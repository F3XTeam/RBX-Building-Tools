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

				-- Get the common surface type
				local SelectionSurfaceTypes = {};
				if self.Options.side == '*' then
					for _, Part in pairs(Selection.Items) do
						table.insert(SelectionSurfaceTypes, Part.TopSurface);
						table.insert(SelectionSurfaceTypes, Part.BottomSurface);
						table.insert(SelectionSurfaceTypes, Part.LeftSurface);
						table.insert(SelectionSurfaceTypes, Part.RightSurface);
						table.insert(SelectionSurfaceTypes, Part.FrontSurface);
						table.insert(SelectionSurfaceTypes, Part.BackSurface);
					end;
				else
					local SurfacePropertyName = self.Options.side.Name .. 'Surface';
					for _, Part in pairs(Selection.Items) do
						table.insert(SelectionSurfaceTypes, Part[SurfacePropertyName]);
					end;
				end;
				local CommonSurfaceType = Support.IdentifyCommonItem(SelectionSurfaceTypes);

				self.State.type = CommonSurfaceType;

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

Tools.Surface.Listeners.Button2Down = function ()

	local self = Tools.Surface;

	-- Capture the camera rotation (for later use
	-- in determining whether a surface was being
	-- selected or the camera was being rotated
	-- with the right mouse button)
	local cr_x, cr_y, cr_z = Workspace.CurrentCamera.CoordinateFrame:toEulerAnglesXYZ();
	self.State.PreB2DownCameraRotation = Vector3.new( cr_x, cr_y, cr_z );

end;

Tools.Surface.Listeners.Button2Up = function ()

	local self = Tools.Surface;

	local cr_x, cr_y, cr_z = Workspace.CurrentCamera.CoordinateFrame:toEulerAnglesXYZ();
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
		targets = Support.CloneTable(Selection.Items);
		target_surface = self.Options.side;
		initial_surfaces = {};
		terminal_surfaces = {};
		unapply = function ( self )
			Selection:clear();
			for _, Target in pairs( self.targets ) do
				if Target then
					for Surface, SurfaceType in pairs(self.initial_surfaces[Target]) do
						Target[Surface] = SurfaceType;
					end;
					Target:MakeJoints();
					Selection:add( Target );
				end;
			end;
		end;
		apply = function ( self )
			Selection:clear();
			for _, Target in pairs( self.targets ) do
				if Target then
					for Surface, SurfaceType in pairs(self.terminal_surfaces[Target]) do
						Target[Surface] = SurfaceType;
					end;
					Target:MakeJoints();
					Selection:add( Target );
				end;
			end;
		end;
	};
	for _, Item in pairs( self.State.HistoryRecord.targets ) do
		if Item then
			self.State.HistoryRecord.initial_surfaces[Item] = {};
			if self.State.HistoryRecord.target_surface == '*' then
				self.State.HistoryRecord.initial_surfaces[Item].RightSurface = Item.RightSurface;
				self.State.HistoryRecord.initial_surfaces[Item].LeftSurface = Item.LeftSurface;
				self.State.HistoryRecord.initial_surfaces[Item].FrontSurface = Item.FrontSurface;
				self.State.HistoryRecord.initial_surfaces[Item].BackSurface = Item.BackSurface;
				self.State.HistoryRecord.initial_surfaces[Item].TopSurface = Item.TopSurface;
				self.State.HistoryRecord.initial_surfaces[Item].BottomSurface = Item.BottomSurface;
			else
				self.State.HistoryRecord.initial_surfaces[Item][self.State.HistoryRecord.target_surface.Name .. 'Surface'] = Item[self.State.HistoryRecord.target_surface.Name .. 'Surface'];
			end;
		end;
	end;

end;

Tools.Surface.finishHistoryRecord = function ( self )

	if not self.State.HistoryRecord then
		return;
	end;

	for _, Item in pairs( self.State.HistoryRecord.targets ) do
		if Item then
			self.State.HistoryRecord.terminal_surfaces[Item] = {};
			if self.State.HistoryRecord.target_surface == '*' then
				self.State.HistoryRecord.terminal_surfaces[Item].RightSurface = Item.RightSurface;
				self.State.HistoryRecord.terminal_surfaces[Item].LeftSurface = Item.LeftSurface;
				self.State.HistoryRecord.terminal_surfaces[Item].FrontSurface = Item.FrontSurface;
				self.State.HistoryRecord.terminal_surfaces[Item].BackSurface = Item.BackSurface;
				self.State.HistoryRecord.terminal_surfaces[Item].TopSurface = Item.TopSurface;
				self.State.HistoryRecord.terminal_surfaces[Item].BottomSurface = Item.BottomSurface;
			else
				self.State.HistoryRecord.terminal_surfaces[Item][self.State.HistoryRecord.target_surface.Name .. 'Surface'] = Item[self.State.HistoryRecord.target_surface.Name .. 'Surface'];
			end;
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
		if self.Options.side == '*' then
			Item.FrontSurface = surface_type;
			Item.BackSurface = surface_type;
			Item.RightSurface = surface_type;
			Item.LeftSurface = surface_type;
			Item.TopSurface = surface_type;
			Item.BottomSurface = surface_type;
		else
			Item[self.Options.side.Name .. "Surface"] = surface_type;
		end;
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
	self.SideDropdown:selectOption( surface == '*' and 'ALL' or surface.Name:upper() );
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

		SideDropdown:addOption('ALL').MouseButton1Up:connect(function ()
			self:changeSurface('*');
		end);

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