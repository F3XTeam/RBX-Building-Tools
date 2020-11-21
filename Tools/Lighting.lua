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
local LightingTool = {
	Name = 'Lighting Tool';
	Color = BrickColor.new 'Really black';

	-- Signals
	OnSideChanged = Signal.new();
}

LightingTool.ManualText = [[<font face="GothamBlack" size="16">Lighting Tool  🛠</font>
Lets you add point lights, surface lights, and spotlights to parts.<font size="6"><br /></font>

<b>TIP:</b> Click on the surface of any part to change a light's side quickly.]]

-- Container for temporary connections (disconnected automatically)
local Connections = {};

function LightingTool.Equip()
	-- Enables the tool's equipped functionality

	-- Start up our interface
	ShowUI();
	EnableSurfaceClickSelection();

end;

function LightingTool.Unequip()
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
	if LightingTool.UI then

		-- Reveal the UI
		LightingTool.UI.Visible = true;

		-- Update the UI every 0.1 seconds
		UIUpdater = Support.ScheduleRecurringTask(UpdateUI, 0.1);

		-- Skip UI creation
		return;

	end;

	-- Create the UI
	LightingTool.UI = Core.Tool.Interfaces.BTLightingToolGUI:Clone();
	LightingTool.UI.Parent = Core.UI;
	LightingTool.UI.Visible = true;

	-- Enable each light type UI
	EnableLightSettingsUI(LightingTool.UI.PointLight);
	EnableLightSettingsUI(LightingTool.UI.SpotLight);
	EnableLightSettingsUI(LightingTool.UI.SurfaceLight);

	-- Hook up manual triggering
	local SignatureButton = LightingTool.UI:WaitForChild('Title'):WaitForChild('Signature')
	ListenForManualWindowTrigger(LightingTool.ManualText, LightingTool.Color.Color, SignatureButton)

	-- Update the UI every 0.1 seconds
	UIUpdater = Support.ScheduleRecurringTask(UpdateUI, 0.1);
end;

function EnableSurfaceClickSelection(LightType)
	-- Allows for the setting of the face for the given light type by clicking

	-- Clear out any existing connection
	if Connections.SurfaceClickSelection then
		Connections.SurfaceClickSelection:Disconnect();
		Connections.SurfaceClickSelection = nil;
	end;

	-- Add the new click connection
	Connections.SurfaceClickSelection = Core.Mouse.Button1Down:Connect(function ()
		local _, ScopeTarget = Core.Targeting:UpdateTarget()
		if Selection.IsSelected(ScopeTarget) then
			SetSurface(LightType, Core.Mouse.TargetSurface)
		end
	end)

end;

function EnableLightSettingsUI(LightSettingsUI)
	-- Sets up the UI for the given light type settings UI

	-- Get the type of light this settings UI is for
	local LightType = LightSettingsUI.Name;

	-- Option input references
	local Options = LightSettingsUI.Options;
	local RangeInput = Options.RangeOption.Input.TextBox;
	local BrightnessInput = Options.BrightnessOption.Input.TextBox;
	local ColorPickerButton = Options.ColorOption.HSVPicker;
	local ShadowsCheckbox = Options.ShadowsOption.Checkbox;

	-- Add/remove/show button references
	local AddButton = LightSettingsUI.AddButton;
	local RemoveButton = LightSettingsUI.RemoveButton;
	local ShowButton = LightSettingsUI.ArrowButton;

	-- Enable range input
	RangeInput.FocusLost:Connect(function ()
		SetRange(LightType, tonumber(RangeInput.Text));
	end);

	-- Enable brightness input
	BrightnessInput.FocusLost:Connect(function ()
		SetBrightness(LightType, tonumber(BrightnessInput.Text));
	end);

	-- Enable color input
	local ColorPickerHandle = nil
	ColorPickerButton.MouseButton1Click:Connect(function ()
		local CommonColor = Support.IdentifyCommonProperty(GetLights(LightType), 'Color')
		local ColorPickerElement = Roact.createElement(ColorPicker, {
			InitialColor = CommonColor or Color3.fromRGB(255, 255, 255);
			SetPreviewColor = function (Color)
				PreviewColor(LightType, Color)
			end;
			OnConfirm = function (Color)
				SetColor(LightType, Color)
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

	-- Enable shadows input
	ShadowsCheckbox.MouseButton1Click:Connect(function ()
		ToggleShadows(LightType);
	end);

	-- Enable light addition button
	AddButton.MouseButton1Click:Connect(function ()
		AddLights(LightType);
	end);

	-- Enable light removal button
	RemoveButton.MouseButton1Click:Connect(function ()
		RemoveLights(LightType);
	end);

	-- Enable light options UI show button
	ShowButton.MouseButton1Click:Connect(function ()
		OpenLightOptions(LightType);
	end);

	-- Enable light type-specific features
	if LightType == 'SpotLight' or LightType == 'SurfaceLight' then

		-- Create a surface selection dropdown
		local Surfaces = {
			'Top';
			'Bottom';
			'Front';
			'Back';
			'Left';
			'Right';
		}
		local SurfaceKey = 'Current' .. LightType .. 'Side'
		local function BuildDropdown()
			return Roact.createElement(Dropdown, {
				Position = UDim2.new(0, 30, 0, 0);
				Size = UDim2.new(0, 72, 0, 25);
				MaxRows = 3;
				Options = Surfaces;
				CurrentOption = LightingTool[SurfaceKey] and LightingTool[SurfaceKey].Name;
				OnOptionSelected = function (Option)
					SetSurface(LightType, Enum.NormalId[Option])
				end;
			})
		end
		local DropdownHandle = Roact.mount(BuildDropdown(), Options.SideOption, 'Dropdown')

		-- Keep dropdown updated
		LightingTool.OnSideChanged:Connect(function ()
			Roact.update(DropdownHandle, BuildDropdown())
		end)

		-- Enable angle input
		local AngleInput = Options.AngleOption.Input.TextBox;
		AngleInput.FocusLost:Connect(function ()
			SetAngle(LightType, tonumber(AngleInput.Text));
		end);

	end;

end;

function HideUI()
	-- Hides the tool UI

	-- Make sure there's a UI
	if not LightingTool.UI then
		return;
	end;

	-- Hide the UI
	LightingTool.UI.Visible = false;

	-- Stop updating the UI
	UIUpdater:Stop();

end;

function GetLights(LightType)
	-- Returns all the lights of the given type in the selection

	local Lights = {};

	-- Get any lights from any selected parts
	for _, Part in pairs(Selection.Parts) do
		table.insert(Lights, Support.GetChildOfClass(Part, LightType));
	end;

	-- Return the lights
	return Lights;

end;

-- List of creatable light types
local LightTypes = { 'SpotLight', 'PointLight', 'SurfaceLight' };

function OpenLightOptions(LightType)
	-- Opens the settings UI for the given light type

	-- Get the UI
	local UI = LightingTool.UI[LightType];
	local UITemplate = Core.Tool.Interfaces.BTLightingToolGUI[LightType];

	-- Close up all light option UIs
	CloseLightOptions(LightType);

	-- Calculate how much to expand this options UI by
	local HeightExpansion = UDim2.new(0, 0, 0, UITemplate.Options.Size.Y.Offset);

	-- Start the options UI size from 0
	UI.Options.Size = UDim2.new(UI.Options.Size.X.Scale, UI.Options.Size.X.Offset, UI.Options.Size.Y.Scale, 0);

	-- Allow the options UI to be seen
	UI.ClipsDescendants = false;

	-- Perform the options UI resize animation
	UI.Options:TweenSize(
		UITemplate.Options.Size + HeightExpansion,
		Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true,
		function ()

			-- Allow visibility of overflowing UIs within the options UI
			UI.Options.ClipsDescendants = false;

		end
	);

	-- Expand the main UI to accommodate the expanded options UI
	LightingTool.UI:TweenSize(
		Core.Tool.Interfaces.BTLightingToolGUI.Size + HeightExpansion,
		Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true
	);

	-- Push any UIs below this one downwards
	local LightTypeIndex = Support.FindTableOccurrence(LightTypes, LightType);
	for LightTypeIndex = LightTypeIndex + 1, #LightTypes do

		-- Get the UI
		local LightType = LightTypes[LightTypeIndex];
		local UI = LightingTool.UI[LightType];

		-- Perform the position animation
		UI:TweenPosition(
			UDim2.new(
				UI.Position.X.Scale,
				UI.Position.X.Offset,
				UI.Position.Y.Scale,
				30 + 30 * (LightTypeIndex - 1) + HeightExpansion.Y.Offset
			),
			Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true
		);

	end;

	-- Enable surface setting by clicking
	EnableSurfaceClickSelection(LightType);

end;

function CloseLightOptions(Exception)
	-- Closes all light options, except the one for the given light type

	-- Go through each light type
	for LightTypeIndex, LightType in pairs(LightTypes) do

		-- Get the UI for each light type
		local UI = LightingTool.UI[LightType];
		local UITemplate = Core.Tool.Interfaces.BTLightingToolGUI[LightType];

		-- Remember the initial size for each options UI
		local InitialSize = UITemplate.Options.Size;

		-- Move each light type UI to its starting position
		UI:TweenPosition(
			UDim2.new(
				UI.Position.X.Scale,
				UI.Position.X.Offset,
				UI.Position.Y.Scale,
				30 + 30 * (LightTypeIndex - 1)
			),
			Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true
		);

		-- Make sure to not resize the exempt light type UI
		if not Exception or Exception and LightType ~= Exception then

			-- Allow the options UI to be resized
			UI.Options.ClipsDescendants = true;

			-- Perform the resize animation to close up
			UI.Options:TweenSize(
				UDim2.new(UI.Options.Size.X.Scale, UI.Options.Size.X.Offset, UI.Options.Size.Y.Scale, 0),
				Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true,
				function ()

					-- Hide the option UI
					UI.ClipsDescendants = true;

					-- Set the options UI's size to its initial size (for reexpansion)
					UI.Options.Size = InitialSize;

				end
			);

		end;

	end;

	-- Contract the main UI if no option UIs are being opened
	if not Exception then
		LightingTool.UI:TweenSize(
			Core.Tool.Interfaces.BTLightingToolGUI.Size,
			Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true
		);
	end;

end;

function UpdateUI()
	-- Updates information on the UI

	-- Make sure the UI's on
	if not LightingTool.UI then
		return;
	end;

	-- Go through each light type and update each options UI
	for _, LightType in pairs(LightTypes) do

		local Lights = GetLights(LightType);
		local LightSettingsUI = LightingTool.UI[LightType];

		-- Option input references
		local Options = LightSettingsUI.Options;
		local RangeInput = Options.RangeOption.Input.TextBox;
		local BrightnessInput = Options.BrightnessOption.Input.TextBox;
		local ColorIndicator = Options.ColorOption.Indicator;
		local ShadowsCheckbox = Options.ShadowsOption.Checkbox;

		-- Add/remove button references
		local AddButton = LightSettingsUI.AddButton;
		local RemoveButton = LightSettingsUI.RemoveButton;

		-- Hide option UIs for light types not present in the selection
		if #Lights == 0 and not LightSettingsUI.ClipsDescendants then
			CloseLightOptions();
		end;

		-------------------------------------------
		-- Show and hide "ADD" and "REMOVE" buttons
		-------------------------------------------

		-- If no selected parts have lights
		if #Lights == 0 then

			-- Show add button only
			AddButton.Visible = true;
			AddButton.Position = UDim2.new(1, -AddButton.AbsoluteSize.X - 5, 0, 3);
			RemoveButton.Visible = false;

		-- If only some selected parts have lights
		elseif #Lights < #Selection.Parts then

			-- Show both add and remove buttons
			AddButton.Visible = true;
			AddButton.Position = UDim2.new(1, -AddButton.AbsoluteSize.X - 5, 0, 3);
			RemoveButton.Visible = true;
			RemoveButton.Position = UDim2.new(1, -AddButton.AbsoluteSize.X - 5 - RemoveButton.AbsoluteSize.X - 2, 0, 3);

		-- If all selected parts have lights
		elseif #Lights == #Selection.Parts then

			-- Show remove button
			RemoveButton.Visible = true;
			RemoveButton.Position = UDim2.new(1, -RemoveButton.AbsoluteSize.X - 5, 0, 3);
			AddButton.Visible = false;

		end;

		--------------------
		-- Update each input
		--------------------

		-- Update the standard inputs
		UpdateDataInputs {
			[RangeInput] = Support.Round(Support.IdentifyCommonProperty(Lights, 'Range'), 2) or '*';
			[BrightnessInput] = Support.Round(Support.IdentifyCommonProperty(Lights, 'Brightness'), 2) or '*';
		};

		-- Update type-specific inputs
		if LightType == 'SpotLight' or LightType == 'SurfaceLight' then

			-- Update the angle input
			local AngleInput = Options.AngleOption.Input.TextBox;
			UpdateDataInputs {
				[AngleInput] = Support.Round(Support.IdentifyCommonProperty(Lights, 'Angle'), 2) or '*';
			};

			-- Update the surface dropdown input
			local Face = Support.IdentifyCommonProperty(Lights, 'Face')
			local SurfaceKey = 'Current' .. LightType .. 'Side'
			if LightingTool[SurfaceKey] ~= Face then
				LightingTool[SurfaceKey] = Face
				LightingTool.OnSideChanged:Fire()
			end
		end

		-- Update special color input
		local Color = Support.IdentifyCommonProperty(Lights, 'Color');
		if Color then
			ColorIndicator.BackgroundColor3 = Color;
			ColorIndicator.Varies.Text = '';
		else
			ColorIndicator.BackgroundColor3 = Color3.new(222/255, 222/255, 222/255);
			ColorIndicator.Varies.Text = '*';
		end;

		-- Update the special shadows input
		local ShadowsEnabled = Support.IdentifyCommonProperty(Lights, 'Shadows');
		if ShadowsEnabled == true then
			ShadowsCheckbox.Image = Core.Assets.CheckedCheckbox;
		elseif ShadowsEnabled == false then
			ShadowsCheckbox.Image = Core.Assets.UncheckedCheckbox;
		elseif ShadowsEnabled == nil then
			ShadowsCheckbox.Image = Core.Assets.SemicheckedCheckbox;
		end;

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

function AddLights(LightType)

	-- Prepare the change request for the server
	local Changes = {};

	-- Go through the selection
	for _, Part in pairs(Selection.Parts) do

		-- Make sure this part doesn't already have a light
		if not Support.GetChildOfClass(Part, LightType) then

			-- Queue a light to be created for this part
			table.insert(Changes, { Part = Part, LightType = LightType });

		end;

	end;

	-- Send the change request to the server
	local Lights = Core.SyncAPI:Invoke('CreateLights', Changes);

	-- Put together the history record
	local HistoryRecord = {
		Lights = Lights;
		Selection = Selection.Items;

		Unapply = function (Record)
			-- Reverts this change

			-- Select changed parts
			Selection.Replace(Record.Selection)

			-- Remove the lights
			Core.SyncAPI:Invoke('Remove', Record.Lights);

		end;

		Apply = function (Record)
			-- Reapplies this change

			-- Restore the lights
			Core.SyncAPI:Invoke('UndoRemove', Record.Lights);

			-- Select changed parts
			Selection.Replace(Record.Selection)

		end;

	};

	-- Register the history record
	Core.History.Add(HistoryRecord);

	-- Open the options UI for this light type
	OpenLightOptions(LightType);

end;

function RemoveLights(LightType)

	-- Get all the lights in the selection
	local Lights = GetLights(LightType);

	-- Create the history record
	local HistoryRecord = {
		Lights = Lights;
		Selection = Selection.Items;

		Unapply = function (Record)
			-- Reverts this change

			-- Restore the lights
			Core.SyncAPI:Invoke('UndoRemove', Record.Lights);

			-- Select changed parts
			Selection.Replace(Record.Selection)

		end;

		Apply = function (Record)
			-- Reapplies this change

			-- Select changed parts
			Selection.Replace(Record.Selection)

			-- Remove the lights
			Core.SyncAPI:Invoke('Remove', Record.Lights);

		end;

	};

	-- Send the removal request
	Core.SyncAPI:Invoke('Remove', Lights);

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
			Core.SyncAPI:Invoke('SyncLighting', Record.Before);

		end;

		Apply = function (Record)
			-- Applies this change

			-- Select the changed parts
			Selection.Replace(Record.Selection)

			-- Send the change request
			Core.SyncAPI:Invoke('SyncLighting', Record.After);

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
	Core.SyncAPI:Invoke('SyncLighting', HistoryRecord.After);

	-- Register the record and clear the staging
	Core.History.Add(HistoryRecord);
	HistoryRecord = nil;

end;

function SetRange(LightType, Range)

	-- Make sure the given range is valid
	if not Range then
		return;
	end;

	-- Start a history record
	TrackChange();

	-- Go through each light
	for _, Light in pairs(GetLights(LightType)) do

		-- Store the state of the light before modification
		table.insert(HistoryRecord.Before, { Part = Light.Parent, LightType = LightType, Range = Light.Range });

		-- Create the change request for this light
		table.insert(HistoryRecord.After, { Part = Light.Parent, LightType = LightType, Range = Range });

	end;

	-- Register the changes
	RegisterChange();

end;

function SetBrightness(LightType, Brightness)

	-- Make sure the given brightness is valid
	if not Brightness then
		return;
	end;

	-- Start a history record
	TrackChange();

	-- Go through each light
	for _, Light in pairs(GetLights(LightType)) do

		-- Store the state of the light before modification
		table.insert(HistoryRecord.Before, { Part = Light.Parent, LightType = LightType, Brightness = Light.Brightness });

		-- Create the change request for this light
		table.insert(HistoryRecord.After, { Part = Light.Parent, LightType = LightType, Brightness = Brightness });

	end;

	-- Register the changes
	RegisterChange();

end;

function SetColor(LightType, Color)

	-- Make sure the given color is valid
	if not Color then
		return;
	end;

	-- Start a history record
	TrackChange();

	-- Go through each light
	for _, Light in pairs(GetLights(LightType)) do

		-- Store the state of the light before modification
		table.insert(HistoryRecord.Before, { Part = Light.Parent, LightType = LightType, Color = Light.Color });

		-- Create the change request for this light
		table.insert(HistoryRecord.After, { Part = Light.Parent, LightType = LightType, Color = Color });

	end;

	-- Register the changes
	RegisterChange();

end;

local PreviewInitialState = nil

function PreviewColor(LightType, Color)
	-- Previews the given color on the selection

	-- Reset colors to initial state if previewing is over
	if not Color and PreviewInitialState then
		for Light, State in pairs(PreviewInitialState) do
			Light.Color = State.Color
		end

		-- Clear initial state
		PreviewInitialState = nil

		-- Skip rest of function
		return

	-- Ensure valid color is given
	elseif not Color then
		return

	-- Save initial state if first time previewing
	elseif not PreviewInitialState then
		PreviewInitialState = {}
		for _, Light in pairs(GetLights(LightType)) do
			PreviewInitialState[Light] = { Color = Light.Color }
		end
	end

	-- Apply preview color
	for Light in pairs(PreviewInitialState) do
		Light.Color = Color
	end
end

function ToggleShadows(LightType)

	-- Determine whether to turn shadows on or off
	local ShadowsEnabled = not Support.IdentifyCommonProperty(GetLights(LightType), 'Shadows');

	-- Start a history record
	TrackChange();

	-- Go through each light
	for _, Light in pairs(GetLights(LightType)) do

		-- Store the state of the light before modification
		table.insert(HistoryRecord.Before, { Part = Light.Parent, LightType = LightType, Shadows = Light.Shadows });

		-- Create the change request for this light
		table.insert(HistoryRecord.After, { Part = Light.Parent, LightType = LightType, Shadows = ShadowsEnabled });

	end;

	-- Register the changes
	RegisterChange();

end;

function SetSurface(LightType, Face)

	-- Make sure the given face is valid, and this is an applicable light type
	if not Face or not (LightType == 'SurfaceLight' or LightType == 'SpotLight') then
		return;
	end;

	LightingTool['Current' .. LightType .. 'Side'] = Face

	-- Start a history record
	TrackChange();

	-- Go through each light
	for _, Light in pairs(GetLights(LightType)) do

		-- Store the state of the light before modification
		table.insert(HistoryRecord.Before, { Part = Light.Parent, LightType = LightType, Face = Light.Face });

		-- Create the change request for this light
		table.insert(HistoryRecord.After, { Part = Light.Parent, LightType = LightType, Face = Face });

	end;

	-- Register the changes
	RegisterChange();

end;

function SetAngle(LightType, Angle)

	-- Make sure the given angle is valid
	if not Angle then
		return;
	end;

	-- Start a history record
	TrackChange();

	-- Go through each light
	for _, Light in pairs(GetLights(LightType)) do

		-- Store the state of the light before modification
		table.insert(HistoryRecord.Before, { Part = Light.Parent, LightType = LightType, Angle = Light.Angle });

		-- Create the change request for this light
		table.insert(HistoryRecord.After, { Part = Light.Parent, LightType = LightType, Angle = Angle });

	end;

	-- Register the changes
	RegisterChange();

end;

-- Return the tool
return LightingTool;