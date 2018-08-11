Serialization = {};

-- Import services
local Tool = script.Parent.Parent
local Support = require(Tool.Libraries.SupportLibrary);
Support.ImportServices();

local Types = {
	Part = 0,
	WedgePart = 1,
	CornerWedgePart = 2,
	VehicleSeat = 3,
	Seat = 4,
	TrussPart = 5,
	SpecialMesh = 6,
	Texture = 7,
	Decal = 8,
	PointLight = 9,
	SpotLight = 10,
	SurfaceLight = 11,
	Smoke = 12,
	Fire = 13,
	Sparkles = 14,
	Model = 15
};

local DefaultNames = {
	Part = 'Part',
	WedgePart = 'Wedge',
	CornerWedgePart = 'CornerWedge',
	VehicleSeat = 'VehicleSeat',
	Seat = 'Seat',
	TrussPart = 'Truss',
	SpecialMesh = 'Mesh',
	Texture = 'Texture',
	Decal = 'Decal',
	PointLight = 'PointLight',
	SpotLight = 'SpotLight',
	SurfaceLight = 'SurfaceLight',
	Smoke = 'Smoke',
	Fire = 'Fire',
	Sparkles = 'Sparkles',
	Model = 'Model'
};

function Serialization.SerializeModel(Items)
	-- Returns a serialized version of the given model

	-- Filter out non-serializable items in `Items`
	local SerializableItems = {};
	for Index, Item in ipairs(Items) do
		table.insert(SerializableItems, Types[Item.ClassName] and Item or nil);
	end;
	Items = SerializableItems;

	-- Get a snapshot of the content
	local Keys = Support.FlipTable(Items);

	local Data = {};
	Data.Version = 2;
	Data.Items = {};

	-- Serialize each item in the model
	for Index, Item in pairs(Items) do

		if Item:IsA 'BasePart' then
			local Datum = {};
			Datum[1] = Types[Item.ClassName];
			Datum[2] = Keys[Item.Parent] or 0;
			Datum[3] = Item.Name == DefaultNames[Item.ClassName] and '' or Item.Name;
			Datum[4] = Item.Size.X;
			Datum[5] = Item.Size.Y;
			Datum[6] = Item.Size.Z;
			Support.ConcatTable(Datum, { Item.CFrame:components() });
			Datum[19] = Item.BrickColor.Number;
			Datum[20] = Item.Material.Value;
			Datum[21] = Item.Anchored and 1 or 0;
			Datum[22] = Item.CanCollide and 1 or 0;
			Datum[23] = Item.Reflectance;
			Datum[24] = Item.Transparency;
			Datum[25] = Item.TopSurface.Value;
			Datum[26] = Item.BottomSurface.Value;
			Datum[27] = Item.FrontSurface.Value;
			Datum[28] = Item.BackSurface.Value;
			Datum[29] = Item.LeftSurface.Value;
			Datum[30] = Item.RightSurface.Value;
			Data.Items[Index] = Datum;
		end;

		if Item.ClassName == 'Part' then
			local Datum = Data.Items[Index];
			Datum[31] = Item.Shape.Value;
		end;

		if Item.ClassName == 'VehicleSeat' then
			local Datum = Data.Items[Index];
			Datum[31] = Item.MaxSpeed;
			Datum[32] = Item.Torque;
			Datum[33] = Item.TurnSpeed;
		end;

		if Item.ClassName == 'TrussPart' then
			local Datum = Data.Items[Index];
			Datum[31] = Item.Style.Value;
		end;

		if Item.ClassName == 'SpecialMesh' then
			local Datum = {};
			Datum[1] = Types[Item.ClassName];
			Datum[2] = Keys[Item.Parent] or 0;
			Datum[3] = Item.Name == DefaultNames[Item.ClassName] and '' or Item.Name;
			Datum[4] = Item.MeshType.Value;
			Datum[5] = Item.MeshId;
			Datum[6] = Item.TextureId;
			Datum[7] = Item.Offset.X;
			Datum[8] = Item.Offset.Y;
			Datum[9] = Item.Offset.Z;
			Datum[10] = Item.Scale.X;
			Datum[11] = Item.Scale.Y;
			Datum[12] = Item.Scale.Z;
			Datum[13] = Item.VertexColor.X;
			Datum[14] = Item.VertexColor.Y;
			Datum[15] = Item.VertexColor.Z;
			Data.Items[Index] = Datum;
		end;

		if Item:IsA 'Decal' then
			local Datum = {};
			Datum[1] = Types[Item.ClassName];
			Datum[2] = Keys[Item.Parent] or 0;
			Datum[3] = Item.Name == DefaultNames[Item.ClassName] and '' or Item.Name;
			Datum[4] = Item.Texture;
			Datum[5] = Item.Transparency;
			Datum[6] = Item.Face.Value;
			Data.Items[Index] = Datum;
		end;

		if Item.ClassName == 'Texture' then
			local Datum = Data.Items[Index];
			Datum[7] = Item.StudsPerTileU;
			Datum[8] = Item.StudsPerTileV;
		end;

		if Item:IsA 'Light' then
			local Datum = {};
			Datum[1] = Types[Item.ClassName];
			Datum[2] = Keys[Item.Parent] or 0;
			Datum[3] = Item.Name == DefaultNames[Item.ClassName] and '' or Item.Name;
			Datum[4] = Item.Brightness;
			Datum[5] = Item.Color.r;
			Datum[6] = Item.Color.g;
			Datum[7] = Item.Color.b;
			Datum[8] = Item.Enabled and 1 or 0;
			Datum[9] = Item.Shadows and 1 or 0;
			Data.Items[Index] = Datum;
		end;

		if Item.ClassName == 'PointLight' then
			local Datum = Data.Items[Index];
			Datum[10] = Item.Range;
		end;

		if Item.ClassName == 'SpotLight' then
			local Datum = Data.Items[Index];
			Datum[10] = Item.Range;
			Datum[11] = Item.Angle;
			Datum[12] = Item.Face.Value;
		end;

		if Item.ClassName == 'SurfaceLight' then
			local Datum = Data.Items[Index];
			Datum[10] = Item.Range;
			Datum[11] = Item.Angle;
			Datum[12] = Item.Face.Value;
		end;

		if Item.ClassName == 'Smoke' then
			local Datum = {};
			Datum[1] = Types[Item.ClassName];
			Datum[2] = Keys[Item.Parent] or 0;
			Datum[3] = Item.Name == DefaultNames[Item.ClassName] and '' or Item.Name;
			Datum[4] = Item.Enabled and 1 or 0;
			Datum[5] = Item.Color.r;
			Datum[6] = Item.Color.g;
			Datum[7] = Item.Color.b;
			Datum[8] = Item.Size;
			Datum[9] = Item.RiseVelocity;
			Datum[10] = Item.Opacity;
			Data.Items[Index] = Datum;
		end;

		if Item.ClassName == 'Fire' then
			local Datum = {};
			Datum[1] = Types[Item.ClassName];
			Datum[2] = Keys[Item.Parent] or 0;
			Datum[3] = Item.Name == DefaultNames[Item.ClassName] and '' or Item.Name;
			Datum[4] = Item.Enabled and 1 or 0;
			Datum[5] = Item.Color.r;
			Datum[6] = Item.Color.g;
			Datum[7] = Item.Color.b;
			Datum[8] = Item.SecondaryColor.r;
			Datum[9] = Item.SecondaryColor.g;
			Datum[10] = Item.SecondaryColor.b;
			Datum[11] = Item.Heat;
			Datum[12] = Item.Size;
			Data.Items[Index] = Datum;
		end;

		if Item.ClassName == 'Sparkles' then
			local Datum = {};
			Datum[1] = Types[Item.ClassName];
			Datum[2] = Keys[Item.Parent] or 0;
			Datum[3] = Item.Name == DefaultNames[Item.ClassName] and '' or Item.Name;
			Datum[4] = Item.Enabled and 1 or 0;
			Datum[5] = Item.SparkleColor.r;
			Datum[6] = Item.SparkleColor.g;
			Datum[7] = Item.SparkleColor.b;
			Data.Items[Index] = Datum;
		end;

		if Item.ClassName == 'Model' then
			local Datum = {};
			Datum[1] = Types[Item.ClassName];
			Datum[2] = Keys[Item.Parent] or 0;
			Datum[3] = Item.Name == DefaultNames[Item.ClassName] and '' or Item.Name;
			Datum[4] = Item.PrimaryPart and Keys[Item.PrimaryPart] or 0;
			Data.Items[Index] = Datum;
		end;

		-- Spread the workload over time to avoid locking up the CPU
		if Index % 100 == 0 then
			wait(0.01);
		end;

	end;

	-- Return the serialized data
	return HttpService:JSONEncode(Data);

end;

function Serialization.InflateBuildData(Data)
	-- Returns an inflated version of the given build data

	local Build = {};
	local Instances = {};

	-- Create each instance
	for Index, Datum in ipairs(Data.Items) do

		-- Inflate BaseParts
		if Datum[1] == Types.Part
			or Datum[1] == Types.WedgePart
			or Datum[1] == Types.CornerWedgePart
			or Datum[1] == Types.VehicleSeat
			or Datum[1] == Types.Seat
			or Datum[1] == Types.TrussPart
		then
			local Item = Instance.new(Support.FindTableOccurrence(Types, Datum[1]));
			Item.Size = Vector3.new(unpack(Support.Slice(Datum, 4, 6)));
			Item.CFrame = CFrame.new(unpack(Support.Slice(Datum, 7, 18)));
			Item.BrickColor = BrickColor.new(Datum[19]);
			Item.Material = Datum[20];
			Item.Anchored = Datum[21] == 1;
			Item.CanCollide = Datum[22] == 1;
			Item.Reflectance = Datum[23];
			Item.Transparency = Datum[24];
			Item.TopSurface = Datum[25];
			Item.BottomSurface = Datum[26];
			Item.FrontSurface = Datum[27];
			Item.BackSurface = Datum[28];
			Item.LeftSurface = Datum[29];
			Item.RightSurface = Datum[30];

			-- Register the part
			Instances[Index] = Item;
		end;

		-- Inflate specific Part properties
		if Datum[1] == Types.Part then
			local Item = Instances[Index];
			Item.Shape = Datum[31];
		end;

		-- Inflate specific VehicleSeat properties
		if Datum[1] == Types.VehicleSeat then
			local Item = Instances[Index];
			Item.MaxSpeed = Datum[31];
			Item.Torque = Datum[32];
			Item.TurnSpeed = Datum[33];
		end;

		-- Inflate specific TrussPart properties
		if Datum[1] == Types.TrussPart then
			local Item = Instances[Index];
			Item.Style = Datum[31];
		end;

		-- Inflate SpecialMesh instances
		if Datum[1] == Types.SpecialMesh then
			local Item = Instance.new('SpecialMesh');
			Item.MeshType = Datum[4];
			Item.MeshId = Datum[5];
			Item.TextureId = Datum[6];
			Item.Offset = Vector3.new(unpack(Support.Slice(Datum, 7, 9)));
			Item.Scale = Vector3.new(unpack(Support.Slice(Datum, 10, 12)));
			Item.VertexColor = Vector3.new(unpack(Support.Slice(Datum, 13, 15)));

			-- Register the mesh
			Instances[Index] = Item;
		end;

		-- Inflate Decal instances
		if Datum[1] == Types.Decal or Datum[1] == Types.Texture then
			local Item = Instance.new(Support.FindTableOccurrence(Types, Datum[1]));
			Item.Texture = Datum[4];
			Item.Transparency = Datum[5];
			Item.Face = Datum[6];

			-- Register the Decal
			Instances[Index] = Item;
		end;

		-- Inflate specific Texture properties
		if Datum[1] == Types.Texture then
			local Item = Instances[Index];
			Item.StudsPerTileU = Datum[7];
			Item.StudsPerTileV = Datum[8];
		end;

		-- Inflate Light instances
		if Datum[1] == Types.PointLight
			or Datum[1] == Types.SpotLight
			or Datum[1] == Types.SurfaceLight
		then
			local Item = Instance.new(Support.FindTableOccurrence(Types, Datum[1]));
			Item.Brightness = Datum[4];
			Item.Color = Color3.new(unpack(Support.Slice(Datum, 5, 7)));
			Item.Enabled = Datum[8] == 1;
			Item.Shadows = Datum[9] == 1;

			-- Register the light
			Instances[Index] = Item;
		end;

		-- Inflate specific PointLight properties
		if Datum[1] == Types.PointLight then
			local Item = Instances[Index];
			Item.Range = Datum[10];
		end;

		-- Inflate specific SpotLight properties
		if Datum[1] == Types.SpotLight then
			local Item = Instances[Index];
			Item.Range = Datum[10];
			Item.Angle = Datum[11];
			Item.Face = Datum[12];
		end;

		-- Inflate specific SurfaceLight properties
		if Datum[1] == Types.SurfaceLight then
			local Item = Instances[Index];
			Item.Range = Datum[10];
			Item.Angle = Datum[11];
			Item.Face = Datum[12];
		end;

		-- Inflate Smoke instances
		if Datum[1] == Types.Smoke then
			local Item = Instance.new('Smoke');
			Item.Enabled = Datum[4] == 1;
			Item.Color = Color3.new(unpack(Support.Slice(Datum, 5, 7)));
			Item.Size = Datum[8];
			Item.RiseVelocity = Datum[9];
			Item.Opacity = Datum[10];

			-- Register the smoke
			Instances[Index] = Item;
		end;

		-- Inflate Fire instances
		if Datum[1] == Types.Fire then
			local Item = Instance.new('Fire');
			Item.Enabled = Datum[4] == 1;
			Item.Color = Color3.new(unpack(Support.Slice(Datum, 5, 7)));
			Item.SecondaryColor = Color3.new(unpack(Support.Slice(Datum, 8, 10)));
			Item.Heat = Datum[11];
			Item.Size = Datum[12];

			-- Register the fire
			Instances[Index] = Item;
		end;

		-- Inflate Sparkles instances
		if Datum[1] == Types.Sparkles then
			local Item = Instance.new('Sparkles');
			Item.Enabled = Datum[4] == 1;
			Item.SparkleColor = Color3.new(unpack(Support.Slice(Datum, 5, 7)));

			-- Register the instance
			Instances[Index] = Item;
		end;

		-- Inflate Model instances
		if Datum[1] == Types.Model then
			local Item = Instance.new('Model');

			-- Register the model
			Instances[Index] = Item;
		end;

	end;

	-- Set object values on each instance
	for Index, Datum in pairs(Data.Items) do

		-- Get the item's instance
		local Item = Instances[Index];

		-- Set each item's parent and name
		if Item and Datum[1] <= 15 then
			Item.Name = (Datum[3] == '') and DefaultNames[Item.ClassName] or Datum[3];
			if Datum[2] == 0 then
				table.insert(Build, Item);
			else
				Item.Parent = Instances[Datum[2]];
			end;
		end;

		-- Set model primary parts
		if Item and Datum[1] == 15 then
			Item.PrimaryPart = (Datum[4] ~= 0) and Instances[Datum[4]] or nil;
		end;

	end;

	-- Return the model
	return Build;

end;

-- Return the API
return Serialization;