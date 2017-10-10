<?php	
	require_once $_SERVER['DOCUMENT_ROOT'] . '/kkdystrack/php/dbUtils.php';
	require_once $_SERVER['DOCUMENT_ROOT'] . '/kkdystrack/php/viewer.php';
	
	session_start();
	$user_id_hash = $_COOKIE['user_id_hash'];
	
	// Attempt to access the viewer data based on this info
	$viewerExists = Viewer::checkUserExists($user_id_hash);
	if($viewerExists) { // if they're cookie matches a database entry, they're good to go
		$viewer = Viewer::withUIDHash($user_id_hash);
		$_SESSION['viewer'] = $viewer;
	} else { // either the cookie is expired, or their record's don't exist, so they need to auth
		
	}
?>
