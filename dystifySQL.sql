/* new cost/cooldown function
* First, finds all of the songs aliased to this one, then for each it
* checks for the proper override conditions, pulling the most specific set
* Then it selects all the songs from recent history, and depending on how 
* closely they match (song, ost, franchise, etc.) a certain value of points, 
* determined by the override, gets added to a total sum, which can later be 
* converted to cost
*/
DELIMITER $$

DROP PROCEDURE IF EXISTS P_CALC_PTS$$
CREATE PROCEDURE P_CALC_PTS
(
	IN m_song_id VARCHAR(255),
	OUT m_pts DOUBLE
)
BEGIN
	DECLARE c_done INTEGER DEFAULT 0;
	DECLARE m_curr_song VARCHAR(255);
	
	-- select all of the songs aliased to this one (including this song itself) into a cursor to iterate through
	DECLARE alias_songs CURSOR FOR
		SELECT  s.song_id AS aliased_song_id 
		FROM 
			song_alias s INNER JOIN song_alias a ON s.alias_name=a.alias_name
		WHERE
			a.song_id = m_song_id
		UNION DISTINCT SELECT m_song_id;
			
	DECLARE CONTINUE HANDLER FOR NOT FOUND SET c_done = 1;
	OPEN alias_songs;
	
	-- append the points
	SELECT 
		o.song_pts, o.ost_pts, o.franchise_pts, o.time_checked
	INTO
		@song_pts, @ost_pts, @franchise_pts, @time_checked
	FROM
		overrides o
	WHERE
		m_song_id LIKE CONCAT(o.override_id, '%')
	ORDER BY CHAR_LENGTH(o.override_id) DESC
	LIMIT 1;
	
	SET m_pts = 0;
	
	IF EXISTS(SELECT(song_id) FROM playlist WHERE song_id=m_song_id) THEN -- Also only run is the song id is actually in the playlist
	
		-- loop through each hit
		l_calc_pts: LOOP
			FETCH alias_songs INTO m_curr_song;
			IF c_done=1 THEN 
				LEAVE l_calc_pts;
			END IF;
			
			SET m_pts = m_pts +
				(SELECT 
					COALESCE(
						SUM(
							F_CALC_PTS_CORE(song_id, m_curr_song, @song_pts, @ost_pts, @franchise_pts) *
							((@time_checked - (UNIX_TIMESTAMP()-UNIX_TIMESTAMP(time_played))) / @time_checked)
							),
						0) AS points
				FROM play_history WHERE @time_checked > UNIX_TIMESTAMP()-UNIX_TIMESTAMP(time_played));
				
		END LOOP l_calc_pts;
	ELSE SET m_pts = -3; END IF;
END

		
	
DELIMITER $$

DROP PROCEDURE IF EXISTS P_CALC_PTS_HELP$$
CREATE PROCEDURE P_CALC_PTS_HELP
(
	IN m_song_id VARCHAR(255)
)
BEGIN
	CALL P_CALC_PTS(m_song_id, @p);
	UPDATE playlist SET song_points=@p WHERE song_id=m_song_id;
END
	
	
	
-- Calculates how closely 2 songs match, in the form of an integer match level. Then applies a point cost to the match based on the match level
-- 0: no match; 1: identical song; 2: diff song, same OST; 3: diff OST, same franchise
DELIMITER $$

DROP FUNCTION IF EXISTS F_CALC_PTS_CORE$$
CREATE FUNCTION F_CALC_PTS_CORE
(
	m_song_1 VARCHAR(255), 
	m_song_2 VARCHAR(255),
	m_lvl_1_pts DOUBLE,
	m_lvl_2_pts DOUBLE,
	m_lvl_3_pts DOUBLE
) RETURNS DOUBLE
	DETERMINISTIC
BEGIN
	DECLARE m_depth_1 INTEGER;
	DECLARE m_depth_2 INTEGER;
	DECLARE m_match_lvl INTEGER;
	DECLARE m_pts DOUBLE;
	
	SET m_depth_1 = CHAR_LENGTH(m_song_1) - CHAR_LENGTH(REPLACE(m_song_1, "\\", ""));
	SET m_depth_2 = CHAR_LENGTH(m_song_2) - CHAR_LENGTH(REPLACE(m_song_2, "\\", ""));
	
	SET m_match_lvl = 
		(SELECT IF(m_song_1=m_song_2, 1,
			IF(SUBSTRING_INDEX(m_song_1, "\\", m_depth_1) = SUBSTRING_INDEX(m_song_2, "\\", m_depth_2), 2,
				IF(SUBSTRING_INDEX(m_song_1, "\\", m_depth_1-1) = SUBSTRING_INDEX(m_song_2, "\\", m_depth_2-1), 3,
					0)
				)
			)
		);
	
	CASE m_match_lvl
		WHEN 1 THEN SET m_pts = m_lvl_1_pts;
		WHEN 2 THEN SET m_pts = m_lvl_2_pts;
		WHEN 3 THEN SET m_pts = m_lvl_3_pts;
		ELSE SET m_pts = 0;
	END CASE;
		
	RETURN m_pts;
END




-- internally fetches a song's points (or recalculates them) and converts to rupee cost / cooldown
DELIMITER $$

DROP FUNCTION IF EXISTS F_CALC_COST$$
CREATE FUNCTION F_CALC_COST
(
	m_song_id VARCHAR(255),
	m_user_id VARCHAR(30),
	m_in_queue_override BOOLEAN
) RETURNS DOUBLE
DETERMINISTIC
BEGIN
	DECLARE m_len_scl DOUBLE;
	DECLARE m_pts_scl DOUBLE;
	DECLARE m_cooldown_pts DOUBLE;
	DECLARE m_base_cost DOUBLE;
	DECLARE m_user_discount DOUBLE DEFAULT 0;
	DECLARE m_cost DOUBLE DEFAULT -4;
	DECLARE m_pts DOUBLE DEFAULT -7;
	
	SET m_len_scl =
		(SELECT
			l.scl
		FROM song_length_cost_scl l
			INNER JOIN playlist p ON l.lower_bound < p.song_length
		WHERE p.song_id = m_song_id
		ORDER BY l.lower_bound DESC
		LIMIT 1);
		
	IF !ISNULL(m_len_scl) THEN -- will be null if the join fails, IE the song isn't found
		IF(m_in_queue_override || NOT EXISTS(SELECT (1) FROM queue_main WHERE song_id=m_song_id)) THEN -- if this fails it's in queue, so it can't play. Override if desiried
			IF COALESCE(!(SELECT is_blacklisted FROM viewers WHERE user_id = m_user_id), 1) THEN
			
				SET m_pts = (SELECT song_points FROM playlist WHERE song_id=m_song_id LIMIT 1);
				
				-- it *should* be impossible for this to fail given we already checked for song existence before, I can't shake the feeling that not checking again will bite me in the ass
				IF m_pts >= 0 THEN
					SET m_pts_scl = F_READ_NUM_PARAM('points_scl', 42);
					SET m_cooldown_pts = F_READ_NUM_PARAM('cooldown_pts', 6);
					SET m_base_cost = F_READ_NUM_PARAM('base_cost', 100);
					SET m_user_discount = COALESCE((SELECT rupee_discount FROM viewers WHERE user_id = m_user_id), 0);
					
					-- make sure we aren't on cooldown before proceeding
					IF m_pts < m_cooldown_pts THEN
						SET m_cost = GREATEST(GREATEST(m_base_cost, ROUND(m_pts*m_pts_scl*m_len_scl*2,-2) / 2) - m_user_discount, 0); -- apply all the scalars, round to nearest 50, and don't let final cost dip below the base_cost. Then factor in for user discounts
					
					ELSE SET m_cost = -1; END IF; -- cooldown
				ELSE SET m_cost = m_pts; END IF; -- something funky happened in the calc cost routine
			
			ELSE SET m_cost = -6; END IF; -- B A N N E D user
		ELSE SET m_cost = -2; END IF; -- in queue, override off
	ELSE SET m_cost = -3, m_pts = -3; END IF; -- bad song_id
	
	RETURN m_cost;
END





-- fetches songs in a format that is ready to be displayed for the front end. NOTE: m_user_id can be set to null/empty and be ignored
DELIMITER $$

DROP PROCEDURE IF EXISTS P_GET_SONGS_IN_OST$$
CREATE PROCEDURE P_GET_SONGS_IN_OST
(
	IN m_ost VARCHAR(255),
	IN m_user_id VARCHAR(30)
)
BEGIN
	DECLARE m_oldest_check INTEGER;
	SET m_oldest_check = UNIX_TIMESTAMP() - F_READ_NUM_PARAM('times_played_check', 2678400);
	
	SELECT
		p.song_id AS song_id,
		p.song_name AS song_name,
		p.ost_name AS ost_name,
		p.song_franchise AS franchise_name,
		p.song_length AS song_length,
		F_CALC_COST(p.song_id, m_user_id, 0)AS cost, -- TODO add proper handling of this
		AVG(r.rating_pct) AS rating_pct,
		COUNT(r.song_id) AS rating_num, 
		MAX(h.time_played) AS last_play,
		COUNT(h.time_played) AS times_played 		
	FROM
		playlist p 
		LEFT JOIN play_history h ON
			p.song_id=h.song_id AND
			UNIX_TIMESTAMP(h.time_played) > m_oldest_check
		LEFT JOIN ratings r ON
			p.song_id=r.song_id
	WHERE
		p.ost_name = m_ost
	GROUP BY p.song_id;
END




DELIMITER $$

DROP VIEW IF EXISTS V_QUEUE_ENTRY$$
CREATE VIEW V_QUEUE_ENTRY AS
	SELECT 
		v.username AS username,
		v.rupees AS rupees,
		v.favorite_song AS favorite_song,
		v.is_blacklisted AS is_blacklisted,
		v.is_admin AS is_admin,
		v.rupee_discount AS rupee_discount,
		v.free_requests AS free_requests,
		v.login_bonus_count AS login_bonus_count,
		v.static_rank AS static_rank,
		v.watchtime_rank AS watchtime_rank,
		v.birthday AS birthday,
		v.last_birthday_withdraw AS last_birthday_withdraw,
		v.song_on_hold AS song_on_hold,
		v.note AS note,
		
		p.song_name AS song_name,
		p.ost_name AS ost_name,
		p.song_franchise AS song_franchise,
		p.song_length AS song_length,
		p.song_points AS song_points,
		
		AVG(r.rating_pct) AS rating_pct,
		COUNT(r.song_id) AS rating_num,
		
		MAX(h.time_played) AS last_play,
		COUNT(h.time_played) AS times_played,
		
		q.user_id AS user_id,
		q.song_id AS song_id,
		q.time_requested AS time_requested,
		q.list_order AS list_order
	FROM
		queue_test q
		LEFT JOIN play_history h ON
			q.song_id=h.song_id AND
			UNIX_TIMESTAMP(h.time_played) > F_READ_NUM_PARAM('times_played_check', 10000)

		LEFT JOIN ratings r ON
			q.song_id=r.song_id

		INNER JOIN playlist p ON
			p.song_id=q.song_id

		INNER JOIN viewers v ON
			v.user_id=q.user_id

	GROUP BY q.song_id, q.id;




-- does a simple read per second test on the parameter table
DELIMITER $$

DROP PROCEDURE IF EXISTS P_BENCHMARK_PARAM_READ$$
CREATE PROCEDURE P_BENCHMARK_PARAM_READ
(
	IN m_key VARCHAR(100),
	IN m_is_dbl BOOLEAN,
	IN m_num INTEGER,
	OUT m_seconds INTEGER,
	OUT m_per_sec DOUBLE
)
BEGIN
	DECLARE i INTEGER DEFAULT 0;
	DECLARE m_start INTEGER;
	DECLARE m_end INTEGER;
	SET m_start = UNIX_TIMESTAMP();
	
	IF m_is_dbl THEN
		WHILE i<m_num DO
			SET @foonum := F_READ_NUM_PARAM(m_key, 0);
			SET i=i+1;
		END WHILE;
	ELSE 
		WHILE i<m_num DO
			SET @foostr := F_READ_STR_PARAM(m_key, "foo");
			SET i=i+1;
		END WHILE;
	END IF;
	
	SET m_seconds = UNIX_TIMESTAMP() - m_start;
	SET m_per_sec = m_num / m_seconds;
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
	SET m_len_max = IF(m_len_max IS NULL, 420E69, m_len_max);
    
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
	IN m_song_id VARCHAR(255),
	IN m_queue_id VARCHAR(100),
	OUT m_cost DOUBLE,
	OUT m_eta DOUBLE
)
BEGIN
	DECLARE m_song_length DOUBLE;
	
	SET m_cost = F_CALC_COST(m_song_id, m_user_id, m_queue_id != 'main');
	SET m_eta = -1;
	IF (m_cost >= 0 AND F_READ_NUM_PARAM("requests_open", 0) OR m_queue_id != 'main') THEN
		IF (m_cost <= (SELECT rupees FROM viewers WHERE user_id=m_user_id)) THEN 
			SET m_song_length = (SELECT song_length FROM playlist WHERE song_id=m_song_id LIMIT 1);
			-- SET m_eta = (SELECT IF(is_playing!=0, len_total_remaining, -1) FROM queues WHERE queue_id = m_queue_id);
			SET @m_sql_eta = CONCAT(
			"SELECT
				IF(F_READ_NUM_PARAM('is_now_playing', 0) != 0,
					(F_READ_NUM_PARAM('now_playing_update', 0)
					+ F_READ_NUM_PARAM('now_playing_length', 0)
					+ SUM(p.song_length)),
					-1) INTO @m_eta
			FROM queue_",m_queue_id," q
				INNER JOIN playlist p ON p.song_id = q.song_id"
			);
			
			PREPARE stmt_eta FROM @m_sql_eta;
			EXECUTE stmt_eta;
			DEALLOCATE PREPARE stmt_eta;
			
			SET m_eta = @m_eta;
			
			-- Add the song to queue
			SET @m_sql_ins = CONCAT ("INSERT INTO `queue_", m_queue_id,
				"` (user_id, time_requested, song_id, list_order) 
					VALUES(?, ?, ?, (SELECT COALESCE(MAX(list_order)+1, 1) FROM (SELECT * FROM queue_",m_queue_id,") AS foo))");
			
			SET @user_id = m_user_id;
			SET @ts = UNIX_TIMESTAMP();
			SET @song_id = m_song_id;
			
			PREPARE stmt_ins FROM @m_sql_ins;
			EXECUTE stmt_ins USING @user_id, @ts, @song_id;
			DEALLOCATE PREPARE stmt_ins;
			
			-- Charge the rupees
			UPDATE viewers SET rupees=rupees-m_cost WHERE user_id=m_user_id;
			
			-- Post a queue update
			INSERT INTO event_log(`time`, `data`, `type`, sender) VALUES(UNIX_TIMESTAMP(), m_queue_id, "QueueUpdatedEvent", "web_frontend");
		ELSE -- user is too poor
			SET m_cost = -5; 
		END IF; 
	ELSE
		SET m_cost = -8;
	END IF;
END






-- Creates a new queue. Will fail nondestructively with an error if another queue with the same name exists
DELIMITER $$

DROP PROCEDURE IF EXISTS P_CREATE_QUEUE$$
CREATE PROCEDURE P_CREATE_QUEUE
(
	IN m_queue_id VARCHAR(100),
	IN m_delete_on_empty BOOLEAN,
	IN m_queue_name VARCHAR(255)
)
BEGIN
	SET @m_sql = CONCAT
	(
	"CREATE TABLE `queue_", m_queue_id, "` (
		`user_id` varchar(30) COLLATE utf8_unicode_ci NOT NULL,
		`time_requested` INTEGER NOT NULL,
		`song_id` varchar(255) COLLATE utf8_unicode_ci NOT NULL,
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
		delete_on_empty,
		queue_name
	) VALUES (
		m_queue_id,
		m_delete_on_empty,
		m_queue_name
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



-- Registers an Event in the database
DELIMITER $$

DROP PROCEDURE IF EXISTS P_POST_EVENT$$
CREATE PROCEDURE P_POST_EVENT
(
	IN m_type VARCHAR(255),
	IN m_data TEXT,
	IN m_sender VARCHAR(100)
)
BEGIN
	INSERT INTO event_log ( `time`, `data`, `type`, `sender`, `description`)
	VALUES (UNIX_TIMESTAMP(), m_data, m_type, m_sender, "");
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
		-- get the next song, load it as the active result set for the procedure
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
CREATE FUNCTION F_GET_SONG_TIMES_PLAYED(m_song_id VARCHAR(255), m_newerThan DATETIME) RETURNS INTEGER
    DETERMINISTIC
BEGIN
    DECLARE m_times_played INTEGER;
	
    SET m_times_played = (SELECT COUNT(song_id) FROM play_history WHERE song_id=m_song_id AND time_played > m_newerThan);
	
    RETURN m_times_played;
END





-- Fetches the last play for a song
DELIMITER $$

DROP FUNCTION IF EXISTS F_GET_SONG_LAST_PLAY$$
CREATE FUNCTION F_GET_SONG_LAST_PLAY(m_song_id VARCHAR(255)) RETURNS DATETIME
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
    DECLARE m_song_id VARCHAR(255);
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
	RETURN (ABS(TIMESTAMPDIFF(SECOND, m_time1, m_time2)) % 86400) < m_shift_len;
END

	




DELIMITER $$

DROP PROCEDURE IF EXISTS P_TEST_END_OF_THE_LINE$$
CREATE PROCEDURE P_TEST_END_OF_THE_LINE
(
	IN m_limit INTEGER,
	IN m_time_shift INTEGER
)
BEGIN
	INSERT INTO ifttt_log
		(
			user_id,
			command,
			`time`,
			response
		)
	SELECT
		t.user_id,
		IF(RAND()>0.666, "!left",
				IF(RAND()>0.5, "!middle","!right"
				)),
		UNIX_TIMESTAMP() + m_time_shift,
		CONCAT 
		(
			v.username,
			", you chose something. Good for you! :dysOk:(",
			t.user_id,
			")"
		)
	FROM
		TMP_MP_USER_POOL t
	INNER JOIN
		viewers v ON
		v.user_id = t.user_id
	LIMIT
		m_limit;
END






DELIMITER $$

DROP PROCEDURE IF EXISTS P_TEST_MERRY_GO_CHOMP$$
CREATE PROCEDURE P_TEST_MERRY_GO_CHOMP
(
	IN m_limit INTEGER,
	IN m_time_shift INTEGER
)
BEGIN
	INSERT INTO ifttt_log
		(
			user_id,
			command,
			`time`,
			response
		)
	SELECT
		t.user_id,
		IF(RAND()>0.666, "!left",
				IF(RAND()>0.5, "!middle","!right"
				)),
		UNIX_TIMESTAMP() + m_time_shift,
		CONCAT 
		(
			v.username,
			", you chose something. Good for you! :dysOk:(",
			t.user_id,
			")"
		)
	FROM
		TMP_MP_USER_POOL t
	INNER JOIN
		viewers v ON
		v.user_id = t.user_id
	LIMIT
		m_limit;
END







































