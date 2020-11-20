local Root = script:FindFirstAncestorWhichIsA('Tool')
local Libraries = Root:WaitForChild('Libraries')
local Vendor = Root:WaitForChild('Vendor')
local UserInputService = game:GetService('UserInputService')
local ContextActionService = game:GetService('ContextActionService')

-- Libraries
local Roact = require(Vendor:WaitForChild('Roact'))
local Cryo = require(Libraries:WaitForChild('Cryo'))
local Maid = require(Libraries:WaitForChild('Maid'))
local new = Roact.createElement

-- Create component
local Slider = Roact.PureComponent:extend(script.Name)

function Slider:init()
    self.Maid = Maid.new()
end

function Slider:willUnmount()
    self.Maid:Destroy()
    ContextActionService:UnbindAction('SliderDragging')
end

function Slider:render()
    return new('ImageButton', {
        Active = false;
        Size = self.props.Size;
        BackgroundColor3 = self.props.BackgroundColor3;
        LayoutOrder = self.props.LayoutOrder;
        AutoButtonColor = false;
        BorderSizePixel = 0;
        [Roact.Event.InputBegan] = function (rbx, Input)
            if (Input.UserInputType.Name == 'MouseButton1') or
               (Input.UserInputType.Name == 'Touch') then
                self:HandleDragInput(rbx, Input)
                self:ListenToDragEvents(rbx)
            end
        end;
    }, Cryo.Dictionary.join(self.props[Roact.Children] or {}, {
        Corners = new('UICorner', {
            CornerRadius = UDim.new(0, 4);
        });
        Thumb = new('Frame', {
            AnchorPoint = Vector2.new(0.5, 0.5);
            BackgroundColor3 = Color3.fromRGB(255, 255, 255);
            BorderSizePixel = 0;
            Position = (typeof(self.props.Value) == 'number') and
                self.props.Value or
                self.props.Value:map(function (Value)
                    return UDim2.new(Value, 0, 0.5, 0)
                end);
            Size = UDim2.new(0, 4, 0, 4);
            ZIndex = 2;
        }, {
            Corners = new('UICorner', {
                CornerRadius = UDim.new(1, 0);
            });
            Shadow = new('Frame', {
                AnchorPoint = Vector2.new(0.5, 0.5);
                BackgroundColor3 = Color3.fromRGB(56, 56, 56);
                BorderSizePixel = 0;
                Position = UDim2.new(0.5, 0, 0.5, 0);
                Size = UDim2.new(0, 6, 0, 6);
            }, {
                Corners = new('UICorner', {
                    CornerRadius = UDim.new(1, 0);
                })
            });
        });
    }))
end

function Slider.IsDragInput(Input)
    return (Input.UserInputType.Name == 'MouseMovement') or
           (Input.UserInputType.Name == 'MouseButton1') or
           (Input.UserInputType.Name == 'Touch')
end

function Slider:ListenToDragEvents(SliderObject)
    local function Callback(Action, State, Input)
        return Enum.ContextActionResult.Sink
    end
    ContextActionService:BindAction('SliderDragging', Callback, false,
        Enum.UserInputType.MouseButton1,
        Enum.UserInputType.MouseMovement,
        Enum.UserInputType.Touch
    )

    self.Maid.DragChangeListener = UserInputService.InputChanged:Connect(function (Input)
        if self.IsDragInput(Input) then
            self:HandleDragInput(SliderObject, Input)
        end
    end)
    self.Maid.DragEndListener = UserInputService.InputEnded:Connect(function (Input)
        if self.IsDragInput(Input) then
            self:HandleDragInput(SliderObject, Input)
            self.Maid.DragChangeListener = nil
            self.Maid.DragEndListener = nil
            ContextActionService:UnbindAction('SliderDragging')
        end
    end)
end

function Slider:HandleDragInput(SliderObject, Input)
    local Alpha = math.clamp((Input.Position.X - SliderObject.AbsolutePosition.X) / SliderObject.AbsoluteSize.X, 0, 1)
    self.props.OnValueChanged(Alpha)
end

return Slider