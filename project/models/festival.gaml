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
	list<people> all_people <- [];
	
	init {		
		create people number: num_people {
			speed <- rnd(min_speed, max_speed);	
		}
		all_people <- people.population;
		
	}
	
	reflex save_training_data when: (cycle mod 5 = 0) {
		list<point> locations <- [];
		
		loop p over: all_people {
			locations <- locations + p.location;
		}
		save(locations) 
			to: "pls.csv" format: "csv"; // lmao the documenation says this is "type" but it is actually "format"
		
	}
}


species people skills: [moving, fipa] {
	rgb color <- #yellow ;
	point target_dest <- nil;

	
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
			species people aspect: base;
		}
	}
}