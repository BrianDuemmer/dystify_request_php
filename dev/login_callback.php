<?php // authenticates the user, and gets their YT creds

	require_once $_SERVER['DOCUMENT_ROOT'] . '/kkdystrack/php/inc/GLOBALS.php';
	require_once $_SERVER['DOCUMENT_ROOT'] . '/kkdystrack/php/inc/viewer.php';
	require_once $_SERVER['DOCUMENT_ROOT'] . '/ext-api/google-api-php-client-2.2.0/vendor/autoload.php';
	require_once $_SERVER['DOCUMENT_ROOT'] . '/ext-api/google-api-php-client-2.2.0/vendor/google/apiclient-services/src/Google/Service/YouTube.php';
	
	
	
	session_start();

	$client = new Google_Client();
	$client->setAuthConfigFile(constant('OAUTH2_AUTH'));
	$client->setRedirectUri(constant('OAUTH2_CALLBACK'));
	$client->addScope(Google_Service_YouTube::YOUTUBE_READONLY);
	$client->setAccessType("offline");
	
	
	if (!isset($_GET['code'])) { //they're not coming back from auth, so do the auth
		$auth_url = $client->createAuthUrl();
		header('Location: ' . filter_var($auth_url, FILTER_SANITIZE_URL)); 
		
		
	} 
	else { // we are auth'ed and good to go
		$client->authenticate($_GET['code']);
		// now get associated channel info, and put that into the database, based on the userid hash (sha256)
		try {
			$youtube = new Google_Service_Youtube($client);
			$fetch = array('mine'=>'true');
			$response = $youtube->channels->listChannels('snippet', $fetch);
			$vw = Viewer::fromYT($response);
			$vw->writeToDB();
			$_SESSION['session_id'] = $vw->sessionID;
			$_SESSION['user_id'] = $vw->userID;
			
			// set the auth cookie; they're in. Have it last a week
			setcookie('session_id', $vw->sessionID, time()+(3600 * 24 * 7), '/');
			
		} 
		catch(Exception $e) {
			die(sprintf('<p>A server error occurred: <code>%s</code></p>', htmlspecialchars($e->getMessage())));
		}
		
		
		// go back to the main page
		$redirect_uri = 'https://' . $_SERVER['HTTP_HOST'] . '/kkdystrack/php/request_page.php';
		header('Location: ' . filter_var($redirect_uri, FILTER_SANITIZE_URL));
		
	}
	
?>






