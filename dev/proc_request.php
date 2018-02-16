<?php
	require_once $_SERVER['DOCUMENT_ROOT'] . '/kkdystrack/php/inc/dbUtil.php';
	session_start();
	if($_SERVER['REQUEST_METHOD'] == 'POST') {
		// get the params, set to defaults if not specified
		$song_id = $_POST['song_id'];
		$queue_id = $_POST['queue_id'] ? $_POST['queue_id'] : 'main';
		$user_id = $_SESSION['user_id']/* ? $_SESSION['user_id'] : 'UC7zzv22da8gxm9IqxBbXAJA'*/; // remove this ternary once done with testing           
		
// 		echo $song_id.'   '.$queue_id.'   '.$user_id;
// 		echo'<br/><br/>';
		
		// add the song
		$ps = db_prepareStatement("CALL P_ADD_SONG(?, ?, ?, @cost, @eta)");
		$ps->bind_param('sss',
				$user_id,
				$song_id,
				$queue_id);
		$ps->execute();
		print_r($ps->error);
// 		print_r(db_verifyConnected()->error_list);
		$ps->close();
		
		// get the output variables
		$res_raw = json_decode(db_execRaw("SELECT @cost AS cost, @eta AS eta"));
		$res_clean = $res_raw->data[0];
		echo json_encode($res_clean);
	}