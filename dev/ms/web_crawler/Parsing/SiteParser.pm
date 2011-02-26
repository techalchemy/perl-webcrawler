######################################################################################
#								SiteParser.pm		
#	Author: Michael Sobczak
#	Date: 2/20/2011								 
######################################################################################
# The purpose of this module is to abstract away the parsing of the html data
# from the siteCrawler.pl script. The SiteParser.pm module will provide functions
# to the siteCrawler script (and any other scripts that want it) that supply it
# with the data it needs. Currently this is the links in the document, the
# meta data of the site, and the text found in the body. The data is supplied to
# code that uses it through the use of the PARSED_PAGE struct. If in further
# revisions this code is modified to provide even more information about a page,
# fields should be added to this struct. Scripts that use that struct will
# not be affected by the addition of further fields, but existing fields must
# be kept the same.
#
#	TODO Finish the body of the if (metatag) clause
#	TODO makesure the plaintext handler is implemented and check for
#		 things like inside script
#																				 
######################################################################################

package SiteParser;

use strict;
use HTML::Parser;
use Class::Struct;

# this struct holds the information that is the result of parsing the html file
# Each attribute is described below
#	links - this is an array of string urls
#	metaData - this is a table which has an attribute as a key and an array
#	of attribute_value - contents pairs.
#	bodyText - this is a string holding the body text of the page
struct(PARSED_PAGE => {
	links => '@',
	charset => '$',
	keywords => '@',
	description => '$',
	bodyText => '$',
});

#private variables used by the functions in this file
my @workingLinkList;
my $workingBodyText;
my $workingCharset;
my @workingKeywordList;
my $workingDescription;

#used to cleverly keep track of what tags are currently open
#	EXAMPLE: you want to know if you're inside a script tag
#   my $insideScriptTag = $inside{"script"};
my %inside = {};

#constants used by the functions in this file
my @tagList = ['a', 'meta', 'p'];

sub parseData
{
	#get the site contents
	my $siteContents = $_[0];
	print $siteContents;
	#clear the temporary variables used by this code
	@workingLinkList = ();
	$workingBodyText = "";
	@workingKeywordList = ();
	$workingDescription = "";
	$workingCharset = "";
	#initialize parsed contents struct
	my $parsedContents = new PARSED_PAGE;
	#set up the HTML Parser with proper event handling subroutines
	my $parser = HTML::Parser->new(start_h => [\&tagHandler, "tagname, attr"],
								   text_h => [\&textHandler, "text"],
								   end_h => [\&endHandler, "tagname"]);
	$parser->report_tags(@tagList);
	#call the parse function
	$parser->parse($siteContents);
	
	#populate the struct
	$parsedContents->links(@workingLinkList);
	$parsedContents->bodyText($workingBodyText);
	$parsedContents->charset($workingCharset);
	$parsedContents->description($workingDescription);
	$parsedContents->keywords(@workingKeywordList);
	
	#return the struct
	return $parsedContents;
}

sub tagHandler
{
	my ($tagname, $attr) = @_;
	print "getting called with: " . $tagname . " " . $attr . "\n";
	#add the addition to the inside hash table
	$inside{$tagname}++;
	
	if ($tagname eq 'a')
	{
		push (@workingLinkList, $attr->{'href'});
	}
	elsif($tagname eq 'meta')
	{
		if (defined $attr->{'name'})
		{
			
		}
		elsif (defined $attr->)
		
	}
}

sub textHandler
{
	my $text = @_;
	$workingBodyText .= $text;
}

sub endHandler
{
	my $tagname = @_;
	$inside{$tagname}--;
}
1;