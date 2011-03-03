require 'Util.pm';
use Util;

main();

sub main
{
	my %config = %{Util::loadConfigFile("testConfigFile.cfg")};
	while (my ($key, $value) = each %config)
	{
		print "key: " . $key . "\tvalue: " . $config{$key} . "\n";
	}
}