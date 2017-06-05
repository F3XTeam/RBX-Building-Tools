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
local RotateTool = {

	Name = 'Rotate Tool';
	Color = BrickColor.new 'Bright green';

	-- Default options
	Increment = 15;
	Pivot = 'Center';

};

-- Container for temporary connections (disconnected automatically)
local Connections = {};

function RotateTool.Equip()
	-- Enables the tool's equipped functionality

	-- Set our current pivot mode
	SetPivot(RotateTool.Pivot);

	-- Start up our interface
	ShowUI();
	BindShortcutKeys();

end;

function RotateTool.Unequip()
	-- Disables the tool's equipped functionality

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
	if RotateTool.UI then

		-- Reveal the UI
		RotateTool.UI.Visible = true;

		-- Update the UI every 0.1 seconds
		UIUpdater = Support.ScheduleRecurringTask(UpdateUI, 0.1);

		-- Skip UI creation
		return;

	end;

	-- Create the UI
	RotateTool.UI = Core.Tool.Interfaces.BTRotateToolGUI:Clone();
	RotateTool.UI.Parent = Core.UI;
	RotateTool.UI.Visible = true;

	-- Add functionality to the pivot option switch
	local PivotSwitch = RotateTool.UI.PivotOption;
	PivotSwitch.Center.Button.MouseButton1Down:connect(function ()
		SetPivot('Center');
	end);
	PivotSwitch.Local.Button.MouseButton1Down:connect(function ()
		SetPivot('Local');
	end);
	PivotSwitch.Last.Button.MouseButton1Down:connect(function ()
		SetPivot('Last');
	end);

	-- Add functionality to the increment input
	local IncrementInput = RotateTool.UI.IncrementOption.Increment.TextBox;
	IncrementInput.FocusLost:connect(function (EnterPressed)
		RotateTool.Increment = tonumber(IncrementInput.Text) or RotateTool.Increment;
		IncrementInput.Text = Support.Round(RotateTool.Increment, 4);
	end);

	-- Add functionality to the rotation inputs
	local XInput = RotateTool.UI.Info.RotationInfo.X.TextBox;
	local YInput = RotateTool.UI.Info.RotationInfo.Y.TextBox;
	local ZInput = RotateTool.UI.Info.RotationInfo.Z.TextBox;
	XInput.FocusLost:connect(function (EnterPressed)
		local NewAngle = tonumber(XInput.Text);
		if NewAngle then
			SetAxisAngle('X', NewAngle);
		end;
	end);
	YInput.FocusLost:connect(function (EnterPressed)
		local NewAngle = tonumber(YInput.Text);
		if NewAngle then
			SetAxisAngle('Y', NewAngle);
		end;
	end);
	ZInput.FocusLost:connect(function (EnterPressed)
		local NewAngle = tonumber(ZInput.Text);
		if NewAngle then
			SetAxisAngle('Z', NewAngle);
		end;
	end);

	-- Update the UI every 0.1 seconds
	UIUpdater = Support.ScheduleRecurringTask(UpdateUI, 0.1);

end;

function HideUI()
	-- Hides the tool UI

	-- Make sure there's a UI
	if not RotateTool.UI then
		return;
	end;

	-- Hide the UI
	RotateTool.UI.Visible = false;

	-- Stop updating the UI
	UIUpdater:Stop();

end;

function UpdateUI()
	-- Updates information on the UI

	-- Make sure the UI's on
	if not RotateTool.UI then
		return;
	end;

	-- Only show and calculate selection info if it's not empty
	if #Selection.Items == 0 then
		RotateTool.UI.Info.Visible = false;
		RotateTool.UI.Size = UDim2.new(0, 245, 0, 90);
		return;
	else
		RotateTool.UI.Info.Visible = true;
		RotateTool.UI.Size = UDim2.new(0, 245, 0, 150);
	end;

	-----------------------------------------
	-- Update the size information indicators
	-----------------------------------------

	-- Identify common angles across axes
	local XVariations, YVariations, ZVariations = {}, {}, {};
	for _, Part in pairs(Selection.Items) do
		table.insert(XVariations, Support.Round(Part.Orientation.X, 3));
		table.insert(YVariations, Support.Round(Part.Orientation.Y, 3));
		table.insert(ZVariations, Support.Round(Part.Orientation.Z, 3));
	end;
	local CommonX = Support.IdentifyCommonItem(XVariations);
	local CommonY = Support.IdentifyCommonItem(YVariations);
	local CommonZ = Support.IdentifyCommonItem(ZVariations);

	-- Shortcuts to indicators
	local XIndicator = RotateTool.UI.Info.RotationInfo.X.TextBox;
	local YIndicator = RotateTool.UI.Info.RotationInfo.Y.TextBox;
	local ZIndicator = RotateTool.UI.Info.RotationInfo.Z.TextBox;

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

function SetPivot(PivotMode)
	-- Sets the given rotation pivot mode

	-- Update setting
	RotateTool.Pivot = PivotMode;

	-- Update the UI switch
	if RotateTool.UI then
		Core.ToggleSwitch(PivotMode, RotateTool.UI.PivotOption);
	end;

	-- Disable any unnecessary bounding boxes
	BoundingBox.ClearBoundingBox();

	-- For center mode, use bounding box handles
	if PivotMode == 'Center' then
		BoundingBox.StartBoundingBox(AttachHandles);

	-- For local mode, use focused part handles
	elseif PivotMode == 'Local' then
		AttachHandles(Selection.Focus, true); 

	-- For last mode, use focused part handles
	elseif PivotMode == 'Last' then
		AttachHandles(Selection.Focus, true);
	end;

end;

function AttachHandles(Part, Autofocus)
	-- Creates and attaches handles to `Part`, and optionally automatically attaches to the focused part

	-- Enable autofocus if requested and not already on
	if Autofocus and not Connections.AutofocusHandle then
		Connections.AutofocusHandle = Selection.FocusChanged:connect(function ()
			AttachHandles(Selection.Focus, true);
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
	Handles = Create 'ArcHandles' {
		Name = 'BTRotationHandles';
		Color = RotateTool.Color;
		Parent = Core.UIContainer;
		Adornee = Part;
	};

	--------------------------------------------------------
	-- Prepare for rotating parts when the handle is clicked
	--------------------------------------------------------

	local AreaPermissions;

	Handles.MouseButton1Down:connect(function ()

		-- Prevent selection
		Core.Targeting.CancelSelecting();

		-- Indicate rotating via handle
		HandleRotating = true;

		-- Freeze bounding box extents while rotating
		if BoundingBox.GetBoundingBox() then
			InitialExtentsSize, InitialExtentsCFrame = BoundingBox.CalculateExtents(Core.Selection.Items, BoundingBox.StaticExtents);
			BoundingBox.PauseMonitoring();
		end;

		-- Stop parts from moving, and capture the initial state of the parts
		InitialState = PreparePartsForRotating();

		-- Track the change
		TrackChange();

		-- Cache area permissions information
		if Core.Mode == 'Tool' then
			AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Selection.Items), Core.Player);
		end;

		-- Set the pivot point to the center of the selection if in Center mode
		if RotateTool.Pivot == 'Center' then
			PivotPoint = BoundingBox.GetBoundingBox().CFrame;

		-- Set the pivot point to the center of the focused part if in Last mode
		elseif RotateTool.Pivot == 'Last' and not CustomPivotPoint then
			PivotPoint = InitialState[Selection.Focus].CFrame;
		end;

	end);

	------------------------------------------
	-- Update parts when the handles are moved
	------------------------------------------

	Handles.MouseDrag:connect(function (Axis, Rotation)

		-- Only rotate if handle is enabled
		if not HandleRotating then
			return;
		end;

		-- Turn the rotation amount into degrees
		Rotation = math.deg(Rotation);

		-- Calculate the increment-aligned rotation amount
		Rotation = GetIncrementMultiple(Rotation, RotateTool.Increment) % 360;

		-- Get displayable rotation delta
		local DisplayedRotation = GetHandleDisplayDelta(Rotation);

		-- Perform the rotation
		RotatePartsAroundPivot(RotateTool.Pivot, PivotPoint, Axis, Rotation, InitialState);

		-- Make sure we're not entering any unauthorized private areas
		if Core.Mode == 'Tool' and Security.ArePartsViolatingAreas(Selection.Items, Core.Player, false, AreaPermissions) then
			for Part, State in pairs(InitialState) do
				Part.CFrame = State.CFrame;
			end;

			-- Reset displayed rotation delta
			DisplayedRotation = 0;
		end;

		-- Update the "degrees rotated" indicator
		if RotateTool.UI then
			RotateTool.UI.Changes.Text.Text = 'rotated ' .. DisplayedRotation .. ' degrees';
		end;

	end);

end;

-- Finalize changes to parts when the handle is let go
Support.AddUserInputListener('Ended', 'MouseButton1', true, function (Input)

	-- Make sure rotating is ongoing
	if not HandleRotating then
		return;
	end;

	-- Prevent selection
	Core.Targeting.CancelSelecting();

	-- Disable rotating
	HandleRotating = false;

	-- Clear this connection to prevent it from firing again
	ClearConnection 'HandleRelease';

	-- Clear change indicator states
	HandleDirection = nil;
	HandleFirstAngle = nil;
	LastDisplayedRotation = nil;

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

	-- Disable handle autofocus if enabled
	ClearConnection 'AutofocusHandle';

end;

function RotatePartsAroundPivot(PivotMode, PivotPoint, Axis, Rotation, InitialStates)
	-- Rotates the given parts in `InitialStates` around `PivotMode` (using `PivotPoint` if applicable)'s `Axis` by `Rotation`

	-- Create a CFrame that increments rotation by `Rotation` around `Axis`
	local RotationCFrame = CFrame.fromAxisAngle(Vector3.FromAxis(Axis), math.rad(Rotation));

	-- Rotate each part
	for Part, InitialState in pairs(InitialStates) do

		-- Rotate around the selection's center, or the currently focused part
		if PivotMode == 'Center' or PivotMode == 'Last' then

			-- Calculate the focused part's rotation
			local RelativeTo = PivotPoint * RotationCFrame;

			-- Calculate this part's offset from the focused part's rotation
			local Offset = PivotPoint:toObjectSpace(InitialState.CFrame);

			-- Rotate relative to the focused part by this part's offset from it
			Part.CFrame = RelativeTo * Offset;

		-- Rotate around the part's center
		elseif RotateTool.Pivot == 'Local' then
			Part.CFrame = InitialState.CFrame * RotationCFrame;

		end;

	end;

end;

function GetHandleDisplayDelta(HandleRotation)
	-- Returns a human-friendly version of the handle's rotation delta

	-- Prepare to capture first angle
	if HandleFirstAngle == nil then
		HandleFirstAngle = true;
		HandleDirection = true;

	-- Capture first angle
	elseif HandleFirstAngle == true then

		-- Determine direction based on first angle
		if math.abs(HandleRotation) > 180 then
			HandleDirection = false;
		else
			HandleDirection = true;
		end;

		-- Disable first angle capturing
		HandleFirstAngle = false;

	end;

	-- Determine the rotation delta to display
	local DisplayedRotation;
	if HandleDirection == true then
		DisplayedRotation = (360 - HandleRotation) % 360;
	else
		DisplayedRotation = HandleRotation % 360;
	end;

	-- Switch delta calculation direction if crossing directions
	if LastDisplayedRotation and (
	   (LastDisplayedRotation <= 120 and DisplayedRotation >= 240) or
	   (LastDisplayedRotation >= 240 and DisplayedRotation <= 120)) then
		HandleDirection = not HandleDirection;
	end;

	-- Update displayed rotation after direction correction
	if HandleDirection == true then
		DisplayedRotation = (360 - HandleRotation) % 360;
	else
		DisplayedRotation = HandleRotation % 360;
	end;

	-- Store this last display rotation
	LastDisplayedRotation = DisplayedRotation;

	-- Return updated display delta
	return DisplayedRotation;

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
			if RotateTool.Pivot == 'Center' then
				SetPivot('Local');

			elseif RotateTool.Pivot == 'Local' then
				SetPivot('Last');

			elseif RotateTool.Pivot == 'Last' then
				SetPivot('Center');
			end;

		-- Check if the - key was pressed
		elseif InputInfo.KeyCode == Enum.KeyCode.Minus or InputInfo.KeyCode == Enum.KeyCode.KeypadMinus then

			-- Focus on the increment input
			if RotateTool.UI then
				RotateTool.UI.IncrementOption.Increment.TextBox:CaptureFocus();
			end;

		-- Nudge around X axis if the 8 button on the keypad is pressed
		elseif InputInfo.KeyCode == Enum.KeyCode.KeypadEight then
			NudgeSelectionByAxis(Enum.Axis.X, 1);

		-- Nudge around X axis if the 2 button on the keypad is pressed
		elseif InputInfo.KeyCode == Enum.KeyCode.KeypadTwo then
			NudgeSelectionByAxis(Enum.Axis.X, -1);

		-- Nudge around Z axis if the 9 button on the keypad is pressed
		elseif InputInfo.KeyCode == Enum.KeyCode.KeypadNine then
			NudgeSelectionByAxis(Enum.Axis.Z, 1);

		-- Nudge around Z axis if the 1 button on the keypad is pressed
		elseif InputInfo.KeyCode == Enum.KeyCode.KeypadOne then
			NudgeSelectionByAxis(Enum.Axis.Z, -1);

		-- Nudge around Y axis if the 4 button on the keypad is pressed
		elseif InputInfo.KeyCode == Enum.KeyCode.KeypadFour then
			NudgeSelectionByAxis(Enum.Axis.Y, -1);

		-- Nudge around Y axis if the 6 button on the keypad is pressed
		elseif InputInfo.KeyCode == Enum.KeyCode.KeypadSix then
			NudgeSelectionByAxis(Enum.Axis.Y, 1);

		-- Start snapping when the R key is pressed down, and it's not the selection clearing hotkey
		elseif (InputInfo.KeyCode == Enum.KeyCode.R) and not Selection.Multiselecting then
			StartSnapping();

		-- Start snapping when T key is pressed down (alias)
		elseif InputInfo.KeyCode == Enum.KeyCode.T then
			StartSnapping();

		end;

	end));

end;

function StartSnapping()

	-- Make sure snapping isn't already enabled
	if SnapTracking.Enabled then
		return;
	end;

	-- Listen for snapped points
	SnapTracking.StartTracking(function (NewPoint)
		SnappedPoint = NewPoint;
	end);

	-- Select the snapped pivot point upon clicking
	Connections.SelectSnappedPivot = Core.Mouse.Button1Down:connect(function ()

		-- Disable unintentional selection
		Core.Targeting.CancelSelecting();

		-- Ensure there is a snap point
		if not SnappedPoint then
			return;
		end;

		-- Disable snapping
		SnapTracking.StopTracking();

		-- Attach the handles to a part at the snapped point
		local Part = Create 'Part' {
			CFrame = SnappedPoint,
			Size = Vector3.new(5, 1, 5)
		};
		SetPivot 'Last';
		AttachHandles(Part, true);

		-- Maintain the part in memory to prevent garbage collection
		GCBypass = { Part };

		-- Set the pivot point
		PivotPoint = SnappedPoint;
		CustomPivotPoint = true;

		-- Disconnect snapped pivot point selection listener
		ClearConnection 'SelectSnappedPivot';

		-- Disable custom pivot point mode when the handles attach elsewhere
		Connections.DisableCustomPivotPoint = Handles.Changed:connect(function (Property)
			if Property == 'Adornee' then
				CustomPivotPoint = false;
				ClearConnection 'DisableCustomPivotPoint';
			end;
		end);

	end);

end;

function SetAxisAngle(Axis, Angle)
	-- Sets the selection's angle on axis `Axis` to `Angle`

	-- Turn the given angle from degrees to radians
	local Angle = math.rad(Angle);

	-- Track this change
	TrackChange();

	-- Prepare parts to be moved
	local InitialStates = PreparePartsForRotating();

	-- Update each part
	for Part, State in pairs(InitialStates) do

		-- Set the part's new CFrame
		Part.CFrame = CFrame.new(Part.Position) * CFrame.Angles(
			Axis == 'X' and Angle or math.rad(Part.Rotation.X),
			Axis == 'Y' and Angle or math.rad(Part.Rotation.Y),
			Axis == 'Z' and Angle or math.rad(Part.Rotation.Z)
		);

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

function NudgeSelectionByAxis(Axis, Direction)
	-- Nudges the rotation of the selection in the direction of the given axis

	-- Ensure selection is not empty
	if #Selection.Items == 0 then
		return;
	end;

	-- Get amount to nudge by
	local NudgeAmount = RotateTool.Increment;

	-- Reverse nudge amount if shift key is held while nudging
	local PressedKeys = Support.FlipTable(Support.GetListMembers(UserInputService:GetKeysPressed(), 'KeyCode'));
	if PressedKeys[Enum.KeyCode.LeftShift] or PressedKeys[Enum.KeyCode.RightShift] then
		NudgeAmount = -NudgeAmount;
	end;

	-- Track the change
	TrackChange();

	-- Stop parts from moving, and capture the initial state of the parts
	local InitialState = PreparePartsForRotating();

	-- Set the pivot point to the center of the selection if in Center mode
	if RotateTool.Pivot == 'Center' then
		local BoundingBoxSize, BoundingBoxCFrame = BoundingBox.CalculateExtents(Selection.Items);
		PivotPoint = BoundingBoxCFrame;

	-- Set the pivot point to the center of the focused part if in Last mode
	elseif RotateTool.Pivot == 'Last' and not CustomPivotPoint then
		PivotPoint = InitialState[Selection.Focus].CFrame;
	end;

	-- Perform the rotation
	RotatePartsAroundPivot(RotateTool.Pivot, PivotPoint, Axis, NudgeAmount * (Direction or 1), InitialState);

	-- Update the "degrees rotated" indicator
	if RotateTool.UI then
		RotateTool.UI.Changes.Text.Text = 'rotated ' .. (NudgeAmount * (Direction or 1)) .. ' degrees';
	end;

	-- Cache area permissions information
	local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Selection.Items), Core.Player);

	-- Make sure we're not entering any unauthorized private areas
	if Core.Mode == 'Tool' and Security.ArePartsViolatingAreas(Selection.Items, Core.Player, false, AreaPermissions) then
		for Part, State in pairs(InitialState) do
			Part.CFrame = State.CFrame;
		end;
	end;

	-- Make joints, restore original anchor and collision states
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
			Core.SyncAPI:Invoke('SyncRotate', Changes);

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
			Core.SyncAPI:Invoke('SyncRotate', Changes);

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
	Core.SyncAPI:Invoke('SyncRotate', Changes);

	-- Register the record and clear the staging
	Core.History.Add(HistoryRecord);
	HistoryRecord = nil;

end;

function PreparePartsForRotating()
	-- Prepares parts for rotating and returns the initial state of the parts

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

-- Return the tool
return RotateTool;