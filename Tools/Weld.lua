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
local WeldTool = {
	Name = 'Weld Tool';
	Color = BrickColor.new 'Really black';
}

WeldTool.ManualText = [[<font face="GothamBlack" size="16">Weld Tool  🛠</font>
Allows you to weld parts to hold them together.<font size="6"><br /></font>

<b>NOTE: </b>Welds may break if parts are individually moved.]]

-- Container for temporary connections (disconnected automatically)
local Connections = {};

function WeldTool.Equip()
	-- Enables the tool's equipped functionality

	-- Start up our interface
	ShowUI();
	EnableFocusHighlighting();

end;

function WeldTool.Unequip()
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

		-- Skip UI creation
		return;

	end;

	-- Create the UI
	UI = Core.Tool.Interfaces.BTWeldToolGUI:Clone();
	UI.Parent = Core.UI;
	UI.Visible = true;

	-- Hook up the buttons
	UI.Interface.WeldButton.MouseButton1Click:Connect(CreateWelds);
	UI.Interface.BreakWeldsButton.MouseButton1Click:Connect(BreakWelds);

	-- Hook up manual triggering
	local SignatureButton = UI:WaitForChild('Title'):WaitForChild('Signature')
	ListenForManualWindowTrigger(WeldTool.ManualText, WeldTool.Color.Color, SignatureButton)

end;

function HideUI()
	-- Hides the tool UI

	-- Make sure there's a UI
	if not UI then
		return;
	end;

	-- Hide the UI
	UI.Visible = false;

end;

-- References to reduce indexing time
local GetConnectedParts = Instance.new('Part').GetConnectedParts;
local GetChildren = script.GetChildren;

function GetPartWelds(Part)
	-- Returns any BT-created welds involving `Part`

	local Welds = {};

	-- Get welds stored inside `Part`
	for Weld in pairs(SearchWelds(Part, Part)) do
		Welds[Weld] = true;
	end;

	-- Get welds stored inside connected parts
	for _, ConnectedPart in pairs(GetConnectedParts(Part)) do
		for Weld in pairs(SearchWelds(ConnectedPart, Part)) do
			Welds[Weld] = true;
		end;
	end;

	-- Return all found welds
	return Welds;

end;

function SearchWelds(Haystack, Part)
	-- Searches for and returns BT-created welds in `Haystack` involving `Part`

	local Welds = {};

	-- Search the haystack for welds involving `Part`
	for _, Item in pairs(GetChildren(Haystack)) do

		-- Check if this item is a BT-created weld involving the part
		if Item.Name == 'BTWeld' and Item.ClassName == 'Weld' and
		   (Item.Part0 == Part or Item.Part1 == Part) then

			-- Store weld if valid
			Welds[Item] = true;

		end;

	end;

	-- Return the found welds
	return Welds;

end;

function CreateWelds()
	-- Creates welds for every selected part to the focused part

	-- Determine welding target
	local WeldTarget = (Selection.Focus:IsA 'BasePart' and Selection.Focus) or
		(Selection.Focus:IsA 'Model' and Selection.Focus.PrimaryPart) or
		Selection.Focus:FindFirstChildWhichIsA('BasePart', true)

	-- Send the change request to the server API
	local Welds = Core.SyncAPI:Invoke('CreateWelds', Selection.Parts, WeldTarget)

	-- Update the UI with the number of welds created
	UI.Changes.Text.Text = ('created %s weld%s'):format(#Welds, #Welds == 1 and '' or 's');

	-- Put together the history record
	local HistoryRecord = {
		Welds = Welds;

		Unapply = function (HistoryRecord)
			-- Reverts this change

			-- Remove the welds
			Core.SyncAPI:Invoke('RemoveWelds', HistoryRecord.Welds);

		end;

		Apply = function (HistoryRecord)
			-- Reapplies this change

			-- Restore the welds
			Core.SyncAPI:Invoke('UndoRemovedWelds', HistoryRecord.Welds);

		end;

	};

	-- Register the history record
	Core.History.Add(HistoryRecord);

end;

function BreakWelds()
	-- Search for any selection-connecting, BT-created welds and remove them

	local Welds = {};

	-- Find welds in selected parts
	for _, Part in pairs(Selection.Parts) do
		for Weld in pairs(GetPartWelds(Part)) do
			Welds[Weld] = true;
		end;
	end;

	-- Turn weld index into list
	Welds = Support.Keys(Welds);

	-- Send the change request to the server API
	local WeldsRemoved = Core.SyncAPI:Invoke('RemoveWelds', Welds);

	-- Update the UI with the number of welds removed
	UI.Changes.Text.Text = ('removed %s weld%s'):format(WeldsRemoved, WeldsRemoved == 1 and '' or 's');

	-- Put together the history record
	local HistoryRecord = {
		Welds = Welds;

		Unapply = function (HistoryRecord)
			-- Reverts this change

			-- Restore the welds
			Core.SyncAPI:Invoke('UndoRemovedWelds', HistoryRecord.Welds);

		end;

		Apply = function (HistoryRecord)
			-- Reapplies this change

			-- Remove the welds
			Core.SyncAPI:Invoke('RemoveWelds', HistoryRecord.Welds);

		end;

	};

	-- Register the history record
	Core.History.Add(HistoryRecord);

end;

function EnableFocusHighlighting()
	-- Enables automatic highlighting of the focused part in the selection

	-- Only enable focus highlighting in tool mode
	if Core.Mode ~= 'Tool' then
		return;
	end;

	-- Reset all outline colors
	Core.Selection.RecolorOutlines(Core.Selection.Color);

	-- Recolor current focused item
	if Selection.Focus and (#Selection.Parts > 1) then
		Core.Selection.RecolorOutline(Selection.Focus, BrickColor.new('Deep orange'))
	end;

	-- Recolor future focused items
	Connections.FocusHighlighting = Selection.FocusChanged:Connect(function (FocusedItem)

		-- Reset all outline colors
		Core.Selection.RecolorOutlines(Core.Selection.Color);

		-- Recolor newly focused item
		if FocusedItem and (#Selection.Parts > 1) then
			Core.Selection.RecolorOutline(FocusedItem, BrickColor.new('Deep orange'))
		end;

	end);

end;

-- Return the tool
return WeldTool;