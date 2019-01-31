local Root = script.Parent.Parent.Parent.Parent
local Vendor = Root:WaitForChild 'Vendor'
local UI = Root:WaitForChild 'UI'

-- Libraries
local Roact = require(Vendor:WaitForChild 'Roact')

-- Roact
local new = Roact.createElement
local Frame = require(UI:WaitForChild 'Frame')
local TextLabel = require(UI:WaitForChild 'TextLabel')
local ImageLabel = require(UI:WaitForChild 'ImageLabel')
local ImageButton = require(UI:WaitForChild 'ImageButton')

-- Create component
local OptionButton = Roact.PureComponent:extend 'OptionButton'

function OptionButton:init()

    -- Set initial state
    self.state = {
        Hovering = nil
    }

    function self.OnMouseEnter()
        self:setState { Hovering = true }
    end

    function self.OnMouseLeave()
        self:setState { Hovering = Roact.None }
    end

end

function OptionButton:render()
    local props = self.props
    local state = self.state
    local IsSelected = props.Selected or nil

    return new(ImageButton, {
        Size = UDim2.new(0, 50, 0, 50),
        Image = 'rbxassetid://2777557920',
        ImageColor3 = Color3.new(1, 1, 1),
        ImageRectOffset = Vector2.new(128, 0),
        ImageRectSize = Vector2.new(64, 64),
        ImageTransparency = (IsSelected or state.Hovering) and 0 or 1,
        LayoutOrder = props.LayoutOrder,
        ZIndex = 0,
        [Roact.Event.Activated] = props.OnActivated,
        [Roact.Event.MouseEnter] = self.OnMouseEnter,
        [Roact.Event.MouseLeave] = self.OnMouseLeave,
    },
    {
        Label = props.Label and new(TextLabel, {
            TextColor3 = Color3.new(1, 1, 1),
            Text = props.Label,
            TextSize = 10,
            Font = 'SourceSansLight',
            Bold = true,
            Size = 'WRAP_CONTENT',
            Position = UDim2.new(0.5, 0, 1, 0),
            AnchorPoint = Vector2.new(0.5, 0.5)
        },
        {
            Background = new(ImageLabel, {
                Image = 'rbxassetid://2777557582',
                ImageColor3 = Color3.fromRGB(84, 84, 84),
                ImageTransparency = 0.5,
                Position = UDim2.new(0.5, 0, 0.5, 0),
                AnchorPoint = Vector2.new(0.5, 0.5),
                ZIndex = 0,
                Size = UDim2.new(1, 8, 1, 4)
            })
        }),
        Checkmark = IsSelected and new(ImageLabel, {
            Image = 'rbxassetid://2777552852',
            ImageRectSize = Vector2.new(15, 15),
            ImageRectOffset = Vector2.new(87, 0),
            Size = UDim2.new(0, 15, 0, 15),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.85, 0, 0.25, 0),
            ZIndex = 2
        }),
        Content = new(Frame, {
            [Roact.Children] = props[Roact.Children]
        })
    })
end

return OptionButton