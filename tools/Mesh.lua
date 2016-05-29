-- Load the main tool's core environment when it's ready
repeat wait() until (
	_G.BTCoreEnv and
	_G.BTCoreEnv[script.Parent.Parent] and
	_G.BTCoreEnv[script.Parent.Parent].CoreReady
);
Core = _G.BTCoreEnv[script.Parent.Parent];

-- Import relevant references
Selection = Core.Selection;
Create = Core.Create;
Support = Core.Support;
Security = Core.Security;
Support.ImportServices();

-- Initialize the tool
local MeshTool = {

	Name = 'Mesh Tool';
	Color = BrickColor.new 'Bright violet';

	-- Standard platform event interface
	Listeners = {};

};

-- Container for temporary connections (disconnected automatically)
local Connections = {};

function Equip()
	-- Enables the tool's equipped functionality

	-- Start up our interface
	ShowUI();

end;

function Unequip()
	-- Disables the tool's equipped functionality

	-- Clear unnecessary resources
	HideUI();
	ClearConnections();

end;

MeshTool.Listeners.Equipped = Equip;
MeshTool.Listeners.Unequipped = Unequip;

function ClearConnections()
	-- Clears out temporary connections

	for ConnectionKey, Connection in pairs(Connections) do
		Connection:disconnect();
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
		UIUpdater = Core.ScheduleRecurringTask(UpdateUI, 0.1);

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

	-- Create the mesh type dropdown
	local TypeDropdown = Core.createDropdown();
	TypeDropdown.Frame.Parent = MeshTool.UI.TypeOption;
	TypeDropdown.Frame.Position = UDim2.new(0, 40, 0, 0);
	TypeDropdown.Frame.Size = UDim2.new(1, -40, 0, 25);

	-- Add the mesh types to the dropdown
	local Types = {
		Block = Enum.MeshType.Brick,
		Cylinder = Enum.MeshType.Cylinder,
		File = Enum.MeshType.FileMesh,
		Head = Enum.MeshType.Head,
		Sphere = Enum.MeshType.Sphere,
		Trapezoid = Enum.MeshType.Torso,
		Wedge = Enum.MeshType.Wedge
	};
	for TypeLabel, TypeEnum in pairs(Types) do

		-- Set the mesh type to the selected
		TypeDropdown:addOption(TypeLabel:upper()).MouseButton1Click:connect(function ()
			SetProperty('MeshType', TypeEnum);
			TypeDropdown:toggle();
		end);

	end;

	-- Enable the scale inputs
	local XScaleInput = MeshTool.UI.ScaleOption.XInput.TextBox;
	local YScaleInput = MeshTool.UI.ScaleOption.YInput.TextBox;
	local ZScaleInput = MeshTool.UI.ScaleOption.ZInput.TextBox;
	XScaleInput.FocusLost:connect(function (EnterPressed)
		local NewScale = tonumber(XScaleInput.Text);
		SetAxisScale('X', NewScale);
	end);
	YScaleInput.FocusLost:connect(function (EnterPressed)
		local NewScale = tonumber(YScaleInput.Text);
		SetAxisScale('Y', NewScale);
	end);
	ZScaleInput.FocusLost:connect(function (EnterPressed)
		local NewScale = tonumber(ZScaleInput.Text);
		SetAxisScale('Z', NewScale);
	end);

	-- Enable the offset inputs
	local XOffsetInput = MeshTool.UI.OffsetOption.XInput.TextBox;
	local YOffsetInput = MeshTool.UI.OffsetOption.YInput.TextBox;
	local ZOffsetInput = MeshTool.UI.OffsetOption.ZInput.TextBox;
	XOffsetInput.FocusLost:connect(function (EnterPressed)
		local NewOffset = tonumber(XOffsetInput.Text);
		SetAxisOffset('X', NewOffset);
	end);
	YOffsetInput.FocusLost:connect(function (EnterPressed)
		local NewOffset = tonumber(YOffsetInput.Text);
		SetAxisOffset('Y', NewOffset);
	end);
	ZOffsetInput.FocusLost:connect(function (EnterPressed)
		local NewOffset = tonumber(ZOffsetInput.Text);
		SetAxisOffset('Z', NewOffset);
	end);

	-- Enable the mesh ID input
	MeshIdInput.FocusLost:connect(function (EnterPressed)
		SetMeshId(ParseAssetId(MeshIdInput.Text));
	end);

	-- Enable the texture ID input
	TextureIdInput.FocusLost:connect(function (EnterPressed)
		SetTextureId(ParseAssetId(TextureIdInput.Text));
	end);

	-- Enable the vertex color/tint option
	VertexColorInput.MouseButton1Click:connect(function ()
		Core.ColorPicker:start(
			function (Color) SetProperty('VertexColor', ColorToVector(Color)) end,
			VectorToColor(Support.IdentifyCommonProperty(GetMeshes(), 'VertexColor')) or Color3.new(1, 1, 1)
		);
	end);

	-- Enable the mesh adding button
	AddButton.Button.MouseButton1Click:connect(function ()
		AddMeshes();
	end);
	RemoveButton.Button.MouseButton1Click:connect(function ()
		RemoveMeshes();
	end);

	-- Update the UI every 0.1 seconds
	UIUpdater = Core.ScheduleRecurringTask(UpdateUI, 0.1);

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
		table.insert(XScaleVariations, Mesh.Scale.X);
		table.insert(YScaleVariations, Mesh.Scale.Y);
		table.insert(ZScaleVariations, Mesh.Scale.Z);
		table.insert(XOffsetVariations, Mesh.Offset.X);
		table.insert(YOffsetVariations, Mesh.Offset.Y);
		table.insert(ZOffsetVariations, Mesh.Offset.Z);
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
	local MeshTypeDropdown = MeshTool.UI.TypeOption.Dropdown;
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
		[TextureIdInput] = TextureId and ParseAssetId(MeshId) or TextureId or '*';
		[XScaleInput] = CommonXScale or '*';
		[YScaleInput] = CommonYScale or '*';
		[ZScaleInput] = CommonZScale or '*';
		[XOffsetInput] = CommonXOffset or '*';
		[YOffsetInput] = CommonYOffset or '*';
		[ZOffsetInput] = CommonZOffset or '*';
	};
	UpdateColorIndicator(VertexColorIndicator, VertexColor);

	local Types = {
		Block = Enum.MeshType.Brick,
		Cylinder = Enum.MeshType.Cylinder,
		File = Enum.MeshType.FileMesh,
		Head = Enum.MeshType.Head,
		Sphere = Enum.MeshType.Sphere,
		Trapezoid = Enum.MeshType.Torso,
		Wedge = Enum.MeshType.Wedge
	};
	local MeshTypeLabel = Support.FindTableOccurrence(Types, MeshType);
	MeshTypeDropdown.MainButton.CurrentOption.Text = MeshTypeLabel and MeshTypeLabel:upper() or '*';

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
	elseif #Meshes == #Selection.Items and FileMeshInSelection then
		DisplayedItems = { MeshTool.UI.TypeOption, MeshTool.UI.ScaleOption, MeshTool.UI.OffsetOption, MeshIdInput.Parent, TextureIdInput.Parent, VertexColorIndicator.Parent, RemoveButton };

	-- Each selected part has a mesh
	elseif #Meshes == #Selection.Items and not FileMeshInSelection then
		DisplayedItems = { MeshTool.UI.TypeOption, MeshTool.UI.ScaleOption, MeshTool.UI.OffsetOption, RemoveButton };

	-- Only some selected parts have meshes, including a file mesh
	elseif #Meshes ~= #Selection.Items and FileMeshInSelection then
		DisplayedItems = { AddButton, MeshTool.UI.TypeOption, MeshTool.UI.ScaleOption, MeshTool.UI.OffsetOption, MeshIdInput.Parent, TextureIdInput.Parent, VertexColorIndicator.Parent, RemoveButton };

	-- Only some selected parts have meshes
	elseif #Meshes ~= #Selection.Items and not FileMeshInSelection then
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
	for _, Part in pairs(Selection.Items) do
		table.insert(Meshes, Support.GetChildOfClass(Part, 'SpecialMesh'));
	end;

	-- Return the meshes
	return Meshes;
end;

function ParseAssetId(Input)
	-- Returns the intended asset ID for the given input

	-- Get the ID number from the input
	local Id = tonumber(Input) or Input:lower():match('%?id=([0-9]+)');

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
	for _, Part in pairs(Selection.Items) do

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

		Unapply = function (HistoryRecord)
			-- Reverts this change

			-- Select changed parts
			Selection.Replace(Support.GetListMembers(HistoryRecord.Meshes, 'Parent'));

			-- Remove the meshes
			Core.SyncAPI:Invoke('Remove', HistoryRecord.Meshes);

		end;

		Apply = function (HistoryRecord)
			-- Reapplies this change

			-- Restore the meshes
			Core.SyncAPI:Invoke('UndoRemove', HistoryRecord.Meshes);

			-- Select changed parts
			Selection.Replace(Support.GetListMembers(HistoryRecord.Meshes, 'Parent'));

		end;

	};

	-- Register the history record
	Core.History:Add(HistoryRecord);

end;

function RemoveMeshes()

	-- Get all the meshes in the selection
	local Meshes = GetMeshes();

	-- Create the history record
	local HistoryRecord = {
		Meshes = Meshes;

		Unapply = function (HistoryRecord)
			-- Reverts this change

			-- Restore the meshes
			Core.SyncAPI:Invoke('UndoRemove', HistoryRecord.Meshes);

			-- Select changed parts
			Selection.Replace(Support.GetListMembers(HistoryRecord.Meshes, 'Parent'));

		end;

		Apply = function (HistoryRecord)
			-- Reapplies this change

			-- Select changed parts
			Selection.Replace(Support.GetListMembers(HistoryRecord.Meshes, 'Parent'));

			-- Remove the meshes
			Core.SyncAPI:Invoke('Remove', HistoryRecord.Meshes);

		end;

	};

	-- Send the removal request
	Core.SyncAPI:Invoke('Remove', Meshes);

	-- Register the history record
	Core.History:Add(HistoryRecord);

end;

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
		MeshId = 'http://www.roblox.com/asset/?id=' .. AssetId;
	};

	-- Only attempt extraction if HttpService is enabled
	if Core.HttpAvailable then

		-- Attempt a mesh extraction on the given asset
		local MeshExtractionUrl = ('http://f3xteam.com/bt/getFirstMeshData/%s'):format(AssetId);
		local ExtractionData = Core.Tool.HttpInterface.GetAsync:InvokeServer(MeshExtractionUrl);

		-- Check if the mesh extraction yielded any data
		if ExtractionData and ExtractionData:len() > 0 then

			-- Parse the extracted mesh information
			ExtractionData = HttpService:JSONDecode(ExtractionData);
			if ExtractionData and ExtractionData.success then
			
				-- Apply any mesh ID found
				local MeshId = ExtractionData.meshID;
				if MeshId then
					Changes.MeshId = 'http://www.roblox.com/asset/?id=' .. MeshId;
				end;

				-- Apply any texture ID found
				local TextureId = ExtractionData.textureID;
				if TextureId then
					Changes.TextureId = 'http://www.roblox.com/asset/?id=' .. TextureId;
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

			end;

		end;

	end;

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
		TextureId = 'http://www.roblox.com/asset/?id=' .. AssetId;
	};

	-- Only attempt extraction if HttpService is enabled
	if Core.HttpAvailable then

		-- Attempt an image extraction on the given asset
		local ImageExtractionUrl = ('http://f3xteam.com/bt/getDecalImageID/%s'):format(AssetId);
		local ExtractionData = Core.Tool.HttpInterface.GetAsync:InvokeServer(ImageExtractionUrl);

		-- Check if the image extraction yielded any data
		if ExtractionData and ExtractionData:len() > 0 then
			Changes.TextureId = 'http://www.roblox.com/asset/?id=' .. ExtractionData;
		end;

	end;

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

		Unapply = function (Record)
			-- Reverts this change

			-- Select the changed parts
			Selection.Replace(Support.GetListMembers(Record.Before, 'Part'));

			-- Send the change request
			Core.SyncAPI:Invoke('SyncMesh', Record.Before);

		end;

		Apply = function (Record)
			-- Applies this change

			-- Select the changed parts
			Selection.Replace(Support.GetListMembers(Record.After, 'Part'));

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
	Core.History:Add(HistoryRecord);
	HistoryRecord = nil;

end;

-- Mark the tool as fully loaded
Core.Tools.Mesh = MeshTool;
MeshTool.Loaded = true;