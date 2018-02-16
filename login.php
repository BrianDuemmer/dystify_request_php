<?php	
	require_once $_SERVER['DOCUMENT_ROOT'] . '/kkdystrack/php/viewer.php';
	
	/** 
	 * something along the lines of:
	 * $USER, $RUPEES rupees $pfp <a>Sign out...</a>
	 * */
	function formatLoggedInBox() {
		$vw = Viewer::withUIDHash($_SESSION['user_id_hash']);
		echo $vw->username .', '. $vw->rupees .' rupees <img src="' .
			$vw->pfpAddress . 
			'" alt="pfp" style="width:48px;height:48px;"></img> ' . 
			'<a href="' .
			'https://' . $_SERVER['HTTP_HOST'] . '/kkdystrack/php/logout.php' .
			'" >Sign out...</a>';
	}
	
	
	
	/**
	 * something along the lines of:
	 * <a>Sign in with YouTube</a> to request songs
	 * */
	function formatLoggedOutBox() {
		echo '<a href="' . 
				'https://' . $_SERVER['HTTP_HOST'] . '/kkdystrack/php/login_callback.php" >' .
				'Sign in with YouTube</a> to request songs!';
	}
	
	
	
	
	session_start();
	
	// Session's already loaded
	if(isset($_SESSION['user_id_hash'])) {
		formatLoggedInBox();
		
	} // session's not loaded yet
	else {
		$user_id_hash = $_COOKIE['user_id_hash'];
		$vw = Viewer::withUIDHash($userIDHash);
		$viewerExists = $vw->userID != '';
		
		if($viewerExists) { // cookie is good, so we can load the session from there
			$_SESSION['user_id_hash'] = $user_id_hash;
			$_SESSION['user_id'] = $vw->userID;
			formatLoggedInBox();
			
		} // not logged in, prompt for login
		else {
			formatLoggedOutBox();
		}
	}
	
	// echo '<br/><pre>'; print_r($_SESSION); echo '</pre>';
?>

</div>