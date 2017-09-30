<?php
	require_once 'dbUtil.php';
	
	class Viewer{
		
		// All info fields
		var $username;
		var $userID;
		var $rupees;
		var $favSong;
		var $isAdmin;
		var $isBlacklisted;
		var $rupeeDiscount;
		var $freeRequests;
		var $loginBonusCount;
		var $watchtimeRank;
		var $staticRank;
		var $birthday;
		var $lastBdayWithdraw;
		var $songOnHold;
		
		/** fetch data from database based on userID */
		function __construct($uid) {
			$this->userID = $uid;
			$this->getByUserID($uid);
		}
		
		/** Empty constructor, for manually initialization */
		function __construct() {}
		
		
		function makeFromJson($vRaw) {
			$vRaw = json_decode($data);
				
			// Write all of the fields
			$this->username = $vRaw->username;
			$this->userID = $vRaw->userID;
			$this->rupees = $vRaw->rupees;
			$this->favSong = $vRaw->favSong;
			$this->isAdmin = $vRaw->isAdmin;
			$this->isBlacklisted = $vRaw->isBlacklisted;
			$this->rupeeDiscount = $vRaw->rupeeDiscount;
			$this->freeRequests = $vRaw->freeRequests;
			$this->loginBonusCount = $vRaw->loginBonusCount;
			$this->watchtimeRank = $vRaw->watchtimeRank;
			$this->staticRank = $vRaw->staticRank;
			$this->birthday = $vRaw->birthday;
			$this->lastBdayWithdraw = $vRaw->lastBdayWithdraw;
			$this->songOnHold = $vRaw->songOnHold;
		}
		
		
		function checkUserExists($uid) {
			$psChk = db_prepareStatement('SELECT 1 FROM viewers WHERE user_id=?');
			$psChk->bind_param('s', $this->userID);
			$psChk->bind_result($resChk);
			$psChk->fetch();
			
			return $resChk;
		}
		
		
		
		function getByUserID($uid) {
			$this->userID = $uid;
			
			// first, make sure they exist in the database
			if(!$resChk) { // record doesn't exist
				$this->hdlUserNotFound();
			}
			
			// get everything (except user id of course) from the database given user id
			$sqlSel = 'SELECT (' .
					'username, ' .
					'rupees, ' .
					'favorite_song, ' .
					'is_admin, ' .
					'is_blacklisted, ' .
					'rupee_discount, ' .
					'free_requests, ' .
					'login_bonus_count, ' .
					'watchtime_rank, ' .
					'static_rank, ' .
					'birthday, ' .
					'last_birthday_withdraw, ' .
					'song_on_hold) ' .
					'FROM viewers WHERE user_id=? LIMIT 1';
			
			
			$ps = db_prepareStatement($sqlSel);
			$ps->bind_param('s', $this->userID);
			$ps->execute();
			
			// bind the results to variables
			$ps->bind_result($this->username,
					$this->username,
					$this->rupees,
					$this->favSong,
					$this->isAdmin,
					$this->isBlacklisted,
					$this->rupeeDiscount,
					$this->freeRequests,
					$this->loginBonusCount,
					$this->watchtimeRank,
					$this->staticRank,
					$this->birthday,
					$this->songOnHold);
			
			$ps->fetch();
		}
		
		
		
		
		/**
		 * Runs when a userID isn't found in the database.
		 * TODO implement this
		 */
		function hdlUserNotFound() {}
		
		
		/**
		 * Writes this viewer to the database
		 */
		function writeToDB() {
			$sqlSel = 'REPLACE INTO viewers (' .
					'username, ' .
					'user_id, ' .
					'rupees, ' .
					'favorite_song, ' .
					'is_admin, ' .
					'is_blacklisted, ' .
					'rupee_discount, ' .
					'free_requests, ' .
					'login_bonus_count, ' .
					'watchtime_rank, ' .
					'static_rank, ' .
					'birthday, ' .
					'last_birthday_withdraw, ' .
					'song_on_hold) ' .
					'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);';
			$ps = db_prepareStatement($sqlSel);
			$ps->bind_param('ssisiidiisssss',
					$username,
					$user_id,
					$rupees,
					$favorite_song,
					$is_admin,
					$is_blacklisted,
					$rupee_discount,
					$free_requests,
					$login_bonus_count,
					$watchtime_rank,
					$static_rank,
					$birthday,
					$last_birthday_withdraw,
					$song_on_hold);
			$ps->execute();
		}
	}
	
	
	
	if($_SERVER['REQUEST_METHOD'] == 'POST' && $_POST['target_id'] == 'viewer') {
		$op = $_POST['target_op'];
		$data = $_POST['data'];
		
		if($op == 'get_by_uid') { // JSON dump the viewer at that ID
			$vwGet = new Viewer($data->userID);
			echo json_encode($vw, JSON_NUMERIC_CHECK | JSON_FORCE_OBJECT);
			
		} elseif ($op == 'write_to_db') { // build a new viewer from the POSTed data, write it to the database
			// Create from data
			$vw = new Viewer();
			$vRaw = json_decode($data);
			$vw->makeFromJson($vRaw);
			
			// write down
			$vw->writeToDB();
		}
	}
	
	
	
?>
