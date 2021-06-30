/***
* Name: TCPAvoidModelSave
* Author: Lili
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model TCPAvoidModelSave

import "constants.gaml"

global{
	int displatTextSize <- 4;
	bool flg_save_agent <- false;
	
	/* ************************* Parameters ************************** */
	float 	percentage_allowed	<- 0.25		category:'Environment';
	bool	allow_cycle			<- false	category:'Environment';
	float 	cycle_rate			<- 0.0		category:'Environment';
	
	int 	peopleApp 			<- 1000		category:'New simulation';
	int 	peopleNApp 			<- 0		category:'New simulation'; // Agentes sin python
	
	
	int	 	wait_response_time		;
	float	app_trust_decrease	<- 1.0;
	
	
	float health_distance <-	1.5;
	
	
	/* ********************* Variables to save ********************* */
	bool save_to_CSV <- true; // True when need to save state of variables
	string scenario <- "Scenario_3_Old";
	map<string,float> crowd_by_store ;
	
	
	/* ************************* Monitors ************************** */
	int good_rec				<-	0;
	int bad_rec					<-	0;
	int times_follow_app		<-	0;
	int times_follow_known		<-	0;
	int rec_count				<- 	0;
	int count_interactions  	<-  0;
	//int request_rec			<- 	0; 
	
	
	/* ************************* Maps ************************** */
	geometry shape <- envelope(streets_shapefile);
	graph net_street;
	//float step <- 1 #mn;//simulation step defined by minutes in a real world
	list<store_point> stores;
	map<street,float> current_weights;
	
	/* ************************* Simulation ID ************************** */
	int person_id 	<- 0;
	int user_id 	<- 0;
	int app_id 		<- 0;
	
	
	// Global variables for simulation
	map<int,string> choice	<-[1::"App", 2::"Knowledge"];
	int people_end_shopping <- 0;  												// LD.n 27/10/2020
	int total_people 		<- peopleApp + peopleNApp;  						// LD.n 27/10/2020
	
	// Variables to save
	float 			average_trust_start <- 0.0;
	float 			average_trust_end 	<- 0.0;
	int 			succeed_rec			<- 0;
	int				failed_rec			<- 0;
	//list<string>	store_data			<- []; 
	
	init{
		step <-10#s;
		wait_response_time <- 2; // Cycle that the agent must wait for an answer
		
		// Create manager
		create manager number:1
		{
			do connect to: "localhost" protocol: "udp_server" port: 9877 with_name: "UDP_Server";
		}
		
		// Environment
		create street 				from: streets_shapefile;
		create residential_block 	from: residential_blocks_shapefile;
		create comercial_block 		from: comercial_blocks_shapefile;
		net_street 		<- as_edge_graph(street); 
		current_weights <- street as_map (each::each.shape.perimeter);

		// Creating stores
		create store_point number: store_locations.rows;
		stores <- list(store_point);
		loop i from: 0 to: length(stores) - 1 step:1 {
				point pt 				 <- {float(store_locations[0,i]),float(store_locations[1,i]),0};
				stores[i].entry 		 <- (pt to_GAMA_CRS "EPSG:4326").location;
				stores[i].location 		 <- stores[i].entry;
				stores[i].store 		 <- string(store_locations[5,i]);
				stores[i].capacity 		 <- int(store_locations[6,i]);
				stores[i].people_allowed <- int(stores[i].capacity*percentage_allowed);
				stores[i].color_i		 <- rgb(rnd(0,255),rnd(0,255),rnd(0,255));
				//write stores[i].store+" >> "+stores[i].people_allowed;
				add stores[i].store::0.0 to:crowd_by_store;
		}
		
		write crowd_by_store;
		
		// Create people
		create user number: peopleApp
		{
			name 	<- "user_"+string(user_id);
			user_id <- user_id+1;
		}
		
		
		create person number: peopleNApp
		{
			name 		<- "person_"+string(person_id);
			person_id 	<- person_id+1;
		}
		
		do calculate_app_trust_average entry:1;
		

	}
	
	action calculate_app_trust_average(int entry)
	{
		if peopleApp !=0
		{
			if entry = 1
			{
				//do save_agents;
				loop us over: user {
					average_trust_start <- average_trust_start+us.app_trust;
				}
				average_trust_start <- average_trust_start/peopleApp;
			}
			else if entry = 2
			{
				loop us over: user {
					if us.app_trust>1
					{
						us.app_trust<-1.0;
					}
					average_trust_end <- average_trust_end+us.app_trust;
				}
				average_trust_end <- average_trust_end/peopleApp;			
			}			
		}

	}
	
	action save_agents
	{
	
		if flg_save_agent
		{
			ask user {
				save user to: "../results/user.csv" type:"csv" rewrite: false;
			}
		
			ask people {
				save user to: "../results/people.csv" type:"csv" rewrite: false;
			}
		}
	}
	
	
	/*
	reflex save_store_state when:every(10#cycle){
		ask store_point {
			save store_point to: "../results/store_state.csv" type:"csv" rewrite: false;
		}
	}
	*/ 
	
	reflex update_trust when:every(1#minute)
	{
		do calculate_app_trust_average entry:2;
	}
	
	reflex count_interactions when:every(1#minute){
		count_interactions <- (user sum_of length(each.mobility_contact_u))+(user sum_of length(each.mobility_contact_p))+(person sum_of length(each.mobility_contact_u))+(person sum_of length(each.mobility_contact_p));
	}
	
	
	reflex halting when:(people_end_shopping=total_people)
	{ 
		do calculate_app_trust_average entry:2;
		//do save_agents;
		write "Avg start: "+average_trust_start;
		write "Avg end: "+average_trust_end;
		write "Rec count:" +rec_count;
		write "Halting ...";
		
		do pause;
		
		//do die;
	}
	
	
	reflex save_results when:save_to_CSV and every(1#minute){
		string current <- ""+cycle+","
							+count_interactions+","
							+average_trust_end+","
							+good_rec+","
							+bad_rec+","
							+times_follow_app+","
							+times_follow_known+","
							+crowd_by_store["Galerias"]+","
							+crowd_by_store["Walmart"]+","
							+crowd_by_store["SAMS"]+","
							+crowd_by_store["Costco"]+","
							+crowd_by_store["Cormercial"]+","
							+crowd_by_store["Chedraui"]
							+"";
		save current to: "../results/"+scenario+".csv" type:csv rewrite:false;
	}
	
}




// Environment species
species street{
	aspect basico{
		draw shape color:#black;
	}
}

species residential_block{
	aspect basico{
		draw shape color:rgb(26,82,119,100);
	}
}

species comercial_block{
	int 	current_people;
	aspect basico{
		draw shape color:rgb(70,26,50,100);
	}
}




// Special agent, its mission is recive the responses from recommendation system and give them to an agent
species manager skills:[network]
{	
	// This reflex stays here because otherwise it was not recognizing the messages
	reflex hi when:every(10#cycle)
	{
		//write name+":  Hi";
	}
	
	reflex fetch when:has_more_message() 
	{	
		loop while:has_more_message()
		{
			message s 	<- fetch_message();
			list items 	<- string(s.contents) split_with(";");
			// item: AgentID;Store1;Store2;...;
			int index 	<- int(items[0]);
			remove first(items) from: items;
			ask user[index]{
				do set_recommended_places places: items;
			}
		}
	}
	
}




// Agents
species people skills:[moving] control: simple_bdi{
	string 		name;
	point 		home;
	int			need_supplies_time;
	int			shopping_time;
	point		goal_place; 
	list 		knowledge_base;
	
	int			waitTimeForResponse <- 0;
	float 		speed 				<- 5 #km/#h;
	float   	belief_congestion	<- rnd(0.5,1.0);
	list<point> visited_places  	<- [];
	
	
	/* ************************* BDI ************************** */
	// Personality
	bool use_personality		<- 	true;
	float openness				<-	rnd(0.0,1.0);
	float conscientiousness		<-	rnd(0.0,1.0);
	float extroversion			<-	rnd(0.0,1.0);
	float agreeableness			<-	rnd(0.0,1.0);
	float neurotism				<-	rnd(0.0,1.0);
	
	
	// Beliefs
	predicate need_supplies 	<- new_predicate("need_supplies");
	predicate end_shopping 		<- new_predicate("end_shopping");
	predicate uncongestioned 	<- new_predicate("uncongestioned");
	predicate congestioned 		<- new_predicate("uncongestioned",false);
	
	// Intentions
	predicate stay_home 		<- new_predicate("stay_home");
	predicate walking 			<- new_predicate("walking");
	predicate go_shopping 		<- new_predicate("go_shopping");
	predicate go_home 			<- new_predicate("go_home",false);
	predicate find_near_store 	<- new_predicate("find_near_store");
	predicate shopping 			<- new_predicate("shopping",false);
	predicate wait_response		<- new_predicate("wait_response");
	
	predicate ending			<- new_predicate("ending");
	
	// Emotions
	emotion fearConfirmed 		<- new_emotion("fear_confirmed",congestioned);
	emotion fear 				<- new_emotion("fear",congestioned);
	
	// Emotional process
	bool use_emotions_architecture <- true;
	
	
	// BDI Rules
	rule belief: need_supplies 	new_desire: find_near_store strength:5.0;
	rule belief: end_shopping 	new_desire: go_home;
	rule belief: congestioned   new_emotion: fearConfirmed strength:7.0;
	
	
	// If place is congested then stops and try to find a new place
	rule emotion: fearConfirmed remove_intention: go_shopping  new_desire: find_near_store  strength:5.0;
	
	
	init
	{
		home 				<- any_location_in(one_of(residential_block)); // Para que aparezca en una calle
		location 			<- home;
		need_supplies_time	<- rnd(120);
		waitTimeForResponse <- wait_response_time;
		
		// Add desire to 0 since nobody wants to be in a crowded space
		do add_desire(uncongestioned ,0.0);
		
		// Agent will remain on its house or will be walking
		if flip(0.5)
		{
			do add_intention(stay_home);
		}
		else
		{
			do add_intention(walking);
			goal_place <- any_location_in(one_of(residential_block));
		}
		
		// Fill nearby stores
		do fill_knowledge_base;
		
		//write name+","+conscientiousness+","+agreeableness+","+obedience;
	}
	
	

	
	action fill_knowledge_base
	{
		map<point,float> store_distance;
		int knowledge_base_size <- 2;
		loop store over:stores
		{
			add store.entry::(store.location distance_to self.home) to:store_distance;
		}
		
		list<float> distances <- store_distance sort_by each ;
		
		// sort
		loop element over: store_distance.keys
		{
			if store_distance[element] in [distances[0],distances[1]]
			{
				add element to:knowledge_base;
			}
			
			//add element::store_distance[element] to: knowledge_base;
			if length(knowledge_base) = knowledge_base_size
			{
				break;
			}	
		}
	}
	
	action select_nearby_store
	{
		list<store_point> selectable <- stores-goal_place;
		
		map<point,float> store_distance;
		loop store over:selectable
		{
			add store.entry::(store.location distance_to self.location) to:store_distance;
		}
		
		list<float> distances <- store_distance sort_by each ;
		
		loop element over: store_distance.keys
		{
			goal_place <- element;
		}
		
	}
	
	
	// Perceive
	perceive target:store_point in: 50#m{
		focus id:"uncongestioned" is_uncertain: true;
	
		
		if !(get_predicate(myself.get_current_intention()) in [myself.shopping,myself.wait_response])
		{
			if crowd_percentage >=  myself.belief_congestion and entry = myself.goal_place 
			{
				ask myself { 
					do add_belief(congestioned);
					do add_emotion(fearConfirmed);
				}
			}
			else if get_predicate(myself.get_current_intention()) = myself.go_shopping and entry != myself.goal_place 
			{
				ask myself { 
					do add_belief(uncongestioned); 
					do remove_emotion(fearConfirmed);
				}
			}
			else if myself.has_emotion(myself.fearConfirmed)
			{
				ask myself { 
					do add_belief(uncongestioned); 
					do remove_emotion(fearConfirmed);
				}
			}
		}
		
	}
	
	
	// Plans
	plan dont_move intention: stay_home instantaneous: true
	{
		if need_supplies_time<=0
		{
			do remove_intention(stay_home);
			do add_belief(need_supplies);
		}
		need_supplies_time <- need_supplies_time - 1;		
	}
	
	
	plan go_walking intention: walking finished_when: has_belief(need_supplies) instantaneous: true
	{
		if need_supplies_time<=0
		{
			do remove_intention(walking);
			do add_belief(need_supplies);
		}
		else
		{
			if (location=goal_place)
			{
				goal_place <- any_location_in(one_of(residential_block));
			}
			do goto target: goal_place on:net_street move_weights: current_weights speed: speed recompute_path: false ;
		}
		need_supplies_time <- need_supplies_time - 1;
	}
	

	plan travel_store intention: go_shopping //finished_when:has_emotion(fearConfirmed)
	{
		do goto target: goal_place on:net_street  move_weights: current_weights speed: speed  recompute_path: false;
		if (location =  goal_place)
		{
			do remove_intention(go_shopping);
			do add_intention(shopping);
			shopping_time <- int(gauss(288.0,60.0)); // Considering that every step equals 10 seconds using minutes it'll be (48,10) 
		}
	}	
	
	
	plan travel_home intention: go_home 
	{
		do goto target: home on:net_street move_weights: current_weights speed: speed  recompute_path: false;
		if (location =  home)
		{
			do remove_intention(go_home);
			//do add_intention(stay_home);
			
			
			// Added to evaluate if simulation needs being cycled
			if allow_cycle
			{
				if flip(cycle_rate)
				{
					need_supplies_time	<- rnd(120);
					do add_intention(stay_home);
					
					//write name+" >> Again >> time >> "+ need_supplies_time;
				}
				else
				{
					do add_intention(ending);
					people_end_shopping <- people_end_shopping + 1;
				}
			}
			else
			{
				do add_intention(ending);
				people_end_shopping <- people_end_shopping + 1;
			}
		}
	}
	
	
	plan end intention: ending
	{	
		
	}

}




species user parent:people {
	list<app> 		app_list			<-[];
	float 			app_trust 			<- 0.5;//rnd(0.0,1.0);
	string 			last_choice;
	list<user> 		mobility_contact_u <-[] update:user at_distance(health_distance#meters); 
	list<person> 	mobility_contact_p <-[] update:person at_distance(health_distance#meters); 
	
	
	// New trust model
	int exp_positive					<-	0;
	int exp_negative					<-	0;
	
	
	init
	{
		create app number: 1
		{
			//app_position 	<- app_id;
			name 			<- "app_" + string(app_id); 
			app_id 			<-	app_id+1;
			do connect to: tcp_server protocol: "tcp_client" port: tcp_server_port with_name: "Client";	
		}
		app_list <- list(app);
		
	}
	
	
	
	plan choose_store intention: find_near_store 
	{
		if has_emotion(fearConfirmed)
		{
			waitTimeForResponse <- wait_response_time;
		}
		
		if(waitTimeForResponse = wait_response_time)
		{
			app_list[0].coordinates <- location;
			app_list[0].flgSend <- true;
			ask app_list
			{
				do request;
			}
			app_list[0].flgSend <- false;
			do remove_intention(find_near_store);
			do add_intention(wait_response);
		}
	}
	
	
	// Wait until recommendation server returns a response
	plan wait intention: wait_response 
	{
		point 			converted_target;
		point 			target;
		string			selected;
		list<string> 	pp;
		bool			failed <- false;
		string			current_choice;
		
		point old_goal <- goal_place;
		

		
		if(length(app_list[0].recommended_places)>0)
		{
			rec_count <- rec_count+1;
			// if true select app option, false select from its knowledge_base
			if flip(app_trust)
			{
				selected 		<- app_list[0].recommended_places[0];
				pp 				<-  selected split_with(","); 
				target 			<- {float(pp[0]),float(pp[1])};
				converted_target<- to_GAMA_CRS(target,"EPSG:4326").location;
					
				if goal_place = converted_target
				{
					selected 	<- one_of(app_list[0].recommended_places - app_list[0].recommended_places[0]);
				}
					
				pp 				<-  selected split_with(","); 
					
					
				if length(pp)=2
				{
					target 			<- {float(pp[0]),float(pp[1])};
					converted_target<- to_GAMA_CRS(target,"EPSG:4326").location;
					
						
					goal_place 		<- converted_target;
				}
				else
				{
					failed 		<- true;
					rec_count 	<- rec_count-1;
				}
				current_choice  <- choice[1];
					
					
			}
			else
			{
				// If user is afraid it means that he already encouter a congestioned stored 
				// so he is going to find the nearby store and go there
				if goal_place = knowledge_base[0] and !has_emotion(fearConfirmed)	
				{
					goal_place <- knowledge_base[1];
						
				}
				else if !has_emotion(fearConfirmed)
				{
					goal_place <- knowledge_base[0];
				}
				else
				{
					do select_nearby_store;
				}
					
				current_choice <- choice[2];
					
			}
			
			
			
			if failed
			{
				waitTimeForResponse <- wait_response_time + 1;
				do remove_intention(wait_response);
				do add_intention(find_near_store);
			}
			else
			{
				
				do remove_belief(congestioned);
				do add_belief(uncongestioned);
				
				do remove_intention(wait_response);
				do remove_intention(find_near_store);
				do add_intention(go_shopping);
				
				//write name + " >> has_emotion " + has_emotion(fearConfirmed)  + " >> Last choice " + last_choice + " >> Last visited: "+last(visited_places) + "  >> old_goal: " + old_goal;
				/*
				if has_emotion(fearConfirmed) and last_choice !=choice[2] and app_trust>0 and last(visited_places) != old_goal
				{
					app_trust <- app_trust - app_trust_decrease;
				}
				 */
				if has_emotion(fearConfirmed) and last_choice != choice[2] //and last(visited_places) != old_goal
				{
					save (string(cycle) + "," +name+","+old_goal+";") to: "../results/bad_recommendation.txt" type:"text" rewrite: false;
					bad_rec 		<- 	bad_rec+1;			// Global
					exp_negative	<-	exp_negative+1;		// Individual
				}
				
				
				if current_choice=choice[1]
				{
					times_follow_app <- times_follow_app+1;
				}
				else if current_choice=choice[2]
				{
					times_follow_known <- times_follow_known+1;
				}
				
				// Update trust
				do update_trust;
			}
			
		}
		else if(waitTimeForResponse <= 0) 
		{
			waitTimeForResponse <- wait_response_time + 1;
			do remove_intention(wait_response);
			do add_intention(find_near_store);
		}
		
		last_choice <- current_choice;
		waitTimeForResponse <- waitTimeForResponse - 1;
		
	}
	
	
	plan shop intention: shopping
	{
		if (shopping_time<=0)
		{
			/* 
			if last_choice = choice[1] and app_trust < 1
			{
				app_trust <- app_trust + app_trust_decrease;
			}
			*/
			
			if last_choice = choice[1]
			{
				//save (string(cycle) + "," + name + "," + goal_place + ";") to: "../results/good_recommendation.txt" type:"text" rewrite: false;
				good_rec 		<- good_rec+1;
				exp_positive 	<- exp_positive+1;
			}
				
			if flip(0.9)					// If true don't shop
			{
				do remove_intention(shopping);
				do remove_belief(need_supplies);
				do add_belief(end_shopping);
				do add_intention(go_home);
			}
			else
			{
				do remove_intention(shopping);
				do add_belief(need_supplies);
			}
			add goal_place to: visited_places;
			waitTimeForResponse <- wait_response_time;
		}
		shopping_time <- shopping_time-1;
	}
	
	
	aspect default 
	{
		draw circle(3#m) color: #purple;
		//draw ("B:" + length(belief_base) + ":" + belief_base) color:#black size:displatTextSize; 
		//draw ("D:" + length(desire_base) + ":" + desire_base) color:#black size:displatTextSize at:{location.x,location.y+displatTextSize}; 
		//draw ("I:" + length(intention_base) + ":" + intention_base) color:#black size:displatTextSize at:{location.x,location.y+2*displatTextSize}; 
		//draw (name+", curIntention:" + get_current_intention()) color:#black size:displatTextSize at:{location.x,location.y+3*displatTextSize}; 
	}
	
	
	action set_recommended_places(list<string> places)
	{
		app_list[0].recommended_places <- places;
	}
	
	
	action update_trust
	{
		float 	indirect_experience	<-	0.0;
		float 	direct_experience	<- 	0.0;
		float 	experience			<-	0.0;
		int 	experiences			<-	exp_positive+exp_negative;
		
		if experiences != 0
		{
			string temp_name <- name;
			// Calculate Indirect experience
			indirect_experience 		<-	average_trust_end;
			//list<user> filtered_user <- user where(each.name != temp_name);
			//write length(filtered_user);
			//indirect_experience <- sum(filtered_user collect each.app_trust)/length(filtered_user);
			
			// Direct experience
			direct_experience			<-	exp_positive/experiences;
			experience			<- (obedience*indirect_experience)+((1-obedience)*direct_experience);
			
			app_trust 					<- app_trust + openness*(experience-app_trust)*app_trust_decrease;
		}
		else
		{
			app_trust 					<- app_trust + openness*(app_trust)*app_trust_decrease;
		}
		
	}
	

	/* *************************************** App *************************************** */
	species app skills:[network]
	{
		list<string> 	recommended_places <- [];
		bool 			flgSend <- false;
		string 			name;
		point 			coordinates;
	
		// Send data to server
		action request
		{
			if flgSend
			{
				string converted_coordinates <- string(coordinates CRS_transform("EPSG:4326"));
				do send  contents: converted_coordinates;
			}

		}
	}
	
}



species person parent:people 
{
	list<user> mobility_contact_u <-[] update:user at_distance(health_distance#meters); 
	list<person> mobility_contact_p <-[] update:person at_distance(health_distance#meters); 
	
	plan choose_store intention: find_near_store instantaneous: true
	{
		// If user is afraid it means that he already encouter a congestioned stored 
		// so he is going to find the nearby store and go there
		if goal_place = knowledge_base[0] and !has_emotion(fearConfirmed)	
		{
			goal_place <- knowledge_base[1];
		}
		else if !has_emotion(fearConfirmed)
		{
			goal_place <- knowledge_base[0];
		}
		else
		{
			do select_nearby_store;
		}
		
		do remove_intention(find_near_store);
		do add_intention(go_shopping);
	}
	
	
	plan shop intention: shopping
	{
		if (shopping_time<=0)
		{
			if flip(0.9)						// If true don't shop again
			{
				do remove_intention(shopping);
				do remove_belief(need_supplies);
				do add_belief(end_shopping);
				do add_intention(go_home);
			}
			else
			{
				do remove_intention(shopping);
				do add_belief(need_supplies);
			}
		}
		shopping_time <- shopping_time-1;
	}

	
	aspect default 
	{
		draw circle(3#m) color: #green;
		//draw ("B:" + length(belief_base) + ":" + belief_base) color:#black size:displatTextSize; 
		//draw ("D:" + length(desire_base) + ":" + desire_base) color:#black size:displatTextSize at:{location.x,location.y+displatTextSize}; 
		//draw ("I:" + length(intention_base) + ":" + intention_base) color:#black size:displatTextSize at:{location.x,location.y+2*displatTextSize}; 
		//draw (name+", curIntention:" + get_current_intention()) color:#black size:displatTextSize at:{location.x,location.y+3*displatTextSize}; 
	}

}



species store_point {
	point 	entry;
	string 	store;
	int 	capacity;
	//bool 	crowded;
	int		people_allowed	 <- 1;
	int 	current_people	 <- 0;
	float	crowd_percentage <- 0.0;
	rgb 	color_i;
	
	
	aspect default 
	{
		//draw circle(10) at: location color:#yellow;
		draw circle(10) at: location color:rgb(crowd_percentage*255, (1-crowd_percentage)*255, 0); //border:#black width:1.0;
		//draw ("Count:" + current_people) color:#black size:displatTextSize at:{location.x,location.y-30}; 
	}
	
	reflex count_people 
	{
		// count must be done differentiating user and person, not using people which is the parent species
		list<user> 	 user_count 	<- user overlapping self;
		list<person> person_count 	<- person overlapping self;
		current_people <- length(user_count)+length(person_count);
		
		
		if people_allowed=0
		{
			people_allowed <-1;
		}
		crowd_percentage <- current_people/people_allowed;
		//write crowd_by_store;
		crowd_by_store[store]<-crowd_percentage;
	}
}



experiment mi_experimento type:gui{
	
	parameter "People with App:"				var:peopleApp ;
	parameter "People without App:"				var:peopleNApp;
	parameter "Capacity percentage allowed:" 	var:percentage_allowed 	min:0.0 	max:1.0 	step:0.01;
	parameter "Cycle simulation:" 				var:allow_cycle 		enables:[cycle_rate];
	parameter "Cycle rate:" 					var:cycle_rate 			min:0.0 	max:1.0 	step:0.01;

	
	output{
		//layout #split;
		display GUI type:opengl 
		{
			species street 				aspect: basico		refresh: false;
			species residential_block 	aspect: basico		refresh: false;
			species comercial_block 	aspect: basico		refresh: false;
			species store_point			aspect: default		;//refresh: false;
			species person 				aspect: default		;
			species user 				aspect: default		;
			
			
			
			
			overlay position: { 40#px, 30#px } size: { 0,0} background: #white border: #black {
				string minutes;
				if current_date.minute < 10
				{
					minutes <- "0"+current_date.minute;
				}
				else 
				{
					minutes <- string(current_date.minute);
				}
				
				draw ""+ (current_date.day-1) +" day, "+current_date.hour+":"+minutes at:{ 20#px, 20#px} color:#black font:font("Arial",20,#bold);
			}
			
			
		}
		

		
		display Statistics
		{
    
	    	/*
    		chart "People" type: scatter {
    			datalist stores value:(stores collect each.current_people) legend:(stores collect each.store) color:(stores collect each.color_i) accumulate_values: true line_visible:false;
        		//data "People allowed" value: (stores collect each.people_allowed) accumulate_values: true line_visible:false ;
        	}
        	*/
        	chart "People count" type: histogram  size: {0.5,0.5} position: {0, 0}{
	        	datalist stores value:(stores collect each.current_people) legend:(stores collect each.store) color:(stores collect each.color_i);
	        }
			
			// mobility_contact
			chart "Mobility contacts" type: scatter size: {0.5,0.5} position: {0.5, 0} {
	        	data "Interactions" value: count_interactions accumulate_values: true line_visible:true ;
	        }
				
				
			chart "Crowd by store" type:series y_label:"Crowd percentage"  size: {1,0.5} position: {0, 0.5}
			{
				datalist stores value:(stores collect each.crowd_percentage) legend:(stores collect each.store) color:(stores collect each.color_i) marker:false;
				data "Percentage allowed" value:(percentage_allowed) color:#red marker:false;
				
			}
		}
		
		display statistics_trust
		{
			// mobility_contact
			chart "Trust evolution" type: series size: {1,0.5} position: {0, 0} {
	        	data "Trust" value: average_trust_end  marker:false ;
	        }
	        
	        chart "Recommendation" type: pie size: {0.5,0.5} position: {0, 0.5}
			{
		        data "Good recommendation" value: good_rec 	color: #blue;
		        data "Bad recommendation"  value: bad_rec 	color: #red;
	        }
	        
	        chart "Evolution" type: series size: {0.5,0.5} position: {0.5, 0.5}
			{
		        data "App recommendation" 	value: times_follow_app 	color: #blue;
		        data "Knowledge"  			value: times_follow_known 	color: #red;
	        }
		}
		
		monitor "Times that agent followed App" 		value: times_follow_app;
		monitor "Times that agent didn't follow App" 	value: times_follow_known;
		
		
		
	}
}


