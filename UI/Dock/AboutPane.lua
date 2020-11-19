local Root = script:FindFirstAncestorWhichIsA('Tool')
local Vendor = Root:WaitForChild('Vendor')
local UI = Root:WaitForChild('UI')

-- Libraries
local Roact = require(Vendor:WaitForChild('Roact'))

-- Roact
local new = Roact.createElement
local ToolManualWindow = require(UI:WaitForChild('ToolManualWindow'))

local MANUAL_CONTENT = [[<font face="GothamBlack" size="16">Building Tools by F3X  🛠</font>
To learn more about each tool, click on its ❔ icon at the top right corner.<font size="12"><br /></font>

<font size="12" color="rgb(150, 150, 150)"><b>Selecting</b></font>
 <font color="rgb(150, 150, 150)">•</font> Select individual parts by holding <b>Shift</b> and clicking each one.
 <font color="rgb(150, 150, 150)">•</font> Rectangle select parts by holding <b>Shift</b>, clicking, and dragging.
 <font color="rgb(150, 150, 150)">•</font> Press <b>Shift-K</b> to select parts inside of the selected parts.
 <font color="rgb(150, 150, 150)">•</font> Press <b>Shift-R</b> to clear your selection.<font size="12"><br /></font>

<font size="12" color="rgb(150, 150, 150)"><b>Exporting your creations</b></font>
You can export your builds into a short code by clicking the export button, or pressing <b>Shift-P</b>.<font size="8"><br /></font>
Install the import plugin in <b>Roblox Studio</b> to import your creation:
<font color="rgb(150, 150, 150)">roblox.com/library/142485815</font>]]

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
        [Roact.Event.Activated] = function (rbx)
            self:setState({
                IsManualOpen = not self.state.IsManualOpen;
            })
        end;
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
        HelpIcon = new('ImageLabel', {
            AnchorPoint = Vector2.new(1, 0.5);
            BackgroundTransparency = 1;
            Position = UDim2.new(1, 0, 0.5, 0);
            Size = UDim2.new(0, 30, 0, 30);
            Image = 'rbxassetid://141911973';

        });
        ManualWindowPortal = new(Roact.Portal, {
            target = self.props.Core.UI;
        }, {
            ManualWindow = (self.state.IsManualOpen or nil) and new(ToolManualWindow, {
                Text = MANUAL_CONTENT;
                ThemeColor = Color3.fromRGB(255, 176, 0);
            });
        });
    })
end

return AboutPane