<?php
require_once $_SERVER['DOCUMENT_ROOT'] . '/kkdystrack/php/inc/GLOBALS.php';
require_once $_SERVER['DOCUMENT_ROOT'] . '/kkdystrack/php/inc/dbUtil.php';
require_once $_SERVER['DOCUMENT_ROOT'] . '/kkdystrack/php/inc/viewer.php';
require_once $_SERVER['DOCUMENT_ROOT'] . '/kkdystrack/php/inc/util.php';

function addToIFTTTLog($data, $isErr) {
    $tbl = $isErr ? 'ifttt_failed' : 'ifttt_log';
    $sql = "INSERT INTO " .$tbl. " (user_id, command, time, response) VALUES(?, ?, UNIX_TIMESTAMP(), ?)";
    $ps = db_prepareStatement($sql);
    $ps->bind_param('sss', $data->user_id, $data->command, $data->response);
    
    print_r($data);
    
    if(!$ps->execute()) {
        die("An error occured attempting to write the ifttt transaction to the database");
    }
}


if($_SERVER['REQUEST_METHOD'] == 'POST') { 
    $body = file_get_contents('php://input');
    file_put_contents("body", $body);
    
    $match = array();
    preg_match_all("/(?<=\\:\\\").+?(?=\\\"(\\<\\>|$))/", $body, $match);
    $data = new stdClass();
    $data->key = $match[0][0];
    $data->user_id = $match[0][1];
    
    // extract command info from the response. if this hits, then we want the command
    $respMatch = array();
    preg_match_all("/(?<=\\!eventrequest).+/i", $match[0][2], $respMatch);
    $data->command="!eventrequest"; // for now this is only for !eventrequest, so leave it defined statically
    $data->response=$respMatch[0][0];
    
    print_r($data);
    
    if($data->response) {
        $isErr = !($data->key == constant('IFTTT_KEY') &&
            isset($data->user_id) &&
            isset($data->command));
        
        addToIFTTTLog($data, $isErr);
        
        
        // Handlers, to do extra things with certain commands
        
        if(!$isErr) { // transaction good, acknowledge
            verify_user_registered($data->user_id);
            $sqlEvt = "REPLACE INTO event_request (user_id, time_sent, song) VALUES(?, UNIX_TIMESTAMP(), ?)";
            $ps = db_prepareStatement($sqlEvt);
            $ps->bind_param('ss', $data->user_id, $data->response);
            $ps->execute();
    }
        
        
    }
}
