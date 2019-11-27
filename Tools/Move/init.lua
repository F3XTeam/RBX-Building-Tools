local Tool = script.Parent.Parent
local Core = require(Tool.Core)
local SnapTracking = require(Tool.Core.Snapping)
local BoundingBox = require(Tool.Core.BoundingBox)

-- Services
local ContextActionService = game:GetService 'ContextActionService'
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

	-- Signals
	DragChanged = Signal.new();
	AxesChanged = Signal.new();
}

-- Initialize tool subsystems
MoveTool.HandleDragging = require(script:WaitForChild 'HandleDragging')
	.new(MoveTool)
MoveTool.FreeDragging = require(script:WaitForChild 'FreeDragging')
	.new(MoveTool)
MoveTool.UIController = require(script:WaitForChild 'UIController')
	.new(MoveTool)

function MoveTool:Equip()
	-- Enables the tool's equipped functionality

	-- Set our current axis mode
	self:SetAxes(self.Axes)

	-- Start up our interface
	self.UIController:ShowUI()
	self:BindShortcutKeys()
	self.FreeDragging:EnableDragging()

end

function MoveTool:Unequip()
	-- Disables the tool's equipped functionality

	-- If dragging, finish dragging
	if self.FreeDragging.IsDragging then
		self.FreeDragging:FinishDragging()
	end

	-- Disable dragging
	ContextActionService:UnbindAction 'BT: Start dragging'

	-- Clear unnecessary resources
	self.UIController:HideUI()
	self.HandleDragging:HideHandles()
	self.Maid:Destroy()
	BoundingBox.ClearBoundingBox();
	SnapTracking.StopTracking();

end

function MoveTool:SetAxes(AxisMode)
	-- Sets the given axis mode

	-- Update setting
	self.Axes = AxisMode
	self.AxesChanged:Fire(self.Axes)

	-- Disable any unnecessary bounding boxes
	BoundingBox.ClearBoundingBox();

	-- For global mode, use bounding box handles
	if AxisMode == 'Global' then
		BoundingBox.StartBoundingBox(function (BoundingBox)
			self.HandleDragging:AttachHandles(BoundingBox)
		end)

	-- For local mode, use focused part handles
	elseif AxisMode == 'Local' then
		self.HandleDragging:AttachHandles(Selection.Focus, true)

	-- For last mode, use focused part handles
	elseif AxisMode == 'Last' then
		self.HandleDragging:AttachHandles(Selection.Focus, true)
	end

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

		-- If - key was pressed, focus on increment input
		elseif (InputInfo.KeyCode.Name == 'Minus') or (InputInfo.KeyCode.Name == 'KeypadMinus') then
			self.UIController:FocusIncrementInput()

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
		elseif (InputInfo.KeyCode == Enum.KeyCode.T) and (not Selection.Multiselecting) then
			self.FreeDragging:AlignSelectionToTarget()
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
			if not self.FreeDragging.IsDragging then
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
	self.HandleDragging:AttachHandles(nil, true)
	BoundingBox.ClearBoundingBox();

	-- Avoid targeting snap points in selected parts while dragging
	if self.FreeDragging.IsDragging then
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
	local InitialStates = self:PreparePartsForDragging()

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
	local InitialState, InitialFocusCFrame = self:PreparePartsForDragging()

	-- Perform the movement
	self:MovePartsAlongAxesByFace(Face, NudgeAmount, InitialState, InitialFocusCFrame)

	-- Indicate updated drag distance
	self.DragChanged:Fire(NudgeAmount)

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

function MoveTool:PreparePartsForDragging()
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
	if not Focus then
		InitialFocusCFrame = nil
	elseif Focus:IsA 'BasePart' then
		InitialFocusCFrame = Focus.CFrame
	elseif Focus:IsA 'Model' then
		InitialFocusCFrame = Focus:GetModelCFrame()
	end

	return InitialState, InitialFocusCFrame
end;

-- Return the tool
return MoveTool;