local Tool						= script.Parent.Parent;
local Interfaces				= Tool.Interfaces;
local UIComponentCountValue		= Tool.UIComponentCount;

function _getAllDescendants( Parent )
	-- Recursively gets all the descendants of  `Parent` and returns them

	local descendants = {};
	for _, Child in pairs( Parent:GetChildren() ) do

		-- Add the direct descendants of `Parent`
		table.insert( descendants, Child );

		-- Add the descendants of each child
		for _, Subchild in pairs( _getAllDescendants( Child ) ) do
			table.insert( descendants, Subchild );
		end;

	end;
	return descendants;
end;

-- Provide a count of the number of UI components in the tool
-- (this allows the client-side code to begin when all expected
-- components have loaded/replicated)

UIComponentCountValue.Value = #_getAllDescendants( Interfaces );