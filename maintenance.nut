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

class Maintenance
{
	lastVehicleManage = null;
	lastNewTown = null;
	lastUpdateEngine = null;
	towns = null;
	blacklist = null;
	vehicles = null;
	defaultEngine = null;
	center = null;
	size = null;
	replace = null;
	noReplace = null;
	constructor(epicenter = null) {
		this.towns      = [];
		this.vehicles   = [];
		this.blacklist  = AIList();
		this.defaultEngine = null;
		this.center = epicenter;
		this.size = 1;
	}
	function TownDistValuator(town1,town2,targetDistance);
	function ManageNetwork();
	function ManageVehicles();
	function CreateLink();
	function BuyVehicles(depot,engine,number,order1,order2);
	function SellVehicle(vehicle);
	function FindTown(chosenCity = null, desprate = false);
	function FindCloseConnection(town);
	function AddTown(theTown);
	function LeaveTown(index);
	function Connect(point1,point2);
	function PerformFullUpgrade();
	function ExpandStation(station);
}

function Maintenance::ManageVehicles() {
    Info("Managing Vehicles...");
}

function Maintenance::ManageVehiclesGarbage() {
	Log.Info("Managing Vehicles...");
	// Check for new defaultEngine every once and awhile...
    /*
	if(this.lastUpdateEngine<AIController.GetTick()-10000) {
		Log.Warning("Checking for a new default engine...");
		local newEngine=Engine.GetEngine_PAXLink(0, AIVehicle.VT_ROAD);
		if(newEngine!=this.defaultEngine) {
			AILog.Info("Switching to " + AIEngine.GetName(newEngine))
			local oldEngine = this.defaultEngine;
			this.defaultEngine=newEngine;
			this.noReplace = 0;
			// While we are at it check if it is necisary to mass upgrade vehicles
			if(AICompany.GetBankBalance(AICompany.COMPANY_SELF)>(AIEngine.GetPrice(defaultEngine)*this.vehicles.len())-(AIEngine.GetPrice(oldEngine)*this.vehicles.len())) this.PerformFullUpgrade();
		}
		this.lastUpdateEngine=AIController.GetTick();
	}
    */
	local frontTiles;
	local i=0;
	for(local i=0;i<this.vehicles.len();i++) {
		// Get rid of the sold vehicles in the depot
		if(AIVehicle.IsStoppedInDepot(vehicles[i])) {
			AIVehicle.SellVehicle(vehicles[i]);
			this.vehicles.remove(i);
			continue;
		}
		// Sell non-profitable vehicles
		if(AIVehicle.GetProfitLastYear(vehicles[i])<0 && AIVehicle.GetAge(vehicles[i])>365) {
			Log.Info("Sending " + AIVehicle.GetName(vehicles[i]) + " due to lack of income from vehicle");
			AIVehicle.SendVehicleToDepot(vehicles[i]);
		}
	}
	foreach(town in this.towns) {
		// check, if more than 30 people are waiting at this station, and suspended is on, turn it off
		if(town.suspended && AIStation.GetCargoWaiting(town.stations[0],Helper.GetPAXCargo())>30) {
			Log.Warning("Town is no longer overloaded, un suspendeding");
			town.suspended=false;
		}
		Log.Info("Checking to improve town " + AITown.GetName(town.id));
		// Grow the station
		local numTiles;
		local numVehicleTiles=0;
		// check the front tile of every singe station peice, it is more accurate!
		foreach(stationpiece, _ in Station.GetRoadFrontTiles(town.stations[0])) {
			local stationtiles=Tile.MakeTileRectAroundTile(AIStation.GetLocation(town.stations[0]),4);
			stationtiles.Valuate(AIRoad.IsRoadTile);
			stationtiles.KeepValue(1);
			numTiles=stationtiles.Count();
			// Loop to see if vehicles are on each tile, if numVehicleTiles>0.5*numTiles->grow station
			local vehiclelist;
			foreach(tile, _ in stationtiles) {
				vehiclelist=Vehicle.GetVehiclesAtTile(tile);
				if(!vehiclelist.IsEmpty()) numVehicleTiles++;
			}
		}
		Log.Info("Number of road tiles around station: " + numTiles);
		Log.Info("Number of vehicles on those road tiles: " + numVehicleTiles);
		local stationPlace=AITileList_StationType(town.stations[0],AIStation.STATION_BUS_STOP);
		local good=true;
		foreach(stationPeice, item in stationPlace) {
			if(Vehicle.GetVehiclesAtTile(stationPeice).Count()<2) good=false;
		}
		if(numVehicleTiles>numTiles*0.15 && AITileList_StationType(town.stations[0],AIStation.STATION_BUS_STOP).Count()<5 && good) this.ExpandStation(town.stations[0]);
		// Control suspended attribute, to ensure not to many vehicles get sent to this station. like blacklist
		if(Station.GetRoadFrontTiles(town.stations[0]).Count()==5  && AIStation.GetCargoWaiting(town.stations[0],Helper.GetPAXCargo())<5) {
			Log.Warning("Station is suspended.  Suspending the sending of vehicles to it");
			town.suspended=true;
		}
		//frontTiles=Station.GetRoadFrontTiles(town.stations[0]);
		// Add more vehicles to the station
		if(AIStation.GetCargoWaiting(town.stations[0],Helper.GetPAXCargo())>AIEngine.GetCapacity(defaultEngine) || AIStation.GetCargoRating(town.stations[0],Helper.GetPAXCargo())<50) {
			// First off, always ensure the proper amount of cash :)
			if(!Money.MakeSureToHaveAmount(AIEngine.GetPrice(defaultEngine)*(AIStation.GetCargoWaiting(town.stations[0],Helper.GetPAXCargo())/AIEngine.GetCapacity(defaultEngine)))) {
				Log.Info("Not enough cash to create needed vehicles for now");
				continue;
			}
			Log.Info("Buying more vehicles for " + AITown.GetName(town.id));
			// Variables to help us
			local destinations=[];
			local list;
			// Get each town that goes to this station
			local same=false;
			/*foreach(vehicle in this.vehicles) {
				if(Order.HasStationInOrders(vehicle,town.stations[0])) {
					list=Order.GetStationListFromOrders(vehicle);
					list.RemoveItem(town.stations[0]);
					// Ensure this station does not already exist
					foreach(destiny in destinations) {
						if(destiny==list.Begin()) same=true;
					}
					if(!same) destinations.append(list.Begin());
					same=false;
				}
			}*/
			Log.Info("LENGTH OF DEST: " + destinations.len());
			// OR find stations that are nearby this station
			local townprep=[];
			// Add items from our network (while we are at it scan previous destinations for suspended stations)
			foreach(otherTown in towns) {
				for(local i=0;i<destinations.len();i++) {
				Log.Warning("TOWN SUSPENSION: " + otherTown.suspended);
					if(otherTown.stations[0]==destinations[i] && otherTown.suspended) {
						destinations.remove(i);
						i--;
					}
				}
				if(!otherTown.suspended) townprep.append(otherTown);
				AIController.Sleep(1);
			}
			Log.Info("LENGTH OF DEST: " + destinations.len());
			// Transfer vars to new townlist
			local townlist=AIList();
			foreach(moveTown in townprep) {
				townlist.AddItem(moveTown.id,0);
			}
			Log.Info("COUNT BEFORE: " + townlist.Count());
			// Valuate to nearby towns (be a bit less restrictive of distance away
			townlist.Valuate(this.TownDistValuator,town.id,50);
			townlist.Sort(AIList.SORT_BY_VALUE, true);
			townlist.RemoveAboveValue(60);
			Log.Info("COUNT AFTER: " + townlist.Count());
			// ReAdd to townprep
			// also check for a variety of other problems
			local match=false;
			Log.Info("LENGTH OF DEST: " + destinations.len());
			for(local i=0;i<townprep.len();i++) {
				Log.Info("TOWN: " + AITown.GetName(townprep[i].id));
				foreach(changedTown, item in townlist) {
					if(townprep[i].id==changedTown) {
						match=true;
					}
					if(match) break;
				}
				Log.Info("MATCH: " + match);
				if(!match) {
					townprep.remove(i);
					i--;
				}
				match=false;
				AIController.Sleep(1);
			}
			for(local i=0;i<townprep.len();i++) {
				if(townprep[i].suspended) {
					Log.Warning("FOUND SUSPENDED TOWN " + AITown.GetName(townprep[i].id));
					townprep.remove(i);
					i--;
					continue;
				}
			}
			Log.Info("LENGTH OF TOWNPREP: " + townprep.len());
			// Add to destinations
			foreach(nextTown in townprep) destinations.append(nextTown.stations[0]);
			Log.Info("LENGTH OF DEST: " + destinations.len());
			// Ensure it is not empty
			if(destinations.len()==0) {
				Log.Warning("Could not find a good destination for this town");
				continue;
			}
			// Now find the station with the most passengers
			local bestStation=0;
			local bestWait=-1;
			foreach(station in destinations) {
				Log.Info("Checking station " + AIStation.GetName(station));
				if(AIStation.GetCargoWaiting(station,Helper.GetPAXCargo())>bestWait) {
					if(station == town.stations[0]) {
						Log.Info("Skipping the town because it will cause an infinate loop");
						continue;
					}
					bestStation=station;
					bestWait=AIStation.GetCargoWaiting(station,Helper.GetPAXCargo());
				}
			}
			Log.Info("BestStation: " + AIStation.GetName(bestStation));
			// If the best station does not have many passengers, make a new city connection
			if(!bestStation) continue;
			if(AIStation.GetCargoWaiting(bestStation,Helper.GetPAXCargo())<10/* && AICompany.GetBankBalance(AICompany.COMPANY_SELF)>20000+(AIEngine.GetPrice(defaultEngine)*2)*/) {
				Log.Warning("Entered if statement!!!");
				local myResult;
				if(town.newStationTries>3) myResult=FindTown(town,true);
				else myResult=FindTown(town);
				continue;
			}
			// Ensure that there is a road from here to there
			local result = false;
			Log.Info("Checking roads...");
			foreach(connection, _ in town.connections) {
				Log.Warning("I see station " + AIStation.GetName(connection));
				if(connection == bestStation) result = true;
			}
			//Log.Warning("After foreach loop...");
			if(!result) {
				Log.Info("Town is not connected to the other city.  Connecting it now...");
				if(!this.Connect(AIStation.GetLocation(town.stations[0]),AIStation.GetLocation(bestStation))) {
					Log.Warning("Could not connect roads.  Cancelling...");
					continue;
				}
				// Add town to the list of both towns
				town.connections.AddItem(bestStation,0);
				foreach(townp in townprep) {
					if(townp.stations[0] == bestStation) {
						Log.Warning("Adding to list of connected stations");
						townp.connections.AddItem(town.stations[0],0);
					}
				}
			}
			else Log.Info("Stations " + AIStation.GetName(town.stations[0]) + " and " + AIStation.GetName(bestStation) + " are already connected.");
			Log.Info("Building the vehicles to " + AIStation.GetName(bestStation));
			// We now (finally) build the vehicles
			if(AIStation.GetCargoRating(town.stations[0],Helper.GetPAXCargo())<50) this.BuyVehicles(town.depot,defaultEngine,2,town.stations[0],bestStation);
			else this.BuyVehicles(town.depot,defaultEngine,AIStation.GetCargoWaiting(town.stations[0],Helper.GetPAXCargo())/AIEngine.GetCapacity(defaultEngine),town.stations[0],bestStation);
			// Wait a little
			AIController.Sleep(50);
		}
	}
	this.lastVehicleManage=AIController.GetTick();
}