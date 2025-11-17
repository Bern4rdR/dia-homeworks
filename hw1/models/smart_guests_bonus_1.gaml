model festival_fair

global {
	float step <- 1 #s;
	float min_speed <- 0.5 #m / #s;
	float max_speed <- 3.0 #m / #s;
	float max_degrade <- 1.4;
	float ht_threshold <- 2.0;
	float max_ht <- 30.0;
	list<people> all_people <- [];
	list<smart_person> smarties <- [];
	float avg_dist_people <- 0.0 update: update_avg_people();
	float avg_dist_smarties <- 0.0 update: update_smarties();
	int num_people <- 12; // computer fan go brrrr, actually, I think past 250 the sim changes how it renders
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
		
		create people number: num_people returns: listAllPeople {
			speed <- rnd(min_speed, max_speed);
			information_center <- one_of(information_centers);		
		}
		self.all_people <- listAllPeople;
		
		create smart_person number: num_people returns: listSPeople {
			speed <- rnd(min_speed, max_speed);
			information_center <- one_of(information_centers);
		}
		self.smarties <- listSPeople;
	}
	
	float update_avg_people {
		float total_distance <- 0.0;
        loop person over: self.all_people {
        	total_distance <- total_distance + person.distance_travelled;
        }
        return total_distance/length(self.all_people);
	}
	
	float update_smarties {
		float total_distance <- 0.0;
        loop person over: self.smarties {
        	total_distance <- total_distance + person.distance_travelled;
        }
        return total_distance/length(self.smarties);
	}
	
    reflex report when: cycle mod 100 = 0 {
        float total_distance <- 0.0;
        loop person over: self.all_people {
        	total_distance <- total_distance + person.distance_travelled;
        }
        float average_distance <- total_distance/length(self.all_people);
        write "People Average Distance Travelled: " + average_distance;
        total_distance <- 0.0;
        loop person over: self.smarties {
        	total_distance <- total_distance + person.distance_travelled;
        }
        average_distance <- total_distance/length(self.smarties);
        write "Smarties Average Distance Travelled: " + average_distance;
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
	float hungry <- 10.0;
	float thirsty <- 10.0;
	point target_dest <- nil;
	float distance_travelled <- 0.0;
	point last_location <- nil;
	
	bool isHungry {
		return hungry < ht_threshold;
	}
	
	bool isThirsty {
		return thirsty < ht_threshold;
	}
	
	action eat {
		ask building {
			if self.type = "Food" {
				myself.hungry <- max_ht;
				myself.target_dest <- nil;
				myself.last_location <- nil;
			}
			else if self.type = "Drinks" {
				myself.thirsty <- max_ht;
				myself.target_dest <- nil;
				myself.last_location <- nil;
				
			}
		}
	}
	
	reflex every_tick when: target_dest = nil {
		if target_dest = nil {
			do wander;
		}
		hungry <- hungry - rnd(max_degrade);
		thirsty <- thirsty - rnd(max_degrade);
		
		// refresh color
		if target_dest = nil {
			color <- #yellow;
		}
	}
	
	reflex find_building when: (isHungry() or isThirsty()) and target_dest = nil {
		target_dest <- any_location_in(information_center);
		color <- #orange;
	}
	
	reflex move when: target_dest != nil {
		do goto target: target_dest;
		
		// Update total distance moved
		if self.last_location != nil {
        	self.distance_travelled <- self.distance_travelled + (self.last_location distance_to self.location); // the paranthesis are just for me -- viv
        	self.last_location <- self.location;
        } else {
        	self.last_location <- self.location;
        }
		
		if location distance_to any_location_in(information_center) < 1.0 {
			color <- isHungry() ? #brown : #green;
			ask information_center {
//				write "Hungry/Thirsty: " + myself.isHungry() + " " + myself.isThirsty();
				myself.target_dest <- any_location_in(one_of(self.stands where (each.type=(myself.isHungry() ? "Food" : "Drinks"))));
//				write "Target destination: " + myself.target_dest;
			}
		}
		else if location distance_to target_dest < 1.0 {
			do eat;
		}
	}
	
	
	aspect base {
		draw circle(1) color: color border: #black;
	}
}

species smart_person parent: people {
	point food_stand <- nil;
	point drink_stand <- nil;
	
	aspect base {
		draw triangle(1) color: color border: #black;
	}
	
	action eat {
		ask building {
			if self.type = "Food" {
				myself.hungry <- max_ht;
				myself.target_dest <- nil;
				myself.last_location <- nil;
				myself.food_stand <- self.location;
			}
			else if self.type = "Drinks" {
				myself.thirsty <- max_ht;
				myself.target_dest <- nil;
				myself.last_location <- nil;
				myself.drink_stand <- self.location;
			}
		}
	}
	
	reflex find_building when: (isHungry() or isThirsty()) and target_dest = nil {
		if isHungry() {
			if food_stand != nil {
				if rnd(1, 4) != 2 {
					target_dest <- food_stand;
				}
			}
		} else if isThirsty() {
			if drink_stand != nil {
				if rnd(1, 4) != 2 {
					target_dest <- drink_stand;	
				}
			}
		}
		if target_dest = nil {
			target_dest <- any_location_in(information_center);	
		}
		
		color <- #orange;
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
			species smart_person aspect: base;
		}
		display chart_display type: 2d {
            chart "Average Distance Over Time" type: series {
                data "Average Distance People" value: avg_dist_people color: #blue;
                data "Average Distance Smarties" value: avg_dist_smarties color: #red;
            }
        }
	}
}