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

function SupportLibrary.Round(Number, Places)
	-- Returns `Number` rounded to the number of decimal `Places`
	-- (from lua-users)

	local Multiplied = 10 ^ (Places or 0);

	return math.floor(Number * Multiplied + 0.5) / Multiplied;
end;

function SupportLibrary.CloneTable(Source)
	-- Returns a deep copy of table `source`

	-- Get a copy of `source`'s metatable, since the hacky method
	-- we're using to copy the table doesn't include its metatable
	local SourceMetatable = getmetatable(Source);

	-- Return a copy of `source` including its metatable
	return setmetatable({ unpack(Source) }, SourceMetatable);
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

return SupportLibrary;