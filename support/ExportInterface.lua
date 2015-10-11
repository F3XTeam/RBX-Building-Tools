-- Provides the ability to export parts to the cloud


------------------------------------------
-- Make references to important objects
------------------------------------------

Services = {
	Workspace	= Game:GetService 'Workspace';
};

local HttpService		= Game:GetService 'HttpService';
local ExportInterface	= script.Parent;

local Tool = script.Parent.Parent;
local Support = require(Tool:WaitForChild 'SupportLibrary');


--------------------
-- Core functions
--------------------

function _generateSerializationID()
	-- Returns a random 5-character string
	-- with characters A-Z, a-z, and 0-9
	-- (there are 916,132,832 unique IDs)

	local characters = {
		"0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
		"a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
		"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"
	};

	local serialization_id = "";

	-- Pick out 5 random characters
	for _ = 1, 5 do
		serialization_id = serialization_id .. ( characters[math.random( #characters )] );
	end;

	return serialization_id;
end;

function _splitNumberListString( str )
	-- Returns the contents of SplitString( str, ", " ), except
	-- each value in the table is turned into a number

	-- Get the number strings
	local numbers = Support.SplitString( str, ", " );

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
			for _, Joint in pairs( Support.GetAllDescendants( Services.Workspace ) ) do
				if Joint:IsA( "Weld" ) and Joint.Name == "BTWeld" then
					if Joint.Part0 == Object and #Support.FindTableOccurrences( objects, Joint.Part1 ) > 0 then
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
				Support.FindTableOccurrences( objects, Weld.Part0 )[1],
				Support.FindTableOccurrences( objects, Weld.Part1 )[1],
				_splitNumberListString( tostring( Weld.C1 ) )
			};
			data.welds[weld_id] = WeldData;
			objects[weld_id] = Weld;
		end;
	end;

	-- Get any meshes in the selection
	local meshes = {};
	for _, Part in pairs( parts ) do
		local Mesh = Support.GetChildOfClass( Part, "SpecialMesh" );
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
				Support.FindTableOccurrences( objects, Mesh.Parent )[1],
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
		local textures_found = Support.GetChildrenOfClass( Part, "Texture" );
		for _, Texture in pairs( textures_found ) do
			table.insert( textures, Texture );
		end;
		local decals_found = Support.GetChildrenOfClass( Part, "Decal" );
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
				Support.FindTableOccurrences( objects, Texture.Parent )[1],
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
		local lights_found = Support.GetChildrenOfClass( Part, "Light", true );
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
				Support.FindTableOccurrences( objects, Light.Parent )[1];
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
		table.insert( decorations, Support.GetChildOfClass( Part, 'Smoke' ) )
		table.insert( decorations, Support.GetChildOfClass( Part, 'Fire' ) );
		table.insert( decorations, Support.GetChildOfClass( Part, 'Sparkles' ) );
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
				Support.FindTableOccurrences( objects, Decoration.Parent )[1],
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

	return HttpService:JSONEncode( data );

end;


-----------------------
-- Man the interface
-----------------------

ExportInterface.Export.OnServerInvoke = function (Player, Parts)

	-- Serialize the parts in given table `Parts`
	local SerializedParts = _serializeParts(Parts);

	-- Send the request
	local RequestResponse;
	local RequestSuccess, RequestError = ypcall(function ()
		RequestResponse = HttpService:PostAsync('http://www.f3xteam.com/bt/export', SerializedParts);
	end);

	local ParsedData;
	local ParseSuccess = ypcall(function ()
		ParsedData = HttpService:JSONDecode(RequestResponse);
	end);

	-- Return whether the request succeeded, any error from it, whether it
	-- was parsed successfully, and the parsed response data if any
	return RequestSuccess, RequestError, ParseSuccess, ParsedData;

end;