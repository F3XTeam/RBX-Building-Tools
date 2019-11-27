local Root = script.Parent.Parent.Parent
local Libraries = Root:WaitForChild 'Libraries'
local Vendor = Root:WaitForChild 'Vendor'
local UI = Root:WaitForChild 'UI'
local RunService = game:GetService 'RunService'

-- Libraries
local Support = require(Libraries:WaitForChild 'SupportLibrary')
local Roact = require(Vendor:WaitForChild 'Roact')
local Maid = require(Libraries:WaitForChild 'Maid')

-- Roact
local new = Roact.createElement
local Frame = require(UI:WaitForChild 'Frame')
local ScrollingFrame = require(UI:WaitForChild 'ScrollingFrame')
local ItemRow = require(script.Parent:WaitForChild 'ItemRow')

-- Create component
local ItemList = Roact.Component:extend 'ItemList'
ItemList.defaultProps = {
    MaxHeight = 300
}

function ItemList:init(props)
    self:setState {
        Min = 0,
        Max = props.MaxHeight,
        CanvasPosition = Vector2.new()
    }

    -- Create callback for updating canvas boundaries
    self.UpdateBoundaries = function (rbx)
        if self.Mounted then
            self:setState {
                CanvasPosition = rbx.CanvasPosition,
                Min = rbx.CanvasPosition.Y - rbx.AbsoluteSize.Y,
                Max = rbx.CanvasPosition.Y + rbx.AbsoluteSize.Y
            }
        end
    end
end

function ItemList:didMount()
    self.Mounted = true
end

function ItemList:willUnmount()
    self.Mounted = false
end

function ItemList:didUpdate(previousProps, previousState)
    local IsScrollTargetSet = self.props.ScrollTo and
        (previousProps.ScrollTo ~= self.props.ScrollTo)

    -- Reset canvas position whenever scope updates (unless a scrolling target is set)
    if (previousProps.Scope ~= self.props.Scope) and (not IsScrollTargetSet) then
        self:setState({
            CanvasPosition = Vector2.new(0, 0);
            Min = 0;
            Max = self.props.MaxHeight;
        })
    end
end

function ItemList:render()
    local props = self.props
    local state = self.state

    -- Keep track of how many items are out of view
    local SkippedAbove = 0
    local SkippedBelow = 0
    local TargetCanvasPosition

    -- Declare a button for each item
    local ItemList = {}
    local VisibleItemCount = 0
    local ItemHeight = props.RowHeight

    -- Go through each item in order
    local OrderedItems = Support.Values(props.Items)
    table.sort(OrderedItems, function (A, B)
        return A.Order < B.Order
    end)
    for i = 1, #OrderedItems do
        local Item = OrderedItems[i]

        -- Get item parent state
        local ParentId = Item.Parent and props.IdMap[Item.Parent]
        local ParentState = ParentId and props.Items[ParentId]

        -- Determine visibility and depth from ancestors
        local Visible = true
        local Depth = 0
        if ParentId then
            local ParentState = ParentState
            while ParentState do

                -- Stop if ancestor not visible
                if not ParentState.Expanded then
                    Visible = nil
                    break

                -- Count visible ancestors
                else
                    Depth = Depth + 1
                end

                -- Check next ancestor
                local ParentId = props.IdMap[ParentState.Parent]
                ParentState = props.Items[ParentId]

            end
        end

        -- Set canvas position to begin at item if requested and out-of-view
        if (Item.Id == props.ScrollTo) and (self.ScrolledTo ~= props.ScrollTo) then
            local ItemPosition = VisibleItemCount * props.RowHeight
            if ItemPosition < state.CanvasPosition.Y or
               ItemPosition > (state.CanvasPosition.Y + props.MaxHeight) then
                TargetCanvasPosition = Vector2.new(0, ItemPosition)
                self.ScrolledTo = Item.Id
            end
        end

        -- Calculate whether item is in view
        if Visible then
            VisibleItemCount = VisibleItemCount + 1
            local ItemTop = (VisibleItemCount - 1) * props.RowHeight
            if ItemTop < state.Min then
                SkippedAbove = SkippedAbove + 1
                Visible = nil
            elseif ItemTop > state.Max then
                SkippedBelow = SkippedBelow + 1
                Visible = nil
            end
        end

        -- Declare component for item
        ItemList[Item.Id] = Visible and new(ItemRow, Support.Merge({}, Item, {
            Depth = Depth,
            Core = props.Core,
            ToggleExpand = props.ToggleExpand,
            Height = props.RowHeight
        }))
    end

    return new(ScrollingFrame, {
        Layout = 'List',
        LayoutDirection = 'Vertical',
        CanvasSize = UDim2.new(1, -2, 0, VisibleItemCount * props.RowHeight),
        Size = UDim2.new(1, 0, 0, VisibleItemCount * props.RowHeight),
        CanvasPosition = TargetCanvasPosition or state.CanvasPosition,
        ScrollBarThickness = 4,
        ScrollBarImageTransparency = 0.6,
        VerticalScrollBarInset = 'ScrollBar',
        [Roact.Change.CanvasPosition] = self.UpdateBoundaries,
        [Roact.Children] = Support.Merge(ItemList, {
            TopSpacer = new(Frame, {
                Size = UDim2.new(0, 0, 0, SkippedAbove * props.RowHeight),
                LayoutOrder = 0
            }),
            BottomSpacer = new(Frame, {
                Size = UDim2.new(0, 0, 0, SkippedBelow * props.RowHeight),
                LayoutOrder = #OrderedItems + 1
            }),
            SizeConstraint = new('UISizeConstraint', {
                MinSize = Vector2.new(0, 20),
                MaxSize = Vector2.new(math.huge, props.MaxHeight)
            })
        })
    })
end

return ItemList