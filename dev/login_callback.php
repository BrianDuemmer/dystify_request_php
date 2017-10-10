<?php // authenticates the user, and gets their YT creds

	require_once 'GLOBALS.php';
	require_once 'viewer.php';
	require_once $_SERVER['DOCUMENT_ROOT'] . '/ext-api/google-api-php-client-2.2.0/vendor/autoload.php';
	require_once $_SERVER['DOCUMENT_ROOT'] . '/ext-api/google-api-php-client-2.2.0/vendor/google/apiclient-services/src/Google/Service/YouTube.php';

	session_start();
	
	$user_id_hash = $_COOKIE['user_id_hash'];
	
	$client = new Google_Client();
	$client->setAuthConfigFile(constant('OAUTH2_AUTH'));
	$client->setRedirectUri(constant('OAUTH2_CALLBACK'));
	$client->addScope(Google_Service_YouTube::YOUTUBE_READONLY);
	$client->setAccessType("offline");
	
	
	
	// first see if their cookie is a valid userid hash
	if (! isset($_GET['code']) && Viewer::checkUserExists($user_id_hash)) { 
		// load their data into a session variable
		$_SESSION['viewer'] = Viewer::withUIDHash($user_id_hash);
		
		
	} 
	elseif (!isset($_GET['code'])) { // cookie's not set and they're not coming back from auth, so do he auth
		$auth_url = $client->createAuthUrl();
		header('Location: ' . filter_var($auth_url, FILTER_SANITIZE_URL)); 
		
		
	} 
	else { // we are auth'ed and good to go
		$client->authenticate($_GET['code']);
		
		// now get associated channel info, and put that into the database, based on the userid hash (sha256)
		try {
			$youtube = new Google_Service_Youtube($client);
			$vw = Viewer::fromYT($youtube);
			$vw->writeToDB();
			$_SESSION['viewer'] = $vw;
			
			// set the auth cookie; they're in. Have it last a week
			setcookie('user_id_hash', $vw->userIDHash, time()+(3600 * 24 * 7), '/');
			
		} 
		catch(Exception $e) {
			die(sprintf('<p>A server error occurred: <code>%s</code></p>', htmlspecialchars($e->getMessage())));
		}
		
		
		// go back to the main page
		$redirect_uri = 'https://' . $_SERVER['HTTP_HOST'] . '/songrequests';
		header('Location: ' . filter_var($redirect_uri, FILTER_SANITIZE_URL));
		
	}
?>






