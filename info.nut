class Swarm extends AIInfo
{
  function GetAuthor()        { return "SAW"; }
  function GetName()          { return "Swarm"; }
  function GetDescription()   { return "An AI with its main objective to dominate by connecting all towns by roads and buses, so people may connect more."; }
  function GetVersion()       { return 1; }
  function MinVersionToLoad() { return 1; }
  function GetDate()          { return "2021-12-20"; }
  function CreateInstance()   { return "Swarm"; }
  function GetShortName()     { return "SWRM"; }
  function GetAPIVersion()    { return "1.9"; }

  function GetSettings() {
    AddSetting({name = "towns_to_cluster",  description = "Connect to and cluster with this many other towns", min_value = 2, max_value = 8, easy_value = 3, medium_value = 3, hard_value = 3, custom_value = 3, flags = AICONFIG_INGAME});
    AddSetting({name = "buses_per_route",   description = "Buses per route", min_value = 1, max_value = 10, easy_value = 2, medium_value = 2, hard_value = 3, custom_value = 3, flags = AICONFIG_INGAME});
    AddSetting({name = "reuse_towns",       description = "Allow busroutes to towns already serviced",  easy_value = 1, medium_value = 1, hard_value = 1, custom_value = 1, flags = AICONFIG_BOOLEAN});
	AddSetting({name = "build_statues",     description = "Build statues when having loads of money",  easy_value = 1, medium_value = 1, hard_value = 1, custom_value = 1, flags = AICONFIG_BOOLEAN});
	AddSetting({name = "use_planes",        description = "Allow aircraft", easy_value = 1, medium_value = 1, hard_value = 1, custom_value = 1, flags = AICONFIG_BOOLEAN});
    //AddSetting({name = "min_money_route",   description = "M1", min_value = 500000, max_value = 500000, easy_value = 500000, medium_value = 500000, hard_value = 500000, custom_value = 500000, flags = AICONFIG_INGAME});
    //AddSetting({name = "min_money_aircraft",   description = "M1", min_value = 100000, max_value = 100000, easy_value = 100000, medium_value = 100000, hard_value = 100000, custom_value = 100000, flags = AICONFIG_INGAME});
    //AddSetting({name = "min_money_costly_aircraft",   description = "M1", min_value = 250000, max_value = 250000, easy_value = 250000, medium_value = 250000, hard_value = 250000, custom_value = 250000, flags = AICONFIG_INGAME});
  }
}
RegisterAI(Swarm());