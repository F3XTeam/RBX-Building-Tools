local Root = script:FindFirstAncestorWhichIsA('Tool')
local Vendor = Root:WaitForChild('Vendor')
local TextService = game:GetService('TextService')

-- Libraries
local Roact = require(Vendor:WaitForChild('Roact'))
local new = Roact.createElement

-- Create component
local Tooltip = Roact.PureComponent:extend(script.Name)

function Tooltip:init()
    self.FrameSize, self.SetFrameSize = Roact.createBinding(UDim2.new())
    self:UpdateTextBounds(self.props.Text)
end

function Tooltip:willUpdate(nextProps)
    if self.props.Text ~= nextProps.Text then
        self:UpdateTextBounds(nextProps.Text)
    end
end

function Tooltip:UpdateTextBounds(Text)
    self.TextBounds = TextService:GetTextSize(
        Text:gsub('<br />', '\n'):gsub('<.->', ''),
        10,
        Enum.Font.Gotham,
        Vector2.new(math.huge, math.huge)
    )
end

function Tooltip:render()
    return new('Frame', {
        AnchorPoint = Vector2.new(0.5, 0);
        BackgroundColor3 = Color3.fromRGB(58, 58, 58);
        BackgroundTransparency = 0;
        BorderSizePixel = 0;
        Position = UDim2.new(0.5, 0, 1, 2);
        Size = UDim2.fromOffset(self.TextBounds.X + 20, self.TextBounds.Y + 8);
        ZIndex = 2;
        Visible = self.props.IsVisible;
    }, {
        Corners = new('UICorner', {
            CornerRadius = UDim.new(0, 3);
        });
        Arrow = new('Frame', {
            AnchorPoint = Vector2.new(0.5, 0.5);
            BackgroundColor3 = Color3.fromRGB(58, 58, 58);
            BackgroundTransparency = 0;
            BorderSizePixel = 0;
            Position = UDim2.new(0.5, 0, 0, 0);
            Size = UDim2.new(0, 6, 0, 6);
            ZIndex = 2;
        });
        Text = new('TextLabel', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 2;
            Font = Enum.Font.Gotham;
            RichText = true;
            Text = self.props.Text;
            TextColor3 = Color3.fromRGB(255, 255, 255);
            TextSize = 10;
            TextXAlignment = Enum.TextXAlignment.Center;
            TextYAlignment = Enum.TextYAlignment.Center;
        });
    })
end

return Tooltip