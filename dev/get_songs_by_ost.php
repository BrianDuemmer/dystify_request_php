<?php
    require_once $_SERVER['DOCUMENT_ROOT'] . '/kkdystrack/php/inc/dbUtil.php';
    require_once $_SERVER['DOCUMENT_ROOT'] . '/kkdystrack/php/inc/util.php';
    
    if($_SERVER['REQUEST_METHOD'] == 'POST') {
        $db = db_verifyConnected();
        
        $ost = $db->escape_string($_POST['ost']);
        $user_id = $db->escape_string(defaultVal($_SESSION['user_id'], 'ERR_DEFAULT_USER'));
        
        $sql = "CALL P_GET_SONGS_IN_OST(\"$ost\", \"$user_id\")";
       echo $sql;
        $rs = db_execRaw($sql);
        //print_r($db->error_list);
        
        echo $rs;
    }