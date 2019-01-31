local Root = script.Parent.Parent.Parent
local Vendor = Root:WaitForChild 'Vendor'
local UI = Root:WaitForChild 'UI'

-- Libraries
local Roact = require(Vendor:WaitForChild 'Roact')
local RoactRodux = require(Vendor:WaitForChild 'RoactRodux')

-- Roact
local new = Roact.createElement
local ImageLabel = require(UI:WaitForChild 'ImageLabel')
local TextLabel = require(UI:WaitForChild 'TextLabel')
local ToolHUD = require(UI:WaitForChild 'ToolHUD')
local ConstraintSelector = require(script:WaitForChild 'ConstraintSelector')

local function ConstraintsHUD(props)
    return new(ToolHUD, {
        Color = props.Color,
        Width = UDim.new(0, props.Mode == 'SelectConstraintType' and 205 or 172),
        Label = 'Constraints'
    },
    {
        ConstraintSelector = new(ConstraintSelector)
    })
end

local function MapStateToProps(state, ownProps)
    return {
        Mode = state.Mode
    }
end

return RoactRodux.connect(MapStateToProps)(ConstraintsHUD)