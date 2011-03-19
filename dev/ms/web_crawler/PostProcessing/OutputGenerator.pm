## @file OutputGenerator.pm
# this file contains the implementation of functions to generate the output of the web crawler

## @class OutputGenerator
# this class is a collection of static methods to output the crawl statistics into output files
package OutputGenerator;

use Consolidate;

## @fn public static void generateOutput($outputDirectory, $aggregators)
# this is a public function intended to be called externally to create the statistics output files
# @param outputDirectory the main output directory. A specific directory for this run will be
# 		 created inside this directory to avoid conflicts
# @param aggregators a reference to the array of statistics aggregators
sub generateOutput
{
	my ($outputDirectory, $aggregators) = @_;
	my $consolidatedStatistics = Consolidate::consolidateStatistics(@{$aggregators});
	
	# create the output directory for this specific run
	my $specificOutputDirectoryPath = $outputDirectory . "/" . localtime();
	# if the directory doesn't exist, create it
	if (-e $specificOutputDirectoryPath)
	{
		mkdir($specificOutputDirectoryPath);
	}
	my $throughputSeries = $consolidatedStatistics->THROUGHPUT;
	my $throughputSampleRate = $consolidatedStatistics->SAMPLE_RATE;
	_handleThroughputOutput($specificOutputDirectoryPath . '/throughput.csv', $throughputSeries, $throughputSampleRate);
}

sub _handleThroughputOutput
{
	my ($outputFilePath, $throughputSeries, $sampleRate) = @_;
	_dumpArrayToCSVFile($outputFilePath, $sampleRate, 'Time (ms)', 'Throughput (jobs)', $throughputSeries);
}

sub _dumpArrayToCSVFile
{
	my ($outputFilePath, $xDelta, $xAxisLabel, $yAxisLabel, $dataSeries) = @_;
	my @data = @{$dataSeries};
	my $xAxisCounter = 0;
	open(OUTPUT_FILE, ">", $outputFilePath);
	print OUTPUT_FILE $xAxisLabel . ", " . $yAxisLabel . "\n";
	foreach(@data)
	{
		print OUTPUT_FILE $xAxisCounter . ", " . $_ . "\n";
		$xAxisCounter += $xDelta;
	}
	close OUTPUT_FILE;
}

1;