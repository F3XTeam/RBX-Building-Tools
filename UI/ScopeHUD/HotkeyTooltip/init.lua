local Root = script.Parent.Parent.Parent
local Vendor = Root:WaitForChild 'Vendor'
local Roact = require(Vendor:WaitForChild 'Roact')

-- Components
local ScopeOutTooltip = require(script:WaitForChild 'ScopeOutTooltip')
local ScopeLockTooltip = require(script:WaitForChild 'ScopeLockTooltip')
local ScopeInTooltip = require(script:WaitForChild 'ScopeInTooltip')
local AltTooltip = require(script:WaitForChild 'AltTooltip')

local function HotkeyTooltip(props)
    local Tooltip = nil

    -- Select appropriate tooltip
    if props.IsAltDown then
        if props.IsScopeParent then
            Tooltip = Roact.createElement(ScopeOutTooltip, props)
        elseif props.IsScope and (not props.IsScopeLocked) then
            Tooltip = Roact.createElement(ScopeLockTooltip, props)
        elseif props.IsScopable then
            Tooltip = Roact.createElement(ScopeInTooltip, props)
        end
    elseif props.DisplayAltHotkey then
        Tooltip = Roact.createElement(AltTooltip, props)
    end

    -- Return tooltip with spacer
    return Roact.createFragment({
        Tooltip = Tooltip;
        Spacer = Tooltip and Roact.createElement('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(0, 0, 1, 0);
            LayoutOrder = props.LayoutOrder and (props.LayoutOrder - 1) or 2;
        });
    })
end

return HotkeyTooltip