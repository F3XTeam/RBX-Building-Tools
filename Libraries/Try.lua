-- A library for controlling the flow of error-prone, interdependent functions
-- @readme https://github.com/F3XTeam/RBX-Try-Library/blob/master/README.md

-- Define default Attempt properties
local Attempt = {};
Attempt.RetryCount = 0;
Attempt._IsAttempt = true;
Attempt.__index = Attempt;

-- Return attempt debugging ID when converted to string
function Attempt:__tostring()
	return self.Id:gsub('table', 'Attempt');
end;

-- Result-packaging helper function
local function PackageProtectedCall(...)
	return ..., { select(2, ...) };
end;

local function IsAttempt(Object)
	-- Returns whether given object is an attempt

	-- Get object metatable
	local ObjectMetatable = getmetatable(Object);

	-- Return whether metatable indicates object is an attempt
	return ObjectMetatable and ObjectMetatable._IsAttempt or false;

end;

local function Try(Function, ...)
	-- Creates, starts, and returns a new attempt

	-- Initialize new attempt
	local self = {};
	self.Id = tostring(self);
	setmetatable(self, Attempt);

	-- Run and return attempt for chaining
	return self:Execute(Function, { ... });

end;

function Attempt:Execute(Function, Arguments)
	-- Executes function with given arguments, saves results in attempt

	-- Capture function execution results
	local Success, Results = PackageProtectedCall(pcall(Function, unpack(Arguments)));

	-- Update attempt state with execution information
	self.Function = Function;
	self.Arguments = Arguments;
	self.Success = Success;
	self.Results = Results;

	-- Get stack trace and start list of skipped operations on failure
	if not Success then
		self.Stack = debug.traceback();
		self.Skips = {};
	end;

	-- Return attempt for chaining
	return self;

end;

function Attempt:Then(Callback)
	-- Passes attempt results to callback, and returns attempt for chaining

	-- Enter new attempt context if received
	local FirstArgument = self.Results[1];
	if self.Success and IsAttempt(FirstArgument) then
		self = FirstArgument;
	end;

	-- Skip callback if attempt failed
	if not self.Success then
		self.Skips[#self.Skips + 1] = Callback;
		return self;
	end;

	-- Execute callback with results of last attempt
	self:Execute(Callback, self.Results);

	-- Return attempt for chaining
	return self;

end;

function Attempt:Catch(...)
	-- Passes errors in failed attempt to given callback, returns attempt for chaining

	-- Enter new attempt context if received
	local FirstArgument = self.Results[1];
	if self.Success and IsAttempt(FirstArgument) then
		self = FirstArgument;
	end;

	-- Skip catching if attempt succeeded
	if self.Success or self.Handled then
		return self;
	end;

	-- Get arguments
	local Arguments = { ... };

	-- Get predicate count and callback
	local PredicateCount = #Arguments - 1;
	local Callback = Arguments[PredicateCount + 1];

	-- Track catching operation for future retry attempts
	self.Skips[#self.Skips + 1] = Arguments;

	-- Get attempt error
	local Error = self.Results[1];
	local HandleError = false;

	-- Handle any error if no predicates specified
	if PredicateCount == 0 then
		HandleError = true;

	-- Handle matching error if predicates specified
	elseif type(Error) == 'string' then
		for PredicateId = 1, PredicateCount do
			if Error:match(Arguments[PredicateId]) then
				HandleError = true;
				break;
			end;
		end;
	end;

	-- Attempt passing error to callback, and return attempt on success
	if HandleError then
		return Try(Callback, Error, self.Stack, self):Then(function ()
			self.Handled = true;
			return self;
		end);
	end;

	-- Return attempt for chaining
	return self;

end;

function Attempt:Retry()
	-- Retries attempt from first failure, applies skipped operations, and returns resulting attempt

	-- Skip retrying if attempt succeeded
	if self.Success then
		return;
	end;

	-- Get skips after attempt failure
	local Skips = self.Skips;

	-- Reset attempt for reexecution
	self.Handled = nil;
	self.Skips = nil;
	self.Stack = nil;

	-- Increment retry counter
	self.RetryCount = self.RetryCount + 1;

	-- Retry attempt
	self:Execute(self.Function, self.Arguments);

	-- Reset retry counter if retry succeded
	if self.Success then
		self.RetryCount = nil;
	end;

	-- Apply skipped operations
	for SkipIndex = 1, #Skips do
		local Skip = Skips[SkipIndex];
		local SkipMetatable = getmetatable(Skip);

		-- Apply callables as `then` operations
		if type(Skip) == 'function' or (SkipMetatable and SkipMetatable.__call) then
			self = self:Then(Skip);

		-- Apply non-callables as `catch` operations
		else
			self = self:Catch(unpack(Skip));
		end;
	end;

	-- Return attempt for chaining
	return self;

end;

return Try;