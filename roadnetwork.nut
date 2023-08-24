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

class RoadNetwork
{
	pathfind_max_iter = 2800;

	function ConnectCluster(townid_a,townlist_a);
    function BuildRoad(townid_a, townid_b);
    function BuildBusStop(townid);
    function BuildRVStation(townid, type);
    function FillRoute(towna, townb, stationa, stationb, depot);
    function SelectNewEngine();
    function ImproveTownRating(townid, min_rating);
}

function RoadNetwork::ConnectCluster(townid_a,townlist_a)
{
	Info("=============================================================");
	Info("Starting cluster from Town: " + AITown.GetName(townid_a));

	// Get list of Towns closest to A
	local townlist_b = B.Return_ClosestTowns_List(townid_a,townlist_a);

	// Remove towns already serviced elsewhere when enabled
	if(!AIController.GetSetting("reuse_towns")) {
		townlist_b.RemoveList(this.towns_used_bus);
	}

	// Start on one of the Town B (the surrounding cities of A)
	local townid_b = townlist_b.Begin();

	// Try to connect towns_to_cluster amount of Towns together
	for(local i=0;i<towns_to_cluster;i++)
	{
		local builtroad = null;

		// Skip to next now to avoid connecting to itself (same Towm)
		townid_b = townlist_b.Next();

		Info("=============================================================");
		Info("About to connect (A): " + AITown.GetName(townid_a) + " -> (B): " + AITown.GetName(townid_b));

		// Build a road between the 2 Towns. Try a few times (if needed)
		for (local a=0;a<road_build_attempts;a++) {

			Info("Pathbuilding.. Attempt: " + (a+1) + " / " + road_build_attempts);
			builtroad = RoadNet.BuildRoad(townid_a,townid_b); this.Sleep(1); if (builtroad) break;
			Info("Pathbuilding to " + AITown.GetName(townid_b) + " failed.");

		}

		// ROAD FAILURE
		if(!builtroad) {
			Warning("Pathbuilding to " + AITown.GetName(townid_b) + " failed! Skipping this connection for now.");

		// ROAD SUCCESS
		} else {
			Info("Road between " + AITown.GetName(townid_a) + " and " + AITown.GetName(townid_b) + " done.");

			// Build Depot, Bus Stops and fill the new route with buses
			local busstop_a = RoadNet.BuildBusStop(townid_a);
			local busstop_b = RoadNet.BuildBusStop(townid_b);
			local bus_depot = RoadNet.BuildRVStation(townid_a,"depot");

			if (busstop_a && busstop_b && bus_depot) {
				local stop_dist = AIMap.DistanceManhattan(busstop_a, busstop_b);
				Info("Distance between busstops: " + stop_dist);

				// Fill route and on success add this Town to used list
				if (RoadNet.FillRoute(townid_a,townid_b,busstop_a,busstop_b,bus_depot)) {
					this.towns_used_bus.AddItem(townid_b, AITown.GetLocation(townid_b));
				}
			}
		}
		// Airlines if enabled and possible
		if(AIController.GetSetting("use_planes") && !AIGameSettings.IsDisabledVehicleType(AIVehicle.VT_AIR) && AIGameSettings.GetValue("vehicle.max_aircraft") > 0) {
			AirNet.ManageAir();
		}
	}
}

function RoadNetwork::BuildRoad(townid_a,townid_b) {
/*
cost.max_cost 			2000000000 	The maximum cost for a route.
cost.tile 				100 The cost for a single tile.
cost.no_existing_road 	40 	The cost that is added to _cost_tile if no road exists yet.
cost.turn 				100 The cost that is added to _cost_tile if the direction changes.
cost.slope 				200 The extra cost if a road tile is sloped.
cost.bridge_per_tile 	150 The cost per tile of a new bridge, this is added to _cost_tile.
cost.tunnel_per_tile 	120 The cost per tile of a new tunnel, this is added to _cost_tile.
cost.coast 				20 	The extra cost for a coast tile.
cost.max_bridge_length 	10 	The maximum length of a bridge that will be build. Note that all existing bridges will be explored, regardless of their length.
cost.max_tunnel_length 	20 	The maximum length of a tunnel that will be build. Note that all existing tunnels will be explored, regardless of their length. 
*/
	AIRoad.SetCurrentRoadType(AIRoad.ROADTYPE_ROAD);
	local pathfinder = RoadPathFinder();
	local tilecost = AIRoad.GetBuildCost(AIRoad.ROADTYPE_ROAD, AIRoad.BT_ROAD);

	pathfinder.cost.max_bridge_length = max_bridge_length;
	pathfinder.cost.max_tunnel_length = max_tunnel_length;
	pathfinder.cost.max_cost = 4000000000;
	pathfinder.cost.tile = 100;
	pathfinder.cost.no_existing_road = 250;
	pathfinder.cost.turn = 200;
	pathfinder.cost.slope = 150;
	pathfinder.cost.bridge_per_tile = 550;
	pathfinder.cost.tunnel_per_tile = 350;
	
	// Have money for at least 100 tiles
	while (!B.HasMoney(100 * tilecost)) {
		Info("Waiting for some more money before building a new road [1]..");
		AIController.Sleep(wait_for_money_time);
	}

	/* Swapping destinations, so that the building originates from the hub city,
	 * and by that also has less chance to a vehicle blocking the roadbuilding progress.
	 */
	pathfinder.InitializePath([AITown.GetLocation(townid_b)], [AITown.GetLocation(townid_a)]);

	// Try to find a path
	local path = false;
	local iter = 0; local pathfind_highest_iter = 0;
	local startdate = AIDate.GetCurrentDate();
	while (path == false) {
		iter++;
		path = pathfinder.FindPath(110);
		this.Sleep(1);
		if (iter >= RoadNetwork.pathfind_max_iter) {
			path = null;
			Warning("Stopped Pathfinding at max iteration allowed #"+iter);
			break;
		}
	}
	if (path == null) {
		// No path was found
		Warning("No path was found.");
		return null;
	}else{
		/*
		if (iter > pathfind_highest_iter) { 
			pathfind_highest_iter = iter;
			local currdate = AIDate.GetCurrentDate();
			tookdays = currdate-startdate;
		}
		Warning("Highest # iterations so far: "+pathfind_highest_iter+" and took "+tookdays+" days.");
		*/

		// Make sure we still have enough money for at least 80 tiles
		while (!B.HasMoney(80 * tilecost)) {
			Info("Waiting for some more money before building a new road [2]..");
			AIController.Sleep(wait_for_money_time);
		}
	}

	/* If a path was found, build a road over it. */
	while (path != null) {
		local par = path.GetParent();
		if (par != null) {
			local last_node = path.GetTile();
			if (AIMap.DistanceManhattan(path.GetTile(), par.GetTile()) == 1 ) {
				if (!AIRoad.BuildRoad(path.GetTile(), par.GetTile())) {
				/* An error occured while building a piece of road, handle it. 
				* Note that is can also be the case that the road was already build. */
					switch (AIError.GetLastError()) {
						case AIError.ERR_ALREADY_BUILT:
							break;
						case AIError.ERR_NOT_ENOUGH_CASH:
							Warning("Not enough money to finish the road. Waiting for more..");
							while (!B.HasMoney(60 * tilecost))  {
								AIController.Sleep(wait_for_money_time);
							}
							if (!AIRoad.BuildRoad(path.GetTile(), par.GetTile())) Error("Still no roadpiece? [1]"); return null;
							break;
						case AIError.ERR_VEHICLE_IN_THE_WAY:
							local retries = 0
							while (!AIRoad.BuildRoad(path.GetTile(), par.GetTile()) && retries >=5 ) {
								AIController.Sleep(75); retries++;
							}
							if (retries >=5) Error("Issue with vehicle in the way after 5 tries!"); return null;
							break;
						case AIError.ERR_AREA_NOT_CLEAR:
							if (!AIRoad.IsRoadTile(path.GetTile())) {
								Warning("Road was blocked and will now have to demolish something. [1]");
								AITile.DemolishTile(path.GetTile());
								AIController.Sleep(1);
							}
							/*while (!AIRoad.BuildRoad(path.GetTile(), par.GetTile())) {
								Warning("Road was blocked and will now have to demolish something. [2]");
								AITile.DemolishTile(path.GetTile());
								AIController.Sleep(75);
							}*/
							if (!AIRoad.BuildRoad(path.GetTile(), par.GetTile())) Error("Issue after area was not clear! [1]"); return null;
							break;
						default:
							Warning("Unhandled error while building road: " + AIError.GetLastErrorString() + ".");
							continue;
					}
				}
			} else {
				/* Build a bridge or tunnel. */
				if (!AIBridge.IsBridgeTile(path.GetTile()) && !AITunnel.IsTunnelTile(path.GetTile())) {
					/* If it was a road tile, demolish it first. Do this to work around expended roadbits. */
					if (AIRoad.IsRoadTile(path.GetTile())) AITile.DemolishTile(path.GetTile());
					if (AITunnel.GetOtherTunnelEnd(path.GetTile()) == par.GetTile()) {
						if (!AITunnel.BuildTunnel(AIVehicle.VT_ROAD, path.GetTile())) {
						/* An error occured while building a tunnel. TODO: handle it. */
							switch (AIError.GetLastError()) {
								case AIError.ERR_ALREADY_BUILT:
									break;
								case AIError.ERR_NOT_ENOUGH_CASH:
									Warning("Not enough money to buy a tunnel. Waiting for more..");
									while (AICompany.GetBankBalance(AICompany.COMPANY_SELF) < (50 * AIRoad.GetBuildCost(AIRoad.ROADTYPE_ROAD, AIRoad.BT_ROAD))) {
										AIController.Sleep(wait_for_money_time);
									}
									if (!AITunnel.BuildTunnel(AIVehicle.VT_ROAD, path.GetTile())) Error("Still no tunnel! [1]"); return null;
									break;
								case AIError.ERR_VEHICLE_IN_THE_WAY:
									while (!AITunnel.BuildTunnel(AIVehicle.VT_ROAD, path.GetTile())) {
										AIController.Sleep(50);
									}
									if (!AITunnel.BuildTunnel(AIVehicle.VT_ROAD, path.GetTile())) Error("Still no tunnel! [2]"); return null;
									break;
								default:
									Warning("Unhandled error while building tunnel: " + AIError.GetLastErrorString() + ".");
									continue;
							}

						}
					} else {
						local bridge_list = AIBridgeList_Length(AIMap.DistanceManhattan(path.GetTile(), par.GetTile()) + 1);
						bridge_list.Valuate(AIBridge.GetMaxSpeed);
						bridge_list.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING); // Slowest bridge FTW :D
						if (!AIBridge.BuildBridge(AIVehicle.VT_ROAD, bridge_list.Begin(), path.GetTile(), par.GetTile())) {
						/* An error occured while building a bridge. TODO: handle it. */
							switch (AIError.GetLastError()) {
								case AIError.ERR_ALREADY_BUILT:
									break;
								case AIError.ERR_NOT_ENOUGH_CASH:
									Warning("Not enough money to buy a bridge. Waiting for more..");
									while (AICompany.GetBankBalance(AICompany.COMPANY_SELF) < (200 * AIRoad.GetBuildCost(AIRoad.ROADTYPE_ROAD, AIRoad.BT_ROAD))) {
										AIController.Sleep(wait_for_money_time);
									}
									if (!AIBridge.BuildBridge(AIVehicle.VT_ROAD, bridge_list.Begin(), path.GetTile(), par.GetTile())) Error("Still no bridge! [1]"); return null;
									break;
								case AIError.ERR_VEHICLE_IN_THE_WAY:
									while (!AIBridge.BuildBridge(AIVehicle.VT_ROAD, bridge_list.Begin(), path.GetTile(), par.GetTile())) {
										AIController.Sleep(50);
									}
									if (!AIBridge.BuildBridge(AIVehicle.VT_ROAD, bridge_list.Begin(), path.GetTile(), par.GetTile())) Error("Still no bridge! [2]"); return null;
									break;
								default:
									Warning("Unhandled error while building bridge: " + AIError.GetLastErrorString() + ".");
									continue;
							}
						}
					}
				}
			}
		}
		path = par;
	}
	return true;
}

function RoadNetwork::BuildBusStop(townid)
{
	local range = 5; // Start with 10x10 Rectangle over center of city
	local area = AITileList();
	local townLocation = AITown.GetLocation(townid);

	// Check whether the town rating is (still) good enough and if not try to improve it, as we aim to serve
	RoadNetwork.ImproveTownRating(townid,AITown.TOWN_RATING_GOOD);

	while (range < 30)
	{
		area.AddRectangle(townLocation - AIMap.GetTileIndex(range, range), townLocation + AIMap.GetTileIndex(range, range));
		// Keep only within town influence
		area.Valuate(AITile.IsWithinTownInfluence, townid);
		area.KeepValue(1);
		// Must be a road
		area.Valuate(AIRoad.IsRoadTile);
		area.KeepValue(1);
		// On a flat (no) slope
		area.Valuate(AITile.GetSlope);
		area.KeepValue(AITile.SLOPE_FLAT);
		// With no already present stations
		area.Valuate(AIRoad.IsDriveThroughRoadStationTile);
		area.KeepValue(0);
		// Straight piece of road not blocking new to-be crossroad next to it forming by Town
		area.Valuate(AIRoad.GetNeighbourRoadCount);
		area.KeepValue(2);
		// Accepts and sorts on most passengers in 3 tile radius
		area.Valuate(AITile.GetCargoAcceptance, this.passenger_cargo_id, 1, 1, 3);
		area.Sort(AIList.SORT_BY_VALUE, AIList.SORT_DESCENDING);
		area.RemoveBelowValue(8); // 8 or lower means no acceptance
		area.KeepTop(6); // Keep some top locations
		// Return a random tile from the remaining results (lazy attempt to avoid clustering in center)
		area.Valuate(AIBase.RandItem);

		if (area.Count()) {
			for (local buildTile = area.Begin(); !area.IsEnd(); buildTile = area.Next()) {
				local buildFront = RoadNetwork.GetRoadTile(buildTile);
				if (buildFront) {
					
					// Build it
					local buildStructure = AIRoad.BuildDriveThroughRoadStation(buildTile, buildFront, AIRoad.ROADVEHTYPE_BUS, AIStation.STATION_JOIN_ADJACENT);

					if (!buildStructure) {
						switch (AIError.GetLastError()) {
							case AIError.ERR_NOT_ENOUGH_CASH:
								Warning("Not enough money to build bus Stop. Waiting for more.");
								while (!B.HasMoney(AIRoad.GetBuildCost(AIRoad.ROADTYPE_ROAD, AIRoad.BT_BUS_STOP))) {
									// if (!AIRoad.IsRoadTile(buildTile)) continue;
									AIController.Sleep(wait_for_money_time);
								}
								if (!AIRoad.BuildDriveThroughRoadStation(buildTile, buildFront, AIRoad.ROADVEHTYPE_BUS, AIStation.STATION_JOIN_ADJACENT)) return null;
								break;
							case AIError.ERR_FLAT_LAND_REQUIRED:
							case AIError.ERR_AREA_NOT_CLEAR:
							case AIError.ERR_UNKNOWN:
								continue;
							default:
								Warning("Unhandled ERR building bus Stop: " + AIError.GetLastErrorString() + ". Trying again");
								continue;
						}
					}

					// Check if the build returned an actual valid station
					if (AIStation.IsValidStation(AIStation.GetStationID(buildTile))) {
						Info("Successfully built bus Stop in: " + AITown.GetName(townid));
						Info("This stations Acceptance value: " + AITile.GetCargoAcceptance(buildTile,this.passenger_cargo_id, 1, 1, 3));

						// Add this Town to used list if station/halte
						this.towns_used_bus.AddItem(townid, townLocation);
						return buildTile;
					}
				}
			}
			range++;
		} else {
			range++;
			area.Clear;
		}
	}
	Error("Building bus Stop in " + AITown.GetName(townid) + " failed!");
	return null;
}

function RoadNetwork::GetRoadTile(tile)
{
	local adjacent = AITileList();
	adjacent.AddTile(tile - AIMap.GetTileIndex(1,0));
	adjacent.AddTile(tile - AIMap.GetTileIndex(0,1));
	adjacent.AddTile(tile - AIMap.GetTileIndex(-1,0));
	adjacent.AddTile(tile - AIMap.GetTileIndex(0,-1));
	adjacent.Valuate(AIRoad.IsRoadTile);
	adjacent.KeepValue(1);
	adjacent.Valuate(AIRoad.IsRoadStationTile);
	adjacent.KeepValue(0);
	adjacent.Valuate(AITile.GetSlope);
	adjacent.KeepValue(AITile.SLOPE_FLAT);
	if (adjacent.Count()) return adjacent.Begin();
	else return null;
}

function RoadNetwork::BuildRVStation(townid, type)
{
	local buildType = null;
	Info("Building bus " + type + " in " + AITown.GetName(townid));
	if (type == "station") {
		buildType = AIRoad.BT_BUS_STOP;
	}
	else if (type == "depot") {
		buildType = AIRoad.BT_DEPOT;
		Info("Checking for pre-built depots in " + AITown.GetName(townid));
		local depotList = AIDepotList(AITile.TRANSPORT_ROAD);
		depotList.Valuate(AITile.GetClosestTown);
		depotList.KeepValue(townid);
		if (!depotList.IsEmpty()) {
			Info("Depot in " + AITown.GetName(townid) + " found. Using it instead of building one");
			local depotTile = depotList.Begin();
			return depotTile;
		}
		Info("No depot in " + AITown.GetName(townid) + " found");
	}
	local range = 2;
	local area = AITileList();
	local townLocation = AITown.GetLocation(townid);

	while (range < 80) {
		area.AddRectangle(townLocation - AIMap.GetTileIndex(range, range), townLocation + AIMap.GetTileIndex(range, range));
		area.Valuate(AITile.IsBuildable);
		area.KeepValue(1);
		if (area.Count()) {
			for (local buildTile = area.Begin(); !area.IsEnd(); buildTile = area.Next()) {
				local buildFront = RoadNetwork.GetRoadTile(buildTile);
				if (buildFront) {
					if (!AIRoad.BuildRoad(buildTile, buildFront)) {
						switch (AIError.GetLastError()) {
							case AIError.ERR_NOT_ENOUGH_CASH:
								Warning("Not enough money to build road for bus " + type + ". Waiting for more");
								while (AICompany.GetBankBalance(AICompany.COMPANY_SELF) < AIRoad.GetBuildCost(AIRoad.ROADTYPE_ROAD, AIRoad.BT_ROAD)) {
									if (!AITile.IsBuildable(buildTile)) continue;
									AIController.Sleep(wait_for_money_time);
								}
								if (!AIRoad.BuildRoad(buildTile, buildFront)) return null;
								break;
							case AIError.ERR_VEHICLE_IN_THE_WAY:
								while (!AIRoad.BuildRoad(buildTile, buildFront)) {
									if (!AITile.IsBuildable(buildTile)) continue;
									AIController.Sleep(1000);
								}
								break;
							case AIError.ERR_ALREADY_BUILT:
								break;
							case AIError.ERR_LAND_SLOPED_WRONG:
							case AIError.ERR_AREA_NOT_CLEAR:
							case AIRoad.ERR_ROAD_ONE_WAY_ROADS_CANNOT_HAVE_JUNCTIONS:
							case AIRoad.ERR_ROAD_WORKS_IN_PROGRESS:
							default:
								Warning("Unhandled error while building bus " + type + ": " + AIError.GetLastErrorString() + ". Trying again");
								continue;
						}
					}
					local buildStructure = null;
					if (type == "depot") buildStructure = AIRoad.BuildRoadDepot(buildTile, buildFront);
					else if (type == "station") buildStructure = AIRoad.BuildRoadStation(buildTile, buildFront, AIRoad.ROADVEHTYPE_BUS, AIStation.STATION_JOIN_ADJACENT);
					else return null;
					if (!buildStructure) {
						switch (AIError.GetLastError()) {
							case AIError.ERR_NOT_ENOUGH_CASH:
								Warning("Not enough money to build bus " + type + ". Waiting for more");
								while (AICompany.GetBankBalance(AICompany.COMPANY_SELF) < AIRoad.GetBuildCost(AIRoad.ROADTYPE_ROAD, buildType)) {
									if (!AITile.IsBuildable(buildTile)) continue;
									AIController.Sleep(wait_for_money_time);
								}
								if (type == "depot" && !AIRoad.BuildRoadDepot(buildTile, buildFront)) return null; 
								else if (type == "station" && !AIRoad.BuildRoadStation(buildTile, buildFront, AIRoad.ROADVEHTYPE_BUS, AIStation.STATION_JOIN_ADJACENT)) return null;
								break;
							case AIError.ERR_FLAT_LAND_REQUIRED:
							case AIError.ERR_AREA_NOT_CLEAR:
							default:
								Warning("Unhandled error while building bus " + type + ": " + AIError.GetLastErrorString() + ". Trying again");
								continue;
						}
					}

					Info("Successfully built bus " + type);
					return buildTile;
				}
			}
			range++;
		} else {
			range++;
			area.Clear;
		}
	}
	Error("Building bus " + type + " in " + AITown.GetName(townid) + " failed");
	return null;
}

function RoadNetwork::FillRoute(towna,townb,stationa,stationb,depot)
{
	Info("Filling Route..");

	// Do we have a City in one of the given Towns?
	local has_city = false;	if (AITown.IsCity(towna) || AITown.IsCity(townb)) has_city = true;

	// Select (new) type of vehicle to buy
	local engine = RoadNetwork.SelectNewEngine(); if (!engine) return false;

	// Wait for cash
	local price = AIEngine.GetPrice(engine);
	while (!B.HasMoney(price*1.04)) {
		Info("Waiting for enough money for a bus..");
		AIController.Sleep(wait_for_money_time);
	}

	// Buy it
	local vehicle_id = AIVehicle.BuildVehicle(depot, engine);

	// Add orders
	AIOrder.AppendOrder(vehicle_id, stationa,0);
	AIOrder.AppendOrder(vehicle_id, stationb,0);

	AIVehicle.StartStopVehicle(vehicle_id);

	// Clone this bus few times
	for(local n=1;n<buses_per_route;n++)
	{
		// Wait for cash
		local price = AIEngine.GetPrice(engine);
		while (!B.HasMoney(price*1.04)) {
			Info("Waiting for enough money for a bus..");
			AIController.Sleep(wait_for_money_time);
		}

		local clone_id = AIVehicle.CloneVehicle(depot, vehicle_id, true);
		AIVehicle.StartStopVehicle(clone_id);
	}

	if(AIVehicle.IsValidVehicle(vehicle_id)) {
		Info("Bus(es) built in: "+AITown.GetName(towna)+", route now complete.");
		return true;
	}
  return false;
}

function RoadNetwork::SelectNewEngine()
{
	local engine_list = AIEngineList(AIVehicle.VT_ROAD);
	//engine_list.Valuate(AIEngine.GetDesignDate);

	engine_list.Valuate(AIEngine.GetRoadType);
	engine_list.KeepValue(AIRoad.ROADTYPE_ROAD);

	engine_list.Valuate(AIEngine.GetCargoType);
	engine_list.KeepValue(passenger_cargo_id);

	engine_list.Valuate(AIEngine.GetReliability);
	engine_list.KeepTop(1); // We want the best Reliability

	//engine_list.Valuate(AIEngine.GetCapacity);
	//engine_list.Sort(AIList.SORT_BY_VALUE, AIList.SORT_DESCENDING);

	if (engine_list.Count()) return engine_list.Begin();
	Error("Could not fetch a valid Engine!"); return null;
}

function RoadNetwork::ImproveTownRating(townid, min_rating)
{
	// Check whether the current rating is good enough
	local rating = AITown.GetRating(townid, AICompany.COMPANY_SELF);
	if (rating == AITown.TOWN_RATING_NONE || rating >= min_rating) return true;

	local location = AITown.GetLocation(townid);

	Info("Planting me some TREES around " + AITown.GetName(townid) + " to pump my ratings.");

	for (local size = 3; size <= 20; size++) {

		// Create up to a quite large (max 40 by 40 tiles) rectangle to cater for real big cities
		local list = AITileList();
		list.AddRectangle(location - AIMap.GetTileIndex(size, size), location + AIMap.GetTileIndex(size, size));

		// Only place within influence area, which also looks nicer
		list.Valuate(AITile.IsWithinTownInfluence, townid);
		list.KeepValue(1);

		// Only buildable tiles
		list.Valuate(AITile.IsBuildable);
		list.KeepValue(1);

		// Don't build trees on tiles that already have trees, as this doesn't give any town rating improvement
		//list.Valuate(AITile.HasTreeOnTile);
		//list.KeepValue(0);

		// Plant trees on the applicable tiles
		foreach (tile, dummy in list) {
			AITile.PlantTree(tile);
		}

		// Check whether the (new) rating is now good enough
		if (AITown.GetRating(townid, AICompany.COMPANY_SELF) >= min_rating) return true;
	}

	// It was not possible to improve the rating to the requested value by treeplanting alone
	return false;
}