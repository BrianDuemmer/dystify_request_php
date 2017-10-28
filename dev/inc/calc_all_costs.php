<?php
    require_once "dbUtil.php";
    
    echo "========= CALCULATING ALL SONG COSTS =========\n";
    $t_start = gmmktime();
    $songs = json_decode(db_execRaw("SELECT * FROM playlist"))->data;
    $num = count($songs);
    echo "Processing a total of $num songs, starting at: ".date('r', $t_start)."\n";
    
    $psCall = db_prepareStatement("CALL P_CALC_PTS(?, @pts)");
    $psUpdate = db_prepareStatement("UPDATE playlist SET song_points=@pts WHERE song_id=?");
    
    if($psUpdate && $psCall) {
        $i = 0;
        foreach ($songs AS $song) {
            $psCall->bind_param('s', $song->song_id);
            $psCall->execute();
            // db_execRaw("CALL P_CALC_PTS(\"". db_verifyConnected()->escape_string($song->song_id)."\", @pts)" );
            
            $psUpdate->bind_param('s', $song->song_id);
            $psUpdate->execute();
            
            // echo "processed song $i, named $song->song_id\n";
            $i++;
        }
        
        $t_end = gmmktime();
        $secs = $t_end - $t_start;
        $rate = $num / $secs;
        
        echo "Finished processing songs at ".date('r', $t_end).". Took $secs seconds, at a rate of $rate songs per second\n\n";
    } else {
        echo "Error occured initializing database statements!\n\n Call error:\n";
        print_r($psCall);
        echo "\n\nupdate error:\n";
        print_r($psUpdate);
    }