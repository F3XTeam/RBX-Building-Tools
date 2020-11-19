Tool = script.Parent.Parent;
Core = require(Tool.Core);

-- Libraries
local ListenForManualWindowTrigger = require(Tool.Core:WaitForChild('ListenForManualWindowTrigger'))

-- Import relevant references
Selection = Core.Selection;
Support = Core.Support;
Security = Core.Security;
Support.ImportServices();

-- Initialize the tool
local AnchorTool = {

	Name = 'Anchor Tool';
	Color = BrickColor.new 'Really black';

}

AnchorTool.ManualText = [[<font face="GothamBlack" size="16">Anchor Tool  🛠</font>
Lets you anchor and unanchor parts.<font size="6"><br /></font>

<b>TIP:</b> Press <b>Enter</b> to toggle anchor quickly.]]

-- Container for temporary connections (disconnected automatically)
local Connections = {};

function AnchorTool.Equip()
	-- Enables the tool's equipped functionality

	-- Start up our interface
	ShowUI();
	BindShortcutKeys();

end;

function AnchorTool.Unequip()
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
	UI = Core.Tool.Interfaces.BTAnchorToolGUI:Clone();
	UI.Parent = Core.UI;
	UI.Visible = true;

	-- References to UI elements
	local AnchorButton = UI.Status.Anchored.Button;
	local UnanchorButton = UI.Status.Unanchored.Button;

	-- Enable the anchor status switch
	AnchorButton.MouseButton1Click:Connect(function ()
		SetProperty('Anchored', true);
	end);
	UnanchorButton.MouseButton1Click:Connect(function ()
		SetProperty('Anchored', false);
	end);

	-- Hook up manual triggering
	local SignatureButton = UI:WaitForChild('Title'):WaitForChild('Signature')
	ListenForManualWindowTrigger(AnchorTool.ManualText, AnchorTool.Color.Color, SignatureButton)

	-- Update the UI every 0.1 seconds
	UIUpdater = Support.ScheduleRecurringTask(UpdateUI, 0.1);

end;

function UpdateUI()
	-- Updates information on the UI

	-- Make sure the UI's on
	if not UI then
		return;
	end;

	-- Check the common anchor status of selection
	local Anchored = Support.IdentifyCommonProperty(Selection.Parts, 'Anchored');

	-- Update the anchor option switch
	if Anchored == true then
		Core.ToggleSwitch('Anchored', UI.Status);

	-- If the selection is unanchored
	elseif Anchored == false then
		Core.ToggleSwitch('Unanchored', UI.Status);

	-- If the anchor status varies, don't select a current switch
	elseif Anchored == nil then
		Core.ToggleSwitch(nil, UI.Status);
	end;

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

function SetProperty(Property, Value)

	-- Make sure the given value is valid
	if Value == nil then
		return;
	end;

	-- Start a history record
	TrackChange();

	-- Go through each part
	for _, Part in pairs(Selection.Parts) do

		-- Store the state of the part before modification
		table.insert(HistoryRecord.Before, { Part = Part, [Property] = Part[Property] });

		-- Create the change request for this part
		table.insert(HistoryRecord.After, { Part = Part, [Property] = Value });

	end;

	-- Register the changes
	RegisterChange();

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

			-- Toggle the selection's anchor status
			ToggleAnchors();

		end;

	end));

end;

function ToggleAnchors()
	-- Toggles the anchor status of the selection

	-- Change the anchor status to the opposite of the common anchor status
	SetProperty('Anchored', not Support.IdentifyCommonProperty(Selection.Parts, 'Anchored'));

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
			Core.SyncAPI:Invoke('SyncAnchor', Record.Before);

		end;

		Apply = function (Record)
			-- Applies this change

			-- Select the changed parts
			Selection.Replace(Record.Selection)

			-- Send the change request
			Core.SyncAPI:Invoke('SyncAnchor', Record.After);

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
	Core.SyncAPI:Invoke('SyncAnchor', HistoryRecord.After);

	-- Register the record and clear the staging
	Core.History.Add(HistoryRecord);
	HistoryRecord = nil;

end;

-- Return the tool
return AnchorTool;