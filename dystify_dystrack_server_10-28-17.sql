-- phpMyAdmin SQL Dump
-- version 4.3.8
-- http://www.phpmyadmin.net
--
-- Host: localhost
-- Generation Time: Oct 27, 2017 at 11:55 PM
-- Server version: 5.5.51-38.2
-- PHP Version: 5.6.20

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;

--
-- Database: `dystify_dystrack_server`
--

DELIMITER $$
--
-- Procedures
--
CREATE DEFINER=`dystify`@`localhost` PROCEDURE `P_ADD_RATING`(
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
END$$

CREATE DEFINER=`dystify`@`localhost` PROCEDURE `P_ADD_SONG`(
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
END$$

CREATE DEFINER=`dystify`@`localhost` PROCEDURE `P_ADD_UPDATE_VIEWER`(
	IN m_user_id_in VARCHAR(30),
	IN m_username_in VARCHAR(100),
	IN m_access_token_in VARCHAR(150),
	IN m_token_type_in VARCHAR(30),
	IN m_token_expires_in INTEGER,
	IN m_token_created_in INTEGER
)
BEGIN
	REPLACE INTO
		viewers
	(
		user_id,
		username,
		access_token,
		token_type,
		token_expires_in,
		token_created
	) VALUES
	(
		m_user_id_in,
		m_username_in,
		m_access_token_in,
		m_token_type_in,
		m_token_expires_in,
		m_token_created_in
	);
	
END$$

CREATE DEFINER=`dystify`@`localhost` PROCEDURE `P_BENCHMARK_PARAM_READ`(
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
END$$

CREATE DEFINER=`dystify`@`localhost` PROCEDURE `P_CALC_COST`(
	IN m_song_id VARCHAR(255),
	IN m_user_id VARCHAR(30),
	IN m_in_queue_override BOOLEAN,
	IN m_recalc_pts BOOLEAN,
	OUT m_cost DOUBLE,
	OUT m_pts DOUBLE
)
BEGIN
	DECLARE m_len_scl DOUBLE;
	DECLARE m_pts_scl DOUBLE;
	DECLARE m_cooldown_pts DOUBLE;
	DECLARE m_base_cost DOUBLE;
	DECLARE m_user_discount DOUBLE DEFAULT 0;
	
	SET m_cost = -4;
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
			IF !(SELECT is_blacklisted FROM viewers WHERE user_id = m_user_id) THEN
			
				IF m_recalc_pts THEN
					CALL P_CALC_PTS(m_song_id, @pts);
				ELSE
					SET @pts = (SELECT song_points FROM playlist WHERE song_id=m_song_id LIMIT 1);
				END IF;
				SET m_pts = @pts;
				
				-- it *should* be impossible for this to fail given we already checked for song existence before, I can't shake the feeling that not checking again will bite me in the ass
				IF m_pts > 0 THEN
					SET m_pts_scl = F_READ_NUM_PARAM('points_scl', 42);
					SET m_cooldown_pts = F_READ_NUM_PARAM('cooldown_pts', 6);
					SET m_base_cost = F_READ_NUM_PARAM('base_cost', 100);
					SET m_user_discount = (SELECT rupee_discount FROM viewers WHERE user_id = m_user_id);
					
					-- make sure we aren't on cooldown before proceeding
					IF m_pts < m_cooldown_pts THEN
						SET m_cost = GREATEST(m_base_cost, ROUND(m_pts*m_pts_scl*m_len_scl*2,-2) / 2) - m_user_discount; -- apply all the scalars, round to nearest 50, and don't let final cost dip below the base_cost. Then factor in for user discounts
					
					ELSE SET m_cost = -1; END IF; -- cooldown
				ELSE SET m_cost = m_pts; END IF; -- something funky happened in the calc cost routine
			
			ELSE SET m_cost = -6; END IF; -- B A N N E D user
		ELSE SET m_cost = -2; END IF; -- in queue, override off
	ELSE SET m_cost = -3, m_pts = -3; END IF; -- bad song_id
END$$

CREATE DEFINER=`dystify`@`localhost` PROCEDURE `P_CALC_COST_BENCHMARK`(
	IN m_song_id VARCHAR(256),
	IN m_user_id VARCHAR(30),
	IN m_in_queue_override BOOLEAN,
	IN m_num_times INTEGER
)
BEGIN
    DECLARE i INTEGER DEFAULT 0;
	DECLARE m_start TIMESTAMP;
	DECLARE m_last TIMESTAMP;
	
	SET m_start = NOW(3);
	SET m_last = NOW(3);
	
	DROP TABLE IF EXISTS P_CALC_COST_BENCHMARK_TEMP;
	CREATE TABLE P_CALC_COST_BENCHMARK_TEMP (
		cost DOUBLE,
		points DOUBLE,
		time_secs DOUBLE,
		delta_time_secs DOUBLE) ENGINE=MEMORY;
	
	
	WHILE i<m_num_times DO
		CALL P_CALC_COST_2(m_song_id, m_user_id, m_in_queue_override, @cost, @pts);
		
		INSERT INTO P_CALC_COST_BENCHMARK_TEMP (cost, points, time_secs, delta_time_secs) 
			VALUES (@cost, @pts, TIME_TO_SEC(NOW(3) - m_start), TIME_TO_SEC(NOW(3) - m_last));
			
		SET i = i+1;
		SET m_last = NOW(3);
	END WHILE;
	
	SELECT * FROM P_CALC_COST_BENCHMARK_TEMP;
	DROP TABLE P_CALC_COST_BENCHMARK_TEMP;
END$$

CREATE DEFINER=`dystify`@`localhost` PROCEDURE `P_CALC_LIST_POS`(
	IN m_queue_id VARCHAR(100)
)
BEGIN
			-- get the proper list order
		SET @sql = CONCAT("SELECT @list_pos := COALESCE((MAX(list_order)+1),1) FROM queue_", m_queue_id);
		PREPARE stmt_foo FROM @sql;
		EXECUTE stmt_foo;
		DEALLOCATE PREPARE stmt_foo;
END$$

CREATE DEFINER=`dystify`@`localhost` PROCEDURE `P_CALC_PTS`(
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
	ELSE SET m_pts = -2; END IF;
END$$

CREATE DEFINER=`dystify`@`localhost` PROCEDURE `P_CREATE_QUEUE`(
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
END$$

CREATE DEFINER=`dystify`@`localhost` PROCEDURE `P_DROP_QUEUE`(
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
END$$

CREATE DEFINER=`dystify`@`localhost` PROCEDURE `P_GET_SONGS_IN_DIR`(
	IN m_dir VARCHAR(255),
	IN m_user_id VARCHAR(30)
)
BEGIN
	SELECT
		`playlist`.`song_id` AS song_id,
		`playlist`.`song_name` AS song_name,
		`playlist`.`ost_name` AS ost_name,
		`playlist`.`song_franchise` AS franchise_name,
		`playlist`.`song_length` AS song_length,
		F_CALC_COST(`playlist`.`song_id`, m_user_id, 0)AS cost, -- TODO add proper handling of this
		(SELECT COALESCE(AVG(`ratings`.`rating_pct`), -1) FROM ratings WHERE ratings.song_id=playlist.song_id) AS rating_pct,
		(SELECT COALESCE(COUNT(`ratings`.`song_id`), -1) FROM ratings WHERE ratings.song_id=playlist.song_id) AS rating_num, 
		F_GET_SONG_LAST_PLAY(playlist.song_id) AS last_play
		-- F_GET_SONG_TIMES_PLAYED(playlist.song_id, DATE_SUB(UTC_TIMESTAMP(), INTERVAL 1 MONTH)) AS times_played 		
	FROM
		playlist
	WHERE
		playlist.song_id LIKE CONCAT(m_dir, '%') /*AND
		playlist.song_id NOT LIKE CONCAT(m_dir, '%', "\\", '%')*/;
END$$

CREATE DEFINER=`dystify`@`localhost` PROCEDURE `P_GET_SONGS_IN_OST`(
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
END$$

CREATE DEFINER=`dystify`@`localhost` PROCEDURE `P_GET_SONGS_SEARCH`(
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
END$$

CREATE DEFINER=`dystify`@`localhost` PROCEDURE `P_POP_NEXT_SONG`(
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
END$$

--
-- Functions
--
CREATE DEFINER=`dystify`@`localhost` FUNCTION `F_CALC_COST`(
	m_song_id VARCHAR(255),
	m_user_id VARCHAR(30),
	m_in_queue_override BOOLEAN
) RETURNS double
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
				IF m_pts > 0 THEN
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
END$$

CREATE DEFINER=`dystify`@`localhost` FUNCTION `F_CALC_PTS`(
	m_song_1 VARCHAR(256), 
	m_song_2 VARCHAR(256),
	m_lvl_1_pts DOUBLE,
	m_lvl_2_pts DOUBLE,
	m_lvl_3_pts DOUBLE

) RETURNS double
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
END$$

CREATE DEFINER=`dystify`@`localhost` FUNCTION `F_CALC_PTS_CORE`(
	m_song_1 VARCHAR(255), 
	m_song_2 VARCHAR(255),
	m_lvl_1_pts DOUBLE,
	m_lvl_2_pts DOUBLE,
	m_lvl_3_pts DOUBLE
) RETURNS double
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
END$$

CREATE DEFINER=`dystify`@`localhost` FUNCTION `F_GET_NEW_SESSION_ID`() RETURNS int(10) unsigned
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
END$$

CREATE DEFINER=`dystify`@`localhost` FUNCTION `F_GET_SONG_BASE_COST`(m_song_id VARCHAR(256)) RETURNS double
    DETERMINISTIC
BEGIN
    DECLARE m_base_cost DOUBLE;

    
    SET m_base_cost = (SELECT base_cost FROM song_overrides WHERE song_id=m_song_id);
    IF(ISNULL(m_base_cost)) THEN
        SET m_base_cost = F_READ_NUM_PARAM('base_cost', 150);
    END IF;

    RETURN m_base_cost;
END$$

CREATE DEFINER=`dystify`@`localhost` FUNCTION `F_GET_SONG_COOLDOWN`(m_song_id VARCHAR(256)) RETURNS double
    DETERMINISTIC
BEGIN
    DECLARE m_cooldown DOUBLE;

    
    SET m_cooldown = (SELECT base_cooldown FROM song_overrides WHERE song_id=m_song_id);
    IF(ISNULL(m_cooldown)) THEN
        SET m_cooldown = F_READ_NUM_PARAM('base_cooldown', 259200);
    END IF;

    RETURN m_cooldown;
END$$

CREATE DEFINER=`dystify`@`localhost` FUNCTION `F_GET_SONG_COST_DROP_DAY`(m_song_id VARCHAR(256)) RETURNS double
    DETERMINISTIC
BEGIN
    DECLARE m_cost_drop_day DOUBLE;

    
    SET m_cost_drop_day = (SELECT cost_drop_day FROM song_overrides WHERE song_id=m_song_id);
    IF(ISNULL(m_cost_drop_day)) THEN
        SET m_cost_drop_day = F_READ_NUM_PARAM('cost_drop_day', 50);
    END IF;

    RETURN m_cost_drop_day;
END$$

CREATE DEFINER=`dystify`@`localhost` FUNCTION `F_GET_SONG_LAST_PLAY`(m_song_id VARCHAR(256)) RETURNS datetime
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
END$$

CREATE DEFINER=`dystify`@`localhost` FUNCTION `F_GET_SONG_MAX_COST`(m_song_id VARCHAR(256)) RETURNS double
    DETERMINISTIC
BEGIN
    DECLARE m_max_cost DOUBLE;

    
    SET m_max_cost = (SELECT max_cost FROM song_overrides WHERE song_id=m_song_id);
    IF(ISNULL(m_max_cost)) THEN
        SET m_max_cost = F_READ_NUM_PARAM('max_cost', 300);
    END IF;

    RETURN m_max_cost;
END$$

CREATE DEFINER=`dystify`@`localhost` FUNCTION `F_GET_SONG_TIMES_PLAYED`(m_song_id VARCHAR(256), m_newerThan DATETIME) RETURNS int(11)
    DETERMINISTIC
BEGIN
    DECLARE m_times_played INTEGER;
	
    SET m_times_played = (SELECT COUNT(song_id) FROM play_history WHERE song_id=m_song_id AND time_played > m_newerThan);
	
    RETURN m_times_played;
END$$

CREATE DEFINER=`dystify`@`localhost` FUNCTION `F_READ_NUM_PARAM`(m_setting VARCHAR(100), m_default DOUBLE) RETURNS double
    DETERMINISTIC
BEGIN
	RETURN COALESCE((SELECT num_val FROM general_settings WHERE m_setting = setting), m_default);
END$$

CREATE DEFINER=`dystify`@`localhost` FUNCTION `F_READ_STR_PARAM`(m_setting VARCHAR(100), m_default VARCHAR(500)) RETURNS varchar(500) CHARSET utf8 COLLATE utf8_unicode_ci
    DETERMINISTIC
BEGIN
	RETURN COALESCE((SELECT str_val FROM general_settings WHERE m_setting = setting), m_default);
END$$

CREATE DEFINER=`dystify`@`localhost` FUNCTION `F_SAME_SHIFT`(m_time1 DATETIME, m_time2 DATETIME, m_shift_len INTEGER) RETURNS tinyint(1)
    DETERMINISTIC
BEGIN
	RETURN (ABS(TIMESTAMPDIFF(SECOND, m_time1, m_time2)) % 86400) < m_shift_len;
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `fire_emblem_minigame`
--

CREATE TABLE IF NOT EXISTS `fire_emblem_minigame` (
  `user_id` varchar(100) COLLATE utf8_unicode_ci NOT NULL,
  `is_nohr` tinyint(1) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `foo`
--

CREATE TABLE IF NOT EXISTS `foo` (
  `q` int(11) DEFAULT NULL,
  `w` varchar(69) COLLATE utf8_unicode_ci DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `forward_queue`
--

CREATE TABLE IF NOT EXISTS `forward_queue` (
  `user_id` varchar(30) COLLATE utf8_unicode_ci NOT NULL,
  `time_requested` datetime NOT NULL,
  `song_id` varchar(256) COLLATE utf8_unicode_ci NOT NULL,
  `priority` int(11) NOT NULL,
  `id` int(11) NOT NULL
) ENGINE=MyISAM AUTO_INCREMENT=3 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `general_settings`
--

CREATE TABLE IF NOT EXISTS `general_settings` (
  `setting` varchar(100) COLLATE utf8_unicode_ci NOT NULL,
  `num_val` double DEFAULT NULL,
  `str_val` varchar(500) COLLATE utf8_unicode_ci DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `ifttt_failed`
--

CREATE TABLE IF NOT EXISTS `ifttt_failed` (
  `user_id` varchar(30) COLLATE utf8_unicode_ci NOT NULL,
  `command` varchar(15) COLLATE utf8_unicode_ci NOT NULL,
  `time` datetime NOT NULL,
  `transaction_id` bigint(20) NOT NULL
) ENGINE=MyISAM AUTO_INCREMENT=2 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `ifttt_log`
--

CREATE TABLE IF NOT EXISTS `ifttt_log` (
  `user_id` varchar(30) COLLATE utf8_unicode_ci NOT NULL,
  `command` varchar(15) COLLATE utf8_unicode_ci NOT NULL,
  `time` datetime NOT NULL,
  `transaction_id` bigint(20) NOT NULL
) ENGINE=MyISAM AUTO_INCREMENT=266 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `overrides`
--

CREATE TABLE IF NOT EXISTS `overrides` (
  `override_id` varchar(256) COLLATE utf8_unicode_ci NOT NULL,
  `song_pts` double NOT NULL,
  `ost_pts` double NOT NULL,
  `franchise_pts` double NOT NULL,
  `time_checked` double NOT NULL,
  `id` int(11) NOT NULL
) ENGINE=MyISAM AUTO_INCREMENT=2 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `playlist`
--

CREATE TABLE IF NOT EXISTS `playlist` (
  `song_name` varchar(300) COLLATE utf8_unicode_ci NOT NULL,
  `ost_name` varchar(100) COLLATE utf8_unicode_ci NOT NULL,
  `song_id` varchar(255) COLLATE utf8_unicode_ci NOT NULL,
  `song_length` double NOT NULL,
  `song_franchise` varchar(100) COLLATE utf8_unicode_ci NOT NULL,
  `song_points` double NOT NULL COMMENT 'points that directly translates to cost/cooldown. Gives significantly more felxibility than just storing cost'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `play_history`
--

CREATE TABLE IF NOT EXISTS `play_history` (
  `user_id` varchar(30) COLLATE utf8_unicode_ci NOT NULL,
  `time_requested` datetime NOT NULL,
  `song_id` varchar(256) COLLATE utf8_unicode_ci NOT NULL,
  `priority` int(11) NOT NULL,
  `time_played` datetime NOT NULL,
  `play_id` bigint(20) NOT NULL
) ENGINE=MyISAM AUTO_INCREMENT=503287 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `play_history_archive`
--

CREATE TABLE IF NOT EXISTS `play_history_archive` (
  `user_id` varchar(30) COLLATE utf8_unicode_ci NOT NULL,
  `time_requested` datetime NOT NULL,
  `song_id` varchar(256) COLLATE utf8_unicode_ci NOT NULL,
  `priority` int(11) NOT NULL,
  `time_played` datetime NOT NULL,
  `play_id` bigint(20) NOT NULL
) ENGINE=MyISAM AUTO_INCREMENT=503287 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `queues`
--

CREATE TABLE IF NOT EXISTS `queues` (
  `queue_id` varchar(100) COLLATE utf8_unicode_ci NOT NULL,
  `num_songs` int(11) NOT NULL DEFAULT '0',
  `len_total_remaining` double NOT NULL DEFAULT '0',
  `len_currsong_remaining` double NOT NULL DEFAULT '0',
  `time_play_started` datetime NOT NULL,
  `is_playing` tinyint(1) NOT NULL DEFAULT '0',
  `now_playing` varchar(256) COLLATE utf8_unicode_ci DEFAULT NULL,
  `delete_on_empty` tinyint(1) NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci COMMENT='Stores information about all active queues';

-- --------------------------------------------------------

--
-- Table structure for table `queue_main`
--

CREATE TABLE IF NOT EXISTS `queue_main` (
  `user_id` varchar(30) COLLATE utf8_unicode_ci NOT NULL,
  `time_requested` datetime NOT NULL,
  `song_id` varchar(256) COLLATE utf8_unicode_ci NOT NULL,
  `list_order` int(11) NOT NULL,
  `id` int(11) NOT NULL
) ENGINE=MyISAM AUTO_INCREMENT=6 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `queue_test`
--

CREATE TABLE IF NOT EXISTS `queue_test` (
  `user_id` varchar(30) COLLATE utf8_unicode_ci NOT NULL,
  `time_requested` datetime NOT NULL,
  `song_id` varchar(256) COLLATE utf8_unicode_ci NOT NULL,
  `list_order` int(11) NOT NULL,
  `id` int(11) NOT NULL
) ENGINE=MyISAM AUTO_INCREMENT=37 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `ratings`
--

CREATE TABLE IF NOT EXISTS `ratings` (
  `song_id` varchar(256) COLLATE utf8_unicode_ci NOT NULL,
  `user_id` varchar(30) COLLATE utf8_unicode_ci NOT NULL,
  `rating_pct` double NOT NULL DEFAULT '-1',
  `rate_id` bigint(20) NOT NULL
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `song_alias`
--

CREATE TABLE IF NOT EXISTS `song_alias` (
  `song_id` varchar(256) COLLATE utf8_unicode_ci NOT NULL,
  `alias_name` varchar(50) COLLATE utf8_unicode_ci NOT NULL,
  `id` int(11) NOT NULL
) ENGINE=MyISAM AUTO_INCREMENT=10 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `song_length_cost_scl`
--

CREATE TABLE IF NOT EXISTS `song_length_cost_scl` (
  `lower_bound` double NOT NULL,
  `scl` double NOT NULL DEFAULT '1'
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `user_blacklist`
--

CREATE TABLE IF NOT EXISTS `user_blacklist` (
  `user_id` varchar(30) COLLATE utf8_unicode_ci NOT NULL,
  `time_banned` int(11) DEFAULT NULL,
  `note` text COLLATE utf8_unicode_ci
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

-- --------------------------------------------------------

--
-- Stand-in structure for view `vfoo`
--
CREATE TABLE IF NOT EXISTS `vfoo` (
`song_name` varchar(300)
,`ost_name` varchar(100)
,`song_id` varchar(255)
,`song_length` double
,`song_franchise` varchar(100)
,`song_points` double
);

-- --------------------------------------------------------

--
-- Table structure for table `viewers`
--

CREATE TABLE IF NOT EXISTS `viewers` (
  `username` varchar(100) COLLATE utf8_unicode_ci NOT NULL,
  `user_id` varchar(30) COLLATE utf8_unicode_ci NOT NULL,
  `rupees` double NOT NULL,
  `favorite_song` varchar(256) COLLATE utf8_unicode_ci NOT NULL,
  `is_admin` tinyint(1) NOT NULL,
  `is_blacklisted` tinyint(1) NOT NULL,
  `rupee_discount` double NOT NULL,
  `free_requests` int(11) NOT NULL,
  `login_bonus_count` int(11) NOT NULL,
  `watchtime_rank` varchar(100) COLLATE utf8_unicode_ci NOT NULL,
  `static_rank` varchar(100) COLLATE utf8_unicode_ci NOT NULL,
  `birthday` date NOT NULL,
  `last_birthday_withdraw` datetime NOT NULL,
  `song_on_hold` varchar(256) COLLATE utf8_unicode_ci NOT NULL,
  `session_id` int(11) unsigned NOT NULL,
  `pfp_address` varchar(500) COLLATE utf8_unicode_ci NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `vip_users`
--

CREATE TABLE IF NOT EXISTS `vip_users` (
  `user_id` varchar(30) COLLATE utf8_unicode_ci NOT NULL,
  `cost_scalar` double DEFAULT NULL,
  `note` text COLLATE utf8_unicode_ci
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

-- --------------------------------------------------------

--
-- Structure for view `vfoo`
--
DROP TABLE IF EXISTS `vfoo`;

CREATE ALGORITHM=UNDEFINED DEFINER=`dystify`@`localhost` SQL SECURITY DEFINER VIEW `vfoo` AS select `playlist`.`song_name` AS `song_name`,`playlist`.`ost_name` AS `ost_name`,`playlist`.`song_id` AS `song_id`,`playlist`.`song_length` AS `song_length`,`playlist`.`song_franchise` AS `song_franchise`,`playlist`.`song_points` AS `song_points` from `playlist`;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `fire_emblem_minigame`
--
ALTER TABLE `fire_emblem_minigame`
  ADD UNIQUE KEY `uid_unique` (`user_id`);

--
-- Indexes for table `forward_queue`
--
ALTER TABLE `forward_queue`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `general_settings`
--
ALTER TABLE `general_settings`
  ADD UNIQUE KEY `setting` (`setting`);

--
-- Indexes for table `ifttt_failed`
--
ALTER TABLE `ifttt_failed`
  ADD PRIMARY KEY (`transaction_id`);

--
-- Indexes for table `ifttt_log`
--
ALTER TABLE `ifttt_log`
  ADD PRIMARY KEY (`transaction_id`);

--
-- Indexes for table `overrides`
--
ALTER TABLE `overrides`
  ADD PRIMARY KEY (`id`), ADD UNIQUE KEY `override_id` (`override_id`);

--
-- Indexes for table `playlist`
--
ALTER TABLE `playlist`
  ADD UNIQUE KEY `i_song_id_unique` (`song_id`);

--
-- Indexes for table `play_history`
--
ALTER TABLE `play_history`
  ADD PRIMARY KEY (`play_id`), ADD KEY `uid_sid` (`user_id`,`song_id`(255)), ADD KEY `time_played_idx` (`time_played`), ADD KEY `i_song_id` (`song_id`);

--
-- Indexes for table `play_history_archive`
--
ALTER TABLE `play_history_archive`
  ADD PRIMARY KEY (`play_id`), ADD UNIQUE KEY `play_id` (`play_id`), ADD KEY `uid_sid` (`user_id`,`song_id`(255)), ADD KEY `time_played_idx` (`time_played`);

--
-- Indexes for table `queues`
--
ALTER TABLE `queues`
  ADD UNIQUE KEY `queue_id_unique` (`queue_id`);

--
-- Indexes for table `queue_main`
--
ALTER TABLE `queue_main`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `queue_test`
--
ALTER TABLE `queue_test`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `ratings`
--
ALTER TABLE `ratings`
  ADD PRIMARY KEY (`rate_id`), ADD KEY `i_song_id` (`song_id`(255));

--
-- Indexes for table `song_alias`
--
ALTER TABLE `song_alias`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `song_length_cost_scl`
--
ALTER TABLE `song_length_cost_scl`
  ADD UNIQUE KEY `upper_bound_idx` (`lower_bound`);

--
-- Indexes for table `user_blacklist`
--
ALTER TABLE `user_blacklist`
  ADD UNIQUE KEY `user_id` (`user_id`);

--
-- Indexes for table `viewers`
--
ALTER TABLE `viewers`
  ADD UNIQUE KEY `session_id_unique` (`session_id`), ADD UNIQUE KEY `user_id_unique` (`user_id`), ADD KEY `session_id_idx` (`session_id`), ADD KEY `user_id_idx` (`user_id`);

--
-- Indexes for table `vip_users`
--
ALTER TABLE `vip_users`
  ADD UNIQUE KEY `user_id` (`user_id`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `forward_queue`
--
ALTER TABLE `forward_queue`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT,AUTO_INCREMENT=3;
--
-- AUTO_INCREMENT for table `ifttt_failed`
--
ALTER TABLE `ifttt_failed`
  MODIFY `transaction_id` bigint(20) NOT NULL AUTO_INCREMENT,AUTO_INCREMENT=2;
--
-- AUTO_INCREMENT for table `ifttt_log`
--
ALTER TABLE `ifttt_log`
  MODIFY `transaction_id` bigint(20) NOT NULL AUTO_INCREMENT,AUTO_INCREMENT=266;
--
-- AUTO_INCREMENT for table `overrides`
--
ALTER TABLE `overrides`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT,AUTO_INCREMENT=2;
--
-- AUTO_INCREMENT for table `play_history`
--
ALTER TABLE `play_history`
  MODIFY `play_id` bigint(20) NOT NULL AUTO_INCREMENT,AUTO_INCREMENT=503287;
--
-- AUTO_INCREMENT for table `play_history_archive`
--
ALTER TABLE `play_history_archive`
  MODIFY `play_id` bigint(20) NOT NULL AUTO_INCREMENT,AUTO_INCREMENT=503287;
--
-- AUTO_INCREMENT for table `queue_main`
--
ALTER TABLE `queue_main`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT,AUTO_INCREMENT=6;
--
-- AUTO_INCREMENT for table `queue_test`
--
ALTER TABLE `queue_test`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT,AUTO_INCREMENT=37;
--
-- AUTO_INCREMENT for table `ratings`
--
ALTER TABLE `ratings`
  MODIFY `rate_id` bigint(20) NOT NULL AUTO_INCREMENT,AUTO_INCREMENT=11;
--
-- AUTO_INCREMENT for table `song_alias`
--
ALTER TABLE `song_alias`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT,AUTO_INCREMENT=10;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
