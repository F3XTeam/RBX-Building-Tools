-- Load the main tool's core environment when it's ready
repeat wait() until (
	_G.BTCoreEnv and
	_G.BTCoreEnv[script.Parent.Parent] and
	_G.BTCoreEnv[script.Parent.Parent].CoreReady
);
setfenv( 1, _G.BTCoreEnv[script.Parent.Parent] );

------------------------------------------
-- Move tool
------------------------------------------

-- Create the main container for this tool
Tools.Move = {};
Tools.Move.Name = 'Move Tool';

-- Define the color of the tool
Tools.Move.Color = BrickColor.new( "Deep orange" );

-- Keep a container for temporary connections
Tools.Move.Connections = {};

-- Keep options in a container too
Tools.Move.Options = {
	["increment"] = 1;
	["axes"] = "global";
};

-- Keep internal state data in its own container
Tools.Move.State = {
	["distance_moved"] = 0;
	["moving"] = false;
	["PreMove"] = {};
};

-- Add listeners
Tools.Move.Listeners = {};

Tools.Move.Listeners.Equipped = function ()

	local self = Tools.Move;

	-- Make sure the tool is actually being equipped (because this is the default tool)
	if not Mouse then
		return;
	end;

	-- Change the color of selection boxes temporarily
	self.State.PreviousSelectionBoxColor = SelectionBoxColor;
	SelectionBoxColor = self.Color;
	updateSelectionBoxColor();

	-- Reveal the GUI
	self:showGUI();

	-- Create the boundingbox if it doesn't already exist
	if not self.BoundingBox then
		self.BoundingBox = RbxUtility.Create "Part" {
			Name = "BTBoundingBox";
			CanCollide = false;
			Transparency = 1;
			Anchored = true;
		};
	end;
	Mouse.TargetFilter = self.BoundingBox;

	-- Refresh the axis type option
	self:changeAxes( self.Options.axes );

	-- Listen for any keystrokes that might affect any dragging operation
	self.Connections.DraggerKeyListener = Mouse.KeyDown:connect( function ( key )

		local key = key:lower();

		-- Make sure a dragger exists
		if not self.Dragger then
			return;
		end;

		-- Rotate along the Z axis if `r` is pressed
		if key == "r" then
			self.Dragger:AxisRotate( Enum.Axis.Z );

		-- Rotate along the X axis if `t` is pressed
		elseif key == "t" then
			self.Dragger:AxisRotate( Enum.Axis.X );

		-- Rotate along the Y axis if `y` is pressed
		elseif key == "y" then
			self.Dragger:AxisRotate( Enum.Axis.Y );
		end;

		-- Simulate a mouse move so that it applies the changes
		self.Dragger:MouseMove( Mouse.UnitRay );

	end );

	self.State.StaticItems = {};
	self.State.StaticExtents = nil;
	self.State.RecalculateStaticExtents = true;	
	
	local StaticItemMonitors = {};

	function AddStaticItem(Item)
		
		-- Make sure the item isn't already in the list
		if #Support.FindTableOccurrences(self.State.StaticItems, Item) > 0 then
			return;
		end;

		-- Add the item to the list
		table.insert(self.State.StaticItems, Item);

		-- Attach state monitors
		StaticItemMonitors[Item] = Item.Changed:connect(function (Property)

			-- To tell when the extents may have changed
			if Property == 'CFrame' or Property == 'Size' then
				self.State.RecalculateStaticExtents = true;
			
			-- To tell when it's no longer static
			elseif Property == 'Anchored' and not Item.Anchored then
				RemoveStaticItem(Item);
			end;

		end);

		-- Recalculate the static extents
		self.State.RecalculateStaticExtents = true;

	end;

	function RemoveStaticItem(Item)

		-- Remove `Item` from the list
		local StaticItemIndex = Support.FindTableOccurrences(self.State.StaticItems, Item)[1];
		if StaticItemIndex then
			self.State.StaticItems[StaticItemIndex] = nil;
		end;

		-- Remove `Item`'s state monitors
		if StaticItemMonitors[Item] then
			StaticItemMonitors[Item]:disconnect();
			StaticItemMonitors[Item] = nil;
		end;

		-- Recalculate static extents
		self.State.RecalculateStaticExtents = true;

	end;

	for _, Item in pairs(Selection.Items) do
		if Item.Anchored then
			AddStaticItem(Item);
		end;
	end;

	table.insert(self.Connections, Selection.ItemAdded:connect(function (Item)
		if Item.Anchored then
			AddStaticItem(Item);
		end;
	end));

	table.insert(self.Connections, Selection.ItemRemoved:connect(function (Item, Clearing)

		-- Make sure this isn't part of a mass removal (i.e. a clearance),
		-- and that the item is actually in the list of static parts
		if Clearing or not StaticItemMonitors[Item] then
			return;
		end;

		RemoveStaticItem(Item);

	end));

	table.insert(self.Connections, Selection.Cleared:connect(function ()
		for MonitorIndex, Monitor in pairs(StaticItemMonitors) do
			Monitor:disconnect();
			StaticItemMonitors[MonitorIndex] = nil;
		end;
		self.State.StaticExtents = nil;
		self.State.StaticItems = {};
	end));

	-- Oh, and update the boundingbox and the GUI regularly
	coroutine.wrap( function ()
		updater_on = true;

		-- Provide a function to stop the loop
		self.Updater = function ()
			updater_on = false;
		end;

		while wait( 0.1 ) and updater_on do

			-- Make sure the tool's equipped
			if CurrentTool == self then

				-- Update the GUI if it's visible
				if self.GUI and self.GUI.Visible then
					self:updateGUI();
				end;

				-- Update the boundingbox if it's visible
				if self.Options.axes == "global" then
					self:updateBoundingBox();
				end;

			end;

		end;

	end )();

end;

Tools.Move.Listeners.Unequipped = function ()

	local self = Tools.Move;

	-- Stop the update loop
	if self.Updater then
		self.Updater();
		self.Updater = nil;
	end;

	-- Stop any dragging
	self:FinishDragging();

	-- Hide the GUI
	self:hideGUI();

	-- Hide the handles
	self:hideHandles();

	-- Clear out any temporary connections
	for connection_index, Connection in pairs( self.Connections ) do
		Connection:disconnect();
		self.Connections[connection_index] = nil;
	end;

	-- Restore the original color of the selection boxes
	SelectionBoxColor = self.State.PreviousSelectionBoxColor;
	updateSelectionBoxColor();

end;

Tools.Move.updateGUI = function ( self )

	if self.GUI then
		local GUI = self.GUI;

		if #Selection.Items > 0 then

			-- Look for identical numbers in each axis
			local position_x, position_y, position_z =  nil, nil, nil;
			for item_index, Item in pairs( Selection.Items ) do

				-- Set the first values for the first item
				if item_index == 1 then
					position_x, position_y, position_z = Support.Round(Item.Position.x, 2), Support.Round(Item.Position.y, 2), Support.Round(Item.Position.z, 2);

				-- Otherwise, compare them and set them to `nil` if they're not identical
				else
					if position_x ~= Support.Round(Item.Position.x, 2) then
						position_x = nil;
					end;
					if position_y ~= Support.Round(Item.Position.y, 2) then
						position_y = nil;
					end;
					if position_z ~= Support.Round(Item.Position.z, 2) then
						position_z = nil;
					end;
				end;

			end;

			-- If each position along each axis is the same, display that number; otherwise, display "*"
			if not self.State.pos_x_focused then
				GUI.Info.Center.X.TextBox.Text = position_x and tostring( position_x ) or "*";
			end;
			if not self.State.pos_y_focused then
				GUI.Info.Center.Y.TextBox.Text = position_y and tostring( position_y ) or "*";
			end;
			if not self.State.pos_z_focused then
				GUI.Info.Center.Z.TextBox.Text = position_z and tostring( position_z ) or "*";
			end;

			GUI.Info.Visible = true;
		else
			GUI.Info.Visible = false;
		end;

		if self.State.distance_moved then
			GUI.Changes.Text.Text = "moved " .. tostring( self.State.distance_moved ) .. " studs";
			GUI.Changes.Position = GUI.Info.Visible and UDim2.new( 0, 5, 0, 165 ) or UDim2.new( 0, 5, 0, 100 );
			GUI.Changes.Visible = true;
		else
			GUI.Changes.Text.Text = "";
			GUI.Changes.Visible = false;
		end;
	end;

end;

Tools.Move.changePosition = function ( self, component, new_value )

	self:startHistoryRecord();

	-- Change the position of each item selected
	for _, Item in pairs( Selection.Items ) do
		Change(Item, {
			CFrame = CFrame.new(
				component == 'x' and new_value or Item.Position.x,
				component == 'y' and new_value or Item.Position.y,
				component == 'z' and new_value or Item.Position.z
			) * CFrame.Angles( Item.CFrame:toEulerAnglesXYZ() );
		});
	end;

	self:finishHistoryRecord();

end;

Tools.Move.startHistoryRecord = function ( self )

	if self.State.HistoryRecord then
		self.State.HistoryRecord = nil;
	end;

	-- Create a history record
	self.State.HistoryRecord = {
		targets = Support.CloneTable(Selection.Items);
		initial_positions = {};
		terminal_positions = {};
		Unapply = function ( self )
			Selection:clear();
			for _, Target in pairs( self.targets ) do
				if Target then
					Change(Target, {
						CFrame = self.initial_positions[Target];
					});
					MakeJoints(Target);
					Selection:add(Target);
				end;
			end;
		end;
		Apply = function ( self )
			Selection:clear();
			for _, Target in pairs( self.targets ) do
				if Target then
					Change(Target, {
						CFrame = self.terminal_positions[Target];
					});
					MakeJoints(Target);
					Selection:add(Target);
				end;
			end;
		end;
	};
	for _, Item in pairs( self.State.HistoryRecord.targets ) do
		if Item then
			self.State.HistoryRecord.initial_positions[Item] = Item.CFrame;
		end;
	end;

end;

Tools.Move.finishHistoryRecord = function ( self )

	if not self.State.HistoryRecord then
		return;
	end;

	for _, Item in pairs( self.State.HistoryRecord.targets ) do
		if Item then
			self.State.HistoryRecord.terminal_positions[Item] = Item.CFrame;
		end;
	end;
	History:Add( self.State.HistoryRecord );
	self.State.HistoryRecord = nil;

end;

Tools.Move.StartDragging = function ( self, Target )
	-- Begins dragging the current selection

	for _, Item in pairs( Selection.Items ) do
		Change(Item, {
			RotVelocity = Vector3.new(0, 0, 0);
			Velocity = Vector3.new(0, 0, 0);
		});
	end;

	self:startHistoryRecord();

	self.State.dragging = true;
	override_selection = true;

	self.Dragger = Instance.new( "Dragger" );
	self.Dragger:MouseDown( Target, Target.CFrame:toObjectSpace( CFrame.new( Mouse.Hit.p ) ).p, Selection.Items );

	-- Release the dragger once the left mouse button is released
	self.Connections.DraggerConnection = UserInputService.InputEnded:connect( function ( InputData )
		if InputData.UserInputType == Enum.UserInputType.MouseButton1 then
			self:FinishDragging();
		end;
	end );

end;

Tools.Move.FinishDragging = function ( self )
	-- Finishes and cleans up the selection dragger

	override_selection = true;

	-- Disable the dragger
	if self.Connections.DraggerConnection then
		self.Connections.DraggerConnection:disconnect();
		self.Connections.DraggerConnection = nil;
	end;
	if not self.Dragger then
		return;
	end;
	self.Dragger:MouseUp();
	self.State.dragging = false;
	self.Dragger:Destroy();
	self.Dragger = nil;

	-- Replicate changes to server if in filter mode
	if FilterMode then
		for _, Item in pairs(Selection.Items) do
			Change(Item, {
				CFrame = Item.CFrame
			});
		end;
	end;

	self:finishHistoryRecord();

end;

Tools.Move.Listeners.Button1Down = function ()

	local self = Tools.Move;

	local Target = self.ManualTarget or Mouse.Target;
	self.ManualTarget = nil;

	-- If an unselected part is being moved, switch to it
	if not Selection:find( Target ) and isSelectable( Target ) then
		Selection:clear();
		Selection:add( Target );
	end;

	-- If the unselected target can't be selected at all, ignore the rest of the procedure
	if not Selection:find( Target ) then
		return;
	end;

	self:StartDragging( Target );

end;

Tools.Move.Listeners.Move = function ()

	local self = Tools.Move;

	if not self.Dragger then
		return;
	end;

	override_selection = true;

	-- Perform the emulated mouse movement
	self.Dragger:MouseMove( Mouse.UnitRay );

	-- Replicate changes to server if in filter mode
	if FilterMode then
		for _, Item in pairs(Selection.Items) do
			Change(Item, {
				CFrame = Item.CFrame
			});
		end;
	end;

end;

Tools.Move.Listeners.KeyUp = function ( Key )
	local self = Tools.Move;

	-- Provide a keyboard shortcut to the increment input
	if Key == '-' and self.GUI then
		self.GUI.IncrementOption.Increment.TextBox:CaptureFocus();
	end;
end;

Tools.Move.showGUI = function ( self )

	-- Initialize the GUI if it's not ready yet
	if not self.GUI then

		local Container = Tool.Interfaces.BTMoveToolGUI:Clone();
		Container.Parent = UI;

		-- Change the axis type option when the button is clicked
		Container.AxesOption.Global.Button.MouseButton1Down:connect( function ()
			self:changeAxes( "global" );
			Container.AxesOption.Global.SelectedIndicator.BackgroundTransparency = 0;
			Container.AxesOption.Global.Background.Image = Assets.DarkSlantedRectangle;
			Container.AxesOption.Local.SelectedIndicator.BackgroundTransparency = 1;
			Container.AxesOption.Local.Background.Image = Assets.LightSlantedRectangle;
			Container.AxesOption.Last.SelectedIndicator.BackgroundTransparency = 1;
			Container.AxesOption.Last.Background.Image = Assets.LightSlantedRectangle;
		end );

		Container.AxesOption.Local.Button.MouseButton1Down:connect( function ()
			self:changeAxes( "local" );
			Container.AxesOption.Global.SelectedIndicator.BackgroundTransparency = 1;
			Container.AxesOption.Global.Background.Image = Assets.LightSlantedRectangle;
			Container.AxesOption.Local.SelectedIndicator.BackgroundTransparency = 0;
			Container.AxesOption.Local.Background.Image = Assets.DarkSlantedRectangle;
			Container.AxesOption.Last.SelectedIndicator.BackgroundTransparency = 1;
			Container.AxesOption.Last.Background.Image = Assets.LightSlantedRectangle;
		end );

		Container.AxesOption.Last.Button.MouseButton1Down:connect( function ()
			self:changeAxes( "last" );
			Container.AxesOption.Global.SelectedIndicator.BackgroundTransparency = 1;
			Container.AxesOption.Global.Background.Image = Assets.LightSlantedRectangle;
			Container.AxesOption.Local.SelectedIndicator.BackgroundTransparency = 1;
			Container.AxesOption.Local.Background.Image = Assets.LightSlantedRectangle;
			Container.AxesOption.Last.SelectedIndicator.BackgroundTransparency = 0;
			Container.AxesOption.Last.Background.Image = Assets.DarkSlantedRectangle;
		end );

		-- Change the increment option when the value of the textbox is updated
		Container.IncrementOption.Increment.TextBox.FocusLost:connect( function ( enter_pressed )
			self.Options.increment = tonumber( Container.IncrementOption.Increment.TextBox.Text ) or self.Options.increment;
			Container.IncrementOption.Increment.TextBox.Text = tostring( self.Options.increment );
		end );

		-- Add functionality to the position inputs
		Container.Info.Center.X.TextButton.MouseButton1Down:connect( function ()
			self.State.pos_x_focused = true;
			Container.Info.Center.X.TextBox:CaptureFocus();
		end );
		Container.Info.Center.X.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( Container.Info.Center.X.TextBox.Text );
			if potential_new then
				self:changePosition( 'x', potential_new );
			end;
			self.State.pos_x_focused = false;
		end );
		Container.Info.Center.Y.TextButton.MouseButton1Down:connect( function ()
			self.State.pos_y_focused = true;
			Container.Info.Center.Y.TextBox:CaptureFocus();
		end );
		Container.Info.Center.Y.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( Container.Info.Center.Y.TextBox.Text );
			if potential_new then
				self:changePosition( 'y', potential_new );
			end;
			self.State.pos_y_focused = false;
		end );
		Container.Info.Center.Z.TextButton.MouseButton1Down:connect( function ()
			self.State.pos_z_focused = true;
			Container.Info.Center.Z.TextBox:CaptureFocus();
		end );
		Container.Info.Center.Z.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( Container.Info.Center.Z.TextBox.Text );
			if potential_new then
				self:changePosition( 'z', potential_new );
			end;
			self.State.pos_z_focused = false;
		end );

		self.GUI = Container;
	end;

	-- Reveal the GUI
	self.GUI.Visible = true;

end;

Tools.Move.hideGUI = function ( self )

	-- Hide the GUI if it exists
	if self.GUI then
		self.GUI.Visible = false;
	end;

end;

Tools.Move.showHandles = function ( self, Part )

	-- Create the handles if they don't exist yet
	if not self.Handles then

		-- Create the object
		self.Handles = RbxUtility.Create "Handles" {
			Name = "BTMovementHandles";
			Color = self.Color;
			Parent = GUIContainer;
		};

		-- Add functionality to the handles

		self.Handles.MouseButton1Down:connect( function ()

			-- Prevent the platform from thinking we're selecting
			override_selection = true;
			self.State.moving = true;

			-- Clear the change stats
			self.State.distance_moved = 0;

			self:startHistoryRecord();

			-- Do a few things to the selection before manipulating it
			for _, Item in pairs( Selection.Items ) do

				-- Keep a copy of the state of each item
				self.State.PreMove[Item] = Item:Clone();

				-- Anchor each item
				Change(Item, {
					Anchored = true;
				});

			end;

			-- Return stuff to normal once the mouse button is released
			self.Connections.HandleReleaseListener = UserInputService.InputEnded:connect( function ( InputData )

				-- Make sure the left mouse button was released
				if InputData.UserInputType ~= Enum.UserInputType.MouseButton1 then
					return;
				end;

				-- Prevent the platform from thinking we're selecting
				override_selection = true;
				self.State.moving = false;

				-- Stop this connection from firing again
				if self.Connections.HandleReleaseListener then
					self.Connections.HandleReleaseListener:disconnect();
					self.Connections.HandleReleaseListener = nil;
				end;

				self:finishHistoryRecord();

				-- Restore properties that may have been changed temporarily
				-- from the pre-movement state copies
				for Item, PreviousItemState in pairs( self.State.PreMove ) do
					Change(Item, {
						Anchored = PreviousItemState.Anchored;
					});

					self.State.PreMove[Item] = nil;

					-- Update the positions on the server if in filter mode
					if FilterMode then
						Change(Item, {
							CFrame = Item.CFrame;
						});
					end;

					MakeJoints(Item);

					Change(Item, {
						Velocity = Vector3.new(0, 0, 0);
						RotVelocity = Vector3.new(0, 0, 0);
					});
				end;

			end );

		end );

		self.Handles.MouseDrag:connect( function ( face, drag_distance )

			-- Calculate which multiple of the increment to use based on the current drag distance's
			-- proximity to their nearest upper and lower multiples

			local difference = drag_distance % self.Options.increment;

			local lower_degree = drag_distance - difference;
			local upper_degree = drag_distance - difference + self.Options.increment;

			local lower_degree_proximity = math.abs( drag_distance - lower_degree );
			local upper_degree_proximity = math.abs( drag_distance - upper_degree );

			if lower_degree_proximity <= upper_degree_proximity then
				drag_distance = lower_degree;
			else
				drag_distance = upper_degree;
			end;

			local increase = drag_distance;

			self.State.distance_moved = drag_distance;

			-- Increment the position of each selected item in the direction of `face`
			for _, Item in pairs( Selection.Items ) do

				-- Remove any joints connected with `Item` so that it can freely move
				BreakJoints(Item);

				-- Update the position of `Item` depending on the type of axes that is currently set
				if face == Enum.NormalId.Top then
					if self.Options.axes == "global" then
						Item.CFrame = CFrame.new( self.State.PreMove[Item].CFrame.p ):toWorldSpace( CFrame.new( 0, increase, 0 ) ) * CFrame.Angles( self.State.PreMove[Item].CFrame:toEulerAnglesXYZ() );
					elseif self.Options.axes == "local" then
						Item.CFrame = self.State.PreMove[Item].CFrame:toWorldSpace( CFrame.new( 0, increase, 0 ) );
					elseif self.Options.axes == "last" then
						Item.CFrame = self.State.PreMove[Selection.Last].CFrame:toWorldSpace( CFrame.new( 0, increase, 0 ) ):toWorldSpace( self.State.PreMove[Item].CFrame:toObjectSpace( self.State.PreMove[Selection.Last].CFrame ):inverse() );
					end;

				elseif face == Enum.NormalId.Bottom then
					if self.Options.axes == "global" then
						Item.CFrame = CFrame.new( self.State.PreMove[Item].CFrame.p ):toWorldSpace( CFrame.new( 0, -increase, 0 ) ) * CFrame.Angles( self.State.PreMove[Item].CFrame:toEulerAnglesXYZ() );
					elseif self.Options.axes == "local" then
						Item.CFrame = self.State.PreMove[Item].CFrame:toWorldSpace( CFrame.new( 0, -increase, 0 ) );
					elseif self.Options.axes == "last" then
						Item.CFrame = self.State.PreMove[Selection.Last].CFrame:toWorldSpace( CFrame.new( 0, -increase, 0 ) ):toWorldSpace( self.State.PreMove[Item].CFrame:toObjectSpace( self.State.PreMove[Selection.Last].CFrame ):inverse() );
					end;

				elseif face == Enum.NormalId.Front then
					if self.Options.axes == "global" then
						Item.CFrame = CFrame.new( self.State.PreMove[Item].CFrame.p ):toWorldSpace( CFrame.new( 0, 0, -increase ) ) * CFrame.Angles( self.State.PreMove[Item].CFrame:toEulerAnglesXYZ() );
					elseif self.Options.axes == "local" then
						Item.CFrame = self.State.PreMove[Item].CFrame:toWorldSpace( CFrame.new( 0, 0, -increase ) );
					elseif self.Options.axes == "last" then
						Item.CFrame = self.State.PreMove[Selection.Last].CFrame:toWorldSpace( CFrame.new( 0, 0, -increase ) ):toWorldSpace( self.State.PreMove[Item].CFrame:toObjectSpace( self.State.PreMove[Selection.Last].CFrame ):inverse() );
					end;

				elseif face == Enum.NormalId.Back then
					if self.Options.axes == "global" then
						Item.CFrame = CFrame.new( self.State.PreMove[Item].CFrame.p ):toWorldSpace( CFrame.new( 0, 0, increase ) ) * CFrame.Angles( self.State.PreMove[Item].CFrame:toEulerAnglesXYZ() );
					elseif self.Options.axes == "local" then
						Item.CFrame = self.State.PreMove[Item].CFrame:toWorldSpace( CFrame.new( 0, 0, increase ) );
					elseif self.Options.axes == "last" then
						Item.CFrame = self.State.PreMove[Selection.Last].CFrame:toWorldSpace( CFrame.new( 0, 0, increase ) ):toWorldSpace( self.State.PreMove[Item].CFrame:toObjectSpace( self.State.PreMove[Selection.Last].CFrame ):inverse() );
					end;

				elseif face == Enum.NormalId.Right then
					if self.Options.axes == "global" then
						Item.CFrame = CFrame.new( self.State.PreMove[Item].CFrame.p ):toWorldSpace( CFrame.new( increase, 0, 0 ) ) * CFrame.Angles( self.State.PreMove[Item].CFrame:toEulerAnglesXYZ() );
					elseif self.Options.axes == "local" then
						Item.CFrame = self.State.PreMove[Item].CFrame:toWorldSpace( CFrame.new( increase, 0, 0 ) );
					elseif self.Options.axes == "last" then
						Item.CFrame = self.State.PreMove[Selection.Last].CFrame:toWorldSpace( CFrame.new( increase, 0, 0 ) ):toWorldSpace( self.State.PreMove[Item].CFrame:toObjectSpace( self.State.PreMove[Selection.Last].CFrame ):inverse() );
					end;

				elseif face == Enum.NormalId.Left then
					if self.Options.axes == "global" then
						Item.CFrame = CFrame.new( self.State.PreMove[Item].CFrame.p ):toWorldSpace( CFrame.new( -increase, 0, 0 ) ) * CFrame.Angles( self.State.PreMove[Item].CFrame:toEulerAnglesXYZ() );
					elseif self.Options.axes == "local" then
						Item.CFrame = self.State.PreMove[Item].CFrame:toWorldSpace( CFrame.new( -increase, 0, 0 ) );
					elseif self.Options.axes == "last" then
						Item.CFrame = self.State.PreMove[Selection.Last].CFrame:toWorldSpace( CFrame.new( -increase, 0, 0 ) ):toWorldSpace( self.State.PreMove[Item].CFrame:toObjectSpace( self.State.PreMove[Selection.Last].CFrame ):inverse() );
					end;

				end;

			end;

		end );

	end;

	-- Stop listening for the existence of the previous adornee (if any)
	if self.Connections.AdorneeExistenceListener then
		self.Connections.AdorneeExistenceListener:disconnect();
		self.Connections.AdorneeExistenceListener = nil;
	end;

	-- Attach the handles to `Part`
	self.Handles.Adornee = Part;

	-- Make sure to hide the handles if `Part` suddenly stops existing
	self.Connections.AdorneeExistenceListener = Part.AncestryChanged:connect( function ( Object, NewParent )

		-- Make sure this change in parent applies directly to `Part`
		if Object ~= Part then
			return;
		end;

		-- Show the handles according to the existence of the part
		if NewParent == nil then
			self:hideHandles();
		else
			self:showHandles( Part );
		end;

	end );

end;

Tools.Move.hideHandles = function ( self )

	-- Hide the handles if they exist
	if self.Handles then
		self.Handles.Adornee = nil;
	end;

end;

Tools.Move.updateBoundingBox = function ( self )
	if #Selection.Items > 0 and not self.State.dragging then
		if self.State.RecalculateStaticExtents then
			self.State.StaticExtents = calculateExtents(self.State.StaticItems, nil, true);
			self.State.RecalculateStaticExtents = false;
		end;
		local SelectionSize, SelectionPosition = calculateExtents(Selection.Items, self.State.StaticExtents);
		self.BoundingBox.Size = SelectionSize;
		self.BoundingBox.CFrame = SelectionPosition;
		self:showHandles(self.BoundingBox);

	else
		self:hideHandles();
	end;
end;

Tools.Move.changeAxes = function ( self, new_axes )

	-- Have a quick reference to the GUI (if any)
	local AxesOptionGUI = self.GUI and self.GUI.AxesOption or nil;

	-- Disconnect any handle-related listeners that are specific to a certain axes option

	if self.Connections.HandleFocusChangeListener then
		self.Connections.HandleFocusChangeListener:disconnect();
		self.Connections.HandleFocusChangeListener = nil;
	end;

	if self.Connections.HandleSelectionChangeListener then
		self.Connections.HandleSelectionChangeListener:disconnect();
		self.Connections.HandleSelectionChangeListener = nil;
	end;

	if new_axes == "global" then

		-- Update the options
		self.Options.axes = "global";

		-- Clear out any previous adornee
		self:hideHandles();

		-- Focus the handles on the boundary box
		self:showHandles( self.BoundingBox );

		-- Update the GUI's option panel
		if self.GUI then
			AxesOptionGUI.Global.SelectedIndicator.BackgroundTransparency = 0;
			AxesOptionGUI.Global.Background.Image = Assets.DarkSlantedRectangle;
			AxesOptionGUI.Local.SelectedIndicator.BackgroundTransparency = 1;
			AxesOptionGUI.Local.Background.Image = Assets.LightSlantedRectangle;
			AxesOptionGUI.Last.SelectedIndicator.BackgroundTransparency = 1;
			AxesOptionGUI.Last.Background.Image = Assets.LightSlantedRectangle;
		end;

	end;

	if new_axes == "local" then

		-- Update the options
		self.Options.axes = "local";

		-- Always have the handles on the most recent addition to the selection
		self.Connections.HandleSelectionChangeListener = Selection.Changed:connect( function ()

			-- Clear out any previous adornee
			self:hideHandles();

			-- If there /is/ a last item in the selection, attach the handles to it
			if Selection.Last then
				self:showHandles( Selection.Last );
			end;

		end );

		-- Switch the adornee of the handles if the second mouse button is pressed
		self.Connections.HandleFocusChangeListener = Mouse.Button2Up:connect( function ()

			-- Make sure the platform doesn't think we're selecting
			override_selection = true;

			-- If the target is in the selection, make it the new adornee
			if Selection:find( Mouse.Target ) then
				Selection:focus( Mouse.Target );
				self:showHandles( Mouse.Target );
			end;

		end );

		-- Finally, attach the handles to the last item added to the selection (if any)
		if Selection.Last then
			self:showHandles( Selection.Last );
		end;

		-- Update the GUI's option panel
		if self.GUI then
			AxesOptionGUI.Global.SelectedIndicator.BackgroundTransparency = 1;
			AxesOptionGUI.Global.Background.Image = Assets.LightSlantedRectangle;
			AxesOptionGUI.Local.SelectedIndicator.BackgroundTransparency = 0;
			AxesOptionGUI.Local.Background.Image = Assets.DarkSlantedRectangle;
			AxesOptionGUI.Last.SelectedIndicator.BackgroundTransparency = 1;
			AxesOptionGUI.Last.Background.Image = Assets.LightSlantedRectangle;
		end;

	end;

	if new_axes == "last" then

		-- Update the options
		self.Options.axes = "last";

		-- Always have the handles on the most recent addition to the selection
		self.Connections.HandleSelectionChangeListener = Selection.Changed:connect( function ()

			-- Clear out any previous adornee
			self:hideHandles();

			-- If there /is/ a last item in the selection, attach the handles to it
			if Selection.Last then
				self:showHandles( Selection.Last );
			end;

		end );

		-- Switch the adornee of the handles if the second mouse button is pressed
		self.Connections.HandleFocusChangeListener = Mouse.Button2Up:connect( function ()

			-- Make sure the platform doesn't think we're selecting
			override_selection = true;

			-- If the target is in the selection, make it the new adornee
			if Selection:find( Mouse.Target ) then
				Selection:focus( Mouse.Target );
				self:showHandles( Mouse.Target );
			end;

		end );

		-- Finally, attach the handles to the last item added to the selection (if any)
		if Selection.Last then
			self:showHandles( Selection.Last );
		end;

		-- Update the GUI's option panel
		if self.GUI then
			AxesOptionGUI.Global.SelectedIndicator.BackgroundTransparency = 1;
			AxesOptionGUI.Global.Background.Image = Assets.LightSlantedRectangle;
			AxesOptionGUI.Local.SelectedIndicator.BackgroundTransparency = 1;
			AxesOptionGUI.Local.Background.Image = Assets.LightSlantedRectangle;
			AxesOptionGUI.Last.SelectedIndicator.BackgroundTransparency = 0;
			AxesOptionGUI.Last.Background.Image = Assets.DarkSlantedRectangle;
		end;

	end;

end;

Tools.Move.Loaded = true;