## @file webCrawler.pl
# this file is the main script for the web crawler. It is the file that will be explicity invoked
# to start a crawl. It expects the first parameter fed to it to be a path to a configuration file.
# the configuration file will specify many of the runtime parameters of the crawler and used
# throughout the code. The following config parameters are used by the crawler and its subsidiary
# modules
# - Configuration Parameters
#	- useDebugMode this paramater indicates whether or not debugging statements should be printed
#	- debugFile name of the debug output file
#	- seedFilename the name of the file containing the seeds to start the crawler with
#	- numWorkers number of worker threads the crawler should create
#	- linkDepth the maximum link depth the crawler should crawl to (seeds are considered to have a link depth of 0)
#	- verbosity the level of verbosity wanted with debug statements. currently three levels of debugging are used by this script
#		# this is the lowest level of verbosity that only prints general information about what the script is doing
#		# this level of verbosity will go more in depth and print function calls and return values
#		# this is the highest level of verbosity and will print a debug line for almost every line of code executed
#	- throughputSampleRate the time in seconds between throughput samples
#	- maxJobsToProcess the maximum number of jobs to process before exiting. Used for debugging. If less than 1, means no limit

# TODO: remaining crawler tasks
# 1). Clean up the code
#	  - split large function definitions into multiple functions
#	  - change documentation to use perl doxygen specification
# 2). Improve debug printing functionality
#	  - implement verbosity levels for different debug statements
#	  - look into conditional code inclusion (debug and release modes)
# 3). Add the statistics aggregation and post processing output
# 4). Move threading code to external module

# check for threading enabled
my $can_use_threads = eval 'use threads; 1';
if (!($can_use_threads))
{
	print "please run again with threads enabled\n";
	exit();
}
# CPAN modules used by this script
use threads ('stringify');
use threads::shared;
use Thread::Queue;
use LWP::Simple;
use Class::Struct;
use Cwd;
# Local modules used by this script;
use Parsing::SiteParser;
use Utilities::Util qw(debugPrint);
use Persistence::PostData qw(sendToDB);
use lib 'PostProcessing';
use CrawlStatisticsAggregator;
use Consolidate;
use OutputGenerator;


#declare structs used by crawler
struct(PAGE_RECORD => {url => '$',
					   timestamp => '$',
					   linkDepth => '$',
					  });

use constant TERMINATE_WORKER => 'TERMINATE';

## @var options
# this is a hash that will store the options specified by the supplied configuration file
my %options = {
	'useDebugMode' => 0,
	'debugFile' => 'output.dbg',
	'seedFilename' => 'seeds.txt',
	'numWorkers' => 4,
	'linkDepth' => 3,
	'verbosity' => 1,
	'throughputSampleRate' => 60
};


print "(" . getCurrentTimeString() . ") starting webCrawler.pl...\n";
main();
print "(" . getCurrentTimeString() . ") finished running webCrawler.pl\n";

## @fn public static void main()
# this is the entry point of the script
sub main
{
	#set debugging mode and logging
	# obtain the configuration parameters
	# assumes config file path is first parameter
	# grab config file path
	my $configFilePath = retrieveAndVerifyConfigurationFilePath();
	
	
	
	# load config params into %options
	loadConfigurationFile($configFilePath);
	Util::debugPrint( "configuration file loaded" );
	
	
	#load the seeds file
	my @seeds = getSeeds();
	Util::debugPrint ( 'seed file loaded' );
	
	#initialize the job queue
	my $pendingJobs = new Thread::Queue;

	my $visitedPages = &share({});
	#these accumulators are used to track the program
	my $predictedAccumulator : shared;
	my $processedAccumulator : shared;
	$predictedAccumulator = 0;
	$processedAccumulator = 0;

	my @seedRecords = buildPageRecords(0, \@seeds);
	#add jobs to queue
	addJobsToQueue(\@seedRecords, $pendingJobs, \$predictedAccumulator);
	
	#initialize the threads
	my @threadPool = initializeThreads($pendingJobs, \$predictedAccumulator, \$processedAccumulator);
	Util::debugPrint ( 'initializing threads and starting crawl' );
	
	
	Util::debugPrint ( 'seeds added to job queue ');
	
	my $threadResults = finishAndCleanUpThreads(@threadPool);
	Util::debugPrint ( 'crawling finished, beginning post processing');
	
	performPostProcessing($threadResults);
	
	Util::debugPrint ( 'post processing finished, exiting script' );
	return 1;
}

## @fn static void retrieveAndVerifyConfigurationFilePath()
# this function is used to get the configuration file path and ensure a legal filename was supplied. if this isn't the case
# the script will either print the usage and exit or simply exit, depending on the circumstances
sub retrieveAndVerifyConfigurationFilePath
{
	my $configFilePath = $ARGV[0];
	if (-e $configFilePath)
	{
		return $configFilePath;
	}
	elsif (scalar(@ARGV) == 0)
	{
		printUsage();
		Util::debugPrint ('No configuration file specified, script exiting');
		exit(0);
	}
	else
	{
		Util::debugPrint ('ERROR: Configuration file not found, script exiting');
		exit(1);
	}
}

## @fn static void performPostProcessing($threadResults)
# this function handles the calls to external post processing modules
# @param threadResults a reference to a hash containing a key for each worker thread id and the results of their thread function
sub performPostProcessing
{
	my $crawlResults = $_[0];
	my $totalJobsProcessed = 0;
	my @aggregators;
	while (my ($key, $value) = each %{$crawlResults})
	{
		push(@aggregators, $crawlResults->{$key});
	}
#	print "total jobs processed: " . $totalJobsProcessed . "\n";
	my $consolidatedStatistics = Consolidate::consolidateStatistics(@aggregators);
	my @consolidatedThroughput = @{$consolidatedStatistics->THROUGHPUT};
	my $currentTime = 0;
	my $sampleRate = $consolidatedStatistics->SAMPLE_RATE;
	
	print 'consolidated throughput: ' . join(',', @consolidatedThroughput) . "\n";
#	
	open(OUTPUT_FILE, ">", "output.csv");
	
	print OUTPUT_FILE "time, jobs\n";
	
	foreach(@consolidatedThroughput)
	{
		print OUTPUT_FILE ($currentTime/60) . ", " . $_ . "\n";
		$currentTime += $sampleRate;
	}
	
	close OUTPUT_FILE;
	#OutputGenerator::generateOutput(getcwd() . "/output", \@aggregators);
}

## @fn static void printUsage()
# this function prints the proper calling syntax for the script
sub printUsage
{
	print "\n\tUsage:\n\n\t\tperl webCrawler.pl <configuration file>\n";
}

## @fn static void finishAndCleanUpThreads(@threadPool)
# this function joins all the existing working threads and places their results in a hash indexed by thread id
# @param threadPool array of the worker thread objects
# @return threadResults returns the results of the worker thread's computation
sub finishAndCleanUpThreads
{
	my @threadPool = @_;
	my $threadResults = {};
	foreach(@threadPool)
	{
		$threadResults->{$_->tid()} = $_->join();
	}
	return $threadResults;
}

## @fn static threads[] initializeThreads($pendingJobs, $predictedAccumulatorRef, $processedAccumulatorRef)
# handles thread initialization for the crawling. Creates the threads and places references to them
# into the thread pool array which is eventually returned.
# @param pendingJobs a reference to the job queue 
# @param predictedAccumulatorRef shared reference to the discovered number of jobs thus far
# @param processedAccumulatorRef shared reference to the processed number of jobs so far
# @return threadPool a list of references to the worker threads
sub initializeThreads
{
	my ($pendingJobs, $predictedAccumulatorRef, $processedAccumulatorRef) = @_;
	my @threadPool;
	for (my $index; $index < $options{'numWorkers'}; $index++)
	{
		Util::debugPrint ("creating thread #" . int($index) );
		push(@threadPool, threads->create(\&workerThread, $pendingJobs, 
											  $predictedAccumulatorRef, 
											  $processedAccumulatorRef));
	}
	return @threadPool;
}


## @fn static String[] getSeeds()
# grabs the seeds from the file specified by the seedFilename parameter in the configuration file
# @return a list of the seeds obtained from the file
sub getSeeds
{
	my @seeds;
	open (SEEDS, "<", $options{'seedFilename'});
	foreach(<SEEDS>)
	{
		chomp();
		push(@seeds, $_);
	}
	close SEEDS;
	return @seeds;
}

sub loadConfigurationFile
{
	my $configFilePath = $_[0];
	%options = Util::loadConfigFile($configFilePath);
	Util::setGlobalDebug($options{'useDebugMode'});
	Util::setGlobalDebugFile($options{'debugFile'});
	Util::setThreadRecord(1);
	unlink($options{'debugFile'});
}

sub addJobsToQueue
{
	my @pageRecords = @{$_[0]};
	my $jobs = $_[1];
	my $discoveredJobsAccumulator = $_[2];
	$$discoveredJobsAccumulator += scalar(@pageRecords);
	Util::debugPrint($$discoveredJobsAccumulator . ' total jobs assigned');
	foreach(@pageRecords)
	{
		$jobs->enqueue($_);
	}
}

## @fn static PAGE_RECORD[] buildPageRecords($linkDepth, @urls)
sub buildPageRecords
{
	my ($linkDepth, $urls) = @_;
	my @pageRecords;
	foreach (@{$urls})
	{
		my %recordHash;
		my $newRecord = \%recordHash;
		$newRecord->{url} = $_;
		$newRecord->{linkDepth} = $linkDepth;
		$newRecord->{timestamp} = getCurrentTimeString();
		push (@pageRecords, $newRecord);
	}
	return @pageRecords;
}

## @fn static string getCurrentTimeString()
# This function returns the current date and time in a nice looking human readable format
# @return string of the current time
sub getCurrentTimeString
{
	my @tempTime = localtime(time);
	my $seconds = @tempTime[0];
	my $minutes = @tempTime[1];
	my $hours = @tempTime[2];
	my $day = @tempTime[3];
	my $month = @tempTime[4];
	my $year = int(@tempTime[5]) + 1900;
	_addZeroIfLessThanTen($hours, $minutes, $seconds);
	return $day . "/" . $month . "/" . $year . " " . $hours . ":" . $minutes . ":" . $seconds;
}

## @fn private static void _addZeroIfLessThanTen(@strings)
# This function takes a list of strings and prefixes a zero to all the
# strings that are less than 10
sub _addZeroIfLessThanTen
{
	foreach(@_)
	{
		if ($_ < 10)
		{
			$_ = '0' . $_;
		}
	}
}

## @fn static void processPage($pageRecord, $pendingJobs, $visitedPages, $predictedAccumulatorRef, $statsAggregator)
# This function is called by the worker threads with each job they receive. This function is currently
# a wrapper for 
sub processPage
{
	#obtain the page record
	my ($pageRecord, $pendingJobs, $predictedAccumulatorRef, $statsAggregator) = @_;
	#grab the site contents
	my $siteContents = getPageContents($pageRecord->{url});
	#parse the page
	my $parsedPage = SiteParser::parseData($siteContents);
	#prune the links here
	my @currentPageLinks = @{$parsedPage->links};
	my @prunedPageLinks = pruneLinks(@currentPageLinks);
	
	# LINE ADDED FOR DAN --  I WANT PRUNED LINKS BACK FOR DB
	#$parsedPage->links->{@prunedPageLinks};
	
	#output the page here using sendToDB(urgency, confighashref, url, parsed page object, and whatever else you want)
#	Util::debugPrint('Sending Page to Output for DB');
#	if(sendToDB(0, \%options, $pageRecord->{url}, $parsedPage))
#	{
#		debugPrint(1, 'SENT OUTPUT SUCCESSFULLY');
#	}
#	else
#	{
#		debugPrint(1, 'FAILED SENDING OUTPUT!');
#	}
	
	#update the during crawl statistics
	$statsAggregator->update($pageRecord->{url}, \@currentPageLinks);
	
	checkLinkDepthAndAddJobs($pageRecord->{linkDepth}, 
							\@prunedPageLinks, 
							$pendingJobs, 
							$predictedAccumulatorRef);
}

## @fn static void checkLinkDepthAndAddJobs($currentLinkDepth, $prunedPageLinks, $jobQueue, $discoveredCounterRef)
# This function checks to make sure that the jobs discovered don't exceed the link depth limit of the crawl. If the jobs
# meet this criteria, they get added to the queue using an addJobToQueue function call
# @param currentLinkDepth the link depth of the page that spawned the links possibly being added
# @param prunedPageLinks a reference to an array of links. These should be pruned before passed to this function
# @param jobQueue reference to the shared job queue, this gets passed through to the add jobs meeting
# @param discoveredCounterRef a reference to a shared scalar to keep track of the jobs discovered
sub checkLinkDepthAndAddJobs
{
	my ($currentLinkDepth, $prunedPageLinks, $jobQueue, $discoveredCounterRef) = @_;
	if (int($currentLinkDepth) < int($options{'linkDepth'}))
	{
		my @resultPageRecords = buildPageRecords($currentLinkDepth + 1, $prunedPageLinks);
		addJobsToQueue(\@resultPageRecords, $jobQueue, $discoveredCounterRef);
	}
}

## @fn static void getPageContents($url)
# The getPageContents function is responsible for taking a url and obtaining its information by accessing the internet
# the current implementation is one line using a function defined in the LWP::Simple module but has been abstracted out
# of the page processing function so it can be modified in the future or placed in a different calling context
# @param url the url of the page to grab
# @return the raw html of the web page specified by the url
sub getPageContents
{
	my $url = $_[0];
	return get($url);
}

## @fn static void pruneLinks(@links)
# this function is responsible for taking a list of all the links found in a page and filtering out the irrelevant ones.
# currently the only pruning applied is a regex that makes sure the link starts with http://
# @param links a list of potential sites to crawl
# @return a pruned list of the links passed to the function
sub pruneLinks
{
	my @links = @_;
	my @prunedList;
	foreach(@links)
	{
		if (/^http:\/\//)
		{
			push(@prunedList, $_);
		}
	}
	return @prunedList;
}


## @fn static void workerThread($pendingJobs, $predictedAccumulatorRef, $processedAccumulatorRef)
# This function is the entry point for all of the worker threads used to process the pages. This function essentially
# pulls jobs off the queue and processes them one by one. During the processing, more jobs will likely be added to the queue
# the current end condition for the worker threads are when all the discovered jobs have been processed. Once a single
# worker thread meets this condition it creates TERMINATE_WORKER jobs and adds them to the queue. When the other threads
# obtain these jobs they will also terminate. Once finished, the thread returns the statistics aggregated during the crawl
# @param pendingJobs a reference to the job queue
# @param predictedAccumulatorRef reference to the total number of jobs added to the queue
# @param processedAccumulatorRef reference to the total number of jobs processed
# @return the finished crawl statistics aggregator
sub workerThread
{
	my ($pendingJobs, $predictedAccumulatorRef, $processedAccumulatorRef) = @_;
	my $statsAggregator = CrawlStatisticsAggregator->new();
	$statsAggregator->setSampleRate($options{'throughputSampleRate'});
	my $JOBS_LIMIT = $options{'maxJobsToProcess'};
	if ($JOBS_LIMIT < 1) { $JOBS_LIMIT = Inf; }
	while (my $newJob = $pendingJobs->dequeue())
	{	
		if ($newJob eq TERMINATE_WORKER)
		{
			last;
		}
		processPage($newJob, $pendingJobs, $predictedAccumulatorRef, $statsAggregator);
		$$processedAccumulatorRef++; 
		Util::debugPrint( 'total jobs processed ' . $$processedAccumulatorRef );
		if ($$predictedAccumulatorRef == $$processedAccumulatorRef || $$processedAccumulatorRef >= $JOBS_LIMIT)
		{
			my @terminalJobArray;
			for (my $index = 0; $index < $options{'numWorkers'} - 1; $index++)
			{
				push(@terminalJobArray, TERMINATE_WORKER);
			}
			$pendingJobs->enqueue(@terminalJobArray);
			last;
		}
		threads->yield();
	}
	Util::debugPrint('finished');
	$statsAggregator->finish();
	return $statsAggregator;
}