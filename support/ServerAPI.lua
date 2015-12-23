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

-- Keep track of created items in memory to not lose them in garbage collection
CreatedInstances = {};

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
			CreatedInstances[Item] = Item;
		end;

		-- Return the clones
		return Clones;
	end;

	['CreatePart'] = function (PartType, Position)
		-- Creates a new part based on `PartType`

		-- Create the part
		local NewPart = Support.CreatePart(PartType);
		NewPart.Parent = Workspace;
		CreatedInstances[NewPart] = NewPart;

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
		elseif Object:IsA 'Smoke' or Object:IsA 'Fire' or Object:IsA 'Sparkles' or Object:IsA 'Mesh' or Object:IsA 'Decal' or Object:IsA 'Texture' or Object:IsA 'Weld' or Object:IsA 'Light' then
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

	['CreateDecoration'] = function (Type, Parent)
		-- Creates a new decoration of type `Type` for part `Parent`

		local Decoration;

		-- Create and parent the decoration
		if Type == 'Smoke' then
			Decoration = Instance.new('Smoke', Parent);

		elseif Type == 'Fire' then
			Decoration = Instance.new('Fire', Parent);

		elseif Type == 'Sparkles' then
			Decoration = Instance.new('Sparkles', Parent);
		end;

		-- Register the decoration
		CreatedInstances[Decoration] = Decoration;

		-- Return the decoration
		return Decoration;
	end;

	['MakeJoints'] = function (Part)
		-- Calls the Part's MakeJoints method

		-- Only perform changes to authorized parts
		if Part:IsA 'BasePart' and Security.IsPartAuthorizedForPlayer(Part, Player) then
			Part:MakeJoints();
		end;

	end;

	['SetParent'] = function (Object, Parent)
		-- Sets `Object`'s parent to `Parent`

		-- If this is a part, make sure we have permission to modify it
		if Object:IsA 'BasePart' then
			if not Security.IsPartAuthorizedForPlayer(Object, Player) then
				return;
			end;

		-- If this is a decoration, make sure we have permission to modify it, and the new parent part
		elseif Object:IsA 'Smoke' or Object:IsA 'Fire' or Object:IsA 'Sparkles' or Object:IsA 'Mesh' or Object:IsA 'Decal' or Object:IsA 'Texture' or Object:IsA 'Weld' or Object:IsA 'Light' then
			
			-- Make sure we can modify the current parent of the decoration (if any)
			if Object.Parent and Object.Parent:IsA 'BasePart' then
				if not Security.IsPartAuthorizedForPlayer(Object.Parent, Player) then
					return;
				end;
			end;

			-- Make sure we can modify the target parent part
			if Parent and Parent:IsA 'BasePart' then
				if not Security.IsPartAuthorizedForPlayer(Parent, Player) then
					return;
				end;
			end;

		end;

		-- If no authorization checks have failed, perform the setting
		Object.Parent = Parent;
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