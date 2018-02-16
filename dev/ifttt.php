<?php
	require_once $_SERVER['DOCUMENT_ROOT'] . '/kkdystrack/php/inc/GLOBALS.php';
	require_once $_SERVER['DOCUMENT_ROOT'] . '/kkdystrack/php/inc/dbUtil.php';
	require_once $_SERVER['DOCUMENT_ROOT'] . '/kkdystrack/php/inc/viewer.php';
	require_once $_SERVER['DOCUMENT_ROOT'] . '/kkdystrack/php/inc/util.php';
	
	function addToIFTTTLog($data, $isErr) {
		$tbl = $isErr ? 'ifttt_failed' : 'ifttt_log';
		$sql = "INSERT INTO " .$tbl. " (user_id, command, time, response) VALUES(?, ?, UNIX_TIMESTAMP(), ?)";
		$ps = db_prepareStatement($sql);
		$ps->bind_param('sss', $data->user_id, $data->command, $data->response);
		
		print_r($data);
		
		if(!$ps->execute()) {
			die("An error occured attempting to write the ifttt transaction to the database");
		}
	}
	
	
	if($_SERVER['REQUEST_METHOD'] == 'POST') {
		$body = file_get_contents('php://input');
// 		fwrite(fopen($_SERVER['DOCUMENT_ROOT'] . '/kkdystrack/body', "rw"), $body);
        file_put_contents("body", $body);
		// parse the body of the request to an object
		$entries =explode('<>', $body);
		$response = substr($entries[2], stripos($entries[2], ":")+1);
		// $response = explode(":", $entries[2])[1];
		
		$user_id_tmp = explode('(', $response);
		$user_id = explode(')', end($user_id_tmp))[0];
		
		$json_raw = "{".$entries[0].", ".$entries[1].", \"user_id\":\"".$user_id."\", \"response\":".$response."}";
		echo $json_raw . "\n";
		
		$data = json_decode($json_raw);
		
		$isErr = !($data->key == constant('IFTTT_KEY') &&
				isset($data->user_id) &&
				isset($data->command));
		
		addToIFTTTLog($data, $isErr);
		
		
		// Handlers, to do extra things with certain commands
		
		if(!$isErr) { // transaction good, acknowledge
			verify_user_registered($data->user_id);
			$count = filter_var($data->command, FILTER_SANITIZE_NUMBER_INT);
			
			// Dystrack handlers
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
				
				
			// General minigame handlers
			} elseif(strpos($data->command, 'join')) { // for the team events 
				$team = strtolower(substr($data->command, 6, 1));
				if(stripos("*mlyp", $team)) {
				    $event = "MarioParty";
				}
				elseif (stripos("*es", $team)) {
				    $event = "Sonic";
				} else {
				    $event = "UNKNOWN_EVENT";
				}
				
				echo $team;
				$sql = "REPLACE INTO team_minigame (user_id, team, event) VALUES(?, ?, ?)";
				$ps = db_prepareStatement($sql);
				$ps->bind_param('sss', $data->user_id, $team, $event);
				if(!$ps->execute()) {
				    die(sprintf("error processing team entry %s", $ps->error));
				}
  
			}
			
		}
	}

	
	
	
	
	
	
	