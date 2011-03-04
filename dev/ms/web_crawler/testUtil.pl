require 'Util.pm';
require 'PostData.pm';
use PostData;
use Util;

main();

sub main
{
	my $configPath = "testConfigFile.cfg";
	print "Config Filepath: " . $configPath . "\n";
	my %config = %{Util::loadConfigFile($configPath)};
	print "Config Hash: " . %config . "\n";
	while (my ($key, $value) = each %config)
	{
		print "key: " . $key . "\tvalue: " . $config{$key} . "\n";
	}
	my %configdata = %{PostData::getCfgInfo()};
	while (my ($key2, $value2) = each %configdata) 
	{
		print "cfgkey: " . $key2 . "\tcfgvalue: " . $configdata{$key} . "\n";
	}
}
