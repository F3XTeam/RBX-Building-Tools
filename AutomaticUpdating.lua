local Tool = script.Parent;

function IsVersionOutdated()
	-- Returns whether this version of Building Tools is out of date

	-- Check most recent version number
	local AssetInfo = Game:GetService('MarketplaceService'):GetProductInfo(142785488, Enum.InfoType.Asset);
	local LatestMajorVersion, LatestMinorVersion, LatestPatchVersion = AssetInfo.Description:match '%[Version: ([0-9]+)%.([0-9]+)%.([0-9]+)%]';
	local CurrentMajorVersion, CurrentMinorVersion, CurrentPatchVersion = Tool.Version.Value:match '([0-9]+)%.([0-9]+)%.([0-9]+)';

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
if not (Tool:IsA 'Tool' and Tool.AutoUpdate.Value and IsVersionOutdated()) then
	return;
end;

-- Attempt to get latest copy of the asset
local LatestVersionId = Game:GetService('InsertService'):GetLatestAssetVersionAsync(142785488);
local Model = Game:GetService('InsertService'):LoadAssetVersion(LatestVersionId);
if Model and #Model:GetChildren() > 0 then

	-- Get the tool
	local NewTool = Model:GetChildren()[1];

	-- Detach update script from tool and save old tool parent
	script.Parent = nil;
	local ToolParent = Tool.Parent;

	-- Replace the current tool with the new one
	Tool:Destroy();
	NewTool.Parent = ToolParent;

end;