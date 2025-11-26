model queens

global {
	int n_size <- 8;
	
	init {
		create queen number: n_size;
		
		list<queen> queens <- queen where (true);
		
		(queens at 0).successor <- queens at 1;
		(queens at 0).row <- 0;
		(queens at 0).location <- {0, 50/n_size};
		loop i from: 1 to: n_size-2 {
			(queens at i).predecessor <- queens at (i-1);
			(queens at i).successor <- queens at (i+1);
			(queens at i).row <- i;
			(queens at i).location <- {0, (i*100 + 50)/n_size};
		}
		(queens at (n_size-1)).predecessor <- queens at (n_size-2);
		(queens at (n_size-1)).row <- n_size-1;
		(queens at (n_size-1)).location <- {0, 100-50/n_size};
		
		create initiator {
			first <- queens at 0;
		}
		bool started <- (initiator at 0).start();
	}
}

species initiator skills: [fipa] {
	queen first;
	
	bool start {
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
	bool has_queen {
		return !empty(queen inside self);
	}
	rgb color <- grid_x mod 2 = grid_y mod 2 ? rgb(238,238,210) : rgb(118, 150, 86);
	
	bool is_safe {
		if grid_y = 0 {
			return true;
		}
		// straight up  ( | )
		loop row from: 0 to: max(0, grid_y-1) {
			if cell[grid_x, row].has_queen() {
				return false;
			}
		}
		
		// diagonal up-left  ( \ )
		int col <- grid_x-1;
		loop row from: grid_y-1 to: 0 {
			if col < 0 { break; }
			if cell[col, row].has_queen() {
				return false;
			}
			col <- col - 1;
		}
		
		// diagonal up-right  ( / )
		col <- grid_x+1;
		loop row from: grid_y-1 to: 0 {
			if col >= n_size { break; }
			if cell[col, row].has_queen() {
				return false;
			}
			col <- col + 1;
		} 
		
		return true;
	}
}


species queen skills: [fipa] {
	image_file queen_shape <- image_file("../queen.png");
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
		available_sq <- available_sq where (each.is_safe());
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
	
	reflex my_turn when: !empty(informs) {
		message msg <- (informs at 0).contents; // clear message queue
		
		// receive message that it's my turn
		//   when predecessor has placed
		//   or successor can't place
		//  either way, move to next available
		placed <- place();
		if !placed { // reset available squares before informing predecessor
			current_sq <- nil;
			available_sq <- cell where (each.grid_y = row);
		}
		if your_turn() {
			write "Algorithm Complete (at time " + int(time) + ")";
		}
	}
	

	aspect icon {
	    draw queen_shape size: 100/n_size;
	}

}



experiment chess_board type: gui {
	parameter "dimensions (N)" var: n_size min: 4 max: 20;
	
	output {
		display board_display type: 2d {
			grid cell border: #black;
			species queen aspect: icon;
		}
	}
}