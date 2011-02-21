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
	metaData => '%',
	bodyText => '$',
});

# this struct is used by metaData table. The reason this additional struct is
# used as the value is due to the peculiar nature of HTML metaData and how it 
# can be made easily accessible.
# the current setup of the metaData table is the following
#	NOTE: key => value indicates a key value pair and perl datatype notation
#   is used to imply types
#
#	%metaData = $attribute_name => @metaDataPairs
#   @metaDataPairs = [ metaDataPair1, metaDataPair2, metaDataPair3, etc.]
#
# this setup allows for easy access to wanted metadata. To demonstrate, below
# is sample perl code for making an array out of the keywords on a webpage
#
# my @namePairs = $metaDataTable{"name"};
# foreach(@namePairs) {
#	if ($_->attributeValue eq "keywords") {
#   	return split(",", $_->content);
#   }	
# }
struct(META_DATA_PAIR => {
	attributeValue => '$',
	content => '$',
});

#private variables used by the functions in this file
my @workingLinkList;
my %workingMetaTable;
my $workingBodyText;

#used to cleverly keep track of what tags are currently open
#	EXAMPLE: you want to know if you're inside a script tag
#   my $insideScriptTag = $inside{"script"};
my %inside = {};

#constants used by the functions in this file
my @tagList = ('a', 'meta', 'p');

sub parseData
{
	#get the site contents
	my $siteContents = @_;
	#clear the temporary variables used by this code
	@workingListList = ();
	%workingMetaTable = {};
	$workingBodyText = "";
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
	$parsedContents->links(@workingListList);
	$parsedContents->metaData(%workingMetaTable);
	$parsedContents->bodyText($workingBodyText);
	
	#return the struct
	return $parsedContents;
}

sub tagHandler
{
	my ($tagname, $attrRef) = @_;
	my %attributeTable = %{$attrRef};
	#add the addition to the inside hash table
	$inside{$tagname}++;
	
	if ($tagname eq 'a')
	{
		push (@workingLinkList, $attributeTable{'href'});
	}
	elsif($tagname eq 'meta')
	{
		#should find the attribute name and use this is the key of the working
		# metaData hash. Then push the value of this attribute and the value
		# of the contents attribute onto the array
		my $metaDataPair = new META_DATA_PAIR;
		my $metaTableKey;
		my ($key, $value);
		while ( ($key, $value) = each %attributeTable )
		{
			##content attribute found
  			if ($key eq "contents")
  			{
  				$metaDataPair->content($attributeTable{$key});
  			}
  			else ##assumes other attribute found
  			{
  				$metaTableKey = $key;
  				$metaDataPair->attributeValue($attributeTable{$key});
  			}
		}
		push($workingMetaTable{$metaTableKey}, $metaDataPair);
	}
}

sub textHandler
{
	my $text = @_;
}

sub endHandler
{
	my $tagname = @_;
	$inside{$tagname}--;
}
1;