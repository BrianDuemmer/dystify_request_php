<?php 	session_start();?>
<!doctype html>
<html>
<head>
    <title>auth test</title>
</head>
<body>
<?php



	function refresh_auth($client) {
		$state = mt_rand();
		$client->setState($state);
		$_SESSION['yt_state'] = $state;
		
		$authUrl = $client->createAuthUrl();
		echo <<<END
  <h3>Authorization Required</h3>
  <p>You need to <a href="$authUrl">authorise access</a> before proceeding.<p>
END;
	}
	
	require_once $_SERVER ['DOCUMENT_ROOT'] . '/kkdystrack/php/GLOBALS.php';
	
	// include the stuff
	require_once $_SERVER['DOCUMENT_ROOT'] . '/ext-api/google-api-php-client-2.2.0/vendor/autoload.php';
	require_once $_SERVER['DOCUMENT_ROOT'] . '/ext-api/google-api-php-client-2.2.0/src/Google/Client.php';
	require_once $_SERVER['DOCUMENT_ROOT'] . '/ext-api/google-api-php-client-2.2.0/vendor/google/apiclient-services/src/Google/Service/YouTube.php';
	
	// auth stuff
	$client = new Google_Client();
	$client->setAuthConfig(constant('OAUTH2_AUTH'));
	$client->addScope(Google_Service_YouTube::YOUTUBE_READONLY);
	$client->setRedirectUri(constant('OAUTH2_CALLBACK'));
	$client->setAccessType("offline");
	
	// webpage body
	echo 'started...<br/>';
	
	// object to do all the api stuff
	$youtube = new Google_Service_Youtube($client);
	
	if(isset($_GET['code'])) {
		echo 'GET[code] set<br/>';
		if(strval($_SESSION['yt_state']) !== strval($_GET['state'])) {
			die('Session state did not match');
		}
		
		$client->authenticate($_GET['code']);
		$_SESSION['yt_token'] = $client->getAccessToken();
		echo 'Set yt_token session var<br/>';
	}
	
	if(isset($_SESSION['yt_token'])) {
		$client->setAccessToken($_SESSION['yt_token']);
		// echo '<code>token: ' . $_SESSION['yt_token'] . '</code><br/>';
	}
	
	// make sure we got the access token correctly
	echo 'trying to get access token <br/>';
	$token = $client->getAccessToken();
	print_r('token: <code>' .$token. '</code><br/>');
	if($token) {
		try {
			$currChannel = $youtube->channels->listChannels('snippet', array('mine'=>'true'));
			print_r('user_id: ' .$currChannel['items']['0']['id'] . '<br/><br/>');
			print_r('username: ' .$currChannel['items']['0']['snippet']['title'] . '<br/><br/>');
		} catch(Exception $e) {
			echo sprintf('<p>A service error occurred: <code>%s</code></p>', htmlspecialchars($e->getMessage()));
			refresh_auth($client);
		}
		
		$_SESSION['yt_token'] = $client->getAccessToken();
	} else {
		refresh_auth($client);
	}
		
	print_r($_SESSION);
	
?>
</body>
</html>














