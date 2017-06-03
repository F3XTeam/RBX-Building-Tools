Tool = script.Parent.Parent;
Core = require(Tool.Core);
SnapTracking = require(Tool.SnappingModule);
BoundingBox = require(Tool.BoundingBoxModule);

-- Import relevant references
Selection = Core.Selection;
Create = Core.Create;
Support = Core.Support;
Security = Core.Security;
Support.ImportServices();

-- Initialize the tool
local MoveTool = {

	Name = 'Move Tool';
	Color = BrickColor.new 'Deep orange';

	-- Default options
	Increment = 1;
	Axes = 'Global';

};

-- Container for temporary connections (disconnected automatically)
local Connections = {};

function MoveTool.Equip()
	-- Enables the tool's equipped functionality

	-- Set our current axis mode
	SetAxes(MoveTool.Axes);

	-- Start up our interface
	ShowUI();
	BindShortcutKeys();
	EnableDragging();

end;

function MoveTool.Unequip()
	-- Disables the tool's equipped functionality

	-- If dragging, finish dragging
	if Dragging then
		FinishDragging();
	end;

	-- Clear unnecessary resources
	HideUI();
	HideHandles();
	ClearConnections();
	BoundingBox.ClearBoundingBox();
	SnapTracking.StopTracking();

end;

function ClearConnections()
	-- Clears out temporary connections

	for ConnectionKey, Connection in pairs(Connections) do
		Connection:disconnect();
		Connections[ConnectionKey] = nil;
	end;

end;

function ClearConnection(ConnectionKey)
	-- Clears the given specific connection

	local Connection = Connections[ConnectionKey];

	-- Disconnect the connection if it exists
	if Connections[ConnectionKey] then
		Connection:disconnect();
		Connections[ConnectionKey] = nil;
	end;

end;

function ShowUI()
	-- Creates and reveals the UI

	-- Reveal UI if already created
	if MoveTool.UI then

		-- Reveal the UI
		MoveTool.UI.Visible = true;

		-- Update the UI every 0.1 seconds
		UIUpdater = Support.ScheduleRecurringTask(UpdateUI, 0.1);

		-- Skip UI creation
		return;

	end;

	-- Create the UI
	MoveTool.UI = Core.Tool.Interfaces.BTMoveToolGUI:Clone();
	MoveTool.UI.Parent = Core.UI;
	MoveTool.UI.Visible = true;

	-- Add functionality to the axes option switch
	local AxesSwitch = MoveTool.UI.AxesOption;
	AxesSwitch.Global.Button.MouseButton1Down:connect(function ()
		SetAxes('Global');
	end);
	AxesSwitch.Local.Button.MouseButton1Down:connect(function ()
		SetAxes('Local');
	end);
	AxesSwitch.Last.Button.MouseButton1Down:connect(function ()
		SetAxes('Last');
	end);

	-- Add functionality to the increment input
	local IncrementInput = MoveTool.UI.IncrementOption.Increment.TextBox;
	IncrementInput.FocusLost:connect(function (EnterPressed)
		MoveTool.Increment = tonumber(IncrementInput.Text) or MoveTool.Increment;
		IncrementInput.Text = Support.Round(MoveTool.Increment, 4);
	end);

	-- Add functionality to the position inputs
	local XInput = MoveTool.UI.Info.Center.X.TextBox;
	local YInput = MoveTool.UI.Info.Center.Y.TextBox;
	local ZInput = MoveTool.UI.Info.Center.Z.TextBox;
	XInput.FocusLost:connect(function (EnterPressed)
		local NewPosition = tonumber(XInput.Text);
		if NewPosition then
			SetAxisPosition('X', NewPosition);
		end;
	end);
	YInput.FocusLost:connect(function (EnterPressed)
		local NewPosition = tonumber(YInput.Text);
		if NewPosition then
			SetAxisPosition('Y', NewPosition);
		end;
	end);
	ZInput.FocusLost:connect(function (EnterPressed)
		local NewPosition = tonumber(ZInput.Text);
		if NewPosition then
			SetAxisPosition('Z', NewPosition);
		end;
	end);

	-- Update the UI every 0.1 seconds
	UIUpdater = Support.ScheduleRecurringTask(UpdateUI, 0.1);

end;

function HideUI()
	-- Hides the tool UI

	-- Make sure there's a UI
	if not MoveTool.UI then
		return;
	end;

	-- Hide the UI
	MoveTool.UI.Visible = false;

	-- Stop updating the UI
	UIUpdater:Stop();

end;

function UpdateUI()
	-- Updates information on the UI

	-- Make sure the UI's on
	if not MoveTool.UI then
		return;
	end;

	-- Only show and calculate selection info if it's not empty
	if #Selection.Items == 0 then
		MoveTool.UI.Info.Visible = false;
		MoveTool.UI.Size = UDim2.new(0, 245, 0, 90);
		return;
	else
		MoveTool.UI.Info.Visible = true;
		MoveTool.UI.Size = UDim2.new(0, 245, 0, 150);
	end;

	---------------------------------------------
	-- Update the position information indicators
	---------------------------------------------

	-- Identify common positions across axes
	local XVariations, YVariations, ZVariations = {}, {}, {};
	for _, Part in pairs(Selection.Items) do
		table.insert(XVariations, Support.Round(Part.Position.X, 3));
		table.insert(YVariations, Support.Round(Part.Position.Y, 3));
		table.insert(ZVariations, Support.Round(Part.Position.Z, 3));
	end;
	local CommonX = Support.IdentifyCommonItem(XVariations);
	local CommonY = Support.IdentifyCommonItem(YVariations);
	local CommonZ = Support.IdentifyCommonItem(ZVariations);

	-- Shortcuts to indicators
	local XIndicator = MoveTool.UI.Info.Center.X.TextBox;
	local YIndicator = MoveTool.UI.Info.Center.Y.TextBox;
	local ZIndicator = MoveTool.UI.Info.Center.Z.TextBox;

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

end;

function SetAxes(AxisMode)
	-- Sets the given axis mode

	-- Update setting
	MoveTool.Axes = AxisMode;

	-- Update the UI switch
	if MoveTool.UI then
		Core.ToggleSwitch(AxisMode, MoveTool.UI.AxesOption);
	end;

	-- Disable any unnecessary bounding boxes
	BoundingBox.ClearBoundingBox();

	-- For global mode, use bounding box handles
	if AxisMode == 'Global' then
		BoundingBox.StartBoundingBox(AttachHandles);

	-- For local mode, use focused part handles
	elseif AxisMode == 'Local' then
		AttachHandles(Selection.Focus, true); 

	-- For last mode, use focused part handles
	elseif AxisMode == 'Last' then
		AttachHandles(Selection.Focus, true);
	end;

end;

local Handles;

-- Directions of movement for each handle's dragged face
local AxisMultipliers = {
	[Enum.NormalId.Top] = Vector3.new(0, 1, 0);
	[Enum.NormalId.Bottom] = Vector3.new(0, -1, 0);
	[Enum.NormalId.Front] = Vector3.new(0, 0, -1);
	[Enum.NormalId.Back] = Vector3.new(0, 0, 1);
	[Enum.NormalId.Left] = Vector3.new(-1, 0, 0);
	[Enum.NormalId.Right] = Vector3.new(1, 0, 0);
};

function AttachHandles(Part, Autofocus)
	-- Creates and attaches handles to `Part`, and optionally automatically attaches to the focused part

	-- Enable autofocus if requested and not already on
	if Autofocus and not Connections.AutofocusHandle then
		Connections.AutofocusHandle = Selection.FocusChanged:connect(function ()
			Handles.Adornee = Selection.Focus;
		end);

	-- Disable autofocus if not requested and on
	elseif not Autofocus and Connections.AutofocusHandle then
		ClearConnection 'AutofocusHandle';
	end;

	-- Just attach and show the handles if they already exist
	if Handles then
		Handles.Adornee = Part;
		Handles.Visible = true;
		Handles.Parent = Part and Core.UIContainer or nil;
		return;
	end;

	-- Create the handles
	Handles = Create 'Handles' {
		Name = 'BTMovementHandles';
		Color = MoveTool.Color;
		Parent = Core.UIContainer;
		Adornee = Part;
	};

	------------------------------------------------------
	-- Prepare for moving parts when the handle is clicked
	------------------------------------------------------

	local AreaPermissions;

	Handles.MouseButton1Down:connect(function ()

		-- Prevent selection
		Core.Targeting.CancelSelecting();

		-- Indicate dragging via handles
		HandleDragging = true;

		-- Freeze bounding box extents while dragging
		if BoundingBox.GetBoundingBox() then
			InitialExtentsSize, InitialExtentsCFrame = BoundingBox.CalculateExtents(Core.Selection.Items, BoundingBox.StaticExtents);
			BoundingBox.PauseMonitoring();
		end;

		-- Stop parts from moving, and capture the initial state of the parts
		InitialState = PreparePartsForDragging();

		-- Track the change
		TrackChange();

		-- Cache area permissions information
		if Core.Mode == 'Tool' then
			AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Selection.Items), Core.Player);
		end;

	end);

	------------------------------------------
	-- Update parts when the handles are moved
	------------------------------------------

	Handles.MouseDrag:connect(function (Face, Distance)

		-- Only drag if handle is enabled
		if not HandleDragging then
			return;
		end;

		-- Calculate the increment-aligned drag distance
		Distance = GetIncrementMultiple(Distance, MoveTool.Increment);

		-- Move the parts along the selected axes by the calculated distance
		MovePartsAlongAxesByFace(Face, Distance, MoveTool.Axes, Selection.Focus, InitialState);

		-- Make sure we're not entering any unauthorized private areas
		if Core.Mode == 'Tool' and Security.ArePartsViolatingAreas(Selection.Items, Core.Player, false, AreaPermissions) then
			Selection.Focus.CFrame = InitialState[Selection.Focus].CFrame;
			TranslatePartsRelativeToPart(Selection.Focus, InitialState);
			Distance = 0;
		end;

		-- Update the "distance moved" indicator
		if MoveTool.UI then
			MoveTool.UI.Changes.Text.Text = 'moved ' .. math.abs(Distance) .. ' studs';
		end;

		-- Update bounding box if enabled in global axes movements
		if MoveTool.Axes == 'Global' and BoundingBox.GetBoundingBox() then
			BoundingBox.GetBoundingBox().CFrame = InitialExtentsCFrame + (AxisMultipliers[Face] * Distance);
		end;

	end);

end;

-- Finalize changes to parts when the handle is let go
Support.AddUserInputListener('Ended', 'MouseButton1', true, function (Input)

	-- Ensure handle dragging is ongoing
	if not HandleDragging then
		return;
	end;

	-- Disable dragging
	HandleDragging = false;

	-- Clear this connection to prevent it from firing again
	ClearConnection 'HandleRelease';

	-- Make joints, restore original anchor and collision states
	for Part, State in pairs(InitialState) do
		Part:MakeJoints();
		Core.RestoreJoints(State.Joints);
		Part.CanCollide = State.CanCollide;
		Part.Anchored = State.Anchored;
	end;

	-- Register the change
	RegisterChange();

	-- Resume normal bounding box updating
	BoundingBox.RecalculateStaticExtents();
	BoundingBox.ResumeMonitoring();

end);

function HideHandles()
	-- Hides the resizing handles

	-- Make sure handles exist and are visible
	if not Handles or not Handles.Visible then
		return;
	end;

	-- Hide the handles
	Handles.Visible = false;
	Handles.Parent = nil;

	-- Disable handle autofocus
	ClearConnection 'AutofocusHandle';

end;

function MovePartsAlongAxesByFace(Face, Distance, Axes, BasePart, InitialStates)
	-- Moves the given parts in `InitialStates`, along the given axis mode, in the given face direction, by the given distance

	-- Get the axis multiplier for this face
	local AxisMultiplier = AxisMultipliers[Face];

	-- Get starting state for `BasePart`
	local InitialBasePartState = InitialStates[BasePart];

	-- Move each part
	for Part, InitialState in pairs(InitialStates) do

		-- Move along standard axes
		if Axes == 'Global' then
			Part.CFrame = InitialState.CFrame + (Distance * AxisMultiplier);

		-- Move along item's axes
		elseif Axes == 'Local' then
			Part.CFrame = InitialState.CFrame * CFrame.new(Distance * AxisMultiplier);

		-- Move along focused part's axes
		elseif Axes == 'Last' then

			-- Calculate the focused part's position
			local RelativeTo = InitialBasePartState.CFrame * CFrame.new(Distance * AxisMultiplier);

			-- Calculate how far apart we should be from the focused part
			local Offset = InitialBasePartState.CFrame:toObjectSpace(InitialState.CFrame);

			-- Move relative to the focused part by this part's offset from it
			Part.CFrame = RelativeTo * Offset;

		end;

	end;

end;

function BindShortcutKeys()
	-- Enables useful shortcut keys for this tool

	-- Track user input while this tool is equipped
	table.insert(Connections, UserInputService.InputBegan:connect(function (InputInfo, GameProcessedEvent)

		-- Make sure this is an intentional event
		if GameProcessedEvent then
			return;
		end;

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
			if MoveTool.Axes == 'Global' then
				SetAxes('Local');

			elseif MoveTool.Axes == 'Local' then
				SetAxes('Last');

			elseif MoveTool.Axes == 'Last' then
				SetAxes('Global');
			end;

		-- Check if the - key was pressed
		elseif InputInfo.KeyCode == Enum.KeyCode.Minus or InputInfo.KeyCode == Enum.KeyCode.KeypadMinus then

			-- Focus on the increment input
			if MoveTool.UI then
				MoveTool.UI.IncrementOption.Increment.TextBox:CaptureFocus();
			end;

		-- Check if the R key was pressed down, and it's not the selection clearing hotkey
		elseif InputInfo.KeyCode == Enum.KeyCode.R and not Selection.Multiselecting then

			-- Start tracking snap points nearest to the mouse
			StartSnapping();

		-- Nudge up if the 8 button on the keypad is pressed
		elseif InputInfo.KeyCode == Enum.KeyCode.KeypadEight then
			NudgeSelectionByFace(Enum.NormalId.Top);

		-- Nudge down if the 2 button on the keypad is pressed
		elseif InputInfo.KeyCode == Enum.KeyCode.KeypadTwo then
			NudgeSelectionByFace(Enum.NormalId.Bottom);

		-- Nudge forward if the 9 button on the keypad is pressed
		elseif InputInfo.KeyCode == Enum.KeyCode.KeypadNine then
			NudgeSelectionByFace(Enum.NormalId.Front);

		-- Nudge backward if the 1 button on the keypad is pressed
		elseif InputInfo.KeyCode == Enum.KeyCode.KeypadOne then
			NudgeSelectionByFace(Enum.NormalId.Back);

		-- Nudge left if the 4 button on the keypad is pressed
		elseif InputInfo.KeyCode == Enum.KeyCode.KeypadFour then
			NudgeSelectionByFace(Enum.NormalId.Left);

		-- Nudge right if the 6 button on the keypad is pressed
		elseif InputInfo.KeyCode == Enum.KeyCode.KeypadSix then
			NudgeSelectionByFace(Enum.NormalId.Right);

		-- Align the selection to the current target surface if T is pressed
		elseif InputInfo.KeyCode == Enum.KeyCode.T then
			AlignSelectionToTarget();

		end;

	end));

	-- Track ending user input while this tool is equipped
	table.insert(Connections, UserInputService.InputEnded:connect(function (InputInfo, GameProcessedEvent)

		-- Make sure this is an intentional event
		if GameProcessedEvent then
			return;
		end;

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
			if not Dragging then
				SetAxes(MoveTool.Axes);
			end;

			-- Stop snapping point tracking if it was enabled
			SnapTracking.StopTracking();

		end;

	end));

end;

-- Event that fires when new point comes into focus while snapping
local PointSnapped = Core.RbxUtility.CreateSignal();

function StartSnapping()
	-- Starts tracking snap points nearest to the mouse

	-- Hide any handles or bounding boxes
	AttachHandles(nil, true);
	BoundingBox.ClearBoundingBox();

	-- Avoid targeting snap points in selected parts while dragging
	if Dragging then
		SnapTracking.TargetBlacklist = Selection.Items;
	end;

	-- Start tracking the closest snapping point
	SnapTracking.StartTracking(function (NewPoint)

		-- Fire `SnappedPoint` and update `SnappedPoint` when there is a new snap point in focus
		if NewPoint then
			SnappedPoint = NewPoint.p;
			PointSnapped:fire(SnappedPoint);
		end;

	end);

end;

function SetAxisPosition(Axis, Position)
	-- Sets the selection's position on axis `Axis` to `Position`

	-- Track this change
	TrackChange();

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
	local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Selection.Items), Core.Player);

	-- Revert changes if player is not authorized to move parts to target destination
	if Core.Mode == 'Tool' and Security.ArePartsViolatingAreas(Selection.Items, Core.Player, false, AreaPermissions) then
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
	RegisterChange();

end;

function NudgeSelectionByFace(Face)
	-- Nudges the selection along the current axes mode in the direction of the focused part's face

	-- Get amount to nudge by
	local NudgeAmount = MoveTool.Increment;

	-- Reverse nudge amount if shift key is held while nudging
	local PressedKeys = Support.FlipTable(Support.GetListMembers(UserInputService:GetKeysPressed(), 'KeyCode'));
	if PressedKeys[Enum.KeyCode.LeftShift] or PressedKeys[Enum.KeyCode.RightShift] then
		NudgeAmount = -NudgeAmount;
	end;

	-- Track this change
	TrackChange();

	-- Prepare parts to be moved
	local InitialState = PreparePartsForDragging();

	-- Perform the movement
	MovePartsAlongAxesByFace(Face, NudgeAmount, MoveTool.Axes, Selection.Focus, InitialState);

	-- Update the "distance moved" indicator
	if MoveTool.UI then
		MoveTool.UI.Changes.Text.Text = 'moved ' .. math.abs(NudgeAmount) .. ' studs';
	end;

	-- Cache up permissions for all private areas
	local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Selection.Items), Core.Player);

	-- Revert changes if player is not authorized to move parts to target destination
	if Core.Mode == 'Tool' and Security.ArePartsViolatingAreas(Selection.Items, Core.Player, false, AreaPermissions) then
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
	RegisterChange();

end;

function TrackChange()

	-- Start the record
	HistoryRecord = {
		Parts = Support.CloneTable(Selection.Items);
		BeforeCFrame = {};
		AfterCFrame = {};

		Unapply = function (Record)
			-- Reverts this change

			-- Select the changed parts
			Selection.Replace(Record.Parts);

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
			Selection.Replace(Record.Parts);

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
	for _, Part in pairs(HistoryRecord.Parts) do
		HistoryRecord.BeforeCFrame[Part] = Part.CFrame;
	end;

end;

function RegisterChange()
	-- Finishes creating the history record and registers it

	-- Make sure there's an in-progress history record
	if not HistoryRecord then
		return;
	end;

	-- Collect the selection's final state
	local Changes = {};
	for _, Part in pairs(HistoryRecord.Parts) do
		HistoryRecord.AfterCFrame[Part] = Part.CFrame;
		table.insert(Changes, { Part = Part, CFrame = Part.CFrame });
	end;

	-- Send the change to the server
	Core.SyncAPI:Invoke('SyncMove', Changes);

	-- Register the record and clear the staging
	Core.History.Add(HistoryRecord);
	HistoryRecord = nil;

end;

function EnableDragging()
	-- Enables part dragging

	-- Pay attention to when the user intends to start dragging
	Connections.DragStart = Core.Mouse.Button1Down:connect(function ()

		-- Make sure this click was not to select
		if Selection.Multiselecting then
			return;
		end;

		-- Check whether the user is snapping
		local IsSnapping = UserInputService:IsKeyDown(Enum.KeyCode.R) and #Selection.Items > 0;

		-- Make sure target is draggable, unless snapping is ongoing
		if not Core.IsSelectable(Core.Mouse.Target) and not IsSnapping then
			return;
		end;

		-- Select the target if it's not selected, and snapping is not ongoing
		if not Selection.IsSelected(Core.Mouse.Target) and not IsSnapping then
			Selection.Replace({ Core.Mouse.Target }, true);
		end;

		-- Mark where dragging began
		DragStart = Vector2.new(Core.Mouse.X, Core.Mouse.Y);
		DragStartTarget = IsSnapping and Selection.Focus or Core.Mouse.Target;

		-- Watch for potential dragging
		Connections.WatchForDrag = Core.Mouse.Move:connect(function ()

			-- Trigger dragging if the mouse is moved over 2 pixels
			if DragStart and (Vector2.new(Core.Mouse.X, Core.Mouse.Y) - DragStart).magnitude >= 2 then

				-- Prepare for dragging
				BoundingBox.ClearBoundingBox();
				SetUpDragging(DragStartTarget, SnapTracking.Enabled and SnappedPoint or nil);

				-- Disable watching for potential dragging
				ClearConnection 'WatchForDrag';

			end;

		end);

	end);

	-- Clear dragging-start watchers once mouse is released
	Connections.DragEnd = Support.AddUserInputListener('Ended', 'MouseButton1', true, function ()

		-- Clear dragging-start data
		DragStart = nil;
		DragStartTarget = nil;

		-- Disconnect dragging-start listeners
		ClearConnection 'WatchForDrag';

	end);

end;

-- Catch whenever the user finishes dragging
UserInputService.InputEnded:connect(function (InputInfo, GameProcessedEvent)

	-- Make sure dragging is active
	if not Dragging then
		return;
	end;

	-- Make sure this was button 1 being released
	if InputInfo.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return;
	end;

	-- Reset normal axes option state
	SetAxes(MoveTool.Axes);

	-- Finish dragging
	FinishDragging();

end);

function SetUpDragging(BasePart, BasePoint)
	-- Sets up and initiates dragging based on the given base part

	-- Prevent selection while dragging
	Core.Targeting.CancelSelecting();

	-- Prepare parts, and start dragging
	InitialState = PreparePartsForDragging();
	StartDragging(BasePart, InitialState, BasePoint);

end;

MoveTool.SetUpDragging = SetUpDragging;

function PreparePartsForDragging()
	-- Prepares parts for dragging and returns the initial state of the parts

	local InitialState = {};

	-- Get index of parts
	local PartIndex = Support.FlipTable(Selection.Items);

	-- Stop parts from moving, and capture the initial state of the parts
	for _, Part in pairs(Selection.Items) do
		InitialState[Part] = { Anchored = Part.Anchored, CanCollide = Part.CanCollide, CFrame = Part.CFrame };
		Part.Anchored = true;
		Part.CanCollide = false;
		InitialState[Part].Joints = Core.PreserveJoints(Part, PartIndex);
		Part:BreakJoints();
		Part.Velocity = Vector3.new();
		Part.RotVelocity = Vector3.new();
	end;

	return InitialState;
end;

function StartDragging(BasePart, InitialState, BasePoint)
	-- Begins dragging the selection

	-- Indicate that we're dragging
	Dragging = true;

	-- Track changes
	TrackChange();

	-- Disable bounding box calculation
	BoundingBox.ClearBoundingBox();

	-- Cache area permissions information
	local AreaPermissions;
	if Core.Mode == 'Tool' then
		AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Selection.Items), Core.Player);
	end;

	-- Determine the base point and part for the dragging
	local BasePart = BasePart or Core.Mouse.Target;
	local BasePartOffset = BasePart.Position - Core.Mouse.Hit.p;

	-- Improve base point alignment for the given increment
	BasePartOffset = Vector3.new(
		GetIncrementMultiple(BasePartOffset.X, MoveTool.Increment),
		GetIncrementMultiple(BasePartOffset.Y, MoveTool.Increment),
		GetIncrementMultiple(BasePartOffset.Z, MoveTool.Increment)
	);
	BasePartOffset = Vector3.new(
		math.abs(BasePartOffset.X) >= BasePart.Size.X / 2 and (BasePart.Size.X / 2 * (BasePartOffset.X > 0 and 1 or -1)) or BasePartOffset.X,
		math.abs(BasePartOffset.Y) >= BasePart.Size.Y / 2 and (BasePart.Size.Y / 2 * (BasePartOffset.Y > 0 and 1 or -1)) or BasePartOffset.Y,
		math.abs(BasePartOffset.Z) >= BasePart.Size.Z / 2 and (BasePart.Size.Z / 2 * (BasePartOffset.Z > 0 and 1 or -1)) or BasePartOffset.Z
	);

	-- Use the given base point instead if any
	if BasePoint then
		BasePartOffset = BasePart.Position - BasePoint;
	end;

	-- Prepare snapping in case it is enabled, and make sure to override its default target selection
	SnapTracking.TargetBlacklist = Selection.Items;
	Connections.DragSnapping = PointSnapped:connect(function (SnappedPoint)

		-- Align the selection's base point to the snapped point
		local Rotation = SurfaceAlignment or (InitialState[BasePart].CFrame - InitialState[BasePart].CFrame.p);
		BasePart.CFrame = CFrame.new(SnappedPoint + BasePartOffset) * Rotation;
		TranslatePartsRelativeToPart(BasePart, InitialState);

		-- Make sure we're not entering any unauthorized private areas
		if Core.Mode == 'Tool' and Security.ArePartsViolatingAreas(Selection.Items, Core.Player, false, AreaPermissions) then
			BasePart.CFrame = InitialState[BasePart].CFrame;
			TranslatePartsRelativeToPart(BasePart, InitialState);
		end;

	end);

	-- Provide a callback to trigger alignment
	TriggerAlignment = function ()
		DragToMouse(BasePart, BasePartOffset, InitialState, AreaPermissions);
	end;

	-- Start up the dragging action
	Connections.Drag = Core.Mouse.Move:connect(function ()
		DragToMouse(BasePart, BasePartOffset, InitialState, AreaPermissions);
	end);

end;

function DragToMouse(BasePart, BasePartOffset, InitialState, AreaPermissions)
	-- Drags the selection by `BasePart`, judging area authorization from `AreaPermissions`

	----------------------------------------------
	-- Check what and where the mouse is aiming at
	----------------------------------------------

	-- Don't consider other selected parts possible targets
	local IgnoreList = Support.CloneTable(Selection.Items);
	table.insert(IgnoreList, Core.Player and Core.Player.Character)

	-- Save last target surface for change detection
	local LastTargetNormal = TargetNormal;

	-- Perform the mouse target search
	Target, TargetPoint, TargetNormal = Workspace:FindPartOnRayWithIgnoreList(
		Ray.new(Core.Mouse.UnitRay.Origin, Core.Mouse.UnitRay.Direction * 5000),
		IgnoreList
	);

	-- Reset any surface alignment if target surface changes
	if LastTargetNormal ~= TargetNormal then
		SurfaceAlignment = nil;
	end;

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
	TargetPoint = GetAlignedTargetPoint(Target, TargetPoint, TargetNormal);

	-- Move the parts towards their target destination
	local Rotation = SurfaceAlignment or (InitialState[BasePart].CFrame - InitialState[BasePart].CFrame.p);
	BasePart.CFrame = CFrame.new(TargetPoint + BasePartOffset) * Rotation;
	TranslatePartsRelativeToPart(BasePart, InitialState);

	-- Check for the largest corner-target plane crossthrough we have to correct
	local CrossthroughCorrection = 0;
	local CornerCrossingMost;
	for _, Part in pairs(Selection.Items) do
		local Corners = Support.GetPartCorners(Part);
		for _, Corner in pairs(Corners) do

			-- Calculate this corner's target plane crossthrough
			local CornerCrossthrough = -(TargetPoint - Corner.p):Dot(TargetNormal);
			CrossthroughCorrection = math.min(CrossthroughCorrection, CornerCrossthrough);

			-- Check if this corner crosses through the most
			if CrossthroughCorrection == CornerCrossthrough then
				CornerCrossingMost = Corner.p;
			end;

		end;
	end;

	-- Retract the parts by the max. crossthrough amount
	local Rotation = SurfaceAlignment or CFrame.Angles(InitialState[BasePart].CFrame:toEulerAnglesXYZ());
	BasePart.CFrame = CFrame.new(TargetPoint + BasePartOffset) * Rotation - (TargetNormal * CrossthroughCorrection);
	TranslatePartsRelativeToPart(BasePart, InitialState);

	----------------------------------------
	-- Check for relevant area authorization
	----------------------------------------

	-- Make sure we're not entering any unauthorized private areas
	if Core.Mode == 'Tool' and Security.ArePartsViolatingAreas(Selection.Items, Core.Player, false, AreaPermissions) then
		BasePart.CFrame = InitialState[BasePart].CFrame;
		TranslatePartsRelativeToPart(BasePart, InitialState);
	end;

end;

function AlignSelectionToTarget()
	-- Aligns the selection to the current target surface while dragging

	-- Ensure dragging is ongoing
	if not Dragging or not TargetNormal then
		return;
	end;

	-- Get target surface normal CFrame and its leftward direction
	local TargetNormalCF = CFrame.new(Vector3.new(), TargetNormal);
	local TargetNormalLeft = -TargetNormalCF.rightVector;

	-- Use detected surface normal directly if not targeting a part
	if not Target then
		SurfaceAlignment = TargetNormalCF * CFrame.Angles(-math.pi / 2, 0, 0);

	-- Align upward directions if targeting a part's front or back surface
	elseif TargetNormal:isClose(Target.CFrame.lookVector, 0.000001) or TargetNormal:isClose(-Target.CFrame.lookVector, 0.000001) then
		SurfaceAlignment = TargetNormalCF *
			CFrame.Angles(0, 0, math.acos(TargetNormalLeft:Dot(Target.CFrame.upVector))) *
			CFrame.Angles(-math.pi / 2, 0, 0);

	-- Align forward directions if targeting any other part surface
	else
		SurfaceAlignment = TargetNormalCF *
			CFrame.Angles(0, 0, math.pi - math.acos(TargetNormalLeft:Dot(Target.CFrame.lookVector))) *
			CFrame.Angles(-math.pi / 2, 0, 0);
	end;

	-- Trigger alignment
	TriggerAlignment();

end;

function GetAlignedTargetPoint(Target, TargetPoint, TargetNormal)
	-- Returns the target point aligned to the nearest increment multiple

	-- By default, use (0, 0, 0) as the alignment reference point
	local ReferencePoint = CFrame.new();

	-------------------------------------------------------------------------
	-- Detect a part target's face being pointed at based on the given normal
	-------------------------------------------------------------------------

	-- Make sure the target is a part
	if Target and Target:IsA 'BasePart' then

		-- Get a front face's corner as a reference point
		if TargetNormal:isClose(Target.CFrame.lookVector, 0.000001) then
			ReferencePoint = Target.CFrame * CFrame.new(Target.Size.X / 2, Target.Size.Y / 2, -Target.Size.Z / 2);

		-- Get a back face's corner as a reference point
		elseif TargetNormal:isClose((Target.CFrame * CFrame.Angles(0, math.pi, 0)).lookVector, 0.000001) then
			ReferencePoint = Target.CFrame * CFrame.new(-Target.Size.X / 2, Target.Size.Y / 2, Target.Size.Z / 2);

		-- Get a left face's corner as a reference point
		elseif TargetNormal:isClose((Target.CFrame * CFrame.Angles(0, math.pi / 2, 0)).lookVector, 0.000001) then
			ReferencePoint = Target.CFrame * CFrame.new(-Target.Size.X / 2, Target.Size.Y / 2, Target.Size.Z / 2);

		-- Get a right face's corner as a reference point
		elseif TargetNormal:isClose((Target.CFrame * CFrame.Angles(0, 3 * math.pi / 2, 0)).lookVector, 0.000001) then
			ReferencePoint = Target.CFrame * CFrame.new(Target.Size.X / 2, Target.Size.Y / 2, Target.Size.Z / 2);

		-- Get a top face's corner as a reference point
		elseif TargetNormal:isClose((Target.CFrame * CFrame.Angles(math.pi / 2, 0, 0)).lookVector, 0.000001) then
			ReferencePoint = Target.CFrame * CFrame.new(-Target.Size.X / 2, Target.Size.Y / 2, Target.Size.Z / 2);

		-- Get a bottom face's corner as a reference point
		elseif TargetNormal:isClose((Target.CFrame * CFrame.Angles(math.pi / 2, 0, 0)).lookVector * -1, 0.000001) then
			ReferencePoint = Target.CFrame * CFrame.new(-Target.Size.X / 2, -Target.Size.Y / 2, Target.Size.Z / 2);
		end;

	end;

	-------------------------------------
	-- Calculate the aligned target point
	-------------------------------------

	-- Align the target point to an increment multiple from the reference point
	local AlignedTargetPoint = ReferencePoint:pointToObjectSpace(TargetPoint);
	AlignedTargetPoint = Vector3.new(
		GetIncrementMultiple(AlignedTargetPoint.X, MoveTool.Increment),
		GetIncrementMultiple(AlignedTargetPoint.Y, MoveTool.Increment),
		GetIncrementMultiple(AlignedTargetPoint.Z, MoveTool.Increment)
	);
	AlignedTargetPoint = (ReferencePoint * CFrame.new(AlignedTargetPoint)).p;

	-- Return the aligned target point
	return AlignedTargetPoint;
end;

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

function FinishDragging()
	-- Releases parts and registers position changes from dragging

	-- Make sure dragging is active
	if not Dragging then
		return;
	end;

	-- Indicate that we're no longer dragging
	Dragging = false;

	-- Clear any surface alignment
	SurfaceAlignment = nil;

	-- Stop the dragging action
	ClearConnection 'Drag';

	-- Stop, clean up snapping point tracking
	SnapTracking.StopTracking();
	ClearConnection 'DragSnapping';

	-- Restore the original state of each part
	for Part, State in pairs(InitialState) do
		Part:MakeJoints();
		Core.RestoreJoints(State.Joints);
		Part.CanCollide = State.CanCollide;
		Part.Anchored = State.Anchored;
	end;

	-- Register changes
	RegisterChange();

end;

-- Return the tool
return MoveTool;