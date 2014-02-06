-- Load the main tool's core environment when it's ready
repeat wait() until (
	_G.BTCoreEnv and
	_G.BTCoreEnv[script.Parent.Parent] and
	_G.BTCoreEnv[script.Parent.Parent].CoreReady
);
setfenv( 1, _G.BTCoreEnv[script.Parent.Parent] );

------------------------------------------
-- Mesh tool
------------------------------------------

-- Create the tool
Tools.Mesh = {};

-- Define the tool's color
Tools.Mesh.Color = BrickColor.new( "Bright violet" );

-- Keep a container for state data
Tools.Mesh.State = {};

-- Keep a container for temporary connections
Tools.Mesh.Connections = {};

-- Keep a container for platform event connections
Tools.Mesh.Listeners = {};

-- Start adding functionality to the tool
Tools.Mesh.Listeners.Equipped = function ()

	local self = Tools.Mesh;

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
		self.stopGUIUpdater = function ( self )
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

Tools.Mesh.Listeners.Unequipped = function ()

	local self = Tools.Mesh;

	-- Stop the GUI updater
	self:stopGUIUpdater();

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

Tools.Mesh.TypeDropdownLabels = {
	[Enum.MeshType.Brick] = "BLOCK";
	[Enum.MeshType.Cylinder] = "CYLINDER";
	[Enum.MeshType.FileMesh] = "FILE";
	[Enum.MeshType.Head] = "HEAD";
	[Enum.MeshType.Sphere] = "SPHERE";
	[Enum.MeshType.Torso] = "TRAPEZOID";
	[Enum.MeshType.Wedge] = "WEDGE";
};

Tools.Mesh.changeType = function ( self, new_type )

	-- Apply type `new_type` to all the meshes in items from the selection
	local meshes = {};
	for _, Item in pairs( Selection.Items ) do
		local Mesh = _getChildOfClass( Item, "SpecialMesh" );
		if Mesh then
			table.insert( meshes, Mesh );
		end;
	end;

	self:startHistoryRecord( meshes );
	for _, Mesh in pairs( meshes ) do
		Mesh.MeshType = new_type;
	end;
	self:finishHistoryRecord();

	if self.TypeDropdown.open then
		self.TypeDropdown:toggle();
	end;

	self:finishHistoryRecord();

end;

Tools.Mesh.updateGUI = function ( self )

	-- Make sure the GUI exists
	if not self.GUI then
		return;
	end;

	local GUI = self.GUI;

	if #Selection.Items > 0 then

		local meshes = {};
		for _, Item in pairs( Selection.Items ) do
			local Mesh = _getChildOfClass( Item, "SpecialMesh" );
			if Mesh then
				table.insert( meshes, Mesh );
			end;
		end;

		local show_add, show_remove, show_mesh_id;
		local mesh_type, mesh_scale_x, mesh_scale_y, mesh_scale_z, mesh_id, mesh_texture, mesh_tint_r, mesh_tint_g, mesh_tint_b;

		-- If every item has a mesh
		if #meshes == #Selection.Items then
			show_add = false;
			show_remove = true;

		-- If no item has a mesh
		elseif #meshes == 0 then
			show_add = true;
			show_remove = false;

		-- If some items have a mesh
		else
			show_add = true;
			show_remove = true;
		end;

		-- If there are meshes
		if #meshes > 0 then
			show_type = true;
			for mesh_index, Mesh in pairs( meshes ) do

				-- Set the start values for later comparison
				if mesh_index == 1 then
					mesh_type = Mesh.MeshType;
					mesh_scale_x, mesh_scale_y, mesh_scale_z = Mesh.Scale.x, Mesh.Scale.y, Mesh.Scale.z;
					mesh_id = Mesh.MeshId:lower();
					mesh_texture = Mesh.TextureId:lower();
					mesh_tint_r, mesh_tint_g, mesh_tint_b = Mesh.VertexColor.x, Mesh.VertexColor.y, Mesh.VertexColor.z;

				-- Set the values to `nil` if they vary across the selection
				else
					if mesh_type ~= Mesh.MeshType then
						mesh_type = nil;
					end;
					if mesh_scale_x ~= Mesh.Scale.x then
						mesh_scale_x = nil;
					end;
					if mesh_scale_y ~= Mesh.Scale.y then
						mesh_scale_y = nil;
					end;
					if mesh_scale_z ~= Mesh.Scale.z then
						mesh_scale_z = nil;
					end;
					if mesh_id ~= Mesh.MeshId:lower() then
						mesh_id = nil;
					end;
					if mesh_texture ~= Mesh.TextureId:lower() then
						mesh_texture = nil;
					end;
					if mesh_tint_r ~= Mesh.VertexColor.x then
						mesh_tint_r = nil;
					end;
					if mesh_tint_g ~= Mesh.VertexColor.y then
						mesh_tint_g = nil;
					end;
					if mesh_tint_b ~= Mesh.VertexColor.z then
						mesh_tint_b = nil;
					end;
				end;

				-- If there's a FileMesh around here, note that
				if Mesh.MeshType == Enum.MeshType.FileMesh then
					show_mesh_id = true;
				end;

			end;

			self.State.mesh_tint = ( mesh_tint_r and mesh_tint_g and mesh_tint_b ) and Color3.new( mesh_tint_r, mesh_tint_g, mesh_tint_b ) or nil;

			if show_mesh_id and show_add and show_remove then
				self.GUI.AddButton.Visible = true;
				self.GUI.RemoveButton.Visible = true;
				self.GUI.MeshIDOption.Visible = true;
				self.GUI.TextureIDOption.Visible = true;
				self.GUI.ScaleOption.Visible = true;
				self.GUI.TintOption.Visible = true;
				self.GUI.TypeOption.Visible = true;
				self.GUI.TypeOption.Position = UDim2.new( 0, 14, 0, 65 );
				self.GUI.ScaleOption.Position = UDim2.new( 0, 0, 0, 100 );
				self.GUI.MeshIDOption.Position = UDim2.new( 0, 14, 0, 135 );
				self.GUI.TextureIDOption.Position = UDim2.new( 0, 14, 0, 165 );
				self.GUI.TintOption.Position = UDim2.new( 0, 0, 0, 200 );
				self.GUI.Size = UDim2.new( 0, 200, 0, 265 );
			elseif show_mesh_id and not show_add and show_remove then
				self.GUI.AddButton.Visible = false;
				self.GUI.RemoveButton.Visible = true;
				self.GUI.MeshIDOption.Visible = true;
				self.GUI.TextureIDOption.Visible = true;
				self.GUI.ScaleOption.Visible = true;
				self.GUI.TintOption.Visible = true;
				self.GUI.TypeOption.Visible = true;
				self.GUI.TypeOption.Position = UDim2.new( 0, 14, 0, 30 );
				self.GUI.ScaleOption.Position = UDim2.new( 0, 0, 0, 65 );
				self.GUI.MeshIDOption.Position = UDim2.new( 0, 14, 0, 100 );
				self.GUI.TextureIDOption.Position = UDim2.new( 0, 14, 0, 130 );
				self.GUI.TintOption.Position = UDim2.new( 0, 0, 0, 165 );
				self.GUI.Size = UDim2.new( 0, 200, 0, 230 );

			elseif not show_mesh_id and show_add and show_remove then
				self.GUI.AddButton.Visible = true;
				self.GUI.RemoveButton.Visible = true;
				self.GUI.MeshIDOption.Visible = false;
				self.GUI.TextureIDOption.Visible = false;
				self.GUI.ScaleOption.Visible = true;
				self.GUI.TintOption.Visible = false;
				self.GUI.TypeOption.Visible = true;
				self.GUI.TypeOption.Position = UDim2.new( 0, 14, 0, 65 );
				self.GUI.ScaleOption.Position = UDim2.new( 0, 0, 0, 100 );
				self.GUI.Size = UDim2.new( 0, 200, 0, 165 );
			elseif not show_mesh_id and not show_add and show_remove then
				self.GUI.AddButton.Visible = false;
				self.GUI.RemoveButton.Visible = true;
				self.GUI.MeshIDOption.Visible = false;
				self.GUI.TextureIDOption.Visible = false;
				self.GUI.ScaleOption.Visible = true;
				self.GUI.TintOption.Visible = false;
				self.GUI.TypeOption.Visible = true;
				self.GUI.TypeOption.Position = UDim2.new( 0, 14, 0, 30 );
				self.GUI.ScaleOption.Position = UDim2.new( 0, 0, 0, 65 );
				self.GUI.Size = UDim2.new( 0, 200, 0, 130 );
			end;

			-- Update the values shown on the GUI
			if not self.State.mesh_id_focused then
				self.GUI.MeshIDOption.TextBox.Text = mesh_id and ( mesh_id:match( "%?id=([0-9]+)" ) or "" ) or "*";
			end;
			if not self.State.texture_id_focused then
				self.GUI.TextureIDOption.TextBox.Text = mesh_texture and ( mesh_texture:match( "%?id=([0-9]+)" ) or "" ) or "*";
			end;
			self.TypeDropdown:selectOption( mesh_type and self.TypeDropdownLabels[mesh_type] or "*" );
			if not self.State.scale_x_focused then
				self.GUI.ScaleOption.XInput.TextBox.Text = mesh_scale_x and _round( mesh_scale_x, 2 ) or "*";
			end;
			if not self.State.scale_y_focused then
				self.GUI.ScaleOption.YInput.TextBox.Text = mesh_scale_y and _round( mesh_scale_y, 2 ) or "*";
			end;
			if not self.State.scale_z_focused then
				self.GUI.ScaleOption.ZInput.TextBox.Text = mesh_scale_z and _round( mesh_scale_z, 2 ) or "*";
			end;
			if not self.State.tint_r_focused then
				self.GUI.TintOption.RInput.TextBox.Text = mesh_tint_r and _round( mesh_tint_r * 255, 0 ) or "*";
			end;
			if not self.State.tint_g_focused then
				self.GUI.TintOption.GInput.TextBox.Text = mesh_tint_g and _round( mesh_tint_g * 255, 0 ) or "*";
			end;
			if not self.State.tint_b_focused then
				self.GUI.TintOption.BInput.TextBox.Text = mesh_tint_b and _round( mesh_tint_b * 255, 0 ) or "*";
			end;

		-- If there are no meshes
		else
			self.GUI.AddButton.Visible = true;
			self.GUI.RemoveButton.Visible = false;
			self.GUI.MeshIDOption.Visible = false;
			self.GUI.TextureIDOption.Visible = false;
			self.GUI.ScaleOption.Visible = false;
			self.GUI.TintOption.Visible = false;
			self.GUI.TypeOption.Visible = false;
			self.GUI.Size = UDim2.new( 0, 200, 0, 62 );
		end;
		self.GUI.SelectNote.Visible = false;

	-- Show a note that says to select something
	else
		self.GUI.AddButton.Visible = false;
		self.GUI.RemoveButton.Visible = false;
		self.GUI.MeshIDOption.Visible = false;
		self.GUI.TextureIDOption.Visible = false;
		self.GUI.ScaleOption.Visible = false;
		self.GUI.TintOption.Visible = false;
		self.GUI.TypeOption.Visible = false;
		self.GUI.SelectNote.Visible = true;
		self.GUI.Size = UDim2.new( 0, 200, 0, 55 );
	end;

end;

Tools.Mesh.showGUI = function ( self )

	-- Initialize the GUI if it's not ready yet
	if not self.GUI then
		local Container = Tool.Interfaces:WaitForChild( "BTMeshToolGUI" ):Clone();
		Container.Parent = UI;

		-- Add functionality to the add/remove buttons
		Container.AddButton.Button.MouseButton1Up:connect( function ()
			self:addMesh();
		end );
		Container.RemoveButton.Button.MouseButton1Up:connect( function ()
			self:removeMesh();
		end );

		-- Add the type dropdown
		local TypeDropdown = createDropdown();
		self.TypeDropdown = TypeDropdown;
		TypeDropdown.Frame.Parent = Container.TypeOption;
		TypeDropdown.Frame.Position = UDim2.new( 0, 40, 0, 0 );
		TypeDropdown.Frame.Size = UDim2.new( 1, -40, 0, 25 );
		TypeDropdown:addOption( "BLOCK" ).MouseButton1Up:connect( function ()
			self:changeType( Enum.MeshType.Brick );
		end );
		TypeDropdown:addOption( "CYLINDER" ).MouseButton1Up:connect( function ()
			self:changeType( Enum.MeshType.Cylinder );
		end );
		TypeDropdown:addOption( "FILE" ).MouseButton1Up:connect( function ()
			self:changeType( Enum.MeshType.FileMesh );
		end );
		TypeDropdown:addOption( "HEAD" ).MouseButton1Up:connect( function ()
			self:changeType( Enum.MeshType.Head );
		end );
		TypeDropdown:addOption( "SPHERE" ).MouseButton1Up:connect( function ()
			self:changeType( Enum.MeshType.Sphere );
		end );
		TypeDropdown:addOption( "TRAPEZOID" ).MouseButton1Up:connect( function ()
			self:changeType( Enum.MeshType.Torso );
		end );
		TypeDropdown:addOption( "WEDGE" ).MouseButton1Up:connect( function ()
			self:changeType( Enum.MeshType.Wedge );
		end );

		-- Add functionality to the scale inputs
		Container.ScaleOption.XInput.TextButton.MouseButton1Down:connect( function ()
			self.State.scale_x_focused = true;
			Container.ScaleOption.XInput.TextBox:CaptureFocus();
		end );
		Container.ScaleOption.XInput.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( Container.ScaleOption.XInput.TextBox.Text );
			if potential_new then
				self:changeScale( 'x', potential_new );
			end;
			self.State.scale_x_focused = false;
		end );

		Container.ScaleOption.YInput.TextButton.MouseButton1Down:connect( function ()
			self.State.scale_y_focused = true;
			Container.ScaleOption.YInput.TextBox:CaptureFocus();
		end );
		Container.ScaleOption.YInput.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( Container.ScaleOption.YInput.TextBox.Text );
			if potential_new then
				self:changeScale( 'y', potential_new );
			end;
			self.State.scale_y_focused = false;
		end );

		Container.ScaleOption.ZInput.TextButton.MouseButton1Down:connect( function ()
			self.State.scale_z_focused = true;
			Container.ScaleOption.ZInput.TextBox:CaptureFocus();
		end );
		Container.ScaleOption.ZInput.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( Container.ScaleOption.ZInput.TextBox.Text );
			if potential_new then
				self:changeScale( 'z', potential_new );
			end;
			self.State.scale_z_focused = false;
		end );

		-- Add functionality to the mesh/texture ID inputs
		Container.MeshIDOption.TextButton.MouseButton1Down:connect( function ()
			self.State.mesh_id_focused = true;
			Container.MeshIDOption.TextBox:CaptureFocus();
		end );
		Container.MeshIDOption.TextBox.FocusLost:connect( function ( enter_pressed )
			local input = Container.MeshIDOption.TextBox.Text;
			local potential_new = tonumber( input ) or input:lower():match( "%?id=([0-9]+)" );
			if potential_new then
				self:changeMesh( potential_new );
			end;
			self.State.mesh_id_focused = false;
		end );

		Container.TextureIDOption.TextButton.MouseButton1Down:connect( function ()
			self.State.texture_id_focused = true;
			Container.TextureIDOption.TextBox:CaptureFocus();
		end );
		Container.TextureIDOption.TextBox.FocusLost:connect( function ( enter_pressed )
			local input = Container.TextureIDOption.TextBox.Text;
			local potential_new = tonumber( input ) or input:lower():match( "%?id=([0-9]+)" );
			if potential_new then
				self:changeTexture( potential_new );
			end;
			self.State.texture_id_focused = false;
		end );

		-- Add functionality to the tint inputs
		Container.TintOption.RInput.TextButton.MouseButton1Down:connect( function ()
			self.State.tint_r_focused = true;
			Container.TintOption.RInput.TextBox:CaptureFocus();
		end );
		Container.TintOption.RInput.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( Container.TintOption.RInput.TextBox.Text );
			if potential_new then
				if potential_new > 255 then
					potential_new = 255;
				elseif potential_new < 0 then
					potential_new = 0;
				end;
				self:changeTint( 'r', potential_new / 255 );
			end;
			self.State.tint_r_focused = false;
		end );

		Container.TintOption.GInput.TextButton.MouseButton1Down:connect( function ()
			self.State.tint_g_focused = true;
			Container.TintOption.GInput.TextBox:CaptureFocus();
		end );
		Container.TintOption.GInput.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( Container.TintOption.GInput.TextBox.Text );
			if potential_new then
				if potential_new > 255 then
					potential_new = 255;
				elseif potential_new < 0 then
					potential_new = 0;
				end;
				self:changeTint( 'g', potential_new / 255 );
			end;
			self.State.tint_g_focused = false;
		end );

		Container.TintOption.BInput.TextButton.MouseButton1Down:connect( function ()
			self.State.tint_b_focused = true;
			Container.TintOption.BInput.TextBox:CaptureFocus();
		end );
		Container.TintOption.BInput.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( Container.TintOption.BInput.TextBox.Text );
			if potential_new then
				if potential_new > 255 then
					potential_new = 255;
				elseif potential_new < 0 then
					potential_new = 0;
				end;
				self:changeTint( 'b', potential_new / 255 );
			end;
			self.State.tint_b_focused = false;
		end );

		Container.TintOption.HSVPicker.MouseButton1Up:connect( function ()
			ColorPicker:start( function ( ... )
				local args = { ... };
				-- If a color was picked, change the spotlights' color
				-- to the selected color
				if #args == 3 then
					local meshes = {};
					for _, Item in pairs( Selection.Items ) do
						local Mesh = _getChildOfClass( Item, "SpecialMesh" );
						if Mesh then
							table.insert( meshes, Mesh );
						end;
					end;
					self:startHistoryRecord( meshes );
					for _, Mesh in pairs( meshes ) do
						Mesh.VertexColor = Vector3.new( _HSVToRGB( ... ) );
					end;
					self:finishHistoryRecord();
				end;
			end, self.State.mesh_tint );
		end );

		self.GUI = Container;
	end;

	-- Reveal the GUI
	self.GUI.Visible = true;

end;

Tools.Mesh.addMesh = function ( self )

	local HistoryRecord = {
		apply = function ( self )
			Selection:clear();
			for _, Mesh in pairs( self.meshes ) do
				Mesh.Parent = self.mesh_parents[Mesh];
				Selection:add( Mesh.Parent );
			end;
		end;
		unapply = function ( self )
			Selection:clear();
			for _, Mesh in pairs( self.meshes ) do
				Selection:add( Mesh.Parent );
				Mesh.Parent = nil;
			end;
		end;
	};

	-- Add meshes to all the items from the selection that
	-- don't already have one
	local meshes = {};
	local mesh_parents = {};
	for _, Item in pairs( Selection.Items ) do
		local Mesh = _getChildOfClass( Item, "SpecialMesh" );
		if not Mesh then
			local Mesh = RbxUtility.Create "SpecialMesh" {
				Parent = Item;
				MeshType = Enum.MeshType.Brick;
			};
			table.insert( meshes, Mesh );
			mesh_parents[Mesh] = Item;
		end;
	end;

	HistoryRecord.meshes = meshes;
	HistoryRecord.mesh_parents = mesh_parents;
	History:add( HistoryRecord );

end;

Tools.Mesh.removeMesh = function ( self )

	local HistoryRecord = {
		apply = function ( self )
			Selection:clear();
			for _, Mesh in pairs( self.meshes ) do
				Selection:add( Mesh.Parent );
				Mesh.Parent = nil;
			end;
		end;
		unapply = function ( self )
			Selection:clear();
			for _, Mesh in pairs( self.meshes ) do
				Mesh.Parent = self.mesh_parents[Mesh];
				Selection:add( Mesh.Parent );
			end;
		end;
	};

	local meshes = {};
	local mesh_parents = {};
	-- Remove meshes from all the selected items
	for _, Item in pairs( Selection.Items ) do
		local meshes_found = _getChildrenOfClass( Item, "SpecialMesh" );
		for _, Mesh in pairs( meshes_found ) do
			table.insert( meshes, Mesh );
			mesh_parents[Mesh] = Mesh.Parent;
			Mesh.Parent = nil;
		end;
	end;

	HistoryRecord.meshes = meshes;
	HistoryRecord.mesh_parents = mesh_parents;
	History:add( HistoryRecord );

end;

Tools.Mesh.startHistoryRecord = function ( self, meshes )

	if self.State.HistoryRecord then
		self.State.HistoryRecord = nil;
	end;

	-- Create a history record
	self.State.HistoryRecord = {
		targets = _cloneTable( meshes );
		initial_type = {};
		terminal_type = {};
		initial_mesh = {};
		terminal_mesh = {};
		initial_texture = {};
		terminal_texture = {};
		initial_scale = {};
		terminal_scale = {};
		initial_tint = {};
		terminal_tint = {};
		unapply = function ( self )
			Selection:clear();
			for _, Target in pairs( self.targets ) do
				if Target then
					Selection:add( Target.Parent );
					Target.MeshType = self.initial_type[Target];
					Target.MeshId = self.initial_mesh[Target];
					Target.TextureId = self.initial_texture[Target];
					Target.Scale = self.initial_scale[Target];
					Target.VertexColor = self.initial_tint[Target];
				end;
			end;
		end;
		apply = function ( self )
			Selection:clear();
			for _, Target in pairs( self.targets ) do
				if Target then
					Selection:add( Target.Parent );
					Target.MeshType = self.terminal_type[Target];
					Target.MeshId = self.terminal_mesh[Target];
					Target.TextureId = self.terminal_texture[Target];
					Target.Scale = self.terminal_scale[Target];
					Target.VertexColor = self.terminal_tint[Target];
				end;
			end;
		end;
	};
	for _, Item in pairs( self.State.HistoryRecord.targets ) do
		if Item then
			self.State.HistoryRecord.initial_type[Item] = Item.MeshType;
			self.State.HistoryRecord.initial_mesh[Item] = Item.MeshId;
			self.State.HistoryRecord.initial_texture[Item] = Item.TextureId;
			self.State.HistoryRecord.initial_scale[Item] = Item.Scale;
			self.State.HistoryRecord.initial_tint[Item] = Item.VertexColor;
		end;
	end;

end;

Tools.Mesh.finishHistoryRecord = function ( self )

	if not self.State.HistoryRecord then
		return;
	end;

	for _, Item in pairs( self.State.HistoryRecord.targets ) do
		if Item then
			self.State.HistoryRecord.terminal_type[Item] = Item.MeshType;
			self.State.HistoryRecord.terminal_mesh[Item] = Item.MeshId;
			self.State.HistoryRecord.terminal_texture[Item] = Item.TextureId;
			self.State.HistoryRecord.terminal_scale[Item] = Item.Scale;
			self.State.HistoryRecord.terminal_tint[Item] = Item.VertexColor;
		end;
	end;
	History:add( self.State.HistoryRecord );
	self.State.HistoryRecord = nil;

end;

Tools.Mesh.changeMesh = function ( self, mesh_id )

	local meshes = {};

	for _, Item in pairs( Selection.Items ) do
		local Mesh = _getChildOfClass( Item, "SpecialMesh" );
		if Mesh then
			table.insert( meshes, Mesh );
		end;
	end;
	self:startHistoryRecord( meshes );
	for _, Mesh in pairs( meshes ) do
		Mesh.MeshId = "http://www.roblox.com/asset/?id=" .. mesh_id;
	end;
	self:finishHistoryRecord();

end;

Tools.Mesh.changeTexture = function ( self, texture_id )

	local meshes = {};

	for _, Item in pairs( Selection.Items ) do
		local Mesh = _getChildOfClass( Item, "SpecialMesh" );
		if Mesh then
			table.insert( meshes, Mesh );
		end;
	end;
	self:startHistoryRecord( meshes );
	for _, Mesh in pairs( meshes ) do
		Mesh.TextureId = "http://www.roblox.com/asset/?id=" .. texture_id;
	end;
	self:finishHistoryRecord();

end;

Tools.Mesh.changeScale = function ( self, component, new_value )

	local meshes = {};

	for _, Item in pairs( Selection.Items ) do
		local Mesh = _getChildOfClass( Item, "SpecialMesh" );
		if Mesh then
			table.insert( meshes, Mesh );
		end;
	end;

	self:startHistoryRecord( meshes );
	for _, Mesh in pairs( meshes ) do
		Mesh.Scale = Vector3.new(
			component == 'x' and new_value or Mesh.Scale.x,
			component == 'y' and new_value or Mesh.Scale.y,
			component == 'z' and new_value or Mesh.Scale.z
		);
	end;
	self:finishHistoryRecord();

end;

Tools.Mesh.changeTint = function ( self, component, new_value )

	local meshes = {};

	for _, Item in pairs( Selection.Items ) do
		local Mesh = _getChildOfClass( Item, "SpecialMesh" );
		if Mesh then
			table.insert( meshes, Mesh );
		end;
	end;

	self:startHistoryRecord( meshes );
	for _, Mesh in pairs( meshes ) do
		Mesh.VertexColor = Vector3.new(
			component == 'r' and new_value or Mesh.VertexColor.x,
			component == 'g' and new_value or Mesh.VertexColor.y,
			component == 'b' and new_value or Mesh.VertexColor.z
		);
	end;
	self:finishHistoryRecord();

end;

Tools.Mesh.hideGUI = function ( self )

	-- Hide the GUI if it exists already
	if self.GUI then
		self.GUI.Visible = false;
	end;

end;

Tools.Mesh.Loaded = true;