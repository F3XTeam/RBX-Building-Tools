-- Load the main tool's core environment when it's ready
repeat wait() until (
	_G.BTCoreEnv and
	_G.BTCoreEnv[script.Parent.Parent] and
	_G.BTCoreEnv[script.Parent.Parent].CoreReady
);
Core = _G.BTCoreEnv[script.Parent.Parent];

-- Import relevant references
Selection = Core.Selection;
Create = Core.Create;
Support = Core.Support;
Security = Core.Security;
SnapTracking = Core.SnapTracking;
Support.ImportServices();

-- Initialize the tool
local RotateTool = {

	Name = 'Rotate Tool';
	Color = BrickColor.new 'Bright green';

	-- Default options
	Increment = 15;
	Pivot = 'Center';

	-- Standard platform event interface
	Listeners = {};

};

-- Container for temporary connections (disconnected automatically)
local Connections = {};

function Equip()
	-- Enables the tool's equipped functionality

	-- Set our current pivot mode
	SetPivot(RotateTool.Pivot);

	-- Start up our interface
	ShowUI();
	BindShortcutKeys();

end;

function Unequip()
	-- Disables the tool's equipped functionality

	-- Clear unnecessary resources
	HideUI();
	HideHandles();
	ClearConnections();
	Core.ClearBoundingBox();
	SnapTracking.StopTracking();

end;

RotateTool.Listeners.Equipped = Equip;
RotateTool.Listeners.Unequipped = Unequip;

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
	if RotateTool.UI then

		-- Reveal the UI
		RotateTool.UI.Visible = true;

		-- Update the UI every 0.1 seconds
		UIUpdater = Core.ScheduleRecurringTask(UpdateUI, 0.1);

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
		IncrementInput.Text = RotateTool.Increment;
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
	UIUpdater = Core.ScheduleRecurringTask(UpdateUI, 0.1);

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
		table.insert(XVariations, Support.Round(Part.Rotation.X, 2));
		table.insert(YVariations, Support.Round(Part.Rotation.Y, 2));
		table.insert(ZVariations, Support.Round(Part.Rotation.Z, 2));
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
	Core.ClearBoundingBox();

	-- For center mode, use bounding box handles
	if PivotMode == 'Center' then
		Core.StartBoundingBox(AttachHandles);

	-- For local mode, use focused part handles
	elseif PivotMode == 'Local' then
		AttachHandles(Selection.Focus, true); 

	-- For last mode, use focused part handles
	elseif PivotMode == 'Last' then
		AttachHandles(Selection.Focus, true);
	end;

end;

local Handles;

function AttachHandles(Part, Autofocus)
	-- Creates and attaches handles to `Part`, and optionally automatically attaches to the focused part
	
	-- Enable autofocus if requested and not already on
	if Autofocus and not Connections.AutofocusHandle then
		Connections.AutofocusHandle = Selection.FocusChanged:connect(function ()
			Handles.Adornee = Selection.Focus;
		end);

	-- Disable autofocus if not requested and on
	elseif not Autofocus and Connections.AutofocusHandle then
		Connections.AutofocusHandle:disconnect();
		Connections.AutofocusHandle = nil;
	end;

	-- Just attach and show the handles if they already exist
	if Handles then
		Handles.Adornee = Part;
		Handles.Visible = true;
		return;
	end;

	-- Create the handles
	Handles = Create 'ArcHandles' {
		Name = 'BTRotationHandles';
		Color = RotateTool.Color;
		Parent = Core.GUIContainer;
		Adornee = Part;
	};

	--------------------------------------------------------
	-- Prepare for rotating parts when the handle is clicked
	--------------------------------------------------------

	local InitialState = {};
	local AreaPermissions;
	local PivotPoint;

	Handles.MouseButton1Down:connect(function ()

		-- Prevent selection
		Core.override_selection = true;

		-- Stop parts from moving, and capture the initial state of the parts
		InitialState = PreparePartsForRotating();

		-- Track the change
		TrackChange();

		-- Cache area permissions information
		if Core.ToolType == 'tool' then
			AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Selection.Items), Core.Player);
		end;

		-- Set the pivot point to the center of the selection if in Center mode
		if RotateTool.Pivot == 'Center' then
			local BoundingBoxSize, BoundingBoxCFrame = Core.CalculateExtents(Selection.Items, StaticExtents);
			PivotPoint = BoundingBoxCFrame;

		-- Set the pivot point to the center of the focused part if in Last mode
		elseif RotateTool.Pivot == 'Last' then
			PivotPoint = InitialState[Selection.Focus].CFrame;
		end;

		------------------------------------------------------
		-- Finalize changes to parts when the handle is let go
		------------------------------------------------------

		Connections.HandleRelease = UserInputService.InputEnded:connect(function (InputInfo, GameProcessedEvent)

			-- Make sure this was button 1 being released
			if InputInfo.UserInputType ~= Enum.UserInputType.MouseButton1 then
				return;
			end;

			-- Prevent selection
			Core.override_selection = true;

			-- Clear this connection to prevent it from firing again
			Connections.HandleRelease:disconnect();
			Connections.HandleRelease = nil;

			-- Make joints, restore original anchor and collision states
			for _, Part in pairs(Selection.Items) do
				Part.CanCollide = InitialState[Part].CanCollide;
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

	Handles.MouseDrag:connect(function (Axis, Rotation)

		-- Turn the rotation amount into degrees
		Rotation = math.deg(Rotation);

		-- Calculate the increment-aligned rotation amount
		Rotation = GetIncrementMultiple(Rotation, RotateTool.Increment);

		-- Perform the rotation
		RotatePartsAroundPivot(RotateTool.Pivot, PivotPoint, Axis, Rotation, Selection.Items, InitialState);

		-- Update the "degrees rotated" indicator
		if RotateTool.UI then
			RotateTool.UI.Changes.Text.Text = 'rotated ' .. math.abs(Rotation) .. ' degrees';
		end;

		-- Make sure we're not entering any unauthorized private areas
		if Core.ToolType == 'tool' and Security.ArePartsViolatingAreas(Selection.Items, Core.Player, AreaPermissions) then
			for Part, PartState in pairs(InitialState) do
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

	-- Disable handle autofocus if enabled
	if Connections.AutofocusHandle then
		Connections.AutofocusHandle:disconnect();
		Connections.AutofocusHandle = nil;
	end;

end;

function RotatePartsAroundPivot(PivotMode, PivotPoint, Axis, Rotation, Parts, InitialState)
	-- Rotates the given `Parts` around `PivotMode` (using `PivotPoint` if applicable)'s `Axis` by `Rotation`

	-- Create a CFrame that increments rotation by `Rotation` around `Axis`
	local RotationCFrame = CFrame.fromAxisAngle(Vector3.FromAxis(Axis), math.rad(Rotation));

	-- Rotate each part
	for _, Part in pairs(Parts) do

		-- Rotate around the selection's center, or the currently focused part
		if PivotMode == 'Center' or PivotMode == 'Last' then

			-- Calculate the focused part's rotation
			local RelativeTo = PivotPoint * RotationCFrame;

			-- Calculate this part's offset from the focused part's rotation
			local Offset = PivotPoint:toObjectSpace(InitialState[Part].CFrame);

			-- Rotate relative to the focused part by this part's offset from it
			Part.CFrame = RelativeTo * Offset;

		-- Rotate around the part's center
		elseif RotateTool.Pivot == 'Local' then
			Part.CFrame = InitialState[Part].CFrame * RotationCFrame;

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

		end;

	end));

end;

function SetAxisAngle(Axis, Angle)
	-- Sets the selection's angle on axis `Axis` to `Angle`

	-- Turn the given angle from degrees to radians
	local Angle = math.rad(Angle);

	-- Track this change
	TrackChange();

	-- Prepare parts to be moved
	local InitialState = PreparePartsForRotating();

	-- Update each part
	for _, Part in pairs(Selection.Items) do

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
	if Core.ToolType == 'tool' and Security.ArePartsViolatingAreas(Selection.Items, Core.Player, AreaPermissions) then
		for Part, PartState in pairs(InitialState) do
			Part.CFrame = PartState.CFrame;
		end;
	end;

	-- Restore the parts' original states
	for Part, PartState in pairs(InitialState) do
		Part.CanCollide = InitialState[Part].CanCollide;
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
			Core.ServerAPI:InvokeServer('SyncRotate', Changes);

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
			Core.ServerAPI:InvokeServer('SyncRotate', Changes);

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
	Core.ServerAPI:InvokeServer('SyncRotate', Changes);

	-- Register the record and clear the staging
	Core.History:Add(HistoryRecord);
	HistoryRecord = nil;

end;

function PreparePartsForRotating()
	-- Prepares parts for rotating and returns the initial state of the parts

	local InitialState = {};

	-- Stop parts from moving, and capture the initial state of the parts
	for _, Part in pairs(Selection.Items) do
		InitialState[Part] = { Anchored = Part.Anchored, CFrame = Part.CFrame, CanCollide = Part.CanCollide };
		Part.Anchored = true;
		Part.CanCollide = false;
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

-- Mark the tool as fully loaded
Core.Tools.Rotate = RotateTool;
RotateTool.Loaded = true;