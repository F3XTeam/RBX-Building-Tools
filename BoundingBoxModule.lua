-- Libraries
local Core = require(script.Parent.Core);
local Support = Core.Support;

-- Initialize module
local BoundingBoxModule = {};

-- Initialize internal module state
local StaticParts = {};
local StaticPartsIndex = {};
local StaticPartMonitors = {};
local RecalculateStaticExtents = true;
local AggregatingStaticParts = false;
local StaticPartAggregators = {};

function BoundingBoxModule.StartBoundingBox(HandleAttachmentCallback)
	-- Creates and starts a selection bounding box

	-- Make sure there isn't already a bounding box
	if BoundingBoxEnabled then
		return;
	end;

	-- Indicate that the bounding box is enabled
	BoundingBoxEnabled = true;

	-- Create the box
	BoundingBox = Core.Create 'Part' {
		Name = 'BTBoundingBox';
		CanCollide = false;
		Transparency = 1;
		Anchored = true;
		Locked = true;
	};

	-- Make the mouse ignore it
	Core.Mouse.TargetFilter = BoundingBox;

	-- Make sure to calculate our static extents
	RecalculateStaticExtents = true;
	StartAggregatingStaticParts();

	-- Begin the bounding box's updater
	BoundingBoxUpdater = Support.ScheduleRecurringTask(UpdateBoundingBox, 0.05);

	-- Attach handles if requested
	if HandleAttachmentCallback then
		BoundingBoxHandleCallback = HandleAttachmentCallback;
		BoundingBoxHandleCallback(BoundingBox);
	end;

end;

function UpdateBoundingBox()
	-- Updates the bounding box to fit the selection's extents

	-- Make sure the bounding box is enabled
	if not BoundingBoxEnabled then
		return;
	end;

	-- If the bounding box is inactive, and should now be active, update it
	if InactiveBoundingBox and #Core.Selection.Items > 0 then
		BoundingBox = InactiveBoundingBox;
		InactiveBoundingBox = nil;
		BoundingBoxHandleCallback(BoundingBox);

	-- If the bounding box is active, and there are no parts, disable it
	elseif BoundingBox and #Core.Selection.Items == 0 then
		InactiveBoundingBox = BoundingBox;
		BoundingBox = nil;
		BoundingBoxHandleCallback(BoundingBox);
		return;

	-- Don't try to update the bounding box if there are no parts
	elseif #Core.Selection.Items == 0 then
		return;
	end;

	-- Recalculate the extents of static items as needed only
	if RecalculateStaticExtents then
		BoundingBoxModule.StaticExtents = BoundingBoxModule.CalculateExtents(StaticParts, nil, true);
		RecalculateStaticExtents = false;
	end;

	-- Update the bounding box
	local BoundingBoxSize, BoundingBoxCFrame = BoundingBoxModule.CalculateExtents(Core.Selection.Items, BoundingBoxModule.StaticExtents);
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
		if not StaticPartsIndex[Part] and Part.Anchored then

			-- Add part to static index
			StaticPartsIndex[Part] = true;

			-- Start monitoring part for changes
			StaticPartMonitors[Part] = Part.Changed:connect(function (Property)

				-- Trigger static extent recalculations on position or size changes
				if Property == 'CFrame' or Property == 'Size' then
					RecalculateStaticExtents = true;

				-- Remove part from static index if it becomes mobile
				elseif Property == 'Anchored' and not Part.Anchored then
					RemoveStaticParts { Part };
				end;

			end);

		end;

	end;

	-- Update the static parts list
	StaticParts = Support.Keys(StaticPartsIndex);

	-- Recalculate static extents to include added parts
	RecalculateStaticExtents = true;

end;

function RemoveStaticParts(Parts)
	-- Removes the given parts from the static parts index

	-- Remove each given part
	for _, Part in pairs(Parts) do

		-- Remove part from static parts index
		StaticPartsIndex[Part] = nil;

		-- Clean up the part's change monitors
		if StaticPartMonitors[Part] then
			StaticPartMonitors[Part]:disconnect();
			StaticPartMonitors[Part] = nil;
		end;

	end;

	-- Update the static parts list
	StaticParts = Support.Keys(StaticPartsIndex);

	-- Recalculate static extents to exclude removed parts
	RecalculateStaticExtents = true;

end;

function StartAggregatingStaticParts()
	-- Begins to look for and identify static parts

	-- Add current qualifying parts to static parts index
	AddStaticParts(Core.Selection.Items);

	-- Watch for parts that become static
	for _, Part in pairs(Core.Selection.Items) do
		table.insert(StaticPartAggregators, Part.Changed:connect(function (Property)
			if Property == 'Anchored' and Part.Anchored then
				AddStaticParts { Part };
			end;
		end));
	end;

	-- Watch newly selected parts
	table.insert(StaticPartAggregators, Core.Selection.ItemsAdded:connect(function (Parts)

		-- Add qualifying parts to static parts index
		AddStaticParts(Parts);

		-- Watch for parts that become anchored
		for _, Part in pairs(Parts) do
			table.insert(StaticPartAggregators, Part.Changed:connect(function (Property)
				if Property == 'Anchored' and Part.Anchored then
					AddStaticParts { Part };
				end;
			end));
		end;

	end));

	-- Remove deselected parts from static parts index
	table.insert(StaticPartAggregators, Core.Selection.ItemsRemoved:connect(function (Parts)
		RemoveStaticParts(Parts);
	end));

end;

function StopAggregatingStaticParts()
	-- Stops looking for static parts, clears unnecessary data

	-- Disconnect all aggregators
	for AggregatorKey, Aggregator in pairs(StaticPartAggregators) do
		Aggregator:disconnect();
		StaticPartAggregators[AggregatorKey] = nil;
	end;

	-- Remove all static part monitors
	for MonitorKey, Monitor in pairs(StaticPartMonitors) do
		Monitor:disconnect();
		StaticPartMonitors[MonitorKey] = nil;
	end;

	-- Clear all static part information
	StaticParts = {};
	StaticPartsIndex = {};
	BoundingBoxModule.StaticExtents = nil;

end;

-- Create shortcuts to avoid intensive lookups
local CFrame_new = CFrame.new;
local table_insert = table.insert;
local CFrame_toWorldSpace = CFrame.new().toWorldSpace;
local math_min = math.min;
local math_max = math.max;
local unpack = unpack;

function BoundingBoxModule.CalculateExtents(Items, StaticExtents, ExtentsOnly)
	-- Returns the size and position of a box covering all items in `Items`

	-- Ensure there are items
	if #Items == 0 then
		return;
	end;

	-- Get initial extents data for comparison
	local ComparisonBaseMin = StaticExtents and StaticExtents.Min or Items[1].Position;
	local ComparisonBaseMax = StaticExtents and StaticExtents.Max or Items[1].Position;
	local MinX, MinY, MinZ = ComparisonBaseMin.X, ComparisonBaseMin.Y, ComparisonBaseMin.Z;
	local MaxX, MaxY, MaxZ = ComparisonBaseMax.X, ComparisonBaseMax.Y, ComparisonBaseMax.Z;

	-- Go through each part in `Items`
	for _, Part in pairs(Items) do

		-- Avoid re-calculating for static parts
		if not (Part.Anchored and StaticExtents) then

			-- Get shortcuts to part data
			local PartCFrame = Part.CFrame;
			local PartSize = Part.Size / 2;
			local SizeX, SizeY, SizeZ = PartSize.X, PartSize.Y, PartSize.Z;

			local Corner;
			local XPoints, YPoints, ZPoints = {}, {}, {};

			Corner = PartCFrame * CFrame_new(SizeX, SizeY, SizeZ);
			table_insert(XPoints, Corner.x);
			table_insert(YPoints, Corner.y);
			table_insert(ZPoints, Corner.z);

			Corner = PartCFrame * CFrame_new(-SizeX, SizeY, SizeZ);
			table_insert(XPoints, Corner.x);
			table_insert(YPoints, Corner.y);
			table_insert(ZPoints, Corner.z);

			Corner = PartCFrame * CFrame_new(SizeX, -SizeY, SizeZ);
			table_insert(XPoints, Corner.x);
			table_insert(YPoints, Corner.y);
			table_insert(ZPoints, Corner.z);

			Corner = PartCFrame * CFrame_new(SizeX, SizeY, -SizeZ);
			table_insert(XPoints, Corner.x);
			table_insert(YPoints, Corner.y);
			table_insert(ZPoints, Corner.z);

			Corner = PartCFrame * CFrame_new(-SizeX, SizeY, -SizeZ);
			table_insert(XPoints, Corner.x);
			table_insert(YPoints, Corner.y);
			table_insert(ZPoints, Corner.z);

			Corner = PartCFrame * CFrame_new(-SizeX, -SizeY, SizeZ);
			table_insert(XPoints, Corner.x);
			table_insert(YPoints, Corner.y);
			table_insert(ZPoints, Corner.z);

			Corner = PartCFrame * CFrame_new(SizeX, -SizeY, -SizeZ);
			table_insert(XPoints, Corner.x);
			table_insert(YPoints, Corner.y);
			table_insert(ZPoints, Corner.z);

			Corner = PartCFrame * CFrame_new(-SizeX, -SizeY, -SizeZ);
			table_insert(XPoints, Corner.x);
			table_insert(YPoints, Corner.y);
			table_insert(ZPoints, Corner.z);

			-- Reduce gathered points to min/max extents
			MinX = math_min(MinX, unpack(XPoints));
			MinY = math_min(MinY, unpack(YPoints));
			MinZ = math_min(MinZ, unpack(ZPoints));
			MaxX = math_max(MaxX, unpack(XPoints));
			MaxY = math_max(MaxY, unpack(YPoints));
			MaxZ = math_max(MaxZ, unpack(ZPoints));

		end;

	end;

	-- Calculate the extents
	local Extents = {
		Min = Vector3.new(MinX, MinY, MinZ),
		Max = Vector3.new(MaxX, MaxY, MaxZ);
	};

	-- Only return extents if requested
	if ExtentsOnly then
		return Extents;
	end;

	-- Calculate the bounding box size
	local Size = Vector3.new(
		MaxX - MinX,
		MaxY - MinY,
		MaxZ - MinZ
	);

	-- Calculate the bounding box center
	local Position = CFrame.new(
		MinX + (MaxX - MinX) / 2,
		MinY + (MaxY - MinY) / 2,
		MinZ + (MaxZ - MinZ) / 2
	);

	-- Return the size and position
	return Size, Position;

end;

return BoundingBoxModule;