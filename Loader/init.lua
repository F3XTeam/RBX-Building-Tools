local Tool = script.Parent;

-- Load tool completely before proceeding
local Indicator = Tool:WaitForChild 'Loaded';
while not Indicator.Value do
	Indicator.Changed:Wait();
end;

-- Initialize the core
local Core = require(Tool:WaitForChild 'Core');

-- Get core tools
local CoreTools = Tool:WaitForChild 'Tools';

-- Initialize move tool
local MoveTool = require(CoreTools:WaitForChild 'Move');
Core.AssignHotkey('Z', Core.Support.Call(Core.EquipTool, MoveTool));
Core.AddToolButton(Core.Assets.MoveIcon, 'Z', MoveTool)

-- Initialize resize tool
local ResizeTool = require(CoreTools:WaitForChild 'Resize')
Core.AssignHotkey('X', Core.Support.Call(Core.EquipTool, ResizeTool));
Core.AddToolButton(Core.Assets.ResizeIcon, 'X', ResizeTool)

-- Initialize rotate tool
local RotateTool = require(CoreTools:WaitForChild 'Rotate')
Core.AssignHotkey('C', Core.Support.Call(Core.EquipTool, RotateTool));
Core.AddToolButton(Core.Assets.RotateIcon, 'C', RotateTool)

-- Initialize paint tool
local PaintTool = require(CoreTools:WaitForChild 'Paint')
Core.AssignHotkey('V', Core.Support.Call(Core.EquipTool, PaintTool));
Core.AddToolButton(Core.Assets.PaintIcon, 'V', PaintTool)

-- Initialize surface tool
local SurfaceTool = require(CoreTools:WaitForChild 'Surface')
Core.AssignHotkey('B', Core.Support.Call(Core.EquipTool, SurfaceTool));
Core.AddToolButton(Core.Assets.SurfaceIcon, 'B', SurfaceTool)

-- Initialize material tool
local MaterialTool = require(CoreTools:WaitForChild 'Material')
Core.AssignHotkey('N', Core.Support.Call(Core.EquipTool, MaterialTool));
Core.AddToolButton(Core.Assets.MaterialIcon, 'N', MaterialTool)

-- Initialize anchor tool
local AnchorTool = require(CoreTools:WaitForChild 'Anchor')
Core.AssignHotkey('M', Core.Support.Call(Core.EquipTool, AnchorTool));
Core.AddToolButton(Core.Assets.AnchorIcon, 'M', AnchorTool)

-- Initialize collision tool
local CollisionTool = require(CoreTools:WaitForChild 'Collision')
Core.AssignHotkey('K', Core.Support.Call(Core.EquipTool, CollisionTool));
Core.AddToolButton(Core.Assets.CollisionIcon, 'K', CollisionTool)

-- Initialize new part tool
local NewPartTool = require(CoreTools:WaitForChild 'NewPart')
Core.AssignHotkey('J', Core.Support.Call(Core.EquipTool, NewPartTool));
Core.AddToolButton(Core.Assets.NewPartIcon, 'J', NewPartTool)

-- Initialize mesh tool
local MeshTool = require(CoreTools:WaitForChild 'Mesh')
Core.AssignHotkey('H', Core.Support.Call(Core.EquipTool, MeshTool));
Core.AddToolButton(Core.Assets.MeshIcon, 'H', MeshTool)

-- Initialize texture tool
local TextureTool = require(CoreTools:WaitForChild 'Texture')
Core.AssignHotkey('G', Core.Support.Call(Core.EquipTool, TextureTool));
Core.AddToolButton(Core.Assets.TextureIcon, 'G', TextureTool)

-- Initialize weld tool
local WeldTool = require(CoreTools:WaitForChild 'Weld')
Core.AssignHotkey('F', Core.Support.Call(Core.EquipTool, WeldTool));
Core.AddToolButton(Core.Assets.WeldIcon, 'F', WeldTool)

-- Initialize lighting tool
local LightingTool = require(CoreTools:WaitForChild 'Lighting')
Core.AssignHotkey('U', Core.Support.Call(Core.EquipTool, LightingTool));
Core.AddToolButton(Core.Assets.LightingIcon, 'U', LightingTool)

-- Initialize decorate tool
local DecorateTool = require(CoreTools:WaitForChild 'Decorate')
Core.AssignHotkey('P', Core.Support.Call(Core.EquipTool, DecorateTool));
Core.AddToolButton(Core.Assets.DecorateIcon, 'P', DecorateTool)

return Core