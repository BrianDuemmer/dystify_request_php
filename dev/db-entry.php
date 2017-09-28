<!DOCTYPE HTML>
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=Cp1252">
<title>Database Tester</title>

<style>
table {
    font-family: arial, sans-serif;
    border-collapse: collapse;
    width: 100%;
}

td, th {
    border: 1px solid #dddddd;
    text-align: left;
    padding: 5px;
}

tr:nth-child(even) {
    background-color: #dddddd;
}
</style>

<!-- JS / JQuery functions -->
<script type="text/javascript" src="/js/jquery.min.js"></script>
<script type="text/javascript">
			$(document).ready(function()
			{
				// on clicking the button, POST down the sql to the database...
				$("#eval_sql").click(function()
				{
					var sql = $("#sql_entry").val();
					$.post( "dbPostExec.php",
							{"sql": sql},
							function(result) //... and populate the results into a table
							{
// 								alert(result);
								rs = JSON.parse(result);
								
								var tblDat = "<tr>";
								
								for(var c=0; c<rs.cols.length; c++) 
									{ tblDat += "<th>" +rs.cols[c]+ "</th>" }
								
								tblDat += "</tr>";

								for(var r=0; r<rs.data.length; r++) { 
									tblDat +="<tr>";
									
									for(var i=0; i<rs.cols.length; i++)
										{ tblDat += "<td>" +rs.data[r][rs.cols[i]]+ "</td>"; }
									
									tblDat +="</tr>";
								}

								$("#sql_results").html(tblDat);
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