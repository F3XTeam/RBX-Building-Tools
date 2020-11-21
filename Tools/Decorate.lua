Tool = script.Parent.Parent;
Core = require(Tool.Core);
local Vendor = Tool:WaitForChild('Vendor')
local UI = Tool:WaitForChild('UI')

-- Libraries
local ListenForManualWindowTrigger = require(Tool.Core:WaitForChild('ListenForManualWindowTrigger'))
local Roact = require(Vendor:WaitForChild('Roact'))
local ColorPicker = require(UI:WaitForChild('ColorPicker'))

-- Import relevant references
Selection = Core.Selection;
Support = Core.Support;
Security = Core.Security;
Support.ImportServices();

-- Initialize the tool
local DecorateTool = {
	Name = 'Decorate Tool';
	Color = BrickColor.new 'Really black';
}

DecorateTool.ManualText = [[<font face="GothamBlack" size="16">Decorate Tool  🛠</font>
Allows you to add smoke, fire, and sparkles to parts.]]

-- Container for temporary connections (disconnected automatically)
local Connections = {};

function DecorateTool.Equip()
	-- Enables the tool's equipped functionality

	-- Start up our interface
	ShowUI();

end;

function DecorateTool.Unequip()
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
	if DecorateTool.UI then

		-- Reveal the UI
		DecorateTool.UI.Visible = true;

		-- Update the UI every 0.1 seconds
		UIUpdater = Support.ScheduleRecurringTask(UpdateUI, 0.1);

		-- Skip UI creation
		return;

	end;

	-- Create the UI
	DecorateTool.UI = Core.Tool.Interfaces.BTDecorateToolGUI:Clone();
	DecorateTool.UI.Parent = Core.UI;
	DecorateTool.UI.Visible = true;

	-- Enable each decoration type UI
	EnableOptionsUI(DecorateTool.UI.Smoke);
	EnableOptionsUI(DecorateTool.UI.Fire);
	EnableOptionsUI(DecorateTool.UI.Sparkles);

	-- Hook up manual triggering
	local SignatureButton = DecorateTool.UI:WaitForChild('Title'):WaitForChild('Signature')
	ListenForManualWindowTrigger(DecorateTool.ManualText, DecorateTool.Color.Color, SignatureButton)

	-- Update the UI every 0.1 seconds
	UIUpdater = Support.ScheduleRecurringTask(UpdateUI, 0.1);

end;

-- List of creatable decoration types
local DecorationTypes = { 'Smoke', 'Fire', 'Sparkles' };

function UpdateUI()
	-- Updates information on the UI

	-- Make sure the UI's on
	if not DecorateTool.UI then
		return;
	end;

	-- Go through each decoration type and update each options UI
	for _, DecorationType in pairs(DecorationTypes) do

		local Decorations = GetDecorations(DecorationType);
		local DecorationSettingsUI = DecorateTool.UI[DecorationType];

		-- Option input references
		local Options = DecorationSettingsUI.Options;

		-- Add/remove button references
		local AddButton = DecorationSettingsUI.AddButton;
		local RemoveButton = DecorationSettingsUI.RemoveButton;

		-- Hide option UIs for decoration types not present in the selection
		if #Decorations == 0 and not DecorationSettingsUI.ClipsDescendants then
			CloseOptions();
		end;

		-------------------------------------------
		-- Show and hide "ADD" and "REMOVE" buttons
		-------------------------------------------

		-- If no selected parts have decorations
		if #Decorations == 0 then

			-- Show add button only
			AddButton.Visible = true;
			AddButton.Position = UDim2.new(1, -AddButton.AbsoluteSize.X - 5, 0, 3);
			RemoveButton.Visible = false;

		-- If only some selected parts have decorations
		elseif #Decorations < #Selection.Parts then

			-- Show both add and remove buttons
			AddButton.Visible = true;
			AddButton.Position = UDim2.new(1, -AddButton.AbsoluteSize.X - 5, 0, 3);
			RemoveButton.Visible = true;
			RemoveButton.Position = UDim2.new(1, -AddButton.AbsoluteSize.X - 5 - RemoveButton.AbsoluteSize.X - 2, 0, 3);

		-- If all selected parts have decorations
		elseif #Decorations == #Selection.Parts then

			-- Show remove button
			RemoveButton.Visible = true;
			RemoveButton.Position = UDim2.new(1, -RemoveButton.AbsoluteSize.X - 5, 0, 3);
			AddButton.Visible = false;

		end;

		--------------------
		-- Update each input
		--------------------

		-- Update smoke inputs
		if DecorationType == 'Smoke' then

			-- Get the inputs
			local SizeInput = Options.SizeOption.Input.TextBox;
			local VelocityInput = Options.VelocityOption.Input.TextBox;
			local OpacityInput = Options.OpacityOption.Input.TextBox;
			local ColorIndicator = Options.ColorOption.Indicator;

			-- Update the inputs
			UpdateDataInputs {
				[SizeInput] = Support.Round(Support.IdentifyCommonProperty(Decorations, 'Size'), 2) or '*';
				[VelocityInput] = Support.Round(Support.IdentifyCommonProperty(Decorations, 'RiseVelocity'), 2) or '*';
				[OpacityInput] = Support.Round(Support.IdentifyCommonProperty(Decorations, 'Opacity'), 2) or '*';
			};
			UpdateColorIndicator(ColorIndicator, Support.IdentifyCommonProperty(Decorations, 'Color'));

		-- Update fire inputs
		elseif DecorationType == 'Fire' then

			-- Get the inputs
			local SizeInput = Options.SizeOption.Input.TextBox;
			local HeatInput = Options.HeatOption.Input.TextBox;
			local SecondaryColorIndicator = Options.SecondaryColorOption.Indicator;
			local ColorIndicator = Options.ColorOption.Indicator;

			-- Update the inputs
			UpdateColorIndicator(ColorIndicator, Support.IdentifyCommonProperty(Decorations, 'Color'));
			UpdateColorIndicator(SecondaryColorIndicator, Support.IdentifyCommonProperty(Decorations, 'SecondaryColor'));
			UpdateDataInputs {
				[HeatInput] = Support.Round(Support.IdentifyCommonProperty(Decorations, 'Heat'), 2) or '*';
				[SizeInput] = Support.Round(Support.IdentifyCommonProperty(Decorations, 'Size'), 2) or '*';
			};

		-- Update sparkle inputs
		elseif DecorationType == 'Sparkles' then

			-- Get the inputs
			local ColorIndicator = Options.ColorOption.Indicator;

			-- Update the inputs
			UpdateColorIndicator(ColorIndicator, Support.IdentifyCommonProperty(Decorations, 'SparkleColor'));

		end;

	end;

end;

function HideUI()
	-- Hides the tool UI

	-- Make sure there's a UI
	if not DecorateTool.UI then
		return;
	end;

	-- Hide the UI
	DecorateTool.UI.Visible = false;

	-- Stop updating the UI
	UIUpdater:Stop();

end;

function GetDecorations(DecorationType)
	-- Returns all the decorations of the given type in the selection

	local Decorations = {};

	-- Get any decorations from any selected parts
	for _, Part in pairs(Selection.Parts) do
		table.insert(Decorations, Support.GetChildOfClass(Part, DecorationType));
	end;

	-- Return the decorations
	return Decorations;

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

function UpdateDataInputs(Data)
	-- Updates the data in the given TextBoxes when the user isn't typing in them

	-- Go through the inputs and data
	for Input, UpdatedValue in pairs(Data) do

		-- Make sure the user isn't typing into the input
		if not Input:IsFocused() then

			-- Set the input's value
			Input.Text = tostring(UpdatedValue);

		end;

	end;

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
			Core.SyncAPI:Invoke('SyncDecorate', Record.Before);

		end;

		Apply = function (Record)
			-- Applies this change

			-- Select the changed parts
			Selection.Replace(Record.Selection)

			-- Send the change request
			Core.SyncAPI:Invoke('SyncDecorate', Record.After);

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
	Core.SyncAPI:Invoke('SyncDecorate', HistoryRecord.After);

	-- Register the record and clear the staging
	Core.History.Add(HistoryRecord);
	HistoryRecord = nil;

end;

function EnableOptionsUI(SettingsUI)
	-- Sets up the UI for the given decoration type settings UI

	-- Get the type of decoration this options UI is for
	local DecorationType = SettingsUI.Name;

	-- Option input references
	local Options = SettingsUI.Options;
	
	-- Add/remove/show button references
	local AddButton = SettingsUI.AddButton;
	local RemoveButton = SettingsUI.RemoveButton;
	local ShowButton = SettingsUI.ArrowButton;

	-- Enable options for smoke decorations
	if DecorationType == 'Smoke' then
		SyncInputToProperty('Color', DecorationType, 'Color', Options.ColorOption.HSVPicker);
		SyncInputToProperty('Size', DecorationType, 'Number', Options.SizeOption.Input.TextBox);
		SyncInputToProperty('RiseVelocity', DecorationType, 'Number', Options.VelocityOption.Input.TextBox);
		SyncInputToProperty('Opacity', DecorationType, 'Number', Options.OpacityOption.Input.TextBox);

	-- Enable options for fire decorations
	elseif DecorationType == 'Fire' then
		SyncInputToProperty('Color', DecorationType, 'Color', Options.ColorOption.HSVPicker);
		SyncInputToProperty('SecondaryColor', DecorationType, 'Color', Options.SecondaryColorOption.HSVPicker);
		SyncInputToProperty('Size', DecorationType, 'Number', Options.SizeOption.Input.TextBox);
		SyncInputToProperty('Heat', DecorationType, 'Number', Options.HeatOption.Input.TextBox);

	-- Enable options for sparkle decorations
	elseif DecorationType == 'Sparkles' then
		SyncInputToProperty('SparkleColor', DecorationType, 'Color', Options.ColorOption.HSVPicker);

	end;

	-- Enable decoration addition button
	AddButton.MouseButton1Click:Connect(function ()
		AddDecorations(DecorationType);
	end);

	-- Enable decoration removal button
	RemoveButton.MouseButton1Click:Connect(function ()
		RemoveDecorations(DecorationType);
	end);

	-- Enable decoration options UI show button
	ShowButton.MouseButton1Click:Connect(function ()
		OpenOptions(DecorationType);
	end);

end;

function OpenOptions(DecorationType)
	-- Opens the options UI for the given decoration type

	-- Get the UI
	local UI = DecorateTool.UI[DecorationType];
	local UITemplate = Core.Tool.Interfaces.BTDecorateToolGUI[DecorationType];

	-- Close up all decoration option UIs
	CloseOptions(DecorationType);

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
	DecorateTool.UI:TweenSize(
		Core.Tool.Interfaces.BTDecorateToolGUI.Size + HeightExpansion,
		Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true
	);

	-- Push any UIs below this one downwards
	local DecorationTypeIndex = Support.FindTableOccurrence(DecorationTypes, DecorationType);
	for DecorationTypeIndex = DecorationTypeIndex + 1, #DecorationTypes do

		-- Get the UI
		local DecorationType = DecorationTypes[DecorationTypeIndex];
		local UI = DecorateTool.UI[DecorationType];

		-- Perform the position animation
		UI:TweenPosition(
			UDim2.new(
				UI.Position.X.Scale,
				UI.Position.X.Offset,
				UI.Position.Y.Scale,
				30 + 30 * (DecorationTypeIndex - 1) + HeightExpansion.Y.Offset
			),
			Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true
		);

	end;

end;

function CloseOptions(Exception)
	-- Closes all decoration options, except the one for the given decoration type

	-- Go through each decoration type
	for DecorationTypeIndex, DecorationType in pairs(DecorationTypes) do

		-- Get the UI for each decoration type
		local UI = DecorateTool.UI[DecorationType];
		local UITemplate = Core.Tool.Interfaces.BTDecorateToolGUI[DecorationType];

		-- Remember the initial size for each options UI
		local InitialSize = UITemplate.Options.Size;

		-- Move each decoration type UI to its starting position
		UI:TweenPosition(
			UDim2.new(
				UI.Position.X.Scale,
				UI.Position.X.Offset,
				UI.Position.Y.Scale,
				30 + 30 * (DecorationTypeIndex - 1)
			),
			Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true
		);
		
		-- Make sure to not resize the exempt decoration type UI
		if not Exception or Exception and DecorationType ~= Exception then

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
		DecorateTool.UI:TweenSize(
			Core.Tool.Interfaces.BTDecorateToolGUI.Size,
			Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true
		);
	end;

end;

function SyncInputToProperty(Property, DecorationType, InputType, Input)
	-- Enables `Input` to change the given property

	-- Enable inputs
	if InputType == 'Color' then
		local ColorPickerHandle = nil
		Input.MouseButton1Click:Connect(function ()
			local CommonColor = Support.IdentifyCommonProperty(GetDecorations(DecorationType), Property)
			local ColorPickerElement = Roact.createElement(ColorPicker, {
				InitialColor = CommonColor or Color3.fromRGB(255, 255, 255);
				SetPreviewColor = function (Color)
					SetPreviewColor(DecorationType, Property, Color)
				end;
				OnConfirm = function (Color)
					SetProperty(DecorationType, Property, Color)
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

	-- Enable number inputs
	elseif InputType == 'Number' then
		Input.FocusLost:Connect(function ()
			SetProperty(DecorationType, Property, tonumber(Input.Text));
		end);

	end;

end;

local PreviewInitialState = nil

function SetPreviewColor(DecorationType, Property, Color)
	-- Previews the given color on the selection

	-- Reset colors to initial state if previewing is over
	if not Color and PreviewInitialState then
		for Decoration, State in pairs(PreviewInitialState) do
			Decoration[Property] = State[Property]
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
		for _, Decoration in pairs(GetDecorations(DecorationType)) do
			PreviewInitialState[Decoration] = { [Property] = Decoration[Property] }
		end
	end

	-- Apply preview color
	for Decoration in pairs(PreviewInitialState) do
		Decoration[Property] = Color
	end
end

function SetProperty(DecorationType, Property, Value)

	-- Make sure the given value is valid
	if not Value then
		return;
	end;

	-- Start a history record
	TrackChange();

	-- Go through each decoration
	for _, Decoration in pairs(GetDecorations(DecorationType)) do

		-- Store the state of the decoration before modification
		table.insert(HistoryRecord.Before, { Part = Decoration.Parent, DecorationType = DecorationType, [Property] = Decoration[Property] });

		-- Create the change request for this decoration
		table.insert(HistoryRecord.After, { Part = Decoration.Parent, DecorationType = DecorationType, [Property] = Value });

	end;

	-- Register the changes
	RegisterChange();

end;

function AddDecorations(DecorationType)

	-- Prepare the change request for the server
	local Changes = {};

	-- Go through the selection
	for _, Part in pairs(Selection.Parts) do

		-- Make sure this part doesn't already have a decoration
		if not Support.GetChildOfClass(Part, DecorationType) then

			-- Queue a decoration to be created for this part
			table.insert(Changes, { Part = Part, DecorationType = DecorationType });

		end;

	end;

	-- Send the change request to the server
	local Decorations = Core.SyncAPI:Invoke('CreateDecorations', Changes);

	-- Put together the history record
	local HistoryRecord = {
		Decorations = Decorations;
		Selection = Selection.Items;

		Unapply = function (Record)
			-- Reverts this change

			-- Select changed parts
			Selection.Replace(Record.Selection)

			-- Remove the decorations
			Core.SyncAPI:Invoke('Remove', Record.Decorations);

		end;

		Apply = function (Record)
			-- Reapplies this change

			-- Restore the decorations
			Core.SyncAPI:Invoke('UndoRemove', Record.Decorations);

			-- Select changed parts
			Selection.Replace(Record.Selection)

		end;

	};

	-- Register the history record
	Core.History.Add(HistoryRecord);

	-- Open the options UI for this decoration type
	OpenOptions(DecorationType);

end;

function RemoveDecorations(DecorationType)

	-- Get all the decorations in the selection
	local Decorations = GetDecorations(DecorationType);

	-- Create the history record
	local HistoryRecord = {
		Decorations = Decorations;
		Selection = Selection.Items;

		Unapply = function (Record)
			-- Reverts this change

			-- Restore the decorations
			Core.SyncAPI:Invoke('UndoRemove', Record.Decorations);

			-- Select changed parts
			Selection.Replace(Record.Selection)

		end;

		Apply = function (Record)
			-- Reapplies this change

			-- Select changed parts
			Selection.Replace(Record.Selection)

			-- Remove the decorations
			Core.SyncAPI:Invoke('Remove', Record.Decorations);

		end;

	};

	-- Send the removal request
	Core.SyncAPI:Invoke('Remove', Decorations);

	-- Register the history record
	Core.History.Add(HistoryRecord);

end;

-- Return the tool
return DecorateTool;