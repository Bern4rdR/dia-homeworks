model festival_fair

global {
	string server_url <- "http://localhost";
	float step <- 1 #s;
	float min_speed <- 0.5 #m / #s;
	float max_speed <- 3.0 #m / #s;
	float max_ht <- 30.0;
	int num_rl <- 0;
	
	int num_people <- 200;
	
	bool wandering_enabled <- true;
	
//	list<point> stage_locations <- [[20, 20], [40, 40], [60, 60], [80, 80]]; // rl use case 1 and 2
	list<point> stage_locations <- [{45, 45}, {55, 45}, {45, 55}, {55, 55}]; // rl use case 3 and 4
	list<float> light_vals <- [1.0, 0.0, 0.0, 0.4];
	list<float> sound_vals <- [0.0, 1.0, 0.0, 0.4];
	list<float> video_vals <- [0.0, 0.0, 1.0, 0.4];
	list<people> all_people <- [];
	list<bar> all_bars <- [];
	
	float introvert_average_utility <- 0.0;
	float rl_utility <- 0.0;
	list<introvert> intros <- nil;
	patient_friend pf <- nil;
	
	
	init {
		loop i from: 0 to: 3 {
			create bar {
				location <- stage_locations at i-1;
				radians <- i*90.0;
			}
		}
		all_bars <- bar.population;	
		write "Bars: " + length(all_bars);
		loop s over: all_bars{
			write "bar at: " + s.radians;
			create bartender {
				location <- s.location;
				color <- #brown;
				my_bar <- s;
			}
		}
		
		create extrovert number: num_people/5 { color <- #yellow; }
		create introvert number: num_people/20 { color <- #red; }
		create grouping number: num_people/5 { color <- #green; }
//		create bartender number: num_people/5 { color <- #brown; }
		create salesperson number: num_people/5 { color <- #blue; }
		
		// rl use case 3 and 4
		create patient_friend {
			location <- {75, 50};
			meeting_loc <- {75, 50};
		}
		pf <- patient_friend.population at 0;

		all_people <- extrovert.population + grouping.population + bartender.population + salesperson.population + introvert.population;
		intros <- introvert.population;
		
		
	}
	
	reflex spawn_rl when: cycle > 50 and num_rl < 1{
//		if use_case = 4 {
//			create rl number: 1 {
//				goal <- goals at 0;
//				remove from: goals index: 0;
//				location <- {10, 30};
//			}
//		} else {
		create rl number: 1 {
			goal <- {90, 50};
			location <- {10, 50};
			
		}	
//		}
		
		num_rl <- num_rl + 1;
	}
	
	reflex report_introvert_utility {
		float t_util <- 0.0;
		loop it over: intros {
			t_util <- t_util + it.utility;
		}
		introvert_average_utility <- t_util/length(intros);
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

species bar skills: [moving] {
	float radians;
	rgb color <- #red;
	
	aspect base {
		draw rectangle({4, 3}) color: color border: color;
	}
	
//	reflex rotate {
//		radians <- radians + 1; //#pi/180;	
//		float x  <- cos(radians)*29 + 50;
//		float y <- sin(radians)*29 + 50;
//		location <- {x, y};
//		write "loc: " + location + " -- " + radians;
//	}
}


species people skills: [moving, fipa] {
	rgb color <- #yellow ;
	point target_dest <- nil;
	bool travelling <- false;
	bar my_choice <- nil;
	bool has_beer <- false;
	float beer_left <- 0.0;
	
	float drunkness <- 0.0;

	reflex select_stage when: cycle mod 120 = 0 {
		my_choice <- one_of(all_bars);
		if wandering_enabled {
			if rnd(100) < 50 {
				my_choice <- nil;
			}
		}
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
	
	action buy_beer(bartender bt) {
		do start_conversation
			to: [bt]
			protocol: 'fipa-propose'
			performative: 'request'
			contents: ['Jag skulle gillar ölen, tack!']
		;
	}
	
	reflex accept_beer when: !empty(accept_proposals) {
		has_beer <- true;
		beer_left <- 1.0;
	}
	
	reflex drink_beer when: has_beer {
		float delta <- rnd(0.1);
		drunkness <- drunkness + delta;
		beer_left <- beer_left - delta;
		if beer_left <= 0.0 {
			has_beer <- false;
		}
	}
	
	aspect base {
		draw circle(1) color: color border: #black;
	}
}

species patient_friend parent: people {
	point meeting_loc <- nil;
	reflex move {
		if meeting_loc != nil {
			if location distance_to meeting_loc > 4 {
				do goto target: meeting_loc;
			} else {
				do wander;
			}
		} else {
			do wander;
		}
	}
	
	aspect base {
		draw rectangle({1, 1}) color: #blue;
	}
}


species extrovert parent: people {
	float generocity <- rnd(1.0, 2.0); // probability multiplier
	float networking_skills;
	// trait #3
	
	reflex encounter when: !empty(people at_distance 2) {
		agent person <- one_of(people at_distance 2);
		
		switch species_of(person) {
			match introvert {
				write "met introvert";
				
				if (rnd(0, generocity) < 0.5) { return; }
				
				do start_conversation
					to: [person]
					protocol: 'fipa-propose'
					performative: 'request'
					contents: ['let me buy you a drink']
				;
			}
			
			match salesperson {
				write "met salesperson";
				
				if (rnd(0, generocity) < 0.5) { return; }
				
				do start_conversation
					to: [person]
					protocol: 'fipa-propose'
					performative: 'propose'
					contents: ['i will buy from you']
				;
				
				list<grouping> local_peers <- grouping at_distance 5;
				if (empty(local_peers)) { return; }
				do start_conversation // used by grouping person to give in to peer pressure
					to: local_peers
					protocol: 'fipa-propose'
					performative: 'inform'
					contents: ['i bought from this salesperson']
				;
			}
			
			default {
				write "met " + species_of(person);
			}
		}
	}
	
	reflex recv  when: !empty(informs) {
		message msg <- informs at 0;
		if (string(msg.contents) contains 'here is your drink') {
			drunkness <- drunkness + 1;
		}
	}
}

species introvert parent: people {
	float social_capacity;
	float tiredness;
	float social_decay;
	list<people> friends;
	float utility <- 0.0;
	bool immune <- false;
	point goal  <- nil;
	bool goal_reached <- false;
	bool escaping <- false;
	bool init <- false;
	list<point> hist_path <- [];
	bool exiting <- false;
	// trait #3
	
	reflex init when: !init {
		init <- true;
		bartender bt <- one_of(bartender.population);
		list<people> notsales <- extrovert.population + grouping.population + introvert.population;
		friends <- friends + bt;
		loop while: length(friends) < 3 {
			people nasta <- one_of(notsales);
			if nasta != self {
				friends <- friends + nasta;
			} 
		}
		// use case 3 and 4
		friends <- [pf];
		goal <- (friends at 0).location;
		remove from: friends index: 0;
	}
	
	action run_away(point ploc, bool always_run) {
		if rnd(100) < 100*(1-social_capacity) or always_run {
			// run away
			point delta <- ploc - location;
			point escape <- {-2 * delta.x, -2 * delta.y};
			target_dest <- escape;
			escaping <- true;
		}
	}
	
	action drop_social_capacity {
		social_capacity <- social_capacity * (1 - social_decay);
	}
	
	reflex onwards when: goal != nil {
		target_dest <- goal;
	}
	
	reflex set_goal when: length(friends) > 0 {
		goal <- (friends at 0).location;		
	}
	
	reflex move when: target_dest != nil {
		do goto target: target_dest;
		hist_path <- hist_path + location;
	}
	
	reflex escape_reset when: escaping and location distance_to target_dest < 0.5 {
		target_dest <- goal;
		escaping <- false;
	}
	
	reflex update_utility when: !immune {
		loop p over: all_people {
			float dist <- p.location distance_to location;
			if  dist < 2.0 {
				utility <- utility - (2 - dist)/2;
			}
		}
		if location distance_to goal < 4 {
			utility <- utility + 10;
			if exiting {
				immune <- true;
				remove self from: all_people;
//				do die;
			}
			if length(friends) > 0 {
				remove from: friends index: 0;
			} else {
				goal <- {50, -10};
				exiting <- true;
			}
		}
	}
	
	reflex encounter when: agent_closest_to(self) distance_to location < 1 {
		agent person <- agent_closest_to(self);
		
		if species_of(person) != introvert {
			do drop_social_capacity;
		}
		
		switch species_of(person) {
			match grouping {
				write "met grouping person";
				// run away
				do run_away(person.location, true);
			}
			match bartender {
				write "met bartender";
				// buy beer
				do buy_beer(bartender(person));
			}
			match salesperson {
				// run away
				write "met salesperson";
				do run_away(person.location, true);
			}
			match extrovert {
				write "met extrovert";
				// run away
				do run_away(person.location, false);
			}
			match introvert {
				write "met introvert";
				// no worries
			}
			default {
				write "met " + species_of(person);
			}
		}
	}
	
	aspect base {
		draw triangle(2) color: color border: #black;
		draw polyline(hist_path) color: #blue width: 2;
	}
}

species grouping parent: people {
	float peer_pressure <- rnd(1.0, 2.0); // probability multiplier
	int group_size <- rnd(3, 7);
	int observed_sales <- 0;
	
	reflex seek_group {
		if (!travelling) {
			list<extrovert> nearby_extroverts <- extrovert at_distance 15;
			
			if (!empty(nearby_extroverts) and length(nearby_extroverts) < group_size) {
				point center_of_group <- mean(nearby_extroverts collect each.location);
				target_dest <- center_of_group; 
			}
		}
	}
	
	reflex encounter when: agent_closest_to(self) distance_to location < 1 {
		agent person <- agent_closest_to(self);
		
		switch species_of(person) {
			match extrovert {
				write "met extrovert";
			}
			match salesperson {
				write "met salesperson";
				
				if (observed_sales > 0 and flip(peer_pressure)) {
					do start_conversation
						to: [person] // seller
						protocol: 'fipa-propose'
						performative: 'propose'
						contents: ['i will buy too']
					;
					
					observed_sales <- 0;
				}
			}
			default {
				write "met " + species_of(person);
			}
		}
	}
	
	reflex listen_to_influence when: !empty(informs) {
		loop msg over: informs {
			if (string(msg.contents) contains 'i bought') {
				observed_sales <- observed_sales + 1;
			} else if (string(msg.contents) contains 'here is your drink') {
				drunkness <- drunkness + 0.5;
			}
		}
		informs <- [];
	}
	
} 

species bartender parent: people {
	float serving_tolerance <- rnd(2.0, 4.5);
	float charm_tolerance <- rnd(1.0, 5.0);
	bar my_bar <- nil;
	// trait #3
	
	reflex encounter when: agent_closest_to(self) distance_to location < 1 {
		agent person <- agent_closest_to(self);
		
		switch species_of(person) {
			match extrovert {
				write "met extrovert";
				
				if (extrovert(person).drunkness < serving_tolerance or extrovert(person).networking_skills > charm_tolerance) {
					write "served customer";
				}
			}
			
			match grouping {
				write "met grouping person";
				
				if (grouping(person).drunkness < serving_tolerance) {
					write "served customer";
					do start_conversation
						to: [person]
						protocol: 'fipa-propose'
						performative: 'inform'
						contents: ['here is your drink']
					;
				}
			}
			default {
				write "met " + species_of(person);
			}
		}
	}
	
	reflex sell_beer when: !empty(requests) {
		loop msg over: requests { 
			do accept_proposal
				message: msg
				contents: ['Enjoy, tack!']
			;	
		}
		
	}
	
	reflex move {
		if location distance_to my_bar.location > 2 {
			target_dest <- my_bar.location;
		}
		if target_dest != nil and location distance_to target_dest < 0.1 {
			target_dest <- nil;
		}
		if target_dest != nil {
			do goto target: target_dest;
		} else {
			do wander;
		}
	}
}

species salesperson parent: people {
	int selling_quota;
	string target_demographic;
	// trait #3
	
	reflex encounter when: agent_closest_to(self) distance_to location < 1 {
		agent person <- agent_closest_to(self);
		
		switch species_of(person) {
			match introvert {
				write "met introvert";
			}
			match bartender {
				write "met bartender";
			}
			default {
				write "met " + species_of(person);
			}
		}
	}
}

species rl parent: introvert skills: [moving, network] {
	int logical_time <- 0;
	bool connected <- false;
	rgb color <- #pink;
	
	reflex encounter when: agent_closest_to(self) distance_to location < 1 {
		
	}
	
	reflex onwards when: goal != nil {
//		target_dest <- goal;
	}
	
	reflex send_data when: goal != nil {
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
	
	reflex report_utility {
		rl_utility <- utility;
	}
	
//	reflex move when: target_dest != nil {
//		do goto target: target_dest;
//	}
	
	aspect base {
		draw triangle(2) color: color border: #black;
		draw polyline(hist_path) color: #orange width: 2;
	}
	
}



experiment festival_traffic type: gui {
	parameter "Number of people agents" var: num_people category: "People" ;
	parameter "minimal speed" var: min_speed category: "People" min: 0.1 #km/#h ;
	parameter "maximal speed" var: max_speed category: "People" max: 10 #km/#h;
	
	output {
		display festival_display type: 2d {
			species extrovert aspect: base;
			species introvert aspect: base;
			species grouping aspect: base;
			species bar aspect: base;
			species bartender aspect: base;
			species salesperson aspect: base;
			species rl aspect: base;
			species patient_friend aspect: base;
		}
		display Statistics type: 2d{
			chart "Introvert Utility" type: series position:{0,0} size:{1.0,0.5}{
				//data "Cycle" value: cycle;
				 data "Utility" value: introvert_average_utility;
			}
			
			chart "RL Agent Utility" type: series position:{0,0.5} size:{1.0,0.5}{
				data legend: "RL Utility" value: rl_utility;
			}
			
		}
	}
}