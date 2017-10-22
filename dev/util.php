<?php
	require_once $_SERVER['DOCUMENT_ROOT'] . '/kkdystrack/php/GLOBALS.php';
	require_once $_SERVER['DOCUMENT_ROOT'] . '/kkdystrack/php/viewer.php';
	require_once $_SERVER['DOCUMENT_ROOT'] . '/ext-api/google-api-php-client-2.2.0/vendor/autoload.php';
	require_once $_SERVER['DOCUMENT_ROOT'] . '/ext-api/google-api-php-client-2.2.0/vendor/google/apiclient-services/src/Google/Service/YouTube.php';

	/**
	 * Will make sure the user with this channel id is
	 * authenticated in the database. This WILL NOT set
	 * up the session for this user!
	 * @param string $user_id
	 */
	function verify_user_registered($user_id) 
	{
		// only do an api request if they aren't in the database, and the userid isn't null or empty
		if(/*!Viewer::checkUserIDExists($user_id) && */$user_id && $user_id != '') {
			$key = constant('YOUTUBE_DATA_API_KEY');
			$url = "https://www.googleapis.com/youtube/v3/channels?id=$user_id&part=snippet&key=$key";
			$response = json_decode(file_get_contents($url), true);
			$vw = Viewer::fromYT($response);
			$vw->writeToDB();
		}
		
		
		// ONE TIME RUN TEST - DO NOT ENABLE PERMANENTLY, SERVER KILLER!
// 		$users = json_decode(db_execRaw("SELECT user_id FROM fire_emblem_minigame WHERE user_id NOT IN (SELECT user_id FROM viewers)"))->data;
		
// 		foreach ($users as $u) {
// 			verify_user_registered($u->user_id);
// 		}
	}
	
	
	
	
	
	function defaultVal($test, $default) 
	{
	    return $test ? $test : $default;
	}