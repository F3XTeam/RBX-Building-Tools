-- Load the main tool's core environment when it's ready
repeat wait() until (
	_G.BTCoreEnv and
	_G.BTCoreEnv[script.Parent.Parent] and
	_G.BTCoreEnv[script.Parent.Parent].CoreReady
);
setfenv( 1, _G.BTCoreEnv[script.Parent.Parent] );

------------------------------------------
-- Collision tool
------------------------------------------

-- Create the tool
Tools.Collision = {};
Tools.Collision.Name = 'Collision Tool';

-- Create structures to hold data that the tool needs
Tools.Collision.Connections = {};

Tools.Collision.State = {
	["colliding"] = nil;
};

Tools.Collision.Listeners = {};

-- Define the color of the tool
Tools.Collision.Color = BrickColor.new( "Really black" );

-- Start adding functionality to the tool
Tools.Collision.Listeners.Equipped = function ()

	local self = Tools.Collision;

	-- Change the color of selection boxes temporarily
	self.State.PreviousSelectionBoxColor = SelectionBoxColor;
	SelectionBoxColor = self.Color;
	updateSelectionBoxColor();

	-- Reveal the GUI
	self:showGUI();

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

				-- Update the collision status of every item in the selection
				local colliding = nil;
				for item_index, Item in pairs( Selection.Items ) do

					-- Set the first values for the first item
					if item_index == 1 then
						colliding = Item.CanCollide;

					-- Otherwise, compare them and set them to `nil` if they're not identical
					else
						if colliding ~= Item.CanCollide then
							colliding = nil;
						end;
					end;

				end;

				self.State.colliding = colliding;

				-- Update the GUI if it's visible
				if self.GUI and self.GUI.Visible then
					self:updateGUI();
				end;

			end;

		end;

	end )();

	-- Listen for the Enter button to be pressed to toggle collision
	self.Connections.EnterButtonListener = Mouse.KeyDown:connect( function ( key )

		local key = key:lower();
		local key_code = key:byte();

		-- If the Enter button is pressed
		if key_code == 13 then

			if self.State.colliding == true then
				self:disable();

			elseif self.State.colliding == false then
				self:enable();

			elseif self.State.colliding == nil then
				self:enable();

			end;

		end;

	end );

end;

Tools.Collision.startHistoryRecord = function ( self )

	if self.State.HistoryRecord then
		self.State.HistoryRecord = nil;
	end;

	-- Create a history record
	self.State.HistoryRecord = {
		targets = Support.CloneTable(Selection.Items);
		initial_collide = {};
		terminal_collide = {};
		initial_cframe = {};
		terminal_cframe = {};
		Unapply = function ( self )
			Selection:clear();
			for _, Target in pairs( self.targets ) do
				if Target then
					Change(Target, {
						CanCollide = self.initial_collide[Target];
						CFrame = self.initial_cframe[Target];
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
						CanCollide = self.terminal_collide[Target];
						CFrame = self.terminal_cframe[Target];
					});
					MakeJoints(Target);
					Selection:add(Target);
				end;
			end;
		end;
	};
	for _, Item in pairs( self.State.HistoryRecord.targets ) do
		if Item then
			self.State.HistoryRecord.initial_collide[Item] = Item.CanCollide;
			self.State.HistoryRecord.initial_cframe[Item] = Item.CFrame;
		end;
	end;

end;

Tools.Collision.finishHistoryRecord = function ( self )

	if not self.State.HistoryRecord then
		return;
	end;

	for _, Item in pairs( self.State.HistoryRecord.targets ) do
		if Item then
			self.State.HistoryRecord.terminal_collide[Item] = Item.CanCollide;
			self.State.HistoryRecord.terminal_cframe[Item] = Item.CFrame;
		end;
	end;
	History:Add( self.State.HistoryRecord );
	self.State.HistoryRecord = nil;

end;

Tools.Collision.enable = function ( self )

	self:startHistoryRecord();

	-- Enable collision for all the items in the selection
	for _, Item in pairs( Selection.Items ) do
		Change(Item, {
			CanCollide = true;
		});
		MakeJoints(Item);
	end;

	self:finishHistoryRecord();

end;

Tools.Collision.disable = function ( self )

	self:startHistoryRecord();

	-- Disable collision for all the items in the selection
	for _, Item in pairs( Selection.Items ) do
		Change(Item, {
			CanCollide = false;
		});
		MakeJoints(Item);
	end;

	self:finishHistoryRecord();

end;

Tools.Collision.showGUI = function ( self )

	-- Initialize the GUI if it's not ready yet
	if not self.GUI then

		local Container = Tool.Interfaces.BTCollisionToolGUI:Clone();
		Container.Parent = UI;

		Container.Status.On.Button.MouseButton1Down:connect( function ()
			self:enable();
		end );

		Container.Status.Off.Button.MouseButton1Down:connect( function ()
			self:disable();
		end );

		self.GUI = Container;
	end;

	-- Reveal the GUI
	self.GUI.Visible = true;

end;

Tools.Collision.updateGUI = function ( self )

	-- Make sure the GUI exists
	if not self.GUI then
		return;
	end;

	local GUI = self.GUI;

	if self.State.colliding == nil then
		GUI.Status.On.Background.Image = Assets.LightSlantedRectangle;
		GUI.Status.On.SelectedIndicator.BackgroundTransparency = 1;
		GUI.Status.Off.Background.Image = Assets.LightSlantedRectangle;
		GUI.Status.Off.SelectedIndicator.BackgroundTransparency = 1;

	elseif self.State.colliding == true then
		GUI.Status.On.Background.Image = Assets.DarkSlantedRectangle;
		GUI.Status.On.SelectedIndicator.BackgroundTransparency = 0;
		GUI.Status.Off.Background.Image = Assets.LightSlantedRectangle;
		GUI.Status.Off.SelectedIndicator.BackgroundTransparency = 1;

	elseif self.State.colliding == false then
		GUI.Status.On.Background.Image = Assets.LightSlantedRectangle;
		GUI.Status.On.SelectedIndicator.BackgroundTransparency = 1;
		GUI.Status.Off.Background.Image = Assets.DarkSlantedRectangle;
		GUI.Status.Off.SelectedIndicator.BackgroundTransparency = 0;

	end;

end;

Tools.Collision.hideGUI = function ( self )

	-- Hide the GUI if it exists
	if self.GUI then
		self.GUI.Visible = false;
	end;

end;

Tools.Collision.Listeners.Unequipped = function ()

	local self = Tools.Collision;

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

Tools.Collision.Loaded = true;