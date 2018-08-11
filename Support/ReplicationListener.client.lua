local Indicator = script.Parent;
local Tool = Indicator.Parent;

-- Wait for tool to load completely
local TotalDescendants = (Indicator:WaitForChild 'DescendantCount').Value;
while not (#Tool:GetDescendants() >= TotalDescendants) do
	wait(0.1);
end;

-- Set load indicator to true upon load completion
Indicator.Value = true;