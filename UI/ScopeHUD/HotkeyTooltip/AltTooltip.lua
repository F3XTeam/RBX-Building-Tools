local Root = script.Parent.Parent.Parent.Parent
local Vendor = Root:WaitForChild 'Vendor'
local TextService = game:GetService('TextService')

-- Libraries
local Roact = require(Vendor:WaitForChild 'Roact')
local new = Roact.createElement

-- Calculate label length
local LABEL_TEXT = 'ALT'
local LABEL_LENGTH = TextService:GetTextSize(LABEL_TEXT,
    21/2, Enum.Font.SourceSansSemibold, Vector2.new(math.huge, math.huge)).X

local function ScopeInTooltip(props)
    return new('ImageLabel', {
        BackgroundTransparency = 1;
        ImageTransparency = 1 - 0.14;
        Image = 'rbxassetid://4445959523';
        ScaleType = Enum.ScaleType.Slice;
        SliceCenter = Rect.new(4, 4, 12, 12);
        ImageColor3 = Color3.fromRGB(0, 0, 0);
        Size = UDim2.new(0, LABEL_LENGTH + 8/2, 0, 30/2);
        LayoutOrder = props.LayoutOrder or 3;
    },
    {
        Label = new('TextLabel', {
            BackgroundTransparency = 1;
            Size = UDim2.new(0, LABEL_LENGTH, 1, 0);
            Position = UDim2.new(0, 5/2, 0.5, 0);
            AnchorPoint = Vector2.new(0, 0.5);
            Font = Enum.Font.SourceSansSemibold;
            TextSize = 21/2;
            Text = LABEL_TEXT;
            TextTransparency = 0.5;
            TextYAlignment = Enum.TextYAlignment.Center;
            TextColor3 = Color3.fromRGB(255, 255, 255);
            LayoutOrder = 1;
        });
    })
end

return ScopeInTooltip