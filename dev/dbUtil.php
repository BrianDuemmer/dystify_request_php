<?php
require_once $_SERVER ['DOCUMENT_ROOT'] . '/dev/GLOBALS.php';

// connection to the database
$connection;

// this statement lets us handle both function calls and post requests
if ($_SERVER ["REQUEST_METHOD"] == "POST" && $_POST ['target_id'] == 'db') {
	$sql = db_clean ( $_POST ['data'] [sql] );
	$results = db_execRaw ( $sql );
	echo $results;
}

/**
 * will make sure we are connected, a la singleton
 */
function db_verifyConnected() {
	if (! isset ( $GLOBALS ['connection'] )) {
		$dbHost = constant ( 'DB_DYSTRACK_HOST' );
		$dbUser = constant ( 'DB_DYSTRACK_USER' );
		$dbPass = constant ( 'DB_DYSTRACK_PASS' );
		$dbDatabase = constant ( 'DB_DYSTRACK_NAME' );
		
		// connect and select table
		$db = mysqli_connect ( $dbHost, $dbUser, $dbPass, $dbDatabase ) or die ( 'failed to connect to database' );
		
		if (isset ( $db )) {
			mysqli_select_db ( $db, $dbDatabase );
		}
		$GLOBALS ['connection'] = $db;
	}
	
	return $GLOBALS ['connection'];
}








/**
 * Execute the SQL statement on the dystrack database
 *
 * @return the resultset from the statement
 */
function db_execRaw($dbStatement) {
	$db = db_verifyConnected ();
// 	echo var_dump($db).'\n';
// 	echo var_dump($dbStatement).'\n';
	
	$result = mysqli_query ( $db, $dbStatement );
	
	// $jsonRes->cols[0] = "";
	$jsonRes = new \stdClass ();
	$jsonRes->data = [ ];
	$jsonRes->cols = [ ];
	
	if ($result != null) {
		// convert to json
		if ($result->num_rows > 0) {
			
			$i = 0;
			while ( $row = $result->fetch_assoc () ) {
				$jsonRes->data [$i] = $row;
				$i ++;
			}
		}
		
		// get column names
		foreach ( $result->fetch_fields () as $col ) {
			$jsonRes->cols [] = $col->name;
		}
	} else {
		//echo 'foo '.mysqli_error($db);
	}
	
	return json_encode ( $jsonRes );
}










function db_prepareStatement($sql) {
	$db = db_verifyConnected ();
	$ps = mysqli_prepare ( $db, $sql );
	
	return $ps;
}

/**
 * cleans any whitespace and bad stuf out of the input
 */
function db_clean($data) {
	$data = trim ( $data );
	return $data;
}

?>