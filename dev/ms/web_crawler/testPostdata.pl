use LWP::Simple;
use Class::Struct;
#declare structs used by crawler
struct(PAGE_RECORD => {url => '$',
					   timestamp => '$',
					   linkDepth => '$',
					  });

# get local modules
require 'Parsing/SiteParser.pm';
require 'Utilities/Util.pm';
require 'Persistence/PostData.pm';
use Parsing::SiteParser;
use Utilities::Util qw(debugPrint);
use Persistence::PostData qw(sendToDB);
my %options;

print "starting webCrawler.pl...\n";
main();
print "finished running webCrawler.pl\n";

sub main
{
	#set debugging mode and logging
	# obtain the configuration parameters
	# assumes config file path is first parameter
	# grab config file path
	my $configFilePath = $ARGV[0];
	# load config params into %options
	%options = Util::loadConfigFile($configFilePath);
	Util::setGlobalDebug($options{'useDebugMode'});
	Util::setGlobalDebugFile($options{'debugFile'});