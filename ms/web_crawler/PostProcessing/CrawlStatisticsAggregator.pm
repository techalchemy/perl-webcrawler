## @file
# Implementation of CrawlStatisticsAggregator
#
# @copy 2011, Michael Sobczak
# $Id: CrawlStatisticsAggregator.pm 2011/03/18

## @class
# A class that will be used to aggregate statistics on the web crawl during runtime
# @par Fields
#	- TOTAL_JOBS_PROCESSED this keeps track of the total number of jobs processed so far
# 	- JOBS_PROCESSED_ACCUMULATOR this keeps track of the jobs processed since the last throughput sample was taken
#	- LAST_SAMPLE_TIME this keeps track of the last time the class took a sample
#	- SAMPLE_RATE this keeps track of the time in seconds between samples
#	- CRAWL_GRAPH this is a reference to a hash with the following format @em domain => outgoing links hash reference
#	- THROUGHPUT_SAMPLES this is a reference to the array containing all the throughput samples
#	- SAMPLE_START_TIME this holds the time when the very first sample started
package CrawlStatisticsAggregator;

use Time::HiRes qw(time);

use constant DEFAULT_SAMPLE_RATE => 60;


## @cmethod CrawlStatisticsAggregator new()
# the constructor for the class
# @return a shiny new CrawlStatisticsAggregator
sub new
{
	my $self = {};
	$self->{TOTAL_JOBS_PROCESSED} = 0;
	$self->{JOBS_PROCESSED_ACCUMULATOR} = 0;
	$self->{LAST_SAMPLE_TIME} = 0;
	$self->{SAMPLE_RATE} = DEFAULT_SAMPLE_RATE;
	$self->{CRAWL_GRAPH} = {};
	$self->{THROUGHPUT_SAMPLES} = [];
	$self->{SAMPLE_START_TIME} = 0;
	$self->{AVERAGE_BRANCHING_FACTOR} = 0;
	$self->{TOTAL_JOBS_DISCOVERED} = 0;
	bless $self, 'CrawlStatisticsAggregator';
	return $self;
}


## @cmethod void setSampleRate($secondsBetweenSamples)
# method used to set the sample rate
# @param secondsBetweenSamples
sub setSampleRate
{
	$_[0]->{SAMPLE_RATE} = $_[1];
}

## @cmethod void update($url, $links)
# this is the public method of the object that will be called by the crawler to update the statistics each time a job is processed
# @param url the url of the page being processed
# @param links a reference to an array containing the links the page denoted by @em url contains
sub update
{
	my ($self, $url, $links) = @_;
	# add the current page and its links to the crawl graph
	#_addPageToGraph($self, $url, @{$links});
	_updateThroughput($self);
	_updateBranchingFactor($self, scalar(@$links));
}

## @cmethod void finish()
# called when the thread is being finished. The purpose of this function is to ensure that
# statistics that are in the process of being calculated aren't dropped when the thread
# is finished running
sub finish
{
	my $self = $_[0];
	push(@{$self->{THROUGHPUT_SAMPLES}}, $self->{JOBS_PROCESSED_ACCUMULATOR});
	$self->{JOBS_PROCESSED_ACCUMULATOR} = 0;
}

## @cmethod void _updateThroughput()
# This is a private method of the class. is called by the update() method to handle the throughput sampling
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
		$self->{LAST_SAMPLE_TIME} = $currentTime;
		$self->{SAMPLE_START_TIME} = $currentTime;
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
			push (@{$self->{THROUGHPUT_SAMPLES}}, 0);
			$leftToPush--;
		}
		$self->{LAST_SAMPLE_TIME} = $currentTime;
	}
}

## @cmethod void _updateBranchingFactor($self, $numberOfLinksFound)
# this function is in charge of maintaining an average branching factor of the pages encountered so far in the crawl
# @param numberOfLinksFound the number of links found in the page currently being processed
sub _updateBranchingFactor
{
	my ($self, $numberOfLinksFound) = @_;
	#update the total discovered jobs
	my $pagesProcessed = $self->{TOTAL_JOBS_PROCESSED};
	$self->{TOTAL_JOBS_DISCOVERED} += $numberOfLinksFound;
	my $newDiscoveredTotal = $self->{TOTAL_JOBS_DISCOVERED};
	my $newAverageBranchingFactor = $newDiscoveredTotal / $pagesProcessed;
}

## @cmethod void _addPageToGraph($url, @links)
# adds the current page to the crawl graph after stripping its domain
# @param url this is the url of the current page
# @param links this is an array of pages the url page links to
sub _addPageToGraph
{
	my ($self, $url, @links) = @_;
	my $domainName = extractDomainName($url);
	#Util::debugPrint('domain name extracted: ' . $domainName);
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

#returns the time in seconds
sub _getTime
{
	return time();
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

sub getTotalJobsDiscovered
{
	return $_[0]->{TOTAL_JOBS_DISCOVERED};
}


1;