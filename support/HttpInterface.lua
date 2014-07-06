-- Provides an interface for the client-side code to use HttpService

local HttpService			= Game:GetService( 'HttpService' );
local HttpInterface			= script.Parent;

HttpInterface.GetAsync.OnServerInvoke = function ( Player, Url, NoCache )
	local Results = {};
	ypcall( function ()
		Results = { HttpService:GetAsync( Url, NoCache ) };
	end );
	return unpack( Results );
end;

HttpInterface.PostAsync.OnServerInvoke = function ( Player, Url, Data, ContentType )
	local Results = {};
	ypcall( function ()
		Results = { HttpService:PostAsync( Url, Data, ContentType ) };
	end );
	return unpack( Results );
end;

HttpInterface.Test.OnServerInvoke = function ( Player )
	-- Returns the status of a test request through HttpService

	local RequestSuccess, RequestOutput = ypcall( function ()
		HttpService:GetAsync 'http://www.google.com';
	end );

	return RequestSuccess, RequestOutput;
end