local CoreTools = script.Parent;
local Tool = CoreTools.Parent;
local Core = require(Tool.Core);

-- Initialize move tool
local MoveTool = require(CoreTools.MoveTool);
Core.AssignHotkey('Z', Core.Support.Call(Core.EquipTool, MoveTool));
Core.Dock.AddToolButton(Core.Assets.MoveIcon, 'Z', MoveTool);

-- Initialize resize tool
local ResizeTool = require(CoreTools.ResizeTool)
Core.AssignHotkey('X', Core.Support.Call(Core.EquipTool, ResizeTool));
Core.Dock.AddToolButton(Core.Assets.ResizeIcon, 'X', ResizeTool);

-- Initialize rotate tool
local RotateTool = require(CoreTools.RotateTool)
Core.AssignHotkey('C', Core.Support.Call(Core.EquipTool, RotateTool));
Core.Dock.AddToolButton(Core.Assets.RotateIcon, 'C', RotateTool);

-- Initialize paint tool
local PaintTool = require(CoreTools.PaintTool)
Core.AssignHotkey('V', Core.Support.Call(Core.EquipTool, PaintTool));
Core.Dock.AddToolButton(Core.Assets.PaintIcon, 'V', PaintTool);

-- Initialize surface tool
local SurfaceTool = require(CoreTools.SurfaceTool)
Core.AssignHotkey('B', Core.Support.Call(Core.EquipTool, SurfaceTool));
Core.Dock.AddToolButton(Core.Assets.SurfaceIcon, 'B', SurfaceTool);

-- Initialize material tool
local MaterialTool = require(CoreTools.MaterialTool)
Core.AssignHotkey('N', Core.Support.Call(Core.EquipTool, MaterialTool));
Core.Dock.AddToolButton(Core.Assets.MaterialIcon, 'N', MaterialTool);

-- Initialize anchor tool
local AnchorTool = require(CoreTools.AnchorTool)
Core.AssignHotkey('M', Core.Support.Call(Core.EquipTool, AnchorTool));
Core.Dock.AddToolButton(Core.Assets.AnchorIcon, 'M', AnchorTool);

-- Initialize collision tool
local CollisionTool = require(CoreTools.CollisionTool)
Core.AssignHotkey('K', Core.Support.Call(Core.EquipTool, CollisionTool));
Core.Dock.AddToolButton(Core.Assets.CollisionIcon, 'K', CollisionTool);

-- Initialize new part tool
local NewPartTool = require(CoreTools.NewPartTool)
Core.AssignHotkey('J', Core.Support.Call(Core.EquipTool, NewPartTool));
Core.Dock.AddToolButton(Core.Assets.NewPartIcon, 'J', NewPartTool);

-- Initialize mesh tool
local MeshTool = require(CoreTools.MeshTool)
Core.AssignHotkey('H', Core.Support.Call(Core.EquipTool, MeshTool));
Core.Dock.AddToolButton(Core.Assets.MeshIcon, 'H', MeshTool);

-- Initialize texture tool
local TextureTool = require(CoreTools.TextureTool)
Core.AssignHotkey('G', Core.Support.Call(Core.EquipTool, TextureTool));
Core.Dock.AddToolButton(Core.Assets.TextureIcon, 'G', TextureTool);

-- Initialize weld tool
local WeldTool = require(CoreTools.WeldTool)
Core.AssignHotkey('F', Core.Support.Call(Core.EquipTool, WeldTool));
Core.Dock.AddToolButton(Core.Assets.WeldIcon, 'F', WeldTool);

-- Initialize lighting tool
local LightingTool = require(CoreTools.LightingTool)
Core.AssignHotkey('U', Core.Support.Call(Core.EquipTool, LightingTool));
Core.Dock.AddToolButton(Core.Assets.LightingIcon, 'U', LightingTool);

-- Initialize decorate tool
local DecorateTool = require(CoreTools.DecorateTool)
Core.AssignHotkey('P', Core.Support.Call(Core.EquipTool, DecorateTool));
Core.Dock.AddToolButton(Core.Assets.DecorateIcon, 'P', DecorateTool);

-- Return success
return true;