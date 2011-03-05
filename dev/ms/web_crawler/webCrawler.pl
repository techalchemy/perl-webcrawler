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
# TODO: documentation
# TODO: build domain graph
#			discuss issues and run experiment
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
require 'SiteParser.pm';
use SiteParser;
require 'Util.pm';
use Util;

# This will be used to access the configuration parameters specificied in file
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
	my $threadState = &share({});
	#share(@pendingJobs);
	#TODO figure out how to pass the jobs
	my @seedRecords = buildPageRecords(0, @seeds);
	
	Util::debugPrint ( 'seeds added to job queue ');
	#initialize the threads
	Util::debugPrint ( 'initializing threads and starting crawl' );
	for (my $index; $index < $options{'numWorkers'}; $index++)
	{
		Util::debugPrint ("creating thread #" . int($index) );
		threads->create(\&workerThread, $pendingJobs, $threadState);
	}
	
	#add jobs to queue
	addJobsToQueue(\@seedRecords, $pendingJobs);
	my $threadResults;
	while (threads->list(threads::running))
	{
		foreach (threads->list(threads::joinable))
		{
			$threadResults{$_->tid()} = $_->join();
		}
	}
	
}

sub addJobsToQueue
{
	my @pageRecords = @{$_[0]};
	my $jobs = $_[1];
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
	my $pageRecord = shift;
	#obtain reference to job queue
	my $pendingJobs = shift;
	#grab the site contents
	my $siteContents = get ($pageRecord->{url});
	#parse the page
	my $parsedPage = SiteParser::parseData($siteContents);
	Util::debugPrint(' processing ' . $pageRecord->{url});
	#output the page here
	
	#prune the links here
	my @currentPageLinks = @{$parsedPage->links};
	my @prunedPageLinks = pruneLinks(currentPageLinks);
	#add the links to the queue
	my @resultPageRecords = ();
	my $currentLinkDepth = $pageRecord->{linkDepth};
	if ($currentLinkDepth + 1 < $options{'linkDepth'})
	{
		Util::debugPrint(" building records");
		@resultPageRecords = buildPageRecords($currentLinkDepth++, @prunedPageLinks);
	}
	else
	{
		Util::debugPrint(' link depth limit reached');
	}
	addJobsToQueue(\@resultPageRecords, $pendingJobs);
}

sub pruneLinks
{
	my @links = @_;
	my @prunedList;
	foreach(@links)
	{
		if (/http:\/\/www./)
		{
			push(@prunedList, $_);
		}
	}
	return @prunedList;
}

# FIXME: this isn't coded properly. program will never stop
sub workerThread
{
	my $pendingJobs = $_[0];
	while (my $newJob = $pendingJobs->dequeue())
	{
		processPage($newJob, $pendingJobs);
	}
#	my $pendingJobs = $_[0];
#	my $threadState = $_[1];
#	Util::debugPrint('execution started');
#	$threadState->{threads->tid()} = 'RUNNING';
#	my $isRunning = 1;
#	my $firstJob = $pendingJobs->dequeue();
#	Util::debugPrint('first job received');
#	processPage($newJob, $pendingJobs);
#	
#	while ($isRunning)
#	{
#		my $currentJob = $pendingJobs->dequeue_nb();
#		if ($currentJob == undef)
#		{
#			Util::debugPrint('going into wait mode');
#			$threadState->{threads->tid()} = 'WAITING';
#			threads->yield();
#		}
#		else
#		{
#			Util::debugPrint('going into run mode');
#			$threadState->{threads->tid()} = 'RUNNING';
#			processPage($currentJob, $pendingJobs);
#		}
#		if ($currentJob == undef)
#		{
#			my $foundARunner = 0;
#			while (my ($key, $value) = each %{$threadState})
#			{
#				if ($key eq 'RUNNING')
#				{
#					$foundARunner = 1;
#				}
#			}
#			if (!($foundARunner))
#			{
#				$isRunning = 0;
#			}
#		}
#	}
	
	
	Util::debugPrint('finished');
}