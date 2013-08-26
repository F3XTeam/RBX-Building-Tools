-- ROBLOX Object Properties =========
-- [Name] Building Tools by F3X
-- [ClassName] LocalScript
-- [Parent] Building Tools
-- ==================================

------------------------------------------
-- Create references to important objects
------------------------------------------
Services = {
	["Workspace"] = game:GetService( "Workspace" );
	["Players"] = game:GetService( "Players" );
	["Lighting"] = game:GetService( "Lighting" );
	["Teams"] = game:GetService( "Teams" );
	["Debris"] = game:GetService( "Debris" );
	["MarketplaceService"] = game:GetService( "MarketplaceService" );
	["JointsService"] = game.JointsService;
	["BadgeService"] = game:GetService( "BadgeService" );
	["RunService"] = game:GetService( "RunService" );
	["ContentProvider"] = game:GetService( "ContentProvider" );
	["TeleportService"] = game:GetService( "TeleportService" );
	["SoundService"] = game:GetService( "SoundService" );
	["InsertService"] = game:GetService( "InsertService" );
	["CollectionService"] = game:GetService( "CollectionService" );
	["UserInputService"] = game:GetService( "UserInputService" );
	["GamePassService"] = game:GetService( "GamePassService" );
	["StarterPack"] = game:GetService( "StarterPack" );
	["StarterGui"] = game:GetService( "StarterGui" );
};

Tool = script.Parent;
Player = Services.Players.LocalPlayer;
Mouse = nil;

dark_slanted_rectangle = "http://www.roblox.com/asset/?id=127774197";
light_slanted_rectangle = "http://www.roblox.com/asset/?id=127772502";

------------------------------------------
-- Load external dependencies
------------------------------------------
RbxUtility = LoadLibrary( "RbxUtility" );
Services.ContentProvider:Preload( dark_slanted_rectangle );
Services.ContentProvider:Preload( light_slanted_rectangle );

------------------------------------------
-- Define functions that are depended-upon
------------------------------------------
function _findTableOccurrences( haystack, needle )
	-- Returns the positions of instances of `needle` in table `haystack`
	local positions = {};

	-- Add any indexes from `haystack` that have `needle`
	for index, value in pairs( haystack ) do
		if value == needle then
			table.insert( positions, index );
		end;
	end;

	return positions;
end;

function _getCollectionInfo( part_collection )
	-- Returns the size and position of collection of parts `part_collection`

	-- Get the corners
	local corners = {};

	for _, Part in pairs( part_collection ) do

		table.insert( corners, Part.CFrame:toWorldSpace( CFrame.new( Part.Size.x / 2, Part.Size.y / 2, Part.Size.z / 2 ) ) );
		table.insert( corners, Part.CFrame:toWorldSpace( CFrame.new( -Part.Size.x / 2, Part.Size.y / 2, Part.Size.z / 2 ) ) );
		table.insert( corners, Part.CFrame:toWorldSpace( CFrame.new( Part.Size.x / 2, -Part.Size.y / 2, Part.Size.z / 2 ) ) );
		table.insert( corners, Part.CFrame:toWorldSpace( CFrame.new( Part.Size.x / 2, Part.Size.y / 2, -Part.Size.z / 2 ) ) );
		table.insert( corners, Part.CFrame:toWorldSpace( CFrame.new( -Part.Size.x / 2, Part.Size.y / 2, -Part.Size.z / 2 ) ) );
		table.insert( corners, Part.CFrame:toWorldSpace( CFrame.new( -Part.Size.x / 2, -Part.Size.y / 2, Part.Size.z / 2 ) ) );
		table.insert( corners, Part.CFrame:toWorldSpace( CFrame.new( Part.Size.x / 2, -Part.Size.y / 2, -Part.Size.z / 2 ) ) );
		table.insert( corners, Part.CFrame:toWorldSpace( CFrame.new( -Part.Size.x / 2, -Part.Size.y / 2, -Part.Size.z / 2 ) ) );

	end;

	-- Get the extents
	local x, y, z = {}, {}, {};

	for _, Corner in pairs( corners ) do
		table.insert( x, Corner.x );
		table.insert( y, Corner.y );
		table.insert( z, Corner.z );
	end;

	local x_min, y_min, z_min = math.min( unpack( x ) ),
								math.min( unpack( y ) ),
								math.min( unpack( z ) );

	local x_max, y_max, z_max = math.max( unpack( x ) ),
								math.max( unpack( y ) ),
								math.max( unpack( z ) );

	-- Get the size between the extents
	local x_size, y_size, z_size = 	x_max - x_min,
									y_max - y_min,
									z_max - z_min;

	local Size = Vector3.new( x_size, y_size, z_size );

	-- Get the centroid of the collection of points
	local Position = CFrame.new( 	x_min + ( x_max - x_min ) / 2,
									y_min + ( y_max - y_min ) / 2,
									z_min + ( z_max - z_min ) / 2 );

	-- Return the size of the collection of parts
	return Size, Position;
end;

------------------------------------------
-- Create data containers
------------------------------------------
ActiveKeys = {};

Options = setmetatable( {

	["_options"] = {
		["Tool"] = nil
	}

}, {

	__newindex = function ( self, key, value )

		-- Do different special things depending on `key`
		if key == "Tool" then

			-- If it's a different tool than the current one
			if self.Tool ~= value then

				-- Run (if existent) the old tool's `Unequipped` listener
				if Options.Tool and Options.Tool.Listeners.Unequipped then
					Options.Tool.Listeners.Unequipped();
				end;

				rawget( self, "_options" ).Tool = nil;

				-- Replace the current handle with `value.Handle`
				local Handle = Tool:FindFirstChild( "Handle" );
				if Handle then
					Handle.Parent = nil;
				end;
				value.Handle.Parent = Tool;

				-- Adjust the grip for the new handle
				Tool.Grip = value.Grip;

				-- Run (if existent) the new tool's `Equipped` listener
				if value.Listeners.Equipped then
					value.Listeners.Equipped();
				end;

			end;
		end;

		-- Set the value normally to `self._options`
		rawget( self, "_options" )[key] = value;

	end;

	-- Get any options from `self._options` instead of `self` directly
	__index = function ( self, key )
		return rawget( self, "_options" )[key];
	end;

} );

-- Keep some state data
clicking = false;
selecting = false;
click_x, click_y = 0, 0;
override_selection = false;

SelectionBoxes = {};
SelectionExistenceListeners = {};
SelectionBoxColor = BrickColor.new( "Cyan" );

function updateSelectionBoxColor()
	-- Updates the color of the selectionboxes
	for _, SelectionBox in pairs( SelectionBoxes ) do
		SelectionBox.Color = SelectionBoxColor;
	end;
end;

Selection = {

	["Items"] = {};

	-- Provide events to listen to changes in the selection
	["Changed"] = RbxUtility.CreateSignal();
	["ItemAdded"] = RbxUtility.CreateSignal();
	["ItemRemoved"] = RbxUtility.CreateSignal();

	-- Provide a method to get an item's index in the selection
	["find"] = function ( self, Needle )

		-- Look through all the selected items and return the matching item's index
		for item_index, Item in pairs( self.Items ) do
			if Item == Needle then
				return item_index;
			end;
		end;

		-- Otherwise, return `nil`

	end;

	-- Provide a method to add items to the selection
	["add"] = function ( self, NewPart )

		-- Make sure `NewPart` isn't already in the selection
		if #_findTableOccurrences( self.Items, NewPart ) > 0 then
			return false;
		end;

		-- Insert it into the selection
		table.insert( self.Items, NewPart );

		-- Add its SelectionBox
		SelectionBoxes[NewPart] = Instance.new( "SelectionBox", Player.PlayerGui );
		SelectionBoxes[NewPart].Name = "BTSelectionBox";
		SelectionBoxes[NewPart].Color = SelectionBoxColor;
		SelectionBoxes[NewPart].Adornee = NewPart;

		-- Make sure to remove the item from the selection when it's deleted
		SelectionExistenceListeners[NewPart] = NewPart.AncestryChanged:connect( function ( Object, NewParent )
			if NewParent == nil then
				Selection:remove( NewPart );
			end;
		end );

		-- Fire events
		self.ItemAdded:fire( NewPart );
		self.Changed:fire();

	end;

	-- Provide a method to remove items from the selection
	["remove"] = function ( self, Item )

		-- Look for `Item` in the selection
		local index = self:find( Item );

		-- Make sure selection item `index` exists
		if not index then
			return false;
		end

		-- Remove `Item`'s SelectionBox
		local SelectionBox = SelectionBoxes[Item];
		if SelectionBox then
			SelectionBox:Destroy();
		end;
		SelectionBoxes[Item] = nil;

		-- Delete the item from the selection
		self.Items[index] = nil;

		-- Delete the existence listeners of the item
		SelectionExistenceListeners[Item]:disconnect();
		SelectionExistenceListeners[Item] = nil;

		-- Fire events
		self.ItemRemoved:fire( Item );
		self.Changed:fire();

	end;

	-- Provide a method to clear the selection
	["clear"] = function ( self )

		-- Go through all the items in the selection and call `self.remove` on them
		for index, Item in pairs( self.Items ) do
			self:remove( Item );
		end;

	end;

};

Tools = {};

------------------------------------------
-- Default tool
------------------------------------------

-- Create the main container for this tool
Tools.Default = {};

-- Keep a container for the tool's listeners
Tools.Default.Listeners = {};

-- Create the handle
Tools.Default.Handle = Instance.new( "Part" );
Tools.Default.Handle.Name = "Handle";
Tools.Default.Handle.CanCollide = false;

Instance.new( "SpecialMesh", Tools.Default.Handle ).Name = "Mesh";
Tools.Default.Handle.Mesh.MeshId = "http://www.roblox.com/asset/?id=16884681";
Tools.Default.Handle.Mesh.MeshType = Enum.MeshType.FileMesh;
Tools.Default.Handle.Mesh.Scale = Vector3.new( 0.6, 0.6, 0.6 );
Tools.Default.Handle.Mesh.TextureId = "http://www.roblox.com/asset/?id=16884673";

-- Set the grip for the handle
Tools.Default.Grip = CFrame.new( 0, 0, -0.4 ) * CFrame.Angles( math.rad( 90 ), math.rad( 90 ), 0 );

------------------------------------------
-- Paint tool
------------------------------------------

-- Create the main container for this tool
Tools.Paint = {};

-- Define options
Tools.Paint.Options = setmetatable( {

	["_options"] = {
		["Color"] = BrickColor.new( "Institutional white" ),
		["PaletteGUI"] = nil
	}

}, {

	-- Get the option from `self._options` instead of `self` directly
	__index = function ( self, key )
		return rawget( self, "_options" )[key];
	end;

	-- Let's do some special stuff if certain options are touched
	__newindex = function ( self, key, value )

		if key == "Color" then

			-- Mark the appropriate color in the palette
			if self.PaletteGUI then

				-- Clear any mark on any other color button from the palette
				for _, PaletteColorButton in pairs( self.PaletteGUI.Palette:GetChildren() ) do
					PaletteColorButton.Text = "";
				end;

				-- Mark the right color button in the palette
				self.PaletteGUI.Palette[value.Name].Text = "X";

			end;

			-- Change the color of selected items
			for _, Item in pairs( Selection.Items ) do
				Item.BrickColor = value;
			end;

		end;

		-- Set the option normally
		rawget( self, "_options" )[key] = value;

	end;

} );

-- Add listeners
Tools.Paint.Listeners = {};

Tools.Paint.Listeners.Equipped = function ()
	showPalette();
end;

Tools.Paint.Listeners.Unequipped = function ()
	hidePalette();
end;

Tools.Paint.Listeners.Button1Up = function ()

	-- Make sure that they clicked on one of the items in their selection
	if #_findTableOccurrences( Selection.Items, Mouse.Target ) > 0 then

		-- Paint all of the selected items `Tools.Paint.Options.Color`
		if Tools.Paint.Options.Color then
			for _, Item in pairs( Selection.Items ) do
				Item.BrickColor = Tools.Paint.Options.Color;
			end;
		end;

	end;

end;

-- Create the handle
Tools.Paint.Handle = Instance.new( "Part" );
Tools.Paint.Handle.Name = "Handle";
Tools.Paint.Handle.CanCollide = false;

Instance.new( "SpecialMesh", Tools.Paint.Handle ).Name = "Mesh";
Tools.Paint.Handle.Mesh.MeshId = "http://www.roblox.com/asset/?id=15952512";
Tools.Paint.Handle.Mesh.MeshType = Enum.MeshType.FileMesh;
Tools.Paint.Handle.Mesh.Scale = Vector3.new( 0.25, 0.25, 0.25 );
Tools.Paint.Handle.Mesh.TextureId = "http://www.roblox.com/asset/?id=15952494";

-- Set the grip for the handle
Tools.Paint.Grip = CFrame.new( 0, 1, 0 ) * CFrame.Angles( 0, math.rad( 90 ), 0 );

function showPalette()
	-- Reveals a color palette

	-- Create the GUI container
	local PaletteGUI = Instance.new( "ScreenGui", Player.PlayerGui );
	PaletteGUI.Name = "BTColorPalette";

	-- Register the GUI
	Tools.Paint.Options.PaletteGUI = PaletteGUI;

	-- Create the frame that will contain the colors
	local PaletteFrame = Instance.new( "Frame", PaletteGUI );
	PaletteFrame.Name = "Palette";
	PaletteFrame.BackgroundColor3 = Color3.new( 0, 0, 0 );
	PaletteFrame.Transparency = 1;
	PaletteFrame.Size = UDim2.new( 0, 205, 0, 205 );
	PaletteFrame.Position = UDim2.new( 0, 0, 1 / 3, 0 );
	PaletteFrame.Draggable = true;
	PaletteFrame.Active = true;

	-- Insert the colors
	for palette_index = 0, 63 do

		-- Get BrickColor `palette_index` from the palette
		local Color = BrickColor.palette( palette_index );

		-- Calculate the row and column in the 8x8 grid
		local row = ( palette_index - ( palette_index % 8 ) ) / 8;
		local column = palette_index % 8;

		-- Create the button
		local ColorButton = Instance.new( "TextButton", PaletteFrame );
		ColorButton.Name = Color.Name;
		ColorButton.BackgroundColor3 = Color.Color;
		ColorButton.Size = UDim2.new( 0, 20, 0, 20 );
		ColorButton.Text = "";
		ColorButton.TextStrokeTransparency = 0.75;
		ColorButton.Font = Enum.Font.ArialBold;
		ColorButton.FontSize = Enum.FontSize.Size18;
		ColorButton.TextColor3 = Color3.new( 1, 1, 1 );
		ColorButton.TextStrokeColor3 = Color3.new( 0, 0, 0 );
		ColorButton.Position = UDim2.new( 0, column * 25 + 5, 0, row * 25 + 5 );
		ColorButton.BorderSizePixel = 0;

		-- Make the button change the `Color` option
		ColorButton.MouseButton1Click:connect( function ()
			Tools.Paint.Options.Color = Color;
		end );

	end;

end;

function hidePalette()

	if Tools.Paint.Options.PaletteGUI then
		Tools.Paint.Options.PaletteGUI:Destroy();
		Tools.Paint.Options.PaletteGUI = nil;
	end;

end;

------------------------------------------
-- Move tool
------------------------------------------

-- Create the main container for this tool
Tools.Move = {};

-- Keep a container for the handles and other temporary stuff
Tools.Move.Temporary = {
	["Handles"] = nil;
	["BoundaryBox"] = nil;
	["BoundarySelectionBox"] = nil;
	["Connections"] = {};
	["MovementListeners"] = {};
	["PreviousSelectionBoxColor"] = nil;
};

-- Keep options in a container too
Tools.Move.Options = {
	["increment"] = 1;
	["axes"] = "global";
};

-- Keep internal state data in its own container
Tools.Move.State = {
	["previous_distance"] = 0;
};

-- Add listeners
Tools.Move.Listeners = {};

Tools.Move.Listeners.Equipped = function ()

	-- Change the color of selection boxes temporarily
	Tools.Move.Temporary.PreviousSelectionBoxColor = SelectionBoxColor;
	SelectionBoxColor = BrickColor.new( "Deep orange" );
	updateSelectionBoxColor();

	Tools.Move.Temporary.BoundaryBox = Tools.Move:createBoundaryBox();

	table.insert( Tools.Move.Temporary.Connections, Selection.Changed:connect( function ()
		Tools.Move.Temporary.BoundaryBox = Tools.Move:updateBoundaryBox( Tools.Move.Temporary.BoundaryBox, Selection.Items );
	end ) );

	-- Listen to movement in any existing selection parts
	for _, Item in pairs( Selection.Items ) do
		Tools.Move.Temporary.MovementListeners[Item] = Item.Changed:connect( function ( property )
			if property == "CFrame" then
				Tools.Move.Temporary.BoundaryBox = Tools.Move:updateBoundaryBox( Tools.Move.Temporary.BoundaryBox, Selection.Items );
			end;
		end );
	end;
	table.insert( Tools.Move.Temporary.Connections, Selection.ItemAdded:connect( function ( Item )
		Tools.Move.Temporary.MovementListeners[Item] = Item.Changed:connect( function ( property )
			if property == "CFrame" then
				Tools.Move.Temporary.BoundaryBox = Tools.Move:updateBoundaryBox( Tools.Move.Temporary.BoundaryBox, Selection.Items );
			end;
		end );
	end ) );
	table.insert( Tools.Move.Temporary.Connections, Selection.ItemRemoved:connect( function ( Item )
		if Tools.Move.Temporary.MovementListeners[Item] then
			Tools.Move.Temporary.MovementListeners[Item]:disconnect();
			Tools.Move.Temporary.MovementListeners[Item] = nil;
		end;
	end ) );
	Tools.Move.Temporary.BoundaryUpdater = coroutine.create( function ()
		while true do
			wait( 0.1 );
			Tools.Move.Temporary.BoundaryBox = Tools.Move:updateBoundaryBox( Tools.Move.Temporary.BoundaryBox, Selection.Items );
		end;
	end );
	coroutine.resume( Tools.Move.Temporary.BoundaryUpdater );

	-- Create 3D movement handles
	Tools.Move.Temporary.Handles = Instance.new( "Handles", Player.PlayerGui );
	Tools.Move.Temporary.Handles.Name = "BTMovementHandles";
	Tools.Move.Temporary.Handles.Adornee = nil;
	Tools.Move.Temporary.Handles.Style = Enum.HandlesStyle.Resize;
	Tools.Move.Temporary.Handles.Color = BrickColor.new( "Deep orange" );

	-- Make sure to hide the handles when the boundary box is hidden
	table.insert( Tools.Move.Temporary.Connections, Tools.Move.Temporary.BoundaryBox.AncestryChanged:connect( function ( Object, NewParent )
 		if NewParent == nil then
			Tools.Move.Temporary.Handles.Adornee = nil;
		else
			Tools.Move.Temporary.Handles.Adornee = Tools.Move.Temporary.BoundaryBox;
		end;
	end ) );

	-- Update BoundaryBox's shape/position to reflect current selection
	Tools.Move.Temporary.BoundaryBox = Tools.Move:updateBoundaryBox( Tools.Move.Temporary.BoundaryBox, Selection.Items );

	table.insert( Tools.Move.Temporary.Connections, Tools.Move.Temporary.Handles.MouseButton1Down:connect( function ()
		Tools.Move.State.moving = true;
		Tools.Move.State.MoveStart = {};
		Tools.Move.State.MoveStartAnchors = {};
		for _, Item in pairs( Selection.Items ) do
			Tools.Move.State.MoveStart[Item] = Item.CFrame;
			Tools.Move.State.MoveStartAnchors[Item] = Item.Anchored;
			Item.Anchored = true;
		end;
		override_selection = true;

		-- Let's listen to `Mouse`'s `Button1Up` instead of the handle's because the latter's only fires when
		-- the button is released /on/ the handle (and that's not always the case)
		local ReleaseListener;
		ReleaseListener = Mouse.Button1Up:connect( function ()
			ReleaseListener:disconnect();
			Tools.Move.State.moving = false;
			Tools.Move.State.MoveStart = {};

			-- Reset each item's anchor state to its original
			for _, Item in pairs( Selection.Items ) do
				Item.Anchored = Tools.Move.State.MoveStartAnchors[Item];
			end;

			Tools.Move.State.MoveStartAnchors = {};
		end );
	end ) );

	table.insert( Tools.Move.Temporary.Connections, Tools.Move.Temporary.Handles.MouseDrag:connect( function ( face, distance )

		local distance = math.floor( distance );

		-- Make sure that the distance has changed by at least a unit
		if distance == Tools.Move.State.previous_distance then
			return;
		end;

		Tools.Move.State.previous_distance = distance;

		-- Increment the position of each selected item in the direction of `face`
		for _, Item in pairs( Selection.Items ) do

			if face == Enum.NormalId.Top then
				Item.CFrame = CFrame.new( Tools.Move.State.MoveStart[Item].p ):toWorldSpace( CFrame.new( 0, Tools.Move.Options.increment * distance, 0 ) ) * CFrame.Angles( Tools.Move.State.MoveStart[Item]:toEulerAnglesXYZ() );
			
			elseif face == Enum.NormalId.Bottom then
				Item.CFrame = CFrame.new( Tools.Move.State.MoveStart[Item].p ):toWorldSpace( CFrame.new( 0, -Tools.Move.Options.increment * distance, 0 ) ) * CFrame.Angles( Tools.Move.State.MoveStart[Item]:toEulerAnglesXYZ() );

			elseif face == Enum.NormalId.Front then
				Item.CFrame = CFrame.new( Tools.Move.State.MoveStart[Item].p ):toWorldSpace( CFrame.new( 0, 0, -Tools.Move.Options.increment * distance ) ) * CFrame.Angles( Tools.Move.State.MoveStart[Item]:toEulerAnglesXYZ() );

			elseif face == Enum.NormalId.Back then
				Item.CFrame = CFrame.new( Tools.Move.State.MoveStart[Item].p ):toWorldSpace( CFrame.new( 0, 0, Tools.Move.Options.increment * distance ) ) * CFrame.Angles( Tools.Move.State.MoveStart[Item]:toEulerAnglesXYZ() );

			elseif face == Enum.NormalId.Right then
				Item.CFrame = CFrame.new( Tools.Move.State.MoveStart[Item].p ):toWorldSpace( CFrame.new( Tools.Move.Options.increment * distance, 0, 0 ) ) * CFrame.Angles( Tools.Move.State.MoveStart[Item]:toEulerAnglesXYZ() );

			elseif face == Enum.NormalId.Left then
				Item.CFrame = CFrame.new( Tools.Move.State.MoveStart[Item].p ):toWorldSpace( CFrame.new( -Tools.Move.Options.increment * distance, 0, 0 ) ) * CFrame.Angles( Tools.Move.State.MoveStart[Item]:toEulerAnglesXYZ() );

			end;

		end;
	end ) );

	-- Show the options GUI
	Tools.Move:showMoveOptions();

end;

Tools.Move.Listeners.Unequipped = function ()

	-- Hide the options GUI
	Tools.Move:hideMoveOptions();

	-- Restore the original selection box color
	SelectionBoxColor = Tools.Move.Temporary.PreviousSelectionBoxColor;
	updateSelectionBoxColor();

	-- Disconnect any temporary connections
	for connection_index, Connection in pairs( Tools.Move.Temporary.Connections ) do
		Connection:disconnect();
		Tools.Move.Temporary.Connections[connection_index] = nil;
	end;
	for connection_index, Connection in pairs( Tools.Move.Temporary.MovementListeners ) do
		Connection:disconnect();
		Tools.Move.Temporary.MovementListeners[connection_index] = nil;
	end;

	-- Dispose of the coroutine that updates the boundary
	Tools.Move.Temporary.BoundaryUpdater = nil;

	-- Remove the boundary box
	if Tools.Move.Temporary.BoundaryBox then
		Tools.Move.Temporary.BoundaryBox:Destroy();
		Tools.Move.Temporary.BoundaryBox = nil;
	end;

	-- Remove the boundary selection box
	if Tools.Move.Temporary.BoundarySelectionBox then
		Tools.Move.Temporary.BoundarySelectionBox:Destroy();
		Tools.Move.Temporary.BoundarySelectionBox = nil;
	end;

	-- Remove the handles
	if Tools.Move.Temporary.Handles then
		Tools.Move.Temporary.Handles:Destroy();
		Tools.Move.Temporary.Handles = nil;
	end;

end;

-- Create the handle
Tools.Move.Handle = Instance.new( "Part" );
Tools.Move.Handle.Name = "Handle";
Tools.Move.Handle.CanCollide = false;
Tools.Move.Handle.Transparency = 1;

-- Set the grip for the handle
Tools.Move.Grip = CFrame.new( 0, 0, 0 );

Tools.Move.showMoveOptions = function ( self )
	-- Creates and shows the move tool's options panel

	local GUIRoot = Instance.new( "ScreenGui", Player.PlayerGui );
	GUIRoot.Name = "BTMoveToolGUI";

	self.Temporary.OptionsGUI = GUIRoot;

	RbxUtility.Create "Frame" {
		Parent = GUIRoot;
		Name = "Container";
		Active = true;
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		Position = UDim2.new( 0, 0, 0, 280 );
		Size = UDim2.new( 0, 245, 0, 90 );
		Draggable = true;
	};

	RbxUtility.Create "Frame" {
		Parent = GUIRoot.Container;
		Name = "AxesOption";
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		Position = UDim2.new( 0, 0, 0, 30 );
	};

	RbxUtility.Create "Frame" {
		Parent = GUIRoot.Container.AxesOption;
		Name = "Global";
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		Position = UDim2.new( 0, 45, 0, 0 );
		Size = UDim2.new( 0, 70, 0, 25 );
	};

	RbxUtility.Create "Frame" {
		Parent = GUIRoot.Container.AxesOption.Global;
		Name = "SelectedIndicator";
		BackgroundColor3 = Color3.new( 1, 1, 1 );
		BorderSizePixel = 0;
		Position = UDim2.new( 0, 6, 0, -2 );
		Size = UDim2.new( 1, -5, 0, 2 );
		BackgroundTransparency = ( self.Options.axes == "global" ) and 0 or 1;
	};

	RbxUtility.Create "TextButton" {
		Parent = GUIRoot.Container.AxesOption.Global;
		Name = "Button";
		Active = true;
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		Position = UDim2.new( 0, 5, 0, 0 );
		Size = UDim2.new( 1, -10, 1, 0 );
		ZIndex = 2;
		Text = "";
		TextTransparency = 1;

		-- Change the axis type option when the button is clicked
		[RbxUtility.Create.E "MouseButton1Down"] = function ()
			self.Options.axes = "global";
			GUIRoot.Container.AxesOption.Global.SelectedIndicator.BackgroundTransparency = 0;
			GUIRoot.Container.AxesOption.Global.Background.Image = dark_slanted_rectangle;
			GUIRoot.Container.AxesOption.Local.SelectedIndicator.BackgroundTransparency = 1;
			GUIRoot.Container.AxesOption.Local.Background.Image = light_slanted_rectangle;
			GUIRoot.Container.AxesOption.Last.SelectedIndicator.BackgroundTransparency = 1;
			GUIRoot.Container.AxesOption.Last.Background.Image = light_slanted_rectangle;
		end;
	};

	RbxUtility.Create "ImageLabel" {
		Parent = GUIRoot.Container.AxesOption.Global;
		Name = "Background";
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		Image = ( self.Options.axes == "global" ) and dark_slanted_rectangle or light_slanted_rectangle;
		Size = UDim2.new( 1, 0, 1, 0 );
	};

	RbxUtility.Create "TextLabel" {
		Parent = GUIRoot.Container.AxesOption.Global;
		Name = "Label";
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		Size = UDim2.new( 1, 0, 1, 0 );
		Font = Enum.Font.ArialBold;
		FontSize = Enum.FontSize.Size12;
		Text = "GLOBAL";
		TextColor3 = Color3.new( 1, 1, 1 );
	};

	RbxUtility.Create "Frame" {
		Parent = GUIRoot.Container.AxesOption;
		Name = "Local";
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		Position = UDim2.new( 0, 110, 0, 0 );
		Size = UDim2.new( 0, 70, 0, 25 );
	};

	RbxUtility.Create "Frame" {
		Parent = GUIRoot.Container.AxesOption.Local;
		Name = "SelectedIndicator";
		BackgroundColor3 = Color3.new( 1, 1, 1 );
		BorderSizePixel = 0;
		Position = UDim2.new( 0, 6, 0, -2 );
		Size = UDim2.new( 1, -5, 0, 2 );
		BackgroundTransparency = ( self.Options.axes == "local" ) and 0 or 1;
	};

	RbxUtility.Create "TextButton" {
		Parent = GUIRoot.Container.AxesOption.Local;
		Name = "Button";
		Active = true;
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		Position = UDim2.new( 0, 5, 0, 0 );
		Size = UDim2.new( 1, -10, 1, 0 );
		ZIndex = 2;
		Text = "";
		TextTransparency = 1;

		-- Change the axis type option when the button is clicked
		[RbxUtility.Create.E "MouseButton1Down"] = function ()
			self.Options.axes = "local";
			GUIRoot.Container.AxesOption.Global.SelectedIndicator.BackgroundTransparency = 1;
			GUIRoot.Container.AxesOption.Global.Background.Image = light_slanted_rectangle;
			GUIRoot.Container.AxesOption.Local.SelectedIndicator.BackgroundTransparency = 0;
			GUIRoot.Container.AxesOption.Local.Background.Image = dark_slanted_rectangle;
			GUIRoot.Container.AxesOption.Last.SelectedIndicator.BackgroundTransparency = 1;
			GUIRoot.Container.AxesOption.Last.Background.Image = light_slanted_rectangle;
		end;
	};

	RbxUtility.Create "ImageLabel" {
		Parent = GUIRoot.Container.AxesOption.Local;
		Name = "Background";
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		Image = ( self.Options.axes == "local" ) and dark_slanted_rectangle or light_slanted_rectangle;
		Size = UDim2.new( 1, 0, 1, 0 );
	};

	RbxUtility.Create "TextLabel" {
		Parent = GUIRoot.Container.AxesOption.Local;
		Name = "Label";
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		Size = UDim2.new( 1, 0, 1, 0 );
		Font = Enum.Font.ArialBold;
		FontSize = Enum.FontSize.Size12;
		Text = "LOCAL";
		TextColor3 = Color3.new( 1, 1, 1 );
	};

	RbxUtility.Create "Frame" {
		Parent = GUIRoot.Container.AxesOption;
		Name = "Last";
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		Position = UDim2.new( 0, 175, 0, 0 );
		Size = UDim2.new( 0, 70, 0, 25 );
	};

	RbxUtility.Create "Frame" {
		Parent = GUIRoot.Container.AxesOption.Last;
		Name = "SelectedIndicator";
		BackgroundColor3 = Color3.new( 1, 1, 1 );
		BorderSizePixel = 0;
		Position = UDim2.new( 0, 6, 0, -2 );
		Size = UDim2.new( 1, -5, 0, 2 );
		BackgroundTransparency = ( self.Options.axes == "last" ) and 0 or 1;
	};

	RbxUtility.Create "TextButton" {
		Parent = GUIRoot.Container.AxesOption.Last;
		Name = "Button";
		Active = true;
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		Position = UDim2.new( 0, 5, 0, 0 );
		Size = UDim2.new( 1, -10, 1, 0 );
		ZIndex = 2;
		Text = "";
		TextTransparency = 1;

		-- Change the axis type option when the button is clicked
		[RbxUtility.Create.E "MouseButton1Down"] = function ()
			self.Options.axes = "last";
			GUIRoot.Container.AxesOption.Global.SelectedIndicator.BackgroundTransparency = 1;
			GUIRoot.Container.AxesOption.Global.Background.Image = light_slanted_rectangle;
			GUIRoot.Container.AxesOption.Local.SelectedIndicator.BackgroundTransparency = 1;
			GUIRoot.Container.AxesOption.Local.Background.Image = light_slanted_rectangle;
			GUIRoot.Container.AxesOption.Last.SelectedIndicator.BackgroundTransparency = 0;
			GUIRoot.Container.AxesOption.Last.Background.Image = dark_slanted_rectangle;
		end;
	};

	RbxUtility.Create "ImageLabel" {
		Parent = GUIRoot.Container.AxesOption.Last;
		Name = "Background";
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		Image = ( self.Options.axes == "last" ) and dark_slanted_rectangle or light_slanted_rectangle;
		Size = UDim2.new( 1, 0, 1, 0 );
	};

	RbxUtility.Create "TextLabel" {
		Parent = GUIRoot.Container.AxesOption.Last;
		Name = "Label";
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		Size = UDim2.new( 1, 0, 1, 0 );
		Font = Enum.Font.ArialBold;
		FontSize = Enum.FontSize.Size12;
		Text = "LAST";
		TextColor3 = Color3.new( 1, 1, 1 );
	};

	RbxUtility.Create "Frame" {
		Parent = GUIRoot.Container.AxesOption;
		Name = "Label";
		BorderSizePixel = 0;
		BackgroundTransparency = 1;
		Size = UDim2.new( 0, 50, 0, 25 );
	};

	RbxUtility.Create "TextLabel" {
		Parent = GUIRoot.Container.AxesOption.Label;
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		Size = UDim2.new( 1, 0, 1, 0 );
		Font = Enum.Font.ArialBold;
		FontSize = Enum.FontSize.Size12;
		Text = "Axes";
		TextColor3 = Color3.new( 1, 1, 1 );
		TextWrapped = true;
		TextStrokeColor3 = Color3.new( 0, 0, 0 );
		TextStrokeTransparency = 0;
	};

	RbxUtility.Create "Frame" {
		Parent = GUIRoot.Container;
		Name = "Title";
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		Size = UDim2.new( 1, 0, 0, 20 );
	};

	RbxUtility.Create "Frame" {
		Parent = GUIRoot.Container.Title;
		Name = "ColorBar";
		BackgroundColor3 = Color3.new( 255 / 255, 170 / 255, 0 );
		BorderSizePixel = 0;
		Position = UDim2.new( 0, 5, 0, -3 );
		Size = UDim2.new( 1, -5, 0, 2 );
	};

	RbxUtility.Create "TextLabel" {
		Parent = GUIRoot.Container.Title;
		Name = "Label";
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		Position = UDim2.new( 0, 10, 0, 1 );
		Size = UDim2.new( 1, -10, 1, 0 );
		Font = Enum.Font.ArialBold;
		FontSize = Enum.FontSize.Size12;
		Text = "MOVE TOOL";
		TextColor3 = Color3.new( 1, 1, 1 );
		TextXAlignment = Enum.TextXAlignment.Left;
		TextStrokeTransparency = 0;
		TextStrokeColor3 = Color3.new( 0, 0, 0 );
		TextWrapped = true;
	};

	RbxUtility.Create "TextLabel" {
		Parent = GUIRoot.Container.Title;
		Name = "F3XSignature";
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		Position = UDim2.new( 0, 10, 0, 1 );
		Size = UDim2.new( 1, -10, 1, 0 );
		Font = Enum.Font.ArialBold;
		FontSize = Enum.FontSize.Size14;
		Text = "F3X";
		TextColor3 = Color3.new( 1, 1, 1 );
		TextXAlignment = Enum.TextXAlignment.Right;
		TextStrokeTransparency = 0.9;
		TextStrokeColor3 = Color3.new( 0, 0, 0 );
		TextWrapped = true;
	};

	RbxUtility.Create "Frame" {
		Parent = GUIRoot.Container;
		Name = "IncrementOption";
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		Position = UDim2.new( 0, 0, 0, 65 );
	};

	RbxUtility.Create "Frame" {
		Parent = GUIRoot.Container.IncrementOption;
		Name = "Increment";
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		Position = UDim2.new( 0, 70, 0, 0 );
		Size = UDim2.new( 0, 50, 0, 25 );
	};

	RbxUtility.Create "Frame" {
		Parent = GUIRoot.Container.IncrementOption.Increment;
		Name = "SelectedIndicator";
		BorderSizePixel = 0;
		BackgroundColor3 = Color3.new( 1, 1, 1 );
		Size = UDim2.new( 1, -4, 0, 2 );
		Position = UDim2.new( 0, 5, 0, -2 );
	};

	RbxUtility.Create "TextBox" {
		Parent = GUIRoot.Container.IncrementOption.Increment;
		BorderSizePixel = 0;
		BackgroundTransparency = 1;
		Position = UDim2.new( 0, 5, 0, 0 );
		Size = UDim2.new( 1, -10, 1, 0 );
		ZIndex = 2;
		Font = Enum.Font.ArialBold;
		FontSize = Enum.FontSize.Size12;
		Text = tostring( self.Options.increment );
		TextColor3 = Color3.new( 1, 1, 1 );

		-- Change the increment option when the value of the textbox is updated
		[RbxUtility.Create.E "FocusLost"] = function ( enter_pressed )
			if enter_pressed then
				self.Options.increment = tonumber( GUIRoot.Container.IncrementOption.Increment.TextBox.Text ) or self.Options.increment;
				GUIRoot.Container.IncrementOption.Increment.TextBox.Text = tostring( self.Options.increment );
			end;
		end;
	};

	RbxUtility.Create "ImageLabel" {
		Parent = GUIRoot.Container.IncrementOption.Increment;
		Name = "Background";
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		Image = light_slanted_rectangle;
		Size = UDim2.new( 1, 0, 1, 0 );
	};

	RbxUtility.Create "Frame" {
		Parent = GUIRoot.Container.IncrementOption;
		Name = "Label";
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		Size = UDim2.new( 0, 75, 0, 25 );
	};

	RbxUtility.Create "TextLabel" {
		Parent = GUIRoot.Container.IncrementOption.Label;
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		Size = UDim2.new( 1, 0, 1, 0 );
		Font = Enum.Font.ArialBold;
		FontSize = Enum.FontSize.Size12;
		Text = "Increment";
		TextColor3 = Color3.new( 1, 1, 1 );
		TextStrokeColor3 = Color3.new( 0, 0, 0 );
		TextStrokeTransparency = 0;
		TextWrapped = true;
	};

	RbxUtility.Create "Frame" {
		Parent = GUIRoot.Container;
		Name = "Help";
		BackgroundColor3 = Color3.new( 0, 0, 0 );
		BackgroundTransparency = 0.8;
		BorderSizePixel = 0;
		Position = UDim2.new( 0, 10, 1, 20 );
		Size = UDim2.new( 1, -10, 0, 50 );
		Visible = false;
	};

	RbxUtility.Create "Frame" {
		Parent = GUIRoot.Container.Help;
		Name = "Line";
		BackgroundColor3 = Color3.new( 1, 170 / 255, 0 );
		BorderSizePixel = 0;
		Size = UDim2.new( 0, 4, 1, 0 );
	};

	RbxUtility.Create "TextLabel" {
		Parent = GUIRoot.Container.Help;
		Name = "Text";
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		Position = UDim2.new( 0, 15, 0, 0 );
		Size = UDim2.new( 1, -30, 1, 0 );
		Font = Enum.Font.Arial;
		FontSize = Enum.FontSize.Size12;
		Text = "";
		TextColor3 = Color3.new( 1, 1, 1 );
		TextStrokeColor3 = Color3.new( 0, 0, 0 );
		TextStrokeTransparency = 0.95;
		TextWrapped = true;
		TextXAlignment = Enum.TextXAlignment.Left;
	};

end;

Tools.Move.hideMoveOptions = function ( self )
	-- Hide any existent options GUI for the move tool

	if self.Temporary.OptionsGUI then
		self.Temporary.OptionsGUI:Destroy();
		self.Temporary.OptionsGUI = nil;
	end;

end;

Tools.Move.createBoundaryBox = function ( self )
	-- Returns an empty boundary box

	local BoundaryBox = Instance.new( "Part" );
	BoundaryBox.Name = "BTBoundaryBox";
	BoundaryBox.Anchored = true;
	BoundaryBox.Locked = true;
	BoundaryBox.CanCollide = false;
	BoundaryBox.Transparency = 1;

	local BoundarySelectionBox = Instance.new( "SelectionBox", Player.PlayerGui );
	BoundarySelectionBox.Name = "BTBoundarySelectionBox";
	BoundarySelectionBox.Color = BrickColor.new( "Deep orange" );
	BoundarySelectionBox.Adornee = BoundaryBox;

	BoundaryBox.AncestryChanged:connect( function ( Child, NewParent )
		if NewParent == nil then
			BoundarySelectionBox.Adornee = nil;
		else
			BoundarySelectionBox.Adornee = BoundaryBox;
		end;
	end );

	self.Temporary.BoundarySelectionBox = BoundarySelectionBox;

	Mouse.TargetFilter = BoundaryBox;

	return BoundaryBox;

end;

Tools.Move.updateBoundaryBox = function ( self, BoundaryBox, part_collection )
	-- Returns the boundary box

	-- Make sure `BoundaryBox` exists
	if not BoundaryBox then
		return false;
	end;

	-- Delete the box if `part_collection` is empty and return a new one
	if #part_collection == 0 then
		BoundaryBox.Parent = nil;
		return BoundaryBox;
	end;

	-- Get the size and position of `part_collection`
	local Size, Position = _getCollectionInfo( part_collection );

	-- Make `BoundaryBox` cover the part collection
	BoundaryBox.Parent = Services.Workspace.CurrentCamera;
	BoundaryBox.Size = Size;
	BoundaryBox.CFrame = Position;

	-- Return `BoundaryBox`
	return BoundaryBox;

end;

------------------------------------------
-- Attach listeners
------------------------------------------

Tool.Equipped:connect( function ( CurrentMouse )

	Mouse = CurrentMouse;

	Options.TargetBox = Instance.new( "SelectionBox", Player.PlayerGui );
	Options.TargetBox.Name = "BTTargetBox";
	Options.TargetBox.Color = BrickColor.new( "Institutional white" );

	-- Enable any temporarily-disabled selection boxes
	for _, SelectionBox in pairs( SelectionBoxes ) do
		SelectionBox.Parent = Player.PlayerGui;
	end;

	-- Call the `Equipped` listener of the current tool
	if Options.Tool and Options.Tool.Listeners.Equipped then
		Options.Tool.Listeners.Equipped();
	end;

	Mouse.KeyDown:connect( function ( key )

		local key = key:lower();
		local key_code = key:byte();

		if key == "z" then
			Options.Tool = Tools.Move;

		elseif key == "v" then
			Options.Tool = Tools.Paint;

		elseif key == "q" then
			Selection:clear();

		elseif key == "e" then
			Options.Tool = Tools.Default;

		end;

		ActiveKeys[key_code] = key_code;
		ActiveKeys[key] = key;

		-- If it's now in multiselection mode, update `selecting`
		-- (these are the left/right ctrl & shift keys)
		if ActiveKeys[47] or ActiveKeys[48] or ActiveKeys[49] or ActiveKeys[50] then
			selecting = ActiveKeys[47] or ActiveKeys[48] or ActiveKeys[49] or ActiveKeys[50];
		end;

	end );

	Mouse.KeyUp:connect( function ( key )

		local key = key:lower();
		local key_code = key:byte();

		ActiveKeys[key_code] = nil;
		ActiveKeys[key] = nil;

		-- If it's no longer in multiselection mode, update `selecting`
		if selecting and not ActiveKeys[selecting] then
			selecting = false;
		end;

	end );

	Mouse.Button1Down:connect( function ()

		clicking = true;
		click_x, click_y = Mouse.X, Mouse.Y;

		-- If multiselection is, just add to the selection
		if selecting then
			return;
		end;

		-- Fire tool listeners
		if Options.Tool and Options.Tool.Listeners.Button1Down then
			Options.Tool.Listeners.Button1Down();
		end;

	end );

	Mouse.Move:connect( function ()

		-- If the target has changed, update the selectionbox appropriately
		if Mouse.Target then
			if Mouse.Target:IsA( "BasePart" ) and not Mouse.Target.Locked and Options.TargetBox.Adornee ~= Mouse.Target and not Selection:find( Mouse.Target ) then
				Options.TargetBox.Adornee = Mouse.Target;
			end;
		end;

		-- When aiming at something invalid, don't highlight any targets
		if not Mouse.Target or ( Mouse.Target and Mouse.Target:IsA( "BasePart" ) and Mouse.Target.Locked ) or Selection:find( Mouse.Target ) then
			Options.TargetBox.Adornee = nil;
		end;

		-- If spay-like multi-selecting, add this current target to the selection
		if selecting and clicking then
			if Mouse.Target and Mouse.Target:IsA( "BasePart" ) and not Mouse.Target.Locked then
				Selection:add( Mouse.Target );
			end;
		end;

		-- Fire tool listeners
		if Options.Tool and Options.Tool.Listeners.Move then
			Options.Tool.Listeners.Move();
		end;

	end );

	Mouse.Button1Up:connect( function ()

		if override_selection then
			override_selection = false;
			return false;
		end;

		clicking = false;

		-- If the target when clicking was invalid then clear the selection (unless we're multi-selecting)
		if not selecting and ( not Mouse.Target or ( Mouse.Target and Mouse.Target:IsA( "BasePart" ) and Mouse.Target.Locked ) ) then
			Selection:clear();
		end;

		-- If multi-selecting, add to/remove from the selection
		if selecting then

			-- If the item isn't already selected, add it to the selection
			if #_findTableOccurrences( Selection.Items, Mouse.Target ) == 0 then
				if Mouse.Target and Mouse.Target:IsA( "BasePart" ) and not Mouse.Target.Locked then
					Selection:add( Mouse.Target );
				end;
			
			-- If the item _is_ already selected, remove it from the selection
			-- (unless they're finishing a spray-like selection)
			else
				if ( Mouse.X == click_x and Mouse.Y == click_y ) and Mouse.Target and Mouse.Target:IsA( "BasePart" ) and not Mouse.Target.Locked then
					Selection:remove( Mouse.Target );
				end;
			end;

		-- If not multi-selecting, replace the selection
		else
			if Mouse.Target and Mouse.Target:IsA( "BasePart" ) and not Mouse.Target.Locked then
				Selection:clear();
				Selection:add( Mouse.Target );
			end;
		end;

		-- Fire tool listeners
		if Options.Tool and Options.Tool.Listeners.Button1Up then
			Options.Tool.Listeners.Button1Up();
		end;

	end );

end );

Tool.Unequipped:connect( function ()

	Mouse = nil;

	-- Remove the mouse target SelectionBox from `Player`
	local TargetBox = Player.PlayerGui:FindFirstChild( "BTTargetBox" );
	if TargetBox then
		TargetBox:Destroy();
	end;

	-- Disable all the selection boxes temporarily
	for _, SelectionBox in pairs( SelectionBoxes ) do
		SelectionBox.Parent = nil;
	end;

	-- Call the `Unequipped` listener of the current tool
	if Options.Tool and Options.Tool.Listeners.Unequipped then
		Options.Tool.Listeners.Unequipped();
	end;

end );

-- Enable `Tools.Default` as the first tool
Options.Tool = Tools.Default;