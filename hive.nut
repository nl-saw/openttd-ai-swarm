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

class Hive
{
	function ColourCompany();
    function NameCompany(name);
    function NamePresident(name);
    function HasMoney(amount);
    function GetMoney(amount);
	function BuildHQ(townid);
	function ManageLoan();
	function Return_TopTowns_List();
	function Return_ClosestTowns_List(townid, townlist);
}

function Hive::ColourCompany()
{
/*
  COLOUR_DARK_BLUE,
  COLOUR_PALE_GREEN,
  COLOUR_PINK,
  COLOUR_YELLOW,
  COLOUR_RED,
  COLOUR_LIGHT_BLUE,
  COLOUR_GREEN,
  COLOUR_DARK_GREEN,
  COLOUR_BLUE,
  COLOUR_CREAM,
  COLOUR_MAUVE,
  COLOUR_PURPLE,
  COLOUR_ORANGE,
  COLOUR_BROWN,
  COLOUR_GREY,
  COLOUR_WHITE,
*/
	local company_colour1 = AICompany.COLOUR_BROWN;
	local company_colour2 = AICompany.COLOUR_GREY;

	local vehicle_colour1 = AICompany.COLOUR_CREAM;
	local vehicle_colour2 = AICompany.COLOUR_WHITE;

	if (!AICompany.SetPrimaryLiveryColour(AICompany.LS_DEFAULT, company_colour1)) {}
	if (!AICompany.SetSecondaryLiveryColour(AICompany.LS_DEFAULT, company_colour2)) {}

	if (!AICompany.SetPrimaryLiveryColour(AICompany.LS_BUS, vehicle_colour1)) {}
	if (!AICompany.SetSecondaryLiveryColour(AICompany.LS_BUS, vehicle_colour2)) {}

	if (!AICompany.SetPrimaryLiveryColour(AICompany.LS_TRUCK, vehicle_colour1)) {}
	if (!AICompany.SetSecondaryLiveryColour(AICompany.LS_TRUCK, vehicle_colour2)) {}

	if (!AICompany.SetPrimaryLiveryColour(AICompany.LS_SMALL_PLANE, vehicle_colour1)) {}
	if (!AICompany.SetSecondaryLiveryColour(AICompany.LS_SMALL_PLANE, vehicle_colour2)) {}

	if (!AICompany.SetPrimaryLiveryColour(AICompany.LS_LARGE_PLANE, vehicle_colour1)) {}
	if (!AICompany.SetSecondaryLiveryColour(AICompany.LS_LARGE_PLANE, vehicle_colour2)) {}
}

function Hive::NameCompany(name)
{
	if (!AICompany.SetName(name))
	{
		local i = 2; while (!AICompany.SetName(name + " #" + i)) i++;
	}
}

function Hive::NamePresident(name)
{
	if (!AICompany.SetPresidentName(name))
	{
		local i = 2; while (!AICompany.SetPresidentName(name + " #" + i)) i++;
	}
}

function Hive::HasMoney(amount)
{
	// if (AICompany.GetBankBalance(AICompany.COMPANY_SELF) + (AICompany.GetMaxLoanAmount() - AICompany.GetLoanAmount()) > amount) return true;
	if (AICompany.GetBankBalance(AICompany.COMPANY_SELF) >= amount) return true;
	return false;
}

function Hive::GetMoney(amount)
{
	if (!Hive.HasMoney(amount)) return;
	if (AICompany.GetBankBalance(AICompany.COMPANY_SELF) > amount) return;

	local loan = amount - AICompany.GetBankBalance(AICompany.COMPANY_SELF) + AICompany.GetLoanInterval() + AICompany.GetLoanAmount();
	loan = loan - loan % AICompany.GetLoanInterval();
	Info("Need a loan to get " + amount + ": " + loan);
	AICompany.SetLoanAmount(loan);
}

function Hive::BuildHQ(townid)
{	// Build HQ near it. TODO: it better...
	local placeind=AITown.GetLocation(townid);
	while(!AICompany.BuildCompanyHQ(placeind)) placeind+=3;
}

function Hive::ManageLoan()
{
	local balance = AICompany.GetBankBalance(AICompany.COMPANY_SELF);
	local current_loan = AICompany.GetLoanAmount();
	local loan_interval = AICompany.GetLoanInterval();
	local pay_back_total = 0;

	if (AIDate.GetCurrentDate()-lastloanaction >= 90)
	{
		while((balance - pay_back_total >= 4*loan_interval) && (current_loan - pay_back_total > 0))
		{
			pay_back_total += loan_interval;
		}

		if (pay_back_total)
		{
			if(!AICompany.SetLoanAmount(current_loan - pay_back_total))
			{
				Warning(AICompany.GetName() + " Failed to pay back");
			}
			else
			{
				Warning("Paid back: " + pay_back_total);
			}
		}
		Warning("Current Loan: " + AICompany.GetLoanAmount());
	    lastloanaction = AIDate.GetCurrentDate();
	}
}

function Hive::Return_TopTowns_List()
{
	// Get list of Towns, somewhat randomized but best populations
    local townlist_a = AITownList();
    Utils_Valuator.Valuate(townlist_a, Hive._TownValuator);
    townlist_a.Sort(AIList.SORT_BY_VALUE, AIList.SORT_DESCENDING);
    return townlist_a;
}

function Hive::_TownValuator(town_id)
{
	return AIBase.RandRange(AITown.GetPopulation(town_id));
}

function Hive::Return_ClosestTowns_List(townid,townlist)
{
	// Get Towns closest to townid, from supplied townlist
	local townlist_b = AIList();
	for(local i=0;i<townlist.Count();i++)
	{
		townlist_b.AddItem(i,AITown.GetDistanceSquareToTile(i,AITown.GetLocation(townid)));
	}
	townlist_b.Sort(AIList.SORT_BY_VALUE, true);
	return townlist_b;
}