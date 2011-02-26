package Util;


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
	return \%configHash;
}

1;