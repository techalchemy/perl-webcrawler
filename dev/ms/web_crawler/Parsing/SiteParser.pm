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
#																				 
######################################################################################

package SiteParser;

#import CPAN modules
use strict;
use HTML::Parser;
use Class::Struct;

#import local modules
require 'Util.pm';
use Util qw(debugPrint);

# this struct holds the information that is the result of parsing the html file
# Each attribute is described below
#	links - this is an array of string urls
#	metaData - this is a table which has an attribute as a key and an array
#	of attribute_value - contents pairs.
#	bodyText - this is a string holding the body text of the page
struct(PARSED_PAGE => {
	title => '$',
	author => '$',
	links => '@',
	charset => '$',
	keywords => '@',
	description => '$',
	bodyText => '$',
});

#private variables used by the functions in this file
my $workingPageStruct;

#used to keep track of what tags are currently open
#	EXAMPLE: you want to know if you're inside a script tag
#   my $insideScriptTag = $inside{"script"};
#	FIXME not tested, doesn't handle tags without end tags
my %inside = {};

#constants used by the functions in this file
my @tagList = ['a', 'meta', 'p', 'body', 'script'];

######################################################################################
#	This function is the only one in this class that should be called by external
#	scripts. It will parse the html data given to it and return a PARSED_PAGE.
#	Since not all sites specify all the attributes in the struct, there is the
#	possibility of fields being undefined. This should be taken into account by
#	users of this module
#		Parameters
#			siteContents - a string containing the site's entire code
#		Return
#			a PARSED_PAGE struct with the fields populated
#
######################################################################################
sub parseData
{
	#get the site contents
	my $siteContents = $_[0];
	#initialize the working struct to be populated while parsing
	$workingPageStruct = new PARSED_PAGE;
	Util::debugPrint('parseData called, initializing parser');
	#initialize parsed contents struct
	#set up the HTML Parser with proper event handling subroutines
	my $parser = HTML::Parser->new(start_h => [\&tagHandler, "tagname, attr"],
								   text_h => [\&textHandler, '@{text}'],
								   end_h => [\&endHandler, "tagname"]);
	$parser->report_tags(@tagList);
	#call the parse function with downcased html data
	Util::debugPrint('parser initialized, starting parsing');
	$parser->parse(lc($siteContents));
	
	
	#return the now populated struct
	Util::debugPrint('parsing done');
	return $workingPageStruct;
}


######################################################################################
#	This function is called by the HTML::Parser to handle start events. The parser
#	uses an event based parsing algorithm and thus this will get called during
#	the execution of the parse function of the HTML::Parser. It modifies a global
#	variable that is a working page struct. This will gradually be populated over
#	the course of the repeated calls to this function see the CPAN page for 
#	HTML::Parser for more information
#		Parameters
#			tagname - name of the tag encountered
#			attr - reference to hashtable containing attribute-value pairs
#		Return
#			none
#
######################################################################################
sub tagHandler
{
	my ($tagname, $attr) = @_;
	#add the addition to the inside hash table
	$inside{$tagname}++;
	if ($tagname eq 'a')
	{
		#Util::debugPrint('link encountered. url => ' . $attr->{'href'});
		push (@{$workingPageStruct->links}, $attr->{'href'});
	}
	elsif($tagname eq 'meta')
	{
		if (defined $attr->{'name'})
		{
			if ($attr->{'name'} eq 'keywords')
			{
				push (@{$workingPageStruct->keywords}, split(/(\s|,|\*)+/, $attr->{'content'}));
			}
			elsif ($attr->{'name'} eq 'description')
			{
				$workingPageStruct->description($attr->{'content'});
			}
			elsif ($attr->{'name'} eq 'title')
			{
				$workingPageStruct->title($attr->{'content'});
			}
			elsif ($attr->{'name'} eq 'author')
			{
				$workingPageStruct->author($attr->{'content'});
			}	
		}
		elsif (defined $attr->{'http-equiv'})
		{
			if ($attr->{'http-equiv'} eq 'content-type')
			{
				$workingPageStruct->charset($attr->{'content'});
			}
		}
	}
}

# FIXME this isn't working at all. serious issue.
sub textHandler
{
#	foreach(@_)
#	{
#		$_ =~ s/\s//g;
#	}
	chomp();
	$workingPageStruct->bodyText($workingPageStruct->bodyText . " " . @_);
}

sub endHandler
{
	my $tagname = @_;
	#remove the appended forward slash (see cpan website on HTML::Parser)
	$tagname =~ s/\///g;
	$inside{$tagname}--;
}
1;