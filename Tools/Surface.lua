Tool = script.Parent.Parent;
Core = require(Tool.Core);

-- Import relevant references
Selection = Core.Selection;
Support = Core.Support;
Security = Core.Security;
Support.ImportServices();

-- Initialize the tool
local SurfaceTool = {

	Name = 'Surface Tool';
	Color = BrickColor.new 'Bright violet';

	-- Default options
	Surface = 'All';

};

-- Container for temporary connections (disconnected automatically)
local Connections = {};

function SurfaceTool.Equip()
	-- Enables the tool's equipped functionality

	-- Start up our interface
	ShowUI();
	EnableSurfaceSelection();

	-- Set our current surface mode
	SetSurface(SurfaceTool.Surface);

end;

function SurfaceTool.Unequip()
	-- Disables the tool's equipped functionality

	-- Clear unnecessary resources
	HideUI();
	ClearConnections();

end;

function ClearConnections()
	-- Clears out temporary connections

	for ConnectionKey, Connection in pairs(Connections) do
		Connection:Disconnect();
		Connections[ConnectionKey] = nil;
	end;

end;

function ShowUI()
	-- Creates and reveals the UI

	-- Reveal UI if already created
	if SurfaceTool.UI then

		-- Reveal the UI
		SurfaceTool.UI.Visible = true;

		-- Update the UI every 0.1 seconds
		UIUpdater = Support.ScheduleRecurringTask(UpdateUI, 0.1);

		-- Skip UI creation
		return;

	end;

	-- Create the UI
	SurfaceTool.UI = Core.Tool.Interfaces.BTSurfaceToolGUI:Clone();
	SurfaceTool.UI.Parent = Core.UI;
	SurfaceTool.UI.Visible = true;

	-- Create the surface selection dropdown
	SurfaceDropdown = Core.Cheer(SurfaceTool.UI.SideOption.Dropdown).Start({ 'All', 'Top', 'Bottom', 'Front', 'Back', 'Left', 'Right' }, 'All', SetSurface);

	-- Map type label names to actual type names
	local SurfaceTypes = {
		['Studs'] = 'Studs',
		['Inlets'] = 'Inlet',
		['Smooth'] = 'Smooth',
		['Weld'] = 'Weld',
		['Glue'] = 'Glue',
		['Universal'] = 'Universal',
		['Hinge'] = 'Hinge',
		['Motor'] = 'Motor',
		['No Outline'] = 'SmoothNoOutlines'
	};

	-- Create the surface type selection dropdown
	SurfaceTypeDropdown = Core.Cheer(SurfaceTool.UI.TypeOption.Dropdown).Start({ 'Studs', 'Inlets', 'Smooth', 'Weld', 'Glue', 'Universal', 'Hinge', 'Motor', 'No Outline' }, '', function (Option)
		SetSurfaceType(Enum.SurfaceType[SurfaceTypes[Option]]);
	end);

	-- Update the UI every 0.1 seconds
	UIUpdater = Support.ScheduleRecurringTask(UpdateUI, 0.1);

end;

function HideUI()
	-- Hides the tool UI

	-- Make sure there's a UI
	if not SurfaceTool.UI then
		return;
	end;

	-- Hide the UI
	SurfaceTool.UI.Visible = false;

	-- Stop updating the UI
	UIUpdater:Stop();

end;

function GetSurfaceTypeDisplayName(SurfaceType)
	-- Returns a more friendly name for the given `SurfaceType`

	-- For stepping motors, add a space
	if SurfaceType == Enum.SurfaceType.SteppingMotor then
		return 'Stepping Motor';

	-- For no outlines, simplify name
	elseif SurfaceType == Enum.SurfaceType.SmoothNoOutlines then
		return 'No Outline';

	-- For other surface types, return their normal name
	else
		return SurfaceType.Name;

	end;

end;

function UpdateUI()
	-- Updates information on the UI

	-- Make sure the UI's on
	if not SurfaceTool.UI then
		return;
	end;

	-- Only show and identify current surface type if selection is not empty
	if #Selection.Parts == 0 then
		SurfaceTypeDropdown.SetOption('');
		return;
	end;

	------------------------------------
	-- Update the surface type indicator
	------------------------------------

	-- Collect all different surface types in selection
	local SurfaceTypeVariations = {};
	for _, Part in pairs(Selection.Parts) do

		-- Search for variations on all surfaces if all surfaces are selected
		if SurfaceTool.Surface == 'All' then
			table.insert(SurfaceTypeVariations, Part.TopSurface);
			table.insert(SurfaceTypeVariations, Part.BottomSurface);
			table.insert(SurfaceTypeVariations, Part.FrontSurface);
			table.insert(SurfaceTypeVariations, Part.BackSurface);
			table.insert(SurfaceTypeVariations, Part.LeftSurface);
			table.insert(SurfaceTypeVariations, Part.RightSurface);

		-- Search for variations on single selected surface
		else
			table.insert(SurfaceTypeVariations, Part[SurfaceTool.Surface .. 'Surface']);
		end;

	end;

	-- Identify common surface type in selection
	local CommonSurfaceType = Support.IdentifyCommonItem(SurfaceTypeVariations);

	-- Update the current surface type in the surface type dropdown
	SurfaceTypeDropdown.SetOption(CommonSurfaceType and GetSurfaceTypeDisplayName(CommonSurfaceType) or '*');

end;

function SetSurface(Surface)
	-- Changes the surface option to `Surface`

	-- Set the surface option
	SurfaceTool.Surface = Surface;

	-- Update the current surface in the surface dropdown
	SurfaceDropdown.SetOption(Surface);

end;

function SetSurfaceType(SurfaceType)
	-- Changes the selection's surface type on the currently selected surface

	-- Make sure a surface has been selected
	if not SurfaceTool.Surface then
		return;
	end;

	-- Track changes
	TrackChange();

	-- Change the surface of the parts locally
	for _, Part in pairs(Selection.Parts) do

		-- Change all surfaces if all selected
		if SurfaceTool.Surface == 'All' then
			Part.TopSurface = SurfaceType;
			Part.BottomSurface = SurfaceType;
			Part.FrontSurface = SurfaceType;
			Part.BackSurface = SurfaceType;
			Part.LeftSurface = SurfaceType;
			Part.RightSurface = SurfaceType;

		-- Change specific selected surface
		else
			Part[SurfaceTool.Surface .. 'Surface'] = SurfaceType;
		end;

	end;

	-- Register changes
	RegisterChange();

end;

function EnableSurfaceSelection()
	-- Allows the player to select surfaces by clicking on them

	-- Watch out for clicks on selected parts
	Connections.SurfaceSelection = Selection.FocusChanged:Connect(function ()
		local Target, ScopeTarget = Core.Targeting:UpdateTarget()
		if Selection.IsSelected(ScopeTarget) then

			-- Set the surface option to the target surface
			SetSurface(Core.Mouse.TargetSurface.Name);

		end;
	end);

end;

function TrackChange()

	-- Start the record
	HistoryRecord = {
		Parts = Support.CloneTable(Selection.Parts);
		BeforeSurfaces = {};
		AfterSurfaces = {};
		Selection = Selection.Items;

		Unapply = function (Record)
			-- Reverts this change

			-- Select the changed parts
			Selection.Replace(Record.Selection)

			-- Put together the change request
			local Changes = {};
			for _, Part in pairs(Record.Parts) do
				table.insert(Changes, { Part = Part, Surfaces = Record.BeforeSurfaces[Part]	});
			end;

			-- Send the change request
			Core.SyncAPI:Invoke('SyncSurface', Changes);

		end;

		Apply = function (Record)
			-- Applies this change

			-- Select the changed parts
			Selection.Replace(Record.Selection)

			-- Put together the change request
			local Changes = {};
			for _, Part in pairs(Record.Parts) do
				table.insert(Changes, { Part = Part, Surfaces = Record.AfterSurfaces[Part] });
			end;

			-- Send the change request
			Core.SyncAPI:Invoke('SyncSurface', Changes);

		end;

	};

	-- Collect the selection's initial state
	for _, Part in pairs(HistoryRecord.Parts) do

		-- Begin to record surfaces
		HistoryRecord.BeforeSurfaces[Part] = {};
		local Surfaces = HistoryRecord.BeforeSurfaces[Part];

		-- Record all surfaces if all selected
		if SurfaceTool.Surface == 'All' then
			Surfaces.Top = Part.TopSurface;
			Surfaces.Bottom = Part.BottomSurface;
			Surfaces.Front = Part.FrontSurface;
			Surfaces.Back = Part.BackSurface;
			Surfaces.Left = Part.LeftSurface;
			Surfaces.Right = Part.RightSurface;

		-- Record specific selected surface
		else
			Surfaces[SurfaceTool.Surface] = Part[SurfaceTool.Surface .. 'Surface'];
		end;

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

		-- Begin to record surfaces
		HistoryRecord.AfterSurfaces[Part] = {};
		local Surfaces = HistoryRecord.AfterSurfaces[Part];

		-- Record all surfaces if all selected
		if SurfaceTool.Surface == 'All' then
			Surfaces.Top = Part.TopSurface;
			Surfaces.Bottom = Part.BottomSurface;
			Surfaces.Front = Part.FrontSurface;
			Surfaces.Back = Part.BackSurface;
			Surfaces.Left = Part.LeftSurface;
			Surfaces.Right = Part.RightSurface;

		-- Record specific selected surface
		else
			Surfaces[SurfaceTool.Surface] = Part[SurfaceTool.Surface .. 'Surface'];
		end;

		-- Create the change request for this part
		table.insert(Changes, { Part = Part, Surfaces = Surfaces });

	end;

	-- Send the changes to the server
	Core.SyncAPI:Invoke('SyncSurface', Changes);

	-- Register the record and clear the staging
	Core.History.Add(HistoryRecord);
	HistoryRecord = nil;

end;

-- Return the tool
return SurfaceTool;