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
Support.ImportServices();

-- Initialize the tool
local SurfaceTool = {

	Name = 'Surface Tool';
	Color = BrickColor.new 'Bright violet';

	-- Default options
	Surface = 'All';

	-- Standard platform event interface
	Listeners = {};

};

-- Container for temporary connections (disconnected automatically)
local Connections = {};

function Equip()
	-- Enables the tool's equipped functionality

	-- Start up our interface
	ShowUI();
	EnableSurfaceSelection();

	-- Set our current surface mode
	SetSurface(SurfaceTool.Surface);

end;

function Unequip()
	-- Disables the tool's equipped functionality

	-- Clear unnecessary resources
	HideUI();
	ClearConnections();

end;

SurfaceTool.Listeners.Equipped = Equip;
SurfaceTool.Listeners.Unequipped = Unequip;

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
	if SurfaceTool.UI then

		-- Reveal the UI
		SurfaceTool.UI.Visible = true;

		-- Update the UI every 0.1 seconds
		UIUpdater = Core.ScheduleRecurringTask(UpdateUI, 0.1);

		-- Skip UI creation
		return;

	end;

	-- Create the UI
	SurfaceTool.UI = Core.Tool.Interfaces.BTSurfaceToolGUI:Clone();
	SurfaceTool.UI.Parent = Core.UI;
	SurfaceTool.UI.Visible = true;

	-- Create the surface selection dropdown
	SurfaceDropdown = Core.createDropdown();
	SurfaceDropdown.Frame.Parent = SurfaceTool.UI.SideOption;
	SurfaceDropdown.Frame.Position = UDim2.new(0, 30, 0, 0);
	SurfaceDropdown.Frame.Size = UDim2.new(0, 72, 0, 25);

	-- Add the surface options to the dropdown
	SurfaceDropdown:addOption('ALL').MouseButton1Up:connect(function ()
		SetSurface('All');
	end);
	SurfaceDropdown:addOption('TOP').MouseButton1Up:connect(function ()
		SetSurface('Top');
	end);
	SurfaceDropdown:addOption('BOTTOM').MouseButton1Up:connect(function ()
		SetSurface('Bottom');
	end);
	SurfaceDropdown:addOption('FRONT').MouseButton1Up:connect(function ()
		SetSurface('Front');
	end);
	SurfaceDropdown:addOption('BACK').MouseButton1Up:connect(function ()
		SetSurface('Back');
	end);
	SurfaceDropdown:addOption('LEFT').MouseButton1Up:connect(function ()
		SetSurface('Left');
	end);
	SurfaceDropdown:addOption('RIGHT').MouseButton1Up:connect(function ()
		SetSurface('Right');
	end);

	-- Create the surface type selection dropdown
	SurfaceTypeDropdown = Core.createDropdown();
	SurfaceTypeDropdown.Frame.Parent = SurfaceTool.UI.TypeOption;
	SurfaceTypeDropdown.Frame.Position = UDim2.new(0, 30, 0, 0);
	SurfaceTypeDropdown.Frame.Size = UDim2.new(0, 87, 0, 25);

	-- Add the surface type options to the dropdown
	SurfaceTypeDropdown:addOption('STUDS').MouseButton1Up:connect(function ()
		SetSurfaceType(Enum.SurfaceType.Studs);
	end);
	SurfaceTypeDropdown:addOption('INLETS').MouseButton1Up:connect(function ()
		SetSurfaceType(Enum.SurfaceType.Inlet);
	end);
	SurfaceTypeDropdown:addOption('SMOOTH').MouseButton1Up:connect(function ()
		SetSurfaceType(Enum.SurfaceType.Smooth);
	end);
	SurfaceTypeDropdown:addOption('WELD').MouseButton1Up:connect(function ()
		SetSurfaceType(Enum.SurfaceType.Weld);
	end);
	SurfaceTypeDropdown:addOption('GLUE').MouseButton1Up:connect(function ()
		SetSurfaceType(Enum.SurfaceType.Glue);
	end);
	SurfaceTypeDropdown:addOption('UNIVERSAL').MouseButton1Up:connect(function ()
		SetSurfaceType(Enum.SurfaceType.Universal);
	end);
	SurfaceTypeDropdown:addOption('HINGE').MouseButton1Up:connect(function ()
		SetSurfaceType(Enum.SurfaceType.Hinge);
	end);
	SurfaceTypeDropdown:addOption('MOTOR').MouseButton1Up:connect(function ()
		SetSurfaceType(Enum.SurfaceType.Motor);
	end);
	SurfaceTypeDropdown:addOption('NO OUTLINE').MouseButton1Up:connect(function ()
		SetSurfaceType(Enum.SurfaceType.SmoothNoOutlines);
	end);

	-- Update the UI every 0.1 seconds
	UIUpdater = Core.ScheduleRecurringTask(UpdateUI, 0.1);

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
		return 'No Outlines';

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
	if #Selection.Items == 0 then
		SurfaceTypeDropdown:selectOption('');
		return;
	end;

	------------------------------------
	-- Update the surface type indicator
	------------------------------------

	-- Collect all different surface types in selection
	local SurfaceTypeVariations = {};
	for _, Part in pairs(Selection.Items) do

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
	SurfaceTypeDropdown:selectOption(CommonSurfaceType and GetSurfaceTypeDisplayName(CommonSurfaceType):upper() or '*');

end;

function SetSurface(Surface)
	-- Changes the surface option to `Surface`

	-- Set the surface option
	SurfaceTool.Surface = Surface;

	-- Update the current surface in the surface dropdown
	SurfaceDropdown:selectOption(Surface:upper());

	-- If the current surface dropdown is open, close it
	if SurfaceDropdown.open then
		SurfaceDropdown:toggle();
	end;

end;

function SetSurfaceType(SurfaceType)
	-- Changes the selection's surface type on the currently selected surface

	-- Make sure a surface has been selected
	if not SurfaceTool.Surface then
		return;
	end;

	-- If the current surface type dropdown is open, close it
	if SurfaceTypeDropdown.open then
		SurfaceTypeDropdown:toggle();
	end;

	-- Track changes
	TrackChange();

	-- Change the surface of the parts locally
	for _, Part in pairs(Selection.Items) do

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

	-- Watch out for clicks on selected parts (use selection system-linked core event)
	SurfaceTool.Listeners.Button1Up = function ()
		if Selection:find(Core.Mouse.Target) and Core.Mouse.TargetSurface and not Core.selecting then

			-- Set the surface option to the target surface
			SetSurface(Core.Mouse.TargetSurface.Name);

		end;
	end;

end;

function TrackChange()

	-- Start the record
	HistoryRecord = {
		Parts = Support.CloneTable(Selection.Items);
		BeforeSurfaces = {};
		AfterSurfaces = {};

		Unapply = function (Record)
			-- Reverts this change

			-- Clear the selection
			Selection:clear();

			-- Put together the change request
			local Changes = {};
			for _, Part in pairs(Record.Parts) do
				table.insert(Changes, { Part = Part, Surfaces = Record.BeforeSurfaces[Part]	});

				-- Select the part
				Selection:add(Part);
			end;

			-- Send the change request
			Core.ServerAPI:InvokeServer('SyncSurface', Changes);

		end;

		Apply = function (Record)
			-- Applies this change

			-- Clear the selection
			Selection:clear();

			-- Put together the change request
			local Changes = {};
			for _, Part in pairs(Record.Parts) do
				table.insert(Changes, { Part = Part, Surfaces = Record.AfterSurfaces[Part] });

				-- Select the part
				Selection:add(Part);
			end;

			-- Send the change request
			Core.ServerAPI:InvokeServer('SyncSurface', Changes);

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
	Core.ServerAPI:InvokeServer('SyncSurface', Changes);

	-- Register the record and clear the staging
	Core.History:Add(HistoryRecord);
	HistoryRecord = nil;

end;

-- Mark the tool as fully loaded
Core.Tools.Surface = SurfaceTool;
SurfaceTool.Loaded = true;