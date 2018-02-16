<?php 
    require_once $_SERVER['DOCUMENT_ROOT'] . '/kkdystrack/php/inc/dbUtil.php';
    require_once $_SERVER['DOCUMENT_ROOT'] . '/kkdystrack/php/inc/util.php';
    
    session_start();
    
    /**
     * 
     * @param array $parent
     * @param string $name
     * @return string
     */
    function extractOstChildInfo($parent, $name) {
        if(count($parent) == 0) { // has no children, is a base layer OST
            return "<li><span>$name</span></li>";
        } else { // has kids, gotta recursively get rid of them
            $html = "<li><span>$name</span><ul>";
            foreach($parent as $key => $child) {
                $html .= extractOstChildInfo($child, $key);
            }
            $html .= "</ul></li>";
            return $html;
        }
    }
    
    
    function trimOstTreeRoot($ostTreeRaw) {
        if(count($ostTreeRaw) == 1) {
            return trimOstTreeRoot($ostTreeRaw[array_keys($ostTreeRaw)[0]]);
        } else {
            return $ostTreeRaw;
        }
    }
    
    
    
    
    
    $ostTree = array();
    $ostTree["Songs"] = trimOstTreeRoot(json_decode(file_get_contents($_SERVER['DOCUMENT_ROOT'] . '/kkdystrack/ost_tree.json'), true));
?>
<!DOCTYPE html>
<html>
    <head>
    	<title>Play songs on the 24/7 Nintendo Music Stream!</title>
        <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1" />
        
       	<script type="text/javascript" src='https://code.jquery.com/jquery-3.3.1.min.js' ></script>
       	<script type="text/javascript" src="https://cdn.datatables.net/1.10.16/js/jquery.dataTables.min.js" ></script>
        <script type="text/javascript" src="https://cdnjs.cloudflare.com/ajax/libs/moment.js/2.7.0/moment.min.js" ></script>
        <link rel="stylesheet" type="text/css" href="https://cdn.datatables.net/1.10.16/css/jquery.dataTables.min.css" ></link>
        
        <script type="text/javascript">
        	// Handlers
            $(document).ready(function() {
				// General init stuff
				$(".SongListContainer caption").text("Select an OST to View Songs!");
                
                $("#OstTree li:has(ul)").find("span").click(function () {
                    $(this).parent().children().toggle();
                    $(this).toggle();
                });

                var songsTbl = $("#SongListTbl").DataTable({
                    "scrollY":        "500px",
                    "scrollCollapse": true,
                    "paging":         false
                });

                var queueTbl = $("#QueueTbl").DataTable({
                    "scrollY":        "500px",
                    "scrollCollapse": true,
                    "paging":         false,
                    "ordering":	  false,
                    "searching": false
                });

                fetchQueue(queueTbl);
                setInterval(fetchQueue, 5000, queueTbl);

//                 alert(JSON.stringify(queueTbl));
                

                // Clicked on an OST
                $("#OstTree li:not(:has(ul))").find("span").click(function () {
                    var getParams = {};
                    getParams["ost"] = $(this).html();
                    
                    $.get("get_songs_by_ost.php", getParams)
                    	.done( function(raw) {
                        	var data = JSON.parse(raw).data;
							songsTbl.clear().draw();
                    		$(".SongListContainer caption").text("Game: ".concat(getParams["ost"]))
                    		for(i=0; i<data.length; i++) {
								addSongToTbl(data[i], songsTbl);
                    		}
                    		songsTbl.draw();
                    	});
                });

                openTab(null, "QueueContainer");
            });



           	function addSongToTbl(songdata, tbl) {
				var row = document.createElement("tr");
				row.setAttribute("data-songid", songdata.song_id);
				
				var song_name = document.createElement("td");
				song_name.textContent = songdata.song_name;

				var song_length = document.createElement("td");
				song_length.textContent = songdata.song_length;

				var cost = document.createElement("td");
				cost.textContent = songdata.cost;

				var rating = document.createElement("td");
				rating.textContent = fmtRatingDisp(songdata.rating_num, songdata.rating_pct);

				var last_play = document.createElement("td");
				last_play.textContent = songdata.last_play != null ? songdata.last_play : "(No Plays)";

				var times_played = document.createElement("td");
				times_played.textContent = songdata.times_played;

				row.addEventListener("click", function() {
					// Possibly replace with something nicer later
					var str = "Add \"" +songdata.ost_name+ " - " +songdata.song_name+ "\" to the queue for " +songdata.cost +" rupees?";
					if(confirm(str)) {
	                    var postParams = {};
	                    postParams["song_id"] = songdata.song_id;
	                    
	                    $.post("proc_request.php", postParams)
	                    	.done( function(raw) {
	                        	var data = JSON.parse(raw);
	                        	if(data.cost > 0) {
									var res = "Success! \"" +songdata.ost_name+ " - " +songdata.song_name+ "\" was added to the queue! ";
									if(data.eta > 0) {
										res += "It should play at approximately ";
										res += fmtEta(data.eta);
									} else {
										res += "We can't determine when it will play, though...";
									}
									alert(res);
		                       	} else {
			                       	alert("There was an issue processing your request, so your song could not be added. Info: " +raw);
		                       	}
	                    	});
					}
				});

				row.append(song_name, song_length, cost, rating, last_play, times_played);
				tbl.row.add(row);
           	}


           	function fmtRatingDisp(num, pct) {
				if(num == 0) {
					return "No Votes";
				} else {
					var voteStr = num == 1 ? ")" : "s)";
					return (pct*5).toFixed(1) +"/5 ("+ num.toString() +" vote" +voteStr;
				}
            }


           	
            function fetchQueue(tbl) {
                $.get("queueInfo.php")
                	.done( function(raw) {
                    	var data = JSON.parse(raw);
                		tbl.clear()
                		for(i=0; i<data.length; i++) {
                			addQueueEntryToTbl(data[i], tbl);
                		}
                		tbl.draw();
                	});
            }



            
        	function addQueueEntryToTbl(songdata, tbl) {
				var row = document.createElement("tr");
				row.setAttribute("data-songid", songdata.song_id);
				
				var disp_name = document.createElement("td");
				disp_name.textContent = songdata.disp_name;

				var song_length = document.createElement("td");
				song_length.textContent = songdata.song_length;

				var username = document.createElement("td");
				username.textContent = songdata.username;

				var rating = document.createElement("td");
				rating.textContent = fmtRatingDisp(songdata.rating_num, songdata.rating_pct);

				var last_play = document.createElement("td");
				last_play.textContent = songdata.last_play != null ? songdata.last_play : "(No Plays)";

				var times_played = document.createElement("td");
				times_played.textContent = songdata.times_played;

				var eta = document.createElement("td");
				eta.textContent = fmtEta(songdata.eta);

				row.append(disp_name, song_length, username, rating, last_play, times_played, eta);
				tbl.row.add(row);
        	}


        	function fmtEta(unixtime) {
            	if(unixtime > 0) {
					return moment.unix(unixtime).format('h:mm A');
            	} else {
                	return "Unknown";
            	}
        	}



        	function openTab(event, toShow) {
				// hide all the tabs to start, and show the one we want
				$(".TabElement").hide();
				$("#" +toShow).show();
				if(event != null) {
					$(".TabLink").removeClass("active");
					event.currentTarget.className += " active";
				}
        	}
        	
        </script>
        <style type="text/css">
           /*table{
                  display:block;
                  overflow:auto;
                  height:100%;
                  width:100%;
                  table-layout: fixed;
                  text-align: left;
                  border-collapse: collapse;
            }*/
            
            tbody tr:nth-child(odd) {background-color: #f2f2f2;}
            .SongListContainer tbody tr:hover {background-color: #99e5ff;}
            
            thead { 
                background: #2793e6e8;
            } 
            
            /*td, th {
                padding-bottom: 2px;
                padding-left: 6px;
                padding-right: 6px;
            }*/
            
            #RequestsContainer {
                display: grid;
                grid-template-columns: 1fr 2fr;
                justify-items: center;
                height: 600px;
            }
            
            .SongListContainer {
                width: 100%;
                height: 100%;
            }
            
            .BodyContainer {
                display: grid;
                grid-row-gap: 15px;
                grid-template-columns:1fr min-content;
                position: absolute;
                top: 0; right: 0; bottom: 0; left: 0;
                padding: 10px 0px 0px 10px;
            }
            
            .QueueContainera {
                display:block;
                font-size: 23;
                background-color: #f1f1f1; 
                padding-right: 25px;
            }
            
            #OstTree {
                height:100%;
                width:100%;
            }
            
            #ChatContainer {
                height: 100%;
                width: 400px;
            }
            
            #StreamContainer {
                width: 100%;
                height: 43.625vw;
                position: relative;
            }
            
            #OstTreeContainer {
                height: 600px;
                width: 100%;
                display: block;
                overflow: auto;
            }
            
            .ContentContainer {
                width: 100%;
                display: block;
                overflow: auto;
            }
            
            .TabBar button{
                background-color: inherit;
                float: left;
                border: none;
                outline: none;
                cursor: pointer;
                padding: 14px 16px;
                transition: 0.3s;
            }
            
            .TabBar {
                text-align: justify;
                overflow: hidden;
                border: 1px solid #ccc;
                background-color: #f1f1f1;
            }
            
            .TabBar button.active {
                background-color: #ccc;
            }
            
            .TabBar button:hover {
                background-color: #ddd;
            }
            
            .TabBar:after {
                content: '';
                display: inline-block;
                width: 100%;
            }
            
            #TabContainer {
                padding-bottom: 100px;
                min-height: 600px;
            }
            
            .TabElement {
                animation: tabFadeEffect 1s;
            }
            
            @keyframes tabFadeEffect {
                from {opacity: 0;}
                to {opacity: 1;}
            }
            
        </style>
    </head>
    
    
    <body>
        <div class="BodyContainer">
        	<div class="ContentContainer">
        		<div id="StreamContainer">
    				<iframe id='StreamVideo' height=100% width=100% src="https://www.youtube.com/embed/live_stream?channel=UC8CDnZ97yyp9k88dxZkApeQ&autoplay=0" frameborder="0" allowfullscreen ></iframe>
				</div>
				
				
				
				<div class="TabBar">
				 	<button class="TabLink active" onclick="openTab(event, 'QueueContainer')">Queue</button>
          			<button class="TabLink" onclick="openTab(event, 'RequestsContainer')">Request Songs</button>
                  	<button class="TabLink" onclick="openTab(event, 'MyRatingsContainer')">Rated By Me</button>
				</div>
				
				
				<div id="TabContainer">
                	<div id="RequestsContainer" class="TabElement">
                		<div id="OstTreeContainer">
                			<ul id="OstTree"> <?php echo extractOstChildInfo($ostTree["Songs"], "Songs")?> </ul>
            			</div>
                		<div class="SongListContainer">
                			<table id="SongListTbl">
                				<caption></caption>
                				<thead>
                					<tr class="TableHeader">
                						<th>Song Name</th>
                						<th>Length</th>
                						<th>Cost</th>
                						<th>Rating</th>
                						<th>Last Play</th>
                						<th>Times Played</th>
                					</tr>
                				</thead>
                				<tbody></tbody>
                			</table>
                		</div>
                	</div>
                	
                	
                	
                	<div id="QueueContainer" class="TabElement">
                		<table id="QueueTbl">
                				<caption>Current Queue</caption>
                				<thead>
                					<tr class="TableHeader">
                						<th>Song</th>
                						<th>Length</th>
                						<th>Requested By</th>
                						<th>Rating</th>
                						<th>Last Play</th>
                						<th>Times Played</th>
                						<th>Expected Play Time:</th>
                					</tr>
                				</thead>
                				<tbody></tbody>
                			</table>
                	</div>
                	
                	<div id="MyRatingsContainer" class="TabElement">
                		<p style="font-size: 24; height: 100%; width: 100%;  align-content: center;">My Ratings Here</p>
                		<?php require_once $_SERVER['DOCUMENT_ROOT'] . '/kkdystrack/php/login.php'; ?>
                	</div>
            	</div>
            </div>
			<iframe id='ChatContainer' src="//gaming.youtube.com/live_chat?v=1bsVC76xt2c&amp;dark_theme=1&amp;embed_domain=dystify.com" frameborder="0" scrolling="no" allowfullscreen="allowfullscreen"></iframe>
    	</div>
    </body>
</html>