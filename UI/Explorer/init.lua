local Root = script.Parent.Parent
local Libraries = Root:WaitForChild 'Libraries'
local UI = Root:WaitForChild 'UI'
local RunService = game:GetService 'RunService'

-- Libraries
local Support = require(Libraries:WaitForChild 'SupportLibrary')
local Roact = require(Libraries:WaitForChild 'Roact')
local Maid = require(Libraries:WaitForChild 'Maid')
local Signal = require(Libraries:WaitForChild 'Signal')

-- Roact
local new = Roact.createElement
local Frame = require(UI:WaitForChild 'Frame')
local ScrollingFrame = require(UI:WaitForChild 'ScrollingFrame')
local ImageLabel = require(UI:WaitForChild 'ImageLabel')
local ImageButton = require(UI:WaitForChild 'ImageButton')
local TextLabel = require(UI:WaitForChild 'TextLabel')
local ItemRow = require(script:WaitForChild 'ItemRow')

-- Create component
local Explorer = Roact.PureComponent:extend 'Explorer'

function Explorer:init()
    self.state = {}

    -- Update batching data
    self.UpdateQueues = {}
    self.QueueTimers = {}

    -- Item tracking data
    self.LastId = 0
    self.IdMap = {}
    self.PendingParent = {}

    -- Define item expanding function
    self._ToggleExpand = function (ItemId)
        return self:setState(function (State)
            local Item = State[ItemId]
            Item.Expanded = not Item.Expanded
            return { [ItemId] = Item }
        end)
    end
end

function Explorer:didUpdate(previousProps, previousState)

    -- Trigger a scope change if prop changes
    if previousProps.Scope ~= self.props.Scope then
        self:UpdateScope(self.props.Scope)
    end

end

function Explorer:UpdateScope(Scope)

    -- Create maid for cleanup
    self.ScopeMaid = Maid.new()

    -- Build initial tree
    spawn(function ()
        self:UpdateTree()
    end)

    -- Listen for new and removing items
    local Scope = self.props.Scope
    self.ScopeMaid.Add = Scope.DescendantAdded:Connect(function (Item)
        self:UpdateTree()
    end)
    self.ScopeMaid.Remove = Scope.DescendantRemoving:Connect(function (Item)
        self:UpdateTree()
    end)

    -- Listen for selected items
    local Selection = self.props.Selection
    self.ScopeMaid.Select = Selection.ItemsAdded:Connect(function (Items)
        self:UpdateSelection(Items)
    end)
    self.ScopeMaid.Deselect = Selection.ItemsRemoved:Connect(function (Items)
        self:UpdateSelection(Items)
    end)

end

function Explorer:didMount()

    -- Create maid for cleanup on unmount
    self.ItemMaid = Maid.new()

    -- Set scope
    self:UpdateScope(self.props.Scope)

end

function Explorer:willUnmount()

    -- Clean up resources
    self.ScopeMaid:Destroy()
    self.ItemMaid:Destroy()

end

local function IsTargetable(Item)
	return Item:IsA 'Model' or
		Item:IsA 'BasePart' or
		Item:IsA 'Tool' or
		Item:IsA 'Accessory' or
		Item:IsA 'Accoutrement'
end

function Explorer.IsItemIndexable(Item)
    return (IsTargetable(Item) and Item.ClassName ~= 'Terrain') or
        Item:IsA 'Folder'
end

function Explorer:UpdateTree()

    -- Check if queue should be executed
    if not self:ShouldExecuteQueue('Tree') then
        return
    end

    -- Track order of each item
    local OrderCounter = 0
    local IdMap = self.IdMap

    -- Perform update to state
    self:setState(function (State)
        local Changes = {}
        local Descendants = self.props.Scope:GetDescendants()
        local DescendantMap = Support.FlipTable(Descendants)

        -- Check all items in scope
        for Index, Item in ipairs(Descendants) do
            local ItemId = IdMap[Item]
            local ItemState = ItemId and State[ItemId]

            -- Update reordered items
            if ItemState then
                if ItemState.Order ~= OrderCounter then
                    ItemState = Support.CloneTable(ItemState)
                    ItemState.Order = OrderCounter
                    Changes[ItemId] = ItemState
                end
                OrderCounter = OrderCounter + 1

                -- Update parents in case scope changed
                local ParentId = self.IdMap[ItemState.Parent]
                if not self.state[ParentId] then
                    self:UpdateItemParent(Item, Changes, State)
                end

            -- Introduce new items
            elseif self:BuildItemState(Item, self.props.Scope, OrderCounter, Changes, State) then
                OrderCounter = OrderCounter + 1
            end
        end

        -- Remove old items from state
        for ItemId, Item in pairs(State) do
            local Object = Item.Instance
            if not DescendantMap[Object] then

                -- Clear state
                Changes[ItemId] = Roact.None

                -- Clear ID
                IdMap[Object] = nil

                -- Clean up resources
                self.ItemMaid[ItemId] = nil

                -- Update parent child counter
                local ParentId = Item.Parent and self.IdMap[Item.Parent]
                local ParentState = self:GetStagedItemState(ParentId, Changes, State)
                if ParentState then
                    ParentState.Children[ItemId] = nil
                    ParentState.Unlocked[ItemId] = nil
                    ParentState.IsLocked = next(ParentState.Children) and not next(ParentState.Unlocked)
                    Changes[ParentId] = ParentState
                    self:PropagateLock(ParentState, Changes, State)
                end

            end
        end

        -- Update state
        return Changes
    end)

end

function Explorer:UpdateSelection(Items)
    local Selection = self.props.Selection

    -- Queue changed items
    self:QueueUpdate('Selection', Items)

    -- Check if queue should be executed
    if not self:ShouldExecuteQueue('Selection') then
        return
    end

    -- Perform updates to state
    self:setState(function (State)
        local Changes = {}
        local Queue = self:GetUpdateQueue('Selection')
        for Items in pairs(Queue) do
            for _, Item in ipairs(Items) do
                local ItemId = self.IdMap[Item]
                if ItemId then
                    local ItemState = Support.CloneTable(State[ItemId])
                    ItemState.Selected = Selection.IsSelected(Item)
                    Changes[ItemId] = ItemState
                end
            end
        end
        return Changes
    end)

end

function Explorer:WaitUntilRendered()

    -- Wait for state to unblock
    while self._setStateBlockedReason do
        RunService.Heartbeat:Wait()
    end

    -- Return whether component still mounted
    return (not not self._handle)

end

function Explorer:BuildItemState(Item, Scope, Order, Changes, State)
    local Parent = Item.Parent
    local ParentId = self.IdMap[Parent]

    -- Check if indexable and visible in hierarchy
    local InHierarchy = ParentId or (Parent == Scope)
    if not (self.IsItemIndexable(Item) and InHierarchy) then
        return nil
    end

    -- Assign ID
    local ItemId = self.LastId + 1
    self.LastId = ItemId
    self.IdMap[Item] = ItemId

    -- Check if item is a part
    local IsPart = Item:IsA 'BasePart'

    -- Create maid for cleanup when item is removed
    local ItemMaid = Maid.new()
    self.ItemMaid[ItemId] = ItemMaid

    -- Prepare item state
    local ItemState = {
        Id = ItemId,
        Name = Item.Name,
        IsPart = IsPart,
        IsLocked = IsPart and Item.Locked or nil,
        Class = Item.ClassName,
        Parent = Parent,
        Children = {},
        Unlocked = {},
        Order = Order,
        Expanded = nil,
        Instance = Item,
        Selected = self.props.Selection.IsSelected(Item) or nil
    }

    -- Register item state into changes
    Changes[ItemId] = ItemState

    -- Update parent children
    local ParentState = self:GetStagedItemState(ParentId, Changes, State)
    if ParentState then
        ParentState.Children[ItemId] = true
        Changes[ParentId] = ParentState
    end

    -- Update children
    for PendingChildId in pairs(self.PendingParent[Item] or {}) do
        local ChildState = self:GetStagedItemState(PendingChildId, Changes, State)
        if ChildState then
            ItemState.Children[PendingChildId] = true
            self:PropagateLock(ChildState, Changes, State)
        end
    end

    -- Propagate lock to ancestors
    self:PropagateLock(ItemState, Changes, State)

    -- Listen to name changes
    ItemMaid.Name = Item:GetPropertyChangedSignal('Name'):Connect(function ()

        -- Queue change
        self:QueueUpdate('Name', Item)

        -- Check if queue should be executed
        if not self:ShouldExecuteQueue('Name') then
            return
        end

        -- Perform updates to state
        self:setState(function (State)
            local Changes = {}
            local Queue = self:GetUpdateQueue('Name')
            for Item in pairs(Queue) do
                local ItemId = self.IdMap[Item]
                local ItemState = Support.CloneTable(State[ItemId])
                ItemState.Name = Item.Name
                Changes[ItemId] = ItemState
            end
            return Changes
        end)

    end)

    -- Listen to parent changes
    ItemMaid.Parent = Item:GetPropertyChangedSignal('Parent'):Connect(function ()
        if not Item.Parent then
            return
        end

        -- Queue change
        self:QueueUpdate('Parent', Item)

        -- Check if queue should be executed
        if not self:ShouldExecuteQueue('Parent') then
            return
        end

        -- Perform updates to state
        self:setState(function (State)
            local Changes = {}
            local Queue = self:GetUpdateQueue('Parent')
            for Item in pairs(Queue) do
                self:UpdateItemParent(Item, Changes, State)
            end
            return Changes
        end)

        -- Update tree state
        self:UpdateTree()
    end)

    -- Attach part-specific listeners
    if IsPart then
        ItemMaid.Locked = Item:GetPropertyChangedSignal('Locked'):Connect(function ()

            -- Queue change
            self:QueueUpdate('Lock', Item)

            -- Check if queue should be executed
            if not self:ShouldExecuteQueue('Lock') then
                return
            end

            -- Perform updates to state
            self:setState(function (State)
                local Changes = {}
                local Queue = self:GetUpdateQueue('Lock')
                for Item in pairs(Queue) do
                    self:UpdateItemLock(Item, Changes, State)
                end
                return Changes
            end)

        end)
    end

    -- Indicate that item state was created
    return true

end

function Explorer:QueueUpdate(Type, Item)
    self.UpdateQueues[Type] = Support.Merge(self.UpdateQueues[Type] or {}, { [Item] = true })
end

function Explorer:GetUpdateQueue(Type)

    -- Get queue
    local Queue = self.UpdateQueues[Type]
    self.UpdateQueues[Type] = nil

    -- Return queued items
    return Queue

end

function Explorer:ShouldExecuteQueue(Type)

    -- Start timer
    local CurrentTime = tick()
    self.QueueTimers[Type] = CurrentTime

    -- Continue if no new changes occur after delay
    wait(0.025)
    if self.QueueTimers[Type] ~= CurrentTime then
        return
    end

    -- Clear timer
    self.QueueTimers[Type] = nil

    -- Wait until state updatable
    if not self:WaitUntilRendered() then
        return
    end

    -- Continue executing queue
    return true

end

function Explorer:UpdateItemLock(Item, Changes, State)

    -- Get staged item state
    local ItemId = self.IdMap[Item]
    local ItemState = self:GetStagedItemState(ItemId, Changes, State)
    if not ItemState then
        return
    end

    -- Update state
    ItemState.IsLocked = Item.Locked
    Changes[ItemId] = ItemState

    -- Propagate lock state up hierarchy
    self:PropagateLock(ItemState, Changes, State)

end

function Explorer:GetStagedItemState(ItemId, Changes, State)

    -- Check if item staged yet
    local StagedItemState = ItemId and Changes[ItemId]

    -- Ensure item still exists
    if not ItemId or (StagedItemState == Roact.None) then
        return
    end

    -- Return staged item state
    return StagedItemState or Support.CloneTable(State[ItemId])

end

function Explorer:UpdateItemParent(Item, Changes, State)

    -- Get staged item state
    local ItemId = self.IdMap[Item]
    local ItemState = self:GetStagedItemState(ItemId, Changes, State)
    if not ItemState then
        return
    end

    -- Get current parent ID
    local PreviousParentId = ItemState.Parent and self.IdMap[ItemState.Parent]

    -- Set new parent ID
    local Parent = Item.Parent
    local ParentId = self.IdMap[Parent]
    ItemState.Parent = Parent
    Changes[ItemId] = ItemState

    -- Queue parenting if parent item valid, but not yet registered
    if not ParentId and not (Parent == Scope) then
        if Parent:IsDescendantOf(Scope) then
            self.PendingParent[Parent] = Support.Merge(self.PendingParent[Parent] or {}, { [ItemId] = true })
        end
    end

    -- Update previous parent
    local PreviousParentState = self:GetStagedItemState(PreviousParentId, Changes, State)
    if PreviousParentState then
        PreviousParentState.Children[ItemId] = nil
        PreviousParentState.Unlocked[ItemId] = nil
        PreviousParentState.IsLocked = next(PreviousParentState.Children) and not next(PreviousParentState.Unlocked)
        Changes[PreviousParentId] = PreviousParentState
    end

    -- Update new parent
    local ParentState = self:GetStagedItemState(ParentId, Changes, State)
    if ParentState then
        ParentState.Children[ItemId] = true
        Changes[ParentId] = ParentState
        self:PropagateLock(ItemState, Changes, State)
    end

end

function Explorer:PropagateLock(ItemState, Changes, State)

    -- Continue if upward propagation is possible
    if not ItemState.Parent then
        return
    end

    -- Start propagation from changed item
    local ItemId = ItemState.Id
    local ItemState = ItemState

    -- Get item's parent state
    repeat
        local Parent = ItemState.Parent
        local ParentId = Parent and self.IdMap[Parent]
        local ParentState = self:GetStagedItemState(ParentId, Changes, State)
        if ParentState then

            -- Update parent lock state
            ParentState.Unlocked[ItemId] = (not ItemState.IsLocked) and true or nil
            ParentState.IsLocked = next(ParentState.Children) and not next(ParentState.Unlocked)
            Changes[ParentId] = ParentState

            -- Continue propagation upwards in the hierarchy
            ItemId = ParentId
            ItemState = ParentState

        -- Stop propagation if parent being removed
        else
            ItemId = nil
            ItemState = nil
        end


    -- Stop at highest reachable point in hierarchy
    until
        not ItemState
end

function Explorer:render()
    local props = self.props
    local state = self.state

    -- Declare a button for each item
    local ItemList = {}
    for Key, Item in pairs(state) do

        -- Get item parent state
        local ParentId = Item.Parent and self.IdMap[Item.Parent]
        local ParentState = ParentId and state[ParentId]

        -- Determine visibility and depth from ancestors
        local Visible = true
        local Depth = 0
        if ParentId then
            local ParentState = ParentState
            while ParentState do

                -- Stop if ancestor not visible
                if not ParentState.Expanded then
                    Visible = false
                    break

                -- Count visible ancestors
                else
                    Depth = Depth + 1
                end

                -- Check next ancestor
                local ParentId = self.IdMap[ParentState.Parent]
                ParentState = state[ParentId]

            end
        end

        -- Declare component for item
        ItemList[Key] = Visible and new(ItemRow, Support.Merge({}, Item, {
            Depth = Depth,
            Selection = props.Selection,
            History = props.History,
            SyncAPI = props.SyncAPI,
            ToggleExpand = self._ToggleExpand
        }))

    end

    -- Display window
    return new(ImageLabel, {
        Active = true,
        Draggable = true,
        Layout = 'List',
        LayoutDirection = 'Vertical',
        Position = UDim2.new(1054/1366, 0, 140/669, 0),
        Width = UDim.new(185/1366),
        Height = 'WRAP_CONTENT',
        Image = 'rbxassetid://2244248341',
        ScaleType = 'Slice',
        SliceCenter = Rect.new(4, 4, 12, 12),
        ImageTransparency = 1 - 0.93,
        ImageColor = '3B3B3B'
    },
    {
        -- Window header
        Header = new(TextLabel, {
            Text = '  EXPLORER',
            TextSize = 9,
            Height = UDim.new(0, 14),
            TextColor = 'FFFFFF',
            TextTransparency = 1 - 0.6/2
        },
        {
            CloseButton = new(ImageButton, {
                Image = 'rbxassetid://2244452978',
                ImageRectOffset = Vector2.new(0, 0),
                ImageRectSize = Vector2.new(14, 14) * 2,
                AspectRatio = 1,
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, 0, 0.5, 0),
                ImageTransparency = 1 - 0.34,
                [Roact.Event.Activated] = props.Close
            })
        }),

        -- Scrollable item list
        ItemList = new(ScrollingFrame, {
            Layout = 'List',
            LayoutDirection = 'Vertical',
            Size = UDim2.new(1, 0, 0, 0),
            CanvasHeight = 'WRAP_CONTENT',
            Height = 'WRAP_CONTENT',
            ScrollBarThickness = 2,
            ScrollBarImageTransparency = 0.6,
            VerticalScrollBarInset = 'ScrollBar',
            [Roact.Children] = Support.Merge(ItemList, {
                SizeConstraint = new('UISizeConstraint', {
                    MinSize = Vector2.new(0, 20),
                    MaxSize = Vector2.new(math.huge, 300)
                })
            })
        })
    })
end

return Explorer