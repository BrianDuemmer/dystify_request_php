<?php
// make sure this user's session is running, then dededestroy it
	session_start();
	session_destroy();
	$_SESSION = array();
	setcookie('session_id', '', time()-10000, '/'); // delete the id cookie
	header('Location: /kkdystrack/php/login.php'); // TODO direct to homepage after testing
?>
