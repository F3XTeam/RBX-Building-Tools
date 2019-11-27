local Tool = script.Parent.Parent;

function IsVersionOutdated(Version)
	-- Returns whether the given version of Building Tools is out of date

	-- Check most recent version number
	local AssetInfo = Game:GetService('MarketplaceService'):GetProductInfo(142785488, Enum.InfoType.Asset);
	local LatestMajorVersion, LatestMinorVersion, LatestPatchVersion = AssetInfo.Description:match '%[Version: ([0-9]+)%.([0-9]+)%.([0-9]+)%]';
	local CurrentMajorVersion, CurrentMinorVersion, CurrentPatchVersion = Version:match '([0-9]+)%.([0-9]+)%.([0-9]+)';

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

-- Ensure tool mode is enabled, auto-updating is enabled, and version is outdated
if not (Tool:IsA 'Tool' and Tool.AutoUpdate.Value and IsVersionOutdated(Tool.Version.Value)) then
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