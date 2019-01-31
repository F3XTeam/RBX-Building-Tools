local Root = script.Parent.Parent.Parent.Parent.Parent
local Vendor = Root:WaitForChild 'Vendor'
local UI = Root:WaitForChild 'UI'

-- Libraries
local Roact = require(Vendor:WaitForChild 'Roact')
local RoactRodux = require(Vendor:WaitForChild 'RoactRodux')

-- Roact
local new = Roact.createElement
local InstanceIcon = require(UI:WaitForChild 'InstanceIcon')
local OptionButton = require(script.Parent.Parent:WaitForChild 'OptionButton')

-- Create component
local ConstraintTypeButton = Roact.PureComponent:extend 'ConstraintTypeButton'

function ConstraintTypeButton:init()
    function self.OnActivated()
        self.props.SetConstraintType(self.props.ClassName)
    end
end

function ConstraintTypeButton:render()
    local props = self.props

    return new(OptionButton, {
        Label = props.Label,
        LayoutOrder = props.LayoutOrder,
        Selected = (props.SelectedConstraintType == props.ClassName),
        OnActivated = self.OnActivated,
        ClassName = props.ClassName
    },
    {
        Icon = new(InstanceIcon, {
            ClassName = props.ClassName,
            Size = UDim2.new(0, 16, 0, 16),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, 0)
        })
    })
end

local function MapStateToProps(state, ownProps)
    return {
        SelectedConstraintType = state.ConstraintType,
    }
end

local function MapDispatchToProps(dispatch)
    return {
        SetConstraintType = function (ConstraintType)
            dispatch({
                type = 'SetConstraintType',
                ConstraintType = ConstraintType
            })
        end
    }
end

return RoactRodux.connect(MapStateToProps, MapDispatchToProps)(ConstraintTypeButton)