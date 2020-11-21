local Root = script:FindFirstAncestorWhichIsA('Tool')
local Libraries = Root:WaitForChild('Libraries')
local Vendor = Root:WaitForChild('Vendor')

-- Libraries
local Roact = require(Vendor:WaitForChild('Roact'))
local Maid = require(Libraries:WaitForChild('Maid'))
local fastSpawn = require(Libraries:WaitForChild('fastSpawn'))

-- Roact
local new = Roact.createElement
local Slider = require(script:WaitForChild('Slider'))

-- Create component
local ColorPicker = Roact.PureComponent:extend(script.Name)

function ColorPicker:init()
    self.Maid = Maid.new()
    local InitialHue,
          InitialSaturation,
          InitialBrightness = (self.props.InitialColor or Color3.fromHSV(0, 0.5, 1)):ToHSV()
    self.HSV, self._SetHSV = Roact.createBinding({
        H = InitialHue;
        S = InitialSaturation;
        V = InitialBrightness;
    })
end

function ColorPicker:didUpdate(previousProps)
    if previousProps.InitialColor ~= self.props.InitialColor then
        local InitialHue,
            InitialSaturation,
            InitialBrightness = (self.props.InitialColor or Color3.fromHSV(0, 0.5, 1)):ToHSV()
        self._SetHSV({
            H = InitialHue;
            S = InitialSaturation;
            V = InitialBrightness;
        })
    end
end

function ColorPicker:SetHSV(HSV)
    self._SetHSV(HSV)
    if self.props.SetPreviewColor then
        fastSpawn(function ()
            self.props.SetPreviewColor(Color3.fromHSV(HSV.H, HSV.S, HSV.V))
        end)
    end
end

function ColorPicker:Finish()
    if self.props.SetPreviewColor then
        fastSpawn(function ()
            self.props.SetPreviewColor(nil)
        end)
    end
    if self.props.OnConfirm then
        local HSV = self.HSV:getValue()
        local Color = Color3.fromHSV(HSV.H, HSV.S, HSV.V)
        fastSpawn(function ()
            self.props.OnConfirm(Color)
        end)
    end
end

function ColorPicker:Cancel()
    if self.props.SetPreviewColor then
        fastSpawn(function ()
            self.props.SetPreviewColor(nil)
        end)
    end
    if self.props.OnCancel then
        fastSpawn(function ()
            self.props.OnCancel()
        end)
    end
end

function ColorPicker:render()
    return new('ScreenGui', {
        DisplayOrder = 1;
    }, {
        Dialog = new('Frame', {
            Active = true;
            Draggable = true;
            ZIndex = 0;
            AnchorPoint = Vector2.new(1, 0.5);
            Position = self.DefaultPosition or UDim2.new(1, -110, 0.5, 0);
            BackgroundTransparency = 1;
            Size = UDim2.fromOffset(240, 0);
            [Roact.Change.Position] = function (rbx)
                ColorPicker.DefaultPosition = rbx.Position
            end;
        }, {
            Layout = new('UIListLayout', {
                FillDirection = Enum.FillDirection.Vertical;
                SortOrder = Enum.SortOrder.LayoutOrder;
                [Roact.Change.AbsoluteContentSize] = function (rbx)
                    rbx.Parent.Size = UDim2.fromOffset(240, rbx.AbsoluteContentSize.Y)
                end;
            });
            Picker = new('Frame', {
                BackgroundTransparency = 1;
                BorderSizePixel = 0;
                Size = UDim2.new(1, 0, 0, 0);
                LayoutOrder = 0;
            }, {
                Layout = new('UIListLayout', {
                    Padding = UDim.new(0, 10);
                    FillDirection = Enum.FillDirection.Horizontal;
                    SortOrder = Enum.SortOrder.LayoutOrder;
                    [Roact.Change.AbsoluteContentSize] = function (rbx)
                        rbx.Parent.Size = UDim2.new(1, 0, 0, rbx.AbsoluteContentSize.Y)
                    end;
                });
                Color = new('Frame', {
                    BorderSizePixel = 0;
                    Size = UDim2.new(0.25, 0, 1, 0);
                    BackgroundColor3 = self.HSV:map(function (HSV)
                        return Color3.fromHSV(HSV.H, HSV.S, HSV.V)
                    end);
                }, {
                    Corners = new('UICorner', {
                        CornerRadius = UDim.new(0, 4);
                    });
                    AspectRatio = new('UIAspectRatioConstraint', {
                        AspectRatio = 1;
                    });
                });
                Sliders = new('Frame', {
                    Position = UDim2.new(0.25, 5, 0, 0);
                    Size = UDim2.new(0.75, 0, 0, 0);
                    BackgroundTransparency = 1;
                }, {
                    Layout = new('UIListLayout', {
                        Padding = UDim.new(0, 10);
                        FillDirection = Enum.FillDirection.Vertical;
                        HorizontalAlignment = Enum.HorizontalAlignment.Left;
                        VerticalAlignment = Enum.VerticalAlignment.Top;
                        SortOrder = Enum.SortOrder.LayoutOrder;
                        [Roact.Change.AbsoluteContentSize] = function (rbx)
                            rbx.Parent.Size = UDim2.new(0.75, 0, 0, rbx.AbsoluteContentSize.Y)
                        end;
                    });
                    HueSlider = new(Slider, {
                        Size = UDim2.new(1, 0, 0, 10);
                        BackgroundColor3 = Color3.fromRGB(255, 255, 255);
                        LayoutOrder = 0;
                        Value = self.HSV:map(function (HSV)
                            return HSV.H
                        end);
                        OnValueChanged = function (Value)
                            local HSV = self.HSV:getValue()
                            self:SetHSV({
                                H = Value;
                                S = HSV.S;
                                V = HSV.V;
                            })
                        end;
                    }, {
                        Gradient = new('UIGradient', {
                            Color = self.HSV:map(function (HSV)
                                return ColorSequence.new({
                                    ColorSequenceKeypoint.new(0/6, Color3.fromHSV(0/6, HSV.S, HSV.V));
                                    ColorSequenceKeypoint.new(1/6, Color3.fromHSV(1/6, HSV.S, HSV.V));
                                    ColorSequenceKeypoint.new(2/6, Color3.fromHSV(2/6, HSV.S, HSV.V));
                                    ColorSequenceKeypoint.new(3/6, Color3.fromHSV(3/6, HSV.S, HSV.V));
                                    ColorSequenceKeypoint.new(4/6, Color3.fromHSV(4/6, HSV.S, HSV.V));
                                    ColorSequenceKeypoint.new(5/6, Color3.fromHSV(5/6, HSV.S, HSV.V));
                                    ColorSequenceKeypoint.new(6/6, Color3.fromHSV(6/6, HSV.S, HSV.V));
                                })
                            end);
                        });
                    });
                    SaturationSlider = new(Slider, {
                        Size = UDim2.new(1, 0, 0, 10);
                        BackgroundColor3 = Color3.fromRGB(255, 255, 255);
                        LayoutOrder = 1;
                        Value = self.HSV:map(function (HSV)
                            return HSV.S
                        end);
                        OnValueChanged = function (Value)
                            local HSV = self.HSV:getValue()
                            self:SetHSV({
                                H = HSV.H;
                                S = Value;
                                V = HSV.V;
                            })
                        end;
                    }, {
                        Gradient = new('UIGradient', {
                            Color = self.HSV:map(function (HSV)
                                return ColorSequence.new(
                                    Color3.fromHSV(HSV.H, 0, HSV.V),
                                    Color3.fromHSV(HSV.H, 1, HSV.V)
                                )
                            end);
                        });
                    });
                    BrightnessSlider = new(Slider, {
                        Size = UDim2.new(1, 0, 0, 10);
                        BackgroundColor3 = Color3.fromRGB(255, 255, 255);
                        LayoutOrder = 2;
                        Value = self.HSV:map(function (HSV)
                            return HSV.V
                        end);
                        OnValueChanged = function (Value)
                            local HSV = self.HSV:getValue()
                            self:SetHSV({
                                H = HSV.H;
                                S = HSV.S;
                                V = Value;
                            })
                        end;
                    }, {
                        Gradient = new('UIGradient', {
                            Color = self.HSV:map(function (HSV)
                                return ColorSequence.new(
                                    Color3.fromHSV(HSV.H, HSV.S, 0),
                                    Color3.fromHSV(HSV.H, HSV.S, 1)
                                )
                            end);
                        });
                    });
                });
            });
            Bottom = new('Frame', {
                BackgroundTransparency = 1;
                BorderSizePixel = 0;
                Size = UDim2.new(1, 0, 0, 34);
                LayoutOrder = 1;
            }, {
                HSVLabel = new('TextLabel', {
                    BackgroundTransparency = 1;
                    Position = UDim2.new(0, 0, 0, 7);
                    Font = Enum.Font.GothamBlack;
                    Text = 'HSV: ';
                    TextSize = 11;
                    TextColor3 = Color3.fromRGB(255, 255, 255);
                    TextStrokeTransparency = 0.95;
                    [Roact.Change.TextBounds] = function (rbx)
                        rbx.Size = UDim2.fromOffset(rbx.TextBounds.X, rbx.TextBounds.Y)
                    end;
                }, {
                    HSVInput = new('TextBox', {
                        BackgroundTransparency = 1;
                        Position = UDim2.new(1, 0, 0, 0);
                        ClearTextOnFocus = false;
                        Font = Enum.Font.Gotham;
                        Text = self.HSV:map(function (HSV)
                            local Hue = tostring(math.floor(HSV.H * 360)) .. '°'
                            local Saturation = tostring(math.floor(HSV.S * 100)) .. '%'
                            local Brightness = tostring(math.floor(HSV.V * 100)) .. '%'
                            return Hue .. ', ' .. Saturation .. ', ' .. Brightness
                        end);
                        TextSize = 11;
                        TextColor3 = Color3.fromRGB(255, 255, 255);
                        TextStrokeTransparency = 0.95;
                        TextXAlignment = Enum.TextXAlignment.Left;
                        [Roact.Change.TextBounds] = function (rbx)
                            rbx.Size = UDim2.fromOffset(rbx.TextBounds.X, rbx.TextBounds.Y)
                        end;
                        [Roact.Event.FocusLost] = function (rbx)
                            local HueInput, SaturationInput, BrightnessInput = rbx.Text:match('([0-9]+)[^0-9]+([0-9]+)[^0-9]+([0-9]+)')
                            if HueInput and SaturationInput and BrightnessInput then
                                self:SetHSV({
                                    H = math.clamp(tonumber(HueInput) / 360, 0, 1);
                                    S = math.clamp(tonumber(SaturationInput) / 100, 0, 1);
                                    V = math.clamp(tonumber(BrightnessInput) / 100, 0, 1);
                                })
                            end
                        end;
                    });
                });
                RGBLabel = new('TextLabel', {
                    BackgroundTransparency = 1;
                    Position = UDim2.new(0, 0, 0, 7 + 11 + 4);
                    Font = Enum.Font.GothamBlack;
                    Text = 'RGB: ';
                    TextSize = 11;
                    TextColor3 = Color3.fromRGB(255, 255, 255);
                    TextStrokeTransparency = 0.95;
                    [Roact.Change.TextBounds] = function (rbx)
                        rbx.Size = UDim2.fromOffset(rbx.TextBounds.X, rbx.TextBounds.Y)
                    end;
                }, {
                    RGBInput = new('TextBox', {
                        BackgroundTransparency = 1;
                        Position = UDim2.new(1, 0, 0, 0);
                        ClearTextOnFocus = false;
                        Font = Enum.Font.Gotham;
                        Text = self.HSV:map(function (HSV)
                            local Color = Color3.fromHSV(HSV.H, HSV.S, HSV.V)
                            local R = tostring(math.round(Color.R * 255))
                            local G = tostring(math.round(Color.G * 255))
                            local B = tostring(math.round(Color.B * 255))
                            return R .. ', ' .. G .. ', ' .. B
                        end);
                        TextSize = 11;
                        TextColor3 = Color3.fromRGB(255, 255, 255);
                        TextStrokeTransparency = 0.95;
                        TextXAlignment = Enum.TextXAlignment.Left;
                        [Roact.Change.TextBounds] = function (rbx)
                            rbx.Size = UDim2.fromOffset(rbx.TextBounds.X, rbx.TextBounds.Y)
                        end;
                        [Roact.Event.FocusLost] = function (rbx)
                            local RInput, GInput, BInput = rbx.Text:match('([0-9]+)[^0-9]+([0-9]+)[^0-9]+([0-9]+)')
                            if RInput and GInput and BInput then
                                local Color = Color3.fromRGB(
                                    math.clamp(tonumber(RInput), 0, 255),
                                    math.clamp(tonumber(GInput), 0, 255),
                                    math.clamp(tonumber(BInput), 0, 255)
                                )
                                local H, S, V = Color:ToHSV()
                                self:SetHSV({
                                    H = H;
                                    S = S;
                                    V = V;
                                })
                            end
                        end;
                    });
                });

                ConfirmButton = new('ImageButton', {
                    BackgroundTransparency = 1;
                    Size = UDim2.new(0, 23, 0, 23);
                    Position = UDim2.new(1, 0, 1, 0);
                    AnchorPoint = Vector2.new(1, 1);
                    Image = 'rbxassetid://2132729935';
                    ScaleType = Enum.ScaleType.Slice;
                    SliceCenter = Rect.new(8, 8, 34, 34);
                    SliceScale = 0.5;
                    [Roact.Event.Activated] = function (rbx)
                        self:Finish()
                    end;
                }, {
                    Label = new('TextLabel', {
                        BackgroundTransparency = 1;
                        Size = UDim2.new(1, 0, 1, 0);
                        Text = '✔';
                        Font = Enum.Font.GothamSemibold;
                        TextSize = 12;
                        TextColor3 = Color3.fromRGB(0, 0, 0);
                    });
                });
                CancelButton = new('ImageButton', {
                    BackgroundTransparency = 1;
                    Size = UDim2.new(0, 25, 0, 23);
                    Position = UDim2.new(1, -30, 1, 0);
                    AnchorPoint = Vector2.new(1, 1);
                    Image = 'rbxassetid://2218340938';
                    ScaleType = Enum.ScaleType.Slice;
                    SliceCenter = Rect.new(8, 8, 34, 34);
                    SliceScale = 0.5;
                    [Roact.Event.Activated] = function (rbx)
                        self:Cancel()
                    end;
                }, {
                    Label = new('TextLabel', {
                        BackgroundTransparency = 1;
                        Size = UDim2.new(1, 0, 1, 0);
                        Text = 'Cancel';
                        Font = Enum.Font.GothamSemibold;
                        TextColor3 = Color3.fromRGB(255, 255, 255);
                        TextSize = 12;
                        TextStrokeTransparency = 0.95;
                        [Roact.Change.TextBounds] = function (rbx)
                            rbx.Parent.Size = UDim2.new(0, rbx.TextBounds.X + 10, 0, 23);
                        end;
                    });
                });
            });
        })
    })
end

return ColorPicker