local Root = script.Parent.Parent.Parent.Parent
local Vendor = Root:WaitForChild 'Vendor'
local TextService = game:GetService('TextService')

-- Libraries
local Roact = require(Vendor:WaitForChild 'Roact')
local new = Roact.createElement

-- Text sizes
local TextBoundaries = Vector2.new(math.huge, math.huge)
local TITLE_SIZE = TextService:GetTextSize('Selection mode', 24/2, Enum.Font.SourceSans, TextBoundaries)
local HOTKEY_SIZE = TextService:GetTextSize('SHIFT-T', 24/2, Enum.Font.SourceSans, TextBoundaries)
local SCOPED_LABEL_SIZE = TextService:GetTextSize('Groups and parts', 25/2, Enum.Font.SourceSans, TextBoundaries)
local DIRECT_LABEL_SIZE = TextService:GetTextSize('Parts only', 25/2, Enum.Font.SourceSans, TextBoundaries)

local function Tooltip(props)
    return new('ImageLabel', {
        AnchorPoint = props.IsToolModeEnabled and
            Vector2.new(0, 1) or
            Vector2.new(0, 0);
        Position = props.IsToolModeEnabled and
            UDim2.new(0, 0, 0, -12/2) or
            UDim2.new(0, 0, 1, 12/2);
        BackgroundTransparency = 1;
        Image = 'rbxassetid://4445959523';
        ScaleType = Enum.ScaleType.Slice;
        SliceCenter = Rect.new(4, 4, 12, 12);
        ImageColor3 = Color3.fromRGB(67, 67, 67);
        Size = UDim2.new(0, TITLE_SIZE.X + 15/2 + HOTKEY_SIZE.X + 22/2, 0, 94/2);
        Visible = props.Visible;
    },
    {
        Arrow = new('Frame', {
            BackgroundColor3 = Color3.fromRGB(67, 67, 67);
            BorderSizePixel = 0;
            AnchorPoint = Vector2.new(0.5, 0.5);
            Position = props.IsToolModeEnabled and
                UDim2.new(0, 18/2, 1, 0) or
                UDim2.new(0, 18/2, 0, 0);
            Size = UDim2.new(0, 10/2, 0, 10/2);
            Rotation = 45;
        });
        Title = new('TextLabel', {
            BackgroundTransparency = 1;
            Font = Enum.Font.SourceSans;
            TextSize = 24/2;
            TextColor3 = Color3.new(1, 1, 1);
            TextTransparency = 1 - 0.6;
            Text = 'Selection mode';
            Size = UDim2.new(0, TITLE_SIZE.X, 0, TITLE_SIZE.Y);
            Position = UDim2.new(0, 8/2, 0, 5/2 + 2);
        });
        Hotkey = new('TextLabel', {
            BackgroundTransparency = 1;
            Font = Enum.Font.SourceSansSemibold;
            TextSize = 20/2;
            TextColor3 = Color3.new(1, 1, 1);
            TextTransparency = 0;
            Text = 'SHIFT-T';
            Size = UDim2.new(0, HOTKEY_SIZE.X, 0, HOTKEY_SIZE.Y);
            Position = UDim2.new(0, 8/2 + TITLE_SIZE.X + 15/2, 0, 5/2 + 2);
        });
        ScopedIcon = new('ImageLabel', {
            BackgroundTransparency = 1;
            Image = 'rbxassetid://4463020853';
            ImageTransparency = 1 - 0.4;
            Position = UDim2.fromOffset(
                8/2,
                5/2 + TITLE_SIZE.Y + 2
            );
            Size = UDim2.new(0, 28/2, 0, 28/2);
            ImageRectOffset = Vector2.new(0, 0);
            ImageRectSize = Vector2.new(14, 14);
        });
        ScopedLabel = new('TextLabel', {
            BackgroundTransparency = 1;
            Font = Enum.Font.SourceSans;
            TextSize = 25/2;
            TextColor3 = Color3.new(1, 1, 1);
            Text = 'Groups and parts';
            Size = UDim2.new(0, SCOPED_LABEL_SIZE.X, 0, SCOPED_LABEL_SIZE.Y);
            Position = UDim2.fromOffset(
                (8 + 26 + 8)/2,
                5/2 + TITLE_SIZE.Y + 2
            );
            TextXAlignment = Enum.TextXAlignment.Left;
        });
        DirectIcon = new('ImageLabel', {
            BackgroundTransparency = 1;
            Image = 'rbxassetid://4463020853';
            ImageTransparency = 1 - 0.4;
            Position = UDim2.fromOffset(
                8/2,
                5/2 + TITLE_SIZE.Y + 2 + SCOPED_LABEL_SIZE.Y + 1
            );
            Size = UDim2.new(0, 28/2, 0, 28/2);
            ImageRectOffset = Vector2.new(14, 0);
            ImageRectSize = Vector2.new(14, 14);
        });
        DirectLabel = new('TextLabel', {
            BackgroundTransparency = 1;
            Font = Enum.Font.SourceSans;
            TextSize = 25/2;
            TextColor3 = Color3.new(1, 1, 1);
            Text = 'Parts only';
            Size = UDim2.new(0, DIRECT_LABEL_SIZE.X, 0, DIRECT_LABEL_SIZE.Y);
            Position = UDim2.fromOffset(
                (8 + 26 + 8)/2,
                5/2 + TITLE_SIZE.Y + 2 + SCOPED_LABEL_SIZE.Y + 1
            );
            TextXAlignment = Enum.TextXAlignment.Left;
        });
    })
end

return Tooltip