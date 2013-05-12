use LWP::UserAgent;
use LWP::Curl;
use Time::HiRes qw(usleep ualarm gettimeofday tv_interval);
use threads;

use Sys::Info;
use Sys::Info::Constants qw(:device_cpu);
use Sys::MemInfo qw(totalmem);

use BenchmarkReport;

use constant
{
	NUM_THREADS => 0,
	PPS_PER_NUM_THREADS => 1,
	AVERAGE_PAGE_SIZE => 2
};


print "starting pageDownloadTest.pl\n";
main();
print "finished running pageDownloadTest.pl\n";

my $config = {};

sub main
{
	my $configFilePath = $ARGV[0];
	
	$config = loadConfigFile($configFilePath);
	
	print "printing config:\n";
	while ( my ($key, $value) = each %$config)
	{
		print "\tkey: " . $key . "\tvalue: " . $config->{$key} . "\n";
	}
	
	my $bigListOfLinks = loadLinksFromFile($config->{linkListFilename}, 
										   $config->{pagesPerTest});
	
	
	
	
	my $benchmarkReport = {};
	
	# benchmark LWP::Simple (baseline)
	my $simpleUserAgent = LWP::UserAgent->new( timeout => $config->{requestTimeout} );
	$benchmarkReport->{'LWP::Simple'} = benchmarkFunction(\&get_LWP_Simple,
														  $simpleUserAgent, 
														  $bigListOfLinks);
	
	# benchmark LWP::Curl
	
	$benchmarkReport->{'LWP::Curl'} = benchmarkFunction(\&get_LWP_Curl,
														$curlInstance, 
														$bigListOfLinks);
	
	# compile a benchmarking report
	
	my $compiledReportText = compileReport($benchmarkReport);
	
	# save this text to a file
	
	open (OUTPUT_FILE, ">", $config->{reportFilename});
	
	print OUTPUT_FILE $compiledReportText;
	
	close OUTPUT_FILE;
}


# This function is supposed to test a single page getting algorithm
#	For all the specified thread pool sizes
#	append the results to the report
sub benchmarkFunction
{
	my ($functionToUse, $functionUserAgent, $linkListRef) = @_;
	
	# get the different thread numbers to benchmark for
	my @threadPoolSizes = (1, 2, 4, 8, 16); 

	# cast passed in list ref into an array
	my @pageList = @$linkListRef;
	my $listSize = scalar(@pageList);
	
	# create the variables to return average page size and PPS values
	my @pageSizeAverages;
	my @ppsValues;
	
	foreach (@threadPoolSizes)
	{
		my $currentNumberOfThreads = int($_);
		print "RUNNING WITH: " . $currentNumberOfThreads . "\n";
		my @workerResults;
		my $workerThreads = [];
		my $rotationSize = $listSize / $currentNumberOfThreads;
		
		# create and start all the threads
		for my $index (0..($currentNumberOfThreads - 1))
		{
			my @listToPass = @pageList;
			if ($index > 0)
			{
				# make a rotated copy of the list to pass to the thread (so index 0 is start)
				my $newFrontIndex = $rotationSize * $index;
				@listToPass = (@pageList[$newFrontIndex..$#pageList], @pageList[0..($newFrontIndex - 1)]);
			}
			# create the thread
			$workerThreads->[$index] = threads->create(\&workerFunction, $functionToUse, 
																		 \@listToPass, 
																		 $functionUserAgent);
		}
		
		# get the results
		@workerResults = map { $_->join(); } @$workerThreads;
		
		my $totalTime = 0;
		my $averagePageSizeSum = 0;
		
		foreach(@workerResults)
		{
			my $currentResults = $_;
			$totalTime += $currentResults->[0];
			$averagePageSizeSum += $currentResults->[1];
		}
		
		my $configurationAveragePageSize = ($averagePageSizeSum) / $currentNumberOfThreads;
		$totalAveragePageSize += $configurationAveragePageSize;
		my $configurationPPS = ($currentNumberOfThreads * $listSize) / ($totalTime / $currentNumberOfThreads);
		push (@ppsValues, $configurationPPS);
	}
	
	$totalAveragePageSize /= scalar(@threadPoolSizes);
	
	return [\@threadPoolSizes, \@ppsValues, $totalAverageSize];
}

sub workerFunction
{
	my ($f, $q, $cfg) = @_;
	my $jobsProcessed = 0;
	my $functionExecutionTime = 0;
	my $averageSizePerPage = 0;
	
	my @jobs = @$q;
	
	while (@jobs)
	{
		my $currentJob = shift @jobs;
		# update the average page size
		{
			use bytes;
			my $currentPageSize = length($currentJob);
			my $averageSizePerPage = (($averageSizePerPage * $jobsProcessed) + $currentPageSize) / ($jobsProcessed + 1);
		}
		my $startTime = [gettimeofday];
		
		$f->($currentJob, $cfg);
		
		my $timeDifference = tv_interval ($startTime, [gettimeofday]);
		
		$functionExecutionTime += $timeDifference;
		
		$jobsProcessed++;
	}
	
	return [$functionExecutionTime, $averageSizePerPage];
}

sub loadLinksFromFile
{
	my ($linkListFilename, $maxLinksToRead) = @_;
	
	open (LINK_FILE, "<", $linkListFilename);
	
	my $numLinksRead = 0;
	my @linkList = ();
		
	while (<LINK_FILE>)
	{
		chomp();
		push (@linkList, $_);
		$numLinksRead++;
		if ($numLinksRead >= $maxLinksToRead)
		{
			last;
		}
	}
	
	close LINK_FILE;
	
	return \@linkList;
}

sub loadConfigFile
{
	my $filename = shift;
	my $loadedConfig = {};
	open (CONFIG_FILE, "<", $filename);
	while (<CONFIG_FILE>)
	{
		if (substr($_, 0, 1) eq ';')
		{
			next;
		}
		chomp();
		my ($key, $value) = split('=');
		my $commaInValue = (-1 != index($value, ','));
		if ($commaInValue)
		{
			$loadedConfig->{$key} = split(',', $value);
		}
		else
		{
			$loadedConfig->{$key} = $value;
		}
	}
	close CONFIG_FILE;
	return $loadedConfig;
}

sub printReportToFile
{
	my ($reportHash, $outputFilename) = @_;
}

sub get_LWP_Simple
{
	my ($page, $ua) = @_;
	return $ua->get($page);
}

sub get_LWP_Curl
{
	my ($page, undef) = @_;
	my $curl = LWP::Curl->new( timeout => $config->{requestTimeout} );
	return $curl->get($page);
}

sub compileReport
{
	my $benchmarkResults = shift;
	
	my %resultsTable = %{$benchmarkResults};
	
	# get the average page size
	my $averagePageSize = 0;
	while (my ($key, $value) = each %resultsTable)
	{
		$averagePageSize += $resultsTable{$key}->[AVERAGE_PAGE_SIZE];
	}
	$averagePageSize /= scalar(keys %resultsTable);
	
	# need to grab a bunch of info about system
	
	my $report = BenchmarkReport->new();
	
	# grab some OS data
	
	my $info = Sys::Info->new();
	my $cpu = $info->device(CPU => %options);
	my $os = $info->os();
	my $totalMemory = (&totalmem / 1024);
	
	$report->addInfo('date', getCurrentTimeString());
	$report->addInfo('OS_name', $os->name());
	$report->addInfo('OS_version', $os->version());
	$report->addInfo('CPU_name', scalar($cpu->identify()));
	$report->addInfo('CPU_speed', $cpu->speed());
	$report->addInfo('CPU_cores', $cpu->count());
	$report->addInfo('CPU_bitness', $cpu->bitness());
	$report->addInfo('CPU_hyperthreading', $cpu->ht());
	$report->addInfo('MEM_total', $totalMemory);
	$report->addInfo('BM_averagePageSize', $averagePageSize / 1024);
	
	
	
	# add the series
	
	while (my ($key, $value) = each %resultsTable)
	{
		my $currentSeriesName = $key;
		
		my $currentValueList = $resultsTable{$key};
		
		# want these arrays to be sorted, doing insertion sort below
		my $threadNumSeries = $currentValueList->[NUM_THREADS];
		my $ppsSeries = $currentValueList->[PPS_PER_NUM_THREADS];
		
		
		# add the series to the report
		$report->addData($threadNumSeries, $currentSeriesName . "{threads}");
		$report->addData($ppsSeries, $currentSeriesName . "{pps}");
	}
	
	return $report->compile();
	
}

## @fn static string getCurrentTimeString()
# This function returns the current date and time in a nice looking human readable format
# @return string of the current time
sub getCurrentTimeString
{
	my @tempTime = localtime(time);
	my $seconds = @tempTime[0];
	my $minutes = @tempTime[1];
	my $hours = @tempTime[2];
	my $day = @tempTime[3];
	my $month = @tempTime[4];
	my $year = int(@tempTime[5]) + 1900;
	_addZeroIfLessThanTen($hours, $minutes, $seconds);
	return $day . "/" . $month . "/" . $year . " " . $hours . ":" . $minutes . ":" . $seconds;
}

## @fn private static void _addZeroIfLessThanTen(@strings)
# This function takes a list of strings and prefixes a zero to all the
# strings that are less than 10
sub _addZeroIfLessThanTen
{
	foreach(@_)
	{
		if ($_ < 10)
		{
			$_ = '0' . $_;
		}
	}
}









