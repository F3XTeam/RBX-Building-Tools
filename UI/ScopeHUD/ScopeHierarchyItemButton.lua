local Root = script.Parent.Parent.Parent
local Libraries = Root:WaitForChild 'Libraries'
local Vendor = Root:WaitForChild 'Vendor'
local TextService = game:GetService('TextService')

-- Libraries
local Roact = require(Vendor:WaitForChild 'Roact')
local Maid = require(Libraries:WaitForChild 'Maid')

-- Roact
local new = Roact.createElement
local HotkeyTooltip = require(script.Parent:WaitForChild 'HotkeyTooltip')

-- Create component
local ScopeHierarchyItemButton = Roact.PureComponent:extend 'ScopeHierarchyItemButton'

--- Creates callbacks and sets up initial state.
function ScopeHierarchyItemButton:init()
    self.Maid = Maid.new()
    self.LayoutRef = Roact.createRef()
    self.ContainerSize, self.UpdateContainerSize = Roact.createBinding(UDim2.new(0, 0, 1, 0))

    --- Processes clicks, triggers scope change
    function self.OnClicked()
        self.props.SetScopeFromButton(self.props.Instance)
    end

    -- Set initial state
    self:UpdateInstanceState()
end

local ClassIconPositions = {
    Part = Vector2.new(2, 1);
    MeshPart = Vector2.new(4, 8);
    UnionOperation = Vector2.new(4, 8);
    NegateOperation = Vector2.new(3, 8);
    VehicleSeat = Vector2.new(6, 4);
    Seat = Vector2.new(6, 4);
    TrussPart = Vector2.new(2, 1);
    CornerWedgePart = Vector2.new(2, 1);
    WedgePart = Vector2.new(2, 1);
    SpawnLocation = Vector2.new(6, 3);
    Model = Vector2.new(3, 1);
    Folder = Vector2.new(8, 8);
    Tool = Vector2.new(8, 2);
    Workspace = Vector2.new(10, 2);
    Accessory = Vector2.new(3, 4);
    Accoutrement = Vector2.new(3, 4);
}

--- Updates the current instance state.
function ScopeHierarchyItemButton:UpdateInstanceState()
    local NewName = self.props.Instance.Name
    local MaxTextBounds = Vector2.new(math.huge, math.huge)
    local TextBounds = TextService:GetTextSize(NewName, 33/2, Enum.Font.SourceSans, MaxTextBounds)

    -- Update instance state
    self:setState({
        InstanceName = NewName;
        InstanceNameLength = TextBounds.X;
    })
end

--- Begins listening to the current instance.
function ScopeHierarchyItemButton:StartTrackingInstance()
    local NameChanged = self.props.Instance:GetPropertyChangedSignal('Name')
    self.Maid.NameListener = NameChanged:Connect(function ()
        self:UpdateInstanceState()
    end)
end

--- Update instance state and track changes.
function ScopeHierarchyItemButton:didMount()
    self:UpdateInstanceState()
    self:StartTrackingInstance()

    -- Set up content size listener
    if self.LayoutRef.current then
        local Layout = self.LayoutRef.current
        local LayoutChanged = Layout:GetPropertyChangedSignal('AbsoluteContentSize')
        self.UpdateContainerSize(UDim2.new(0, Layout.AbsoluteContentSize.X, 0, 38/2))
        self.Maid.LayoutListener = LayoutChanged:Connect(function ()
            self.UpdateContainerSize(UDim2.new(0, Layout.AbsoluteContentSize.X, 0, 38/2))
        end)
    end
end

--- Cleans up tracking resources.
function ScopeHierarchyItemButton:willUnmount()
    self.Maid:Destroy()
end

--- Updates state and tracking resources for new instances.
function ScopeHierarchyItemButton:didUpdate(previousProps, previousState)
    if previousProps.Instance ~= self.props.Instance then
        self:UpdateInstanceState()
        self:StartTrackingInstance()
    end
end

function ScopeHierarchyItemButton:render()
    local ClassName = self.props.Instance.ClassName
    local IconPosition = ClassIconPositions[ClassName] or Vector2.new(1, 1)
    local ShouldDisplayArrow = (self.props.LayoutOrder ~= 2) or nil

    return new('ImageButton', {
        BackgroundTransparency = 1;
        ImageTransparency = 1;
        Size = self.ContainerSize;
        LayoutOrder = self.props.LayoutOrder;
        [Roact.Event.InputBegan] = self.OnInputBegin;
        [Roact.Event.InputEnded] = self.OnInputEnd;
        [Roact.Event.Activated] = self.OnClicked;
    },
    {
        Layout = new('UIListLayout', {
            [Roact.Ref] = self.LayoutRef;
            FillDirection = Enum.FillDirection.Horizontal;
            HorizontalAlignment = Enum.HorizontalAlignment.Left;
            VerticalAlignment = Enum.VerticalAlignment.Center;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Padding = UDim.new(0, 5/2);
        });

        ArrowWrapper = ShouldDisplayArrow and new('Frame', {
            Size = UDim2.new(0, 38/2, 0, 38/2);
            BackgroundTransparency = 1;
            LayoutOrder = 0;
        },
        {
            Arrow = new('ImageLabel', {
                Size = UDim2.new(1, 0, 1, 0);
                BackgroundTransparency = 1;
                Image = 'rbxassetid://2244452978';
                ImageRectOffset = Vector2.new(14*3, 0) * 2;
                ImageRectSize = Vector2.new(14, 14) * 2;
                ImageTransparency = 0;
                Rotation = 90;
            });
        });

        InstanceInfo = new('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(0, self.state.InstanceNameLength + 28/2 + 10/2, 1, 0);
            LayoutOrder = 1;
        },
        {
            InstanceIcon = new('ImageLabel', {
                BackgroundTransparency = 1;
                Image = 'rbxassetid://2245672825';
                ImageRectOffset = (IconPosition - Vector2.new(1, 1)) * Vector2.new(16, 16);
                ImageRectSize = Vector2.new(16, 16);
                ImageTransparency = self.props.IsTarget and 0.5 or 0;
                AnchorPoint = Vector2.new(0, 0.5);
                Position = UDim2.new(0, 0, 0.5, 0);
                Size = UDim2.new(0, 28/2, 0, 28/2);
                LayoutOrder = 0;
            });
            InstanceName = new('TextLabel', {
                BackgroundTransparency = 1;
                Size = UDim2.new(0, self.state.InstanceNameLength, 0, 28/2);
                Position = UDim2.new(0, 28/2 + 10/2, 0.5, 0);
                AnchorPoint = Vector2.new(0, 0.5);
                Font = Enum.Font.SourceSans;
                TextSize = 33/2;
                Text = self.state.InstanceName;
                TextTransparency = self.props.IsTarget and 0.5 or 0;
                TextYAlignment = Enum.TextYAlignment.Center;
                TextColor3 = Color3.fromRGB(255, 255, 255);
                LayoutOrder = 1;
            },
            {
                TextShadow = new('TextLabel', {
                    BackgroundTransparency = 1;
                    Size = UDim2.new(1, 0, 1, 0);
                    Position = UDim2.new(0, 0, 0, 1);
                    Font = Enum.Font.SourceSans;
                    TextSize = 33/2;
                    Text = self.state.InstanceName;
                    TextYAlignment = Enum.TextYAlignment.Center;
                    TextColor3 = Color3.fromRGB(112, 112, 112);
                    TextStrokeColor3 = Color3.fromRGB(112, 112, 112);
                    TextTransparency = self.props.IsTarget and 1 or 0.77;
                    TextStrokeTransparency = 0.77;
                    ZIndex = 0;
                })
            });
        });

        Tooltip = new(HotkeyTooltip, {
            IsScopeParent = self.props.IsScopeParent;
            IsScope = self.props.IsScope;
            IsScopable = self.props.IsScopable;
            IsScopeLocked = self.props.IsScopeLocked;
            IsAltDown = self.props.IsAltDown;
        });
    })
end

return ScopeHierarchyItemButton