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
	$self->{SAMPLE_START_TIME} = 0;
	bless $self, 'CrawlStatisticsAggregator';
	return $self;
}

sub setSampleRate
{
	#account for using micro second timer
	$_[0]->{SAMPLE_RATE} = $_[1] * TIMER_UNITS_PER_MILLISECOND;
}

sub update
{
	my ($self, $url, $links) = @_;
	# add the current page and its links to the crawl graph
	addPageToGraph($self, $url, @{$links});
	updateThroughput($self);
}

sub updateThroughput
{
	my $self = shift;
	# update the throughput
	#get the current time
	my $currentTime = _getTime();
	#find the last sample time
	my $lastSampleTime = $self->{LAST_SAMPLE_TIME};
	#if the last sample time is 0, it means this is the first time
	#update has been called
	# for postProcessing purposes, multiple instances of this object
	# will need to be aligned to plot the overall throughput
	# this is done by having a SAMPLE_START_TIME that holds the
	# time that this instance started sampling
	if ($lastSampleTime == 0)
	{
		$self->{SAMPLE_START_TIME} = _getTime();
	}
	# Add to the processed job counter and the accumulator
	$self->{JOBS_PROCESSED_ACCUMULATOR}++;
	$self->{TOTAL_JOBS_PROCESSED}++;
	# see if time of sample has elapsed
	if ($currentTime - $lastSampleTime > $self->{SAMPLE_RATE})
	{
		# add the jobs processed over interval
		# to the samples array
		push(@{$self->{THROUGHPUT_SAMPLES}}, $self->{JOBS_PROCESSED_ACCUMULATOR});
		# reset accumulator
		$self->{JOBS_PROCESSED_ACCUMULATOR} = 0;
		# update the last sample time field
		$self->{LAST_SAMPLE_TIME} = $currentTime;
	}
}

sub addPageToGraph
{
	my ($self, $url, @links) = @_;
	my $domainName = extractDomainName($url);
	Util::debugPrint('domain name extracted: ' . $domainName);
	my $outgoingLinks = $self->{CRAWL_GRAPH}->{$domainName};
	foreach(@links)
	{
		my $currentLinkDomain = extractDomainName($_);
		$outgoingLinks->{$currentLinkDomain}++;
	}
}

sub extractDomainName
{
	foreach(@_)
	{
		$_ =~ s/(http:\/\/|www\.)//g;
	}
}

#returns the time in microseconds
sub _getTime
{
	my ($seconds, $microseconds) = gettimeofday;
	return ($seconds * 10**6) + $microseconds;
}



1;