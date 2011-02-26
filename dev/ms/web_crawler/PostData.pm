######################################################################################
#								PostData.pm
#	Author: Daniel Ryan
#	Date: 2/26/2011
######################################################################################
# The purpose of this script is to take as a parameter the struct resulting from
# the data parser.  This data will undergo a JSON encoding and serialization.
# The serialized JSON encoded struct will have an insertion of a random number of
# random length at a random position for preventing unauthorized deserialization.
# The length and position of this number will be passed in the headers to the
# data processing script, along with a unique UserAgent identifier (Danconia)
# NB: Install modules JSON and PHP::Serialize
######################################################################################
# Declare in config files (key/value pairs):
#	userAgent=AgentName
#	authName=Username
#	userPass=PasswordSeed
#	serverLocation=php script location path
######################################################################################
# Pass to the DB Handler:
#	Headers
#		UserAgent, byte replace start, byte replace length, request type(post),
#			protocol (https/tls), password encryption seed
#	Post reqeust
#		authname, credential, urgency, data(serialized struct)
######################################################################################
# Expect as return:
#	Valid return packet in Serialized JSON encoded key/value confirmation array in format:
#	{DataReceived: 1/0, UserAuthSuccess: 1/0, }
######################################################################################
# TODO:
# Retain hash data accessible by $variable{keyname} with set keynames
# Write functions: sendToDB(struct); convertStruct(struct); (return t/f); insertRandomString(binary);
#	encodePassword(password); 
# Create %headerInfo for transportReplaceStart, transportReplaceLen, transportReplaceVal
# SendToDB cascading  calls: convertStruct, insertRandomString, encodePassword, shipData
# shipData function handles user agent connection
######################################################################################

# Declare Class Name
package PostData;

# Define namespaces, include Util for config parsing
require 'Util.pm';
use strict;
use Util;
use PHP::Serialization qw(serialize unserialize);
use JSON::XS;
use LWP::UserAgent;

# Define static variables
my $configFile;
my $encodedData;
my %configHash = {
	"userAgent", 'dataPoster',
	"authName", 0,
	"userPass", 'default password',
	"serverLocation", 'localhost'
}
my %headerInfo = {
	"transportReplaceStart", 0,
	"transportReplaceLen", 0,
	"transportReplaceVal", 0,
	"encodedPass", 'blank',
	"passEncodeKey", 'blank'
}
my %hashedStruct = {
}
# Relative path of the config file location and loading for isolation testing
$configFile = "commConfig.conf";
%configHash = Util::loadConfigFile($configFile);

my $commLink = LWP::UserAgent->new();

# Take hash values passed from main script
sub setConfigValues
{
	%configHash = %{$_[0]};
}
# Call main function for processing
sub sendToDB
{
	# Check struct conversion to serialized and randomized JSON
	if (convertToStruct($_[0]))
	{
		print "\n\nStruct object successfully converted\n\n";
	}
	else 
	{
		print "\n\nStruct object conversion failure\n\n";
	}
	# Check password encoding & rewrite to hash table as encodedPass
	if (encodePassword(%cognfigHash{'userPass'}))
	{
		print "\n\n\nPassword successfully encoded";
	}
	else
	{
		print "\n\n\nPassword endoding failure\n\n\n";
	}
	if (shipData($encodedData))
	{
		return 1;
	}
	else
	{
		return 0;
	}
		
}
sub convertToStruct 
{
	%hashedStruct = %{$_[0]};
	my $jsonStruct = json_encode %hashedStruct;
	my $serialData = serialize($jsonStruct);
	if(insertRandomString($serialData))
	{
		print "\nString randomization complete\n";
	}
	else
	{
		print "\nString randomization failed\n";
	}
}
sub insertRandomString 
{
	
}
sub encodePassword
{
	
}
sub shipData
{
	
}

1;