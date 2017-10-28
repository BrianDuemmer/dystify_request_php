<?php
	require_once $_SERVER['DOCUMENT_ROOT'] . '/kkdystrack/php/inc/dbUtil.php';
	require_once $_SERVER['DOCUMENT_ROOT'] . '/kkdystrack/php/inc/util.php';
	
	session_start();
	
	
	function execAndFormatOutput(mysqli_stmt $ps) 
	{				
		if($ps->execute()) {
			
			echo '11<br/>';
			
			$ps->bind_result(
					$song_id,
					$name,
					$ost,
					$franchise,
					$length,
					$cost,
					$rating_pct,
					$rating_num,
					$olderthan,
					$times_played);
			
			echo '25<br/>';
			
			$res = new \stdClass();
			$res->data = [];
			$res->cols = [
				"song_id",
				"song_name",
				"ost_name",
				"franchise_name",
				"song_length",
				"cost",
				"rating_pct",
				"rating_num",
				"last_play",
				"times_played"
			];
			
			print_r($ps);
			
			while ($ps->fetch()) {
				echo '45<br/>';
				$row = new \stdClass();
				
				$row->song_id = $song_id;
				$row->name = $name;
				$row->ost = $ost;
				$row->franchise = $franchise;
				$row->length = $length;
				$row->cost = $cost;
				$row->rating_pct = $rating_pct;
				$row->rating_num = $rating_num;
				$row->olderthan = $olderthan;
				$row->times_played = $times_played;
				
				$res->data[] = $row;
			}
			
			return json_encode($res);
		} else {
			die(sprintf('Error searching songs! <br/> %s', $ps->error));
		}
	}
	
	
	
	
	if($_SERVER['REQUEST_METHOD'] == 'POST') {
		
		$db = db_verifyConnected();
		$name_q = $db->real_escape_string($_POST['name_query']);
		$ost_q = $db->real_escape_string($_POST['ost_query']);
		$franchise_q = $db->real_escape_string($_POST['franchise_query']);
		$olderthan = $db->real_escape_string($_POST['olderthan']);
		$len_min = $db->real_escape_string($_POST['len_min']);
		$len_max = $db->real_escape_string($_POST['len_max']);
		$min_rating = $db->real_escape_string($_POST['min_rating']);
		
		$user_id = $_SESSION['user_id']/*$db->real_escape_string("fuck you kid you're a dick")*/;
		
		// make safe defaults
		$name_q = defaultVal($name_q, '');
		$ost_q = defaultVal($ost_q, '');
		$franchise_q = defaultVal($franchise_q, '');
		$olderthan = defaultVal($olderthan, gmdate('Y-m-d H:i:s'));
		$len_min = defaultVal($len_min, 0);
		$len_max = defaultVal($len_max, 9999999999999);
		$min_rating = defaultVal($min_rating, -2);
		$user_id = defaultVal($user_id, 'ERR_DEFAULT_USER');
		
		// pull number of results to draw from the settings table
		$num_results = json_decode(db_execRaw("SELECT F_READ_NUM_PARAM('song_search_num_results', 10) AS n"))->data[0]->n;
		
		
		$sql = "CALL P_GET_SONGS_SEARCH(
				'$name_q', 
				'$ost_q', 
				'$franchise_q', 
				'$olderthan', 
				$len_min, 
				$len_max,
				$min_rating,
				'$user_id',
				$num_results)";
// 		echo $sql;
				
		echo db_execRaw($sql);
 		print_r($db->error_list);
 		print_r($_POST);
 		echo $olderthan;
	}






