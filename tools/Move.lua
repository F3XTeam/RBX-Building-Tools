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
Support.ImportServices();

-- Load necessary external modules
RegionModule = require(Core.Tool:WaitForChild 'Region by AxisAngle');

-- Initialize the tool
local MoveTool = {

	Name = 'Move Tool';
	Color = BrickColor.new 'Deep orange';

	-- Default options
	Increment = 1;
	Axes = 'Global';

	-- Standard platform event interface
	Listeners = {};

};

-- Container for temporary connections (disconnected automatically)
local Connections = {};

function Equip()
	-- Enables the tool's equipped functionality

	-- Set our current axis mode
	SetAxes(MoveTool.Axes);

	-- Start up our interface
	ShowUI();
	BindShortcutKeys();
	EnableDragging();

end;

function Unequip()
	-- Disables the tool's equipped functionality

	-- If dragging, finish dragging
	if Dragging then
		FinishDragging();
	end;

	-- Clear unnecessary resources
	HideUI();
	ClearConnections();
	Core.ClearBoundingBox();

end;

MoveTool.Listeners.Equipped = Equip;
MoveTool.Listeners.Unequipped = Unequip;

function ClearConnections()
	-- Clears out temporary connections

	for ConnectionKey, Connection in pairs(Connections) do
		Connection:disconnect();
		Connections[ConnectionKey] = nil;
	end;

end;

function ShowUI()
	-- Creates and reveals the UI

	-- Only reveal UI if already created
	if MoveTool.UI then
		MoveTool.UI.Visible = true;
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
		IncrementInput.Text = MoveTool.Increment;
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
	Core.ScheduleRecurringTask(UpdateUI, 0.1);

end;

function HideUI()
	-- Hides the tool UI

	-- Make sure there's a UI
	if not MoveTool.UI then
		return;
	end;

	-- Hide the UI
	MoveTool.UI.Visible = false;

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
		return;
	else
		MoveTool.UI.Info.Visible = true;
	end;

	---------------------------------------------
	-- Update the position information indicators
	---------------------------------------------

	-- Identify common positions across axes
	local XVariations, YVariations, ZVariations = {}, {}, {};
	for _, Part in pairs(Selection.Items) do
		table.insert(XVariations, Support.Round(Part.Position.X, 2));
		table.insert(YVariations, Support.Round(Part.Position.Y, 2));
		table.insert(ZVariations, Support.Round(Part.Position.Z, 2));
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
	Core.ClearBoundingBox();

	-- For global mode, use bounding box handles
	if AxisMode == 'Global' then
		Core.StartBoundingBox(AttachHandles);

	-- For local mode, use focused part handles
	elseif AxisMode == 'Local' then
		AttachHandles(Selection.Last, true); 

	-- For last mode, use focused part handles
	elseif AxisMode == 'Last' then
		AttachHandles(Selection.Last, true);
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
		Connections.AutofocusHandle = Selection.Changed:connect(function ()
			Handles.Adornee = Selection.Last;
		end);

	-- Disable autofocus if not requested and on
	elseif not Autofocus and Connections.AutofocusHandle then
		Connections.AutofocusHandle:disconnect();
		Connections.AutofocusHandle = nil;
	end;

	-- Just attach the handles if they already exist
	if Handles then
		Handles.Adornee = Part;
		return;
	end;

	-- Create the handles
	Handles = Create 'Handles' {
		Name = 'BTMovementHandles';
		Color = MoveTool.Color;
		Parent = Core.GUIContainer;
		Adornee = Part;
	};

	------------------------------------------------------
	-- Prepare for moving parts when the handle is clicked
	------------------------------------------------------

	local InitialState = {};
	local AreaPermissions;

	Handles.MouseButton1Down:connect(function ()

		-- Prevent selection
		Core.override_selection = true;

		-- Stop parts from moving, and capture the initial state of the parts
		for _, Part in pairs(Selection.Items) do
			InitialState[Part] = { Anchored = Part.Anchored, CFrame = Part.CFrame, CanCollide = Part.CanCollide };
			Part.Anchored = true;
			Part.CanCollide = false;
			Part:BreakJoints();
			Part.Velocity = Vector3.new();
			Part.RotVelocity = Vector3.new();
		end;

		-- Track the change
		TrackChange();

		-- Cache area permissions information
		AreaPermissions = GetPermissionsCache();

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

	Handles.MouseDrag:connect(function (Face, Distance)

		-- Calculate the increment-aligned drag distance
		Distance = GetIncrementMultiple(Distance, MoveTool.Increment);

		--------------------------------------------------------------------
		-- Move the parts along the selected axes by the calculated distance
		--------------------------------------------------------------------

		-- Get the axis multiplier for this face
		local AxisMultiplier = AxisMultipliers[Face];

		for _, Part in pairs(Selection.Items) do

			-- Move along standard axes
			if MoveTool.Axes == 'Global' then
				Part.CFrame = InitialState[Part].CFrame + (Distance * AxisMultiplier);

			-- Move along item's axes
			elseif MoveTool.Axes == 'Local' then
				Part.CFrame = InitialState[Part].CFrame * CFrame.new(Distance * AxisMultiplier);

			-- Move along focused part's axes
			elseif MoveTool.Axes == 'Last' then

				-- Calculate the focused part's position
				local RelativeTo = InitialState[Selection.Last].CFrame * CFrame.new(Distance * AxisMultiplier);

				-- Calculate how far apart we should be from the focused part
				local Offset = InitialState[Selection.Last].CFrame:toObjectSpace(InitialState[Part].CFrame);

				-- Move relative to the focused part by this part's offset from it
				Part.CFrame = RelativeTo * Offset;

			end;

		end;

		----------------------------------------
		-- Check for relevant area authorization
		----------------------------------------

		-- Make sure we're not entering any unauthorized private areas
		if ArePartsViolatingAreas(AreaPermissions) then
			Selection.Last.CFrame = InitialState[Selection.Last].CFrame;
			TranslatePartsRelativeToPart(Selection.Last, InitialState, Selection.Items);
		end;

	end);

end;

function BindShortcutKeys()
	-- Enables useful shortcut keys for this tool

	-- Track user input while this tool is equipped
	table.insert(Connections, UserInputService.InputBegan:connect(function (InputInfo, GameProcessedEvent)

		-- Make sure this is an intentional event
		if GameProcessedEvent then
			return;
		end;

		-- Make sure this is input is a key press
		if InputInfo.UserInputType ~= Enum.UserInputType.Keyboard then
			return;
		end;

		-- Check if the enter key was pressed
		if InputInfo.KeyCode == Enum.KeyCode.Return or InputInfo.KeyCode == Enum.KeyCode.KeypadEnter then

			-- Make sure it wasn't pressed while typing
			if UserInputService:GetFocusedTextBox() then
				return;
			end;

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

			-- Make sure it wasn't pressed while typing
			if UserInputService:GetFocusedTextBox() then
				return;
			end;

			-- Focus on the increment input
			if MoveTool.UI then
				MoveTool.UI.IncrementOption.Increment.TextBox:CaptureFocus();
			end;

		end;

	end));

end;

function SetAxisPosition(Axis, Position)
	-- Sets the selection's position on axis `Axis` to `Position`

	-- Track this change
	TrackChange();

	-- Update each part
	for _, Part in pairs(Selection.Items) do
		Part.CFrame = CFrame.new(
			Axis == 'X' and Position or Part.Position.X,
			Axis == 'Y' and Position or Part.Position.Y,
			Axis == 'Z' and Position or Part.Position.Z
		) * CFrame.Angles(Part.CFrame:toEulerAnglesXYZ());
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

			-- Clear the selection
			Selection:clear();

			-- Put together the change request
			local Changes = {};
			for _, Part in pairs(Record.Parts) do
				table.insert(Changes, { Part = Part, CFrame = Record.BeforeCFrame[Part] });

				-- Select the part
				Selection:add(Part);
			end;

			-- Send the change request
			Core.ServerAPI:InvokeServer('SyncMove', Changes);

		end;

		Apply = function (Record)
			-- Applies this change

			-- Clear the selection
			Selection:clear();

			-- Put together the change request
			local Changes = {};
			for _, Part in pairs(Record.Parts) do
				table.insert(Changes, { Part = Part, CFrame = Record.AfterCFrame[Part] });

				-- Select the part
				Selection:add(Part);
			end;

			-- Send the change request
			Core.ServerAPI:InvokeServer('SyncMove', Changes);

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
	Core.ServerAPI:InvokeServer('SyncMove', Changes);

	-- Register the record and clear the staging
	Core.History:Add(HistoryRecord);
	HistoryRecord = nil;

end;

function EnableDragging()
	-- Enables part dragging

	-- Pay attention to when the user intends to start dragging
	Connections.DragStart = Core.Mouse.Button1Down:connect(function ()

		-- Make sure target is draggable
		if not Core.isSelectable(Core.Mouse.Target) then
			return;
		end;

		-- Make sure this click was not to select
		if Core.selecting then
			return;
		end;

		-- Select the target if it's not selected
		if not Selection:find(Core.Mouse.Target) then
			Selection:clear();
			Selection:add(Core.Mouse.Target);
		end;

		-- Prepare for dragging
		SetUpDragging(Core.Mouse.Target);

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

	-- Prevent selection
	Core.override_selection = true;

	-- Finish dragging
	FinishDragging();

	-- Reset normal axes option state
	SetAxes(MoveTool.Axes);

end);

function SetUpDragging(BasePart)
	-- Sets up and initiates dragging based on the given base part

	-- Prevent selection while dragging
	Core.override_selection = true;

	-- Prepare parts, and start dragging
	InitialState = PreparePartsForDragging();
	StartDragging(BasePart, InitialState);

end;

MoveTool.SetUpDragging = SetUpDragging;

function PreparePartsForDragging()
	-- Prepares parts for dragging and returns the initial state of the parts

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

function StartDragging(BasePart, InitialState)
	-- Begins dragging the selection

	-- Indicate that we're dragging
	Dragging = true;

	-- Track changes
	TrackChange();

	-- Disable bounding box calculation
	Core.ClearBoundingBox();

	-- Cache area permissions information
	local AreaPermissions = GetPermissionsCache();

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

	-- Perform the mouse target search
	local Target, TargetPoint, TargetNormal = Workspace:FindPartOnRayWithIgnoreList(
		Ray.new(Core.Mouse.UnitRay.Origin, Core.Mouse.UnitRay.Direction * 5000),
		IgnoreList
	);

	------------------------------------------------
	-- Move the selection towards the right location
	------------------------------------------------

	-- Get the increment-aligned target point
	TargetPoint = GetAlignedTargetPoint(Target, TargetPoint, TargetNormal);

	-- Move the parts towards their target destination
	BasePart.CFrame = CFrame.new(TargetPoint + BasePartOffset) * CFrame.Angles(BasePart.CFrame:toEulerAnglesXYZ());
	TranslatePartsRelativeToPart(BasePart, InitialState, Selection.Items);

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
	BasePart.CFrame = CFrame.new(TargetPoint + BasePartOffset) * CFrame.Angles(BasePart.CFrame:toEulerAnglesXYZ()) - (TargetNormal * CrossthroughCorrection);
	TranslatePartsRelativeToPart(BasePart, InitialState, Selection.Items);

	----------------------------------------
	-- Check for relevant area authorization
	----------------------------------------

	-- Make sure we're not entering any unauthorized private areas
	if ArePartsViolatingAreas(AreaPermissions) then
		BasePart.CFrame = InitialState[BasePart].CFrame;
		TranslatePartsRelativeToPart(BasePart, InitialState, Selection.Items);
	end;

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

function GetPermissionsCache()
	-- Returns a cache of the current player's authorization to all areas

	-- Make sure security is enabled
	if Core.ToolType ~= 'tool' or not Core.Security.AreAreasEnabled() then
		return;
	end;

	-- Build the cache of permissions for each area
	local Cache = {};
	for _, Area in pairs(Core.Security.Areas:GetChildren()) do
		Cache[Area] = Core.Security.IsAreaAuthorizedForPlayer(Area, Core.Player);
	end;

	-- Return the permissions cache
	return Cache;
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

function ArePartsViolatingAreas(AreaPermissions)
	-- Returns whether the selected parts are inside any unauthorized parts

	-- Make sure area security is being enforced
	if Core.ToolType ~= 'tool' or not Core.Security.AreAreasEnabled() then
		return false;
	end;
	
	-- Go through each area and check if any part violates its permissions
	for Area, Authorized in pairs(AreaPermissions) do

		-- Get all parts from the selection within this area
		local Region = RegionModule.new(
			Area.CFrame * CFrame.new(0, Area.Size.Y / 2 + Core.Security.AreaHeight / 2, 0),
			Vector3.new(Area.Size.X, Core.Security.AreaHeight, Area.Size.Z)
		);
		local ContainedParts = Region:CastParts(Selection.Items);

		-- If parts end up in this area, check if it's unauthorized
		if #ContainedParts > 0 and not Authorized then
			return true;
		end;

	end;

	-- If no area authorization violations occur, return false
	return false;
end;

function TranslatePartsRelativeToPart(BasePart, InitialState, Parts)

	for _, Part in pairs(Parts) do

		-- Calculate the focused part's position
		local RelativeTo = InitialState[BasePart].CFrame;

		-- Calculate how far apart we should be from the focused part
		local Offset = RelativeTo:toObjectSpace(InitialState[Part].CFrame);

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

	-- Stop the dragging action
	Connections.Drag:disconnect()
	Connections.Drag = nil;

	-- Restore the original state of each part
	for _, Part in pairs(Selection.Items) do
		Part.CanCollide = InitialState[Part].CanCollide;
		Part:MakeJoints();
		Part.Anchored = InitialState[Part].Anchored;
	end;

	-- Register changes
	RegisterChange();

end;

-- Mark the tool as fully loaded
Core.Tools.Move = MoveTool;
MoveTool.Loaded = true;