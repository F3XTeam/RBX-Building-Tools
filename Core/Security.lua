-- Services
MarketplaceService = Game:GetService 'MarketplaceService';
HttpService = Game:GetService 'HttpService';
Workspace = Game:GetService 'Workspace';

-- References
Tool = script.Parent.Parent
Libraries = Tool:WaitForChild 'Libraries'
Support = require(Libraries:WaitForChild 'SupportLibrary')
RegionModule = require(Libraries:WaitForChild 'Region')

-- Determine whether we're in tool or plugin mode
local ToolMode = (Tool.Parent:IsA 'Plugin') and 'Plugin' or 'Tool'

-- Initialize the security module
Security = {};

-- The distance above the area-defining part that counts as part of the area
Security.AreaHeight = 500;

-- Whether to allow building outside of private areas
Security.AllowPublicBuilding = true;

-- Allowed locations in the hierarchy (descendants of which are authorized)
Security.AllowedLocations = { Workspace };

-- Track the enabling of areas
Security.Areas = Workspace:FindFirstChild('[Private Building Areas]');
Workspace.ChildAdded:Connect(function (Child)
	if not Security.Areas and Child.Name == '[Private Building Areas]' then
		Security.Areas = Child;
	end;
end);
Workspace.ChildRemoved:Connect(function (Child)
	if Security.Areas and Child.Name == '[Private Building Areas]' then
		Security.Areas = nil;
	end;
end);

function Security.IsAreaAuthorizedForPlayer(Area, Player)
	-- Returns whether `Player` has permission to manipulate parts in this area

	-- Ensure area has permissions
	local Permissions = Area:FindFirstChild '[Permissions]';
	if not Permissions then
		return;
	else
		Permissions = require(Permissions);
	end;

	-- Ensure permissions are set up
	if not Permissions then
		return;
	end;

	-- Search for authorizing permission
	for _, Permission in pairs(Permissions) do

		-- Check group permissions
		if Permission.Type == 'Group' then

			-- Check player's group membership
			local PlayerInGroup = Player:IsInGroup(Permission.GroupId);

			-- If no specific rank is required, authorize
			if PlayerInGroup and not Permission.Ranks then
				return true;

			-- If specific rank is required, check player rank
			elseif PlayerInGroup and Permission.Ranks then
				local Symbol, RankNumber = tostring(Permission.Ranks):match('([<>]?=?)([0-9]+)');
				local PlayerRank = Player:GetRankInGroup(Permission.GroupId);
				RankNumber = tonumber(RankNumber);

				-- Check the player rank
				if not Symbol and (PlayerRank == RankNumber) then
					return true;
				elseif Symbol == '=' and (PlayerRank == RankNumber) then
					return true;
				elseif Symbol == '>' and (PlayerRank > RankNumber) then
					return true;
				elseif Symbol == '<' and (PlayerRank < RankNumber) then
					return true;
				elseif Symbol == '>=' and (PlayerRank >= RankNumber) then
					return true;
				elseif Symbol == '<=' and (PlayerRank <= RankNumber) then
					return true;
				end;
			end;

		-- Check player permissions
		elseif Permission.Type == 'Player' then
			if (Player.userId == Permission.PlayerId) or (Player.Name == Permission.PlayerName) then
				return true;
			end;

		-- Check owner permissions
		elseif Permission.Type == 'Owner' then
			if (Player.userId == Permission.PlayerId) or (Player.Name == Permission.PlayerName) then
				return true;
			end;

		-- Check auto-permissions
		elseif Permission.Type == 'Anybody' then
			return true;

		-- Check friend permissions
		elseif Permission.Type == 'Friends' then
			if Player:IsFriendsWith(Permission.PlayerId) then
				return true;
			end;

		-- Check asset permissions
		elseif Permission.Type == 'Asset' then
			if MarketplaceService:PlayerOwnsAsset(Player, Permission.AssetId) then
				return true;
			end;

		-- Check team permissions
		elseif Permission.Type == 'Team' then
			if Permission.Team and Player.Team == Permission.Team then
				return true;
			elseif Permission.TeamColor and Player.Team and Player.Team.TeamColor == Permission.TeamColor then
				return true;
			elseif Permission.TeamName and Player.Team and Player.Team.Name == Permission.TeamName then
				return true;
			end;
		
		-- Check BC permissions
		elseif Permission.Type == 'NoBC' then
			if Player.MembershipType == Enum.MembershipType.None then
				return true;
			end;
		elseif Permission.Type == 'AnyBC' then
			if Player.MembershipType ~= Enum.MembershipType.None then
				return true;
			end;
		elseif Permission.Type == 'BC' then
			if Player.MembershipType == Enum.MembershipType.BuildersClub then
				return true;
			end;
		elseif Permission.Type == 'TBC' then
			if Player.MembershipType == Enum.MembershipType.TurboBuildersClub then
				return true;
			end;
		elseif Permission.Type == 'OBC' then
			if Player.MembershipType == Enum.MembershipType.OutrageousBuildersClub then
				return true;
			end;

		-- Check custom permissions
		elseif Permission.Type == 'Callback' then
			return Permission.Callback(Player);
		end;

	end;

	-- If the player passes none of these conditions, deny access
	return false;
end;

function Security.IsItemAllowed(Item, Player)
	-- Returns whether instance `Item` can be accessed

	-- Ensure `Item` is a part or a model
	local IsItemClassAllowed = (Item:IsA 'BasePart' and not Item:IsA 'Terrain') or
		(Item:IsA 'Model' and not Item:IsA 'Workspace') or
		Item:IsA 'Folder' or
		Item:IsA 'Smoke' or
		Item:IsA 'Fire' or
		Item:IsA 'Sparkles' or
		Item:IsA 'DataModelMesh' or
		Item:IsA 'Decal' or
		Item:IsA 'Texture' or
		Item:IsA 'Light'
	if not IsItemClassAllowed then
		return false
	end

	-- Check if `Item` descendants from any allowed location
	for _, AllowedLocation in pairs(Security.AllowedLocations) do
		if Item:IsDescendantOf(AllowedLocation) then
			return true
		end
	end

	-- Deny if `Item` is not a descendant of any allowed location
	return false

end

function Security.IsLocationAllowed(Location, Player)
	-- Returns whether location `Location` can be accessed

	-- Check if within allowed locations
	for _, AllowedLocation in pairs(Security.AllowedLocations) do
		if (AllowedLocation == Location) or Location:IsDescendantOf(AllowedLocation) then
			return true
		end
	end

	-- Deny if not within allowed locations
	return false
end

function Security.AreAreasEnabled()
	-- Returns whether areas are enabled

	-- Base whether areas are enabled depending on area container presence and tool mode
	if Security.Areas and (ToolMode == 'Tool') then
		return true;
	else
		return false;
	end;
end;

function Security.ArePartsViolatingAreas(Parts, Player, ExemptPartial, AreaPermissions)
	-- Returns whether the given parts are inside any unauthorized areas

	-- Make sure area security is being enforced
	if not Security.AreAreasEnabled() then
		return false;
	end;

	-- If no parts, no violations exist
	if not next(Parts) then
		return false
	end

	-- Make sure there is a permissions cache
	AreaPermissions = AreaPermissions or {};

	-- Check which areas the parts are in
	local Areas, RegionMap = Security.GetSelectionAreas(Parts, true);

	-- Check authorization for each relevant area
	for _, Area in pairs(Areas) do

		-- Determine authorization if not in given permissions cache
		if AreaPermissions[Area] == nil then
			AreaPermissions[Area] = Security.IsAreaAuthorizedForPlayer(Area, Player);
		end;

		-- If unauthorized and partial violations aren't exempt, declare violation
		if not ExemptPartial and AreaPermissions[Area] == false then
			return true;
		end;

		-- If authorized and partial violations are allowed, check if all parts match area
		if ExemptPartial and AreaPermissions[Area] then

			-- Get parts matched to this area
			for Region, RegionParts in pairs(RegionMap) do
				if Region.Area == Area then

					-- If all parts are on this authorized area, call off any violation
					if Support.CountKeys(Parts) == #RegionParts then
						return false
					end

				end
			end

		end;

	end;

	-- If not in a private area, determine violation based on public building policy
	if #Areas == 0 then
		return not Security.AllowPublicBuilding;

	-- If authorization for a partial violation-exempt check on an area failed, indicate a violation
	elseif ExemptPartial then
		return true;

	-- If in authorized areas, determine violation based on public building policy compliance
	elseif RegionMap and not Security.AllowPublicBuilding then

		-- Check area residence of each part's corner
		local PartCornerCompliance = {};
		for AreaRegion, Parts in pairs(RegionMap) do
			for _, Part in pairs(Parts) do
				PartCornerCompliance[Part] = PartCornerCompliance[Part] or 0;

				-- Track the number of corners that `Part` has in this region
				for _, Corner in pairs(Support.GetPartCorners(Part)) do
					if AreaRegion:CastPoint(Corner.p) then
						PartCornerCompliance[Part] = PartCornerCompliance[Part] + 1;
					end;
				end;

			end;
		end;

		-- Ensure all corners of the part are contained within areas
		for _, CornersContained in pairs(PartCornerCompliance) do
			if CornersContained ~= 8 then
				return true;
			end;
		end;

	end;

	-- If no violations occur, indicate no violations
	return false;
end;

function Security.GetSelectionAreas(Selection, ReturnMap)
	-- Returns a list of areas that the selection of parts is in

	-- Make sure areas are enabled
	if not Security.AreAreasEnabled() then
		return {};
	end;

	-- Start a map if requested
	local Map = ReturnMap and {} or nil;

	-- Check each area to find out if any of the parts are within
	local Areas = {};
	for _, Area in pairs(Security.Areas:GetChildren()) do

		-- Get all parts from the selection within this area
		local Region = RegionModule.new(
			Area.CFrame * CFrame.new(0, Security.AreaHeight / 2 - Area.Size.Y / 2, 0),
			Vector3.new(Area.Size.X, Security.AreaHeight + Area.Size.Y, Area.Size.Z)
		);
		Region.Area = Area
		local ContainedParts = Region:CastParts(Selection);

		-- If parts are in this area, remember the area
		if #ContainedParts > 0 then
			table.insert(Areas, Area);

			-- Map out the parts for each area region
			if Map then
				Map[Region] = ContainedParts;
			end;
		end;

	end;

	-- Return the areas where any of the given parts exist
	return Areas, Map;
end;

function Security.GetPermissions(Areas, Player)
	-- Returns a cache of the current player's authorization to the given areas

	-- Make sure security is enabled
	if not Security.AreAreasEnabled() then
		return;
	end;

	-- Build the cache of permissions for each area
	local Cache = {};
	for _, Area in pairs(Areas) do
		Cache[Area] = Security.IsAreaAuthorizedForPlayer(Area, Player);
	end;

	-- Return the permissions cache
	return Cache;
end;

return Security;