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

Tool:WaitForChild( "GetAsync" );
Tool:WaitForChild( "PostAsync" );
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
Tool:WaitForChild( "Interfaces" );

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
wait();
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

		-- Make sure `NewPart` is selectable
		if not NewPart or not NewPart:IsA( "BasePart" ) or NewPart.Locked or NewPart.Parent == nil then
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
	"Texture"
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

-- Enable `Tools.Move` as the first tool
equipTool( Tools.Move );