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
LastParents = {};

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

		-- Position the part
		NewPart.CFrame = Position;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas({ NewPart }), Player);

		-- Make sure the player is allowed to create parts in the area
		if Security.ArePartsViolatingAreas({ NewPart }, Player, AreaPermissions) then
			return;
		end;

		-- Parent the part
		NewPart.Parent = Workspace;

		-- Register the part
		CreatedInstances[NewPart] = NewPart;

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

	['CreateDecorations'] = function (Type, Parent)
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

	['Remove'] = function (Objects)
		-- Removes the given objects

		-- Get the relevant parts for each object, for permission checking
		local Parts = {};

		-- Go through the selection
		for _, Object in pairs(Objects) do

			-- Make sure the object still exists
			if Object then

				if Object:IsA 'BasePart' then
					table.insert(Parts, Object);

				elseif Object:IsA 'Smoke' or Object:IsA 'Fire' or Object:IsA 'Sparkles' or Object:IsA 'DataModelMesh' or Object:IsA 'Decal' or Object:IsA 'Texture' or Object:IsA 'Weld' or Object:IsA 'Light' then
					table.insert(Parts, Object.Parent);
				end;

			end;

		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player);

		-- Make sure the player is allowed to perform changes to these parts
		if Security.ArePartsViolatingAreas(Parts, Player, AreaPermissions) then
			return;
		end;

		-- After confirming permissions, perform each removal
		for _, Object in pairs(Objects) do

			-- Store the part's current parent
			LastParents[Object] = Object.Parent;

			-- Register the object
			CreatedInstances[Object] = Object;

			-- Set the object's current parent to `nil`
			Object.Parent = nil;

		end;

	end;

	['UndoRemove'] = function (Objects)
		-- Restores the given removed objects to their last parents

		-- Get the relevant parts for each object, for permission checking
		local Parts = {};

		-- Go through the selection
		for _, Object in pairs(Objects) do

			-- Make sure the object still exists
			if Object then

				if Object:IsA 'BasePart' then
					table.insert(Parts, Object);

				elseif Object:IsA 'Smoke' or Object:IsA 'Fire' or Object:IsA 'Sparkles' or Object:IsA 'DataModelMesh' or Object:IsA 'Decal' or Object:IsA 'Texture' or Object:IsA 'Weld' or Object:IsA 'Light' then
					table.insert(Parts, Object.Parent);
				end;

			end;

		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player);

		-- Make sure the player is allowed to perform changes to these parts
		if Security.ArePartsViolatingAreas(Parts, Player, AreaPermissions) then
			return;
		end;

		-- After confirming permissions, perform each removal
		for _, Object in pairs(Objects) do

			-- Store the part's current parent
			local LastParent = LastParents[Object];
			LastParents[Object] = Object.Parent;

			-- Register the object
			CreatedInstances[Object] = Object;

			-- Set the object's parent to the last parent
			Object.Parent = LastParent;

		end;

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

	['SyncSurface'] = function (Changes)
		-- Updates parts server-side given their new surfaces

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

			-- Apply each surface change
			for Surface, SurfaceType in pairs(Change.Surfaces) do
				Part[Surface .. 'Surface'] = SurfaceType;
			end;

		end;

	end;

	['CreateLights'] = function (Changes)
		-- Creates lights in the given parts

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

		-- Make a list of allowed light type requests
		local AllowedLightTypes = { PointLight = true, SurfaceLight = true, SpotLight = true };

		-- Keep track of the newly created lights
		local Lights = {};

		-- Create each light
		for Part, Change in pairs(ChangeSet) do

			-- Make sure the requested light type is valid
			if AllowedLightTypes[Change.LightType] then

				-- Create the light
				local Light = Instance.new(Change.LightType, Part);
				table.insert(Lights, Light);

				-- Register the light
				CreatedInstances[Light] = Light;

			end;

		end;

		-- Return the new lights
		return Lights;

	end;

	['SyncLighting'] = function (Changes)
		-- Updates aspects of the given selection's lights

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

		-- Make a list of allowed light type requests
		local AllowedLightTypes = { PointLight = true, SurfaceLight = true, SpotLight = true };

		-- Update each part's lights
		for Part, Change in pairs(ChangeSet) do

			-- Make sure that the light type requested is valid
			if AllowedLightTypes[Change.LightType] then

				-- Grab the part's light
				local Light = Support.GetChildOfClass(Part, Change.LightType);

				-- Make sure the light exists
				if Light then

					-- Make the requested changes
					if Change.Range ~= nil then
						Light.Range = Change.Range;
					end;
					if Change.Brightness ~= nil then
						Light.Brightness = Change.Brightness;
					end;
					if Change.Color ~= nil then
						Light.Color = Change.Color;
					end;
					if Change.Shadows ~= nil then
						Light.Shadows = Change.Shadows;
					end;
					if Change.Face ~= nil then
						Light.Face = Change.Face;
					end;
					if Change.Angle ~= nil then
						Light.Angle = Change.Angle;
					end;

				end;

			end;

		end;

	end;

	['CreateDecorations'] = function (Changes)
		-- Creates decorations in the given parts

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

		-- Make a list of allowed decoration type requests
		local AllowedDecorationTypes = { Smoke = true, Fire = true, Sparkles = true };

		-- Keep track of the newly created decorations
		local Decorations = {};

		-- Create each decoration
		for Part, Change in pairs(ChangeSet) do

			-- Make sure the requested decoration type is valid
			if AllowedDecorationTypes[Change.DecorationType] then

				-- Create the decoration
				local Decoration = Instance.new(Change.DecorationType, Part);
				table.insert(Decorations, Decoration);

				-- Register the decoration
				CreatedInstances[Decoration] = Decoration;

			end;

		end;

		-- Return the new decorations
		return Decorations;

	end;

	['SyncDecorate'] = function (Changes)
		-- Updates aspects of the given selection's decorations

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

		-- Make a list of allowed decoration type requests
		local AllowedDecorationTypes = { Smoke = true, Fire = true, Sparkles = true };

		-- Update each part's decorations
		for Part, Change in pairs(ChangeSet) do

			-- Make sure that the decoration type requested is valid
			if AllowedDecorationTypes[Change.DecorationType] then

				-- Grab the part's decoration
				local Decoration = Support.GetChildOfClass(Part, Change.DecorationType);

				-- Make sure the decoration exists
				if Decoration then

					-- Make the requested changes
					if Change.Color ~= nil then
						Decoration.Color = Change.Color;
					end;
					if Change.Opacity ~= nil then
						Decoration.Opacity = Change.Opacity;
					end;
					if Change.RiseVelocity ~= nil then
						Decoration.RiseVelocity = Change.RiseVelocity;
					end;
					if Change.Size ~= nil then
						Decoration.Size = Change.Size;
					end;
					if Change.Heat ~= nil then
						Decoration.Heat = Change.Heat;
					end;
					if Change.SecondaryColor ~= nil then
						Decoration.SecondaryColor = Change.SecondaryColor;
					end;
					if Change.SparkleColor ~= nil then
						Decoration.SparkleColor = Change.SparkleColor;
					end;

				end;

			end;

		end;

	end;

	['CreateMeshes'] = function (Changes)
		-- Creates meshes in the given parts

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

		-- Keep track of the newly created meshes
		local Meshes = {};

		-- Create each mesh
		for Part, Change in pairs(ChangeSet) do

			-- Create the mesh
			local Mesh = Instance.new('SpecialMesh', Part);
			table.insert(Meshes, Mesh);

			-- Register the mesh
			CreatedInstances[Mesh] = Mesh;

		end;

		-- Return the new meshes
		return Meshes;

	end;

	['SyncMesh'] = function (Changes)
		-- Updates aspects of the given selection's meshes

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

		-- Update each part's meshes
		for Part, Change in pairs(ChangeSet) do

			-- Grab the part's mesh
			local Mesh = Support.GetChildOfClass(Part, 'SpecialMesh');

			-- Make sure the mesh exists
			if Mesh then

				-- Make the requested changes
				if Change.VertexColor ~= nil then
					Mesh.VertexColor = Change.VertexColor;
				end;
				if Change.MeshType ~= nil then
					Mesh.MeshType = Change.MeshType;
				end;
				if Change.Scale ~= nil then
					Mesh.Scale = Change.Scale;
				end;
				if Change.Offset ~= nil then
					Mesh.Offset = Change.Offset;
				end;
				if Change.MeshId ~= nil then
					Mesh.MeshId = Change.MeshId;
				end;
				if Change.TextureId ~= nil then
					Mesh.TextureId = Change.TextureId;
				end;

			end;

		end;

	end;

	['CreateTextures'] = function (Changes)
		-- Creates textures in the given parts

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

		-- Make a list of allowed texture type requests
		local AllowedTextureTypes = { Texture = true, Decal = true };

		-- Keep track of the newly created textures
		local Textures = {};

		-- Create each texture
		for Part, Change in pairs(ChangeSet) do

			-- Make sure the requested light type is valid
			if AllowedTextureTypes[Change.TextureType] then

				-- Create the texture
				local Texture = Instance.new(Change.TextureType, Part);
				Texture.Face = Change.Face;
				table.insert(Textures, Texture);

				-- Register the texture
				CreatedInstances[Texture] = Texture;

			end;

		end;

		-- Return the new textures
		return Textures;

	end;

	['SyncTexture'] = function (Changes)
		-- Updates aspects of the given selection's textures

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

		-- Make a list of allowed texture type requests
		local AllowedTextureTypes = { Texture = true, Decal = true };

		-- Update each part's textures
		for Part, Change in pairs(ChangeSet) do

			-- Make sure that the texture type requested is valid
			if AllowedTextureTypes[Change.TextureType] then

				-- Get the right textures within the part
				for _, Texture in pairs(Part:GetChildren()) do
					if Texture.ClassName == Change.TextureType and Texture.Face == Change.Face then

						-- Perform the changes
						if Change.Texture ~= nil then
							Texture.Texture = Change.Texture;
						end;
						if Change.Transparency ~= nil then
							Texture.Transparency = Change.Transparency;
						end;
						if Change.StudsPerTileU ~= nil then
							Texture.StudsPerTileU = Change.StudsPerTileU;
						end;
						if Change.StudsPerTileV ~= nil then
							Texture.StudsPerTileV = Change.StudsPerTileV;
						end;

					end;
				end;

			end;

		end;

	end;

	['SyncAnchor'] = function (Changes)
		-- Updates parts server-side given their new anchor status

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
			Part.Anchored = Change.Anchored;
		end;

	end;

	['SyncCollision'] = function (Changes)
		-- Updates parts server-side given their new collision status

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
			Part.CanCollide = Change.CanCollide;
		end;

	end;

	['SyncMaterial'] = function (Changes)
		-- Updates parts server-side given their new material

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
			if Change.Material ~= nil then
				Part.Material = Change.Material;
			end;
			if Change.Transparency ~= nil then
				Part.Transparency = Change.Transparency;
			end;
			if Change.Reflectance ~= nil then
				Part.Reflectance = Change.Reflectance;
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