local Root = script:FindFirstAncestorWhichIsA('Tool')
local Vendor = Root:WaitForChild('Vendor')

-- Libraries
local Roact = require(Vendor:WaitForChild('Roact'))
local new = Roact.createElement

-- Create component
local SelectionButton = Roact.PureComponent:extend(script.Name)

function SelectionButton:render()
    return new('ImageButton', {
        BackgroundTransparency = 1;
        Image = self.props.IconAssetId;
        LayoutOrder = self.props.LayoutOrder;
        ImageTransparency = self.props.IsActive and 0 or 0.5;
        [Roact.Event.Activated] = self.props.OnActivated;
    });
end

return SelectionButton