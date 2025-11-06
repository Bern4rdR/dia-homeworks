model festival_fair

global {
	float step <- 1 #s;
	float min_speed <- 0.5 #m / #s;
	float max_speed <- 3.0 #m / #s;
	
	int num_people <- 10;
	// graph festival_grounds;
	
	init {
		create building number: 4 {
			type <- one_of(["Food", "Drinks"]);
			color <- type = "Food" ? #red : #gray;
		}
		list<building> stands_b <- building where (each.type != "Information");
		
		
		create building {
			type <- "Information";
			color <- #blue;
			stands <- stands_b;
		}
		list<building> information_centers <- building where (each.type="Information");
		
		create people number: num_people {
			speed <- rnd(min_speed, max_speed);
			hungry <- false;
			thirsty <- false;
			information_center <- one_of(information_centers);		
		}
	}
}

species building skills: [fipa] {
	string type; 
	rgb color;
	list<building> stands;
	
	aspect base {
		draw circle(3) color: color ;
	}
}

species people skills: [moving, fipa] {
	rgb color <- #yellow ;
	building information_center;
	bool hungry;
	bool thirsty;
	point target_dest <- nil;
	
	reflex every_tick when: target_dest = nil {
		if target_dest = nil {
			do wander amplitude: 1.0;
		}
		if !hungry {
			hungry <- flip(0.1);
		}
		if !thirsty {
			thirsty <- flip(0.1);
		}
		
		// refresh color
		if target_dest != nil {
			color <- #yellow;
		}
	}
	
	reflex find_building when: (hungry or thirsty) and target_dest = nil {
		target_dest <- any_location_in(information_center);
		color <- #orange;
	}
	
	reflex move when: target_dest != nil {
		do goto target: target_dest;
		
		if location = any_location_in(information_center) {
			color <- #green;
			ask information_center {
				myself.target_dest <- any_location_in(one_of(self.stands where (each.type=(myself.hungry ? "Food" : "Drinks"))));
			}
		}
		else if location distance_to target_dest < 1.0 {
			ask building {
				if self.type = "Food" {
					myself.hungry <- false;
					myself.target_dest <- nil;
				}
				else if self.type = "Drinks" {
					myself.thirsty <- false;
					myself.target_dest <- nil;
				}
			}
		}
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
			species building aspect: base;
			species people aspect: base;
		}
	}
}