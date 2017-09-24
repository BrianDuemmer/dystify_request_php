<!DOCTYPE HTML>
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=Cp1252">
<title>Database Tester</title>

<!-- JS / JQuery functions -->
<script type="text/javascript" src="/js/jquery.min.js"></script>
<script type="text/javascript">
			$(document).ready(function()
			{
				// on clicking the button, POST down the sql to the database
				$("#eval_sql").click(function()
				{
					var sql = $("#sql_entry").val();
					$.post( "dbPostExec.php",
							{"sql": sql},
							function(result)
							{
								$("#res_p").html(result);
							});
				});
			});

				
</script>

</head>
<body>
	<h2>SQL Entry</h2>
	<p>SQL code run here will be executed on the dystrack database. The
		database this runs on is not live.</p>

	<textarea id="sql_entry" rows="25" cols="75"></textarea>
	<br />
	<button id="eval_sql">Evaluate</button>
	<hr>
	
	<p id="res_p">RESULTS:</p>
	<table id="sql_results"></table>
</body>
</html>