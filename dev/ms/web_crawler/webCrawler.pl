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

# check for threading enabled
my $can_use_threads = eval 'use threads; 1';
if (!($can_use_threads))
{
	print "please run again with threads enabled\n";
	exit();
}
# get CPAN modules
use threads ('stringify');
use threads::shared;
use Thread::Queue;
use LWP::Simple;
use Class::Struct;
#declare structs used by crawler
struct(PAGE_RECORD => {url => '$',
					   timestamp => '$',
					   linkDepth => '$',
					  });

# get local modules
require 'Parsing/SiteParser.pm';
require 'Utilities/Util.pm';
require 'Persistence/PostData.pm';
require 'PostProcessing/CrawlStatisticsAggregator.pm';
use Parsing::SiteParser;
use Utilities::Util qw(debugPrint);
use Persistence::PostData qw(sendToDB);
use PostProcessing::CrawlStatisticsAggregator qw(update);
my %options;

print "starting webCrawler.pl...\n";
main();
print "finished running webCrawler.pl\n";

## @fn public static void main()
# this is the entry point of the script
sub main
{
	#set debugging mode and logging
	# obtain the configuration parameters
	# assumes config file path is first parameter
	# grab config file path
	my $configFilePath = $ARGV[0];
	
	# load config params into %options
	loadConfigurationFile($configFilePath);
	Util::debugPrint( "configuration file loaded" );
	
	#load the seeds file
	my @seeds = getSeeds();
	Util::debugPrint ( 'seed file loaded' );
	
	#initialize the job queue
	my $pendingJobs = new Thread::Queue;

	#this is a shared hash that will be used to keep track of which pages
	#have already been visited.
	#	TODO: adding another object that needs to be accessed serially could
	#		  start to limit the scalability of the system. Is there some way
	#		  we can speed this up?
	my $visitedPages = &share({});
	#these accumulators are used to track the program
	my $predictedAccumulator : shared;
	my $processedAccumulator : shared;
	#&share($processedAccumulatorRef);
	$predictedAccumulator = 0;
	$processedAccumulator = 0;

	my @seedRecords = buildPageRecords(0, @seeds);
	
	
	#initialize the threads
	my @threadPool = initializeThreads($pendingJobs, $visitedPages, \$predictedAccumulator, \$processedAccumulator);
	Util::debugPrint ( 'initializing threads and starting crawl' );
	
	
	#add jobs to queue
	addJobsToQueue(\@seedRecords, $pendingJobs, \$predictedAccumulator);
	Util::debugPrint ( 'seeds added to job queue ');
	my $threadResults = {};
	foreach(@threadPool)
	{
		$threadResults->{$_->tid()} = $_->join();
	}
	Util::debugPrint ( 'crawling finished, beginning post processing');
	
	return 1;
}

sub initializeThreads
{
	my ($pendingJobs, $visitedPages, $predictedAccumulatorRef, $processedAccumulatorRef) = @_;
	my @threadPool;
	for (my $index; $index < $options{'numWorkers'}; $index++)
	{
		Util::debugPrint ("creating thread #" . int($index) );
		push(@threadPool, threads->create(\&workerThread, $pendingJobs, $visitedPages, 
				$predictedAccumulatorRef, $processedAccumulatorRef));
	}
	return @threadPool;
}

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

######################################################################################
#	This function takes a link depth and a list of urls and turns them into page
#	records in a hash
#		Parameters
#			content - This should be the HTML page contents. A single scalar holding
#			all the data is expected
#		Return
#			A human readable using strinpopg indicating the current time
#
######################################################################################
sub buildPageRecords
{
	my ($linkDepth, @urls) = @_;
	my @pageRecords;
	foreach (@urls)
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

######################################################################################
#	This function takes the current time and outputs it in a format that is human
#	readable. For future processing, the time can be broken up easily with regexes
#		Parameters
#			content - This should be the HTML page contents. A single scalar holding
#			all the data is expected
#		Return
#			A human readable using string indicating the current time
#
######################################################################################
sub getCurrentTimeString
{
	my @tempTime = localtime(time);
	my $seconds = @tempTime[0];
	my $minutes = @tempTime[1];
	my $hours = @tempTime[2];
	my $day = @tempTime[3];
	my $month = @tempTime[4];
	my $year = int(@tempTime[5]) + 1900;
	return $day . "/" . $month . "/" . $year . " " . $hours . ":" . $minutes . ":" . $seconds;
}

sub processPage
{
	#obtain the page record
	my ($pageRecord, $pendingJobs, $visitedPages, $predictedAccumulatorRef, $graphCrawler) = @_;
	#grab the site contents
	my $siteContents = get ($pageRecord->{url});
	#parse the page
	my $parsedPage = SiteParser::parseData($siteContents);
	Util::debugPrint(' processing ' . $pageRecord->{url});
	#prune the links here
	my @currentPageLinks = @{$parsedPage->links};
	my @prunedPageLinks = pruneLinks(@currentPageLinks);
	my $numLinksPruned = scalar(@currentPageLinks) - scalar(@prunedPageLinks);
	Util::debugPrint('pruned ' . $numLinksPruned . ' links');
	
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
	
	#add the links to the queue
	my @resultPageRecords = ();
	my $currentLinkDepth = $pageRecord->{linkDepth};
	if (int($currentLinkDepth) < int($options{'linkDepth'}))
	{
		Util::debugPrint(" building records");
		#increase the predicted jobs accumulator
		@resultPageRecords = buildPageRecords($currentLinkDepth + 1, @prunedPageLinks);
	}
	else
	{
		Util::debugPrint(' link depth limit reached ');
	}
	addJobsToQueue(\@resultPageRecords, $pendingJobs, $predictedAccumulatorRef);
}

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

sub workerThread
{
	my ($pendingJobs, $visitedPages, $predictedAccumulatorRef, $processedAccumulatorRef) = @_;
	my $crawlGraph = \{};
	while (my $newJob = $pendingJobs->dequeue())
	{
		$$processedAccumulatorRef++; 
		Util::debugPrint( 'total jobs processed ' . $$processedAccumulatorRef );
		processPage($newJob, $pendingJobs, $visitedPages, $predictedAccumulatorRef, $crawlGraph);
		if ($$predictedAccumulatorRef == $$processedAccumulatorRef)
		{
			last;
		}
		threads->yield();
	}
	Util::debugPrint('finished');
	return $crawlGraph;
}