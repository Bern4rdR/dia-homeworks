model festival_fair

global {
	float step <- 1 #s;
	float min_speed <- 0.5 #m / #s;
	float max_speed <- 3.0 #m / #s;
	float max_ht <- 30.0;
	
	int num_people <- 50;
	
	list<point> stage_locations <- [[20, 20], [40, 40], [60, 60], [80, 80]];
	list<float> light_vals <- [1.0, 0.0, 0.0, 0.4];
	list<float> sound_vals <- [0.0, 1.0, 0.0, 0.4];
	list<float> video_vals <- [0.0, 0.0, 1.0, 0.4];
	list<people> all_people <- [];
	list<bar> all_bars <- [];
	
	
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
		
		create extrovert number: num_people/4 { color <- #yellow; }
		create introvert number: num_people/4 { color <- #red; }
		create police number: num_people/4 { color <- #blue; }
		create salesperson number: num_people/4 { color <- #green; }

		all_people <- people.population;
		
		
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
			contents: ['Jag vill ha en öl, tack!']
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
	
	reflex asked_to_leave when: !empty(informs) {
		message msg <- informs at 0;
		if (string(list(msg.contents) at 0) contains 'You need to leave') and flip(0.8) { // has a 20% chance to defy
			do die;
		}
	}
	
	aspect base {
		draw circle(1) color: color border: #black;
	}
}


species extrovert parent: people {
	float generocity <- rnd(1.0, 2.0); // probability multiplier
	float networking_skills <- rnd(2.0, 5.0);
	int ideal_group_size <- rnd(3, 7);
	
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
			
			match bartender {
				write 'met bartender';
				do buy_beer(bartender(person));
			}
			
			match salesperson {
				write "met salesperson";
				
				if (rnd(0, generocity) < 0.5 or rnd(1.0, 8.0) > networking_skills) { return; }
				
				do start_conversation
					to: [person]
					protocol: 'fipa-propose'
					performative: 'propose'
					contents: ['i will buy from you']
				;
				
				list<people> local_peers <- people at_distance 5;
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
	
	reflex find_group when: length(people at_distance 5) < ideal_group_size {
		if (travelling) { return; }
		
		list<people> nearby_people <- people at_distance 25;
		
		if (!empty(nearby_people)) {
			target_dest <- one_of(nearby_people).location;
			travelling <- true;
		}
	}
	
	reflex recv when: !empty(informs) {
		message msg <- informs at 0;
		if (string(msg.contents) contains 'here is your drink') {
			drunkness <- drunkness + 1;
		}
	}
	
	reflex sales when: !empty(proposes) {
		loop msg over: proposes {
			
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
	// trait #3
	
	reflex init when: !init {
		init <- true;
		bartender bt <- one_of(bartender.population);
		list<people> notsales <- extrovert.population + police.population + introvert.population;
		friends <- friends + bt;
		loop while: length(friends) < 3 {
			people nasta <- one_of(notsales);
			if nasta != self {
				friends <- friends + nasta;
			} 
		}
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
		if !goal_reached and location distance_to goal < 2 {
			utility <- utility + 10;
			if length(friends) > 0 {
				goal <- (friends at 0).location;
				remove from: friends index: 0;
			} else {
				goal_reached <- true;
				goal <- nil;
			}
		}
	}
	
	reflex recover when: agent_closest_to(self) distance_to location > 1 {
		tiredness <- tiredness + 0.1;
	}
	
	reflex encounter when: agent_closest_to(self) distance_to location < 1 {
		agent person <- agent_closest_to(self);
		tiredness <- tiredness + 0.1;
		
		if species_of(person) != introvert {
			do drop_social_capacity;
		}
		
		switch species_of(person) {
			match police {
				write "met police";
				// run away
			}
			match bartender {
				write "met bartender";
				// buy beer
				do buy_beer(bartender(person));
			}
			match salesperson {
				write "met salesperson";
				// do social capacity check
				do run_away(person.location, true);
			}
			match extrovert {
				write "met extrovert";
				// do social capacity check
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
	
	reflex buy_wares when: !empty(proposes) {
		loop offer over: proposes {
			if rnd(1.0, 10.0) > tiredness {
				do accept_proposal
					message: offer
					contents: ['I will buy from you']
				;
			}
		}
				
	}
	
	aspect base {
		draw triangle(2) color: color border: #black;
		draw polyline(hist_path) color: #blue width: 2;
	}
}

species police parent: people {
	float max_drunkness_allowed <- rnd(5.0, 15.0); // maximum drunkness they allow others to be before throwing them out
	int num_drunk_tolerance <- rnd(3, 7); // max number of drunk people before getting mad at bartender
	float selling_suspicion <- 0.0; // value of suspicion towards salesperson
	
	int num_drunk_encountered <- 0; // will keep count of number of too drunk guests encountered
	
	
	reflex seek_group { // will go towards groups of people to inspect them
		if (!travelling) {
			list<extrovert> nearby_extroverts <- extrovert at_distance 15;
			
			if !empty(nearby_extroverts) {
				point center_of_group <- mean(nearby_extroverts collect each.location);
				target_dest <- center_of_group; 
			}
		}
	}
	
	action warn(people p, string m) {
		do start_conversation
			to: [p]
			protocol: 'fipa-propose'
			performative: 'inform'
			contents: [m]
		;
	}
	
	reflex encounter when: agent_closest_to(self) distance_to location < 1 {
		agent person <- agent_closest_to(self);
		
		switch species_of(person) {
			match bartender {
				write "met bartender";
				if (num_drunk_encountered > num_drunk_tolerance) {
					do warn(people(person), 'Too many drunks! Be more strict');
					num_drunk_encountered <- 0;
					write 'Reporting in: The bartender has been asked to be stricter when serving';
				}
			}
			match salesperson {
				write "met salesperson";
				selling_suspicion <- selling_suspicion + 0.3;
				
				if (selling_suspicion > 5.0) {
					do warn(people(person), "That's it, I'm arresting you!");
					ask person { do die; }
					write "Reporting in: I've arrested a salesperson";
				}
			}
			default {
				write "met " + species_of(person);
				
				if [extrovert, introvert] contains species_of(person) and (people(person).drunkness > max_drunkness_allowed) {
					num_drunk_encountered <- num_drunk_encountered + 1;
					
					do warn(people(person), 'You are too drunk! You need to leave');
					write "Reporting in: I've asked a person to leave";
				}
			}
		}
	}
	
} 

species bartender parent: people {
	float serving_tolerance <- rnd(2.0, 4.5);
	float charm_tolerance <- rnd(1.0, 5.0);
	float irritation <- 0.0;
	
	bar my_bar <- nil;
	
	reflex sell_beer when: !empty(requests) {
		loop msg over: requests { 
			agent sender <- agent(msg.sender);
			
			switch species_of(sender) {
				match extrovert {
					write 'met extrovert';
				
					if (extrovert(sender).drunkness < serving_tolerance or extrovert(sender).networking_skills > charm_tolerance) {
						do accept_proposal
							message: msg
							contents: ['Enjoy, tack!']
						;
						write 'served customer';
					} else {
						do start_conversation
							to: [sender]
							protocol: 'fipa-propose'
							performative: 'inform'
							contents: ['I cannot serve you']
						;
					}
				}
				match introvert {
					write "met introvert";
					
					if (introvert(sender).drunkness < serving_tolerance) {
						do accept_proposal
							message: msg
							contents: ['Enjoy, tack!']
						;
					} else {
						do start_conversation
							to: [sender]
							protocol: 'fipa-propose'
							performative: 'inform'
							contents: ['I cannot serve you']
						;
					}
				}
				match salesperson {
					write 'met salesperson';
					irritation <- irritation + 0.1;
					
					if (salesperson(sender).drunkness < serving_tolerance and irritation < 5.0) {
						do accept_proposal
							message: msg
							contents: ['Enjoy, tack!']
						;
					} else {
						do start_conversation
							to: [sender]
							protocol: 'fipa-propose'
							performative: 'inform'
							contents: ['You are disturbing the other customers! I cannot serve you']
						;
					}
				}
			}	
		}
	}
	
	reflex tighten_tolerance when: !empty(informs) { // when asked by police officer
		message msg <- informs at 0;
		if (string(list(msg.contents) at 0) contains "Be more strict") {
			serving_tolerance <- serving_tolerance * 0.8;
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
	bool oportunistic_find <- false;
	float risk_averse <- rnd(0.5, 2.5);
	float territory_awareness <- rnd(1.0, 5.0);
	agent last_interaction;
	
	
	
   reflex find_oportunistic_person when: oportunistic_find and !travelling { // prefer extroverts based on distance


   agent closest_extrovert <- agents where (species(each) = extrovert and each != last_interaction) closest_to self;
   agent closest_other <- agents where (species(each) != extrovert and species(each) != police and each != last_interaction) closest_to self;
   agent final_target;
   
   float dist_extro <- self distance_to closest_extrovert;
    float dist_other <- self distance_to closest_other;
    
    float probability <- (dist_extro < dist_other) ? 0.75 : 0.25;

	if (flip(probability)) {
	    final_target <- closest_extrovert;
	} else {
	    final_target <- closest_other;
	}
	
	target_dest <- final_target.location;
	travelling <- true;	
   }
   
   reflex find_person when: !oportunistic_find and !travelling  { // no preferences
   	agent closest <- agents where (species(each) != police and each != last_interaction) closest_to self;
   	target_dest <- closest.location;
   	travelling <- true;
   	
   }
   
   reflex avoid_police when: !empty(police at_distance (10.0*risk_averse)) {
	   	agent closest <- police closest_to self;
	   	target_dest <- location + (location - closest.location);
	   	travelling <- true;
   }
	
	reflex encounter when: agent_closest_to(self) distance_to location < 1 {
		agent person <- agent_closest_to(self);
		
		switch species_of(person) {
			match introvert {
				
				write "met introvert";
				if (length(introvert at_distance 5) >= 2) {
					do ask_to_buy(person);
				}
			}
			match extrovert {
				write "met extrovert";
				do ask_to_buy(person);
			}
			match bartender {
				write "met bartender";
				do buy_beer(bartender(person));
			}
			
			default {
				write "met " + species_of(person);
			}
		}
	}
	
	reflex maintain_territory when: !empty(salesperson at_distance territory_awareness) {
		list<salesperson> competitors <- salesperson at_distance territory_awareness;
		target_dest <- location + (location - one_of(competitors).location) * risk_averse;
		travelling <- true;
	}
	
	action ask_to_buy(agent target) {
		do start_conversation
			to: [target]
			protocol: 'fipa-propose'
			performative: 'propose'
			contents: ['Do you want to buy my wares?']
		;
	}
	
	reflex sell when: !empty(accept_proposals) or !empty(proposes) {
		loop yes over: accept_proposals {
			list<string> tmp_msg <- yes.contents; // clear message from queue
		}
		loop yes over: proposes {
			list<string> tmp_msg <- yes.contents; // clear message from queue
		}
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
			species police aspect: base;
			species bar aspect: base;
			species bartender aspect: base;
			species salesperson aspect: base;
		}
	}
}