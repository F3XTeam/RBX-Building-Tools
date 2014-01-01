------------------------------------------
-- Create references to important objects
------------------------------------------
Services = {
	["Workspace"] = Game:GetService( "Workspace" );
	["Players"] = Game:GetService( "Players" );
	["Lighting"] = Game:GetService( "Lighting" );
	["Teams"] = Game:GetService( "Teams" );
	["Debris"] = Game:GetService( "Debris" );
	["MarketplaceService"] = Game:GetService( "MarketplaceService" );
	["JointsService"] = Game.JointsService;
	["BadgeService"] = Game:GetService( "BadgeService" );
	["RunService"] = Game:GetService( "RunService" );
	["ContentProvider"] = Game:GetService( "ContentProvider" );
	["TeleportService"] = Game:GetService( "TeleportService" );
	["SoundService"] = Game:GetService( "SoundService" );
	["InsertService"] = Game:GetService( "InsertService" );
	["CollectionService"] = Game:GetService( "CollectionService" );
	["UserInputService"] = Game:GetService( "UserInputService" );
	["GamePassService"] = Game:GetService( "GamePassService" );
	["StarterPack"] = Game:GetService( "StarterPack" );
	["StarterGui"] = Game:GetService( "StarterGui" );
	["TestService"] = Game:GetService( "TestService" );
	["ReplicatedStorage"] = Game:GetService( "ReplicatedStorage" );
};

Tool = script.Parent;
Player = Services.Players.LocalPlayer;
Mouse = nil;
Camera = Services.Workspace.CurrentCamera;

GetAsync = function ( ... )
	return Tool.GetAsync:InvokeServer( ... );
end;
PostAsync = function ( ... )
	return Tool.PostAsync:InvokeServer( ... );
end;

dark_slanted_rectangle = "http://www.roblox.com/asset/?id=127774197";
light_slanted_rectangle = "http://www.roblox.com/asset/?id=127772502";
action_completion_sound = "http://www.roblox.com/asset/?id=99666917";
expand_arrow = "http://www.roblox.com/asset/?id=134367382";
tool_decal = "http://www.roblox.com/asset/?id=129748355";

------------------------------------------
-- Load external dependencies
------------------------------------------
RbxUtility = LoadLibrary( "RbxUtility" );
Services.ContentProvider:Preload( dark_slanted_rectangle );
Services.ContentProvider:Preload( light_slanted_rectangle );
Services.ContentProvider:Preload( action_completion_sound );
Services.ContentProvider:Preload( expand_arrow );
Services.ContentProvider:Preload( tool_decal );

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

	-- Create shortcuts to certain things that are expensive to call constantly
	-- (note: otherwise it actually becomes an issue if the selection grows
	-- considerably large)
	local table_insert = table.insert;
	local newCFrame = CFrame.new;

	for _, Part in pairs( part_collection ) do

		local PartCFrame = Part.CFrame;
		local partCFrameOffset = PartCFrame.toWorldSpace;
		local PartSize = Part.Size / 2;
		local size_x, size_y, size_z = PartSize.x, PartSize.y, PartSize.z;

		table_insert( corners, partCFrameOffset( PartCFrame, newCFrame( size_x, size_y, size_z ) ) );
		table_insert( corners, partCFrameOffset( PartCFrame, newCFrame( -size_x, size_y, size_z ) ) );
		table_insert( corners, partCFrameOffset( PartCFrame, newCFrame( size_x, -size_y, size_z ) ) );
		table_insert( corners, partCFrameOffset( PartCFrame, newCFrame( size_x, size_y, -size_z ) ) );
		table_insert( corners, partCFrameOffset( PartCFrame, newCFrame( -size_x, size_y, -size_z ) ) );
		table_insert( corners, partCFrameOffset( PartCFrame, newCFrame( -size_x, -size_y, size_z ) ) );
		table_insert( corners, partCFrameOffset( PartCFrame, newCFrame( size_x, -size_y, -size_z ) ) );
		table_insert( corners, partCFrameOffset( PartCFrame, newCFrame( -size_x, -size_y, -size_z ) ) );

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

function _getAllDescendants( Parent )
	-- Recursively gets all the descendants of  `Parent` and returns them

	local descendants = {};

	for _, Child in pairs( Parent:GetChildren() ) do

		-- Add the direct descendants of `Parent`
		table.insert( descendants, Child );

		-- Add the descendants of each child
		for _, Subchild in pairs( _getAllDescendants( Child ) ) do
			table.insert( descendants, Subchild );
		end;

	end;

	return descendants;

end;

function _pointToScreenSpace( Point )
	-- Returns Vector3 `Point`'s position on the screen when rendered
	-- (kudos to stravant for this)

	local point = Camera.CoordinateFrame:pointToObjectSpace( Point );
	local aspectRatio = Mouse.ViewSizeX / Mouse.ViewSizeY;
	local hfactor = math.tan( math.rad( Camera.FieldOfView ) / 2 )
	local wfactor = aspectRatio * hfactor;

	local x = ( point.x / point.z ) / -wfactor;
	local y = ( point.y / point.z ) /  hfactor;

	local screen_pos = Vector2.new( Mouse.ViewSizeX * ( 0.5 + 0.5 * x ), Mouse.ViewSizeY * ( 0.5 + 0.5 * y ) );
	if ( screen_pos.x < 0 or screen_pos.x > Mouse.ViewSizeX ) or ( screen_pos.y < 0 or screen_pos.y > Mouse.ViewSizeY ) then
		return nil;
	end;
	if Camera.CoordinateFrame:toObjectSpace( CFrame.new( Point ) ).z > 0 then
		return nil;
	end;

	return screen_pos;

end;

function _cloneParts( parts )
	-- Returns a table of cloned `parts`

	local new_parts = {};

	-- Copy the parts into `new_parts`
	for part_index, Part in pairs( parts ) do
		new_parts[part_index] = Part:Clone();
	end;

	return new_parts;
end;

function _replaceParts( old_parts, new_parts )
	-- Removes `old_parts` and inserts `new_parts`

	-- Remove old parts
	for _, OldPart in pairs( old_parts ) do
		OldPart.Parent = nil;
	end;

	-- Insert `new_parts
	for _, NewPart in pairs( new_parts ) do
		NewPart.Parent = Services.Workspace;
		NewPart:MakeJoints();
	end;

end;

function _splitString( str, delimiter )
	-- Returns a table of string `str` split by pattern `delimiter`

	local parts = {};
	local pattern = ( "([^%s]+)" ):format( delimiter );

	str:gsub( pattern, function ( part )
		table.insert( parts, part );
	end );

	return parts;
end;

function _generateSerializationID()
	-- Returns a random 5-character string
	-- with characters A-Z, a-z, and 0-9
	-- (there are 916,132,832 unique IDs)

	local characters = {
		"0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
		"a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
		"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z" };

	local serialization_id = "";

	-- Pick out 5 random characters
	for _ = 1, 5 do
		serialization_id = serialization_id .. ( characters[math.random( #characters )] );
	end;

	return serialization_id;
end;

function _splitNumberListString( str )
	-- Returns the contents of _splitString( str, ", " ), except
	-- each value in the table is turned into a number

	-- Get the number strings
	local numbers = _splitString( str, ", " );

	-- Turn them into numbers
	for number_index, number in pairs( numbers ) do
		numbers[number_index] = tonumber( number );
	end;

	-- Return `numbers`
	return numbers;
end;

function _getSerializationPartType( Part )
	-- Returns a special number that determines the type of
	-- part `Part` is

	local Types = {
		Normal = 1,
		Truss = 2,
		Wedge = 3,
		Corner = 4,
		Cylinder = 5,
		Ball = 6,
		Seat = 7,
		VehicleSeat = 8,
		Spawn = 9
	};

	-- Return the appropriate type number
	if Part.ClassName == "Part" then
		if Part.Shape == Enum.PartType.Block then
			return Types.Normal;
		elseif Part.Shape == Enum.PartType.Cylinder then
			return Types.Cylinder;
		elseif Part.Shape == Enum.PartType.Ball then
			return Types.Ball;
		end;

	elseif Part.ClassName == "Seat" then
		return Types.Seat;

	elseif Part.ClassName == "VehicleSeat" then
		return Types.VehicleSeat;

	elseif Part.ClassName == "SpawnLocation" then
		return Types.Spawn;

	elseif Part.ClassName == "WedgePart" then
		return Types.Wedge;

	elseif Part.ClassName == "CornerWedgePart" then
		return Types.Corner;

	elseif Part.ClassName == "TrussPart" then
		return Types.Truss;

	end;

end;

function _serializeParts( parts )
	-- Returns JSON-encoded data about parts in
	-- table `parts` that can be used to recreate them

	local data = {
		version = 1,
		parts = {}
	};

	local objects = {};

	-- Store part data
	for _, Part in pairs( parts ) do
		local part_id = _generateSerializationID();
		local PartData = {
			_getSerializationPartType( Part ),
			_splitNumberListString( tostring( Part.Size ) ),
			_splitNumberListString( tostring( Part.CFrame ) ),
			Part.BrickColor.Number,
			Part.Material.Value,
			Part.Anchored,
			Part.CanCollide,
			Part.Reflectance,
			Part.Transparency,
			Part.TopSurface.Value,
			Part.BottomSurface.Value,
			Part.LeftSurface.Value,
			Part.RightSurface.Value,
			Part.FrontSurface.Value,
			Part.BackSurface.Value
		};
		data.parts[part_id] = PartData;
		objects[part_id] = Part;
	end;

	-- Get any meshes in the selection
	local meshes = {};
	for _, Part in pairs( parts ) do
		local Mesh = _getChildOfClass( Part, "SpecialMesh" );
		if Mesh then
			table.insert( meshes, Mesh );
		end;
	end;

	-- Serialize any meshes
	if #meshes > 0 then
		data.meshes = {};
		for _, Mesh in pairs( meshes ) do
			local mesh_id = _generateSerializationID();
			local MeshData = {
				_findTableOccurrences( objects, Mesh.Parent )[1],
				Mesh.MeshType.Value,
				_splitNumberListString( tostring( Mesh.Scale ) ),
				Mesh.MeshId,
				Mesh.TextureId,
				_splitNumberListString( tostring( Mesh.VertexColor ) )
			};
			data.meshes[mesh_id] = MeshData;
			objects[mesh_id] = Mesh;
		end;
	end;

	-- Get any textures in the selection
	local textures = {};
	for _, Part in pairs( parts ) do
		local textures_found = _getChildrenOfClass( Part, "Texture" );
		for _, Texture in pairs( textures_found ) do
			table.insert( textures, Texture );
		end;
		local decals_found = _getChildrenOfClass( Part, "Decal" );
		for _, Decal in pairs( decals_found ) do
			table.insert( textures, Decal );
		end;
	end;

	-- Serialize any textures
	if #textures > 0 then
		data.textures = {};
		for _, Texture in pairs( textures ) do
			local texture_type;
			if Texture.ClassName == "Decal" then
				texture_type = 1;
			elseif Texture.ClassName == "Texture" then
				texture_type = 2;
			end;
			local texture_id = _generateSerializationID();
			local TextureData = {
				_findTableOccurrences( objects, Texture.Parent )[1],
				texture_type,
				Texture.Face.Value,
				Texture.Texture,
				Texture.Transparency,
				texture_type == 2 and Texture.StudsPerTileU or nil,
				texture_type == 2 and Texture.StudsPerTileV or nil
			};
			data.textures[texture_id] = TextureData;
			objects[texture_id] = Texture;
		end;
	end;

	return RbxUtility.EncodeJSON( data );

end;

function _getChildOfClass( Parent, class_name )
	-- Returns the first child of `Parent` that is of class `class_name`
	-- or nil if it couldn't find any

	-- Look for a child of `Parent` of class `class_name` and return it
	for _, Child in pairs( Parent:GetChildren() ) do
		if Child.ClassName == class_name then
			return Child;
		end;
	end;

	return nil;

end;

function _getChildrenOfClass( Parent, class_name )
	-- Returns a table containing the children of `Parent` that are
	-- of class `class_name`
	local matches = {};

	-- Go through each child of `Parent`
	for _, Child in pairs( Parent:GetChildren() ) do

		-- If it's of type `class_name`, add it to the match list
		if Child.ClassName == class_name then
			table.insert( matches, Child );
		end;

	end;

	return matches;
end;

------------------------------------------
-- Create data containers
------------------------------------------
ActiveKeys = {};

CurrentTool = nil;

function equipTool( NewTool )

	-- If it's a different tool than the current one
	if CurrentTool ~= NewTool then

		-- Run (if existent) the old tool's `Unequipped` listener
		if CurrentTool and CurrentTool.Listeners.Unequipped then
			CurrentTool.Listeners.Unequipped();
		end;

		CurrentTool = NewTool;

		-- Recolor the handle
		Tool.Handle.BrickColor = NewTool.Color;

		-- Run (if existent) the new tool's `Equipped` listener
		if NewTool.Listeners.Equipped then
			NewTool.Listeners.Equipped();
		end;

	end;
end;

-- Keep some state data
clicking = false;
selecting = false;
click_x, click_y = 0, 0;
override_selection = false;

SelectionBoxes = {};
SelectionExistenceListeners = {};
SelectionBoxColor = BrickColor.new( "Cyan" );
TargetBox = nil;

-- Keep a container for temporary connections
-- from the platform
Connections = {};

-- Create the handle
if not Tool:FindFirstChild( "Handle" ) then
	Handle = RbxUtility.Create "Part" {
		Name = "Handle";
		Parent = Tool;
		Locked = true;
		FormFactor = Enum.FormFactor.Custom;
		Size = Vector3.new( 0.8, 0.8, 0.8 );
		TopSurface = Enum.SurfaceType.Smooth;
		BottomSurface = Enum.SurfaceType.Smooth;
	};

	RbxUtility.Create "Decal" {
		Parent = Handle;
		Face = Enum.NormalId.Front;
		Texture = tool_decal;
	};
	RbxUtility.Create "Decal" {
		Parent = Handle;
		Face = Enum.NormalId.Back;
		Texture = tool_decal;
	};
	RbxUtility.Create "Decal" {
		Parent = Handle;
		Face = Enum.NormalId.Left;
		Texture = tool_decal;
	};
	RbxUtility.Create "Decal" {
		Parent = Handle;
		Face = Enum.NormalId.Right;
		Texture = tool_decal;
	};
	RbxUtility.Create "Decal" {
		Parent = Handle;
		Face = Enum.NormalId.Top;
		Texture = tool_decal;
	};
	RbxUtility.Create "Decal" {
		Parent = Handle;
		Face = Enum.NormalId.Bottom;
		Texture = tool_decal;
	};
end;

-- Set the grip for the handle
Tool.Grip = CFrame.new( 0, 0, 0.4 );

-- Make sure the UI container gets placed
Player:WaitForChild( "PlayerGui" );
wait( 0 );
UI = RbxUtility.Create "ScreenGui" {
	Name = "Building Tools by F3X (UI)",
	Parent = Player.PlayerGui
};

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
		SelectionBoxes[NewPart] = Instance.new( "SelectionBox", UI );
		SelectionBoxes[NewPart].Name = "BTSelectionBox";
		SelectionBoxes[NewPart].Color = SelectionBoxColor;
		SelectionBoxes[NewPart].Adornee = NewPart;

		-- Remove any target selection box focus
		if NewPart == TargetBox.Adornee then
			TargetBox.Adornee = nil;
		end;

		-- Make sure to remove the item from the selection when it's deleted
		SelectionExistenceListeners[NewPart] = NewPart.AncestryChanged:connect( function ( Object, NewParent )
			if NewParent == nil then
				Selection:remove( NewPart );
			end;
		end );

		-- Provide a reference to the last item added to the selection (i.e. NewPart)
		self:focus( NewPart );

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

		-- Delete the item from the selection
		table.remove( self.Items, self:find( Item ) );

		-- If it was logged as the last item, change it
		if self.Last == Item then
			self:focus( ( #self.Items > 0 ) and self.Items[#self.Items] or nil );
		end;

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

	-- Provide a method to change the focus of the selection
	["focus"] = function ( self, NewFocus )

		-- Change the focus
		self.Last = NewFocus;

		-- Fire events
		self.Changed:fire();

	end;

};

Tools = {};

------------------------------------------
-- Move tool
------------------------------------------

-- Create the main container for this tool
Tools.Move = {};

-- Define the color of the tool
Tools.Move.Color = BrickColor.new( "Deep orange" );

-- Keep a container for temporary connections
Tools.Move.Connections = {};

-- Keep options in a container too
Tools.Move.Options = {
	["increment"] = 1;
	["axes"] = "global";
};

-- Keep internal state data in its own container
Tools.Move.State = {
	["distance_moved"] = 0;
	["moving"] = false;
	["PreMove"] = {};
};

-- Add listeners
Tools.Move.Listeners = {};

Tools.Move.Listeners.Equipped = function ()

	local self = Tools.Move;

	-- Make sure the tool is actually being equipped (because this is the default tool)
	if not Mouse then
		return;
	end;

	-- Change the color of selection boxes temporarily
	self.State.PreviousSelectionBoxColor = SelectionBoxColor;
	SelectionBoxColor = self.Color;
	updateSelectionBoxColor();

	-- Reveal the GUI
	self:showGUI();

	-- Create the boundingbox if it doesn't already exist
	if not self.BoundingBox then
		self.BoundingBox = RbxUtility.Create "Part" {
			Name = "BTBoundingBox";
			CanCollide = false;
			Transparency = 1;
			Anchored = true;
		};
	end;
	Mouse.TargetFilter = self.BoundingBox;

	-- Refresh the axis type option
	self:changeAxes( self.Options.axes );

	-- Listen for any keystrokes that might affect any dragging operation
	self.Connections.DraggerKeyListener = Mouse.KeyDown:connect( function ( key )

		local key = key:lower();

		-- Make sure a dragger exists
		if not self.Dragger then
			return;
		end;

		-- Rotate along the Z axis if `r` is pressed
		if key == "r" then
			self.Dragger:AxisRotate( Enum.Axis.Y );

		-- Rotate along the X axis if `t` is pressed
		elseif key == "t" then
			self.Dragger:AxisRotate( Enum.Axis.X );

		-- Rotate along the Y axis if `y` is pressed
		elseif key == "y" then
			self.Dragger:AxisRotate( Enum.Axis.Z );
		end;

		-- Simulate a mouse move so that it applies the changes
		self.Dragger:MouseMove( Mouse.UnitRay );

	end );

	-- Oh, and update the boundingbox and the GUI regularly
	coroutine.wrap( function ()
		local updater_on = true;

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

				-- Update the boundingbox if it's visible
				if self.Options.axes == "global" then
					self:updateBoundingBox();
				end;

			end;

		end;

	end )();

end;

Tools.Move.Listeners.Unequipped = function ()

	local self = Tools.Move;

	-- Stop the update loop
	self.Updater();
	self.Updater = nil;

	-- Hide the GUI
	self:hideGUI();

	-- Hide the handles
	self:hideHandles();

	-- Clear out any temporary connections
	for connection_index, Connection in pairs( self.Connections ) do
		Connection:disconnect();
		self.Connections[connection_index] = nil;
	end;

	-- Restore the original color of the selection boxes
	SelectionBoxColor = self.State.PreviousSelectionBoxColor;
	updateSelectionBoxColor();

end;

Tools.Move.updateGUI = function ( self )

	if self.GUI then
		local GUI = self.GUI;

		if #Selection.Items > 0 then

			-- Look for identical numbers in each axis
			local position_x, position_y, position_z =  nil, nil, nil;
			for item_index, Item in pairs( Selection.Items ) do

				-- Set the first values for the first item
				if item_index == 1 then
					position_x, position_y, position_z = _round( Item.Position.x, 2 ), _round( Item.Position.y, 2 ), _round( Item.Position.z, 2 );

				-- Otherwise, compare them and set them to `nil` if they're not identical
				else
					if position_x ~= _round( Item.Position.x, 2 ) then
						position_x = nil;
					end;
					if position_y ~= _round( Item.Position.y, 2 ) then
						position_y = nil;
					end;
					if position_z ~= _round( Item.Position.z, 2 ) then
						position_z = nil;
					end;
				end;

			end;

			-- If each position along each axis is the same, display that number; otherwise, display "*"
			if not self.State.pos_x_focused then
				GUI.Info.Center.X.TextBox.Text = position_x and tostring( position_x ) or "*";
			end;
			if not self.State.pos_y_focused then
				GUI.Info.Center.Y.TextBox.Text = position_y and tostring( position_y ) or "*";
			end;
			if not self.State.pos_z_focused then
				GUI.Info.Center.Z.TextBox.Text = position_z and tostring( position_z ) or "*";
			end;

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

Tools.Move.changePosition = function ( self, component, new_value )

	self:startHistoryRecord();

	-- Change the position of each item selected
	for _, Item in pairs( Selection.Items ) do
		Item.CFrame = CFrame.new(
			component == 'x' and new_value or Item.Position.x,
			component == 'y' and new_value or Item.Position.y,
			component == 'z' and new_value or Item.Position.z
		);
	end;

	self:finishHistoryRecord();

end;

-- Provide the following two functions to save space
Tools.Move.startHistoryRecord = function ( self )

	if self.State.HistoryRecord then
		self.State.HistoryRecord = nil;
	end;

	-- Create a history record
	self.State.HistoryRecord = {
		targets = _cloneTable( Selection.Items );
		initial_positions = {};
		terminal_positions = {};
		unapply = function ( self )
			Selection:clear();
			for _, Target in pairs( self.targets ) do
				if Target then
					Target.CFrame = self.initial_positions[Target];
					Target:MakeJoints();
					Selection:add( Target );
				end;
			end;
		end;
		apply = function ( self )
			Selection:clear();
			for _, Target in pairs( self.targets ) do
				if Target then
					Target.CFrame = self.terminal_positions[Target];
					Target:MakeJoints();
					Selection:add( Target );
				end;
			end;
		end;
	};
	for _, Item in pairs( self.State.HistoryRecord.targets ) do
		if Item then
			self.State.HistoryRecord.initial_positions[Item] = Item.CFrame;
		end;
	end;

end;

Tools.Move.finishHistoryRecord = function ( self )

	if not self.State.HistoryRecord then
		return;
	end;

	for _, Item in pairs( self.State.HistoryRecord.targets ) do
		if Item then
			self.State.HistoryRecord.terminal_positions[Item] = Item.CFrame;
		end;
	end;
	History:add( self.State.HistoryRecord );
	self.State.HistoryRecord = nil;

end;

Tools.Move.Listeners.Button1Down = function ()

	local self = Tools.Move;

	local Target = self.ManualTarget or Mouse.Target;
	self.ManualTarget = nil;

	if not Target or ( Target:IsA( "BasePart" ) and Target.Locked ) then
		return;
	end;

	if not Selection:find( Target ) then
		Selection:clear();
		Selection:add( Target );
	end;

	for _, Item in pairs( Selection.Items ) do
		Item.RotVelocity = Vector3.new( 0, 0, 0 );
		Item.Velocity = Vector3.new( 0, 0, 0 );
	end;

	self:startHistoryRecord();

	self.State.dragging = true;
	override_selection = true;

	self.Dragger = Instance.new( "Dragger" );
	self.Dragger:MouseDown( Target, Target.CFrame:toObjectSpace( CFrame.new( Mouse.Hit.p ) ).p, Selection.Items );
	self.Connections.DraggerConnection = Mouse.Button1Up:connect( function ()

		override_selection = true;

		-- Disable the dragger
		if self.Connections.DraggerConnection then
			self.Connections.DraggerConnection:disconnect();
			self.Connections.DraggerConnection = nil;
		end;
		if not self.Dragger then
			return;
		end;
		self.Dragger:MouseUp();
		self.State.dragging = false;
		self.Dragger:Destroy();
		self.Dragger = nil;

		self:finishHistoryRecord();

	end );

end;

Tools.Move.Listeners.Move = function ()

	local self = Tools.Move;

	if not self.Dragger then
		return;
	end;

	override_selection = true;

	self.Dragger:MouseMove( Mouse.UnitRay );

end;

Tools.Move.showGUI = function ( self )

	-- Initialize the GUI if it's not ready yet
	if not self.GUI then

		local Container = Tool:WaitForChild( "BTMoveToolGUI" ):Clone();
		Container.Parent = UI;

		-- Change the axis type option when the button is clicked
		Container.AxesOption.Global.Button.MouseButton1Down:connect( function ()
			self:changeAxes( "global" );
			Container.AxesOption.Global.SelectedIndicator.BackgroundTransparency = 0;
			Container.AxesOption.Global.Background.Image = dark_slanted_rectangle;
			Container.AxesOption.Local.SelectedIndicator.BackgroundTransparency = 1;
			Container.AxesOption.Local.Background.Image = light_slanted_rectangle;
			Container.AxesOption.Last.SelectedIndicator.BackgroundTransparency = 1;
			Container.AxesOption.Last.Background.Image = light_slanted_rectangle;
		end );

		Container.AxesOption.Local.Button.MouseButton1Down:connect( function ()
			self:changeAxes( "local" );
			Container.AxesOption.Global.SelectedIndicator.BackgroundTransparency = 1;
			Container.AxesOption.Global.Background.Image = light_slanted_rectangle;
			Container.AxesOption.Local.SelectedIndicator.BackgroundTransparency = 0;
			Container.AxesOption.Local.Background.Image = dark_slanted_rectangle;
			Container.AxesOption.Last.SelectedIndicator.BackgroundTransparency = 1;
			Container.AxesOption.Last.Background.Image = light_slanted_rectangle;
		end );

		Container.AxesOption.Last.Button.MouseButton1Down:connect( function ()
			self:changeAxes( "last" );
			Container.AxesOption.Global.SelectedIndicator.BackgroundTransparency = 1;
			Container.AxesOption.Global.Background.Image = light_slanted_rectangle;
			Container.AxesOption.Local.SelectedIndicator.BackgroundTransparency = 1;
			Container.AxesOption.Local.Background.Image = light_slanted_rectangle;
			Container.AxesOption.Last.SelectedIndicator.BackgroundTransparency = 0;
			Container.AxesOption.Last.Background.Image = dark_slanted_rectangle;
		end );

		-- Change the increment option when the value of the textbox is updated
		Container.IncrementOption.Increment.TextBox.FocusLost:connect( function ( enter_pressed )
			self.Options.increment = tonumber( Container.IncrementOption.Increment.TextBox.Text ) or self.Options.increment;
			Container.IncrementOption.Increment.TextBox.Text = tostring( self.Options.increment );
		end );

		-- Add functionality to the position inputs
		Container.Info.Center.X.TextButton.MouseButton1Down:connect( function ()
			self.State.pos_x_focused = true;
			Container.Info.Center.X.TextBox:CaptureFocus();
		end );
		Container.Info.Center.X.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( Container.Info.Center.X.TextBox.Text );
			if potential_new then
				self:changePosition( 'x', potential_new );
			end;
			self.State.pos_x_focused = false;
		end );
		Container.Info.Center.Y.TextButton.MouseButton1Down:connect( function ()
			self.State.pos_y_focused = true;
			Container.Info.Center.Y.TextBox:CaptureFocus();
		end );
		Container.Info.Center.Y.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( Container.Info.Center.Y.TextBox.Text );
			if potential_new then
				self:changePosition( 'y', potential_new );
			end;
			self.State.pos_y_focused = false;
		end );
		Container.Info.Center.Z.TextButton.MouseButton1Down:connect( function ()
			self.State.pos_z_focused = true;
			Container.Info.Center.Z.TextBox:CaptureFocus();
		end );
		Container.Info.Center.Z.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( Container.Info.Center.Z.TextBox.Text );
			if potential_new then
				self:changePosition( 'z', potential_new );
			end;
			self.State.pos_z_focused = false;
		end );

		self.GUI = Container;
	end;

	-- Reveal the GUI
	self.GUI.Visible = true;

end;

Tools.Move.hideGUI = function ( self )

	-- Hide the GUI if it exists
	if self.GUI then
		self.GUI.Visible = false;
	end;

end;

Tools.Move.showHandles = function ( self, Part )

	-- Create the handles if they don't exist yet
	if not self.Handles then

		-- Create the object
		self.Handles = RbxUtility.Create "Handles" {
			Name = "BTMovementHandles";
			Color = self.Color;
			Parent = Player.PlayerGui;
		};

		-- Add functionality to the handles

		self.Handles.MouseButton1Down:connect( function ()

			-- Prevent the platform from thinking we're selecting
			override_selection = true;
			self.State.moving = true;

			-- Clear the change stats
			self.State.distance_moved = 0;

			self:startHistoryRecord();

			-- Do a few things to the selection before manipulating it
			for _, Item in pairs( Selection.Items ) do

				-- Keep a copy of the state of each item
				self.State.PreMove[Item] = Item:Clone();

				-- Anchor each item
				Item.Anchored = true;

			end;

			-- Return stuff to normal once the mouse button is released
			self.Connections.HandleReleaseListener = Mouse.Button1Up:connect( function ()

				-- Prevent the platform from thinking we're selecting
				override_selection = true;
				self.State.moving = false;

				-- Stop this connection from firing again
				if self.Connections.HandleReleaseListener then
					self.Connections.HandleReleaseListener:disconnect();
					self.Connections.HandleReleaseListener = nil;
				end;

				self:finishHistoryRecord();

				-- Restore properties that may have been changed temporarily
				-- from the pre-movement state copies
				for Item, PreviousItemState in pairs( self.State.PreMove ) do
					Item.Anchored = PreviousItemState.Anchored;
					self.State.PreMove[Item] = nil;
					Item:MakeJoints();
					Item.Velocity = Vector3.new( 0, 0, 0 );
					Item.RotVelocity = Vector3.new( 0, 0, 0 );
				end;

			end );

		end );

		self.Handles.MouseDrag:connect( function ( face, drag_distance )

			-- Calculate which multiple of the increment to use based on the current drag distance's
			-- proximity to their nearest upper and lower multiples

			local difference = drag_distance % self.Options.increment;

			local lower_degree = drag_distance - difference;
			local upper_degree = drag_distance - difference + self.Options.increment;

			local lower_degree_proximity = math.abs( drag_distance - lower_degree );
			local upper_degree_proximity = math.abs( drag_distance - upper_degree );

			if lower_degree_proximity <= upper_degree_proximity then
				drag_distance = lower_degree;
			else
				drag_distance = upper_degree;
			end;

			local increase = drag_distance;

			self.State.distance_moved = drag_distance;

			-- Increment the position of each selected item in the direction of `face`
			for _, Item in pairs( Selection.Items ) do

				-- Remove any joints connected with `Item` so that it can freely move
				Item:BreakJoints();

				-- Update the position of `Item` depending on the type of axes that is currently set
				if face == Enum.NormalId.Top then
					if self.Options.axes == "global" then
						Item.CFrame = CFrame.new( self.State.PreMove[Item].CFrame.p ):toWorldSpace( CFrame.new( 0, increase, 0 ) ) * CFrame.Angles( self.State.PreMove[Item].CFrame:toEulerAnglesXYZ() );
					elseif self.Options.axes == "local" then
						Item.CFrame = self.State.PreMove[Item].CFrame:toWorldSpace( CFrame.new( 0, increase, 0 ) );
					elseif self.Options.axes == "last" then
						Item.CFrame = self.State.PreMove[Selection.Last].CFrame:toWorldSpace( CFrame.new( 0, increase, 0 ) ):toWorldSpace( self.State.PreMove[Item].CFrame:toObjectSpace( self.State.PreMove[Selection.Last].CFrame ):inverse() );
					end;

				elseif face == Enum.NormalId.Bottom then
					if self.Options.axes == "global" then
						Item.CFrame = CFrame.new( self.State.PreMove[Item].CFrame.p ):toWorldSpace( CFrame.new( 0, -increase, 0 ) ) * CFrame.Angles( self.State.PreMove[Item].CFrame:toEulerAnglesXYZ() );
					elseif self.Options.axes == "local" then
						Item.CFrame = self.State.PreMove[Item].CFrame:toWorldSpace( CFrame.new( 0, -increase, 0 ) );
					elseif self.Options.axes == "last" then
						Item.CFrame = self.State.PreMove[Selection.Last].CFrame:toWorldSpace( CFrame.new( 0, -increase, 0 ) ):toWorldSpace( self.State.PreMove[Item].CFrame:toObjectSpace( self.State.PreMove[Selection.Last].CFrame ):inverse() );
					end;

				elseif face == Enum.NormalId.Front then
					if self.Options.axes == "global" then
						Item.CFrame = CFrame.new( self.State.PreMove[Item].CFrame.p ):toWorldSpace( CFrame.new( 0, 0, -increase ) ) * CFrame.Angles( self.State.PreMove[Item].CFrame:toEulerAnglesXYZ() );
					elseif self.Options.axes == "local" then
						Item.CFrame = self.State.PreMove[Item].CFrame:toWorldSpace( CFrame.new( 0, 0, -increase ) );
					elseif self.Options.axes == "last" then
						Item.CFrame = self.State.PreMove[Selection.Last].CFrame:toWorldSpace( CFrame.new( 0, 0, -increase ) ):toWorldSpace( self.State.PreMove[Item].CFrame:toObjectSpace( self.State.PreMove[Selection.Last].CFrame ):inverse() );
					end;

				elseif face == Enum.NormalId.Back then
					if self.Options.axes == "global" then
						Item.CFrame = CFrame.new( self.State.PreMove[Item].CFrame.p ):toWorldSpace( CFrame.new( 0, 0, increase ) ) * CFrame.Angles( self.State.PreMove[Item].CFrame:toEulerAnglesXYZ() );
					elseif self.Options.axes == "local" then
						Item.CFrame = self.State.PreMove[Item].CFrame:toWorldSpace( CFrame.new( 0, 0, increase ) );
					elseif self.Options.axes == "last" then
						Item.CFrame = self.State.PreMove[Selection.Last].CFrame:toWorldSpace( CFrame.new( 0, 0, increase ) ):toWorldSpace( self.State.PreMove[Item].CFrame:toObjectSpace( self.State.PreMove[Selection.Last].CFrame ):inverse() );
					end;

				elseif face == Enum.NormalId.Right then
					if self.Options.axes == "global" then
						Item.CFrame = CFrame.new( self.State.PreMove[Item].CFrame.p ):toWorldSpace( CFrame.new( increase, 0, 0 ) ) * CFrame.Angles( self.State.PreMove[Item].CFrame:toEulerAnglesXYZ() );
					elseif self.Options.axes == "local" then
						Item.CFrame = self.State.PreMove[Item].CFrame:toWorldSpace( CFrame.new( increase, 0, 0 ) );
					elseif self.Options.axes == "last" then
						Item.CFrame = self.State.PreMove[Selection.Last].CFrame:toWorldSpace( CFrame.new( increase, 0, 0 ) ):toWorldSpace( self.State.PreMove[Item].CFrame:toObjectSpace( self.State.PreMove[Selection.Last].CFrame ):inverse() );
					end;

				elseif face == Enum.NormalId.Left then
					if self.Options.axes == "global" then
						Item.CFrame = CFrame.new( self.State.PreMove[Item].CFrame.p ):toWorldSpace( CFrame.new( -increase, 0, 0 ) ) * CFrame.Angles( self.State.PreMove[Item].CFrame:toEulerAnglesXYZ() );
					elseif self.Options.axes == "local" then
						Item.CFrame = self.State.PreMove[Item].CFrame:toWorldSpace( CFrame.new( -increase, 0, 0 ) );
					elseif self.Options.axes == "last" then
						Item.CFrame = self.State.PreMove[Selection.Last].CFrame:toWorldSpace( CFrame.new( -increase, 0, 0 ) ):toWorldSpace( self.State.PreMove[Item].CFrame:toObjectSpace( self.State.PreMove[Selection.Last].CFrame ):inverse() );
					end;

				end;

			end;

		end );

	end;

	-- Stop listening for the existence of the previous adornee (if any)
	if self.Connections.AdorneeExistenceListener then
		self.Connections.AdorneeExistenceListener:disconnect();
		self.Connections.AdorneeExistenceListener = nil;
	end;

	-- Attach the handles to `Part`
	self.Handles.Adornee = Part;

	-- Make sure to hide the handles if `Part` suddenly stops existing
	self.Connections.AdorneeExistenceListener = Part.AncestryChanged:connect( function ( Object, NewParent )

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

Tools.Move.hideHandles = function ( self )

	-- Hide the handles if they exist
	if self.Handles then
		self.Handles.Adornee = nil;
	end;

end;

Tools.Move.updateBoundingBox = function ( self )

	if #Selection.Items > 0 and not self.State.dragging then
		local SelectionSize, SelectionPosition = _getCollectionInfo( Selection.Items );
		self.BoundingBox.Size = SelectionSize;
		self.BoundingBox.CFrame = SelectionPosition;
		self:showHandles( self.BoundingBox );

	else
		self:hideHandles();
	end;

end;

Tools.Move.changeAxes = function ( self, new_axes )

	-- Have a quick reference to the GUI (if any)
	local AxesOptionGUI = self.GUI and self.GUI.AxesOption or nil;

	-- Disconnect any handle-related listeners that are specific to a certain axes option

	if self.Connections.HandleFocusChangeListener then
		self.Connections.HandleFocusChangeListener:disconnect();
		self.Connections.HandleFocusChangeListener = nil;
	end;

	if self.Connections.HandleSelectionChangeListener then
		self.Connections.HandleSelectionChangeListener:disconnect();
		self.Connections.HandleSelectionChangeListener = nil;
	end;

	if new_axes == "global" then

		-- Update the options
		self.Options.axes = "global";

		-- Clear out any previous adornee
		self:hideHandles();

		-- Focus the handles on the boundary box
		self:showHandles( self.BoundingBox );

		-- Update the GUI's option panel
		if self.GUI then
			AxesOptionGUI.Global.SelectedIndicator.BackgroundTransparency = 0;
			AxesOptionGUI.Global.Background.Image = dark_slanted_rectangle;
			AxesOptionGUI.Local.SelectedIndicator.BackgroundTransparency = 1;
			AxesOptionGUI.Local.Background.Image = light_slanted_rectangle;
			AxesOptionGUI.Last.SelectedIndicator.BackgroundTransparency = 1;
			AxesOptionGUI.Last.Background.Image = light_slanted_rectangle;
		end;

	end;

	if new_axes == "local" then

		-- Update the options
		self.Options.axes = "local";

		-- Always have the handles on the most recent addition to the selection
		self.Connections.HandleSelectionChangeListener = Selection.Changed:connect( function ()

			-- Clear out any previous adornee
			self:hideHandles();

			-- If there /is/ a last item in the selection, attach the handles to it
			if Selection.Last then
				self:showHandles( Selection.Last );
			end;

		end );

		-- Switch the adornee of the handles if the second mouse button is pressed
		self.Connections.HandleFocusChangeListener = Mouse.Button2Up:connect( function ()

			-- Make sure the platform doesn't think we're selecting
			override_selection = true;

			-- If the target is in the selection, make it the new adornee
			if Selection:find( Mouse.Target ) then
				Selection:focus( Mouse.Target );
				self:showHandles( Mouse.Target );
			end;

		end );

		-- Finally, attach the handles to the last item added to the selection (if any)
		if Selection.Last then
			self:showHandles( Selection.Last );
		end;

		-- Update the GUI's option panel
		if self.GUI then
			AxesOptionGUI.Global.SelectedIndicator.BackgroundTransparency = 1;
			AxesOptionGUI.Global.Background.Image = light_slanted_rectangle;
			AxesOptionGUI.Local.SelectedIndicator.BackgroundTransparency = 0;
			AxesOptionGUI.Local.Background.Image = dark_slanted_rectangle;
			AxesOptionGUI.Last.SelectedIndicator.BackgroundTransparency = 1;
			AxesOptionGUI.Last.Background.Image = light_slanted_rectangle;
		end;

	end;

	if new_axes == "last" then

		-- Update the options
		self.Options.axes = "last";

		-- Always have the handles on the most recent addition to the selection
		self.Connections.HandleSelectionChangeListener = Selection.Changed:connect( function ()

			-- Clear out any previous adornee
			self:hideHandles();

			-- If there /is/ a last item in the selection, attach the handles to it
			if Selection.Last then
				self:showHandles( Selection.Last );
			end;

		end );

		-- Switch the adornee of the handles if the second mouse button is pressed
		GUI.Connections.HandleFocusChangeListener = Mouse.Button2Up:connect( function ()

			-- Make sure the platform doesn't think we're selecting
			override_selection = true;

			-- If the target is in the selection, make it the new adornee
			if Selection:find( Mouse.Target ) then
				Selection:focus( Mouse.Target );
				self:showHandles( Mouse.Target );
			end;

		end );

		-- Finally, attach the handles to the last item added to the selection (if any)
		if Selection.Last then
			self:showHandles( Selection.Last );
		end;

		-- Update the GUI's option panel
		if self.GUI then
			AxesOptionGUI.Global.SelectedIndicator.BackgroundTransparency = 1;
			AxesOptionGUI.Global.Background.Image = light_slanted_rectangle;
			AxesOptionGUI.Local.SelectedIndicator.BackgroundTransparency = 1;
			AxesOptionGUI.Local.Background.Image = light_slanted_rectangle;
			AxesOptionGUI.Last.SelectedIndicator.BackgroundTransparency = 0;
			AxesOptionGUI.Last.Background.Image = dark_slanted_rectangle;
		end;

	end;

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
	["length_resized"] = 0;
};

Tools.Resize.Listeners = {};

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
			Selection:focus( Mouse.Target );
		end;

	end ) );

	-- Finally, attach the handles to the last item added to the selection (if any)
	if Selection.Last then
		Tools.Resize:showHandles( Selection.Last );
	end;

	-- Update the GUI regularly
	coroutine.wrap( function ()
		local updater_on = true;

		-- Provide a function to stop the loop
		Tools.Resize.Temporary.Updater = function ()
			updater_on = false;
		end;

		while wait( 0.1 ) and updater_on do

			-- Make sure the tool's equipped
			if CurrentTool == Tools.Resize then

				-- Update the GUI if it's visible
				if Tools.Resize.Temporary.GUI and Tools.Resize.Temporary.GUI.Visible then
					Tools.Resize:updateGUI();
				end;

			end;

		end;

	end )();

end;

Tools.Resize.Listeners.Unequipped = function ()

	-- Stop the update loop
	Tools.Resize.Temporary.Updater();
	Tools.Resize.Temporary.Updater = nil;

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

	-- Initialize the GUI if it's not ready yet
	if not self.Temporary.GUI then

		local Container = Tool:WaitForChild( "BTResizeToolGUI" ):Clone();
		Container.Parent = UI;

		-- Change the axis type option when the button is clicked
		Container.DirectionsOption.Normal.Button.MouseButton1Down:connect( function ()
			self.Options.directions = "normal";
			Container.DirectionsOption.Normal.SelectedIndicator.BackgroundTransparency = 0;
			Container.DirectionsOption.Normal.Background.Image = dark_slanted_rectangle;
			Container.DirectionsOption.Both.SelectedIndicator.BackgroundTransparency = 1;
			Container.DirectionsOption.Both.Background.Image = light_slanted_rectangle;
		end );

		Container.DirectionsOption.Both.Button.MouseButton1Down:connect( function ()
			self.Options.directions = "both";
			Container.DirectionsOption.Normal.SelectedIndicator.BackgroundTransparency = 1;
			Container.DirectionsOption.Normal.Background.Image = light_slanted_rectangle;
			Container.DirectionsOption.Both.SelectedIndicator.BackgroundTransparency = 0;
			Container.DirectionsOption.Both.Background.Image = dark_slanted_rectangle;
		end );

		-- Change the increment option when the value of the textbox is updated
		Container.IncrementOption.Increment.TextBox.FocusLost:connect( function ( enter_pressed )
			self.Options.increment = tonumber( Container.IncrementOption.Increment.TextBox.Text ) or self.Options.increment;
			Container.IncrementOption.Increment.TextBox.Text = tostring( self.Options.increment );
		end );

		-- Add functionality to the size inputs
		Container.Info.SizeInfo.X.TextButton.MouseButton1Down:connect( function ()
			self.State.size_x_focused = true;
			Container.Info.SizeInfo.X.TextBox:CaptureFocus();
		end );
		Container.Info.SizeInfo.X.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( Container.Info.SizeInfo.X.TextBox.Text );
			if potential_new then
				self:changeSize( 'x', potential_new );
			end;
			self.State.size_x_focused = false;
		end );
		Container.Info.SizeInfo.Y.TextButton.MouseButton1Down:connect( function ()
			self.State.size_y_focused = true;
			Container.Info.SizeInfo.Y.TextBox:CaptureFocus();
		end );
		Container.Info.SizeInfo.Y.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( Container.Info.SizeInfo.Y.TextBox.Text );
			if potential_new then
				self:changeSize( 'y', potential_new );
			end;
			self.State.size_y_focused = false;
		end );
		Container.Info.SizeInfo.Z.TextButton.MouseButton1Down:connect( function ()
			self.State.size_z_focused = true;
			Container.Info.SizeInfo.Z.TextBox:CaptureFocus();
		end );
		Container.Info.SizeInfo.Z.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( Container.Info.SizeInfo.Z.TextBox.Text );
			if potential_new then
				self:changeSize( 'z', potential_new );
			end;
			self.State.size_z_focused = false;
		end );

		self.Temporary.GUI = Container;
	end;

	-- Reveal the GUI
	self.Temporary.GUI.Visible = true;

end;

Tools.Resize.changeSize = function ( self, component, new_value )

	-- Add a new record to the history system
	local old_parts, new_parts = _cloneTable( Selection.Items ), _cloneParts( Selection.Items );
	local focus_search = _findTableOccurrences( old_parts, Selection.Last );
	_replaceParts( old_parts, new_parts );
	for _, Item in pairs( new_parts ) do
		Selection:add( Item );
	end;
	if #focus_search > 0 then
		Selection:focus( new_parts[focus_search[1]] );
	end;
	History:add( old_parts, new_parts );

	-- Change the size of each item selected
	for _, Item in pairs( Selection.Items ) do
		local OldCFrame = Item.CFrame;
		-- Make the item be able to be freely resized
		if ( pcall( function () local test = Item.FormFactor; end ) ) then
			Item.FormFactor = Enum.FormFactor.Custom;
		end;
		Item.Size = Vector3.new(
			component == 'x' and new_value or Item.Size.x,
			component == 'y' and new_value or Item.Size.y,
			component == 'z' and new_value or Item.Size.z
		);
		Item.CFrame = OldCFrame;
	end;

end;

Tools.Resize.updateGUI = function ( self )

	-- Make sure the GUI exists
	if not self.Temporary.GUI then
		return;
	end;

	local GUI = self.Temporary.GUI;

	if #Selection.Items > 0 then

		-- Look for identical numbers in each axis
		local size_x, size_y, size_z =  nil, nil, nil;
		for item_index, Item in pairs( Selection.Items ) do

			-- Set the first values for the first item
			if item_index == 1 then
				size_x, size_y, size_z = _round( Item.Size.x, 2 ), _round( Item.Size.y, 2 ), _round( Item.Size.z, 2 );

			-- Otherwise, compare them and set them to `nil` if they're not identical
			else
				if size_x ~= _round( Item.Size.x, 2 ) then
					size_x = nil;
				end;
				if size_y ~= _round( Item.Size.y, 2 ) then
					size_y = nil;
				end;
				if size_z ~= _round( Item.Size.z, 2 ) then
					size_z = nil;
				end;
			end;

		end;

		-- Update the size info on the GUI
		if not self.State.size_x_focused then
			GUI.Info.SizeInfo.X.TextBox.Text = size_x and tostring( size_x ) or "*";
		end;
		if not self.State.size_y_focused then
			GUI.Info.SizeInfo.Y.TextBox.Text = size_y and tostring( size_y ) or "*";
		end;
		if not self.State.size_z_focused then
			GUI.Info.SizeInfo.Z.TextBox.Text = size_z and tostring( size_z ) or "*";
		end;

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
		self.Temporary.GUI.Visible = false;
	end;

end;

Tools.Resize.showHandles = function ( self, Part )

	-- Create the handles if they don't exist yet
	if not self.Temporary.Handles then

		-- Create the object
		self.Temporary.Handles = RbxUtility.Create "Handles" {
			Name = "BTResizeHandles";
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

			-- Add a new record to the history system
			local old_parts, new_parts = _cloneTable( Selection.Items ), _cloneParts( Selection.Items );
			local focus_search = _findTableOccurrences( old_parts, Selection.Last );
			_replaceParts( old_parts, new_parts );
			for _, Item in pairs( new_parts ) do
				Selection:add( Item );
			end;
			if #focus_search > 0 then
				Selection:focus( new_parts[focus_search[1]] );
			end;
			History:add( old_parts, new_parts );

			-- Do a few things to the selection before manipulating it
			for _, Item in pairs( Selection.Items ) do

				-- Keep a copy of the state of each item
				self.State.PreResize[Item] = Item:Clone();

				-- Make the item be able to be freely resized
				if ( pcall( function () local test = Item.FormFactor; end ) ) then
					Item.FormFactor = Enum.FormFactor.Custom;
				end;

				-- Anchor each item
				Item.Anchored = true;

			end;

			-- Return stuff to normal once the mouse button is released
			self.Temporary.Connections.HandleReleaseListener = Mouse.Button1Up:connect( function ()

				-- Prevent the platform from thinking we're selecting
				override_selection = true;
				self.State.resizing = false;

				-- Stop this connection from firing again
				if self.Temporary.Connections.HandleReleaseListener then
					self.Temporary.Connections.HandleReleaseListener:disconnect();
					self.Temporary.Connections.HandleReleaseListener = nil;
				end;

				-- Restore properties that may have been changed temporarily
				-- from the pre-resize state copies
				for Item, PreviousItemState in pairs( self.State.PreResize ) do
					Item.Anchored = PreviousItemState.Anchored;
					self.State.PreResize[Item] = nil;
					Item:MakeJoints();
				end;

			end );

		end );

		self.Temporary.Handles.MouseDrag:connect( function ( face, drag_distance )

			-- Calculate which multiple of the increment to use based on the current drag distance's
			-- proximity to their nearest upper and lower multiples

			local difference = drag_distance % self.Options.increment;

			local lower_degree = drag_distance - difference;
			local upper_degree = drag_distance - difference + self.Options.increment;

			local lower_degree_proximity = math.abs( drag_distance - lower_degree );
			local upper_degree_proximity = math.abs( drag_distance - upper_degree );

			if lower_degree_proximity <= upper_degree_proximity then
				drag_distance = lower_degree;
			else
				drag_distance = upper_degree;
			end;

			local increase = drag_distance;

			-- Log the distance that the handle was dragged
			self.State.previous_distance = drag_distance;

			-- Note the length by which the selection will be enlarged
			if self.Options.directions == "both" then
				increase = drag_distance * 2;
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

					-- Calculate the appropriate increment to the size based on the shape of `Item`
					local SizeIncrease;
					if ( pcall( function () local test = Item.Shape; end ) ) and ( Item.Shape == Enum.PartType.Ball or Item.Shape == Enum.PartType.Cylinder ) then
						SizeIncrease = Vector3.new( increase, increase, increase );
					elseif not ( pcall( function () local test = Item.Shape; end ) ) or ( Item.Shape and Item.Shape == Enum.PartType.Block ) then
						SizeIncrease = Vector3.new( 0, increase, 0 );
					end;

					Item.Size = self.State.PreResize[Item].Size + SizeIncrease;
					if Item.Size == self.State.PreResize[Item].Size + SizeIncrease then
						Item.CFrame = ( self.Options.directions == "normal" and self.State.PreResize[Item].CFrame:toWorldSpace( CFrame.new( 0, increase / 2, 0 ) ) )
									  or ( self.Options.directions == "both" and self.State.PreResize[Item].CFrame );
					-- If the resizing was not possible, revert `Item`'s state
					else
						Item.Size = PreviousItemState.Size;
						Item.CFrame = PreviousItemState.CFrame;
					end;

				elseif face == Enum.NormalId.Bottom then

					-- Calculate the appropriate increment to the size based on the shape of `Item`
					local SizeIncrease;
					if ( pcall( function () local test = Item.Shape; end ) ) and ( Item.Shape == Enum.PartType.Ball or Item.Shape == Enum.PartType.Cylinder ) then
						SizeIncrease = Vector3.new( increase, increase, increase );
					elseif not ( pcall( function () local test = Item.Shape; end ) ) or ( Item.Shape and Item.Shape == Enum.PartType.Block ) then
						SizeIncrease = Vector3.new( 0, increase, 0 );
					end;

					Item.Size = self.State.PreResize[Item].Size + SizeIncrease;
					if Item.Size == self.State.PreResize[Item].Size + SizeIncrease then
						Item.CFrame = ( self.Options.directions == "normal" and self.State.PreResize[Item].CFrame:toWorldSpace( CFrame.new( 0, -increase / 2, 0 ) ) )
									  or ( self.Options.directions == "both" and self.State.PreResize[Item].CFrame );
					-- If the resizing was not possible, revert `Item`'s state
					else
						Item.Size = PreviousItemState.Size;
						Item.CFrame = PreviousItemState.CFrame;
					end;

				elseif face == Enum.NormalId.Front then

					-- Calculate the appropriate increment to the size based on the shape of `Item`
					local SizeIncrease;
					if ( pcall( function () local test = Item.Shape; end ) ) and ( Item.Shape == Enum.PartType.Ball or Item.Shape == Enum.PartType.Cylinder ) then
						SizeIncrease = Vector3.new( increase, increase, increase );
					elseif not ( pcall( function () local test = Item.Shape; end ) ) or ( Item.Shape and Item.Shape == Enum.PartType.Block ) then
						SizeIncrease = Vector3.new( 0, 0, increase );
					end;

					Item.Size = self.State.PreResize[Item].Size + SizeIncrease;
					if Item.Size == self.State.PreResize[Item].Size + SizeIncrease then
						Item.CFrame = ( self.Options.directions == "normal" and self.State.PreResize[Item].CFrame:toWorldSpace( CFrame.new( 0, 0, -increase / 2 ) ) )
									  or ( self.Options.directions == "both" and self.State.PreResize[Item].CFrame );
					-- If the resizing was not possible, revert `Item`'s state
					else
						Item.Size = PreviousItemState.Size;
						Item.CFrame = PreviousItemState.CFrame;
					end;

				elseif face == Enum.NormalId.Back then

					-- Calculate the appropriate increment to the size based on the shape of `Item`
					local SizeIncrease;
					if ( pcall( function () local test = Item.Shape; end ) ) and ( Item.Shape == Enum.PartType.Ball or Item.Shape == Enum.PartType.Cylinder ) then
						SizeIncrease = Vector3.new( increase, increase, increase );
					elseif not ( pcall( function () local test = Item.Shape; end ) ) or ( Item.Shape and Item.Shape == Enum.PartType.Block ) then
						SizeIncrease = Vector3.new( 0, 0, increase );
					end;

					Item.Size = self.State.PreResize[Item].Size + SizeIncrease;
					if Item.Size == self.State.PreResize[Item].Size + SizeIncrease then
						Item.CFrame = ( self.Options.directions == "normal" and self.State.PreResize[Item].CFrame:toWorldSpace( CFrame.new( 0, 0, increase / 2 ) ) )
									  or ( self.Options.directions == "both" and self.State.PreResize[Item].CFrame );
					-- If the resizing was not possible, revert `Item`'s state
					else
						Item.Size = PreviousItemState.Size;
						Item.CFrame = PreviousItemState.CFrame;
					end;

				elseif face == Enum.NormalId.Left then

					-- Calculate the appropriate increment to the size based on the shape of `Item`
					local SizeIncrease;
					if ( pcall( function () local test = Item.Shape; end ) ) and ( Item.Shape == Enum.PartType.Ball or Item.Shape == Enum.PartType.Cylinder ) then
						SizeIncrease = Vector3.new( increase, increase, increase );
					elseif not ( pcall( function () local test = Item.Shape; end ) ) or ( Item.Shape and Item.Shape == Enum.PartType.Block ) then
						SizeIncrease = Vector3.new( increase, 0, 0 );
					end;

					Item.Size = self.State.PreResize[Item].Size + SizeIncrease;
					if Item.Size == self.State.PreResize[Item].Size + SizeIncrease then
						Item.CFrame = ( self.Options.directions == "normal" and self.State.PreResize[Item].CFrame:toWorldSpace( CFrame.new( -increase / 2, 0, 0 ) ) )
									  or ( self.Options.directions == "both" and self.State.PreResize[Item].CFrame );
					-- If the resizing was not possible, revert `Item`'s state
					else
						Item.Size = PreviousItemState.Size;
						Item.CFrame = PreviousItemState.CFrame;
					end;

				elseif face == Enum.NormalId.Right then

					-- Calculate the appropriate increment to the size based on the shape of `Item`
					local SizeIncrease;
					if ( pcall( function () local test = Item.Shape; end ) ) and ( Item.Shape == Enum.PartType.Ball or Item.Shape == Enum.PartType.Cylinder ) then
						SizeIncrease = Vector3.new( increase, increase, increase );
					elseif not ( pcall( function () local test = Item.Shape; end ) ) or ( Item.Shape and Item.Shape == Enum.PartType.Block ) then
						SizeIncrease = Vector3.new( increase, 0, 0 );
					end;

					Item.Size = self.State.PreResize[Item].Size + SizeIncrease;
					if Item.Size == self.State.PreResize[Item].Size + SizeIncrease then
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
-- Rotate tool
------------------------------------------

-- Create the tool
Tools.Rotate = {};

-- Create structures to hold data that the tool needs
Tools.Rotate.Temporary = {
	["Connections"] = {};
};

Tools.Rotate.Options = {
	["increment"] = 15;
	["pivot"] = "center"
};

Tools.Rotate.State = {
	["PreRotation"] = {};
	["rotating"] = false;
	["previous_distance"] = 0;
	["degrees_rotated"] = 0;
	["rotation_size"] = 0;
};

Tools.Rotate.Listeners = {};

-- Define the color of the tool
Tools.Rotate.Color = BrickColor.new( "Bright green" );

-- Start adding functionality to the tool
Tools.Rotate.Listeners.Equipped = function ()

	-- Change the color of selection boxes temporarily
	Tools.Rotate.Temporary.PreviousSelectionBoxColor = SelectionBoxColor;
	SelectionBoxColor = Tools.Rotate.Color;
	updateSelectionBoxColor();

	-- Reveal the GUI
	Tools.Rotate:showGUI();

	-- Create the boundingbox if it doesn't already exist
	if not Tools.Rotate.Temporary.BoundingBox then
		Tools.Rotate.Temporary.BoundingBox = RbxUtility.Create "Part" {
			Name = "BTBoundingBox";
			CanCollide = false;
			Transparency = 1;
			Anchored = true;
		};
	end;
	Mouse.TargetFilter = Tools.Rotate.Temporary.BoundingBox;

	-- Update the pivot option
	Tools.Rotate:changePivot( Tools.Rotate.Options.pivot );

	-- Oh, and update the boundingbox and the GUI regularly
	coroutine.wrap( function ()
		local updater_on = true;

		-- Provide a function to stop the loop
		Tools.Rotate.Temporary.Updater = function ()
			updater_on = false;
		end;

		while wait( 0.1 ) and updater_on do

			-- Make sure the tool's equipped
			if CurrentTool == Tools.Rotate then

				-- Update the GUI if it's visible
				if Tools.Rotate.Temporary.GUI and Tools.Rotate.Temporary.GUI.Visible then
					Tools.Rotate:updateGUI();
				end;

				-- Update the boundingbox if it's visible
				if Tools.Rotate.Options.pivot == "center" then
					Tools.Rotate:updateBoundingBox();
				end;

			end;

		end;

	end )();

	-- Also enable the ability to select an edge as a pivot
	SelectEdge:start( function ( EdgeMarker )
		Tools.Rotate:changePivot( "last" );
		Tools.Rotate.Options.PivotPoint = EdgeMarker.CFrame;
		Tools.Rotate:showHandles( EdgeMarker );
	end );

end;

Tools.Rotate.Listeners.Unequipped = function ()

	-- Stop the update loop
	Tools.Rotate.Temporary.Updater();
	Tools.Rotate.Temporary.Updater = nil;

	-- Disable the ability to select edges
	SelectEdge:stop();
	if Tools.Rotate.Options.PivotPoint then
		Tools.Rotate.Options.PivotPoint = nil;
	end;

	-- Hide the GUI
	Tools.Rotate:hideGUI();

	-- Hide the handles
	Tools.Rotate:hideHandles();

	-- Clear out any temporary connections
	for connection_index, Connection in pairs( Tools.Rotate.Temporary.Connections ) do
		Connection:disconnect();
		Tools.Rotate.Temporary.Connections[connection_index] = nil;
	end;

	-- Restore the original color of the selection boxes
	SelectionBoxColor = Tools.Rotate.Temporary.PreviousSelectionBoxColor;
	updateSelectionBoxColor();

end;

Tools.Rotate.Listeners.Button1Down = function ()

	local self = Tools.Rotate;

	if not self.State.rotating and self.Options.PivotPoint then
		self.Options.PivotPoint = nil;
	end;

end;

Tools.Rotate.showGUI = function ( self )

	-- Initialize the GUI if it's not ready yet
	if not self.Temporary.GUI then

		local Container = Tool:WaitForChild( "BTRotateToolGUI" ):Clone();
		Container.Parent = UI;

		-- Change the pivot type option when the button is clicked
		Container.PivotOption.Center.Button.MouseButton1Down:connect( function ()
			self:changePivot( "center" );
		end );

		Container.PivotOption.Local.Button.MouseButton1Down:connect( function ()
			self:changePivot( "local" );
		end );

		Container.PivotOption.Last.Button.MouseButton1Down:connect( function ()
			self:changePivot( "last" );
		end );

		-- Change the increment option when the value of the textbox is updated
		Container.IncrementOption.Increment.TextBox.FocusLost:connect( function ( enter_pressed )
			self.Options.increment = tonumber( Container.IncrementOption.Increment.TextBox.Text ) or self.Options.increment;
			Container.IncrementOption.Increment.TextBox.Text = tostring( self.Options.increment );
		end );

		-- Add functionality to the rotation inputs
		Container.Info.RotationInfo.X.TextButton.MouseButton1Down:connect( function ()
			self.State.rot_x_focused = true;
			Container.Info.RotationInfo.X.TextBox:CaptureFocus();
		end );
		Container.Info.RotationInfo.X.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( Container.Info.RotationInfo.X.TextBox.Text );
			if potential_new then
				self:changeRotation( 'x', math.rad( potential_new ) );
			end;
			self.State.rot_x_focused = false;
		end );
		Container.Info.RotationInfo.Y.TextButton.MouseButton1Down:connect( function ()
			self.State.rot_y_focused = true;
			Container.Info.RotationInfo.Y.TextBox:CaptureFocus();
		end );
		Container.Info.RotationInfo.Y.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( Container.Info.RotationInfo.Y.TextBox.Text );
			if potential_new then
				self:changeRotation( 'y', math.rad( potential_new ) );
			end;
			self.State.rot_y_focused = false;
		end );
		Container.Info.RotationInfo.Z.TextButton.MouseButton1Down:connect( function ()
			self.State.rot_z_focused = true;
			Container.Info.RotationInfo.Z.TextBox:CaptureFocus();
		end );
		Container.Info.RotationInfo.Z.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( Container.Info.RotationInfo.Z.TextBox.Text );
			if potential_new then
				self:changeRotation( 'z', math.rad( potential_new ) );
			end;
			self.State.rot_z_focused = false;
		end );

		self.Temporary.GUI = Container;
	end;

	-- Reveal the GUI
	self.Temporary.GUI.Visible = true;

end;

Tools.Rotate.changeRotation = function ( self, component, new_value )

	-- Add a new record to the history system
	local old_parts, new_parts = _cloneTable( Selection.Items ), _cloneParts( Selection.Items );
	local focus_search = _findTableOccurrences( old_parts, Selection.Last );
	_replaceParts( old_parts, new_parts );
	for _, Item in pairs( new_parts ) do
		Selection:add( Item );
	end;
	if #focus_search > 0 then
		Selection:focus( new_parts[focus_search[1]] );
	end;
	History:add( old_parts, new_parts );

	-- Change the rotation of each item selected
	for _, Item in pairs( Selection.Items ) do
		local old_x_rot, old_y_rot, old_z_rot = Item.CFrame:toEulerAnglesXYZ();
		Item.CFrame = CFrame.new( Item.Position ) * CFrame.Angles(
			component == 'x' and new_value or old_x_rot,
			component == 'y' and new_value or old_y_rot,
			component == 'z' and new_value or old_z_rot
		);
	end;

end;

Tools.Rotate.updateGUI = function ( self )

	-- Make sure the GUI exists
	if not self.Temporary.GUI then
		return;
	end;

	local GUI = self.Temporary.GUI;

	if #Selection.Items > 0 then

		-- Look for identical numbers in each axis
		local rot_x, rot_y, rot_z = nil, nil, nil;
		for item_index, Item in pairs( Selection.Items ) do

			local item_rot_x, item_rot_y, item_rot_z = Item.CFrame:toEulerAnglesXYZ();

			-- Set the first values for the first item
			if item_index == 1 then
				rot_x, rot_y, rot_z = _round( math.deg( item_rot_x ), 2 ), _round( math.deg( item_rot_y ), 2 ), _round( math.deg( item_rot_z ), 2 );

			-- Otherwise, compare them and set them to `nil` if they're not identical
			else
				if rot_x ~= _round( math.deg( item_rot_x ), 2 ) then
					rot_x = nil;
				end;
				if rot_y ~= _round( math.deg( item_rot_y ), 2 ) then
					rot_y = nil;
				end;
				if rot_z ~= _round( math.deg( item_rot_z ), 2 ) then
					rot_z = nil;
				end;
			end;

		end;

		-- Update the size info on the GUI
		if not self.State.rot_x_focused then
			GUI.Info.RotationInfo.X.TextBox.Text = rot_x and tostring( rot_x ) or "*";
		end;
		if not self.State.rot_y_focused then
			GUI.Info.RotationInfo.Y.TextBox.Text = rot_y and tostring( rot_y ) or "*";
		end;
		if not self.State.rot_z_focused then
			GUI.Info.RotationInfo.Z.TextBox.Text = rot_z and tostring( rot_z ) or "*";
		end;

		GUI.Info.Visible = true;
	else
		GUI.Info.Visible = false;
	end;

	if self.State.degrees_rotated then
		GUI.Changes.Text.Text = "rotated " .. tostring( self.State.degrees_rotated ) .. " degrees";
		GUI.Changes.Position = GUI.Info.Visible and UDim2.new( 0, 5, 0, 165 ) or UDim2.new( 0, 5, 0, 100 );
		GUI.Changes.Visible = true;
	else
		GUI.Changes.Text.Text = "";
		GUI.Changes.Visible = false;
	end;

end;

Tools.Rotate.hideGUI = function ( self )

	-- Hide the GUI if it exists
	if self.Temporary.GUI then
		self.Temporary.GUI.Visible = false;
	end;

end;

Tools.Rotate.updateBoundingBox = function ( self )

	if #Selection.Items > 0 then
		local SelectionSize, SelectionPosition = _getCollectionInfo( Selection.Items );
		self.Temporary.BoundingBox.Size = SelectionSize;
		self.Temporary.BoundingBox.CFrame = SelectionPosition;
		self:showHandles( self.Temporary.BoundingBox );

	else
		self:hideHandles();
	end;

end;

Tools.Rotate.changePivot = function ( self, new_pivot )

	-- Have a quick reference to the GUI (if any)
	local PivotOptionGUI = self.Temporary.GUI and self.Temporary.GUI.PivotOption or nil;

	-- Disconnect any handle-related listeners that are specific to a certain pivot option
	if self.Temporary.Connections.HandleFocusChangeListener then
		self.Temporary.Connections.HandleFocusChangeListener:disconnect();
		self.Temporary.Connections.HandleFocusChangeListener = nil;
	end;

	if self.Temporary.Connections.HandleSelectionChangeListener then
		self.Temporary.Connections.HandleSelectionChangeListener:disconnect();
		self.Temporary.Connections.HandleSelectionChangeListener = nil;
	end;

	-- Remove any temporary edge selection
	if self.Options.PivotPoint then
		self.Options.PivotPoint = nil;
	end;

	if new_pivot == "center" then

		-- Update the options
		self.Options.pivot = "center";

		-- Focus the handles on the boundingbox
		self:showHandles( self.Temporary.BoundingBox );

		-- Update the GUI's option panel
		if self.Temporary.GUI then
			PivotOptionGUI.Center.SelectedIndicator.BackgroundTransparency = 0;
			PivotOptionGUI.Center.Background.Image = dark_slanted_rectangle;
			PivotOptionGUI.Local.SelectedIndicator.BackgroundTransparency = 1;
			PivotOptionGUI.Local.Background.Image = light_slanted_rectangle;
			PivotOptionGUI.Last.SelectedIndicator.BackgroundTransparency = 1;
			PivotOptionGUI.Last.Background.Image = light_slanted_rectangle;
		end;

	end;

	if new_pivot == "local" then

		-- Update the options
		self.Options.pivot = "local";

		-- Always have the handles on the most recent addition to the selection
		self.Temporary.Connections.HandleSelectionChangeListener = Selection.Changed:connect( function ()

			-- Clear out any previous adornee
			self:hideHandles();

			-- If there /is/ a last item in the selection, attach the handles to it
			if Selection.Last then
				self:showHandles( Selection.Last );
			end;

		end );

		-- Switch the adornee of the handles if the second mouse button is pressed
		self.Temporary.Connections.HandleFocusChangeListener = Mouse.Button2Up:connect( function ()

			-- Make sure the platform doesn't think we're selecting
			override_selection = true;

			-- If the target is in the selection, make it the new adornee
			if Selection:find( Mouse.Target ) then
				Selection:focus( Mouse.Target );
				self:showHandles( Mouse.Target );
			end;

		end );

		-- Finally, attach the handles to the last item added to the selection (if any)
		if Selection.Last then
			self:showHandles( Selection.Last );
		end;

		-- Update the GUI's option panel
		if self.Temporary.GUI then
			PivotOptionGUI.Center.SelectedIndicator.BackgroundTransparency = 1;
			PivotOptionGUI.Center.Background.Image = light_slanted_rectangle;
			PivotOptionGUI.Local.SelectedIndicator.BackgroundTransparency = 0;
			PivotOptionGUI.Local.Background.Image = dark_slanted_rectangle;
			PivotOptionGUI.Last.SelectedIndicator.BackgroundTransparency = 1;
			PivotOptionGUI.Last.Background.Image = light_slanted_rectangle;
		end;

	end;

	if new_pivot == "last" then

		-- Update the options
		self.Options.pivot = "last";

		-- Always have the handles on the most recent addition to the selection
		self.Temporary.Connections.HandleSelectionChangeListener = Selection.Changed:connect( function ()

			-- Clear out any previous adornee
			if not self.Options.PivotPoint then
				self:hideHandles();
			end;

			-- If there /is/ a last item in the selection, attach the handles to it
			if Selection.Last and not self.Options.PivotPoint then
				self:showHandles( Selection.Last );
			end;

		end );

		-- Switch the adornee of the handles if the second mouse button is pressed
		self.Temporary.Connections.HandleFocusChangeListener = Mouse.Button2Up:connect( function ()

			-- Make sure the platform doesn't think we're selecting
			override_selection = true;

			-- If the target is in the selection, make it the new adornee
			if Selection:find( Mouse.Target ) then
				Selection:focus( Mouse.Target );
				self:showHandles( Mouse.Target );
			end;

		end );

		-- Finally, attach the handles to the last item added to the selection (if any)
		if Selection.Last then
			self:showHandles( Selection.Last );
		end;

		-- Update the GUI's option panel
		if self.Temporary.GUI then
			PivotOptionGUI.Center.SelectedIndicator.BackgroundTransparency = 1;
			PivotOptionGUI.Center.Background.Image = light_slanted_rectangle;
			PivotOptionGUI.Local.SelectedIndicator.BackgroundTransparency = 1;
			PivotOptionGUI.Local.Background.Image = light_slanted_rectangle;
			PivotOptionGUI.Last.SelectedIndicator.BackgroundTransparency = 0;
			PivotOptionGUI.Last.Background.Image = dark_slanted_rectangle;
		end;

	end;

end;


Tools.Rotate.showHandles = function ( self, Part )

	-- Create the handles if they don't exist yet
	if not self.Temporary.Handles then

		-- Create the object
		self.Temporary.Handles = RbxUtility.Create "ArcHandles" {
			Name = "BTRotationHandles";
			Color = self.Color;
			Parent = Player.PlayerGui;
		};

		-- Add functionality to the handles

		self.Temporary.Handles.MouseButton1Down:connect( function ()

			-- Prevent the platform from thinking we're selecting
			override_selection = true;
			self.State.rotating = true;

			-- Clear the change stats
			self.State.degrees_rotated = 0;
			self.State.rotation_size = 0;

			-- Add a new record to the history system
			local old_parts, new_parts = _cloneTable( Selection.Items ), _cloneParts( Selection.Items );
			local focus_search = _findTableOccurrences( old_parts, Selection.Last );
			_replaceParts( old_parts, new_parts );
			for _, Item in pairs( new_parts ) do
				Selection:add( Item );
			end;
			if #focus_search > 0 then
				Selection:focus( new_parts[focus_search[1]] );
			end;
			History:add( old_parts, new_parts );

			-- Do a few things to the selection before manipulating it
			for _, Item in pairs( Selection.Items ) do

				-- Keep a copy of the state of each item
				self.State.PreRotation[Item] = Item:Clone();

				-- Anchor each item
				Item.Anchored = true;

			end;

			-- Also keep the position of the original selection
			local PreRotationSize, PreRotationPosition = _getCollectionInfo( self.State.PreRotation );
			self.State.PreRotationPosition = PreRotationPosition;

			-- Return stuff to normal once the mouse button is released
			self.Temporary.Connections.HandleReleaseListener = Mouse.Button1Up:connect( function ()

				-- Prevent the platform from thinking we're selecting
				override_selection = true;
				self.State.rotating = false;

				-- Stop this connection from firing again
				if self.Temporary.Connections.HandleReleaseListener then
					self.Temporary.Connections.HandleReleaseListener:disconnect();
					self.Temporary.Connections.HandleReleaseListener = nil;
				end;

				-- Restore properties that may have been changed temporarily
				-- from the pre-rotation state copies
				for Item, PreviousItemState in pairs( self.State.PreRotation ) do
					Item.Anchored = PreviousItemState.Anchored;
					self.State.PreRotation[Item] = nil;
					Item:MakeJoints();
				end;

			end );

		end );

		self.Temporary.Handles.MouseDrag:connect( function ( axis, drag_distance )

			-- Round down and convert the drag distance to degrees to make it easier to work with
			local drag_distance = math.floor( math.deg( drag_distance ) );

			-- Calculate which multiple of the increment to use based on the current angle's
			-- proximity to their nearest upper and lower multiples

			local difference = drag_distance % self.Options.increment;

			local lower_degree = drag_distance - difference;
			local upper_degree = drag_distance - difference + self.Options.increment;

			local lower_degree_proximity = math.abs( drag_distance - lower_degree );
			local upper_degree_proximity = math.abs( drag_distance - upper_degree );

			if lower_degree_proximity <= upper_degree_proximity then
				drag_distance = lower_degree;
			else
				drag_distance = upper_degree;
			end;

			local increase = self.Options.increment * math.floor( drag_distance / self.Options.increment );

			self.State.degrees_rotated = drag_distance;

			-- Go through the selection and make changes to it
			for _, Item in pairs( Selection.Items ) do

				-- Keep a copy of `Item` in case we need to revert anything
				local PreviousItemState = Item:Clone();

				-- Break any of `Item`'s joints so it can move freely
				Item:BreakJoints();

				-- Rotate `Item` according to the options and the handle that was used
				if axis == Enum.Axis.Y then
					if self.Options.pivot == "center" then
						Item.CFrame = self.State.PreRotationPosition:toWorldSpace( CFrame.new( 0, 0, 0 ) * CFrame.Angles( 0, math.rad( increase ), 0 ) ):toWorldSpace( self.State.PreRotation[Item].CFrame:toObjectSpace( self.State.PreRotationPosition ):inverse() );
					elseif self.Options.pivot == "local" then
						Item.CFrame = self.State.PreRotation[Item].CFrame:toWorldSpace( CFrame.new( 0, 0, 0 ) * CFrame.Angles( 0, math.rad( increase ), 0 ) );
					elseif self.Options.pivot == "last" then
						Item.CFrame = ( self.Options.PivotPoint or self.State.PreRotation[Selection.Last].CFrame ):toWorldSpace( CFrame.new( 0, 0, 0 ) * CFrame.Angles( 0, math.rad( increase ), 0 ) ):toWorldSpace( self.State.PreRotation[Item].CFrame:toObjectSpace( self.Options.PivotPoint or self.State.PreRotation[Selection.Last].CFrame ):inverse() );
					end;
				elseif axis == Enum.Axis.X then
					if self.Options.pivot == "center" then
						Item.CFrame = self.State.PreRotationPosition:toWorldSpace( CFrame.new( 0, 0, 0 ) * CFrame.Angles( math.rad( increase ), 0, 0 ) ):toWorldSpace( self.State.PreRotation[Item].CFrame:toObjectSpace( self.State.PreRotationPosition ):inverse() );
					elseif self.Options.pivot == "local" then
						Item.CFrame = self.State.PreRotation[Item].CFrame:toWorldSpace( CFrame.new( 0, 0, 0 ) * CFrame.Angles( math.rad( increase ), 0, 0 ) );
					elseif self.Options.pivot == "last" then
						Item.CFrame = ( self.Options.PivotPoint or self.State.PreRotation[Selection.Last].CFrame ):toWorldSpace( CFrame.new( 0, 0, 0 ) * CFrame.Angles( math.rad( increase ), 0, 0 ) ):toWorldSpace( self.State.PreRotation[Item].CFrame:toObjectSpace( self.Options.PivotPoint or self.State.PreRotation[Selection.Last].CFrame ):inverse() );
					end;
				elseif axis == Enum.Axis.Z then
					if self.Options.pivot == "center" then
						Item.CFrame = self.State.PreRotationPosition:toWorldSpace( CFrame.new( 0, 0, 0 ) * CFrame.Angles( 0, 0, math.rad( increase ) ) ):toWorldSpace( self.State.PreRotation[Item].CFrame:toObjectSpace( self.State.PreRotationPosition ):inverse() );
					elseif self.Options.pivot == "local" then
						Item.CFrame = self.State.PreRotation[Item].CFrame:toWorldSpace( CFrame.new( 0, 0, 0 ) * CFrame.Angles( 0, 0, math.rad( increase ) ) );
					elseif self.Options.pivot == "last" then
						Item.CFrame = ( self.Options.PivotPoint or self.State.PreRotation[Selection.Last].CFrame ):toWorldSpace( CFrame.new( 0, 0, 0 ) * CFrame.Angles( 0, 0, math.rad( increase ) ) ):toWorldSpace( self.State.PreRotation[Item].CFrame:toObjectSpace( self.Options.PivotPoint or self.State.PreRotation[Selection.Last].CFrame ):inverse() );
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

Tools.Rotate.hideHandles = function ( self )

	-- Hide the handles if they exist
	if self.Temporary.Handles then
		self.Temporary.Handles.Adornee = nil;
	end;

end;


------------------------------------------
-- Paint tool
------------------------------------------

-- Create the main container for this tool
Tools.Paint = {};

-- Define the color of the tool
Tools.Paint.Color = BrickColor.new( "Really red" );

-- Define options
Tools.Paint.Options = {
	["Color"] = nil
};

Tools.Paint.Temporary = {};

-- Add listeners
Tools.Paint.Listeners = {};

Tools.Paint.Listeners.Equipped = function ()

	-- Change the color of selection boxes temporarily
	Tools.Paint.Temporary.PreviousSelectionBoxColor = SelectionBoxColor;
	SelectionBoxColor = Tools.Paint.Color;
	updateSelectionBoxColor();

	-- Show the GUI
	Tools.Paint:showGUI();

	-- Update the selected color
	Tools.Paint:changeColor( Tools.Paint.Options.Color );

end;

Tools.Paint.Listeners.Unequipped = function ()

	-- Clear out the preferred color option
	Tools.Paint:changeColor( nil );

	-- Hide the GUI
	Tools.Paint:hideGUI();

	-- Restore the original color of the selection boxes
	SelectionBoxColor = Tools.Paint.Temporary.PreviousSelectionBoxColor;
	updateSelectionBoxColor();

end;

Tools.Paint.Listeners.Button1Up = function ()

	-- Make sure that they clicked on one of the items in their selection
	-- (and they weren't multi-selecting)
	if Selection:find( Mouse.Target ) and not selecting and not selecting then

		override_selection = true;

		-- Add a new record to the history system
		local old_parts, new_parts = _cloneTable( Selection.Items ), _cloneParts( Selection.Items );
		local focus_search = _findTableOccurrences( old_parts, Selection.Last );
		_replaceParts( old_parts, new_parts );
		for _, Item in pairs( new_parts ) do
			Selection:add( Item );
		end;
		if #focus_search > 0 then
			Selection:focus( new_parts[focus_search[1]] );
		end;
		History:add( old_parts, new_parts );

		-- Paint all of the selected items `Tools.Paint.Options.Color`
		if Tools.Paint.Options.Color then
			for _, Item in pairs( Selection.Items ) do
				Item.BrickColor = Tools.Paint.Options.Color;
			end;
		end;

	end;

end;

Tools.Paint.changeColor = function ( self, Color )

	-- Alright so if `Color` is given, set that as the preferred color
	if Color then

		-- First of all, change the color option itself
		self.Options.Color = Color;

		-- Add a new record to the history system
		local old_parts, new_parts = _cloneTable( Selection.Items ), _cloneParts( Selection.Items );
		local focus_search = _findTableOccurrences( old_parts, Selection.Last );
		_replaceParts( old_parts, new_parts );
		for _, Item in pairs( new_parts ) do
			Selection:add( Item );
		end;
		if #focus_search > 0 then
			Selection:focus( new_parts[focus_search[1]] );
		end;
		History:add( old_parts, new_parts );

		-- Then, we want to update the color of any items in the selection
		for _, Item in pairs( Selection.Items ) do
			Item.BrickColor = Color;
		end;

		-- After that, we want to mark our new color in the palette
		if self.Temporary.GUI then

			-- First clear out any other marks
			for _, ColorSquare in pairs( self.Temporary.GUI.Palette:GetChildren() ) do
				ColorSquare.Text = "";
			end;

			-- Then mark the right square
			self.Temporary.GUI.Palette[Color.Name].Text = "X";

		end;

	-- Otherwise, let's assume no color at all
	else

		-- Set the preferred color to none
		self.Options.Color = nil;

		-- Clear out any color option marks on any of the squares
		if self.Temporary.GUI then
			for _, ColorSquare in pairs( self.Temporary.GUI.Palette:GetChildren() ) do
				ColorSquare.Text = "";
			end;
		end;

	end;

end;

Tools.Paint.showGUI = function ( self )

	-- Initialize the GUI if it's not ready yet
	if not self.Temporary.GUI then

		local Container = Tool:WaitForChild( "BTPaintToolGUI" ):Clone();
		Container.Parent = UI;

		for _, ColorButton in pairs( Container.Palette:GetChildren() ) do
			ColorButton.MouseButton1Click:connect( function ()
				self:changeColor( BrickColor.new( ColorButton.Name ) );
			end );
		end;

		self.Temporary.GUI = Container;
	end;

	-- Reveal the GUI
	self.Temporary.GUI.Visible = true;

end;

Tools.Paint.hideGUI = function ( self )

	-- Hide the GUI if it exists
	if self.Temporary.GUI then
		self.Temporary.GUI.Visible = false;
	end;

end;

------------------------------------------
-- Anchor tool
------------------------------------------

-- Create the tool
Tools.Anchor = {};

-- Create structures to hold data that the tool needs
Tools.Anchor.Temporary = {
	["Connections"] = {};
};

Tools.Anchor.State = {
	["anchored"] = nil;
};

Tools.Anchor.Listeners = {};

-- Define the color of the tool
Tools.Anchor.Color = BrickColor.new( "Really black" );

-- Start adding functionality to the tool
Tools.Anchor.Listeners.Equipped = function ()

	-- Change the color of selection boxes temporarily
	Tools.Anchor.Temporary.PreviousSelectionBoxColor = SelectionBoxColor;
	SelectionBoxColor = Tools.Anchor.Color;
	updateSelectionBoxColor();

	-- Reveal the GUI
	Tools.Anchor:showGUI();

	-- Update the GUI regularly
	coroutine.wrap( function ()
		local updater_on = true;

		-- Provide a function to stop the loop
		Tools.Anchor.Temporary.Updater = function ()
			updater_on = false;
		end;

		while wait( 0.1 ) and updater_on do

			-- Make sure the tool's equipped
			if CurrentTool == Tools.Anchor then

				-- Update the anchor status of every item in the selection
				local anchor_status = nil;
				for item_index, Item in pairs( Selection.Items ) do

					-- Set the first values for the first item
					if item_index == 1 then
						anchor_status = Item.Anchored;

					-- Otherwise, compare them and set them to `nil` if they're not identical
					else
						if anchor_status ~= Item.Anchored then
							anchor_status = nil;
						end;
					end;

				end;

				Tools.Anchor.State.anchored = anchor_status;

				-- Update the GUI if it's visible
				if Tools.Anchor.Temporary.GUI and Tools.Anchor.Temporary.GUI.Visible then
					Tools.Anchor:updateGUI();
				end;

			end;

		end;

	end )();

	-- Listen for the Enter button to be pressed to toggle the anchor
	Tools.Anchor.Temporary.Connections.EnterButtonListener = Mouse.KeyDown:connect( function ( key )

		local key = key:lower();
		local key_code = key:byte();

		-- If the Enter button is pressed
		if key_code == 13 then

			if Tools.Anchor.State.anchored == true then
				Tools.Anchor:unanchor();

			elseif Tools.Anchor.State.anchored == false then
				Tools.Anchor:anchor();

			elseif Tools.Anchor.State.anchored == nil then
				Tools.Anchor:anchor();

			end;

		end;

	end );

end;

Tools.Anchor.anchor = function ( self )

	-- Add a new record to the history system
	local old_parts, new_parts = _cloneTable( Selection.Items ), _cloneParts( Selection.Items );
	local focus_search = _findTableOccurrences( old_parts, Selection.Last );
	_replaceParts( old_parts, new_parts );
	for _, Item in pairs( new_parts ) do
		Selection:add( Item );
	end;
	if #focus_search > 0 then
		Selection:focus( new_parts[focus_search[1]] );
	end;
	History:add( old_parts, new_parts );

	-- Anchor all the items in the selection
	for _, Item in pairs( Selection.Items ) do
		Item.Anchored = true;
		Item:MakeJoints();
	end;

end;

Tools.Anchor.unanchor = function ( self )

	-- Add a new record to the history system
	local old_parts, new_parts = _cloneTable( Selection.Items ), _cloneParts( Selection.Items );
	local focus_search = _findTableOccurrences( old_parts, Selection.Last );
	_replaceParts( old_parts, new_parts );
	for _, Item in pairs( new_parts ) do
		Selection:add( Item );
	end;
	if #focus_search > 0 then
		Selection:focus( new_parts[focus_search[1]] );
	end;
	History:add( old_parts, new_parts );

	-- Unanchor all the items in the selection
	for _, Item in pairs( Selection.Items ) do
		Item.Anchored = false;
		Item:MakeJoints();
	end;

end;

Tools.Anchor.showGUI = function ( self )

	-- Initialize the GUI if it's not ready yet
	if not self.Temporary.GUI then

		local Container = Tool:WaitForChild( "BTAnchorToolGUI" ):Clone();
		Container.Parent = UI;

		-- Change the anchor status when the button is clicked
		Container.Status.Anchored.Button.MouseButton1Down:connect( function ()
			self:anchor();
		end );

		Container.Status.Unanchored.Button.MouseButton1Down:connect( function ()
			self:unanchor();
		end );

		self.Temporary.GUI = Container;
	end;

	-- Reveal the GUI
	self.Temporary.GUI.Visible = true;

end;

Tools.Anchor.updateGUI = function ( self )

	-- Make sure the GUI exists
	if not self.Temporary.GUI then
		return;
	end;

	local GUI = self.Temporary.GUI;

	if self.State.anchored == nil then
		GUI.Status.Anchored.Background.Image = light_slanted_rectangle;
		GUI.Status.Anchored.SelectedIndicator.BackgroundTransparency = 1;
		GUI.Status.Unanchored.Background.Image = light_slanted_rectangle;
		GUI.Status.Unanchored.SelectedIndicator.BackgroundTransparency = 1;

	elseif self.State.anchored == true then
		GUI.Status.Anchored.Background.Image = dark_slanted_rectangle;
		GUI.Status.Anchored.SelectedIndicator.BackgroundTransparency = 0;
		GUI.Status.Unanchored.Background.Image = light_slanted_rectangle;
		GUI.Status.Unanchored.SelectedIndicator.BackgroundTransparency = 1;

	elseif self.State.anchored == false then
		GUI.Status.Anchored.Background.Image = light_slanted_rectangle;
		GUI.Status.Anchored.SelectedIndicator.BackgroundTransparency = 1;
		GUI.Status.Unanchored.Background.Image = dark_slanted_rectangle;
		GUI.Status.Unanchored.SelectedIndicator.BackgroundTransparency = 0;

	end;

end;

Tools.Anchor.hideGUI = function ( self )

	-- Hide the GUI if it exists
	if self.Temporary.GUI then
		self.Temporary.GUI.Visible = false;
	end;

end;

Tools.Anchor.Listeners.Unequipped = function ()

	-- Stop the update loop
	Tools.Anchor.Temporary.Updater();
	Tools.Anchor.Temporary.Updater = nil;

	-- Hide the GUI
	Tools.Anchor:hideGUI();

	-- Clear out any temporary connections
	for connection_index, Connection in pairs( Tools.Anchor.Temporary.Connections ) do
		Connection:disconnect();
		Tools.Anchor.Temporary.Connections[connection_index] = nil;
	end;

	-- Restore the original color of the selection boxes
	SelectionBoxColor = Tools.Anchor.Temporary.PreviousSelectionBoxColor;
	updateSelectionBoxColor();

end;

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
		local updater_on = true;

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
	local cr_x, cr_y, cr_z = Camera.CoordinateFrame:toEulerAnglesXYZ();
	self.State.PreB2DownCameraRotation = Vector3.new( cr_x, cr_y, cr_z );

end;

Tools.Surface.Listeners.Button2Up = function ()

	local self = Tools.Surface;

	local cr_x, cr_y, cr_z = Camera.CoordinateFrame:toEulerAnglesXYZ();
	local CameraRotation = Vector3.new( cr_x, cr_y, cr_z );

	-- If a surface is selected
	if Selection:find( Mouse.Target ) and self.State.PreB2DownCameraRotation == CameraRotation then
		self:changeSurface( Mouse.TargetSurface );
	end;

end;

Tools.Surface.SpecialTypeNames = {
	SmoothNoOutlines = "NO OUTLINE",
	Inlet = "INLETS"
};

Tools.Surface.changeType = function ( self, surface_type )

	-- Add a new record to the history system
	local old_parts, new_parts = _cloneTable( Selection.Items ), _cloneParts( Selection.Items );
	local focus_search = _findTableOccurrences( old_parts, Selection.Last );
	_replaceParts( old_parts, new_parts );
	for _, Item in pairs( new_parts ) do
		Selection:add( Item );
	end;
	if #focus_search > 0 then
		Selection:focus( new_parts[focus_search[1]] );
	end;
	History:add( old_parts, new_parts );

	-- Apply `surface_type` to all items in the selection
	for _, Item in pairs( Selection.Items ) do
		Item[self.Options.side.Name .. "Surface"] = surface_type;
	end;
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

function createDropdown()

	local Frame = RbxUtility.Create "Frame" {
		Name = "Dropdown";
		Size = UDim2.new( 0, 20, 0, 20 );
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		ClipsDescendants = true;
	};

	RbxUtility.Create "ImageLabel" {
		Parent = Frame;
		Name = "Arrow";
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		Image = expand_arrow;
		Position = UDim2.new( 1, -21, 0, 3 );
		Size = UDim2.new( 0, 20, 0, 20 );
		ZIndex = 3;
	};

	local DropdownObject = {
		-- Provide access to the actual frame
		Frame = Frame;

		-- Keep a list of all the options in the dropdown
		_options = {};

		-- Provide a function to add options to the dropdown
		addOption = function ( self, option )

			-- Add the option to the list
			table.insert( self._options, option );

			-- Create the GUI for the option
			local Button = RbxUtility.Create "TextButton" {
				Parent = self.Frame;
				BackgroundColor3 = Color3.new( 0, 0, 0 );
				BackgroundTransparency = 0.3;
				BorderColor3 = Color3.new( 27 / 255, 42 / 255, 53 / 255 );
				BorderSizePixel = 1;
				Name = option;
				Position = UDim2.new( math.ceil( #self._options / 9 ) - 1, 0, 0, 25 * ( ( #self._options % 9 == 0 ) and 9 or ( #self._options % 9 ) ) );
				Size = UDim2.new( 1, 0, 0, 25 );
				ZIndex = 3;
				Text = "";
			};
			local Label = RbxUtility.Create "TextLabel" {
				Parent = Button;
				BackgroundTransparency = 1;
				BorderSizePixel = 0;
				Position = UDim2.new( 0, 6, 0, 0 );
				Size = UDim2.new( 1, -30, 1, 0 );
				ZIndex = 3;
				Font = Enum.Font.ArialBold;
				FontSize = Enum.FontSize.Size12;
				Text = option;
				TextColor3 = Color3.new( 1, 1, 1 );
				TextXAlignment = Enum.TextXAlignment.Left;
				TextYAlignment = Enum.TextYAlignment.Center;
			};

			-- Return the button object
			return Button;

		end;

		selectOption = function ( self, option )
			self.Frame.MainButton.CurrentOption.Text = option;
		end;

		open = false;

		toggle = function ( self )

			-- If it's open, close it
			if self.open then
				self.Frame.MainButton.BackgroundTransparency = 0.3;
				self.Frame.ClipsDescendants = true;
				self.open = false;

			-- If it's not open, open it
			else
				self.Frame.MainButton.BackgroundTransparency = 0;
				self.Frame.ClipsDescendants = false;
				self.open = true;
			end;

		end;

	};

	-- Create the GUI for the option
	local MainButton = RbxUtility.Create "TextButton" {
		Parent = Frame;
		Name = "MainButton";
		BackgroundColor3 = Color3.new( 0, 0, 0 );
		BackgroundTransparency = 0.3;
		BorderColor3 = Color3.new( 27 / 255, 42 / 255, 53 / 255 );
		BorderSizePixel = 1;
		Position = UDim2.new( 0, 0, 0, 0 );
		Size = UDim2.new( 1, 0, 0, 25 );
		ZIndex = 2;
		Text = "";

		-- Toggle the dropdown when pressed
		[RbxUtility.Create.E "MouseButton1Up"] = function ()
			DropdownObject:toggle();
		end;
	};
	RbxUtility.Create "TextLabel" {
		Parent = MainButton;
		Name = "CurrentOption";
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		Position = UDim2.new( 0, 6, 0, 0 );
		Size = UDim2.new( 1, -30, 1, 0 );
		ZIndex = 3;
		Font = Enum.Font.ArialBold;
		FontSize = Enum.FontSize.Size12;
		Text = "";
		TextColor3 = Color3.new( 1, 1, 1 );
		TextXAlignment = Enum.TextXAlignment.Left;
		TextYAlignment = Enum.TextYAlignment.Center;
	};

	return DropdownObject;

end;

Tools.Surface.showGUI = function ( self )

	-- Initialize the GUI if it's not ready yet
	if not self.GUI then

		local Container = Tool:WaitForChild( "BTSurfaceToolGUI" ):Clone();
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
		local updater_on = true;

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

Tools.Material.changeMaterial = function ( self, material_type )

	-- Add a new record to the history system
	local old_parts, new_parts = _cloneTable( Selection.Items ), _cloneParts( Selection.Items );
	local focus_search = _findTableOccurrences( old_parts, Selection.Last );
	_replaceParts( old_parts, new_parts );
	for _, Item in pairs( new_parts ) do
		Selection:add( Item );
	end;
	if #focus_search > 0 then
		Selection:focus( new_parts[focus_search[1]] );
	end;
	History:add( old_parts, new_parts );

	-- Apply `material_type` to all items in the selection
	for _, Item in pairs( Selection.Items ) do
		Item.Material = material_type;
	end;
	if self.MaterialDropdown.open then
		self.MaterialDropdown:toggle();
	end;
end;

Tools.Material.changeTransparency = function ( self, transparency )

	-- Add a new record to the history system
	local old_parts, new_parts = _cloneTable( Selection.Items ), _cloneParts( Selection.Items );
	local focus_search = _findTableOccurrences( old_parts, Selection.Last );
	_replaceParts( old_parts, new_parts );
	for _, Item in pairs( new_parts ) do
		Selection:add( Item );
	end;
	if #focus_search > 0 then
		Selection:focus( new_parts[focus_search[1]] );
	end;
	History:add( old_parts, new_parts );

	-- Apply `transparency` to all items in the selection
	for _, Item in pairs( Selection.Items ) do
		Item.Transparency = transparency;
	end;
end;

Tools.Material.changeReflectance = function ( self, reflectance )

	-- Add a new record to the history system
	local old_parts, new_parts = _cloneTable( Selection.Items ), _cloneParts( Selection.Items );
	local focus_search = _findTableOccurrences( old_parts, Selection.Last );
	_replaceParts( old_parts, new_parts );
	for _, Item in pairs( new_parts ) do
		Selection:add( Item );
	end;
	if #focus_search > 0 then
		Selection:focus( new_parts[focus_search[1]] );
	end;
	History:add( old_parts, new_parts );

	-- Apply `reflectance` to all items in the selection
	for _, Item in pairs( Selection.Items ) do
		Item.Reflectance = reflectance;
	end;
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

		local Container = Tool:WaitForChild( "BTMaterialToolGUI" ):Clone();
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

------------------------------------------
-- Collision tool
------------------------------------------

-- Create the tool
Tools.Collision = {};

-- Create structures to hold data that the tool needs
Tools.Collision.Temporary = {
	["Connections"] = {};
};

Tools.Collision.State = {
	["colliding"] = nil;
};

Tools.Collision.Listeners = {};

-- Define the color of the tool
Tools.Collision.Color = BrickColor.new( "Really black" );

-- Start adding functionality to the tool
Tools.Collision.Listeners.Equipped = function ()

	-- Change the color of selection boxes temporarily
	Tools.Collision.Temporary.PreviousSelectionBoxColor = SelectionBoxColor;
	SelectionBoxColor = Tools.Collision.Color;
	updateSelectionBoxColor();

	-- Reveal the GUI
	Tools.Collision:showGUI();

	-- Update the GUI regularly
	coroutine.wrap( function ()
		local updater_on = true;

		-- Provide a function to stop the loop
		Tools.Collision.Temporary.Updater = function ()
			updater_on = false;
		end;

		while wait( 0.1 ) and updater_on do

			-- Make sure the tool's equipped
			if CurrentTool == Tools.Collision then

				-- Update the collision status of every item in the selection
				local colliding = nil;
				for item_index, Item in pairs( Selection.Items ) do

					-- Set the first values for the first item
					if item_index == 1 then
						colliding = Item.CanCollide;

					-- Otherwise, compare them and set them to `nil` if they're not identical
					else
						if colliding ~= Item.CanCollide then
							colliding = nil;
						end;
					end;

				end;

				Tools.Collision.State.colliding = colliding;

				-- Update the GUI if it's visible
				if Tools.Collision.Temporary.GUI and Tools.Collision.Temporary.GUI.Visible then
					Tools.Collision:updateGUI();
				end;

			end;

		end;

	end )();

	-- Listen for the Enter button to be pressed to toggle collision
	Tools.Collision.Temporary.Connections.EnterButtonListener = Mouse.KeyDown:connect( function ( key )

		local key = key:lower();
		local key_code = key:byte();

		-- If the Enter button is pressed
		if key_code == 13 then

			if Tools.Collision.State.colliding == true then
				Tools.Collision:disable();

			elseif Tools.Collision.State.colliding == false then
				Tools.Collision:enable();

			elseif Tools.Collision.State.colliding == nil then
				Tools.Collision:enable();

			end;

		end;

	end );

end;

Tools.Collision.enable = function ( self )

	-- Add a new record to the history system
	local old_parts, new_parts = _cloneTable( Selection.Items ), _cloneParts( Selection.Items );
	local focus_search = _findTableOccurrences( old_parts, Selection.Last );
	_replaceParts( old_parts, new_parts );
	for _, Item in pairs( new_parts ) do
		Selection:add( Item );
	end;
	if #focus_search > 0 then
		Selection:focus( new_parts[focus_search[1]] );
	end;
	History:add( old_parts, new_parts );

	-- Enable collision for all the items in the selection
	for _, Item in pairs( Selection.Items ) do
		Item.CanCollide = true;
	end;

end;

Tools.Collision.disable = function ( self )

	-- Add a new record to the history system
	local old_parts, new_parts = _cloneTable( Selection.Items ), _cloneParts( Selection.Items );
	local focus_search = _findTableOccurrences( old_parts, Selection.Last );
	_replaceParts( old_parts, new_parts );
	for _, Item in pairs( new_parts ) do
		Selection:add( Item );
	end;
	if #focus_search > 0 then
		Selection:focus( new_parts[focus_search[1]] );
	end;
	History:add( old_parts, new_parts );

	-- Disable collision for all the items in the selection
	for _, Item in pairs( Selection.Items ) do
		Item.CanCollide = false;
	end;

end;

Tools.Collision.showGUI = function ( self )

	-- Initialize the GUI if it's not ready yet
	if not self.Temporary.GUI then

		local Container = Tool:WaitForChild( "BTCollisionToolGUI" ):Clone();
		Container.Parent = UI;

		Container.Status.On.Button.MouseButton1Down:connect( function ()
			self:enable();
		end );

		Container.Status.Off.Button.MouseButton1Down:connect( function ()
			self:disable();
		end );

		self.Temporary.GUI = Container;
	end;

	-- Reveal the GUI
	self.Temporary.GUI.Visible = true;

end;

Tools.Collision.updateGUI = function ( self )

	-- Make sure the GUI exists
	if not self.Temporary.GUI then
		return;
	end;

	local GUI = self.Temporary.GUI;

	if self.State.colliding == nil then
		GUI.Status.On.Background.Image = light_slanted_rectangle;
		GUI.Status.On.SelectedIndicator.BackgroundTransparency = 1;
		GUI.Status.Off.Background.Image = light_slanted_rectangle;
		GUI.Status.Off.SelectedIndicator.BackgroundTransparency = 1;

	elseif self.State.colliding == true then
		GUI.Status.On.Background.Image = dark_slanted_rectangle;
		GUI.Status.On.SelectedIndicator.BackgroundTransparency = 0;
		GUI.Status.Off.Background.Image = light_slanted_rectangle;
		GUI.Status.Off.SelectedIndicator.BackgroundTransparency = 1;

	elseif self.State.colliding == false then
		GUI.Status.On.Background.Image = light_slanted_rectangle;
		GUI.Status.On.SelectedIndicator.BackgroundTransparency = 1;
		GUI.Status.Off.Background.Image = dark_slanted_rectangle;
		GUI.Status.Off.SelectedIndicator.BackgroundTransparency = 0;

	end;

end;

Tools.Collision.hideGUI = function ( self )

	-- Hide the GUI if it exists
	if self.Temporary.GUI then
		self.Temporary.GUI.Visible = false;
	end;

end;

Tools.Collision.Listeners.Unequipped = function ()

	-- Stop the update loop
	Tools.Collision.Temporary.Updater();
	Tools.Collision.Temporary.Updater = nil;

	-- Hide the GUI
	Tools.Collision:hideGUI();

	-- Clear out any temporary connections
	for connection_index, Connection in pairs( Tools.Collision.Temporary.Connections ) do
		Connection:disconnect();
		Tools.Collision.Temporary.Connections[connection_index] = nil;
	end;

	-- Restore the original color of the selection boxes
	SelectionBoxColor = Tools.Collision.Temporary.PreviousSelectionBoxColor;
	updateSelectionBoxColor();

end;

------------------------------------------
-- New part tool
------------------------------------------

-- Create the tool
Tools.NewPart = {};

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
	elseif self.Options.type == "truss" then
		NewPart = Instance.new( "TrussPart", Services.Workspace );
	elseif self.Options.type == "wedge" then
		NewPart = Instance.new( "WedgePart", Services.Workspace );
	elseif self.Options.type == "corner" then
		NewPart = Instance.new( "CornerWedgePart", Services.Workspace );
	elseif self.Options.type == "cylinder" then
		NewPart = Instance.new( "Part", Services.Workspace );
		NewPart.Shape = "Cylinder";
	elseif self.Options.type == "ball" then
		NewPart = Instance.new( "Part", Services.Workspace );
		NewPart.Shape = "Ball";
	elseif self.Options.type == "seat" then
		NewPart = Instance.new( "Seat", Services.Workspace );
	elseif self.Options.type == "vehicle seat" then
		NewPart = Instance.new( "VehicleSeat", Services.Workspace );
	elseif self.Options.type == "spawn" then
		NewPart = Instance.new( "SpawnLocation", Services.Workspace );
	end;
	NewPart.Anchored = true;

	-- Select the new part
	Selection:clear();
	Selection:add( NewPart );

	-- Add a new record to the history system
	local new_parts = { NewPart };
	History:add( {}, new_parts );

	-- Switch to the move tool and simulate clicking so
	-- that the user could easily position their new part
	equipTool( Tools.Move );
	Tools.Move.ManualTarget = NewPart;
	NewPart.CFrame = CFrame.new( Mouse.Hit.p );
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

		local Container = Tool:WaitForChild( "BTNewPartToolGUI" ):Clone();
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
		local updater_on = true;

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

	-- Add a new record to the history system
	local old_parts, new_parts = _cloneTable( Selection.Items ), _cloneParts( Selection.Items );
	local focus_search = _findTableOccurrences( old_parts, Selection.Last );
	_replaceParts( old_parts, new_parts );
	for _, Item in pairs( new_parts ) do
		Selection:add( Item );
	end;
	if #focus_search > 0 then
		Selection:focus( new_parts[focus_search[1]] );
	end;
	History:add( old_parts, new_parts );

	-- Apply type `new_type` to all the meshes in items from the selection
	for _, Item in pairs( Selection.Items ) do
		local Mesh = _getChildOfClass( Item, "SpecialMesh" );
		if Mesh then
			Mesh.MeshType = new_type;
		end;
	end;

	if self.TypeDropdown.open then
		self.TypeDropdown:toggle();
	end;

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
				self.GUI.TintOption.RInput.TextBox.Text = mesh_tint_r and _round( mesh_tint_r * 255, 2 ) or "*";
			end;
			if not self.State.tint_g_focused then
				self.GUI.TintOption.GInput.TextBox.Text = mesh_tint_g and _round( mesh_tint_g * 255, 2 ) or "*";
			end;
			if not self.State.tint_b_focused then
				self.GUI.TintOption.BInput.TextBox.Text = mesh_tint_b and _round( mesh_tint_b * 255, 2 ) or "*";
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
		local Container = Tool:WaitForChild( "BTMeshToolGUI" ):Clone();
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


		self.GUI = Container;
	end;

	-- Reveal the GUI
	self.GUI.Visible = true;

end;

Tools.Mesh.addMesh = function ( self )

	-- Add a new record to the history system
	local old_parts, new_parts = _cloneTable( Selection.Items ), _cloneParts( Selection.Items );
	local focus_search = _findTableOccurrences( old_parts, Selection.Last );
	_replaceParts( old_parts, new_parts );
	for _, Item in pairs( new_parts ) do
		Selection:add( Item );
	end;
	if #focus_search > 0 then
		Selection:focus( new_parts[focus_search[1]] );
	end;
	History:add( old_parts, new_parts );

	-- Add meshes to all the items from the selection that
	-- don't already have one
	for _, Item in pairs( Selection.Items ) do
		local Mesh = _getChildOfClass( Item, "SpecialMesh" );
		if not Mesh then
			RbxUtility.Create "SpecialMesh" {
				Parent = Item;
				MeshType = Enum.MeshType.Brick;
			};
		end;
	end;

end;

Tools.Mesh.removeMesh = function ( self )

	-- Add a new record to the history system
	local old_parts, new_parts = _cloneTable( Selection.Items ), _cloneParts( Selection.Items );
	local focus_search = _findTableOccurrences( old_parts, Selection.Last );
	_replaceParts( old_parts, new_parts );
	for _, Item in pairs( new_parts ) do
		Selection:add( Item );
	end;
	if #focus_search > 0 then
		Selection:focus( new_parts[focus_search[1]] );
	end;
	History:add( old_parts, new_parts );

	-- Remove meshes from all the selected items
	for _, Item in pairs( Selection.Items ) do
		local meshes = _getChildrenOfClass( Item, "SpecialMesh" );
		for _, Mesh in pairs( meshes ) do
			Mesh:Destroy();
		end;
	end;

end;

Tools.Mesh.changeMesh = function ( self, mesh_id )

	-- Add a new record to the history system
	local old_parts, new_parts = _cloneTable( Selection.Items ), _cloneParts( Selection.Items );
	local focus_search = _findTableOccurrences( old_parts, Selection.Last );
	_replaceParts( old_parts, new_parts );
	for _, Item in pairs( new_parts ) do
		Selection:add( Item );
	end;
	if #focus_search > 0 then
		Selection:focus( new_parts[focus_search[1]] );
	end;
	History:add( old_parts, new_parts );

	-- Apply type `new_type` to all the meshes in items from the selection
	for _, Item in pairs( Selection.Items ) do
		local Mesh = _getChildOfClass( Item, "SpecialMesh" );
		if Mesh then
			Mesh.MeshId = "http://www.roblox.com/asset/?id=" .. mesh_id;
		end;
	end;

end;

Tools.Mesh.changeTexture = function ( self, texture_id )

	-- Add a new record to the history system
	local old_parts, new_parts = _cloneTable( Selection.Items ), _cloneParts( Selection.Items );
	local focus_search = _findTableOccurrences( old_parts, Selection.Last );
	_replaceParts( old_parts, new_parts );
	for _, Item in pairs( new_parts ) do
		Selection:add( Item );
	end;
	if #focus_search > 0 then
		Selection:focus( new_parts[focus_search[1]] );
	end;
	History:add( old_parts, new_parts );

	-- Apply type `new_type` to all the meshes in items from the selection
	for _, Item in pairs( Selection.Items ) do
		local Mesh = _getChildOfClass( Item, "SpecialMesh" );
		if Mesh then
			Mesh.TextureId = "http://www.roblox.com/asset/?id=" .. texture_id;
		end;
	end;

end;

Tools.Mesh.changeScale = function ( self, component, new_value )

	-- Add a new record to the history system
	local old_parts, new_parts = _cloneTable( Selection.Items ), _cloneParts( Selection.Items );
	local focus_search = _findTableOccurrences( old_parts, Selection.Last );
	_replaceParts( old_parts, new_parts );
	for _, Item in pairs( new_parts ) do
		Selection:add( Item );
	end;
	if #focus_search > 0 then
		Selection:focus( new_parts[focus_search[1]] );
	end;
	History:add( old_parts, new_parts );

	-- Apply type `new_type` to all the meshes in items from the selection
	for _, Item in pairs( Selection.Items ) do
		local Mesh = _getChildOfClass( Item, "SpecialMesh" );
		if Mesh then
			Mesh.Scale = Vector3.new(
				component == 'x' and new_value or Mesh.Scale.x,
				component == 'y' and new_value or Mesh.Scale.y,
				component == 'z' and new_value or Mesh.Scale.z
			);
		end;
	end;

end;

Tools.Mesh.changeTint = function ( self, component, new_value )

	-- Add a new record to the history system
	local old_parts, new_parts = _cloneTable( Selection.Items ), _cloneParts( Selection.Items );
	local focus_search = _findTableOccurrences( old_parts, Selection.Last );
	_replaceParts( old_parts, new_parts );
	for _, Item in pairs( new_parts ) do
		Selection:add( Item );
	end;
	if #focus_search > 0 then
		Selection:focus( new_parts[focus_search[1]] );
	end;
	History:add( old_parts, new_parts );

	-- Apply type `new_type` to all the meshes in items from the selection
	for _, Item in pairs( Selection.Items ) do
		local Mesh = _getChildOfClass( Item, "SpecialMesh" );
		if Mesh then
			Mesh.VertexColor = Vector3.new(
				component == 'r' and new_value or Mesh.VertexColor.x,
				component == 'g' and new_value or Mesh.VertexColor.y,
				component == 'b' and new_value or Mesh.VertexColor.z
			);
		end;
	end;

end;

Tools.Mesh.hideGUI = function ( self )

	-- Hide the GUI if it exists already
	if self.GUI then
		self.GUI.Visible = false;
	end;

end;

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
		local updater_on = true;

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

Tools.Texture.Listeners.Unequipped = function ()

	local self = Tools.Texture;

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

Tools.Texture.Listeners.Button2Down = function ()

	local self = Tools.Texture;

	-- Capture the camera rotation (for later use
	-- in determining whether a surface was being
	-- selected or the camera was being rotated
	-- with the right mouse button)
	local cr_x, cr_y, cr_z = Camera.CoordinateFrame:toEulerAnglesXYZ();
	self.State.PreB2DownCameraRotation = Vector3.new( cr_x, cr_y, cr_z );

end;

Tools.Texture.Listeners.Button2Up = function ()

	local self = Tools.Texture;

	local cr_x, cr_y, cr_z = Camera.CoordinateFrame:toEulerAnglesXYZ();
	local CameraRotation = Vector3.new( cr_x, cr_y, cr_z );

	-- If a surface is selected, change the side option
	if Selection:find( Mouse.Target ) and self.State.PreB2DownCameraRotation == CameraRotation then
		self:changeSide( Mouse.TargetSurface );
	end;

end;

Tools.Texture.Listeners.KeyUp = function ( key )

	local self = Tools.Texture;

	local key = key:lower();
	local key_code = key:byte();

	-- Toggle modes if the enter button is pressed
	if key_code == 13 then
		if self.Options.mode == "decal" then
			self:changeMode( "texture" );
		elseif self.Options.mode == "texture" then
			self:changeMode( "decal" );
		end;
	end;

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
		self.GUI.ModeOption.Decal.Background.Image = dark_slanted_rectangle;
		self.GUI.ModeOption.Texture.Background.Image = light_slanted_rectangle;
		self.GUI.AddButton.Button.Text = "ADD DECAL";
		self.GUI.RemoveButton.Button.Text = "REMOVE DECAL";
	elseif new_mode == "texture" then
		self.GUI.ModeOption.Decal.SelectedIndicator.Transparency = 1;
		self.GUI.ModeOption.Texture.SelectedIndicator.Transparency = 0;
		self.GUI.ModeOption.Decal.Background.Image = light_slanted_rectangle;
		self.GUI.ModeOption.Texture.Background.Image = dark_slanted_rectangle;
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

	-- Apply the new texture to any items w/ textures in the selection
	-- that are on the side in the options
	for _, Item in pairs( Selection.Items ) do
		local textures = _getChildrenOfClass( Item, "Texture" );
		for _, Texture in pairs( textures ) do
			if Texture.Face == self.Options.side then
				Texture.Texture = "http://www.roblox.com/asset/?id=" .. new_texture;
			end;
		end;
	end;

end;

Tools.Texture.changeDecal = function ( self, new_decal )

	-- Apply the new decal to any items w/ decals in the selection
	-- that are on the side in the options
	for _, Item in pairs( Selection.Items ) do
		local decals = _getChildrenOfClass( Item, "Decal" );
		for _, Decal in pairs( decals ) do
			if Decal.Face == self.Options.side then
				Decal.Texture = "http://www.roblox.com/asset/?id=" .. new_decal;
			end;
		end;
	end;

end;

Tools.Texture.changeTransparency = function ( self, new_transparency )

	-- Apply the new transparency to any items w/
	-- decals/textures in the selectionthat are on
	-- the side in the options
	for _, Item in pairs( Selection.Items ) do

		if self.Options.mode == "texture" then
			local textures = _getChildrenOfClass( Item, "Texture" );
			for _, Texture in pairs( textures ) do
				if Texture.Face == self.Options.side then
					Texture.Transparency = new_transparency;
				end;
			end;

		elseif self.Options.mode == "decal" then
			local decals = _getChildrenOfClass( Item, "Decal" );
			for _, Decal in pairs( decals ) do
				if Decal.Face == self.Options.side then
					Decal.Transparency = new_transparency;
				end;
			end;
		end;

	end;

end;

Tools.Texture.changeFrequency = function ( self, direction, new_frequency )

	-- Apply the new frequency to any items w/ textures
	-- in the selection that are on the side in the options
	for _, Item in pairs( Selection.Items ) do
		local textures = _getChildrenOfClass( Item, "Texture" );
		for _, Texture in pairs( textures ) do
			if Texture.Face == self.Options.side then

				-- Apply the new frequency to the right direction
				if direction == "x" then
					Texture.StudsPerTileU = new_frequency;
				elseif direction == "y" then
					Texture.StudsPerTileV = new_frequency;
				end;

			end;
		end;
	end;

end;

Tools.Texture.addTexture = function ( self )

	for _, Item in pairs( Selection.Items ) do

		-- Check if the item has a texture already
		local textures = _getChildrenOfClass( Item, "Texture" );
		local has_texture = false;
		for _, Texture in pairs( textures ) do
			if Texture.Face == self.Options.side then
				has_texture = true;
				break;
			end;
		end;

		-- Only add a texture if it doesn't already exist
		if not has_texture then
			RbxUtility.Create "Texture" {
				Parent = Item;
				Face = self.Options.side;
			};
		end;

	end;

end;

Tools.Texture.addDecal = function ( self )

	for _, Item in pairs( Selection.Items ) do

		-- Check if the item has a decal already
		local decals = _getChildrenOfClass( Item, "Decal" );
		local has_decal = false;
		for _, Decal in pairs( decals ) do
			if Decal.Face == self.Options.side then
				has_decal = true;
				break;
			end;
		end;

		-- Only add a decal if it doesn't already exist
		if not has_decal then
			RbxUtility.Create "Decal" {
				Parent = Item;
				Face = self.Options.side;
			};
		end;

	end;

end;

Tools.Texture.removeTexture = function ( self )

	-- Remove any textures on the selected side
	for _, Item in pairs( Selection.Items ) do
		local textures = _getChildrenOfClass( Item, "Texture" );
		for _, Texture in pairs( textures ) do
			if Texture.Face == self.Options.side then
				Texture:Destroy();
			end;
		end;
	end;

end;

Tools.Texture.removeDecal = function ( self )

	-- Remove any decals on the selected side
	for _, Item in pairs( Selection.Items ) do
		local decals = _getChildrenOfClass( Item, "Decal" );
		for _, Decal in pairs( decals ) do
			if Decal.Face == self.Options.side then
				Decal:Destroy();
			end;
		end;
	end;

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
				local textures_found = _getChildrenOfClass( Item, "Texture" );
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
				self.GUI.TransparencyOption.TransparencyInput.TextBox.Text = texture_transparency and _round( texture_transparency, 2 ) or "*";
			end;
			if not self.State.rep_x_focused then
				self.GUI.RepeatOption.XInput.TextBox.Text = texture_repeat_x and _round( texture_repeat_x, 2 ) or "*";
			end;
			if not self.State.rep_y_focused then
				self.GUI.RepeatOption.YInput.TextBox.Text = texture_repeat_y and _round( texture_repeat_y, 2 ) or "*";
			end;

		elseif self.Options.mode == "decal" then

			-- Get the applicable decals
			local decals = {};
			for _, Item in pairs( Selection.Items ) do
				local decals_found = _getChildrenOfClass( Item, "Decal" );
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
				self.GUI.TransparencyOption.TransparencyInput.TextBox.Text = decal_transparency and _round( decal_transparency, 2 ) or "*";
			end;

		end;
	end;

end;

Tools.Texture.showGUI = function ( self )

	-- Initialize the GUI if it's not ready yet
	if not self.GUI then
		local Container = Tool:WaitForChild( "BTTextureToolGUI" ):Clone();
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

------------------------------------------
-- Provide an interface to the 2D
-- selection system
------------------------------------------

Select2D = {

	-- Keep state data
	["enabled"] = false;

	-- Keep objects
	["GUI"] = nil;

	-- Keep temporary, disposable connections
	["Connections"] = {};

	-- Provide an interface to the functions
	["start"] = function ( self )

		if enabled then
			return;
		end;

		self.enabled = true;

		-- Create the GUI
		self.GUI = RbxUtility.Create "ScreenGui" {
			Name = "BTSelectionRectangle";
			Parent = UI;
		};

		local Rectangle = RbxUtility.Create "Frame" {
			Name = "Rectangle";
			Active = false;
			Parent = self.GUI;
			BackgroundColor3 = Color3.new( 0, 0, 0 );
			BackgroundTransparency = 0.5;
			BorderSizePixel = 0;
			Position = UDim2.new( 0, math.min( click_x, Mouse.X ), 0, math.min( click_y, Mouse.Y ) );
			Size = UDim2.new( 0, math.max( click_x, Mouse.X ) - math.min( click_x, Mouse.X ), 0, math.max( click_y, Mouse.Y ) - math.min( click_y, Mouse.Y ) );
		};

		-- Listen for when to resize the selection
		self.Connections.SelectionResize = Mouse.Move:connect( function ()
			Rectangle.Position = UDim2.new( 0, math.min( click_x, Mouse.X ), 0, math.min( click_y, Mouse.Y ) );
			Rectangle.Size = UDim2.new( 0, math.max( click_x, Mouse.X ) - math.min( click_x, Mouse.X ), 0, math.max( click_y, Mouse.Y ) - math.min( click_y, Mouse.Y ) );
		end );

		-- Listen for when the selection ends
		self.Connections.SelectionEnd = Mouse.Button1Up:connect( function ()
			self:select();
			self:finish();
		end );

	end;

	["select"] = function ( self )

		if not self.enabled then
			return;
		end;

		for _, Object in pairs( _getAllDescendants( Services.Workspace ) ) do

			-- Make sure we can select this part
			if Object:IsA( "BasePart" ) and not Object.Locked then

				-- Check if the part is rendered within the range of the selection area
				local PartPosition = _pointToScreenSpace( Object.Position );
				if PartPosition then
					local left_check = PartPosition.x >= self.GUI.Rectangle.AbsolutePosition.x;
					local right_check = PartPosition.x <= ( self.GUI.Rectangle.AbsolutePosition.x + self.GUI.Rectangle.AbsoluteSize.x );
					local top_check = PartPosition.y >= self.GUI.Rectangle.AbsolutePosition.y;
					local bottom_check = PartPosition.y <= ( self.GUI.Rectangle.AbsolutePosition.y + self.GUI.Rectangle.AbsoluteSize.y );

					-- If the part is within the selection area, select it
					if left_check and right_check and top_check and bottom_check then
						Selection:add( Object );
					end;
				end;

			end;

		end;

	end;

	["finish"] = function ( self )

		if not self.enabled then
			return;
		end;

		-- Disconnect temporary connections
		for connection_index, Connection in pairs( self.Connections ) do
			Connection:disconnect();
			self.Connections[connection_index] = nil;
		end;

		-- Remove temporary objects
		self.GUI:Destroy();
		self.GUI = nil;

		self.enabled = false;

	end;

};

------------------------------------------
-- Provide an interface to the edge
-- selection system
------------------------------------------
SelectEdge = {

	-- Keep state data
	["enabled"] = false;
	["started"] = false;

	-- Keep objects
	["Marker"] = nil;
	["MarkerOutline"] = RbxUtility.Create "SelectionBox" {
		Color = BrickColor.new( "Institutional white" );
		Parent = UI;
		Name = "BTEdgeSelectionMarkerOutline";
	};

	-- Keep temporary, disposable connections
	["Connections"] = {};

	-- Provide an interface to the functions
	["start"] = function ( self, edgeSelectionCallback )

		if self.started then
			return;
		end;

		-- Listen for when to engage in selection
		self.Connections.KeyListener = Mouse.KeyDown:connect( function ( key )

			local key = key:lower();
			local key_code = key:byte();

			if key == "e" and #Selection.Items > 0 then
				self:enable( edgeSelectionCallback );
			end;

		end );

		self.started = true;

	end;

	["enable"] = function ( self, edgeSelectionCallback )

		if self.enabled then
			return;
		end;

		self.Connections.MoveListener = Mouse.Move:connect( function ()

			-- Make sure the target can be selected
			if not Selection:find( Mouse.Target ) then
				return;
			end;

			-- Calculate the proximity to each edge
			local Proximity = {};
			local edges = {};

			-- Create shortcuts to certain things that are expensive to call constantly
			local table_insert = table.insert;
			local newCFrame = CFrame.new;
			local PartCFrame = Mouse.Target.CFrame;
			local partCFrameOffset = PartCFrame.toWorldSpace;
			local PartSize = Mouse.Target.Size / 2;
			local size_x, size_y, size_z = PartSize.x, PartSize.y, PartSize.z;

			table_insert( edges, partCFrameOffset( PartCFrame, newCFrame( size_x, size_y, size_z ) ) );
			table_insert( edges, partCFrameOffset( PartCFrame, newCFrame( -size_x, size_y, size_z ) ) );
			table_insert( edges, partCFrameOffset( PartCFrame, newCFrame( size_x, -size_y, size_z ) ) );
			table_insert( edges, partCFrameOffset( PartCFrame, newCFrame( size_x, size_y, -size_z ) ) );
			table_insert( edges, partCFrameOffset( PartCFrame, newCFrame( -size_x, size_y, -size_z ) ) );
			table_insert( edges, partCFrameOffset( PartCFrame, newCFrame( -size_x, -size_y, size_z ) ) );
			table_insert( edges, partCFrameOffset( PartCFrame, newCFrame( size_x, -size_y, -size_z ) ) );
			table_insert( edges, partCFrameOffset( PartCFrame, newCFrame( -size_x, -size_y, -size_z ) ) );
			table_insert( edges, partCFrameOffset( PartCFrame, newCFrame( size_x, size_y, 0 ) ) );
			table_insert( edges, partCFrameOffset( PartCFrame, newCFrame( size_x, 0, size_z ) ) );
			table_insert( edges, partCFrameOffset( PartCFrame, newCFrame( 0, size_y, size_z ) ) );
			table_insert( edges, partCFrameOffset( PartCFrame, newCFrame( size_x, 0, 0 ) ) );
			table_insert( edges, partCFrameOffset( PartCFrame, newCFrame( 0, size_y, 0 ) ) );
			table_insert( edges, partCFrameOffset( PartCFrame, newCFrame( 0, 0, size_z ) ) );
			table_insert( edges, partCFrameOffset( PartCFrame, newCFrame( -size_x, size_y, 0 ) ) );
			table_insert( edges, partCFrameOffset( PartCFrame, newCFrame( -size_x, 0, size_z ) ) );
			table_insert( edges, partCFrameOffset( PartCFrame, newCFrame( 0, -size_y, size_z ) ) );
			table_insert( edges, partCFrameOffset( PartCFrame, newCFrame( -size_x, 0, 0 ) ) );
			table_insert( edges, partCFrameOffset( PartCFrame, newCFrame( 0, -size_y, 0 ) ) );
			table_insert( edges, partCFrameOffset( PartCFrame, newCFrame( 0, 0, -size_z ) ) );
			table_insert( edges, partCFrameOffset( PartCFrame, newCFrame( size_x, -size_y, 0 ) ) );
			table_insert( edges, partCFrameOffset( PartCFrame, newCFrame( size_x, 0, -size_z ) ) );
			table_insert( edges, partCFrameOffset( PartCFrame, newCFrame( 0, size_y, -size_z ) ) );
			table_insert( edges, partCFrameOffset( PartCFrame, newCFrame( -size_x, -size_y, 0 ) ) );
			table_insert( edges, partCFrameOffset( PartCFrame, newCFrame( -size_x, 0, -size_z ) ) );
			table_insert( edges, partCFrameOffset( PartCFrame, newCFrame( 0, -size_y, -size_z ) ) );

			-- Calculate the proximity of every edge to the mouse
			for edge_index, Edge in pairs( edges ) do
				Proximity[edge_index] = ( Mouse.Hit.p - Edge.p ).magnitude;
			end;

			-- Get the closest edge to the mouse
			local highest_proximity = 1;
			for proximity_index, proximity in pairs( Proximity ) do
				if proximity < Proximity[highest_proximity] then
					highest_proximity = proximity_index;
				end;
			end;

			-- Replace the current target edge (if any)
			local ClosestEdge = edges[highest_proximity];

			if self.Marker then
				self.Marker:Destroy();
			end;
			self.Marker = RbxUtility.Create "Part" {
				Name = "BTEdgeSelectionMarker";
				Anchored = true;
				Locked = true;
				CanCollide = false;
				Transparency = 1;
				FormFactor = Enum.FormFactor.Custom;
				Size = Vector3.new( 0.2, 0.2, 0.2 );
				CFrame = ClosestEdge;
			};

			self.MarkerOutline.Adornee = self.Marker;

		end );

		self.Connections.ClickListener = Mouse.Button1Up:connect( function ()
			override_selection = true;
			self:select( edgeSelectionCallback );
		end );

		self.enabled = true;

	end;

	["select"] = function ( self, callback )

		if not self.enabled or not self.Marker then
			return;
		end;

		-- Turn the marker into an actual part of the selection
		self.Marker.Parent = Services.Workspace.CurrentCamera;
		self.MarkerOutline.Adornee = self.Marker;

		callback( self.Marker );

		-- Stop treating it like a marker
		self.Marker = nil;

		self:disable();

	end;

	["disable"] = function ( self )

		if not self.enabled then
			return;
		end;

		-- Disconnect unnecessary temporary connections
		if self.Connections.ClickListener then
			self.Connections.ClickListener:disconnect();
			self.Connections.ClickListener = nil;
		end;
		if self.Connections.MoveListener then
			self.Connections.MoveListener:disconnect();
			self.Connections.MoveListener = nil;
		end;

		-- Remove temporary objects
		if self.Marker then
			self.Marker:Destroy();
		end;
		self.Marker = nil;

		self.MarkerOutline.Adornee = nil;
		self.enabled = false;

	end;

	["stop"] = function ( self )

		if not self.started then
			return;
		end;

		-- Disconnect & remove all temporary connections
		for connection_index, Connection in pairs( self.Connections ) do
			Connection:disconnect();
			self.Connections[connection_index] = nil;
		end;

		-- Remove temporary objects
		if self.Marker then
			self.Marker:Destroy();
		end;

		self.started = false;

	end;

};

------------------------------------------
-- Provide an interface to the history
-- system
------------------------------------------
History = {

	-- Keep a container for the actual history data
	["Data"] = {};

	-- Keep state data
	["index"] = 0;

	-- Provide functions to control the system
	["undo"] = function ( self )

		-- Make sure we're not getting out of boundary
		if self.index - 1 < 0 then
			return;
		end;

		-- Fetch the history record & unapply it
		local CurrentRecord = self.Data[self.index];
		CurrentRecord:unapply();

		-- Go back in the history
		self.index = self.index - 1;

	end;

	["redo"] = function ( self )

		-- Make sure we're not getting out of boundary
		if self.index + 1 > #self.Data then
			return;
		end;

		-- Go forward in the history
		self.index = self.index + 1;

		-- Fetch the new history record & apply it
		local NewRecord = self.Data[self.index];
		NewRecord:apply();

	end;

	["add"] = function ( self, Record )

		-- Place the record in its right spot
		self.Data[self.index + 1] = Record;

		-- Advance the history index
		self.index = self.index + 1;

		-- Clear out the following history
		for index = self.index + 1, #self.Data do
			self.Data[index] = nil;
		end;

	end;

};

------------------------------------------
-- Provide an interface to the
-- import/export system
------------------------------------------

IE = {

	["export"] = function ()

		local serialized_selection = _serializeParts( Selection.Items );

		-- Dump to logs
		Services.TestService:Warn( false, "[Building Tools by F3X] Exported Model: \n" .. serialized_selection );

		-- Get ready to upload to the web for retrieval
		local upload_data;
		local cancelUpload;

		-- Create the export dialog
		local Dialog = Tool.BTExportDialog:Clone();
		Dialog.Loading.Size = UDim2.new( 1, 0, 0, 0 );
		Dialog.Parent = UI;
		Dialog.Loading:TweenSize( UDim2.new( 1, 0, 0, 80 ), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.25 );
		Dialog.Loading.CloseButton.MouseButton1Up:connect( function ()
			cancelUpload();
			Dialog:Destroy();
		end );

		-- Run the upload/post-upload/failure code in a coroutine
		-- so it can be cancelled
		coroutine.resume( coroutine.create( function ()
			cancelUpload = function ()
				coroutine.yield();
			end;
			local upload_attempt = ypcall( function ()
				upload_data = PostAsync( "http://www.f3xteam.com/bt/export", serialized_selection );
			end );

			-- Fail graciously
			if not upload_attempt then
				Dialog.Loading.TextLabel.Text = "Upload failed";
				Dialog.Loading.CloseButton.Text = 'Ok :(';
				return;
			end;
			if not ( upload_data and type( upload_data ) == 'string' and upload_data:len() > 0 ) then
				Dialog.Loading.TextLabel.Text = "Upload failed";
				Dialog.Loading.CloseButton.Text = 'Ok ;(';
				return;
			end;
			if not pcall( function () upload_data = RbxUtility.DecodeJSON( upload_data ); end ) or not upload_data then
				Dialog.Loading.TextLabel.Text = "Upload failed";
				Dialog.Loading.CloseButton.Text = "Ok :'(";
				return;
			end;
			if not upload_data.success then
				Dialog.Loading.TextLabel.Text = "Upload failed";
				Dialog.Loading.CloseButton.Text = "Ok :''(";
			end;

			Dialog.Loading.Visible = false;
			Dialog.Info.Size = UDim2.new( 1, 0, 0, 0 );
			Dialog.Info.CreationID.Text = upload_data.id;
			Dialog.Info.Visible = true;
			Dialog.Info:TweenSize( UDim2.new( 1, 0, 0, 75 ), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.25 );
			Dialog.Tip.Size = UDim2.new( 1, 0, 0, 0 );
			Dialog.Tip.Visible = true;
			Dialog.Tip:TweenSize( UDim2.new( 1, 0, 0, 30 ), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.25 );
			Dialog.Close.Size = UDim2.new( 1, 0, 0, 0 );
			Dialog.Close.Visible = true;
			Dialog.Close:TweenSize( UDim2.new( 1, 0, 0, 20 ), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.25 );
			Dialog.Close.Button.MouseButton1Up:connect( function ()
				Dialog:Destroy();
			end );

			-- Play a confirmation sound
			local Sound = RbxUtility.Create "Sound" {
				Name = "BTActionCompletionSound";
				Pitch = 1.5;
				SoundId = action_completion_sound;
				Volume = 1;
				Parent = Player;
			};
			Sound:Play();
			Sound:Destroy();
		end ) );

	end;

};

------------------------------------------
-- Attach listeners
------------------------------------------

Tool.Equipped:connect( function ( CurrentMouse )

	Mouse = CurrentMouse;

	if not TargetBox then
		TargetBox = Instance.new( "SelectionBox", UI );
		TargetBox.Name = "BTTargetBox";
		TargetBox.Color = BrickColor.new( "Institutional white" );
	end;

	-- Enable any temporarily-disabled selection boxes
	for _, SelectionBox in pairs( SelectionBoxes ) do
		SelectionBox.Parent = UI;
	end;

	-- Call the `Equipped` listener of the current tool
	if CurrentTool and CurrentTool.Listeners.Equipped then
		CurrentTool.Listeners.Equipped();
	end;

	table.insert( Connections, Mouse.KeyDown:connect( function ( key )

		local key = key:lower();
		local key_code = key:byte();

		-- Provide the abiltiy to delete via the shift + X key combination
		if ActiveKeys[47] or ActiveKeys[48] and key == "x" then

			local selection_items = _cloneTable( Selection.Items );

			-- Create a history record
			local HistoryRecord = {
				targets = selection_items;
				parents = {};
				apply = function ( self )
					for _, Target in pairs( self.targets ) do
						if Target then
							Target.Parent = nil;
						end;
					end;
				end;
				unapply = function ( self )
					Selection:clear();
					for _, Target in pairs( self.targets ) do
						if Target then
							Target.Parent = self.parents[Target];
							Target:MakeJoints();
							Selection:add( Target );
						end;
					end;
				end;
			};

			for _, Item in pairs( selection_items ) do
				HistoryRecord.parents[Item] = Item.Parent;
				Item.Parent = nil;
			end;

			History:add( HistoryRecord );

			return;
		end;

		-- Provide the ability to clone via the shift + C key combination
		if ActiveKeys[47] or ActiveKeys[48] and key == "c" then

			-- Make sure that there are items in the selection
			if #Selection.Items > 0 then

				local item_copies = {};

				-- Make a copy of every item in the selection and add it to table `item_copies`
				for _, Item in pairs( Selection.Items ) do
					local ItemCopy = Item:Clone();
					ItemCopy.Parent = Services.Workspace;
					table.insert( item_copies, ItemCopy );
				end;

				-- Replace the selection with the copied items
				Selection:clear();
				for _, Item in pairs( item_copies ) do
					Selection:add( Item );
				end;

				local HistoryRecord = {
					copies = item_copies;
					unapply = function ( self )
						for _, Copy in pairs( self.copies ) do
							if Copy then
								Copy.Parent = nil;
							end;
						end;
					end;
					apply = function ( self )
						Selection:clear();
						for _, Copy in pairs( self.copies ) do
							if Copy then
								Copy.Parent = Services.Workspace;
								Copy:MakeJoints();
								Selection:add( Copy );
							end;
						end;
					end;
				};
				History:add( HistoryRecord );

				-- Play a confirmation sound
				local Sound = RbxUtility.Create "Sound" {
					Name = "BTActionCompletionSound";
					Pitch = 1.5;
					SoundId = action_completion_sound;
					Volume = 1;
					Parent = Player;
				};
				Sound:Play();
				Sound:Destroy();

				-- Highlight the outlines of the new parts
				coroutine.wrap( function ()
					for transparency = 1, 0, -0.1 do
						for Item, SelectionBox in pairs( SelectionBoxes ) do
							SelectionBox.Transparency = transparency;
						end;
						wait( 0.1 );
					end;
				end )();

			end;

			return;

		end;

		if key == "z" and not ( ActiveKeys[47] or ActiveKeys[48] ) then
			equipTool( Tools.Move );

		elseif key == "x" then
			equipTool( Tools.Resize );

		elseif key == "c" then
			equipTool( Tools.Rotate );

		elseif key == "v" then
			equipTool( Tools.Paint );

		elseif key == "b" then
			equipTool( Tools.Surface );

		elseif key == "n" then
			equipTool( Tools.Material );

		elseif key == "m" then
			equipTool( Tools.Anchor );

		elseif key == "k" then
			equipTool( Tools.Collision );

		elseif key == "j" then
			equipTool( Tools.NewPart );

		elseif key == "h" then
			equipTool( Tools.Mesh );

		elseif key == "g" then
			equipTool( Tools.Texture );

		elseif key == "q" then
			Selection:clear();

		end;

		-- Undo if shift+z is pressed
		if key == "z" and ( ActiveKeys[47] or ActiveKeys[48] ) then
			History:undo();

		-- Redo if shift+y is pressed
		elseif key == "y" and ( ActiveKeys[47] or ActiveKeys[48] ) then
			History:redo();
		end;

		-- Serialize and dump selection to logs if shift+p is pressed
		if key == "p" and ( ActiveKeys[47] or ActiveKeys[48] ) then
			IE:export();
		end;

		ActiveKeys[key_code] = key_code;
		ActiveKeys[key] = key;

		-- If it's now in multiselection mode, update `selecting`
		-- (these are the left/right ctrl & shift keys)
		if ActiveKeys[47] or ActiveKeys[48] or ActiveKeys[49] or ActiveKeys[50] then
			selecting = ActiveKeys[47] or ActiveKeys[48] or ActiveKeys[49] or ActiveKeys[50];
		end;

	end ) );

	table.insert( Connections, Mouse.KeyUp:connect( function ( key )

		local key = key:lower();
		local key_code = key:byte();

		ActiveKeys[key_code] = nil;
		ActiveKeys[key] = nil;

		-- If it's no longer in multiselection mode, update `selecting` & related values
		if selecting and not ActiveKeys[selecting] then
			selecting = false;
			if Select2D.enabled then
				Select2D:select();
				Select2D:finish();
			end;
		end;

		-- Fire tool listeners
		if CurrentTool and CurrentTool.Listeners.KeyUp then
			CurrentTool.Listeners.KeyUp( key );
		end;

	end ) );

	table.insert( Connections, Mouse.Button1Down:connect( function ()

		clicking = true;
		click_x, click_y = Mouse.X, Mouse.Y;

		-- If multiselection is, just add to the selection
		if selecting then
			return;
		end;

		-- Fire tool listeners
		if CurrentTool and CurrentTool.Listeners.Button1Down then
			CurrentTool.Listeners.Button1Down();
		end;

	end ) );

	table.insert( Connections, Mouse.Move:connect( function ()

		-- If the mouse has moved since it was clicked, start 2D selection mode
		if not override_selection and not Select2D.enabled and clicking and selecting and ( click_x ~= Mouse.X or click_y ~= Mouse.Y ) then
			Select2D:start();
		end;

		-- If the target has changed, update the selectionbox appropriately
		if not override_selection and Mouse.Target then
			if Mouse.Target:IsA( "BasePart" ) and not Mouse.Target.Locked and TargetBox.Adornee ~= Mouse.Target and not Selection:find( Mouse.Target ) then
				TargetBox.Adornee = Mouse.Target;
			end;
		end;

		-- When aiming at something invalid, don't highlight any targets
		if not override_selection and not Mouse.Target or ( Mouse.Target and Mouse.Target:IsA( "BasePart" ) and Mouse.Target.Locked ) or Selection:find( Mouse.Target ) then
			TargetBox.Adornee = nil;
		end;

		-- Fire tool listeners
		if CurrentTool and CurrentTool.Listeners.Move then
			CurrentTool.Listeners.Move();
		end;

		if override_selection then
			override_selection = false;
		end;

	end ) );

	table.insert( Connections, Mouse.Button1Up:connect( function ()

		clicking = false;

		-- Make sure the person didn't accidentally miss a handle or something
		if not Select2D.enabled and ( Mouse.X ~= click_x or Mouse.Y ~= click_y ) then
			override_selection = true;
		end;

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
		if CurrentTool and CurrentTool.Listeners.Button1Up then
			CurrentTool.Listeners.Button1Up();
		end;

		if override_selection then
			override_selection = false;
		end;

	end ) );

	table.insert( Connections, Mouse.Button2Down:connect( function ()
		-- Fire tool listeners
		if CurrentTool and CurrentTool.Listeners.Button2Down then
			CurrentTool.Listeners.Button2Down();
		end;
	end ) );

	table.insert( Connections, Mouse.Button2Up:connect( function ()
		-- Fire tool listeners
		if CurrentTool and CurrentTool.Listeners.Button2Up then
			CurrentTool.Listeners.Button2Up();
		end;
	end ) );

end );

Tool.Unequipped:connect( function ()

	Mouse = nil;

	-- Remove the mouse target SelectionBox from `Player`
	if TargetBox then
		TargetBox:Destroy();
		TargetBox = nil;
	end;

	-- Disable all the selection boxes temporarily
	for _, SelectionBox in pairs( SelectionBoxes ) do
		SelectionBox.Parent = nil;
	end;

	-- Disconnect temporary platform-related connections
	for connection_index, Connection in pairs( Connections ) do
		Connection:disconnect();
		Connections[connection_index] = nil;
	end;

	-- Call the `Unequipped` listener of the current tool
	if CurrentTool and CurrentTool.Listeners.Unequipped then
		CurrentTool.Listeners.Unequipped();
	end;

end );

-- Enable `Tools.Move` as the first tool
equipTool( Tools.Move );