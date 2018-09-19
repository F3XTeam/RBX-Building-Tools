local Tool = script.Parent.Parent
local History = require(script.Parent.History)

-- Libraries
local Libraries = Tool:WaitForChild 'Libraries'
local Support = require(Libraries:WaitForChild 'SupportLibrary')
local Signal = require(Libraries:WaitForChild 'Signal')
local Maid = require(Libraries:WaitForChild 'Maid')

-- Core selection system
Selection = {}
Selection.Items = {}
Selection.ItemIndex = {}
Selection.Parts = {}
Selection.PartIndex = {}
Selection.Outlines = {}
Selection.Color = BrickColor.new 'Cyan'
Selection.Multiselecting = false
Selection.Maid = Maid.new()

-- Events to listen to selection changes
Selection.ItemsAdded = Signal.new()
Selection.ItemsRemoved = Signal.new()
Selection.PartsAdded = Signal.new()
Selection.PartsRemoved = Signal.new()
Selection.FocusChanged = Signal.new()
Selection.Cleared = Signal.new()
Selection.Changed = Signal.new()

function Selection.IsSelected(Item)
	-- Returns whether `Item` is selected or not

	-- Check and return item presence in index
	return Selection.ItemIndex[Item];

end;

local function CollectParts(Item, Table)
	-- Adds parts found in `Item` to `Table`

	-- Collect parts
	if Item:IsA 'BasePart' then
		Table[#Table + 1] = Item

	-- Collect parts inside of groups
	elseif Item:IsA 'Model' or Item:IsA 'Folder' then
		local Items = Item:GetDescendants()
		for _, Item in ipairs(Items) do
			if Item:IsA 'BasePart' then
				Table[#Table + 1] = Item
			end
		end
	end
end

function Selection.Add(Items, RegisterHistory)
	-- Adds the given items to the selection

	-- Get core API
	local Core = GetCore();

	-- Go through and validate each given item
	local SelectableItems = {};
	for _, Item in pairs(Items) do

		-- Make sure each item is valid and not already selected
		if Core.IsSelectable(Item) and not Selection.ItemIndex[Item] then
			table.insert(SelectableItems, Item);
		end;

	end;

	local OldSelection = Selection.Items;

	-- Track parts in new selection
	local Parts = {}

	-- Go through the valid new selection items
	for _, Item in pairs(SelectableItems) do

		-- Add each valid item to the selection
		Selection.ItemIndex[Item] = true;

		-- Create maid for cleaning up item listeners
		local ItemMaid = Maid.new()
		Selection.Maid[Item] = ItemMaid

		-- Deselect items that are destroyed
		ItemMaid.RemovalListener = Item.AncestryChanged:Connect(function (Object, Parent)
			if Parent == nil then
				Selection.Remove({ Item })
			end
		end)

		-- Collect parts within item
		CollectParts(Item, Parts)

		-- Listen for new parts in groups
		local IsGroup = Item:IsA 'Model' or Item:IsA 'Folder' or nil
		ItemMaid.NewParts = IsGroup and Item.DescendantAdded:Connect(function (Descendant)
			if Descendant:IsA 'BasePart' then
				local NewRefCount = (Selection.PartIndex[Descendant] or 0) + 1
				Selection.PartIndex[Descendant] = NewRefCount
				Selection.Parts = Support.Keys(Selection.PartIndex)
				if NewRefCount == 1 then
					Selection.PartsAdded:Fire { Descendant }
				end
			end
		end)
		ItemMaid.RemovingParts = IsGroup and Item.DescendantRemoving:Connect(function (Descendant)
			if Selection.PartIndex[Descendant] then
				local NewRefCount = (Selection.PartIndex[Descendant] or 0) - 1
				Selection.PartIndex[Descendant] = (NewRefCount > 0) and NewRefCount or nil
				if NewRefCount == 0 then
					Selection.Parts = Support.Keys(Selection.PartIndex)
					Selection.PartsRemoved:Fire { Descendant }
				end
			end
		end)

	end

	-- Update selected item list
	Selection.Items = Support.Keys(Selection.ItemIndex);

	-- Create a history record for this selection change, if requested
	if RegisterHistory and #SelectableItems > 0 then
		TrackSelectionChange(OldSelection);
	end;

	-- Create selection boxes for the selection
	CreateSelectionBoxes(SelectableItems);

	-- Register references to new parts
	local NewParts = {}
	for _, Part in pairs(Parts) do
		local NewRefCount = (Selection.PartIndex[Part] or 0) + 1
		Selection.PartIndex[Part] = NewRefCount
		if NewRefCount == 1 then
			NewParts[#NewParts + 1] = Part
		end
	end

	-- Update parts list
	if #NewParts > 0 then
		Selection.Parts = Support.Keys(Selection.PartIndex)
		Selection.PartsAdded:Fire(NewParts)
	end

	-- Fire relevant events
	Selection.ItemsAdded:Fire(SelectableItems);
	Selection.Changed:Fire();

end;

function Selection.Remove(Items, RegisterHistory)
	-- Removes the given items from the selection

	-- Go through and validate each given item
	local DeselectableItems = {};
	for _, Item in pairs(Items) do

		-- Make sure each item is actually selected
		if Selection.IsSelected(Item) then
			table.insert(DeselectableItems, Item);
		end;

	end;

	local OldSelection = Selection.Items;

	-- Track parts in removing selection
	local Parts = {}

	-- Go through the valid deselectable items
	for _, Item in pairs(DeselectableItems) do

		-- Remove item from selection
		Selection.ItemIndex[Item] = nil;

		-- Stop tracking item's parts
		Selection.Maid[Item] = nil

		-- Get parts associated with item
		CollectParts(Item, Parts)

	end;

	-- Remove selection boxes from deselected items
	RemoveSelectionBoxes(DeselectableItems);

	-- Update selected item list
	Selection.Items = Support.Keys(Selection.ItemIndex);

	-- Create a history record for this selection change, if requested
	if RegisterHistory and #DeselectableItems > 0 then
		TrackSelectionChange(OldSelection);
	end;

	-- Clear references to removing parts
	local RemovingParts = {}
	for _, Part in pairs(Parts) do
		local NewRefCount = (Selection.PartIndex[Part] or 0) - 1
		Selection.PartIndex[Part] = (NewRefCount > 0) and NewRefCount or nil
		if NewRefCount == 0 then
			RemovingParts[#RemovingParts + 1] = Part
		end
	end

	-- Update parts list
	if #RemovingParts > 0 then
		Selection.Parts = Support.Keys(Selection.PartIndex)
		Selection.PartsRemoved:Fire(RemovingParts)
	end

	-- Fire relevant events
	Selection.ItemsRemoved:Fire(DeselectableItems);
	Selection.Changed:Fire();

end;

function Selection.Clear(RegisterHistory)
	-- Clears all items from selection

	-- Remove all selected items
	Selection.Remove(Selection.Items, RegisterHistory);

	-- Fire relevant events
	Selection.Cleared:Fire();

end;

function Selection.Replace(Items, RegisterHistory)
	-- Replaces the current selection with the given new items

	-- Save old selection reference for history
	local OldSelection = Selection.Items;

	-- Clear current selection and select new items
	Selection.Clear(false);
	Selection.Add(Items, false);

	-- Create a history record for this selection change, if requested
	if RegisterHistory then
		TrackSelectionChange(OldSelection);
	end;

end;

function Selection.SetFocus(Item)
	-- Selects `Item` as the focused selection item

	-- Make sure the item is selected or is `nil`
	if not Selection.IsSelected(Item) and Item ~= nil then
		return;
	end;

	-- Set the item as the focus
	Selection.Focus = Item;

	-- Fire relevant events
	Selection.FocusChanged:Fire(Item);

end;

function FocusOnLastSelectedPart()
	-- Sets the last part of the selection as the focus

	-- If selection is empty, clear the focus
	if #Selection.Items == 0 then
		Selection.SetFocus(nil);

	-- Otherwise, focus on the last part in the selection
	else
		Selection.SetFocus(Selection.Items[#Selection.Items]);
	end;

end;

-- Listen for changes to the selection and keep the focus updated
Selection.Changed:Connect(FocusOnLastSelectedPart);

function GetCore()
	-- Returns the core API
	return require(script.Parent);
end;

function CreateSelectionBoxes(Items)
	-- Creates a SelectionBox for each given item

	-- Get the core API
	local Core = GetCore();

	-- Only create selection boxes if in tool mode
	if Core.Mode ~= 'Tool' then
		return;
	end;

	-- Track new selection boxes
	local SelectionBoxes = {};

	-- Create an outline for each part
	for _, Item in pairs(Items) do

		-- Avoid duplicate selection boxes
		if not Selection.Outlines[Item] then

			-- Create the selection box
			local SelectionBox = Instance.new 'SelectionBox';
			SelectionBox.Name = 'BTSelectionBox';
			SelectionBox.Color = Selection.Color;
			SelectionBox.Adornee = Item;
			SelectionBox.LineThickness = 0.025;
			SelectionBox.Transparency = 0.5;

			-- Register the outline
			Selection.Outlines[Item] = SelectionBox;
			table.insert(SelectionBoxes, SelectionBox);

		end;

	end;

	-- Parent the selection boxes
	for _, SelectionBox in pairs(SelectionBoxes) do
		SelectionBox.Parent = Core.UIContainer;
	end;

end;

function RemoveSelectionBoxes(Items)
	-- Removes the given item's selection box

	-- Only proceed if in tool mode
	if GetCore().Mode ~= 'Tool' then
		return;
	end;

	-- Remove each item's outline
	for _, Item in pairs(Items) do

		-- Get the item's selection box
		local SelectionBox = Selection.Outlines[Item];

		-- Remove the selection box if found
		if SelectionBox then
			SelectionBox:Destroy();
		end;

		-- Deregister the selection box
		Selection.Outlines[Item] = nil;

	end;

end;

function Selection.RecolorOutlines(Color)
	-- Updates selection outline colors

	-- Set `Color` as the new color
	Selection.Color = Color;

	-- Recolor existing outlines
	for _, Outline in pairs(Selection.Outlines) do
		Outline.Color = Selection.Color;
	end;

end;

function Selection.FlashOutlines()
	-- Flashes selection outlines for emphasis

	-- Fade in from complete to normal transparency
	for Transparency = 1, 0.5, -0.1 do

		-- Update each outline
		for _, Outline in pairs(Selection.Outlines) do
			Outline.Transparency = Transparency;
		end;

		-- Fade over time
		wait(0.1);

	end;

end;

function Selection.EnableOutlines()
	-- Shows selection outlines

	local UIContainer = GetCore().UIContainer;

	-- Show each outline
	for _, Outline in pairs(Selection.Outlines) do
		Outline.Parent = UIContainer;
	end;

	-- Hide outlines when tool is disabled
	GetCore().Connections.HideOutlinesOnDisable = GetCore().Disabling:Connect(Selection.HideOutlines);

end;

function Selection.EnableMultiselectionHotkeys()
	-- Enables hotkeys for multiselecting

	-- Determine multiselection hotkeys
	local Hotkeys = Support.FlipTable { 'LeftShift', 'RightShift', 'LeftControl', 'RightControl' };

	-- Get core API
	local Core = GetCore();

	-- Listen for matching key presses
	Core.Connections.MultiselectionHotkeys = Support.AddUserInputListener('Began', 'Keyboard', false, function (Input)
		if Hotkeys[Input.KeyCode.Name] then
			Selection.Multiselecting = true;
		end;
	end);

	-- Listen for matching key releases
	Core.Connections.MultiselectingReleaseHotkeys = Support.AddUserInputListener('Ended', 'Keyboard', true, function (Input)

		-- Get currently pressed keys
		local PressedKeys = Support.GetListMembers(Support.GetListMembers(Game:GetService('UserInputService'):GetKeysPressed(), 'KeyCode'), 'Name');

		-- Continue multiselection if a hotkey is still pressed
		for _, PressedKey in pairs(PressedKeys) do
			if Hotkeys[PressedKey] then
				return;
			end;
		end;

		-- Disable multiselection if matching key not found
		Selection.Multiselecting = false;

	end);

end;

function Selection.HideOutlines()
	-- Hides selection outlines

	-- Hide each outline
	for _, Outline in pairs(Selection.Outlines) do
		Outline.Parent = nil;
	end;

end;

function TrackSelectionChange(OldSelection)
	-- Registers a history record for a change in the selection

	-- Avoid overwriting history for selection actions
	if History.Index ~= #History.Stack then
		return;
	end;

	-- Add the history record
	History.Add({

		Before = OldSelection;
		After = Selection.Items;

		Unapply = function (HistoryRecord)
			-- Reverts this change

			-- Restore the old selection
			Selection.Replace(HistoryRecord.Before);

		end;

		Apply = function (HistoryRecord)
			-- Reapplies this change

			-- Restore the new selection
			Selection.Replace(HistoryRecord.After);

		end;
	});

end;

return Selection;