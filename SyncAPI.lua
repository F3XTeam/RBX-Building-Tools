local HttpService = game:GetService('HttpService')
local RunService = game:GetService('RunService')

-- References
SyncAPI = script.Parent;
Tool = SyncAPI.Parent;
Player = nil;

-- Libraries
Security = require(Tool.Core.Security);
RegionModule = require(Tool.Libraries.Region);
Support = require(Tool.Libraries.SupportLibrary);
Serialization = require(Tool.Libraries.SerializationV3);

-- Import services
Support.ImportServices();

-- Default options
Options = {
	DisallowLocked = false
}

-- Keep track of created items in memory to not lose them in garbage collection
CreatedInstances = {};
LastParents = {};

-- Determine whether we're in tool or plugin mode
ToolMode = (Tool.Parent:IsA 'Plugin') and 'Plugin' or 'Tool'

local IsHttpServiceEnabled = nil

-- List of actions that could be requested
Actions = {

	['RecolorHandle'] = function (NewColor)
		-- Recolors the tool handle
		Tool.Handle.BrickColor = NewColor;
	end;

	['Clone'] = function (Items, Parent)
		-- Clones the given items

		-- Validate arguments
		assert(type(Items) == 'table', 'Invalid items')
		assert(typeof(Parent) == 'Instance', 'Invalid parent')
		assert(Security.IsLocationAllowed(Parent, Player), 'Permission denied for client')

		-- Check if items modifiable
		if not CanModifyItems(Items) then
			return {}
		end

		-- Check if parts intruding into private areas
		local Parts = GetPartsFromSelection(Items)
		if Security.ArePartsViolatingAreas(Parts, Player, false) then
			return {}
		end

		local Clones = {}

		-- Clone items
		for _, Item in pairs(Items) do
			local Clone = Item:Clone()
			Clone.Parent = Parent

			-- Register the clone
			table.insert(Clones, Clone)
			CreatedInstances[Item] = Item
		end

		-- Return the clones
		return Clones
	end;

	['CreatePart'] = function (PartType, Position, Parent)
		-- Creates a new part based on `PartType`

		-- Validate requested parent
		assert(typeof(Parent) == 'Instance', 'Invalid parent')
		assert(Security.IsLocationAllowed(Parent, Player), 'Permission denied for client')

		-- Create the part
		local NewPart = CreatePart(PartType);

		-- Position the part
		NewPart.CFrame = Position;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas({ NewPart }), Player);

		-- Make sure the player is allowed to create parts in the area
		if Security.ArePartsViolatingAreas({ NewPart }, Player, false, AreaPermissions) then
			return;
		end;

		-- Parent the part
		NewPart.Parent = Parent

		-- Register the part
		CreatedInstances[NewPart] = NewPart;

		-- Return the part
		return NewPart;
	end;

	['CreateGroup'] = function (Type, Parent, Items)
		-- Creates a new group of type `Type`

		local ValidGroupTypes = {
			Model = true,
			Folder = true
		}

		-- Validate arguments
		assert(ValidGroupTypes[Type], 'Invalid group type')
		assert(typeof(Parent) == 'Instance', 'Invalid parent')
		assert(Security.IsLocationAllowed(Parent, Player), 'Permission denied for client')

		-- Check if items selectable
		if not CanModifyItems(Items) then
			return
		end

		-- Check if parts intruding into private areas
		local Parts = GetPartsFromSelection(Items)
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player)
		if Security.ArePartsViolatingAreas(Parts, Player, true, AreaPermissions) then
			return
		end

		-- Create group
		local Group = Instance.new(Type)

		-- Attach children
		for _, Item in pairs(Items) do
			Item.Parent = Group
		end

		-- Parent group
		Group.Parent = Parent

		-- Make joints
		if Type == 'Model' then
			Group:MakeJoints()
		elseif Type == 'Folder' then
			local Parts = Support.GetDescendantsWhichAreA(Group, 'BasePart')
			for _, Part in pairs(Parts) do
				Part:MakeJoints()
			end
		end

		-- Return the new group
		return Group

	end,

	['Ungroup'] = function (Groups)

		-- Validate arguments
		assert(type(Groups) == 'table', 'Invalid groups')

		-- Check if items modifiable
		if not CanModifyItems(Groups) then
			return
		end

		-- Check if parts intruding into private areas
		local Parts = GetPartsFromSelection(Groups)
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player)
		if Security.ArePartsViolatingAreas(Parts, Player, true, AreaPermissions) then
			return
		end

		local Results = {}

		-- Check each group
		for Key, Group in ipairs(Groups) do
			assert(typeof(Group) == 'Instance', 'Invalid group')

			-- Track group children
			local Children = {}
			Results[Key] = Children

			-- Unpack group children into parent
			local NewParent = Group.Parent
			for _, Child in pairs(Group:GetChildren()) do
				LastParents[Child] = Group
				Children[#Children + 1] = Child
				Child.Parent = NewParent
				if Child:IsA 'BasePart' then
					Child:MakeJoints()
				elseif Child:IsA 'Folder' then
					local Parts = Support.GetDescendantsWhichAreA(Child, 'BasePart')
					for _, Part in pairs(Parts) do
						Part:MakeJoints()
					end
				end
			end

			-- Track removing group
			LastParents[Group] = Group.Parent
			CreatedInstances[Group] = Group

			-- Remove group
			Group.Parent = nil
		end

		return Results
	end,

	['SetParent'] = function (Items, Parent)

		-- Validate arguments
		assert(type(Items) == 'table', 'Invalid items')
		assert(type(Parent) == 'table' or typeof(Parent) == 'Instance', 'Invalid parent')

		-- Check if items modifiable
		if not CanModifyItems(Items) then
			return
		end

		-- Check if parts intruding into private areas
		local Parts = GetPartsFromSelection(Items)
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player)
		if Security.ArePartsViolatingAreas(Parts, Player, true, AreaPermissions) then
			return
		end

		-- Move each item to different parent
		if type(Parent) == 'table' then
			for Key, Item in pairs(Items) do
				local Parent = Parent[Key]

				-- Check if parent allowed
				assert(Security.IsLocationAllowed(Parent, Player), 'Permission denied for client')

				-- Move item
				Item.Parent = Parent
				if Item:IsA 'BasePart' then
					Item:MakeJoints()
				elseif Item:IsA 'Folder' then
					local Parts = Support.GetDescendantsWhichAreA(Item, 'BasePart')
					for _, Part in pairs(Parts) do
						Part:MakeJoints()
					end
				end
			end

		-- Move to single parent
		elseif typeof(Parent) == 'Instance' then
			assert(Security.IsLocationAllowed(Parent, Player), 'Permission denied for client')

			-- Reparent items
			for _, Item in pairs(Items) do
				Item.Parent = Parent
				if Item:IsA 'BasePart' then
					Item:MakeJoints()
				elseif Item:IsA 'Folder' then
					local Parts = Support.GetDescendantsWhichAreA(Item, 'BasePart')
					for _, Part in pairs(Parts) do
						Part:MakeJoints()
					end
				end
			end
		end

	end,

	['SetName'] = function (Items, Name)

		-- Validate arguments
		assert(type(Items) == 'table', 'Invalid items')
		assert(type(Name) == 'table' or type(Name) == 'string', 'Invalid name')

		-- Check if items modifiable
		if not CanModifyItems(Items) then
			return
		end

		-- Check if parts intruding into private areas
		local Parts = GetPartsFromSelection(Items)
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player)
		if Security.ArePartsViolatingAreas(Parts, Player, true, AreaPermissions) then
			return
		end

		-- Rename each item to a different name
		if type(Name) == 'table' then
			for Key, Item in pairs(Items) do
				local Name = Name[Key]
				Item.Name = Name
			end

		-- Rename to single name
		elseif type(Name) == 'string' then
			for _, Item in pairs(Items) do
				Item.Name = Name
			end
		end

	end,

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

				elseif Object:IsA 'Smoke' or Object:IsA 'Fire' or Object:IsA 'Sparkles' or Object:IsA 'DataModelMesh' or Object:IsA 'Decal' or Object:IsA 'Texture' or Object:IsA 'Light' then
					table.insert(Parts, Object.Parent);

				elseif Object:IsA 'Model' or Object:IsA 'Folder' then
					Support.ConcatTable(Parts, Support.GetDescendantsWhichAreA(Object, 'BasePart'))
				end

			end;

		end;

		-- Check if items modifiable
		if not CanModifyItems(Objects) then
			return
		end

		-- Check if parts intruding into private areas
		if Security.ArePartsViolatingAreas(Parts, Player, true) then
			return
		end

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

			-- Make sure the object still exists, and that its last parent is registered
			if Object and LastParents[Object] then

				if Object:IsA 'BasePart' then
					table.insert(Parts, Object);

				elseif Object:IsA 'Smoke' or Object:IsA 'Fire' or Object:IsA 'Sparkles' or Object:IsA 'DataModelMesh' or Object:IsA 'Decal' or Object:IsA 'Texture' or Object:IsA 'Light' then
					table.insert(Parts, Object.Parent);

				elseif Object:IsA 'Model' or Object:IsA 'Folder' then
					Support.ConcatTable(Parts, Support.GetDescendantsWhichAreA(Object, 'BasePart'))
				end

			end;

		end;

		-- Check if items modifiable
		if not CanModifyItems(Objects) then
			return
		end

		-- Check if parts intruding into private areas
		if Security.ArePartsViolatingAreas(Parts, Player, false) then
			return
		end

		-- After confirming permissions, perform each removal
		for _, Object in pairs(Objects) do

			-- Store the part's current parent
			local LastParent = LastParents[Object];
			LastParents[Object] = Object.Parent;

			-- Register the object
			CreatedInstances[Object] = Object;

			-- Set the object's parent to the last parent
			Object.Parent = LastParent;

			-- Make joints
			if Object:IsA 'BasePart' then
				Object:MakeJoints()
			else
				local Parts = Support.GetDescendantsWhichAreA(Object, 'BasePart')
				for _, Part in pairs(Parts) do
					Part:MakeJoints()
				end
			end

		end;

	end;

	['SyncMove'] = function (Changes)
		-- Updates parts server-side given their new CFrames

		-- Grab a list of every part we're attempting to modify
		local Parts = {};
		local Models = {}
		for _, Change in pairs(Changes) do
			if Change.Part then
				table.insert(Parts, Change.Part);
			elseif Change.Model then
				table.insert(Models, Change.Model)
			end
		end;

		-- Ensure parts are selectable
		if not (CanModifyItems(Parts) and CanModifyItems(Models)) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player);

		-- Make sure the player is allowed to perform changes to these parts
		if Security.ArePartsViolatingAreas(Parts, Player, true, AreaPermissions) then
			return;
		end;

		-- Reorganize the changes
		local PartChangeSet = {}
		local ModelChangeSet = {}
		for _, Change in pairs(Changes) do
			if Change.Part then
				Change.InitialState = {
					Anchored = Change.Part.Anchored;
					CFrame = Change.Part.CFrame;
				}
				PartChangeSet[Change.Part] = Change
			elseif Change.Model then
				ModelChangeSet[Change.Model] = Change.Pivot
			end
		end;

		-- Preserve joints
		for Part, Change in pairs(PartChangeSet) do
			Change.Joints = PreserveJoints(Part, PartChangeSet)
		end;

		-- Perform each change
		for Part, Change in pairs(PartChangeSet) do

			-- Stabilize the parts and maintain the original anchor state
			Part.Anchored = true;
			Part:BreakJoints();
			Part.Velocity = Vector3.new();
			Part.RotVelocity = Vector3.new();

			-- Set the part's CFrame
			Part.CFrame = Change.CFrame;

		end;
		for Model, Pivot in pairs(ModelChangeSet) do
			Model.WorldPivot = Pivot
		end

		-- Make sure the player is authorized to move parts into this area
		if Security.ArePartsViolatingAreas(Parts, Player, false, AreaPermissions) then

			-- Revert changes if unauthorized destination
			for Part, Change in pairs(PartChangeSet) do
				Part.CFrame = Change.InitialState.CFrame;
			end;

		end;

		-- Restore the parts' original states
		for Part, Change in pairs(PartChangeSet) do
			Part:MakeJoints();
			RestoreJoints(Change.Joints);
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

		-- Ensure parts are selectable
		if not CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player);

		-- Make sure the player is allowed to perform changes to these parts
		if Security.ArePartsViolatingAreas(Parts, Player, true, AreaPermissions) then
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

			-- Set the part's size and CFrame
			Part.Size = Change.Size;
			Part.CFrame = Change.CFrame;

		end;

		-- Make sure the player is authorized to move parts into this area
		if Security.ArePartsViolatingAreas(Parts, Player, false, AreaPermissions) then

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

		-- Grab a list of every part and model we're attempting to modify
		local Parts = {};
		local Models = {}
		for _, Change in pairs(Changes) do
			if Change.Part then
				table.insert(Parts, Change.Part);
			elseif Change.Model then
				table.insert(Models, Change.Model)
			end
		end;

		-- Ensure parts are selectable
		if not (CanModifyItems(Parts) and CanModifyItems(Models)) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player);

		-- Make sure the player is allowed to perform changes to these parts
		if Security.ArePartsViolatingAreas(Parts, Player, true, AreaPermissions) then
			return;
		end;

		-- Reorganize the changes
		local PartChangeSet = {}
		local ModelChangeSet = {}
		for _, Change in pairs(Changes) do
			if Change.Part then
				Change.InitialState = {
					Anchored = Change.Part.Anchored;
					CFrame = Change.Part.CFrame;
				}
				PartChangeSet[Change.Part] = Change
			elseif Change.Model then
				ModelChangeSet[Change.Model] = Change.Pivot
			end
		end;

		-- Preserve joints
		for Part, Change in pairs(PartChangeSet) do
			Change.Joints = PreserveJoints(Part, PartChangeSet)
		end;

		-- Perform each change
		for Part, Change in pairs(PartChangeSet) do

			-- Stabilize the parts and maintain the original anchor state
			Part.Anchored = true;
			Part:BreakJoints();
			Part.Velocity = Vector3.new();
			Part.RotVelocity = Vector3.new();

			-- Set the part's CFrame
			Part.CFrame = Change.CFrame;

		end;
		for Model, Pivot in pairs(ModelChangeSet) do
			Model.WorldPivot = Pivot
		end

		-- Make sure the player is authorized to move parts into this area
		if Security.ArePartsViolatingAreas(Parts, Player, false, AreaPermissions) then

			-- Revert changes if unauthorized destination
			for Part, Change in pairs(PartChangeSet) do
				Part.CFrame = Change.InitialState.CFrame;
			end;

		end;

		-- Restore the parts' original states
		for Part, Change in pairs(PartChangeSet) do
			Part:MakeJoints();
			RestoreJoints(Change.Joints);
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

		-- Ensure parts are selectable
		if not CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player);

		-- Make sure the player is allowed to perform changes to these parts
		if Security.ArePartsViolatingAreas(Parts, Player, true, AreaPermissions) then
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
			Part.Color = Change.Color;

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

		-- Ensure parts are selectable
		if not CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player);

		-- Make sure the player is allowed to perform changes to these parts
		if Security.ArePartsViolatingAreas(Parts, Player, true, AreaPermissions) then
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

		-- Ensure parts are selectable
		if not CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player);

		-- Make sure the player is allowed to perform changes to these parts
		if Security.ArePartsViolatingAreas(Parts, Player, true, AreaPermissions) then
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

		-- Ensure parts are selectable
		if not CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player);

		-- Make sure the player is allowed to perform changes to these parts
		if Security.ArePartsViolatingAreas(Parts, Player, true, AreaPermissions) then
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

		-- Ensure parts are selectable
		if not CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player);

		-- Make sure the player is allowed to perform changes to these parts
		if Security.ArePartsViolatingAreas(Parts, Player, true, AreaPermissions) then
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

		-- Ensure parts are selectable
		if not CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player);

		-- Make sure the player is allowed to perform changes to these parts
		if Security.ArePartsViolatingAreas(Parts, Player, true, AreaPermissions) then
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

		-- Ensure parts are selectable
		if not CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player);

		-- Make sure the player is allowed to perform changes to these parts
		if Security.ArePartsViolatingAreas(Parts, Player, true, AreaPermissions) then
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

		-- Ensure parts are selectable
		if not CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player);

		-- Make sure the player is allowed to perform changes to these parts
		if Security.ArePartsViolatingAreas(Parts, Player, true, AreaPermissions) then
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

		-- Ensure parts are selectable
		if not CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player);

		-- Make sure the player is allowed to perform changes to these parts
		if Security.ArePartsViolatingAreas(Parts, Player, true, AreaPermissions) then
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

		-- Ensure parts are selectable
		if not CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player);

		-- Make sure the player is allowed to perform changes to these parts
		if Security.ArePartsViolatingAreas(Parts, Player, true, AreaPermissions) then
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

		-- Ensure parts are selectable
		if not CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player);

		-- Make sure the player is allowed to perform changes to these parts
		if Security.ArePartsViolatingAreas(Parts, Player, true, AreaPermissions) then
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

		-- Ensure parts are selectable
		if not CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player);

		-- Make sure the player is allowed to perform changes to these parts
		if Security.ArePartsViolatingAreas(Parts, Player, true, AreaPermissions) then
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

		-- Ensure parts are selectable
		if not CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player);

		-- Make sure the player is allowed to perform changes to these parts
		if Security.ArePartsViolatingAreas(Parts, Player, true, AreaPermissions) then
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

	['CreateWelds'] = function (Parts, TargetPart)
		-- Creates welds for the given parts to the target part

		-- Ensure parts are selectable
		if not CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player);

		-- Make sure the player is allowed to perform changes to these parts
		if Security.ArePartsViolatingAreas(Parts, Player, true, AreaPermissions) then
			return;
		end;

		local Welds = {};

		-- Create the welds
		for _, Part in pairs(Parts) do

			-- Make sure we're not welding this part to itself
			if Part ~= TargetPart then

				-- Calculate the offset of the part from the target part
				local Offset = Part.CFrame:toObjectSpace(TargetPart.CFrame);

				-- Create the weld
				local Weld = Instance.new('Weld');
				Weld.Name = 'BTWeld';
				Weld.Part0 = TargetPart;
				Weld.Part1 = Part;
				Weld.C1 = Offset;
				Weld.Archivable = true;
				Weld.Parent = TargetPart;

				-- Register the weld
				CreatedInstances[Weld] = Weld;
				table.insert(Welds, Weld);

			end;

		end;

		-- Return the welds created
		return Welds;
	end;

	['RemoveWelds'] = function (Welds)
		-- Removes the given welds

		local Parts = {};

		-- Go through each weld
		for _, Weld in pairs(Welds) do

			-- Make sure each given weld is valid
			if Weld.ClassName ~= 'Weld' then
				return;
			end;

			-- Collect the relevant parts for this weld
			table.insert(Parts, Weld.Part0);
			table.insert(Parts, Weld.Part1);

		end;

		-- Ensure parts are selectable
		if not CanModifyItems(Parts) then
			return;
		end;

		local WeldsRemoved = 0;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player);

		-- Go through each weld
		for _, Weld in pairs(Welds) do

			-- Check the permissions on each weld-related part
			local Part0Unauthorized = Security.ArePartsViolatingAreas({ Weld.Part0 }, Player, true, AreaPermissions);
			local Part1Unauthorized = Security.ArePartsViolatingAreas({ Weld.Part1 }, Player, true, AreaPermissions);

			-- If at least one of the involved parts is authorized, remove the weld
			if not Part0Unauthorized or not Part1Unauthorized then

				-- Register the weld
				CreatedInstances[Weld] = Weld;
				LastParents[Weld] = Weld.Parent;
				WeldsRemoved = WeldsRemoved + 1;

				-- Remove the weld
				Weld.Parent = nil;

			end;

		end;

		-- Return the number of welds removed
		return WeldsRemoved;
	end;

	['UndoRemovedWelds'] = function (Welds)
		-- Restores the given removed welds

		local Parts = {};

		-- Go through each weld
		for _, Weld in pairs(Welds) do

			-- Make sure each given weld is valid
			if Weld.ClassName ~= 'Weld' then
				return;
			end;

			-- Make sure each weld has its old parent registered
			if not LastParents[Weld] then
				return;
			end;

			-- Collect the relevant parts for this weld
			table.insert(Parts, Weld.Part0);
			table.insert(Parts, Weld.Part1);

		end;

		-- Ensure parts are selectable
		if not CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player);

		-- Go through each weld
		for _, Weld in pairs(Welds) do

			-- Check the permissions on each weld-related part
			local Part0Unauthorized = Security.ArePartsViolatingAreas({ Weld.Part0 }, Player, false, AreaPermissions);
			local Part1Unauthorized = Security.ArePartsViolatingAreas({ Weld.Part0 }, Player, false, AreaPermissions);

			-- If at least one of the involved parts is authorized, restore the weld
			if not Part0Unauthorized or not Part1Unauthorized then

				-- Store the part's current parent
				local LastParent = LastParents[Weld];
				LastParents[Weld] = Weld.Parent;

				-- Register the weld
				CreatedInstances[Weld] = Weld;

				-- Set the weld's parent to the last parent
				Weld.Parent = LastParent;

			end;

		end;

	end;

	['Export'] = function (Parts)
		-- Serializes, exports, and returns ID for importing given parts

		-- Offload action to server-side if API is running locally
		if RunService:IsClient() and not RunService:IsStudio() then
			return SyncAPI.ServerEndpoint:InvokeServer('Export', Parts);
		end;

		-- Ensure valid selection
		assert(type(Parts) == 'table', 'Invalid item table');

		-- Ensure there are items to export
		if #Parts == 0 then
			return;
		end;

		-- Ensure parts are selectable
		if not CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player);

		-- Make sure the player is allowed to access these parts
		if Security.ArePartsViolatingAreas(Parts, Player, true, AreaPermissions) then
			return;
		end;

		-- Get all descendants of the parts
		local Items = Support.CloneTable(Parts);
		for _, Part in pairs(Parts) do
			Support.ConcatTable(Items, Part:GetDescendants());
		end;

		-- After confirming permissions, serialize parts
		local SerializedBuildData = Serialization.SerializeModel(Items);

		-- Push serialized data to server
		local Response = HttpService:JSONDecode(
			HttpService:PostAsync(
				'http://f3xteam.com/bt/export',
				HttpService:JSONEncode { data = SerializedBuildData, version = 3, userId = (Player and Player.UserId) },
				Enum.HttpContentType.ApplicationJson,
				true
			)
		);

		-- Return creation ID on success
		if Response.success then
			return Response.id;
		else
			error('Export failed due to server-side error', 2);
		end;

	end;

	['IsHttpServiceEnabled'] = function ()
		-- Returns whether HttpService is enabled

		-- Offload action to server-side if API is running locally
		if RunService:IsClient() then
			return SyncAPI.ServerEndpoint:InvokeServer('IsHttpServiceEnabled')
		end

		-- Return cached status if available
		if IsHttpServiceEnabled ~= nil then
			return IsHttpServiceEnabled
		end

		-- Perform test HTTP request
		local DidSucceed, Result = pcall(function ()
			return HttpService:GetAsync('https://google.com')
		end)

		-- Determine whether HttpService is enabled based on whether request succeeded
		if DidSucceed then
			IsHttpServiceEnabled = true
		elseif (not DidSucceed) and Result:match('Http requests are not enabled') then
			IsHttpServiceEnabled = false
		end

		return IsHttpServiceEnabled or false
	end;

	['ExtractMeshFromAsset'] = function (AssetId)
		-- Returns the first found mesh in the given asset

		-- Offload action to server-side if API is running locally
		if RunService:IsClient() and not RunService:IsStudio() then
			return SyncAPI.ServerEndpoint:InvokeServer('ExtractMeshFromAsset', AssetId);
		end;

		-- Ensure valid asset ID is given
		assert(type(AssetId) == 'number', 'Invalid asset ID');

		-- Return parsed response from API
		return HttpService:JSONDecode(
			HttpService:GetAsync('http://f3xteam.com/bt/getFirstMeshData/' .. AssetId)
		);

	end;

	['ExtractImageFromDecal'] = function (DecalAssetId)
		-- Returns the first image found in the given decal asset

		-- Offload action to server-side if API is running locally
		if RunService:IsClient() and not RunService:IsStudio() then
			return SyncAPI.ServerEndpoint:InvokeServer('ExtractImageFromDecal', DecalAssetId);
		end;

		-- Return direct response from the API
		return HttpService:GetAsync('http://f3xteam.com/bt/getDecalImageID/' .. DecalAssetId);

	end;

	['SetMouseLockEnabled'] = function (Enabled)
		-- Sets whether mouse lock is enabled for the current player

		-- Offload action to server-side if API is running locally
		if RunService:IsClient() and not RunService:IsStudio() then
			return SyncAPI.ServerEndpoint:InvokeServer('SetMouseLockEnabled', Enabled);
		end;

		-- Set whether mouse lock is enabled
		Player.DevEnableMouseLock = Enabled;

	end;

	['SetLocked'] = function (Items, Locked)
		-- Locks or unlocks the specified parts

		-- Validate arguments
		assert(type(Items) == 'table', 'Invalid items')
		assert(type(Locked) == 'table' or type(Locked) == 'boolean', 'Invalid lock state')

		-- Check if items modifiable
		if not CanModifyItems(Items) then
			return
		end

		-- Check if parts intruding into private areas
		local Parts = GetPartsFromSelection(Items)
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player)
		if Security.ArePartsViolatingAreas(Parts, Player, true, AreaPermissions) then
			return
		end

		-- Set each item to a different lock state
		if type(Locked) == 'table' then
			for Key, Item in pairs(Items) do
				local Locked = Locked[Key]
				Item.Locked = Locked
			end

		-- Set to single lock state
		elseif type(Locked) == 'boolean' then
			for _, Item in pairs(Items) do
				Item.Locked = Locked
			end
		end

	end

}

function CanModifyItems(Items)
	-- Returns whether the items can be modified

	-- Check each item
	for _, Item in pairs(Items) do

		-- Catch items that cannot be reached
		local ItemAllowed = Security.IsItemAllowed(Item, Player)
		local LastParentKnown = LastParents[Item]
		if not (ItemAllowed or LastParentKnown) then
			return false
		end

		-- Catch locked parts
		if Options.DisallowLocked and (Item:IsA 'BasePart') and Item.Locked then
			return false
		end

	end

	-- Return true if all items modifiable
	return true

end

function GetPartsFromSelection(Selection)
	local Parts = {}

	-- Get parts from selection
	for _, Item in pairs(Selection) do
		if Item:IsA 'BasePart' then
			Parts[#Parts + 1] = Item

		-- Get parts within other items
		else
			for _, Descendant in pairs(Item:GetDescendants()) do
				if Descendant:IsA 'BasePart' then
					Parts[#Parts + 1] = Descendant
				end
			end
		end
	end

	-- Return parts
	return Parts
end

-- References to reduce indexing time
local GetConnectedParts = Instance.new('Part').GetConnectedParts;
local GetChildren = script.GetChildren;

function GetPartJoints(Part, Whitelist)
	-- Returns any manual joints involving `Part`

	local Joints = {};

	-- Get joints stored inside `Part`
	for Joint, JointParent in pairs(SearchJoints(Part, Part, Whitelist)) do
		Joints[Joint] = JointParent;
	end;

	-- Get joints stored inside connected parts
	for _, ConnectedPart in pairs(GetConnectedParts(Part)) do
		for Joint, JointParent in pairs(SearchJoints(ConnectedPart, Part, Whitelist)) do
			Joints[Joint] = JointParent;
		end;
	end;

	-- Return all found joints
	return Joints;

end;

-- Types of joints to assume should be preserved
local ManualJointTypes = Support.FlipTable { 'Weld', 'ManualWeld', 'ManualGlue', 'Motor', 'Motor6D' };

function SearchJoints(Haystack, Part, Whitelist)
	-- Searches for and returns manual joints in `Haystack` involving `Part` and other parts in `Whitelist`

	local Joints = {};

	-- Search the haystack for joints involving `Part`
	for _, Item in pairs(GetChildren(Haystack)) do

		-- Check if this item is a manual, intentional joint
		if ManualJointTypes[Item.ClassName] and
		   (Whitelist[Item.Part0] and Whitelist[Item.Part1]) then

			-- Save joint and state if intentional
			Joints[Item] = Item.Parent;

		end;

	end;

	-- Return the found joints
	return Joints;

end;

function RestoreJoints(Joints)
	-- Restores the joints from the given `Joints` data

	-- Restore each joint
	for Joint, JointParent in pairs(Joints) do
		Joint.Parent = JointParent;
	end;

end;

function PreserveJoints(Part, Whitelist)
	-- Preserves and returns intentional joints of `Part` connecting parts in `Whitelist`

	-- Get the part's joints
	local Joints = GetPartJoints(Part, Whitelist);

	-- Save the joints from being broken
	for Joint in pairs(Joints) do
		Joint.Parent = nil;
	end;

	-- Return the joints
	return Joints;

end;

function CreatePart(PartType)
	-- Creates and returns new part based on `PartType` with sensible defaults

	local NewPart

	if PartType == 'Normal' then
		NewPart = Instance.new('Part')
		NewPart.Size = Vector3.new(4, 1, 2)

	elseif PartType == 'Truss' then
		NewPart = Instance.new('TrussPart')

	elseif PartType == 'Wedge' then
		NewPart = Instance.new('WedgePart')
		NewPart.Size = Vector3.new(4, 1, 2)

	elseif PartType == 'Corner' then
		NewPart = Instance.new('CornerWedgePart')

	elseif PartType == 'Cylinder' then
		NewPart = Instance.new('Part')
		NewPart.Shape = 'Cylinder'
		NewPart.Size = Vector3.new(2, 2, 2)

	elseif PartType == 'Ball' then
		NewPart = Instance.new('Part')
		NewPart.Shape = 'Ball'

	elseif PartType == 'Seat' then
		NewPart = Instance.new('Seat')
		NewPart.Size = Vector3.new(4, 1, 2)

	elseif PartType == 'Vehicle Seat' then
		NewPart = Instance.new('VehicleSeat')
		NewPart.Size = Vector3.new(4, 1, 2)

	elseif PartType == 'Spawn' then
		NewPart = Instance.new('SpawnLocation')
		NewPart.Size = Vector3.new(4, 1, 2)
	end

	-- Make part surfaces smooth
	NewPart.TopSurface = Enum.SurfaceType.Smooth;
	NewPart.BottomSurface = Enum.SurfaceType.Smooth;

	-- Make sure the part is anchored
	NewPart.Anchored = true

	return NewPart
end

-- Keep current player updated in tool mode
if ToolMode == 'Tool' then

	-- Set current player if in backpack
	if Tool.Parent and Tool.Parent:IsA 'Backpack' then
		Player = Tool.Parent.Parent;

	-- Set current player if in character
	elseif Tool.Parent and Tool.Parent:IsA 'Model' then
		Player = Players:GetPlayerFromCharacter(Tool.Parent);

	-- Clear `Player` if not in possession of a player
	else
		Player = nil;
	end;

	-- Stay updated with latest player operating the tool
	Tool.AncestryChanged:Connect(function (Child, Parent)

		-- Ensure tool's parent changed
		if Child ~= Tool then
			return;
		end;

		-- Set `Player` to player of the backpack the tool is in
		if Parent and Parent:IsA 'Backpack' then
			Player = Parent.Parent;

		-- Set `Player` to player of the character holding the tool
		elseif Parent and Parent:IsA 'Model' then
			Player = Players:GetPlayerFromCharacter(Parent);

		-- Clear `Player` if tool is not parented to a player
		else
			Player = nil;
		end;

	end);

end;

-- Provide an interface into the module
return {

	-- Provide access to internal options
	Options = Options;

	-- Provide client actions API
	PerformAction = function (Client, ActionName, ...)

		-- Make sure the action exists
		local Action = Actions[ActionName];
		if not Action then
			return;
		end;

		-- Ensure client is current player in tool mode
		if ToolMode == 'Tool' then
			assert(Player and (Client == Player), 'Permission denied for client');
		end;

		-- Execute valid actions
		return Action(...);

	end;

};