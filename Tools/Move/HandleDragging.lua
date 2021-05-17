local Tool = script.Parent.Parent.Parent

-- API
local Core = require(Tool.Core)
local Selection = Core.Selection
local Security = Core.Security
local BoundingBox = require(Tool.Core.BoundingBox)

-- Libraries
local Libraries = Tool:WaitForChild 'Libraries'
local MoveUtil = require(script.Parent:WaitForChild 'Util')

-- Create class
local HandleDragging = {}
HandleDragging.__index = HandleDragging

-- Directions of movement for each handle's dragged face
local AxisMultipliers = {
	[Enum.NormalId.Top] = Vector3.new(0, 1, 0);
	[Enum.NormalId.Bottom] = Vector3.new(0, -1, 0);
	[Enum.NormalId.Front] = Vector3.new(0, 0, -1);
	[Enum.NormalId.Back] = Vector3.new(0, 0, 1);
	[Enum.NormalId.Left] = Vector3.new(-1, 0, 0);
	[Enum.NormalId.Right] = Vector3.new(1, 0, 0);
}

function HandleDragging.new(Tool)
    local self = {
		Tool = Tool;

		-- Handle state
		IsHandleDragging = false;
		Handles = nil;

		-- Selection state
		InitialExtentsSize = nil;
		InitialExtentsCFrame = nil;
		InitialState = nil;
		InitialFocusCFrame = nil;
    }

    return setmetatable(self, HandleDragging)
end

function HandleDragging:AttachHandles(Part, Autofocus)
	-- Creates and attaches handles to `Part`, and optionally automatically attaches to the focused part

	-- Enable autofocus if requested and not already on
	if Autofocus and not self.Tool.Maid.AutofocusHandle then
		self.Tool.Maid.AutofocusHandle = Selection.FocusChanged:Connect(function ()
			self:AttachHandles(Selection.Focus, true)
		end)

	-- Disable autofocus if not requested and on
	elseif not Autofocus and self.Tool.Maid.AutofocusHandle then
		self.Tool.Maid.AutofocusHandle = nil
	end

	-- Just attach and show the handles if they already exist
	if self.Handles then
		self.Handles:BlacklistObstacle(BoundingBox.GetBoundingBox())
		self.Handles:SetAdornee(Part)
		return
	end

	local AreaPermissions
	local function OnHandleDragStart()
		-- Prepare for moving parts when the handle is clicked

		-- Prevent selection
		Core.Targeting.CancelSelecting()

		-- Indicate dragging via handles
		self.IsHandleDragging = true

		-- Freeze bounding box extents while dragging
		if BoundingBox.GetBoundingBox() then
			local InitialExtentsSize, InitialExtentsCFrame =
				BoundingBox.CalculateExtents(Selection.Parts, BoundingBox.StaticExtents)
			self.InitialExtentsSize = InitialExtentsSize
			self.InitialExtentsCFrame = InitialExtentsCFrame
			BoundingBox.PauseMonitoring()
		end

		-- Stop parts from moving, and capture the initial state of the parts
		local InitialPartStates, InitialModelStates, InitialFocusCFrame = self.Tool:PrepareSelectionForDragging()
		self.InitialPartStates = InitialPartStates
		self.InitialModelStates = InitialModelStates
		self.InitialFocusCFrame = InitialFocusCFrame

		-- Track the change
		self.Tool:TrackChange()

		-- Cache area permissions information
		if Core.Mode == 'Tool' then
			AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Selection.Parts), Core.Player)
		end

	end

	local function OnHandleDrag(Face, Distance)
		-- Update parts when the handles are moved

		-- Only drag if handle is enabled
		if not self.IsHandleDragging then
			return
		end

		-- Calculate the increment-aligned drag distance
		Distance = MoveUtil.GetIncrementMultiple(Distance, self.Tool.Increment)

		-- Move the parts along the selected axes by the calculated distance
		self.Tool:MovePartsAlongAxesByFace(Face, Distance, self.InitialPartStates, self.InitialModelStates, self.InitialFocusCFrame)

		-- Make sure we're not entering any unauthorized private areas
		if Core.Mode == 'Tool' and Security.ArePartsViolatingAreas(Selection.Parts, Core.Player, false, AreaPermissions) then
			local Part, InitialPartState = next(self.InitialPartStates)
			Part.CFrame = InitialPartState.CFrame
			MoveUtil.TranslatePartsRelativeToPart(Part, self.InitialPartStates, self.InitialModelStates)
			Distance = 0
		end

		-- Signal out change in dragged distance
		self.Tool.DragChanged:Fire(Distance)

		-- Update bounding box if enabled in global axes movements
		if self.Tool.Axes == 'Global' and BoundingBox.GetBoundingBox() then
			BoundingBox.GetBoundingBox().CFrame = self.InitialExtentsCFrame + (AxisMultipliers[Face] * Distance)
		end

	end

	local function OnHandleDragEnd()
		if not self.IsHandleDragging then
			return
		end

		-- Disable dragging
		self.IsHandleDragging = false

		-- Make joints, restore original anchor and collision states
		for Part, State in pairs(self.InitialPartStates) do
			Part:MakeJoints()
			Core.RestoreJoints(State.Joints)
			Part.CanCollide = State.CanCollide
			Part.Anchored = State.Anchored
		end

		-- Register change
		self.Tool:RegisterChange()

		-- Resume bounding box updates
		BoundingBox.RecalculateStaticExtents()
		BoundingBox.ResumeMonitoring()
	end

	-- Create the handles
	local Handles = require(Libraries:WaitForChild 'Handles')
	self.Handles = Handles.new({
		Color = self.Tool.Color.Color,
		Parent = Core.UIContainer,
		Adornee = Part,
		ObstacleBlacklist = { BoundingBox.GetBoundingBox() },
		OnDragStart = OnHandleDragStart,
		OnDrag = OnHandleDrag,
		OnDragEnd = OnHandleDragEnd
	})

end

function HandleDragging:HideHandles()
	-- Hides the resizing handles

	-- Make sure handles exist and are visible
	if not self.Handles then
		return
	end

	-- Hide the handles
	self.Handles = self.Handles:Destroy()

	-- Disable handle autofocus
	self.Tool.Maid.AutofocusHandle = nil

end

return HandleDragging