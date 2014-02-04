-- Load the main tool's core environment when it's ready
repeat wait() until (
	_G.BTCoreEnv and
	_G.BTCoreEnv[script.Parent.Parent] and
	_G.BTCoreEnv[script.Parent.Parent].CoreReady
);
setfenv( 1, _G.BTCoreEnv[script.Parent.Parent] );

------------------------------------------
-- Anchor tool
------------------------------------------

-- Create the tool
Tools.Anchor = {};

-- Create structures to hold data that the tool needs
Tools.Anchor.Connections = {};

Tools.Anchor.State = {
	["anchored"] = nil;
};

Tools.Anchor.Listeners = {};

-- Define the color of the tool
Tools.Anchor.Color = BrickColor.new( "Really black" );

-- Start adding functionality to the tool
Tools.Anchor.Listeners.Equipped = function ()

	local self = Tools.Anchor;

	-- Change the color of selection boxes temporarily
	self.State.PreviousSelectionBoxColor = SelectionBoxColor;
	SelectionBoxColor = self.Color;
	updateSelectionBoxColor();

	-- Reveal the GUI
	self:showGUI();

	-- Update the GUI regularly
	coroutine.wrap( function ()
		local updater_on = true;

		-- Provide a function to stop the loop
		self.Updater = function ()
			updater_on = false;
		end;

		while wait( 0.1 ) and updater_on do

			-- Make sure the tool's equipped
			if CurrentTool == self then

				-- Update the anchor status of every item in the selection
				local anchor_status = nil;
				for item_index, Item in pairs( Selection.Items ) do

					-- Set the first values for the first item
					if item_index == 1 then
						anchor_status = Item.Anchored;

					-- Otherwise, compare them and set them to `nil` if they're not identical
					else
						if anchor_status ~= Item.Anchored then
							anchor_status = nil;
						end;
					end;

				end;

				self.State.anchored = anchor_status;

				-- Update the GUI if it's visible
				if self.GUI and self.GUI.Visible then
					self:updateGUI();
				end;

			end;

		end;

	end )();

	-- Listen for the Enter button to be pressed to toggle the anchor
	self.Connections.EnterButtonListener = Mouse.KeyDown:connect( function ( key )

		local key = key:lower();
		local key_code = key:byte();

		-- If the Enter button is pressed
		if key_code == 13 then

			if self.State.anchored == true then
				self:unanchor();

			elseif self.State.anchored == false then
				self:anchor();

			elseif self.State.anchored == nil then
				self:anchor();

			end;

		end;

	end );

end;


Tools.Anchor.startHistoryRecord = function ( self )

	if self.State.HistoryRecord then
		self.State.HistoryRecord = nil;
	end;

	-- Create a history record
	self.State.HistoryRecord = {
		targets = _cloneTable( Selection.Items );
		initial_positions = {};
		terminal_positions = {};
		initial_anchors = {};
		terminal_anchors = {};
		unapply = function ( self )
			Selection:clear();
			for _, Target in pairs( self.targets ) do
				if Target then
					Target.RotVelocity = Vector3.new( 0, 0, 0 );
					Target.Velocity = Vector3.new( 0, 0, 0 );
					Target.CFrame = self.initial_positions[Target];
					Target.Anchored = self.initial_anchors[Target];
					Target:MakeJoints();
					Selection:add( Target );
				end;
			end;
		end;
		apply = function ( self )
			Selection:clear();
			for _, Target in pairs( self.targets ) do
				if Target then
					Target.RotVelocity = Vector3.new( 0, 0, 0 );
					Target.Velocity = Vector3.new( 0, 0, 0 );
					Target.CFrame = self.terminal_positions[Target];
					Target.Anchored = self.terminal_anchors[Target];
					Target:MakeJoints();
					Selection:add( Target );
				end;
			end;
		end;
	};
	for _, Item in pairs( self.State.HistoryRecord.targets ) do
		if Item then
			self.State.HistoryRecord.initial_anchors[Item] = Item.Anchored;
			self.State.HistoryRecord.initial_positions[Item] = Item.CFrame;
		end;
	end;

end;

Tools.Anchor.finishHistoryRecord = function ( self )

	if not self.State.HistoryRecord then
		return;
	end;

	for _, Item in pairs( self.State.HistoryRecord.targets ) do
		if Item then
			self.State.HistoryRecord.terminal_anchors[Item] = Item.Anchored;
			self.State.HistoryRecord.terminal_positions[Item] = Item.CFrame;
		end;
	end;
	History:add( self.State.HistoryRecord );
	self.State.HistoryRecord = nil;

end;

Tools.Anchor.anchor = function ( self )

	self:startHistoryRecord();

	-- Anchor all the items in the selection
	for _, Item in pairs( Selection.Items ) do
		Item.Anchored = true;
		Item:MakeJoints();
	end;

	self:finishHistoryRecord();

end;

Tools.Anchor.unanchor = function ( self )

	self:startHistoryRecord();

	-- Unanchor all the items in the selection
	for _, Item in pairs( Selection.Items ) do
		Item.Anchored = false;
		Item.Velocity = Vector3.new( 0, 0, 0 );
		Item.RotVelocity = Vector3.new( 0, 0, 0 );
		Item:MakeJoints();
	end;

	self:finishHistoryRecord();

end;

Tools.Anchor.showGUI = function ( self )

	-- Initialize the GUI if it's not ready yet
	if not self.GUI then

		local Container = Tool.Interfaces:WaitForChild( "BTAnchorToolGUI" ):Clone();
		Container.Parent = UI;

		-- Change the anchor status when the button is clicked
		Container.Status.Anchored.Button.MouseButton1Down:connect( function ()
			self:anchor();
		end );

		Container.Status.Unanchored.Button.MouseButton1Down:connect( function ()
			self:unanchor();
		end );

		self.GUI = Container;
	end;

	-- Reveal the GUI
	self.GUI.Visible = true;

end;

Tools.Anchor.updateGUI = function ( self )

	-- Make sure the GUI exists
	if not self.GUI then
		return;
	end;

	local GUI = self.GUI;

	if self.State.anchored == nil then
		GUI.Status.Anchored.Background.Image = light_slanted_rectangle;
		GUI.Status.Anchored.SelectedIndicator.BackgroundTransparency = 1;
		GUI.Status.Unanchored.Background.Image = light_slanted_rectangle;
		GUI.Status.Unanchored.SelectedIndicator.BackgroundTransparency = 1;

	elseif self.State.anchored == true then
		GUI.Status.Anchored.Background.Image = dark_slanted_rectangle;
		GUI.Status.Anchored.SelectedIndicator.BackgroundTransparency = 0;
		GUI.Status.Unanchored.Background.Image = light_slanted_rectangle;
		GUI.Status.Unanchored.SelectedIndicator.BackgroundTransparency = 1;

	elseif self.State.anchored == false then
		GUI.Status.Anchored.Background.Image = light_slanted_rectangle;
		GUI.Status.Anchored.SelectedIndicator.BackgroundTransparency = 1;
		GUI.Status.Unanchored.Background.Image = dark_slanted_rectangle;
		GUI.Status.Unanchored.SelectedIndicator.BackgroundTransparency = 0;

	end;

end;

Tools.Anchor.hideGUI = function ( self )

	-- Hide the GUI if it exists
	if self.GUI then
		self.GUI.Visible = false;
	end;

end;

Tools.Anchor.Listeners.Unequipped = function ()

	local self = Tools.Anchor;

	-- Stop the update loop
	if self.Updater then
		self.Updater();
		self.Updater = nil;
	end;

	-- Hide the GUI
	self:hideGUI();

	-- Clear out any temporary connections
	for connection_index, Connection in pairs( self.Connections ) do
		Connection:disconnect();
		self.Connections[connection_index] = nil;
	end;

	-- Restore the original color of the selection boxes
	SelectionBoxColor = self.State.PreviousSelectionBoxColor;
	updateSelectionBoxColor();

end;

Tools.Anchor.Loaded = true;