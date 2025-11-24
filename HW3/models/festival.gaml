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
				contents: [lights, sound, video, location]
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
	
	reflex choose_stage when: !empty(informs) {
		write "got inform message";
		loop msg over: informs {
			list cnt <- list(msg.contents);
			float lt <- cnt at 0;
			float so <- cnt at 1;
			float vd <- cnt at 2;
			point stage_loc <- cnt at 3;
			float new_utility <- lights * lt + sound * so + video * vd;
			if new_utility >= current_utility {
				current_utility <- new_utility;
				target_dest <- [stage_loc.x + rnd(-5, -1), stage_loc.y + rnd(-3, 3)];
			}
		}
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