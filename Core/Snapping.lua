-- Libraries
Core = require(script.Parent);
Support = Core.Support;

SnapTracking = {};
SnapTracking.Enabled = false;
SnapTracking.TrackCorners = true;
SnapTracking.TrackFaceCentroids = true;
SnapTracking.TrackEdgeMidpoints = true;

function SnapTracking.StartTracking(Callback)
	-- Starts displaying the given target's snap point nearest to the mouse, calls back every time a new point is approached

	-- Make sure tracking isn't already on
	if SnapTracking.Enabled then
		SnapTracking.StopTracking();
	end;

	-- Indicate that tracking is now enabled
	SnapTracking.Enabled = true;

	-- Disable selection
	Core.Targeting.CancelSelecting();

	-- Start the UI
	SnapTracking.StartUI();

	-- Store callback to send changes in current snapping point
	SnapTracking.SetCallback(Callback);

	-- Start tracking mouse movement
	function UpdateTrackingTarget(Input)

		-- Blacklist the player's character and the items in `TargetBlacklist`
		local TargetBlacklist = Support.ConcatTable(
			{ Player and Player.Character },
			SnapTracking.TargetBlacklist or {}
		);

		-- Find the current target part and point
		local TargetRay = Workspace.CurrentCamera:ScreenPointToRay(Input.Position.X, Input.Position.Y);
		local TargetPart, TargetPoint, TargetNormal, TargetMaterial = Workspace:FindPartOnRayWithIgnoreList(
			Ray.new(TargetRay.Origin, TargetRay.Direction * 5000),
			TargetBlacklist
		);

		-- Make sure a target part exists
		if not TargetPart then
			return;
		end;

		-- Check with any snapping target filter
		if SnapTracking.TargetFilter and not SnapTracking.TargetFilter(TargetPart) then
			return;
		end;

		-- Set the current target for snap point tracking
		SnapTracking.MousePoint = TargetPoint;
		SnapTracking.SetTrackingTarget(TargetPart);

	end;

	-- Update the tracking and UI to the current mouse and proximity state
	if not SnapTracking.CustomMouseTracking then
		SnapTracking.MouseTracking = Support.AddUserInputListener('Changed', 'MouseMovement', false, UpdateTrackingTarget);
		UpdateTrackingTarget({ Position = Vector2.new(Core.Mouse.X, Core.Mouse.Y) });
		SnapTracking.Update();
	end;

end;

function SnapTracking.SetCallback(Callback)
	-- Sets the function that is called back whenever a new snap point is in focus
	SnapTracking.Callback = Callback;
end;

function SnapTracking.StartUI()
	-- Creates the point marking UI
	SnapTracking.PointMarker = Core.Tool.Interfaces.PointMarker:Clone();
	SnapTracking.PointMarker.Parent = Core.UI;
end;

function SnapTracking.ClearUI()
	-- Removes the point marking UI

	-- Make sure tracking is currently enabled
	if not SnapTracking.Enabled then
		return;
	end;

	-- Remove the point marker UI
	SnapTracking.PointMarker:Destroy();
	SnapTracking.PointMarker = nil;

end;

function SnapTracking.Update()
	-- Updates the current closest point, reflects it on UI, calls callback function

	-- Make sure tracking is currently enabled
	if not SnapTracking.Enabled then
		return;
	end;

	-- Calculate the closest point
	local ClosestPoint = SnapTracking.GetClosestPoint();

	-- Inform the callback function
	SnapTracking.Callback(ClosestPoint);

	-- Update the point marker UI
	SnapTracking.UpdateUI(ClosestPoint);

end;

function SnapTracking.UpdateUI(Point)
	-- Updates the point marker UI to reflect the position of the current closest snap point

	-- Make sure tracking is enabled, and that the UI has started
	if not SnapTracking.Enabled or not SnapTracking.PointMarker then
		return;
	end;

	-- Make sure there's actually a point that needs to be marked, or hide the point marker
	if not Point then
		SnapTracking.PointMarker.Visible = false;
		return;
	end;

	-- Map the point's position on the screen
	local PointPosition, PointVisible = Workspace.CurrentCamera:WorldToScreenPoint(Point.p);

	-- Move the point marker UI to the point's position on the screen
	SnapTracking.PointMarker.Visible = PointVisible;
	SnapTracking.PointMarker.Position = UDim2.new(0, PointPosition.X, 0, PointPosition.Y);

end;

function SnapTracking.SetTrackingTarget(NewTarget)
	-- Sets the target part whose snapping points' proximity we are tracking
	SnapTracking.Target = NewTarget;
	SnapTracking.Update();
end;

function SnapTracking.GetClosestPoint()
	-- Find the current nearest snapping point for the target, update the GUI

	-- Make sure there's a target part to track, and a current mouse position to calculate proximity relative to
	if not SnapTracking.Target or not SnapTracking.MousePoint then
		return nil;
	end;

	local SnappingPoints = {};
	local SnappingPointProximity = {};

	-- Get the current target's snapping points
	local PartCFrame = SnapTracking.Target.CFrame;
	local PartSize = SnapTracking.Target.Size / 2;
	local SizeX, SizeY, SizeZ = PartSize.X, PartSize.Y, PartSize.Z;

	-- Filter based on snapping point options
	if SnapTracking.TrackCorners then
		table.insert(SnappingPoints, PartCFrame * CFrame.new(SizeX, SizeY, SizeZ));
		table.insert(SnappingPoints, PartCFrame * CFrame.new(-SizeX, SizeY, SizeZ));
		table.insert(SnappingPoints, PartCFrame * CFrame.new(SizeX, -SizeY, SizeZ));
		table.insert(SnappingPoints, PartCFrame * CFrame.new(SizeX, SizeY, -SizeZ));
		table.insert(SnappingPoints, PartCFrame * CFrame.new(-SizeX, SizeY, -SizeZ));
		table.insert(SnappingPoints, PartCFrame * CFrame.new(-SizeX, -SizeY, SizeZ));
		table.insert(SnappingPoints, PartCFrame * CFrame.new(SizeX, -SizeY, -SizeZ));
		table.insert(SnappingPoints, PartCFrame * CFrame.new(-SizeX, -SizeY, -SizeZ));
	end;
	if SnapTracking.TrackEdgeMidpoints then
		table.insert(SnappingPoints, PartCFrame * CFrame.new(SizeX, SizeY, 0));
		table.insert(SnappingPoints, PartCFrame * CFrame.new(SizeX, 0, SizeZ));
		table.insert(SnappingPoints, PartCFrame * CFrame.new(0, SizeY, SizeZ));
		table.insert(SnappingPoints, PartCFrame * CFrame.new(-SizeX, SizeY, 0));
		table.insert(SnappingPoints, PartCFrame * CFrame.new(-SizeX, 0, SizeZ));
		table.insert(SnappingPoints, PartCFrame * CFrame.new(0, -SizeY, SizeZ));
		table.insert(SnappingPoints, PartCFrame * CFrame.new(SizeX, -SizeY, 0));
		table.insert(SnappingPoints, PartCFrame * CFrame.new(SizeX, 0, -SizeZ));
		table.insert(SnappingPoints, PartCFrame * CFrame.new(0, SizeY, -SizeZ));
		table.insert(SnappingPoints, PartCFrame * CFrame.new(-SizeX, -SizeY, 0));
		table.insert(SnappingPoints, PartCFrame * CFrame.new(-SizeX, 0, -SizeZ));
		table.insert(SnappingPoints, PartCFrame * CFrame.new(0, -SizeY, -SizeZ));
	end;
	if SnapTracking.TrackFaceCentroids then
		table.insert(SnappingPoints, PartCFrame * CFrame.new(SizeX, 0, 0));
		table.insert(SnappingPoints, PartCFrame * CFrame.new(0, 0, SizeZ));
		table.insert(SnappingPoints, PartCFrame * CFrame.new(0, SizeY, 0));
		table.insert(SnappingPoints, PartCFrame * CFrame.new(-SizeX, 0, 0));
		table.insert(SnappingPoints, PartCFrame * CFrame.new(0, -SizeY, 0));
		table.insert(SnappingPoints, PartCFrame * CFrame.new(0, 0, -SizeZ));
	end;

	-- Calculate proximity of each snapping point to the mouse
	for SnappingPointKey, SnappingPoint in ipairs(SnappingPoints) do
		SnappingPointProximity[SnappingPointKey] = (SnapTracking.MousePoint - SnappingPoint.p).magnitude;
	end;

	-- Sort out the closest snapping point
	local ClosestPointKey = 1;
	for PointKey, Proximity in pairs(SnappingPointProximity) do
		if Proximity < SnappingPointProximity[ClosestPointKey] then
			ClosestPointKey = PointKey;
		end;
	end;

	-- Return the closest point
	return SnappingPoints[ClosestPointKey];
end;

function SnapTracking.StopTracking()
	-- Stops tracking the current closest snapping point, cleans up

	-- Clear the previous tracking target, and callback
	SnapTracking.Target = nil;
	SnapTracking.Callback = nil;

	-- Reset snapping point options
	SnapTracking.TrackFaceCentroids = true;
	SnapTracking.TrackEdgeMidpoints = true;
	SnapTracking.TrackCorners = true;
	SnapTracking.TargetFilter = nil;
	SnapTracking.TargetBlacklist = {};

	-- Make sure we're currently tracking
	if not SnapTracking.Enabled then
		return;
	end;

	-- Stop tracking the mouse and its proximity to snapping points
	SnapTracking.MouseTracking:Disconnect();
	SnapTracking.MouseTracking = nil;

	-- Clear the point marker UI from the screen
	SnapTracking.ClearUI();

	-- Indicate that tracking is no longer enabled
	SnapTracking.Enabled = false;

end;

return SnapTracking;