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

my %options;
my $pendingJobs = Thread::Queue->new();
my %threadState :shared;
my %threadResults;

my $isRunning = 0;
my @threadPool = 0;

print "starting webCrawler.pl...\n";
main();
print "finished running webCrawler.pl\n";

sub main
{
	# obtain the configuration parameters
	# assumes config file path is first parameter
	# grab config file path
	my $configFilePath = $ARGV[0];
	# load config params into %options
	%options = Util::loadConfigFile($configFilePath);
	print "configuration file loaded\n";
	#load the seeds file
	open (SEEDS, "<", $options{'seedFilename'});
	my @seeds = <SEEDS>;
	close SEEDS;

	#initialize the job queue
	$pendingJobs->enqueue(@seeds);
	#initialize the threads
	for (my $index; $index < $options{'numWorkers'}; $index++)
	{
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

sub processPage
{
	my $pageRecord = shift;
	my $siteContents = get ($pageRecord->url);
	my $parsedPage = SiteParser::parseData($siteContents);
	#output the page here
	print "thread: " . threads->tid() . "\tcrawling: " . $pageRecord->url . "\n";
	#prune the links here
	#add the links to the queue
	my @resultPageRecords = ();
	if ($pageRecord->linkDepth < options{'linkDepth'})
	{
		my @resultPageRecords = buildPageRecords($parsedPage->links);
	}
	$pendingJobs->enqueue(\@resultPageRecords); 
}

sub workerThread
{
	while ($isRunning)
	{
		my $newPage;
		if ($threadHasExecutedTable{threads->tid()})
		{
			$newPage = $pendingJobs->dequeue_nb();
			if ($newPage == undef)
			{
				return;	
			}
		}
		else
		{
			$newPage = $pendingJobs->dequeue();
			$threadHasExecutedTable{threads->tid()} = 1;
		}
		processPage($newPage);
	}
}