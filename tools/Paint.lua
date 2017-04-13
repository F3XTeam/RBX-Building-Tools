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
		Connection:disconnect();
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
				Button.MouseButton1Click:connect(function ()
					SetColor(BrickColor.new(Button.Name));
				end);

				-- Register the button
				PaletteButtons[Button.Name] = Button;

			end;
		end;
	end;

	-- Paint selection when current color indicator is clicked
	PaintTool.UI.LastColor.MouseButton1Click:connect(PaintParts);

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
		if PaletteButtons[Part.BrickColor.Name] then
			PaletteButtons[Part.BrickColor.Name].Text = '+';
		end;
	end;

end;

function SetColor(Color)
	-- Changes the color option to `Color`

	-- Set the color option
	PaintTool.BrickColor = Color;

	-- Shortcuts to color indicators
	local ColorLabel = PaintTool.UI.LastColor.ColorName;
	local ColorSquare = ColorLabel.ColorSquare;

	-- Update the indicators
	ColorLabel.Visible = true;
	ColorLabel.Text = Color.Name;
	ColorSquare.BackgroundColor3 = Color.Color;
	ColorSquare.Position = UDim2.new(1, -ColorLabel.TextBounds.X - 16, 0.2, 1);

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
		Part.BrickColor = PaintTool.BrickColor;

		-- Allow part coloring for unions
		if Part.ClassName == 'UnionOperation' then
			Part.UsePartColor = true;
		end;
	end;

	-- Register changes
	RegisterChange();

end;

function BindShortcutKeys()
	-- Enables useful shortcut keys for this tool

	-- Track user input while this tool is equipped
	table.insert(Connections, UserInputService.InputBegan:connect(function (InputInfo, GameProcessedEvent)

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
				SetColor(Core.Mouse.Target.BrickColor);
			end;

		end;

	end));

end;

function EnableClickPainting()
	-- Allows the player to paint parts by clicking on them

	-- Watch out for clicks on selected parts
	Connections.ClickPainting = Selection.FocusChanged:connect(function (Part)
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
		HistoryRecord.BeforeColor[Part] = Part.BrickColor;

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
		HistoryRecord.AfterColor[Part] = Part.BrickColor;
		table.insert(Changes, { Part = Part, Color = Part.BrickColor, UnionColoring = true });
	end;

	-- Send the change to the server
	Core.SyncAPI:Invoke('SyncColor', Changes);

	-- Register the record and clear the staging
	Core.History.Add(HistoryRecord);
	HistoryRecord = nil;

end;

-- Return the tool
return PaintTool;