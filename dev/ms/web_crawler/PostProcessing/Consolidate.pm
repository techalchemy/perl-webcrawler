package Consolidate;

use CrawlStatisticsAggregator;

sub consolidateStatistics
{
	my @aggregators = @_;
	_consolidateThroughputSamples(@aggregators);
	_consolidateGraphs(@aggregators);
	
}

sub _consolidateThroughputSamples
{
	my @aggregators = @_;
	# find the earliest sample time and the last sample time
	my ($earliestSampleTime, $latestSampleTime) = (0, 0);
	foreach(@aggregators)
	{
		my ($currentStartingSampleTime, $currentLastSampleTime);
		my $currentAggregator = $_;
		my $currentSampleRate = $currentAggregator->getSampleRate();
		my $currentNumSamples = $currentAggregator->getNumberOfSamples();
		$currentStartingSampleTime = $currentAggregator->getSampleStartTime();
		$currentLastSampleTime = $currentStartingSampleTime + ($currentNumSamples * $currentSampleRate);
		if ($currentStartingSampleTime < $earliestSampleTime)
		{
			$earliestSampleTime = $currentStartingSampleTime;
		}
		if ($currentLastSampleTime > $latestSampleTime)
		{
			$latestSampleTime = $currentLastSampleTime;
		}
	}
	
	# create the array that will hold the consolidated throughput samples
	my @consolidatedArray;
	
	# loop through each aggregator and place all of its samples into
	# the right "bucket" (index) in the consolidated sample array
	 
}

sub _calculateStartIndexForSampleList
{
	my ($startTime, $sampleRate) = @_;
	my $index = int($startTime/$sampleRate);
}

sub _consolidateGraphs
{
	my @aggregators = @_;
}

1;