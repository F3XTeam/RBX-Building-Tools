local Root = script.Parent.Parent
local Vendor = Root:WaitForChild 'Vendor'

-- API
local Core = require(Root:WaitForChild 'Core')

-- Libraries
local Roact = require(Vendor:WaitForChild 'Roact')
local RoactRodux = require(Vendor:WaitForChild 'RoactRodux')

-- Initialize tool
local ConstraintsTool = {
    Name = 'Constraints',
    Color = BrickColor.new 'Really black',
    Store = require(script:WaitForChild 'ConfigStore')
}

function ConstraintsTool:Equip()
    self:ShowHUD()
end

function ConstraintsTool:Unequip()
    self:HideHUD()
end

function ConstraintsTool:ShowHUD()

    -- Ensure UI isn't already visible
    if self.HUDHandle then
        return
    end

    -- Create UI
    local Template = require(script:WaitForChild 'HUD')
    local UI = Roact.createElement(RoactRodux.StoreProvider, {
        store = self.Store
    },
    {
        UI = Roact.createElement(Template, { 
            Color = self.Color.Color
        })
    })

    -- Mount and save handle
    self.HUDHandle = Roact.mount(UI, Core.UI, 'ConstraintsHUD')

end

function ConstraintsTool:HideHUD()

    -- Unmount current UI if any
    if self.HUDHandle then
        self.HUDHandle = Roact.unmount(self.HUDHandle)
    end

end

return ConstraintsTool