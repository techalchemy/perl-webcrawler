#this class will be used to handle the post processing functions in the webCrawler

package CrawlStatisticsAggregator;
use Time::HiRes qw(gettimeofday);

use constant TIMER_UNITS_PER_MILLISECOND => 1000;

sub new
{
	my $self = {};
	$self->{TOTAL_JOBS_PROCESSED} = 0;
	$self->{JOBS_PROCESSED_ACCUMULATOR} = 0;
	$self->{LAST_SAMPLE_TIME} = 0;
	$self->{SAMPLE_RATE} = 0;
	$self->{CRAWL_GRAPH} = {};
	$self->{THROUGHPUT_SAMPLES} = [];
	bless $self, 'CrawlStatisticsAggregator';
	return $self;
}

sub setSampleRate
{
	#account for using micro second timer
	$_[0]->{SAMPLE_RATE} = $_[1] / TIMER_UNITS_PER_MILLISECOND;
}

sub update
{
	my ($self, $crawlGraph, $url, $links) = @_;
	# add the current page and its links to the crawl graph
	addPageToGraph($crawlGraph, $url, @{$links});
	# update the throughput
	my ($throwAway, $currentTime) = gettimeofday;
	my $lastSampleTime = $self->{LAST_SAMPLE_TIME};
	if ($lastSampleTime == 0)
	{
		$self->{THROUGHPUT_SAMPLES} = gettimeofday;
	}
	$self->{JOBS_PROCESSED_ACCUMULATOR}++;
	if ($currentTime - $lastSampleTime > $self->{SAMPLE_RATE})
	{
		push(@{$self->{THROUGHPUT_SAMPLES}}, $self->{JOBS_PROCESSED_ACCUMULATOR});
		$self->{JOBS_PROCESSED_ACCUMULATOR} = 0;
		$self->{LAST_SAMPLE_TIME} = $currentTime;
	}
}

sub addPageToGraph
{
	my ($graphCrawler, $url, @links) = @_;
	my $domainName = extractDomainName($url);
	Util::debugPrint('domain name extracted: ' . $domainName);
	my $outgoingLinks = $domainEncountered->{$domainName};
	if (!exists $outgoingLinks)
	{
		$outgoingLinks = {};	
	}
	foreach(@links)
	{
		$outgoingLinks->{$_}++;
	}
}

sub extractDomainName
{
	foreach(@_)
	{
		$_ =~ s/(http:\/\/|www\.)//g;
	}
}



1;