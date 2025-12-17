model festival_fair

global {
	float step <- 1 #s;
	float min_speed <- 0.5 #m / #s;
	float max_speed <- 3.0 #m / #s;
	float max_ht <- 30.0;
	string server_url <- "http://localhost";
	
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
				radians <- i*90.0;
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
		
		create rl number: 1 {
			goal <- {50, 50};
			location <- {10, 10};
			
		}
		
		
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
	
	reflex rotate {
		radians <- radians + 1; //#pi/180;	
		float x  <- cos(radians)*29 + 50;
		float y <- sin(radians)*29 + 50;
		location <- {x, y};
		write "loc: " + location + " -- " + radians;
	}
}


species people skills: [moving, fipa] {
	rgb color <- #yellow ;
	point target_dest <- nil;
	bool travelling <- false;
	stage my_choice <- nil;

	reflex select_stage when: cycle mod 120 = 0 {
		my_choice <- one_of(all_stages);
//		write "choice: " + my_choice.radians;
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
	
	reflex send_data {
		list<point> locs <- [];
		loop p over: all_people {
			locs <- locs + p.location;
		}
		logical_time <- logical_time + 1;
        
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
        

        write "sent" + logical_time;
//        do post to: "server" data: json_data;
	}
	
	
	reflex get_destination when: has_more_message() {
		message msg <- fetch_message();
		
        // Parse JSON response
        map<string, unknown> response <- msg.contents as map<string, unknown>;
        string bdy <- response["BODY"];
		write "Got Msg: " + bdy;
		
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
		write "data  " + sdx + " " + sdy;
		float tdx <- sdx as float;
		float tdy <- sdy as float;
		target_dest <- {tdx, tdy};
		write "New Dest: " + target_dest;
        // Extract new goal from JSON

	}
	
	reflex move when: target_dest != nil {
		do goto target: target_dest;
	}
	
	aspect base {
		draw triangle(1) color: color border: #black;
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
		}
	}
}