model festival_fair

global {
	float step <- 1 #s;
	float min_speed <- 0.5 #m / #s;
	float max_speed <- 3.0 #m / #s;
	float max_degrade <- 1.4;
	float ht_threshold <- 2.0;
	float max_ht <- 100.0;
	int num_security <- 3;
	
	int num_people <- 10;
	int num_evil <- 1;
	int num_stands <- 4;
	
	init {
		create building number: num_stands {
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
			information_center <- one_of(information_centers);
//			type <- rnd(100) < evil_prob ? "Evil" : "Visitor";
		}
		
		create evil_people number: num_evil;
		create security_people number: num_security;
//		create people number: num_security {
//			speed <- rnd(min_speed, max_speed);
////			type <- "Security";
//			color <- #blue;
//		}
	}
}

species building{
	string type; 
	rgb color;
	list<building> stands;
	
	aspect base {
		draw circle(3) color: color ;
	}
	
	// TODO: notify security when receiving info
}

species people skills: [moving] {
	rgb color <- #yellow;
	building information_center;
	float hungry <- 10.0;
	float thirsty <- 10.0;
	point target_dest <- nil;
	bool notify_evil <- false;
	point evil_location <- nil;
	
	
	bool isHungry {
		return hungry < ht_threshold;
	}
	
	bool isThirsty {
		return thirsty < ht_threshold;
	}
	
	reflex every_tick when: target_dest = nil {
		do wander;
		hungry <- hungry - rnd(max_degrade);
		thirsty <- thirsty - rnd(max_degrade);
			// should agents die if they reach 0?	
	}
	
	reflex find_evil when: (!notify_evil and any(evil_people at_distance(5))) {
    write "Evil nearby!";
    notify_evil <- true;
    evil_location <- self.location;
    color <- #orange;
}
		
	
	
	reflex find_building when: (isHungry() or isThirsty()) and target_dest = nil {
		target_dest <- any_location_in(information_center);
//		color <- type = "Evil" ? #red : #orange;
	}
	
	reflex move when: target_dest != nil {
		do goto target: target_dest;
		
	
		if location distance_to any_location_in(information_center) < 1.0 {
			if notify_evil {
				// TODO
				// self.notify_security()
				notify_evil <- false;
				color <- #yellow;
				security_people security <- one_of(security_people);
				ask security{
					self.target_dest <- myself.evil_location;
				}
			} else {
//				color <- type = "Evil" ? #red : #green;
				ask information_center {
					myself.target_dest <- any_location_in(one_of(self.stands where (each.type=(myself.isHungry() ? "Food" : "Drinks"))));
				}	
			}
		}
		else if location distance_to target_dest < 1.0 {
			ask building {
				if self.type = "Food" {
					myself.hungry <- max_ht;
					myself.target_dest <- nil;
				}
				else if self.type = "Drinks" {
					myself.thirsty <- max_ht;
					myself.target_dest <- nil;
				}
			}
		}
	}
	
	
	aspect base {
		draw circle(1) color: color border: #black;
	}
}


species evil_people parent: people {
	
	bool is_evil <- true;
	
	rgb color <- #red;
	
// This empty function cancels the reflex for subclass.
	reflex find_evil when: false {}
	}
	
species security_people parent: people{
	rgb color <- #blue;
	point evil_pos <- nil;
	
	reflex move  {
		if (self.location = target_dest) {target_dest <- nil;}
		if (target_dest=nil) {do wander;}
		else {do goto target: target_dest;}
		
		}
	
	reflex find_evil when: false {}
	reflex kill_evil when: not empty(evil_people at_distance 5) {
    evil_people target <- one_of(evil_people at_distance 5);
    ask target {
        do die;
    }
}

	
	
}


experiment festival_traffic type: gui {
	parameter "Visitor agents" var: num_people category: "People" min: 10 max: 20;
	parameter "Evil agents" var: num_evil category: "People" min: 1 max: 3;
	parameter "Security agents" var: num_security category: "People" min: 1 max: 3;
	parameter "minimal speed" var: min_speed category: "People" min: 0.1 #km/#h ;
	parameter "maximal speed" var: max_speed category: "People" max: 10 #km/#h;
	
	parameter "Number of food/drink stands" var: num_stands category: "Building" min: 4 max: 10;
	
	output {
		display festival_display type: 2d {
			species building aspect: base;
			species people aspect: base;
			species evil_people aspect: base;
			species security_people aspect: base;
		}
	}
}