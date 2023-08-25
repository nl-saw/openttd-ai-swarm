/*
 *  Swarm - An OpenTTD AI by SAW and a work in progress.
 *  Estimated 90% complete, but 100% functional!
 *
 *	12-2021
 *
 * Requires: PathFinder.Road version 4, make sure you have that mod installed
 *
 * Swarm is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3 of the License
 *
 * Swarm is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 */

import("pathfinder.road", "RoadPathFinder", 4);

require("utils/valuator.nut");
require("utils/logsystem.nut");
require("hive.nut");
require("roadnetwork.nut");
require("airnetwork.nut");

B		<- Hive;
Info	<- Logsystem.Info;
Warning <- Logsystem.Warning;
Error	<- Logsystem.Error;
RoadNet	<- RoadNetwork;
AirNet	<- AirNetwork;

class Swarm extends AIController
{
	turn = "AIR";
	max_bridge_length = 30;
	max_tunnel_length = 30;
	road_build_attempts = 3;
	max_pax_waiting = 500;
	towns_to_cluster = AIController.GetSetting("towns_to_cluster");
	buses_per_route = AIController.GetSetting("buses_per_route");
	towns_used_air = AIList;
	towns_used_bus = AIList;
	vehicle_to_depot = {};
	passenger_cargo_id = -1;
	goal_reached = false;
	wait_for_money_time = 250;
	lastloanaction = AIDate.GetCurrentDate();
	pathfind_highest_loop = 0; tookdays = 0;
	alltownslist = AITownList();

	constructor()
	{
		this.towns_used_air = AIList();
		this.towns_used_bus = AIList();

		local list = AICargoList();
		for (local i = list.Begin(); !list.IsEnd(); i = list.Next()) {
			if (AICargo.HasCargoClass(i, AICargo.CC_PASSENGERS)) {
				this.passenger_cargo_id = i;
				break;
			}
		}
		if (passenger_cargo_id == -1) Error("Your game doesn't have any passengers cargo, and as we are a passenger only AI, we can't do anything :( The AI will crash now shortly..");
	}
}

function Swarm::Start()
{
	Warning("G'day mate!");
	local start_tick = AIController.GetTick();
	local start_date = AIDate.GetCurrentDate();
	local townlist_a = B.Return_TopTowns_List();
	local townid_a = townlist_a.Begin();

	AICompany.SetPresidentGender(0); // No offense, ladies
	AICompany.SetLoanAmount(AICompany.GetMaxLoanAmount());

	B.NameCompany("UberSwarm");
	B.NamePresident("I. M. Networth");
	B.ColourCompany();
	B.BuildHQ(townid_a);

	Info("[WORLD] Amount of Towns: "+townlist_a.Count());
	Info("[Game Settings] Max Road Units: "+AIGameSettings.GetValue("vehicle.max_roadveh"));
	Info("[Game Settings] Max Air  Units: "+AIGameSettings.GetValue("vehicle.max_aircraft"));

	// Before starting the main loop, sleep a bit to prevent problems with ecs. IDK, but why not
	AIController.Sleep(max(1, 100 - (AIController.GetTick() - start_tick)));

	// Airlines if enabled and possible - Start with 2 Airports and an Aircraft
	if(AIController.GetSetting("use_planes") && !AIGameSettings.IsDisabledVehicleType(AIVehicle.VT_AIR) && AIGameSettings.GetValue("vehicle.max_aircraft") > 0)
	{
		// The lazy approach, for now
		AirNet.ManageAir();	Sleep(1);
		AirNet.ManageAir();	Sleep(1);
		AirNet.ManageAir();
	}

	// MAIN LOOP
	while(1)
	{
		// .. as long as any Town has not been seviced yet or max Road Units been reached
		while(townlist_a.Count() > 0 && !goal_reached)
		{
			Info("- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -");
			Info("Remaining Unserviced Towns by buses: " + townlist_a.Count());

			// Form a new cluster from one of the bigger Towns to nearby Towns from a Townlist
			RoadNet.ConnectCluster(townid_a,alltownslist);

			// Add this Town A to towns_used_bus list and then remove it for the available remaining Towns
			this.towns_used_bus.AddItem(townid_a, AITown.GetLocation(townid_a));
			townlist_a.RemoveList(this.towns_used_bus);

			//Set next town A
			townid_a = townlist_a.Next();

			// Check on Vehicle limit and if met, set goal_reached
			local vlist = AIVehicleList();
			local total_road = 0;
			for (local i = vlist.Begin(); !vlist.IsEnd(); i = vlist.Next()) { if (AIVehicle.VT_ROAD) total_road++; }
			if (total_road >= AIGameSettings.GetValue("vehicle.max_roadveh")) goal_reached = true;

			// Manage (payback) loan
			if (AIDate.GetCurrentDate()-start_date >= 600) B.ManageLoan();

		}

		while(townlist_a.Count() == 0 || goal_reached)
		{
			Info("Okay I am Done :) Tried to connect all the towns now and/or hit (road) vehicle limit. Will idle from here on out. Thanks for having me!");
			AIController.Sleep(56000);
		}

   }
  Info("Exiting");
}