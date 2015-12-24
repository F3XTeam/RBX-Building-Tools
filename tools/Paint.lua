-- Load the main tool's core environment when it's ready
repeat wait() until (
	_G.BTCoreEnv and
	_G.BTCoreEnv[script.Parent.Parent] and
	_G.BTCoreEnv[script.Parent.Parent].CoreReady
);
setfenv( 1, _G.BTCoreEnv[script.Parent.Parent] );

------------------------------------------
-- Paint tool
------------------------------------------

-- Create the main container for this tool
Tools.Paint = {};
Tools.Paint.Name = 'Paint Tool';

-- Define the color of the tool
Tools.Paint.Color = BrickColor.new( "Really red" );

-- Define options
Tools.Paint.Options = {
	["Color"] = nil
};

Tools.Paint.State = {};

-- Add listeners
Tools.Paint.Listeners = {};

Tools.Paint.Listeners.Equipped = function ()

	local self = Tools.Paint;

	-- Change the color of selection boxes temporarily
	self.State.PreviousSelectionBoxColor = SelectionBoxColor;
	SelectionBoxColor = self.Color;
	updateSelectionBoxColor();

	-- Show the GUI
	self:showGUI();

	-- Update the selected color
	self:changeColor( self.Options.Color );

end;

Tools.Paint.Listeners.Unequipped = function ()

	local self = Tools.Paint;

	-- Clear out the preferred color option
	self:changeColor( nil );

	-- Hide the GUI
	self:hideGUI();

	-- Restore the original color of the selection boxes
	SelectionBoxColor = self.State.PreviousSelectionBoxColor;
	updateSelectionBoxColor();

end;

Tools.Paint.startHistoryRecord = function ( self )

	if self.State.HistoryRecord then
		self.State.HistoryRecord = nil;
	end;

	-- Create a history record
	self.State.HistoryRecord = {
		targets = Support.CloneTable(Selection.Items);
		initial_colors = {};
		terminal_colors = {};
		Unapply = function ( self )
			Selection:clear();
			for _, Target in pairs( self.targets ) do
				if Target then
					Change(Target, {
						BrickColor = self.initial_colors[Target];
					});
					Selection:add( Target );
				end;
			end;
		end;
		Apply = function ( self )
			Selection:clear();
			for _, Target in pairs( self.targets ) do
				if Target then
					Change(Target, {
						BrickColor = self.terminal_colors[Target];
					});
					Selection:add( Target );
				end;
			end;
		end;
	};
	for _, Item in pairs( self.State.HistoryRecord.targets ) do
		if Item then
			self.State.HistoryRecord.initial_colors[Item] = Item.BrickColor;
		end;
	end;

end;

Tools.Paint.finishHistoryRecord = function ( self )

	if not self.State.HistoryRecord then
		return;
	end;

	for _, Item in pairs( self.State.HistoryRecord.targets ) do
		if Item then
			self.State.HistoryRecord.terminal_colors[Item] = Item.BrickColor;
		end;
	end;
	History:Add( self.State.HistoryRecord );
	self.State.HistoryRecord = nil;

end;

Tools.Paint.Listeners.Button1Up = function ()

	local self = Tools.Paint;

	-- Make sure that they clicked on one of the items in their selection
	-- (and they weren't multi-selecting)
	if Selection:find( Mouse.Target ) and not selecting and not selecting then

		override_selection = true;

		self:startHistoryRecord();

		-- Paint all of the selected items `Tools.Paint.Options.Color`
		if self.Options.Color then
			for _, Item in pairs( Selection.Items ) do
				Change(Item, {
					BrickColor = self.Options.Color;
				});
			end;
		end;

		self:finishHistoryRecord();

	end;

end;

Tools.Paint.changeColor = function ( self, Color )

	-- Alright so if `Color` is given, set that as the preferred color
	if Color then

		-- First of all, change the color option itself
		self.Options.Color = Color;

		self:startHistoryRecord();

		-- Then, we want to update the color of any items in the selection
		for _, Item in pairs( Selection.Items ) do
			Change(Item, {
				BrickColor = Color;
			});
		end;

		self:finishHistoryRecord();

		-- After that, we want to mark our new color in the palette
		if self.GUI then

			-- First clear out any other marks
			for _, ColorSquare in pairs( self.GUI.Palette:GetChildren() ) do
				ColorSquare.Text = "";
			end;

			-- Then mark the right square
			self.GUI.Palette[Color.Name].Text = "X";

		end;

	-- Otherwise, let's assume no color at all
	else

		-- Set the preferred color to none
		self.Options.Color = nil;

		-- Clear out any color option marks on any of the squares
		if self.GUI then
			for _, ColorSquare in pairs( self.GUI.Palette:GetChildren() ) do
				ColorSquare.Text = "";
			end;
		end;

	end;

end;

Tools.Paint.showGUI = function ( self )

	-- Initialize the GUI if it's not ready yet
	if not self.GUI then

		local Container = Tool.Interfaces.BTPaintToolGUI:Clone();
		Container.Parent = UI;

		for _, ColorButton in pairs( Container.Palette:GetChildren() ) do
			ColorButton.MouseButton1Click:connect( function ()
				self:changeColor( BrickColor.new( ColorButton.Name ) );
			end );
		end;

		self.GUI = Container;
	end;

	-- Reveal the GUI
	self.GUI.Visible = true;

end;

Tools.Paint.hideGUI = function ( self )

	-- Hide the GUI if it exists
	if self.GUI then
		self.GUI.Visible = false;
	end;

end;

Tools.Paint.Loaded = true;