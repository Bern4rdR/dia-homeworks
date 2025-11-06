/**
* Name: TestModel
* Based on the internal skeleton template. 
* Author: VivienneCurewitz
* Tags: 
*/

model Festival

global {
	/** Insert the global definitions, variables and actions here */
	int guests <- 10;
	int shops <- 4;
	int infobooths <- 2;
	
	float max_hunger_step <- 0.3;
	float max_thirst_step <- 0.5;
	
	float max_ht_up <- 30.0;
	
	float ask_range <- 1.0;
	float eat_range <- 1.0;
	
	float threshold_thirst <- 2.0;
	float threshold_hunger <- 2.0;
	
	point info_center_coords <- {25, 40};
	
	list<point> shop_coords <- [{80, 20}, {80, 40}, {80, 60}, {80, 80}];
	
	init {
		create infoBooth number: infobooths;
		loop i from: 0 to: 3 {
			create shop number: 1 with: (location: shop_coords[i]);
		}
		create guest number: guests;
	}
}

species guest skills: [moving] {
	float hunger <- 10.0;
	float thirst <- 10.0;
	rgb color <- #blue;
	float size <- 1.0;
	infoBooth my_info; 
	point move_location <- {-1, -1};
	bool has_destination <- false;
	bool to_shop <- false;
	
	
	init { 
	}
	
	bool hungry {
		return hunger < threshold_hunger or thirst < threshold_thirst;
	}
	
	bool near_info {
		return (location.x - info_center_coords.x < 2) and (location.y - info_center_coords.y < 2);
	}
	
	bool near_shop {
		return to_shop and (location.x - move_location.x < 2) and (location.y - move_location.y < 2);
	}
	

	reflex update {
		hunger <- hunger - rnd(max_hunger_step);
		thirst <- thirst - rnd(max_thirst_step);
		if hungry() and not has_destination {
			move_location <- info_center_coords;
			has_destination <- true;
			color <- #red;
		}
		if not has_destination {
			do wander;
		}
	}
	
	
	reflex move when: has_destination {
		do goto target: move_location;
	}
	
	reflex ask when: hungry() and near_info() and not to_shop  {
		list<infoBooth> info <- infoBooth at_distance(4.0);
		if length(info) > 0 {
			ask info[0] {
				myself.move_location <- where_shop();
				myself.has_destination <- true;
				myself.to_shop <- true;
			}
		}
	}
	
	reflex eat when: hungry() and near_shop() {
		list <shop> nshop <- shop at_distance(4.0);
		if length(nshop) > 0 {
			ask nshop[0] {
				point fd <- feed();
				myself.hunger <- myself.hunger + fd.x;
				myself.thirst <- myself.thirst + fd.y;
			}
		}
		if not hungry() {
			to_shop <- false;
			has_destination <- false;
			color <- #blue;
		}
	}
	
//	reflex eat when: my_cell.food > 0 { 
//		float energy_transfer <- min([max_transfer, my_cell.food]);
//		my_cell.food <- my_cell.food - energy_transfer;
//		energy <- energy + energy_transfer;
//	}
//	reflex die when: energy <= 0 {
//		do die;
//	}
	
	aspect base {
		draw circle(size) color: color;
	}
}

species shop {
	bool hasFood <- true;
	bool hasDrink <- true;
	rgb color <- #pink;
	float x_size <- 4.0;
	float y_size <- 2.0;
	
	init {

	}
	
	point feed {
		float food <- rnd(max_ht_up);
		float drink <- rnd(max_ht_up);
		return {food, drink};
	}
	
	aspect base {
		draw circle(x_size) color: color;
	}
	
}

species infoBooth {
	rgb color <- #green;
	float x_size <- 3.0;
	int next_shop <- 0;
	
	init {
		location <- info_center_coords;
	}
	
	point where_shop {
		point sp <- shop_coords[next_shop];
		next_shop <- mod(next_shop + 1, 4);
		return sp;
	}
	
	aspect base {
		draw circle(x_size) color: color;
	}
}


experiment Festival type: gui {
	parameter "Initial number of guests: " var: guests min: 1 max: 1000 category: "Guest";
	output {
		display main_display {
			species guest aspect: base;
			species shop aspect: base;
			species infoBooth aspect: base;
		}
	}
}

