-- Connection-based Events via wrapped BindableEvents
-- @author Validark
-- @original https://gist.github.com/Anaminus/afd813efc819bad8e560caea28942010

-- These hold references to metatables for after we lock __metatable to a string
local Signals = setmetatable({}, {__mode = "kv"})
local PseudoConnections = setmetatable({}, {__mode = "kv"})

local Event = {}

function Event:Connect(Function, Arg)
	return Signals[self]:Connect(Function, Arg)
end

function Event:Wait()
	return Signals[self]:Wait()
end

local Signal = {
	__index = {
		NextId = 0; -- Holds the next Arguments ID
		YieldingThreads = 0; -- Number of Threads waiting on the signal
	}
}

local function GetArguments(self, Id)
	local Arguments = self.Arguments[Id]
	local ThreadsRemaining = Arguments.NumConnectionsAndThreads - 1

	if ThreadsRemaining == 0 then
		self.Arguments[Id] = nil
	else
		Arguments.NumConnectionsAndThreads = ThreadsRemaining
	end

	return unpack(Arguments, 1, Arguments.n)
end

local function Destruct(self)
	local ConstructorData = self.ConstructorData
	if self.Destructor and ConstructorData then
		self:Destructor(unpack(ConstructorData, 1, ConstructorData.n))
		self.ConstructorData = nil
	end
end

local function pack(...) -- This is useful because trailing nil's on the stack may be preserved
	return {n = select("#", ...), ...}
end

local function Disconnect(self)
	self = PseudoConnections[self]

	if self.Connection then
		self.Connection:Disconnect()
		self.Connection = nil
	end

	local Signal = self.Signal

	if Signal then
		self.Connected = false
		local Connections = Signal.Connections
		local NumConnections = #Connections

		for i = 1, NumConnections do
			if Connections[i] == self then
				table.remove(Connections, i)
				break
			end
		end

		if NumConnections == 0 then
			Destruct(Signal)
		end
		self.Signal = nil
	end
end

local function PseudoConnection__index(self, i)
	if i == "Disconnect" then
		return Disconnect
	elseif i == "Connected" then
		return PseudoConnections[self].Connected
	else
		BadIndex(self, i, "RBXScriptConnection")
	end
end

local function RBXScriptConnectionToString()
	return "RBXScriptConnection"
end

local function RBXScriptSignalToString()
	return "RBXScriptSignal"
end

function Signal.new(Constructor, Destructor)
	local self = setmetatable({
		Bindable = Instance.new("BindableEvent"); -- Dispatches scheduler-compatible Threads
		Arguments = {}; -- Holds arguments for pending listener functions and Threads: [Id] = {#Connections + YieldingThreads, arguments}
		Connections = {}; -- SignalConnections connected to the signal
		Constructor = Constructor; -- Constructor function
		Destructor = Destructor; -- Destructor function
		Event = newproxy(true); -- Event interface which can only access Connect() and Wait()
	}, Signal)

	local EventMt = getmetatable(self.Event)
	EventMt.__index = Event
	EventMt.__metatable = "The metatable is locked"
	EventMt.__type = "RBXScriptSignal"
	EventMt.__tostring = RBXScriptSignalToString
	Signals[self.Event] = self

	return self
end

function Signal.__index:Connect(Function, Arg)
	local NumConnections = #self.Connections

	if NumConnections == 0 and self.Constructor and not self.ConstructorData then
		self.ConstructorData = pack(self:Constructor())
	end

	local Connection = newproxy(true)
	local ConnectionMt = getmetatable(Connection)
	ConnectionMt.Connected = true
	ConnectionMt.__metatable = "The metatable is locked"
	ConnectionMt.__type = "RBXScriptConnection"
	ConnectionMt.__tostring = RBXScriptConnectionToString
	ConnectionMt.__index = PseudoConnection__index
	ConnectionMt.Signal = self
	ConnectionMt.Connection = self.Bindable.Event:Connect(function(Id)
		if Arg then
			Function(Arg, GetArguments(self, Id))
		else
			Function(GetArguments(self, Id))
		end
	end)

	PseudoConnections[Connection] = ConnectionMt
	self.Connections[NumConnections + 1] = ConnectionMt
	return Connection
end

function Signal.__index:Fire(...)
	local Id = self.NextId
	local Stack = pack(...)
	local NumConnectionsAndThreads = #self.Connections + self.YieldingThreads

	Stack.NumConnectionsAndThreads = NumConnectionsAndThreads

	self.NextId = Id + 1
	self.Arguments[Id] = Stack
	self.YieldingThreads = nil

	if NumConnectionsAndThreads > 0 then
		self.Bindable:Fire(Id)
	end
end

function Signal.__index:Wait()
	self.YieldingThreads = self.YieldingThreads + 1
	return GetArguments(self, self.Bindable.Event:Wait())
end

function Signal.__index:Destroy()
	Destruct(self)

	self.Bindable = self.Bindable:Destroy()
	local Connections = self.Connections

	for i = #Connections, 1, -1 do
		local Connection = Connections[i]
		Connection.Connected = false
		Connection.Signal = nil
		Connection.Connection = nil
		Connections[i] = nil
	end

	self.YieldingThreads = nil
	self.Arguments = nil
	self.Connections = nil
	setmetatable(self, nil)
end

return Signal