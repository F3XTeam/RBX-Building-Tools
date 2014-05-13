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
	["Selection"] = Game:GetService( "Selection" );
	["CoreGui"] = Game:GetService( "CoreGui" );
};

Tool = script.Parent;
Player = Services.Players.LocalPlayer;
Mouse = nil;

-- Determine whether this is the plugin or tool
if plugin then
	ToolType = 'plugin';
elseif Tool:IsA( 'Tool' ) then
	ToolType = 'tool';
end;

-- Get tool type-specific resources
if ToolType == 'tool' then
	GUIContainer = Player:WaitForChild( 'PlayerGui' );
	in_server = not not Game:FindFirstChild( 'NetworkClient' );
elseif ToolType == 'plugin' then
	GUIContainer = Services.CoreGui;
	in_server = not not Game:FindFirstChild( 'NetworkServer' );
end;
if in_server then
	Tool:WaitForChild( "GetAsync" );
	Tool:WaitForChild( "PostAsync" );
	GetAsync = function ( ... )
		return Tool.GetAsync:InvokeServer( ... );
	end;
	PostAsync = function ( ... )
		return Tool.PostAsync:InvokeServer( ... );
	end;
end;

dark_slanted_rectangle = "http://www.roblox.com/asset/?id=127774197";
light_slanted_rectangle = "http://www.roblox.com/asset/?id=127772502";
action_completion_sound = "http://www.roblox.com/asset/?id=99666917";
expand_arrow = "http://www.roblox.com/asset/?id=134367382";
tool_decal = "http://www.roblox.com/asset/?id=129748355";
undo_active_decal = "http://www.roblox.com/asset/?id=141741408";
undo_inactive_decal = "http://www.roblox.com/asset/?id=142074557";
redo_active_decal = "http://www.roblox.com/asset/?id=141741327";
redo_inactive_decal = "http://www.roblox.com/asset/?id=142074553";
delete_active_decal = "http://www.roblox.com/asset/?id=141896298";
delete_inactive_decal = "http://www.roblox.com/asset/?id=142074644";
export_active_decal = "http://www.roblox.com/asset/?id=141741337";
export_inactive_decal = "http://www.roblox.com/asset/?id=142074569";
clone_active_decal = "http://www.roblox.com/asset/?id=142073926";
clone_inactive_decal = "http://www.roblox.com/asset/?id=142074563";
plugin_icon = "http://www.roblox.com/asset/?id=142287521";

------------------------------------------
-- Load external dependencies
------------------------------------------
RbxUtility = LoadLibrary( "RbxUtility" );
Services.ContentProvider:Preload( dark_slanted_rectangle );
Services.ContentProvider:Preload( light_slanted_rectangle );
Services.ContentProvider:Preload( action_completion_sound );
Services.ContentProvider:Preload( expand_arrow );
Services.ContentProvider:Preload( tool_decal );
Services.ContentProvider:Preload( undo_active_decal );
Services.ContentProvider:Preload( undo_inactive_decal );
Services.ContentProvider:Preload( redo_inactive_decal );
Services.ContentProvider:Preload( redo_active_decal );
Services.ContentProvider:Preload( delete_active_decal );
Services.ContentProvider:Preload( delete_inactive_decal );
Services.ContentProvider:Preload( export_active_decal );
Services.ContentProvider:Preload( export_inactive_decal );
Services.ContentProvider:Preload( clone_active_decal );
Services.ContentProvider:Preload( clone_inactive_decal );
Services.ContentProvider:Preload( plugin_icon );
Tool:WaitForChild( "Interfaces" );
repeat wait( 0 ) until _G.gloo;
Gloo = _G.gloo;

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

	local point = Services.Workspace.CurrentCamera.CoordinateFrame:pointToObjectSpace( Point );
	local aspectRatio = Mouse.ViewSizeX / Mouse.ViewSizeY;
	local hfactor = math.tan( math.rad( Services.Workspace.CurrentCamera.FieldOfView ) / 2 )
	local wfactor = aspectRatio * hfactor;

	local x = ( point.x / point.z ) / -wfactor;
	local y = ( point.y / point.z ) /  hfactor;

	local screen_pos = Vector2.new( Mouse.ViewSizeX * ( 0.5 + 0.5 * x ), Mouse.ViewSizeY * ( 0.5 + 0.5 * y ) );
	if ( screen_pos.x < 0 or screen_pos.x > Mouse.ViewSizeX ) or ( screen_pos.y < 0 or screen_pos.y > Mouse.ViewSizeY ) then
		return nil;
	end;
	if Services.Workspace.CurrentCamera.CoordinateFrame:toObjectSpace( CFrame.new( Point ) ).z > 0 then
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

	-- Get any welds in the selection
	local welds = {};
	for object_id, Object in pairs( objects ) do
		if Object:IsA( "BasePart" ) then
			for _, Joint in pairs( _getAllDescendants( Services.Workspace ) ) do
				if Joint:IsA( "Weld" ) and Joint.Name == "BTWeld" then
					if Joint.Part0 == Object and #_findTableOccurrences( objects, Joint.Part1 ) > 0 then
						table.insert( welds, Joint );
					end;
				end;
			end;
		end;
	end;

	-- Serialize any welds
	if #welds > 0 then
		data.welds = {};
		for _, Weld in pairs( welds ) do
			local weld_id = _generateSerializationID();
			local WeldData = {
				_findTableOccurrences( objects, Weld.Part0 )[1],
				_findTableOccurrences( objects, Weld.Part1 )[1],
				_splitNumberListString( tostring( Weld.C1 ) )
			};
			data.welds[weld_id] = WeldData;
			objects[weld_id] = Weld;
		end;
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

	-- Get any lights in the selection
	local lights = {};
	for _, Part in pairs( parts ) do
		local lights_found = _getChildrenOfClass( Part, "Light", true );
		for _, Light in pairs( lights_found ) do
			table.insert( lights, Light );
		end;
	end;

	-- Serialize any lights
	if #lights > 0 then
		data.lights = {};
		for _, Light in pairs( lights ) do
			local light_type;
			if Light:IsA( "PointLight" ) then
				light_type = 1;
			elseif Light:IsA( "SpotLight" ) then
				light_type = 2;
			end;
			local light_id = _generateSerializationID();
			local LightData = {
				_findTableOccurrences( objects, Light.Parent )[1];
				light_type,
				_splitNumberListString( tostring( Light.Color ) ),
				Light.Brightness,
				Light.Range,
				Light.Shadows,
				light_type == 2 and Light.Angle or nil,
				light_type == 2 and Light.Face.Value or nil
			};
			data.lights[light_id] = LightData;
			objects[light_id] = Light;
		end;
	end;

	-- Get any decorations in the selection
	local decorations = {};
	for _, Part in pairs( parts ) do
		table.insert( decorations, _getChildOfClass( Part, 'Smoke' ) )
		table.insert( decorations, _getChildOfClass( Part, 'Fire' ) );
		table.insert( decorations, _getChildOfClass( Part, 'Sparkles' ) );
	end;

	-- Serialize any decorations
	if #decorations > 0 then
		data.decorations = {};
		for _, Decoration in pairs( decorations ) do
			local decoration_type;
			if Decoration:IsA( 'Smoke' ) then
				decoration_type = 1;
			elseif Decoration:IsA( 'Fire' ) then
				decoration_type = 2;
			elseif Decoration:IsA( 'Sparkles' ) then
				decoration_type = 3;
			end;
			local decoration_id = _generateSerializationID();
			local DecorationData = {
				_findTableOccurrences( objects, Decoration.Parent )[1],
				decoration_type
			};
			if decoration_type == 1 then
				DecorationData[3] = _splitNumberListString( tostring( Decoration.Color ) );
				DecorationData[4] = Decoration.Opacity;
				DecorationData[5] = Decoration.RiseVelocity;
				DecorationData[6] = Decoration.Size;
			elseif decoration_type == 2 then
				DecorationData[3] = _splitNumberListString( tostring( Decoration.Color ) );
				DecorationData[4] = _splitNumberListString( tostring( Decoration.SecondaryColor ) );
				DecorationData[5] = Decoration.Heat;
				DecorationData[6] = Decoration.Size;
			elseif decoration_type == 3 then
				DecorationData[3] = _splitNumberListString( tostring( Decoration.SparkleColor ) );
			end;
			data.decorations[decoration_id] = DecorationData;
			objects[decoration_id] = Decoration;
		end;
	end;

	return RbxUtility.EncodeJSON( data );

end;

function _getChildOfClass( Parent, class_name, inherit )
	-- Returns the first child of `Parent` that is of class `class_name`
	-- or nil if it couldn't find any

	-- Look for a child of `Parent` of class `class_name` and return it
	if not inherit then
		for _, Child in pairs( Parent:GetChildren() ) do
			if Child.ClassName == class_name then
				return Child;
			end;
		end;
	else
		for _, Child in pairs( Parent:GetChildren() ) do
			if Child:IsA( class_name ) then
				return Child;
			end;
		end;
	end;

	return nil;

end;

function _getChildrenOfClass( Parent, class_name, inherit )
	-- Returns a table containing the children of `Parent` that are
	-- of class `class_name`
	local matches = {};


	if not inherit then
		for _, Child in pairs( Parent:GetChildren() ) do
			if Child.ClassName == class_name then
				table.insert( matches, Child );
			end;
		end;
	else
		for _, Child in pairs( Parent:GetChildren() ) do
			if Child:IsA( class_name ) then
				table.insert( matches, Child );
			end;
		end;
	end;

	return matches;
end;

function _HSVToRGB( hue, saturation, value )
	-- Returns the RGB equivalent of the given HSV-defined color
	-- (adapted from some code found around the web)

	-- If it's achromatic, just return the value
	if saturation == 0 then
		return value;
	end;

	-- Get the hue sector
	local hue_sector = math.floor( hue / 60 );
	local hue_sector_offset = ( hue / 60 ) - hue_sector;

	local p = value * ( 1 - saturation );
	local q = value * ( 1 - saturation * hue_sector_offset );
	local t = value * ( 1 - saturation * ( 1 - hue_sector_offset ) );

	if hue_sector == 0 then
		return value, t, p;
	elseif hue_sector == 1 then
		return q, value, p;
	elseif hue_sector == 2 then
		return p, value, t;
	elseif hue_sector == 3 then
		return p, q, value;
	elseif hue_sector == 4 then
		return t, p, value;
	elseif hue_sector == 5 then
		return value, p, q;
	end;
end;

function _RGBToHSV( red, green, blue )
	-- Returns the HSV equivalent of the given RGB-defined color
	-- (adapted from some code found around the web)

	local hue, saturation, value;

	local min_value = math.min( red, green, blue );
	local max_value = math.max( red, green, blue );

	value = max_value;

	local value_delta = max_value - min_value;

	-- If the color is not black
	if max_value ~= 0 then
		saturation = value_delta / max_value;

	-- If the color is purely black
	else
		saturation = 0;
		hue = -1;
		return hue, saturation, value;
	end;

	if red == max_value then
		hue = ( green - blue ) / value_delta;
	elseif green == max_value then
		hue = 2 + ( blue - red ) / value_delta;
	else
		hue = 4 + ( red - green ) / value_delta;
	end;

	hue = hue * 60;
	if hue < 0 then
		hue = hue + 360;
	end;

	return hue, saturation, value;
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
		if ToolType == 'tool' then
			Tool.Handle.BrickColor = NewTool.Color;
		end;

		-- Highlight the right button on the dock
		for _, Button in pairs( Dock.ToolButtons:GetChildren() ) do
			Button.BackgroundTransparency = 1;
		end;
		local Button = Dock.ToolButtons:FindFirstChild( getToolName( NewTool ) .. "Button" );
		if Button then
			Button.BackgroundTransparency = 0;
		end;

		-- Run (if existent) the new tool's `Equipped` listener
		if NewTool.Listeners.Equipped then
			NewTool.Listeners.Equipped();
		end;

	end;
end;

function cloneSelection()
	-- Clones the items in the selection

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
			Parent = Player or Services.SoundService;
		};
		Sound:Play();
		Sound:Destroy();

		-- Highlight the outlines of the new parts
		coroutine.wrap( function ()
			for transparency = 1, 0.5, -0.1 do
				for Item, SelectionBox in pairs( SelectionBoxes ) do
					SelectionBox.Transparency = transparency;
				end;
				wait( 0.1 );
			end;
		end )();

	end;

end;

function deleteSelection()
	-- Deletes the items in the selection

	if #Selection.Items == 0 then
		return;
	end;

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

end;

function prismSelect()
	-- Selects all the parts within the area of the selected parts

	-- Make sure parts to define the area are present
	if #Selection.Items == 0 then
		return;
	end;

	local parts = {};

	-- Get all the parts in workspace
	local workspace_parts = {};
	local workspace_children = _getAllDescendants( Services.Workspace );
	for _, Child in pairs( workspace_children ) do
		if Child:IsA( 'BasePart' ) and not Selection:find( Child ) then
			table.insert( workspace_parts, Child );
		end;
	end;

	-- Go through each part and perform area tests on each one
	local checks = {};
	for _, Item in pairs( workspace_parts ) do
		checks[Item] = 0;
		for _, SelectionItem in pairs( Selection.Items ) do

			-- Calculate the position of the item in question in relation to the area-defining parts
			local offset = SelectionItem.CFrame:toObjectSpace( Item.CFrame );
			local extents = SelectionItem.Size / 2;

			-- Check the item off if it passed this test (if it's within the range of the extents)
			if ( math.abs( offset.x ) <= extents.x ) and ( math.abs( offset.y ) <= extents.y ) and ( math.abs( offset.z ) <= extents.z ) then
				checks[Item] = checks[Item] + 1;
			end;

		end;
	end;

	-- Delete the parts that were used to select the area
	local selection_items = _cloneTable( Selection.Items );
	local selection_item_parents = {};
	for _, Item in pairs( selection_items ) do
		selection_item_parents[Item] = Item.Parent;
		Item.Parent = nil;
	end;

	-- Select the parts that passed any area checks
	for _, Item in pairs( workspace_parts ) do
		if checks[Item] > 0 then
			Selection:add( Item );
		end;
	end;

	-- Add a history record
	History:add( {
		selection_parts = selection_items;
		selection_part_parents = selection_item_parents;
		new_selection = _cloneTable( Selection.Items );
		apply = function ( self )
			Selection:clear();
			for _, Item in pairs( self.selection_parts ) do
				Item.Parent = nil;
			end;
			for _, Item in pairs( self.new_selection ) do
				Selection:add( Item );
			end;
		end;
		unapply = function ( self )
			Selection:clear();
			for _, Item in pairs( self.selection_parts ) do
				Item.Parent = self.selection_part_parents[Item];
				Selection:add( Item );
			end;
		end;
	} );

end;

function toggleHelp()

	-- Make sure the dock is ready
	if not Dock then
		return;
	end;

	-- Toggle the visibility of the help tooltip
	Dock.HelpInfo.Visible = not Dock.HelpInfo.Visible;

end;

function getToolName( tool )
	-- Returns the name of `tool` as registered in `Tools`

	local name_search = _findTableOccurrences( Tools, tool );
	if #name_search > 0 then
		return name_search[1];
	end;

end;

function isSelectable( Object )
	-- Returns whether `Object` is selectable

	if not Object or not Object.Parent or not Object:IsA( "BasePart" ) or Object.Locked or Selection:find( Object ) then
		return false;
	end;

	-- If it passes all checks, return true
	return true;
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

-- Set the grip for the handle
if ToolType == 'tool' then
	Tool.Grip = CFrame.new( 0, 0, 0.4 );
end;

-- Make sure the UI container gets placed
UI = RbxUtility.Create "ScreenGui" {
	Name = "Building Tools by F3X (UI)"
};
if ToolType == 'tool' then
	UI.Parent = GUIContainer;
elseif ToolType == 'plugin' then
	UI.Parent = Services.CoreGui;
end;

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

		-- Make sure `NewPart` is selectable
		if not isSelectable( NewPart ) then
			return false;
		end;

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
		SelectionBoxes[NewPart].Transparency = 0.5;

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

-- Keep the Studio selection up-to-date (if applicable)
if ToolType == 'plugin' then
	Selection.Changed:connect( function ()
		Services.Selection:Set( Selection.Items );
	end );
end;

Tools = {};

------------------------------------------
-- Define other utilities needed by tools
------------------------------------------

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
			if isSelectable( Object ) then

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

			if key == "t" and #Selection.Items > 0 then
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

		-- Cancel any ongoing selection
		self:disable();

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

	-- Provide events for the platform to listen for changes
	["Changed"] = RbxUtility.CreateSignal();

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

		-- Fire the relevant events
		self.Changed:fire();

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

		-- Fire the relevant events
		self.Changed:fire();

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

		-- Fire the relevant events
		self.Changed:fire();

	end;

};


------------------------------------------
-- Provide an interface color picker
-- system
------------------------------------------
ColorPicker = {
	
	-- Keep some state data
	["enabled"] = false;
	["callback"] = nil;
	["track_mouse"] = nil;
	["hue"] = 0;
	["saturation"] = 1;
	["value"] = 1;

	-- Keep the current GUI here
	["GUI"] = nil;

	-- Keep temporary, disposable connections here
	["Connections"] = {};

	-- Provide an interface to the functions
	["start"] = function ( self, callback, start_color )

		-- Replace any existing color pickers
		if self.enabled then
			self:cancel();
		end;
		self.enabled = true;

		-- Create the GUI
		self.GUI = Tool.Interfaces.BTHSVColorPicker:Clone();
		self.GUI.Parent = UI;

		-- Register the callback function for when we're done here
		self.callback = callback;

		-- Update the GUI
		local start_color = start_color or Color3.new( 1, 0, 0 );
		self:_changeColor( _RGBToHSV( start_color.r, start_color.g, start_color.b ) );

		-- Add functionality to the GUI's interactive elements
		table.insert( self.Connections, self.GUI.HueSaturation.MouseButton1Down:connect( function ( x, y )
			self.track_mouse = 'hue-saturation';
			self:_onMouseMove( x, y );
		end ) );

		table.insert( self.Connections, self.GUI.HueSaturation.MouseButton1Up:connect( function ()
			self.track_mouse = nil;
		end ) );

		table.insert( self.Connections, self.GUI.MouseMoved:connect( function ( x, y )
			self:_onMouseMove( x, y );
		end ) );

		table.insert( self.Connections, self.GUI.Value.MouseButton1Down:connect( function ( x, y )
			self.track_mouse = 'value';
			self:_onMouseMove( x, y );
		end ) );

		table.insert( self.Connections, self.GUI.Value.MouseButton1Up:connect( function ()
			self.track_mouse = nil;
		end ) );

		table.insert( self.Connections, self.GUI.OkButton.MouseButton1Up:connect( function ()
			self:finish();
		end ) );

		table.insert( self.Connections, self.GUI.CancelButton.MouseButton1Up:connect( function ()
			self:cancel();
		end ) );

		table.insert( self.Connections, self.GUI.HueOption.Input.TextButton.MouseButton1Down:connect( function ()
			self.GUI.HueOption.Input.TextBox:CaptureFocus();
		end ) );
		table.insert( self.Connections, self.GUI.HueOption.Input.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( self.GUI.HueOption.Input.TextBox.Text );
			if potential_new then
				if potential_new > 360 then
					potential_new = 360;
				elseif potential_new < 0 then
					potential_new = 0;
				end;
				self:_changeColor( potential_new, self.saturation, self.value );
			else
				self:_updateGUI();
			end;
		end ) );

		table.insert( self.Connections, self.GUI.SaturationOption.Input.TextButton.MouseButton1Down:connect( function ()
			self.GUI.SaturationOption.Input.TextBox:CaptureFocus();
		end ) );
		table.insert( self.Connections, self.GUI.SaturationOption.Input.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( ( self.GUI.SaturationOption.Input.TextBox.Text:gsub( '%%', '' ) ) );
			if potential_new then
				if potential_new > 100 then
					potential_new = 100;
				elseif potential_new < 0 then
					potential_new = 0;
				end;
				self:_changeColor( self.hue, potential_new / 100, self.value );
			else
				self:_updateGUI();
			end;
		end ) );

		table.insert( self.Connections, self.GUI.ValueOption.Input.TextButton.MouseButton1Down:connect( function ()
			self.GUI.ValueOption.Input.TextBox:CaptureFocus();
		end ) );
		table.insert( self.Connections, self.GUI.ValueOption.Input.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( ( self.GUI.ValueOption.Input.TextBox.Text:gsub( '%%', '' ) ) );
			if potential_new then
				if potential_new < 0 then
					potential_new = 0;
				elseif potential_new > 100 then
					potential_new = 100;
				end;
				self:_changeColor( self.hue, self.saturation, potential_new / 100 );
			else
				self:_updateGUI();
			end;
		end ) );

	end;

	["_onMouseMove"] = function ( self, x, y )
		if not self.track_mouse then
			return;
		end;

		if self.track_mouse == 'hue-saturation' then
			-- Calculate the mouse position relative to the graph
			local graph_x, graph_y = x - self.GUI.HueSaturation.AbsolutePosition.x, y - self.GUI.HueSaturation.AbsolutePosition.y;

			-- Make sure we're not going out of bounds
			if graph_x < 0 then
				graph_x = 0;
			elseif graph_x > self.GUI.HueSaturation.AbsoluteSize.x then
				graph_x = self.GUI.HueSaturation.AbsoluteSize.x;
			end;
			if graph_y < 0 then
				graph_y = 0;
			elseif graph_y > self.GUI.HueSaturation.AbsoluteSize.y then
				graph_y = self.GUI.HueSaturation.AbsoluteSize.y;
			end;

			-- Calculate the new color and change it
			self:_changeColor( 359 * graph_x / 209, 1 - graph_y / 200, self.value );

		elseif self.track_mouse == 'value' then
			-- Calculate the mouse position relative to the value bar
			local bar_y = y - self.GUI.Value.AbsolutePosition.y;

			-- Make sure we're not going out of bounds
			if bar_y < 0 then
				bar_y = 0;
			elseif bar_y > self.GUI.Value.AbsoluteSize.y then
				bar_y = self.GUI.Value.AbsoluteSize.y;
			end;

			-- Calculate the new color and change it
			self:_changeColor( self.hue, self.saturation, 1 - bar_y / 200 );
		end;
	end;

	["_changeColor"] = function ( self, hue, saturation, value )
		if hue ~= hue then
			hue = 359;
		end;
		self.hue = hue;
		self.saturation = saturation == 0 and 0.01 or saturation;
		self.value = value;
		self:_updateGUI();
	end;

	["_updateGUI"] = function ( self )

		self.GUI.HueSaturation.Cursor.Position = UDim2.new( 0, 209 * self.hue / 360 - 8, 0, ( 1 - self.saturation ) * 200 - 8 );
		self.GUI.Value.Cursor.Position = UDim2.new( 0, -2, 0, ( 1 - self.value ) * 200 - 8 );

		local color = Color3.new( _HSVToRGB( self.hue, self.saturation, self.value ) );
		self.GUI.ColorDisplay.BackgroundColor3 = color;
		self.GUI.Value.ColorBG.BackgroundColor3 = Color3.new( _HSVToRGB( self.hue, self.saturation, 1 ) );

		self.GUI.HueOption.Bar.BackgroundColor3 = color;
		self.GUI.SaturationOption.Bar.BackgroundColor3 = color;
		self.GUI.ValueOption.Bar.BackgroundColor3 = color;

		self.GUI.HueOption.Input.TextBox.Text = math.floor( self.hue );
		self.GUI.SaturationOption.Input.TextBox.Text = math.floor( self.saturation * 100 ) .. "%";
		self.GUI.ValueOption.Input.TextBox.Text = math.floor( self.value * 100 ) .. "%";

	end;

	["finish"] = function ( self )

		if not self.enabled then
			return;
		end;

		-- Remove the GUI
		if self.GUI then
			self.GUI:Destroy();
		end;
		self.GUI = nil;
		self.track_mouse = nil;

		-- Disconnect all temporary connections
		for connection_index, connection in pairs( self.Connections ) do
			connection:disconnect();
			self.Connections[connection_index] = nil;
		end;

		-- Call the callback function that was provided to us
		self.callback( self.hue, self.saturation, self.value );
		self.callback = nil;

		self.enabled = false;

	end;

	["cancel"] = function ( self )

		if not self.enabled then
			return;
		end;

		-- Remove the GUI
		if self.GUI then
			self.GUI:Destroy();
		end;
		self.GUI = nil;
		self.track_mouse = nil;

		-- Disconnect all temporary connections
		for connection_index, connection in pairs( self.Connections ) do
			connection:disconnect();
			self.Connections[connection_index] = nil;
		end;

		-- Call the callback function that was provided to us
		self.callback();
		self.callback = nil;

		self.enabled = false;

	end;

};

------------------------------------------
-- Provide an interface to the
-- import/export system
------------------------------------------
IE = {

	["export"] = function ()

		if #Selection.Items == 0 then
			return;
		end;

		local serialized_selection = _serializeParts( Selection.Items );

		-- Dump to logs
		-- Services.TestService:Warn( false, "[Building Tools by F3X] Exported Model: \n" .. serialized_selection );

		-- Get ready to upload to the web for retrieval
		local upload_data;
		local cancelUpload;

		-- Create the export dialog
		local Dialog = Tool.Interfaces.BTExportDialog:Clone();
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

			-- Make sure we're in a server
			if ToolType == 'plugin' and not in_server then
				Dialog.Loading.TextLabel.Text = "Use Tools > Test > Start Server to export from Studio";
				Dialog.Loading.TextLabel.TextWrapped = true;
				Dialog.Loading.CloseButton.Position = UDim2.new( 0, 0, 0, 50 );
				Dialog.Loading.CloseButton.Text = 'Got it';
				return;
			end;

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

			print( "[Building Tools by F3X] Uploaded Export: " .. upload_data.id );

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
				Parent = Player or Services.SoundService;
			};
			Sound:Play();
			Sound:Destroy();
		end ) );

	end;

};

------------------------------------------
-- Prepare the dock UI
------------------------------------------

Tooltips = {};

-- Wait for all parts of the base UI to fully replicate
if ToolType == 'tool' then
	local UIComponentCount = (Tool:WaitForChild 'UIComponentCount').Value;
	repeat wait( 0.1 ) until #_getAllDescendants( Tool.Interfaces ) >= UIComponentCount;
end;

-- Create the main GUI
Dock = Tool.Interfaces.BTDockGUI:Clone();
Dock.Parent = UI;
Dock.Visible = false;

-- Add functionality to each tool button
function RegisterToolButton( ToolButton )
	-- Provides functionality to `ToolButton`

	-- Get the tool name and the tool
	local tool_name = ToolButton.Name:match( "(.+)Button" );

	if tool_name then

		-- Create the click connection
		ToolButton.MouseButton1Up:connect( function ()
			local Tool = Tools[tool_name];
			if Tool then
				equipTool( Tool );
			end;
		end );

		ToolButton.MouseEnter:connect( function ()
			local Tooltip = Tooltips[tool_name];
			if Tooltip then
				Tooltip:focus( 'button' );
			end;
		end );

		ToolButton.MouseLeave:connect( function ()
			local Tooltip = Tooltips[tool_name];
			if Tooltip then
				Tooltip:unfocus( 'button' );
			end;
		end );

	end;
end;
for _, ToolButton in pairs( Dock.ToolButtons:GetChildren() ) do
	RegisterToolButton( ToolButton );
end;

-- Prepare the tooltips
function RegisterTooltip( Tooltip )
	local tool_name = Tooltip.Name:match( "(.+)Info" );

	Tooltips[tool_name] = {

		GUI = Tooltip;

		button_focus = false;
		tooltip_focus = false;

		focus = function ( self, source )
			if Dock.HelpInfo.Visible then
				return;
			end;
			if source == 'button' then
				self.button_focus = true;
			elseif source == 'tooltip' then
				self.tooltip_focus = true;
			end;
			for _, Tooltip in pairs( Dock.Tooltips:GetChildren() ) do
				Tooltip.Visible = false;
			end;
			self.GUI.Visible = true;
		end;

		unfocus = function ( self, source )
			if source == 'button' then
				self.button_focus = false;
			elseif source == 'tooltip' then
				self.tooltip_focus = false;
			end;
			if not self.button_focus and not self.tooltip_focus then
				self.GUI.Visible = false;
			end;
		end;

	};

	-- Make it disappear after it's out of mouse focus
	Tooltip.MouseEnter:connect( function ()
		Tooltips[tool_name]:focus( 'tooltip' );
	end );
	Tooltip.MouseLeave:connect( function ()
		Tooltips[tool_name]:unfocus( 'tooltip' );
	end );

	-- Create the scrolling container
	local ScrollingContainer = Gloo.ScrollingContainer( true, false, 15 );
	ScrollingContainer.GUI.Parent = Tooltip;

	-- Put the tooltip content in the container
	for _, Child in pairs( Tooltip.Content:GetChildren() ) do
		Child.Parent = ScrollingContainer.Container;
	end;
	ScrollingContainer.GUI.Size = Dock.Tooltips.Size;
	ScrollingContainer.Container.Size = Tooltip.Content.Size;
	ScrollingContainer.Boundary.Size = Dock.Tooltips.Size;
	ScrollingContainer.Boundary.BackgroundTransparency = 1;
	Tooltip.Content:Destroy();

end;
for _, Tooltip in pairs( Dock.Tooltips:GetChildren() ) do
	RegisterTooltip( Tooltip );
end;

-- Create the scrolling container for the help tooltip
local ScrollingContainer = Gloo.ScrollingContainer( true, false, 15 );
ScrollingContainer.GUI.Parent = Dock.HelpInfo;

-- Put the help tooltip content in the container
for _, Child in pairs( Dock.HelpInfo.Content:GetChildren() ) do
	Child.Parent = ScrollingContainer.Container;
end;
ScrollingContainer.GUI.Size = Dock.HelpInfo.Size;
ScrollingContainer.Container.Size = Dock.HelpInfo.Content.Size;
ScrollingContainer.Boundary.Size = Dock.HelpInfo.Size;
ScrollingContainer.Boundary.BackgroundTransparency = 1;
Dock.HelpInfo.Content:Destroy();

-- Add functionality to the other GUI buttons
Dock.SelectionButtons.UndoButton.MouseButton1Up:connect( function ()
	History:undo();
end );
Dock.SelectionButtons.RedoButton.MouseButton1Up:connect( function ()
	History:redo();
end );
Dock.SelectionButtons.DeleteButton.MouseButton1Up:connect( function ()
	deleteSelection();
end );
Dock.SelectionButtons.CloneButton.MouseButton1Up:connect( function ()
	cloneSelection();
end );
Dock.SelectionButtons.ExportButton.MouseButton1Up:connect( function ()
	IE:export();
end );
Dock.InfoButtons.HelpButton.MouseButton1Up:connect( function ()
	toggleHelp();
end );

-- Shade the buttons according to whether they'll function or not
Selection.Changed:connect( function ()

	-- If there are items, they should be active
	if #Selection.Items > 0 then
		Dock.SelectionButtons.DeleteButton.Image = delete_active_decal;
		Dock.SelectionButtons.CloneButton.Image = clone_active_decal;
		Dock.SelectionButtons.ExportButton.Image = export_active_decal;

	-- If there aren't items, they shouldn't be active
	else
		Dock.SelectionButtons.DeleteButton.Image = delete_inactive_decal;
		Dock.SelectionButtons.CloneButton.Image = clone_inactive_decal;
		Dock.SelectionButtons.ExportButton.Image = export_inactive_decal;
	end;

end );

-- Make the selection/info buttons display tooltips upon hovering over them
for _, SelectionButton in pairs( Dock.SelectionButtons:GetChildren() ) do
	SelectionButton.MouseEnter:connect( function ()
		if SelectionButton:FindFirstChild( 'Tooltip' ) then
			SelectionButton.Tooltip.Visible = true;
		end;
	end );
	SelectionButton.MouseLeave:connect( function ()
		if SelectionButton:FindFirstChild( 'Tooltip' ) then
			SelectionButton.Tooltip.Visible = false;
		end;
	end );
end;
Dock.InfoButtons.HelpButton.MouseEnter:connect( function ()
	Dock.InfoButtons.HelpButton.Tooltip.Visible = true;
end );
Dock.InfoButtons.HelpButton.MouseLeave:connect( function ()
	Dock.InfoButtons.HelpButton.Tooltip.Visible = false;
end );

History.Changed:connect( function ()

	-- If there are any records
	if #History.Data > 0 then

		-- If we're at the beginning
		if History.index == 0 then
			Dock.SelectionButtons.UndoButton.Image = undo_inactive_decal;
			Dock.SelectionButtons.RedoButton.Image = redo_active_decal;

		-- If we're at the end
		elseif History.index == #History.Data then
			Dock.SelectionButtons.UndoButton.Image = undo_active_decal;
			Dock.SelectionButtons.RedoButton.Image = redo_inactive_decal;

		-- If we're neither at the beginning or the end
		else
			Dock.SelectionButtons.UndoButton.Image = undo_active_decal;
			Dock.SelectionButtons.RedoButton.Image = redo_active_decal;
		end;

	-- If there are no records
	else
		Dock.SelectionButtons.UndoButton.Image = undo_inactive_decal;
		Dock.SelectionButtons.RedoButton.Image = redo_inactive_decal;
	end;

end );

------------------------------------------
-- Attach tool event listeners
------------------------------------------

function equipBT( CurrentMouse )

	Mouse = CurrentMouse;

	-- Enable the move tool if there's no tool currently enabled
	if not CurrentTool then
		equipTool( Tools.Move );
	end;

	if not TargetBox then
		TargetBox = Instance.new( "SelectionBox", UI );
		TargetBox.Name = "BTTargetBox";
		TargetBox.Color = BrickColor.new( "Institutional white" );
		TargetBox.Transparency = 0.5;
	end;

	-- Enable any temporarily-disabled selection boxes
	for _, SelectionBox in pairs( SelectionBoxes ) do
		SelectionBox.Parent = UI;
	end;

	-- Update the internal selection if this is a plugin
	if ToolType == 'plugin' then
		for _, Item in pairs( Services.Selection:Get() ) do
			Selection:add( Item );
		end;
	end;

	-- Call the `Equipped` listener of the current tool
	if CurrentTool and CurrentTool.Listeners.Equipped then
		CurrentTool.Listeners.Equipped();
	end;

	-- Show the dock
	Dock.Visible = true;

	table.insert( Connections, Mouse.KeyDown:connect( function ( key )

		local key = key:lower();
		local key_code = key:byte();

		-- Provide the abiltiy to delete via the shift + X key combination
		if ActiveKeys[47] or ActiveKeys[48] and key == "x" then
			deleteSelection();
			return;
		end;

		-- Provide the ability to clone via the shift + C key combination
		if ActiveKeys[47] or ActiveKeys[48] and key == "c" then
			cloneSelection();
			return;
		end;

		-- Undo if shift+z is pressed
		if key == "z" and ( ActiveKeys[47] or ActiveKeys[48] ) then
			History:undo();
			return;

		-- Redo if shift+y is pressed
		elseif key == "y" and ( ActiveKeys[47] or ActiveKeys[48] ) then
			History:redo();
			return;
		end;

		-- Serialize and dump selection to logs if shift+p is pressed
		if key == "p" and ( ActiveKeys[47] or ActiveKeys[48] ) then
			IE:export();
			return;
		end;

		-- Perform a prism selection if shift + k is pressed
		if key == "k" and ( ActiveKeys[47] or ActiveKeys[48] ) then
			prismSelect();
			return;
		end;

		-- Clear the selection if shift + r is pressed
		if key == "r" and ( ActiveKeys[47] or ActiveKeys[48] ) then
			Selection:clear();
			return;
		end;

		if key == "z" then
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

		elseif key == "f" then
			equipTool( Tools.Weld );

		elseif key == "u" then
			equipTool( Tools.Lighting );

		elseif key == "p" then
			equipTool( Tools.Decorate );

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
		if not override_selection and isSelectable( Mouse.Target ) and TargetBox.Adornee ~= Mouse.Target then
			TargetBox.Adornee = Mouse.Target;
		end;

		-- When aiming at something invalid, don't highlight any targets
		if not override_selection and not isSelectable( Mouse.Target ) then
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
		if not override_selection and not selecting and not isSelectable( Mouse.Target ) then
			Selection:clear();
		end;

		-- If multi-selecting, add to/remove from the selection
		if not override_selection and selecting then

			-- If the item isn't already selected, add it to the selection
			if not Selection:find( Mouse.Target ) then
				if isSelectable( Mouse.Target ) then
					Selection:add( Mouse.Target );
				end;

			-- If the item _is_ already selected, remove it from the selection
			else
				if ( Mouse.X == click_x and Mouse.Y == click_y ) and Selection:find( Mouse.Target ) then
					Selection:remove( Mouse.Target );
				end;
			end;

		-- If not multi-selecting, replace the selection
		else
			if not override_selection and isSelectable( Mouse.Target ) then
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

end;

function unequipBT()

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

	-- Hide the dock
	Dock.Visible = false;

	-- Disconnect temporary platform-related connections
	for connection_index, Connection in pairs( Connections ) do
		Connection:disconnect();
		Connections[connection_index] = nil;
	end;

	-- Call the `Unequipped` listener of the current tool
	if CurrentTool and CurrentTool.Listeners.Unequipped then
		CurrentTool.Listeners.Unequipped();
	end;

end;


------------------------------------------
-- Provide the platform's environment for
-- other tool scripts to extend upon
------------------------------------------

local tool_list = {
	"Anchor",
	"Collision",
	"Material",
	"Mesh",
	"Move",
	"NewPart",
	"Paint",
	"Resize",
	"Rotate",
	"Surface",
	"Texture",
	"Weld",
	"Lighting",
	"Decorate"
};

-- Make sure all the tool scripts are in the tool & deactivate them
for _, tool_name in pairs( tool_list ) do
	local script_name = "BT" .. tool_name .. "Tool";
	repeat wait() until script:FindFirstChild( script_name );
	script[script_name].Disabled = true;
end;

-- Load the platform
if not _G.BTCoreEnv then
	_G.BTCoreEnv = {};
end;
_G.BTCoreEnv[Tool] = getfenv( 0 );
CoreReady = true;

-- Reload the tool scripts
for _, tool_name in pairs( tool_list ) do
	local script_name = "BT" .. tool_name .. "Tool";
	script[script_name].Disabled = false;
end;

-- Wait for all the tools to load
for _, tool_name in pairs( tool_list ) do
	if not Tools[tool_name] then
		repeat wait() until Tools[tool_name];
	end;
	repeat wait() until Tools[tool_name].Loaded;
end;

-- Activate the plugin and tool connections
if ToolType == 'plugin' then
	local ToolbarButton = plugin:CreateToolbar( 'Building Tools by F3X' ):CreateButton( '', 'Building Tools by F3X', plugin_icon );
	local plugin_active = false;
	ToolbarButton.Click:connect( function ()
		if plugin_active then
			plugin_active = false;
			unequipBT();
		else
			plugin_active = true;
			plugin:Activate( true );
			equipBT( plugin:GetMouse() );
		end;
	end );
	plugin.Deactivation:connect( unequipBT );

elseif ToolType == 'tool' then
	Tool.Equipped:connect( equipBT );
	Tool.Unequipped:connect( unequipBT );
end;