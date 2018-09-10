-- Light-weight, flexible object for cleaning up connections, instances, etc.
-- @author Validark

local FastSpawn = require(script.Parent:WaitForChild 'FastSpawn')

-- Just a reference that can't ever be accessed but will be used as an index for LinkToInstance
local LinkToInstanceIndex = newproxy(false)

local Janitors = setmetatable({}, {__mode = "k"})
local Janitor = {}
Janitor.__index = {CurrentlyCleaning = true}

local TypeDefaults = {
	["function"] = true;
	["RBXScriptConnection"] = "Disconnect";
}

function Janitor.new()
	return setmetatable({CurrentlyCleaning = false}, Janitor)
end

function Janitor.__index:Add(Object, MethodName, Index)
	if Index then
		self:Remove(Index)

		local this = Janitors[self]

		if not this then
			this = {}
			Janitors[self] = this
		end

		this[Index] = Object
	end

	self[Object] = MethodName or TypeDefaults[typeof(Object)] or "Destroy"
	return Object
end

function Janitor.__index:Remove(Index)
	local this = Janitors[self]

	if this then
		local Object = this[Index]

		if Object then
			local MethodName = self[Object]

			if MethodName then
				if MethodName == true then
					Object()
				else
					Object[MethodName](Object)
				end
				self[Object] = nil
			end

			this[Index] = nil
		end
	end
end

function Janitor.__index:Cleanup()
	if not self.CurrentlyCleaning then
		self.CurrentlyCleaning = nil -- A little trick to exclude the Debouncer from the loop below AND set it to true via __index :)

		for Object, MethodName in next, self do
			if MethodName == true then
				Object()
			else
				Object[MethodName](Object)
			end
			self[Object] = nil
		end

		local this = Janitors[self]

		if this then
			for Index in next, this do
				this[Index] = nil
			end
			Janitors[self] = nil
		end

		self.CurrentlyCleaning = false
	end
end

function Janitor.__index:Destroy()
	self:Cleanup()
	setmetatable(self, nil)
end

Janitor.__call = Janitor.__index.Cleanup

--- Makes the Janitor clean up when the instance is destroyed
-- @param Instance Instance The Instance the Janitor will wait for to be Destroyed
-- @returns Disconnectable table to stop Janitor from being cleaned up upon Instance Destroy (automatically cleaned up by Janitor, btw)
-- @author Corecii

local Disconnect = {Connected = true}
Disconnect.__index = Disconnect
function Disconnect:Disconnect()
	self.Connected = false
	self.Connection:Disconnect()
end

function Janitor.__index:LinkToInstance(Object, AllowMultiple)
	local Reference = Instance.new("ObjectValue")
	Reference.Value = Object
	-- ObjectValues have weak-like Instance references
	-- If the Instance can no longer be accessed then it can be collected despite
	--  the ObjectValue having a reference to it
	local ManualDisconnect = setmetatable({}, Disconnect)
	local Connection
	local function ChangedFunction(Obj, Par)
		if not Reference.Value then
			ManualDisconnect.Connected = false
			return self:Cleanup()
		elseif Obj == Reference.Value and not Par then
			Obj = nil
			wait()  -- Push further execution of this script to the end of the current execution cycle
					  --  This is needed because when the event first runs it's always still Connected
			-- The object may have been reparented or the event manually disconnected or disconnected and ran in that time...
			if (not Reference.Value or not Reference.Value.Parent) and ManualDisconnect.Connected then
				if not Connection.Connected then
					ManualDisconnect.Connected = false
					return self:Cleanup()
				else
					-- Since this event won't fire if the instance is destroyed while in nil, we have to check
					--  often to make sure it's not destroyed. Once it's parented outside of nil we can stop doing
					--  this. We also must check to make sure it wasn't manually disconnected or disconnected and ran.
					while wait(0.2) do
						if not ManualDisconnect.Connected then
							-- Don't run func, we were disconnected manually
							return
						elseif not Connection.Connected then
							-- Otherwise, if we're disconnected it's because instance was destroyed
							ManualDisconnect.Connected = false
							return self:Cleanup()
						elseif Reference.Value.Parent then
							-- If it's still Connected then it's not destroyed. If it has a parent then
							--  we can quit checking if it's destroyed like this.
							return
						end
					end
				end
			end
		end
	end
	Connection = Object.AncestryChanged:Connect(ChangedFunction)
	ManualDisconnect.Connection = Connection
	Object = nil
	-- If the object is currently in nil then we need to start our destroy checking loop
	-- We need to spawn a new Roblox Lua thread right now before any other code runs.
	--  spawn() starts it on the next cycle or frame, coroutines don't have ROBLOX's coroutine.yield handler
	--  The only option left is BindableEvents, which run as soon as they are called and use ROBLOX's yield
	FastSpawn(ChangedFunction, Reference.Value, Reference.Value.Parent)

	if AllowMultiple then -- Give Task to Janitor, cleanup this Connection upon cleanup
		self:Add(ManualDisconnect, "Disconnect")
	else
		self:Add(ManualDisconnect, "Disconnect", LinkToInstanceIndex)
	end

	return ManualDisconnect
end

return Janitor