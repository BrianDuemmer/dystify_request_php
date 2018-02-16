<?php
/*
 * Serves as an endpoint for clients to connect to in order to listen on events happening in the web interface.
 * by default it will poll the event_log table in the database periodically to check for new events being
 * registered, and upon seeing any new events it will read them out and append them to the output stream,
 * update the counter, and flush the output, and repeat.
 *
 * Utilizes Server Sent Events methodology, and as such this should never truly return, and it sets up for the
 * script to have unlimited runtime. In practice it will probably get booted off now and again for XYZ reason.
 * As a result, a connection can specify a `last_event_id`, which tells the server what to set the initial
 * event pointer to. If not set or is invalid (not present in the database records), it defaults to the most recently
 * submitted event, within the last second.
 */

// requires / setup
require_once "../inc/dbUtil.php";
require_once "event.php";
ini_set('max_execution_time', 0); // run forever

// globals
$last_event = Event::getValidLastID($_GET['last_event']);

// if ($_SERVER['REQUEST_METHOD'] == 'GET' && isset($_GET['last_event'])) {
//     $last_event=Event::getValidLastID($_GET['last_event']);
// }

// main processing loop, run indefinitely
while('not false') {
    $pending = Event::fromDB_eidGreaterThan($last_event);
    if($pending === array()) {
        foreach($pending AS $event) {
            echo $event->fmtSSEBody();
            $last_event = max($last_event, $event->event_id);
        }
    }
    ob_flush();
    flush();
}