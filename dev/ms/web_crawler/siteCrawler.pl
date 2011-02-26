######################################################################################
#								siteCrawler.pl										 
######################################################################################
# The purpose of this script is to crawl a subset of the internet specificied by
# seed web pages and link depth. The script currently outputs all the information
# gathered into files that are named based on unique identifiers. The output files
# contain the original web data, as well as metadata captured by the script. This
# metadata gets placed into the beginning of the file, inside of HTML comments.	
#
#	TODO add instrumentation
#		debug printing of relevant runtime info
#		add output files for following things:
#			list of links encountered
#	TODO handling different charsets
#	TODO do HTML parsing via extending HTML::Parser class
#	TODO change how program options are set
#		config file, command line params, or both?
#																				 
######################################################################################
require 'SiteParser.pm';
use strict;

use HTML::Parser;
use LWP::Simple;
use Class::Struct;
use SiteParser;

#no warnings 'utf8'; #XXX get rid of this once charset handling implemented

# this struct will be used to hold the date on each page
struct(PAGE_RECORD => {url => '$',
					   timestamp => '$',
					   contents => '$',
					   linkDepth => '$',
					  });

my $MAX_LINK_DEPTH = 3;
my $MAX_IDENTIFIER_RANGE = 0xffffffffffffffff;
my $DATA_FILE_SUFFIX = ".dat";
my $PROCESSING_SCRIPT_PATH = 'webProcessor.pl';
my $PROCESSING_FUNCTION_NAME = 'processRecord';
my $DEBUG_PRINT_OUTPUT_FILENAME = "debug_log.txt";

my $isStoringOriginal = '1';
my $isProcessing = '1';


# This array is currently used to share information between the extractLinks 
# function and the foundLink function
my @tempLinkArray = (); 

print "starting siteCrawler.pl...\n";
main();
print "finished running siteCrawler.pl...\n";

sub main()
{
	#check to see if the user just wanted to see the usage
	if ((scalar(@ARGV) == 0) || (join("", @ARGV) =~ m/(help|\?|usage|-h)/g))
	{
		print "\nProper calling conventions:\n";
		print "\tperl siteCrawler.pl <seed file> <id prefix> <max link depth>\n\n";
		return;
	}

	my @seeds = loadAndSeparate($ARGV[0]);
	my $idPrefix = $ARGV[1];
	$MAX_LINK_DEPTH = $ARGV[2];
	startCrawling($idPrefix, \@seeds);
}

######################################################################################
#	Simple function that takes in a path to a seed file. Assumes one entry
#	per line. Loads seeds into array and returns it
#		Parameters
#			indentifierPrefix - a prefix for identifiers to allow multiple crawlers
#			to output to the same directory without conflicts
#			seedArrayRef - A reference to an array containing the seeds for the
#			crawler
#		Return
#			An array containing all the urls of all the links
#
######################################################################################
sub loadAndSeparate($)
{
	my @tempArray;
	my $seedFilePath = $_[0];
	open (INPUT_FILE, $seedFilePath);
	while (<INPUT_FILE>)
	{
		chomp();
		push(@tempArray, $_);
	}
	close (INPUT_FILE);
	return @tempArray;
}

######################################################################################
#	This function is the workhorse of the script. It will be supplied with a ID prefix
#	and a list of seed URLs to start crawling. It will visit each of these pages and
#	the pages they link to. Building PAGE_RECORD objects for each one and storing it
#	to a file. 
#		Parameters
#			indentifierPrefix - a prefix for identifiers to allow multiple crawlers
#			to output to the same directory without conflicts
#			seedArrayRef - A reference to an array containing the seeds for the
#			crawler
#		Return
#			An array containing all the urls of all the links
#
######################################################################################
sub startCrawling($$)
{
	my ($identifierPrefix, $seedArrayRef) = @_; #store arguments in local variables
	
	my @seeds = @{$seedArrayRef}; #seed array, dereferencing the seedArrayRef parameter
	
	my @siteStack = (); #stack to hold websites
	
	# build page records for each of the seeds
	push(@siteStack, checkAndBuildPageRecords(\@seeds, 0));

	# MAIN LOOP
	# The basic algorithm this loop implements is to pop a site off the stack, process it
	# and push all the new links onto the stack. Repeat until stack is empty
	while (@siteStack)
	{
		my $currentRecord = pop @siteStack;
		$currentRecord->contents(get $currentRecord->url);
		#make sure the page is defined, if it isn't just go to the next one
		next unless defined $currentRecord->contents;
		
		$currentRecord->timestamp(getCurrentTimeString());
		
		if ($isStoringOriginal)
		{
			storePage($currentRecord, $identifierPrefix);	
		}
		
		my @currentRecordLinks;
		if ($isProcessing)
		{
			require $PROCESSING_SCRIPT_PATH;
			&$PROCESSING_FUNCTION_NAME($currentRecord);
		}
		@currentRecordLinks = extractLinks($currentRecord->contents);
		my @newPageRecords = ();
		if ($currentRecord->linkDepth < $MAX_LINK_DEPTH)
		{
			@newPageRecords = checkAndBuildPageRecords(\@currentRecordLinks, $currentRecord->linkDepth + 1);
		}
		push (@siteStack, @newPageRecords);
	}
}


######################################################################################
#	This function is used to verify that the links are correctly formed, possibly
#   fixing them if not, and then builds page records for each of them
#		Parameters
#			linkListRef - reference to array of links
#			linkDepth - depth the links should have
#		Return
#			an array of page records with the url and linkDepth fields populated
#
######################################################################################
sub checkAndBuildPageRecords($$)
{
	my ($linkListRef, $linkDepth) = @_;
	my @links = @{$linkListRef};
	my @recordList = ();
	foreach (@links)
	{
		#check for legal link
		if (/http:\/\//)
		{
			my $currentRecord = new PAGE_RECORD;
			$currentRecord->url($_);
			$currentRecord->linkDepth($linkDepth);
			push (@recordList, $currentRecord);
		}
	}
	return @recordList;
}

######################################################################################
#	This function takes the current time and outputs it in a format that is human
#	readable. For future processing, the time can be broken up easily with regexes
#		Parameters
#			content - This should be the HTML page contents. A single scalar holding
#			all the data is expected
#		Return
#			A human readable using string indicating the current time
#
######################################################################################
sub getCurrentTimeString
{
	my @tempTime = localtime(time);
	my $seconds = @tempTime[0];
	my $minutes = @tempTime[1];
	my $hours = @tempTime[2];
	my $day = @tempTime[3];
	my $month = @tempTime[4];
	my $year = int(@tempTime[5]) + 1900;
	return $day . "/" . $month . "/" . $year . " " . $hours . ":" . $minutes . ":" . $seconds;
}

sub debugPrint($)
{
	open (DEBUG_FILE, ">>", $DEBUG_PRINT_OUTPUT_FILENAME);
	print DEBUG_FILE "TIME: " . getCurrentTimeString() . " MESSAGE: " . $_[0] . "\n";
	close (DEBUG_FILE);
}


######################################################################################
#	This function will take a given page record struct and store it to a file. This
#	output file will be given a unique ID to name the file. The crawler metadata
#	will be saved.
#		Parameters
#			pageRecord - this should be an instance of the PAGE_RECORD struct
#			idPrefix - this is used to ensure unique ids are created between
#			different runs of the parser
#		Return
#			none
#
######################################################################################
sub storePage($$)
{
	my $pageRecord = $_[0];
	my $idPrefix = $_[1];
	
	my $url = $pageRecord->url;
	my $timeStamp = $pageRecord->timestamp;
	my $linkDepth = $pageRecord->linkDepth;
	my $contents = $pageRecord->contents;
	
	my $pageID = getUniqueID();
	
	open (OUTPUT_FILE, ">", $idPrefix . "_" . $pageID . $DATA_FILE_SUFFIX);
	#print program metadata as html comments
	print OUTPUT_FILE "<!-- url: " . $url . " -->";
	print OUTPUT_FILE "<!-- timestamp: " . $timeStamp . " -->";
	print OUTPUT_FILE "<!-- linkDepth: " . $linkDepth . " -->";
	print OUTPUT_FILE $contents;
	close (OUTPUT_FILE);
}


######################################################################################
#	This function creates a unique ID to use for the filename. The current way these
#	IDs are generated is by simply searching the current working directory to see if
#	a file aready exists with the current working directory. This isn't very 
#	satisfactory and should be changed.
#		Parameters
#			pageRecord - this should be an instance of the PAGE_RECORD struct
#		Return
#			none
#
######################################################################################
sub getUniqueID()
{
	my $attemptedID = int(rand($MAX_IDENTIFIER_RANGE));
	while (glob("*_" . $attemptedID . $DATA_FILE_SUFFIX))
	{
		$attemptedID = int(rand($MAX_IDENTIFIER_RANGE));
	}
	return $attemptedID;
}


######################################################################################
#	This function pulls all the links out of an HTML file and places them in an array.
#	currently this is done using a global temporary variable. This is not good coding
#	practice and should be changed. The reason it's used currently is because instead
#	of overriding the HTML::Parser class, it simply instantiates one and supplies
#	the event handling function foundLink that is defined in this script.
#		Parameters
#			content - This should be the HTML page contents. A single scalar holding
#			all the data is expected
#		Return
#			An array containing all the urls of all the links
#
######################################################################################
sub extractLinks($)
{
	my $content = @_[0];
	my $parser = HTML::Parser->new(start_h => [\&foundLink, "tagname, attr"]);
	$parser->report_tags(['a']);
	$parser->parse($content);
	return @tempLinkArray;
}

######################################################################################
#	This function is called when start events are triggered by the HTML::Parser. The
#	way this parser is configured in extractLinks it will trigger when a <a> tag is
#	encountered. This function just pulls out the href data and pushes it onto the
#	tempLinkArray
#		Parameters
#			tagname - currently the only tags being looked for are link tags, so 
#			this doesn't really matter
#			attr - this is a struct that contains the attributes of the tag
#		Return
#			Doesn't return anything, but modifies global variable @tempLinkArray
#
######################################################################################
sub foundLink($$) { 
	##pushes the url onto the temp link array
	my ($tagname, $attr) = @_;
	push(@tempLinkArray, $attr->{ href });
	##Debugging code to make list of links found
	open (LINK_OUTPUT_FILE, ">>", "linklist.txt");
	print LINK_OUTPUT_FILE $attr->{ href } . "\n";
	close LINK_OUTPUT_FILE;
}
