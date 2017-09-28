<?php
require_once $_SERVER ['DOCUMENT_ROOT'] . '/dev/GLOBALS.php';

if ($_SERVER ['REQUEST_METHOD'] == "POST") {
	// fetch post parameters
	$dbHost = constant ( 'DB_DYSTRACK_HOST' );
	$dbUser = constant ( 'DB_DYSTRACK_USER' );
	$dbPass = constant ( 'DB_DYSTRACK_PASS' );
	$dbDatabase = constant ( 'DB_DYSTRACK_NAME' );
	$dbStatement = clean ( $_POST ['sql'] );
	
	// fetch query
	$db = mysqli_connect ( $dbHost, $dbUser, $dbPass, $dbDatabase ) or die ( 'failed to connect to database: ' . mysqli_error ( $db ) );
	mysqli_select_db ( $db, $dbDatabase );
	$result = mysqli_query ( $db, $dbStatement );
	
	//$jsonRes->cols[0] = "";
	$jsonRes = new \stdClass();
	$jsonRes->data = [];
	$jsonRes->cols = [];
	
	// convert to json
	if ($result->num_rows > 0) {
		
		$i = 0;
		while ( $row = $result->fetch_assoc () ) {
			$jsonRes->data [$i] = $row;
			$i ++;
		}
	}
	
	// get column names
	foreach ($result->fetch_fields() as $col) {
		$jsonRes->cols[] = $col->name;
	}
	
	echo json_encode ( $jsonRes );
} else {
	echo "ERRROR! Method was not post!";
}
function clean($data) {
	$data = trim ( $data );
	return $data;
}
?>
