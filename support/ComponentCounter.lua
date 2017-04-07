local Count = script.Parent;
local Tool = Count.Parent.Parent;
local Support = require(Tool:WaitForChild 'SupportLibrary');

-- Exclude counting thumbnail part (autoremoves)
local ThumbnailDescendantCount = 5;

-- Provide total count of all descendants
Count.Value = Support.GetDescendantCount(Tool) - ThumbnailDescendantCount;