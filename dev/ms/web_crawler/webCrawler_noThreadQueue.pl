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
# TODO: fix how workerThread function works
#			possibly is working, but run experiment
# TODO: remove excess code
# TODO: documentation
# TODO: build domain graph
#			discuss issues and run experiment
# TODO: fix linkDepth off by one error
# TODO: what is $_
# TODO: array declaration [] ()
#	
#
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
use Getopt::Long;
use threads;
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
require 'SiteParser.pm';
use SiteParser;
require 'Util.pm';
use Util;

my %options;

my %threadState :shared;
my %threadResults;
#my $pendingJobs = &share([]);

my @threadPool;

print "starting webCrawler.pl...\n";
main();
print "finished running webCrawler.pl\n";

sub main
{
	#set debugging mode and logging
	# obtain the configuration parameters
	# assumes config file path is first parameter
	# grab config file path
	my $pendingJobs = &share([]);
	my $crawledSites = &share({});
	Util::setGlobalDebugFile('errors.dbg');
	Util::debugPrint('ERR INVALID PENDING JOBS DECL: ' . $@ . "; " . $!. "; " . $^E . "; " . $?);
	Util::setGlobalDebugFile('output.dbg');
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
	#my $jobQueueReference :shared = \@pendingJobs;
	#TODO figure out how to pass the jobs
	#This returns an array containing references to hash tables w/ page record info
	my @seedRecords = buildPageRecords(0, @seeds);
	#Pushes reference to an array of hash references to the job queue by ref to shared array pendingJobs
	addJobsToQueue(\@seedRecords, $pendingJobs);
	showStack($pendingJobs);
	Util::debugPrint ( 'seeds added to job queue ');
	#initialize the threads
	Util::debugPrint ( 'initializing threads and starting crawl' );
	for (my $index; $index < $options{'numWorkers'}; $index++)
	{
		Util::debugPrint ("creating thread #" . int($index) );
		Util::setGlobalDebugFile('errors.dbg');
		push(@threadPool, threads->create(\&workerThread, $pendingJobs, $crawledSites));
		Util::debugPrint('WORKER THREAD ERRORS: ' . $@ . "; " . $!. "; " . $^E . "; " . $?);
		Util::setGlobalDebugFile('queueDebug.dbg');
	}
	
	while (threads->list(threads::running))
	{
		foreach (threads->list(threads::joinable))
		{
			$threadResults{$_->tid()} = $_->join();
		}
	}
	
}
#Should take in 3 vals -- first ref to array of hash table refs, second to shared ar. ref
#3rd a scalar ref to array of crawled sites
sub addJobsToQueue
{
	Util::setGlobalDebugFile('queueDebug.dbg');
	#dereference the pagerecords array (now an array of hash refs)
	my @pageRecords = @{$_[0]};
	#Hang onto the jobqueue ref
	my $jobQueueReference = $_[1];
	my $sitesCrawledRef = $_[2];
	Util::debugPrint('JOB ADDER ADDING JOBS TO QUEUE');
	foreach(@pageRecords)
	{
		#Make a shared clone of the hash table
		#but first see if the url you want has already been accessed
		my $pageURL = $_->{url};
		print "Analyzing URL: " . $pageURL . "\n";
		if (exists $sitesCrawledRef->{$pageURL}) 
		{
			Util::setGlobalDebugFile('sitesCrawled.dbg');
			Util::debugPrint('ERROR ADDING JOB: Site crawled previously: ' . $clonedRef->{url});
			Util::setGlobalDebugFile('queueDebug.dbg')
		}
		else
		{
			Util::setGlobalDebugFile('sitesCrawled.dbg');
			Util::debugPrint('JOB ADDED TO QUEUE (previously uncrawled): ' . $_->{url});
			Util::setGlobalDebugFile('errors.dbg');
			my $clonedRef = &shared_clone($_);
		Util::debugPrint('CLONING ERRORS: ' . $@ . "; " . $!. "; " . $^E . "; " . $?);
			Util::setGlobalDebugFile('queueDebug.dbg');
			Util::debugPrint('Adding job to queue: ' . $clonedRef->{url});
			#Push the cloned hash refs to the jobqueue array w/ deref
			#If this fails try with a $
			if(push(@$jobQueueReference, $clonedRef))
			{
				Util::debugPrint('Job successfully added');
				Util::setGlobalDebugFile('errors.dbg');
				Util::debugPrint('PUSHED JOB: ' . $@ . "; " . $!. "; " . $^E . "; " . $?);
				Util::setGlobalDebugFile('queueDebug.dbg');
				$sitesCrawledRef->{$clonedRef->{url}} = 1;
				showStack($jobQueueReference, threads->tid());
			} 
			else
			{
				Util::setGlobalDebugFile('errors.dbg');
				Util::debugPrint('PUSH ERROR: ' . $@ . "; " . $!. "; " . $^E . "; " . $?);
				Util::setGlobalDebugFile('queueDebug.dbg');
				showStack($jobQueueReference, threads->tid());
			}
			
		}
	}
	Util::setGlobalDebugFile('output.dbg');
}

######################################################################################
#	This function takes a link depth and a list of urls and turns them into page
#	records in a hash
#		Parameters
#			content - This should be the HTML page contents. A single scalar holding
#			all the data is expected
#		Return
#			A human readable using string indicating the current time
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

# Expecting pageRecord, jobQueueRef (both as refs)
sub processPage
{
	my $pageRecord = shift;
	my $jobQueueReference = shift;
	Util::setGlobalDebugFile('queueDebug.dbg');
	my $siteContents = get ($pageRecord->{url});
	Util::debugPrint('Retreiving data from: ' . $pageRecord->{url});
	my $parsedPage = SiteParser::parseData($siteContents);
	#Util::debugPrint(' processing ' . $pageRecord->{url});
	#output the page here
	
	#prune the links here
	my @currentPageLinks = @{$parsedPage->links};
	@currentPageLinks = pruneLinks(@currentPageLinks);
	Util::debugPrint('Links retrieved: ' . "@currentPageLinks");
	#add the links to the queue
	my @resultPageRecords;
	my $currentLinkDepth = $pageRecord->{linkDepth};
	if ($currentLinkDepth < $options{'linkDepth'})
	{
		Util::debugPrint(" THREAD BUILDING PAGE RECORDS");
		#Give the buildPageRecords func a linkdepth and array of links
		@resultPageRecords = buildPageRecords($currentLinkDepth++, @currentPageLinks);
		#Returns an array of hash table references
	}
	Util::setGlobalDebugFile('errors.dbg');
	addJobsToQueue(\@resultPageRecords, $jobQueueReference);
	Util::debugPrint('ATTEMPTED TO ADD JOB: ' . $@ . "; " . $!. "; " . $^E . "; " . $?);
	showStack($jobQueueReference);
	Util::setGlobalDebugFile('output.dbg');
}
sub pruneLinks
{
	my @dirtyLinks = $_[0];
	my @cleanLinks;
	foreach(@dirtyLinks)
	{
		my $linkVal = $dirtyLinks[$_];
		if($linkVal =~ m/^http/i) 
		{
			Util::setGlobalDebug('cleanLinks.dbg');
			Util::debugPrint('FOUND CLEAN LINK: ' . $linkVal);
			Util::setGlobalDebugFile('queueDebug.dbg');
			push(@cleanLinks, $linkVal);
		}
	}
	return @cleanLinks;
}
# FIXME: this isn't coded properly
sub workerThread
{
	#print "thread " . threads->tid() . "\n";
	Util::setGlobalDebugFile('queueDebug.dbg');
	Util::debugPrint('Instantiating thread: ' . threads->tid());
	my $jobQueueReference = $_[0];
	showStack($jobQueueReference, threads->tid());
	Util::debugPrint('thread[' . threads->tid() . ']: Job Queue Ref: ' . $jobQueueReference);
	my $isRunning = 1;
	while ($isRunning)
	{
		Util::debugPrint('running');
		$threadState{threads->tid()} = 'RUNNING';
		my $newPage;
		#FORMER: $newPage = pop @pendingJobs
		$newPage = pop @$jobQueueReference;
		Util::debugPrint('POPPING JOB FROM STACK: ' . $newPage);
		if ($newPage == undef)
		{
			Util::debugPrint('JOB NOT FOUND');
			Util::debugPrint('ERROR Getting Job: ' . $@ . "; " . $!. "; " . $^E . "; " . $?);
			$threadState{threads->tid()} = 'WAIT';
			threads->yield();
		}
		else
		{
			Util::debugPrint("JOB FOUND: " . $newPage->{url});
			Util::debugPrint('processing page');
			Util::setGlobalDebugFile('output.dbg');
			processPage($newPage, $jobQueueReference);
			showStack($jobQueueReference, threads->tid());
			Util::setGlobalDebugFile('queueDebug.dbg');
		}
		my @runningThreads = threads->list(threads::all);
		foreach (@runningThreads)
		{
			if ($threadState{$_->tid()} eq 'RUNNING')
			{
				$isRunning = 1;
				next;
			}
		}
		$isRunning = 0;
	}
	Util::setGlobalDebugFile('output.dbg');
	Util::debugPrint('finished');
}
sub showStack {
	Util::setGlobalDebugFile('stack.dbg');
	my ($jobQueueRef, $threadNum) = @_;
	if ($threadNum)
	{
		Util::debugPrint('WORKER [' . $threadNum . '] CURRENT STACK: ' . "@$jobQueueReference");
		Util::debugPrint('WORKER [' . $threadNum . '] STACK ERRORS: ' . $@ . "; " . $!. "; " . $^E . "; " . $?);	
	}
	else 
	{
	Util::debugPrint('NON-WORKER STACK: ' . "@$jobQueueReference");
	Util::debugPrint('NON-WORKER STACK ERRORS: ' . $@ . "; " . $!. "; " . $^E . "; " . $?);	
	}
	Util::setGlobalDebugFile('queueDebug.dbg');
}