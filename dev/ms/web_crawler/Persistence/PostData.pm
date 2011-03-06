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
# data processing script, along with a unique UserAgent identifier
# NB: Install modules JSON and PHP::Serialize
######################################################################################
# Declare in config files (key/value pairs):
#	userAgent=AgentName
#	authName=Username
#	userPass=PasswordSeed
#	serverLocation=php script location path
######################################################################################
# Expect as return:
#	Valid return packet in Serialized JSON encoded key/value confirmation array in format:
#	{DataReceived: 1/0, UserAuthSuccess: 1/0, }
######################################################################################
# USAGE INSTRUCTIONS
# CALL PostData::setConfigValues(%configHashTable) (returns void)
# CALL PostData::sendToDB(structObject) (returns true/false)
######################################################################################

# Declare Class Name
package PostData;

# Define namespaces, include Util for config parsing
require 'Util.pm';
require HTTP::Headers;
use HTTP::Request::Common qw(POST GET);
use strict;
use Util;
use PHP::Serialization qw(serialize unserialize);
use JSON::XS;
use LWP::UserAgent;
use Digest::SHA qw(sha256);

# Define static variables
my $configFile;
my $encodedData;

my %configHash = {
	"userAgent", 'dataPoster',
	"authName", 0,
	"userPass", 'default password',
	"serverLocation", 'localhost'
};
my %headerInfo = {
	"transportReplaceStart", 0,
	"transportReplaceLen", 0,
	"transportReplaceVal", 0,
	"urgencyFlag", 0,
	"encodedPass", 'blank',
	"passEncodeKey", 'blank'
};
my %hashedStruct = {
};

# Relative path of the config file location and loading for isolation testing
#$configFile = "commConfig.conf";
#%configHash = Util::loadConfigFile($configFile);

# Take hash values passed from main script
sub getCfgInfo 
{
	Util::getConfig();
}
sub setConfigValues
{
	%configHash = %{$_[0]};
};
# Call main function for processing -- Returns False on any failure
# Pass this function the uflag and struct (uflag, struct)
# UFlag: 0 = non-urgent; 1 = expedite; 2 = extremely urgent
sub sendToDB
{
	# Set config urgency flag
	$headerInfo{"urgencyFlag"} = $_[0];
	# Check struct conversion to serialized and randomized JSON
	if (convertFromStruct($_[1]))
	{
		print "Struct object successfully converted\n";
	}
	else 
	{
		print "Struct object conversion failure\n";
		return 0;
	}
	# Check password encoding & rewrite to hash table as encodedPass
	if (encodePassword())
	{
		print "Password successfully encoded\n";
	}
	else
	{
		print "Password endoding failure\n";
		return 0;
	}
	# use $encodedData value set by insertRandomString
	if (shipData($encodedData))
	{
		print "Data Sent!\n";
		return 1;
	}
	else
	{
		print "Data Sending Failure\n";
		return 0;
	}
		
}
sub convertFromStruct 
{
	# Typecast the struct data into a hash table
	%hashedStruct = %{$_[0]};
	# Convert hash table to JSON
	my $jsonStruct = json_encode(%hashedStruct);
	# Error checking
	if ($jsonStruct)
	{
		print "JSON Encoding Successful\n";
	}
	else
	{
		print "JSON Encoding Failed\n";
		return 0;
	}
	# PHP Serialize the JSON value
	my $serialData = serialize($jsonStruct);
	# More error checking
	if ($serialData)
	{
		print "Serialization Successful\n";
	}
	else
	{
		print "Serialization Failed\n";
		return 0;
	}
	# Call insert function to encode serial data
	if(insertRandomString($serialData))
	{
		print "String randomization complete\n";
	}
	else
	{
		print "String randomization failed\n";
		return 0;
	}
}
# Function to salt binary data
sub insertRandomString 
{
	# Param: Serialized Value
	my $decodedStringVal = $_[0];
	# Count the length of the value
	my $stringLengthTotal = length($decodedStringVal);
	# Determine start bit for random num insertion (casts start as random val b/w 0-stringLen)
	$headerInfo{"transportReplaceStart"} = int(rand($stringLengthTotal));
	# Determine random number & length of random string to insert & store in hash
	$headerInfo{"transportReplaceVal"} = int(rand(99999999999999999999999999999999999));
	$headerInfo{"transportReplaceLen"} = length($headerInfo{"transportReplaceVal"});
	# Insert the generated value into the initial string (make functional)
	# First, split the binary scalar into the first and last sections
	my $lastSubstrBit = $headerInfo{"transportReplaceStart"}+1;
	my $finalDataFirst = substr($decodedStringVal, 0, $headerInfo{"transportReplaceStart"});
	my $finalDataLast = substr($decodedStringVal, $lastSubstrBit);
	# Then, insert the new data in to the serial data
	my $finalSerialData = $finalDataFirst . $headerInfo{"transportReplaceVal"} . $finalDataLast;
	$encodedData = $finalSerialData;
	return 1;
}
sub encodePassword
{
	my $decodedPassText = $configHash{"userPass"};
	# generate encryption salt (this string is 30 concatenated ascii characters)
	my $saltVal = eval sprintf q[(%s)], join q[ . ] => ('chr(int(rand(92))+33)') x 30;
	# Salt the password with the string
	my $saltedPass = $saltVal . $decodedPassText;
	# SHA-2 encryption for SALT
	my $encodedPass = sha256($saltedPass);
	# Set the header values with the salt string and the encrypted password 
	$headerInfo{"encodedPass"} = $encodedPass;
	$headerInfo{"passEncodeKey"} = $saltVal;
	return 1;
}

# Stuff to know for transport: configHash has userAgent, authName, serverLocation
# headerInfo has transportReplaceStart, transportReplaceLen, encodedPass, passEncodeKey
# encodedData is being sent
# send all info via HTTPS

sub shipData
{
	# Begin with header object declaring content and agent types
	my $headerObj = HTTP::Headers->new(
	Content_Type => 'text/html',
	User_Agent => $configHash{"userAgent"}
	);
	# Pass header object encoding metadata
	$headerObj->header(
	-transportReplaceStart => $headerInfo{"transportReplaceStart"},
	-transportReplaceLen => $headerInfo{"transportReplaceLen"},
	-passEncodeKey => $headerInfo{"passEncodeKey"},
	-urgencyFlag => $headerInfo{"urgencyFlag"}
	);
	# NB: Submit via form: %configHash{"authName"}, %headerInfo{"encodedPass"}, $encodedData
	# Instantiate Request Objet for Form post to server
	# TODO Add form data
	my $httpRequest = POST $configHash{"serverLocation"}, [
	authName => $configHash{"authName"},
	userPass => $headerInfo{"encodedPass"},
	dataPackage => $encodedData
	];
	# Instantiate new LWP UserAgent object to submit form request
	my $commLink = LWP::UserAgent->new();
	$commLink->headers($headerObj);
	$commLink->agent($configHash{"userAgent"});
	# Read response for bit flag indicators
	my $httpResponse = $commLink->request($httpRequest);
	my $httpData = $httpResponse->content;
	# Unserialize response data and json_decode it into an array
	my $responseJson = unserialize $httpResponse;
	my @responseArray = json_decode $responseJson;
	# Check if the operation succeeded
	my $responseString;
	if (($responseArray[0] == 1) and ($responseArray[1] == 1))
	{
		$responseString = "Authenticated and Transmitted\n";
		return 1;
	}
	else
	{
		$responseString = "Data Failed to Transfer\n";
		return 0;
	}
}

1;