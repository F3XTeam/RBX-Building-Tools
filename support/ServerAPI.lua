-- References
ServerAPI = script.Parent;
Tool = ServerAPI.Parent;
Player = nil;

-- Services
Workspace = Game:GetService 'Workspace';

-- Libraries
RbxUtility = LoadLibrary 'RbxUtility';
Support = require(Tool.SupportLibrary);
Security = require(Tool.SecurityModule);
Create = RbxUtility.Create;
CreateSignal = RbxUtility.CreateSignal;

-- Keep track of created parts in memory to not lose them in garbage collection
CreatedParts = {};

-- List of actions that could be requested
Actions = {

	['RecolorHandle'] = function (NewColor)
		-- Recolors the tool handle
		Tool.Handle.BrickColor = NewColor;
	end;

	['Clone'] = function (Items)
		-- Clones the given items

		local Clones = {};

		-- Copy the items
		for _, Item in pairs(Items) do
			local Clone = Item:Clone();
			Clone.Parent = Workspace;
			table.insert(Clones, Clone);
			CreatedParts[Item] = Item;
		end;

		-- Return the clones
		return Clones;
	end;

	['CreatePart'] = function (PartType, Position)
		-- Creates a new part based on `PartType`

		local NewPart;

		if PartType == 'Normal' then
			NewPart = Instance.new('Part', Workspace);
			NewPart.FormFactor = Enum.FormFactor.Custom;
			NewPart.Size = Vector3.new(4, 1, 2);

		elseif PartType == 'Truss' then
			NewPart = Instance.new('TrussPart', Workspace);

		elseif PartType == 'Wedge' then
			NewPart = Instance.new('WedgePart', Workspace);
			NewPart.FormFactor = Enum.FormFactor.Custom;
			NewPart.Size = Vector3.new(4, 1, 2);

		elseif PartType == 'Corner' then
			NewPart = Instance.new('CornerWedgePart', Workspace);

		elseif PartType == 'Cylinder' then
			NewPart = Instance.new('Part', Workspace);
			NewPart.Shape = 'Cylinder';
			NewPart.FormFactor = Enum.FormFactor.Custom;
			NewPart.TopSurface = Enum.SurfaceType.Smooth;
			NewPart.BottomSurface = Enum.SurfaceType.Smooth;
			NewPart.Size = Vector3.new(2, 2, 2);

		elseif PartType == 'Ball' then
			NewPart = Instance.new('Part', Workspace);
			NewPart.Shape = 'Ball';
			NewPart.FormFactor = Enum.FormFactor.Custom;
			NewPart.TopSurface = Enum.SurfaceType.Smooth;
			NewPart.BottomSurface = Enum.SurfaceType.Smooth;

		elseif PartType == 'Seat' then
			NewPart = Instance.new('Seat', Workspace);
			NewPart.FormFactor = Enum.FormFactor.Custom;
			NewPart.Size = Vector3.new(4, 1, 2);

		elseif PartType == 'Vehicle Seat' then
			NewPart = Instance.new('VehicleSeat', Workspace);
			NewPart.Size = Vector3.new(4, 1, 2);

		elseif PartType == 'Spawn' then
			NewPart = Instance.new('SpawnLocation', Workspace);
			NewPart.FormFactor = Enum.FormFactor.Custom;
			NewPart.Size = Vector3.new(4, 1, 2);
		end;

		-- Make sure the part is anchored
		NewPart.Anchored = true;

		-- Position the part
		NewPart.CFrame = Position;

		-- Return the part
		return NewPart;
	end;

	['Change'] = function (Object, Changes)
		-- Performs the requested changes to `Object`'s properties

		local Part;

		-- Figure out the part this change applies to
		if Object:IsA 'BasePart' then
			Part = Object;
		elseif Object:IsA 'Smoke' or Object:IsA 'Fire' or Object:IsA 'Mesh' or Object:IsA 'Decal' or Object:IsA 'Texture' or Object:IsA 'Weld' or Object:IsA 'Smoke' or Object:IsA 'Light' then
			Part = Object.Parent;
		end;

		-- Only perform changes to authorized parts
		if Part:IsA 'BasePart' and Security.IsPartAuthorizedForPlayer(Part, Player) then

			-- Apply changes
			-- TODO: Restrict certain properties
			for Property, Value in pairs(Changes) do
				Object[Property] = Value;
			end;

		end;

	end;

	['MakeJoints'] = function (Part)
		-- Calls the Part's MakeJoints method

		-- Only perform changes to authorized parts
		if Part:IsA 'BasePart' and Security.IsPartAuthorizedForPlayer(Part, Player) then
			Part:MakeJoints();
		end;

	end;

};

-- Provide functionality to the API instance
ServerAPI.OnServerInvoke = function (Client, ActionName, ...)

	-- Make sure the action exists
	local Action = Actions[ActionName];
	if not Action then
		return;
	end;

	-- Update the Player pointer
	Player = Client;

	-- Execute valid actions
	return Action(...);

end;