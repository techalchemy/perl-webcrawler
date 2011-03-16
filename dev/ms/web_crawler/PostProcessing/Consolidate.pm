package Consolidate;



use CrawlStatisticsAggregator;

sub consolidateStatistics
{
	# get the aggregator objects passed to function
	my $self = shift;
	my @aggregators = @_;
	my $consolidatedThroughputSamples = _consolidateThroughputSamples(@aggregators);
	my $consolidatedGraph = _consolidateGraphs(@aggregators);
}

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

sub _calculateStartIndexForSampleList
{
	my ($startTime, $sampleRate) = @_;
	my $index = int($startTime/$sampleRate);
}

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