model festival_fair

/*
 * [x] New agent type: auctioneer
 *    [ ] pop up at least once per simulation
 *    [x] communicate only with FIPA
 * [ ] Dutch auction: sell items to auction winners
 *      - start price higher than market value
 *      - reduce price until offer
 *      - first bid is winner
 *      - price goes below set limit: cancel auction
 */


global {
	float step <- 1 #s;
	float min_speed <- 0.5 #m / #s;
	float max_speed <- 3.0 #m / #s;
	float max_degrade <- 1.4;
	float ht_threshold <- 2.0;
	float max_ht <- 30.0;
	
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
			information_center <- one_of(information_centers);		
		}
		
		create auctioneer {
			list<people> visitors <- people where (each.color = #yellow);
			participants <- visitors;
			asking_price <- 10.0;
			min_price <- 8.5;
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
	float hungry <- 10.0;
	float thirsty <- 10.0;
	point target_dest <- nil;
	int current_auction_id <- nil;
	int id <- rnd(1, 10000000);
	
	float acceptable_price <- rnd(5, 7.5);
	
	bool isHungry {
		return hungry < ht_threshold;
	}
	
	bool isThirsty {
		return thirsty < ht_threshold;
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
		
		if location distance_to any_location_in(information_center) < 1.0 {
			color <- isHungry() ? #brown : #green;
			ask information_center {
				myself.target_dest <- any_location_in(one_of(self.stands where (each.type=(myself.isHungry() ? "Food" : "Drinks"))));
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
	
	reflex place_bid when: !(empty(proposes)) {
		message current_bid <- proposes at 0;
		float price <- list(current_bid.contents) at 0;
		// write current_bid.contents;
		
		if (price <= acceptable_price) {
			// write 'I\'ll buy';
			do accept_proposal
				message: current_bid
				contents: ['I\'ll buy', price, id]
			;
		} else {
			// write 'Price too high';
			do reject_proposal
				message: current_bid
				contents: ['Price too high']
			;
		}
	}
	
	reflex handle_cfp when: !(empty(cfps)) {
		message next_cfp <- cfps at 0;
		string type <- list(next_cfp.contents) at 0;
		if (type = "dutch") {
			write 'I\'ll enter the auction';
			current_auction_id <- list(next_cfp.contents) at 1;
			do cfp
				message: next_cfp
				contents: ['enter', current_auction_id]
			;
		}
	}
	
	reflex handle_auction_end when: !(empty(informs)) {
		message inform <- informs at 0;
		list content <- list(inform.contents);
		if content at 0 = 'auction over' and content at 1 = id {
			write "Yay I won!!!! " + id;
		} else if content at 0 = 'auction over' {
			write "Oh no I lost :(";
		}
	}
	
	
	aspect base {
		draw circle(1) color: color border: #black;
	}
}



species auctioneer skills: [fipa] {
	list<people> participants;
	float asking_price;
	float min_price;
	float decr_factor <- 0.9; // decrement price by percent
	int auction_id <- rnd(10000000);
	bool has_proposed_auction <- false;
	bool auction_started <- false;
	bool auction_over <- false;
	int num_participants <- 0;
	int winner <- 0;

	reflex send_cfp when: (time=1) {
		loop p over: participants {
			do start_conversation
			to: [p]
			protocol: 'fipa-propose'
			performative: 'cfp'
			contents: ["dutch", self.auction_id];
		}
		has_proposed_auction <- true;
	}
	
	reflex read_cfp_response when: (!empty(cfps) and has_proposed_auction and not auction_started) {
		loop ap over: cfps {
			list cts <- list(ap.contents);
			// write cts at 0;
			
			if cts at 0 = 'enter' {
				num_participants <- num_participants + 1;
			}
		}
		// write "CFPS: " + length(cfps);
		auction_started <- true;
	}
	// should only trigger when there are no messages to process
	reflex send_message when: (empty(cfps) and auction_started and (time mod 2 = 0)) {
		write 'asking price: ' + asking_price;
		loop p over: participants {
			do start_conversation 
				to: [p]
				protocol: 'fipa-propose'
				performative: 'propose'
				contents: [asking_price]
			;
		}
	}
	
	reflex read_message when: !(empty(accept_proposals) and empty(reject_proposals)) {
		loop msg over: accept_proposals {
			if not auction_over {
				winner <- int(list(msg.contents) at 2);
				auction_over <- true;			
			}
			write msg.contents;
			// do smthn with msg.contents
		}
		
		if length(reject_proposals) = length(participants) {
			// next iteration of auction
			loop rej over: reject_proposals {
				write rej.contents;
			}
			write 'moving to next round';
			asking_price <- asking_price * decr_factor;
			if asking_price < min_price {
				auction_over <- true;
				write 'minimum price reached: ending auction';
			}
			
		}
	}
	
	reflex inform_result when: auction_over {
		if winner != 0 {
			write "Winner found: " + winner;
		}
		do start_conversation
			to: participants
			protocol: 'fipa-propose'
			performative: 'inform'
			contents: ['auction over', winner]
		;
		winner <- nil;
		has_proposed_auction <- false;
		auction_started <- false;
		auction_over <- false;
	}
	
	aspect base {
		draw circle(2) color: #blue border: #black;
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