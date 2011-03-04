package Util;

######################################################################################
# DEBUGGING static variables	
######################################################################################
my $globalDebugFlag = 0;
my $globalDebugFile = 0;

######################################################################################
#	This function is used to verify that the links are correctly formed, possibly
#   fixing them if not, and then builds page records for each of them
#		Parameters
#			configFilePath - path to configuration file containing
#			configuration parameters in the following format:
#				parameter1Name=parameter1Value;
#				parameter2Name=parameter2Value;
#		Return
#			configHash - REFERENCE to the configuration hashtable
#
######################################################################################
sub loadConfigFile
{
	my $configFilePath = $_[0];
	print "Config Path from UTIL: " . $configFilePath . "\n";
	#create the configuration file hash
	my %configHash;
	#open the file for reads
	open (OUTPUT_FILE, "<", $configFilePath);
	while (<OUTPUT_FILE>)
	{
		chomp();
		debugPrint("raw line: " . $_);
		my ($key, $value) = split(/=/);
#		print "found key: " . $key . "\n";
#		print "found value: " . $value . "\n";
		$value =~ s/;//g;
#		print "Util modified value: " . $value . "\n";
		$configHash{$key} = $value;
	}
	close(OUTPUT_FILE);
	return %configHash;
}


sub debugPrint
{
	my @data = @_;
	if (!$globalDebugFlag) { return; }
	my $debugFile = $globalDebugFile;
	my $callingModule = caller();
	$callingModule . ": " . $data;
	open (OUTPUT_FILE, ">>", $debugFile);
	print OUTPUT_FILE $callingModule . ': ';
	foreach (@data)
	{
		my $formattedData = formatData($_);
		print OUTPUT_FILE $formattedData;
	}
	print OUTPUT_FILE "\n";
	
	close OUTPUT_FILE;
}

sub formatData
{
	my $data = $_[0];
	my $dataRef = \$data;
	my $returnData = "";
	$_ = $dataRef;
	if (/HASH/)
	{
		my %outputHash = %{$dataRef};
		$returnData = ' { ';
		while (my ($key, $value) = each %outputHash)
		{
			$returnData .= $key . ' => ' . $outputHash{$key} . ', ';
		}
		$returnData = ' } ';
	}
	elsif(/ARRAY/)
	{
		my @outputArray = @{$dataRef};
		$returnData .= ' [ ';
		foreach (@outputArray)
		{
			$returnData .= $_ . ',';
		}
		$returnData .= ' ] ';
	}
	elsif(/SCALAR/)
	{
		$returnData .= ${$dataRef};
	}
	else
	{
		$returnData .= ${$dataRef};
	}
	return $returnData;
}

sub setGlobalDebug
{
	$globalDebugFlag = $_[0];
}

sub setGlobalDebugFile
{
	$globalDebugFile = $_[0];
}

sub getConfig
{
	my $callerPrefix = caller() . "_";
	$callerPrefix = lc($callerPrefix);
	debugPrint(" Called by " . $callerPrefix ."\n");
	my %returnHash;
	# change %config back to %options for later use
	foreach $optionName (keys %config) {
		$optionName = lc($optionName);
		debugPrint("Found option: " . $optionName . "\n"); 
		if ($optionName =~ m/^($callerPrefix)/)
		{
			$returnHash{$'} =~ $options{$optionName};
		}
	}
	return %returnHash;
}

1;