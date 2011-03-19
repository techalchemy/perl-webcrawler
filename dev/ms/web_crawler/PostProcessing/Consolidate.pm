## @file Consolidate.pm
# this module is intended to be used after a run of the crawler is finished and the
# individual statistics aggregator objects from each thread need to be combined into
# a final combined data set

## @class Consolidate
# this class only consists of static methods, there is no need for it to be instantiated
package Consolidate;
use Class::Struct;
use CrawlStatisticsAggregator;

## @class CONSOLIDATED_STATISTICS
# this struct is used as a container for the consolidated statistic outputs
struct(CONSOLIDATED_STATISTICS => {
	THROUGHPUT => '*@',
	SAMPLE_RATE => '$',
	CRAWL_GRAPH => '*%',
});

## @fn public static CONSOLIDATED_STATISTICS consolidateStatistics(@aggregators)
# this function takes a list of aggregators and combines them into a single data set
# @param @aggregators a list of CrawlStatisticsAggregator objects to consolidate
# @return a CONSOLIDATED_STATISTICS struct populated with the combined outputs
sub consolidateStatistics
{
	# get the aggregator objects passed to function
	my @aggregators = @_;
	# get the combined throughput samples
	my $consolidatedThroughputSamples = _consolidateThroughputSamples(@aggregators);
	# get the combined graph
	my $consolidatedGraph = _consolidateGraphs(@aggregators);
	# populate the struct to be returned
	my $consolidatedStatistics = CONSOLIDATED_STATISTICS->new(
									THROUGHPUT => $consolidatedThroughputSamples,
									SAMPLE_RATE => $aggregators[0]->getSampleRate(),
									CRAWL_GRAPH => $consolidatedGraph);
	return $consolidatedStatistics;
}


## @fn private static *int _consolidateThroughputSamples(@aggregators)
# this function combines the throughput samples into a single array
# @param @aggregators the disparate aggregators used by worker threads
# @return an array of throughput samples over time
sub _consolidateThroughputSamples
{
	my @aggregators = @_;
	# find the earliest sample time and the last sample time
	# 	do this by looping through each aggregator and finding end/start times
	#	pick the earliest and latest obviously
	my ($earliestSampleTime, $latestSampleTime) = (0, 0);
	foreach(@aggregators)
	{
		# declare local variables to be used
		my ($currentStartingSampleTime, $currentLastSampleTime);
		my $currentAggregator = $_;
		my $currentSampleRate = $currentAggregator->getSampleRate();
		my $currentNumSamples = $currentAggregator->getNumberOfSamples();
		#calculate starting and ending time of this aggregator's samples
		$currentStartingSampleTime = $currentAggregator->getSampleStartTime();
		$currentLastSampleTime = $currentStartingSampleTime + ($currentNumSamples * $currentSampleRate);
		#check to see if we have new earliest starting time
		if ($currentStartingSampleTime < $earliestSampleTime)
		{
			# update earliest sample time
			$earliestSampleTime = $currentStartingSampleTime;
		}
		#check to see if we have new latest ending time
		if ($currentLastSampleTime > $latestSampleTime)
		{
			# update latest sample time
			$latestSampleTime = $currentLastSampleTime;
		}
	}
	
	# create the array that will hold the consolidated throughput samples
	my @consolidatedArray;
	
	# loop through each aggregator and place all of its samples into
	# the right "bucket" (index) in the consolidated sample array
	foreach(@aggregators)
	{
		my $currentAggregator = $_;
		my @currentSampleArray = @{$_->getThroughputSamples()};
		my $startingSampleIndex = _calculateStartIndexForSampleList(
										$_->getSampleStartTime(), 
										$_->getSampleRate());
		my $numSamples = scalar(@currentSampleArray);
		for (my $currentSampleNumber = 0; $currentSampleNumber < $numSamples; $currentSampleNumber++)
		{
			$consolidatedArray[$startingSampleIndex + $currentSampleNumber] += $currentSampleArray[$currentSampleNumber];
		}
	}
	#return a reference to the consolidated sample array
	return \@consolidatedArray;
}

## @fn private static int _calculateStartIndexForSampleList($startTime, $sampleRate)
# this function uses the starting time and the sample rate of a given throughput sample array
# and uses it to compute the index in the combined array this particular sample array should
# start placing its values
# @param startTime starting time of the sampling
# @param sampleRate time in milliseconds between samples
# @return index the array index to start dumping samples in
sub _calculateStartIndexForSampleList
{
	my ($startTime, $sampleRate) = @_;
	my $index = int($startTime/$sampleRate);
}

## @fn private static {} _consolidateGraphs(@aggregators)
# this function consolidates the graphs into a single whole
# @param aggregators the list of aggregators whose graphs should be combined
# @return a reference to the combined graph
sub _consolidateGraphs
{
	# get aggregators passed to function
	my @aggregators = @_;
	# declare the graph that will eventually be returned
	my $consolidatedGraph = {};
	foreach(@aggregators)
	{
		# get current aggregator and crawl graph
		my $currentAggregator = $_;
		my $currentCrawlGraph = $currentAggregator->getCrawlGraph();
		# loop through each key in the current crawl graph
		# this means loop through domain encountered by the current crawl graph
		while (my ($key, $value) = each %{$currentCrawlGraph})
		{
			# get a hash of the outgoing links from the current domain
			my $currentDomainOutgoingLinks = $currentCrawlGraph->{$key};
			# for each of these outgoing links, add them to the consolidated graph
			while (my ($outgoingLinkKey, $outgoingLinkValue) = each %{$currentDomainOutgoingLinks})
			{
				# first get the consolidated graph's hash of outgoing links using the current key
				# then in that hash, use the current outgoing link key to point to the frequency
				# add the current frequency to the existing frequency
				$consolidatedGraph->{$key}->{$outgoingLinkKey} += $currentDomainOutgoingLinks{$outgoingLinkKey};
			}
			
		}
	}
	
	return $consolidatedGraph;
}

1;