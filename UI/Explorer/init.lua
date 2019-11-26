local Root = script.Parent.Parent
local Libraries = Root:WaitForChild 'Libraries'
local Vendor = Root:WaitForChild 'Vendor'
local UI = Root:WaitForChild 'UI'
local RunService = game:GetService 'RunService'

-- Libraries
local Support = require(Libraries:WaitForChild 'SupportLibrary')
local Roact = require(Vendor:WaitForChild 'Roact')
local Maid = require(Libraries:WaitForChild 'Maid')
local Signal = require(Libraries:WaitForChild 'Signal')

-- Roact
local new = Roact.createElement
local Frame = require(UI:WaitForChild 'Frame')
local ImageLabel = require(UI:WaitForChild 'ImageLabel')
local ImageButton = require(UI:WaitForChild 'ImageButton')
local TextLabel = require(UI:WaitForChild 'TextLabel')
local ItemList = require(script:WaitForChild 'ItemList')

-- Create component
local Explorer = Roact.PureComponent:extend 'Explorer'

function Explorer:init(props)
    self:setState {
        Items = {},
        RowHeight = 18
    }

    -- Update batching data
    self.UpdateQueues = {}
    self.QueueTimers = {}

    -- Item tracking data
    self.LastId = 0
    self.IdMap = {}
    self.PendingParent = {}

    -- Define item expanding function
    self.ToggleExpand = function (ItemId)
        return self:setState(function (State)
            local Item = State.Items[ItemId]
            Item.Expanded = not Item.Expanded
            return { Items = State.Items }
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
    local Core = self.props.Core
    local Selection = Core.Selection

    -- Clear previous cleanup maid
    if self.ScopeMaid then
        self.ScopeMaid:Destroy()
    end

    -- Create maid for cleanup
    self.ScopeMaid = Maid.new()

    -- Ensure new scope is defined
    if not Scope then
        return
    end

    -- Build initial tree
    coroutine.resume(coroutine.create(function ()
        self:UpdateTree()

        -- Scroll to first selected item
        if #Selection.Items > 0 then
            local FocusedItem = Selection.IsSelected(Selection.Focus) and Selection.Focus or Selection.Items[1]
            self:setState({
                ScrollTo = self.IdMap[FocusedItem]
            })
        else
            self:setState({
                ScrollTo = Roact.None
            })
        end
    end))

    -- Listen for new and removing items
    local Scope = Core.Targeting.Scope
    self.ScopeMaid.Add = Scope.DescendantAdded:Connect(function (Item)
        self:UpdateTree()
    end)
    self.ScopeMaid.Remove = Scope.DescendantRemoving:Connect(function (Item)
        self:UpdateTree()
    end)

    -- Listen for selected items
    self.ScopeMaid.Select = Selection.ItemsAdded:Connect(function (Items)
        self:UpdateSelection(Items)

        -- If single item selected, get item state
        local ItemId = (#Items == 1) and self.IdMap[Items[1]]

        -- Expand ancestors leading to item
        self:setState(function (State)
            local Changes = {}
            local ItemState = State.Items[ItemId]
            local ParentId = ItemState and self.IdMap[ItemState.Parent]
            local ParentState = ParentId and State.Items[ParentId]

            while ParentState do
                ParentState.Expanded = true
                Changes[ParentId] = ParentState
                ParentId = self.IdMap[ParentState.Parent]
                ParentState = State.Items[ParentId]
            end

            return {
                Items = Support.Merge(State.Items, Changes),
                ScrollTo = ItemId
            }
        end)
    end)
    self.ScopeMaid.Deselect = Selection.ItemsRemoved:Connect(function (Items)
        self:UpdateSelection(Items)
    end)

end

function Explorer:didMount()
    self.Mounted = true

    -- Create maid for cleanup on unmount
    self.ItemMaid = Maid.new()

    -- Set scope
    self:UpdateScope(self.props.Scope)
end

function Explorer:willUnmount()
    self.Mounted = false

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
    local OrderCounter = 1
    local IdMap = self.IdMap

    -- Perform update to state
    self:setState(function (State)
        local Changes = {}
        local Descendants = self.props.Scope:GetDescendants()
        local DescendantMap = Support.FlipTable(Descendants)

        -- Check all items in scope
        for Index, Item in ipairs(Descendants) do
            local ItemId = IdMap[Item]
            local ItemState = ItemId and State.Items[ItemId]

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
                if not State.Items[ParentId] then
                    self:UpdateItemParent(Item, Changes, State)
                end

            -- Introduce new items
            elseif self:BuildItemState(Item, self.props.Scope, OrderCounter, Changes, State) then
                OrderCounter = OrderCounter + 1
            end
        end

        -- Remove old items from state
        for ItemId, Item in pairs(State.Items) do
            local Object = Item.Instance
            if not DescendantMap[Object] then

                -- Clear state
                Changes[ItemId] = Support.Blank

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
        return { Items = Support.MergeWithBlanks(State.Items, Changes) }
    end)

end

function Explorer:UpdateSelection(Items)
    local Selection = self.props.Core.Selection

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
                    local ItemState = Support.CloneTable(State.Items[ItemId])
                    ItemState.Selected = Selection.IsSelected(Item)
                    Changes[ItemId] = ItemState
                end
            end
        end
        return { Items = Support.Merge(State.Items, Changes) }
    end)

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
        Selected = self.props.Core.Selection.IsSelected(Item) or nil
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
                local ItemState = Support.CloneTable(State.Items[ItemId])
                ItemState.Name = Item.Name
                Changes[ItemId] = ItemState
            end
            return { Items = Support.Merge(State.Items, Changes) }
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
            return { Items = Support.MergeWithBlanks(State.Items, Changes) }
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
                return { Items = Support.MergeWithBlanks(State.Items, Changes) }
            end)

        end)
    end

    -- Indicate that item state was created
    return true

end

function Explorer:QueueUpdate(Type, Item)
    self.UpdateQueues[Type] = Support.Merge(self.UpdateQueues[Type] or {}, {
        [Item] = true
    })
end

function Explorer:GetUpdateQueue(Type)

    -- Get queue
    local Queue = self.UpdateQueues[Type]
    self.UpdateQueues[Type] = nil

    -- Return queued items
    return Queue

end

function Explorer:ShouldExecuteQueue(Type)
    local ShouldExecute = self.QueueTimers[Type] or Support.CreateConsecutiveCallDeferrer(0.025)
    self.QueueTimers[Type] = ShouldExecute

    -- Wait until state updatable
    if ShouldExecute() and self.Mounted then
        return true
    end
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
    if not ItemId or (StagedItemState == Support.Blank) or
        not (StagedItemState or State.Items[ItemId]) then
        return
    end

    -- Return staged item state
    return StagedItemState or Support.CloneTable(State.Items[ItemId])

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

    -- Display window
    return new(ImageLabel, {
        Active = true,
        Layout = 'List',
        LayoutDirection = 'Vertical',
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -100, 0.6, -380/2),
        Width = UDim.new(0, 145),
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
        ItemList = new(ItemList, {
            Scope = props.Scope,
            Items = state.Items,
            ScrollTo = state.ScrollTo,
            Core = props.Core,
            IdMap = self.IdMap,
            RowHeight = state.RowHeight,
            ToggleExpand = self.ToggleExpand
        })
    })
end

return Explorer