-- Load the main tool's core environment when it's ready
repeat wait() until (
	_G.BTCoreEnv and
	_G.BTCoreEnv[script.Parent.Parent] and
	_G.BTCoreEnv[script.Parent.Parent].CoreReady
);
setfenv( 1, _G.BTCoreEnv[script.Parent.Parent] );

------------------------------------------
-- New part tool
------------------------------------------

-- Create the tool
Tools.NewPart = {};

-- Define the tool's color
Tools.NewPart.Color = BrickColor.new( "Really black" );

-- Keep a container for temporary connections
Tools.NewPart.Connections = {};

Tools.NewPart.Templates = {};

-- Keep a container for state data
Tools.NewPart.State = {
	["Part"] = nil;
};

-- Maintain a container for options
Tools.NewPart.Options = {
	["type"] = "normal"
};

-- Keep a container for platform event connections
Tools.NewPart.Listeners = {};

-- Start adding functionality to the tool
Tools.NewPart.Listeners.Equipped = function ()

	local self = Tools.NewPart;

	-- Change the color of selection boxes temporarily
	self.State.PreviousSelectionBoxColor = SelectionBoxColor;
	SelectionBoxColor = self.Color;
	updateSelectionBoxColor();

	-- Reveal the GUI
	self:showGUI();

	-- Restore the type option
	self:changeType( self.Options.type );

end;

Tools.NewPart.Listeners.Unequipped = function ()

	local self = Tools.NewPart;

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

Tools.NewPart.Listeners.Button1Down = function ()

	local self = Tools.NewPart;

	local NewPart;

	-- Create the new part of type `self.Options.type`
	if self.Options.type == "normal" then
		NewPart = Instance.new( "Part", Services.Workspace );
		NewPart.FormFactor = Enum.FormFactor.Custom;
		NewPart.Size = Vector3.new( 4, 1, 2 );
	elseif self.Options.type == "truss" then
		NewPart = Instance.new( "TrussPart", Services.Workspace );
	elseif self.Options.type == "wedge" then
		NewPart = Instance.new( "WedgePart", Services.Workspace );
		NewPart.FormFactor = Enum.FormFactor.Custom;
		NewPart.Size = Vector3.new( 4, 1, 2 );
	elseif self.Options.type == "corner" then
		NewPart = Instance.new( "CornerWedgePart", Services.Workspace );
	elseif self.Options.type == "cylinder" then
		NewPart = Instance.new( "Part", Services.Workspace );
		NewPart.Shape = "Cylinder";
		NewPart.FormFactor = Enum.FormFactor.Custom;
		NewPart.TopSurface = Enum.SurfaceType.Smooth;
		NewPart.BottomSurface = Enum.SurfaceType.Smooth;
	elseif self.Options.type == "ball" then
		NewPart = Instance.new( "Part", Services.Workspace );
		NewPart.Shape = "Ball";
		NewPart.FormFactor = Enum.FormFactor.Custom;
		NewPart.TopSurface = Enum.SurfaceType.Smooth;
		NewPart.BottomSurface = Enum.SurfaceType.Smooth;
	elseif self.Options.type == "seat" then
		NewPart = Instance.new( "Seat", Services.Workspace );
		NewPart.FormFactor = Enum.FormFactor.Custom;
		NewPart.Size = Vector3.new( 4, 1, 2 );
	elseif self.Options.type == "vehicle seat" then
		NewPart = Instance.new( "VehicleSeat", Services.Workspace );
		NewPart.Size = Vector3.new( 4, 1, 2 );
	elseif self.Options.type == "spawn" then
		NewPart = Instance.new( "SpawnLocation", Services.Workspace );
		NewPart.FormFactor = Enum.FormFactor.Custom;
		NewPart.Size = Vector3.new( 4, 1, 2 );
	elseif self.Templates[self.Options.type] then
		NewPart = self.Templates[self.Options.type]:Clone()
	end;
	NewPart.Anchored = true;

	-- Select the new part
	Selection:clear();
	Selection:add( NewPart );

	local HistoryRecord = {
		target = NewPart;
		apply = function ( self )
			Selection:clear();
			if self.target then
				self.target.Parent = Services.Workspace;
				Selection:add( self.target );
			end;
		end;
		unapply = function ( self )
			if self.target then
				self.target.Parent = nil;
			end;
		end;
	};
	History:add( HistoryRecord );

	-- Switch to the move tool and simulate clicking so
	-- that the user could easily position their new part
	equipTool( Tools.Move );
	Tools.Move.ManualTarget = NewPart;
	NewPart.CFrame = Mouse.Hit;
	Tools.Move.Listeners.Button1Down();
	Tools.Move.Listeners.Move();

end;

Tools.NewPart.Listeners.Button2Down = function() 
	local self = Tools.NewPart
	NewTemplate = Mouse.Target
	if NewTemplate and NewTemplate:IsA("BasePart") then
		self:AddType( NewTemplate )
	end
end)

Tools.NewPart.changeType = function ( self, new_type )
	self.Options.type = new_type;
	self.TypeDropdown:selectOption( new_type:upper() );
	if self.TypeDropdown.open then
		self.TypeDropdown:toggle();
	end;
end;

Tools.NewPart.AddType = function ( self, template )
	local TemplateName = "template"..tostring(#self.Templates+1)
	self.Templates[TemplateName] = template:Clone()
	self.TypeDropdown:addOption( TemplateName:upper() ) ).MouseButton1Up:connect( function ()
		self:changeType( TemplateName )
	end )
end;

Tools.NewPart.showGUI = function ( self )

	-- Initialize the GUI if it's not ready yet
	if not self.GUI then

		local Container = Tool.Interfaces.BTNewPartToolGUI:Clone();
		Container.Parent = UI;

		local TypeDropdown = createDropdown();
		self.TypeDropdown = TypeDropdown;
		TypeDropdown.Frame.Parent = Container.TypeOption;
		TypeDropdown.Frame.Position = UDim2.new( 0, 70, 0, 0 );
		TypeDropdown.Frame.Size = UDim2.new( 0, 140, 0, 25 );

		TypeDropdown:addOption( "NORMAL" ).MouseButton1Up:connect( function ()
			self:changeType( "normal" );
		end );
		TypeDropdown:addOption( "TRUSS" ).MouseButton1Up:connect( function ()
			self:changeType( "truss" );
		end );
		TypeDropdown:addOption( "WEDGE" ).MouseButton1Up:connect( function ()
			self:changeType( "wedge" );
		end );
		TypeDropdown:addOption( "CORNER" ).MouseButton1Up:connect( function ()
			self:changeType( "corner" );
		end );
		TypeDropdown:addOption( "CYLINDER" ).MouseButton1Up:connect( function ()
			self:changeType( "cylinder" );
		end );
		TypeDropdown:addOption( "BALL" ).MouseButton1Up:connect( function ()
			self:changeType( "ball" );
		end );
		TypeDropdown:addOption( "SEAT" ).MouseButton1Up:connect( function ()
			self:changeType( "seat" );
		end );
		TypeDropdown:addOption( "VEHICLE SEAT" ).MouseButton1Up:connect( function ()
			self:changeType( "vehicle seat" );
		end );
		TypeDropdown:addOption( "SPAWN" ).MouseButton1Up:connect( function ()
			self:changeType( "spawn" );
		end );

		self.GUI = Container;
	end;

	-- Reveal the GUI
	self.GUI.Visible = true;

end;

Tools.NewPart.hideGUI = function ( self )

	-- Hide the GUI if it exists already
	if self.GUI then
		self.GUI.Visible = false;
	end;

end;

Tools.NewPart.Loaded = true;
