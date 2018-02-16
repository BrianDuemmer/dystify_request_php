<?php
    require_once $_SERVER['DOCUMENT_ROOT'] . '/kkdystrack/php/inc/dbUtil.php';
    
    function getQueueMain() {
        $sql = "SELECT CONCAT(p.ost_name, ' - ', p.song_name) AS disp_name, 
                v.username, 
                p.song_length,
                AVG(r.rating_pct) AS rating_pct,
        		COUNT(r.song_id) AS rating_num, 
        		MAX(h.time_played) AS last_play,
        		COUNT(h.time_played) AS times_played, 	
                IF(
                    F_READ_NUM_PARAM('is_now_playing', 0) != 0 AND
                    (
                        F_READ_NUM_PARAM('now_playing_update', 0) + 
                        F_READ_NUM_PARAM('now_playing_update', 0) > 
                        UNIX_TIMESTAMP()
                    ),
                        (F_READ_NUM_PARAM('now_playing_update', 0)
                         + F_READ_NUM_PARAM('now_playing_length', 0)
                         +  (SELECT SUM(pl.song_length) FROM queue_main qm INNER JOIN playlist pl ON pl.song_id=qm.song_id WHERE qm.list_order<=q.list_order)
                         -  p.song_length)
                    , -1
                  ) AS eta
                
                FROM queue_main q 
                INNER JOIN playlist p ON p.song_id=q.song_id
                INNER JOIN viewers v ON v.user_id=q.user_id
                LEFT JOIN play_history h ON
                			p.song_id=h.song_id AND
                			UNIX_TIMESTAMP(h.time_played) > 
                                UNIX_TIMESTAMP() - F_READ_NUM_PARAM('times_played_check', 2678400)
        		LEFT JOIN ratings r ON
        			p.song_id=r.song_id
                GROUP BY q.song_id
                ORDER BY q.list_order";
        
        return json_encode(json_decode(db_execRaw($sql))->data);
    }
    
    
    if($_SERVER['REQUEST_METHOD'] == "GET") {
        echo getQueueMain();
    }