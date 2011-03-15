package GraphDraw;

use CrawlStatisticsAggregator;

sub drawGraph
{
	renderGraph(consolidateGraphs(@_));
}

sub consolidateGraphs
{
	my @graphTables = @_;
	my @adjacencyMatrix;
	foreach(@graphTables)
	{
		while (my ($key, $value) = each %{$_})
		{
			
		}
	}
}

sub renderGraph
{
	
}

sub processAndGraphThroughput
{
	my @throughputSamples = @_;
	my @alignedConsolidatedSamples = consolidateAndAlign(@throughputSamples);
	
	
}

sub consolidateAndAlign
{
	my @combinedArray;
	my @startTimes;
	foreach(@_)
	{
		push(@startTimes, @{$_}[0]);
	}
	
	
}

1;