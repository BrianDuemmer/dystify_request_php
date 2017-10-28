<?php
	require_once $_SERVER['DOCUMENT_ROOT'] . '/kkdystrack/php/inc/dbUtil.php';
	
	$counts = json_decode(db_execRaw(
			"SELECT COUNT(*) AS t, 
			SUM(is_nohr) AS n, 
			COUNT(8)-SUM(is_nohr) AS h 
			FROM fire_emblem_minigame"))->data[0];
	
	$nohrUsers = json_decode(db_execRaw(
			"SELECT 
				viewers.username AS nohr 
			FROM 
				viewers 
			JOIN fire_emblem_minigame ON 
				fire_emblem_minigame.user_id = viewers.user_id 
			WHERE fire_emblem_minigame.is_nohr=1
			ORDER BY nohr DESC;"))->data; 
	
	$hosheidoUsers = json_decode(db_execRaw(
			"SELECT
				viewers.username AS hoshido
			FROM
				viewers
			JOIN fire_emblem_minigame ON
				fire_emblem_minigame.user_id = viewers.user_id
			WHERE fire_emblem_minigame.is_nohr=0
			ORDER BY hoshido DESC;"))->data;
	
	$tbl_html = '';
	for($i = 0; $i < max(count($nohrUsers), count($hosheidoUsers)); $i++) {
		$tbl_html .= "<tr><td>";
		$tbl_html .= $hosheidoUsers[$i]->hoshido;
		$tbl_html .= "</td><td>";
		$tbl_html .= $nohrUsers[$i]->nohr;
		$tbl_html .= "</td></tr>\n";
	}
	
	$winningTeam = ($counts->n < $counts->h ? "Hoshido" : "Nohr");
	$diff_user = abs($counts->n - $counts->h);
	$diff_pct = $counts->t ? round(100 * $diff_user/$counts->t) : 0; 
	$ppltxt = ($diff_user == 1 ? "person (so close!)" : "people");
	
	if($diff_user != 0) {
		$disp_txt = "Team $winningTeam is winning by $diff_user $ppltxt ($diff_pct%)!";
	} else {
		$disp_txt = "Oh my, it seems we have a tie on our hands...";
	}
?>
<!DOCTYPE HTML>
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=Cp1252">
<title>Team Standings</title>

<style>
table {
    font-family: arial, sans-serif;
    border-collapse: collapse;
    width: 60%;
}

td, th {
    border: 1px solid #dddddd;
    text-align: center;
    padding: 5px;
    width: 30%;
}

tr:nth-child(even) {
    background-color: #dddddd;
}

p {
	font-size: small; 
	text-align: center;
	font-style: italic;
}
</style>
</head>

<body>
	<h1 style="text-align: center;"><strong>TEAM STANDINGS:</strong></h1>
	<h4 style="text-align: center;"><?php echo $GLOBALS['disp_txt']?></h4>
	<p>NOTE: Your name will only appear if you <a href="https://dystify.com/kkdystrack/php/login.php">register</a> with K. K. DysTrack!</p>            
	<table width="100%" align="center">
		<tbody>
			<tr> <th>HOSHIDO</th> <th>NOHR</th> </tr>
			<?php echo $GLOBALS['tbl_html']?>
		</tbody>
	</table>
</body>
</html>

