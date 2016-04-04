-- References
ServerAPI = script.Parent;
Tool = ServerAPI.Parent;
Player = nil;

-- Libraries
RbxUtility = LoadLibrary 'RbxUtility';
Support = require(Tool.SupportLibrary);
Security = require(Tool.SecurityModule);
RegionModule = require(Tool['Region by AxisAngle']);
Create = RbxUtility.Create;
CreateSignal = RbxUtility.CreateSignal;

-- Import services
Support.ImportServices();

-- Keep track of created items in memory to not lose them in garbage collection
CreatedInstances = {};

-- Determine whether we're in tool or plugin mode
if Tool:IsA 'Tool' then
	ToolMode = 'Tool';
elseif Tool:IsA 'Model' then
	ToolMode = 'Plugin';
end;

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
		elseif Object:IsA 'Smoke' or Object:IsA 'Fire' or Object:IsA 'Sparkles' or Object:IsA 'DataModelMesh' or Object:IsA 'Decal' or Object:IsA 'Texture' or Object:IsA 'Weld' or Object:IsA 'Light' then
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

		-- Only perform changes to authorized parts
		if not Security.IsPartAuthorizedForPlayer(Parent, Player) then
			return;
		end;

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

	['CreateDecoration'] = function (Type, Parent)
		-- Creates a new decoration of type `Type` for part `Parent`

		-- Only perform changes to authorized parts
		if not Security.IsPartAuthorizedForPlayer(Parent, Player) then
			return;
		end;

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

	['CreateLight'] = function (Type, Parent)
		-- Creates a new light of type `Type` for part `Parent`

		-- Only perform changes to authorized parts
		if not Security.IsPartAuthorizedForPlayer(Parent, Player) then
			return;
		end;

		local Light;

		-- Create and parent the light
		if Type == 'SpotLight' then
			Light = Instance.new('SpotLight', Parent);

		elseif Type == 'PointLight' then
			Light = Instance.new('PointLight', Parent);
		end;

		-- Register the light
		CreatedInstances[Light] = Light;

		-- Return the light
		return Light;
	end;

	['MakeJoints'] = function (Part)
		-- Calls the Part's MakeJoints method

		-- Only perform changes to authorized parts
		if Part:IsA 'BasePart' and Security.IsPartAuthorizedForPlayer(Part, Player) then
			Part:MakeJoints();
		end;

	end;

	['BreakJoints'] = function (Part)
		-- Calls the Part's BreakJoints method

		-- Only perform changes to authorized parts
		if Part:IsA 'BasePart' and Security.IsPartAuthorizedForPlayer(Part, Player) then
			Part:BreakJoints();
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
		elseif Object:IsA 'Smoke' or Object:IsA 'Fire' or Object:IsA 'Sparkles' or Object:IsA 'DataModelMesh' or Object:IsA 'Decal' or Object:IsA 'Texture' or Object:IsA 'Weld' or Object:IsA 'Light' then
			
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

		-- If no authorization checks have failed, keep the part in memory & perform the setting
		CreatedInstances[Object] = Object;
		Object.Parent = Parent;
	end;

	['CreateMesh'] = function (Parent)
		-- Creates a new SpecialMesh inside `Parent`

		-- Only perform changes to authorized parts
		if not Security.IsPartAuthorizedForPlayer(Parent, Player) then
			return;
		end;

		-- Create and parent the mesh
		local Mesh = Instance.new('SpecialMesh', Parent);

		-- Register the light
		CreatedInstances[Mesh] = Mesh;

		-- Return the mesh
		return Mesh;
	end;

	['SyncMove'] = function (Changes)
		-- Updates parts server-side given their new CFrames

		-- Grab a list of every part we're attempting to modify
		local Parts = {};
		for _, Change in pairs(Changes) do
			if Change.Part then
				table.insert(Parts, Change.Part);
			end;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player);

		-- Make sure the player is allowed to perform changes to these parts
		if Security.ArePartsViolatingAreas(Parts, Player, AreaPermissions) then
			return;
		end;

		-- Reorganize the changes
		local ChangeSet = {};
		for _, Change in pairs(Changes) do
			if Change.Part then
				Change.InitialState = { Anchored = Change.Part.Anchored, CFrame = Change.Part.CFrame };
				ChangeSet[Change.Part] = Change;
			end;
		end;

		-- Perform each change
		for Part, Change in pairs(ChangeSet) do

			-- Stabilize the parts and maintain the original anchor state
			Part.Anchored = true;
			Part:BreakJoints();
			Part.Velocity = Vector3.new();
			Part.RotVelocity = Vector3.new();

			-- Set the part's CFrame
			Part.CFrame = Change.CFrame;

		end;

		-- Make sure the player is authorized to move parts into this area
		if Security.ArePartsViolatingAreas(Parts, Player, AreaPermissions) then

			-- Revert changes if unauthorized destination
			for Part, Change in pairs(ChangeSet) do
				Part.CFrame = Change.InitialState.CFrame;
			end;

		end;

		-- Restore the parts' original states
		for Part, Change in pairs(ChangeSet) do
			Part:MakeJoints();
			Part.Anchored = Change.InitialState.Anchored;
		end;

	end;

	['SyncResize'] = function (Changes)
		-- Updates parts server-side given their new sizes and CFrames

		-- Grab a list of every part we're attempting to modify
		local Parts = {};
		for _, Change in pairs(Changes) do
			if Change.Part then
				table.insert(Parts, Change.Part);
			end;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player);

		-- Make sure the player is allowed to perform changes to these parts
		if Security.ArePartsViolatingAreas(Parts, Player, AreaPermissions) then
			return;
		end;

		-- Reorganize the changes
		local ChangeSet = {};
		for _, Change in pairs(Changes) do
			if Change.Part then
				Change.InitialState = { Anchored = Change.Part.Anchored, Size = Change.Part.Size, CFrame = Change.Part.CFrame };
				ChangeSet[Change.Part] = Change;
			end;
		end;

		-- Perform each change
		for Part, Change in pairs(ChangeSet) do

			-- Stabilize the parts and maintain the original anchor state
			Part.Anchored = true;
			Part:BreakJoints();
			Part.Velocity = Vector3.new();
			Part.RotVelocity = Vector3.new();

			-- Ensure the part has a "Custom" form factor to resize properly
			if Part:IsA 'FormFactorPart' then
				Part.FormFactor = Enum.FormFactor.Custom;
			end;

			-- Set the part's size and CFrame
			Part.Size = Change.Size;
			Part.CFrame = Change.CFrame;

		end;

		-- Make sure the player is authorized to move parts into this area
		if Security.ArePartsViolatingAreas(Parts, Player, AreaPermissions) then

			-- Revert changes if unauthorized destination
			for Part, Change in pairs(ChangeSet) do
				Part.Size = Change.InitialState.Size;
				Part.CFrame = Change.InitialState.CFrame;
			end;

		end;

		-- Restore the parts' original states
		for Part, Change in pairs(ChangeSet) do
			Part:MakeJoints();
			Part.Anchored = Change.InitialState.Anchored;
		end;

	end;

	['SyncRotate'] = function (Changes)
		-- Updates parts server-side given their new CFrames

		-- Grab a list of every part we're attempting to modify
		local Parts = {};
		for _, Change in pairs(Changes) do
			if Change.Part then
				table.insert(Parts, Change.Part);
			end;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player);

		-- Make sure the player is allowed to perform changes to these parts
		if Security.ArePartsViolatingAreas(Parts, Player, AreaPermissions) then
			return;
		end;

		-- Reorganize the changes
		local ChangeSet = {};
		for _, Change in pairs(Changes) do
			if Change.Part then
				Change.InitialState = { Anchored = Change.Part.Anchored, CFrame = Change.Part.CFrame };
				ChangeSet[Change.Part] = Change;
			end;
		end;

		-- Perform each change
		for Part, Change in pairs(ChangeSet) do

			-- Stabilize the parts and maintain the original anchor state
			Part.Anchored = true;
			Part:BreakJoints();
			Part.Velocity = Vector3.new();
			Part.RotVelocity = Vector3.new();

			-- Set the part's CFrame
			Part.CFrame = Change.CFrame;

		end;

		-- Make sure the player is authorized to move parts into this area
		if Security.ArePartsViolatingAreas(Parts, Player, AreaPermissions) then

			-- Revert changes if unauthorized destination
			for Part, Change in pairs(ChangeSet) do
				Part.CFrame = Change.InitialState.CFrame;
			end;

		end;

		-- Restore the parts' original states
		for Part, Change in pairs(ChangeSet) do
			Part:MakeJoints();
			Part.Anchored = Change.InitialState.Anchored;
		end;

	end;

	['SyncColor'] = function (Changes)
		-- Updates parts server-side given their new colors

		-- Grab a list of every part we're attempting to modify
		local Parts = {};
		for _, Change in pairs(Changes) do
			if Change.Part then
				table.insert(Parts, Change.Part);
			end;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player);

		-- Make sure the player is allowed to perform changes to these parts
		if Security.ArePartsViolatingAreas(Parts, Player, AreaPermissions) then
			return;
		end;

		-- Reorganize the changes
		local ChangeSet = {};
		for _, Change in pairs(Changes) do
			if Change.Part then
				ChangeSet[Change.Part] = Change;
			end;
		end;

		-- Perform each change
		for Part, Change in pairs(ChangeSet) do

			-- Set the part's color
			Part.BrickColor = Change.Color;

			-- If this part is a union, set its UsePartColor state
			if Part.ClassName == 'UnionOperation' then
				Part.UsePartColor = Change.UnionColoring;
			end;

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