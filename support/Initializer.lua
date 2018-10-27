local Tool = script.Parent;
local Plugin = plugin;

-- Expose plugin if in plugin mode
_G[Tool] = { Plugin = Plugin };

-- Load tool completely before proceeding
local Indicator = Tool:WaitForChild 'Loaded';
while not Indicator.Value do
	Indicator.Changed:Wait();
end;

-- Initialize the core
local Core = require(Tool:WaitForChild 'Core');

-- Attach core tools
require(Tool.Tools.CoreToolLoader);