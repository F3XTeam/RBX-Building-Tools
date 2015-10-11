local Tool						= script.Parent.Parent;
local Interfaces				= Tool.Interfaces;
local UIComponentCountValue		= Tool.UIComponentCount;
local Support					= require(Tool:WaitForChild 'SupportLibrary');

-- Provide a count of the number of UI components in the tool
-- (this allows the client-side code to begin when all expected
-- components have loaded/replicated)

UIComponentCountValue.Value = #Support.GetAllDescendants( Interfaces );