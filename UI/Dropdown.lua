local Root = script:FindFirstAncestorWhichIsA('Tool')
local Vendor = Root:WaitForChild('Vendor')
local Libraries = Root:WaitForChild('Libraries')

-- Libraries
local Roact = require(Vendor:WaitForChild('Roact'))
local Cryo = require(Libraries:WaitForChild('Cryo'))
local new = Roact.createElement

-- Create component
local Dropdown = Roact.PureComponent:extend(script.Name)

function Dropdown:init()
    self.Size, self.SetSize = Roact.createBinding(Vector2.new())
    self:setState({
        AreOptionsVisible = false;
    })
end

function Dropdown:BuildButtonList()
    local List = {}
    for _, Option in ipairs(self.props.Options) do
        table.insert(List, new('TextButton', {
            BackgroundTransparency = (self.props.CurrentOption == Option) and 0.1 or 1;
            BackgroundColor3 = Color3.fromRGB(0, 145, 255);
            BorderSizePixel = 0;
            Font = Enum.Font.GothamBold;
            Text = Option;
            TextColor3 = Color3.fromRGB(255, 255, 255);
            TextSize = 10;
            TextXAlignment = Enum.TextXAlignment.Left;
            TextYAlignment = Enum.TextYAlignment.Center;
            ZIndex = 3;
            [Roact.Event.MouseEnter] = function (rbx)
                rbx.BackgroundTransparency = 0.2
            end;
            [Roact.Event.InputEnded] = function (rbx)
                rbx.BackgroundTransparency = (self.props.CurrentOption == Option) and 0.1 or 1
            end;
            [Roact.Event.Activated] = function (rbx)
                self:setState({
                    AreOptionsVisible = false;
                })
                self.props.OnOptionSelected(Option)
            end;
        }, {
            Padding = new('UIPadding', {
                PaddingLeft = UDim.new(0, 6);
                PaddingRight = UDim.new(0, 6);
            });
            Corners = new('UICorner', {
                CornerRadius = UDim.new(0, 4);
            });
        }))
    end
    return List
end

function Dropdown:render()
    return new('ImageButton', {
        BackgroundColor3 = Color3.fromRGB(0, 0, 0);
        BackgroundTransparency = 0.3;
        BorderSizePixel = 0;
        Position = self.props.Position;
        Size = self.props.Size;
        Image = '';
        [Roact.Change.AbsoluteSize] = function (rbx)
            self.SetSize(rbx.AbsoluteSize)
        end;
        [Roact.Event.Activated] = function (rbx)
            self:setState({
                AreOptionsVisible = not self.state.AreOptionsVisible;
            })
        end;
    }, {
        Corners = new('UICorner', {
            CornerRadius = UDim.new(0, 4);
        });
        CurrentOption = new('TextLabel', {
            BackgroundTransparency = 1;
            Font = Enum.Font.GothamBold;
            Text = self.props.CurrentOption or '*';
            TextColor3 = Color3.fromRGB(255, 255, 255);
            TextSize = 10;
            TextXAlignment = Enum.TextXAlignment.Left;
            TextYAlignment = Enum.TextYAlignment.Center;
            Position = UDim2.new(0, 6, 0, 0);
            Size = UDim2.new(1, -32, 1, 0);
        });
        Arrow = new('ImageLabel', {
            BackgroundTransparency = 1;
            AnchorPoint = Vector2.new(1, 0.5);
            Position = UDim2.new(1, -3, 0.5, 0);
            Size = UDim2.new(0, 20, 0, 20);
            Image = 'rbxassetid://134367382';
        });
        Options = new('Frame', {
            Visible = self.state.AreOptionsVisible;
            BackgroundColor3 = Color3.fromRGB(0, 0, 0);
            BackgroundTransparency = 0.3;
            BorderSizePixel = 0;
            Position = UDim2.new(0, 0, 1, 1);
            Size = UDim2.new(
                math.ceil(#self.props.Options / self.props.MaxRows), 0,
                (#self.props.Options > self.props.MaxRows) and self.props.MaxRows or #self.props.Options, 0
            );
            ZIndex = 2;
        }, Cryo.Dictionary.join(self:BuildButtonList(), {
            Corners = new('UICorner', {
                CornerRadius = UDim.new(0, 4);
            });
            Layout = new('UIGridLayout', {
                CellPadding = UDim2.new();
                CellSize = self.Size:map(function (Size)
                    return UDim2.fromOffset(Size.X, Size.Y)
                end);
                FillDirection = Enum.FillDirection.Vertical;
                FillDirectionMaxCells = self.props.MaxRows;
                HorizontalAlignment = Enum.HorizontalAlignment.Left;
                VerticalAlignment = Enum.VerticalAlignment.Top;
                SortOrder = Enum.SortOrder.LayoutOrder;
                StartCorner = Enum.StartCorner.TopLeft;
            });
        }));
    })
end

return Dropdown