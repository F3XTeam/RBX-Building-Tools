local Root = script.Parent.Parent
local Libraries = Root:WaitForChild 'Libraries'
local Vendor = Root:WaitForChild 'Vendor'
local UI = Root:WaitForChild 'UI'
local TweenService = game:GetService 'TweenService'

-- Libraries
local Roact = require(Vendor:WaitForChild 'Roact')
local Support = require(Libraries:WaitForChild 'SupportLibrary')

-- Roact
local new = Roact.createElement
local ImageLabel = require(UI:WaitForChild 'ImageLabel')
local Frame = require(UI:WaitForChild 'Frame')
local HeaderLabel = require(script:WaitForChild 'HeaderLabel')

-- Create component
local ToolHUD = Roact.PureComponent:extend 'ToolHUD'

-- Default properties
ToolHUD.defaultProps = {
    Position = UDim2.new(0, 10, 0.45, 0)
}

function ToolHUD:init(props)
    function self.OnMouseEnter()
        if not self.state.SuppressingHover then
            self:setState { Hovering = true }
        end
    end

    function self.OnMouseLeave()
        self:setState {
            Hovering = Roact.None,
            SuppressingHover = Roact.None
        }
    end

    function self.OnChildMouseEnter()
        self:setState {
            SuppressingHover = true,
            Hovering = Roact.None
        }
    end

    function self.OnChildMouseLeave(rbx, X, Y)
        self:setState {
            SuppressingHover = Roact.None,
            Hovering = self.state.SuppressingHover
        }
    end

    -- Background instance reference
    self.BackgroundRef = Roact.createRef()

    -- Set initial state
    self.state = {
        Hovering = false
    }
end

function ToolHUD:didUpdate(previousProps, previousState)
    if (not previousState.Hovering) and self.state.Hovering then
        self.BackgroundRef.current.ImageTransparency = 1
        TweenService:Create(self.BackgroundRef.current, TweenInfo.new(0.25), { ImageTransparency = 1 - 0.4 }):Play()
    elseif previousState.Hovering and (not self.state.Hovering) then
        self.BackgroundRef.current.ImageTransparency = 1 - 0.4
        TweenService:Create(self.BackgroundRef.current, TweenInfo.new(0.25), { ImageTransparency = 1 }):Play()
    end
end

function ToolHUD:didMount()
    self.InitialRenderComplete = true
end

function ToolHUD:willUnmount()
    self.InitialRenderComplete = nil
end

function ToolHUD:render()
    local props = self.props
    local state = self.state

    -- Add callbacks to child sections
    local Sections = props[Roact.Children]
    for _, Section in pairs(Sections) do
        Section.props.OnMouseEnter = self.OnChildMouseEnter
        Section.props.OnMouseLeave = self.OnChildMouseLeave
    end

    -- Background
    return new(ImageLabel, {
        Image = 'rbxassetid://2244248341',
        ImageColor3 = Color3.fromRGB(64, 64, 64),
        ScaleType = 'Slice',
        SliceCenter = Rect.new(4, 4, 12, 12),
        Active = true,
        Draggable = true,
        Layout = 'List',
        LayoutDirection = 'Vertical',
        ImageTransparency = (not self.InitialRenderComplete) and (state.Hovering and 1 - 0.4 or 1),
        Width = props.Width,
        Height = 'WRAP_CONTENT',
        HorizontalPadding = 6,
        VerticalPadding = 12,
        HorizontalAlignment = 'Center',
        VerticalAlignment = 'Top',
        Position = props.Position,
        [Roact.Event.MouseEnter] = self.OnMouseEnter,
        [Roact.Event.MouseLeave] = self.OnMouseLeave,
        [Roact.Ref] = self.BackgroundRef
    },
    {
        Header = new('Frame', {
            Size = UDim2.new(1, -6, 0, 25),
            BackgroundTransparency = 1,
            LayoutOrder = 0
        },
        {
            ColorBar = new('Frame', {
                BackgroundColor3 = props.Color,
                Size = UDim2.new(1, 0, 0, 2),
                BorderSizePixel = 0
            }),

            -- Tool label
            Label = new(HeaderLabel, {
                Label = props.Label
            }),

            -- F3X logotype
            Signature = new('ImageLabel', {
                Image = 'rbxassetid://2800152391',
                Size = UDim2.new(0, 22, 0, 10),
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, -3, 0, 10),
                BackgroundTransparency = 1
            })
        }),

        -- Custom content
        Content = new(Frame, {
            LayoutOrder = 1,
            Layout = 'List',
            LayoutDirection = 'Vertical',
            Height = 'WRAP_CONTENT',
            [Roact.Children] = Sections
        })
    })
end

return ToolHUD