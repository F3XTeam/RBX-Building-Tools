Tool = script.Parent.Parent;
Core = require(Tool.Core);
local Vendor = Tool:WaitForChild('Vendor')
local UI = Tool:WaitForChild('UI')
local Libraries = Tool:WaitForChild('Libraries')

-- Libraries
local ListenForManualWindowTrigger = require(Tool.Core:WaitForChild('ListenForManualWindowTrigger'))
local Roact = require(Vendor:WaitForChild('Roact'))
local ColorPicker = require(UI:WaitForChild('ColorPicker'))
local Dropdown = require(UI:WaitForChild('Dropdown'))
local Signal = require(Libraries:WaitForChild('Signal'))

-- Import relevant references
Selection = Core.Selection;
Support = Core.Support;
Security = Core.Security;
Support.ImportServices();

-- Initialize the tool
local MeshTool = {
	Name = 'Mesh Tool';
	Color = BrickColor.new 'Bright violet';

	-- State
	CurrentType = nil;

	-- Signals
	OnTypeChanged = Signal.new();
}

MeshTool.ManualText = [[<font face="GothamBlack" size="16">Mesh Tool  🛠</font>
Lets you add meshes to parts.<font size="6"><br /></font>

<b>TIP:</b> You can paste the link to anything with a mesh (e.g. a hat, gear, etc) and it will automatically find the right mesh and texture IDs.<font size="6"><br /></font>

<b>NOTE:</b> If HttpService is not enabled, you must type the mesh or image asset ID directly.]]

-- Container for temporary connections (disconnected automatically)
local Connections = {};

function MeshTool.Equip()
	-- Enables the tool's equipped functionality

	-- Start up our interface
	ShowUI();

end;

function MeshTool.Unequip()
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
	if MeshTool.UI then

		-- Reveal the UI
		MeshTool.UI.Visible = true;

		-- Update the UI every 0.1 seconds
		UIUpdater = Support.ScheduleRecurringTask(UpdateUI, 0.1);

		-- Skip UI creation
		return;

	end;

	-- Create the UI
	MeshTool.UI = Core.Tool.Interfaces.BTMeshToolGUI:Clone();
	MeshTool.UI.Parent = Core.UI;
	MeshTool.UI.Visible = true;

	local AddButton = MeshTool.UI.AddButton;
	local RemoveButton = MeshTool.UI.RemoveButton;

	local MeshIdInput = MeshTool.UI.MeshIdOption.TextBox;
	local TextureIdInput = MeshTool.UI.TextureIdOption.TextBox;
	local VertexColorInput = MeshTool.UI.TintOption.HSVPicker;

	MeshTypes = {
		Block = Enum.MeshType.Brick,
		Cylinder = Enum.MeshType.Cylinder,
		File = Enum.MeshType.FileMesh,
		Head = Enum.MeshType.Head,
		Sphere = Enum.MeshType.Sphere,
		Wedge = Enum.MeshType.Wedge
	};

	-- Sort the mesh types
	SortedMeshTypes = Support.Keys(MeshTypes);
	table.sort(SortedMeshTypes);

	-- Create type dropdown
	local function BuildTypeDropdown()
		return Roact.createElement(Dropdown, {
			Position = UDim2.new(0, 40, 0, 0);
			Size = UDim2.new(1, -40, 0, 25);
			Options = SortedMeshTypes;
			MaxRows = 6;
			CurrentOption = MeshTool.CurrentType;
			OnOptionSelected = function (Option)
				SetProperty('MeshType', MeshTypes[Option])
			end;
		})
	end

	-- Mount type dropdown
	local TypeDropdownHandle = Roact.mount(BuildTypeDropdown(), MeshTool.UI.TypeOption, 'Dropdown')
	MeshTool.OnTypeChanged:Connect(function ()
		Roact.update(TypeDropdownHandle, BuildTypeDropdown())
	end)

	-- Enable the scale inputs
	local XScaleInput = MeshTool.UI.ScaleOption.XInput.TextBox;
	local YScaleInput = MeshTool.UI.ScaleOption.YInput.TextBox;
	local ZScaleInput = MeshTool.UI.ScaleOption.ZInput.TextBox;
	XScaleInput.FocusLost:Connect(function (EnterPressed)
		local NewScale = tonumber(XScaleInput.Text);
		SetAxisScale('X', NewScale);
	end);
	YScaleInput.FocusLost:Connect(function (EnterPressed)
		local NewScale = tonumber(YScaleInput.Text);
		SetAxisScale('Y', NewScale);
	end);
	ZScaleInput.FocusLost:Connect(function (EnterPressed)
		local NewScale = tonumber(ZScaleInput.Text);
		SetAxisScale('Z', NewScale);
	end);

	-- Enable the offset inputs
	local XOffsetInput = MeshTool.UI.OffsetOption.XInput.TextBox;
	local YOffsetInput = MeshTool.UI.OffsetOption.YInput.TextBox;
	local ZOffsetInput = MeshTool.UI.OffsetOption.ZInput.TextBox;
	XOffsetInput.FocusLost:Connect(function (EnterPressed)
		local NewOffset = tonumber(XOffsetInput.Text);
		SetAxisOffset('X', NewOffset);
	end);
	YOffsetInput.FocusLost:Connect(function (EnterPressed)
		local NewOffset = tonumber(YOffsetInput.Text);
		SetAxisOffset('Y', NewOffset);
	end);
	ZOffsetInput.FocusLost:Connect(function (EnterPressed)
		local NewOffset = tonumber(ZOffsetInput.Text);
		SetAxisOffset('Z', NewOffset);
	end);

	-- Enable the mesh ID input
	MeshIdInput.FocusLost:Connect(function (EnterPressed)
		SetMeshId(ParseAssetId(MeshIdInput.Text));
	end);

	-- Enable the texture ID input
	TextureIdInput.FocusLost:Connect(function (EnterPressed)
		SetTextureId(ParseAssetId(TextureIdInput.Text));
	end);

	-- Enable the vertex color/tint option
	local ColorPickerHandle = nil
	VertexColorInput.MouseButton1Click:Connect(function ()
		local CommonColor = VectorToColor(Support.IdentifyCommonProperty(GetMeshes(), 'VertexColor'))
		local ColorPickerElement = Roact.createElement(ColorPicker, {
			InitialColor = CommonColor or Color3.fromRGB(255, 255, 255);
			SetPreviewColor = function (Color)
				SetPreviewTint(ColorToVector(Color))
			end;
			OnConfirm = function (Color)
				SetProperty('VertexColor', ColorToVector(Color))
				ColorPickerHandle = Roact.unmount(ColorPickerHandle)
			end;
			OnCancel = function ()
				ColorPickerHandle = Roact.unmount(ColorPickerHandle)
			end;
		})
		ColorPickerHandle = ColorPickerHandle and
			Roact.update(ColorPickerHandle, ColorPickerElement) or
			Roact.mount(ColorPickerElement, Core.UI, 'ColorPicker')
	end)

	-- Enable the mesh adding button
	AddButton.Button.MouseButton1Click:Connect(function ()
		AddMeshes();
	end);
	RemoveButton.Button.MouseButton1Click:Connect(function ()
		RemoveMeshes();
	end);

	-- Hook up manual triggering
	local SignatureButton = MeshTool.UI:WaitForChild('Title'):WaitForChild('Signature')
	ListenForManualWindowTrigger(MeshTool.ManualText, MeshTool.Color.Color, SignatureButton)

	-- Update the UI every 0.1 seconds
	UIUpdater = Support.ScheduleRecurringTask(UpdateUI, 0.1);

end;

function UpdateUI()
	-- Updates information on the UI

	-- Make sure the UI's on
	if not MeshTool.UI then
		return;
	end;

	-- Get all meshes
	local Meshes = GetMeshes();

	-- Identify all common properties
	local MeshType = Support.IdentifyCommonProperty(Meshes, 'MeshType');
	local MeshId = Support.IdentifyCommonProperty(Meshes, 'MeshId');
	local TextureId = Support.IdentifyCommonProperty(Meshes, 'TextureId');
	local VertexColor = VectorToColor(Support.IdentifyCommonProperty(Meshes, 'VertexColor'));

	-- Check if there's a file mesh in the selection
	local FileMeshInSelection = false;
	for _, Mesh in pairs(GetMeshes()) do
		if Mesh.MeshType == Enum.MeshType.FileMesh then
			FileMeshInSelection = true;
			break;
		end;
	end;

	-- Identify common scales and offsets across axes
	local XScaleVariations, YScaleVariations, ZScaleVariations = {}, {}, {};
	local XOffsetVariations, YOffsetVariations, ZOffsetVariations = {}, {}, {};
	for _, Mesh in pairs(GetMeshes()) do
		table.insert(XScaleVariations, Support.Round(Mesh.Scale.X, 3));
		table.insert(YScaleVariations, Support.Round(Mesh.Scale.Y, 3));
		table.insert(ZScaleVariations, Support.Round(Mesh.Scale.Z, 3));
		table.insert(XOffsetVariations, Support.Round(Mesh.Offset.X, 3));
		table.insert(YOffsetVariations, Support.Round(Mesh.Offset.Y, 3));
		table.insert(ZOffsetVariations, Support.Round(Mesh.Offset.Z, 3));
	end;
	local CommonXScale = Support.IdentifyCommonItem(XScaleVariations);
	local CommonYScale = Support.IdentifyCommonItem(YScaleVariations);
	local CommonZScale = Support.IdentifyCommonItem(ZScaleVariations);
	local CommonXOffset = Support.IdentifyCommonItem(XOffsetVariations);
	local CommonYOffset = Support.IdentifyCommonItem(YOffsetVariations);
	local CommonZOffset = Support.IdentifyCommonItem(ZOffsetVariations);

	-- Shortcuts to updating UI elements
	local AddButton = MeshTool.UI.AddButton;
	local RemoveButton = MeshTool.UI.RemoveButton;
	local MeshIdInput = MeshTool.UI.MeshIdOption.TextBox;
	local TextureIdInput = MeshTool.UI.TextureIdOption.TextBox;
	local VertexColorIndicator = MeshTool.UI.TintOption.Indicator;
	local XScaleInput = MeshTool.UI.ScaleOption.XInput.TextBox;
	local YScaleInput = MeshTool.UI.ScaleOption.YInput.TextBox;
	local ZScaleInput = MeshTool.UI.ScaleOption.ZInput.TextBox;
	local XOffsetInput = MeshTool.UI.OffsetOption.XInput.TextBox;
	local YOffsetInput = MeshTool.UI.OffsetOption.YInput.TextBox;
	local ZOffsetInput = MeshTool.UI.OffsetOption.ZInput.TextBox;

	-- Update the inputs
	UpdateDataInputs {
		[MeshIdInput] = MeshId and ParseAssetId(MeshId) or MeshId or '*';
		[TextureIdInput] = TextureId and ParseAssetId(TextureId) or TextureId or '*';
		[XScaleInput] = CommonXScale or '*';
		[YScaleInput] = CommonYScale or '*';
		[ZScaleInput] = CommonZScale or '*';
		[XOffsetInput] = CommonXOffset or '*';
		[YOffsetInput] = CommonYOffset or '*';
		[ZOffsetInput] = CommonZOffset or '*';
	};
	UpdateColorIndicator(VertexColorIndicator, VertexColor);

	-- Update selection state
	local MeshTypeLabel = Support.FindTableOccurrence(MeshTypes, MeshType)
	if MeshTool.CurrentType ~= MeshTypeLabel then
		MeshTool.CurrentType = MeshTypeLabel
		MeshTool.OnTypeChanged:Fire(MeshTypeLabel)
	end

	AddButton.Visible = false;
	RemoveButton.Visible = false;
	MeshTool.UI.TypeOption.Visible = false;
	MeshIdInput.Parent.Visible = false;
	TextureIdInput.Parent.Visible = false;
	VertexColorIndicator.Parent.Visible = false;
	MeshTool.UI.ScaleOption.Visible = false;
	MeshTool.UI.OffsetOption.Visible = false;

	-- Update the UI to display options depending on the mesh type
	local DisplayedItems;
	if #Meshes == 0 then
		DisplayedItems = { AddButton };

	-- Each selected part has a mesh, including a file mesh
	elseif #Meshes == #Selection.Parts and FileMeshInSelection then
		DisplayedItems = { MeshTool.UI.TypeOption, MeshTool.UI.ScaleOption, MeshTool.UI.OffsetOption, MeshIdInput.Parent, TextureIdInput.Parent, VertexColorIndicator.Parent, RemoveButton };

	-- Each selected part has a mesh
	elseif #Meshes == #Selection.Parts and not FileMeshInSelection then
		DisplayedItems = { MeshTool.UI.TypeOption, MeshTool.UI.ScaleOption, MeshTool.UI.OffsetOption, RemoveButton };

	-- Only some selected parts have meshes, including a file mesh
	elseif #Meshes ~= #Selection.Parts and FileMeshInSelection then
		DisplayedItems = { AddButton, MeshTool.UI.TypeOption, MeshTool.UI.ScaleOption, MeshTool.UI.OffsetOption, MeshIdInput.Parent, TextureIdInput.Parent, VertexColorIndicator.Parent, RemoveButton };

	-- Only some selected parts have meshes
	elseif #Meshes ~= #Selection.Parts and not FileMeshInSelection then
		DisplayedItems = { AddButton, MeshTool.UI.TypeOption, MeshTool.UI.ScaleOption, MeshTool.UI.OffsetOption, RemoveButton };

	end;

	-- Display the relevant UI elements
	DisplayLinearLayout(DisplayedItems, MeshTool.UI, UDim2.new(0, 0, 0, 20), 10);

end;

function HideUI()
	-- Hides the tool UI

	-- Make sure there's a UI
	if not MeshTool.UI then
		return;
	end;

	-- Hide the UI
	MeshTool.UI.Visible = false;

	-- Stop updating the UI
	UIUpdater:Stop();

end;

function GetMeshes()
	-- Returns all the meshes in the selection

	local Meshes = {};

	-- Get any meshes from any selected parts
	for _, Part in pairs(Selection.Parts) do
		table.insert(Meshes, Support.GetChildOfClass(Part, 'SpecialMesh'));
	end;

	-- Return the meshes
	return Meshes;
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

function VectorToColor(Vector)
	-- Returns the Color3 with the values in the given Vector3

	-- Make sure that the given Vector3 is valid
	if not Vector then return end;

	-- Return the Color3
	return Color3.new(Vector.X, Vector.Y, Vector.Z);
end;

function ColorToVector(Color)
	-- Returns the Vector3 with the values in the given Color3

	-- Make sure that the given Color3 is valid
	if not Color then return end;

	-- Return the Vector3
	return Vector3.new(Color.r, Color.g, Color.b);
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

function UpdateColorIndicator(Indicator, Color)
	-- Updates the given color indicator

	-- If there is a single color, just display it
	if Color then
		Indicator.BackgroundColor3 = Color;
		Indicator.Varies.Text = '';

	-- If the colors vary, display a * on a gray background
	else
		Indicator.BackgroundColor3 = Color3.new(222/255, 222/255, 222/255);
		Indicator.Varies.Text = '*';
	end;

end;

function DisplayLinearLayout(Items, Container, StartPosition, Padding)

	-- Keep track of the total vertical extents of all items
	local Sum = 0;

	-- Go through each item
	for ItemIndex, Item in ipairs(Items) do

		-- Make the item visible
		Item.Visible = true;

		-- Position this item underneath the past items
		Item.Position = StartPosition + UDim2.new(
			Item.Position.X.Scale,
			Item.Position.X.Offset,
			0,
			Sum + Padding
		);

		-- Update the sum of item heights
		Sum = Sum + Padding + Item.AbsoluteSize.Y;

	end;

	-- Resize the container to fit the new layout
	Container.Size = UDim2.new(0, 200, 0, 30 + Sum);

end;

function AddMeshes()

	-- Prepare the change request for the server
	local Changes = {};

	-- Go through the selection
	for _, Part in pairs(Selection.Parts) do

		-- Make sure this part doesn't already have a mesh
		if not Support.GetChildOfClass(Part, 'SpecialMesh') then

			-- Queue a mesh to be created for this part
			table.insert(Changes, { Part = Part });

		end;

	end;

	-- Send the change request to the server
	local Meshes = Core.SyncAPI:Invoke('CreateMeshes', Changes);

	-- Put together the history record
	local HistoryRecord = {
		Meshes = Meshes;
		Selection = Selection.Items;

		Unapply = function (Record)
			-- Reverts this change

			-- Select changed parts
			Selection.Replace(Record.Selection)

			-- Remove the meshes
			Core.SyncAPI:Invoke('Remove', Record.Meshes);

		end;

		Apply = function (Record)
			-- Reapplies this change

			-- Restore the meshes
			Core.SyncAPI:Invoke('UndoRemove', Record.Meshes);

			-- Select changed parts
			Selection.Replace(Record.Selection)

		end;

	};

	-- Register the history record
	Core.History.Add(HistoryRecord);

end;

function RemoveMeshes()

	-- Get all the meshes in the selection
	local Meshes = GetMeshes();

	-- Create the history record
	local HistoryRecord = {
		Meshes = Meshes;
		Selection = Selection.Items;

		Unapply = function (Record)
			-- Reverts this change

			-- Restore the meshes
			Core.SyncAPI:Invoke('UndoRemove', Record.Meshes);

			-- Select changed parts
			Selection.Replace(Record.Selection)

		end;

		Apply = function (Record)
			-- Reapplies this change

			-- Select changed parts
			Selection.Replace(Record.Selection)

			-- Remove the meshes
			Core.SyncAPI:Invoke('Remove', Record.Meshes);

		end;

	};

	-- Send the removal request
	Core.SyncAPI:Invoke('Remove', Meshes);

	-- Register the history record
	Core.History.Add(HistoryRecord);

end;

local PreviewInitialState = nil

function SetPreviewTint(Tint)
	-- Previews the given tint on the selection

	-- Reset tints to initial state if previewing is over
	if not Tint and PreviewInitialState then
		for Mesh, State in pairs(PreviewInitialState) do
			Mesh.VertexColor = State.VertexColor
		end

		-- Clear initial state
		PreviewInitialState = nil

		-- Skip rest of function
		return

	-- Ensure valid tint is given
	elseif not Tint then
		return

	-- Save initial state if first time previewing
	elseif not PreviewInitialState then
		PreviewInitialState = {}
		for _, Mesh in pairs(GetMeshes()) do
			PreviewInitialState[Mesh] = { VertexColor = Mesh.VertexColor }
		end
	end

	-- Apply preview tint
	for Mesh in pairs(PreviewInitialState) do
		Mesh.VertexColor = Tint
	end
end

function SetProperty(Property, Value)

	-- Make sure the given value is valid
	if not Value then
		return;
	end;

	-- Start a history record
	TrackChange();

	-- Go through each mesh
	for _, Mesh in pairs(GetMeshes()) do

		-- Store the state of the mesh before modification
		table.insert(HistoryRecord.Before, { Part = Mesh.Parent, [Property] = Mesh[Property] });

		-- Create the change request for this mesh
		table.insert(HistoryRecord.After, { Part = Mesh.Parent, [Property] = Value });

	end;

	-- Register the changes
	RegisterChange();

end;

function SetAxisScale(Axis, Scale)
	-- Sets the selection's scale on axis `Axis` to `Scale`

	-- Start a history record
	TrackChange();

	-- Go through each mesh
	for _, Mesh in pairs(GetMeshes()) do

		-- Store the state of the mesh before modification
		table.insert(HistoryRecord.Before, { Part = Mesh.Parent, Scale = Mesh.Scale });

		-- Put together the changed scale
		local Scale = Vector3.new(
			Axis == 'X' and Scale or Mesh.Scale.X,
			Axis == 'Y' and Scale or Mesh.Scale.Y,
			Axis == 'Z' and Scale or Mesh.Scale.Z
		);

		-- Create the change request for this mesh
		table.insert(HistoryRecord.After, { Part = Mesh.Parent, Scale = Scale });

	end;

	-- Register the changes
	RegisterChange();

end;

function SetAxisOffset(Axis, Offset)
	-- Sets the selection's offset on axis `Axis` to `Offset`

	-- Start a history record
	TrackChange();

	-- Go through each mesh
	for _, Mesh in pairs(GetMeshes()) do

		-- Store the state of the mesh before modification
		table.insert(HistoryRecord.Before, { Part = Mesh.Parent, Offset = Mesh.Offset });

		-- Put together the changed scale
		local Offset = Vector3.new(
			Axis == 'X' and Offset or Mesh.Offset.X,
			Axis == 'Y' and Offset or Mesh.Offset.Y,
			Axis == 'Z' and Offset or Mesh.Offset.Z
		);

		-- Create the change request for this mesh
		table.insert(HistoryRecord.After, { Part = Mesh.Parent, Offset = Offset });

	end;

	-- Register the changes
	RegisterChange();

end;

function SetMeshId(AssetId)
	-- Sets the meshes in the selection's mesh ID to the intended, given mesh asset

	-- Make sure the given asset ID is valid
	if not AssetId then
		return;
	end;

	-- Prepare the change request
	local Changes = {
		MeshId = 'rbxassetid://' .. AssetId;
	};

	-- Attempt a mesh extraction on the given asset
	Core.Try(Core.SyncAPI.Invoke, Core.SyncAPI, 'ExtractMeshFromAsset', AssetId)
		:Then(function (ExtractionData)

			-- Ensure extraction succeeded
			assert(ExtractionData.success, 'Extraction failed');

			-- Apply any mesh found
			local MeshId = ExtractionData.meshID;
			if MeshId then
				Changes.MeshId = 'rbxassetid://' .. MeshId;
			end;

			-- Apply any texture found
			local TextureId = ExtractionData.textureID;
			if TextureId then
				Changes.TextureId = 'rbxassetid://' .. TextureId;
			end;

			-- Apply any vertex color found
			local VertexColor = ExtractionData.tint;
			if VertexColor then
				Changes.VertexColor = Vector3.new(VertexColor.x, VertexColor.y, VertexColor.z);
			end;

			-- Apply any scale found
			local Scale = ExtractionData.scale;
			if Scale then
				Changes.Scale = Vector3.new(Scale.x, Scale.y, Scale.z);
			end;

		end);

	-- Start a history record
	TrackChange();

	-- Go through each mesh
	for _, Mesh in pairs(GetMeshes()) do

		-- Create the history change requests for this mesh
		local Before, After = { Part = Mesh.Parent }, { Part = Mesh.Parent };

		-- Gather change information to finish up the history change requests
		for Property, Value in pairs(Changes) do
			Before[Property] = Mesh[Property];
			After[Property] = Value;
		end;

		-- Store the state of the mesh before modification
		table.insert(HistoryRecord.Before, Before);

		-- Create the change request for this mesh
		table.insert(HistoryRecord.After, After);

	end;

	-- Register the changes
	RegisterChange();

end;

function SetTextureId(AssetId)
	-- Sets the meshes in the selection's texture ID to the intended, given image asset

	-- Make sure the given asset ID is valid
	if not AssetId then
		return;
	end;

	-- Prepare the change request
	local Changes = {
		TextureId = 'rbxassetid://' .. AssetId;
	};

	-- Attempt an image extraction on the given asset
	Core.Try(Core.SyncAPI.Invoke, Core.SyncAPI, 'ExtractImageFromDecal', AssetId)
		:Then(function (ExtractedImage)
			Changes.TextureId = 'rbxassetid://' .. ExtractedImage;
		end);

	-- Start a history record
	TrackChange();

	-- Go through each mesh
	for _, Mesh in pairs(GetMeshes()) do

		-- Create the history change requests for this mesh
		local Before, After = { Part = Mesh.Parent }, { Part = Mesh.Parent };

		-- Gather change information to finish up the history change requests
		for Property, Value in pairs(Changes) do
			Before[Property] = Mesh[Property];
			After[Property] = Value;
		end;

		-- Store the state of the mesh before modification
		table.insert(HistoryRecord.Before, Before);

		-- Create the change request for this mesh
		table.insert(HistoryRecord.After, After);

	end;

	-- Register the changes
	RegisterChange();

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
			Core.SyncAPI:Invoke('SyncMesh', Record.Before);

		end;

		Apply = function (Record)
			-- Applies this change

			-- Select the changed parts
			Selection.Replace(Record.Selection)

			-- Send the change request
			Core.SyncAPI:Invoke('SyncMesh', Record.After);

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
	Core.SyncAPI:Invoke('SyncMesh', HistoryRecord.After);

	-- Register the record and clear the staging
	Core.History.Add(HistoryRecord);
	HistoryRecord = nil;

end;

-- Return the tool
return MeshTool;