## @file crawler.pl
# This script is meant to be run to execute a web crawl with a specified configuration. This script will most likely supply the configuration
# through the use of a .cfg configuration file, although the extension is arbitrary (for now). The configuration parameters that can be
# used will be listed below. The details of how these configuration parameters should be formatted can be found in the Utilities::Util package
# documentation.


# include the CPAN modules

# include the local modules

BEGIN
{
	
	
}

# begin execution here
print getCurrentTimeString() . "starting crawler.pl...\n";
main(\@ARGV);
print getCurrentTimeString() . "finished running crawler.pl...\n";


sub main
{
	# place the parameters in an array reference
	my @parameters = @$_[0];
	# the configuration file should be in the first argument
	#	validate the argument is okay
	if (!@parameters)
	{
		# configuration file was undefined, print something and exit
		print "configuration file path undefined, try again\n";
	}
	my $configurationFilePath = $parameters[0];
	# load the configuration
	my $configuration = loadConfigurationFile($configurationFilePath);
	# get the list of page processing functions
	my $pageProcessingFunctions = getPageProcessingFunctions();
	# create the crawling engine to do the crawl
	my $robot = CrawlingEngine->new($pageProcessingFunctions, $configuration);
	# run the crawl
	my $crawlingResults = $robot->crawl();
	# yay, script done
}

sub loadConfigurationFile
{
	# TODO: implement loadConfigurationFile (in crawler.pl)
}

sub getPageProcessingFunctions
{
	# TODO: implement getPageProcessingFunctions (in crawler.pl)
}


## @fn static string getCurrentTimeString()
# This function returns the current date and time in a nice looking human readable format
# @return string of the current time
sub getCurrentTimeString
{
	my @tempTime = localtime(time);
	my $seconds = @tempTime[0];
	my $minutes = @tempTime[1];
	my $hours = @tempTime[2];
	my $day = @tempTime[3];
	my $month = @tempTime[4];
	my $year = int(@tempTime[5]) + 1900;
	_addZeroIfLessThanTen($hours, $minutes, $seconds);
	return $day . "/" . $month . "/" . $year . " " . $hours . ":" . $minutes . ":" . $seconds;
}

## @fn private static void _addZeroIfLessThanTen(@strings)
# This function takes a list of strings and prefixes a zero to all the
# strings that are less than 10
sub _addZeroIfLessThanTen
{
	foreach(@_)
	{
		if ($_ < 10)
		{
			$_ = '0' . $_;
		}
	}
}