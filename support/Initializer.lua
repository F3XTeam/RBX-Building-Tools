local Tool = script.Parent;
local Plugin = plugin;

-- Expose plugin if in plugin mode
_G[Tool] = { Plugin = Plugin };

-- Initialize the core
local Core = require(Tool:WaitForChild 'Core');

-- Attach core tools
require(Tool.Tools.CoreToolLoader);