-- Load the main tool's core environment when it's ready
repeat wait() until (
	_G.BTCoreEnv and
	_G.BTCoreEnv[script.Parent.Parent] and
	_G.BTCoreEnv[script.Parent.Parent].CoreReady
);
setfenv( 1, _G.BTCoreEnv[script.Parent.Parent] );

------------------------------------------
-- Surface tool
------------------------------------------

-- Create the tool
Tools.Surface = {};

-- Define the tool's color
Tools.Surface.Color = BrickColor.new( "Bright violet" );

-- Keep a container for temporary connections
Tools.Surface.Connections = {};

-- Keep a container for state data
Tools.Surface.State = {
	["type"] = nil;
};

-- Maintain a container for options
Tools.Surface.Options = {
	["side"] = Enum.NormalId.Front;
};

-- Keep a container for platform event connections
Tools.Surface.Listeners = {};

-- Start adding functionality to the tool
Tools.Surface.Listeners.Equipped = function ()

	local self = Tools.Surface;

	-- Change the color of selection boxes temporarily
	self.State.PreviousSelectionBoxColor = SelectionBoxColor;
	SelectionBoxColor = self.Color;
	updateSelectionBoxColor();

	-- Reveal the GUI
	self:showGUI();

	-- Restore the side option
	self:changeSurface( self.Options.side );

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

				-- Update the surface type of every item in the selection
				local surface_type = nil;
				for item_index, Item in pairs( Selection.Items ) do

					-- Set the first values for the first item
					if item_index == 1 then
						surface_type = Item[self.Options.side.Name .. "Surface"];

					-- Otherwise, compare them and set them to `nil` if they're not identical
					else
						if surface_type ~= Item[self.Options.side.Name .. "Surface"] then
							surface_type = nil;
						end;
					end;

				end;

				self.State.type = surface_type;

				-- Update the GUI if it's visible
				if self.GUI and self.GUI.Visible then
					self:updateGUI();
				end;

			end;

		end;

	end )();

end;

Tools.Surface.Listeners.Unequipped = function ()

	local self = Tools.Surface;

	-- Stop the GUI updating loop
	self.Updater();
	self.Updater = nil;

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

Tools.Surface.Listeners.Button2Down = function ()

	local self = Tools.Surface;

	-- Capture the camera rotation (for later use
	-- in determining whether a surface was being
	-- selected or the camera was being rotated
	-- with the right mouse button)
	local cr_x, cr_y, cr_z = Services.Workspace.CurrentCamera.CoordinateFrame:toEulerAnglesXYZ();
	self.State.PreB2DownCameraRotation = Vector3.new( cr_x, cr_y, cr_z );

end;

Tools.Surface.Listeners.Button2Up = function ()

	local self = Tools.Surface;

	local cr_x, cr_y, cr_z = Services.Workspace.CurrentCamera.CoordinateFrame:toEulerAnglesXYZ();
	local CameraRotation = Vector3.new( cr_x, cr_y, cr_z );

	-- If a surface is selected
	if Selection:find( Mouse.Target ) and self.State.PreB2DownCameraRotation == CameraRotation then
		self:changeSurface( Mouse.TargetSurface );
	end;

end;

Tools.Surface.startHistoryRecord = function ( self )

	if self.State.HistoryRecord then
		self.State.HistoryRecord = nil;
	end;

	-- Create a history record
	self.State.HistoryRecord = {
		targets = _cloneTable( Selection.Items );
		target_surface = self.Options.side;
		initial_surfaces = {};
		terminal_surfaces = {};
		unapply = function ( self )
			Selection:clear();
			for _, Target in pairs( self.targets ) do
				if Target then
					Target[self.target_surface.Name .. "Surface"] = self.initial_surfaces[Target];
					Target:MakeJoints();
					Selection:add( Target );
				end;
			end;
		end;
		apply = function ( self )
			Selection:clear();
			for _, Target in pairs( self.targets ) do
				if Target then
					Target[self.target_surface.Name .. "Surface"] = self.terminal_surfaces[Target];
					Target:MakeJoints();
					Selection:add( Target );
				end;
			end;
		end;
	};
	for _, Item in pairs( self.State.HistoryRecord.targets ) do
		if Item then
			self.State.HistoryRecord.initial_surfaces[Item] = Item[self.Options.side.Name .. "Surface"];
		end;
	end;

end;

Tools.Surface.finishHistoryRecord = function ( self )

	if not self.State.HistoryRecord then
		return;
	end;

	for _, Item in pairs( self.State.HistoryRecord.targets ) do
		if Item then
			self.State.HistoryRecord.terminal_surfaces[Item] = Item[self.Options.side.Name .. "Surface"];
		end;
	end;
	History:add( self.State.HistoryRecord );
	self.State.HistoryRecord = nil;

end;

Tools.Surface.SpecialTypeNames = {
	SmoothNoOutlines = "NO OUTLINE",
	Inlet = "INLETS"
};

Tools.Surface.changeType = function ( self, surface_type )

	self:startHistoryRecord();

	-- Apply `surface_type` to all items in the selection
	for _, Item in pairs( Selection.Items ) do
		Item[self.Options.side.Name .. "Surface"] = surface_type;
		Item:MakeJoints();
	end;

	self:finishHistoryRecord();

	self.TypeDropdown:selectOption( self.SpecialTypeNames[surface_type.Name] or surface_type.Name:upper() );
	if self.TypeDropdown.open then
		self.TypeDropdown:toggle();
	end;
end;

Tools.Surface.changeSurface = function ( self, surface )
	self.Options.side = surface;
	self.SideDropdown:selectOption( surface.Name:upper() );
	if self.SideDropdown.open then
		self.SideDropdown:toggle();
	end;
end;

Tools.Surface.updateGUI = function ( self )

	-- Make sure the GUI exists
	if not self.GUI then
		return;
	end;

	if #Selection.Items > 0 then
		self.TypeDropdown:selectOption( self.State.type and ( self.SpecialTypeNames[self.State.type.Name] or self.State.type.Name:upper() ) or "*" );
	else
		self.TypeDropdown:selectOption( "" );
	end;

end;

Tools.Surface.showGUI = function ( self )

	-- Initialize the GUI if it's not ready yet
	if not self.GUI then

		local Container = Tool.Interfaces.BTSurfaceToolGUI:Clone();
		Container.Parent = UI;

		local SideDropdown = createDropdown();
		self.SideDropdown = SideDropdown;
		SideDropdown.Frame.Parent = Container.SideOption;
		SideDropdown.Frame.Position = UDim2.new( 0, 30, 0, 0 );
		SideDropdown.Frame.Size = UDim2.new( 0, 72, 0, 25 );

		SideDropdown:addOption( "TOP" ).MouseButton1Up:connect( function ()
			self:changeSurface( Enum.NormalId.Top );
		end );
		SideDropdown:addOption( "BOTTOM" ).MouseButton1Up:connect( function ()
			self:changeSurface( Enum.NormalId.Bottom );
		end );
		SideDropdown:addOption( "FRONT" ).MouseButton1Up:connect( function ()
			self:changeSurface( Enum.NormalId.Front );
		end );
		SideDropdown:addOption( "BACK" ).MouseButton1Up:connect( function ()
			self:changeSurface( Enum.NormalId.Back );
		end );
		SideDropdown:addOption( "LEFT" ).MouseButton1Up:connect( function ()
			self:changeSurface( Enum.NormalId.Left );
		end );
		SideDropdown:addOption( "RIGHT" ).MouseButton1Up:connect( function ()
			self:changeSurface( Enum.NormalId.Right );
		end );

		local TypeDropdown = createDropdown();
		self.TypeDropdown = TypeDropdown;
		TypeDropdown.Frame.Parent = Container.TypeOption;
		TypeDropdown.Frame.Position = UDim2.new( 0, 30, 0, 0 );
		TypeDropdown.Frame.Size = UDim2.new( 0, 87, 0, 25 );

		TypeDropdown:addOption( "STUDS" ).MouseButton1Up:connect( function ()
			self:changeType( Enum.SurfaceType.Studs );
		end );
		TypeDropdown:addOption( "INLETS" ).MouseButton1Up:connect( function ()
			self:changeType( Enum.SurfaceType.Inlet );
		end );
		TypeDropdown:addOption( "SMOOTH" ).MouseButton1Up:connect( function ()
			self:changeType( Enum.SurfaceType.Smooth );
		end );
		TypeDropdown:addOption( "WELD" ).MouseButton1Up:connect( function ()
			self:changeType( Enum.SurfaceType.Weld );
		end );
		TypeDropdown:addOption( "GLUE" ).MouseButton1Up:connect( function ()
			self:changeType( Enum.SurfaceType.Glue );
		end );
		TypeDropdown:addOption( "UNIVERSAL" ).MouseButton1Up:connect( function ()
			self:changeType( Enum.SurfaceType.Universal );
		end );
		TypeDropdown:addOption( "HINGE" ).MouseButton1Up:connect( function ()
			self:changeType( Enum.SurfaceType.Hinge );
		end );
		TypeDropdown:addOption( "MOTOR" ).MouseButton1Up:connect( function ()
			self:changeType( Enum.SurfaceType.Motor );
		end );
		TypeDropdown:addOption( "NO OUTLINE" ).MouseButton1Up:connect( function ()
			self:changeType( Enum.SurfaceType.SmoothNoOutlines );
		end );

		self.GUI = Container;

	end;

	-- Reveal the GUI
	self.GUI.Visible = true;

end;

Tools.Surface.hideGUI = function ( self )

	-- Hide the GUI if it exists already
	if self.GUI then
		self.GUI.Visible = false;
	end;

end;

Tools.Surface.Loaded = true;