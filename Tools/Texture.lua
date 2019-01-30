Tool = script.Parent.Parent;
Core = require(Tool.Core);

-- Import relevant references
Selection = Core.Selection;
Support = Core.Support;
Security = Core.Security;
Support.ImportServices();

-- Initialize the tool
local TextureTool = {

	Name = 'Texture Tool';
	Color = BrickColor.new 'Bright violet';

	-- Default options
	Type = 'Decal';
	Face = Enum.NormalId.Front;

};

-- Container for temporary connections (disconnected automatically)
local Connections = {};

function TextureTool.Equip()
	-- Enables the tool's equipped functionality

	-- Start up our interface
	ShowUI();
	EnableSurfaceClickSelection();

	-- Set our current texture type and face
	SetTextureType(TextureTool.Type);
	SetFace(TextureTool.Face);

end;

function TextureTool.Unequip()
	-- Disables the tool's equipped functionality

	-- Clear unnecessary resources
	HideUI();
	ClearConnections();

end;

function ClearConnections()
	-- Clears out temporary connections

	for ConnectionKey, Connection in pairs(Connections) do
		Connection:Disconnect();
		Connections[ConnectionKey] = nil;
	end;

end;

function ShowUI()
	-- Creates and reveals the UI

	-- Reveal UI if already created
	if UI then

		-- Reveal the UI
		UI.Visible = true;

		-- Update the UI every 0.1 seconds
		UIUpdater = Support.ScheduleRecurringTask(UpdateUI, 0.1);

		-- Skip UI creation
		return;

	end;

	-- Create the UI
	UI = Core.Tool.Interfaces.BTTextureToolGUI:Clone();
	UI.Parent = Core.UI;
	UI.Visible = true;

	-- References to UI elements
	local AddButton = UI.AddButton;
	local RemoveButton = UI.RemoveButton;
	local DecalModeButton = UI.ModeOption.Decal.Button;
	local TextureModeButton = UI.ModeOption.Texture.Button;
	local ImageIdInput = UI.ImageIDOption.TextBox;
	local TransparencyInput = UI.TransparencyOption.Input.TextBox;
	local RepeatXInput = UI.RepeatOption.XInput.TextBox;
	local RepeatYInput = UI.RepeatOption.YInput.TextBox;

	-- Enable the texture type switch
	DecalModeButton.MouseButton1Click:Connect(function ()
		SetTextureType 'Decal';
	end);
	TextureModeButton.MouseButton1Click:Connect(function ()
		SetTextureType 'Texture';
	end);

	-- Create the face selection dropdown
	local Faces = { 'Top', 'Bottom', 'Front', 'Back', 'Left', 'Right' };
	FaceDropdown = Core.Cheer(UI.SideOption.Dropdown).Start(Faces, '', function (Face)
		SetFace(Enum.NormalId[Face]);
	end);

	-- Enable the image ID input
	ImageIdInput.FocusLost:Connect(function (EnterPressed)
		SetTextureId(TextureTool.Type, TextureTool.Face, ParseAssetId(ImageIdInput.Text));
	end);

	-- Enable other inputs
	SyncInputToProperty('Transparency', TransparencyInput);
	SyncInputToProperty('StudsPerTileU', RepeatXInput);
	SyncInputToProperty('StudsPerTileV', RepeatYInput);

	-- Enable the texture adding button
	AddButton.Button.MouseButton1Click:Connect(function ()
		AddTextures(TextureTool.Type, TextureTool.Face);
	end);
	RemoveButton.Button.MouseButton1Click:Connect(function ()
		RemoveTextures(TextureTool.Type, TextureTool.Face);
	end);

	-- Update the UI every 0.1 seconds
	UIUpdater = Support.ScheduleRecurringTask(UpdateUI, 0.1);

end;

function SyncInputToProperty(Property, Input)
	-- Enables `Input` to change the given property

	-- Enable inputs
	Input.FocusLost:Connect(function ()
		SetProperty(TextureTool.Type, TextureTool.Face, Property, tonumber(Input.Text));
	end);

end;

function EnableSurfaceClickSelection()
	-- Allows for the setting of the current face by clicking

	-- Clear out any existing connection
	if Connections.SurfaceClickSelection then
		Connections.SurfaceClickSelection:Disconnect();
		Connections.SurfaceClickSelection = nil;
	end;

	-- Add the new click connection
	Connections.SurfaceClickSelection = UserInputService.InputEnded:Connect(function (Input, GameProcessedEvent)
		if not GameProcessedEvent and Input.UserInputType == Enum.UserInputType.MouseButton1 and Selection.IsSelected(Core.Mouse.Target) then
			SetFace(Core.Mouse.TargetSurface);
		end;
	end);

end;

function HideUI()
	-- Hides the tool UI

	-- Make sure there's a UI
	if not UI then
		return;
	end;

	-- Hide the UI
	UI.Visible = false;

	-- Stop updating the UI
	UIUpdater:Stop();

end;

function GetTextures(TextureType, Face)
	-- Returns all the textures in the selection

	local Textures = {};

	-- Get any textures from any selected parts
	for _, Part in pairs(Selection.Parts) do
		for _, Child in pairs(Part:GetChildren()) do

			-- If this child is texture we're looking for, collect it
			if Child.ClassName == TextureType and Child.Face == Face then
				table.insert(Textures, Child);
			end;

		end;
	end;

	-- Return the found textures
	return Textures;

end;

-- List of creatable textures
local TextureTypes = { 'Decal', 'Texture' };

-- List of UI layouts
local Layouts = {
	EmptySelection = { 'SelectNote' };
	NoTextures = { 'ModeOption', 'SideOption', 'AddButton' };
	SomeDecals = { 'ModeOption', 'SideOption', 'ImageIDOption', 'TransparencyOption', 'AddButton', 'RemoveButton' };
	AllDecals = { 'ModeOption', 'SideOption', 'ImageIDOption', 'TransparencyOption', 'RemoveButton' };
	SomeTextures = { 'ModeOption', 'SideOption', 'ImageIDOption', 'TransparencyOption', 'RepeatOption', 'AddButton', 'RemoveButton' };
	AllTextures = { 'ModeOption', 'SideOption', 'ImageIDOption', 'TransparencyOption', 'RepeatOption', 'RemoveButton' };
};

-- List of UI elements
local UIElements = { 'SelectNote', 'ModeOption', 'SideOption', 'ImageIDOption', 'TransparencyOption', 'RepeatOption', 'AddButton', 'RemoveButton' };

-- Current UI layout
local CurrentLayout;

function ChangeLayout(Layout)
	-- Sets the UI to the given layout

	-- Make sure the new layout isn't already set
	if CurrentLayout == Layout then
		return;
	end;

	-- Set this as the current layout
	CurrentLayout = Layout;

	-- Reset the UI
	for _, ElementName in pairs(UIElements) do
		local Element = UI[ElementName];
		Element.Visible = false;
	end;

	-- Keep track of the total vertical extents of all items
	local Sum = 0;

	-- Go through each layout element
	for ItemIndex, ItemName in ipairs(Layout) do

		local Item = UI[ItemName];

		-- Make the item visible
		Item.Visible = true;

		-- Position this item underneath the past items
		Item.Position = UDim2.new(0, 0, 0, 20) + UDim2.new(
			Item.Position.X.Scale,
			Item.Position.X.Offset,
			0,
			Sum + 10
		);

		-- Update the sum of item heights
		Sum = Sum + 10 + Item.AbsoluteSize.Y;

	end;

	-- Resize the container to fit the new layout
	UI.Size = UDim2.new(0, 200, 0, 30 + Sum);

end;

function UpdateUI()
	-- Updates information on the UI

	-- Make sure the UI's on
	if not UI then
		return;
	end;

	-- Get the textures in the selection
	local Textures = GetTextures(TextureTool.Type, TextureTool.Face);

	-- References to UI elements
	local ImageIdInput = UI.ImageIDOption.TextBox;
	local TransparencyInput = UI.TransparencyOption.Input.TextBox;

	-----------------------
	-- Update the UI layout
	-----------------------

	-- Get the plural version of the current texture type
	local PluralTextureType = TextureTool.Type .. 's';

	-- Figure out the necessary UI layout
	if #Selection.Parts == 0 then
		ChangeLayout(Layouts.EmptySelection);
		return;

	-- When the selection has no textures
	elseif #Textures == 0 then
		ChangeLayout(Layouts.NoTextures);
		return;

	-- When only some selected items have textures
	elseif #Selection.Parts ~= #Textures then
		ChangeLayout(Layouts['Some' .. PluralTextureType]);

	-- When all selected items have textures
	elseif #Selection.Parts == #Textures then
		ChangeLayout(Layouts['All' .. PluralTextureType]);
	end;

	------------------------
	-- Update UI information
	------------------------

	-- Get the common properties
	local ImageId = Support.IdentifyCommonProperty(Textures, 'Texture');
	local Transparency = Support.IdentifyCommonProperty(Textures, 'Transparency');

	-- Update the common inputs
	UpdateDataInputs {
		[ImageIdInput] = ImageId and ParseAssetId(ImageId) or ImageId or '*';
		[TransparencyInput] = Transparency and Support.Round(Transparency, 3) or '*';
	};

	-- Update texture-specific information on UI
	if TextureTool.Type == 'Texture' then

		-- Get texture-specific UI elements
		local RepeatXInput = UI.RepeatOption.XInput.TextBox;
		local RepeatYInput = UI.RepeatOption.YInput.TextBox;

		-- Get texture-specific common properties
		local RepeatX = Support.IdentifyCommonProperty(Textures, 'StudsPerTileU');
		local RepeatY = Support.IdentifyCommonProperty(Textures, 'StudsPerTileV');

		-- Update inputs
		UpdateDataInputs {
			[RepeatXInput] = RepeatX and Support.Round(RepeatX, 3) or '*';
			[RepeatYInput] = RepeatY and Support.Round(RepeatY, 3) or '*';
		};

	end;

end;

function UpdateDataInputs(Data)
	-- Updates the data in the given TextBoxes when the user isn't typing in them

	-- Go through the inputs and data
	for Input, UpdatedValue in pairs(Data) do

		-- Makwe sure the user isn't typing into the input
		if not Input:IsFocused() then

			-- Set the input's value
			Input.Text = tostring(UpdatedValue);

		end;

	end;

end;

function ParseAssetId(Input)
	-- Returns the intended asset ID for the given input

	-- Get the ID number from the input
	local Id = tonumber(Input)
		or tonumber(Input:lower():match('%?id=([0-9]+)'))
		or tonumber(Input:match('/([0-9]+)/'))
		or tonumber(Input:lower():match('rbxassetid://([0-9]+)'));

	-- Return the ID
	return Id;
end;

function SetFace(Face)

	-- Update the tool option
	TextureTool.Face = Face;

	-- Update the UI
	FaceDropdown.SetOption(Face and Face.Name or '*');

end;

function SetTextureType(TextureType)

	-- Update the tool option
	TextureTool.Type = TextureType;

	-- Update the UI
	Core.ToggleSwitch(TextureType, UI.ModeOption);
	UI.AddButton.Button.Text = 'ADD ' .. TextureType:upper();
	UI.RemoveButton.Button.Text = 'REMOVE ' .. TextureType:upper();

end;

function SetProperty(TextureType, Face, Property, Value)

	-- Make sure the given value is valid
	if not Value then
		return;
	end;

	-- Start a history record
	TrackChange();

	-- Go through each texture
	for _, Texture in pairs(GetTextures(TextureType, Face)) do

		-- Store the state of the texture before modification
		table.insert(HistoryRecord.Before, { Part = Texture.Parent, TextureType = TextureType, Face = Face, [Property] = Texture[Property] });

		-- Create the change request for this texture
		table.insert(HistoryRecord.After, { Part = Texture.Parent, TextureType = TextureType, Face = Face, [Property] = Value });

	end;

	-- Register the changes
	RegisterChange();

end;

function SetTextureId(TextureType, Face, AssetId)
	-- Sets the textures in the selection to the intended, given image asset

	-- Make sure the given asset ID is valid
	if not AssetId then
		return;
	end;

	-- Prepare the change request
	local Changes = {
		Texture = 'rbxassetid://' .. AssetId;
	};

	-- Attempt an image extraction on the given asset
	Core.Try(Core.SyncAPI.Invoke, Core.SyncAPI, 'ExtractImageFromDecal', AssetId)
		:Then(function (ExtractedImage)
			Changes.Texture = 'rbxassetid://' .. ExtractedImage;
		end);

	-- Start a history record
	TrackChange();

	-- Go through each texture
	for _, Texture in pairs(GetTextures(TextureType, Face)) do

		-- Create the history change requests for this texture
		local Before, After = { Part = Texture.Parent, TextureType = TextureType, Face = Face }, { Part = Texture.Parent, TextureType = TextureType, Face = Face };

		-- Gather change information to finish up the history change requests
		for Property, Value in pairs(Changes) do
			Before[Property] = Texture[Property];
			After[Property] = Value;
		end;

		-- Store the state of the texture before modification
		table.insert(HistoryRecord.Before, Before);

		-- Create the change request for this texture
		table.insert(HistoryRecord.After, After);

	end;

	-- Register the changes
	RegisterChange();

end;

function AddTextures(TextureType, Face)

	-- Prepare the change request for the server
	local Changes = {};

	-- Go through the selection
	for _, Part in pairs(Selection.Parts) do

		-- Make sure this part doesn't already have a texture of the same type
		local HasTextures;
		for _, Child in pairs(Part:GetChildren()) do
			if Child.ClassName == TextureType and Child.Face == Face then
				HasTextures = true;
			end;
		end;

		-- Queue a texture to be created for this part, if not already existent
		if not HasTextures then
			table.insert(Changes, { Part = Part, TextureType = TextureType, Face = Face });
		end;

	end;

	-- Send the change request to the server
	local Textures = Core.SyncAPI:Invoke('CreateTextures', Changes);

	-- Put together the history record
	local HistoryRecord = {
		Textures = Textures;
		Selection = Selection.Items;

		Unapply = function (Record)
			-- Reverts this change

			-- Select changed parts
			Selection.Replace(Record.Selection)

			-- Remove the textures
			Core.SyncAPI:Invoke('Remove', Record.Textures);

		end;

		Apply = function (Record)
			-- Reapplies this change

			-- Restore the textures
			Core.SyncAPI:Invoke('UndoRemove', Record.Textures);

			-- Select changed parts
			Selection.Replace(Record.Selection)

		end;

	};

	-- Register the history record
	Core.History.Add(HistoryRecord);

end;

function RemoveTextures(TextureType, Face)

	-- Get all the textures in the selection
	local Textures = GetTextures(TextureType, Face);

	-- Create the history record
	local HistoryRecord = {
		Textures = Textures;
		Selection = Selection.Items;

		Unapply = function (Record)
			-- Reverts this change

			-- Restore the textures
			Core.SyncAPI:Invoke('UndoRemove', Record.Textures);

			-- Select changed parts
			Selection.Replace(Record.Selection)

		end;

		Apply = function (Record)
			-- Reapplies this change

			-- Select changed parts
			Selection.Replace(Record.Selection)

			-- Remove the textures
			Core.SyncAPI:Invoke('Remove', Record.Textures);

		end;

	};

	-- Send the removal request
	Core.SyncAPI:Invoke('Remove', Textures);

	-- Register the history record
	Core.History.Add(HistoryRecord);

end;

function TrackChange()

	-- Start the record
	HistoryRecord = {
		Before = {};
		After = {};
		Selection = Selection.Items;

		Unapply = function (Record)
			-- Reverts this change

			-- Select the changed parts
			Selection.Replace(Record.Selection)

			-- Send the change request
			Core.SyncAPI:Invoke('SyncTexture', Record.Before);

		end;

		Apply = function (Record)
			-- Applies this change

			-- Select the changed parts
			Selection.Replace(Record.Selection)

			-- Send the change request
			Core.SyncAPI:Invoke('SyncTexture', Record.After);

		end;

	};

end;

function RegisterChange()
	-- Finishes creating the history record and registers it

	-- Make sure there's an in-progress history record
	if not HistoryRecord then
		return;
	end;

	-- Send the change to the server
	Core.SyncAPI:Invoke('SyncTexture', HistoryRecord.After);

	-- Register the record and clear the staging
	Core.History.Add(HistoryRecord);
	HistoryRecord = nil;

end;

-- Return the tool
return TextureTool;