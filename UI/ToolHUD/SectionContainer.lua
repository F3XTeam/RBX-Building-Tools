local Root = script.Parent.Parent.Parent
local Vendor = Root:WaitForChild 'Vendor'
local UI = Root:WaitForChild 'UI'
local TweenService = game:GetService 'TweenService'

-- Libraries
local Roact = require(Vendor:WaitForChild 'Roact')

-- Roact
local new = Roact.createElement
local ImageLabel = require(UI:WaitForChild 'ImageLabel')

-- Create component
local SectionContainer = Roact.PureComponent:extend 'ToolHUD'

-- Default properties
SectionContainer.defaultProps = {
    Position = UDim2.new(0, 10, 0.45, 0)
}

function SectionContainer:init()
    function self.OnMouseEnter(...)
        self.props.OnMouseEnter(...)
        self:setState { Hovering = true }
    end

    function self.OnMouseLeave(...)
        self.props.OnMouseLeave(...)
        self:setState { Hovering = false }
    end

    -- Background instance reference
    self.BackgroundRef = Roact.createRef()

    -- Set initial state
    self.state = {
        Hovering = false
    }
end

function SectionContainer:didUpdate(previousProps, previousState)
    if (not previousState.Hovering) and self.state.Hovering then
        self.BackgroundRef.current.ImageTransparency = 1
        TweenService:Create(self.BackgroundRef.current, TweenInfo.new(0.25), { ImageTransparency = 1 - 0.4 }):Play()
    elseif previousState.Hovering and (not self.state.Hovering) then
        self.BackgroundRef.current.ImageTransparency = 1 - 0.4
        TweenService:Create(self.BackgroundRef.current, TweenInfo.new(0.25), { ImageTransparency = 1 }):Play()
    end
end

function SectionContainer:didMount()
    self.InitialRenderComplete = true
end

function SectionContainer:willUnmount()
    self.InitialRenderComplete = nil
end

function SectionContainer:render()
    local props = self.props
    local state = self.state

    return new(ImageLabel, {
        LayoutOrder = props.LayoutOrder,
        Image = 'rbxassetid://2244248341',
        ImageColor3 = Color3.fromRGB(64, 64, 64),
        ScaleType = 'Slice',
        SliceCenter = Rect.new(4, 4, 12, 12),
        Active = true,
        Draggable = true,
        Layout = 'List',
        LayoutDirection = 'Vertical',
        ImageTransparency = (not self.InitialRenderComplete) and (state.Hovering and 1 - 0.4 or 1),
        Height = 'WRAP_CONTENT',
        HorizontalAlignment = 'Center',
        VerticalAlignment = 'Top',
        ZIndex = 0,
        Position = props.Position,
        [Roact.Event.MouseEnter] = self.OnMouseEnter,
        [Roact.Event.MouseLeave] = self.OnMouseLeave,
        [Roact.Ref] = self.BackgroundRef,
        [Roact.Children] = props[Roact.Children]
    })
end

return SectionContainer