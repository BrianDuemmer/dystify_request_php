<?php
	require_once $_SERVER['DOCUMENT_ROOT'] . '/kkdystrack/php/GLOBALS.php';
	require_once $_SERVER['DOCUMENT_ROOT'] . '/kkdystrack/php/dbUtil.php';
	require_once $_SERVER['DOCUMENT_ROOT'] . '/kkdystrack/php/viewer.php';
	require_once $_SERVER['DOCUMENT_ROOT'] . '/kkdystrack/php/util.php';
	
	function addToIFTTTLog($data, $isErr) {
		$tbl = $isErr ? 'ifttt_failed' : 'ifttt_log';
		$sql = "INSERT INTO " .$tbl. " (user_id, command, time) VALUES(?, ?, UTC_TIMESTAMP())";
		$ps = db_prepareStatement($sql);
		$ps->bind_param('ss', $data->user_id, $data->command);
		
		print_r($data);
		
		if(!$ps->execute()) {
			die("An error occured attempting to write the ifttt transaction to the database");
		}
	}
	
	
	if($_SERVER['REQUEST_METHOD'] == 'POST') {
		$body = file_get_contents('php://input');
		
		// parse the body of the request to an object
		$entries =explode('<>', $body);
		$response = explode(":", $entries[2])[1];
		
		$user_id_tmp = explode('(', $response);
		$user_id = explode(')', end($user_id_tmp))[0];
		
		$json_raw = "{".$entries[0].", ".$entries[1].", \"user_id\":\"".$user_id."\"}";
		$data = json_decode($json_raw);
		
		$isErr = !($data->key == constant('IFTTT_KEY') &&
				isset($data->user_id) &&
				isset($data->command));
		
		addToIFTTTLog($data, $isErr);
		if(!$isErr) { // transaction good, acknowledge
			verify_user_registered($data->user_id);
			$count = filter_var($data->command, FILTER_SANITIZE_NUMBER_INT);
			
			if(strpos($data->command, 'transfer')) { // rupee transfer
				echo $count;
				$vw = Viewer::withUID($data->user_id);
				$vw->rupees += $count;
				$vw->writeToDB();
				
			} elseif(strpos($data->command, 'rate')) { // rate song
				$rating = $count / 5;
				$sql = "CALL P_ADD_RATING(?, ?)";
				$ps = db_prepareStatement($sql);
				$ps->bind_param('sd', $data->user_id, $rating);
				if(!$ps->execute()) {
					die(sprintf("error processing rating %s", $ps->error));
				}
			} elseif(strpos($data->command, 'join')) { // for the fire emblem event minigame
				$isNohr = strtolower(str_split($data->command)[6]) == "n";
				echo $isNohr;
				$sql = "REPLACE INTO fire_emblem_minigame (user_id, is_nohr) VALUES(?, ?)";
				$ps = db_prepareStatement($sql);
				$ps->bind_param('si', $data->user_id, $isNohr);
				$ps->execute();
			}
		}
	}

	
	
	
	
	
	
	