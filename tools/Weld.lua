-- Load the main tool's core environment when it's ready
repeat wait() until (
	_G.BTCoreEnv and
	_G.BTCoreEnv[script.Parent.Parent] and
	_G.BTCoreEnv[script.Parent.Parent].CoreReady
);
setfenv( 1, _G.BTCoreEnv[script.Parent.Parent] );

------------------------------------------
-- Weld tool
------------------------------------------

-- Create the tool
Tools.Weld = {};

-- Define the tool's color
Tools.Weld.Color = BrickColor.new( "Really black" );

-- Keep a container for state data
Tools.Weld.State = {};

-- Keep a container for temporary connections
Tools.Weld.Connections = {};

-- Keep a container for platform event connections
Tools.Weld.Listeners = {};

-- Start adding functionality to the tool
Tools.Weld.Listeners.Equipped = function ()

	local self = Tools.Weld;

	-- Change the color of selection boxes temporarily
	self.State.PreviousSelectionBoxColor = SelectionBoxColor;
	SelectionBoxColor = self.Color;
	updateSelectionBoxColor();

	-- Reveal the GUI
	self:showGUI();

	-- Highlight the last part in the selection
	if Selection.Last and SelectionBoxes[Selection.Last] then
		SelectionBoxes[Selection.Last].Color = BrickColor.new( "Pastel Blue" );
	end;
	self.Connections.LastPartHighlighter = Selection.Changed:connect( function ()
		updateSelectionBoxColor();
		if Selection.Last and SelectionBoxes[Selection.Last] then
			SelectionBoxes[Selection.Last].Color = BrickColor.new( "Pastel Blue" );
		end;
	end );

end;

Tools.Weld.Listeners.Unequipped = function ()

	local self = Tools.Weld;

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

Tools.Weld.Listeners.Button2Down = function ()

	local self = Tools.Weld;

	-- Capture the camera rotation (for later use
	-- in determining whether a surface was being
	-- selected or the camera was being rotated
	-- with the right mouse button)
	local cr_x, cr_y, cr_z = Workspace.CurrentCamera.CoordinateFrame:toEulerAnglesXYZ();
	self.State.PreB2DownCameraRotation = Vector3.new( cr_x, cr_y, cr_z );

end;

Tools.Weld.Listeners.Button2Up = function ()

	local self = Tools.Weld;

	local cr_x, cr_y, cr_z = Workspace.CurrentCamera.CoordinateFrame:toEulerAnglesXYZ();
	local CameraRotation = Vector3.new( cr_x, cr_y, cr_z );

	-- If a part is selected
	if Selection:find( Mouse.Target ) and self.State.PreB2DownCameraRotation == CameraRotation then
		Selection:focus( Mouse.Target );
	end;

end;

Tools.Weld.weld = function ( self )

	local HistoryRecord = {
		weld_parents = {};
		unapply = function ( self )
			Selection:clear();
			for _, Weld in pairs( self.welds ) do
				Selection:add( Weld.Part0 );
				Selection:add( Weld.Part1 );
				Weld.Parent = nil;
			end;
		end;
		apply = function ( self )
			Selection:clear();
			for _, Weld in pairs( self.welds ) do
				Weld.Parent = self.weld_parents[Weld];
				Selection:add( Weld.Part0 );
				Selection:add( Weld.Part1 );
			end;
		end;
	};

	-- Keep track of the welds we create
	local welds = {};

	-- Make sure there's more than one item
	if #Selection.Items > 1 and Selection.Last then

		-- Weld all the parts to the last part
		for _, Item in pairs( Selection.Items ) do
			if Item ~= Selection.Last then
				local Weld = RbxUtility.Create "Weld" {
					Name = 'BTWeld';
					Parent = Selection.Last;
					Part0 = Selection.Last;
					Part1 = Item;
					Archivable = false;

					-- Calculate the offset of `Item` from `Selection.Last`
					C1 = Item.CFrame:toObjectSpace( Selection.Last.CFrame );
				};
				table.insert( welds, Weld );
				HistoryRecord.weld_parents[Weld] = Weld.Parent;
			end;
		end;

	end;

	HistoryRecord.welds = welds;
	History:add( HistoryRecord );

	-- Update the change bar
	self.GUI.Changes.Text.Text = "created " .. #welds .. " weld" .. ( #welds ~= 1 and "s" or "" );

	-- Play a confirmation sound
	local Sound = RbxUtility.Create "Sound" {
		Name = "BTActionCompletionSound";
		Pitch = 1.5;
		SoundId = Assets.ActionCompletionSound;
		Volume = 1;
		Parent = Player;
	};
	Sound:Play();
	Sound:Destroy();

end;

Tools.Weld.breakWelds = function ( self )

	local HistoryRecord = {
		weld_parents = {};
		apply = function ( self )
			Selection:clear();
			for _, Weld in pairs( self.welds ) do
				Selection:add( Weld.Part0 );
				Selection:add( Weld.Part1 );
				Weld.Parent = nil;
			end;
		end;
		unapply = function ( self )
			Selection:clear();
			for _, Weld in pairs( self.welds ) do
				Selection:add( Weld.Part1 );
				Selection:add( Weld.Part0 );
				Weld.Parent = self.weld_parents[Weld];
			end;
		end;
	};

	-- Break any welds we created for each item in the selection
	local welds = {};
	local all_objects = Support.GetAllDescendants(Game.Workspace);
	for _, Weld in pairs( all_objects ) do
		if Weld:IsA( "Weld" ) and Weld.Name == "BTWeld" then
			for _, Item in pairs( Selection.Items ) do
				if Weld.Part0 == Item or Weld.Part1 == Item then
					if not HistoryRecord.weld_parents[Weld] then
						table.insert( welds, Weld );
						HistoryRecord.weld_parents[Weld] = Weld.Parent;
						Weld.Parent = nil;
					end;
				end;
			end;
		end;
	end;

	HistoryRecord.welds = welds;
	History:add( HistoryRecord );

	-- Update the change bar
	self.GUI.Changes.Text.Text = "broke " .. #welds .. " weld" .. ( #welds ~= 1 and "s" or "" );

	-- Play a confirmation sound
	local Sound = RbxUtility.Create "Sound" {
		Name = "BTActionCompletionSound";
		Pitch = 1.5;
		SoundId = Assets.ActionCompletionSound;
		Volume = 1;
		Parent = Player;
	};
	Sound:Play();
	Sound:Destroy();

end;

Tools.Weld.showGUI = function ( self )

	-- Initialize the GUI if it's not ready yet
	if not self.GUI then

		local Container = Tool.Interfaces.BTWeldToolGUI:Clone();
		Container.Parent = UI;

		Container.Interface.WeldButton.MouseButton1Up:connect( function ()
			self:weld();
		end );

		Container.Interface.BreakWeldsButton.MouseButton1Up:connect( function ()
			self:breakWelds();
		end );

		self.GUI = Container;
	end;

	-- Reveal the GUI
	self.GUI.Visible = true;

end;

Tools.Weld.hideGUI = function ( self )

	-- Hide the GUI if it exists already
	if self.GUI then
		self.GUI.Visible = false;
	end;

end;

Tools.Weld.Loaded = true;