local Root = script.Parent.Parent.Parent.Parent
local Vendor = Root:WaitForChild 'Vendor'
local UI = Root:WaitForChild 'UI'

-- Libraries
local Roact = require(Vendor:WaitForChild 'Roact')

-- Roact
local new = Roact.createElement
local Frame = require(UI:WaitForChild 'Frame')
local SectionContainer = require(UI:WaitForChild('ToolHUD'):WaitForChild 'SectionContainer')
local ConstraintTypeButton = require(script:WaitForChild 'ConstraintTypeButton')

local function ConstraintSelector(props)
    return new(SectionContainer, props, {
        Options = new(Frame, {
            Layout = 'Grid',
            Height = 'WRAP_CONTENT',
            CellSize = UDim2.new(0, 50, 0, 50),
            CellPadding = UDim2.new(0, 0, 0, 15),
            FillDirectionMaxCells = 4,
            VerticalAlignment = 'Top',
            HorizontalAlignment = 'Center',
            VerticalPadding = 12
        },
        {
            Weld = new(ConstraintTypeButton, {
                Label = 'WELD',
                ClassName = 'WeldConstraint',
                LayoutOrder = 0
            }),
            Hinge = new(ConstraintTypeButton, {
                Label = 'HINGE',
                ClassName = 'HingeConstraint',
                LayoutOrder = 1
            }),
            BallSocket = new(ConstraintTypeButton, {
                Label = 'BALL IN\nSOCKET',
                ClassName = 'BallSocketConstraint',
                LayoutOrder = 2
            }),
            Prismatic = new(ConstraintTypeButton, {
                Label = 'PRISMATIC',
                ClassName = 'PrismaticConstraint',
                LayoutOrder = 3
            }),
            Cylindrical = new(ConstraintTypeButton, {
                Label = 'CYLINDRICAL',
                ClassName = 'CylindricalConstraint',
                LayoutOrder = 4
            }),
            Rope = new(ConstraintTypeButton, {
                Label = 'ROPE',
                ClassName = 'RopeConstraint',
                LayoutOrder = 5
            }),
            Rod = new(ConstraintTypeButton, {
                Label = 'ROD',
                ClassName = 'RodConstraint',
                LayoutOrder = 6
            }),
            Spring = new(ConstraintTypeButton, {
                Label = 'SPRING',
                ClassName = 'SpringConstraint',
                LayoutOrder = 7
            })
        })
    })
end

return ConstraintSelector