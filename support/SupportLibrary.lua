SupportLibrary = {};

function SupportLibrary.FindTableOccurrences(Haystack, Needle)
	-- Returns the positions of instances of `needle` in table `haystack`

	local Positions = {};

	-- Add any indexes from `Haystack` that are `Needle`
	for Index, Value in pairs(Haystack) do
		if Value == Needle then
			table.insert(Positions, Index);
		end;
	end;

	return Positions;
end;

function SupportLibrary.FindTableOccurrence(Haystack, Needle)
	-- Returns one occurrence of `Needle` in `Haystack`

	-- Search for the first instance of `Needle` found and return it
	for Index, Value in pairs(Haystack) do
		if Value == Needle then
			return Index;
		end;
	end;

	-- If no occurrences exist, return `nil`
	return nil;

end;

function SupportLibrary.IsInTable(Haystack, Needle)
	-- Returns whether the given `Needle` can be found within table `Haystack`

	-- Go through every value in `Haystack` and return whether `Needle` is found
	for _, Value in pairs(Haystack) do
		if Value == Needle then
			return true;
		end;
	end;

	-- If no instances were found, return false
	return false;
end;

function SupportLibrary.DoTablesMatch(A, B)
	-- Returns whether the values of tables A and B are the same

	-- Check B table differences
	for Index in pairs(A) do
		if A[Index] ~= B[Index] then
			return false;
		end;
	end;

	-- Check A table differences
	for Index in pairs(B) do
		if B[Index] ~= A[Index] then
			return false;
		end;
	end;

	-- Return true if no differences
	return true;
end;

function SupportLibrary.Round(Number, Places)
	-- Returns `Number` rounded to the given number of decimal places (from lua-users)

	-- Ensure that `Number` is a number
	if type(Number) ~= 'number' then
		return;
	end;

	-- Round the number
	local Multiplier = 10 ^ (Places or 0);
	local RoundedNumber = math.floor(Number * Multiplier + 0.5) / Multiplier;

	-- Return the rounded number
	return RoundedNumber;
end;

function SupportLibrary.CloneTable(Table)
	-- Returns a copy of `Table`

	local ClonedTable = {};

	-- Copy all values into `ClonedTable`
	for Key, Value in pairs(Table) do
		ClonedTable[Key] = Value;
	end;

	-- Return the clone
	return ClonedTable;
end;

function SupportLibrary.GetAllDescendants(Parent)
	-- Recursively gets all the descendants of `Parent` and returns them

	local Descendants = {};

	for _, Child in pairs(Parent:GetChildren()) do

		-- Add the direct descendants of `Parent`
		table.insert(Descendants, Child);

		-- Add the descendants of each child
		for _, Subchild in pairs(SupportLibrary.GetAllDescendants(Child)) do
			table.insert(Descendants, Subchild);
		end;

	end;

	return Descendants;
end;

function SupportLibrary.GetDescendantCount(Parent)
	-- Recursively gets a count of all the descendants of `Parent` and returns them

	local Count = 0;

	for _, Child in pairs(Parent:GetChildren()) do

		-- Count the direct descendants of `Parent`
		Count = Count + 1;

		-- Count and add the descendants of each child
		Count = Count + SupportLibrary.GetDescendantCount(Child);

	end;

	return Count;
end;

function SupportLibrary.CloneParts(Parts)
	-- Returns a table of cloned `Parts`

	local Clones = {};

	-- Copy the parts into `Clones`
	for Index, Part in pairs(Parts) do
		Clones[Index] = Part:Clone();
	end;

	return Clones;
end;

function SupportLibrary.SplitString(String, Delimiter)
	-- Returns a table of string `String` split by pattern `Delimiter`

	local StringParts = {};
	local Pattern = ('([^%s]+)'):format(Delimiter);

	-- Capture each separated part
	String:gsub(Pattern, function (Part)
		table.insert(StringParts, Part);
	end);

	return StringParts;
end;

function SupportLibrary.GetChildOfClass(Parent, ClassName, Inherit)
	-- Returns the first child of `Parent` that is of class `ClassName`
	-- or nil if it couldn't find any

	-- Look for a child of `Parent` of class `ClassName` and return it
	if not Inherit then
		for _, Child in pairs(Parent:GetChildren()) do
			if Child.ClassName == ClassName then
				return Child;
			end;
		end;
	else
		for _, Child in pairs(Parent:GetChildren()) do
			if Child:IsA(ClassName) then
				return Child;
			end;
		end;
	end;

	return nil;
end;

function SupportLibrary.GetChildrenOfClass(Parent, ClassName, Inherit)
	-- Returns a table containing the children of `Parent` that are
	-- of class `ClassName`

	local Matches = {};

	if not Inherit then
		for _, Child in pairs(Parent:GetChildren()) do
			if Child.ClassName == ClassName then
				table.insert(Matches, Child);
			end;
		end;
	else
		for _, Child in pairs(Parent:GetChildren()) do
			if Child:IsA(ClassName) then
				table.insert(Matches, Child);
			end;
		end;
	end;

	return Matches;
end;

function SupportLibrary.HSVToRGB(Hue, Saturation, Value)
	-- Returns the RGB equivalent of the given HSV-defined color
	-- (adapted from some code found around the web)

	-- If it's achromatic, just return the value
	if Saturation == 0 then
		return Value;
	end;

	-- Get the hue sector
	local HueSector = math.floor(Hue / 60);
	local HueSectorOffset = (Hue / 60) - HueSector;

	local P = Value * (1 - Saturation);
	local Q = Value * (1 - Saturation * HueSectorOffset);
	local T = Value * (1 - Saturation * (1 - HueSectorOffset));

	if HueSector == 0 then
		return Value, T, P;
	elseif HueSector == 1 then
		return Q, Value, P;
	elseif HueSector == 2 then
		return P, Value, T;
	elseif HueSector == 3 then
		return P, Q, Value;
	elseif HueSector == 4 then
		return T, P, Value;
	elseif HueSector == 5 then
		return Value, P, Q;
	end;
end;

function SupportLibrary.RGBToHSV(Red, Green, Blue)
	-- Returns the HSV equivalent of the given RGB-defined color
	-- (adapted from some code found around the web)

	local Hue, Saturation, Value;

	local MinValue = math.min(Red, Green, Blue);
	local MaxValue = math.max(Red, Green, Blue);

	Value = MaxValue;

	local ValueDelta = MaxValue - MinValue;

	-- If the color is not black
	if MaxValue ~= 0 then
		Saturation = ValueDelta / MaxValue;

	-- If the color is purely black
	else
		Saturation = 0;
		Hue = -1;
		return Hue, Saturation, Value;
	end;

	if Red == MaxValue then
		Hue = (Green - Blue) / ValueDelta;
	elseif Green == MaxValue then
		Hue = 2 + (Blue - Red) / ValueDelta;
	else
		Hue = 4 + (Red - Green) / ValueDelta;
	end;

	Hue = Hue * 60;
	if Hue < 0 then
		Hue = Hue + 360;
	end;

	return Hue, Saturation, Value;
end;

function SupportLibrary.IdentifyCommonItem(Items)
	-- Returns the common item in table `Items`, or `nil` if
	-- they vary

	local CommonItem = nil;

	for ItemIndex, Item in pairs(Items) do

		-- Set the initial item to compare against
		if ItemIndex == 1 then
			CommonItem = Item;

		-- Check if this item is the same as the rest
		else
			-- If it isn't the same, there is no common item, so just stop right here
			if Item ~= CommonItem then
				return nil;
			end;
		end;

	end;

	-- Return the common item
	return CommonItem;
end;

function SupportLibrary.IdentifyCommonProperty(Items, Property)
	-- Returns the common `Property` value in the instances given in `Items`

	local PropertyVariations = {};

	-- Capture all the variations of the property value
	for _, Item in pairs(Items) do
		table.insert(PropertyVariations, Item[Property]);
	end;

	-- Return the common property value
	return SupportLibrary.IdentifyCommonItem(PropertyVariations);

end;

function SupportLibrary.CreateSignal()
	-- Returns a ROBLOX-like signal for connections (RbxUtility's is buggy)

	local Signal = {
		Connections	= {};

		-- Provide a function to connect an event handler
		Connect = function (Signal, Handler)

			-- Register the handler
			table.insert(Signal.Connections, Handler);

			-- Return a controller for this connection
			local ConnectionController = {

				-- Include a reference to the connection's handler
				Handler = Handler;

				-- Provide a way to disconnect this connection
				Disconnect = function (Connection)
					local ConnectionSearch = SupportLibrary.FindTableOccurrences(Signal.Connections, Connection.Handler);
					if #ConnectionSearch > 0 then
						local ConnectionIndex = ConnectionSearch[1];
						table.remove(Signal.Connections, ConnectionIndex);
					end;
				end;

			};

			-- Add compatibility aliases
			ConnectionController.disconnect = ConnectionController.Disconnect;

			-- Return the connection's controller
			return ConnectionController;

		end;

		-- Provide a function to trigger any connections' handlers
		Fire = function (Signal, ...)
			for _, Connection in pairs(Signal.Connections) do
				Connection(...);
			end;
		end;
	};

	-- Add compatibility aliases
	Signal.connect	= Signal.Connect;
	Signal.fire		= Signal.Fire;

	return Signal;
end;

function SupportLibrary.GetPartCorners(Part)
	-- Returns a table of the given part's corners' CFrames

	-- Make references to functions called a lot for efficiency
	local Insert = table.insert;
	local ToWorldSpace = CFrame.new().toWorldSpace;
	local NewCFrame = CFrame.new;

	-- Get info about the part
	local PartCFrame = Part.CFrame;
	local SizeX, SizeY, SizeZ = Part.Size.x / 2, Part.Size.y / 2, Part.Size.z / 2;

	-- Get each corner
	local Corners = {};
	Insert(Corners, ToWorldSpace(PartCFrame, NewCFrame(SizeX, SizeY, SizeZ)));
	Insert(Corners, ToWorldSpace(PartCFrame, NewCFrame(-SizeX, SizeY, SizeZ)));
	Insert(Corners, ToWorldSpace(PartCFrame, NewCFrame(SizeX, -SizeY, SizeZ)));
	Insert(Corners, ToWorldSpace(PartCFrame, NewCFrame(SizeX, SizeY, -SizeZ)));
	Insert(Corners, ToWorldSpace(PartCFrame, NewCFrame(-SizeX, SizeY, -SizeZ)));
	Insert(Corners, ToWorldSpace(PartCFrame, NewCFrame(-SizeX, -SizeY, SizeZ)));
	Insert(Corners, ToWorldSpace(PartCFrame, NewCFrame(SizeX, -SizeY, -SizeZ)));
	Insert(Corners, ToWorldSpace(PartCFrame, NewCFrame(-SizeX, -SizeY, -SizeZ)));

	return Corners;
end;

function SupportLibrary.CreatePart(PartType)
	-- Creates and returns new part based on `PartType` with sensible defaults

	local NewPart;

	if PartType == 'Normal' then
		NewPart = Instance.new('Part');
		NewPart.Size = Vector3.new(4, 1, 2);

	elseif PartType == 'Truss' then
		NewPart = Instance.new('TrussPart');

	elseif PartType == 'Wedge' then
		NewPart = Instance.new('WedgePart');
		NewPart.Size = Vector3.new(4, 1, 2);

	elseif PartType == 'Corner' then
		NewPart = Instance.new('CornerWedgePart');

	elseif PartType == 'Cylinder' then
		NewPart = Instance.new('Part');
		NewPart.Shape = 'Cylinder';
		NewPart.TopSurface = Enum.SurfaceType.Smooth;
		NewPart.BottomSurface = Enum.SurfaceType.Smooth;
		NewPart.Size = Vector3.new(2, 2, 2);

	elseif PartType == 'Ball' then
		NewPart = Instance.new('Part');
		NewPart.Shape = 'Ball';
		NewPart.TopSurface = Enum.SurfaceType.Smooth;
		NewPart.BottomSurface = Enum.SurfaceType.Smooth;

	elseif PartType == 'Seat' then
		NewPart = Instance.new('Seat');
		NewPart.Size = Vector3.new(4, 1, 2);

	elseif PartType == 'Vehicle Seat' then
		NewPart = Instance.new('VehicleSeat');
		NewPart.Size = Vector3.new(4, 1, 2);

	elseif PartType == 'Spawn' then
		NewPart = Instance.new('SpawnLocation');
		NewPart.Size = Vector3.new(4, 1, 2);
	end;
	
	-- Make sure the part is anchored
	NewPart.Anchored = true;

	return NewPart;
end;

function SupportLibrary.ImportServices()
	-- Adds references to common services into the calling environment

	-- Get the calling environment
	local CallingEnvironment = getfenv(2);

	-- Add the services
	CallingEnvironment.Workspace = Game:GetService 'Workspace';
	CallingEnvironment.Players = Game:GetService 'Players';
	CallingEnvironment.MarketplaceService = Game:GetService 'MarketplaceService';
	CallingEnvironment.ContentProvider = Game:GetService 'ContentProvider';
	CallingEnvironment.SoundService = Game:GetService 'SoundService';
	CallingEnvironment.UserInputService = Game:GetService 'UserInputService';
	CallingEnvironment.SelectionService = Game:GetService 'Selection';
	CallingEnvironment.CoreGui = Game:GetService 'CoreGui';
	CallingEnvironment.HttpService = Game:GetService 'HttpService';
	CallingEnvironment.ChangeHistoryService = Game:GetService 'ChangeHistoryService';
	CallingEnvironment.ReplicatedStorage = Game:GetService 'ReplicatedStorage';
	CallingEnvironment.GroupService = Game:GetService 'GroupService';
	CallingEnvironment.ServerScriptService = Game:GetService 'ServerScriptService';
	CallingEnvironment.StarterGui = Game:GetService 'StarterGui';
	CallingEnvironment.RunService = Game:GetService 'RunService';
end;

function SupportLibrary.GetListMembers(List, MemberName)
	-- Gets the given member for each object in the given list table

	local Members = {};

	-- Collect the member values for each item in the list
	for _, Item in pairs(List) do
		table.insert(Members, Item[MemberName]);
	end;

	-- Return the members
	return Members;

end;

function SupportLibrary.AddUserInputListener(InputState, InputType, CatchAll, Callback)
	-- Connects to the given user input event and takes care of standard boilerplate code

	-- Turn the given `InputType` string into a proper enum
	local InputType = Enum.UserInputType[InputType];

	-- Create a UserInputService listener based on the given `InputState`
	return Game:GetService('UserInputService')['Input' .. InputState]:connect(function (Input, GameProcessedEvent)

		-- Make sure this input was not captured by the client (unless `CatchAll` is enabled)
		if GameProcessedEvent and not CatchAll then
			return;
		end;

		-- Make sure this is the right input type
		if Input.UserInputType ~= InputType then
			return;
		end;

		-- Make sure any key input did not occur while typing into a UI
		if InputType == Enum.UserInputType.Keyboard and Game:GetService('UserInputService'):GetFocusedTextBox() then
			return;
		end;

		-- Call back upon passing all conditions
		Callback(Input);

	end);

end;

function SupportLibrary.AddGuiInputListener(Gui, InputState, InputType, CatchAll, Callback)
	-- Connects to the given GUI user input event and takes care of standard boilerplate code

	-- Turn the given `InputType` string into a proper enum
	local InputType = Enum.UserInputType[InputType];

	-- Create a UserInputService listener based on the given `InputState`
	return Gui['Input' .. InputState]:connect(function (Input, GameProcessedEvent)

		-- Make sure this input was not captured by the client (unless `CatchAll` is enabled)
		if GameProcessedEvent and not CatchAll then
			return;
		end;

		-- Make sure this is the right input type
		if Input.UserInputType ~= InputType then
			return;
		end;

		-- Call back upon passing all conditions
		Callback(Input);

	end);

end;

function SupportLibrary.AreKeysPressed(...)
	-- Returns whether the given keys are pressed

	local RequestedKeysPressed = 0;

	-- Get currently pressed keys
	local PressedKeys = SupportLibrary.GetListMembers(Game:GetService('UserInputService'):GetKeysPressed(), 'KeyCode');

	-- Go through each requested key
	for _, Key in pairs({ ... }) do

		-- Count requested keys that are pressed
		if SupportLibrary.IsInTable(PressedKeys, Key) then
			RequestedKeysPressed = RequestedKeysPressed + 1;
		end;

	end;

	-- Return whether all the requested keys are pressed or not
	return RequestedKeysPressed == #{...};

end;

function SupportLibrary.ConcatTable(DestinationTable, SourceTable)
	-- Inserts all values of SourceTable into DestinationTable

	-- Add each value from `SourceTable` into `DestinationTable`
	for _, Value in pairs(SourceTable) do
		table.insert(DestinationTable, Value);
	end;

	-- Return the destination table
	return DestinationTable;
end;

function SupportLibrary.ClearTable(Table)
	-- Clears out every value in `Table`

	-- Clear each index
	for Index in pairs(Table) do
		Table[Index] = nil;
	end;

	-- Return the given table
	return Table;
end;

function SupportLibrary.Values(Table)
	-- Returns all the values in the given table

	local Values = {};

	-- Go through each key and get each value
	for _, Value in pairs(Table) do
		table.insert(Values, Value);
	end;

	-- Return the values
	return Values;
end;

function SupportLibrary.Keys(Table)
	-- Returns all the keys in the given table

	local Keys = {};

	-- Go through each key and get each value
	for Key in pairs(Table) do
		table.insert(Keys, Key);
	end;

	-- Return the values
	return Keys;
end;

function SupportLibrary.Call(Function, ...)
	-- Returns a callback to `Function` with the given arguments
	local Args = { ... };
	return function (...)
		Function(unpack(
			SupportLibrary.ConcatTable(SupportLibrary.CloneTable(Args), { ... })
		));
	end;
end;

function SupportLibrary.Trim(String)
	-- Returns a trimmed version of `String` (adapted from code from lua-users)
	return (String:gsub("^%s*(.-)%s*$", "%1"));
end

function SupportLibrary.ChainCall(...)
	-- Returns function that passes arguments through given functions and returns the final result

	-- Get the given chain of functions
	local Chain = { ... };

	-- Return the chaining function
	return function (...)

		-- Get arguments
		local Arguments = { ... };

		-- Go through each function and store the returned data to reuse in the next function's arguments 
		for _, Function in ipairs(Chain) do
			Arguments = { Function(unpack(Arguments)) };
		end;

		-- Return the final returned data
		return unpack(Arguments);

	end;

end;

function SupportLibrary.CountKeys(Table)
	-- Returns the number of keys in `Table`

	local Count = 0;

	-- Count each key
	for _ in pairs(Table) do
		Count = Count + 1;
	end;

	-- Return the count
	return Count;

end;

function SupportLibrary.Slice(Table, Start, End)
	-- Returns values from `Start` to `End` in `Table`

	local Slice = {};

	-- Go through the given indices
	for Index = Start, End do
		table.insert(Slice, Table[Index]);
	end;

	-- Return the slice
	return Slice;

end;

function SupportLibrary.FlipTable(Table)
	-- Returns a table with keys and values in `Table` swapped

	local FlippedTable = {};

	-- Flip each key and value
	for Key, Value in pairs(Table) do
		FlippedTable[Value] = Key;
	end;

	-- Return the flipped table
	return FlippedTable;

end;

function SupportLibrary.ScheduleRecurringTask(TaskFunction, Interval)
	-- Repeats `Task` every `Interval` seconds until stopped

	-- Create a task object
	local Task = {

		-- A switch determining if it's running or not
		Running = true;

		-- A function to stop this task
		Stop = function (Task)
			Task.Running = false;
		end;

		-- References to the task function and set interval
		TaskFunction = TaskFunction;
		Interval = Interval;

	};

	coroutine.wrap(function (Task)

		-- Repeat the task
		while wait(Task.Interval) and Task.Running do
			Task.TaskFunction();
		end;

	end)(Task);

	-- Return the task object
	return Task;

end;

function SupportLibrary.Clamp(Number, Minimum, Maximum)
	-- Returns the given number, clamped according to the provided min/max

	-- Clamp the number
	if Minimum and Number < Minimum then
		Number = Minimum;
	elseif Maximum and Number > Maximum then
		Number = Maximum;
	end;

	-- Return the clamped number
	return Number;

end;

return SupportLibrary;