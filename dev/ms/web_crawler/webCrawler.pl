######################################################################################
#								  webCrawler.pl		
#	Author: Michael Sobczak
#	Date: 2/20/2011								 
######################################################################################
# This script is the main driver of the web crawler. It is called with a config file
# that controls many of its properties. This script will take a list of seeds and
# crawl web dictated by the seed pages and the linkDepth. As well as various other
# pruning properties. WARNING: must be run with -Dusethreads parameter set to
# perl executable. This will allow multiple threads to run.
# The following is a list of the config parameters that can be set in a config
# file and what they do
#	
# TASKS FOR THIS THING
# TODO: remove excess code
# TODO: documentation in natural docs format?
# TODO: build domain graph
#			discuss issues and run experiment
# TODO: change the structure of this project. add some organization via different
#		file structure etc.
# TODO: Incorporate calls to PostData
# 			Including Post Processing Results. See Below.
# TODO: add post processing routines
# TODO: add updating running statistics
#			for performance and web based
# TODO: LARGE GOAL
#			Change how the threading model works
#			Boss and Worker threads
#				Amdahl's law considerations, job queue add and remove
#				requests at the entry and exit of processPage are likely
#				the main component of the serial code runtime. With this
#				in mind the execution of this script will change to
#				a more scalable tree based implementation eventually.
#				as for now, a boss worker thread model should be the next step 
#			Tree based implementation
#				current idea is a hierarchy of crawlers that can send signals
#				back and forth to share data 
#																				 
######################################################################################


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
use Parsing::SiteParser;
use Utilities::Util qw(debugPrint);
use Persistence::PostData qw(sendToDB);
my %options;

print "starting webCrawler.pl...\n";
main();
print "finished running webCrawler.pl\n";

sub main
{
	#set debugging mode and logging
	# obtain the configuration parameters
	# assumes config file path is first parameter
	# grab config file path
	my $configFilePath = $ARGV[0];
	# load config params into %options
	%options = Util::loadConfigFile($configFilePath);
	Util::setGlobalDebug($options{'useDebugMode'});
	Util::setGlobalDebugFile($options{'debugFile'});
	Util::setThreadRecord(1);
	unlink($options{'debugFile'});
	Util::debugPrint( "configuration file loaded" );
	#load the seeds file
	open (SEEDS, "<", $options{'seedFilename'});
	foreach(<SEEDS>)
	{
		chomp();
		push(@seeds, $_);
	}
	close SEEDS;
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
	#my $predictedAccumulatorRef = &share($predictedAccumulatorRef);
	my $processedAccumulator : shared;
	#&share($processedAccumulatorRef);
	$predictedAccumulator = 0;
	$processedAccumulator = 0;
	#share(@pendingJobs);

	my @seedRecords = buildPageRecords(0, @seeds);
	
	
	#initialize the threads
	Util::debugPrint ( 'initializing threads and starting crawl' );
	for (my $index; $index < $options{'numWorkers'}; $index++)
	{
		Util::debugPrint ("creating thread #" . int($index) );
		push(@threadPool, threads->create(\&workerThread, $pendingJobs, $visitedPages, 
				\$predictedAccumulator, \$processedAccumulator));
	}
	
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
	$parsedPage->links->{@prunedPageLinks};
	
	#output the page here using sendToDB(urgency, confighashref, url, parsed page object, and whatever else you want)
	Util::debugPrint('Sending Page to Output for DB');
	if(sendToDB(0, \%options, $pageRecord->{url}, $parsedPage))
	{
		debugPrint(1, 'SENT OUTPUT SUCCESSFULLY');
	}
	else
	{
		debugPrint(1, 'FAILED SENDING OUTPUT!');
	}
	
	#update the during crawl statistics
	addPageToGraph($graphCrawler, $pageRecord->{'url'}, $parsedPage->links);
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

sub addPageToGraph
{
	my ($graphCrawler, $url, @links) = @_;
	my $domainName = extractDomainName($url);
	Util::debugPrint('domain name extracted: ' . $domainName);
	if (exists $domainEncountered->{$domain})
	{
		
	}
	else
	{
		
	}
}

sub extractDomainName
{
	my $url = @_;
	my $domain;
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