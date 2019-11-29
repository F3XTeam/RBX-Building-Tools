local Root = script.Parent.Parent
local Libraries = Root:WaitForChild 'Libraries'
local Vendor = Root:WaitForChild 'Vendor'
local Workspace = game:GetService('Workspace')
local ContextActionService = game:GetService('ContextActionService')
local UserInputService = game:GetService('UserInputService')

-- Libraries
local Roact = require(Vendor:WaitForChild 'Roact')
local Maid = require(Libraries:WaitForChild 'Maid')
local Support = require(Libraries:WaitForChild 'SupportLibrary')

-- Roact
local new = Roact.createElement
local ScopeHierarchyItemButton = require(script:WaitForChild 'ScopeHierarchyItemButton')
local HotkeyTooltip = require(script:WaitForChild 'HotkeyTooltip')
local ModeToggle = require(script:WaitForChild 'ModeToggle')

-- Create component
local ScopeHUD = Roact.PureComponent:extend 'ScopeHUD'

--- Creates callbacks and sets up initial state.
function ScopeHUD:init(props)
    self.Maid = Maid.new()
    self.LayoutRef = Roact.createRef()
    self.ContainerSize, self.UpdateContainerSize = Roact.createBinding(UDim2.new(0, 0, 0, 38/2))

    --- Processes input, listens for hover start
    function self.OnInputBegin(rbx, Input, WasProcessed)
        if WasProcessed then
            return
        end

        -- Set hovering state
        if (Input.UserInputType.Name == 'MouseMovement') or
           (Input.UserInputType.Name == 'Touch') then
            self:setState({
                IsHovering = true
            })
        end
    end

    --- Processes input, listens for hover end
    function self.OnInputEnd(rbx, Input, WasProcessed)
        if (Input.UserInputType.Name == 'MouseMovement') or
           (Input.UserInputType.Name == 'Touch') then
            self:setState({
                IsHovering = false
            })
        end
    end

    --- Processes requests from buttons to set scope
    function self.SetScopeFromButton(NewScope)
        self.props.Core.Targeting:SetScope(NewScope)
    end

    -- Set initial state
    self:UpdateTargetingState()
    self:setState({
        IsHovering = false;
        IsToolModeEnabled = (self.props.Core.Mode == 'Tool')
    })
end

--- Updates the current scope and target state.
function ScopeHUD:UpdateTargetingState()
    local Targeting = self.props.Core.Targeting
    local Scope = Targeting.Scope
    local DirectTarget, ScopeTarget = Targeting:UpdateTarget()
    return self:setState({
        Scope = Scope or Roact.None;
        ScopeTarget = ScopeTarget or Roact.None;
        DirectTarget = DirectTarget or Roact.None;
        IsScopeLocked = Targeting.IsScopeLocked;
    })
end

--- Begins tracking scope and target changes.
function ScopeHUD:didMount()
    self:UpdateTargetingState()

    -- Set up targeting change listeners
    local Targeting = self.props.Core.Targeting
    self.Maid.ScopeChangeListener = Targeting.ScopeChanged:Connect(function (Scope)
        Targeting:UpdateTarget()
        self:setState({
            Scope = Scope or Roact.None;
        })
    end)
    self.Maid.ScopeTargetChangeListener = Targeting.ScopeTargetChanged:Connect(function (ScopeTarget)
        self:setState({
            ScopeTarget = ScopeTarget or Roact.None;
        })
    end)
    self.Maid.TargetChangeListener = Targeting.TargetChanged:Connect(function (DirectTarget)
        self:setState({
            DirectTarget = DirectTarget or Roact.None;
        })
    end)
    self.Maid.ScopeLockChangeListener = Targeting.ScopeLockChanged:Connect(function (IsScopeLocked)
        self:setState({
            IsScopeLocked = IsScopeLocked;
        })
    end)

    -- Set up alt key listeners
    local function AltKeyCallback(_, State, Input)
        if State.Name == 'Begin' then
            self:setState({
                IsAltDown = true;
            })
        elseif State.Name == 'End' then
            self:setState({
                IsAltDown = false;
            })
        end
        return Enum.ContextActionResult.Pass
    end
    ContextActionService:BindAction('BT/ScopeHUD: Scope', AltKeyCallback, false,
        Enum.KeyCode.LeftAlt,
        Enum.KeyCode.RightAlt
    )

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
function ScopeHUD:willUnmount()
    self.Maid:Destroy()
end

function ScopeHUD:render()
    return new('Frame', {
        Active = true;
        Draggable = true;
        Position = self.state.IsToolModeEnabled and
            UDim2.new(0, 10/2, 1, -8/2) or
            UDim2.new(0, 10/2, 0, 8/2);
        AnchorPoint = self.state.IsToolModeEnabled and
            Vector2.new(0, 1) or
            Vector2.new(0, 0);
        Size = self.ContainerSize;
        BackgroundTransparency = 1;
        [Roact.Event.InputBegan] = self.OnInputBegin;
        [Roact.Event.InputEnded] = self.OnInputEnd;
    },
    Support.Merge(self:BuildScopeHierarchyButtons(), {
        Layout = new('UIListLayout', {
            [Roact.Ref] = self.LayoutRef;
            FillDirection = Enum.FillDirection.Horizontal;
            HorizontalAlignment = Enum.HorizontalAlignment.Left;
            VerticalAlignment = Enum.VerticalAlignment.Center;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Padding = UDim.new(0, 5/2);
        });
        ModeToggle = new(ModeToggle, {
            Core = self.props.Core;
            IsToolModeEnabled = self.state.IsToolModeEnabled;
        });
    }))
end

--- Returns whether it should be possible to scope into the given item.
-- @returns boolean
local function IsItemScopable(Item)
    return Item:IsA('Model')
        or Item:IsA('Folder')
        or Item:IsA('Tool')
        or Item:IsA('Accessory')
        or Item:IsA('Accoutrement')
        or (Item:IsA('BasePart') and Item:FindFirstChildWhichIsA('BasePart', true))
end

--- Builds and returns a button for each item in the scope hierarchy.
-- @returns ScopeHierarchyItemButton[]
function ScopeHUD:BuildScopeHierarchyButtons()
    local Hierarchy = {}
    local Buttons = {}

    -- Navigate up hierarchy from scope target
    local CurrentScopePosition = self.state.ScopeTarget or
                                 self.state.Scope
    while (CurrentScopePosition ~= nil) and
          (CurrentScopePosition ~= Workspace.Parent) do
        table.insert(Hierarchy, 1, CurrentScopePosition)
        CurrentScopePosition = CurrentScopePosition.Parent
    end

    -- Create button for each scope hierarchy item
    for Index, ScopePosition in ipairs(Hierarchy) do
        Buttons[Index] = new(ScopeHierarchyItemButton, {
            Instance = ScopePosition;
            IsTarget = (self.state.ScopeTarget == ScopePosition);
            IsScopeParent = self.state.Scope and (self.state.Scope.Parent == ScopePosition);
            IsScope = (self.state.Scope == ScopePosition);
            IsScopable = (self.state.ScopeTarget == ScopePosition) and IsItemScopable(ScopePosition);
            IsScopeLocked = self.state.IsScopeLocked;
            SetScopeFromButton = self.SetScopeFromButton;
            IsAltDown = self.state.IsAltDown;
            LayoutOrder = Index + 1;
        })
    end

    -- Add hotkey tooltip if alt not held down
    if not self.state.IsAltDown then
        Buttons[#Hierarchy + 1] = new(HotkeyTooltip, {
            IsAltDown = false;
            DisplayAltHotkey = UserInputService.KeyboardEnabled;
            LayoutOrder = #Hierarchy + 2;
        })
    end

    -- Return list of buttons
    return Buttons
end

return ScopeHUD