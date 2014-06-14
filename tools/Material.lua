-- Load the main tool's core environment when it's ready
repeat wait() until (
	_G.BTCoreEnv and
	_G.BTCoreEnv[script.Parent.Parent] and
	_G.BTCoreEnv[script.Parent.Parent].CoreReady
);
setfenv( 1, _G.BTCoreEnv[script.Parent.Parent] );

------------------------------------------
-- Material tool
------------------------------------------

-- Create the tool
Tools.Material = {};
Tools.Material.Color = BrickColor.new( "Bright violet" );
Tools.Material.Connections = {};
Tools.Material.State = {
	["material"] = nil;
	["reflectance_focused"] = false;
	["transparency_focused"] = false;
};
Tools.Material.Listeners = {};
Tools.Material.SpecialMaterialNames = {
	CorrodedMetal = "CORRODED METAL",
	DiamondPlate = "DIAMOND PLATE",
	SmoothPlastic = "SMOOTH PLASTIC"
};

-- Start adding functionality to the tool
Tools.Material.Listeners.Equipped = function ()

	local self = Tools.Material;

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

				-- Update the material type of every item in the selection
				local material_type, transparency, reflectance = nil, nil, nil;
				for item_index, Item in pairs( Selection.Items ) do

					-- Set the first values for the first item
					if item_index == 1 then
						material_type = Item.Material;
						transparency = Item.Transparency;
						reflectance = Item.Reflectance;

					-- Otherwise, compare them and set them to `nil` if they're not identical
					else
						if material_type ~= Item.Material then
							material_type = nil;
						end;
						if reflectance ~= Item.Reflectance then
							reflectance = nil;
						end;
						if transparency ~= Item.Transparency then
							transparency = nil;
						end;
					end;

				end;

				self.State.material = material_type;
				self.State.transparency = transparency;
				self.State.reflectance = reflectance;

				-- Update the GUI if it's visible
				if self.GUI and self.GUI.Visible then
					self:updateGUI();
				end;

			end;

		end;

	end )();

end;

Tools.Material.Listeners.Unequipped = function ()

	local self = Tools.Material;

	-- Stop the GUI updating loop
	if self.Updater then
		self.Updater();
		self.Updater = nil;
	end;

	-- Hide the GUI
	self:hideGUI();

	-- Disconnect temporary connections
	for connection_index, Connection in pairs( self.Connections ) do
		Connection:disconnect();
		self.Connections[connection_index] = nil;
	end;

	-- Restore the original color of selection boxes
	SelectionBoxColor = self.State.PreviousSelectionBoxColor;
	updateSelectionBoxColor();

end;

Tools.Material.startHistoryRecord = function ( self )

	if self.State.HistoryRecord then
		self.State.HistoryRecord = nil;
	end;

	-- Create a history record
	self.State.HistoryRecord = {
		targets = _cloneTable( Selection.Items );
		initial_material = {};
		terminal_material = {};
		initial_transparency = {};
		terminal_transparency = {};
		initial_reflectance = {};
		terminal_reflectance = {};
		unapply = function ( self )
			Selection:clear();
			for _, Target in pairs( self.targets ) do
				if Target then
					Target.Material = self.initial_material[Target];
					Target.Transparency = self.initial_transparency[Target];
					Target.Reflectance = self.initial_reflectance[Target];
					Selection:add( Target );
				end;
			end;
		end;
		apply = function ( self )
			Selection:clear();
			for _, Target in pairs( self.targets ) do
				if Target then
					Target.Material = self.terminal_material[Target];
					Target.Transparency = self.terminal_transparency[Target];
					Target.Reflectance = self.terminal_reflectance[Target];
					Selection:add( Target );
				end;
			end;
		end;
	};
	for _, Item in pairs( self.State.HistoryRecord.targets ) do
		if Item then
			self.State.HistoryRecord.initial_material[Item] = Item.Material;
			self.State.HistoryRecord.initial_transparency[Item] = Item.Transparency;
			self.State.HistoryRecord.initial_reflectance[Item] = Item.Reflectance;
		end;
	end;

end;

Tools.Material.finishHistoryRecord = function ( self )

	if not self.State.HistoryRecord then
		return;
	end;

	for _, Item in pairs( self.State.HistoryRecord.targets ) do
		if Item then
			self.State.HistoryRecord.terminal_material[Item] = Item.Material;
			self.State.HistoryRecord.terminal_transparency[Item] = Item.Transparency;
			self.State.HistoryRecord.terminal_reflectance[Item] = Item.Reflectance;
		end;
	end;
	History:add( self.State.HistoryRecord );
	self.State.HistoryRecord = nil;

end;

Tools.Material.changeMaterial = function ( self, material_type )

	self:startHistoryRecord();

	-- Apply `material_type` to all items in the selection
	for _, Item in pairs( Selection.Items ) do
		Item.Material = material_type;
	end;

	self:finishHistoryRecord();

	if self.MaterialDropdown.open then
		self.MaterialDropdown:toggle();
	end;
end;

Tools.Material.changeTransparency = function ( self, transparency )

	self:startHistoryRecord();

	-- Apply `transparency` to all items in the selection
	for _, Item in pairs( Selection.Items ) do
		Item.Transparency = transparency;
	end;

	self:finishHistoryRecord();

end;

Tools.Material.changeReflectance = function ( self, reflectance )

	self:startHistoryRecord();

	-- Apply `reflectance` to all items in the selection
	for _, Item in pairs( Selection.Items ) do
		Item.Reflectance = reflectance;
	end;

	self:finishHistoryRecord();

end;

Tools.Material.updateGUI = function ( self )

	-- Make sure the GUI exists
	if not self.GUI then
		return;
	end;

	if #Selection.Items > 0 then
		self.GUI.Size = UDim2.new( 0, 200, 0, 145 );
		self.GUI.MaterialOption.Visible = true;
		self.GUI.ReflectanceOption.Visible = true;
		self.GUI.TransparencyOption.Visible = true;
		self.GUI.SelectNote.Visible = false;
		self.MaterialDropdown:selectOption( self.State.material and ( self.SpecialMaterialNames[self.State.material.Name] or self.State.material.Name:upper() ) or "*" );

		-- Update the text inputs without interrupting the user
		if not self.State.transparency_focused then
			self.GUI.TransparencyOption.TransparencyInput.TextBox.Text = self.State.transparency and tostring( _round( self.State.transparency, 2 ) ) or "*";
		end;
		if not self.State.reflectance_focused then
			self.GUI.ReflectanceOption.ReflectanceInput.TextBox.Text = self.State.reflectance and tostring( _round( self.State.reflectance, 2 ) ) or "*";
		end;

	else
		self.GUI.Size = UDim2.new( 0, 200, 0, 62 );
		self.GUI.MaterialOption.Visible = false;
		self.GUI.ReflectanceOption.Visible = false;
		self.GUI.TransparencyOption.Visible = false;
		self.GUI.SelectNote.Visible = true;
		self.MaterialDropdown:selectOption( "" );
		self.GUI.TransparencyOption.TransparencyInput.TextBox.Text = "";
		self.GUI.ReflectanceOption.ReflectanceInput.TextBox.Text = "";
	end;

end;


Tools.Material.showGUI = function ( self )

	-- Initialize the GUI if it's not ready yet
	if not self.GUI then

		local Container = Tool.Interfaces.BTMaterialToolGUI:Clone();
		Container.Parent = UI;

		local MaterialDropdown = createDropdown();
		self.MaterialDropdown = MaterialDropdown;
		MaterialDropdown.Frame.Parent = Container.MaterialOption;
		MaterialDropdown.Frame.Position = UDim2.new( 0, 50, 0, 0 );
		MaterialDropdown.Frame.Size = UDim2.new( 0, 130, 0, 25 );

		MaterialDropdown:addOption( "SMOOTH PLASTIC" ).MouseButton1Up:connect( function ()
			self:changeMaterial( Enum.Material.SmoothPlastic );
		end );
		MaterialDropdown:addOption( "PLASTIC" ).MouseButton1Up:connect( function ()
			self:changeMaterial( Enum.Material.Plastic );
		end );
		MaterialDropdown:addOption( "CONCRETE" ).MouseButton1Up:connect( function ()
			self:changeMaterial( Enum.Material.Concrete );
		end );
		MaterialDropdown:addOption( "DIAMOND PLATE" ).MouseButton1Up:connect( function ()
			self:changeMaterial( Enum.Material.DiamondPlate );
		end );
		MaterialDropdown:addOption( "CORRODED METAL" ).MouseButton1Up:connect( function ()
			self:changeMaterial( Enum.Material.CorrodedMetal );
		end );
		MaterialDropdown:addOption( "BRICK" ).MouseButton1Up:connect( function ()
			self:changeMaterial( Enum.Material.Brick );
		end );
		MaterialDropdown:addOption( "FABRIC" ).MouseButton1Up:connect( function ()
			self:changeMaterial( Enum.Material.Fabric );
		end );
		MaterialDropdown:addOption( "FOIL" ).MouseButton1Up:connect( function ()
			self:changeMaterial( Enum.Material.Foil );
		end );
		MaterialDropdown:addOption( "GRANITE" ).MouseButton1Up:connect( function ()
			self:changeMaterial( Enum.Material.Granite );
		end );
		MaterialDropdown:addOption( "GRASS" ).MouseButton1Up:connect( function ()
			self:changeMaterial( Enum.Material.Grass );
		end );
		MaterialDropdown:addOption( "ICE" ).MouseButton1Up:connect( function ()
			self:changeMaterial( Enum.Material.Ice );
		end );
		MaterialDropdown:addOption( "MARBLE" ).MouseButton1Up:connect( function ()
			self:changeMaterial( Enum.Material.Marble );
		end );
		MaterialDropdown:addOption( "PEBBLE" ).MouseButton1Up:connect( function ()
			self:changeMaterial( Enum.Material.Pebble );
		end );
		MaterialDropdown:addOption( "SAND" ).MouseButton1Up:connect( function ()
			self:changeMaterial( Enum.Material.Sand );
		end );
		MaterialDropdown:addOption( "SLATE" ).MouseButton1Up:connect( function ()
			self:changeMaterial( Enum.Material.Slate );
		end );
		MaterialDropdown:addOption( "WOOD" ).MouseButton1Up:connect( function ()
			self:changeMaterial( Enum.Material.Wood );
		end );

		-- Capture focus of the input when clicked
		-- (so we can detect when it is focused-on)
		Container.TransparencyOption.TransparencyInput.TextButton.MouseButton1Down:connect( function ()
			self.State.transparency_focused = true;
			Container.TransparencyOption.TransparencyInput.TextBox:CaptureFocus();
		end );

		-- Change the transparency when the value of the textbox is updated
		Container.TransparencyOption.TransparencyInput.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( Container.TransparencyOption.TransparencyInput.TextBox.Text );
			if potential_new then
				if potential_new > 1 then
					potential_new = 1;
				elseif potential_new < 0 then
					potential_new = 0;
				end;
				self:changeTransparency( potential_new );
			end;
			self.State.transparency_focused = false;
		end );

		-- Capture focus of the input when clicked
		-- (so we can detect when it is focused-on)
		Container.ReflectanceOption.ReflectanceInput.TextButton.MouseButton1Down:connect( function ()
			self.State.reflectance_focused = true;
			Container.ReflectanceOption.ReflectanceInput.TextBox:CaptureFocus();
		end );

		-- Change the reflectance when the value of the textbox is updated
		Container.ReflectanceOption.ReflectanceInput.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( Container.ReflectanceOption.ReflectanceInput.TextBox.Text );
			if potential_new then
				if potential_new > 1 then
					potential_new = 1;
				elseif potential_new < 0 then
					potential_new = 0;
				end;
				self:changeReflectance( potential_new );
			end;
			self.State.reflectance_focused = false;
		end );

		self.GUI = Container;

	end;

	-- Reveal the GUI
	self.GUI.Visible = true;

end;

Tools.Material.hideGUI = function ( self )

	-- Hide the GUI if it exists already
	if self.GUI then
		self.GUI.Visible = false;
	end;

end;

Tools.Material.Loaded = true;