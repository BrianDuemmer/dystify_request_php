<?php
require_once 'inc/dbUtil.php';

/**
 *
 * @param array $parent
 * @param string $rootStr
 * @param array $fullList
 */
function addChildern(&$parent, $rootStr, $fullList)
{
    foreach ($fullList as $entry) 
    {
        $preg = "/(?<=^".preg_quote($rootStr)."\\\\).+?(?=\\\\|$)/";
        $hasMatch = preg_match($preg, $entry, $matchArr);
        $match = $matchArr[0];
        $next = $rootStr . "\\" . $match;
        
        if (! isset($parent[$match]) && $hasMatch) 
        {
           // echo "$hasMatch, $match, $rootStr, $next, $preg<br/>\n";
            $parent[$match] = array();
            addChildern($parent[$match], $next, $fullList);
        }
    }
}

$sql = "SELECT SUBSTR(song_id FROM 1 FOR (LENGTH(song_id) - POSITION('\\\\' IN REVERSE(song_id))) ) AS parent, ost_name FROM playlist GROUP BY parent, ost_name"; 
$fullListRaw = json_decode(db_execRaw($sql), true);

$fullList = array();
foreach ($fullListRaw['data'] as $entry) {
    // gotta swap the filepath OSTs for the registered OSTs
    // this is important for selecting by OST later down the line
    $currRowSplit = explode("\\", $entry['parent']);
    array_pop($currRowSplit);
    $currRowSplit[] = $entry['ost_name'];
    $currRowProper = implode("\\", $currRowSplit);
    $fullList[] = $currRowProper;
}
$rootStr = explode("\\", $fullList[0])[0];
echo $rootStr."<br/><br/>";
$tree = array();
$tree[$rootStr] = array();
addChildern($tree[$rootStr], $rootStr, $fullList); 
print_r($tree);
$sweetsweetjson = json_encode($tree);
$sweetsweetjson = str_replace("[]", "{}", $sweetsweetjson); // convert leaves from array to object to make parsing easier
echo "<br/><br/>".$sweetsweetjson; 

$fhdl = fopen(dirname(__FILE__)."/../ost_tree.json", 'w');
fwrite($fhdl, $sweetsweetjson);
        