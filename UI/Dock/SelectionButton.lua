local Root = script:FindFirstAncestorWhichIsA('Tool')
local Vendor = Root:WaitForChild('Vendor')

-- Libraries
local Roact = require(Vendor:WaitForChild('Roact'))

-- Roact
local new = Roact.createElement
local Tooltip = require(script.Parent:WaitForChild('Tooltip'))

-- Create component
local SelectionButton = Roact.PureComponent:extend(script.Name)

function SelectionButton:init()
    self:setState({
        IsHovering = false;
    })
end

function SelectionButton:render()
    return new('ImageButton', {
        BackgroundTransparency = 1;
        Image = self.props.IconAssetId;
        LayoutOrder = self.props.LayoutOrder;
        ImageTransparency = self.props.IsActive and 0 or 0.5;
        [Roact.Event.Activated] = self.props.OnActivated;
        [Roact.Event.InputBegan] = function (rbx, Input)
            if Input.UserInputType.Name == 'MouseMovement' then
                self:setState({
                    IsHovering = true;
                })
            end
        end;
        [Roact.Event.InputEnded] = function (rbx, Input)
            if Input.UserInputType.Name == 'MouseMovement' then
                self:setState({
                    IsHovering = false;
                })
            end
        end;
    }, {
        Tooltip = new(Tooltip, {
            IsVisible = self.state.IsHovering;
            Text = self.props.TooltipText or '';
        })
    });
end

return SelectionButton