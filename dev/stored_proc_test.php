<?php
	require_once $_SERVER['DOCUMENT_ROOT'] . '/kkdystrack/php/dbUtil.php';
	
	if($_SERVER['REQUEST_METHOD'] == 'POST') {
		echo "foo:" . $_POST['foo'] . '<br/>';
		
		$q = db_verifyConnected()->real_escape_string($_POST['foo']);
		$sql = "CALL P_DUMMY_PROC('$q')";
// 		$ps = db_prepareStatement($sql);
// 		$ps->bind_param('s', $q);
// 		$ps->execute();
// 		$res = array();
// 		$ps->bind_result($res[0], $res[1], $res[2], $res[3], $res[4], $res[5]);
// 		print_r($res);
		
		echo $sql . '<br/>';
		echo db_rstojson(db_verifyConnected()->query($sql));
	}
?>
