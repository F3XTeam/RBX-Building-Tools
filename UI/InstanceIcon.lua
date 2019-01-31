local Root = script.Parent.Parent
local Vendor = Root:WaitForChild 'Vendor'
local Libraries = Root:WaitForChild 'Libraries'
local UI = Root:WaitForChild 'UI'

-- Libraries
local Roact = require(Vendor:WaitForChild 'Roact')
local Support = require(Libraries:WaitForChild 'SupportLibrary')

-- Roact
local new = Roact.createElement
local ImageLabel = require(UI:WaitForChild 'ImageLabel')

-- Map of icons
local ClassIcons = {
    Part = Vector2.new(2, 1),
    MeshPart = Vector2.new(4, 8),
    UnionOperation = Vector2.new(4, 8),
    NegateOperation = Vector2.new(3, 8),
    VehicleSeat = Vector2.new(6, 4),
    Seat = Vector2.new(6, 4),
    TrussPart = Vector2.new(2, 1),
    CornerWedgePart = Vector2.new(2, 1),
    WedgePart = Vector2.new(2, 1),
    SpawnLocation = Vector2.new(6, 3),
    Model = Vector2.new(3, 1),
    Folder = Vector2.new(8, 8),
    Tool = Vector2.new(8, 2),
    Workspace = Vector2.new(10, 2),
    Accessory = Vector2.new(3, 4),
    Accoutrement = Vector2.new(3, 4),
    Attachment = Vector2.new(2, 9),
    BallSocketConstraint = Vector2.new(7, 9),
    HingeConstraint = Vector2.new(8, 9),
    PrismaticConstraint = Vector2.new(9, 9),
    RopeConstraint = Vector2.new(10, 9),
    RodConstraint = Vector2.new(1, 10),
    SpringConstraint = Vector2.new(2, 10),
    WeldConstraint = Vector2.new(5, 10),
    CylindricalConstraint = Vector2.new(6, 10)
}

local function InstanceIcon(props)
    local ImageProps = Support.MergeWithBlanks({}, props, { ClassName = Support.Blank })
    local IconPosition = ClassIcons[props.ClassName]

    return new(ImageLabel, Support.Merge(ImageProps, {
        Image = 'rbxassetid://2245672825',
        ImageRectOffset = (IconPosition - Vector2.new(1, 1)) * Vector2.new(16, 16),
        ImageRectSize = Vector2.new(16, 16)
    }))
end

return InstanceIcon