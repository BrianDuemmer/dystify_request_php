<?php
    require_once $_SERVER['DOCUMENT_ROOT'] . '/kkdystrack/php/inc/dbUtil.php';
    $teams_raw = json_decode(db_execRaw("SELECT v.username, t.team FROM team_minigame t INNER JOIN viewers v ON v.user_id=t.user_id ORDER BY v.username ASC"), true)['data'];
//     print_r($teams_raw);
    // store all of the team members in arrays corresponding to their team
    $mario = array();
    $luigi = array();
    $peach = array();
    $yoshi = array();
    
    //populate the respective arrays
    foreach ($teams_raw AS $member) {
        $vw = $member['username'];
        switch(strtolower($member['team'])) {
            case 'l':
                $luigi[] = $vw;
                break;
            case 'm':
                $mario[] = $vw;
                break;
            case 'p':
                $peach[] = $vw;
                break;
            case 'y':
                $yoshi[] = $vw;
                break;
        }
        
        //fetch the most populated team
        $max = max(count($luigi), count($mario), count($peach), count($yoshi));
        $tbl_inner = '';
        
        for($i=0; $i<$max; $i++) {
            $tbl_inner .= "<tr><td>";
            $tbl_inner .= $luigi[$i];
            $tbl_inner .= "</td><td>";
            $tbl_inner .= $mario[$i];
            $tbl_inner .= "</td><td>";
            $tbl_inner .= $peach[$i];
            $tbl_inner .= "</td><td>";
            $tbl_inner .= $yoshi[$i];
            $tbl_inner .= "</td></tr>\n";
        }
    }
?>

<!DOCTYPE html>
<html>
<head>
</head>

<body>
<div class="team_view">
	<img align=middle width=40% alt="Mario Party Teams" src="https://dystify.com/images/mp_teams.jpg"; ?>
	<p>Type !join M, L, P, or Y in stream chat to pick a team!</p>
	<table>
		<tbody>
			<tr><th>LUIGI</th><th>MARIO</th><th>PEACH</th><th>YOSHI</th></tr>
			<?php echo $GLOBALS['tbl_inner'];?>
		</tbody>
	</table>
</div>
</body>
</html>




