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

class Town
{
	id = null;
	outerLayer = null;
	stations = null;
	depot = null;
	suspended = null;
	newStationTries = null;
	connections = null;
	constructor(townid) {
		this.id = townid;
		this.outerLayer = true;
		this.stations = [];
		this.depot = null;
		this.connections = AIList();
	}
	function Begin();
	function BuildStation();
	function End();
}

function Town::Begin() {
	Log.Info("Attempting to build station and depot");
	local station=Road.BuildStopInTown(this.id,AIRoad.ROADVEHTYPE_BUS,Helper.GetPAXCargo(),Helper.GetPAXCargo());
	if(!station) {
		Log.Warning("Could not build station!");
		return false;
	}
	this.stations.append(AIStation.GetStationID(station));
	this.depot=Road.BuildDepotNextToRoad(station, 25, 125);
	if(!this.depot) {
		Log.Warning("Could not build depot!");
		return false;
	}
	this.suspended=false;
	this.newStationTries=0;
	return true;
}

function Town::BuildStation() {
	// Not yet implemented
	Log.Info("Empty Function");
}

function Town::End() {
	for(local i=0;i<this.stations.len();i++) {
		AIRoad.RemoveRoadStation(AIStation.GetLocation(this.stations[i]));
		while(AIStation.IsValidStation(this.stations[i])) AIRoad.RemoveRoadStation(AIStation.GetLocation(this.stations[i]));
	}
	AIRoad.RemoveRoadDepot(this.depot);
	this.id=null;
}