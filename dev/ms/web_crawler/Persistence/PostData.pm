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
# data processing script, along with a unique PostData_userAgent identifier
# NB: Install modules JSON and PHP::Serialize
######################################################################################
# Declare in config files (key/value pairs):
#	PostData_userAgent=AgentName
#	PostData_authName=Username
#	PostData_userPass=PasswordSeed
#	PostData_serverLocation=php script location path
######################################################################################
# Expect as return:
#	Valid return packet in Serialized JSON encoded key/value confirmation array in format:
#	{DataReceived: 1/0, Success: 1/0, }
######################################################################################
# USAGE INSTRUCTIONS
# CALL PostData::setConfigValues(\%configHashTable) (returns void)
# CALL PostData::sendToDB(urgencyflag, object1.....object n) (returns true/false)
######################################################################################

# Declare Class Name
package PostData;

# Define namespaces, include Util for config parsing
use lib '..';
require 'Utilities/Util.pm';
require HTTP::Headers;
use HTTP::Request::Common qw(POST GET);
use strict;
use Utilities::Util;
use PHP::Serialization qw(serialize unserialize);
use JSON::XS;
use LWP::UserAgent;
use Digest::SHA qw(sha256);

# Define static variables
my $encodedData;
my @replaceStartVals;
my @replaceLenVals;
my @replaceStrings;
my @formData;

# CONFIG DATA WE NEED: PostData_userAgent, PostData_authName, PostData_userPass, serverLocation, urgencyFlag, 
my %configHash = {
	"PostData_userAgent" => 'dataPoster',
	"PostData_authName" => 0,
	"PostData_userPass" => 'default password',
	"PostData_serverLocation" => 'localhost'
};
my %headerInfo = {
	"replaceStart", \@replaceStartVals,
	"replaceLen", \@replaceLenVals,
	"replaceVal", \@replaceStrings,
	"urgencyFlag", 0,
	"encodedPass", 'blank',
	"passEncodeKey", 'blank'
};
sub setConfigValues
{
	%configHash = %{$_[0]};
};
# Call main function for processing -- Returns False on any failure
# Pass this function the uflag and struct (uflag, struct)
# UFlag: 0 = non-urgent; 1 = expedite; 2 = extremely urgent
sub sendToDB
{
	my ($urgFlag, @passedParams) = @_;
	# Set config urgency flag
	$headerInfo{"urgencyFlag"} = $urgFlag;
	my $paramData;
	# Check struct conversion to serialized and randomized JSON
	foreach $paramData (@passedParams) 
	{
		if (convertToJson($paramData)) 
		{
			Util::debugPrint("Converting Data to JSON: Success");
		}
		else
		{
			Util::debugPrint("FAILURE: Converting data to JSON");
			return 0;
		}	
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
sub convertToJson
{
	# Determine what type of data we are dealing with
	my $initialData = $_[0];
	my $jsonStruct = undef;
	if ($initialData =~ m/^HASH/) 
	{
		# Typecast the hash ref into a hash table
		my %hashedStruct = %{$initialData};
		# Convert hash table to JSON
		$jsonStruct = json_encode(%hashedStruct);
	}
	elsif ($initialData =~ m/^ARRAY/)
	{
		# Typecast the array ref into an array
		my @arrayStruct = @{$initialData};
		# Convert hash table to JSON
		$jsonStruct = json_encode(@arrayStruct);		
	}
	elsif ($initialData =~ m/^SCALAR/)
	{
		# Typecast the scalar appropriately
		my $scalarStruct = $$initialData;
		# Convert hash table to JSON
		$jsonStruct = json_encode($scalarStruct);
	}
	# IF ITS A REF TO A REF ???
	elsif ($initialData =~ m/^REF/)
	{
		#DeReference and ReCall this function
		my $dereferencedRef = \$initialData;
		convertToJson($dereferencedRef);		
	}
	# If it's an object ref
	elsif ($initialData =~ m/^\w+\=/)
	{
		# Pass the data type reference back to this function
		$initialData =~ s/^\w+\=//;
		convertToJson($initialData);
	}
	else 
	{
		$jsonStruct = json_encode($initialData);
	}
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
	my $startBitVal = int(rand($stringLengthTotal));
	push(@replaceStartVals, $startBitVal);
	# Determine random number & length of random string to insert & store in hash
	my $replaceStringVal = int(rand(99999999999999999999999999999999999));
	push(@replaceStrings, $replaceStringVal);
	my $insertedLength = length($replaceStringVal);
	push(@replaceLenVals, $insertedLength);
	# Insert the generated value into the initial string (make functional)
	# First, split the binary scalar into the first and last sections
	my $lastSubstrBit = $startBitVal+1;
	my $finalDataFirst = substr($decodedStringVal, 0, $startBitVal);
	my $finalDataLast = substr($decodedStringVal, $lastSubstrBit);
	# Then, insert the new data in to the serial data
	my $finalSerialData = $finalDataFirst . $replaceStringVal . $finalDataLast;
	push(@formData, $finalSerialData);
	return 1;
}
sub encodePassword
{
	my $decodedPassText = $configHash{"PostData_userPass"};
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

# Stuff to know for transport: configHash has PostData_userAgent, PostData_authName, PostData_serverLocation
# headerInfo has transportReplaceStart, transportReplaceLen, encodedPass, passEncodeKey
# encodedData is being sent
# send all info via HTTPS

sub shipData
{
	# Begin with header object declaring content and agent types
	my $headerObj = HTTP::Headers->new(
	Content_Type => 'text/html',
	User_Agent => $configHash{"PostData_userAgent"}
	);
	# Pass header object encoding metadata
	# build header w/ foreach loop on header data (json encode)
	my $transStartInfo = json_encode(@replaceStartVals);
	my $transLenInfo = json_encode(@replaceLenVals);
	$headerObj->header(
	-transportReplaceStart => $transStartInfo,
	-transportReplaceLen => $transLenInfo,
	-passEncodeKey => $headerInfo{"passEncodeKey"},
	-urgencyFlag => $headerInfo{"urgencyFlag"}
	);
	# NB: Submit via form: %configHash{"PostData_authName"}, %headerInfo{"encodedPass"}, $encodedData
	# Instantiate Request Objet for Form post to server
	# TODO Add form data
	my $sendThisData = json_encode(@formData);
	my $httpRequest = POST $configHash{"PostData_serverLocation"}, [
	authName => $configHash{"PostData_authName"},
	userPass => $headerInfo{"encodedPass"},
	dataPackage => $sendThisData
	];
	# Instantiate new LWP PostData_userAgent object to submit form request
	#TODO Make all of the commlink stuff declared in the instantiation
	my $commLink = LWP::UserAgent->new();
	$commLink->headers($headerObj);
	$commLink->agent($configHash{"PostData_userAgent"});
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