Tool = script.Parent;

-- Await initialization
repeat wait() until _G[Tool];
Plugin = _G[Tool].Plugin;

-- Detect mode
Mode = Plugin and 'Plugin' or 'Tool';

-- Load tool completely
local Indicator = Tool:WaitForChild 'Loaded';
while not Indicator.Value do
	Indicator.Changed:Wait();
end;

-- Modules
Security = require(script.Security)
History = require(script.History)
Selection = require(script.Selection)
Targeting = require(script.Targeting)

-- Libraries
Region = require(Tool.Libraries.Region)
Signal = require(Tool.Libraries.Signal)
Support = require(Tool.Libraries.SupportLibrary)
Cheer = require(Tool.Libraries.Cheer)
Try = require(Tool.Libraries.Try)
Make = require(Tool.Libraries.Make)
local Roact = require(Tool.Libraries:WaitForChild 'Roact')
local Janitor = require(Tool.Libraries:WaitForChild 'Janitor')

-- References
Support.ImportServices();
SyncAPI = Tool.SyncAPI;
Player = Players.LocalPlayer;

-- Preload assets
Assets = require(Tool.Assets)

-- Core events
ToolChanged = Signal.new()

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
	ToolChanged:Fire(Tool);

	-- Equip the tool
	Tool.Equip();

end;

function RecolorHandle(Color)
	SyncAPI:Invoke('RecolorHandle', Color);
end;

-- Theme UI to current tool
ToolChanged:Connect(function (Tool)
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
		local _PressedKeys = Support.GetListMembers(UserInputService:GetKeysPressed(), 'KeyCode');

		-- Filter out problematic keys
		local PressedKeys = {};
		local FilteredKeys = Support.FlipTable { 'LeftAlt', 'W', 'S', 'A', 'D', 'Space' };
		for _, Key in ipairs(_PressedKeys) do
			if not FilteredKeys[Key.Name] then
				table.insert(PressedKeys, Key);
			end;
		end;

		-- Count pressed keys
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

Enabling = Signal.new()
Disabling = Signal.new()
Enabled = Signal.new()
Disabled = Signal.new()

function Enable(Mouse)

	-- Ensure tool is disabled or disabling, and not already enabling
	if (IsEnabled and not IsDisabling) or IsEnabling then
		return;

	-- If tool is disabling, enable it once fully disabled
	elseif IsDisabling then
		Disabled:Wait();
		return Enable(Mouse);
	end;

	-- Indicate that tool is enabling
	IsEnabling = true;
	Enabling:Fire();

	-- Update the core mouse
	getfenv(0).Mouse = Mouse;

	-- Use default mouse behavior
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default;

	-- Disable mouse lock in tool mode
	if Mode == 'Tool' then
		SyncAPI:Invoke('SetMouseLockEnabled', false);
	end;

	-- Wait for UI to initialize asynchronously
	while not UI do
		wait(0.1);
	end;

	-- Show UI
	UI.Parent = UIContainer;

	-- Display startup notifications
	if not StartupNotificationsDisplayed then
		Cheer(Tool.Interfaces.Notifications, UI).Start(getfenv(0));
		StartupNotificationsDisplayed = true;
	end;

	-- Start systems
	EnableHotkeys();
	Targeting.EnableTargeting();
	Selection.EnableOutlines();
	Selection.EnableMultiselectionHotkeys();

	-- Equip current tool
	EquipTool(CurrentTool or require(Tool.Tools.Move));

	-- Indicate that tool is now enabled
	IsEnabled = true;
	IsEnabling = false;
	Enabled:Fire();

end;

function Disable()

	-- Ensure tool is enabled or enabling, and not already disabling
	if (not IsEnabled and not IsEnabling) or IsDisabling then
		return;

	-- If tool is enabling, disable it once fully enabled
	elseif IsEnabling then
		Enabled:Wait();
		return Disable();
	end;

	-- Indicate that tool is now disabling
	IsDisabling = true;
	Disabling:Fire();

	-- Reenable mouse lock option in tool mode
	if Mode == 'Tool' then
		pcall(SyncAPI.Invoke, SyncAPI, 'SetMouseLockEnabled', true);
	end;

	-- Hide UI
	if UI then
		UI.Parent = script;
	end;

	-- Unequip current tool
	if CurrentTool then
		CurrentTool.Unequip();
		CurrentTool.Equipped = false;
	end;

	-- Clear temporary connections
	ClearConnections();

	-- Indicate that tool is now disabled
	IsEnabled = false;
	IsDisabling = false;
	Disabled:Fire();

end;


-- Core connections
Connections = {};

function ClearConnections()
	-- Clears and disconnects temporary connections
	for Index, Connection in pairs(Connections) do
		Connection:Disconnect();
		Connections[Index] = nil;
	end;
end;

function InitializeUI()
	-- Sets up the UI

	-- Ensure UI has not yet been initialized
	if UI then
		return;
	end;

	-- Create the root UI
	UI = Instance.new('ScreenGui')
	UI.Name = 'Building Tools by F3X (UI)'

	-- Set up dock
	Dock = Cheer(Tool.Interfaces.Dock, UI).Start(getfenv(0));

	-- Clean up UI on tool teardown
	UIJanitor = Janitor.new()
	Tool.AncestryChanged:Connect(function (Item, Parent)
		if Parent == nil then
			UIJanitor:Cleanup()
		end
	end)

	-- Register explorer button on dock
	ExplorerDockButton = Dock.AddSelectionButton(Assets.ExplorerDockIcon, 'EXPLORER\n(Shift + H)')
	ExplorerDockButton.Activated:Connect(ToggleExplorer)
	ExplorerDockButton.ImageTransparency = 0.66

end;

local UIElements = Tool:WaitForChild 'UI'
local ExplorerTemplate = require(UIElements:WaitForChild 'Explorer')

function ToggleExplorer()
	if not ExplorerVisible then
		OpenExplorer()
	else
		CloseExplorer()
	end
end

function OpenExplorer()

	-- Ensure explorer not already open
	if ExplorerHandle then
		return
	end

	-- Initialize explorer
	Explorer = Roact.createElement(ExplorerTemplate, {
		Selection = Selection,
		History = History,
		Scope = Workspace,
		SyncAPI = SyncAPI,
		Close = CloseExplorer
	})

	-- Mount explorer
	ExplorerHandle = Roact.mount(Explorer, UI, 'Explorer')
	ExplorerVisible = true

	-- Unmount explorer on tool cleanup
	UIJanitor:Add(Support.Call(Roact.unmount, ExplorerHandle), true, 'Explorer')

	-- Update dock
	ExplorerDockButton.ImageTransparency = 0

end

function CloseExplorer()

	-- Clean up explorer
	ExplorerHandle = UIJanitor:Remove('Explorer')
	ExplorerVisible = nil

	-- Update dock
	ExplorerDockButton.ImageTransparency = 0.66

end

-- Register explorer pane toggling hotkeys
AssignHotkey({ 'LeftShift', 'H' }, ToggleExplorer)
AssignHotkey({ 'RightShift', 'H' }, ToggleExplorer)

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
	PluginButton.Click:Connect(function ()
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
	Plugin.Deactivation:Connect(Disable);

	-- Sync Studio selection to internal selection
	Selection.Changed:Connect(function ()
		SelectionService:Set(Selection.Items);
	end);

	-- Sync internal selection to Studio selection on enabling
	Enabling:Connect(function ()
		Selection.Replace(SelectionService:Get());
	end);

	-- Roughly sync Studio history to internal history (API lacking necessary functionality)
	History.Changed:Connect(function ()
		ChangeHistoryService:SetWaypoint 'Building Tools by F3X';
	end);

elseif Mode == 'Tool' then

	-- Set the UI root
	UIContainer = Player:WaitForChild 'PlayerGui';

	-- Connect the tool to the system
	Tool.Equipped:Connect(Enable);
	Tool.Unequipped:Connect(Disable);

	-- Disable the tool if not parented
	if not Tool.Parent then
		Disable();
	end;

	-- Disable the tool automatically if not equipped or in backpack
	Tool.AncestryChanged:Connect(function (Item, Parent)
		if not Parent or not (Parent:IsA 'Backpack' or (Parent:IsA 'Model' and Players:GetPlayerFromCharacter(Parent))) then
			Disable();
		end;
	end);

end;

-- Assign hotkeys for undoing (left or right shift + Z)
AssignHotkey({ 'LeftShift', 'Z' }, History.Undo);
AssignHotkey({ 'RightShift', 'Z' }, History.Undo);

-- Assign hotkeys for redoing (left or right shift + Y)
AssignHotkey({ 'LeftShift', 'Y' }, History.Redo);
AssignHotkey({ 'RightShift', 'Y' }, History.Redo);

-- If in-game, enable ctrl hotkeys for undoing and redoing
if Mode == 'Tool' then
	AssignHotkey({ 'LeftControl', 'Z' }, History.Undo);
	AssignHotkey({ 'RightControl', 'Z' }, History.Undo);
	AssignHotkey({ 'LeftControl', 'Y' }, History.Redo);
	AssignHotkey({ 'RightControl', 'Y' }, History.Redo);
end;

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

			-- Deselect the clones
			Selection.Remove(HistoryRecord.Clones, false);

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

	-- Flash the outlines of the new parts
	coroutine.wrap(Selection.FlashOutlines)();

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

			-- Deselect the parts
			Selection.Remove(HistoryRecord.Parts, false);

			-- Remove the parts
			SyncAPI:Invoke('Remove', HistoryRecord.Parts);

		end;

	};

	-- Deselect parts before deleting
	Selection.Remove(HistoryRecord.Parts, false);

	-- Perform the removal
	SyncAPI:Invoke('Remove', HistoryRecord.Parts);

	-- Register the history record
	History.Add(HistoryRecord);

end;

-- Assign hotkeys for cloning (left or right shift + c)
AssignHotkey({ 'LeftShift', 'C' }, CloneSelection);
AssignHotkey({ 'RightShift', 'C' }, CloneSelection);

-- Assign hotkeys for deletion (left or right shift + X)
AssignHotkey({ 'LeftShift', 'X' }, DeleteSelection);
AssignHotkey({ 'RightShift', 'X' }, DeleteSelection);

-- If in-game, enable ctrl hotkeys for cloning and deleting
if Mode == 'Tool' then
	AssignHotkey({ 'LeftControl', 'C' }, CloneSelection);
	AssignHotkey({ 'RightControl', 'C' }, CloneSelection);
	AssignHotkey({ 'LeftControl', 'X' }, DeleteSelection);
	AssignHotkey({ 'RightControl', 'X' }, DeleteSelection);
end;

-- Assign hotkeys for prism selection
AssignHotkey({ 'LeftShift', 'K' }, Targeting.PrismSelect);
AssignHotkey({ 'RightShift', 'K' }, Targeting.PrismSelect);

-- If in-game, enable ctrl hotkeys for prism selection
if Mode == 'Tool' then
	AssignHotkey({ 'LeftControl', 'K' }, Targeting.PrismSelect);
	AssignHotkey({ 'RightControl', 'K' }, Targeting.PrismSelect);
end;

-- Assign hotkeys for sibling selection
AssignHotkey({ 'LeftBracket' }, Support.Call(Targeting.SelectSiblings, false, true));
AssignHotkey({ 'LeftShift', 'LeftBracket' }, Support.Call(Targeting.SelectSiblings, false, false));
AssignHotkey({ 'RightShift', 'LeftBracket' }, Support.Call(Targeting.SelectSiblings, false, false));

-- Assign hotkeys for selection clearing
AssignHotkey({ 'LeftShift', 'R' }, Support.Call(Selection.Clear, true));
AssignHotkey({ 'RightShift', 'R' }, Support.Call(Selection.Clear, true));

-- If in-game, enable ctrl hotkeys for sibling selection & selection clearing
if Mode == 'Tool' then
	AssignHotkey({ 'LeftControl', 'LeftBracket' }, Support.Call(Targeting.SelectSiblings, false, false));
	AssignHotkey({ 'RightControl', 'LeftBracket' }, Support.Call(Targeting.SelectSiblings, false, false));
	AssignHotkey({ 'LeftControl', 'R' }, Support.Call(Selection.Clear, true));
	AssignHotkey({ 'RightControl', 'R' }, Support.Call(Selection.Clear, true));
end;

function GroupSelection()
	-- Groups the selected items

	-- Create history record
	local HistoryRecord = {
		Items = Support.CloneTable(Selection.Items),
		CurrentParents = Support.GetListMembers(Selection.Items, 'Parent')
	}

	function HistoryRecord:Unapply()
		SyncAPI:Invoke('SetParent', self.Items, self.CurrentParents)
		SyncAPI:Invoke('Remove', { self.NewParent })
		Selection.Replace(self.Items)
	end

	function HistoryRecord:Apply()
		SyncAPI:Invoke('UndoRemove', { self.NewParent })
		SyncAPI:Invoke('SetParent', self.Items, self.NewParent)
		Selection.Replace({ self.NewParent })
	end

	-- Perform group creation
	local Focus = Selection.Focus
	HistoryRecord.NewParent = SyncAPI:Invoke('CreateGroup', 'Model',
		Focus and Focus.Parent or Selection.Scope,
		HistoryRecord.Items
	)

	-- Register history record
	History.Add(HistoryRecord)

	-- Select new group
	Selection.Replace({ HistoryRecord.NewParent })

end

function UngroupSelection()
	-- Ungroups the selected groups

	-- Create history record
	local HistoryRecord = {
		Selection = Selection.Items
	}

	function HistoryRecord:Unapply()
		SyncAPI:Invoke('UndoRemove', self.Groups)

		-- Reparent children
		for GroupId, Items in ipairs(self.GroupChildren) do
			spawn(function ()
				SyncAPI:Invoke('SetParent', Items, self.Groups[GroupId])
			end)
		end

		-- Reselect groups
		Selection.Replace(self.Selection)
	end

	function HistoryRecord:Apply()

		-- Get groups from selection
		self.Groups = {}
		for _, Item in ipairs(self.Selection) do
			if Item:IsA 'Model' or Item:IsA 'Folder' then
				self.Groups[#self.Groups + 1] = Item
			end
		end

		-- Perform ungrouping
		self.GroupParents = Support.GetListMembers(self.Groups, 'Parent')
		self.GroupChildren = SyncAPI:Invoke('Ungroup', self.Groups)

		-- Get unpacked children
		local UnpackedChildren = Support.CloneTable(self.Selection)
		for GroupId, Children in pairs(self.GroupChildren) do
			for _, Child in ipairs(Children) do
				UnpackedChildren[#UnpackedChildren + 1] = Child
			end
		end

		-- Select unpacked items
		Selection.Replace(UnpackedChildren)

	end

	-- Perform action
	HistoryRecord:Apply()

	-- Register history record
	History.Add(HistoryRecord)

end

-- Assign grouping hotkeys
AssignHotkey({ 'LeftShift', 'G' }, GroupSelection)
AssignHotkey({ 'RightShift', 'G' }, GroupSelection)
AssignHotkey({ 'LeftShift', 'U' }, UngroupSelection)
AssignHotkey({ 'RightShift', 'U' }, UngroupSelection)

function IsSelectable(Object)
	-- Returns whether `Object` can be selected

	-- Check if `Object` exists, is not locked, and is not ignored
	if not Object or not Object.Parent or (Object:IsA 'BasePart' and Object.Locked) then
		return false;
	end;

	-- If areas are enabled, check if `Object` violates any areas
	if Security.AreAreasEnabled() then
		return not Security.ArePartsViolatingAreas({ Object }, Player, true, {});
	end;

	-- If no checks fail, `Object` is selectable
	return Object;

end;

function ExportSelection()
	-- Exports the selected parts

	-- Make sure that there are items in the selection
	if #Selection.Items == 0 then
		return;
	end;

	-- Start an export dialog
	local Dialog = Cheer(Tool.Interfaces.ExportDialog, UI).Start();

	-- Send the exporting request to the server
	Try(SyncAPI.Invoke, SyncAPI, 'Export', Selection.Items)

	-- Display creation ID on success
	:Then(function (CreationId)
		Dialog.SetResult(CreationId);
		print('[Building Tools by F3X] Uploaded Export:', CreationId);
	end)

	-- Display error messages on failure
	:Catch('Http requests are not enabled', function ()
		Dialog.SetError('Please enable HTTP requests');
	end)
	:Catch('Export failed due to server-side error', function ()
		Dialog.SetError('An error occurred, try again');
	end)
	:Catch('Post data too large', function ()
		Dialog.SetError('Try splitting up your build');
	end)
	:Catch(function (Error, Stack, Attempt)
		Dialog.SetError('An unknown error occurred, try again')
		warn('❌ [Building Tools by F3X] Failed to export selection', '\n\nError:\n', Error, '\n\nStack:\n', Stack);
	end);

end;

-- Assign hotkey for exporting selection
AssignHotkey({ 'LeftShift', 'P' }, ExportSelection);
AssignHotkey({ 'RightShift', 'P' }, ExportSelection);

-- If in-game, enable ctrl hotkeys for exporting
if Mode == 'Tool' then
	AssignHotkey({ 'LeftControl', 'P' }, ExportSelection);
	AssignHotkey({ 'RightControl', 'P' }, ExportSelection);
end;

function IsVersionOutdated()
	-- Returns whether this version of Building Tools is out of date

	-- Check most recent version number
	local AssetInfo = MarketplaceService:GetProductInfo(142785488, Enum.InfoType.Asset);
	local LatestMajorVersion, LatestMinorVersion, LatestPatchVersion = AssetInfo.Description:match '%[Version: ([0-9]+)%.([0-9]+)%.([0-9]+)%]';
	local CurrentMajorVersion, CurrentMinorVersion, CurrentPatchVersion = Tool.Version.Value:match '([0-9]+)%.([0-9]+)%.([0-9]+)';

	-- Convert version data into numbers
	local LatestMajorVersion, LatestMinorVersion, LatestPatchVersion =
		tonumber(LatestMajorVersion), tonumber(LatestMinorVersion), tonumber(LatestPatchVersion);
	local CurrentMajorVersion, CurrentMinorVersion, CurrentPatchVersion =
		tonumber(CurrentMajorVersion), tonumber(CurrentMinorVersion), tonumber(CurrentPatchVersion);

	-- Determine whether current version is outdated
	if LatestMajorVersion > CurrentMajorVersion then
		return true;
	elseif LatestMajorVersion == CurrentMajorVersion then
		if LatestMinorVersion > CurrentMinorVersion then
			return true;
		elseif LatestMinorVersion == CurrentMinorVersion then
			return LatestPatchVersion > CurrentPatchVersion;
		end;
	end;

	-- Return an up-to-date status if not oudated
	return false;

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

-- References to reduce indexing time
local GetConnectedParts = Instance.new('Part').GetConnectedParts;
local GetChildren = script.GetChildren;

function GetPartJoints(Part, Whitelist)
	-- Returns any manual joints involving `Part`

	local Joints = {};

	-- Get joints stored inside `Part`
	for Joint, JointParent in pairs(SearchJoints(Part, Part, Whitelist)) do
		Joints[Joint] = JointParent;
	end;

	-- Get joints stored inside connected parts
	for _, ConnectedPart in pairs(GetConnectedParts(Part)) do
		for Joint, JointParent in pairs(SearchJoints(ConnectedPart, Part, Whitelist)) do
			Joints[Joint] = JointParent;
		end;
	end;

	-- Return all found joints
	return Joints;

end;

-- Types of joints to assume should be preserved
local ManualJointTypes = Support.FlipTable { 'Weld', 'ManualWeld', 'ManualGlue', 'Motor', 'Motor6D' };

function SearchJoints(Haystack, Part, Whitelist)
	-- Searches for and returns manual joints in `Haystack` involving `Part` and other parts in `Whitelist`

	local Joints = {};

	-- Search the haystack for joints involving `Part`
	for _, Item in pairs(GetChildren(Haystack)) do

		-- Check if this item is a manual, intentional joint
		if ManualJointTypes[Item.ClassName] and
		   (Whitelist[Item.Part0] and Whitelist[Item.Part1]) then

			-- Save joint and state if intentional
			Joints[Item] = Item.Parent;

		end;

	end;

	-- Return the found joints
	return Joints;

end;

function RestoreJoints(Joints)
	-- Restores the joints from the given `Joints` data

	-- Restore each joint
	for Joint, JointParent in pairs(Joints) do
		Joint.Parent = JointParent;
	end;

end;

function PreserveJoints(Part, Whitelist)
	-- Preserves and returns intentional joints of `Part` connecting parts in `Whitelist`

	-- Get the part's joints
	local Joints = GetPartJoints(Part, Whitelist);

	-- Save the joints from being broken
	for Joint in pairs(Joints) do
		Joint.Parent = nil;
	end;

	-- Return the joints
	return Joints;

end;

-- Initialize the UI
InitializeUI();

-- Return core
return getfenv(0);