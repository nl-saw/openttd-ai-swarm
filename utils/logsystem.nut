class Logsystem
{
    function Info(string);
    function Warning(string);
    function Error(string);
}

function Logsystem::Info(string)
{
	AILog.Info("[Swarm] " + string);
}

function Logsystem::Warning(string)
{
	AILog.Warning("[Swarm] " + string);
}

function Logsystem::Error(string)
{
	AILog.Error("[Swarm] " + string);
}