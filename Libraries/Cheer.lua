local Support = require(script.Parent:WaitForChild 'SupportLibrary')
local Signal = require(script.Parent:WaitForChild 'Signal')

local Cheer = {};

function Cheer.WaitFor(View)
	-- Waits until the given view fully loads

	-- Get the component's total descendant count
	local TotalCount = (View:WaitForChild 'CheerDescendantCount').Value;

	-- Check if the loaded descendant count matches the total
	if Support.GetDescendantCount(View) >= TotalCount then
		return View;
	end;

	-- Wait for the loaded descendant count to reach its total
	while Support.GetDescendantCount(View) ~= TotalCount do
		wait(0.1);
	end;

	-- Return the component
	return View;

end;

function Cheer.LoadComponent(View)

	-- Execute ModuleScript-based components
	local ComponentModule = View:FindFirstChild '[Component]';
	if ComponentModule and ComponentModule.ClassName == 'ModuleScript' then
		require(ComponentModule);
	end;

	-- Get components list
	local Components = Cheer.GetCheerData().Components;

	-- Wait for component to register
	while not Components[View] do
		Cheer.GetCheerData().ComponentRegistered:Wait();
	end;

	-- Wait for component to be ready
	local Component = Components[View];
	while not Component.Ready do
		wait(0.1);
	end;

	-- Return the view's component
	return Components[View];

end;

function Cheer.FromTemplate(View, Parent)

	-- Clone and parent the component view
	local Component = View:Clone();
	Component.Parent = Parent;

	-- Load and return the component
	return Cheer.LoadComponent(Component);

end;

function Cheer.GetCheerData()
	-- Returns or initializes the game's Cheer data container

	-- Initialize Cheer data if nonexistent
	if not _G.CheerData then

		-- Create global data container
		_G.CheerData = {
			Components = {},
			ComponentRegistered = Signal.new()
		};

		-- Enable new components' OnRemove event
		Cheer.GetCheerData().ComponentRegistered:Connect(function (Name, View)
			local OnRemove = Cheer(View).OnRemove;

			-- Fire `OnRemove` upon deletion
			View.AncestryChanged:Connect(function (Item, Parent)
				if Parent == nil then
					OnRemove:Fire();
				end;
			end);
		end);

	end;

	-- Return Cheer data
	return _G.CheerData;

end;

function Cheer.CreateComponent(Name, RootView, ManualReadiness)

	-- Ensure root view is provided
	if typeof(RootView) ~= 'Instance' then
		return;
	end;

	-- Create signal indicating component removal
	local OnRemove = Signal.new();

	-- Create component
	local Component = { View = RootView, Name = Name, OnRemove = OnRemove, Ready = not ManualReadiness };

	-- Register component
	Cheer.GetCheerData().Components[RootView] = Component;
	Cheer.GetCheerData().ComponentRegistered:Fire(Name, RootView);

	-- Return the component
	return Component;

end;

function Cheer.Bind(Source, ...)

	local Args = { ... };
	local Filters, Destination = {};

	-- Parse arguments
	if #Args == 2 then
		Filters, Destination = ...;
	elseif #Args == 1 then
		Destination = ...;
	end;

	-- Create filter chain
	local Filter = Support.ChainCall(unpack(Filters));

	-- Create destinations list
	local Destinations = (typeof(Destination) == 'table') and Destination or { Destination };

	local function CallDestination(...)

		-- Call each destination
		for _, Destination in ipairs(Destinations) do

			-- If `Destination` is a function, call it
			if typeof(Destination) == 'function' then
				Destination(Filter(...));

			-- If `Destination` is a link, update its structure
			elseif (typeof(Destination) == 'userdata') and pcall(function () return #Destination; end) then
				Destination('Update', Filter(...));

			-- If `Destination` is a TextBox, update it if not focused
			elseif (typeof(Destination) == 'Instance') and Destination:IsA 'TextBox' and not Destination:IsFocused() then
				Destination.Text = Filter(...);

			-- If `Destination` is a TextLabel, update it
			elseif (typeof(Destination) == 'Instance') and Destination:IsA 'TextLabel' then
				Destination.Text = Filter(...);

			-- If `Destination` is a value instance, update it
			elseif (typeof(Destination) == 'Instance') and Destination.ClassName:match('Value$') then
				Destination.Value = Filter(...);
			end;

		end;

	end;

	-- Create a controller for the binding
	local Binding = {};

	function Binding.Trigger()
		-- Manually triggers a source data call to the destination

		-- If `Source` is a link
		if typeof(Source == 'userdata') and pcall(function () return #Source; end) then
			CallDestination(#Source);

		-- If `Source` is a text box
		elseif (typeof(Source) == 'Instance') and Source:IsA 'TextBox' then
			CallDestination(Source.Text);

		-- If `Source` is a button
		elseif (typeof(Source) == 'Instance') and Source:IsA 'GuiButton' then
			CallDestination();

		-- If `Source` is a value instance
		elseif (typeof(Source) == 'Instance') and Source.ClassName:match('Value$') then
			CallDestination(Source.Value);
		end;

		-- Return the binding
		return Binding;

	end;

	-- If `Source` is a link
	if typeof(Source) == 'userdata' and pcall(function () return #Source; end) then

		-- Subscribe to changes in the linked data
		local Subscription = Source('Subscribe', function (Change)
			CallDestination(#Source);
		end);

		-- Provide unbind method
		Binding.Unbind = function ()
			Subscription:Unsubscribe();
		end;

	-- If `Source` is an event
	elseif (typeof(Source) == 'RBXScriptSignal') or (typeof(Source) == 'table' and Source.Wait and Source.Connect) then

		-- Watch for the event firing
		local Connection = Source:Connect(function (...)
			CallDestination(...);
		end);

		-- Provide unbind method
		Binding.Unbind = function ()
			Connection:Disconnect();
		end;

	-- If `Source` is a TextBox
	elseif (typeof(Source) == 'Instance') and Source:IsA 'TextBox' then

		-- Watch for text box submitting
		local Connection = Source.FocusLost:Connect(function (EnterPressed)
			if EnterPressed then
				CallDestination(Source.Text);
			end;
		end);

		-- Provide unbind method
		Binding.Unbind = function ()
			Connection:Disconnect();
		end;

	-- If `Source` is a GUI button
	elseif (typeof(Source) == 'Instance') and Source:IsA 'GuiButton' then

		-- Watch for button clicking
		local Connection = Source.MouseButton1Click:Connect(function ()
			CallDestination();
		end);

		-- Provide unbind method
		Binding.Unbind = function ()
			Connection:Disconnect();
		end;

	-- If `Source` is a Value instance
	elseif (typeof(Source) == 'Instance') and Source.ClassName:match('Value$') then

		-- Watch for value changing
		local Connection = Source.Changed:Connect(function (Value)
			CallDestination(Value);
		end);

		-- Provide unbind method
		Binding.Unbind = function ()
			Connection:Disconnect();
		end;

	end;

	-- Attempt to get the calling script
	local Script = getfenv(2).script;

	-- Disable the binding if the script is removed
	if type(Script) == 'userdata' then
		Script.AncestryChanged:Connect(function (_, Parent)
			if Parent == nil then
				Binding.Unbind();
			end;
		end);
	end;

	-- Return the binding controller
	return Binding;

end;

function Cheer.Link(Structure)
	-- Returns a link to the given structure

	-- Create the link
	local Link = newproxy(true);
	local LinkMetatable = getmetatable(Link);

	-- Keep track of change subscriptions
	local LinkSubscriptions = {};
	local LinkDifferenceStream = Signal.new();

	function LinkMetatable.__index(Link, Index)
		-- Create sublinks for each requested subpath
		return Cheer.CreateSublink(Link, Index);
	end;

	function LinkMetatable.__newindex(Link, Key, Value)
		-- Patch a new value into the requested subpath

		-- Form path for change
		local Path = -Link;
		table.insert(Path, Key);

		-- Trigger patch
		Link('Patch', { Path = Path, Value = Value });

	end;

	function LinkMetatable.__len(Link)
		-- Return data when called with #
		return Structure; 
	end;

	local function Update(UpdatedStructure)
		-- Processes differences in structure updates and triggers subscribers

		-- Get the differences
		local Differences = Cheer.GetStructureDiff(Structure, UpdatedStructure);

		-- Set the updated structure as current
		Structure = UpdatedStructure;

		-- Trigger subscribers
		for _, Difference in ipairs(Differences) do
			LinkDifferenceStream:Fire(Difference);
		end;

	end;

	local function Set(UpdatedStructure)
		-- Replaces the entire structure and triggers top-level subscribers

		-- Replace structure
		Structure = UpdatedStructure;

		-- Trigger subscribers
		LinkDifferenceStream:Fire({
			Path = {},
			Value = UpdatedStructure
		});

	end;

	local function Patch(Difference)
		-- Processes difference into structure and triggers subscribers

		-- Patch root structure directly
		if #Difference.Path == 0 then
			Structure = Difference.Value;
			LinkDifferenceStream:Fire(Difference);
			return;
		end;

		-- Separate target from path
		local Path = Support.Slice(Difference.Path, 1, #Difference.Path - 1);
		local Target = Difference.Path[#Difference.Path];

		-- Patch at target point
		local Point = Link('Get', Path);
		Point[Target] = Difference.Value;

		-- Trigger subscribers
		LinkDifferenceStream:Fire(Difference);

	end;

	function LinkMetatable.__call(Link, Type, ...)

		-- Return subdata from sublinks
		if Type == 'Get' then
			local Path = ...;

			-- Return `nil` if anchor structure is `nil`
			if not Structure then
				return nil;
			end;

			-- Start at the anchor structure
			local Position = Structure;

			-- Travel recursively through the structure by the given path
			for _, Index in ipairs(Path) do
				Position = Position[Index];
			end;

			-- Return the final position in the structure subdata
			return Position;

		-- Store subscription callbacks to subpaths
		elseif Type == 'Subscribe' then
			local Callback, Path = ...;
			local Path = Path or -Link;

			-- Connect and react to relevant events in difference stream
			local Connection = LinkDifferenceStream:Connect(function (Difference)
				if Cheer.DoesPathMatch(Difference.Path, Path, true) then
					Callback(Difference);
				end;
			end);

			-- Create the subscription registration
			local Subscription = {
				Path = Path,
				Connection = Connection
			};

			function Subscription.Unsubscribe()
				-- Provide function to remove subscription

				-- Disable difference stream connection
				Connection:Disconnect();

				-- Unregister subscription
				LinkSubscriptions[Subscription] = nil;

			end;

			-- Attempt to get the calling script
			local Script = getfenv(2).script;

			-- Disconnect the subscription if the script is removed
			if type(Script) == 'userdata' then
				Script.AncestryChanged:Connect(function (_, Parent)
					if Parent == nil then
						Subscription:Unsubscribe();
					end;
				end);
			end;

			-- Add and return the subscription
			LinkSubscriptions[Subscription] = true;
			return Subscription;

		-- Return path requests
		elseif Type == 'GetPath' then
			return ...;

		-- Process update requests
		elseif Type == 'Update' then
			Update(...);

		-- Process set requests
		elseif Type == 'Set' then
			Set(...);

		-- Process patching requests
		elseif Type == 'Patch' then
			Patch(...);

		-- Process member iteration requests
		elseif Type == 'All' then
			local Member = ... or Link;

			-- Set initial order
			local Order = Support.Keys(#Member);
			local OrderIndex = Support.FlipTable(Order);
			local OrderModifier = nil;

			return function (Modifier, Key)
				-- Iterate or accept modifiers

				-- Apply new order modifiers
				if Modifier and Modifier.Type == 'Sort' and Modifier ~= OrderModifier then

					-- Sort values by `Modifier.Field`, based on value type
					table.sort(Order, function (A, B)

						-- Get values at keys `A` and `B`
						local A, B = #Member[A][Modifier.Field], #Member[B][Modifier.Field];

						-- Compare string values
						if type(A) == 'string' and type(B) == 'string' then
							return A:lower() < B:lower();

						-- Compare number values
						elseif type(A) == 'number' and type(B) == 'number' then
							return A < B;
						end;

					end);

					-- Reverse table order if sort is decreasing
					if Modifier.Direction == 'Decreasing' then
						Order = Support.ReverseTable(Order);
					end;

					-- Update order index
					OrderIndex = Support.FlipTable(Order);

					-- Indicate modifier has been applied
					OrderModifier = Modifier;

				end;

				-- Get or initiate current key
				local Key = not Key and Order[1] or (OrderIndex[Key] and Order[OrderIndex[Key] + 1]);

				-- Return value
				return Key, Key and (#Member[Key] and Member[Key]), Key and OrderIndex[Key];

			end;

		end;
	end;

	function LinkMetatable.__unm(Link)
		-- Returns the link's raw path
		return {};
	end;
	
	-- Return the link object
	return Link;

end;

function Cheer.CreateSublink(AnchorLink, Index)
	-- Returns a sublink for the given anchor link's index

	-- Create the sublink
	local Link = newproxy(true);
	local LinkMetatable = getmetatable(Link);

	function LinkMetatable.__index(Link, Index)
		-- Create sublinks for each requested subpath
		return Cheer.CreateSublink(Link, Index);
	end;

	function LinkMetatable.__call(Link, Type, ...)

		-- Requests data from the anchor link
		if Type == 'Get' or Type == 'GetPath' then
			local Path = ... or {};

			-- Skip pathbuilding when index is nil
			if not Index then
				return nil;
			end;

			-- Register this sublink pass into the path
			table.insert(Path, 1, Index);

			-- Pass the built path so far to the anchor link
			return AnchorLink(Type, Path);

		-- Requests a subscription from the anchor structure
		elseif Type == 'Subscribe' then
			local Callback, Path = ...;
			return AnchorLink('Subscribe', Callback, Path or -Link)

		-- Requests a member iterator from the anchor link
		elseif Type == 'All' then
			local Member = ... or Link;
			return AnchorLink('All', Member);
		
		-- Requests a patch from the anchor link
		elseif Type == 'Patch' then
			local Difference = ...;
			return AnchorLink('Patch', Difference);
		end;

	end;

	function LinkMetatable.__unm(Link)
		-- Returns the link's raw path
		return Link('GetPath');
	end;

	function LinkMetatable.__len(Link)
		-- Returns subdata from anchor structure when called with #
		return Link('Get');
	end;

	function LinkMetatable.__newindex(Link, Key, Value)
		-- Patch a new value into the requested subpath

		-- Form path for change
		local Path = -Link;
		table.insert(Path, Key);

		-- Trigger patch
		Link('Patch', { Path = Path, Value = Value });

	end;

	-- Return the sublink object
	return Link;

end;

function Cheer.GetStructureDiff(A, B, Path)
	-- Returns differences in structure B from A, with optional `Path` table for location-tracking

	local Differences = {};

	-- Keep track of reviewed indices in structure A
	local ReviewedIndices = {};

	-- For non-tables, compare differences directly
	if type(A) ~= 'table' or type(B) ~= 'table' then
		if A ~= B then
			table.insert(Differences, {
				Path = {},
				Value = B
			});
		end;
		return Differences;
	end;

	-- Go through all indices in A
	for Index in pairs(A) do

		-- Mark the index as reviewed
		ReviewedIndices[Index] = true;

		-- Compare table differences
		if type(A[Index]) == 'table' and type(B[Index]) == 'table' then

			-- Keep track of the search path
			local Path = Path and Support.CloneTable(Path) or {};
			table.insert(Path, Index);

			-- Take note of any differences
			Support.ConcatTable(Differences, Cheer.GetStructureDiff(A[Index], B[Index], Path));

		-- Compare other differences and take note of their path
		elseif A[Index] ~= B[Index] then
			table.insert(Differences, {
				Path = Support.ConcatTable(Path and Support.CloneTable(Path) or {}, { Index }),
				Value = B[Index]
			});

		end;

	end;

	-- Go through all unreviewed indices in B
	for Index in pairs(B) do
		if not ReviewedIndices[Index] then

			-- Take note of differences and their path
			table.insert(Differences, {
				Path = Support.ConcatTable(Path and Support.CloneTable(Path) or {}, { Index }),
				Value = B[Index];
			});

		end;
	end;

	-- Return the differences
	return Differences;

end;

function Cheer.DoesPathMatch(Path, Test, Propagate)
	-- Returns whether the test path matches `Path`, optionally propagating up

	-- Go through the test path's indices and ensure they're in `Path` (otherwise fail)
	for Index, PathIndex in ipairs(Test) do
		if Path[Index] ~= Test[Index] then
			return false;
		end;
	end;

	-- If paths aren't of same length but match so far, pass if propagating
	if #Test ~= #Path then
		return Propagate and true or false;
	end;

	-- If it's an exact match, pass
	return true;

end;

function Cheer.Clamp(Minimum, Maximum)
	-- Returns a Cheer filter clamping the passed numbers with the given parameters

	return function (...)

		local Args = { ... };
		local FilteredArgs = {};

		for Index, Arg in ipairs(Args) do

			-- Clamp each argument
			if Arg and Minimum and Arg < Minimum then
				Arg = Minimum;
			elseif Arg and Maximum and Arg > Maximum then
				Arg = Maximum;
			end;

			-- Index the filtered argument
			FilteredArgs[Index] = Arg;

		end;

		-- Return the filtered arguments
		return unpack(FilteredArgs);

	end;

end;

function Cheer.Divide(Divisor)
	-- Returns a Cheer filter dividing the passed numbers by the given `Divisor`

	return function (...)

		local Args = { ... };
		local FilteredArgs = {};

		for Index, Arg in ipairs(Args) do

			-- Divide each argument
			Arg = Arg / Divisor;

			-- Index the filtered argument
			FilteredArgs[Index] = Arg;

		end;

		-- Return the filtered arguments
		return unpack(FilteredArgs);

	end;

end;

function Cheer.Multiply(Multiplier)
	-- Returns a Cheer filter multiplying the passed numbers by the given `Multiplier`

	return function (...)

		local Args = { ... };
		local FilteredArgs = {};

		for Index, Arg in ipairs(Args) do

			-- Multiply each argument
			Arg = Arg * Multiplier;

			-- Index the filtered argument
			FilteredArgs[Index] = Arg;

		end;

		-- Return the filtered arguments
		return unpack(FilteredArgs);

	end;

end;

function Cheer.Append(String)
	-- Returns a Cheer filter appending `String` to the passed strings

	return function (...)

		local Args = { ... };
		local FilteredArgs = {};

		for Index, Arg in ipairs(Args) do

			-- Append to each string
			Arg = Arg .. String;

			-- Index the filtered argument
			FilteredArgs[Index] = Arg;

		end;

		-- Return the filtered arguments
		return unpack(FilteredArgs);

	end;

end;

function Cheer.Round(Places)
	-- Returns a Cheer filter which rounds passed numbers to the given number of decimal places

	return function (...)

		local Args = { ... };
		local FilteredArgs = {};

		for Index, Arg in ipairs(Args) do

			-- Round each number
			Arg = Support.Round(Arg, Places);

			-- Index the filtered argument
			FilteredArgs[Index] = Arg;

		end;

		-- Return the filtered arguments
		return unpack(FilteredArgs);

	end;

end;

function Cheer.Return(...)
	-- Returns a Cheer filter which returns the given arguments

	-- Store passed args
	local Args = { ... };

	-- Return passed args when called
	return function ()
		return unpack(Args);
	end;

end;

function Cheer.ToBoolean(...)
	-- Cheer filter returning boolean equivalents of passed arguments

	local Args = { ... };

	-- Process each argument
	for Index, Arg in ipairs(Args) do

		-- Convert the argument
		Args[Index] = not (not Args);

	end;

	-- Return the filtered arguments
	return unpack(Args);

end;

function Cheer.Matches(...)
	-- Returns a Cheer filter which returns whether the passed arguments match the given arguments

	-- Store passed args
	local TargetArgs = { ... };

	-- Return match result when called
	return function (...)
		local Args = { ... };

		-- Check each argument against the target arguments
		for ArgIndex, TargetArg in ipairs(TargetArgs) do
			if Args[ArgIndex] ~= TargetArg then

				-- Return a mismatch result at first mismatch
				return false;

			end;
		end;

		-- Return a matching result if no mismatches
		return true;
	end;

end;

function Cheer.Set(Object, Member)
	-- Returns a Cheer destination which sets member `Member` of `Object` to passed value

	return function (Value)
		Object[Member] = Value;
	end;

end;

-- Provide iteration sorting modifiers
Cheer.Sorted = setmetatable({}, {

	-- Allow increasing sort modifiers
	__add = function (Self, SortingField)
		return { Type = 'Sort', Field = SortingField, Direction = 'Increasing' };
	end;

	-- Allow decreasing sort modifiers
	__sub = function (Self, SortingField)
		return { Type = 'Sort', Field = SortingField, Direction = 'Decreasing' };
	end;

});

setmetatable(Cheer, {

	-- Enable syntactic sugar for loading components
	__call = function (Cheer, ...)

		local ArgCount = #{...};

		-- Direct loading
		if ArgCount == 1 then
			return Cheer.LoadComponent(...);

		-- Template instance loading
		elseif ArgCount == 2 then
			return Cheer.FromTemplate(...);
		end;

	end;

});

return Cheer;