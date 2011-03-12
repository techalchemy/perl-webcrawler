<?php
/*
What it does:
authenticate: User_Agent from headers, passEncodeKey from headers, authName / userPass from form post
	After this, set authFlag to 1 (in returnArray)
Does authentication on the requesting client.  If the client is authenticated, then:
	1) Remove the random shit from the serialized data
	2) Look at urgency before passing info along
	3) Break info down for table // title, author, links, charset, keywords, description, bodytext
		a) Unserialize
		b) Construct MYSQL query to post this info -- extract pageURL as key, values = title, author, keywords, charset, description, links, bodytext(blob?)
		c) Another MySQL query to keep track of linking (make 1 table per site?)
	4) return a serialized, encoded array of 1, 1 on success

foreach example 3: key and value

$a = array(
    "one" => 1,
    "two" => 2,
    "three" => 3,
    "seventeen" => 17
);

foreach ($a as $k => $v) {
    echo "\$a[$k] => $v.\n";
}

foreach example 4: multi-dimensional arrays
$a = array();
$a[0][0] = "a";
$a[0][1] = "b";
$a[1][0] = "y";
$a[1][1] = "z";

foreach ($a as $v1) {
    foreach ($v1 as $v2) {
        echo "$v2\n";
    }
}

Format:
	Passed in HEADERS:
		UserAgent from config file (User_Agent)
		JSON sequential order of transfer start value bits (from array) (transportReplaceStart)
		JSON sequential order of injected string length (from array) (transportReplaceLen)
		Password salt value (passEncodeKey)
		Urgency Flag (urgencyFlag)

	Passed via HTTP POST to serverLocation from Config:
		Authenticating Username (authName)
		Encrypted password (userPass)
		pageURL
		JSON sequential order of randomized, serialized, JSON former data structures (dataPackage)
*/
// connect to DB here
// use PCONNECT function
// compile list of accepted UA's, authnames, passwords

$headers = apache_request_headers();
$transReplaceBegin = array();
$transReplaceLen = array();
$dataPkgArray = array();
$headerInput = array(
	"User-Agent" => '',
	"passEncodeKey" => '',
	"transportReplaceStart" => '', // make this an array (is this json?)
	"transportReplaceLen" => '', // make this an array (is this json)
	"urgencyFlag => ''
);
$postRequest = array(
	"authName" => '',
	"userPass" => '',
	"pageURL" => '',
	"dataPackage" => '' //this is an array (is this json?)
);
$acceptedUA = array("
$acceptedAuthInfo = array(

);
foreach ($headers as $header => $value) {
    if ($headerInput[$header]) {
    	$headerInput[$header] = $value;
    }
}
$postRequest["authName"] = $_POST["authName"];
$postRequest["userPass"] = $_POST["userPass"];
$postRequest["pageURL"] = $_POST["pageURL"];
$postRequest["dataPackage"] = $_POST["dataPackage"];
$authorized = checkAuth($headerInput["User-Agent"], $headerInput["passEncodeKey"], $postRequest["authName"], $postRequest["userPass"]);
function authorized ($headerAgent, $headerPassKey, $headerAuthName, $headerUserPass) {

return 1/0
}
?>