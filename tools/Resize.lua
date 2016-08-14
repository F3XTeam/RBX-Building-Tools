Tool = script.Parent.Parent;
Core = require(Tool.Core);
SnapTracking = require(Tool.SnappingModule);

-- Import relevant references
Selection = Core.Selection;
Create = Core.Create;
Support = Core.Support;
Security = Core.Security;
Support.ImportServices();

-- Initialize the tool
local ResizeTool = {

	Name = 'Resize Tool';
	Color = BrickColor.new 'Cyan';

	-- Default options
	Increment = 1;
	Directions = 'Normal';

};

-- Container for temporary connections (disconnected automatically)
local Connections = {};

function ResizeTool.Equip()
	-- Enables the tool's equipped functionality

	-- Start up our interface
	ShowUI();
	ShowHandles();
	BindShortcutKeys();

end;

function ResizeTool.Unequip()
	-- Disables the tool's equipped functionality

	-- Clear unnecessary resources
	HideUI();
	HideHandles();
	ClearConnections();
	SnapTracking.StopTracking();

end;

function ClearConnections()
	-- Clears out temporary connections

	for ConnectionKey, Connection in pairs(Connections) do
		Connection:disconnect();
		Connections[ConnectionKey] = nil;
	end;

end;

function ShowUI()
	-- Creates and reveals the UI

	-- Reveal UI if already created
	if ResizeTool.UI then

		-- Reveal the UI
		ResizeTool.UI.Visible = true;

		-- Update the UI every 0.1 seconds
		UIUpdater = Support.ScheduleRecurringTask(UpdateUI, 0.1);

		-- Skip UI creation
		return;

	end;

	-- Create the UI
	ResizeTool.UI = Core.Tool.Interfaces.BTResizeToolGUI:Clone();
	ResizeTool.UI.Parent = Core.UI;
	ResizeTool.UI.Visible = true;

	-- Add functionality to the directions option switch
	local DirectionsSwitch = ResizeTool.UI.DirectionsOption;
	DirectionsSwitch.Normal.Button.MouseButton1Down:connect(function ()
		SetDirections('Normal');
	end);
	DirectionsSwitch.Both.Button.MouseButton1Down:connect(function ()
		SetDirections('Both');
	end);

	-- Add functionality to the increment input
	local IncrementInput = ResizeTool.UI.IncrementOption.Increment.TextBox;
	IncrementInput.FocusLost:connect(function (EnterPressed)
		ResizeTool.Increment = tonumber(IncrementInput.Text) or ResizeTool.Increment;
		IncrementInput.Text = Support.Round(ResizeTool.Increment, 3);
	end);

	-- Add functionality to the size inputs
	local XInput = ResizeTool.UI.Info.SizeInfo.X.TextBox;
	local YInput = ResizeTool.UI.Info.SizeInfo.Y.TextBox;
	local ZInput = ResizeTool.UI.Info.SizeInfo.Z.TextBox;
	XInput.FocusLost:connect(function (EnterPressed)
		local NewSize = tonumber(XInput.Text);
		if NewSize then
			SetAxisSize('X', NewSize);
		end;
	end);
	YInput.FocusLost:connect(function (EnterPressed)
		local NewSize = tonumber(YInput.Text);
		if NewSize then
			SetAxisSize('Y', NewSize);
		end;
	end);
	ZInput.FocusLost:connect(function (EnterPressed)
		local NewSize = tonumber(ZInput.Text);
		if NewSize then
			SetAxisSize('Z', NewSize);
		end;
	end);

	-- Update the UI every 0.1 seconds
	UIUpdater = Support.ScheduleRecurringTask(UpdateUI, 0.1);

end;

function HideUI()
	-- Hides the tool UI

	-- Make sure there's a UI
	if not ResizeTool.UI then
		return;
	end;

	-- Hide the UI
	ResizeTool.UI.Visible = false;

	-- Stop updating the UI
	UIUpdater:Stop();

end;

function UpdateUI()
	-- Updates information on the UI

	-- Make sure the UI's on
	if not ResizeTool.UI then
		return;
	end;

	-- Only show and calculate selection info if it's not empty
	if #Selection.Items == 0 then
		ResizeTool.UI.Info.Visible = false;
		ResizeTool.UI.Size = UDim2.new(0, 245, 0, 90);
		return;
	else
		ResizeTool.UI.Info.Visible = true;
		ResizeTool.UI.Size = UDim2.new(0, 245, 0, 150);
	end;

	-----------------------------------------
	-- Update the size information indicators
	-----------------------------------------

	-- Identify common sizes across axes
	local XVariations, YVariations, ZVariations = {}, {}, {};
	for _, Part in pairs(Selection.Items) do
		table.insert(XVariations, Support.Round(Part.Size.X, 2));
		table.insert(YVariations, Support.Round(Part.Size.Y, 2));
		table.insert(ZVariations, Support.Round(Part.Size.Z, 2));
	end;
	local CommonX = Support.IdentifyCommonItem(XVariations);
	local CommonY = Support.IdentifyCommonItem(YVariations);
	local CommonZ = Support.IdentifyCommonItem(ZVariations);

	-- Shortcuts to indicators
	local XIndicator = ResizeTool.UI.Info.SizeInfo.X.TextBox;
	local YIndicator = ResizeTool.UI.Info.SizeInfo.Y.TextBox;
	local ZIndicator = ResizeTool.UI.Info.SizeInfo.Z.TextBox;

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

function SetDirections(DirectionMode)
	-- Sets the given resizing direction mode

	-- Update setting
	ResizeTool.Directions = DirectionMode;

	-- Update the UI switch
	if ResizeTool.UI then
		Core.ToggleSwitch(DirectionMode, ResizeTool.UI.DirectionsOption);
	end;

end;

local Handles;

-- Directions of resizing for each handle's dragged face
local AxisSizeMultipliers = {
	[Enum.NormalId.Top] = Vector3.new(0, 1, 0);
	[Enum.NormalId.Bottom] = Vector3.new(0, 1, 0);
	[Enum.NormalId.Front] = Vector3.new(0, 0, 1);
	[Enum.NormalId.Back] = Vector3.new(0, 0, 1);
	[Enum.NormalId.Left] = Vector3.new(1, 0, 0);
	[Enum.NormalId.Right] = Vector3.new(1, 0, 0);
};

-- Directions of positioning adjustment for each handle's dragged face
local AxisPositioningMultipliers = {
	[Enum.NormalId.Top] = Vector3.new(0, 1, 0);
	[Enum.NormalId.Bottom] = Vector3.new(0, -1, 0);
	[Enum.NormalId.Front] = Vector3.new(0, 0, -1);
	[Enum.NormalId.Back] = Vector3.new(0, 0, 1);
	[Enum.NormalId.Left] = Vector3.new(-1, 0, 0);
	[Enum.NormalId.Right] = Vector3.new(1, 0, 0);
};

function ShowHandles()
	-- Creates and automatically attaches handles to the currently focused part

	-- Autofocus handles on latest focused part
	Connections.AutofocusHandle = Selection.FocusChanged:connect(function ()
		Handles.Adornee = Selection.Focus;
	end);

	-- If handles already exist, only show them
	if Handles then
		Handles.Adornee = Selection.Focus;
		Handles.Visible = true;
		Handles.Parent = Core.UIContainer;
		return;
	end;

	-- Create the handles
	Handles = Create 'Handles' {
		Name = 'BTResizingHandles';
		Color = ResizeTool.Color;
		Parent = Core.UIContainer;
		Adornee = Selection.Focus;
	};

	--------------------------------------------------------
	-- Prepare for resizing parts when the handle is clicked
	--------------------------------------------------------

	local InitialState = {};
	local AreaPermissions;

	Handles.MouseButton1Down:connect(function ()

		-- Prevent selection
		Core.Targeting.CancelSelecting();

		-- Indicate resizing via handles
		HandleResizing = true;

		-- Stop parts from moving, and capture the initial state of the parts
		InitialState = PreparePartsForResizing();

		-- Track the change
		TrackChange();

		-- Cache area permissions information
		if Core.Mode == 'Tool' then
			AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Selection.Items), Core.Player);
		end;

		------------------------------------------------------
		-- Finalize changes to parts when the handle is let go
		------------------------------------------------------

		Connections.HandleRelease = UserInputService.InputEnded:connect(function (InputInfo, GameProcessedEvent)

			-- Make sure this was button 1 being released
			if InputInfo.UserInputType ~= Enum.UserInputType.MouseButton1 then
				return;
			end;

			-- Disable resizing
			HandleResizing = false;

			-- Prevent selection
			Core.Targeting.CancelSelecting();

			-- Clear this connection to prevent it from firing again
			Connections.HandleRelease:disconnect();
			Connections.HandleRelease = nil;

			-- Make joints, restore original anchor and collision states
			for _, Part in pairs(Selection.Items) do
				Part:MakeJoints();
				Part.Anchored = InitialState[Part].Anchored;
			end;

			-- Register the change
			RegisterChange();

		end);

	end);

	------------------------------------------
	-- Update parts when the handles are moved
	------------------------------------------

	Handles.MouseDrag:connect(function (Face, Distance)

		-- Only resize if handle is enabled
		if not HandleResizing then
			return;
		end;

		-- Calculate the increment-aligned drag distance
		Distance = GetIncrementMultiple(Distance, ResizeTool.Increment);

		-- Resize the parts on the selected faces by the calculated distance
		local Success, Adjustment = ResizePartsByFace(Face, Distance, ResizeTool.Directions, InitialState);

		-- If the resizing did not succeed, resize according to the suggested adjustment
		if not Success then
			ResizePartsByFace(Face, Adjustment, ResizeTool.Directions, InitialState);
		end;

		-- Update the "studs resized" indicator
		if ResizeTool.UI then
			ResizeTool.UI.Changes.Text.Text = 'resized ' .. Support.Round(math.abs(Adjustment or Distance), 3) .. ' studs';
		end;

		-- Make sure we're not entering any unauthorized private areas
		if Core.Mode == 'Tool' and Security.ArePartsViolatingAreas(Selection.Items, Core.Player, false, AreaPermissions) then
			for Part, PartState in pairs(InitialState) do
				Part.Size = PartState.Size;
				Part.CFrame = PartState.CFrame;
			end;
		end;

	end);

end;

function HideHandles()
	-- Hides the resizing handles

	-- Make sure handles exist and are visible
	if not Handles or not Handles.Visible then
		return;
	end;

	-- Hide the handles
	Handles.Visible = false;
	Handles.Parent = nil;

	-- Clear unnecessary resources
	Connections.AutofocusHandle:disconnect();
	Connections.AutofocusHandle = nil;

end;

function ResizePartsByFace(Face, Distance, Directions, InitialState)
	-- Resizes the selection on face `Face` by `Distance` studs, in the given `Directions`

	-- Adjust the size increment to the resizing direction mode
	if Directions == 'Both' then
		Distance = Distance * 2;
	end;

	-- Calculate the increment vector for this resizing
	local AxisSizeMultiplier = AxisSizeMultipliers[Face];
	local IncrementVector = Distance * AxisSizeMultiplier;

	-- Resize each part
	for _, Part in pairs(Selection.Items) do

		-- Make sure this increment will not undersize the part
		local TargetSize = InitialState[Part].Size + IncrementVector;
		local ShortestSize = math.min(TargetSize.X, TargetSize.Y, TargetSize.Z);
		if ShortestSize < 0.2 then

			-- Calculate and return how much to resize in order to normalize the resizing
			local SizeAdjustment = Distance + 0.2 - ShortestSize;
			return false, SizeAdjustment;

		end;

		-- Perform the size change
		Part.Size = InitialState[Part].Size + IncrementVector;

		-- Offset the part when resizing in the normal, one direction
		if Directions == 'Normal' then
			Part.CFrame = InitialState[Part].CFrame * CFrame.new(AxisPositioningMultipliers[Face] * Distance / 2);

		-- Keep the part centered when resizing in both directions
		elseif Directions == 'Both' then
			Part.CFrame = InitialState[Part].CFrame;

		end;

	end;

	-- Indicate that the resizing happened successfully
	return true;
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

			-- Toggle the current directions mode
			if ResizeTool.Directions == 'Normal' then
				SetDirections('Both');

			elseif ResizeTool.Directions == 'Both' then
				SetDirections('Normal');
			end;

		-- Check if the - key was pressed
		elseif InputInfo.KeyCode == Enum.KeyCode.Minus or InputInfo.KeyCode == Enum.KeyCode.KeypadMinus then

			-- Focus on the increment input
			if ResizeTool.UI then
				ResizeTool.UI.IncrementOption.Increment.TextBox:CaptureFocus();
			end;

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

		-- Start snapping when the R key is pressed down (and it's not Shift R)
		elseif InputInfo.KeyCode == Enum.KeyCode.R and not (Support.AreKeysPressed(Enum.KeyCode.LeftShift) or Support.AreKeysPressed(Enum.KeyCode.RightShift)) then
			StartSnapping();

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

		-- Make sure it wasn't pressed while typing
		if UserInputService:GetFocusedTextBox() then
			return;
		end;

		-- Finish snapping when the R key is released (and it's not Shift R)
		if InputInfo.KeyCode == Enum.KeyCode.R and not (Support.AreKeysPressed(Enum.KeyCode.LeftShift) or Support.AreKeysPressed(Enum.KeyCode.RightShift)) then
			FinishSnapping();

		end;

	end));

end;

function SetAxisSize(Axis, Size)
	-- Sets the selection's size on axis `Axis` to `Size`

	-- Track this change
	TrackChange();

	-- Prepare parts to be resized
	local InitialState = PreparePartsForResizing();

	-- Update each part
	for _, Part in pairs(Selection.Items) do

		-- Set the part's new size
		Part.Size = Vector3.new(
			Axis == 'X' and Size or Part.Size.X,
			Axis == 'Y' and Size or Part.Size.Y,
			Axis == 'Z' and Size or Part.Size.Z
		);

		-- Keep the part in place
		Part.CFrame = InitialState[Part].CFrame;

	end;

	-- Cache up permissions for all private areas
	local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Selection.Items), Core.Player);

	-- Revert changes if player is not authorized to resize parts towards the end destination
	if Core.Mode == 'Tool' and Security.ArePartsViolatingAreas(Selection.Items, Core.Player, false, AreaPermissions) then
		for Part, PartState in pairs(InitialState) do
			Part.Size = PartState.Size;
			Part.CFrame = PartState.CFrame;
		end;
	end;

	-- Restore the parts' original states
	for Part, PartState in pairs(InitialState) do
		Part:MakeJoints();
		Part.Anchored = InitialState[Part].Anchored;
	end;

	-- Register the change
	RegisterChange();

end;

function NudgeSelectionByFace(Face)
	-- Nudges the size of the selection in the direction of the given face

	-- Track this change
	TrackChange();

	-- Prepare parts to be resized
	local InitialState = PreparePartsForResizing();

	-- Perform the resizing
	local Success = ResizePartsByFace(Face, ResizeTool.Increment, ResizeTool.Directions, InitialState);

	-- If the resizing did not succeed, revert the parts to their original state
	if not Success then
		for Part, PartState in pairs(InitialState) do
			Part.Size = PartState.Size;
			Part.CFrame = PartState.CFrame;
		end;
	end;

	-- Cache up permissions for all private areas
	local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Selection.Items), Core.Player);

	-- Revert changes if player is not authorized to resize parts towards the end destination
	if Core.Mode == 'Tool' and Security.ArePartsViolatingAreas(Selection.Items, Core.Player, false, AreaPermissions) then
		for Part, PartState in pairs(InitialState) do
			Part.Size = PartState.Size;
			Part.CFrame = PartState.CFrame;
		end;
	end;

	-- Restore the parts' original states
	for Part, PartState in pairs(InitialState) do
		Part:MakeJoints();
		Part.Anchored = InitialState[Part].Anchored;
	end;

	-- Register the change
	RegisterChange();

end;

function TrackChange()

	-- Start the record
	HistoryRecord = {
		Parts = Support.CloneTable(Selection.Items);
		BeforeSize = {};
		AfterSize = {};
		BeforeCFrame = {};
		AfterCFrame = {};

		Unapply = function (Record)
			-- Reverts this change

			-- Select the changed parts
			Selection.Replace(Record.Parts);

			-- Put together the change request
			local Changes = {};
			for _, Part in pairs(Record.Parts) do
				table.insert(Changes, { Part = Part, Size = Record.BeforeSize[Part], CFrame = Record.BeforeCFrame[Part] });
			end;

			-- Send the change request
			Core.SyncAPI:Invoke('SyncResize', Changes);

		end;

		Apply = function (Record)
			-- Applies this change

			-- Select the changed parts
			Selection.Replace(Record.Parts);

			-- Put together the change request
			local Changes = {};
			for _, Part in pairs(Record.Parts) do
				table.insert(Changes, { Part = Part, Size = Record.AfterSize[Part], CFrame = Record.AfterCFrame[Part] });
			end;

			-- Send the change request
			Core.SyncAPI:Invoke('SyncResize', Changes);

		end;

	};

	-- Collect the selection's initial state
	for _, Part in pairs(HistoryRecord.Parts) do
		HistoryRecord.BeforeSize[Part] = Part.Size;
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
		HistoryRecord.AfterSize[Part] = Part.Size;
		HistoryRecord.AfterCFrame[Part] = Part.CFrame;
		table.insert(Changes, { Part = Part, Size = Part.Size, CFrame = Part.CFrame });
	end;

	-- Send the change to the server
	Core.SyncAPI:Invoke('SyncResize', Changes);

	-- Register the record and clear the staging
	Core.History.Add(HistoryRecord);
	HistoryRecord = nil;

end;

function PreparePartsForResizing()
	-- Prepares parts for resizing and returns the initial state of the parts

	local InitialState = {};

	-- Stop parts from moving, and capture the initial state of the parts
	for _, Part in pairs(Selection.Items) do
		InitialState[Part] = { Anchored = Part.Anchored, Size = Part.Size, CFrame = Part.CFrame };
		Part.Anchored = true;
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

-- Event that fires when a new point is snapped
PointSnapped = Core.RbxUtility.CreateSignal();

function StartSnapping()

	-- Make sure snapping isn't already enabled
	if SnapTracking.Enabled then
		return;
	end;

	-- Only enable corner snapping
	SnapTracking.TrackEdgeMidpoints = false;
	SnapTracking.TrackFaceCentroids = false;
	SnapTracking.TargetFilter = Selection.Find;

	-- Trigger the PointSnapped event when a new point is snapped
	SnapTracking.StartTracking(function (NewPoint)
		if NewPoint and NewPoint.p ~= SnappedPoint then
			SnappedPoint = NewPoint.p;
			PointSnapped:fire(NewPoint.p);
		end;
	end);

	-- Listen for when the user starts dragging while in snap mode
	Connections.SnapDragStart = Support.AddUserInputListener('Began', 'MouseButton1', false, function (Input)

		SnappingStage = 'Direction';
		SnappingStartAim = Vector2.new(Input.Position.X, Input.Position.Y);
		SnappingStartPoint = SnappedPoint;
		SnappingStartTarget = SnapTracking.Target;
		SnappingStartDirections = GetFaceOffsetsFromCorner(SnappingStartTarget, SnappingStartPoint);
		SnappingStartSelectionState = PreparePartsForResizing();

		TrackChange();

		-- Listen for when the user drags
		Connections.SnapDrag = Support.AddUserInputListener('Changed', 'MouseMovement', false, function (Input)

			-- Update the latest aim
			SnappingEndAim = Vector2.new(Input.Position.X, Input.Position.Y);

			-- Use the mouse position to figure out the resize direction (until after 20px)
			if SnappingStage == 'Direction' then

				-- Check the length
				local Length = (SnappingEndAim - SnappingStartAim).magnitude;
				if Length < 20 then
					return;
				end;

				local DragSlope = (SnappingEndAim.Y - SnappingStartAim.Y) / (SnappingEndAim.X - SnappingStartAim.X);

				-- Go through corner offsets representing the possible directions
				local Directions = {};
				for _, Direction in pairs(SnappingStartDirections) do

					-- Map the corner & corner offset to screen points
					local ScreenSnappedPoint = Workspace.CurrentCamera:WorldToScreenPoint(SnappingStartPoint);
					local ScreenOffsetPoint = Workspace.CurrentCamera:WorldToScreenPoint(Direction.Offset);

					-- Get the slope representing the direction (based on the mapped screen points)
					local DirectionSlope = (ScreenOffsetPoint.Y - ScreenSnappedPoint.Y) / (ScreenOffsetPoint.X - ScreenSnappedPoint.X);

					-- Calculate the similarity between the drag & direction slopes
					local SlopeDelta = math.abs(math.abs(DragSlope) - math.abs(DirectionSlope));
					table.insert(Directions, { Face = Direction.Face, SlopeDelta = SlopeDelta, Offset = Direction.Offset });

				end;

				-- Get the direction slope closest to the mouse's
				table.sort(Directions, function (A, B)
					return A.SlopeDelta < B.SlopeDelta;
				end);

				-- Select the resizing direction that was closest to the mouse drag
				SnappingDirection = Directions[1].Face;
				SnappingDirectionOffset = Directions[1].Offset;

				-- Move to the destination-picking stage of snapping
				SnappingStage = 'Destination';

				SnapTracking.TargetFilter = function (Target) return not Target.Locked; end;
				SnapTracking.TargetBlacklist = Selection.Items;

			-- Resize in the selected direction up to the targeted destination
			elseif SnappingStage == 'Destination' then

			end;

		end);

		-- Listen for when a new point is snapped
		Connections.Snap = PointSnapped:connect(function (SnappedPoint)

			if SnappingStage == 'Destination' then
				local Direction = (SnappingDirectionOffset - SnappingStartPoint).unit;
				local Distance = (SnappedPoint - SnappingStartPoint):Dot(Direction);

				-- Resize the parts on the selected faces by the calculated distance
				local Success, Adjustment = ResizePartsByFace(SnappingDirection, Distance, 'Normal', SnappingStartSelectionState);

				-- If the resizing did not succeed, resize according to the suggested adjustment
				if not Success then
					ResizePartsByFace(SnappingDirection, Adjustment, 'Normal', SnappingStartSelectionState);
				end;

			end;

		end);

		Connections.SnapDragEnd = Support.AddUserInputListener('Ended', 'MouseButton1', false, function (Input)
			-- Restore the parts' original states
			for Part, PartState in pairs(SnappingStartSelectionState) do
				Part:MakeJoints();
				Part.Anchored = PartState.Anchored;
			end;
			RegisterChange();
		end);

	end);

end;

function FinishSnapping()

	-- Make sure snapping is enabled
	if not SnapTracking.Enabled then
		return;
	end;

	-- Stop snap point tracking
	SnapTracking.StopTracking();

	Connections.SnapDragStart:disconnect();
	Connections.SnapDragStart = nil;

	if Connections.Snap then

		Connections.Snap:disconnect();
		Connections.Snap = nil;

		Connections.SnapDrag:disconnect();
		Connections.SnapDrag = nil;

	end;

end;


function GetFaceOffsetsFromCorner(Part, Point)
	-- Returns offsets of the given corner point in the direction of its intersecting faces

	local Offsets = {};

	-- Go through each face the corner intersects
	local Faces = GetFacesFromCorner(Part, Point);
	for _, Face in pairs(Faces) do

		-- Calculate the offset from the corner in the direction of the face
		local Offset = CFrame.new(Point) * CFrame.Angles(Part.CFrame:toEulerAnglesXYZ()) * Vector3.FromNormalId(Face);
		table.insert(Offsets, { Face = Face, Offset = Offset });

	end;

	-- Return the list of offsets
	return Offsets;
end;

function GetFacesFromCorner(Part, Point)
	-- Returns the 3 faces that the given corner point intersects

	local Faces = {};

	-- Get all the face centers of the part
	for _, FaceEnum in pairs(Enum.NormalId:GetEnumItems()) do
		local Face = Part.CFrame * (Part.Size / 2 * Vector3.FromNormalId(FaceEnum));

		-- Get the face's proximity to the point
		local Proximity = (Point - Face).magnitude;

		-- Keep track of the proximity to the point
		table.insert(Faces, { Proximity = Proximity, Face = FaceEnum });
	end;

	-- Find the closest faces to the point
	table.sort(Faces, function (A, B)
		return A.Proximity < B.Proximity;
	end);

	-- Return the 3 closest faces
	return { Faces[1].Face, Faces[2].Face, Faces[3].Face };
end;

-- Return the tool
return ResizeTool;