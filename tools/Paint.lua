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
local PaintTool = {

	Name = 'Paint Tool';
	Color = BrickColor.new 'Really red';

	-- Default options
	BrickColor = nil;

	-- Standard platform event interface
	Listeners = {};

};

-- Container for temporary connections (disconnected automatically)
local Connections = {};

function Equip()
	-- Enables the tool's equipped functionality

	-- Start up our interface
	ShowUI();
	BindShortcutKeys();
	EnableClickPainting();

end;

function Unequip()
	-- Disables the tool's equipped functionality

	-- Clear unnecessary resources
	HideUI();
	ClearConnections();

end;

PaintTool.Listeners.Equipped = Equip;
PaintTool.Listeners.Unequipped = Unequip;

function ClearConnections()
	-- Clears out temporary connections

	for ConnectionKey, Connection in pairs(Connections) do
		Connection:disconnect();
		Connections[ConnectionKey] = nil;
	end;

end;

-- Import the color list
local Colors = require(script:WaitForChild 'Colors');

function ShowUI()
	-- Creates and reveals the UI

	-- Only reveal UI if already created
	if PaintTool.UI then
		PaintTool.UI.Visible = true;
		return;
	end;

	-- Create the UI
	PaintTool.UI = Core.Tool.Interfaces.BTPaintToolGUI:Clone();
	PaintTool.UI.Parent = Core.UI;
	PaintTool.UI.Visible = true;

	-- Populate the palette
	local Columns = 11;
	for Index, Color in ipairs(Colors) do

		-- Get the BrickColor for this color
		local Color = BrickColor.new(Color);

		-- Calculate the column and row for this button
		local Column = (Index - 1) % Columns;
		local Row = math.floor((Index - 1) / Columns);

		-- Create the button for this color
		local Button = Create 'TextButton' {
			Parent = PaintTool.UI.Palette;
			Name = Color.Name;
			BackgroundColor3 = Color.Color;
			Size = UDim2.new(1 / Columns, 0, 1 / Columns, 0);
			Position = UDim2.new(Column * (1 / Columns), 0, Row * (1 / Columns), 0);
			SizeConstraint = Enum.SizeConstraint.RelativeXX;
			BorderSizePixel = 0;
			TextColor3 = Color3.new(1, 1, 1);
			Text = '';
			FontSize = Enum.FontSize.Size8;
			Font = Enum.Font.ArialBold;
			TextStrokeTransparency = 0.15;
			TextStrokeColor3 = Color3.new(0, 0, 0);
		};

		-- Recolor the selection when the button is clicked
		Button.MouseButton1Click:connect(function ()
			SetColor(Color);
		end);

	end;

	-- Paint selection when current color indicator is clicked
	PaintTool.UI.LastColor.MouseButton1Click:connect(PaintParts);

	-- Update the UI every 0.1 seconds
	Core.ScheduleRecurringTask(UpdateUI, 0.1);

end;

function HideUI()
	-- Hides the tool UI

	-- Make sure there's a UI
	if not PaintTool.UI then
		return;
	end;

	-- Hide the UI
	PaintTool.UI.Visible = false;

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
	for _, Button in pairs(PaintTool.UI.Palette:GetChildren()) do
		Button.Text = '';
	end;

	-- Indicate the variety of colors in the selection
	for _, Part in pairs(Selection.Items) do
		PaintTool.UI.Palette[Part.BrickColor.Name].Text = '-';
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
	ColorSquare.Position = UDim2.new(0.5, -ColorLabel.TextBounds.X / 2 - 16, 0.2, 1);

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

		-- Check if the R key was pressed
		if InputInfo.KeyCode == Enum.KeyCode.R and not (Core.ActiveKeys[Enum.KeyCode.LeftShift] or Core.ActiveKeys[Enum.KeyCode.RightShift]) then

			-- Set the current color to that of the current mouse target (if any)
			if Core.Mouse.Target then
				SetColor(Core.Mouse.Target.BrickColor);
			end;

		end;

	end));

end;

function EnableClickPainting()
	-- Allows the player to paint parts by clicking on them

	-- Watch out for clicks on selected parts (use selection system-linked core event)
	PaintTool.Listeners.Button1Up = function ()
		if Selection:find(Core.Mouse.Target) and not Core.selecting then

			-- Paint the selected parts
			PaintParts();

		end;
	end;

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

			-- Clear the selection
			Selection:clear();

			-- Put together the change request
			local Changes = {};
			for _, Part in pairs(Record.Parts) do
				table.insert(Changes, { Part = Part, Color = Record.BeforeColor[Part], UnionColoring = Record.BeforeUnionColoring[Part] });

				-- Select the part
				Selection:add(Part);
			end;

			-- Send the change request
			Core.ServerAPI:InvokeServer('SyncColor', Changes);

		end;

		Apply = function (Record)
			-- Applies this change

			-- Clear the selection
			Selection:clear();

			-- Put together the change request
			local Changes = {};
			for _, Part in pairs(Record.Parts) do
				table.insert(Changes, { Part = Part, Color = Record.AfterColor[Part], UnionColoring = true });

				-- Select the part
				Selection:add(Part);
			end;

			-- Send the change request
			Core.ServerAPI:InvokeServer('SyncColor', Changes);

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
	Core.ServerAPI:InvokeServer('SyncColor', Changes);

	-- Register the record and clear the staging
	Core.History:Add(HistoryRecord);
	HistoryRecord = nil;

end;

-- Mark the tool as fully loaded
Core.Tools.Paint = PaintTool;
PaintTool.Loaded = true;