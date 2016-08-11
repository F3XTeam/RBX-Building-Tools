local Count = script.Parent;
local Tool = Count.Parent.Parent;
local Support = require(Tool:WaitForChild 'SupportLibrary');

-- Provide total count of all descendants
Count.Value = Support.GetDescendantCount(Tool);