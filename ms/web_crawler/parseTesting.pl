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
	print "printing keywords found: \n";
	foreach(@{$parsedPage->keywords})
	{
		print "\t" . $_ . "\n";
	}
	print "printing body text\n";
	printDebugLine("body", $parsedPage->bodyText);
	
	print "printing metadata found: \n";
	printDebugLine("charset", $parsedPage->charset);
	printDebugLine("description", $parsedPage->description);
	printDebugLine("title", $parsedPage->title);
	printDebugLine("author", $parsedPage->author);
	
}

sub printDebugLine
{
	my ($header, $data) = @_;
	print $header . ": " . $data . "\n";
}