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
Tools.NewPart.Name = 'New Part Tool';

-- Define the tool's color
Tools.NewPart.Color = BrickColor.new( "Really black" );

-- Keep a container for temporary connections
Tools.NewPart.Connections = {};

-- Keep a container for state data
Tools.NewPart.State = {
	["Part"] = nil;
};

-- Maintain a container for options
Tools.NewPart.Options = {
	["type"] = "Normal"
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

	-- If in filter mode, request from the server the creation of a new part of type `Options.type`
	if FilterMode then
		NewPart = ServerAPI:InvokeServer('CreatePart', self.Options.type, CFrame.new(Mouse.Hit.p));

	-- Otherwise, create the part locally instantly
	else
		NewPart = Support.CreatePart(self.Options.type);
		NewPart.Parent = Workspace;
		NewPart.CFrame = CFrame.new(Mouse.Hit.p);
	end;

	-- Select the new part
	Selection:clear();
	Selection:add( NewPart );

	local HistoryRecord = {
		target = NewPart;
		Apply = function ( self )
			Selection:clear();
			if self.target then
				SetParent(self.target, Workspace);
				Selection:add(self.target);
			end;
		end;
		Unapply = function ( self )
			if self.target then
				SetParent(self.target, nil);
			end;
		end;
	};
	History:Add( HistoryRecord );

	-- Switch to the move tool and simulate clicking so
	-- that the user could easily position their new part
	equipTool( Tools.Move );
	Tools.Move.ManualTarget = NewPart;
	Tools.Move.Listeners.Button1Down();
	Tools.Move.Listeners.Move();

end;

Tools.NewPart.changeType = function ( self, new_type )
	self.Options.type = new_type;
	self.TypeDropdown:selectOption( new_type:upper() );
	if self.TypeDropdown.open then
		self.TypeDropdown:toggle();
	end;
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


		local Types = { 'Normal', 'Truss', 'Wedge', 'Corner', 'Cylinder', 'Ball', 'Seat', 'Vehicle Seat', 'Spawn' };

		-- Add dropdown options for every type
		for _, Type in pairs(Types) do
			TypeDropdown:addOption(Type:upper()).MouseButton1Up:connect(function ()
				self:changeType(Type);
			end);
		end;

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