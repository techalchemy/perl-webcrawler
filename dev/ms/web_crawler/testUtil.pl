require 'Util.pm';
require 'PostData.pm';
use PostData;
use Util;

main();

sub main
{
	my %config = %{Util::loadConfigFile("testConfigFile.cfg")};
	while (my ($key, $value) = each %config)
	{
		print "key: " . $key . "\tvalue: " . $config{$key} . "\n";
	}
	PostData::getCfgInfo();
}
