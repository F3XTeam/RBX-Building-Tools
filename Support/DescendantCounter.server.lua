local Count = script.Parent;
local Tool = Count.Parent.Parent;

-- Exclude counting autoremoving items (thumbnail and autoupdating script)
local AutoremovingItemsCount = 5 + 1;

-- Provide total count of all descendants
Count.Value = #Tool:GetDescendants() - AutoremovingItemsCount;