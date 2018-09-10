local Root = script.Parent.Parent
local Libraries = Root:WaitForChild 'Libraries'

-- Libraries
local Support = require(Libraries:WaitForChild 'SupportLibrary')

-- Roact
local Roact = require(Libraries:WaitForChild 'Roact')
local new = Roact.createElement

-- Create component
local ImageLabel = Roact.PureComponent:extend 'ImageLabel'

-- Set defaults
ImageLabel.defaultProps = {
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 1, 0),
    Image = ''
}

function ImageLabel:render()
    local props = Support.CloneTable(self.props)
    local state = self.state

    -- Include aspect ratio constraint if specified
    if props.AspectRatio then
        local Constraint = new('UIAspectRatioConstraint', {
            AspectRatio = props.AspectRatio
        })

        -- Insert constraint into children
        props[Roact.Children] = Support.Merge(
            { AspectRatio = Constraint },
            props[Roact.Children] or {}
        )
    end

    -- Include list layout if specified
    if props.Layout == 'List' then

        -- Determine dynamic dimensions
        local DynamicWidth = props.Size == 'WRAP_CONTENT' or
            props.Width == 'WRAP_CONTENT'
        local DynamicHeight = props.Size == 'WRAP_CONTENT' or
            props.Height == 'WRAP_CONTENT'
        local DynamicSize = DynamicWidth or DynamicHeight
        local SizeCallback = DynamicSize and function (rbx)
            self:SetContentSize(rbx.AbsoluteContentSize)
        end

        -- Create layout
        local Layout = new('UIListLayout', {
            FillDirection = props.LayoutDirection,
            Padding = props.LayoutPadding,
            HorizontalAlignment = props.HorizontalAlignment,
            VerticalAlignment = props.VerticalAlignment,
            SortOrder = props.SortOrder or 'LayoutOrder',
            [Roact.Change.AbsoluteContentSize] = SizeCallback or nil
        })

        -- Update size based on content if dynamic
        local ContentSize = state.ContentSize
        if DynamicSize and ContentSize then
            props.Size = UDim2.new(
                DynamicWidth and UDim.new(0, ContentSize.X) or
                    (props.Width or self.props.Size.X),
                DynamicHeight and UDim.new(0, ContentSize.Y) or
                    (props.Height or self.props.Size.Y)
            )
        end

        -- Insert layout into children
        props[Roact.Children] = Support.Merge(
            { Layout = Layout },
            props[Roact.Children] or {}
        )
    end

    -- Parse hex colors
    if type(props.ImageColor) == 'string' then
        local R, G, B = props.ImageColor:lower():match('#?(..)(..)(..)')
        props.ImageColor3 = Color3.fromRGB(tonumber(R, 16), tonumber(G, 16), tonumber(B, 16))
    end

    -- Filter out custom properties
    props.AspectRatio = nil
    props.Layout = nil
    props.LayoutDirection = nil
    props.LayoutPadding = nil
    props.HorizontalAlignment = nil
    props.VerticalAlignment = nil
    props.SortOrder = nil
    props.Width = nil
    props.Height = nil
    props.ImageColor = nil

    -- Display component in wrapper
    return new('ImageLabel', props)

end

function ImageLabel:SetContentSize(ContentSize)
    self:setState { ContentSize = ContentSize }
end

return ImageLabel