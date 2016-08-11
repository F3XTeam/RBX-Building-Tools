local ServerEndpoint = script.Parent;
local SyncAPI = ServerEndpoint.Parent;
local Tool = SyncAPI.Parent;
local FilterModeEnabled = (Tool:WaitForChild 'FilterMode').Value;

-- Enable this endpoint if filter mode is enabled
if FilterModeEnabled then

	-- Start the server-side sync module
	SyncModule = require(SyncAPI:WaitForChild 'SyncModule');

	-- Provide functionality to the server API endpoint instance
	ServerEndpoint.OnServerInvoke = function (Client, ...)
		return SyncModule.PerformAction(Client, ...);
	end;

end;