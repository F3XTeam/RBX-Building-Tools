local Indicator = script.Parent;
local Tool = Indicator.Parent;

-- Libraries
local Support = require(Tool:WaitForChild 'SupportLibrary');

-- Get the total component count
local TotalCount = (Indicator:WaitForChild 'ComponentCount').Value;

-- Wait for tool to load completely
while not (Support.GetDescendantCount(Tool) >= TotalCount) do
	wait(0.1);
end;

-- Set load indicator to true upon load completion
Indicator.Value = true;