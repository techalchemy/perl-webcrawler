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
	3) Connect to mysql db -- DONE
	4) check if mysql tables exist already (replace . with _ for tld's) -- DONE
	5) Make tables for each page by TLD, fields: relative URL path, url's linked to -- DONE
	6) Make table w/ pageurl as key and include columns of title, author, keywords, charset, description, bodytext -- DONE
	7) Consider making a class containing important variables, ie:exampleConnClass.php -- DONE
*/
Class databaseControl {
	// This array contains key => value of username => array(useragent, pass)
	// This will contain authentication information.
	public static $authInfoArray = array(
		'danconia' => array('techne', 'a9e74g65d4asdf48w91pp4a3'),
		'testUn' => array('testUA', 'testPass')
	);
	// this contains username => database, tables
	public static $accessList (
		'danconia' => array('crawlRecords', 'raw_webData')
	);
	// Make an array of the header fields we want
	public $headerInput = array(
		"User-Agent" => '',
		"passEncodeKey" => '',
		"transportReplaceStart" => '',
		"transportReplaceLen" => '',
		"urgencyFlag" => ''
	);
	// Define what post request info we are looking for
	public $postRequest = array(
		"authName" => '',
		"userPass" => '',
		"pageURL" => '',
		"dataPackage" => ''
	);
	public function setHeaderVal($header, $value) {
		self::headerInput[$header] = $value;
	}
	public function setPostInfo ($field, $value) {
		self::postRequest[$field] = $value;
	}
	public function getData ($startVal, $lenVal, $dataPkg) {
		// Determine Where the second string starts
		$strTwoStart = $startVal + $lenVal;
		// Remove the added piece through exclusion
		$binOne = substr($dataPkg, 0, $startVal) . substr($dataPkg, $strTwoStart);
		// Unserialize and decode the data contained in each data package
		$actualData = json_decode(unserialize($binOne), true);
		// If that didn't fail, send it along to the DB. Otherwise, return 0 to the client
		if ($actualData) {
			databaseControl::passToDb($actualData);
		}
		else {
			$returnVal = json_encode(array('1', '0'));
			echo $returnVal;
		}
	}

	// Send your info to the db in a post
	public function passToDb ($dataArray) {
		$userName = databaseControl::$postRequest["authName"];
		$dbToWrite = databaseControl::$accessList[$userName][0];
		$urgencyFlag = databaseControl::$headerInput["urgencyFlag"];
		$page = databaseControl::$postRequest["pageURL"];
		$table = databaseControl::$accessList[$userName][1];
		$tld = databaseControl::get_tld($page);
		$tables = array($table, $tld);
		$dbConnection = mysql_connect('localhost', 'dbHandler', 'a99e8d13g2d5q9wep465d');
		if ($dbConnection) {
			if(mysql_select_db($dbToWrite, $dbConnection) === false) {
				// create the database you want
				$qry = 'CREATE DATABASE ' . $dbToWrite;
				if(mysql_query($qry, $dbConnection)) {
					// now select it and write to it
					mysql_select_db($dbToWrite, $dbConnection);
					$selectQry = 'SELECT TABLE_NAME FROM '.$dbToWrite.'.tables WHERE TABLE_NAME = `'.$tables[0].'`';
					if(mysql_query($selectQry, $dbConnection) === false) {
						$newSelectQry = 'CREATE TABLE `'.$tables[0].'` ( `pageURL` varchar(80) NOT NULL, PRIMARY_KEY(pageURL), `title` varchar(100) default NULL, `author` varchar(100) default NULL, `keywords` text(2048) default NULL, `charset` varchar(100) default NULL, `description` text(4000) default NULL, `bodytext` longtext(100000) default NULL)';
						mysql_query($newSelectQry, $dbConnection);
					}
					$selectQry2 = 'SELECT TABLE_NAME FROM '.$dbToWrite.'.tables WHERE TABLE_NAME = `'.$tables[1].'`';
					if(mysql_query($selectQry2, $dbConnection) === false) {
						$newSelectQry2 = 'CREATE TABLE `'.$tables[1].'` ( `linkTo` varchar(100) NOT NULL, PRIMARY_KEY(linkTo), `numLinks` int(200) default NULL)';
						mysql_query($newSelectQry2, $dbConnection);
					}
					foreach($dataArray as $dataKey => $dataValue) {
						if ($dataKey != 'links') {
							$qry = 'INSERT INTO `'.$table[0].'` ('.$dataKey.') VALUE ('.$dataValue.')';
							mysql_query($qry, $dbConnection);
						}
						else {
							$linksArray = array();
							foreach($dataValue as $linkVal) {
								$tldlink = databaseControl::get_tld($linkVal);
								array_push($linksArray, $tldlink);
							}
							$linksList = implode($linksArray, ',');
							$qry = 'INSERT INTO `'.$table[1].'` ('.$dataKey.') VALUES ('.$linksList.')';
							mysql_query($qry, $dbConnection);
						}
					}
				}
				else {
					$returnVal = json_encode(array('1', '0'));
					echo $returnVal;
				}

			}
			else {
				// now select it and write to it
				mysql_select_db($dbToWrite, $dbConnection);
				$selectQry = 'SELECT TABLE_NAME FROM '.$dbToWrite.'.tables WHERE TABLE_NAME = `'.$tables[0].'`';
				if(mysql_query($selectQry, $dbConnection) === false) {
					$newSelectQry = 'CREATE TABLE `'.$tables[0].'` ( `pageURL` varchar(80) NOT NULL, PRIMARY_KEY(pageURL), `title` varchar(100) default NULL, `author` varchar(100) default NULL, `keywords` text(2048) default NULL, `charset` varchar(100) default NULL, `description` text(4000) default NULL, `bodytext` longtext(100000) default NULL)';
					mysql_query($newSelectQry, $dbConnection);
				}
				$selectQry2 = 'SELECT TABLE_NAME FROM '.$dbToWrite.'.tables WHERE TABLE_NAME = `'.$tables[1].'`';
				if(mysql_query($selectQry2, $dbConnection) === false) {
					$newSelectQry2 = 'CREATE TABLE `'.$tables[1].'` ( `linkTo` varchar(100) NOT NULL, PRIMARY_KEY(linkTo), `numLinks` int(200) default NULL)';
					mysql_query($newSelectQry2, $dbConnection);
				}
				foreach($dataArray as $dataKey => $dataValue) {
					if ($dataKey != 'links') {
						$qry = 'INSERT INTO `'.$table[0].'` ('.$dataKey.') VALUE ('.$dataValue.')';
						mysql_query($qry, $dbConnection);
					}
					else {
						$linksArray = array();
						foreach($dataValue as $linkVal) {
							$tldlink = databaseControl::get_tld($linkVal);
							array_push($linksArray, $tldlink);
						}
						$linksList = implode($linksArray, ',');
						$qry = 'INSERT INTO `'.$table[1].'` ('.$dataKey.') VALUES ('.$linksList.')';
						mysql_query($qry, $dbConnection);
					}
				}
			}
		}
		else {
			$returnVal = json_encode(array('1', '0');
			echo $returnVal;
		}
	}
	public function get_tld($url) {
		$hostname = parse_url($url, PHP_URL,HOST);
		if (strpos($hostname, "www") !== false) {
			$parts = explode('.', $hostname);
			array_pop($parts);
			$newurl = implode('.', $parts);
			return $newurl;
		}
		else {
			return $hostname;
		}
	}
}

// Get an array of the headers sent
$headers = apache_request_headers();


// Compare each header field we have to the ones we want; populate those we want
foreach ($headers as $header => $value) {
    if (databaseControl::$headerInput[$header]) {
    	// If the header we are looking at is an expected array, decode it from json and store it as an array
    	if (($header == "transportReplaceStart") || ($header == "transportReplaceLen")) {
    		$headerVal = json_decode($value, true);
    		databaseControl::setHeaderVal($header, $headerVal);
    	}
    	// Otherwise just get the string
    	else {
    		databaseControl::setHeaderVal($header, $value);
    	}
    }
}

// Fill in info from POST
databaseControl::setPostInfo("authName", $_POST["authName"]);
databaseControl::setPostInfo("userPass", $_POST["userPass"]);
databaseControl::setPostInfo("pageURL", $_POST["pageURL"]);
databaseControl::setPostInfo("dataPackage", json_decode($_POST["dataPackage"], true));

// Check if the user is authorized -- this returns 1 if true
$authorized = checkAuth(databaseControl::$headerInput["User-Agent"], databaseControl::$headerInput["passEncodeKey"], databaseControl::$postRequest["authName"], databaseControl::$postRequest["userPass"]);

// If authorization passes, go send all the data you need to send
if ($authorized == 1) {
	// First, get the reference key of each piece of data and pull its corresponding salt locations for conversion
	foreach (databaseControl::$postRequest["dataPackage"] as $dataNum => $dataContents) {
		// This function should trigger calls to finally post to the db
		databaseControl::getData(databaseControl::$headerInput["transportReplaceStart"][$dataNum], databaseControl::$headerInput["transportReplaceLen"][$dataNum], $dataContents);
	}
}
else {
	$returnVal = json_encode(array('0', '0');
	echo $returnVal;
}

function checkAuth ($headerAgent, $headerPassKey, $postAuthName, $postUserPass) {
	if (isset(databaseControl::$authInfoArray[$postAuthName])) {
		// allowed UA: $authInfoArray[$postAuthName][0] & plaintext pass [1]
		if ($headerAgent == databaseControl::$authInfoArray[$postAuthName][0]) {
			$ptPass = $headerPassKey . databaseControl::$authInfoArray[$postAuthName][1];
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