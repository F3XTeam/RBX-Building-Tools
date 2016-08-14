local SyncAPI = script.Parent;
local Tool = SyncAPI.Parent;
local ServerEndpoint = SyncAPI:WaitForChild 'ServerEndpoint';

function IsFilterModeEnabled()
	return (Tool:WaitForChild 'FilterMode').Value;
end;

-- Provide functionality to the local API endpoint instance
SyncAPI.OnInvoke = function (...)

	-- Route requests to server endpoint if in filter mode
	if IsFilterModeEnabled() then
		return ServerEndpoint:InvokeServer(...);

	-- Perform requests locally if working locally
	else
		SyncModule = require(SyncAPI:WaitForChild 'SyncModule');
		return SyncModule.PerformAction(Game.Players.LocalPlayer, ...);
	end;

end;