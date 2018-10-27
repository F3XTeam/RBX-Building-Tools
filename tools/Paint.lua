Tool = script.Parent.Parent;
Core = require(Tool.Core);

-- Import relevant references
Selection = Core.Selection;
Create = Core.Create;
Support = Core.Support;
Security = Core.Security;
Support.ImportServices();

-- Initialize the tool
local PaintTool = {

	Name = 'Paint Tool';
	Color = BrickColor.new 'Really red';

	-- Default options
	BrickColor = nil;

};

-- Container for temporary connections (disconnected automatically)
local Connections = {};

function PaintTool.Equip()
	-- Enables the tool's equipped functionality

	-- Start up our interface
	ShowUI();
	BindShortcutKeys();
	EnableClickPainting();

end;

function PaintTool.Unequip()
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
	if PaintTool.UI then

		-- Reveal the UI
		PaintTool.UI.Visible = true;

		-- Update the UI every 0.1 seconds
		UIUpdater = Support.ScheduleRecurringTask(UpdateUI, 0.1);

		-- Skip UI creation
		return;

	end;

	-- Create the UI
	PaintTool.UI = Core.Tool.Interfaces.BTPaintToolGUI:Clone();
	PaintTool.UI.Parent = Core.UI;
	PaintTool.UI.Visible = true;

	-- Track palette buttons
	PaletteButtons = {};

	-- Enable the palette
	for _, Column in pairs(PaintTool.UI.Palette:GetChildren()) do
		for _, Button in pairs(Column:GetChildren()) do
			if Button.ClassName == 'TextButton' then

				-- Recolor the selection when the button is clicked
				Button.MouseButton1Click:Connect(function ()
					SetColor(BrickColor.new(Button.Name).Color);
				end);

				-- Register the button
				PaletteButtons[Button.Name] = Button;

			end;
		end;
	end;

	-- Paint selection when current color indicator is clicked
	PaintTool.UI.Controls.LastColorButton.MouseButton1Click:Connect(PaintParts);

	-- Enable color picker button
	PaintTool.UI.Controls.ColorPickerButton.MouseButton1Click:Connect(function ()
		Core.Cheer(Core.Tool.Interfaces.BTHSVColorPicker, Core.UI).Start(
			Support.IdentifyCommonProperty(Selection.Items, 'Color') or Color3.new(1, 1, 1),
			SetColor,
			Core.Targeting.CancelSelecting,
			PreviewColor
		);
	end);

	-- Update the UI every 0.1 seconds
	UIUpdater = Support.ScheduleRecurringTask(UpdateUI, 0.1);

end;

function HideUI()
	-- Hides the tool UI

	-- Make sure there's a UI
	if not PaintTool.UI then
		return;
	end;

	-- Hide the UI
	PaintTool.UI.Visible = false;

	-- Stop updating the UI
	UIUpdater:Stop();

end;

function UpdateUI()
	-- Updates information on the UI

	-- Make sure the UI's on
	if not PaintTool.UI then
		return;
	end;

	-----------------------------------------
	-- Update the color information indicator
	-----------------------------------------

	-- Clear old color indicators
	for Color, Button in pairs(PaletteButtons) do
		Button.Text = '';
	end;

	-- Indicate the variety of colors in the selection
	for _, Part in pairs(Selection.Items) do
		if PaletteButtons[Part.BrickColor.Name] and Part.Color == Part.BrickColor.Color then
			PaletteButtons[Part.BrickColor.Name].Text = '+';
		end;
	end;

	-- Update the color picker button's background
	local CommonColor = Support.IdentifyCommonProperty(Selection.Items, 'Color');
	PaintTool.UI.Controls.ColorPickerButton.ImageColor3 = CommonColor or PaintTool.BrickColor or Color3.new(1, 0, 0);

end;

function SetColor(Color)
	-- Changes the color option to `Color`

	-- Set the color option
	PaintTool.BrickColor = Color;

	-- Use BrickColor name if color matches one
	local EquivalentBrickColor = BrickColor.new(Color);
	local RGBText = ('(%d, %d, %d)'):format(Color.r * 255, Color.g * 255, Color.b * 255);
	local ColorText = (EquivalentBrickColor.Color == Color) and EquivalentBrickColor.Name or RGBText;

	-- Shortcuts to color indicators
	local ColorLabel = PaintTool.UI.Controls.LastColorButton.ColorName;
	local ColorSquare = ColorLabel.ColorSquare;

	-- Update the indicators
	ColorLabel.Visible = true;
	ColorLabel.Text = ColorText;
	ColorSquare.BackgroundColor3 = Color;
	ColorSquare.Position = UDim2.new(1, -ColorLabel.TextBounds.X - 18, 0.2, 1);

	-- Paint currently selected parts
	PaintParts();

end;

function PaintParts()
	-- Recolors the selection with the selected color

	-- Make sure a color has been selected
	if not PaintTool.BrickColor then
		return;
	end;

	-- Track changes
	TrackChange();

	-- Change the color of the parts locally
	for _, Part in pairs(Selection.Items) do
		Part.Color = PaintTool.BrickColor;

		-- Allow part coloring for unions
		if Part.ClassName == 'UnionOperation' then
			Part.UsePartColor = true;
		end;
	end;

	-- Register changes
	RegisterChange();

end;

function PreviewColor(Color)
	-- Previews the given color on the selection

	-- Reset colors to initial state if previewing is over
	if not Color and InitialState then
		for Part, State in pairs(InitialState) do

			-- Reset part color
			Part.Color = State.Color;

			-- Update union coloring options
			if Part.ClassName == 'UnionOperation' then
				Part.UsePartColor = State.UsePartColor;
			end;
		end;

		-- Clear initial state
		InitialState = nil;

		-- Skip rest of function
		return;

	-- Ensure valid color is given
	elseif not Color then
		return;

	-- Save initial state if first time previewing
	elseif not InitialState then
		InitialState = {};
		for _, Part in pairs(Selection.Items) do
			InitialState[Part] = { Color = Part.Color, UsePartColor = (Part.ClassName == 'UnionOperation') and Part.UsePartColor or nil };
		end;
	end;

	-- Apply preview color
	for _, Part in pairs(Selection.Items) do
		Part.Color = Color;

		-- Enable union coloring
		if Part.ClassName == 'UnionOperation' then
			Part.UsePartColor = true;
		end;
	end;

end;

function BindShortcutKeys()
	-- Enables useful shortcut keys for this tool

	-- Track user input while this tool is equipped
	table.insert(Connections, UserInputService.InputBegan:Connect(function (InputInfo, GameProcessedEvent)

		-- Make sure this is an intentional event
		if GameProcessedEvent then
			return;
		end;

		-- Make sure this input is a key press
		if InputInfo.UserInputType ~= Enum.UserInputType.Keyboard then
			return;
		end;

		-- Make sure it wasn't pressed while typing
		if UserInputService:GetFocusedTextBox() then
			return;
		end;

		-- Check if the enter key was pressed
		if InputInfo.KeyCode == Enum.KeyCode.Return or InputInfo.KeyCode == Enum.KeyCode.KeypadEnter then

			-- Paint the selection with the current color
			PaintParts();

		end;

		-- Check if the R key was pressed, and it wasn't the selection clearing hotkey
		if InputInfo.KeyCode == Enum.KeyCode.R and not Selection.Multiselecting then

			-- Set the current color to that of the current mouse target (if any)
			if Core.Mouse.Target then
				SetColor(Core.Mouse.Target.Color);
			end;

		end;

	end));

end;

function EnableClickPainting()
	-- Allows the player to paint parts by clicking on them

	-- Watch out for clicks on selected parts
	Connections.ClickPainting = Selection.FocusChanged:Connect(function (Part)
		if Selection.IsSelected(Core.Mouse.Target) then

			-- Paint the selected parts
			PaintParts();

		end;
	end);

end;

function TrackChange()

	-- Start the record
	HistoryRecord = {
		Parts = Support.CloneTable(Selection.Items);
		BeforeColor = {};
		BeforeUnionColoring = {};
		AfterColor = {};

		Unapply = function (Record)
			-- Reverts this change

			-- Select the changed parts
			Selection.Replace(Record.Parts);

			-- Put together the change request
			local Changes = {};
			for _, Part in pairs(Record.Parts) do
				table.insert(Changes, { Part = Part, Color = Record.BeforeColor[Part], UnionColoring = Record.BeforeUnionColoring[Part] });
			end;

			-- Send the change request
			Core.SyncAPI:Invoke('SyncColor', Changes);

		end;

		Apply = function (Record)
			-- Applies this change

			-- Select the changed parts
			Selection.Replace(Record.Parts);

			-- Put together the change request
			local Changes = {};
			for _, Part in pairs(Record.Parts) do
				table.insert(Changes, { Part = Part, Color = Record.AfterColor[Part], UnionColoring = true });
			end;

			-- Send the change request
			Core.SyncAPI:Invoke('SyncColor', Changes);

		end;

	};

	-- Collect the selection's initial state
	for _, Part in pairs(HistoryRecord.Parts) do
		HistoryRecord.BeforeColor[Part] = Part.Color;

		-- If this part is a union, collect its UsePartColor state
		if Part.ClassName == 'UnionOperation' then
			HistoryRecord.BeforeUnionColoring[Part] = Part.UsePartColor;
		end;
	end;

end;

function RegisterChange()
	-- Finishes creating the history record and registers it

	-- Make sure there's an in-progress history record
	if not HistoryRecord then
		return;
	end;

	-- Collect the selection's final state
	local Changes = {};
	for _, Part in pairs(HistoryRecord.Parts) do
		HistoryRecord.AfterColor[Part] = Part.Color;
		table.insert(Changes, { Part = Part, Color = Part.Color, UnionColoring = true });
	end;

	-- Send the change to the server
	Core.SyncAPI:Invoke('SyncColor', Changes);

	-- Register the record and clear the staging
	Core.History.Add(HistoryRecord);
	HistoryRecord = nil;

end;

-- Return the tool
return PaintTool;