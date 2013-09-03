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

	local table_insert = table.insert;

	for _, Part in pairs( part_collection ) do

		-- Create shortcuts to certain things that are expensive to call constantly
		local PartCFrame = Part.CFrame;
		local PartSize = Part.Size / 2;
		local size_x, size_y, size_z = PartSize.x, PartSize.y, PartSize.z;

		table_insert( corners, PartCFrame:toWorldSpace( CFrame.new( size_x, size_y, size_z ) ) );
		table_insert( corners, PartCFrame:toWorldSpace( CFrame.new( -size_x, size_y, size_z ) ) );
		table_insert( corners, PartCFrame:toWorldSpace( CFrame.new( size_x, -size_y, size_z ) ) );
		table_insert( corners, PartCFrame:toWorldSpace( CFrame.new( size_x, size_y, -size_z ) ) );
		table_insert( corners, PartCFrame:toWorldSpace( CFrame.new( -size_x, size_y, -size_z ) ) );
		table_insert( corners, PartCFrame:toWorldSpace( CFrame.new( -size_x, -size_y, size_z ) ) );
		table_insert( corners, PartCFrame:toWorldSpace( CFrame.new( size_x, -size_y, -size_z ) ) );
		table_insert( corners, PartCFrame:toWorldSpace( CFrame.new( -size_x, -size_y, -size_z ) ) );

	end;

	-- Get the extents
	local x, y, z = {}, {}, {};

	for _, Corner in pairs( corners ) do
		table_insert( x, Corner.x );
		table_insert( y, Corner.y );
		table_insert( z, Corner.z );
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

function _round( number, places )
	-- Returns `number` rounded to the number of decimal `places`
	-- (from lua-users)

	local mult = 10 ^ ( places or 0 );

	return math.floor( number * mult + 0.5 ) / mult;

end

function _cloneTable( source )
	-- Returns a deep copy of table `source`

	-- Get a copy of `source`'s metatable, since the hacky method
	-- we're using to copy the table doesn't include its metatable
	local source_mt = getmetatable( source );

	-- Return a copy of `source` including its metatable
	return setmetatable( { unpack( source ) }, source_mt );
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

Dragger = nil;

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

		-- Remove any target selection box focus
		if NewPart == Options.TargetBox.Adornee then
			Options.TargetBox.Adornee = nil;
		end;

		-- Make sure to remove the item from the selection when it's deleted
		SelectionExistenceListeners[NewPart] = NewPart.AncestryChanged:connect( function ( Object, NewParent )
			if NewParent == nil then
				Selection:remove( NewPart );
			end;
		end );

		-- Provide a reference to the last item added to the selection (i.e. NewPart)
		self.Last = NewPart;

		-- Fire events
		self.ItemAdded:fire( NewPart );
		self.Changed:fire();

	end;

	-- Provide a method to remove items from the selection
	["remove"] = function ( self, Item )

		-- Make sure selection item `Item` exists
		if not self:find( Item ) then
			return false;
		end;

		-- Remove `Item`'s SelectionBox
		local SelectionBox = SelectionBoxes[Item];
		if SelectionBox then
			SelectionBox:Destroy();
		end;
		SelectionBoxes[Item] = nil;

		-- If it was logged as the last item, change it
		if self.Last == Item then
			self.Last = ( #self.Items > 1 ) and self.Items[#self.Items - 1] or nil;
		end;

		-- Delete the item from the selection
		table.remove( self.Items, self:find( Item ) );

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
		for _, Item in pairs( _cloneTable( self.Items ) ) do
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
Tools.Default.Handle.Locked = true;

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
	-- (and they weren't multi-selecting)
	if Selection:find( Mouse.Target ) and not selecting and not selecting then

		override_selection = true;

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
	["moving"] = false;
	["dragging"] = false;
};

-- Add listeners
Tools.Move.Listeners = {};

Tools.Move.Listeners.Equipped = function ()

	-- Change the color of selection boxes temporarily
	Tools.Move.Temporary.PreviousSelectionBoxColor = SelectionBoxColor;
	SelectionBoxColor = BrickColor.new( "Deep orange" );
	updateSelectionBoxColor();

	Tools.Move.Temporary.BoundaryBox = Tools.Move:createBoundaryBox();

	-- Show the GUI
	Tools.Move:showGUI();

	table.insert( Tools.Move.Temporary.Connections, Selection.Changed:connect( function ()
		Tools.Move.Temporary.BoundaryBox = Tools.Move:updateBoundaryBox( Tools.Move.Temporary.BoundaryBox, Selection.Items );
		Tools.Move:updateGUI();
		Tools.Move:updateAxes();
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
			Tools.Move:updateGUI();
		end;
	end );
	coroutine.resume( Tools.Move.Temporary.BoundaryUpdater );

	-- Create 3D movement handles
	Tools.Move.Temporary.Handles = Instance.new( "Handles", Player.PlayerGui );
	Tools.Move.Temporary.Handles.Name = "BTMovementHandles";
	Tools.Move.Temporary.Handles.Adornee = nil;
	Tools.Move.Temporary.Handles.Style = Enum.HandlesStyle.Resize;
	Tools.Move.Temporary.Handles.Color = BrickColor.new( "Deep orange" );

	-- Update BoundaryBox's shape/position to reflect current selection
	Tools.Move.Temporary.BoundaryBox = Tools.Move:updateBoundaryBox( Tools.Move.Temporary.BoundaryBox, Selection.Items );
	Tools.Move:updateGUI();

	table.insert( Tools.Move.Temporary.Connections, Tools.Move.Temporary.Handles.MouseButton1Down:connect( function ()
		Tools.Move.State.moving = true;
		Tools.Move.State.distance_moved = 0;
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
			override_selection = true;

			ReleaseListener:disconnect();
			Tools.Move.State.moving = false;
			Tools.Move.State.MoveStart = {};

			-- Reset each item's anchor state to its original
			for _, Item in pairs( Selection.Items ) do
				Item.Anchored = Tools.Move.State.MoveStartAnchors[Item];
				Item:MakeJoints();
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

		Tools.Move.State.distance_moved = Tools.Move.Options.increment * distance;
		Tools.Move:updateGUI();

		-- Increment the position of each selected item in the direction of `face`
		for _, Item in pairs( Selection.Items ) do

			-- Remove any joints connected with `Item` so that it can freely move
			Item:BreakJoints();

			-- Update the position of `Item` depending on the type of axes that is currently set
			if face == Enum.NormalId.Top then
				if Tools.Move.Options.axes == "global" then
					Item.CFrame = CFrame.new( Tools.Move.State.MoveStart[Item].p ):toWorldSpace( CFrame.new( 0, Tools.Move.Options.increment * distance, 0 ) ) * CFrame.Angles( Tools.Move.State.MoveStart[Item]:toEulerAnglesXYZ() );
				elseif Tools.Move.Options.axes == "local" then
					Item.CFrame = Tools.Move.State.MoveStart[Item]:toWorldSpace( CFrame.new( 0, Tools.Move.Options.increment * distance, 0 ) );
				elseif Tools.Move.Options.axes == "last" then
					Item.CFrame = Tools.Move.State.MoveStart[Selection.Last]:toWorldSpace( CFrame.new( 0, Tools.Move.Options.increment * distance, 0 ) ):toWorldSpace( Tools.Move.State.MoveStart[Item]:toObjectSpace( Tools.Move.State.MoveStart[Selection.Last] ):inverse() );
				end;
			
			elseif face == Enum.NormalId.Bottom then
				if Tools.Move.Options.axes == "global" then
					Item.CFrame = CFrame.new( Tools.Move.State.MoveStart[Item].p ):toWorldSpace( CFrame.new( 0, -Tools.Move.Options.increment * distance, 0 ) ) * CFrame.Angles( Tools.Move.State.MoveStart[Item]:toEulerAnglesXYZ() );
				elseif Tools.Move.Options.axes == "local" then
					Item.CFrame = Tools.Move.State.MoveStart[Item]:toWorldSpace( CFrame.new( 0, -Tools.Move.Options.increment * distance, 0 ) );
				elseif Tools.Move.Options.axes == "last" then
					Item.CFrame = Tools.Move.State.MoveStart[Selection.Last]:toWorldSpace( CFrame.new( 0, -Tools.Move.Options.increment * distance, 0 ) ):toWorldSpace( Tools.Move.State.MoveStart[Item]:toObjectSpace( Tools.Move.State.MoveStart[Selection.Last] ):inverse() );
				end;

			elseif face == Enum.NormalId.Front then
				if Tools.Move.Options.axes == "global" then
					Item.CFrame = CFrame.new( Tools.Move.State.MoveStart[Item].p ):toWorldSpace( CFrame.new( 0, 0, -Tools.Move.Options.increment * distance ) ) * CFrame.Angles( Tools.Move.State.MoveStart[Item]:toEulerAnglesXYZ() );
				elseif Tools.Move.Options.axes == "local" then
					Item.CFrame = Tools.Move.State.MoveStart[Item]:toWorldSpace( CFrame.new( 0, 0, -Tools.Move.Options.increment * distance ) );
				elseif Tools.Move.Options.axes == "last" then
					Item.CFrame = Tools.Move.State.MoveStart[Selection.Last]:toWorldSpace( CFrame.new( 0, 0, -Tools.Move.Options.increment * distance ) ):toWorldSpace( Tools.Move.State.MoveStart[Item]:toObjectSpace( Tools.Move.State.MoveStart[Selection.Last] ):inverse() );
				end;

			elseif face == Enum.NormalId.Back then
				if Tools.Move.Options.axes == "global" then
					Item.CFrame = CFrame.new( Tools.Move.State.MoveStart[Item].p ):toWorldSpace( CFrame.new( 0, 0, Tools.Move.Options.increment * distance ) ) * CFrame.Angles( Tools.Move.State.MoveStart[Item]:toEulerAnglesXYZ() );
				elseif Tools.Move.Options.axes == "local" then
					Item.CFrame = Tools.Move.State.MoveStart[Item]:toWorldSpace( CFrame.new( 0, 0, Tools.Move.Options.increment * distance ) );
				elseif Tools.Move.Options.axes == "last" then
					Item.CFrame = Tools.Move.State.MoveStart[Selection.Last]:toWorldSpace( CFrame.new( 0, 0, Tools.Move.Options.increment * distance ) ):toWorldSpace( Tools.Move.State.MoveStart[Item]:toObjectSpace( Tools.Move.State.MoveStart[Selection.Last] ):inverse() );
				end;

			elseif face == Enum.NormalId.Right then
				if Tools.Move.Options.axes == "global" then
					Item.CFrame = CFrame.new( Tools.Move.State.MoveStart[Item].p ):toWorldSpace( CFrame.new( Tools.Move.Options.increment * distance, 0, 0 ) ) * CFrame.Angles( Tools.Move.State.MoveStart[Item]:toEulerAnglesXYZ() );
				elseif Tools.Move.Options.axes == "local" then
					Item.CFrame = Tools.Move.State.MoveStart[Item]:toWorldSpace( CFrame.new( Tools.Move.Options.increment * distance, 0, 0 ) );
				elseif Tools.Move.Options.axes == "last" then
					Item.CFrame = Tools.Move.State.MoveStart[Selection.Last]:toWorldSpace( CFrame.new( Tools.Move.Options.increment * distance, 0, 0 ) ):toWorldSpace( Tools.Move.State.MoveStart[Item]:toObjectSpace( Tools.Move.State.MoveStart[Selection.Last] ):inverse() );
				end;

			elseif face == Enum.NormalId.Left then
				if Tools.Move.Options.axes == "global" then
					Item.CFrame = CFrame.new( Tools.Move.State.MoveStart[Item].p ):toWorldSpace( CFrame.new( -Tools.Move.Options.increment * distance, 0, 0 ) ) * CFrame.Angles( Tools.Move.State.MoveStart[Item]:toEulerAnglesXYZ() );
				elseif Tools.Move.Options.axes == "local" then
					Item.CFrame = Tools.Move.State.MoveStart[Item]:toWorldSpace( CFrame.new( -Tools.Move.Options.increment * distance, 0, 0 ) );
				elseif Tools.Move.Options.axes == "last" then
					Item.CFrame = Tools.Move.State.MoveStart[Selection.Last]:toWorldSpace( CFrame.new( -Tools.Move.Options.increment * distance, 0, 0 ) ):toWorldSpace( Tools.Move.State.MoveStart[Item]:toObjectSpace( Tools.Move.State.MoveStart[Selection.Last] ):inverse() );
				end;

			end;

		end;
	end ) );

	Tools.Move:updateAxes();

end;

Tools.Move.updateGUI = function ( self )
	
	if self.Temporary.OptionsGUI then
		local GUI = self.Temporary.OptionsGUI.Container;

		if #Selection.Items > 0 then
			local SelectionSize, SelectionPosition = _getCollectionInfo( Selection.Items );

			GUI.Info.Center.X.TextLabel.Text = tostring( _round( SelectionPosition.x, 2 ) );
			GUI.Info.Center.Y.TextLabel.Text = tostring( _round( SelectionPosition.y, 2 ) );
			GUI.Info.Center.Z.TextLabel.Text = tostring( _round( SelectionPosition.z, 2 ) );

			GUI.Info.Visible = true;
		else
			GUI.Info.Visible = false;
		end;

		if self.State.distance_moved then
			GUI.Changes.Text.Text = "moved " .. tostring( self.State.distance_moved ) .. " studs";
			GUI.Changes.Position = GUI.Info.Visible and UDim2.new( 0, 5, 0, 165 ) or UDim2.new( 0, 5, 0, 100 );
			GUI.Changes.Visible = true;
		else
			GUI.Changes.Text.Text = "";
			GUI.Changes.Visible = false;
		end;
	end;

end;

Tools.Move.Listeners.Button1Down = function ()

	if not Mouse.Target or ( Mouse.Target:IsA( "BasePart" ) and Mouse.Target.Locked ) then
		return;
	end;

	if not Selection:find( Mouse.Target ) then
		Selection:clear();
		Selection:add( Mouse.Target );
	end;

	Tools.Move.State.dragging = true;

	override_selection = true;

	Tools.Move.Temporary.Dragger = Instance.new( "Dragger" );

	Tools.Move.Temporary.Dragger:MouseDown( Mouse.Target, Mouse.Target.Position - Mouse.Hit.p, Selection.Items );

	Tools.Move.Temporary.DraggerConnection = Mouse.Button1Up:connect( function ()

		override_selection = true;

		Tools.Move.Temporary.DraggerConnection:disconnect();
		Tools.Move.Temporary.DraggerConnection = nil;

		if not Tools.Move.Temporary.Dragger then
			return;
		end;

		Tools.Move.Temporary.Dragger:MouseUp();

		Tools.Move.State.dragging = false;

		Tools.Move.Temporary.Dragger:Destroy();
		Tools.Move.Temporary.Dragger = nil;

	end );

end;

Tools.Move.Listeners.Move = function ()

	if not Tools.Move.Temporary.Dragger then
		return;
	end;

	override_selection = true;

	Tools.Move.Temporary.Dragger:MouseMove( Mouse.UnitRay );

end;

Tools.Move.Listeners.Unequipped = function ()

	-- Hide the options GUI
	Tools.Move:hideGUI();

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

	if Tools.Move.Temporary.DraggerConnection then
		Tools.Move.Temporary.DraggerConnection:disconnect();
		Tools.Move.Temporary.DraggerConnection = nil;
	end;

	if Tools.Move.Temporary.Dragger then
		Tools.Move.Temporary.Dragger:Destroy();
		Tools.Move.Temporary.Dragger = nil;
	end;

	if Tools.Move.Temporary.AdorneeWatcher then
		Tools.Move.Temporary.AdorneeWatcher:disconnect();
		Tools.Move.Temporary.AdorneeWatcher = nil;
	end;

end;

-- Create the handle
Tools.Move.Handle = Instance.new( "Part" );
Tools.Move.Handle.Name = "Handle";
Tools.Move.Handle.CanCollide = false;
Tools.Move.Handle.Transparency = 1;
Tools.Move.Handle.Locked = true;

-- Set the grip for the handle
Tools.Move.Grip = CFrame.new( 0, 0, 0 );

Tools.Move.showGUI = function ( self )
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
			self:updateAxes();
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
			self:updateAxes();
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
			self:updateAxes();
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
		Name = "Info";
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		Position = UDim2.new( 0, 5, 0, 100 );
		Size = UDim2.new( 1, -5, 0, 60 );
		Visible = false;
	};

	RbxUtility.Create "Frame" {
		Parent = GUIRoot.Container.Info;
		Name = "ColorBar";
		BorderSizePixel = 0;
		BackgroundColor3 = Color3.new( 1, 170 / 255, 0 );
		Size = UDim2.new( 1, 0, 0, 2 );
	};

	RbxUtility.Create "TextLabel" {
		Parent = GUIRoot.Container.Info;
		Name = "Label";
		BorderSizePixel = 0;
		BackgroundTransparency = 1;
		Position = UDim2.new( 0, 10, 0, 2 );
		Size = UDim2.new( 1, -10, 0, 20 );
		Font = Enum.Font.ArialBold;
		FontSize = Enum.FontSize.Size12;
		Text = "SELECTION INFO";
		TextColor3 = Color3.new( 1, 1, 1 );
		TextStrokeColor3 = Color3.new( 0, 0, 0 );
		TextStrokeTransparency = 0;
		TextWrapped = true;
		TextXAlignment = Enum.TextXAlignment.Left;
	};

	RbxUtility.Create "Frame" {
		Parent = GUIRoot.Container.Info;
		Name = "Center";
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		Position = UDim2.new( 0, 0, 0, 30 );
	};

	RbxUtility.Create "TextLabel" {
		Parent = GUIRoot.Container.Info.Center;
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		Size = UDim2.new( 0, 75, 0, 25 );
		Font = Enum.Font.ArialBold;
		FontSize = Enum.FontSize.Size12;
		Text = "Center";
		TextColor3 = Color3.new( 1, 1, 1 );
		TextStrokeColor3 = Color3.new( 0, 0, 0);
		TextStrokeTransparency = 0;
		TextWrapped = true;
	};

	RbxUtility.Create "Frame" {
		Parent = GUIRoot.Container.Info.Center;
		Name = "X";
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		Position = UDim2.new( 0, 70, 0, 0 );
		Size = UDim2.new( 0, 50, 0, 25 );
	};

	RbxUtility.Create "TextLabel" {
		Parent = GUIRoot.Container.Info.Center.X;
		Name = "TextLabel";
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		Position = UDim2.new( 0, 5, 0, 0 );
		Size = UDim2.new( 1, -10, 1, 0 );
		ZIndex = 2;
		Font = Enum.Font.ArialBold;
		FontSize = Enum.FontSize.Size12;
		Text = "";
		TextColor3 = Color3.new( 1, 1, 1 );
		TextWrapped = true;
	};

	RbxUtility.Create "ImageLabel" {
		Parent = GUIRoot.Container.Info.Center.X;
		Name = "Background";
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		Size = UDim2.new( 1, 0, 1, 0 );
		Image = light_slanted_rectangle;
	};

	RbxUtility.Create "Frame" {
		Parent = GUIRoot.Container.Info.Center;
		Name = "Y";
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		Position = UDim2.new( 0, 117, 0, 0 );
		Size = UDim2.new( 0, 50, 0, 25 );
	};

	RbxUtility.Create "TextLabel" {
		Parent = GUIRoot.Container.Info.Center.Y;
		Name = "TextLabel";
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		Position = UDim2.new( 0, 5, 0, 0 );
		Size = UDim2.new( 1, -10, 1, 0 );
		ZIndex = 2;
		Font = Enum.Font.ArialBold;
		FontSize = Enum.FontSize.Size12;
		Text = "";
		TextColor3 = Color3.new( 1, 1, 1 );
		TextWrapped = true;
	};

	RbxUtility.Create "ImageLabel" {
		Parent = GUIRoot.Container.Info.Center.Y;
		Name = "Background";
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		Size = UDim2.new( 1, 0, 1, 0 );
		Image = light_slanted_rectangle;
	};

	RbxUtility.Create "Frame" {
		Parent = GUIRoot.Container.Info.Center;
		Name = "Z";
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		Position = UDim2.new( 0, 164, 0, 0 );
		Size = UDim2.new( 0, 50, 0, 25 );
	};

	RbxUtility.Create "TextLabel" {
		Parent = GUIRoot.Container.Info.Center.Z;
		Name = "TextLabel";
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		Position = UDim2.new( 0, 5, 0, 0 );
		Size = UDim2.new( 1, -10, 1, 0 );
		ZIndex = 2;
		Font = Enum.Font.ArialBold;
		FontSize = Enum.FontSize.Size12;
		Text = "";
		TextColor3 = Color3.new( 1, 1, 1 );
		TextWrapped = true;
	};

	RbxUtility.Create "ImageLabel" {
		Parent = GUIRoot.Container.Info.Center.Z;
		Name = "Background";
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		Size = UDim2.new( 1, 0, 1, 0 );
		Image = light_slanted_rectangle;
	};

	RbxUtility.Create "Frame" {
		Parent = GUIRoot.Container;
		Name = "Changes";
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		Position = UDim2.new( 0, 5, 0, 165 );
		Size = UDim2.new( 1, -5, 0, 20 );
		Visible = false;
	};

	RbxUtility.Create "Frame" {
		Parent = GUIRoot.Container.Changes;
		Name = "ColorBar";
		BorderSizePixel = 0;
		BackgroundColor3 = Color3.new( 1, 170 / 255, 0 );
		Size = UDim2.new( 1, 0, 0, 2 );
	};

	RbxUtility.Create "TextLabel" {
		Parent = GUIRoot.Container.Changes;
		Name = "Text";
		BorderSizePixel = 0;
		BackgroundTransparency = 1;
		Position = UDim2.new( 0, 10, 0, 2 );
		Size = UDim2.new( 1, -10, 0, 20 );
		Font = Enum.Font.ArialBold;
		FontSize = Enum.FontSize.Size11;
		Text = "";
		TextColor3 = Color3.new( 1, 1, 1 );
		TextStrokeColor3 = Color3.new( 0, 0, 0 );
		TextStrokeTransparency = 0.5;
		TextWrapped = true;
		TextXAlignment = Enum.TextXAlignment.Right;
	};

end;

Tools.Move.hideGUI = function ( self )
	-- Hide any existent options GUI for the move tool

	if self.Temporary.OptionsGUI then
		self.Temporary.OptionsGUI:Destroy();
		self.Temporary.OptionsGUI = nil;
	end;

end;

Tools.Move.updateAxes = function ( self )
	-- Updates the axis type of the tool depending on the options

	if self.Temporary.AdorneeWatcher then
		self.Temporary.AdorneeWatcher:disconnect();
		self.Temporary.AdorneeWatcher = nil;
	end;

	if self.Temporary.LocalAxesChooser then
		self.Temporary.LocalAxesChooser:disconnect();
		self.Temporary.LocalAxesChooser = nil;
	end;

	self.Temporary.Handles.Adornee = nil;

	if self.Options.axes == "global" then
		if self.Temporary.BoundaryBox.Parent then
			self.Temporary.Handles.Adornee = self.Temporary.BoundaryBox;
		end;
	end;

	if self.Options.axes == "local" then

		-- If there is a last item in the selection, attach the handles to it
		if Selection.Last then
			self.Temporary.Handles.Adornee = Selection.Last;
		end;

		-- Move the handles over to whichever part is the mouse's current target
		self.Temporary.LocalAxesChooser = Mouse.Button2Up:connect( function ()
			if Selection:find( Mouse.Target ) then
				self.Temporary.Handles.Adornee = Mouse.Target;
			end;
		end );

	end;

	if self.Options.axes == "last" then

		-- If there is a last item in the selection, attach the handles to it
		if Selection.Last then
			self.Temporary.Handles.Adornee = Selection.Last;
		end;

	end;

	-- Make sure to hide the handles when their adornee is removed
	if self.Temporary.Handles.Adornee then
		local Adornee = self.Temporary.Handles.Adornee;
		self.Temporary.AdorneeWatcher = self.Temporary.Handles.Adornee.AncestryChanged:connect( function ( Object, NewParent )
	 		if NewParent == nil then
				self.Temporary.Handles.Adornee = nil;
			else
				self.Temporary.Handles.Adornee = Adornee;
			end;
		end );
	end;

	-- Reload the boundary box's parent so that the AdorneeWatcher connection can catch it
	self.Temporary.BoundaryBox.Parent = self.Temporary.BoundaryBox.Parent;

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

	-- Delete the box if `part_collection` is empty or we're dragging and return a new one
	if #part_collection == 0 or self.State.dragging then
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
-- Resize tool
------------------------------------------

-- Create the tool
Tools.Resize = {};

-- Create structures that will be used within the tool
Tools.Resize.Temporary = {
	["Connections"] = {};
};

Tools.Resize.Options = {
	["increment"] = 1;
	["directions"] = "normal";
};

Tools.Resize.State = {
	["PreResize"] = {};
	["previous_distance"] = 0;
	["resizing"] = false;
};

Tools.Resize.Listeners = {};

-- Create the handle for the tool
Tools.Resize.Handle = RbxUtility.Create "Part" {
	Name = "Handle";
	CanCollide = false;
	Transparency = 1;
	Locked = true;
};

-- Set the grip for the handle
Tools.Resize.Grip = CFrame.new( 0, 0, 0 );

-- Define the color of the tool
Tools.Resize.Color = BrickColor.new( "Cyan" );

Tools.Resize.Listeners.Equipped = function ()

	-- Change the color of selection boxes temporarily
	Tools.Resize.Temporary.PreviousSelectionBoxColor = SelectionBoxColor;
	SelectionBoxColor = Tools.Resize.Color;
	updateSelectionBoxColor();

	-- Reveal the GUI
	Tools.Resize:showGUI();

	-- Always have the handles on the most recent addition to the selection
	table.insert( Tools.Resize.Temporary.Connections, Selection.Changed:connect( function ()

		-- Clear out any previous adornee
		Tools.Resize:hideHandles();

		-- If there /is/ a last item in the selection, attach the handles to it
		if Selection.Last then
			Tools.Resize:showHandles( Selection.Last );
		end;

	end ) );

	-- Switch the adornee of the handles if the second mouse button is pressed
	table.insert( Tools.Resize.Temporary.Connections, Mouse.Button2Up:connect( function ()

		-- Make sure the platform doesn't think we're selecting
		override_selection = true;

		-- If the target is in the selection, make it the new adornee
		if Selection:find( Mouse.Target ) then
			Tools.Resize:showHandles( Mouse.Target );
		end;

	end ) );

	-- Finally, attach the handles to the last item added to the selection (if any)
	if Selection.Last then
		Tools.Resize:showHandles( Selection.Last );
	end;

end;

Tools.Resize.Listeners.Unequipped = function ()

	-- Hide the GUI
	Tools.Resize:hideGUI();

	-- Hide the handles
	Tools.Resize:hideHandles();

	-- Clear out any temporary connections
	for connection_index, Connection in pairs( Tools.Resize.Temporary.Connections ) do
		Connection:disconnect();
		Tools.Resize.Temporary.Connections[connection_index] = nil;
	end;

	-- Restore the original color of the selection boxes
	SelectionBoxColor = Tools.Resize.Temporary.PreviousSelectionBoxColor;
	updateSelectionBoxColor();

end;

Tools.Resize.showGUI = function ( self )

	-- Create the GUI if it doesn't exist
	if not self.Temporary.GUI then
		local GUIRoot = Instance.new( "ScreenGui", Player.PlayerGui );
		GUIRoot.Name = "BTResizeToolGUI";

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
			Name = "DirectionsOption";
			BackgroundTransparency = 1;
			BorderSizePixel = 0;
			Position = UDim2.new( 0, 0, 0, 30 );
		};

		RbxUtility.Create "Frame" {
			Parent = GUIRoot.Container.DirectionsOption;
			Name = "Normal";
			BackgroundTransparency = 1;
			BorderSizePixel = 0;
			Position = UDim2.new( 0, 70, 0, 0 );
			Size = UDim2.new( 0, 70, 0, 25 );
		};

		RbxUtility.Create "Frame" {
			Parent = GUIRoot.Container.DirectionsOption.Normal;
			Name = "SelectedIndicator";
			BackgroundColor3 = Color3.new( 1, 1, 1 );
			BorderSizePixel = 0;
			Position = UDim2.new( 0, 6, 0, -2 );
			Size = UDim2.new( 1, -5, 0, 2 );
			BackgroundTransparency = ( self.Options.directions == "normal" ) and 0 or 1;
		};

		RbxUtility.Create "TextButton" {
			Parent = GUIRoot.Container.DirectionsOption.Normal;
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
				self.Options.directions = "normal";
				GUIRoot.Container.DirectionsOption.Normal.SelectedIndicator.BackgroundTransparency = 0;
				GUIRoot.Container.DirectionsOption.Normal.Background.Image = dark_slanted_rectangle;
				GUIRoot.Container.DirectionsOption.Both.SelectedIndicator.BackgroundTransparency = 1;
				GUIRoot.Container.DirectionsOption.Both.Background.Image = light_slanted_rectangle;
			end;
		};

		RbxUtility.Create "ImageLabel" {
			Parent = GUIRoot.Container.DirectionsOption.Normal;
			Name = "Background";
			BackgroundTransparency = 1;
			BorderSizePixel = 0;
			Image = ( self.Options.directions == "normal" ) and dark_slanted_rectangle or light_slanted_rectangle;
			Size = UDim2.new( 1, 0, 1, 0 );
		};

		RbxUtility.Create "TextLabel" {
			Parent = GUIRoot.Container.DirectionsOption.Normal;
			Name = "Label";
			BackgroundTransparency = 1;
			BorderSizePixel = 0;
			Size = UDim2.new( 1, 0, 1, 0 );
			Font = Enum.Font.ArialBold;
			FontSize = Enum.FontSize.Size12;
			Text = "NORMAL";
			TextColor3 = Color3.new( 1, 1, 1 );
		};

		RbxUtility.Create "Frame" {
			Parent = GUIRoot.Container.DirectionsOption;
			Name = "Both";
			BackgroundTransparency = 1;
			BorderSizePixel = 0;
			Position = UDim2.new( 0, 135, 0, 0 );
			Size = UDim2.new( 0, 70, 0, 25 );
		};

		RbxUtility.Create "Frame" {
			Parent = GUIRoot.Container.DirectionsOption.Both;
			Name = "SelectedIndicator";
			BackgroundColor3 = Color3.new( 1, 1, 1 );
			BorderSizePixel = 0;
			Position = UDim2.new( 0, 6, 0, -2 );
			Size = UDim2.new( 1, -5, 0, 2 );
			BackgroundTransparency = ( self.Options.directions == "both" ) and 0 or 1;
		};

		RbxUtility.Create "TextButton" {
			Parent = GUIRoot.Container.DirectionsOption.Both;
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
				self.Options.directions = "both";
				GUIRoot.Container.DirectionsOption.Normal.SelectedIndicator.BackgroundTransparency = 1;
				GUIRoot.Container.DirectionsOption.Normal.Background.Image = light_slanted_rectangle;
				GUIRoot.Container.DirectionsOption.Both.SelectedIndicator.BackgroundTransparency = 0;
				GUIRoot.Container.DirectionsOption.Both.Background.Image = dark_slanted_rectangle;
			end;
		};

		RbxUtility.Create "ImageLabel" {
			Parent = GUIRoot.Container.DirectionsOption.Both;
			Name = "Background";
			BackgroundTransparency = 1;
			BorderSizePixel = 0;
			Image = ( self.Options.directions == "both" ) and dark_slanted_rectangle or light_slanted_rectangle;
			Size = UDim2.new( 1, 0, 1, 0 );
		};

		RbxUtility.Create "TextLabel" {
			Parent = GUIRoot.Container.DirectionsOption.Both;
			Name = "Label";
			BackgroundTransparency = 1;
			BorderSizePixel = 0;
			Size = UDim2.new( 1, 0, 1, 0 );
			Font = Enum.Font.ArialBold;
			FontSize = Enum.FontSize.Size12;
			Text = "BOTH";
			TextColor3 = Color3.new( 1, 1, 1 );
		};

		RbxUtility.Create "Frame" {
			Parent = GUIRoot.Container.DirectionsOption;
			Name = "Label";
			BorderSizePixel = 0;
			BackgroundTransparency = 1;
			Size = UDim2.new( 0, 75, 0, 25 );
		};

		RbxUtility.Create "TextLabel" {
			Parent = GUIRoot.Container.DirectionsOption.Label;
			BackgroundTransparency = 1;
			BorderSizePixel = 0;
			Size = UDim2.new( 1, 0, 1, 0 );
			Font = Enum.Font.ArialBold;
			FontSize = Enum.FontSize.Size12;
			Text = "Directions";
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
			BackgroundColor3 = self.Color.Color;
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
			Text = "RESIZE TOOL";
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
			Name = "Info";
			BackgroundTransparency = 1;
			BorderSizePixel = 0;
			Position = UDim2.new( 0, 5, 0, 100 );
			Size = UDim2.new( 1, -5, 0, 60 );
			Visible = false;
		};

		RbxUtility.Create "Frame" {
			Parent = GUIRoot.Container.Info;
			Name = "ColorBar";
			BorderSizePixel = 0;
			BackgroundColor3 = self.Color.Color;
			Size = UDim2.new( 1, 0, 0, 2 );
		};

		RbxUtility.Create "TextLabel" {
			Parent = GUIRoot.Container.Info;
			Name = "Label";
			BorderSizePixel = 0;
			BackgroundTransparency = 1;
			Position = UDim2.new( 0, 10, 0, 2 );
			Size = UDim2.new( 1, -10, 0, 20 );
			Font = Enum.Font.ArialBold;
			FontSize = Enum.FontSize.Size12;
			Text = "SELECTION INFO";
			TextColor3 = Color3.new( 1, 1, 1 );
			TextStrokeColor3 = Color3.new( 0, 0, 0 );
			TextStrokeTransparency = 0;
			TextWrapped = true;
			TextXAlignment = Enum.TextXAlignment.Left;
		};

		RbxUtility.Create "Frame" {
			Parent = GUIRoot.Container.Info;
			Name = "SizeInfo";
			BackgroundTransparency = 1;
			BorderSizePixel = 0;
			Position = UDim2.new( 0, 0, 0, 30 );
		};

		RbxUtility.Create "TextLabel" {
			Parent = GUIRoot.Container.Info.SizeInfo;
			BackgroundTransparency = 1;
			BorderSizePixel = 0;
			Size = UDim2.new( 0, 75, 0, 25 );
			Font = Enum.Font.ArialBold;
			FontSize = Enum.FontSize.Size12;
			Text = "Size";
			TextColor3 = Color3.new( 1, 1, 1 );
			TextStrokeColor3 = Color3.new( 0, 0, 0);
			TextStrokeTransparency = 0;
			TextWrapped = true;
		};

		RbxUtility.Create "Frame" {
			Parent = GUIRoot.Container.Info.SizeInfo;
			Name = "X";
			BackgroundTransparency = 1;
			BorderSizePixel = 0;
			Position = UDim2.new( 0, 70, 0, 0 );
			Size = UDim2.new( 0, 50, 0, 25 );
		};

		RbxUtility.Create "TextLabel" {
			Parent = GUIRoot.Container.Info.SizeInfo.X;
			Name = "TextLabel";
			BackgroundTransparency = 1;
			BorderSizePixel = 0;
			Position = UDim2.new( 0, 5, 0, 0 );
			Size = UDim2.new( 1, -10, 1, 0 );
			ZIndex = 2;
			Font = Enum.Font.ArialBold;
			FontSize = Enum.FontSize.Size12;
			Text = "";
			TextColor3 = Color3.new( 1, 1, 1 );
			TextWrapped = true;
		};

		RbxUtility.Create "ImageLabel" {
			Parent = GUIRoot.Container.Info.SizeInfo.X;
			Name = "Background";
			BackgroundTransparency = 1;
			BorderSizePixel = 0;
			Size = UDim2.new( 1, 0, 1, 0 );
			Image = light_slanted_rectangle;
		};

		RbxUtility.Create "Frame" {
			Parent = GUIRoot.Container.Info.SizeInfo;
			Name = "Y";
			BackgroundTransparency = 1;
			BorderSizePixel = 0;
			Position = UDim2.new( 0, 117, 0, 0 );
			Size = UDim2.new( 0, 50, 0, 25 );
		};

		RbxUtility.Create "TextLabel" {
			Parent = GUIRoot.Container.Info.SizeInfo.Y;
			Name = "TextLabel";
			BackgroundTransparency = 1;
			BorderSizePixel = 0;
			Position = UDim2.new( 0, 5, 0, 0 );
			Size = UDim2.new( 1, -10, 1, 0 );
			ZIndex = 2;
			Font = Enum.Font.ArialBold;
			FontSize = Enum.FontSize.Size12;
			Text = "";
			TextColor3 = Color3.new( 1, 1, 1 );
			TextWrapped = true;
		};

		RbxUtility.Create "ImageLabel" {
			Parent = GUIRoot.Container.Info.SizeInfo.Y;
			Name = "Background";
			BackgroundTransparency = 1;
			BorderSizePixel = 0;
			Size = UDim2.new( 1, 0, 1, 0 );
			Image = light_slanted_rectangle;
		};

		RbxUtility.Create "Frame" {
			Parent = GUIRoot.Container.Info.SizeInfo;
			Name = "Z";
			BackgroundTransparency = 1;
			BorderSizePixel = 0;
			Position = UDim2.new( 0, 164, 0, 0 );
			Size = UDim2.new( 0, 50, 0, 25 );
		};

		RbxUtility.Create "TextLabel" {
			Parent = GUIRoot.Container.Info.SizeInfo.Z;
			Name = "TextLabel";
			BackgroundTransparency = 1;
			BorderSizePixel = 0;
			Position = UDim2.new( 0, 5, 0, 0 );
			Size = UDim2.new( 1, -10, 1, 0 );
			ZIndex = 2;
			Font = Enum.Font.ArialBold;
			FontSize = Enum.FontSize.Size12;
			Text = "";
			TextColor3 = Color3.new( 1, 1, 1 );
			TextWrapped = true;
		};

		RbxUtility.Create "ImageLabel" {
			Parent = GUIRoot.Container.Info.SizeInfo.Z;
			Name = "Background";
			BackgroundTransparency = 1;
			BorderSizePixel = 0;
			Size = UDim2.new( 1, 0, 1, 0 );
			Image = light_slanted_rectangle;
		};

		RbxUtility.Create "Frame" {
			Parent = GUIRoot.Container;
			Name = "Changes";
			BackgroundTransparency = 1;
			BorderSizePixel = 0;
			Position = UDim2.new( 0, 5, 0, 165 );
			Size = UDim2.new( 1, -5, 0, 20 );
			Visible = false;
		};

		RbxUtility.Create "Frame" {
			Parent = GUIRoot.Container.Changes;
			Name = "ColorBar";
			BorderSizePixel = 0;
			BackgroundColor3 = self.Color.Color;
			Size = UDim2.new( 1, 0, 0, 2 );
		};

		RbxUtility.Create "TextLabel" {
			Parent = GUIRoot.Container.Changes;
			Name = "Text";
			BorderSizePixel = 0;
			BackgroundTransparency = 1;
			Position = UDim2.new( 0, 10, 0, 2 );
			Size = UDim2.new( 1, -10, 0, 20 );
			Font = Enum.Font.ArialBold;
			FontSize = Enum.FontSize.Size11;
			Text = "";
			TextColor3 = Color3.new( 1, 1, 1 );
			TextStrokeColor3 = Color3.new( 0, 0, 0 );
			TextStrokeTransparency = 0.5;
			TextWrapped = true;
			TextXAlignment = Enum.TextXAlignment.Right;
		};

		-- Constantly update the GUI if it's visible
		coroutine.wrap( function ()
			while wait( 0.1 ) do
				if GUIRoot.Container.Visible then
					self:updateGUI();
				end;
			end;
		end )();

		self.Temporary.GUI = GUIRoot;
	end;

	-- Reveal the GUI
	self.Temporary.GUI.Container.Visible = true;

end;

Tools.Resize.updateGUI = function ( self )

	-- Make sure the GUI exists
	if not self.Temporary.GUI then
		return;
	end;

	local GUI = self.Temporary.GUI.Container;

	if #Selection.Items > 0 then

		-- Get the size and position of the selection
		local SelectionSize, SelectionPosition = _getCollectionInfo( Selection.Items );

		-- Update the size info on the GUI
		GUI.Info.SizeInfo.X.TextLabel.Text = tostring( _round( SelectionSize.x, 2 ) );
		GUI.Info.SizeInfo.Y.TextLabel.Text = tostring( _round( SelectionSize.y, 2 ) );
		GUI.Info.SizeInfo.Z.TextLabel.Text = tostring( _round( SelectionSize.z, 2 ) );

		GUI.Info.Visible = true;
	else
		GUI.Info.Visible = false;
	end;

	if self.State.length_resized then
		GUI.Changes.Text.Text = "resized " .. tostring( self.State.length_resized ) .. " studs";
		GUI.Changes.Position = GUI.Info.Visible and UDim2.new( 0, 5, 0, 165 ) or UDim2.new( 0, 5, 0, 100 );
		GUI.Changes.Visible = true;
	else
		GUI.Changes.Text.Text = "";
		GUI.Changes.Visible = false;
	end;

end;

Tools.Resize.hideGUI = function ( self )

	-- Hide the GUI if it exists
	if self.Temporary.GUI then
		self.Temporary.GUI.Container.Visible = false;
	end;

end;

Tools.Resize.showHandles = function ( self, Part )

	-- Create the handles if they don't exist yet
	if not self.Temporary.Handles then

		-- Create the object
		self.Temporary.Handles = RbxUtility.Create "Handles" {
			Name = "BTMovementHandles";
			Style = Enum.HandlesStyle.Resize;
			Color = self.Color;
			Parent = Player.PlayerGui;
		};

		-- Add functionality to the handles
		self.Temporary.Handles.MouseButton1Down:connect( function ()

			-- Prevent the platform from thinking we're selecting
			override_selection = true;
			self.State.resizing = true;

			-- Clear the change stats
			self.State.length_resized = 0;

			-- Do a few things to the selection before manipulating it
			for _, Item in pairs( Selection.Items ) do

				-- Keep a copy of the state of each item
				self.State.PreResize[Item] = Item:Clone();

				-- Make the item be able to be freely resized
				Item.FormFactor = Enum.FormFactor.Custom;

				-- Anchor each item
				Item.Anchored = true;

			end;

			-- Return stuff to normal once the mouse button is released
			self.Temporary.Connections.HandleReleaseListener = Mouse.Button1Up:connect( function ()

				-- Prevent the platform from thinking we're selecting
				override_selection = true;
				self.State.resizing = false;

				-- Stop this connection from firing again
				self.Temporary.Connections.HandleReleaseListener:disconnect();
				self.Temporary.Connections.HandleReleaseListener = nil;

				-- Restore properties that may have been changed temporarily
				-- from the pre-resize state copies
				for Item, PreviousItemState in pairs( self.State.PreResize ) do
					Item.Anchored = PreviousItemState.Anchored;
					self.State.PreResize[Item] = nil;
					Item:MakeJoints();
				end;

			end );

		end );

		self.Temporary.Handles.MouseDrag:connect( function ( face, distance )
			
			-- Round `distance` down
			local distance = math.floor( distance );

			-- Make sure the distance has changed by at least 1 unit
			if distance == self.State.previous_distance then
				return;
			end;

			-- Log the distance that the handle was dragged
			self.State.previous_distance = distance;

			-- Note the length by which the selection will be enlarged
			local increase;
			if self.Options.directions == "normal" then
				increase = distance * self.Options.increment;
			elseif self.Options.directions == "both" then
				increase = distance * self.Options.increment * 2;
			end;
			self.State.length_resized = increase;

			-- Go through the selection and make changes to it
			for _, Item in pairs( Selection.Items ) do

				-- Keep a copy of `Item` in case we need to revert anything
				local PreviousItemState = Item:Clone();

				-- Break any of `Item`'s joints so it can move freely
				Item:BreakJoints();

				-- Position and resize `Item` according to the options and the handle that was used

				if face == Enum.NormalId.Top then
					Item.Size = self.State.PreResize[Item].Size + Vector3.new( 0, increase, 0 );
					if Item.Size == self.State.PreResize[Item].Size + Vector3.new( 0, increase, 0 ) then
						Item.CFrame = ( self.Options.directions == "normal" and self.State.PreResize[Item].CFrame:toWorldSpace( CFrame.new( 0, increase / 2, 0 ) ) )
									  or ( self.Options.directions == "both" and self.State.PreResize[Item].CFrame );
					-- If the resizing was not possible, revert `Item`'s state
					else
						Item.Size = PreviousItemState.Size;
						Item.CFrame = PreviousItemState.CFrame;
					end;

				elseif face == Enum.NormalId.Bottom then
					Item.Size = self.State.PreResize[Item].Size + Vector3.new( 0, increase, 0 );
					if Item.Size == self.State.PreResize[Item].Size + Vector3.new( 0, increase, 0 ) then
						Item.CFrame = ( self.Options.directions == "normal" and self.State.PreResize[Item].CFrame:toWorldSpace( CFrame.new( 0, -increase / 2, 0 ) ) )
									  or ( self.Options.directions == "both" and self.State.PreResize[Item].CFrame );
					-- If the resizing was not possible, revert `Item`'s state
					else
						Item.Size = PreviousItemState.Size;
						Item.CFrame = PreviousItemState.CFrame;
					end;

				elseif face == Enum.NormalId.Front then
					Item.Size = self.State.PreResize[Item].Size + Vector3.new( 0, 0, increase );
					if Item.Size == self.State.PreResize[Item].Size + Vector3.new( 0, 0, increase ) then
						Item.CFrame = ( self.Options.directions == "normal" and self.State.PreResize[Item].CFrame:toWorldSpace( CFrame.new( 0, 0, -increase / 2 ) ) )
									  or ( self.Options.directions == "both" and self.State.PreResize[Item].CFrame );
					-- If the resizing was not possible, revert `Item`'s state
					else
						Item.Size = PreviousItemState.Size;
						Item.CFrame = PreviousItemState.CFrame;
					end;

				elseif face == Enum.NormalId.Back then
					Item.Size = self.State.PreResize[Item].Size + Vector3.new( 0, 0, increase );
					if Item.Size == self.State.PreResize[Item].Size + Vector3.new( 0, 0, increase ) then
						Item.CFrame = ( self.Options.directions == "normal" and self.State.PreResize[Item].CFrame:toWorldSpace( CFrame.new( 0, 0, increase / 2 ) ) )
									  or ( self.Options.directions == "both" and self.State.PreResize[Item].CFrame );
					-- If the resizing was not possible, revert `Item`'s state
					else
						Item.Size = PreviousItemState.Size;
						Item.CFrame = PreviousItemState.CFrame;
					end;

				elseif face == Enum.NormalId.Left then
					Item.Size = self.State.PreResize[Item].Size + Vector3.new( increase, 0, 0 );
					if Item.Size == self.State.PreResize[Item].Size + Vector3.new( increase, 0, 0 ) then
						Item.CFrame = ( self.Options.directions == "normal" and self.State.PreResize[Item].CFrame:toWorldSpace( CFrame.new( -increase / 2, 0, 0 ) ) )
									  or ( self.Options.directions == "both" and self.State.PreResize[Item].CFrame );
					-- If the resizing was not possible, revert `Item`'s state
					else
						Item.Size = PreviousItemState.Size;
						Item.CFrame = PreviousItemState.CFrame;
					end;

				elseif face == Enum.NormalId.Right then
					Item.Size = self.State.PreResize[Item].Size + Vector3.new( increase, 0, 0 );
					if Item.Size == self.State.PreResize[Item].Size + Vector3.new( increase, 0, 0 ) then
						Item.CFrame = ( self.Options.directions == "normal" and self.State.PreResize[Item].CFrame:toWorldSpace( CFrame.new( increase / 2, 0, 0 ) ) )
									  or ( self.Options.directions == "both" and self.State.PreResize[Item].CFrame );
					-- If the resizing was not possible, revert `Item`'s state
					else
						Item.Size = PreviousItemState.Size;
						Item.CFrame = PreviousItemState.CFrame;
					end;
				end;

				-- Make joints with surrounding parts again once the resizing is done
				Item:MakeJoints();

			end;

		end );

	end;

	-- Stop listening for the existence of the previous adornee (if any)
	if self.Temporary.Connections.AdorneeExistenceListener then
		self.Temporary.Connections.AdorneeExistenceListener:disconnect();
		self.Temporary.Connections.AdorneeExistenceListener = nil;
	end;

	-- Attach the handles to `Part`
	self.Temporary.Handles.Adornee = Part;

	-- Make sure to hide the handles if `Part` suddenly stops existing
	self.Temporary.Connections.AdorneeExistenceListener = Part.AncestryChanged:connect( function ( Object, NewParent )

		-- Make sure this change in parent applies directly to `Part`
		if Object ~= Part then
			return;
		end;

		-- Show the handles according to the existence of the part
		if NewParent == nil then
			self:hideHandles();
		else
			self:showHandles( Part );
		end;

	end );

end;

Tools.Resize.hideHandles = function ( self )

	-- Hide the handles if they exist
	if self.Temporary.Handles then
		self.Temporary.Handles.Adornee = nil;
	end;

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

		elseif key == "x" then
			Options.Tool = Tools.Resize;

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
		if not override_selection and Mouse.Target then
			if Mouse.Target:IsA( "BasePart" ) and not Mouse.Target.Locked and Options.TargetBox.Adornee ~= Mouse.Target and not Selection:find( Mouse.Target ) then
				Options.TargetBox.Adornee = Mouse.Target;
			end;
		end;

		-- When aiming at something invalid, don't highlight any targets
		if not override_selection and not Mouse.Target or ( Mouse.Target and Mouse.Target:IsA( "BasePart" ) and Mouse.Target.Locked ) or Selection:find( Mouse.Target ) then
			Options.TargetBox.Adornee = nil;
		end;

		-- If spay-like multi-selecting, add this current target to the selection
		if not override_selection and selecting and clicking then
			if Mouse.Target and Mouse.Target:IsA( "BasePart" ) and not Mouse.Target.Locked then
				Selection:add( Mouse.Target );
			end;
		end;

		-- Fire tool listeners
		if Options.Tool and Options.Tool.Listeners.Move then
			Options.Tool.Listeners.Move();
		end;

		if override_selection then
			override_selection = false;
		end;

	end );

	Mouse.Button1Up:connect( function ()

		clicking = false;

		-- If the target when clicking was invalid then clear the selection (unless we're multi-selecting)
		if not override_selection and not selecting and ( not Mouse.Target or ( Mouse.Target and Mouse.Target:IsA( "BasePart" ) and Mouse.Target.Locked ) ) then
			Selection:clear();
		end;

		-- If multi-selecting, add to/remove from the selection
		if not override_selection and selecting then

			-- If the item isn't already selected, add it to the selection
			if not Selection:find( Mouse.Target ) then
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
			if not override_selection and Mouse.Target and Mouse.Target:IsA( "BasePart" ) and not Mouse.Target.Locked then
				Selection:clear();
				Selection:add( Mouse.Target );
			end;
		end;

		-- Fire tool listeners
		if Options.Tool and Options.Tool.Listeners.Button1Up then
			Options.Tool.Listeners.Button1Up();
		end;

		if override_selection then
			override_selection = false;
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