<?php
    require_once '../inc/dbUtil.php';

class Event
{
    private $event_id;
    var $time; // unix time it was created
    var $data; // any corresponding data, in json format
    var $type; // integer corresponding to the type of event
    var $description;  // optional text description of the event

    
    function __construct()
    {
        $this->data = "";
        $this->description = "";
        $this->event_id = -1;
        $this->time = -1;
        $this->type = "generic";
    }

    
    /**
     * gets an array of events from the database, with event_id's greater
     * than $min_event_id
     * 
     * @param int $min_event_id
     * @return Event[]
     */
    static function fromDB_eidGreaterThan($min_event_id)
    {
        $sql = "SELECT event_id, time, data, type, description FROM event_log WHERE event_id > ?";
        $ps = db_prepareStatement($sql);
        $ps->bind_param('i', $min_event_id);
        if ($ps->execute()) {
            $res = array();
            $ps->bind_result($event_id, $time, $data, $type, $description);
            while ($ps->fetch()) { // iterate over the results, add each to the return array
                $e = new Event();
                
                $e->data = $data;
                $e->description = $description;
                $e->event_id = $event_id;
                $e->time = $time;
                $e->type = $type;
                
                $res[] = $e;
            }
            return $res;
        } else {
            die("Failed to query database for event_log");
        }
    }

    /**
     * gets a valid number for the last event ID, optionally taking a
     * desired event id to check.
     * If not set or is invalid (not present in the database records),
     * it defaults to the most recently submitted event.
     * 
     * @param int $last_id
     *            optional ID to check
     * @return int a guaranteed valid event ID for usage
     */
    static function getValidLastID($last_event = null)
    {
        $last_event = filter_var($last_event, FILTER_SANITIZE_NUMBER_INT);
        if ($last_event) {
            $eid_bounds = json_decode(db_execRaw("SELECT COALESCE(MIN(event_id), 0) AS min, COALESCE(MAX(event_id), 0) AS max FROM event_log"), true)['data'][0];
            if ($last_event > $eid_bounds['max'] || $last_event < $eid_bounds['min']) {
                $last_event = $eid_bounds['max']; // set to the most recent event
            }
        }
        
        return $last_event;
    }
    
    
    
    /**
     * Returns a string representation of this event, ready to be appended to an SSE stream.
     * @return string
     */
    function fmtSSEBody() {
        $ret = "id:$this->event_id
event:$this->type
data:$this->data
description:".addslashes($this->description)."\n";
        return $ret;
    }
    
    
    
    function getEventID() {
        return $this->event_id;
    }
    
    
    
    /**
     * officially registers this event; that is, it flushes this event to the database. If time is not set, it
     * will default to the current unix timestamp, and event_id will be determined by the server.
     */
    function register() {
        if($this->time < 0)
            $this->time = time();
        $sql = "INSERT INTO event_log (`time`, data, type, description) VALUES (?, ?, ?, ?)";
        $ps = db_prepareStatement($sql);
        $ps->bind_param('isss', $this->time, $this->data, $this->type, $this->description);
        $ps->execute();
    }
}


















