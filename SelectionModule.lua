-- Libraries
local RbxUtility = LoadLibrary 'RbxUtility';
local History = require(script.Parent.HistoryModule);
local Support = require(script.Parent.SupportLibrary);

-- Core selection system
Selection = {};
Selection.Items = {};
Selection.Outlines = {};
Selection.Color = BrickColor.new 'Cyan';

-- Events to listen to selection changes
Selection.ItemsAdded = RbxUtility.CreateSignal();
Selection.ItemsRemoved = RbxUtility.CreateSignal();
Selection.FocusChanged = RbxUtility.CreateSignal();
Selection.Cleared = RbxUtility.CreateSignal();
Selection.Changed = RbxUtility.CreateSignal();

-- Item existence listeners
local Listeners = {};

function Selection.Find(Needle)
	-- Return `Needle`'s index in the selection, or `nil` if not found

	-- Go through each selected item
	for Index, Item in pairs(Selection.Items) do

		-- Return the index if a match is found
		if Item == Needle then
			return Index;
		end;

	end;

	-- Return `nil` if no match is found
	return nil;
end;

function Selection.Add(Items, RegisterHistory)
	-- Adds the given items to the selection

	local SelectableItems = {};

	-- Go through and validate each given item
	for _, Item in pairs(Items) do

		-- Make sure each item is valid and not already selected
		if GetCore().IsSelectable(Item) and not Selection.Find(Item) then

			-- Queue each part to be added into the selection
			table.insert(SelectableItems, Item);

		end;

	end;

	local OldSelection = Support.CloneTable(Selection.Items);

	-- Go through the valid new selection items
	for _, Item in pairs(SelectableItems) do

		-- Add each valid item to the selection
		table.insert(Selection.Items, Item);

		-- Add a selection box
		CreateSelectionBox(Item);

		-- Deselect items that are destroyed
		Listeners[Item] = Item.AncestryChanged:connect(function (Object, Parent)
			if Parent == nil then
				Selection.Remove({ Item });
			end;
		end);

	end;

	-- Create a history record for this selection change, if requested
	if RegisterHistory and #SelectableItems > 0 then
		TrackSelectionChange(OldSelection);
	end;

	-- Fire relevant events
	Selection.ItemsAdded:fire(SelectableItems);
	Selection.Changed:fire();

end;

function Selection.Remove(Items, RegisterHistory)
	-- Removes the given items from the selection

	local DeselectableItems = {};

	-- Go through and validate each given item
	for _, Item in pairs(Items) do

		-- Make sure each item is actually selected
		if Selection.Find(Item) then
			table.insert(DeselectableItems, Item);
		end;

	end;

	local OldSelection = Support.CloneTable(Selection.Items);

	-- Go through the valid deselectable items
	for _, Item in pairs(DeselectableItems) do

		-- Clear item's selection box
		RemoveSelectionBox(Item);

		-- Remove item from selection
		table.remove(Selection.Items, Selection.Find(Item));

		-- Stop tracking item's parent
		Listeners[Item]:disconnect();
		Listeners[Item] = nil;

	end;

	-- Create a history record for this selection change, if requested
	if RegisterHistory and #DeselectableItems > 0 then
		TrackSelectionChange(OldSelection);
	end;

	-- Fire relevant events
	Selection.ItemsRemoved:fire(DeselectableItems);
	Selection.Changed:fire();

end;

function Selection.Clear(RegisterHistory)
	-- Clears all items from selection

	-- Remove all selected items
	Selection.Remove(Selection.Items, RegisterHistory);

	-- Fire relevant events
	Selection.Cleared:fire();

end;

function Selection.Replace(Items, RegisterHistory)
	-- Replaces the current selection with the given new items

	-- Clear current selection
	Selection.Clear(RegisterHistory);

	-- Select new items
	Selection.Add(Items, RegisterHistory);

end;

function Selection.SetFocus(Item)
	-- Selects `Item` as the focused selection item

	-- Make sure the item is selected or is `nil`
	if not Selection.Find(Item) and Item ~= nil then
		return;
	end;

	-- Set the item as the focus
	Selection.Focus = Item;

	-- Fire relevant events
	Selection.FocusChanged:fire(Item);

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
Selection.Changed:connect(FocusOnLastSelectedPart);

function GetCore()
	-- Returns the core API
	return require(script.Parent.Core);
end;

function CreateSelectionBox(Item)
	-- Creates a SelectionBox for the given item

	-- Only create selection boxes if in tool mode
	if GetCore().Mode ~= 'Tool' then
		return;
	end;

	-- Avoid duplicate selection boxes
	if Selection.Outlines[Item] then
		return;
	end;

	-- Create the selection box
	local SelectionBox = RbxUtility.Create 'SelectionBox' {
		Name = 'BTSelectionBox';
		Parent = GetCore().UIContainer;
		Color = Selection.Color;
		Adornee = Item;
		LineThickness = 0.025;
		Transparency = 0.5;
	};

	-- Register the selection box
	Selection.Outlines[Item] = SelectionBox;

end;

function RemoveSelectionBox(Item)
	-- Removes the given item's selection box

	-- Get the item's selection box
	local SelectionBox = Selection.Outlines[Item];

	-- Remove the selection box if found
	if SelectionBox then
		SelectionBox:Destroy();
	end;

	-- Deregister the selection box
	Selection.Outlines[Item] = nil;

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
	GetCore().Connections.HideOutlinesOnDisable = GetCore().Disabling:connect(Selection.HideOutlines);

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

	-- Add the history record
	History.Add({

		Before = OldSelection;
		After = Support.CloneTable(Selection.Items);

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