local Root = script:FindFirstAncestorWhichIsA('Tool')
local Vendor = Root:WaitForChild('Vendor')

-- Libraries
local Roact = require(Vendor:WaitForChild('Roact'))

-- Roact
local new = Roact.createElement
local ToolList = require(script:WaitForChild('ToolList'))
local SelectionPane = require(script:WaitForChild('SelectionPane'))
local AboutPane = require(script:WaitForChild('AboutPane'))

-- Create component
local Dock = Roact.PureComponent:extend(script.Name)

function Dock:init()
    self.DockSize, self.SetDockSize = Roact.createBinding(UDim2.new())
end

function Dock:render()
    return new('Frame', {
        Active = true;
        AnchorPoint = Vector2.new(1, 0.5);
        BackgroundTransparency = 1;
        Position = UDim2.new(1, -10, 0.6, 0);
        Size = self.DockSize;
        ZIndex = 0;
    }, {
        Layout = new('UIListLayout', {
            Padding = UDim.new(0, 1);
            FillDirection = Enum.FillDirection.Vertical;
            HorizontalAlignment = Enum.HorizontalAlignment.Left;
            VerticalAlignment = Enum.VerticalAlignment.Top;
            SortOrder = Enum.SortOrder.LayoutOrder;
            [Roact.Ref] = function (rbx)
                if rbx then
                    self.SetDockSize(UDim2.fromOffset(rbx.AbsoluteContentSize.X, rbx.AbsoluteContentSize.Y))
                end
            end;
            [Roact.Change.AbsoluteContentSize] = function (rbx)
                self.SetDockSize(UDim2.fromOffset(rbx.AbsoluteContentSize.X, rbx.AbsoluteContentSize.Y))
            end;
        });
        ToolList = new(ToolList, {
            LayoutOrder = 0;
            Tools = self.props.Tools;
            Core = self.props.Core;
        });
        SelectionPane = new(SelectionPane, {
            LayoutOrder = 1;
            Core = self.props.Core;
        });
        AboutPane = new(AboutPane, {
            LayoutOrder = 2;
            Core = self.props.Core;
        });
    })
end

return Dock