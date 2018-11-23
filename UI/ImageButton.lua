local Root = script.Parent.Parent
local Libraries = Root:WaitForChild 'Libraries'
local Vendor = Root:WaitForChild 'Vendor'

-- Libraries
local Support = require(Libraries:WaitForChild 'SupportLibrary')

-- Roact
local Roact = require(Vendor:WaitForChild 'Roact')
local new = Roact.createElement

-- Create component
local ImageButton = Roact.PureComponent:extend 'ImageButton'

-- Set defaults
ImageButton.defaultProps = {
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 1, 0),
    Image = ''
}

function ImageButton:render()
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

        -- Base height off width using the aspect ratio
        if props.DominantAxis == 'Width' then
            props.SizeConstraint = 'RelativeXX'
            if typeof(props.Width) == 'UDim' then
                props.Height = UDim.new(props.Width.Scale / props.AspectRatio, 0)
            else
                props.Size = UDim2.new(
                    props.Size.X,
                    UDim.new(props.Size.X.Scale / props.AspectRatio, 0)
                )
            end

        -- Base width off height using the aspect ratio
        elseif props.DominantAxis == 'Height' then
            props.SizeConstraint = 'RelativeYY'
            if typeof(props.Height) == 'UDim' then
                props.Width = UDim.new(props.Height.Scale * props.AspectRatio, 0)
            else
                props.Size = UDim2.new(
                    UDim.new(props.Size.Y.Scale * props.AspectRatio, 0),
                    props.Size.Y
                )
            end
        end
    end

    -- Include list layout if specified
    if props.Layout == 'List' then
        local Layout = new('UIListLayout', {
            FillDirection = props.LayoutDirection,
            Padding = props.LayoutPadding,
            HorizontalAlignment = props.HorizontalAlignment,
            VerticalAlignment = props.VerticalAlignment,
            SortOrder = props.SortOrder or 'LayoutOrder',
            [Roact.Ref] = function (rbx)
                self:UpdateContentSize(rbx)
            end,
            [Roact.Change.AbsoluteContentSize] = function (rbx)
                self:UpdateContentSize(rbx)
            end
        })

        -- Update size
        props.Size = self:GetSize()

        -- Insert layout into children
        props[Roact.Children] = Support.Merge(
            { Layout = Layout },
            props[Roact.Children]
        )
    end

    -- Parse hex colors
    if type(props.ImageColor) == 'string' then
        local R, G, B = props.ImageColor:lower():match('#?(..)(..)(..)')
        props.ImageColor3 = Color3.fromRGB(tonumber(R, 16), tonumber(G, 16), tonumber(B, 16))
    end

    -- Filter out custom properties
    props.AspectRatio = nil
    props.DominantAxis = nil
    props.Layout = nil
    props.LayoutDirection = nil
    props.LayoutPadding = nil
    props.HorizontalAlignment = nil
    props.VerticalAlignment = nil
    props.HorizontalPadding = nil
    props.VerticalPadding = nil
    props.SortOrder = nil
    props.Width = nil
    props.Height = nil
    props.ImageColor = nil

    -- Display component in wrapper
    return new('ImageButton', props)

end

function ImageButton:GetSize(ContentSize)
    local props = self.props
    
    -- Determine dynamic dimensions
    local DynamicWidth = props.Size == 'WRAP_CONTENT' or
        props.Width == 'WRAP_CONTENT'
    local DynamicHeight = props.Size == 'WRAP_CONTENT' or
        props.Height == 'WRAP_CONTENT'
    local DynamicSize = DynamicWidth or DynamicHeight

    -- Get padding from props
    local Padding = UDim2.new(
        0, props.HorizontalPadding or 0,
        0, props.VerticalPadding or 0
    )
    
    -- Calculate size based on content if dynamic
    return Padding + UDim2.new(
        (ContentSize and DynamicWidth) and UDim.new(0, ContentSize.X) or
            (typeof(props.Width) == 'UDim' and props.Width or props.Size.X),
        (ContentSize and DynamicHeight) and UDim.new(0, ContentSize.Y) or
            (typeof(props.Height) == 'UDim' and props.Height or props.Size.Y)
    )
end

function ImageButton:UpdateContentSize(Layout)
    if not (Layout and Layout.Parent) then
        return
    end

    -- Set container size based on content
    Layout.Parent.Size = self:GetSize(Layout.AbsoluteContentSize)
end

return ImageButton