local Root = script:FindFirstAncestorWhichIsA('Tool')
local Vendor = Root:WaitForChild('Vendor')

-- Libraries
local Roact = require(Vendor:WaitForChild('Roact'))
local new = Roact.createElement

-- Create component
local ToolManualWindow = Roact.PureComponent:extend(script.Name)

function ToolManualWindow:init()
    self.CanvasSize, self.SetCanvasSize = Roact.createBinding(UDim2.new(1, 0, 0, 0))
end

function ToolManualWindow:render()
    return new('ScreenGui', {
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling;
    }, {
        Window = new('Frame', {
            AnchorPoint = Vector2.new(0.5, 0.5);
            BackgroundColor3 = Color3.fromRGB(61, 61, 61);
            BackgroundTransparency = 0.1;
            BorderSizePixel = 0;
            Position = UDim2.new(0.5, 0, 0.5, 0);
            Size = self.CanvasSize:map(function (CanvasSize)
                return UDim2.fromOffset(420, CanvasSize.Y.Offset + 10)
            end);
        }, {
            SizeConstraint = new('UISizeConstraint', {
                MaxSize = Vector2.new(math.huge, 300);
            });
            Corners = new('UICorner', {
                CornerRadius = UDim.new(0, 3);
            });
            ColorBar = new('Frame', {
                BackgroundColor3 = self.props.ThemeColor;
                BorderSizePixel = 0;
                Size = UDim2.new(0, 3, 1, 0);
            }, {
                Corners = new('UICorner', {
                    CornerRadius = UDim.new(0, 3);
                });
            });
            Content = new('ScrollingFrame', {
                BackgroundTransparency = 1;
                BorderSizePixel = 0;
                Size = UDim2.new(1, 0, 1, 0);
                CanvasSize = self.CanvasSize;
                ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255);
                ScrollBarThickness = 2;
                ScrollingDirection = Enum.ScrollingDirection.Y;
            }, {
                Text = new('TextLabel', {
                    BackgroundTransparency = 1;
                    Size = UDim2.new(1, 0, 1, 0);
                    Font = Enum.Font.Gotham;
                    LineHeight = 1.2;
                    RichText = true;
                    Text = self.props.Text;
                    TextColor3 = Color3.fromRGB(255, 255, 255);
                    TextSize = 11;
                    TextWrapped = true;
                    TextXAlignment = Enum.TextXAlignment.Left;
                    TextYAlignment = Enum.TextYAlignment.Top;
                    -- [Roact.Ref] = function (rbx)
                    --     if rbx then
                    --         self.SetCanvasSize(UDim2.new(1, 0, 0, rbx.TextBounds.Y))
                    --     end
                    -- end;
                    [Roact.Change.TextBounds] = function (rbx)
                        self.SetCanvasSize(UDim2.new(1, 0, 0, rbx.TextBounds.Y + 20))
                    end;
                }, {
                    Padding = new('UIPadding', {
                        PaddingBottom = UDim.new(0, 0);
                        PaddingLeft = UDim.new(0, 25);
                        PaddingRight = UDim.new(0, 25);
                        PaddingTop = UDim.new(0, 15);
                    });
                });
            });
        });
    })
end

return ToolManualWindow