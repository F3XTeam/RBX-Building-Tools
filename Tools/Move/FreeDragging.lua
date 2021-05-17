local Tool = script.Parent.Parent.Parent
local UserInputService = game:GetService 'UserInputService'
local ContextActionService = game:GetService 'ContextActionService'
local Workspace = game:GetService 'Workspace'

-- API
local Core = require(Tool.Core)
local Selection = Core.Selection
local Security = Core.Security
local SnapTracking = require(Tool.Core.Snapping)
local BoundingBox = require(Tool.Core.BoundingBox)

-- Libraries
local Libraries = Tool:WaitForChild 'Libraries'
local Support = require(Libraries:WaitForChild 'SupportLibrary')
local MoveUtil = require(script.Parent:WaitForChild 'Util')

-- Create class
local FreeDragging = {}
FreeDragging.__index = FreeDragging

function FreeDragging.new(Tool)
    local self = {
		Tool = Tool;

        -- Dragging state
        IsDragging = false;
        StartScreenPoint = nil;
        StartTarget = nil;
        CrossthroughCorrection = nil;
        LastSelection = nil;
        LastBasePartOffset = nil;
        Target = nil;
        TargetPoint = nil;
        TargetNormal = nil;
        LastTargetNormal = nil;
        CornerOffsets = nil;

        -- Surface alignment state
        TriggerAlignment = nil;
        SurfaceAlignment = nil;
        LastSurfaceAlignment = nil;
    }

    setmetatable(self, FreeDragging)

    -- Listen for free dragging ending
    self:InstallDragEndListener()

    -- Return initialized module
    return self
end

function FreeDragging:EnableDragging()
	-- Enables part dragging

	local function HandleDragStart(Action, State, Input)
		if State.Name ~= 'Begin' then
			return Enum.ContextActionResult.Pass
		end

		-- Get mouse target
		local TargetPart = Core.Mouse.Target
		if (not TargetPart) or Selection.Multiselecting then
			return Enum.ContextActionResult.Pass
		end

		-- Make sure target is draggable, unless snapping
		local IsSnapping = UserInputService:IsKeyDown(Enum.KeyCode.R) and #Selection.Items > 0
		if not Core.IsSelectable({ TargetPart }) and not IsSnapping then
			return Enum.ContextActionResult.Pass
		end

		-- Initialize dragging detection data
		self.StartTarget = TargetPart
		self.StartScreenPoint = Vector2.new(Core.Mouse.X, Core.Mouse.Y)

		-- Select unselected target, if not snapping
		local _, ScopeTarget = Core.Targeting:UpdateTarget()
		if not Selection.IsSelected(ScopeTarget) and not IsSnapping then
			Core.Targeting.SelectTarget(true)
			Core.Targeting.CancelSelecting()
		end

		local function HandlePotentialDragStart(Action, State, Input)
			if State.Name ~= 'Change' then
				return Enum.ContextActionResult.Pass
			end

			-- Trigger dragging if the mouse is moved over 2 pixels
			local DragScreenDistance = self.StartScreenPoint and
				(Vector2.new(Core.Mouse.X, Core.Mouse.Y) - self.StartScreenPoint).Magnitude
			if DragScreenDistance >= 2 then

				-- Prepare for dragging
				BoundingBox.ClearBoundingBox()
				self:SetUpDragging(self.StartTarget, SnapTracking.Enabled and self.Tool.SnappedPoint or nil)

				-- Stop watching for potential dragging
				ContextActionService:UnbindAction 'BT: Watch for dragging'

			end

			-- Pass input if not a touch interaction
			if Input.UserInputType.Name ~= 'Touch' then
				return Enum.ContextActionResult.Pass
			end
		end

		-- Watch for potential dragging
		ContextActionService:BindAction('BT: Watch for dragging', HandlePotentialDragStart, false,
			Enum.UserInputType.MouseMovement,
			Enum.UserInputType.Touch
		)
	end

	-- Pay attention to when the user intends to start dragging
	ContextActionService:BindAction('BT: Start dragging', HandleDragStart, false,
		Enum.UserInputType.MouseButton1,
		Enum.UserInputType.Touch
	)

end

function FreeDragging:SetUpDragging(BasePart, BasePoint)
	-- Sets up and initiates dragging based on the given base part

	-- Prevent selection while dragging
	Core.Targeting.CancelSelecting()

	-- Prepare parts, and start dragging
	self.InitialPartStates, self.InitialModelStates = self.Tool:PrepareSelectionForDragging()
	self:StartDragging(BasePart, self.InitialPartStates, self.InitialModelStates, BasePoint)

end

function FreeDragging:StartDragging(BasePart, InitialPartStates, InitialModelStates, BasePoint)
	-- Begins dragging the selection

	-- Ensure dragging is not already ongoing
	if self.IsDragging then
		return
	end

	-- Indicate that we're dragging
	self.IsDragging = true

	-- Track changes
	self.Tool:TrackChange()

	-- Disable bounding box calculation
	BoundingBox.ClearBoundingBox()

	-- Cache area permissions information
	local AreaPermissions
	if Core.Mode == 'Tool' then
		AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Selection.Parts), Core.Player)
	end

	-- Ensure a base part is provided
	if not InitialPartStates[BasePart] then
		BasePart = next(InitialPartStates)
		if not BasePart then
			return
		end
	end

	-- Determine the base point for dragging
	local BasePartOffset = -BasePart.CFrame:pointToObjectSpace(Core.Mouse.Hit.p)

	-- Improve base point alignment for the given increment
	BasePartOffset = Vector3.new(
		math.clamp(MoveUtil.GetIncrementMultiple(BasePartOffset.X, self.Tool.Increment), -BasePart.Size.X / 2, BasePart.Size.X / 2),
		math.clamp(MoveUtil.GetIncrementMultiple(BasePartOffset.Y, self.Tool.Increment), -BasePart.Size.Y / 2, BasePart.Size.Y / 2),
		math.clamp(MoveUtil.GetIncrementMultiple(BasePartOffset.Z, self.Tool.Increment), -BasePart.Size.Z / 2, BasePart.Size.Z / 2)
	)

	-- Use the given base point instead if any
	if BasePoint then
		BasePartOffset = -BasePart.CFrame:pointToObjectSpace(BasePoint)
	end

	-- Prepare snapping in case it is enabled, and make sure to override its default target selection
	SnapTracking.TargetBlacklist = Selection.Items
	self.Tool.Maid.DragSnapping = self.Tool.PointSnapped:Connect(function (SnappedPoint)

		-- Align the selection's base point to the snapped point
		local Rotation = self.SurfaceAlignment or (InitialPartStates[BasePart].CFrame - InitialPartStates[BasePart].CFrame.p)
		BasePart.CFrame = CFrame.new(SnappedPoint) * Rotation * CFrame.new(BasePartOffset)
		MoveUtil.TranslatePartsRelativeToPart(BasePart, InitialPartStates, InitialModelStates)

		-- Make sure we're not entering any unauthorized private areas
		if Core.Mode == 'Tool' and Security.ArePartsViolatingAreas(Selection.Parts, Core.Player, false, AreaPermissions) then
			BasePart.CFrame = InitialPartStates[BasePart].CFrame
			MoveUtil.TranslatePartsRelativeToPart(BasePart, InitialPartStates, InitialModelStates)
		end

	end)

	-- Update cache of corner offsets for later crossthrough calculations
	self.CornerOffsets = GetCornerOffsets(InitialPartStates[BasePart].CFrame, InitialPartStates)

	-- Provide a callback to trigger alignment
	self.TriggerAlignment = function ()

		-- Trigger drag recalculation
		self:DragToMouse(BasePart, BasePartOffset, InitialPartStates, InitialModelStates, AreaPermissions)

		-- Trigger snapping recalculation
		if SnapTracking.Enabled then
			self.Tool.PointSnapped:Fire(self.Tool.SnappedPoint)
		end

	end

	local function HandleDragChange(Action, State, Input)
		if State.Name == 'Change' then
			self:DragToMouse(BasePart, BasePartOffset, InitialPartStates, InitialModelStates, AreaPermissions)
		end
		return Enum.ContextActionResult.Pass
	end

	-- Start up the dragging
	ContextActionService:BindAction('BT: Dragging', HandleDragChange, false,
		Enum.UserInputType.MouseMovement,
		Enum.UserInputType.Touch
	)

end

function FreeDragging:DragToMouse(BasePart, BasePartOffset, InitialPartStates, InitialModelStates, AreaPermissions)
	-- Drags the selection by `BasePart`, judging area authorization from `AreaPermissions`

	----------------------------------------------
	-- Check what and where the mouse is aiming at
	----------------------------------------------

	-- Don't consider other selected parts possible targets
	local IgnoreList = Support.CloneTable(Selection.Items)
	table.insert(IgnoreList, Core.Player and Core.Player.Character)

	-- Perform the mouse target search
	local Target, TargetPoint, TargetNormal = Workspace:FindPartOnRayWithIgnoreList(
		Ray.new(Core.Mouse.UnitRay.Origin, Core.Mouse.UnitRay.Direction * 5000),
		IgnoreList
	)
	self.Target = Target
	self.TargetPoint = TargetPoint
	self.TargetNormal = TargetNormal

	-- Reset any surface alignment and calculated crossthrough if target surface changes
	if self.LastTargetNormal ~= self.TargetNormal then
		self.SurfaceAlignment = nil
		self.CrossthroughCorrection = nil
	end

	-- Reset any calculated crossthrough if selection, drag offset, or surface alignment change
	if (self.LastSelection ~= Selection.Items) or
			(self.LastBasePartOffset ~= BasePartOffset) or
			(self.LastSurfaceAlignment ~= self.SurfaceAlignment) then
		self.CrossthroughCorrection = nil
	end

	-- Save last dragging options for change detection
	self.LastSelection = Selection.Items
	self.LastBasePartOffset = BasePartOffset
	self.LastSurfaceAlignment = self.SurfaceAlignment
	self.LastTargetNormal = self.TargetNormal

	------------------------------------------------
	-- Move the selection towards any snapped points
	------------------------------------------------

	-- If snapping is enabled, skip regular dragging
	if SnapTracking.Enabled then
		return
	end

	------------------------------------------------------
	-- Move the selection towards the right mouse location
	------------------------------------------------------

	-- Get the increment-aligned target point
	self.TargetPoint = self:GetAlignedTargetPoint(
		self.Target,
		self.TargetPoint,
		self.TargetNormal,
		self.Tool.Increment
	)

	-- Move the parts towards their target destination
	local Rotation = self.SurfaceAlignment or (InitialPartStates[BasePart].CFrame - InitialPartStates[BasePart].CFrame.p)
	local TargetCFrame = CFrame.new(self.TargetPoint) * Rotation * CFrame.new(BasePartOffset)

	-- Calculate crossthrough against target plane if necessary
	if not self.CrossthroughCorrection then
		self.CrossthroughCorrection = 0

		-- Calculate each corner's tentative position
		for _, CornerOffset in pairs(self.CornerOffsets) do
			local Corner = TargetCFrame * CornerOffset

			-- Calculate the corner's target plane crossthrough
			local CornerCrossthrough = -(self.TargetPoint - Corner):Dot(self.TargetNormal)

			-- Check if this corner crosses through the most
			if CornerCrossthrough < self.CrossthroughCorrection then
				self.CrossthroughCorrection = CornerCrossthrough
			end
		end
	end

	-- Move the selection, retracted by the max. crossthrough amount
	BasePart.CFrame = TargetCFrame - (self.TargetNormal * self.CrossthroughCorrection)
	MoveUtil.TranslatePartsRelativeToPart(BasePart, InitialPartStates, InitialModelStates)

	----------------------------------------
	-- Check for relevant area authorization
	----------------------------------------

	-- Make sure we're not entering any unauthorized private areas
	if Core.Mode == 'Tool' and Security.ArePartsViolatingAreas(Selection.Parts, Core.Player, false, AreaPermissions) then
		BasePart.CFrame = InitialPartStates[BasePart].CFrame
		MoveUtil.TranslatePartsRelativeToPart(BasePart, InitialPartStates, InitialModelStates)
	end

end

function FreeDragging:AlignSelectionToTarget()
	-- Aligns the selection to the current target surface while dragging

	-- Ensure dragging is ongoing
	if not self.IsDragging or not self.TargetNormal then
		return
	end

	-- Get target surface normal as arbitrarily oriented CFrame
	local TargetNormalCF = CFrame.new(Vector3.new(), self.TargetNormal)

	-- Use detected surface normal directly if not targeting a part
	if not self.Target then
		self.SurfaceAlignment = TargetNormalCF * CFrame.Angles(-math.pi / 2, 0, 0)

	-- For parts, calculate orientation based on the target surface, and the target part's orientation
	else

		-- Set upward direction to match the target surface normal
		local UpVector, LookVector, RightVector = self.TargetNormal

		-- Use target's rightward orientation for calculating orientation (when targeting forward or backward directions)
		local Target, TargetNormal = self.Target, self.TargetNormal
		if TargetNormal:isClose(Target.CFrame.lookVector, 0.000001) or TargetNormal:isClose(-Target.CFrame.lookVector, 0.000001) then
			LookVector = TargetNormal:Cross(Target.CFrame.rightVector).unit
			RightVector = LookVector:Cross(TargetNormal).unit

		-- Use target's forward orientation for calculating orientation (when targeting any other direction)
		else
			RightVector = Target.CFrame.lookVector:Cross(TargetNormal).unit
			LookVector = TargetNormal:Cross(RightVector).unit
		end

		-- Generate rotation matrix based on direction vectors
		self.SurfaceAlignment = CFrame.new(
			0, 0, 0,
			RightVector.X, UpVector.X, -LookVector.X,
			RightVector.Y, UpVector.Y, -LookVector.Y,
			RightVector.Z, UpVector.Z, -LookVector.Z
		)

	end

	-- Trigger alignment
	self:TriggerAlignment()

end

function FreeDragging:GetAlignedTargetPoint(Target, TargetPoint, TargetNormal, Increment)
	-- Returns the target point aligned to the nearest increment multiple

	-- By default, use the center of the universe for alignment on all axes
	local ReferencePoint = CFrame.new()
	local PlaneAxes = Vector3.new(1, 1, 1)

	-----------------------------------------------------------------------------
	-- Detect appropriate reference points and plane axes for recognized surfaces
	-----------------------------------------------------------------------------

	-- Make sure the target is a part
	if Target and Target:IsA 'BasePart' and Target.ClassName ~= 'Terrain' then
		local Size = Target.Size / 2

		-- Calculate the direction of a wedge surface
		local WedgeDirection = (Target.CFrame - Target.CFrame.p) *
			CFrame.fromAxisAngle(Vector3.FromAxis(Enum.Axis.X), math.atan(Target.Size.Z / Target.Size.Y))

		-- Calculate the direction of a corner part's Z-axis surface
		local CornerDirectionZ = (Target.CFrame - Target.CFrame.p) *
			CFrame.fromAxisAngle(Vector3.FromAxis(Enum.Axis.X), math.pi - math.atan(Target.Size.Z / Target.Size.Y))

		-- Calculate the direction of a corner part's X-axis surface
		local CornerDirectionX = (Target.CFrame - Target.CFrame.p) *
			CFrame.fromAxisAngle(Vector3.FromAxis(Enum.Axis.Z), math.atan(Target.Size.Y / Target.Size.X)) *
			CFrame.fromAxisAngle(Vector3.FromAxis(Enum.Axis.X), math.pi / 2) *
			CFrame.fromAxisAngle(Vector3.FromAxis(Enum.Axis.Z), -math.pi / 2)

		-- Get the right alignment reference point on a part's front surface
		if TargetNormal:isClose(Target.CFrame.lookVector, 0.000001) then
			ReferencePoint = Target.CFrame * CFrame.new(Size.X, Size.Y, -Size.Z)
			PlaneAxes = Vector3.new(1, 1, 0)

		-- Get the right alignment reference point on a part's back surface
		elseif TargetNormal:isClose(-Target.CFrame.lookVector, 0.000001) then
			ReferencePoint = Target.CFrame * CFrame.new(-Size.X, Size.Y, Size.Z)
			PlaneAxes = Vector3.new(1, 1, 0)

		-- Get the right alignment reference point on a part's left surface
		elseif TargetNormal:isClose(-Target.CFrame.rightVector, 0.000001) then
			ReferencePoint = Target.CFrame * CFrame.new(-Size.X, Size.Y, -Size.Z)
			PlaneAxes = Vector3.new(0, 1, 1)

		-- Get the right alignment reference point on a part's right surface
		elseif TargetNormal:isClose(Target.CFrame.rightVector, 0.000001) then
			ReferencePoint = Target.CFrame * CFrame.new(Size.X, Size.Y, Size.Z)
			PlaneAxes = Vector3.new(0, 1, 1)

		-- Get the right alignment reference point on a part's upper surface
		elseif TargetNormal:isClose(Target.CFrame.upVector, 0.000001) then
			ReferencePoint = Target.CFrame * CFrame.new(Size.X, Size.Y, Size.Z)
			PlaneAxes = Vector3.new(1, 0, 1)

		-- Get the right alignment reference point on a part's bottom surface
		elseif TargetNormal:isClose(-Target.CFrame.upVector, 0.000001) then
			ReferencePoint = Target.CFrame * CFrame.new(Size.X, -Size.Y, -Size.Z)
			PlaneAxes = Vector3.new(1, 0, 1)

		-- Get the right alignment reference point on wedged part surfaces
		elseif TargetNormal:isClose(WedgeDirection.lookVector, 0.000001) then

			-- Get reference point oriented to wedge plane
			ReferencePoint = WedgeDirection *
				CFrame.fromAxisAngle(Vector3.FromAxis(Enum.Axis.X), -math.pi / 2) +
				(Target.CFrame * Vector3.new(Size.X, Size.Y, Size.Z))

			-- Set plane offset axes
			PlaneAxes = Vector3.new(1, 0, 1)

		-- Get the right alignment reference point on the Z-axis surface of a corner part
		elseif TargetNormal:isClose(CornerDirectionZ.lookVector, 0.000001) then

			-- Get reference point oriented to wedged plane
			ReferencePoint = CornerDirectionZ *
				CFrame.fromAxisAngle(Vector3.FromAxis(Enum.Axis.X), -math.pi / 2) +
				(Target.CFrame * Vector3.new(-Size.X, Size.Y, -Size.Z))

			-- Set plane offset axes
			PlaneAxes = Vector3.new(1, 0, 1)

		-- Get the right alignment reference point on the X-axis surface of a corner part
		elseif TargetNormal:isClose(CornerDirectionX.lookVector, 0.000001) then

			-- Get reference point oriented to wedged plane
			ReferencePoint = CornerDirectionX *
				CFrame.fromAxisAngle(Vector3.FromAxis(Enum.Axis.X), -math.pi / 2) +
				(Target.CFrame * Vector3.new(Size.X, Size.Y, -Size.Z))

			-- Set plane offset axes
			PlaneAxes = Vector3.new(1, 0, 1)

		-- Return an unaligned point for unrecognized surfaces
		else
			return TargetPoint
		end

	end

	-------------------------------------
	-- Calculate the aligned target point
	-------------------------------------

	-- Get target point offset from reference point
	local ReferencePointOffset = ReferencePoint:inverse() * CFrame.new(TargetPoint)

	-- Align target point on increment grid from reference point along the plane axes
	local AlignedTargetPoint = ReferencePoint * (Vector3.new(
		MoveUtil.GetIncrementMultiple(ReferencePointOffset.X, Increment),
		MoveUtil.GetIncrementMultiple(ReferencePointOffset.Y, Increment),
		MoveUtil.GetIncrementMultiple(ReferencePointOffset.Z, Increment)
	) * PlaneAxes)

	-- Return the aligned target point
	return AlignedTargetPoint

end

function FreeDragging:FinishDragging()
	-- Releases parts and registers position changes from dragging

	-- Make sure dragging is active
	if not self.IsDragging then
		return
	end

	-- Indicate that we're no longer dragging
	self.IsDragging = false

	-- Clear any surface alignment
	self.SurfaceAlignment = nil

	-- Stop the dragging action
	ContextActionService:UnbindAction 'BT: Dragging'

	-- Stop, clean up snapping point tracking
	SnapTracking.StopTracking()
	self.Tool.Maid.DragSnapping = nil

	-- Restore the original state of each part
	for Part, State in pairs(self.InitialPartStates) do
		Part:MakeJoints()
		Core.RestoreJoints(State.Joints)
		Part.CanCollide = State.CanCollide
		Part.Anchored = State.Anchored
	end

	-- Register changes
	self.Tool:RegisterChange()

end


-- Cache common functions to avoid unnecessary table lookups
local TableInsert, NewVector3 = table.insert, Vector3.new

function GetCornerOffsets(Origin, InitialStates)
	-- Calculates and returns the offset of every corner in the initial state from the origin CFrame

	local CornerOffsets = {}

	-- Get offset for origin point
	local OriginOffset = Origin:inverse()

	-- Go through each item in the initial state
	for Item, State in pairs(InitialStates) do
		local ItemCFrame = State.CFrame
		local SizeX, SizeY, SizeZ = Item.Size.X / 2, Item.Size.Y / 2, Item.Size.Z / 2

		-- Gather each corner
		TableInsert(CornerOffsets, OriginOffset * (ItemCFrame * NewVector3(SizeX, SizeY, SizeZ)))
		TableInsert(CornerOffsets, OriginOffset * (ItemCFrame * NewVector3(-SizeX, SizeY, SizeZ)))
		TableInsert(CornerOffsets, OriginOffset * (ItemCFrame * NewVector3(SizeX, -SizeY, SizeZ)))
		TableInsert(CornerOffsets, OriginOffset * (ItemCFrame * NewVector3(SizeX, SizeY, -SizeZ)))
		TableInsert(CornerOffsets, OriginOffset * (ItemCFrame * NewVector3(-SizeX, SizeY, -SizeZ)))
		TableInsert(CornerOffsets, OriginOffset * (ItemCFrame * NewVector3(-SizeX, -SizeY, SizeZ)))
		TableInsert(CornerOffsets, OriginOffset * (ItemCFrame * NewVector3(SizeX, -SizeY, -SizeZ)))
		TableInsert(CornerOffsets, OriginOffset * (ItemCFrame * NewVector3(-SizeX, -SizeY, -SizeZ)))
	end

	-- Return the offsets
	return CornerOffsets

end

function FreeDragging:InstallDragEndListener()
    Support.AddUserInputListener('Ended', {'Touch', 'MouseButton1'}, true, function (Input)

        -- Clear drag detection data
        self.StartScreenPoint = nil
        self.StartTarget = nil
        ContextActionService:UnbindAction 'BT: Watch for dragging'

        -- Reset from drag mode if dragging
        if self.IsDragging then

            -- Reset axes
            self.Tool:SetAxes(self.Tool.Axes)

            -- Finalize the dragging operation
            self:FinishDragging()

        end

    end)
end

return FreeDragging