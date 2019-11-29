local Root = script.Parent.Parent.Parent
local Vendor = Root:WaitForChild 'Vendor'
local Libraries = Root:WaitForChild 'Libraries'

-- Libraries
local Roact = require(Vendor:WaitForChild 'Roact')
local Maid = require(Libraries:WaitForChild 'Maid')

-- Roact
local new = Roact.createElement
local Tooltip = require(script:WaitForChild 'Tooltip')

local ModeToggle = Roact.PureComponent:extend 'ModeToggle'

function ModeToggle:init()
    self.Maid = Maid.new()

    --- Processes input, listens for hover start
    function self.OnInputBegin(rbx, Input, WasProcessed)
        if WasProcessed then
            return
        end

        -- Set hovering state
        if Input.UserInputType.Name == 'MouseMovement' then
            self:setState({
                IsHovering = true;
            })
        end
    end

    --- Processes input, listens for hover end
    function self.OnInputEnd(rbx, Input, WasProcessed)
        if Input.UserInputType.Name == 'MouseMovement' then
            self:setState({
                IsHovering = false;
            })
        end
    end

    --- Processes input, and toggles between targeting modes.
    function self.OnActivated()
        self.props.Core.Targeting:ToggleTargetingMode()
    end

    -- Set initial targeting mode
    self:setState({
        TargetingMode = self.props.Core.Targeting.TargetingMode;
        IsHovering = false;
    })
end

function ModeToggle:didMount()
    local Targeting = self.props.Core.Targeting
    self.Maid.ModeListener = Targeting.TargetingModeChanged:Connect(function (NewTargetingMode)
        self:setState({
            TargetingMode = NewTargetingMode;
        })
    end)
end

function ModeToggle:willUnmount()
    self.Maid:Destroy()
end

function ModeToggle:render()
    local IconSpritesheetPosition = (self.state.TargetingMode == 'Scoped' and 0) or
                                    (self.state.TargetingMode == 'Direct' and 14)
    return Roact.createFragment({
        ModeToggle = new('ImageButton', {
            BackgroundTransparency = 1;
            Image = 'rbxassetid://4445959523';
            ImageTransparency = 1 - (self.state.IsHovering and 0.5 or 0.2);
            ScaleType = Enum.ScaleType.Slice;
            SliceCenter = Rect.new(4, 4, 12, 12);
            ImageColor3 = Color3.fromRGB(131, 131, 131);
            Size = UDim2.new(0, 36/2, 0, 36/2);
            LayoutOrder = 0;
            [Roact.Event.Activated] = self.OnActivated;
            [Roact.Event.InputBegan] = self.OnInputBegin;
            [Roact.Event.InputEnded] = self.OnInputEnd;
        },
        {
            Icon = new('ImageLabel', {
                BackgroundTransparency = 1;
                Image = 'rbxassetid://4463020853';
                ImageTransparency = 1 - (self.state.IsHovering and 1 or 0.5);
                AnchorPoint = Vector2.new(0.5, 0.5);
                Position = UDim2.new(0.5, 0, 0.5, 0);
                Size = UDim2.new(0, 28/2, 0, 28/2);
                ImageRectOffset = Vector2.new(IconSpritesheetPosition, 0);
                ImageRectSize = Vector2.new(14, 14);
            });
            Tooltip = new(Tooltip, {
                Visible = self.state.IsHovering;
                IsToolModeEnabled = self.props.IsToolModeEnabled;
            });
        });
        ModeToggleSpacer = new('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(0, 0, 1, 0);
            LayoutOrder = 1;
        });
    })
end

return ModeToggle