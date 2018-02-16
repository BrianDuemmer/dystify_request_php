<?php
	require_once $_SERVER['DOCUMENT_ROOT'] . '/kkdystrack/php/inc/dbUtil.php';
    
	$sql = "SELECT v.username, 
        SUBSTRING_INDEX(
            SUBSTRING_INDEX(
                i.response, 
                \"you paid 300 Rupees to add \\\"\", 
                -1), 
            \"\\\" to the New Year's Event queue. (\"
            , 1) 
        AS song FROM ifttt_log i INNER JOIN viewers v ON v.user_id=i.user_id WHERE i.command='!eventrequest' ORDER BY song DESC, i.time DESC";
	$res = json_decode(db_execRaw($sql), true)['data'];
	

	$tbl_inner = '';
	foreach($res AS $line) {
	    $tbl_inner .= "<tr><td>";
	    $tbl_inner .= $line['username'];
	    $tbl_inner .= "</td><td>";
	    $tbl_inner .= $line['song'];
	    $tbl_inner .= "</td></tr>\n";
	}
	$disp_txt = "Type !eventrequest <Your Song> in YouTube chat to request a song for the event!";
?>


<!DOCTYPE HTML>
<html>
<head>
<meta charset="utf-8"/>
<script>
			(function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){
  			(i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
			 m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
			  })(window,document,'script','//www.google-analytics.com/analytics.js','ga');

			  ga('create', 'UA-75150259-1', 'auto');
			  ga('send', 'pageview');
		</script>

		<div id="fb-root"></div>
			<script>(function(d, s, id) {
			  var js, fjs = d.getElementsByTagName(s)[0];
			  if (d.getElementById(id)) return;
			  js = d.createElement(s); js.id = id;
			  js.src = "//connect.facebook.net/en_US/sdk.js#xfbml=1&version=v2.5";
			  fjs.parentNode.insertBefore(js, fjs);
			}(document, 'script', 'facebook-jssdk'));</script>
<title>New Years Event</title>
<link href="css/bootstrap.css" rel="stylesheet" type="text/css" media="all" />
<!-- jQuery (necessary for Bootstrap's JavaScript plugins) -->
<script src="js/jquery.min.js"></script>
<!-- Custom Theme files -->
<!--theme-style-->
<link href="css/style.css" rel="stylesheet" type="text/css" media="all" />	
<!--//theme-style-->
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<meta name="keywords" content="Dystify Homepage" />
<script type="application/x-javascript"> addEventListener("load", function() { setTimeout(hideURLbar, 0); }, false); function hideURLbar(){ window.scrollTo(0,1); } </script>
<!--flexslider-->
<link rel="stylesheet" href="css/flexslider.css" type="text/css" media="screen" />
<!--//flexslider-->
<script src="js/easyResponsiveTabs.js" type="text/javascript"></script>
		    <script type="text/javascript">
			    $(document).ready(function () {
			        $('#horizontalTab').easyResponsiveTabs({
			            type: 'default', //Types: default, vertical, accordion            
			            width: 'auto', //auto or any width like 600px
			            fit: true   // 100% fit in a container
			        });
			    });
				
</script>
<script src="js/modernizr.custom.97074.js"></script>
<script type="text/javascript" src="js/jquery.hoverdir.js"></script>	
		<script type="text/javascript">
			$(function() {
			
				$(' #da-thumbs > li ').each( function() { $(this).hoverdir(); } );

			});
		</script>
<!--flexslider-->
<link rel="stylesheet" href="css/flexslider.css" type="text/css" media="screen" />
<!--//flexslider-->
<script src="js/jquery.chocolat.js"></script>
		<link rel="stylesheet" href="css/chocolat.css" type="text/css" media="screen" charset="utf-8">
		<!--light-box-files -->


</head>
<body> 
<!--header-->	
<div class="header" >
	<div class="header-top">
		<div class="container">
			<div class="head-top">
				<div class="logo">
					<h1><a href="index.html"><span>D</span>ystify</a></h1>
				</div>
			<div class="top-nav">		
			  <span class="menu"><img src="images/menu.png" alt=""> </span>
					<ul>
						<li><a  href="index"  >Home</a></li>
						<li><a  href="playlist"  >Playlist</a></li>
						<li><a  href="songlist"  >Song List</a></li>
						<li><a  href="streamfaq"  >FAQ</a></li>
						<li><a  href="https://youtube.com/c/Dystifyzer/live" target="_blank" >Live Stream</a></li>
						<li><a  href="https://discord.gg/a7S92js" target="_blank">Discord</a></li>
						<li><a  href="https://twitter.com/Dystify" target="_blank">Twitter</a></li>
						<div class="clearfix"> </div>
					</ul>

					<!--script-->
				<script>
					$("span.menu").click(function(){
						$(".top-nav ul").slideToggle(500, function(){
						});
					});
			</script>

				</div>
				
				<div class="clearfix"> </div>
		</div>
		</div>
	</div>
</div>
<!--banner-->
<div class="banner">
	<div class="container">
		<h2>.</h2>
		 <div class="banner-matter">
           	 <div class="slider">
                 
			  <script>window.jQuery || document.write('<script src="js/libs/jquery-1.7.min.js">\x3C/script>')</script>
			  <!--FlexSlider-->
			  <script defer src="js/jquery.flexslider.js"></script>
			  <script type="text/javascript">
			    $(function(){
			      SyntaxHighlighter.all();
			    });
			    $(window).load(function(){
			      $('.flexslider').flexslider({
			        animation: "slide",
			        start: function(slider){
			          $('body').removeClass('loading');
			        }
			      });
			    });
			  </script>

			 </div>
		</div>	
	</div>
<!--title-->
</div>
<!--games-->
<div class="container">
		<div class="games">
		<h3>New Year's Event</h3>
			<section>
				<ul id="da-thumbs" class="da-thumbs">
<!-- <p style ="text-align: center;">Our Sonic Forces launch event will take place on Saturday, October 21 at 1 PM PDT (PST), 4 PM EDT (EST), 8 PM UTC, 9 PM BST, 10 PM CEST, 4 AM JST, 6 AM AEST!</p><br>
	<p style ="text-align: center;">During the event there will be a competition between the two rival kingdoms, Hoshido and Nohr. We will have different minigames to earn points as well as a final duel at the end of the event. Lead your team to victory by signing up now!</p>-->
<br>
<p style="text-align: center;"><b><?php echo $GLOBALS['disp_txt']?></b></p>
<br>          
<div class="bannerh2"><p style="text-align: center;"><!-- <img src="/images/sanicspeeed.jpg" alt="Sonic Forces Teams" style="width:60%"></p></div> <!--"width:700px;height:394px;"-->
	<div class="table"><table width="60%" align="center">
		<tbody>
			<tr> <th>Username</th> <th>Song</th> </tr>

			<?php echo $GLOBALS['tbl_inner']?>

		</tbody>

	</table></ul></div>
<div class="clearfix"> </div>
				</ul>
			</section>
			

	</div>
</div>
</div>
<!--footer-->
	<div class="footer">
		<div class="container">
			<div class="footer-top">
				<div class="col-md-4  top-footer">
					<ul>
						<li><a href="https://twitter.com/Dystify" target="_blank"><i></i></a></li>
						<li><a href="https://twitter.com/Dystify" target="_blank">Twitter</a></li>
					</ul>
				</div>
				<div class="col-md-4 top-footer">
					<ul>
						<li><a href="https://www.youtube.com/channel/UC8CDnZ97yyp9k88dxZkApeQ?sub_confirmation=1" target="_blank"><i class="youtube"></i></a></li>
						<li><a href="https://www.youtube.com/channel/UC8CDnZ97yyp9k88dxZkApeQ?sub_confirmation=1" target="_blank">Youtube</a></li>
					</ul>
				</div>
				<div class="col-md-4 top-footer">
					<ul>
						<li><a href="https://youtube.streamlabs.com/dystifyzer" target="_blank"><i class="facebook"></i></a></li>
						<li><a href="https://youtube.streamlabs.com/dystifyzer" target="_blank">Support&nbsp;Me</a></li>
						</ul>
				</div>
				<div class="clearfix"></div>
			</div>
			<ul class="footer-grid">
					<li><a  href="index"  >Home</a></li>
						<li><a  href="playlist"  >Playlist</a></li>
						<li><a  href="#"  >Song List</a></li>
						<li><a  href="streamfaq"  >FAQ</a></li>
						<li><a  href="https://youtube.com/c/Dystifyzer/live" target="_blank"  >Live Stream</a></li>
						<li><a  href="https://discord.gg/a7S92js" target="_blank" >Discord</a></li>
						<li><a  href="https://twitter.com/Dystify" target="_blank">Twitter</a></li>
					</ul>
					<p> © Dystify. All rights reserved.</p>
		</div>
	</div>

</body>

</html>



