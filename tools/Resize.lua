-- Load the main tool's core environment when it's ready
repeat wait() until (
	_G.BTCoreEnv and
	_G.BTCoreEnv[script.Parent.Parent] and
	_G.BTCoreEnv[script.Parent.Parent].CoreReady
);
setfenv( 1, _G.BTCoreEnv[script.Parent.Parent] );

------------------------------------------
-- Resize tool
------------------------------------------

-- Create the tool
Tools.Resize = {};
Tools.Resize.Name = 'Resize Tool';

-- Create structures that will be used within the tool
Tools.Resize.Connections = {};

Tools.Resize.Options = {
	["increment"] = 1;
	["directions"] = "normal";
};

Tools.Resize.State = {
	["PreResize"] = {};
	["previous_distance"] = 0;
	["resizing"] = false;
	["length_resized"] = 0;
};

Tools.Resize.Listeners = {};

-- Define the color of the tool
Tools.Resize.Color = BrickColor.new( "Cyan" );

Tools.Resize.Listeners.Equipped = function ()

	local self = Tools.Resize;

	-- Change the color of selection boxes temporarily
	self.State.PreviousSelectionBoxColor = SelectionBoxColor;
	SelectionBoxColor = self.Color;
	updateSelectionBoxColor();

	-- Reveal the GUI
	self:showGUI();

	-- Always have the handles on the most recent addition to the selection
	table.insert( self.Connections, Selection.Changed:connect( function ()

		-- Clear out any previous adornee
		self:hideHandles();

		-- If there /is/ a last item in the selection, attach the handles to it
		if Selection.Last then
			self:showHandles( Selection.Last );
		end;

	end ) );

	-- Switch the adornee of the handles if the second mouse button is pressed
	table.insert( self.Connections, Mouse.Button2Up:connect( function ()

		-- Make sure the platform doesn't think we're selecting
		override_selection = true;

		-- If the target is in the selection, make it the new adornee
		if Selection:find( Mouse.Target ) then
			Selection:focus( Mouse.Target );
		end;

	end ) );

	-- Finally, attach the handles to the last item added to the selection (if any)
	if Selection.Last then
		self:showHandles( Selection.Last );
	end;

	-- Update the GUI regularly
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

			end;

		end;

	end )();

end;

Tools.Resize.Listeners.Unequipped = function ()

	local self = Tools.Resize;

	-- Stop the update loop
	if self.Updater then
		self.Updater();
		self.Updater = nil;
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

Tools.Resize.Listeners.KeyUp = function ( Key )
	local self = Tools.Resize;

	-- Provide a keyboard shortcut to the increment input
	if Key == '-' and self.GUI then
		self.GUI.IncrementOption.Increment.TextBox:CaptureFocus();
	end;
end;

Tools.Resize.showGUI = function ( self )

	-- Initialize the GUI if it's not ready yet
	if not self.GUI then

		local Container = Tool.Interfaces.BTResizeToolGUI:Clone();
		Container.Parent = UI;

		-- Change the axis type option when the button is clicked
		Container.DirectionsOption.Normal.Button.MouseButton1Down:connect( function ()
			self.Options.directions = "normal";
			Container.DirectionsOption.Normal.SelectedIndicator.BackgroundTransparency = 0;
			Container.DirectionsOption.Normal.Background.Image = Assets.DarkSlantedRectangle;
			Container.DirectionsOption.Both.SelectedIndicator.BackgroundTransparency = 1;
			Container.DirectionsOption.Both.Background.Image = Assets.LightSlantedRectangle;
		end );

		Container.DirectionsOption.Both.Button.MouseButton1Down:connect( function ()
			self.Options.directions = "both";
			Container.DirectionsOption.Normal.SelectedIndicator.BackgroundTransparency = 1;
			Container.DirectionsOption.Normal.Background.Image = Assets.LightSlantedRectangle;
			Container.DirectionsOption.Both.SelectedIndicator.BackgroundTransparency = 0;
			Container.DirectionsOption.Both.Background.Image = Assets.DarkSlantedRectangle;
		end );

		-- Change the increment option when the value of the textbox is updated
		Container.IncrementOption.Increment.TextBox.FocusLost:connect( function ( enter_pressed )
			self.Options.increment = tonumber( Container.IncrementOption.Increment.TextBox.Text ) or self.Options.increment;
			Container.IncrementOption.Increment.TextBox.Text = tostring( self.Options.increment );
		end );

		-- Add functionality to the size inputs
		Container.Info.SizeInfo.X.TextButton.MouseButton1Down:connect( function ()
			self.State.size_x_focused = true;
			Container.Info.SizeInfo.X.TextBox:CaptureFocus();
		end );
		Container.Info.SizeInfo.X.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( Container.Info.SizeInfo.X.TextBox.Text );
			if potential_new then
				self:changeSize( 'x', potential_new );
			end;
			self.State.size_x_focused = false;
		end );
		Container.Info.SizeInfo.Y.TextButton.MouseButton1Down:connect( function ()
			self.State.size_y_focused = true;
			Container.Info.SizeInfo.Y.TextBox:CaptureFocus();
		end );
		Container.Info.SizeInfo.Y.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( Container.Info.SizeInfo.Y.TextBox.Text );
			if potential_new then
				self:changeSize( 'y', potential_new );
			end;
			self.State.size_y_focused = false;
		end );
		Container.Info.SizeInfo.Z.TextButton.MouseButton1Down:connect( function ()
			self.State.size_z_focused = true;
			Container.Info.SizeInfo.Z.TextBox:CaptureFocus();
		end );
		Container.Info.SizeInfo.Z.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( Container.Info.SizeInfo.Z.TextBox.Text );
			if potential_new then
				self:changeSize( 'z', potential_new );
			end;
			self.State.size_z_focused = false;
		end );

		self.GUI = Container;
	end;

	-- Reveal the GUI
	self.GUI.Visible = true;

end;

Tools.Resize.startHistoryRecord = function ( self )

	if self.State.HistoryRecord then
		self.State.HistoryRecord = nil;
	end;

	-- Create a history record
	self.State.HistoryRecord = {
		targets = Support.CloneTable(Selection.Items);
		initial_positions = {};
		terminal_positions = {};
		initial_sizes = {};
		terminal_sizes = {};
		Unapply = function ( self )
			Selection:clear();
			for _, Target in pairs( self.targets ) do
				if Target then
					Target.Size = self.initial_sizes[Target];
					Target.CFrame = self.initial_positions[Target];
					Target:MakeJoints();
					Selection:add( Target );
				end;
			end;
		end;
		Apply = function ( self )
			Selection:clear();
			for _, Target in pairs( self.targets ) do
				if Target then
					Target.Size = self.terminal_sizes[Target];
					Target.CFrame = self.terminal_positions[Target];
					Target:MakeJoints();
					Selection:add( Target );
				end;
			end;
		end;
	};
	for _, Item in pairs( self.State.HistoryRecord.targets ) do
		if Item then
			self.State.HistoryRecord.initial_sizes[Item] = Item.Size;
			self.State.HistoryRecord.initial_positions[Item] = Item.CFrame;
		end;
	end;

end;

Tools.Resize.finishHistoryRecord = function ( self )

	if not self.State.HistoryRecord then
		return;
	end;

	for _, Item in pairs( self.State.HistoryRecord.targets ) do
		if Item then
			self.State.HistoryRecord.terminal_sizes[Item] = Item.Size;
			self.State.HistoryRecord.terminal_positions[Item] = Item.CFrame;
		end;
	end;
	History:Add( self.State.HistoryRecord );
	self.State.HistoryRecord = nil;

end;

Tools.Resize.changeSize = function ( self, component, new_value )

	self:startHistoryRecord();

	-- Change the size of each item selected
	for _, Item in pairs( Selection.Items ) do
		local OldCFrame = Item.CFrame;
		-- Make the item be able to be freely resized
		if ( pcall( function () local test = Item.FormFactor; end ) ) then
			Item.FormFactor = Enum.FormFactor.Custom;
		end;
		Item.Size = Vector3.new(
			component == 'x' and new_value or Item.Size.x,
			component == 'y' and new_value or Item.Size.y,
			component == 'z' and new_value or Item.Size.z
		);
		Item.CFrame = OldCFrame;
	end;

	self:finishHistoryRecord();

end;

Tools.Resize.updateGUI = function ( self )

	-- Make sure the GUI exists
	if not self.GUI then
		return;
	end;

	local GUI = self.GUI;

	if #Selection.Items > 0 then

		-- Look for identical numbers in each axis
		local size_x, size_y, size_z =  nil, nil, nil;
		for item_index, Item in pairs( Selection.Items ) do

			-- Set the first values for the first item
			if item_index == 1 then
				size_x, size_y, size_z = Support.Round(Item.Size.x, 2), Support.Round(Item.Size.y, 2), Support.Round(Item.Size.z, 2);

			-- Otherwise, compare them and set them to `nil` if they're not identical
			else
				if size_x ~= Support.Round(Item.Size.x, 2) then
					size_x = nil;
				end;
				if size_y ~= Support.Round(Item.Size.y, 2) then
					size_y = nil;
				end;
				if size_z ~= Support.Round(Item.Size.z, 2) then
					size_z = nil;
				end;
			end;

		end;

		-- Update the size info on the GUI
		if not self.State.size_x_focused then
			GUI.Info.SizeInfo.X.TextBox.Text = size_x and tostring( size_x ) or "*";
		end;
		if not self.State.size_y_focused then
			GUI.Info.SizeInfo.Y.TextBox.Text = size_y and tostring( size_y ) or "*";
		end;
		if not self.State.size_z_focused then
			GUI.Info.SizeInfo.Z.TextBox.Text = size_z and tostring( size_z ) or "*";
		end;

		GUI.Info.Visible = true;
	else
		GUI.Info.Visible = false;
	end;

	if self.State.length_resized then
		GUI.Changes.Text.Text = "resized " .. tostring( self.State.length_resized ) .. " studs";
		GUI.Changes.Position = GUI.Info.Visible and UDim2.new( 0, 5, 0, 165 ) or UDim2.new( 0, 5, 0, 100 );
		GUI.Changes.Visible = true;
	else
		GUI.Changes.Text.Text = "";
		GUI.Changes.Visible = false;
	end;

end;

Tools.Resize.hideGUI = function ( self )

	-- Hide the GUI if it exists
	if self.GUI then
		self.GUI.Visible = false;
	end;

end;

Tools.Resize.showHandles = function ( self, Part )

	-- Create the handles if they don't exist yet
	if not self.Handles then

		-- Create the object
		self.Handles = RbxUtility.Create "Handles" {
			Name = "BTResizeHandles";
			Style = Enum.HandlesStyle.Resize;
			Color = self.Color;
			Parent = GUIContainer;
		};

		-- Add functionality to the handles
		self.Handles.MouseButton1Down:connect( function ()

			-- Prevent the platform from thinking we're selecting
			override_selection = true;
			self.State.resizing = true;

			-- Clear the change stats
			self.State.length_resized = 0;

			self:startHistoryRecord();

			-- Do a few things to the selection before manipulating it
			for _, Item in pairs( Selection.Items ) do

				-- Keep a copy of the state of each item
				self.State.PreResize[Item] = Item:Clone();

				-- Make the item be able to be freely resized
				if ( pcall( function () local test = Item.FormFactor; end ) ) then
					Item.FormFactor = Enum.FormFactor.Custom;
				end;

				-- Anchor each item
				Item.Anchored = true;

			end;

			-- Return stuff to normal once the mouse button is released
			self.Connections.HandleReleaseListener = Mouse.Button1Up:connect( function ()

				-- Prevent the platform from thinking we're selecting
				override_selection = true;
				self.State.resizing = false;

				-- Stop this connection from firing again
				if self.Connections.HandleReleaseListener then
					self.Connections.HandleReleaseListener:disconnect();
					self.Connections.HandleReleaseListener = nil;
				end;

				self:finishHistoryRecord();

				-- Restore properties that may have been changed temporarily
				-- from the pre-resize state copies
				for Item, PreviousItemState in pairs( self.State.PreResize ) do
					Item.Anchored = PreviousItemState.Anchored;
					self.State.PreResize[Item] = nil;
					Item:MakeJoints();
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

			-- Log the distance that the handle was dragged
			self.State.previous_distance = drag_distance;

			-- Note the length by which the selection will be enlarged
			if self.Options.directions == "both" then
				increase = drag_distance * 2;
			end;
			self.State.length_resized = increase;

			-- Go through the selection and make changes to it
			for _, Item in pairs( Selection.Items ) do

				-- Keep a copy of `Item` in case we need to revert anything
				local PreviousItemState = Item:Clone();

				-- Break any of `Item`'s joints so it can move freely
				Item:BreakJoints();

				-- Position and resize `Item` according to the options and the handle that was used

				if face == Enum.NormalId.Top then

					-- Calculate the appropriate increment to the size based on the shape of `Item`
					local SizeIncrease;
					if ( pcall( function () local test = Item.Shape; end ) ) and ( Item.Shape == Enum.PartType.Ball or Item.Shape == Enum.PartType.Cylinder ) then
						SizeIncrease = Vector3.new( increase, increase, increase );
					elseif not ( pcall( function () local test = Item.Shape; end ) ) or ( Item.Shape and Item.Shape == Enum.PartType.Block ) then
						SizeIncrease = Vector3.new( 0, increase, 0 );
					end;

					Item.Size = self.State.PreResize[Item].Size + SizeIncrease;
					if Item.Size == self.State.PreResize[Item].Size + SizeIncrease then
						Item.CFrame = ( self.Options.directions == "normal" and self.State.PreResize[Item].CFrame:toWorldSpace( CFrame.new( 0, increase / 2, 0 ) ) )
									  or ( self.Options.directions == "both" and self.State.PreResize[Item].CFrame );
					-- If the resizing was not possible, revert `Item`'s state
					else
						Item.Size = PreviousItemState.Size;
						Item.CFrame = PreviousItemState.CFrame;
					end;

				elseif face == Enum.NormalId.Bottom then

					-- Calculate the appropriate increment to the size based on the shape of `Item`
					local SizeIncrease;
					if ( pcall( function () local test = Item.Shape; end ) ) and ( Item.Shape == Enum.PartType.Ball or Item.Shape == Enum.PartType.Cylinder ) then
						SizeIncrease = Vector3.new( increase, increase, increase );
					elseif not ( pcall( function () local test = Item.Shape; end ) ) or ( Item.Shape and Item.Shape == Enum.PartType.Block ) then
						SizeIncrease = Vector3.new( 0, increase, 0 );
					end;

					Item.Size = self.State.PreResize[Item].Size + SizeIncrease;
					if Item.Size == self.State.PreResize[Item].Size + SizeIncrease then
						Item.CFrame = ( self.Options.directions == "normal" and self.State.PreResize[Item].CFrame:toWorldSpace( CFrame.new( 0, -increase / 2, 0 ) ) )
									  or ( self.Options.directions == "both" and self.State.PreResize[Item].CFrame );
					-- If the resizing was not possible, revert `Item`'s state
					else
						Item.Size = PreviousItemState.Size;
						Item.CFrame = PreviousItemState.CFrame;
					end;

				elseif face == Enum.NormalId.Front then

					-- Calculate the appropriate increment to the size based on the shape of `Item`
					local SizeIncrease;
					if ( pcall( function () local test = Item.Shape; end ) ) and ( Item.Shape == Enum.PartType.Ball or Item.Shape == Enum.PartType.Cylinder ) then
						SizeIncrease = Vector3.new( increase, increase, increase );
					elseif not ( pcall( function () local test = Item.Shape; end ) ) or ( Item.Shape and Item.Shape == Enum.PartType.Block ) then
						SizeIncrease = Vector3.new( 0, 0, increase );
					end;

					Item.Size = self.State.PreResize[Item].Size + SizeIncrease;
					if Item.Size == self.State.PreResize[Item].Size + SizeIncrease then
						Item.CFrame = ( self.Options.directions == "normal" and self.State.PreResize[Item].CFrame:toWorldSpace( CFrame.new( 0, 0, -increase / 2 ) ) )
									  or ( self.Options.directions == "both" and self.State.PreResize[Item].CFrame );
					-- If the resizing was not possible, revert `Item`'s state
					else
						Item.Size = PreviousItemState.Size;
						Item.CFrame = PreviousItemState.CFrame;
					end;

				elseif face == Enum.NormalId.Back then

					-- Calculate the appropriate increment to the size based on the shape of `Item`
					local SizeIncrease;
					if ( pcall( function () local test = Item.Shape; end ) ) and ( Item.Shape == Enum.PartType.Ball or Item.Shape == Enum.PartType.Cylinder ) then
						SizeIncrease = Vector3.new( increase, increase, increase );
					elseif not ( pcall( function () local test = Item.Shape; end ) ) or ( Item.Shape and Item.Shape == Enum.PartType.Block ) then
						SizeIncrease = Vector3.new( 0, 0, increase );
					end;

					Item.Size = self.State.PreResize[Item].Size + SizeIncrease;
					if Item.Size == self.State.PreResize[Item].Size + SizeIncrease then
						Item.CFrame = ( self.Options.directions == "normal" and self.State.PreResize[Item].CFrame:toWorldSpace( CFrame.new( 0, 0, increase / 2 ) ) )
									  or ( self.Options.directions == "both" and self.State.PreResize[Item].CFrame );
					-- If the resizing was not possible, revert `Item`'s state
					else
						Item.Size = PreviousItemState.Size;
						Item.CFrame = PreviousItemState.CFrame;
					end;

				elseif face == Enum.NormalId.Left then

					-- Calculate the appropriate increment to the size based on the shape of `Item`
					local SizeIncrease;
					if ( pcall( function () local test = Item.Shape; end ) ) and ( Item.Shape == Enum.PartType.Ball or Item.Shape == Enum.PartType.Cylinder ) then
						SizeIncrease = Vector3.new( increase, increase, increase );
					elseif not ( pcall( function () local test = Item.Shape; end ) ) or ( Item.Shape and Item.Shape == Enum.PartType.Block ) then
						SizeIncrease = Vector3.new( increase, 0, 0 );
					end;

					Item.Size = self.State.PreResize[Item].Size + SizeIncrease;
					if Item.Size == self.State.PreResize[Item].Size + SizeIncrease then
						Item.CFrame = ( self.Options.directions == "normal" and self.State.PreResize[Item].CFrame:toWorldSpace( CFrame.new( -increase / 2, 0, 0 ) ) )
									  or ( self.Options.directions == "both" and self.State.PreResize[Item].CFrame );
					-- If the resizing was not possible, revert `Item`'s state
					else
						Item.Size = PreviousItemState.Size;
						Item.CFrame = PreviousItemState.CFrame;
					end;

				elseif face == Enum.NormalId.Right then

					-- Calculate the appropriate increment to the size based on the shape of `Item`
					local SizeIncrease;
					if ( pcall( function () local test = Item.Shape; end ) ) and ( Item.Shape == Enum.PartType.Ball or Item.Shape == Enum.PartType.Cylinder ) then
						SizeIncrease = Vector3.new( increase, increase, increase );
					elseif not ( pcall( function () local test = Item.Shape; end ) ) or ( Item.Shape and Item.Shape == Enum.PartType.Block ) then
						SizeIncrease = Vector3.new( increase, 0, 0 );
					end;

					Item.Size = self.State.PreResize[Item].Size + SizeIncrease;
					if Item.Size == self.State.PreResize[Item].Size + SizeIncrease then
						Item.CFrame = ( self.Options.directions == "normal" and self.State.PreResize[Item].CFrame:toWorldSpace( CFrame.new( increase / 2, 0, 0 ) ) )
									  or ( self.Options.directions == "both" and self.State.PreResize[Item].CFrame );
					-- If the resizing was not possible, revert `Item`'s state
					else
						Item.Size = PreviousItemState.Size;
						Item.CFrame = PreviousItemState.CFrame;
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

Tools.Resize.hideHandles = function ( self )

	-- Hide the handles if they exist
	if self.Handles then
		self.Handles.Adornee = nil;
	end;

end;

Tools.Resize.Loaded = true;