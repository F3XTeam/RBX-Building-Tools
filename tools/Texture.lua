-- Load the main tool's core environment when it's ready
repeat wait() until (
	_G.BTCoreEnv and
	_G.BTCoreEnv[script.Parent.Parent] and
	_G.BTCoreEnv[script.Parent.Parent].CoreReady
);
setfenv( 1, _G.BTCoreEnv[script.Parent.Parent] );

------------------------------------------
-- Texture tool
------------------------------------------

-- Create the tool
Tools.Texture = {};

-- Define the tool's color
Tools.Texture.Color = BrickColor.new( "Bright violet" );

-- Keep a container for state data
Tools.Texture.Options = {
	side = Enum.NormalId.Front;
	mode = "decal";
};
Tools.Texture.State = {};

-- Keep a container for temporary connections
Tools.Texture.Connections = {};

-- Keep a container for platform event connections
Tools.Texture.Listeners = {};

-- Start adding functionality to the tool
Tools.Texture.Listeners.Equipped = function ()

	local self = Tools.Texture;

	-- Change the color of selection boxes temporarily
	self.State.PreviousSelectionBoxColor = SelectionBoxColor;
	SelectionBoxColor = self.Color;
	updateSelectionBoxColor();

	-- Reveal the GUI
	self:showGUI();

	-- Prepare the GUI
	self:changeSide( self.Options.side );
	self:changeMode( self.Options.mode );

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

Tools.Texture.Listeners.Unequipped = function ()

	local self = Tools.Texture;

	-- Stop the GUI updater
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

Tools.Texture.Listeners.Button2Down = function ()

	local self = Tools.Texture;

	-- Capture the camera rotation (for later use
	-- in determining whether a surface was being
	-- selected or the camera was being rotated
	-- with the right mouse button)
	local cr_x, cr_y, cr_z = Workspace.CurrentCamera.CoordinateFrame:toEulerAnglesXYZ();
	self.State.PreB2DownCameraRotation = Vector3.new( cr_x, cr_y, cr_z );

end;

Tools.Texture.Listeners.Button2Up = function ()

	local self = Tools.Texture;

	local cr_x, cr_y, cr_z = Workspace.CurrentCamera.CoordinateFrame:toEulerAnglesXYZ();
	local CameraRotation = Vector3.new( cr_x, cr_y, cr_z );

	-- If a surface is selected, change the side option
	if Selection:find( Mouse.Target ) and self.State.PreB2DownCameraRotation == CameraRotation then
		self:changeSide( Mouse.TargetSurface );
	end;

end;

Tools.Texture.startHistoryRecord = function ( self, textures )

	if self.State.HistoryRecord then
		self.State.HistoryRecord = nil;
	end;

	-- Create a history record
	self.State.HistoryRecord = {
		targets = Support.CloneTable(textures);
		initial_texture = {};
		terminal_texture = {};
		initial_transparency = {};
		terminal_transparency = {};
		initial_repeat = {};
		terminal_repeat = {};
		initial_side = {};
		terminal_side = {};
		unapply = function ( self )
			Selection:clear();
			for _, Target in pairs( self.targets ) do
				if Target then
					Selection:add( Target.Parent );
					Target.Texture = self.initial_texture[Target];
					Target.Transparency = self.initial_transparency[Target];
					Target.Face = self.initial_side[Target];
					if Target:IsA( "Texture" ) then
						Target.StudsPerTileU = self.initial_repeat[Target].x;
						Target.StudsPerTileV = self.initial_repeat[Target].y;
					end;
				end;
			end;
		end;
		apply = function ( self )
			Selection:clear();
			for _, Target in pairs( self.targets ) do
				if Target then
					Selection:add( Target.Parent );
					Target.Texture = self.terminal_texture[Target];
					Target.Transparency = self.terminal_transparency[Target];
					Target.Face = self.terminal_side[Target];
					if Target:IsA( "Texture" ) then
						Target.StudsPerTileU = self.terminal_repeat[Target].x;
						Target.StudsPerTileV = self.terminal_repeat[Target].y;
					end;
				end;
			end;
		end;
	};
	for _, Item in pairs( self.State.HistoryRecord.targets ) do
		if Item then
			self.State.HistoryRecord.initial_texture[Item] = Item.Texture;
			self.State.HistoryRecord.initial_transparency[Item] = Item.Transparency;
			self.State.HistoryRecord.initial_side[Item] = Item.Face;
			if Item:IsA( "Texture" ) then
				self.State.HistoryRecord.initial_repeat[Item] = Vector2.new( Item.StudsPerTileU, Item.StudsPerTileV );
			end;
		end;
	end;

end;

Tools.Texture.finishHistoryRecord = function ( self )

	if not self.State.HistoryRecord then
		return;
	end;

	for _, Item in pairs( self.State.HistoryRecord.targets ) do
		if Item then
			self.State.HistoryRecord.terminal_texture[Item] = Item.Texture;
			self.State.HistoryRecord.terminal_transparency[Item] = Item.Transparency;
			self.State.HistoryRecord.terminal_side[Item] = Item.Face;
			if Item:IsA( "Texture" ) then
				self.State.HistoryRecord.terminal_repeat[Item] = Vector2.new( Item.StudsPerTileU, Item.StudsPerTileV );
			end;
		end;
	end;
	History:add( self.State.HistoryRecord );
	self.State.HistoryRecord = nil;

end;

Tools.Texture.changeMode = function ( self, new_mode )

	-- Set the option
	self.Options.mode = new_mode;

	-- Make sure the GUI exists
	if not self.GUI then
		return;
	end;

	-- Update the GUI
	if new_mode == "decal" then
		self.GUI.ModeOption.Decal.SelectedIndicator.Transparency = 0;
		self.GUI.ModeOption.Texture.SelectedIndicator.Transparency = 1;
		self.GUI.ModeOption.Decal.Background.Image = Assets.DarkSlantedRectangle;
		self.GUI.ModeOption.Texture.Background.Image = Assets.LightSlantedRectangle;
		self.GUI.AddButton.Button.Text = "ADD DECAL";
		self.GUI.RemoveButton.Button.Text = "REMOVE DECAL";
	elseif new_mode == "texture" then
		self.GUI.ModeOption.Decal.SelectedIndicator.Transparency = 1;
		self.GUI.ModeOption.Texture.SelectedIndicator.Transparency = 0;
		self.GUI.ModeOption.Decal.Background.Image = Assets.LightSlantedRectangle;
		self.GUI.ModeOption.Texture.Background.Image = Assets.DarkSlantedRectangle;
		self.GUI.AddButton.Button.Text = "ADD TEXTURE";
		self.GUI.RemoveButton.Button.Text = "REMOVE TEXTURE";
	end;

end;

Tools.Texture.changeSide = function ( self, new_side )

	-- Set the option
	self.Options.side = new_side;

	-- Update the GUI
	if self.SideDropdown then
		self.SideDropdown:selectOption( new_side.Name:upper() );
		if self.SideDropdown.open then
			self.SideDropdown:toggle();
		end;
	end;

end;

Tools.Texture.changeTexture = function ( self, new_texture )

	local textures = {};

	-- Apply the new texture to any items w/ textures in the selection
	-- that are on the side in the options
	for _, Item in pairs( Selection.Items ) do
		local textures_found = Support.GetChildrenOfClass(Item, "Texture");
		for _, Texture in pairs( textures_found ) do
			if Texture.Face == self.Options.side then
				table.insert( textures, Texture );
			end;
		end;
	end;

	-- Check if the given ID is actually a decal and get the right image ID from it
	if HttpAvailable then
		local BaseImageExtractionUrl = 'http://www.f3xteam.com/bt/getDecalImageID/%s';
		local ExtractedImageID = Tool.HttpInterface.GetAsync:InvokeServer( BaseImageExtractionUrl:format( new_texture ) );
		if ExtractedImageID and ExtractedImageID:len() > 0 then
			new_texture = ExtractedImageID;
		end;
	end;

	self:startHistoryRecord( textures );
	for _, Texture in pairs( textures ) do
		Texture.Texture = "http://www.roblox.com/asset/?id=" .. new_texture;
	end;
	self:finishHistoryRecord();

end;

Tools.Texture.changeDecal = function ( self, new_decal )

	local decals = {};

	-- Apply the new decal to any items w/ decals in the selection
	-- that are on the side in the options
	for _, Item in pairs( Selection.Items ) do
		local decals_found = Support.GetChildrenOfClass(Item, "Decal");
		for _, Decal in pairs( decals_found ) do
			if Decal.Face == self.Options.side then
				table.insert( decals, Decal );
			end;
		end;
	end;

	-- Check if the given ID is actually a decal and get the right image ID from it
	if HttpAvailable then
		local BaseImageExtractionUrl = 'http://www.f3xteam.com/bt/getDecalImageID/%s';
		local ExtractedImageID = Tool.HttpInterface.GetAsync:InvokeServer( BaseImageExtractionUrl:format( new_decal ) );
		if ExtractedImageID and ExtractedImageID:len() > 0 then
			new_decal = ExtractedImageID;
		end;
	end;

	self:startHistoryRecord( decals );
	for _, Decal in pairs( decals ) do
		Decal.Texture = "http://www.roblox.com/asset/?id=" .. new_decal;
	end;
	self:finishHistoryRecord();

end;

Tools.Texture.changeTransparency = function ( self, new_transparency )

	local textures = {};

	-- Apply the new transparency to any items w/
	-- decals/textures in the selectionthat are on
	-- the side in the options
	for _, Item in pairs( Selection.Items ) do

		if self.Options.mode == "texture" then
			local textures_found = Support.GetChildrenOfClass(Item, "Texture");
			for _, Texture in pairs( textures_found ) do
				if Texture.Face == self.Options.side then
					table.insert( textures, Texture );
				end;
			end;

		elseif self.Options.mode == "decal" then
			local decals_found = Support.GetChildrenOfClass(Item, "Decal");
			for _, Decal in pairs( decals_found ) do
				if Decal.Face == self.Options.side then
					table.insert( textures, Decal );
				end;
			end;
		end;

	end;

	self:startHistoryRecord( textures );
	for _, Texture in pairs( textures ) do
		Texture.Transparency = new_transparency;
	end;
	self:finishHistoryRecord();

end;

Tools.Texture.changeFrequency = function ( self, direction, new_frequency )

	local textures = {};

	-- Apply the new frequency to any items w/ textures
	-- in the selection that are on the side in the options
	for _, Item in pairs( Selection.Items ) do
		local textures_found = Support.GetChildrenOfClass(Item, "Texture");
		for _, Texture in pairs( textures_found ) do
			if Texture.Face == self.Options.side then
				table.insert( textures, Texture );
			end;
		end;
	end;

	self:startHistoryRecord( textures );
	for _, Texture in pairs( textures ) do
		-- Apply the new frequency to the right direction
		if direction == "x" then
			Texture.StudsPerTileU = new_frequency;
		elseif direction == "y" then
			Texture.StudsPerTileV = new_frequency;
		end;
	end;
	self:finishHistoryRecord();

end;

Tools.Texture.addTexture = function ( self )

	local HistoryRecord = {
		apply = function ( self )
			Selection:clear();
			for _, Texture in pairs( self.textures ) do
				Texture.Parent = self.texture_parents[Texture];
				Selection:add( Texture.Parent );
			end;
		end;
		unapply = function ( self )
			Selection:clear();
			for _, Texture in pairs( self.textures ) do
				Selection:add( Texture.Parent );
				Texture.Parent = nil;
			end;
		end;
	};

	local textures = {};
	local texture_parents = {};

	for _, Item in pairs( Selection.Items ) do

		-- Check if the item has a texture already
		local textures_found = Support.GetChildrenOfClass(Item, "Texture");
		local has_texture = false;
		for _, Texture in pairs( textures_found ) do
			if Texture.Face == self.Options.side then
				has_texture = true;
				break;
			end;
		end;

		-- Only add a texture if it doesn't already exist
		if not has_texture then
			local Texture = RbxUtility.Create "Texture" {
				Parent = Item;
				Face = self.Options.side;
			};
			table.insert( textures, Texture );
			texture_parents[Texture] = Item;
		end;

	end;

	HistoryRecord.textures = textures;
	HistoryRecord.texture_parents = texture_parents;
	History:add( HistoryRecord );

end;

Tools.Texture.addDecal = function ( self )

	local HistoryRecord = {
		apply = function ( self )
			Selection:clear();
			for _, Decal in pairs( self.decals ) do
				Decal.Parent = self.decal_parents[Decal];
				Selection:add( Decal.Parent );
			end;
		end;
		unapply = function ( self )
			Selection:clear();
			for _, Decal in pairs( self.decals ) do
				Selection:add( Decal.Parent );
				Decal.Parent = nil;
			end;
		end;
	};

	local decals = {};
	local decal_parents = {};

	for _, Item in pairs( Selection.Items ) do

		-- Check if the item has a decal already
		local decals_found = Support.GetChildrenOfClass(Item, "Decal");
		local has_decal = false;
		for _, Decal in pairs( decals_found ) do
			if Decal.Face == self.Options.side then
				has_decal = true;
				break;
			end;
		end;

		-- Only add a texture if it doesn't already exist
		if not has_decal then
			local Decal = RbxUtility.Create "Decal" {
				Parent = Item;
				Face = self.Options.side;
			};
			table.insert( decals, Decal );
			decal_parents[Decal] = Item;
		end;

	end;

	HistoryRecord.decals = decals;
	HistoryRecord.decal_parents = decal_parents;
	History:add( HistoryRecord );

end;

Tools.Texture.removeTexture = function ( self )

	local HistoryRecord = {
		textures = {};
		texture_parents = {};
		apply = function ( self )
			Selection:clear();
			for _, Texture in pairs( self.textures ) do
				Selection:add( Texture.Parent );
				Texture.Parent = nil;
			end;
		end;
		unapply = function ( self )
			Selection:clear();
			for _, Texture in pairs( self.textures ) do
				Texture.Parent = self.texture_parents[Texture];
				Selection:add( Texture.Parent );
			end;
		end;
	};

	-- Remove any textures on the selected side
	for _, Item in pairs( Selection.Items ) do
		local textures = Support.GetChildrenOfClass(Item, "Texture");
		for _, Texture in pairs( textures ) do
			if Texture.Face == self.Options.side then
				table.insert( HistoryRecord.textures, Texture );
				HistoryRecord.texture_parents[Texture] = Texture.Parent;
				Texture.Parent = nil;
			end;
		end;
	end;

	History:add( HistoryRecord );

end;

Tools.Texture.removeDecal = function ( self )

	local HistoryRecord = {
		decals = {};
		decal_parents = {};
		apply = function ( self )
			Selection:clear();
			for _, Decal in pairs( self.decals ) do
				Selection:add( Decal.Parent );
				Decal.Parent = nil;
			end;
		end;
		unapply = function ( self )
			Selection:clear();
			for _, Decal in pairs( self.decals ) do
				Decal.Parent = self.decal_parents[Decal];
				Selection:add( Decal.Parent );
			end;
		end;
	};

	-- Remove any decals on the selected side
	for _, Item in pairs( Selection.Items ) do
		local decals = Support.GetChildrenOfClass(Item, "Decal");
		for _, Decal in pairs( decals ) do
			if Decal.Face == self.Options.side then
				table.insert( HistoryRecord.decals, Decal );
				HistoryRecord.decal_parents[Decal] = Decal.Parent;
				Decal.Parent = nil;
			end;
		end;
	end;

	History:add( HistoryRecord );

end;

Tools.Texture.updateGUI = function ( self )

	-- Make sure the GUI exists
	if not self.GUI then
		return;
	end;

	local GUI = self.GUI;

	-- If there are no items selected, just minimize
	-- non-tool-option controls
	if #Selection.Items == 0 then
		self.GUI.AddButton.Visible = false;
		self.GUI.RemoveButton.Visible = false;
		self.GUI.ImageIDOption.Visible = false;
		self.GUI.TransparencyOption.Visible = false;
		self.GUI.RepeatOption.Visible = false;
		self.GUI.Size = UDim2.new( 0, 200, 0, 100 );

	else
		if self.Options.mode == "texture" then

			-- Get the applicable textures
			local textures = {};
			for _, Item in pairs( Selection.Items ) do
				local textures_found = Support.GetChildrenOfClass(Item, "Texture");
				for _, Texture in pairs( textures_found ) do
					if Texture.Face == self.Options.side then
						table.insert( textures, Texture );
						break;
					end;
				end;
			end;

			-- If there are no textures
			if #textures == 0 then
				self.GUI.AddButton.Visible = true;
				self.GUI.RemoveButton.Visible = false;
				self.GUI.ImageIDOption.Visible = false;
				self.GUI.TransparencyOption.Visible = false;
				self.GUI.RepeatOption.Visible = false;
				self.GUI.Size = UDim2.new( 0, 200, 0, 130 );

			-- If only some parts have textures
			elseif #textures ~= #Selection.Items then
				self.GUI.AddButton.Visible = true;
				self.GUI.RemoveButton.Visible = true;
				self.GUI.ImageIDOption.Visible = true;
				self.GUI.TransparencyOption.Visible = true;
				self.GUI.RepeatOption.Visible = true;
				self.GUI.ImageIDOption.Position = UDim2.new( 0, 14, 0, 135 );
				self.GUI.TransparencyOption.Position = UDim2.new( 0, 14, 0, 170 );
				self.GUI.RepeatOption.Position = UDim2.new( 0, 0, 0, 205 );
				self.GUI.Size = UDim2.new( 0, 200, 0, 280 );

			-- If every item has a texture
			elseif #textures == #Selection.Items then
				self.GUI.AddButton.Visible = false;
				self.GUI.RemoveButton.Visible = true;
				self.GUI.ImageIDOption.Visible = true;
				self.GUI.TransparencyOption.Visible = true;
				self.GUI.RepeatOption.Visible = true;
				self.GUI.ImageIDOption.Position = UDim2.new( 0, 14, 0, 100 );
				self.GUI.TransparencyOption.Position = UDim2.new( 0, 14, 0, 135 );
				self.GUI.RepeatOption.Position = UDim2.new( 0, 0, 0, 170 );
				self.GUI.Size = UDim2.new( 0, 200, 0, 245 );
			end;

			-- Get the values to display on the GUI
			local texture_id, texture_transparency, texture_repeat_x, texture_repeat_y;
			for texture_index, Texture in pairs( textures ) do

				-- Set the start values for later comparison
				if texture_index == 1 then
					texture_id = Texture.Texture:lower();
					texture_transparency = Texture.Transparency;
					texture_repeat_x = Texture.StudsPerTileU;
					texture_repeat_y = Texture.StudsPerTileV;

				-- Set the values to `nil` if they vary across the selection
				else
					if texture_id ~= Texture.Texture:lower() then
						texture_id = nil;
					end;
					if texture_transparency ~= Texture.Transparency then
						texture_transparency = nil;
					end;
					if texture_repeat_x ~= Texture.StudsPerTileU then
						texture_repeat_x = nil;
					end;
					if texture_repeat_y ~= Texture.StudsPerTileV then
						texture_repeat_y = nil;
					end;
				end;

			end;

			-- Update the GUI's values
			if not self.State.image_id_focused then
				self.GUI.ImageIDOption.TextBox.Text = texture_id and ( texture_id:match( "%?id=([0-9]+)" ) or "" ) or "*";
			end;
			if not self.State.transparency_focused then
				self.GUI.TransparencyOption.TransparencyInput.TextBox.Text = texture_transparency and Support.Round(texture_transparency, 2) or "*";
			end;
			if not self.State.rep_x_focused then
				self.GUI.RepeatOption.XInput.TextBox.Text = texture_repeat_x and Support.Round(texture_repeat_x, 2) or "*";
			end;
			if not self.State.rep_y_focused then
				self.GUI.RepeatOption.YInput.TextBox.Text = texture_repeat_y and Support.Round(texture_repeat_y, 2) or "*";
			end;

		elseif self.Options.mode == "decal" then

			-- Get the applicable decals
			local decals = {};
			for _, Item in pairs( Selection.Items ) do
				local decals_found = Support.GetChildrenOfClass(Item, "Decal");
				for _, Decal in pairs( decals_found ) do
					if Decal.Face == self.Options.side then
						table.insert( decals, Decal );
						break;
					end;
				end;
			end;

			-- If there are no decals
			if #decals == 0 then
				self.GUI.AddButton.Visible = true;
				self.GUI.RemoveButton.Visible = false;
				self.GUI.ImageIDOption.Visible = false;
				self.GUI.TransparencyOption.Visible = false;
				self.GUI.RepeatOption.Visible = false;
				self.GUI.Size = UDim2.new( 0, 200, 0, 130 );

			-- If only some parts have decals
			elseif #decals ~= #Selection.Items then
				self.GUI.AddButton.Visible = true;
				self.GUI.RemoveButton.Visible = true;
				self.GUI.ImageIDOption.Visible = true;
				self.GUI.TransparencyOption.Visible = true;
				self.GUI.RepeatOption.Visible = false;
				self.GUI.ImageIDOption.Position = UDim2.new( 0, 14, 0, 135 );
				self.GUI.TransparencyOption.Position = UDim2.new( 0, 14, 0, 170 );
				self.GUI.Size = UDim2.new( 0, 200, 0, 245 );

			-- If every item has a decal
			elseif #decals == #Selection.Items then
				self.GUI.AddButton.Visible = false;
				self.GUI.RemoveButton.Visible = true;
				self.GUI.ImageIDOption.Visible = true;
				self.GUI.TransparencyOption.Visible = true;
				self.GUI.RepeatOption.Visible = false;
				self.GUI.ImageIDOption.Position = UDim2.new( 0, 14, 0, 100 );
				self.GUI.TransparencyOption.Position = UDim2.new( 0, 14, 0, 135 );
				self.GUI.Size = UDim2.new( 0, 200, 0, 205 );
			end;

			-- Get the values to display on the GUI
			local decal_id, decal_transparency;
			for decal_index, Decal in pairs( decals ) do

				-- Set the start values for later comparison
				if decal_index == 1 then
					decal_id = Decal.Texture:lower();
					decal_transparency = Decal.Transparency;

				-- Set the values to `nil` if they vary across the selection
				else
					if decal_id ~= Decal.Texture:lower() then
						decal_id = nil;
					end;
					if decal_transparency ~= Decal.Transparency then
						decal_transparency = nil;
					end;
				end;

			end;

			-- Update the GUI's values
			if not self.State.image_id_focused then
				self.GUI.ImageIDOption.TextBox.Text = decal_id and ( decal_id:match( "%?id=([0-9]+)" ) or "" ) or "*";
			end;
			if not self.State.transparency_focused then
				self.GUI.TransparencyOption.TransparencyInput.TextBox.Text = decal_transparency and Support.Round(decal_transparency, 2) or "*";
			end;

		end;
	end;

end;

Tools.Texture.showGUI = function ( self )

	-- Initialize the GUI if it's not ready yet
	if not self.GUI then
		local Container = Tool.Interfaces.BTTextureToolGUI:Clone();
		Container.Parent = UI;

		-- Add functionality to the add/remove buttons
		Container.AddButton.Button.MouseButton1Up:connect( function ()
			if self.Options.mode == "decal" then
				self:addDecal();
			elseif self.Options.mode == "texture" then
				self:addTexture();
			end;
		end );
		Container.RemoveButton.Button.MouseButton1Up:connect( function ()
			if self.Options.mode == "decal" then
				self:removeDecal();
			elseif self.Options.mode == "texture" then
				self:removeTexture();
			end;
		end );

		-- Add functionality to the mode selectors
		Container.ModeOption.Decal.Button.MouseButton1Down:connect( function ()
			self:changeMode( "decal" );
		end );
		Container.ModeOption.Texture.Button.MouseButton1Down:connect( function ()
			self:changeMode( "texture" );
		end );

		-- Add the side dropdown
		local SideDropdown = createDropdown();
		self.SideDropdown = SideDropdown;
		SideDropdown.Frame.Parent = Container.SideOption;
		SideDropdown.Frame.Position = UDim2.new( 0, 35, 0, 0 );
		SideDropdown.Frame.Size = UDim2.new( 1, -50, 0, 25 );
		SideDropdown:addOption( "TOP" ).MouseButton1Up:connect( function ()
			self:changeSide( Enum.NormalId.Top );
		end );
		SideDropdown:addOption( "BOTTOM" ).MouseButton1Up:connect( function ()
			self:changeSide( Enum.NormalId.Bottom );
		end );
		SideDropdown:addOption( "FRONT" ).MouseButton1Up:connect( function ()
			self:changeSide( Enum.NormalId.Front );
		end );
		SideDropdown:addOption( "BACK" ).MouseButton1Up:connect( function ()
			self:changeSide( Enum.NormalId.Back );
		end );
		SideDropdown:addOption( "LEFT" ).MouseButton1Up:connect( function ()
			self:changeSide( Enum.NormalId.Left );
		end );
		SideDropdown:addOption( "RIGHT" ).MouseButton1Up:connect( function ()
			self:changeSide( Enum.NormalId.Right );
		end );

		-- Add functionality to the repeat inputs
		Container.RepeatOption.XInput.TextButton.MouseButton1Down:connect( function ()
			self.State.rep_x_focused = true;
			Container.RepeatOption.XInput.TextBox:CaptureFocus();
		end );
		Container.RepeatOption.XInput.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( Container.RepeatOption.XInput.TextBox.Text );
			if potential_new then
				self:changeFrequency( 'x', potential_new );
			end;
			self.State.rep_x_focused = false;
		end );

		Container.RepeatOption.YInput.TextButton.MouseButton1Down:connect( function ()
			self.State.rep_y_focused = true;
			Container.RepeatOption.YInput.TextBox:CaptureFocus();
		end );
		Container.RepeatOption.YInput.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( Container.RepeatOption.YInput.TextBox.Text );
			if potential_new then
				self:changeFrequency( 'y', potential_new );
			end;
			self.State.rep_y_focused = false;
		end );

		-- Add functionality to the decal/texture ID inputs
		Container.ImageIDOption.TextButton.MouseButton1Down:connect( function ()
			self.State.image_id_focused = true;
			Container.ImageIDOption.TextBox:CaptureFocus();
		end );
		Container.ImageIDOption.TextBox.FocusLost:connect( function ( enter_pressed )
			local input = Container.ImageIDOption.TextBox.Text;
			local potential_new = tonumber( input ) or input:lower():match( "%?id=([0-9]+)" );
			if potential_new then
				if self.Options.mode == "decal" then
					self:changeDecal( potential_new );
				elseif self.Options.mode == "texture" then
					self:changeTexture( potential_new );
				end;
			end;
			self.State.image_id_focused = false;
		end );

		Container.TransparencyOption.TransparencyInput.TextButton.MouseButton1Down:connect( function ()
			self.State.transparency_focused = true;
			Container.TransparencyOption.TransparencyInput.TextBox:CaptureFocus();
		end );
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

		self.GUI = Container;
	end;

	-- Reveal the GUI
	self.GUI.Visible = true;

end;

Tools.Texture.hideGUI = function ( self )

	-- Hide the GUI if it exists already
	if self.GUI then
		self.GUI.Visible = false;
	end;

end;

Tools.Texture.Loaded = true;