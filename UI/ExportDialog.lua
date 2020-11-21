local Root = script:FindFirstAncestorWhichIsA('Tool')
local Vendor = Root:WaitForChild('Vendor')

-- Libraries
local Roact = require(Vendor:WaitForChild('Roact'))
local new = Roact.createElement

local function ExportDialog(props)
    return new('ScreenGui', {}, {
        Dialog = new('Frame', {
            AnchorPoint = Vector2.new(0.5, 0.5);
            BackgroundColor3 = Color3.fromRGB(31, 31, 31);
            BackgroundTransparency = 0.6;
            BorderSizePixel = 0;
            Position = UDim2.new(0.5, 0, 0.5, 0);
            Size = UDim2.new(0, 200, 0, 0);
        }, {
            Corners = new('UICorner', {
                CornerRadius = UDim.new(0, 4);
            });
            CloseButton = new('TextButton', {
                AnchorPoint = Vector2.new(0, 1);
                BackgroundColor3 = Color3.fromRGB(0, 0, 0);
                BackgroundTransparency = 0.5;
                Modal = true;
                Position = UDim2.new(0, 0, 1, 0);
                Size = UDim2.new(1, 0, 0, 23);
                Text = 'Close';
                Font = Enum.Font.GothamSemibold;
                TextColor3 = Color3.fromRGB(255, 255, 255);
                TextSize = 11;
                [Roact.Event.Activated] = function (rbx)
                    props.OnDismiss()
                end;
            }, {
                Corners = new('UICorner', {
                    CornerRadius = UDim.new(0, 4);
                });
            });
            Text = new('TextLabel', {
                BackgroundTransparency = 1;
                Size = UDim2.new(1, 0, 1, -23);
                Font = Enum.Font.GothamSemibold;
                RichText = true;
                Text = props.Text;
                TextColor3 = Color3.fromRGB(255, 255, 255);
                TextSize = 11;
                TextWrapped = true;
                [Roact.Change.TextBounds] = function (rbx)
                    rbx.Parent.Size = UDim2.new(0, 200, 0, rbx.TextBounds.Y + 23 + 26)
                end;
            }, {
                Padding = new('UIPadding', {
                    PaddingLeft = UDim.new(0, 10);
                    PaddingRight = UDim.new(0, 10);
                });
            });
        });
    })
end

return ExportDialog