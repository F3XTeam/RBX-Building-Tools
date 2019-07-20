local Tool = script.Parent.Parent
local Core = require(Tool.Core)
local SnapTracking = require(Tool.Core.Snapping)
local BoundingBox = require(Tool.Core.BoundingBox)

-- Services
local ContextActionService = game:GetService 'ContextActionService'
local Workspace = game:GetService 'Workspace'
local UserInputService = game:GetService 'UserInputService'

-- Libraries
local Libraries = Tool:WaitForChild 'Libraries'
local Signal = require(Libraries:WaitForChild 'Signal')
local Maid = require(Libraries:WaitForChild 'Maid')

-- Import relevant references
local Selection = Core.Selection
local Support = Core.Support
local Security = Core.Security

-- Initialize the tool
local MoveTool = {
	Name = 'Move Tool';
	Color = BrickColor.new 'Deep orange';

	-- Default options
	Increment = 1;
	Axes = 'Global';

	-- Dragging state
	IsFreeDragging = false;
	IsHandleDragging = false;
	FreeDragStartScreenPoint = nil;
	FreeDragStartTarget = nil;
	TriggerAlignment = nil;
	SurfaceAlignment = nil;
	LastSurfaceAlignment = nil;
	CrossthroughCorrection = nil;
	LastSelection = nil;
	LastBasePartOffset = nil;
	Target = nil;
	TargetPoint = nil;
	TargetNormal = nil;
	LastTargetNormal = nil;
	CornerOffsets = nil;

	-- Selection state
	InitialState = nil;
	InitialFocusCFrame = nil;
	InitialExtentsSize = nil;
	InitialExtentsCFrame = nil;

	-- Snapping state
	SnappedPoint = nil;
	PointSnapped = Signal.new();

	-- Resource maid
	Maid = Maid.new();
}

function MoveTool:Equip()
	-- Enables the tool's equipped functionality

	-- Set our current axis mode
	self:SetAxes(self.Axes)

	-- Start up our interface
	self:ShowUI()
	self:BindShortcutKeys()
	self:EnableDragging()

end

function MoveTool:Unequip()
	-- Disables the tool's equipped functionality

	-- If dragging, finish dragging
	if self.IsFreeDragging then
		self:FinishDragging()
	end

	-- Disable dragging
	ContextActionService:UnbindAction 'BT: Start dragging'

	-- Clear unnecessary resources
	self:HideUI()
	self:HideHandles()
	self.Maid:Destroy()
	BoundingBox.ClearBoundingBox();
	SnapTracking.StopTracking();

end

function MoveTool:ShowUI()
	-- Creates and reveals the UI

	-- Reveal UI if already created
	if self.UI then
		self.UI.Visible = true
		self.UIUpdater = Support.Loop(0.1, self.UpdateUI, self)
		return
	end

	-- Create the UI
	self.UI = Core.Tool.Interfaces.BTMoveToolGUI:Clone()
	self.UI.Parent = Core.UI
	self.UI.Visible = true

	-- Add functionality to the axes option switch
	local AxesSwitch = self.UI.AxesOption
	AxesSwitch.Global.Button.MouseButton1Down:Connect(function ()
		self:SetAxes('Global')
	end)
	AxesSwitch.Local.Button.MouseButton1Down:Connect(function ()
		self:SetAxes('Local')
	end)
	AxesSwitch.Last.Button.MouseButton1Down:Connect(function ()
		self:SetAxes('Last')
	end)

	-- Add functionality to the increment input
	local IncrementInput = self.UI.IncrementOption.Increment.TextBox
	IncrementInput.FocusLost:Connect(function (EnterPressed)
		self.Increment = tonumber(IncrementInput.Text) or self.Increment
		IncrementInput.Text = Support.Round(self.Increment, 4)
	end)

	-- Add functionality to the position inputs
	local XInput = self.UI.Info.Center.X.TextBox
	local YInput = self.UI.Info.Center.Y.TextBox
	local ZInput = self.UI.Info.Center.Z.TextBox
	XInput.FocusLost:Connect(function (EnterPressed)
		local NewPosition = tonumber(XInput.Text)
		if NewPosition then
			self:SetAxisPosition('X', NewPosition)
		end
	end)
	YInput.FocusLost:Connect(function (EnterPressed)
		local NewPosition = tonumber(YInput.Text)
		if NewPosition then
			self:SetAxisPosition('Y', NewPosition)
		end
	end)
	ZInput.FocusLost:Connect(function (EnterPressed)
		local NewPosition = tonumber(ZInput.Text)
		if NewPosition then
			self:SetAxisPosition('Z', NewPosition)
		end
	end)

	-- Update the UI every 0.1 seconds
	self.UIUpdater = Support.Loop(0.1, self.UpdateUI, self)

end

function MoveTool:HideUI()
	-- Hides the tool UI

	-- Make sure there's a UI
	if not self.UI then
		return;
	end;

	-- Hide the UI
	self.UI.Visible = false

	-- Stop updating the UI
	self.UIUpdater()

end

function MoveTool:UpdateUI()
	-- Updates information on the UI

	-- Make sure the UI's on
	if not self.UI then
		return;
	end;

	-- Only show and calculate selection info if it's not empty
	if #Selection.Parts == 0 then
		self.UI.Info.Visible = false
		self.UI.Size = UDim2.new(0, 245, 0, 90)
		return;
	else
		self.UI.Info.Visible = true
		self.UI.Size = UDim2.new(0, 245, 0, 150)
	end;

	---------------------------------------------
	-- Update the position information indicators
	---------------------------------------------

	-- Identify common positions across axes
	local XVariations, YVariations, ZVariations = {}, {}, {};
	for _, Part in pairs(Selection.Parts) do
		table.insert(XVariations, Support.Round(Part.Position.X, 3));
		table.insert(YVariations, Support.Round(Part.Position.Y, 3));
		table.insert(ZVariations, Support.Round(Part.Position.Z, 3));
	end;
	local CommonX = Support.IdentifyCommonItem(XVariations);
	local CommonY = Support.IdentifyCommonItem(YVariations);
	local CommonZ = Support.IdentifyCommonItem(ZVariations);

	-- Shortcuts to indicators
	local XIndicator = self.UI.Info.Center.X.TextBox
	local YIndicator = self.UI.Info.Center.Y.TextBox
	local ZIndicator = self.UI.Info.Center.Z.TextBox

	-- Update each indicator if it's not currently being edited
	if not XIndicator:IsFocused() then
		XIndicator.Text = CommonX or '*';
	end;
	if not YIndicator:IsFocused() then
		YIndicator.Text = CommonY or '*';
	end;
	if not ZIndicator:IsFocused() then
		ZIndicator.Text = CommonZ or '*';
	end;

end

function MoveTool:SetAxes(AxisMode)
	-- Sets the given axis mode

	-- Update setting
	self.Axes = AxisMode

	-- Update the UI switch
	if self.UI then
		Core.ToggleSwitch(AxisMode, self.UI.AxesOption)
	end;

	-- Disable any unnecessary bounding boxes
	BoundingBox.ClearBoundingBox();

	-- For global mode, use bounding box handles
	if AxisMode == 'Global' then
		BoundingBox.StartBoundingBox(function (BoundingBox)
			self:AttachHandles(BoundingBox)
		end)

	-- For local mode, use focused part handles
	elseif AxisMode == 'Local' then
		self:AttachHandles(Selection.Focus, true)

	-- For last mode, use focused part handles
	elseif AxisMode == 'Last' then
		self:AttachHandles(Selection.Focus, true)
	end

end

-- Directions of movement for each handle's dragged face
local AxisMultipliers = {
	[Enum.NormalId.Top] = Vector3.new(0, 1, 0);
	[Enum.NormalId.Bottom] = Vector3.new(0, -1, 0);
	[Enum.NormalId.Front] = Vector3.new(0, 0, -1);
	[Enum.NormalId.Back] = Vector3.new(0, 0, 1);
	[Enum.NormalId.Left] = Vector3.new(-1, 0, 0);
	[Enum.NormalId.Right] = Vector3.new(1, 0, 0);
};

function MoveTool:AttachHandles(Part, Autofocus)
	-- Creates and attaches handles to `Part`, and optionally automatically attaches to the focused part

	-- Enable autofocus if requested and not already on
	if Autofocus and not self.Maid.AutofocusHandle then
		self.Maid.AutofocusHandle = Selection.FocusChanged:Connect(function ()
			self:AttachHandles(Selection.Focus, true)
		end)

	-- Disable autofocus if not requested and on
	elseif not Autofocus and self.Maid.AutofocusHandle then
		self.Maid.AutofocusHandle = nil
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
		Core.Targeting.CancelSelecting();

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
		local InitialState, InitialFocusCFrame = PreparePartsForDragging()
		self.InitialState = InitialState
		self.InitialFocusCFrame = InitialFocusCFrame

		-- Track the change
		self:TrackChange()

		-- Cache area permissions information
		if Core.Mode == 'Tool' then
			AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Selection.Parts), Core.Player);
		end;

	end

	local function OnHandleDrag(Face, Distance)
		-- Update parts when the handles are moved

		-- Only drag if handle is enabled
		if not self.IsHandleDragging then
			return;
		end;

		-- Calculate the increment-aligned drag distance
		Distance = GetIncrementMultiple(Distance, self.Increment);

		-- Move the parts along the selected axes by the calculated distance
		self:MovePartsAlongAxesByFace(Face, Distance, self.InitialState, self.InitialFocusCFrame)

		-- Make sure we're not entering any unauthorized private areas
		if Core.Mode == 'Tool' and Security.ArePartsViolatingAreas(Selection.Parts, Core.Player, false, AreaPermissions) then
			local Part, InitialPartState = next(self.InitialState)
			Part.CFrame = InitialPartState.CFrame
			TranslatePartsRelativeToPart(Part, self.InitialState)
			Distance = 0
		end;

		-- Update the "distance moved" indicator
		if self.UI then
			self.UI.Changes.Text.Text = 'moved ' .. math.abs(Distance) .. ' studs';
		end;

		-- Update bounding box if enabled in global axes movements
		if self.Axes == 'Global' and BoundingBox.GetBoundingBox() then
			BoundingBox.GetBoundingBox().CFrame = self.InitialExtentsCFrame + (AxisMultipliers[Face] * Distance);
		end;

	end

	local function OnHandleDragEnd()
		if not self.IsHandleDragging then
			return
		end

		-- Disable dragging
		self.IsHandleDragging = false

		-- Make joints, restore original anchor and collision states
		for Part, State in pairs(self.InitialState) do
			Part:MakeJoints()
			Core.RestoreJoints(State.Joints)
			Part.CanCollide = State.CanCollide
			Part.Anchored = State.Anchored
		end

		-- Register change
		self:RegisterChange()

		-- Resume bounding box updates
		BoundingBox.RecalculateStaticExtents()
		BoundingBox.ResumeMonitoring()
	end

	-- Create the handles
	local Handles = require(Libraries:WaitForChild 'Handles')
	self.Handles = Handles.new({
		Color = self.Color.Color,
		Parent = Core.UIContainer,
		Adornee = Part,
		ObstacleBlacklist = { BoundingBox.GetBoundingBox() },
		OnDragStart = OnHandleDragStart,
		OnDrag = OnHandleDrag,
		OnDragEnd = OnHandleDragEnd
	})

end

function MoveTool:HideHandles()
	-- Hides the resizing handles

	-- Make sure handles exist and are visible
	if not self.Handles then
		return
	end

	-- Hide the handles
	self.Handles = self.Handles:Destroy()

	-- Disable handle autofocus
	self.Maid.AutofocusHandle = nil

end

function MoveTool:MovePartsAlongAxesByFace(Face, Distance, InitialStates, InitialFocusCFrame)
	-- Moves the given parts in `InitialStates`, along the given axis mode, in the given face direction, by the given distance

	-- Calculate the shift along the direction of the face
	local Shift = Vector3.FromNormalId(Face) * Distance

	-- Move along global axes
	if self.Axes == 'Global' then
		for Part, InitialState in pairs(InitialStates) do
			Part.CFrame = InitialState.CFrame + Shift
		end

	-- Move along individual items' axes
	elseif self.Axes == 'Local' then
		for Part, InitialState in pairs(InitialStates) do
			Part.CFrame = InitialState.CFrame * CFrame.new(Shift)
		end

	-- Move along focused item's axes
	elseif self.Axes == 'Last' then

		-- Calculate focused item's position
		local FocusCFrame = InitialFocusCFrame * CFrame.new(Shift)

		-- Move parts based on initial offset from focus
		for Part, InitialState in pairs(InitialStates) do
			local FocusOffset = InitialFocusCFrame:toObjectSpace(InitialState.CFrame)
			Part.CFrame = FocusCFrame * FocusOffset
		end

	end

end

function MoveTool:BindShortcutKeys()
	-- Enables useful shortcut keys for this tool

	-- Track user input while this tool is equipped
	self.Maid.HotkeyStart = UserInputService.InputBegan:Connect(function (InputInfo, GameProcessedEvent)
		if GameProcessedEvent then
			return
		end

		-- Make sure this input is a key press
		if InputInfo.UserInputType ~= Enum.UserInputType.Keyboard then
			return;
		end;

		-- Make sure it wasn't pressed while typing
		if UserInputService:GetFocusedTextBox() then
			return;
		end;

		-- Check if the enter key was pressed
		if InputInfo.KeyCode == Enum.KeyCode.Return or InputInfo.KeyCode == Enum.KeyCode.KeypadEnter then

			-- Toggle the current axis mode
			if self.Axes == 'Global' then
				self:SetAxes('Local')
			elseif self.Axes == 'Local' then
				self:SetAxes('Last')
			elseif self.Axes == 'Last' then
				self:SetAxes('Global')
			end

		-- Check if the - key was pressed
		elseif InputInfo.KeyCode == Enum.KeyCode.Minus or InputInfo.KeyCode == Enum.KeyCode.KeypadMinus then

			-- Focus on the increment input
			if self.UI then
				self.UI.IncrementOption.Increment.TextBox:CaptureFocus();
			end;

		-- Check if the R key was pressed down, and it's not the selection clearing hotkey
		elseif InputInfo.KeyCode == Enum.KeyCode.R and not Selection.Multiselecting then

			-- Start tracking snap points nearest to the mouse
			self:StartSnapping()

		-- Nudge up if the 8 button on the keypad is pressed
		elseif InputInfo.KeyCode == Enum.KeyCode.KeypadEight then
			self:NudgeSelectionByFace(Enum.NormalId.Top)

		-- Nudge down if the 2 button on the keypad is pressed
		elseif InputInfo.KeyCode == Enum.KeyCode.KeypadTwo then
			self:NudgeSelectionByFace(Enum.NormalId.Bottom)

		-- Nudge forward if the 9 button on the keypad is pressed
		elseif InputInfo.KeyCode == Enum.KeyCode.KeypadNine then
			self:NudgeSelectionByFace(Enum.NormalId.Front)

		-- Nudge backward if the 1 button on the keypad is pressed
		elseif InputInfo.KeyCode == Enum.KeyCode.KeypadOne then
			self:NudgeSelectionByFace(Enum.NormalId.Back)

		-- Nudge left if the 4 button on the keypad is pressed
		elseif InputInfo.KeyCode == Enum.KeyCode.KeypadFour then
			self:NudgeSelectionByFace(Enum.NormalId.Left)

		-- Nudge right if the 6 button on the keypad is pressed
		elseif InputInfo.KeyCode == Enum.KeyCode.KeypadSix then
			self:NudgeSelectionByFace(Enum.NormalId.Right)

		-- Align the selection to the current target surface if T is pressed
		elseif InputInfo.KeyCode == Enum.KeyCode.T then
			self:AlignSelectionToTarget()
		end
	end)

	-- Track ending user input while this tool is equipped
	self.Maid.HotkeyRelease = UserInputService.InputEnded:Connect(function (InputInfo, GameProcessedEvent)
		if GameProcessedEvent then
			return
		end

		-- Make sure this is input from the keyboard
		if InputInfo.UserInputType ~= Enum.UserInputType.Keyboard then
			return;
		end;

		-- Check if the R key was let go
		if InputInfo.KeyCode == Enum.KeyCode.R then

			-- Make sure it wasn't pressed while typing
			if UserInputService:GetFocusedTextBox() then
				return;
			end;

			-- Reset handles if not dragging
			if not self.IsFreeDragging then
				self:SetAxes(self.Axes)
			end

			-- Stop snapping point tracking if it was enabled
			SnapTracking.StopTracking();

		end
	end)

end

function MoveTool:StartSnapping()
	-- Starts tracking snap points nearest to the mouse

	-- Hide any handles or bounding boxes
	self:AttachHandles(nil, true)
	BoundingBox.ClearBoundingBox();

	-- Avoid targeting snap points in selected parts while dragging
	if self.IsFreeDragging then
		SnapTracking.TargetBlacklist = Selection.Items;
	end;

	-- Start tracking the closest snapping point
	SnapTracking.StartTracking(function (NewPoint)

		-- Fire `SnappedPoint` and update `SnappedPoint` when there is a new snap point in focus
		if NewPoint then
			self.SnappedPoint = NewPoint.p
			self.PointSnapped:Fire(self.SnappedPoint)
		end

	end)

end

function MoveTool:SetAxisPosition(Axis, Position)
	-- Sets the selection's position on axis `Axis` to `Position`

	-- Track this change
	self:TrackChange()

	-- Prepare parts to be moved
	local InitialStates = PreparePartsForDragging();

	-- Update each part
	for Part in pairs(InitialStates) do

		-- Set the part's new CFrame
		Part.CFrame = CFrame.new(
			Axis == 'X' and Position or Part.Position.X,
			Axis == 'Y' and Position or Part.Position.Y,
			Axis == 'Z' and Position or Part.Position.Z
		) * (Part.CFrame - Part.CFrame.p);

	end;

	-- Cache up permissions for all private areas
	local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Selection.Parts), Core.Player);

	-- Revert changes if player is not authorized to move parts to target destination
	if Core.Mode == 'Tool' and Security.ArePartsViolatingAreas(Selection.Parts, Core.Player, false, AreaPermissions) then
		for Part, State in pairs(InitialStates) do
			Part.CFrame = State.CFrame;
		end;
	end;

	-- Restore the parts' original states
	for Part, State in pairs(InitialStates) do
		Part:MakeJoints();
		Core.RestoreJoints(State.Joints);
		Part.CanCollide = State.CanCollide;
		Part.Anchored = State.Anchored;
	end;

	-- Register the change
	self:RegisterChange()

end

function MoveTool:NudgeSelectionByFace(Face)
	-- Nudges the selection along the current axes mode in the direction of the focused part's face

	-- Get amount to nudge by
	local NudgeAmount = self.Increment

	-- Reverse nudge amount if shift key is held while nudging
	local PressedKeys = Support.FlipTable(Support.GetListMembers(UserInputService:GetKeysPressed(), 'KeyCode'));
	if PressedKeys[Enum.KeyCode.LeftShift] or PressedKeys[Enum.KeyCode.RightShift] then
		NudgeAmount = -NudgeAmount;
	end;

	-- Track this change
	self:TrackChange()

	-- Prepare parts to be moved
	local InitialState, InitialFocusCFrame = PreparePartsForDragging()

	-- Perform the movement
	self:MovePartsAlongAxesByFace(Face, NudgeAmount, InitialState, InitialFocusCFrame)

	-- Update the "distance moved" indicator
	if self.UI then
		self.UI.Changes.Text.Text = 'moved ' .. math.abs(NudgeAmount) .. ' studs'
	end

	-- Cache up permissions for all private areas
	local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Selection.Parts), Core.Player);

	-- Revert changes if player is not authorized to move parts to target destination
	if Core.Mode == 'Tool' and Security.ArePartsViolatingAreas(Selection.Parts, Core.Player, false, AreaPermissions) then
		for Part, State in pairs(InitialState) do
			Part.CFrame = State.CFrame;
		end;
	end;

	-- Restore the parts' original states
	for Part, State in pairs(InitialState) do
		Part:MakeJoints();
		Core.RestoreJoints(State.Joints);
		Part.CanCollide = State.CanCollide;
		Part.Anchored = State.Anchored;
	end;

	-- Register the change
	self:RegisterChange()

end

function MoveTool:TrackChange()

	-- Start the record
	self.HistoryRecord = {
		Parts = Support.CloneTable(Selection.Parts);
		BeforeCFrame = {};
		AfterCFrame = {};
		Selection = Selection.Items;

		Unapply = function (Record)
			-- Reverts this change

			-- Select the changed parts
			Selection.Replace(Record.Selection)

			-- Put together the change request
			local Changes = {};
			for _, Part in pairs(Record.Parts) do
				table.insert(Changes, { Part = Part, CFrame = Record.BeforeCFrame[Part] });
			end;

			-- Send the change request
			Core.SyncAPI:Invoke('SyncMove', Changes);

		end;

		Apply = function (Record)
			-- Applies this change

			-- Select the changed parts
			Selection.Replace(Record.Selection)

			-- Put together the change request
			local Changes = {};
			for _, Part in pairs(Record.Parts) do
				table.insert(Changes, { Part = Part, CFrame = Record.AfterCFrame[Part] });
			end;

			-- Send the change request
			Core.SyncAPI:Invoke('SyncMove', Changes);

		end;

	};

	-- Collect the selection's initial state
	for _, Part in pairs(self.HistoryRecord.Parts) do
		self.HistoryRecord.BeforeCFrame[Part] = Part.CFrame
	end

end

function MoveTool:RegisterChange()
	-- Finishes creating the history record and registers it

	-- Make sure there's an in-progress history record
	if not self.HistoryRecord then
		return
	end

	-- Collect the selection's final state
	local Changes = {};
	for _, Part in pairs(self.HistoryRecord.Parts) do
		self.HistoryRecord.AfterCFrame[Part] = Part.CFrame
		table.insert(Changes, { Part = Part, CFrame = Part.CFrame });
	end;

	-- Send the change to the server
	Core.SyncAPI:Invoke('SyncMove', Changes);

	-- Register the record and clear the staging
	Core.History.Add(self.HistoryRecord)
	self.HistoryRecord = nil

end

function MoveTool:EnableDragging()
	-- Enables part dragging

	local function HandleDragStart(Action, State, Input)
		if State.Name ~= 'Begin' then
			return Enum.ContextActionResult.Pass
		end

		-- Get mouse target
		local TargetPart = Core.Mouse.Target
		if Selection.Multiselecting then
			return Enum.ContextActionResult.Pass
		end

		-- Make sure target is draggable, unless snapping
		local IsSnapping = UserInputService:IsKeyDown(Enum.KeyCode.R) and #Selection.Items > 0
		if not Core.IsSelectable({ TargetPart }) and not IsSnapping then
			return Enum.ContextActionResult.Pass
		end

		-- Initialize dragging detection data
		self.FreeDragStartTarget = TargetPart
		self.FreeDragStartScreenPoint = Vector2.new(Core.Mouse.X, Core.Mouse.Y)

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
			local DragScreenDistance = self.FreeDragStartScreenPoint and
				(Vector2.new(Core.Mouse.X, Core.Mouse.Y) - self.FreeDragStartScreenPoint).Magnitude
			if DragScreenDistance >= 2 then

				-- Prepare for dragging
				BoundingBox.ClearBoundingBox()
				self:SetUpDragging(self.FreeDragStartTarget, SnapTracking.Enabled and self.SnappedPoint or nil)

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

-- Catch whenever the user finishes dragging
Support.AddUserInputListener('Ended', {'Touch', 'MouseButton1'}, true, function (Input)

	-- Clear drag detection data
	MoveTool.FreeDragStartScreenPoint = nil
	MoveTool.FreeDragStartTarget = nil
	ContextActionService:UnbindAction 'BT: Watch for dragging'

	-- Reset from drag mode if dragging
	if MoveTool.IsFreeDragging then

		-- Reset axes
		MoveTool:SetAxes(MoveTool.Axes)

		-- Finalize the dragging operation
		MoveTool:FinishDragging()

	end

end)

function MoveTool:SetUpDragging(BasePart, BasePoint)
	-- Sets up and initiates dragging based on the given base part

	-- Prevent selection while dragging
	Core.Targeting.CancelSelecting();

	-- Prepare parts, and start dragging
	self.InitialState = PreparePartsForDragging()
	self:StartDragging(BasePart, self.InitialState, BasePoint)

end

function PreparePartsForDragging()
	-- Prepares parts for dragging and returns the initial state of the parts

	local InitialState = {};

	-- Get index of parts
	local PartIndex = Support.FlipTable(Selection.Parts)

	-- Stop parts from moving, and capture the initial state of the parts
	for _, Part in pairs(Selection.Parts) do
		InitialState[Part] = { Anchored = Part.Anchored, CanCollide = Part.CanCollide, CFrame = Part.CFrame };
		Part.Anchored = true;
		Part.CanCollide = false;
		InitialState[Part].Joints = Core.PreserveJoints(Part, PartIndex);
		Part:BreakJoints();
		Part.Velocity = Vector3.new();
		Part.RotVelocity = Vector3.new();
	end;

	-- Get initial state of focused item
	local InitialFocusCFrame
	local Focus = Selection.Focus
	if Focus:IsA 'BasePart' then
		InitialFocusCFrame = Focus.CFrame
	elseif Focus:IsA 'Model' then
		InitialFocusCFrame = Focus:GetModelCFrame()
	end

	return InitialState, InitialFocusCFrame
end;

function MoveTool:StartDragging(BasePart, InitialState, BasePoint)
	-- Begins dragging the selection

	-- Ensure dragging is not already ongoing
	if self.IsFreeDragging then
		return
	end

	-- Indicate that we're dragging
	self.IsFreeDragging = true

	-- Track changes
	self:TrackChange()

	-- Disable bounding box calculation
	BoundingBox.ClearBoundingBox();

	-- Cache area permissions information
	local AreaPermissions;
	if Core.Mode == 'Tool' then
		AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Selection.Parts), Core.Player);
	end;

	-- Ensure a base part is provided
	if not InitialState[BasePart] then
		BasePart = next(InitialState)
		if not BasePart then
			return
		end
	end

	-- Determine the base point for dragging
	local BasePartOffset = -BasePart.CFrame:pointToObjectSpace(Core.Mouse.Hit.p);

	-- Improve base point alignment for the given increment
	BasePartOffset = Vector3.new(
		math.clamp(GetIncrementMultiple(BasePartOffset.X, self.Increment), -BasePart.Size.X / 2, BasePart.Size.X / 2),
		math.clamp(GetIncrementMultiple(BasePartOffset.Y, self.Increment), -BasePart.Size.Y / 2, BasePart.Size.Y / 2),
		math.clamp(GetIncrementMultiple(BasePartOffset.Z, self.Increment), -BasePart.Size.Z / 2, BasePart.Size.Z / 2)
	)

	-- Use the given base point instead if any
	if BasePoint then
		BasePartOffset = -BasePart.CFrame:pointToObjectSpace(BasePoint);
	end;

	-- Prepare snapping in case it is enabled, and make sure to override its default target selection
	SnapTracking.TargetBlacklist = Selection.Items;
	self.Maid.DragSnapping = self.PointSnapped:Connect(function (SnappedPoint)

		-- Align the selection's base point to the snapped point
		local Rotation = self.SurfaceAlignment or (InitialState[BasePart].CFrame - InitialState[BasePart].CFrame.p)
		BasePart.CFrame = CFrame.new(SnappedPoint) * Rotation * CFrame.new(BasePartOffset);
		TranslatePartsRelativeToPart(BasePart, InitialState);

		-- Make sure we're not entering any unauthorized private areas
		if Core.Mode == 'Tool' and Security.ArePartsViolatingAreas(Selection.Parts, Core.Player, false, AreaPermissions) then
			BasePart.CFrame = InitialState[BasePart].CFrame;
			TranslatePartsRelativeToPart(BasePart, InitialState);
		end;

	end)

	-- Update cache of corner offsets for later crossthrough calculations
	self.CornerOffsets = GetCornerOffsets(InitialState[BasePart].CFrame, InitialState)

	-- Provide a callback to trigger alignment
	self.TriggerAlignment = function ()

		-- Trigger drag recalculation
		self:DragToMouse(BasePart, BasePartOffset, InitialState, AreaPermissions);

		-- Trigger snapping recalculation
		if SnapTracking.Enabled then
			self.PointSnapped:Fire(self.SnappedPoint)
		end

	end

	local function HandleDragChange(Action, State, Input)
		if State.Name == 'Change' then
			self:DragToMouse(BasePart, BasePartOffset, InitialState, AreaPermissions)
		end
		return Enum.ContextActionResult.Pass
	end

	-- Start up the dragging
	ContextActionService:BindAction('BT: Dragging', HandleDragChange, false,
		Enum.UserInputType.MouseMovement,
		Enum.UserInputType.Touch
	)

end

-- Cache common functions to avoid unnecessary table lookups
local TableInsert, NewVector3 = table.insert, Vector3.new;

function GetCornerOffsets(Origin, InitialStates)
	-- Calculates and returns the offset of every corner in the initial state from the origin CFrame

	local CornerOffsets = {};

	-- Get offset for origin point
	local OriginOffset = Origin:inverse();

	-- Go through each item in the initial state
	for Item, State in pairs(InitialStates) do
		local ItemCFrame = State.CFrame;
		local SizeX, SizeY, SizeZ = Item.Size.X / 2, Item.Size.Y / 2, Item.Size.Z / 2;

		-- Gather each corner
		TableInsert(CornerOffsets, OriginOffset * (ItemCFrame * NewVector3(SizeX, SizeY, SizeZ)));
		TableInsert(CornerOffsets, OriginOffset * (ItemCFrame * NewVector3(-SizeX, SizeY, SizeZ)));
		TableInsert(CornerOffsets, OriginOffset * (ItemCFrame * NewVector3(SizeX, -SizeY, SizeZ)));
		TableInsert(CornerOffsets, OriginOffset * (ItemCFrame * NewVector3(SizeX, SizeY, -SizeZ)));
		TableInsert(CornerOffsets, OriginOffset * (ItemCFrame * NewVector3(-SizeX, SizeY, -SizeZ)));
		TableInsert(CornerOffsets, OriginOffset * (ItemCFrame * NewVector3(-SizeX, -SizeY, SizeZ)));
		TableInsert(CornerOffsets, OriginOffset * (ItemCFrame * NewVector3(SizeX, -SizeY, -SizeZ)));
		TableInsert(CornerOffsets, OriginOffset * (ItemCFrame * NewVector3(-SizeX, -SizeY, -SizeZ)));
	end;

	-- Return the offsets
	return CornerOffsets;

end;

function MoveTool:DragToMouse(BasePart, BasePartOffset, InitialState, AreaPermissions)
	-- Drags the selection by `BasePart`, judging area authorization from `AreaPermissions`

	----------------------------------------------
	-- Check what and where the mouse is aiming at
	----------------------------------------------

	-- Don't consider other selected parts possible targets
	local IgnoreList = Support.CloneTable(Selection.Items);
	table.insert(IgnoreList, Core.Player and Core.Player.Character);

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
		return;
	end;

	------------------------------------------------------
	-- Move the selection towards the right mouse location
	------------------------------------------------------

	-- Get the increment-aligned target point
	self.TargetPoint = GetAlignedTargetPoint(
		self.Target,
		self.TargetPoint,
		self.TargetNormal,
		self.Increment
	)

	-- Move the parts towards their target destination
	local Rotation = self.SurfaceAlignment or (InitialState[BasePart].CFrame - InitialState[BasePart].CFrame.p);
	local TargetCFrame = CFrame.new(self.TargetPoint) * Rotation * CFrame.new(BasePartOffset);

	-- Calculate crossthrough against target plane if necessary
	if not self.CrossthroughCorrection then
		self.CrossthroughCorrection = 0

		-- Calculate each corner's tentative position
		for _, CornerOffset in pairs(self.CornerOffsets) do
			local Corner = TargetCFrame * CornerOffset;

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
	TranslatePartsRelativeToPart(BasePart, InitialState);

	----------------------------------------
	-- Check for relevant area authorization
	----------------------------------------

	-- Make sure we're not entering any unauthorized private areas
	if Core.Mode == 'Tool' and Security.ArePartsViolatingAreas(Selection.Parts, Core.Player, false, AreaPermissions) then
		BasePart.CFrame = InitialState[BasePart].CFrame;
		TranslatePartsRelativeToPart(BasePart, InitialState);
	end;

end

function MoveTool:AlignSelectionToTarget()
	-- Aligns the selection to the current target surface while dragging

	-- Ensure dragging is ongoing
	if not self.IsFreeDragging or not self.TargetNormal then
		return;
	end;

	-- Get target surface normal as arbitrarily oriented CFrame
	local TargetNormalCF = CFrame.new(Vector3.new(), self.TargetNormal);

	-- Use detected surface normal directly if not targeting a part
	if not self.Target then
		self.SurfaceAlignment = TargetNormalCF * CFrame.Angles(-math.pi / 2, 0, 0)

	-- For parts, calculate orientation based on the target surface, and the target part's orientation
	else

		-- Set upward direction to match the target surface normal
		local UpVector, LookVector, RightVector = self.TargetNormal;

		-- Use target's rightward orientation for calculating orientation (when targeting forward or backward directions)
		local Target, TargetNormal = self.Target, self.TargetNormal
		if TargetNormal:isClose(Target.CFrame.lookVector, 0.000001) or TargetNormal:isClose(-Target.CFrame.lookVector, 0.000001) then
			LookVector = TargetNormal:Cross(Target.CFrame.rightVector).unit;
			RightVector = LookVector:Cross(TargetNormal).unit;

		-- Use target's forward orientation for calculating orientation (when targeting any other direction)
		else
			RightVector = Target.CFrame.lookVector:Cross(TargetNormal).unit;
			LookVector = TargetNormal:Cross(RightVector).unit;
		end;

		-- Generate rotation matrix based on direction vectors
		self.SurfaceAlignment = CFrame.new(
			0, 0, 0,
			RightVector.X, UpVector.X, -LookVector.X,
			RightVector.Y, UpVector.Y, -LookVector.Y,
			RightVector.Z, UpVector.Z, -LookVector.Z
		)

	end;

	-- Trigger alignment
	self:TriggerAlignment()

end

function GetAlignedTargetPoint(Target, TargetPoint, TargetNormal, Increment)
	-- Returns the target point aligned to the nearest increment multiple

	-- By default, use the center of the universe for alignment on all axes
	local ReferencePoint = CFrame.new();
	local PlaneAxes = Vector3.new(1, 1, 1);

	-----------------------------------------------------------------------------
	-- Detect appropriate reference points and plane axes for recognized surfaces
	-----------------------------------------------------------------------------

	-- Make sure the target is a part
	if Target and Target:IsA 'BasePart' and Target.ClassName ~= 'Terrain' then
		local Size = Target.Size / 2;

		-- Calculate the direction of a wedge surface
		local WedgeDirection = (Target.CFrame - Target.CFrame.p) *
			CFrame.fromAxisAngle(Vector3.FromAxis(Enum.Axis.X), math.atan(Target.Size.Z / Target.Size.Y));

		-- Calculate the direction of a corner part's Z-axis surface
		local CornerDirectionZ = (Target.CFrame - Target.CFrame.p) *
			CFrame.fromAxisAngle(Vector3.FromAxis(Enum.Axis.X), math.pi - math.atan(Target.Size.Z / Target.Size.Y));

		-- Calculate the direction of a corner part's X-axis surface
		local CornerDirectionX = (Target.CFrame - Target.CFrame.p) *
			CFrame.fromAxisAngle(Vector3.FromAxis(Enum.Axis.Z), math.atan(Target.Size.Y / Target.Size.X)) *
			CFrame.fromAxisAngle(Vector3.FromAxis(Enum.Axis.X), math.pi / 2) *
			CFrame.fromAxisAngle(Vector3.FromAxis(Enum.Axis.Z), -math.pi / 2);

		-- Get the right alignment reference point on a part's front surface
		if TargetNormal:isClose(Target.CFrame.lookVector, 0.000001) then
			ReferencePoint = Target.CFrame * CFrame.new(Size.X, Size.Y, -Size.Z);
			PlaneAxes = Vector3.new(1, 1, 0);

		-- Get the right alignment reference point on a part's back surface
		elseif TargetNormal:isClose(-Target.CFrame.lookVector, 0.000001) then
			ReferencePoint = Target.CFrame * CFrame.new(-Size.X, Size.Y, Size.Z);
			PlaneAxes = Vector3.new(1, 1, 0);

		-- Get the right alignment reference point on a part's left surface
		elseif TargetNormal:isClose(-Target.CFrame.rightVector, 0.000001) then
			ReferencePoint = Target.CFrame * CFrame.new(-Size.X, Size.Y, -Size.Z);
			PlaneAxes = Vector3.new(0, 1, 1);

		-- Get the right alignment reference point on a part's right surface
		elseif TargetNormal:isClose(Target.CFrame.rightVector, 0.000001) then
			ReferencePoint = Target.CFrame * CFrame.new(Size.X, Size.Y, Size.Z);
			PlaneAxes = Vector3.new(0, 1, 1);

		-- Get the right alignment reference point on a part's upper surface
		elseif TargetNormal:isClose(Target.CFrame.upVector, 0.000001) then
			ReferencePoint = Target.CFrame * CFrame.new(Size.X, Size.Y, Size.Z);
			PlaneAxes = Vector3.new(1, 0, 1);

		-- Get the right alignment reference point on a part's bottom surface
		elseif TargetNormal:isClose(-Target.CFrame.upVector, 0.000001) then
			ReferencePoint = Target.CFrame * CFrame.new(Size.X, -Size.Y, -Size.Z);
			PlaneAxes = Vector3.new(1, 0, 1);

		-- Get the right alignment reference point on wedged part surfaces
		elseif TargetNormal:isClose(WedgeDirection.lookVector, 0.000001) then

			-- Get reference point oriented to wedge plane
			ReferencePoint = WedgeDirection *
				CFrame.fromAxisAngle(Vector3.FromAxis(Enum.Axis.X), -math.pi / 2) +
				(Target.CFrame * Vector3.new(Size.X, Size.Y, Size.Z));

			-- Set plane offset axes
			PlaneAxes = Vector3.new(1, 0, 1);

		-- Get the right alignment reference point on the Z-axis surface of a corner part
		elseif TargetNormal:isClose(CornerDirectionZ.lookVector, 0.000001) then

			-- Get reference point oriented to wedged plane
			ReferencePoint = CornerDirectionZ *
				CFrame.fromAxisAngle(Vector3.FromAxis(Enum.Axis.X), -math.pi / 2) +
				(Target.CFrame * Vector3.new(-Size.X, Size.Y, -Size.Z));

			-- Set plane offset axes
			PlaneAxes = Vector3.new(1, 0, 1);

		-- Get the right alignment reference point on the X-axis surface of a corner part
		elseif TargetNormal:isClose(CornerDirectionX.lookVector, 0.000001) then

			-- Get reference point oriented to wedged plane
			ReferencePoint = CornerDirectionX *
				CFrame.fromAxisAngle(Vector3.FromAxis(Enum.Axis.X), -math.pi / 2) +
				(Target.CFrame * Vector3.new(Size.X, Size.Y, -Size.Z));

			-- Set plane offset axes
			PlaneAxes = Vector3.new(1, 0, 1);

		-- Return an unaligned point for unrecognized surfaces
		else
			return TargetPoint;
		end;

	end;

	-------------------------------------
	-- Calculate the aligned target point
	-------------------------------------

	-- Get target point offset from reference point
	local ReferencePointOffset = ReferencePoint:inverse() * CFrame.new(TargetPoint);

	-- Align target point on increment grid from reference point along the plane axes
	local AlignedTargetPoint = ReferencePoint * (Vector3.new(
		GetIncrementMultiple(ReferencePointOffset.X, Increment),
		GetIncrementMultiple(ReferencePointOffset.Y, Increment),
		GetIncrementMultiple(ReferencePointOffset.Z, Increment)
	) * PlaneAxes)

	-- Return the aligned target point
	return AlignedTargetPoint;

end

function GetIncrementMultiple(Number, Increment)

	-- Get how far the actual distance is from a multiple of our increment
	local MultipleDifference = Number % Increment;

	-- Identify the closest lower and upper multiples of the increment
	local LowerMultiple = Number - MultipleDifference;
	local UpperMultiple = Number - MultipleDifference + Increment;

	-- Calculate to which of the two multiples we're closer
	local LowerMultipleProximity = math.abs(Number - LowerMultiple);
	local UpperMultipleProximity = math.abs(Number - UpperMultiple);

	-- Use the closest multiple of our increment as the distance moved
	if LowerMultipleProximity <= UpperMultipleProximity then
		Number = LowerMultiple;
	else
		Number = UpperMultiple;
	end;

	return Number;
end;

function TranslatePartsRelativeToPart(BasePart, InitialStates)
	-- Moves the given parts in `InitialStates` to BasePart's current position, with their original offset from it

	-- Get focused part's position for offsetting
	local RelativeTo = InitialStates[BasePart].CFrame:inverse();

	-- Calculate offset and move each part
	for Part, InitialState in pairs(InitialStates) do

		-- Calculate how far apart we should be from the focused part
		local Offset = RelativeTo * InitialState.CFrame;

		-- Move relative to the focused part by this part's offset from it
		Part.CFrame = BasePart.CFrame * Offset;

	end;

end;

function MoveTool:FinishDragging()
	-- Releases parts and registers position changes from dragging

	-- Make sure dragging is active
	if not self.IsFreeDragging then
		return;
	end;

	-- Indicate that we're no longer dragging
	self.IsFreeDragging = false

	-- Clear any surface alignment
	self.SurfaceAlignment = nil

	-- Stop the dragging action
	ContextActionService:UnbindAction 'BT: Dragging';

	-- Stop, clean up snapping point tracking
	SnapTracking.StopTracking();
	self.Maid.DragSnapping = nil

	-- Restore the original state of each part
	for Part, State in pairs(self.InitialState) do
		Part:MakeJoints();
		Core.RestoreJoints(State.Joints);
		Part.CanCollide = State.CanCollide;
		Part.Anchored = State.Anchored;
	end;

	-- Register changes
	self:RegisterChange()

end

-- Return the tool
return MoveTool;