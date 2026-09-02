SupportLibrary = {};

function SupportLibrary.FindTableOccurrence(Haystack, Needle)
	-- Returns one occurrence of `Needle` in `Haystack`
	return table.find(Haystack, Needle)
end;

function SupportLibrary.IsInTable(Haystack, Needle)
	-- Returns whether the given `Needle` can be found within table `Haystack`
	return table.find(Haystack, Needle) ~= nil
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

function SupportLibrary.Merge(Target, ...)
	-- Copies members of the given tables into the specified target table

	local Tables = { ... }

	-- Copy members from each table into target
	for TableOrder, Table in ipairs(Tables) do
		for Key, Value in pairs(Table) do
			Target[Key] = Value
		end
	end

	-- Return target
	return Target
end

-- Create symbol representing a blank value
local Blank = newproxy(true)
SupportLibrary.Blank = Blank
getmetatable(Blank).__tostring = function ()
	return 'Symbol(Blank)'
end

function SupportLibrary.MergeWithBlanks(Target, ...)
	-- Copies members of the given tables into the specified target table, including blank values

	local Tables = { ... }

	-- Copy members from each table into target
	for TableOrder, Table in ipairs(Tables) do
		for Key, Value in pairs(Table) do
			if Value == Blank then
				Target[Key] = nil
			else
				Target[Key] = Value
			end
		end
	end

	-- Return target
	return Target
end

function SupportLibrary.GetDescendantsWhichAreA(Object, Class)
	-- Returns descendants of `Object` which match `Class`
	return Object:QueryDescendants(Class)
end

function SupportLibrary.GetChildOfClass(Parent, ClassName, Inherit)
	-- Returns the first child of `Parent` that is of class `ClassName`
	-- or nil if it couldn't find any

	-- Look for a child of `Parent` of class `ClassName` and return it
	if not Inherit then
		return Parent:FindFirstChildOfClass(ClassName)
	else
		return Parent:FindFirstChildWhichIsA(ClassName)
	end;
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

-- Make references to functions called a lot for efficiency
local Insert = table.insert;
local NewCFrame = CFrame.new;
local ToWorldSpace = NewCFrame().ToWorldSpace;

function SupportLibrary.GetPartCorners(Part)
	-- Returns a table of the given part's corners' CFrames

	-- Get info about the part
	local PartCFrame = Part.CFrame;
	local SizeX, SizeY, SizeZ = Part.Size.X / 2, Part.Size.Y / 2, Part.Size.Z / 2;

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

function SupportLibrary.GetListMembers(List, MemberName)
	-- Gets the given member for each object in the given list table

	local Members = {}

	-- Collect the member values for each item in the list
	for Key, Item in ipairs(List) do
		Members[Key] = Item[MemberName]
	end

	-- Return the members
	return Members

end

function SupportLibrary.GetMemberMap(List, MemberName)
	-- Maps the given items' specified members to each item

	local Map = {}

	-- Collect member values
	for Key, Item in ipairs(List) do
		Map[Item] = Item[MemberName]
	end

	-- Return map
	return Map

end

function SupportLibrary.AddUserInputListener(InputState, InputTypeFilter, CatchAll, Callback)
	-- Connects to the given user input event and takes care of standard boilerplate code

	-- Create input type whitelist
	local InputTypes = {}
	if type(InputTypeFilter) == 'string' then
		InputTypes[InputTypeFilter] = true
	elseif type(InputTypeFilter) == 'table' then
		InputTypes = SupportLibrary.FlipTable(InputTypeFilter)
	end

	-- Create a UserInputService listener based on the given `InputState`
	return game:GetService('UserInputService')['Input' .. InputState]:Connect(function (Input, GameProcessedEvent)

		-- Make sure this input was not captured by the client (unless `CatchAll` is enabled)
		if GameProcessedEvent and not CatchAll then
			return;
		end;


		-- Make sure this is the right input type
		if not InputTypes[Input.UserInputType.Name] then
			return;
		end;

		-- Make sure any key input did not occur while typing into a UI
		if Input.UserInputType == Enum.UserInputType.Keyboard and game:GetService('UserInputService'):GetFocusedTextBox() then
			return;
		end;

		-- Call back upon passing all conditions
		Callback(Input);

	end);

end;

function SupportLibrary.ConcatTable(TargetTable, ...)
	-- Inserts all values from given source tables into target

	local SourceTables = { ... }

	-- Insert values from each source table into target
	for TableOrder, SourceTable in ipairs(SourceTables) do
		for Key, Value in ipairs(SourceTable) do
			table.insert(TargetTable, Value)
		end
	end

	-- Return the destination table
	return TargetTable
end

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
	local Args = { ... }
	return function (...)
		return Function(unpack(
			SupportLibrary.ConcatTable({}, Args, { ... })
			))
	end
end

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

function SupportLibrary.Loop(Interval, Function, ...)
	-- Calls the given function repeatedly at the specified interval until stopped

	local Args = { ... }

	-- Create state
	local Running = true
	local Stop = function ()
		Running = nil
	end

	-- Start loop
	coroutine.wrap(function ()
		while wait(Interval) and Running do
			Function(unpack(Args))
		end
	end)()

	-- Return stopping callback
	return Stop
end

function SupportLibrary.CreateConsecutiveCallDeferrer(MaxInterval)
	-- Returns a callback for determining whether to execute consecutive calls

	local LastCallTime
	local function ShouldExecuteCall()

		-- Mark latest call time
		local CallTime = tick()
		LastCallTime = CallTime

		-- Indicate whether call still latest
		wait(MaxInterval)
		return LastCallTime == CallTime

	end

	-- Return callback
	return ShouldExecuteCall

end

return SupportLibrary;
