model queens

global {
	int n_size <- 8;
	
	init {
		create queen number: n_size;
		
		list<queen> queens <- queen where (true);
		
		create initiator {
			first <- queens at 0;
		}
		
		(queens at 0).successor <- queens at 1;
		(queens at 0).row <- 0;
		(queens at 0).location <- {0, 6};
		loop i from: 1 to: n_size-2 {
			(queens at i).predecessor <- queens at (i-1);
			(queens at i).successor <- queens at (i+1);
			(queens at i).row <- i;
			(queens at i).location <- {0, i*12.5 + 6};
		}
		(queens at (n_size-1)).predecessor <- queens at (n_size-2);
		(queens at (n_size-1)).row <- n_size-1;
		(queens at (n_size-1)).location <- {0, 7*12.5+6};
		
		bool started <- (initiator at 0).start();
	}
}

species initiator skills: [fipa] {
	queen first;
	
	bool start {
		write "starting...";
		do start_conversation
			to: [first]
			protocol: 'fipa-propose'
			performative: 'inform'
			contents: ['start']
		;
		return true;
	}
}

grid cell width: n_size height: n_size neighbors: 4 skills: [fipa] {
	bool has_queen <- false;
	rgb color <- grid_x mod 2 = grid_y mod 2 ? #white : #brown;
	
	bool is_safe {
		write " checking " + grid_x;
		if grid_y = 0 {
			write "  safe";
			return true;
		}
		// straight up  ( | )
		loop row from: 0 to: max(0, grid_y-1) {
			if cell[grid_x, row].has_queen {
				write "  up " + grid_x + " " + row;
				return false;
			}
		}
		
		// diagonal up-left  ( \ )
		int col <- grid_x-1;
		loop row from: grid_y-1 to: 0 {
			if col < 0 { break; }
			if cell[col, row].has_queen {
				write "  diag left " + col + " " + row;
				return false;
			}
			col <- col - 1;
		}
		
		// diagonal up-right  ( / )
		col <- grid_x+1;
		loop row from: grid_y-1 to: 0 {
			if col >= n_size { break; }
			if cell[col, row].has_queen {
				write "  diag right " + col + " " + row;
				return false;
			}
			col <- col + 1;
		} 
		
		write "  safe";
		return true;
	}
	
	reflex queen_placed when: !empty(informs) {
		message info <- informs at 0;
		if list(info.contents) contains 'place' {
			// write "queen is placed at " + grid_x + " " + grid_y;
			has_queen <- true;
		} else if list(info.contents) contains 'remove' {
			// write "queen removed from " + grid_x + " " + grid_y;
			has_queen <- false;
		}
	}
}


species queen skills: [fipa] {
	queen predecessor;
	queen successor;
	int row;
	
	list<cell> available_sq;
	cell current_sq;
	bool placed;
	
	
	bool place {
		if empty(available_sq) {
			available_sq <- cell where (each.grid_y = row);
		}
		write "placing... " + row;
		available_sq <- available_sq where (each.is_safe());
		write "options " + available_sq;
		if empty(available_sq) {
			return false;
		}
		
		// select the next square
		if current_sq = nil { // hasn't been placed yet
			current_sq <- available_sq at 0;
		} else if empty(available_sq where (each.grid_x > current_sq.grid_x)) { // can't place anywhere else
			return false;
		} else { // can place
			current_sq <- available_sq where (each.grid_x > current_sq.grid_x) at 0;
		}
		
		write "selected square: " + current_sq;
		location <- current_sq.location;
		return true;
	}
	
	bool your_turn {
		// can't place -> to predecessor
		// has placed -> to successor
		// if has placed and successor = nil -> write something about being done
		if successor = nil and placed {
			return true;
		}
		
		do start_conversation
			to: [placed ? successor : predecessor]
			protocol: 'fipa-propose'
			performative: 'inform'
			contents: ['your turn']
		;
		return false;
	}
	
	reflex my_turn when: !empty(informs) and (time mod n_size = row) {
		message msg <- (informs at 0).contents; // clear message queue
		
		// receive message that it's my turn
		//   when predecessor has placed
		//   or successor can't place
		//  either way, move to next available
		if current_sq != nil { // update board
			do start_conversation
				to: [current_sq]
				protocol: 'fipa-propose'
				performative: 'inform'
				contents: ['remove']
			;
		}
		placed <- place();
		if placed { // update board
			do start_conversation
				to: [current_sq]
				protocol: 'fipa-propose'
				performative: 'inform'
				contents: ['place']
			;
		} else { // reset available squares before informing predecessor
			current_sq <- nil;
			available_sq <- cell where (each.grid_y = row);
		}
		if your_turn() {
			write "Algorithm Complete";
		}
	}
	
	
	aspect base {
		draw square(3) color: #black;
	}
}



experiment chess_board type: gui {
	parameter "dimensions (N)" var: n_size min: 4 max: 20;
	
	output {
		display board_display type: 2d {
			grid cell border: #black;
			species queen aspect: base;
		}
	}
}