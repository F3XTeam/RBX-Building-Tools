local Count = script.Parent;
local Tool = Count.Parent.Parent;
local Support = require(Tool:WaitForChild 'SupportLibrary');

-- Exclude counting autoremoving items (thumbnail and autoupdating script)
local AutoremovingItemsCount = 5 + 1;

-- Provide total count of all descendants
Count.Value = Support.GetDescendantCount(Tool) - AutoremovingItemsCount;