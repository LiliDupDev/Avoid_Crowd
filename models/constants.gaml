/**
* Name: constants
* Based on the internal empty template. 
* Author: Lili
* Tags: 
*/


model constants

global{
	date starting_date <- date([2020,10,13,0,0,0]);

	/* ************************* Connection Data ************************** */
	string tcp_server 	<- "localhost";
	int tcp_server_port <- 9999;
	
	string udp_server 	<- "localhost";
	int udp_server_port <- 9877;
	
	/* ************************* Map ************************** */
	file streets_shapefile 				<- file("../includes/big_road.shp");
	file residential_blocks_shapefile 	<- file("../includes/BloquesResidencial_3.shp");
	file comercial_blocks_shapefile 	<- file("../includes/BloquesComercial_3.shp");
	matrix store_locations 				<- matrix(csv_file("../includes/store_data.csv", true));  // load CSV with store location

}

