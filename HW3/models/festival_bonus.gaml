model festival_fair

global {
	float step <- 1 #s;
	float min_speed <- 0.5 #m / #s;
	float max_speed <- 3.0 #m / #s;
	float max_ht <- 30.0;
	
	int num_people <- 100;
	// graph festival_grounds;
	
	list<point> stage_locations <- [[40, 20], [40, 40], [40, 60], [40, 80]];
	list<float> light_vals <- [1.0, 0.0, 0.0, 0.4];
	list<float> sound_vals <- [0.0, 1.0, 0.0, 0.4];
	list<float> video_vals <- [0.0, 0.0, 1.0, 0.4];
	
	init {		
		create people number: num_people {
			speed <- rnd(min_speed, max_speed);	
			lights <- rnd(1.0);
			sound <- rnd(1.0);
			video <- rnd(1.0);
			pref <- one_of(["low", "high"]);
		}
		int counter <- 0;
		list<people> visitors <- people where (each.color = #yellow);
		loop loc over: stage_locations {
			create stage {
				location <- loc;
				lights <- light_vals at counter;
				sound <- sound_vals at counter;
				video <- video_vals at counter;
				guests <- visitors;
				id <- counter;
			}
			counter <- counter + 1;
		}
		
	}
}

species stage skills: [fipa] {
	rgb color <- #blue;
	float lights;
	float sound;
	float video;
	int id;
	
	bool hasBroadcasted <- false;
	point position;
	list<people> guests;
	
	reflex inform when: !hasBroadcasted {
		write "broadcasting";
		loop g over: guests {
			do start_conversation
				to: [g]
				protocol: 'fipa_propose'
				performative: 'inform'
				contents: [lights, sound, video, location, id]
			;
		}
		hasBroadcasted <- true;
	}

	
	aspect base {
		draw square(3) color: color ;
	}
}

species people skills: [moving, fipa] {
	rgb color <- #yellow ;
	point target_dest <- nil;
	float lights;
	float sound;
	float video;
	float current_utility <- 0.0;
	string pref <- "low";
	list<float> base_utilities <- [];
	int stage_index <- 0;
	list<list> people_ut <- [];
	
	list<float> utility_vars <- [];
	float current_ut <- 0.0;
	
	bool hasProvidedUtility <- true;
	
	list<list> stage_prefs <- [[], [], [], []];
	list<int> stage_count <- [0, 0, 0, 0];
	
	float low_pop_ut(float x) {
		return 100.0 - x;
//		return 1000/((x^2)/100 + 1);
	}
	
	float high_pop_ut(float x) {
		return x*1.0;
//		return (x^2)/100;
	}
	
	point set_location(point stage_loc) {
		return point([stage_loc.x + rnd(-5, -1), stage_loc.y + rnd(-3, 3)]);
	}
	
	
	reflex choose_stage when: !empty(informs) {
		loop msg over: informs {
			list cnt <- list(msg.contents);
			float lt <- cnt at 0;
			float so <- cnt at 1;
			float vd <- cnt at 2;
			point stage_loc <- cnt at 3;
			float new_utility <- lights * lt + sound * so + video * vd;
			base_utilities <- base_utilities + new_utility;
			if new_utility >= current_utility {
				current_utility <- new_utility;
				target_dest <- set_location(stage_loc);
				stage_index <- cnt at 4;
			}
		}
		hasProvidedUtility <- false;
	}
	
	reflex message_leader when: !hasProvidedUtility {
		people leader <- people[0];
		hasProvidedUtility <- true;
		if leader = self {
			write "I am leader";
		}
		do start_conversation
			to: [leader]
			protocol: 'fipa_propose'
			performative: 'propose'
			contents: [self, base_utilities, pref, stage_index]
		;
	}
	
	reflex receive_data when: length(proposes) > 1 {
		float global_ut <- 0.0;
		// map of key stage index and value msg contents deliverd by other agents
		loop msg over: proposes {
			list data <- list(msg.contents);
			people_ut <- people_ut + [data];
			int st <- data at 3;
			stage_count[st] <- stage_count[st] + 1;
		}
		write "global util sum: " + global_ut;
		write "Stage Prefs 0: " + stage_count[0];
		write "Stage Prefs 1: " + stage_count[1];
		write "Stage Prefs 2: " + stage_count[2];
		write "Stage Prefs 3: " + stage_count[3];
		current_ut <- calc_global_utility(people_ut);
		write "Global utility with density: " + current_ut;
		
	}
	
	reflex global_coordinate when: length(people_ut) > 1 {
		int pind <- cycle mod num_people;
		int best_ind <- -1;
		list step_p <- people_ut[pind];
		float best_ut <- 0.0;
		int original_ind <- step_p[3];
		loop i from: 0 to: 3 step: 1 { // hardcoded num stages
			step_p[3] <- i;
			float util <- calc_global_utility(people_ut);
			if util > best_ut {
				best_ut <- util;
				best_ind <- i;
			}
		}
		step_p[3] <- best_ind;
		if best_ind != original_ind {
			do start_conversation
				to: [step_p[0]]
				protocol: 'fipa_propose'
				performative: 'request'
				contents: [best_ind]
			;
			write "Expected new global utility: " + best_ut;
		}
		
	}
	
	reflex go_to_new_stage when: !empty(requests) {
		message msg <- requests at 0;
		int new_stage_index <-  list(msg.contents) at 0;
		write "Moving to new stage: " + new_stage_index + " from previous stage: " + stage_index + " pref " + pref;
		stage_index <- new_stage_index; 
		target_dest <- set_location(stage_locations[stage_index]);
		
	}
	
	float calc_global_utility(list<list> pt) {
		float global_ut <- 0.0;
		stage_count <- [0, 0, 0, 0];
		loop peeps over: pt {
			int si <- peeps[3];
			stage_count[si] <- stage_count[si] + 1;
		}
		loop peeps over: pt {
			list<float> bs <- peeps[1];
			string pr <- peeps[2];
			int si <- peeps[3];
			if pr = "low" {
				global_ut <- global_ut + low_pop_ut(stage_count[si]);
			} else {
				global_ut <- global_ut + high_pop_ut(stage_count[si]);
			}
			
		}
//		loop stage_box over: stage_prefs {
//			int num_attendees <- length(stage_box);
//			loop peep over: stage_box {
//				if length(stage_box) = 1 {
//					stage_box <- stage_box[0];
//				}
//				string lh <- list(stage_box)[2];
//				if lh = "low" {
//					global_ut <- global_ut + low_pop_ut(num_attendees);
//				} else {
//					global_ut <- global_ut + high_pop_ut(num_attendees);
//				}
//			}
//		}
		return global_ut;
	}

	
	reflex every_tick when: target_dest = nil {
		if target_dest = nil {
			do wander;
		}
	}
	
	reflex move when: target_dest != nil {
		do goto target: target_dest;
		
	}
	
	
	aspect base {
		draw circle(1) color: color border: #black;
	}
}

experiment festival_traffic type: gui {
	parameter "Number of people agents" var: num_people category: "People" ;
	parameter "minimal speed" var: min_speed category: "People" min: 0.1 #km/#h ;
	parameter "maximal speed" var: max_speed category: "People" max: 10 #km/#h;
	
	output {
		display festival_display type: 2d {
			species stage aspect: base;
			species people aspect: base;
		}
	}
}