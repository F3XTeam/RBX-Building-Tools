local Root = script.Parent.Parent
local Libraries = Root:WaitForChild 'Libraries'
local Vendor = Root:WaitForChild 'Vendor'
local TextService = game:GetService 'TextService'

-- Libraries
local Support = require(Libraries:WaitForChild 'SupportLibrary')

-- Roact
local Roact = require(Vendor:WaitForChild 'Roact')
local new = Roact.createElement

-- Create component
local TextLabel = Roact.PureComponent:extend 'TextLabel'

-- Set defaults
TextLabel.defaultProps = {
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 1, 0),
    TextSize = 16,
    Font = 'SourceSans',
    TextColor3 = Color3.new(0, 0, 0),
    TextXAlignment = 'Left'
}

-- Constants
local INFINITE_BOUNDS = Vector2.new(math.huge, math.huge)

function TextLabel:getSize()

    -- Return size directly if fixed
    if not (self.props.Width or self.props.Height or self.props.Size == 'WRAP_CONTENT') then
        return self.props.Size
    end

    -- Get fixed sizes for individual axes
    local Width, Height
    if typeof(self.props.Width) == 'UDim' then
        Width = self.props.Width
    elseif typeof(self.props.Height) == 'UDim' then
        Height = self.props.Height
    end

    -- Get text size from height if autoscaled
    local TextSize = self.props.TextSize
    if self.props.TextScaled and self.AbsoluteSize then
        TextSize = self.AbsoluteSize.Y
    end

    -- Calculate content bounds
    local Bounds = TextService:GetTextSize(
        self.props.Text,
        TextSize,
        self.props.Font,
        INFINITE_BOUNDS
    )

    -- Set width and height based on content if requested
    if not Width and (self.props.Width == 'WRAP_CONTENT' or self.props.Size == 'WRAP_CONTENT') then
        Width = UDim.new(0, Bounds.X)
    end
    if not Height and (self.props.Height == 'WRAP_CONTENT' or self.props.Size == 'WRAP_CONTENT') then
        Height = UDim.new(0, Bounds.Y)
    end

    -- Return the calculated size
    return UDim2.new(
        Width or (self.props.Size and self.props.Size.X) or UDim.new(),
        Height or (self.props.Size and self.props.Size.Y) or UDim.new()
    )

end

function TextLabel:updateSize()
    if not self.Mounted then
        return
    end

    -- Calculate new size
    local Size = self:getSize()
    local TextSize = self.props.TextScaled and
        (self.AbsoluteSize and self.AbsoluteSize.Y) or
        self.props.TextSize

    -- Check if state is outdated
    if self.state.Size ~= Size or
        self.state.TextSize ~= TextSize then

        -- Update state
        self:setState {
            Size = Size,
            TextSize = TextSize
        }
    end
end

function TextLabel:init()
    self.Updating = true
    self.state = {
        Size = UDim2.new(),
        TextSize = 0
    }
end

function TextLabel:willUpdate(nextProps, nextState)
    self.Updating = true
end

function TextLabel:render()
    local props = Support.Merge({}, self.props, {

        -- Override size
        Size = self.state.Size,
        TextSize = self.state.TextSize,
        TextScaled = false,

        -- Get initial size
        [Roact.Ref] = function (rbx)
            self.AbsoluteSize = rbx and
                rbx.AbsoluteSize or
                self.AbsoluteSize
        end,

        -- Track size changes
        [Roact.Change.AbsoluteSize] = function (rbx)
            self.AbsoluteSize = rbx.AbsoluteSize
            if not self.Updating then
                self:updateSize()
            end
        end

    })

    -- Parse hex colors
    if type(props.TextColor) == 'string' then
        local R, G, B = props.TextColor:lower():match('#?(..)(..)(..)')
        props.TextColor3 = Color3.fromRGB(tonumber(R, 16), tonumber(G, 16), tonumber(B, 16))
    end

    -- Separate children from props
    local children = Support.Merge({}, self.props[Roact.Children])

    -- Clear invalid props
    props.Width = nil
    props.Height = nil
    props.Bold = nil
    props.TextColor = nil
    props.AspectRatio = nil
    props[Roact.Children] = nil

    -- Include aspect ratio constraint if specified
    if self.props.AspectRatio then
        local Constraint = new('UIAspectRatioConstraint', {
            AspectRatio = self.props.AspectRatio
        })

        -- Insert constraint into children
        children.AspectRatio = Constraint
    end

    -- Add a bold layer if specified
    if self.props.Bold then
        local BoldProps = Support.CloneTable(props)
        BoldProps.Size = UDim2.new(1, 0, 1, 0)
        BoldProps.Position = nil
        BoldProps.TextScaled = true
        BoldProps.AnchorPoint = nil
        children.Bold = new(TextLabel, BoldProps)
    end

    -- Display component in wrapper
    return new('TextLabel', props, children)

end

function TextLabel:didMount()
    self.Updating = nil
    self.Mounted = true
    self:updateSize()
end

function TextLabel:willUnmount()
    self.Mounted = nil
end

function TextLabel:didUpdate(previousProps, previousState)
    self.Updating = nil
    self:updateSize()
end

return TextLabel