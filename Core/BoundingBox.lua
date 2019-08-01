local Core = require(script.Parent);
local Support = Core.Support;

-- Libraries
local Tool = script.Parent.Parent
local Libraries = Tool:WaitForChild 'Libraries'
local Maid = require(Libraries:WaitForChild 'Maid')

-- Initialize module
local BoundingBoxModule = {};

-- Initialize internal module state
local StaticParts = {};
local StaticPartsIndex = {};
local StaticPartMonitors = Maid.new()
local RecalculateStaticExtents = true;
local StaticPartAggregators = Maid.new()
local PotentialPartMonitors = Maid.new()

function BoundingBoxModule.StartBoundingBox(HandleAttachmentCallback)
	-- Creates and starts a selection bounding box

	-- Make sure there isn't already a bounding box
	if BoundingBoxEnabled then
		return;
	end;

	-- Indicate that the bounding box is enabled
	BoundingBoxEnabled = true;

	-- Create the box
	BoundingBox = Core.Make 'Part' {
		Name = 'BTBoundingBox';
		CanCollide = false;
		Transparency = 1;
		Anchored = true;
		Locked = true;
		Parent = Core.UI;
	};

	-- Make the mouse ignore it
	Core.Mouse.TargetFilter = BoundingBox;

	-- Make sure to calculate our static extents
	RecalculateStaticExtents = true;
	StartAggregatingStaticParts();

	-- Store handle attachment callback
	BoundingBoxHandleCallback = HandleAttachmentCallback;

	-- Begin the bounding box's updater
	BoundingBoxModule.UpdateBoundingBox();
	BoundingBoxUpdater = Support.ScheduleRecurringTask(BoundingBoxModule.UpdateBoundingBox, 0.05);

	-- Attach handles if requested
	if BoundingBoxHandleCallback then
		BoundingBoxHandleCallback(BoundingBox);
	end;

end;

function BoundingBoxModule.GetBoundingBox()
	-- Returns the current bounding box

	-- Get and return bounding box
	return BoundingBox;

end;

function IsPhysicsStatic()
	-- Returns whether the game's physics are active or static

	-- Determine value if not yet cached
	if _IsPhysicsStatic == nil then
		_IsPhysicsStatic = (Core.Mode == 'Plugin') and (Workspace.DistributedGameTime == 0);
	end;

	-- Return cached value
	return _IsPhysicsStatic;

end;

function BoundingBoxModule.UpdateBoundingBox()
	-- Updates the bounding box to fit the selection's extents

	-- Make sure the bounding box is enabled
	if not BoundingBoxEnabled then
		return;
	end;

	-- If the bounding box is inactive, and should now be active, update it
	if InactiveBoundingBox and #Core.Selection.Parts > 0 then
		BoundingBox = InactiveBoundingBox;
		InactiveBoundingBox = nil;
		BoundingBoxHandleCallback(BoundingBox);

	-- If the bounding box is active, and there are no parts, disable it
	elseif BoundingBox and #Core.Selection.Parts == 0 then
		InactiveBoundingBox = BoundingBox;
		BoundingBox = nil;
		BoundingBoxHandleCallback(BoundingBox);
		return;

	-- Don't try to update the bounding box if there are no parts
	elseif #Core.Selection.Parts == 0 then
		return;
	end;

	-- Recalculate the extents of static items as needed only
	if RecalculateStaticExtents then
		BoundingBoxModule.StaticExtents = BoundingBoxModule.CalculateExtents(StaticParts, nil, true);
		RecalculateStaticExtents = false;
	end;

	-- Update the bounding box
	local BoundingBoxSize, BoundingBoxCFrame = BoundingBoxModule.CalculateExtents(Core.Selection.Parts, BoundingBoxModule.StaticExtents);
	BoundingBox.Size = BoundingBoxSize;
	BoundingBox.CFrame = BoundingBoxCFrame;

end;

function BoundingBoxModule.ClearBoundingBox()
	-- Clears the selection bounding box

	-- Make sure there's a bounding box
	if not BoundingBoxEnabled then
		return;
	end;

	-- If there's a bounding box updater, stop it
	if BoundingBoxUpdater then
		BoundingBoxUpdater:Stop();
		BoundingBoxUpdater = nil;
	end;

	-- Stop tracking static parts
	StopAggregatingStaticParts();

	-- Delete the bounding box
	if BoundingBox then
		BoundingBox:Destroy();
		BoundingBox = nil;
	elseif InactiveBoundingBox then
		InactiveBoundingBox:Destroy();
		InactiveBoundingBox = nil;
	end;

	-- Mark the bounding box as disabled
	BoundingBoxEnabled = false;

	-- Clear the bounding box handle callback
	BoundingBoxHandleCallback(nil);
	BoundingBoxHandleCallback = nil;

end;

function AddStaticParts(Parts)
	-- Adds the static parts to the list for state tracking

	-- Add each given part
	for _, Part in pairs(Parts) do

		-- Ensure part isn't already indexed, and verify it is static
		if not StaticPartsIndex[Part] and (IsPhysicsStatic() or Part.Anchored) then

			-- Add part to static index
			StaticPartsIndex[Part] = true;

			-- Monitor static part for changes
			AddStaticPartMonitor(Part);

		end;

	end;

	-- Update the static parts list
	StaticParts = Support.Keys(StaticPartsIndex);

	-- Recalculate static extents to include added parts
	RecalculateStaticExtents = true;

end;

function AddStaticPartMonitor(Part)
	-- Monitors the given part to track when it is no longer static

	-- Ensure part is static and isn't already monitored
	if not StaticPartsIndex[Part] or StaticPartMonitors[Part] then
		return;
	end;

	-- Start monitoring part for changes
	StaticPartMonitors[Part] = Maid.new({

		-- Trigger static extent recalculations on position or size changes
		Part:GetPropertyChangedSignal('CFrame'):Connect(function ()
			RecalculateStaticExtents = true
		end);
		Part:GetPropertyChangedSignal('Size'):Connect(function ()
			RecalculateStaticExtents = true
		end);

		-- Remove part from static index if it becomes mobile
		Part:GetPropertyChangedSignal('Anchored'):Connect(function ()
			if not IsPhysicsStatic() and not Part.Anchored then
				RemoveStaticParts { Part }
			end
		end);

	})

end;

function RemoveStaticParts(Parts)
	-- Removes the given parts from the static parts index

	-- Remove each given part
	for _, Part in pairs(Parts) do

		-- Remove part from static parts index
		StaticPartsIndex[Part] = nil;

		-- Clean up the part's change monitors
		StaticPartMonitors[Part] = nil

	end;

	-- Update the static parts list
	StaticParts = Support.Keys(StaticPartsIndex);

	-- Recalculate static extents to exclude removed parts
	RecalculateStaticExtents = true;

end;

function StartAggregatingStaticParts()
	-- Begins to look for and identify static parts

	-- Add current qualifying parts to static parts index
	AddStaticParts(Core.Selection.Parts);

	-- Watch for parts that become static
	for _, Part in ipairs(Core.Selection.Parts) do
		AddPotentialPartMonitor(Part);
	end;

	-- Watch newly selected parts
	StaticPartAggregators.SelectedParts = Core.Selection.PartsAdded:Connect(function (Parts)

		-- Add qualifying parts to static parts index
		AddStaticParts(Parts);

		-- Watch for parts that become anchored
		for _, Part in pairs(Parts) do
			AddPotentialPartMonitor(Part);
		end;

	end)

	-- Remove deselected parts from static parts index
	StaticPartAggregators.DeselectedParts = Core.Selection.PartsRemoved:Connect(function (Parts)
		RemoveStaticParts(Parts);
		for _, Part in pairs(Parts) do
			PotentialPartMonitors[Part] = nil
		end
	end)

end;

function BoundingBoxModule.RecalculateStaticExtents()
	-- Sets flag indicating that extents of static items should be recalculated

	-- Set flag to trigger recalculation on the next step in the update loop
	RecalculateStaticExtents = true;

end;

function AddPotentialPartMonitor(Part)
	-- Monitors the given part to track when it becomes static

	-- Ensure part is not already monitored
	if PotentialPartMonitors[Part] then
		return;
	end;

	-- Create anchored state change monitor
	PotentialPartMonitors[Part] = Part:GetPropertyChangedSignal('Anchored'):Connect(function (Property)
		if Part.Anchored then
			AddStaticParts { Part };
		end;
	end);

end;

function BoundingBoxModule.PauseMonitoring()
	-- Disables part monitors

	-- Disconnect all potential part monitors
	PotentialPartMonitors:Destroy()

	-- Disconnect all static part monitors
	StaticPartMonitors:Destroy()

	-- Stop update loop
	if BoundingBoxUpdater then
		BoundingBoxUpdater:Stop();
		BoundingBoxUpdater = nil;
	end;

end;

function BoundingBoxModule.ResumeMonitoring()
	-- Starts update loop and part monitors for selected and indexed parts

	-- Ensure bounding box is enabled
	if not BoundingBoxEnabled then
		return;
	end;

	-- Start static part monitors
	for StaticPart in pairs(StaticPartsIndex) do
		AddStaticPartMonitor(StaticPart);
	end;

	-- Start potential part monitors
	for _, Part in ipairs(Core.Selection.Parts) do
		AddPotentialPartMonitor(Part);
	end;

	-- Start update loop
	if not BoundingBoxUpdater then
		BoundingBoxUpdater = Support.ScheduleRecurringTask(BoundingBoxModule.UpdateBoundingBox, 0.05);
	end;

end;

function StopAggregatingStaticParts()
	-- Stops looking for static parts, clears unnecessary data

	-- Disconnect all aggregators
	StaticPartAggregators:Destroy()

	-- Remove all static part monitors
	StaticPartMonitors:Destroy()

	-- Remove all potential part monitors
	PotentialPartMonitors:Destroy()

	-- Clear all static part information
	StaticParts = {};
	StaticPartsIndex = {};
	BoundingBoxModule.StaticExtents = nil;

end;

function BoundingBoxModule.CalculateExtents(Parts, StaticExtents, ExtentsOnly)
	-- Returns the size and position of a box covering all items in `Items`

	-- Ensure there are items
	if #Parts == 0 then
		return nil
	end

	-- Get initial extents data for comparison
	local ComparisonBaseMin = StaticExtents and StaticExtents.Min or Parts[1].Position
	local ComparisonBaseMax = StaticExtents and StaticExtents.Max or Parts[1].Position
	local MinX, MinY, MinZ = ComparisonBaseMin.X, ComparisonBaseMin.Y, ComparisonBaseMin.Z
	local MaxX, MaxY, MaxZ = ComparisonBaseMax.X, ComparisonBaseMax.Y, ComparisonBaseMax.Z

	-- Check each relevant part
	local IsPhysicsStatic = IsPhysicsStatic()
	for i = 1, #Parts do
		if not ((IsPhysicsStatic or Parts[i].Anchored) and StaticExtents) then
			local PositionX, PositionY, PositionZ,
				RightVectorX, UpVectorX, LookVectorX,
				RightVectorY, UpVectorY, LookVectorY,
				RightVectorZ, UpVectorZ, LookVectorZ = Parts[i].CFrame:GetComponents()
			local PartSize = Parts[i].Size
			local SizeX, SizeY, SizeZ = PartSize.X/2, PartSize.Y/2, PartSize.Z/2

			-- Calculate extents along X axis
			local px = SizeX * (RightVectorX < 0 and -RightVectorX or RightVectorX) +
					SizeY * (UpVectorX < 0 and -UpVectorX or UpVectorX) +
					SizeZ * (LookVectorX < 0 and -LookVectorX or LookVectorX)

			-- Calculate extents along Y axis
			local py = SizeX * (RightVectorY < 0 and -RightVectorY or RightVectorY) +
					SizeY * (UpVectorY < 0 and -UpVectorY or UpVectorY) +
					SizeZ * (LookVectorY < 0 and -LookVectorY or LookVectorY)

			-- Calculate extents along Z axis
			local pz = SizeX * (RightVectorZ < 0 and -RightVectorZ or RightVectorZ) +
					SizeY * (UpVectorZ < 0 and -UpVectorZ or UpVectorZ) +
					SizeZ * (LookVectorZ < 0 and -LookVectorZ or LookVectorZ)

			-- Update minimum positions on each axis
			local PartMinX = PositionX - px
			if PartMinX < MinX then
				MinX = PartMinX
			end
			local PartMinY = PositionY - py
			if PartMinY < MinY then
				MinY = PartMinY
			end
			local PartMinZ = PositionZ - pz
			if PartMinZ < MinZ then
				MinZ = PartMinZ
			end

			-- Update max positions on each axis
			local PartMaxX = PositionX + px
			if PartMaxX > MaxX then
				MaxX = PartMaxX
			end
			local PartMaxY = PositionY + py
			if PartMaxY > MaxY then
				MaxY = PartMaxY
			end
			local PartMaxZ = PositionZ + pz
			if PartMaxZ > MaxZ then
				MaxZ = PartMaxZ
			end
		end
	end

	-- Return extents only if requested
	if ExtentsOnly then
		return {
			Min = Vector3.new(MinX, MinY, MinZ);
			Max = Vector3.new(MaxX, MaxY, MaxZ);
		}
	end

	-- Construct CFrame and Vector3 representing bounding box center and size
	return Vector3.new((MaxX - MinX), (MaxY - MinY), (MaxZ - MinZ)),
		   CFrame.new((MinX + MaxX)/2, (MinY + MaxY)/2, (MinZ + MaxZ)/2)
end

return BoundingBoxModule;