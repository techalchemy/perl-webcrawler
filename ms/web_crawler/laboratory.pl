require 'SiteParser.pm';
use SiteParser;

main();

sub main
{
	open (HTML_FILE, "<", "test.html");
	my $contents = join('', <HTML_FILE>);
	close (HTML_FILE);
	my $structReference = SiteParser::parseData($contents);
	print "Printing something: " . $structReference . "\n";
	my %convertedHash = %{$structReference};
	while (my ($key, $value) = each %convertedHash)
	{
		print "key: " . $key . "\tvalue: " . $convertedHash{$key} . "\n";
	}
}