-- References
Tool = script.Parent;
Support = require(Tool.SupportLibrary);

-- Initialize the security module
Security = {};
Security.Areas = {};

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
	for _, Area in pairs(Security.Areas) do

		-- Get the corner's offset from the area
		local Offset = Area.CFrame:toObjectSpace(Point);
		local Extents = Area.Size / 2;

		-- Check if the corner is within the XZ plane of the area, and within 500 above the area
		if math.abs(Offset.x) <= Extents.x and Offset.y <= 500 and Offset.y >= Extents.y and math.abs(Offset.z) <= Extents.z then
			return Area;
		end;

	end;

end;


return Security;