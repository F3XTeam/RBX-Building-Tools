local SyncAPI = script.Parent;
local Tool = SyncAPI.Parent;
local FilterModeEnabled = (Tool:WaitForChild 'FilterMode').Value;
local ServerEndpoint = SyncAPI:WaitForChild 'ServerEndpoint';

-- Start a local sync module when working locally
if not FilterModeEnabled then
	SyncModule = require(SyncAPI:WaitForChild 'SyncModule');	
end;

-- Provide functionality to the local API endpoint instance
SyncAPI.OnInvoke = function (...)

	-- Route requests to server endpoint if in filter mode
	if FilterModeEnabled then
		return ServerEndpoint:InvokeServer(...);

	-- Perform requests locally if working locally
	else
		return SyncModule.PerformAction(Game.Players.LocalPlayer, ...);
	end;

end;