-- Libraries
Core = require(script.Parent.Core);
Support = Core.Support;

BoundingBoxModule = {};

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

StaticParts = {};
StaticPartMonitors = {};
RecalculateStaticExtents = true;
AggregatingStaticParts = false;
StaticPartAggregators = {};

function AddStaticPart(Part)
	-- Adds the static part to the list for state tracking

	-- Make sure the part isn't already in the list
	if Support.IsInTable(StaticParts, Part) then
		return;
	end;

	-- Add the part to the list
	table.insert(StaticParts, Part);

	-- Starts monitoring the part
	StaticPartMonitors[Part] = Part.Changed:connect(function (Property)

		if Property == 'CFrame' or Property == 'Size' then
			RecalculateStaticExtents = true;

		elseif Property == 'Anchored' and not Part.Anchored then
			RemoveStaticPart(Part);
		end;

	end);

	-- Recalculate the extents including this new part
	RecalculateStaticExtents = true;

end;

function RemoveStaticPart(Part)
	-- Removes the part from the static part tracking list

	-- Get the part's key in the list
	local PartKey = Support.FindTableOccurrence(StaticParts, Part);

	-- Remove it from the list
	if PartKey then
		StaticParts[PartKey] = nil;
	end;

	-- Clear its state monitors
	if StaticPartMonitors[Part] then
		StaticPartMonitors[Part]:disconnect();
		StaticPartMonitors[Part] = nil;
	end;

end;

function StartAggregatingStaticParts()
	-- Begins to look for and identify static parts

	-- Add current static parts
	for _, Part in pairs(Core.Selection.Items) do
		if Part.Anchored then
			AddStaticPart(Part);
		end;

		-- Watch for parts that become anchored
		table.insert(StaticPartAggregators, Part.Changed:connect(function (Property)
			if Property == 'Anchored' and Part.Anchored then
				AddStaticPart(Part);
			end;
		end));
	end;

	-- Add newly selected anchored parts
	table.insert(StaticPartAggregators, Core.Selection.ItemsAdded:connect(function (Parts)

		-- Go through each selected part
		for _, Part in pairs(Parts) do

			-- Only add anchored, static parts
			if Part.Anchored then
				AddStaticPart(Part);
			end;

			-- Watch for parts that become anchored
			table.insert(StaticPartAggregators, Part.Changed:connect(function (Property)
				if Property == 'Anchored' and Part.Anchored then
					AddStaticPart(Part);
				end;
			end));

		end;

	end));

	-- Remove deselected parts
	table.insert(StaticPartAggregators, Core.Selection.ItemsRemoved:connect(function (Parts)

		-- Remove the items
		for _, Part in pairs(Parts) do
			RemoveStaticPart(Part);
		end;

		-- Recalculate static extents without the removed parts
		RecalculateStaticExtents = true;

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
	BoundingBoxModule.StaticExtents = nil;

end;

-- Create shortcuts to avoid intensive lookups
local CFrame_new = CFrame.new;
local table_insert = table.insert;
local CFrame_toWorldSpace = CFrame.new().toWorldSpace;
local math_min = math.min;
local math_max = math.max;

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

			Corner = CFrame_toWorldSpace(PartCFrame, CFrame_new(SizeX, SizeY, SizeZ));
			table_insert(XPoints, Corner['x']);
			table_insert(YPoints, Corner['y']);
			table_insert(ZPoints, Corner['z']);
			
			Corner = CFrame_toWorldSpace(PartCFrame, CFrame_new(-SizeX, SizeY, SizeZ));
			table_insert(XPoints, Corner['x']);
			table_insert(YPoints, Corner['y']);
			table_insert(ZPoints, Corner['z']);

			Corner = CFrame_toWorldSpace(PartCFrame, CFrame_new(SizeX, -SizeY, SizeZ));
			table_insert(XPoints, Corner['x']);
			table_insert(YPoints, Corner['y']);
			table_insert(ZPoints, Corner['z']);
			
			Corner = CFrame_toWorldSpace(PartCFrame, CFrame_new(SizeX, SizeY, -SizeZ));
			table_insert(XPoints, Corner['x']);
			table_insert(YPoints, Corner['y']);
			table_insert(ZPoints, Corner['z']);
			
			Corner = CFrame_toWorldSpace(PartCFrame, CFrame_new(-SizeX, SizeY, -SizeZ));
			table_insert(XPoints, Corner['x']);
			table_insert(YPoints, Corner['y']);
			table_insert(ZPoints, Corner['z']);
			
			Corner = CFrame_toWorldSpace(PartCFrame, CFrame_new(-SizeX, -SizeY, SizeZ));
			table_insert(XPoints, Corner['x']);
			table_insert(YPoints, Corner['y']);
			table_insert(ZPoints, Corner['z']);
			
			Corner = CFrame_toWorldSpace(PartCFrame, CFrame_new(SizeX, -SizeY, -SizeZ));
			table_insert(XPoints, Corner['x']);
			table_insert(YPoints, Corner['y']);
			table_insert(ZPoints, Corner['z']);
			
			Corner = CFrame_toWorldSpace(PartCFrame, CFrame_new(-SizeX, -SizeY, -SizeZ));
			table_insert(XPoints, Corner['x']);
			table_insert(YPoints, Corner['y']);
			table_insert(ZPoints, Corner['z']);

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