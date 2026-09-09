local Tool = script.Parent.Parent;
local Core = require(Tool.Core);

-- Ensure tool mode is enabled, auto-updating is enabled, and version is outdated
if not (Tool:IsA 'Tool' and Tool.AutoUpdate.Value and Core.IsVersionOutdated()) then
	return;
end;

-- Use module to insert latest tool
local GetLatestTool = require(580330877);
if not GetLatestTool then
	return;
end;

-- Get latest copy of tool
local NewTool = GetLatestTool();
if NewTool then

	-- Prevent update attempt loops since fetched version is now cached
	NewTool.AutoUpdate.Value = false;

	-- Cancel replacing current tool if fetched version is the same
	if NewTool.Version.Value == Tool.Version.Value then
		return;
	end;

	-- Detach update script from tool and save old tool parent
	script.Parent = nil;
	local ToolParent = Tool.Parent;

	-- Remove current tool (delayed to prevent parenting conflicts)
	wait(0.05);
	Tool.Parent = nil;

	-- Remove the tool again if anything attempts to reparent it
	Tool.Changed:Connect(function (Property)
		if Property == 'Parent' and Tool.Parent then
			wait(0.05);
			Tool.Parent = nil;
		end;
	end);

	-- Add the new tool
	NewTool.Parent = ToolParent;

end;