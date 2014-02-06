-- Load the main tool's core environment when it's ready
repeat wait() until (
	_G.BTCoreEnv and
	_G.BTCoreEnv[script.Parent.Parent] and
	_G.BTCoreEnv[script.Parent.Parent].CoreReady
);
setfenv( 1, _G.BTCoreEnv[script.Parent.Parent] );

------------------------------------------
-- Rotate tool
------------------------------------------

-- Create the tool
Tools.Rotate = {};

-- Create structures to hold data that the tool needs
Tools.Rotate.Connections = {};

Tools.Rotate.Options = {
	["increment"] = 15;
	["pivot"] = "center"
};

Tools.Rotate.State = {
	["PreRotation"] = {};
	["rotating"] = false;
	["previous_distance"] = 0;
	["degrees_rotated"] = 0;
	["rotation_size"] = 0;
};

Tools.Rotate.Listeners = {};

-- Define the color of the tool
Tools.Rotate.Color = BrickColor.new( "Bright green" );

-- Start adding functionality to the tool
Tools.Rotate.Listeners.Equipped = function ()

	local self = Tools.Rotate;

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

	-- Update the pivot option
	self:changePivot( self.Options.pivot );

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
				if self.Options.pivot == "center" then
					self:updateBoundingBox();
				end;

			end;

		end;

	end )();

	-- Also enable the ability to select an edge as a pivot
	SelectEdge:start( function ( EdgeMarker )
		self:changePivot( "last" );
		self.Options.PivotPoint = EdgeMarker.CFrame;
		self.Connections.EdgeSelectionRemover = Selection.Changed:connect( function ()
			self.Options.PivotPoint = nil;
			if self.Connections.EdgeSelectionRemover then
				self.Connections.EdgeSelectionRemover:disconnect();
				self.Connections.EdgeSelectionRemover = nil;
			end;
		end );
		self:showHandles( EdgeMarker );
	end );

end;

Tools.Rotate.Listeners.Unequipped = function ()

	local self = Tools.Rotate;

	-- Stop the update loop
	if self.Updater then
		self.Updater();
		self.Updater = nil;
	end;

	-- Disable the ability to select edges
	SelectEdge:stop();
	if self.Options.PivotPoint then
		self.Options.PivotPoint = nil;
	end;

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

Tools.Rotate.Listeners.Button1Down = function ()

	local self = Tools.Rotate;

	if not self.State.rotating and self.Options.PivotPoint then
		self.Options.PivotPoint = nil;
	end;

end;

Tools.Rotate.showGUI = function ( self )

	-- Initialize the GUI if it's not ready yet
	if not self.GUI then

		local Container = Tool.Interfaces:WaitForChild( "BTRotateToolGUI" ):Clone();
		Container.Parent = UI;

		-- Change the pivot type option when the button is clicked
		Container.PivotOption.Center.Button.MouseButton1Down:connect( function ()
			self:changePivot( "center" );
		end );

		Container.PivotOption.Local.Button.MouseButton1Down:connect( function ()
			self:changePivot( "local" );
		end );

		Container.PivotOption.Last.Button.MouseButton1Down:connect( function ()
			self:changePivot( "last" );
		end );

		-- Change the increment option when the value of the textbox is updated
		Container.IncrementOption.Increment.TextBox.FocusLost:connect( function ( enter_pressed )
			self.Options.increment = tonumber( Container.IncrementOption.Increment.TextBox.Text ) or self.Options.increment;
			Container.IncrementOption.Increment.TextBox.Text = tostring( self.Options.increment );
		end );

		-- Add functionality to the rotation inputs
		Container.Info.RotationInfo.X.TextButton.MouseButton1Down:connect( function ()
			self.State.rot_x_focused = true;
			Container.Info.RotationInfo.X.TextBox:CaptureFocus();
		end );
		Container.Info.RotationInfo.X.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( Container.Info.RotationInfo.X.TextBox.Text );
			if potential_new then
				self:changeRotation( 'x', math.rad( potential_new ) );
			end;
			self.State.rot_x_focused = false;
		end );
		Container.Info.RotationInfo.Y.TextButton.MouseButton1Down:connect( function ()
			self.State.rot_y_focused = true;
			Container.Info.RotationInfo.Y.TextBox:CaptureFocus();
		end );
		Container.Info.RotationInfo.Y.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( Container.Info.RotationInfo.Y.TextBox.Text );
			if potential_new then
				self:changeRotation( 'y', math.rad( potential_new ) );
			end;
			self.State.rot_y_focused = false;
		end );
		Container.Info.RotationInfo.Z.TextButton.MouseButton1Down:connect( function ()
			self.State.rot_z_focused = true;
			Container.Info.RotationInfo.Z.TextBox:CaptureFocus();
		end );
		Container.Info.RotationInfo.Z.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( Container.Info.RotationInfo.Z.TextBox.Text );
			if potential_new then
				self:changeRotation( 'z', math.rad( potential_new ) );
			end;
			self.State.rot_z_focused = false;
		end );

		self.GUI = Container;
	end;

	-- Reveal the GUI
	self.GUI.Visible = true;

end;

Tools.Rotate.startHistoryRecord = function ( self )

	if self.State.HistoryRecord then
		self.State.HistoryRecord = nil;
	end;

	-- Create a history record
	self.State.HistoryRecord = {
		targets = _cloneTable( Selection.Items );
		initial_cframes = {};
		terminal_cframes = {};
		unapply = function ( self )
			Selection:clear();
			for _, Target in pairs( self.targets ) do
				if Target then
					Target.CFrame = self.initial_cframes[Target];
					Target:MakeJoints();
					Selection:add( Target );
				end;
			end;
		end;
		apply = function ( self )
			Selection:clear();
			for _, Target in pairs( self.targets ) do
				if Target then
					Target.CFrame = self.terminal_cframes[Target];
					Target:MakeJoints();
					Selection:add( Target );
				end;
			end;
		end;
	};
	for _, Item in pairs( self.State.HistoryRecord.targets ) do
		if Item then
			self.State.HistoryRecord.initial_cframes[Item] = Item.CFrame;
		end;
	end;

end;

Tools.Rotate.finishHistoryRecord = function ( self )

	if not self.State.HistoryRecord then
		return;
	end;

	for _, Item in pairs( self.State.HistoryRecord.targets ) do
		if Item then
			self.State.HistoryRecord.terminal_cframes[Item] = Item.CFrame;
		end;
	end;
	History:add( self.State.HistoryRecord );
	self.State.HistoryRecord = nil;

end;

Tools.Rotate.changeRotation = function ( self, component, new_value )

	self:startHistoryRecord();

	-- Change the rotation of each item selected
	for _, Item in pairs( Selection.Items ) do
		local old_x_rot, old_y_rot, old_z_rot = Item.CFrame:toEulerAnglesXYZ();
		Item.CFrame = CFrame.new( Item.Position ) * CFrame.Angles(
			component == 'x' and new_value or old_x_rot,
			component == 'y' and new_value or old_y_rot,
			component == 'z' and new_value or old_z_rot
		);
	end;

	self:finishHistoryRecord();

end;

Tools.Rotate.updateGUI = function ( self )

	-- Make sure the GUI exists
	if not self.GUI then
		return;
	end;

	local GUI = self.GUI;

	if #Selection.Items > 0 then

		-- Look for identical numbers in each axis
		local rot_x, rot_y, rot_z = nil, nil, nil;
		for item_index, Item in pairs( Selection.Items ) do

			local item_rot_x, item_rot_y, item_rot_z = Item.CFrame:toEulerAnglesXYZ();

			-- Set the first values for the first item
			if item_index == 1 then
				rot_x, rot_y, rot_z = _round( math.deg( item_rot_x ), 2 ), _round( math.deg( item_rot_y ), 2 ), _round( math.deg( item_rot_z ), 2 );

			-- Otherwise, compare them and set them to `nil` if they're not identical
			else
				if rot_x ~= _round( math.deg( item_rot_x ), 2 ) then
					rot_x = nil;
				end;
				if rot_y ~= _round( math.deg( item_rot_y ), 2 ) then
					rot_y = nil;
				end;
				if rot_z ~= _round( math.deg( item_rot_z ), 2 ) then
					rot_z = nil;
				end;
			end;

		end;

		-- Update the size info on the GUI
		if not self.State.rot_x_focused then
			GUI.Info.RotationInfo.X.TextBox.Text = rot_x and tostring( rot_x ) or "*";
		end;
		if not self.State.rot_y_focused then
			GUI.Info.RotationInfo.Y.TextBox.Text = rot_y and tostring( rot_y ) or "*";
		end;
		if not self.State.rot_z_focused then
			GUI.Info.RotationInfo.Z.TextBox.Text = rot_z and tostring( rot_z ) or "*";
		end;

		GUI.Info.Visible = true;
	else
		GUI.Info.Visible = false;
	end;

	if self.State.degrees_rotated then
		GUI.Changes.Text.Text = "rotated " .. tostring( self.State.degrees_rotated ) .. " degrees";
		GUI.Changes.Position = GUI.Info.Visible and UDim2.new( 0, 5, 0, 165 ) or UDim2.new( 0, 5, 0, 100 );
		GUI.Changes.Visible = true;
	else
		GUI.Changes.Text.Text = "";
		GUI.Changes.Visible = false;
	end;

end;

Tools.Rotate.hideGUI = function ( self )

	-- Hide the GUI if it exists
	if self.GUI then
		self.GUI.Visible = false;
	end;

end;

Tools.Rotate.updateBoundingBox = function ( self )

	if #Selection.Items > 0 then
		local SelectionSize, SelectionPosition = _getCollectionInfo( Selection.Items );
		self.BoundingBox.Size = SelectionSize;
		self.BoundingBox.CFrame = SelectionPosition;
		self:showHandles( self.BoundingBox );

	else
		self:hideHandles();
	end;

end;

Tools.Rotate.changePivot = function ( self, new_pivot )

	-- Have a quick reference to the GUI (if any)
	local PivotOptionGUI = self.GUI and self.GUI.PivotOption or nil;

	-- Disconnect any handle-related listeners that are specific to a certain pivot option
	if self.Connections.HandleFocusChangeListener then
		self.Connections.HandleFocusChangeListener:disconnect();
		self.Connections.HandleFocusChangeListener = nil;
	end;

	if self.Connections.HandleSelectionChangeListener then
		self.Connections.HandleSelectionChangeListener:disconnect();
		self.Connections.HandleSelectionChangeListener = nil;
	end;

	-- Remove any temporary edge selection
	if self.Options.PivotPoint then
		self.Options.PivotPoint = nil;
	end;

	if new_pivot == "center" then

		-- Update the options
		self.Options.pivot = "center";

		-- Focus the handles on the boundingbox
		self:showHandles( self.BoundingBox );

		-- Update the GUI's option panel
		if self.GUI then
			PivotOptionGUI.Center.SelectedIndicator.BackgroundTransparency = 0;
			PivotOptionGUI.Center.Background.Image = dark_slanted_rectangle;
			PivotOptionGUI.Local.SelectedIndicator.BackgroundTransparency = 1;
			PivotOptionGUI.Local.Background.Image = light_slanted_rectangle;
			PivotOptionGUI.Last.SelectedIndicator.BackgroundTransparency = 1;
			PivotOptionGUI.Last.Background.Image = light_slanted_rectangle;
		end;

	end;

	if new_pivot == "local" then

		-- Update the options
		self.Options.pivot = "local";

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
			PivotOptionGUI.Center.SelectedIndicator.BackgroundTransparency = 1;
			PivotOptionGUI.Center.Background.Image = light_slanted_rectangle;
			PivotOptionGUI.Local.SelectedIndicator.BackgroundTransparency = 0;
			PivotOptionGUI.Local.Background.Image = dark_slanted_rectangle;
			PivotOptionGUI.Last.SelectedIndicator.BackgroundTransparency = 1;
			PivotOptionGUI.Last.Background.Image = light_slanted_rectangle;
		end;

	end;

	if new_pivot == "last" then

		-- Update the options
		self.Options.pivot = "last";

		-- Always have the handles on the most recent addition to the selection
		self.Connections.HandleSelectionChangeListener = Selection.Changed:connect( function ()

			-- Clear out any previous adornee
			if not self.Options.PivotPoint then
				self:hideHandles();
			end;

			-- If there /is/ a last item in the selection, attach the handles to it
			if Selection.Last and not self.Options.PivotPoint then
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
			PivotOptionGUI.Center.SelectedIndicator.BackgroundTransparency = 1;
			PivotOptionGUI.Center.Background.Image = light_slanted_rectangle;
			PivotOptionGUI.Local.SelectedIndicator.BackgroundTransparency = 1;
			PivotOptionGUI.Local.Background.Image = light_slanted_rectangle;
			PivotOptionGUI.Last.SelectedIndicator.BackgroundTransparency = 0;
			PivotOptionGUI.Last.Background.Image = dark_slanted_rectangle;
		end;

	end;

end;


Tools.Rotate.showHandles = function ( self, Part )

	-- Create the handles if they don't exist yet
	if not self.Handles then

		-- Create the object
		self.Handles = RbxUtility.Create "ArcHandles" {
			Name = "BTRotationHandles";
			Color = self.Color;
			Parent = GUIContainer;
		};

		-- Add functionality to the handles

		self.Handles.MouseButton1Down:connect( function ()

			-- Prevent the platform from thinking we're selecting
			override_selection = true;
			self.State.rotating = true;

			-- Clear the change stats
			self.State.degrees_rotated = 0;
			self.State.rotation_size = 0;

			self:startHistoryRecord();

			-- Do a few things to the selection before manipulating it
			for _, Item in pairs( Selection.Items ) do

				-- Keep a copy of the state of each item
				self.State.PreRotation[Item] = Item:Clone();

				-- Anchor each item
				Item.Anchored = true;

			end;

			-- Also keep the position of the original selection
			local PreRotationSize, PreRotationPosition = _getCollectionInfo( self.State.PreRotation );
			self.State.PreRotationPosition = PreRotationPosition;

			-- Return stuff to normal once the mouse button is released
			self.Connections.HandleReleaseListener = Mouse.Button1Up:connect( function ()

				-- Prevent the platform from thinking we're selecting
				override_selection = true;
				self.State.rotating = false;

				-- Stop this connection from firing again
				if self.Connections.HandleReleaseListener then
					self.Connections.HandleReleaseListener:disconnect();
					self.Connections.HandleReleaseListener = nil;
				end;

				self:finishHistoryRecord();

				-- Restore properties that may have been changed temporarily
				-- from the pre-rotation state copies
				for Item, PreviousItemState in pairs( self.State.PreRotation ) do
					Item.Anchored = PreviousItemState.Anchored;
					self.State.PreRotation[Item] = nil;
					Item:MakeJoints();
				end;

			end );

		end );

		self.Handles.MouseDrag:connect( function ( axis, drag_distance )

			-- Round down and convert the drag distance to degrees to make it easier to work with
			local drag_distance = math.floor( math.deg( drag_distance ) );

			-- Calculate which multiple of the increment to use based on the current angle's
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

			local increase = self.Options.increment * math.floor( drag_distance / self.Options.increment );

			self.State.degrees_rotated = drag_distance;

			-- Go through the selection and make changes to it
			for _, Item in pairs( Selection.Items ) do

				-- Keep a copy of `Item` in case we need to revert anything
				local PreviousItemState = Item:Clone();

				-- Break any of `Item`'s joints so it can move freely
				Item:BreakJoints();

				-- Rotate `Item` according to the options and the handle that was used
				if axis == Enum.Axis.Y then
					if self.Options.pivot == "center" then
						Item.CFrame = self.State.PreRotationPosition:toWorldSpace( CFrame.new( 0, 0, 0 ) * CFrame.Angles( 0, math.rad( increase ), 0 ) ):toWorldSpace( self.State.PreRotation[Item].CFrame:toObjectSpace( self.State.PreRotationPosition ):inverse() );
					elseif self.Options.pivot == "local" then
						Item.CFrame = self.State.PreRotation[Item].CFrame:toWorldSpace( CFrame.new( 0, 0, 0 ) * CFrame.Angles( 0, math.rad( increase ), 0 ) );
					elseif self.Options.pivot == "last" then
						Item.CFrame = ( self.Options.PivotPoint or self.State.PreRotation[Selection.Last].CFrame ):toWorldSpace( CFrame.new( 0, 0, 0 ) * CFrame.Angles( 0, math.rad( increase ), 0 ) ):toWorldSpace( self.State.PreRotation[Item].CFrame:toObjectSpace( self.Options.PivotPoint or self.State.PreRotation[Selection.Last].CFrame ):inverse() );
					end;
				elseif axis == Enum.Axis.X then
					if self.Options.pivot == "center" then
						Item.CFrame = self.State.PreRotationPosition:toWorldSpace( CFrame.new( 0, 0, 0 ) * CFrame.Angles( math.rad( increase ), 0, 0 ) ):toWorldSpace( self.State.PreRotation[Item].CFrame:toObjectSpace( self.State.PreRotationPosition ):inverse() );
					elseif self.Options.pivot == "local" then
						Item.CFrame = self.State.PreRotation[Item].CFrame:toWorldSpace( CFrame.new( 0, 0, 0 ) * CFrame.Angles( math.rad( increase ), 0, 0 ) );
					elseif self.Options.pivot == "last" then
						Item.CFrame = ( self.Options.PivotPoint or self.State.PreRotation[Selection.Last].CFrame ):toWorldSpace( CFrame.new( 0, 0, 0 ) * CFrame.Angles( math.rad( increase ), 0, 0 ) ):toWorldSpace( self.State.PreRotation[Item].CFrame:toObjectSpace( self.Options.PivotPoint or self.State.PreRotation[Selection.Last].CFrame ):inverse() );
					end;
				elseif axis == Enum.Axis.Z then
					if self.Options.pivot == "center" then
						Item.CFrame = self.State.PreRotationPosition:toWorldSpace( CFrame.new( 0, 0, 0 ) * CFrame.Angles( 0, 0, math.rad( increase ) ) ):toWorldSpace( self.State.PreRotation[Item].CFrame:toObjectSpace( self.State.PreRotationPosition ):inverse() );
					elseif self.Options.pivot == "local" then
						Item.CFrame = self.State.PreRotation[Item].CFrame:toWorldSpace( CFrame.new( 0, 0, 0 ) * CFrame.Angles( 0, 0, math.rad( increase ) ) );
					elseif self.Options.pivot == "last" then
						Item.CFrame = ( self.Options.PivotPoint or self.State.PreRotation[Selection.Last].CFrame ):toWorldSpace( CFrame.new( 0, 0, 0 ) * CFrame.Angles( 0, 0, math.rad( increase ) ) ):toWorldSpace( self.State.PreRotation[Item].CFrame:toObjectSpace( self.Options.PivotPoint or self.State.PreRotation[Selection.Last].CFrame ):inverse() );
					end;
				end;

				-- Make joints with surrounding parts again once the resizing is done
				Item:MakeJoints();

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

Tools.Rotate.hideHandles = function ( self )

	-- Hide the handles if they exist
	if self.Handles then
		self.Handles.Adornee = nil;
	end;

end;

Tools.Rotate.Loaded = true;