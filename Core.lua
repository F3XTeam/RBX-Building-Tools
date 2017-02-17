Tool = script.Parent;

-- Await initialization
repeat wait() until _G[Tool];
Plugin = _G[Tool].Plugin;

-- Detect mode
Mode = Plugin and 'Plugin' or 'Tool';

-- Load tool completely
if Mode == 'Tool' then
	local Indicator = Tool:WaitForChild 'Loaded';
	while not Indicator.Value do
		Indicator.Changed:wait();
	end;
end;

-- Libraries
Support = require(Tool.SupportLibrary);
Security = require(Tool.SecurityModule);
History = require(Tool.HistoryModule);
Selection = require(Tool.SelectionModule);
Targeting = require(Tool.TargetingModule);
Cheer = require(Tool['Cheer by F3X']);
Region = require(Tool['Region by AxisAngle']);
RbxUtility = LoadLibrary 'RbxUtility';
Create = RbxUtility.Create;

-- References
Support.ImportServices();
SyncAPI = Tool.SyncAPI;
Player = Players.LocalPlayer;

-- Preload assets
Assets = require(Tool.Assets);
ContentProvider:PreloadAsync(Support.Values(Assets));

-- Core events
ToolChanged = RbxUtility.CreateSignal();

function EquipTool(Tool)
	-- Equips and switches to the given tool

	-- Unequip current tool
	if CurrentTool and CurrentTool.Equipped then
		CurrentTool.Unequip();
		CurrentTool.Equipped = false;
	end;

	-- Set `Tool` as current
	CurrentTool = Tool;
	CurrentTool.Equipped = true;

	-- Fire relevant events
	ToolChanged:fire(Tool);

	-- Equip the tool
	Tool.Equip();

end;

function RecolorHandle(Color)
	SyncAPI:Invoke('RecolorHandle', Color);
end;

-- Theme UI to current tool
ToolChanged:connect(function (Tool)
	coroutine.wrap(RecolorHandle)(Tool.Color);
	coroutine.wrap(Selection.RecolorOutlines)(Tool.Color);
end);

-- Core hotkeys
Hotkeys = {};

function AssignHotkey(Hotkey, Callback)
	-- Assigns the given hotkey to `Callback`

	-- Standardize enum-described hotkeys
	if type(Hotkey) == 'userdata' then
		Hotkey = { Hotkey };

	-- Standardize string-described hotkeys
	elseif type(Hotkey) == 'string' then
		Hotkey = { Enum.KeyCode[Hotkey] };

	-- Standardize string table-described hotkeys
	elseif type(Hotkey) == 'table' then
		for Index, Key in ipairs(Hotkey) do
			if type(Key) == 'string' then
				Hotkey[Index] = Enum.KeyCode[Key];
			end;
		end;
	end;

	-- Register the hotkey
	table.insert(Hotkeys, { Keys = Hotkey, Callback = Callback });

end;

function EnableHotkeys()
	-- Begins to listen for hotkey triggering

	-- Listen for pressed keys
	Connections.Hotkeys = Support.AddUserInputListener('Began', 'Keyboard', false, function (Input)
		local PressedKeys = Support.GetListMembers(UserInputService:GetKeysPressed(), 'KeyCode');
		local KeyCount = #PressedKeys;

		-- Prioritize hotkeys based on # of required keys
		table.sort(Hotkeys, function (A, B)
			if #A.Keys > #B.Keys then
				return true;
			end;
		end);

		-- Identify matching hotkeys
		for _, Hotkey in ipairs(Hotkeys) do
			if KeyCount == #Hotkey.Keys then

				-- Get the hotkey's key index
				local Keys = Support.FlipTable(Hotkey.Keys)
				local MatchingKeys = 0;

				-- Check matching pressed keys
				for _, PressedKey in pairs(PressedKeys) do
					if Keys[PressedKey] then
						MatchingKeys = MatchingKeys + 1;
					end;
				end;

				-- Trigger the first matching hotkey's callback
				if MatchingKeys == KeyCount then
					Hotkey.Callback();
					break;
				end;

			end;
		end;
	end);

end;

Enabling = RbxUtility.CreateSignal();
Disabling = RbxUtility.CreateSignal();

function Enable(Mouse)

	-- Update the core mouse
	getfenv(0).Mouse = Mouse;

	-- Fire event
	Enabling:fire();

	-- Use default mouse behavior
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default;

	-- Show UI
	UI.Parent = UIContainer;

	-- Start systems
	EnableHotkeys();
	Targeting.EnableTargeting();
	Selection.EnableOutlines();

	-- Equip current tool
	EquipTool(CurrentTool or require(Tool.Tools.MoveTool));

end;

function Disable()

	-- Fire event
	Disabling:fire();

	-- Hide UI
	UI.Parent = nil;

	-- Unequip current tool
	if CurrentTool then
		CurrentTool.Unequip();
		CurrentTool.Equipped = false;
	end;

	-- Clear temporary connections
	ClearConnections();

end;

-- Enable tool or plugin
if Mode == 'Plugin' then

	-- Set the UI root
	UIContainer = CoreGui;

	-- Create the toolbar button
	PluginButton = Plugin:CreateToolbar('Building Tools by F3X'):CreateButton(
		'Building Tools by F3X',
		'Building Tools by F3X',
		Assets.PluginIcon
	);

	-- Connect the button to the system
	PluginButton.Click:connect(function ()
		PluginEnabled = not PluginEnabled;
		PluginButton:SetActive(PluginEnabled);

		-- Toggle the tool
		if PluginEnabled then
			Plugin:Activate(true);
			Enable(Plugin:GetMouse());
		else
			Disable();
		end;
	end);

	-- Disable the tool upon plugin deactivation
	Plugin.Deactivation:connect(Disable);

elseif Mode == 'Tool' then

	-- Set the UI root
	UIContainer = Player:WaitForChild 'PlayerGui';

	-- Connect the tool to the system
	Tool.Equipped:connect(Enable);
	Tool.Unequipped:connect(Disable);

end;

-- Create the UI root
UI = Create 'ScreenGui' {
	Name = 'Building Tools by F3X (UI)'
};

-- Core connections
Connections = {};

function ClearConnections()
	-- Clears and disconnects temporary connections
	for Index, Connection in pairs(Connections) do
		Connection:disconnect();
		Connections[Index] = nil;
	end;
end;

-- Assign hotkeys for undoing (left or right shift + Z)
AssignHotkey({ 'LeftShift', 'Z' }, History.Undo);
AssignHotkey({ 'RightShift', 'Z' }, History.Undo);

-- Assign hotkeys for redoing (left or right shift + Y)
AssignHotkey({ 'LeftShift', 'Y' }, History.Redo);
AssignHotkey({ 'RightShift', 'Y' }, History.Redo);

function CloneSelection()
	-- Clones selected parts

	-- Make sure that there are items in the selection
	if #Selection.Items == 0 then
		return;
	end;

	-- Send the cloning request to the server
	local Clones = SyncAPI:Invoke('Clone', Selection.Items);

	-- Put together the history record
	local HistoryRecord = {
		Clones = Clones;

		Unapply = function (HistoryRecord)
			-- Reverts this change

			-- Remove the clones
			SyncAPI:Invoke('Remove', HistoryRecord.Clones);

		end;

		Apply = function (HistoryRecord)
			-- Reapplies this change

			-- Restore the clones
			SyncAPI:Invoke('UndoRemove', HistoryRecord.Clones);

		end;

	};

	-- Register the history record
	History.Add(HistoryRecord);

	-- Select the clones
	Selection.Replace(Clones);

	-- Play a confirmation sound
	PlayConfirmationSound();

	-- Flash the outlines of the new parts
	coroutine.wrap(Selection.FlashOutlines)();

end;

function PlayConfirmationSound()
	-- Plays a confirmation beep sound

	-- Create the sound
	local Sound = Create 'Sound' {
		Name = 'BTActionCompletionSound';
		Pitch = 1.5;
		SoundId = Assets.ActionCompletionSound;
		Volume = 1;
		Parent = SoundService;
		PlayOnRemove = true;
	};

	-- Trigger playing
	Sound:Play();
	Sound:Destroy();

end;

function DeleteSelection()
	-- Deletes selected items

	-- Put together the history record
	local HistoryRecord = {
		Parts = Support.CloneTable(Selection.Items);

		Unapply = function (HistoryRecord)
			-- Reverts this change

			-- Restore the parts
			SyncAPI:Invoke('UndoRemove', HistoryRecord.Parts);

			-- Select the restored parts
			Selection.Replace(HistoryRecord.Parts);

		end;

		Apply = function (HistoryRecord)
			-- Applies this change

			-- Remove the parts
			SyncAPI:Invoke('Remove', HistoryRecord.Parts);

		end;

	};

	-- Perform the removal
	SyncAPI:Invoke('Remove', Selection.Items);

	-- Register the history record
	History.Add(HistoryRecord);

end;

-- Assign hotkeys for cloning (left or right shift + c)
AssignHotkey({ 'LeftShift', 'C' }, CloneSelection);
AssignHotkey({ 'RightShift', 'C' }, CloneSelection);

-- Assign hotkeys for deletion (left or right shift + X)
AssignHotkey({ 'LeftShift', 'X' }, DeleteSelection);
AssignHotkey({ 'RightShift', 'X' }, DeleteSelection);

function PrismSelect()
	-- Selects parts in the currently selected parts

	local Parts = {};

	-- Go through each selected part
	for _, Part in pairs(Selection.Items) do
		local Region = Region.FromPart(Part);
		Support.ConcatTable(Parts, Region:Cast());
	end;

	-- Delete the selection parts
	DeleteSelection();

	-- Select all found parts
	Selection.Replace(Parts, true);

end;

-- Assign hotkeys for prism selection
AssignHotkey({ 'LeftShift', 'K' }, PrismSelect);
AssignHotkey({ 'RightShift', 'K' }, PrismSelect);

-- Assign hotkeys for selection clearing
AssignHotkey({ 'LeftShift', 'R' }, Support.Call(Selection.Clear, true));
AssignHotkey({ 'RightShift', 'R' }, Support.Call(Selection.Clear, true));

function IsSelectable(Object)
	-- Returns whether `Object` can be selected

	-- Check if `Object` exists, is not locked, and is not ignored
	if not Object or not Object.Parent or not Object:IsA 'BasePart' or Object.Locked or IsIgnored(Object) then
		return false;
	end;

	-- If areas are enabled, check if `Object` violates any areas
	if Security.AreAreasEnabled() then
		return not Security.ArePartsViolatingAreas({ Object }, Player, true, {});
	end;

	-- If no checks fail, `Object` is selectable
	return Object;

end;

function IsIgnored(Object)
	-- TODO: Add ignoring capability
end;

function SetParent(Parent)
	-- Sets the current default parent for parts

end;

function ToggleSwitch(CurrentButtonName, SwitchContainer)
	-- Toggles between the buttons in a switch

	-- Reset all buttons
	for _, Button in pairs(SwitchContainer:GetChildren()) do

		-- Make sure to not mistake the option label for a button
		if Button.Name ~= 'Label' then

			-- Set appearance to disabled
			Button.SelectedIndicator.BackgroundTransparency = 1;
			Button.Background.Image = Assets.LightSlantedRectangle;

		end;

	end;

	-- Make sure there's a new current button
	if CurrentButtonName then

		-- Get the current button
		local CurrentButton = SwitchContainer[CurrentButtonName];

		-- Set the current button's appearance to enabled
		CurrentButton.SelectedIndicator.BackgroundTransparency = 0;
		CurrentButton.Background.Image = Assets.DarkSlantedRectangle;

	end;
end;

-- Create the dock
Dock = Cheer(Tool.Interfaces.BTDock, UI).Start(getfenv(0));

-- Return core
return getfenv(0);