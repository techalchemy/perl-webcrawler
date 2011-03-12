<?php
/*
Author: Daniel Ryan
Date: March 12, 2011

The purpose of this code is to take a series of inputs in page requests from headers and form posts.
It will authenticate the requesting user against its known users, then post the requested information to
its known databases and return whether this was successful in a JSON array.

Inputs:
	Headers: User-Agent, passEncodeKey (salt), urgencyFlag, transportReplaceStart (array), transportReplaceLen (array)
				-> the arrays in the headers will be json encoded
	Post: authName, userPass (sha256), pageURL, dataPackage (array of serialized, json encoded arrays)

Outputs: json encoded 2 value array: Authenticated, Transmitted (1/0 for each)

Still to do:
	1) Take Urgency Flag into account
	2) Write queueing system
	3) Connect to mysql db
	4) check if mysql tables exist already (replace . with _ for tld's)
	5) Make tables for each page by TLD, fields: relative URL path, url's linked to
	6) Make table w/ pageurl as key and include columns of title, author, keywords, charset, description, bodytext
	7) Consider making a class containing important variables, ie:exampleConnClass.php
*/

// This array contains key => value of username => array(useragent, pass, db)
// This will contain authentication information.
global $authInfoArray = array(
	'danconia' => array('techne', 'a9e74g65d4asdf48w91pp4a3', 'crawlRecords),
	'testUn' => array('testUA', 'testPass')
);

// Get an array of the headers sent
$headers = apache_request_headers();

// Make an array of the header fields we want
global $headerInput = array(
	"User-Agent" => '',
	"passEncodeKey" => '',
	"transportReplaceStart" => '',
	"transportReplaceLen" => '',
	"urgencyFlag => ''
);

// Compare each header field we have to the ones we want; populate those we want
foreach ($headers as $header => $value) {
    if ($headerInput[$header]) {
    	// If the header we are looking at is an expected array, decode it from json and store it as an array
    	if (($header == "transportReplaceStart") || ($header == "transportReplaceLen")) {
    		$headerInput[$header] = json_decode($value, true);
    	}
    	// Otherwise just get the string
    	else {
    		$headerInput[$header] = $value;
    	}
    }
}

// Define what post request info we are looking for
global $postRequest = array(
	"authName" => '',
	"userPass" => '',
	"pageURL" => '',
	"dataPackage" => ''
);

// Then fill it all in
$postRequest["authName"] = $_POST["authName"];
$postRequest["userPass"] = $_POST["userPass"];
$postRequest["pageURL"] = $_POST["pageURL"];
$postRequest["dataPackage"] = json_decode($_POST["dataPackage"], true);

// Check if the user is authorized -- this returns 1 if true
$authorized = checkAuth($headerInput["User-Agent"], $headerInput["passEncodeKey"], $postRequest["authName"], $postRequest["userPass"]);

// If authorization passes, go send all the data you need to send
if ($authorized == 1) {
	// First, get the reference key of each piece of data and pull its corresponding salt locations for conversion
	foreach ($postRequest["dataPackage"] as $dataNum => $dataContents) {
		// This function should trigger calls to finally post to the db
		getData($postRequest["authName"], $authInfoArray[$postRequest["authName"]][2], $headerInput["urgencyFlag"], $postRequest["pageURL"], $headerInput["transportReplaceStart"][$dataNum], $headerInput["transportReplaceLen"][$dataNum], $dataContents);
	}
}
else {
	$returnVal = json_encode(array('0', '0');
	echo $returnVal;
}

function getData ($usrName, $dbAccess, $urgency, $page, $startVal, $lenVal, $dataPkg) {
	// Determine Where the second string starts
	$strTwoStart = $startVal + $lenVal;
	// Remove the added piece through exclusion
	$binOne = substr($dataPkg, 0, $startVal) . substr($dataPkg, $strTwoStart);
	// Unserialize and decode the data contained in each data package
	$actualData = json_decode(unserialize($binOne), true);
	// If that didn't fail, send it along to the DB. Otherwise, return 0 to the client
	if ($actualData) {
		passToDb($usrName, $dbAccess, $urgency, $page, $actualData);
	}
	else {
		$returnVal = json_encode(array('1', '0'));
		echo $returnVal;
	}
}

// Send your info to the db in a post
function PassToDb ($userName, $accessDB, $urgencyFlag, $page, $dataArray) {
	$dbConnection = mysql_pconnect('localhost', 'dbHandler', 'a99e8d13g2d5q9wep465d');
	if ($dbConnection) {
	}
	else {
		$returnVal = json_encode(array('1', '0');
		echo $returnVal;
	}
	// Next, check what database the user has access to
	// Then, see if the tables they need exist; if not, create them
	// Then, insert the new record into the table
}

function authorized ($headerAgent, $headerPassKey, $postAuthName, $postUserPass) {
	if (isset($authInfoArray[$postAuthName])) {
		// allowed UA: $authInfoArray[$postAuthName][0] & plaintext pass [1]
		if ($headerAgent == $authInfoArray[$postAuthName][0]) {
			$ptPass = $headerPassKey . $authInfoArray[$postAuthName][1];
			$encryptedPass = hash("sha256", $ptPass);
			if ($postUserPass == $encryptedPass) {
				return 1;
			}
			else {
				return 0;
			}
		}
		else {
			return 0;
		}
	}
	else {
		return 0;
	}
}
?>