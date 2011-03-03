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
	#create the configuration file hash
	my %configHash;
	#open the file for reads
	open (OUTPUT_FILE, "<", $configFilePath);
	while (<OUTPUT_FILE>)
	{
		chomp();
		my ($key, $value) = split(/=/);
		$value =~ s/;//g;
		$configHash{$key} = $value;
	}
	close(OUTPUT_FILE);
	return %configHash;
}


sub debugPrint
{
	my ($data, $filename) = @_;
	my $debugFile = $globalDebugFile;
	my $isPrinting = $globalDebugFlag;
	if ($filename != undef)
	{
		$debugFile = $filename;
		$isPrinting = 1;
	}
	if ($isPrinting)
	{
		open (OUTPUT_FILE, ">>", $debugFile);
		my $formattedData = formatData($data);
		print OUTPUT_FILE $formattedData . "\n";
	}
	#do data formatting depending on type
	
	
	
}

sub formatData
{
	my $data = $_[0];
	return $data;
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
	my %returnHash;
	foreach $optionName (keys %options) {
		$optionName = lc($optionName);
		if ($optionName =~ m/^($callerPrefix)/)
		{
			$returnHash{$optionName} = $options{$optionName};
		}
	}
	return %returnHash;
}

1;