model festival_fair

global {
	float step <- 1 #s;
	float min_speed <- 0.5 #m / #s;
	float max_speed <- 3.0 #m / #s;
	float max_ht <- 30.0;
	
	int num_people <- 10;
	// graph festival_grounds;
	
	init {		
		create people number: num_people {
			speed <- rnd(min_speed, max_speed);	
		}
	}
}

species stage skills: [fipa] {
	rgb color;
	float lights;
	float sound;
	float video;
	
	aspect base {
		draw square(3) color: color ;
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
			species stage aspect: base;
			species people aspect: base;
		}
	}
}