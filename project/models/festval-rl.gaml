model festival_fair

global {
	float step <- 1 #s;
	float min_speed <- 0.5 #m / #s;
	float max_speed <- 3.0 #m / #s;
	float max_ht <- 30.0;
	string server_url <- "http://localhost";
	int num_rl <- 0;
	bool stop <- false;
	int use_case <- 4;
	
	list<point> goals <- [
		{50, 30}, {90, 30}, {70, 50}, {90, 70}, {50, 70}, {10, 70}];
	
	int num_people <- 200;
	// graph festival_grounds;
	
//	list<point> stage_locations <- [[20, 20], [40, 40], [60, 60], [80, 80]]; // diagonal
	list<point> stage_locations <- [[30, 30], [30, 70], [70, 30], [70, 70]];
	list<float> light_vals <- [1.0, 0.0, 0.0, 0.4];
	list<float> sound_vals <- [0.0, 1.0, 0.0, 0.4];
	list<float> video_vals <- [0.0, 0.0, 1.0, 0.4];
	list<people> all_people <- [];
	list<stage> all_stages <- [];
	
	
	init {
		loop i from: 1 to: 4 {
			create stage {
				if use_case = 1 {
					radians <- i*90.0;
				} else if use_case = 2 or use_case = 3 {
					radians <- i*180.0 + 90;
					if i mod 2 = 0 {
						center <- {40, 40};
					} else {
						center <- {60, 60};
					}
				}
				if use_case = 4 {
					center <- stage_locations at (i-1);
				}
				
				
			}
		}
		all_stages <- stage.population;	
		write "Stages: " + length(all_stages);
		loop s over: all_stages{
			write "stage at: " + s.radians;
		}
		create people number: num_people {
			speed <- rnd(min_speed, max_speed);	
		}
		all_people <- people.population;
		
		
		
		
	}
	
	reflex when: cycle > 50 and num_rl < 1{
		if use_case = 4 {
			create rl number: 1 {
				goal <- goals at 0;
				remove from: goals index: 0;
				location <- {10, 30};
			}
		} else {
			create rl number: 1 {
				goal <- {90, 50};
				location <- {10, 50};
				
			}	
		}
		
		num_rl <- num_rl + 1;
	}
	
	reflex when: stop {
		do pause;
	}
	
//	reflex save_training_data when: (cycle mod 1 = 0) {
//		list<point> locations <- [];
//		
//		loop p over: all_people {
//			locations <- locations + p.location;
//		}
//		save(locations) 
//			to: "data/pls"+cycle+".csv" format: "csv"; // lmao the documenation says this is "type" but it is actually "format"
//		
//	}
}

species stage skills: [moving] {
	float radians;
	point center;
	
	reflex rotate_big_crowd when: use_case = 1 {
		radians <- radians + 1; //#pi/180;	
		float x  <- cos(radians)*10 + 50;
		float y <- sin(radians)*10 + 50;
		location <- {x, y};
	}
	
	reflex rotate_center when: use_case = 2 {
		radians <- radians + 1; //#pi/180;	
		float x  <- cos(radians)*10 + center.x;
		float y <- sin(radians)*10 + center.y;
		location <- {x, y};
	}
	
	reflex rotate3 when: use_case = 3 {
		float x  <- cos(radians)*10 + center.x;
		float y <- sin(radians)*10 + center.y;
		location <- {x, y};
	}
	
	reflex uc4 when: use_case = 4 {
		location <- center;
	}
}


species people skills: [moving, fipa] {
	rgb color <- #yellow ;
	point target_dest <- nil;
	bool travelling <- false;
	stage my_choice <- nil;

	reflex select_stage when: cycle mod 150 = 0 {
		my_choice <- one_of(all_stages);
		if rnd(100) < 15 {
			my_choice <- nil;
		}
	}
	
	reflex every_tick when: target_dest = nil {
		if target_dest = nil {
			do wander;
		}
	}
	
	reflex move {
		if my_choice != nil {
			target_dest <- my_choice.location;
			if target_dest distance_to location < 2 {
				travelling <- false;
			}
			if target_dest distance_to location > 9 {
				travelling <- true;
			}
			
		}
		if travelling {
			do goto target: target_dest;
		} else {
			do wander;
		}

		
	}
	
	
	aspect base {
		draw circle(1) color: color border: #black;
	}
}

species rl skills: [moving, network] {
	rgb color <- #pink;
	point goal <- nil;
	point target_dest <- nil;
	int logical_time <- 0;
	bool connected <- false;
	list<point> hist_path <- [];
	float utility <- 0.0;
	bool goal_reached <- false;
	
	reflex update_utility {
		loop p over: all_people {
			float dist <- p.location distance_to location;
			if  dist < 2.0 {
				utility <- utility - (2 - dist)/2;
			}
		}
		if location distance_to goal < 2 and !goal_reached {
			utility <- utility + 100;
			write "RL Utility: " + utility;
			if use_case = 4 {
				if length(goals) > 0 {
					write "Achieved Goal: " + goal;
					goal <- goals at 0;
					remove from: goals index: 0;
				} else {
					stop <- true;
				}
			} else {
				stop <- true;
			}
		}
	}
	
	reflex send_data {
		list<point> locs <- [];
		loop p over: all_people {
			locs <- locs + p.location;
		}
		logical_time <- logical_time + 1;
        hist_path <- hist_path + location;
        // Serialize JSON yourself
	    string body <- ""+goal.x+"\t"+goal.y+"\t"+location.x+"\t"+location.y+"\t"+logical_time+"\t"+locs;
		if !connected {
		    do connect to: server_url protocol: "http" port: 7654 with_name: "rlserver";
			connected <- true;
		}
	
	    do send to: "/update" contents: [
	      "POST", 
	      body, 
	      ["Content-Type"::"application/json"]
	    ];
        

//        write "sent" + logical_time;
//        do post to: "server" data: json_data;
	}
	
	reflex write_pos when: cycle mod 5 = 0 {
		write "RL Loc: " + location;
	}
	
	
	reflex get_destination when: has_more_message() {
		message msg <- fetch_message();
		
        // Parse JSON response
        map<string, unknown> response <- msg.contents as map<string, unknown>;
        string bdy <- response["BODY"];
//		write "Got Msg: " + bdy;
		
		int si <- 0;
		loop i from: 0 to: length(bdy) {
			if bdy at i = "," {
				si <- i;
				break;
			}
		}
		string sdx <- "";
		string sdy <- "";
		loop i from: 0 to: length(bdy) {
			if i < si {
				sdx <- sdx + bdy at i;
			} else if i > si {
				sdy <- sdy + bdy at i;
			}
		}
//		write "data  " + sdx + " " + sdy;
		float tdx <- sdx as float;
		float tdy <- sdy as float;
		target_dest <- {tdx, tdy};
//		write "New Dest: " + target_dest;
        // Extract new goal from JSON

	}
	
	reflex move when: target_dest != nil {
		do goto target: target_dest;
	}
	
	aspect base {
		draw triangle(2) color: color border: #black;
		draw polyline(hist_path) color: #blue width: 2;
	}
	
}

species introvert skills: [moving] {
	rgb color <- #pink;
	point goal <- nil;
	point target_dest <- nil;
	int logical_time <- 0;
	bool connected <- false;
	list<point> hist_path <- [];
	float utility <- 0.0;
	bool goal_reached <- false;
	
	
	reflex move when: goal != nil {
		hist_path <- hist_path + location;
		do goto target: goal;
	}
	
	reflex update_utility {
		loop p over: all_people {
			float dist <- p.location distance_to location;
			if  dist < 2.0 {
				utility <- utility - (2 - dist)/2;
			}
		}
		if location distance_to goal < 2 and !goal_reached {
			utility <- utility + 100;
			write "Introvert Utility: " + utility;
			if use_case = 4 {
				if length(goals) > 0 {
					write "Achieved Goal: " + goal;
					goal <- goals at 0;
					remove from: goals index: 0;
				} else {
					stop <- true;
				}
			} else {
				stop <- true;
			}
		}
	}
	
	aspect base {
		draw triangle(2) color: color border: #black;
		draw polyline(hist_path) color: #blue width: 2;
	}
	
}


experiment festival_traffic type: gui {
	parameter "Number of people agents" var: num_people category: "People" ;
	parameter "minimal speed" var: min_speed category: "People" min: 0.1 #km/#h ;
	parameter "maximal speed" var: max_speed category: "People" max: 10 #km/#h;
	
	output {
		display festival_display type: 2d {
			species people aspect: base;
			species rl aspect: base;
			species introvert aspect: base;
		}
	}
}