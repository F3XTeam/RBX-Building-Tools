local Tool = script.Parent;

-- Initialize the core
local Core = require(Tool:WaitForChild 'Core');

-- Attach core tools
require(Tool.Tools.CoreToolLoader);