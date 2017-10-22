-- calculates the cost of the song
DELIMITER $$

DROP FUNCTION IF EXISTS F_CALC_COST$$
CREATE FUNCTION F_CALC_COST(m_song_id VARCHAR(256), m_user_id VARCHAR(256), m_in_queue_override BOOLEAN) RETURNS DOUBLE
	NOT DETERMINISTIC
BEGIN
	DECLARE m_cost DOUBLE;
	DECLARE m_base_cost DOUBLE;
	DECLARE m_cooldown INTEGER;
	DECLARE m_max_cost DOUBLE;
	DECLARE m_last_play DATETIME;
	DECLARE m_cost_drop_day DOUBLE;
	DECLARE m_user_discount DOUBLE;
	
	SET m_cost = -4; -- -1 for on cooldown, -2 for in queue already, -3 for song not found, -4 for unknown
	
	IF(m_in_queue_override || NOT EXISTS(SELECT (1) FROM queue_main WHERE song_id=m_song_id)) THEN -- if this fails it's in queue, so obviously it can't play	
		IF EXISTS(SELECT(song_id) FROM playlist WHERE song_id=m_song_id) THEN -- Also only run is the song id is actually in the playlist
			SELECT base_cooldown, cost_drop_day, base_cost, max_cost
				INTO m_cooldown, m_cost_drop_day, m_base_cost, m_max_cost
				FROM song_overrides WHERE song_id=m_song_id LIMIT 1;
				
			IF(ISNULL(m_cooldown)) THEN
				SET m_cooldown = F_READ_NUM_PARAM('stdSongCooldown', 259200);
				SET m_cost_drop_day = F_READ_NUM_PARAM('stdSongCostDropDay', 50);
				SET m_base_cost = F_READ_NUM_PARAM('stdSongBaseCost', 150);
				SET m_max_cost = F_READ_NUM_PARAM('stdSongMaxCost', 300);
			END IF;
			
			SET m_last_play = F_GET_SONG_LAST_PLAY(m_song_id);
						
			
			IF(TIMESTAMPDIFF(SECOND, m_last_play, UTC_TIMESTAMP()) < m_cooldown) THEN -- Still on cooldown
				SET m_cost = -1;
			ELSE -- Calculate it for real => cost = max - (days*cost/day); return max(cost, base_cost)
				SET m_cost = m_max_cost - (TIMESTAMPDIFF(DAY, m_last_play, 
					DATE_SUB(UTC_TIMESTAMP(), INTERVAL m_cooldown SECOND)) * m_cost_drop_day);
			
				-- Shift cost for this user. = max(0, normal_cost-user_discount)
				SET m_user_discount = COALESCE((SELECT rupee_discount FROM viewers WHERE user_id = m_user_id), 0.0);
				SET m_cost = GREATEST(0, (GREATEST(m_cost, m_base_cost)-m_user_discount));
			END IF;
		ELSE
			SET m_cost = -3;
		END IF;
	ELSE	
		SET m_cost = -2;
	END IF;
	
	RETURN m_cost;
END





-- dumps a table of songs and their costs based on user search parameters
DELIMITER $$

DROP PROCEDURE IF EXISTS P_GET_SONGS_SEARCH$$
CREATE PROCEDURE P_GET_SONGS_SEARCH
(
	IN m_name_query VARCHAR(100),
	IN m_ost_query VARCHAR(100),
	IN m_franchise_query VARCHAR(100),
	IN m_olderthan DATETIME,
	IN m_len_min DOUBLE,
	IN m_len_max DOUBLE,
	IN m_min_rating DOUBLE,
	IN m_user_id VARCHAR(30),
	IN m_num_results INTEGER
) 
BEGIN
    SET m_name_query = IF(m_name_query = '' OR m_name_query IS NULL, '%', CONCAT('%', m_name_query, '%'));	
	SET m_ost_query = IF(m_ost_query = '' OR m_ost_query IS NULL, '%', CONCAT('%', m_ost_query, '%'));	
	SET m_franchise_query = IF(m_franchise_query = '' OR m_franchise_query IS NULL, '%', CONCAT('%', m_franchise_query, '%'));	
	SET m_olderthan = IF(m_olderthan IS NULL, UTC_TIMESTAMP(), m_olderthan);	
	SET m_len_min = IF(m_len_min IS NULL, 0.0, m_len_min);
	SET m_len_max = IF(m_len_max IS NULL, 9999999999999999999999999, m_len_max);
    
	SELECT
		`playlist`.`song_id` AS song_id,
		`playlist`.`song_name` AS song_name,
		`playlist`.`ost_name` AS ost_name,
		`playlist`.`song_franchise` AS franchise_name,
		`playlist`.`song_length` AS song_length,
		F_CALC_COST(`playlist`.`song_id`, m_user_id, 0)AS cost, -- TODO add proper handling of this
		(SELECT COALESCE(AVG(`ratings`.`rating_pct`), -1) FROM ratings WHERE ratings.song_id=playlist.song_id) AS rating_pct,
		(SELECT COALESCE(COUNT(`ratings`.`song_id`), -1) FROM ratings WHERE ratings.song_id=playlist.song_id) AS rating_num, 
		F_GET_SONG_LAST_PLAY(playlist.song_id) AS last_play,
		F_GET_SONG_TIMES_PLAYED(playlist.song_id, DATE_SUB(UTC_TIMESTAMP(), INTERVAL 1 MONTH)) AS times_played 
		
				
	FROM
		playlist
	WHERE
		`playlist`.`song_name` LIKE m_name_query AND
		`playlist`.`ost_name` LIKE m_ost_query AND
		`playlist`.`song_franchise` LIKE m_franchise_query AND
		`playlist`.`song_length` BETWEEN m_len_min AND m_len_max
	HAVING
		rating_pct >= m_min_rating AND
		last_play < m_olderthan
	LIMIT m_num_results;
END




--=============================================================================================================================================================================--
--=============================================================================================================================================================================--
--=============================================================================================================================================================================--
--=============================================================================================================================================================================--


-- only run if not on cooldown and the user has enough to pay for it

-- Adds a song to the specified queue
DELIMITER $$

DROP PROCEDURE IF EXISTS P_ADD_SONG$$
CREATE PROCEDURE P_ADD_SONG
(
	IN m_user_id VARCHAR(30),
	IN m_song_id VARCHAR(256),
	IN m_queue_id VARCHAR(100),
	OUT m_cost DOUBLE,
	OUT m_eta DOUBLE
)
BEGIN
	DECLARE m_song_length DOUBLE;
	
	 SET m_cost = F_CALC_COST(m_song_id, m_user_id, m_queue_id != 'main');
	
	 IF (m_cost >= 0 && m_cost <= (SELECT rupees FROM viewers WHERE user_id=m_user_id)) THEN 
		SET m_song_length = (SELECT song_length FROM playlist WHERE song_id=m_song_id LIMIT 1);
		SET m_eta = (SELECT IF(is_playing!=0, len_total_remaining, -1) FROM queues WHERE queue_id = m_queue_id);
		
		-- Add the song to queue
		SET @m_sql_ins = CONCAT ("INSERT INTO `queue_", m_queue_id,
			"` (user_id, time_requested, song_id, list_order) 
				VALUES(?, ?, ?, (SELECT COALESCE(MAX(list_order)+1, 1) FROM (SELECT * FROM queue_",m_queue_id,") AS foo))");
		
		SET @user_id = m_user_id;
		SET @ts = UTC_TIMESTAMP();
		SET @song_id = m_song_id;
		
		PREPARE stmt_ins FROM @m_sql_ins;
		EXECUTE stmt_ins USING @user_id, @ts, @song_id;
		DEALLOCATE PREPARE stmt_ins;
		
		
		-- update the queues table
		 SET @m_sql_update = CONCAT("UPDATE queues 
			SET num_songs=num_songs+1, 
			 len_total_remaining=len_total_remaining+", m_song_length,
			" WHERE queue_id='", m_queue_id,"'");
		
		PREPARE stmt_update FROM @m_sql_update;
		-- EXECUTE stmt_update;
		DEALLOCATE PREPARE stmt_update;
		
		-- Charge the rupees
		UPDATE viewers SET rupees=rupees-m_cost WHERE user_id=m_user_id;
	-- ELSE -- user is too poor
		-- SET m_cost = -5; 
	END IF; 
END






-- Creates a new queue. Will fail nondestructively with an error if another queue with the same name exists
DELIMITER $$

DROP PROCEDURE IF EXISTS P_CREATE_QUEUE$$
CREATE PROCEDURE P_CREATE_QUEUE
(
	IN m_queue_id VARCHAR(100),
	IN m_delete_on_empty BOOLEAN
)
BEGIN
	SET @m_sql = CONCAT
	(
	"CREATE TABLE `queue_", m_queue_id, "` (
		`user_id` varchar(30) COLLATE utf8_unicode_ci NOT NULL,
		`time_requested` datetime NOT NULL,
		`song_id` varchar(256) COLLATE utf8_unicode_ci NOT NULL,
		`list_order` int(11) NOT NULL,
		`id` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY
	) ENGINE=MyISAM AUTO_INCREMENT=1 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci"
	);
	
	-- Create the table
	PREPARE stmt FROM @m_sql;
	EXECUTE stmt;
	DEALLOCATE PREPARE stmt;
	
	-- Add to queues record
	INSERT INTO	queues (
		queue_id,
		delete_on_empty
	) VALUES (
		m_queue_id,
		m_delete_on_empty
	);
END




-- Forcibly drops a queue
DELIMITER $$

DROP PROCEDURE IF EXISTS P_DROP_QUEUE$$
CREATE PROCEDURE P_DROP_QUEUE
(
	IN m_queue_id VARCHAR(100)
)
BEGIN
	SET @m_sql = CONCAT("DROP TABLE `queue_", m_queue_id, "`");
	
	-- drop the table
	PREPARE stmt FROM @m_sql;
	EXECUTE stmt;
	DEALLOCATE PREPARE stmt;
	
	-- Add to queues record
	DELETE FROM queues WHERE queue_id=m_queue_id;
END





-- pulls the next song from a queue. If the queue is empty afterwards, and is set to dededestroy
-- on empty, this will also drop the queue automatically
DELIMITER $$

DROP PROCEDURE IF EXISTS P_POP_NEXT_SONG$$
CREATE PROCEDURE P_POP_NEXT_SONG
(
	IN m_queue_id VARCHAR(100)
)
BEGIN
	SET @m_sql = CONCAT("SELECT @id := id FROM `queue_", m_queue_id, "` ORDER BY list_order ASC LIMIT 1");
	
	-- get the unique id of the next entry
	PREPARE stmt FROM @m_sql;
	EXECUTE stmt;
	DEALLOCATE PREPARE stmt;
	
	IF(!ISNULL(@id)) THEN
		-- get the next song
		SET @m_sql_get = CONCAT(
			"SELECT playlist.*, queue.user_id FROM PLAYLIST 
			JOIN queue_",m_queue_id," AS queue ON 
			playlist.song_id=queue.song_id 
			HAVING queue.id=@id");
		
		PREPARE stmt_get FROM @m_sql_get;
		EXECUTE stmt_get;
		DEALLOCATE PREPARE stmt_get;
		
		-- get just the song id
		SET @m_sql_song_id = CONCAT("SELECT @song_id := song_id FROM queue_",m_queue_id, " WHERE id=@id");
		PREPARE stmt_song_id FROM @m_sql_song_id;
		EXECUTE stmt_song_id;
		DEALLOCATE PREPARE stmt_song_id;
		
		-- remove it from the queue
		SET @m_sql_del = CONCAT("DELETE FROM queue_",m_queue_id," WHERE id=@id");
		PREPARE stmt_del FROM @m_sql_del;
		EXECUTE stmt_del;
		DEALLOCATE PREPARE stmt_del;
		
		-- update the list_order of all the remaining songs
		SET @m_sql_up = CONCAT("UPDATE queue_",m_queue_id," SET list_order=list_order-1");
		PREPARE stmt_up FROM @m_sql_up;
		EXECUTE stmt_up;
		DEALLOCATE PREPARE stmt_up;
		
		-- see much time is left in the queue
		SET @m_sql_len = CONCAT("SELECT @len_remain := SUM(playlist.song_length) FROM queue_",m_queue_id," AS queue JOIN playlist ON playlist.song_id=queue.song_id");
		PREPARE stmt_len FROM @m_sql_len;
		EXECUTE stmt_len;
		DEALLOCATE PREPARE stmt_len;
	
		-- delete if there aren't any songs left
		IF(@len_remain > 0 && (SELECT delete_on_empty FROM queues WHERE queue_id=m_queue_id)) THEN
			CALL P_DROP_QUEUE(m_queue_id);
			
		ELSE -- just update the queues table
			UPDATE queues
			SET
				len_total_remaining=@len_remaining,
				len_currsong_remaining = (SELECT song_length FROM playlist WHERE song_id = @song_id LIMIT 1)
			WHERE queue_id=m_queue_id;
		END IF;
	END IF;
END






--=============================================================================================================================================================================--
--=============================================================================================================================================================================--
--=============================================================================================================================================================================--
--=============================================================================================================================================================================--




-- Returns a new, unique session id. random integer, unsigned, full range
DELIMITER $$

DROP FUNCTION IF EXISTS F_GET_NEW_SESSION_ID$$
CREATE FUNCTION F_GET_NEW_SESSION_ID() RETURNS INTEGER UNSIGNED
    NOT DETERMINISTIC
BEGIN
    DECLARE m_session_id INTEGER UNSIGNED;
	
    SET m_session_id = 
		(SELECT
			FLOOR(RAND() * (~0 >> 32)) AS num
		FROM
			viewers
		WHERE
			"num" NOT IN (SELECT session_id FROM viewers )
		LIMIT 1);
	
    RETURN COALESCE(m_session_id, FLOOR(RAND() * (~0 >> 32)));
END





-- Fetches the amount of times a song has played
DELIMITER $$

DROP FUNCTION IF EXISTS F_GET_SONG_TIMES_PLAYED$$
CREATE FUNCTION F_GET_SONG_TIMES_PLAYED(m_song_id VARCHAR(256), m_newerThan DATETIME) RETURNS INTEGER
    DETERMINISTIC
BEGIN
    DECLARE m_times_played INTEGER;
	
    SET m_times_played = (SELECT COUNT(song_id) FROM play_history WHERE song_id=m_song_id AND time_played > m_newerThan);
	
    RETURN m_times_played;
END





-- Fetches the last play for a song
DELIMITER $$

DROP FUNCTION IF EXISTS F_GET_SONG_LAST_PLAY$$
CREATE FUNCTION F_GET_SONG_LAST_PLAY(m_song_id VARCHAR(256)) RETURNS DATETIME
    DETERMINISTIC
BEGIN
    DECLARE m_last_play DATETIME;
	DECLARE m_shift_time INTEGER;
	
	SET m_shift_time = F_READ_NUM_PARAM('shift_time', 28800); -- 8 hours
	
    SET m_last_play = COALESCE(
				(SELECT time_played FROM play_history 
					WHERE m_song_id=song_id  
					HAVING F_SAME_SHIFT(UTC_TIMESTAMP(), time_played, m_shift_time)
					ORDER BY time_played DESC
					LIMIT 1),
				DATE('1889-09-23 12:00:00')
			);
	
    RETURN m_last_play;
END





-- Adds a rating to the ratings table
DELIMITER $$

DROP PROCEDURE IF EXISTS P_ADD_RATING$$
CREATE PROCEDURE P_ADD_RATING
(
	IN m_user_id VARCHAR(30),
	IN m_rating DOUBLE
) 
BEGIN
    DECLARE m_song_id VARCHAR(256);
	SET m_song_id = F_READ_STR_PARAM('now_playing', '');
	IF(m_song_id != '') THEN
		INSERT INTO ratings (song_id, user_id, rating_pct) 
		VALUES(m_song_id, m_user_id, m_rating);
	END IF;
END





--=============================================================================================================================================================================--
--=============================================================================================================================================================================--
--=============================================================================================================================================================================--
--=============================================================================================================================================================================--




-- Reads a varchar setting from the database
DELIMITER $$

DROP FUNCTION IF EXISTS F_READ_STR_PARAM$$
CREATE FUNCTION F_READ_STR_PARAM(m_setting VARCHAR(100), m_default VARCHAR(500)) RETURNS VARCHAR(500)
	DETERMINISTIC
BEGIN
	RETURN COALESCE((SELECT str_val FROM general_settings WHERE m_setting = setting), m_default);
END




-- Reads a numeric setting from the database
DELIMITER $$

DROP FUNCTION IF EXISTS F_READ_NUM_PARAM$$
CREATE FUNCTION F_READ_NUM_PARAM(m_setting VARCHAR(100), m_default DOUBLE) RETURNS DOUBLE
	DETERMINISTIC
BEGIN
	RETURN COALESCE((SELECT num_val FROM general_settings WHERE m_setting = setting), m_default);
END




-- Checks if two timestamps happened in the same shift (on any day)
DELIMITER $$

DROP FUNCTION IF EXISTS F_SAME_SHIFT$$
CREATE FUNCTION F_SAME_SHIFT(m_time1 DATETIME, m_time2 DATETIME, m_shift_len INTEGER) RETURNS BOOLEAN
	DETERMINISTIC
BEGIN
	DECLARE m_sameShift BOOLEAN;
	SET m_sameShift = (ABS(TIMESTAMPDIFF(SECOND, m_time1, m_time2)) % 86400) < m_shift_len;
	RETURN (m_sameShift);
END

	











