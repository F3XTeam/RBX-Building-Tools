local Root = script.Parent.Parent.Parent
local Vendor = Root:WaitForChild 'Vendor'

-- Libraries
local Roact = require(Vendor:WaitForChild 'Roact')

-- Roact
local new = Roact.createElement

local function HeaderLabel(props)
    return new('TextLabel', {
        TextSize = 13,
        Font = 'SourceSansSemibold',
        Size = UDim2.new(1, -40, 0, 14),
        Text = props.Label,
        BackgroundTransparency = 1,
        TextColor3 = Color3.new(1, 1, 1),
        TextXAlignment = 'Left',
        TextYAlignment = 'Bottom',
        Position = UDim2.new(0, 6, 0, 20),
        AnchorPoint = Vector2.new(0, 1),
        TextStrokeTransparency = 0
    },
    {
        ClearLabel = new('TextLabel', {
            TextSize = 13,
            Font = 'SourceSansSemibold',
            Size = UDim2.new(1, 0, 1, 0),
            Text = props.Label,
            BackgroundTransparency = 1,
            TextColor3 = Color3.new(1, 1, 1),
            TextXAlignment = 'Left',
            TextYAlignment = 'Bottom'
        },
        {
            BoldLabel = new('TextLabel', {
                TextSize = 13,
                Font = 'SourceSansSemibold',
                Size = UDim2.new(1, 0, 1, 0),
                Text = props.Label,
                BackgroundTransparency = 1,
                TextColor3 = Color3.new(1, 1, 1),
                TextXAlignment = 'Left',
                TextYAlignment = 'Bottom'
            })
        })
    })
end

return HeaderLabel