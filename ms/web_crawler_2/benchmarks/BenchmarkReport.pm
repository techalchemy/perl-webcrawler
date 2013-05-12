
package BenchmarkReport;
	
	sub new
	{
		my $class = shift;
		my $self = {};
		$self->{INFO_KEYS} = [];
		$self->{INFO_VALUES} = [];
		$self->{DATA_SERIES} = [];
		$self->{SERIES_NAMES} = [];
		$self->{NUM_SERIES} = 0;
		$self->{NUM_INFO} = 0;
				
		bless $self, $class;
		return $self;
	}
	
	sub addInfo
	{
		my ($self, $key, $value) = @_;
		my $numInfo = $self->{NUM_INFO};
		$self->{INFO_KEYS}->[$numInfo] = $key;
		$self->{INFO_VALUES}->[$numInfo] = $value;
		$self->{NUM_INFO}++;
	}
	
	sub addData
	{
		my ($self, $seriesRef, $seriesName) = @_;
		my $newSeriesIndex = $self->{NUM_SERIES};
		$self->{DATA_SERIES}->[$newSeriesIndex] = $seriesRef;
		$self->{SERIES_NAMES}->[$newSeriesIndex] = $seriesName;
		$self->{NUM_SERIES}++;
	}
	
	sub compile
	{
		my $self = shift;
		
		my $compiledReport = "";
		
		# first add the key/value pairs
		my $keyList = $self->{INFO_KEYS};
		my $valueList = $self->{INFO_VALUES};
		my $numInfo = $self->{NUM_INFO};
		
		for my $index (0..($numInfo - 1))
		{
			$compiledReport .= $keyList->[$index] . '=' . $valueList->[$index] . "\n";
		}
		
		# now add the cvs series
		my $series = $self->{DATA_SERIES};
		my $names = $self->{SERIES_NAMES};
		my $numSeries = scalar(@$series);
		
		for my $index (0..($numSeries - 1))
		{
			$compiledReport .= 'series' . $index . '_name=' . $names->[$index] . "\n";
			$compiledReport .= 'series' . $index . '_data=' . join(",", @{$series->[$index]}) . "\n";
		}
		
		return $compiledReport;
	}
	
1;