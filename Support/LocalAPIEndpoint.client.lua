local SyncAPI = script.Parent;
local Tool = SyncAPI.Parent;
local ServerEndpoint = SyncAPI:WaitForChild 'ServerEndpoint';
local RunService = game:GetService 'RunService'

-- Provide functionality to the local API endpoint instance
SyncAPI.OnInvoke = function (...)

	-- Route requests to server endpoint if in filter mode
	if not RunService:IsServer() then
		return ServerEndpoint:InvokeServer(...)

	-- Perform requests locally if working locally
	else
		SyncModule = require(SyncAPI:WaitForChild 'SyncModule')
		return SyncModule.PerformAction(game.Players.LocalPlayer, ...)
	end;

end;