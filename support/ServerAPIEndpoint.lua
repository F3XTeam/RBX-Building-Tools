local ServerEndpoint = script.Parent;
local SyncAPI = ServerEndpoint.Parent;
local Tool = SyncAPI.Parent;

-- Enable this endpoint if filtering is enabled
if Workspace.FilteringEnabled then

	-- Start the server-side sync module
	SyncModule = require(SyncAPI:WaitForChild 'SyncModule');

	-- Provide functionality to the server API endpoint instance
	ServerEndpoint.OnServerInvoke = function (Client, ...)
		return SyncModule.PerformAction(Client, ...);
	end;

end;