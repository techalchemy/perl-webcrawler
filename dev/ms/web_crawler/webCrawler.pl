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
my @pendingJobs :shared;
my %threadState :shared;
my %threadResults;

my @threadPool = 0;

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
	#TODO figure out how to pass the jobs
	my @seedRecords = buildPageRecords(0, @seeds);
	foreach (@seedRecords) { 
		my %jobHash = %{shared_clone(\%{$_})};
		print "job hash: " . $jobHash{'linkDepth'} . "\n";
		push(@pendingJobs, shared_clone(\%{$_})); 
	}
	print "printing jobs\n";
	print join(", ", @pendingJobs);
	Util::debugPrint ( 'seeds added to job queue ');
	#initialize the threads
	Util::debugPrint ( 'initializing threads and starting crawl' );
	for (my $index; $index < $options{'numWorkers'}; $index++)
	{
		Util::debugPrint ("creating thread #" . int($index) );
		push(@threadPool, threads->create(\&workerThread));
	}
	
	while (threads->list(threads::running))
	{
		foreach (threads->list(threads::joinable))
		{
			$threadResults{$_->tid()} = $_->join();
		}
	}
	
}

sub buildPageRecords
{
	my ($linkDepth, @urls) = @_;
	my @pageRecords;
	foreach (@urls)
	{
		my %recordHash;
		my $newRecord = \%recordHash;
		$newRecord->{url} = ($_);
		$newRecord->{linkDepth} = ($linkDepth);
		$newRecord->{timestamp} = (getCurrentTimeString());
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
	my $pageRecord = shift;
	my $siteContents = get ($pageRecord->{url});
	my $parsedPage = SiteParser::parseData($siteContents);
	#output the page here
	
	#prune the links here
	#add the links to the queue
	my @resultPageRecords = ();
	Util::debugPrint("thread: " . threads->tid() . "\tlinks: " . join(",", $parsedPage->{links}));
	if ($pageRecord->{linkDepth} < $options{linkDepth})
	{
		my @resultPageRecords = buildPageRecords($pageRecord->{linkDepth}, $parsedPage->{links});
	}
	foreach (@resultPageRecords)
	{
		Util::debugPrint('thread: ' . threads->tid() . ' adding ' . $_->{url} . ' to queue');		
		push (@pendingJobs, shared_clone (\%{$_}));
	}
}

sub workerThread
{
	Util::debugPrint('thread: ' . threads->tid());
	#print "thread " . threads->tid() . "\n";
	my $isRunning = 1;
	while ($isRunning)
	{
		Util::debugPrint('thread: ' .threads->tid() . ' is running');
		$threadState{threads->tid()} = 'RUNNING';
		my $newPage;
		$newPage = pop @pendingJobs;
		
		if ($newPage == undef)
		{
			Util::debugPrint('thread: ' . threads->tid() . ' going to wait mode');
			$threadState{threads->tid()} = 'WAIT';
			threads->yield();
		}
		else
		{
			Util::debugPrint('new job received by: ' . threads->tid() . "\tjob: " . $newPage->{url});
			Util::debugPrint('thread: ' . threads->tid() . ' processing page');
			processPage($newPage);
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
	print "thread " . threads->tid() . " is finished\n";
}