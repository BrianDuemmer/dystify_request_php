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
		var $userIDHash;
		
		function __construct() {}
		
		/** initializes using a user ID, gets other stuff from the database */
		static function withUIDHash($userIDHash) {
			$impl = new Viewer();
			$impl->getByUserIDHash($userIDHash);
			return $impl;
		}
		
		
		/** Creates a new user entry by querying the YouTube API */
		static function fromYT($youtube) 
		{
			try {
				$currChannel = $youtube->channels->listChannels('snippet', array('mine'=>'true'));
				
				// get the channel info
				$userID = $currChannel['items']['0']['id'];
				$username = $currChannel['items']['0']['snippet']['title'];
				$userIDHash = hash('sha256', $userID);
				
				// try to pull an existing user with this info, or make a new one
				$impl = Viewer::withUIDHash($userIDHash);
				$impl->userID = $userID;
				$impl->username = $username;
				$impl->userIDHash = $userIDHash;
				
				return $impl;
			} catch(Exception $e) { // there was some issue with getting YT info
				return NULL;
			}
			
		}

		
		
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
		
		/** Returns true if the user exists in the database, false if they don't, and null if $uidh is null */
		static function checkUserExists($uidh) {
			if(isset($uidh)) {
				$ps = db_prepareStatement('SELECT 1 FROM viewers WHERE user_id_hash=?');
				$ps->bind_param('s', $uidh);
				$ps->execute();
				$ps->bind_results($ret);
				$ps->fetch();
				
				return isset($ret);
			}
		}
		
		
		
		
		
		function getByUserIDHash($uidh) {		
			// first, make sure they exist in the database
			if(!Viewer::checkUserExists($uidh)) { // record doesn't exist, just leave
				$this->hdlUserNotFound();
				return;
			}
			
			// get everything (except user id of course) from the database given user id
			$sqlSel = 'SELECT ' .
					'user_id, ' .
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
					'song_on_hold ' .
					'user_id_hash ' .
					'FROM viewers WHERE user_id_hash=? LIMIT 1';
			
			$ps = db_prepareStatement($sqlSel);	
			$ps->bind_param('s', $uidh);
			$ps->execute();
			
			// bind the results to variables
			$ps->bind_result($this->userID,
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
					$this->lastBdayWithdraw,
					$this->songOnHold,
					$this->userIDHash);
			
			$ps->fetch();
		}
		
		
		
		
		/**
		 * Runs when a userID isn't found in the database.
		 * TODO implement this
		 */
		function hdlUserNotFound() {
			$this->userID = null;
		}
		
		
		
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
					'song_on_hold ' . 
					'user_id_hash) ' .
					'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);';
			$ps = db_prepareStatement($sqlSel);
			$ps->bind_param('ssisiidiissssss',
					$this->username,
					$this->userID,
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
					$this->lastBdayWithdraw,
					$this->songOnHold,
					$this->userIDHash);
			$ps->execute();
		}
	}
	
	
	
	if($_SERVER['REQUEST_METHOD'] == 'POST' && $_POST['target_id'] == 'viewer') {
		$op = $_POST['target_op'];
		$data = json_decode($_POST['data']);
		
		if($op == 'get_by_uid') { // JSON dump the viewer at that ID
			$vwGet = Viewer::withUID($data->userID);
			echo json_encode($vwGet, JSON_NUMERIC_CHECK | JSON_FORCE_OBJECT);
			
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
