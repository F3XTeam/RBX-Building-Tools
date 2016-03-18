-- Services
MarketplaceService = Game:GetService 'MarketplaceService';
HttpService = Game:GetService 'HttpService';
Workspace = Game:GetService 'Workspace';

-- References
Tool = script.Parent;
Support = require(Tool:WaitForChild 'SupportLibrary');
RegionModule = require(Tool:WaitForChild 'Region by AxisAngle');

-- Initialize the security module
Security = {};

-- The distance above the area-defining part that counts as part of the area
Security.AreaHeight = 500;

-- Track the enabling of areas
Security.Areas = Workspace:FindFirstChild('[Private Building Areas]');
Workspace.ChildAdded:connect(function (Child)
	if not Security.Areas and Child.Name == '[Private Building Areas]' then
		Security.Areas = Child;
	end;
end);
Workspace.ChildRemoved:connect(function (Child)
	if Security.Areas and Child.Name == '[Private Building Areas]' then
		Security.Areas = nil;
	end;
end);

-- Security module functionality

function Security.IsPartAuthorizedForPlayer(Part, Player)
	-- Returns whether `Player` can manipulate `Part`

	-- Automatically deny access if the part is locked
	if Part.Locked then
		return false;
	end;

	-- Automatically grant access if areas are disabled
	if not Security.AreAreasEnabled() then
		return true;
	end;

	-- Figure out what protection this part is under
	local Public, Areas = Security.GetPartAreas(Part);

	-- Automatically grant authorization if in public space
	if Public then
		return true;
	end;

	-- If the part is part of areas, base permissions off any of those areas
	for _, Area in pairs(Areas) do
		if Security.IsAreaAuthorizedForPlayer(Area, Player) then
			return true;
		end;
	end;

	-- If the player doesn't meet any conditions, deny access
	return false;
end;

function Security.IsPointAuthorizedForPlayer(Point, Player)
	-- Returns whether `Player` is authorized to space point `Point`

	-- Automatically grant access if areas are disabled
	if not Security.AreAreasEnabled() then
		return true;
	end;

	-- Figure out what protection this point is in
	local Area = Security.GetPointArea(Point);

	-- Automatically grant authorization if in public space
	if not Area then
		return true;
	end;

	-- Base permission off the point's area
	if Security.IsAreaAuthorizedForPlayer(Area, Player) then
		return true;
	end;

	-- If the player doesn't meet any conditions, deny access
	return false;
end;

function Security.IsAreaAuthorizedForPlayer(Area, Player)
	-- Returns whether `Player` has permission to manipulate parts in this area

	-- Make sure the area is properly structured
	local Permissions = Area:FindFirstChild 'Permissions';
	if not Permissions then
		return nil;
	end;

	-- Automatically grant access if the player is the owner of this area
	if Area:FindFirstChild('OwnerID') and Player.userId == Area.OwnerID.Value then
		return true;
	end;

	-- Automatically grant access if `Anybody` is enabled
	if Permissions:FindFirstChild 'Anybody' and Permissions.Anybody.Value then
		return true;
	end;

	-- Grant access if the player's name or ID is on the list
	if Permissions:FindFirstChild 'Players' and Permissions.Players.Value:len() > 0 then

		-- Try to parse the player list
		local PlayerList;
		pcall(function () PlayerList = HttpService:JSONDecode(Permissions.Players.Value); end);

		-- Make sure the player list was properly formatted
		if PlayerList and type(PlayerList) == 'table' then

			-- Check if the player is on the list
			for _, PlayerIdentifier in pairs(PlayerList) do
				if	(type(PlayerIdentifier) == 'string' and Player.Name == PlayerIdentifier) or
					(type(PlayerIdentifier) == 'number' and Player.userId == PlayerIdentifier) then
					return true;
				end;
			end;

		end;

	end;

	-- Grant access if the player's a friend & friends are allowed
	if Permissions:FindFirstChild 'Friends' and Permissions.Friends.Value and Area:FindFirstChild('OwnerID') then
		if Player:IsFriendsWith(Area.OwnerID.Value) then
			return true;
		end;
	end;

	-- Grant access if the player's in the given group
	if Permissions:FindFirstChild 'InGroup' and Permissions.InGroup.Value:len() > 0 then

		-- Try to parse the group data
		local GroupData;
		pcall(function () GroupData = HttpService:JSONDecode(Permissions.InGroup.Value); end);

		-- Make sure the group data was properly formatted
		if GroupData and type(GroupData) == 'table' and GroupData.id and type(GroupData.id) == 'number' then

			-- Check if the player is in the given group
			local PlayerInGroup = Player:IsInGroup(GroupData.id);
			if PlayerInGroup then

				-- If all the player needs is to be in the group, authorize them
				if not GroupData.ranks then
					return true;

				-- If a rank is specified, check that
				else
					local PlayerRole = Player:GetRoleInGroup(GroupData.id);
					local PlayerRank = Player:GetRankInGroup(GroupData.id);

					-- Go through each specified rank, & check if the player is in any of them
					for _, Rank in pairs(GroupData.ranks) do

						-- If the rank # is given straightforwardly, only check that
						if type(Rank) == 'number' then
							if PlayerRank == Rank then
								return true;
							end;

						-- If it's a role name, or a rank # with a >, <, >=, <= prefix, check those
						elseif type(Rank) == 'string' then

							-- Try to parse out the symbol and rank # if any
							local Symbol, RankNumber = Rank:match('([<>]?=?)([0-9]+)');

							-- Check roles
							if not RankNumber then
								if PlayerRole == Rank then
									return true;
								end;

							-- Check ranks, maybe with >, <, >=, or <=
							else
								RankNumber = tonumber(RankNumber);

								-- If no symbol, directly check rank #
								if not Symbol and PlayerRank == RankNumber then
									return true;
								end;

								-- If there are symbols, check those
								if Symbol == '>' and PlayerRank > RankNumber then
									return true;
								elseif Symbol == '<' and PlayerRank < RankNumber then
									return true;
								elseif Symbol == '>=' and PlayerRank >= RankNumber then
									return true;
								elseif Symbol == '<=' and PlayerRank <= RankNumber then
									return true;
								end;
							end;

						end;

					end;
				end;

			end;

		end;

	end;

	-- Grant access if the player owns the given item
	if Permissions:FindFirstChild 'HasItem' then
		if MarketplaceService:PlayerOwnsAsset(Player, Permissions.HasItem.Value) then
			return true;
		end;
	end;

	-- Grant access if the player has the specified BC type
	if Permissions:FindFirstChild 'NoBC' and Permissions.NoBC.Value then
		if Player.MembershipType == Enum.MembershipType.None then
			return true;
		end;
	end;
	if Permissions:FindFirstChild 'AnyBC' and Permissions.AnyBC.Value then
		if Player.MembershipType ~= Enum.MembershipType.None then
			return true;
		end;
	end
	if Permissions:FindFirstChild 'BC' and Permissions.BC.Value then
		if Player.MembershipType == Enum.MembershipType.BuildersClub then
			return true;
		end;
	end;
	if Permissions:FindFirstChild 'TBC' and Permissions.TBC.Value then
		if Player.MembershipType == Enum.MembershipType.TurboBuildersClub then
			return true;
		end;
	end;
	if Permissions:FindFirstChild 'OBC' and Permissions.OBC.Value then
		if Player.MembershipType == Enum.MembershipType.OutrageousBuildersClub then
			return true;
		end;
	end;

	-- Grant access if the player is in the specified team
	if Permissions:FindFirstChild 'InTeam' then
		if not Player.Neutral and Player.TeamColor == Permissions.InTeam.Value then
			return true;
		end;
	end;

	-- Grant access through a custom ModuleScript if it exists
	if Permissions:FindFirstChild 'Custom' then
		if require(Permissions.Custom)(Player) then
			return true;
		end;
	end;

	-- If the player passes none of these conditions, deny access
	return false;
end;

function Security.AreAreasEnabled()
	-- Returns whether areas are enabled

	-- Base whether areas are enabled depending on whether there's an area container
	if Security.Areas then
		return true;
	else
		return false;
	end;
end;

function Security.GetPartAreas(Part)
	-- Returns whether this part is public, along with any areas it's part of

	-- Get the corners of this part
	local Corners = Support.GetPartCorners(Part);

	local PartAreas = {};
	local ContainedCorners = 0;

	-- Check for the area of each corner
	for _, Corner in pairs(Corners) do
		local Area = Security.GetPointArea(Corner);
		if Area then
			table.insert(PartAreas, Area);
			ContainedCorners = ContainedCorners + 1;
		end;
	end;

	local Public = false;

	-- If there is a loose corner, consider it a public part
	if ContainedCorners ~= 8 then
		Public = true;
	end;

	return Public, PartAreas;
end;

function Security.GetPointArea(Point)
	-- Returns the area this point exists in, or `nil`

	-- Check every area
	for _, Area in pairs(Security.Areas:GetChildren()) do

		-- Get the corner's offset from the area
		local Offset = Point - Area.Position;
		local Extents = Area.Size / 2;

		-- Check if the corner is within the XZ plane of the area, and within the height of the area
		if math.abs(Offset.x) <= Extents.x and Offset.y <= Security.AreaHeight and Offset.y >= Extents.y and math.abs(Offset.z) <= Extents.z then
			return Area;
		end;

	end;

end;

function Security.ArePartsViolatingAreas(Parts, Player, AreaPermissions)
	-- Returns whether the given parts are inside any unauthorized areas

	-- Make sure area security is being enforced
	if not Security.AreAreasEnabled() then
		return false;
	end;

	-- Make sure there is a permissions cache
	AreaPermissions = AreaPermissions or {};

	-- Check with areas the parts are in
	local Areas = Security.GetSelectionAreas(Parts);

	-- Check authorization for each relevant area
	for _, Area in pairs(Areas) do

		-- If unauthorized, call a violation
		if AreaPermissions[Area] == false then
			return true;

		-- Determine authorization if not in given permissions cache
		elseif AreaPermissions[Area] == nil then
			AreaPermissions[Area] = Security.IsAreaAuthorizedForPlayer(Area, Player);
			if not AreaPermissions[Area] then
				return true;
			end;
		end;

	end;

	-- If no area authorization violations occur, return false
	return false;
end;

function Security.GetSelectionAreas(Selection)
	-- Returns a list of areas that the selection of parts is in

	-- Make sure areas are enabled
	if not Security.AreAreasEnabled() then
		return {};
	end;

	-- Check each area to find out if any of the parts are within
	local Areas = {};
	for _, Area in pairs(Security.Areas:GetChildren()) do

		-- Get all parts from the selection within this area
		local Region = RegionModule.new(
			Area.CFrame * CFrame.new(0, Security.AreaHeight / 2 - Area.Size.Y / 2, 0),
			Vector3.new(Area.Size.X, Security.AreaHeight + Area.Size.Y, Area.Size.Z)
		);
		local ContainedParts = Region:CastParts(Selection);

		-- If parts are in this area, remember the area
		if #ContainedParts > 0 then
			table.insert(Areas, Area);
		end;

	end;

	-- Return the areas where any of the given parts exist
	return Areas;
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