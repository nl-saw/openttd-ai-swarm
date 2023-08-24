/*
 * This file is part of Swarm, which is an AI for OpenTTD
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

class AirNetwork
{
	airport_max_aircraft = 16;

	function ManageAir();
	function BuildAirport(location);
}

function AirNetwork::ManageAir()
{
	Info("ManageAir");

	/*
	local list = AIVehicleList();
	list.Valuate(AIVehicle.GetVehicleType);
	list.KeepValue(AIVehicle.VT_AIR);
	list.Valuate(AIVehicle.GetAge);
	list.KeepAboveValue(365 * 2);
	list.Valuate(AIVehicle.GetProfitLastYear);
	for (local i = list.Begin(); !list.IsEnd(); i = list.Next()) {
		local profit = list.GetValue(i);
		if (profit < (GetSetting("min_profit_keep_aircraft")) && AIVehicle.GetProfitThisYear(i) < (GetSetting("min_profit_keep_aircraft"))) {
			if (!vehicle_to_depot.rawin(i) || vehicle_to_depot.rawget(i) != true) {
				Info("Sending " + i + " to depot as profit is: " + profit + " / " + AIVehicle.GetProfitThisYear(i));
				AIVehicle.SendVehicleToDepot(i);
				vehicle_to_depot.rawset(i, true);
			}
		}
		if (vehicle_to_depot.rawin(i) && vehicle_to_depot.rawget(i) == true) {
			if (AIVehicle.SellVehicle(i)) {
				Info("Selling " + i + " as it finally is in a depot.");
				local list2 = AIVehicleList_Station(AIStation.GetStationID(this.route_1.GetValue(i)));
				if (list2.Count() == 0) AirNetwork.SellAirports(i);
				vehicle_to_depot.rawdelete(i);
			}
		}
	}
	*/

	// Get a list of all our airports, sort on passengers waiting desc
	local airports = AIStationList(AIStation.STATION_AIRPORT);
	airports.Valuate(AIStation.GetCargoWaiting, this.passenger_cargo_id);
	airports.Sort(AIList.SORT_BY_VALUE, AIList.SORT_DESCENDING);

	// Create a seperate list and add all the returned airports to it
	local aplist = AIList();
	aplist.AddList(airports);

	// Go through and filter out stations that already have X or more aircraft assigned
	for (local ap = airports.Begin(); !airports.IsEnd(); ap = airports.Next()) {
		if (AIVehicleList_Station(ap).Count() >= AirNetwork.airport_max_aircraft) aplist.RemoveItem(ap);
	}

	if (aplist.Count() < 1) {
		Warning("We do not have any Airports servicable. Building new one.");
		AirNetwork.BuildAirport(0);
		return true;
	}

	// Go through the filtered list and see what we can do to improve the AP if needed
	for (local i = aplist.Begin(); !aplist.IsEnd(); i = aplist.Next())
	{
		local assigned_to = AIVehicleList_Station(i);
		local pax_amount = AIStation.GetCargoWaiting(i,this.passenger_cargo_id);
		local hangar = AIAirport.GetHangarOfAirport(AIStation.GetLocation(i));

		//Info("Assigned amount: "+assigned_to.Count());

		// More than X amount of passengers waiting
		if (pax_amount >= max_pax_waiting) {

			Info("Airport " + i + " (" + AIStation.GetLocation(i) + ") has enough passengers waiting, buying a new aircraft.");

			// We only need one random aircraft to examine
			assigned_to.Valuate(AIBase.RandItem);
			local v = assigned_to.Begin();

			// Wait for enough money for the new aircraft
			local engine = AirNetwork.SelectNewEngine();
			local price = AIEngine.GetPrice(engine);
			while (!B.HasMoney(price*1.02)) {
				Info("Waiting for enough money ("+price+") for an aircraft..");
				AIController.Sleep(wait_for_money_time);
			}

			// Build it and order it to go from A -> B
			local acraft_id = AIVehicle.BuildVehicle(hangar, engine);

			if(AIVehicle.IsValidVehicle(acraft_id)) {

				AIOrder.AppendOrder(acraft_id, AIStation.GetLocation(i), AIOrder.OF_NONE); // A  OF_FULL_LOAD_ANY
				i = aplist.Next(); // Skip the next airport iteration as it will also be served extra by the new aircraft
				AIOrder.AppendOrder(acraft_id, AIStation.GetLocation(i), AIOrder.OF_NONE); // B

				AIVehicle.StartStopVehicle(acraft_id);
				Info("Aircraft built!");
				
				// Updating max Pax according to latest type aircraft
				max_pax_waiting = AIEngine.GetCapacity(engine) * 2.5;
			}
		}

		// Brand new station I assume. No passengers and no aircraft assigned
		else if(pax_amount == 0 && AIVehicleList_Station(i).Count() == 0) {

			Info("Station " + i + " (" + AIStation.GetLocation(i) + ") seems to be brand new. Looking for another new station.");

			// Get a list of all airports, not having any passengers yet
			local new_aps = AIStationList(AIStation.STATION_AIRPORT);
			new_aps.RemoveItem(i); // Remove myself
			new_aps.Valuate(AIStation.GetCargoWaiting, this.passenger_cargo_id);
			new_aps.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
			new_aps.KeepTop(6);

			// Go through and filter out stations that already have aircraft assigned
			for (local check_serviced = new_aps.Begin(); !new_aps.IsEnd(); check_serviced = new_aps.Next()) {
				if (AIVehicleList_Station(check_serviced).Count() > 0) new_aps.RemoveItem(check_serviced);
			}if (new_aps.Count() == 0) { Warning("Did not find other new airport so building one."); AirNetwork.BuildAirport(i); return true; }

			Info("Found this many other empty and unserved stations: "+new_aps.Count()+". Going to use one of them.");
			new_aps.Valuate(AIBase.RandItem);
			new_aps.KeepTop(1);

			local dest_i = new_aps.Begin();
			// i  - Curent AP
			// dest_i - Dest AP

			// Wait for enough money for the new aircraft
			local engine = AirNetwork.SelectNewEngine();
			local price = AIEngine.GetPrice(engine);
			while (!B.HasMoney(price*1.02)) {
				Info("Waiting for enough money ("+price+") for an aircraft..");
				AIController.Sleep(wait_for_money_time);
			}

			// Build it
			local clone_id = AIVehicle.BuildVehicle(hangar, engine);

			if(AIVehicle.IsValidVehicle(clone_id)) {

				AIOrder.AppendOrder(clone_id, AIStation.GetLocation(i), AIOrder.OF_NONE);
				AIOrder.AppendOrder(clone_id, AIStation.GetLocation(dest_i), AIOrder.OF_NONE);
				AIVehicle.StartStopVehicle(clone_id);

				Info("Aircraft built on new Airport!");
			}
		}

		// Station does not have enough passengers waiting
		else {
			Info("Station Not "+max_pax_waiting+" :"+i);
		}
	}
	Info("Done manage!");
}

function AirNetwork::BuildAirport(location)
{
	local airport_type = AIAirport.AT_INVALID;
		 if(AIAirport.IsValidAirportType(AIAirport.AT_INTERNATIONAL))	{ airport_type = AIAirport.AT_INTERNATIONAL; }
	else if(AIAirport.IsValidAirportType(AIAirport.AT_LARGE)) 			{ airport_type = AIAirport.AT_LARGE; }
	else if(AIAirport.IsValidAirportType(AIAirport.AT_SMALL)) 			{ airport_type = AIAirport.AT_SMALL; }
	else { Error("Can not select a Valid Airport Type."); 				return null; }

	local airport_x = AIAirport.GetAirportWidth(airport_type);
	local airport_y = AIAirport.GetAirportHeight(airport_type);
	local airport_rad = AIAirport.GetAirportCoverageRadius(airport_type);
	local airport_cost = AIAirport.GetPrice(airport_type);
	local town_list = B.Return_TopTowns_List();
	town_list.RemoveList(this.towns_used_air);

//	if (location > 0) {
//		town_list.Valuate(AITile.GetDistanceSquareToTile, AIStation.GetLocation(location));
//		town_list.KeepAboveValue(200);
//	}

	// Wait for enough money
	while (!B.HasMoney(airport_cost*1.02)) {
		Info("Waiting for enough money ("+airport_cost+") for an airport..");
		AIController.Sleep(wait_for_money_time);
	}

	for (local town = town_list.Begin(); !town_list.IsEnd(); town = town_list.Next())
	{
		local tilerange = 38;
		local max_tilerange = 60;

		while (tilerange < max_tilerange)
		{
			tilerange+=2;
			//Info("In tilerange while: "+tilerange+"/"+max_tilerange);
			Sleep(1);
			local town_name = AITown.GetName(town);
			local tile = AITown.GetLocation(town);
			local list = AITileList();
			list.AddRectangle(tile - AIMap.GetTileIndex(tilerange, tilerange), tile + AIMap.GetTileIndex(tilerange, tilerange));
			list.Valuate(AITile.IsBuildableRectangle, airport_x, airport_y);
			list.KeepValue(1);
			list.Valuate(AITile.GetCargoAcceptance, this.passenger_cargo_id, airport_x, airport_y, airport_rad);
			list.Sort(AIList.SORT_BY_VALUE, AIList.SORT_DESCENDING);

			if (list.Count() == 0) continue;
			{
				local test = AITestMode();
				local good_tile = 0;

				for (tile = list.Begin(); !list.IsEnd(); tile = list.Next()) {
					Sleep(1);
					if (!AIAirport.BuildAirport(tile, airport_type, AIStation.STATION_NEW)) continue;
					good_tile = tile;
					break;
				}
				if (good_tile == 0) continue;
			}

			Info("Placing an Airport near " + town_name);

			if (AIAirport.BuildAirport(tile, airport_type, AIStation.STATION_NEW)) {
				Info("This airports Acceptance value: " + AITile.GetCargoAcceptance(tile,this.passenger_cargo_id, airport_x, airport_y, airport_rad));
				this.towns_used_air.AddItem(town, tile);
				return tile;
			}else{
				Warning("Could not place the airport: " + AIError.GetLastErrorString());
			}
		}
	}
	Info("Couldn't find a suitable location to build an airport at.");
	return null;
}

function AirNetwork::SelectNewEngine()
{
	local engine_list = AIEngineList(AIVehicle.VT_AIR);

	engine_list.Valuate(AIEngine.GetCargoType);
	engine_list.KeepValue(this.passenger_cargo_id);

	engine_list.Valuate(AIEngine.GetCapacity);
	engine_list.Sort(AIList.SORT_BY_VALUE, AIList.SORT_DESCENDING);
	engine_list.KeepTop(2);

	//engine_list.Valuate(AIEngine.GetReliability);
	//engine_list.KeepTop(3); // We want next to capacity, good Reliability

	engine_list.Valuate(AIEngine.GetPrice);
	engine_list.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);

	//engine_list.Valuate(AIEngine.GetDesignDate);
	//engine_list.Sort(AIList.SORT_BY_VALUE, AIList.SORT_DESCENDING);
	//engine_list.KeepTop(10);

	//local balance = AICompany.GetBankBalance(AICompany.COMPANY_SELF);
	//engine_list.Valuate(AIEngine.GetPrice);
	//engine_list.KeepBelowValue(balance < (GetSetting("min_money_costly_aircraft")) ? 50000 : (balance < 1000000 ? (GetSetting("min_money_costly_aircraft")) : 1000000));

	//engine_list.Valuate(AIEngine.GetCapacity);
	//engine_list.KeepTop(1);

	if (engine_list.Count()) return engine_list.Begin();
	Error("Could not fetch a valid Aircraft Engine!"); return null;
}