<?php
	if ($_SERVER ['REQUEST_METHOD'] == "POST") {
		// fetch post parameters
		$dbHost = clean ( $_POST ['dbHost'] );
		$dbUser = clean ( $_POST ['dbUser'] );
		$dbPass = clean ( $_POST ['dbPass'] );
		$dbDatabase = clean ( $_POST ['dbDatabase'] );
		$dbStatement = clean ( $_POST ['dbStatement'] );
		
		// fetch query
		// echo $dbHost . ' - ' . $dbUser . ' - ' . $dbPass ;
		
		$db = mysqli_connect ( $dbHost, $dbUser, $dbPass, $dbDatabase ) or die ( 'failed to connect to database: ' . mysqli_error ( $db ) );
		mysqli_select_db ( $db, $dbDatabase );
		$result = mysqli_query ( $db, $dbStatement );
		
		$jsonRes = Array (
				"No Resultset" 
		);
		
		// convert to json
		if ($result->num_rows > 0) {
			
			$i = 0;
			while ( $row = $result->fetch_assoc () ) {
				$jsonRes [$i] = $row;
				$i ++;
			}
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
