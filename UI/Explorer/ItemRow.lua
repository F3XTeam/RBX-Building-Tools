local Root = script.Parent.Parent.Parent
local Libraries = Root:WaitForChild 'Libraries'
local Vendor = Root:WaitForChild 'Vendor'
local UI = Root:WaitForChild 'UI'
local UserInputService = game:GetService 'UserInputService'

-- Libraries
local Support = require(Libraries:WaitForChild 'SupportLibrary')
local Roact = require(Vendor:WaitForChild 'Roact')
local Maid = require(Libraries:WaitForChild 'Maid')

-- Roact
local new = Roact.createElement
local Frame = require(UI:WaitForChild 'Frame')
local ImageLabel = require(UI:WaitForChild 'ImageLabel')
local ImageButton = require(UI:WaitForChild 'ImageButton')
local TextLabel = require(UI:WaitForChild 'TextLabel')
local TextBox = require(UI:WaitForChild 'TextBox')

-- Create component
local ItemRow = Roact.PureComponent:extend 'ItemRow'

function ItemRow:init()

    -- Item button callback
    self.OnActivated = function ()
        self:HandleSelection()
    end

    -- Expand arrow callback
    self.OnArrowActivated = function ()
        self:ToggleExpand()
    end

    -- Lock button callback
    self.OnLockActivated = function ()
        self:ToggleLock()
    end

    -- Name button callback
    self.OnNameActivated = function (rbx)
        local CurrentTime = tick()
        if self.LastNameClick and (CurrentTime - self.LastNameClick) <= 0.25 then
            self:setState { EditingName = true }
        else
            self.LastNameClick = CurrentTime
            self:HandleSelection()
        end
    end

    -- Name input callback
    self.OnNameInputBlur = function (rbx, EnterPressed)
        if #rbx.Text > 0 then
            self:SetName(rbx.Text)
        end
        self:setState { EditingName = Roact.None }
    end

end

function ItemRow:GetParts()
    local Object = self.props.Instance

    -- Return part for parts
    if Object:IsA 'BasePart' then
        return { Object }

    -- Return descendant parts for other items
    else
        local Parts = {}
        for _, Part in pairs(Object:GetDescendants()) do
            if Part:IsA 'BasePart' then
                Parts[#Parts + 1] = Part
            end
        end
        return Parts
    end
end

function ItemRow:ToggleLock()
    local props = self.props

    -- Create history record
    local Parts = self:GetParts()
    local HistoryRecord = {
        Parts = Parts,
        BeforeLocked = Support.GetListMembers(Parts, 'Locked'),
        AfterLocked = not props.IsLocked
    }

    function HistoryRecord:Unapply()
        props.Core.SyncAPI:Invoke('SetLocked', self.Parts, self.BeforeLocked)
    end

    function HistoryRecord:Apply()
        props.Core.SyncAPI:Invoke('SetLocked', self.Parts, self.AfterLocked)
    end

    -- Send lock toggling request to gameserver
    HistoryRecord:Apply()

    -- Register history record
    props.Core.History.Add(HistoryRecord)

end

function ItemRow:SetName(Name)
    local props = self.props

    -- Create history record
    local HistoryRecord = {
        Items = { props.Instance },
        BeforeName = props.Instance.Name,
        AfterName = Name
    }

    function HistoryRecord:Unapply()
        props.Core.SyncAPI:Invoke('SetName', self.Items, self.BeforeName)
    end

    function HistoryRecord:Apply()
        props.Core.SyncAPI:Invoke('SetName', self.Items, self.AfterName)
    end

    -- Send renaming request to gameserver
    HistoryRecord:Apply()

    -- Register history record
    props.Core.History.Add(HistoryRecord)

end

function ItemRow:HandleSelection()
    local props = self.props
    local Selection = props.Core.Selection
    local Targeting = props.Core.Targeting

    -- Check if scoping
    local Scoping = UserInputService:IsKeyDown 'LeftAlt' or
        UserInputService:IsKeyDown 'RightAlt'

    -- Enter scope if requested
    if Scoping then
        Targeting:SetScope(props.Instance)
        return
    end

    -- Check if multiselecting
    local Multiselecting = UserInputService:IsKeyDown 'LeftControl' or
        UserInputService:IsKeyDown 'RightControl'

    -- Perform selection
    if Multiselecting then
        if not Selection.IsSelected(props.Instance) then
            Selection.Add({ props.Instance }, true)
        else
            Selection.Remove({ props.Instance }, true)
        end
    else
        Selection.Replace({ props.Instance }, true)
    end
end

function ItemRow:ToggleExpand()
    self.props.ToggleExpand(self.props.Id)
end

function ItemRow:didMount()
    self.Maid = Maid.new()

    local Targeting = self.props.Core.Targeting
    local Item = self.props.Instance

    -- Listen for targeting
    self.Maid.TargetListener = Targeting.ScopeTargetChanged:Connect(function (ScopeTarget)
        local IsTarget = self.state.Targeted
        if (not IsTarget) and (ScopeTarget == Item) then
            self:setState { Targeted = true }
        elseif IsTarget and (ScopeTarget ~= Item) then
            self:setState { Targeted = Roact.None }
        end
    end)
end

function ItemRow:willUnmount()
    self.Maid = self.Maid:Destroy()
end

ItemRow.ClassIcons = {
    Part = Vector2.new(2, 1),
    MeshPart = Vector2.new(4, 8),
    UnionOperation = Vector2.new(4, 8),
    NegateOperation = Vector2.new(3, 8),
    VehicleSeat = Vector2.new(6, 4),
    Seat = Vector2.new(6, 4),
    TrussPart = Vector2.new(2, 1),
    CornerWedgePart = Vector2.new(2, 1),
    WedgePart = Vector2.new(2, 1),
    SpawnLocation = Vector2.new(6, 3),
    Model = Vector2.new(3, 1),
    Folder = Vector2.new(8, 8),
    Tool = Vector2.new(8, 2),
    Workspace = Vector2.new(10, 2),
    Accessory = Vector2.new(3, 4),
    Accoutrement = Vector2.new(3, 4)
}

function ItemRow:render()
    local props = self.props
    local state = self.state

    -- Determine icon for class
    local IconPosition = ItemRow.ClassIcons[props.Class] or Vector2.new(1, 1)

    -- Item information
    local Metadata = new(Frame, {
        Layout = 'List',
        LayoutDirection = 'Horizontal',
        VerticalAlignment = 'Center'
    },
    {
        StartSpacer = new(Frame, {
            AspectRatio = (5 + 10 * props.Depth) / 18,
            LayoutOrder = 0
        }),

        -- Class icon
        Icon = new(ImageLabel, {
            AspectRatio = 1,
            Image = 'rbxassetid://2245672825',
            ImageRectOffset = (IconPosition - Vector2.new(1, 1)) * Vector2.new(16, 16),
            ImageRectSize = Vector2.new(16, 16),
            Size = UDim2.new(1, 0, 12/18, 0),
            LayoutOrder = 1
        }),

        IconSpacer = new(Frame, {
            AspectRatio = 5/18,
            LayoutOrder = 2
        }),

        -- Item name
        NameContainer = new(ImageButton, {
            Layout = 'List',
            Width = 'WRAP_CONTENT',
            LayoutOrder = 3,
            [Roact.Event.Activated] = self.OnNameActivated
        },
        {
            Name = (not state.EditingName) and new(TextLabel, {
                TextSize = 13,
                TextColor = 'FFFFFF',
                Text = props.Name,
                Width = 'WRAP_CONTENT'
            }),
            NameInput = state.EditingName and new(TextBox, {
                TextSize = 13,
                TextColor = 'FFFFFF',
                Text = props.Name,
                Width = 'WRAP_CONTENT',
                [Roact.Event.FocusLost] = self.OnNameInputBlur
            })
        })
    })

    -- Item buttons
    local Buttons = new(Frame, {
        Layout = 'List',
        LayoutDirection = 'Horizontal',
        HorizontalAlignment = 'Right',
        VerticalAlignment = 'Center',
        Width = 'WRAP_CONTENT',
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0)
    },
    {
        -- Locking button
        Lock = new(ImageButton, {
            AspectRatio = 1,
            DominantAxis = 'Height',
            Image = 'rbxassetid://2244452978',
            ImageRectOffset = Vector2.new(14 * (props.IsLocked and 2 or 1), 0) * 2,
            ImageRectSize = Vector2.new(14, 14) * 2,
            Size = UDim2.new(1, 0, 12/18, 0),
            ImageTransparency = 1 - (props.IsLocked and 0.75 or 0.15),
            LayoutOrder = 0,
            [Roact.Event.Activated] = self.OnLockActivated
        }),

        Spacer = new(Frame, {
            LayoutOrder = 1,
            AspectRatio = 1/10
        }),

        -- Item expansion arrow
        ArrowWrapper = next(props.Children) and new(Frame, {
            AspectRatio = 1,
            Size = UDim2.new(1, 0, 14/18, 0),
            LayoutOrder = 2
        },
        {
            Arrow = new(ImageButton, {
                Image = 'rbxassetid://2244452978',
                ImageRectOffset = Vector2.new(14 * 3, 0) * 2,
                ImageRectSize = Vector2.new(14, 14) * 2,
                Rotation = props.Expanded and 180 or 90,
                ImageTransparency = 1 - 0.15,
                [Roact.Event.Activated] = self.OnArrowActivated
            })
        }),

        EndSpacer = new(Frame, {
            LayoutOrder = 3,
            AspectRatio = 1/20
        })
    })

    -- Determine transparency from selection and targeting state
    local Transparency = 1
    if props.Selected then
        Transparency = 1 - 0.15
    elseif state.Targeted then
        Transparency = 1 - 0.05
    end

    -- Return button with contents
    return new(ImageButton, {
        LayoutOrder = props.Order,
        Size = UDim2.new(1, 0, 0, props.Height),
        AutoButtonColor = false,
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = Transparency,
        [Roact.Event.Activated] = self.OnActivated
    },
    {
        Metadata = Metadata,
        Buttons = Buttons
    })
end

return ItemRow