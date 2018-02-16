<?php
	require_once $_SERVER['DOCUMENT_ROOT'] . '/kkdystrack/php/inc/dbUtil.php';
	
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
		var $sessionID;
		var $pfpAddress;
		
		function __construct() {
			$this->birthday = '';
			$this->favSong = '';
			$this->freeRequests = 0;
			$this->isAdmin = 0;
			$this->isBlacklisted = 0;
			$this->lastBdayWithdraw = '';
			$this->loginBonusCount = 0;
			$this->pfpAddress = '';
			$this->rupeeDiscount = 0.0;
			$this->rupees = 0;
			$this->songOnHold = '';
			$this->staticRank = '';
			$this->userID = '';
			$this->sessionID = 0;
			$this->username = '';
			$this->watchtimeRank = '';
		}
		
		/** initializes using a user ID hash, gets other stuff from the database */
		static function withSessionID($session_id) {
			$impl = new Viewer();
			$impl->getBySessionID($session_id);
			return $impl;
		}
		
		
		
		/** initializes using a user ID, gets other stuff from the database */
		static function withUID($userID) {
			$ps = db_prepareStatement("SELECT session_id FROM viewers WHERE user_id=?");
			$ps->bind_param('s', $userID);
			$ps->execute();
			$ps->bind_result($id);
			$ps->fetch();
			$ps->close();
			
			$impl = new Viewer();
			$impl->getBySessionID($id);
			$impl->sessionID = $id;
			$impl->userID = $userID;
			return $impl;
		}
		
		
		/** Creates a new user entry by querying the YouTube API. */
		static function fromYT($response) 
		{
			try {
				// get the channel info
				$userID = $response['items']['0']['id'];
				$username = $response['items']['0']['snippet']['title'];
				$pfpAddress = $response['items']['0']['snippet']['thumbnails']['high']['url'];
				
				// try to pull an existing user with this info, or make a new one
				if(!Viewer::checkUserIDExists($userID)) {
					
					$id = json_decode(db_execRaw("SELECT F_GET_NEW_SESSION_ID() AS id"))->data[0]->id;
					$impl = Viewer::withSessionID($id);
					$impl->userID = $userID;
					$impl->username = $username;
					$impl->sessionID = $id;
					$impl->pfpAddress = $pfpAddress;
					
				} else { // viewer exists, use that. Just update stuff
					$ps = db_prepareStatement("UPDATE viewers SET username=?, pfp_address=? WHERE user_id=?");
					$ps->bind_param('sss', $username, $pfpAddress, $userID);
					$ps->execute();
					$impl = Viewer::withUID($userID);
				}
				
				return $impl;
			} catch(Exception $e) { // there was some issue with getting YT info
				die(sprintf('Error allocating viewer object from YouTube response:%s', htmlspecialchars($e->getMessage())));          
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
			$this->sessionID = $vRaw->sessionID;
			$this->pfpAddress = $vRaw->pfpAddress;
		}
		
		
		
		
		
		/** Returns true if the user exists in the database, false if they don't, and null if $uid is null */
		static function checkUserIDExists($uid) {
			if(isset($uid)) {
				$ps = db_prepareStatement('SELECT 1 FROM viewers WHERE user_id=?');
				$ps->bind_param('s', $uid);
				$ps->execute();
				$ps->bind_result($ret);
				$ps->fetch();
				
				return isset($ret);
			}
		}
		
		
		
		
		/** Returns true if the user exists in the database, false if they don't, and null if $id is null */
		static function checkSessionIDExists($id) {
			if(isset($id)) {
				// (false)->go_fuck_yourself(); debug
				$ps = db_prepareStatement('SELECT 1 FROM viewers WHERE session_id=?');
				print_r(mysqli_error(db_verifyConnected()));
				$ps->bind_param('i', $id);
				$ps->execute();
				$ps->bind_result($ret);
				$ps->fetch();
		
				return isset($ret);
			}
		}
		
		
		
		
		
		
		function getBySessionID($sesion_id) {		
			// first, make sure they exist in the database
			if(!Viewer::checkSessionIDExists($sesion_id)) { // record doesn't exist, just leave
				$this->hdlUserNotFound();
				return;
			}
			
			// get everything from the database given user id
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
					'song_on_hold, ' .
					'session_id, ' .
					'pfp_address ' .
					'FROM viewers WHERE session_id=? LIMIT 1';
			
			$ps = db_prepareStatement($sqlSel);	
			$ps->bind_param('i', $sesion_id);
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
					$this->sessionID,
					$this->pfpAddress);
			
			$ps->fetch();
		}
		
		
		
		
		
		
		/**
		 * Runs when a userID isn't found in the database.
		 * TODO implement this
		 */
		function hdlUserNotFound() {
			$this->userID = null;
			//echo 'user not found';
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
					'song_on_hold, ' . 
					'pfp_address, ' .
					'session_id) ' .
					'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)';
			$ps = db_prepareStatement($sqlSel);
			$bind_success = $ps->bind_param('ssisiidiissssssi',
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
					$this->pfpAddress,
					$this->sessionID);
			if($bind_success) {
				if(!$ps->execute()) {
					echo 'exec fail: ' . htmlspecialchars($ps->error);
				}
				$ps->close();
			} else {
				echo 'bind fail';
			}
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
