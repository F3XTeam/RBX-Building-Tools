local Root = script.Parent.Parent
local Libraries = Root:WaitForChild 'Libraries'
local Vendor = Root:WaitForChild 'Vendor'
local UI = Root:WaitForChild 'UI'

-- Libraries
local Support = require(Libraries:WaitForChild 'SupportLibrary')
local Roact = require(Vendor:WaitForChild 'Roact')

-- Roact
local new = Roact.createElement
local ImageLabel = require(UI:WaitForChild 'ImageLabel')

-- Create component
local LoadingSpinner = Roact.PureComponent:extend 'LoadingSpinner'

function LoadingSpinner:init()
    self.instance = Roact.createRef()
end

function LoadingSpinner:didMount()
    coroutine.wrap(function ()
        self.Running = true
        while self.Running and self.instance.current do
            local Spinner = self.instance.current
            Spinner.Rotation = (Spinner.Rotation + 12) % 360
            wait(0.01)
        end
    end)()
end

function LoadingSpinner:willUnmount()
    self.Running = nil
end

function LoadingSpinner:render()

    -- Prepare props
    local props = Support.Merge({}, self.props or {}, {
        [Roact.Ref] = self.instance,
        Image = 'rbxassetid://1932255814',
        AspectRatio = 1
    })

    -- Display component in wrapper
    return new(ImageLabel, props)

end

return LoadingSpinner