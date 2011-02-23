use strict;
use SiteParser;

main();

sub main()
{
	open (HTML_FILE, "<", "test.html");
	my $contents = join('', <HTML_FILE>);
	close (HTML_FILE);
	
	print "about to parse html file...\n";
	my $parsedPage = SiteParser::parseData($contents);
	print "done parsing html file...\n";
	print "printing links found: \n";
	foreach(@{$parsedPage->links})
	{
		print "\t" . $_ . "\n";
	}
	
	print "printing metadata found: \n";
	my ($key, $value);
	my %metaHash = $parsedPage->metaData;
	foreach (($key, $value) = each %metaHash)
	{
		my @currentAttributePairList = @{$metaHash{$key}};
		print "current attribute: " . $key . "\n";
		foreach (@currentAttributePairList)
		{
			print "\t" . @_->attributeValue . " => " . @_->contents . "\n";
		}
	}
}