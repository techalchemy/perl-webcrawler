## @file CrawlStatisticsAggregator.pm
# this module is an implementation of the crawl statistics aggregator class

## @class CrawlStatisticsAggregator
# @par Description
# This class is intended to be used by worker threads in the crawler. it will aggregate runtime
# crawl statistics using the update method. after all the workers are done, all the instances
# of this class will be consolidated and processed by other modules to generate output data
package CrawlStatisticsAggregator;

use Time::HiRes qw(gettimeofday);

## @var TIMER_UNITS_PER_MILLISECOND
# used to compensate for the fact that sample rates are specified in milliseconds but the
# timer being used by this module operates in microseconds
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
	_addPageToGraph($self, $url, @{$links});
	_updateThroughput($self);
}

sub _updateThroughput
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
	# since an instance of this object is only one of many
	# and will need to aligned with others, we need to account
	# for the possibility that multiple sample lengths could
	# have elapsed since the last sampling
	my $samplesMissed = ($currentTime - $self->{LAST_SAMPLE_TIME}) / $self->{SAMPLE_RATE};
	if ($samplesMissed >= 1)
	{
		# add the jobs processed over interval
		# to the samples array
		push(@{$self->{THROUGHPUT_SAMPLES}}, $self->{JOBS_PROCESSED_ACCUMULATOR});
		# reset accumulator
		$self->{JOBS_PROCESSED_ACCUMULATOR} = 0;
		# update the last sample time field
		my $leftToPush = int($samplesMissed - 1);
		while ($leftToPush > 0)
		{
			push (@{$self->THROUGHPUT_SAMPLES}, 0);
		}
		$self->{LAST_SAMPLE_TIME} = $currentTime;
	}
}

sub _addPageToGraph
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
	my $currentDomain = $_[0];
	$currentDomain =~ s!^https?://(?:www\.)?!!i;
	$currentDomain =~ s!/.*!!;
	$currentDomain =~ s/[\?\#\:].*//;
	return $currentDomain;
}

#returns the time in microseconds
sub _getTime
{
	my ($seconds, $microseconds) = gettimeofday;
	return ($seconds * 10**6) + $microseconds;
}


# set and get accessor methods


sub getSampleRate
{
	return $_[0]->{SAMPLE_RATE};
}

sub getSampleStartTime
{
	return $_[0]->{SAMPLE_START_TIME};
}

sub getThroughputSamples
{
	return $_[0]->{THROUGHPUT_SAMPLES};
}

sub getTotalJobsProcessed
{
	return $_[0]->{TOTAL_JOBS_PROCESSED};
}

sub getCrawlGraph
{
	return $_[0]->{CRAWL_GRAPH};
}

sub getNumberOfSamples
{
	return scalar(@{$_[0]->{THROUGHPUT_SAMPLES}});
}


1;