local Root = script.Parent.Parent.Parent
local Libraries = Root:WaitForChild 'Libraries'
local Vendor = Root:WaitForChild 'Vendor'

-- Libraries
local Support = require(Libraries:WaitForChild 'SupportLibrary')
local Rodux = require(Vendor:WaitForChild 'Rodux')

-- Default tool configuration
local DefaultConfig = {
    ConstraintType = 'WeldConstraint',
    Mode = 'SelectConstraintType'
}

-- Create reducer for tool config actions
local Reducer = Rodux.createReducer(DefaultConfig, {
    SetConstraintType = function (State, Action)
        return Support.Merge({}, State, {
            ConstraintType = Action.ConstraintType
        })
    end
})

-- Return config store
return Rodux.Store.new(Reducer)