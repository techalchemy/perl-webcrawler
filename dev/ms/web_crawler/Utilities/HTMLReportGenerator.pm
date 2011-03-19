## @file Implementation of HTMLReportGenerator
# @par Description
# This module is going to be used to easily generate nice looking HTML reports. The creation
# of this file was motivated by the post processing scripts and the need to output the results
# of a web crawl in a easily digestable and useable way. The module will work by creating
# an instance of the class defined below. Data will be added to this object over time until
# the report is finished, at which point a publishing method can be called to actually
# finalize the report and output it

## @class HTMLReportGenerator
# The purpose of this class is to encapsulate in a user friendly way the creation of HTML reports
# including images, text, lists, tables and other common HTML elements
package HTMLReportGenerator;
#use this module to create a struct to encapsulate each element of the report
use Class::Struct;

struct(REPORT_ELEMENT => {
	TYPE => '$',
	CONTENT => '$',
});

## @enum Data Types
#  this enum is used to specify which datatype an element is
use constant
{
	IMAGE,
	LINK,
	PARAGRAPH,
	HEADER,
	ORDERED_LIST,
	LIST_ITEM,
	UNORDERED_LIST,
	TABLE
};

use constant
{
	LEFT,
	RIGHT,
	CENTER
};

## @cmethod HTMLReportGenerator()
# the default constructor for the class
sub new
{
	my $self = {};
	$self->{DOCUMENT_ELEMENTS} = [];
	$self->{CURRENT_ALIGNMENT} = LEFT;
	my $class = 'HTMLReportGenerator';
	bless $self, $class;
	return $self;
}

sub publishDocument
{
	
}

sub _compileElement
{
	
}

sub _addToDocument
{
	my ($self, $type, $content);
	my $pageElement = REPORT_ELEMENT->new(TYPE => $type, CONTENT => $content);
	push(@{$self->{DOCUMENT_ELEMENTS}}, $pageElement);
}

## @cmethod void addParagraph($text)
# this function is used to add a paragraph to the report
sub addParagraph
{
	my ($self, $text) = @_;
	_addToDocument($self, PARAGRAPH, $text);
}

sub addImage
{
	my ($self, $imageData) = @_;
	_addToDocument($self, IMAGE, $imageData);
}

sub addLink
{
	my ($self, $url, $linkText) = @_;
	
}

sub addHeader
{
	
}

sub addOrderedList
{
	
}

sub addUnorderedList
{
	
}

sub addTable
{
	
}

sub setAlignment
{
	
}


1;