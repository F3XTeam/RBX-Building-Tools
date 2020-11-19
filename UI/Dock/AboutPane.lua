local Root = script:FindFirstAncestorWhichIsA('Tool')
local Vendor = Root:WaitForChild('Vendor')

-- Libraries
local Roact = require(Vendor:WaitForChild('Roact'))
local new = Roact.createElement

-- Create component
local AboutPane = Roact.PureComponent:extend(script.Name)

function AboutPane:init()
    self.DockSize, self.SetDockSize = Roact.createBinding(UDim2.new())
end

function AboutPane:render()
    return new('ImageButton', {
        Image = '';
        BackgroundTransparency = 0.75;
        BackgroundColor3 = Color3.fromRGB(0, 0, 0);
        LayoutOrder = self.props.LayoutOrder;
        Size = UDim2.new(1, 0, 0, 32);
    }, {
        Corners = new('UICorner', {
            CornerRadius = UDim.new(0, 3);
        });
        Signature = new('ImageLabel', {
            AnchorPoint = Vector2.new(0, 0.5);
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 0, 13);
            Image = 'rbxassetid://2326685066';
            Position = UDim2.new(0, 6, 0.5, 0);
        }, {
            AspectRatio = new('UIAspectRatioConstraint', {
                AspectRatio = 2.385;
            });
        });
        HelpButton = new('ImageButton', {
            AnchorPoint = Vector2.new(1, 0.5);
            BackgroundTransparency = 1;
            Position = UDim2.new(1, 0, 0.5, 0);
            Size = UDim2.new(0, 30, 0, 30);
            Image = 'rbxassetid://141911973';
        });
    })
end

return AboutPane