model festival_fair

/*
 * [x] New agent type: auctioneer
 *    [x] pop up at least once per simulation
 *    [x] communicate only with FIPA
 * [x] Dutch auction: sell items to auction winners
 *      - start price higher than market value
 *      - reduce price until offer
 *      - first bid is winner
 *      - price goes below set limit: cancel auction
 * [X] English auction: sell items to auction winners
 *      - start at minimmum accepted price
 *      - get bids until no one bids higher
 *      - highest bid is winner
 * [ ] Sealed auction: one bid each
 *      - each participant places exactly one bid
 *      - highest bid wins
 */


global {
	float step <- 1 #s;
	float min_speed <- 0.5 #m / #s;
	float max_speed <- 3.0 #m / #s;
	float max_degrade <- 1.4;
	float ht_threshold <- 2.0;
	float max_ht <- 30.0;
	
	int num_people <- 100;
	bool dutch_auction <- false;
	bool english_auction <- false;
	bool sealed_auction <- false;
	
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
		
		if (dutch_auction){
			create dutch_people number: num_people {
				speed <- rnd(min_speed, max_speed);
				information_center <- one_of(information_centers);		
			}
		
			create dutch_auctioneer {
				list<dutch_people> visitors <- dutch_people where (each.color = #yellow);
				participants <- visitors;
				asking_price <- 10.0;
				min_price <- 3.0;
			}
		}
		
		if (english_auction){
			create english_people number: num_people {
				speed <- rnd(min_speed, max_speed);
				information_center <- one_of(information_centers);		
			}
			
			create english_people number: 1 {
				speed <- rnd(min_speed, max_speed);
				information_center <- one_of(information_centers);		
				max_price <- 120;
			}
			
			create english_auctioneer {
				list<english_people> visitors <- english_people where (each.color = #yellow);
				participants <- visitors;
			}
		}
		
		if sealed_auction {
			create dutch_people number: num_people {
				speed <- rnd(min_speed, max_speed);
				information_center <- one_of(information_centers);
			}
			
			create sealed_auctioneer {
				list<dutch_people> visitors <- dutch_people where (each.color = #yellow);
				participants <- visitors;
				min_price <- 70.0;
			}
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

species dutch_people skills: [moving, fipa] {
	rgb color <- #yellow ;
	building information_center;
	float hungry <- 10.0;
	float thirsty <- 10.0;
	point target_dest <- nil;
	int current_auction_id <- nil;
	int id <- rnd(1, 10000000);
	string auction_type <- "";
	
	float biased_rand(float min_value <-0, float max_value) {
    	float r <- rnd(1.0);
    	float y <- (r ^ 2.5) * (max_value-min_value);
    	return int(y)+min_value;
		}
	
	float acceptable_price <- rnd(50, 100.0);
	
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
		write current_bid.contents;
		if (auction_type = 'sealed') {
			acceptable_price <- biased_rand(price, acceptable_price);
		}
		if (price <= acceptable_price) {
			write 'I\'ll buy';
			do accept_proposal
				message: current_bid
				contents: ['I\'ll buy', acceptable_price, id]
			;
		} else {
			write 'Price too high';
			do reject_proposal
				message: current_bid
				contents: ['Price too high']
			;
		}
	}
	
	reflex handle_cfp when: !(empty(cfps)) {
		message next_cfp <- cfps at 0;
		string type <- list(next_cfp.contents) at 0;
		if (["dutch", 'sealed'] contains type) {
			auction_type <- type;
			write 'I\'ll enter the auction';
			current_auction_id <- int(list(next_cfp.contents) at 1);
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

species english_people skills: [moving, fipa] {
	rgb color <- #yellow ;
	building information_center;
	float hungry <- 10.0;
	float thirsty <- 10.0;
	point target_dest <- nil;
	int current_auction_id <- nil;
	int id <- rnd(1, 10000000);
	int biased_rand(int min_value <-0, int max_value) {
    	float r <- rnd(1.0);
    	float y <- (r ^ 2.5) * (max_value-min_value);
    	return int(y)+min_value;
		}
	
	int max_price <- biased_rand(50, 100);
	
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
		int price <- list(current_bid.contents) at 0;
		int next_offer <- price +  biased_rand(1, 10);
		if (next_offer > max_price and price < max_price){
			next_offer <- max_price;
		}
		if (price <= max_price and next_offer <= max_price) {
			write string(id)+': I\'ll buy at '+ next_offer;
			do accept_proposal
				message: current_bid
				contents: ['I\'ll buy', next_offer, id]
			;
		} else {
			write string(id)+': Price too high' + next_offer +">"+ max_price;
			do reject_proposal
				message: current_bid
				contents: ['Price too high']
			;
		}
	}
	
	reflex handle_cfp when: !(empty(cfps)) {
		message next_cfp <- cfps at 0;
		string type <- list(next_cfp.contents) at 0;
		if (type = "english") {
			write string(id)+':I\'ll enter the auction';
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
			write string(id)+":Yay I won!!!! ";
		} else if content at 0 = 'auction over' {
			write string(id)+":Oh no I lost :(";
		}
	}
	
	
	aspect base {
		draw circle(1) color: color border: #black;
	}
}



species dutch_auctioneer skills: [fipa] {
	list<dutch_people> participants;
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
			write cts at 0;
			
			if cts at 0 = 'enter' {
				num_participants <- num_participants + 1;
			}
		}
		write "CFPS: " + length(cfps);
		auction_started <- true;
	}
	// should only trigger when there are no messages to process
	reflex send_message when: (empty(cfps) and auction_started and (time mod 2 = 0)) {
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
				winner <- list(msg.contents) at 2;
				auction_over <- true;			
			}
			write msg.contents;
			// do smthn with msg.contents
		}
		
		if length(reject_proposals) = length(participants) {
			// next iteration of auction
			write 'moving to next round';
			loop rej over: reject_proposals {
				write rej.contents;
			}
			write 'Proposals remaining: ' + length(reject_proposals);
			asking_price <- asking_price * decr_factor;
			if asking_price < min_price {
				auction_over <- true;
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

species english_auctioneer skills: [fipa] {
	list<english_people> participants;
	int start_price <- rnd(10,20);
	int current_price <- start_price;
	int current_winner;
	int current_time <- 0;
	int auction_id <- rnd(10000000);
	bool has_proposed_auction <- false;
	bool auction_started <- false;
	bool auction_over <- false;
	int num_participants <- 0;

	reflex send_cfp when: (time=1) {
		
		loop p over: participants {
			do start_conversation
			to: [p]
			protocol: 'fipa-propose'
			performative: 'cfp'
			contents: ["english", self.auction_id];
		}
		has_proposed_auction <- true;
	}
	
	reflex read_cfp_response when: (!empty(cfps) and has_proposed_auction and not auction_started) {
		loop ap over: cfps {
			list cts <- list(ap.contents);
			write cts at 0;
			
			if cts at 0 = 'enter' {
				num_participants <- num_participants + 1;
			}
		}
		write "CFPS: " + length(cfps);
		auction_started <- true;
	}
	// should only trigger when there are no messages to process
	reflex send_message when: (empty(cfps) and auction_started and (time mod 2 = 0)) {
		write "Starting auction at "+ start_price;
		loop p over: participants {
			do start_conversation 
				to: [p]
				protocol: 'fipa-propose'
				performative: 'propose'
				contents: [start_price]
			;
		}
		auction_started <- false;
	}
	
	reflex accept_bids when: !(empty(accept_proposals)) {
		list<message> msgs <- accept_proposals;
		if (length(msgs) > 1) {
		loop msg over: msgs {
			int new_offer <- list(msg.contents) at 1; 
			if (new_offer > current_price){
				current_price <- new_offer;
				current_winner <- list(msg.contents) at 2;
				current_time <- cycle;
			}
			

//			write msg.contents;
		}
		write "New price: "+ current_price;
		loop msg over: msgs {
			do propose message: msg contents: [current_price];
			}
		}
		
	}
	
	reflex inform_result when: cycle - current_time > 5 and current_winner != 0{
		list<message> msgs <- accept_proposals;
		loop msg over: msgs {
			int new_offer <- list(msg.contents) at 1;
			int offerer <- list(msg.contents) at 2; 
			if (new_offer > current_price and offerer != current_winner){
				current_price <- new_offer;
				current_winner <- list(msg.contents) at 2;
				current_time <- cycle;
			}
			

//			write msg.contents;
		}
		
		write "Winner found: " + current_winner + " at price "+ current_price;
		do start_conversation
			to: participants
			protocol: 'fipa-propose'
			performative: 'inform'
			contents: ['auction over', current_winner]
		;
		do die;
	}
	
	aspect base {
		draw circle(2) color: #blue border: #black;
	}
}

species sealed_auctioneer skills: [fipa] {
	list<dutch_people> participants;
	float min_price;
	int auction_id <- rnd(10000000);
	bool has_proposed_auction <- false;
	bool auction_started <- false;
	bool auction_over <- false;
	int num_participants <- 0;
	int winner <- 0;
	float winning_bid <- 0.0;

	reflex send_cfp when: (time=1) {
		write 'proposing auction';
		loop p over: participants {
			do start_conversation
			to: [p]
			protocol: 'fipa-propose'
			performative: 'cfp'
			contents: ["sealed", auction_id];
		}
		has_proposed_auction <- true;
	}
	
	reflex read_cfp_response when: (!empty(cfps) and has_proposed_auction and not auction_started) {
		write 'got responses';
		loop ap over: cfps {
			list cts <- list(ap.contents);
			write cts at 0;
			
			if cts at 0 = 'enter' {
				num_participants <- num_participants + 1;
			}
		}
		write "CFPS: " + length(cfps);
		auction_started <- true;
	}
	// should only trigger when there are no messages to process
	reflex send_message when: (empty(cfps) and auction_started and (time mod 2 = 0)) {
		write 'starting auction';
		loop p over: participants {
			do start_conversation 
				to: [p]
				protocol: 'fipa-propose'
				performative: 'propose'
				contents: [min_price]
			;
		}
	}
	
	reflex read_message when: !(empty(accept_proposals)) {
		write 'got bids';
		float highest_bid <- 0.0;
		loop msg over: accept_proposals {
			float bid <- float(list(msg.contents) at 1);
			if bid > highest_bid {
				highest_bid <- bid;
				winner <- highest_bid >= min_price ? int(list(msg.contents) at 2) : 0;
			}
		}
		auction_over <- true;
		winning_bid <- highest_bid;
	}
	
	reflex inform_result when: auction_over {
		if winner != 0 {
			write "Winner found: " + winner + "at price: " + winning_bid;
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

experiment festival_dutch_auction type: gui {
	float minimum_cycle_duration <- 1.0;
	parameter "Dutch Auction" var: dutch_auction init: true read_only: true;
	parameter "Number of people agents" var: num_people category: "People" ;
	parameter "minimal speed" var: min_speed category: "People" min: 0.1 #km/#h ;
	parameter "maximal speed" var: max_speed category: "People" max: 10 #km/#h;
	
	output {
		display festival_display type: 2d {
			species building aspect: base;
			species dutch_people aspect: base;
		}
	}
}

experiment festival_english_auction type: gui {
	float minimum_cycle_duration <- 1.0;
	parameter "English Auction" var: english_auction init: true read_only: true;
	parameter "Number of people agents" var: num_people category: "People" ;
	parameter "minimal speed" var: min_speed category: "People" min: 0.1 #km/#h ;
	parameter "maximal speed" var: max_speed category: "People" max: 10 #km/#h;
	
	output {
		display festival_display type: 2d {
			species building aspect: base;
			species english_people aspect: base;
		}
	}
}


experiment festival_sealed_auction type: gui {
	float minimum_cycle_duration <- 1.0;
	parameter "Sealed auction" var: sealed_auction init: true read_only: true;
	parameter "Number of people agents" var: num_people category: "People" ;
	parameter "minimal speed" var: min_speed category: "People" min: 0.1 #km/#h ;
	parameter "maximal speed" var: max_speed category: "People" max: 10 #km/#h;
	
	output {
		display festival_display type: 2d {
			species building aspect: base;
			species dutch_people aspect: base;
		}
	}
}

