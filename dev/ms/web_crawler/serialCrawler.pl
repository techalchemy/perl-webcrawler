## @file pageProcessingBaseline.pl
# this file includes function calls from webCrawler.pl. The intent of this file is to isolate and allow for proper profiling of the page processing
# code without including any aspects of threading and job allocation. The use of this will be to make judgements on page processing optimizations and
# also give an idea of what performance our threading model could expect given an efficient synchronization scheme. This script should be called
# with a config file suited for webCrawler, although not all the parameters will be used.

#all local modules being used by program
use Utilities::Util;
use Parsing::SiteParser;
use PostProcessing::CrawlStatisticsAggregator;
use Deprecated::WebCrawler;

#cpan module used to visually show progress of crawl

#declare constants so boolean logic statements are more readable
use constant true => 1;
use constant false => 0;

my %configurationParameters;
my @numSeeds;

print "(" . WebCrawler::getCurrentTimeString() . ") starting pageProcessingBaseline.pl\n";
start();
print "(" . WebCrawler::getCurrentTimeString() . ") finished running pageProcessingBaseline\n";

## @fn static void main
# execution of the script begins here. Since this code is intended to be run by the profiler, it will attempt to isolate as many
# aspects of the page processing code as possible.
sub start
{
	my $configFilePath = $ARGV[0];
	print "config file path specified: " . $configFilePath . "\n";
	%configurationParameters = Util::loadConfigFile($configFilePath);
	#configure util debug printing facilities
	Util::setGlobalDebug($configurationParameters{'useDebugMode'});
	Util::setGlobalDebugFile($configurationParameters{'debugFile'});
	Util::setThreadRecord(0);
	unlink($configurationParameters{'debugFile'});
	#start
	my $compiledStats = startCrawling();
	#finished, can test post processing performance in another script
}

sub startCrawling
{
	# load the seeds from a file
	my @seeds = WebCrawler::getSeeds($configurationParameters{'seedFilename'});
	print "seeds loaded: " . join(", ", @seeds) . "\n";
	#initialize the data structure being employed to store jobs
	my @seedRecords = WebCrawler::buildPageRecords(0, \@seeds);
	#printPageRecords(@seedRecords);
	#create the job holder
	my @pendingJobs;
	# assign the seed jobs
	push(@pendingJobs, @seedRecords);
	#initialize the statistics aggregator
	my $statsAggregator = CrawlStatisticsAggregator->new();
	$statsAggregator->setSampleRate($configurationParameters{'throughputSampleRate'});
	#start crawling and continue doing so until crawl is finished (no more jobs)
	#populate some variables for efficiency
	my $MAX_LINK_DEPTH = int($configurationParameters{'linkDepth'});
	Util::debugPrint('max link depth allowed set to ' . $MAX_LINK_DEPTH);
	while (@pendingJobs)
	{
		#shift a job off the queue
		my $currentJob = shift(@pendingJobs);
		#store the url and link depth of the page
		my $currentURL = $currentJob->{url};
		my $currentLinkDepth = $currentJob->{linkDepth};
		Util::debugPrint('currently processing ' . $currentURL);
		#grab the page this job refers to
		my $siteContents = WebCrawler::getPageContents($currentURL);
		#parse the page
		my $parsedPage = SiteParser::parseData($siteContents);
		#get the links from the page
		my @linksFound = @{$parsedPage->links};
		
		#prune the links
		my @prunedPageLinks = WebCrawler::pruneLinks(@linksFound);
		#update the stats
		
		#add the found jobs to the queue if still within linkDepth bounds
		if (int($currentLinkDepth) < int($MAX_LINK_DEPTH))
		{
			#turn the pruned links into crawl jobs
			my @newRecords = WebCrawler::buildPageRecords($currentLinkDepth + 1, \@prunedPageLinks);
			push(@pendingJobs, @newRecords);
		}
		else
		{
			Util::debugPrint('link depth limit reached, not adding links to crawl job');
		}
		$statsAggregator->update($currentURL, \@prunedPageLinks);
		#estimatePercentComplete($statsAggregator, \@pendingJobs);
		printDebugInfo($statsAggregator, scalar(@pendingJobs));
	}
	#clean up the statistics aggregation
	Util::debugPrint('all jobs have been processed, cleaning up and finishing crawl');
	$statsAggregator->finish();
	return $statsAggregator;
}

sub printPageRecords
{
	print "printing list of records:\n";
	my $counter = 0;
	foreach(@_)
	{
		print "\trecord #" . $counter . ":\n\t\t";
		print $_->{url} . "\n\t\t";
		print $_->{linkDepth} . "\n";
	}
}

sub printDebugInfo
{
	my ($stats, $jobsPending) = @_;
	Util::debugPrint('jobs processed so far ' . $stats->getTotalJobsProcessed());
	Util::debugPrint('jobs currently waiting to be processed ' . $jobsPending);
}

sub estimatePercentComplete
{
	my ($statsAggregator, $pendingJobs) = @_;
	my $totalJobsProcessed = $statsAggregator->getTotalJobsProcessed();
	my $totalJobsDiscovered = $statsAggregator->getTotalJobsDiscovered();
	# declare the variable that will hold the estimate of the total amount of jobs this crawl run will end up assigning
	my $finalNumberOfPagesEstimate = 0;
	#
}

