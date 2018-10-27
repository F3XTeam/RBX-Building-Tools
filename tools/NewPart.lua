Tool = script.Parent.Parent;
Core = require(Tool.Core);

-- Import relevant references
Selection = Core.Selection;
Create = Core.Create;
Support = Core.Support;
Security = Core.Security;
Support.ImportServices();

-- Initialize the tool
local NewPartTool = {

	Name = 'New Part Tool';
	Color = BrickColor.new 'Really black';

	-- Default options
	Type = 'Normal';

};

-- Container for temporary connections (disconnected automatically)
local Connections = {};

function NewPartTool.Equip()
	-- Enables the tool's equipped functionality

	-- Start up our interface
	ShowUI();
	EnableClickCreation();

	-- Set our current type
	SetType(NewPartTool.Type);

end;

function NewPartTool.Unequip()
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
	if UI then

		-- Reveal the UI
		UI.Visible = true;

		-- Skip UI creation
		return;

	end;

	-- Create the UI
	UI = Core.Tool.Interfaces.BTNewPartToolGUI:Clone();
	UI.Parent = Core.UI;
	UI.Visible = true;

	-- Creatable part types
	Types = { 'Normal', 'Truss', 'Wedge', 'Corner', 'Cylinder', 'Ball', 'Seat', 'Vehicle Seat', 'Spawn' };

	-- Create the type selection dropdown
	TypeDropdown = Core.Cheer(UI.TypeOption.Dropdown).Start(Types, '', function (Type)
		SetType(Type);
	end);

end;

function HideUI()
	-- Hides the tool UI

	-- Make sure there's a UI
	if not UI then
		return;
	end;

	-- Hide the UI
	UI.Visible = false;

end;

function SetType(Type)

	-- Update the tool option
	NewPartTool.Type = Type;

	-- Update the UI
	TypeDropdown.SetOption(Type);

end;

function EnableClickCreation()
	-- Allows the user to click anywhere and create a new part

	-- Listen for clicks
	Connections.ClickCreationListener = UserInputService.InputBegan:Connect(function (Input, GameProcessedEvent)

		-- Make sure this is an intentional event
		if GameProcessedEvent then
			return;
		end;

		-- Make sure this was button 1 being released
		if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return;
		end;

		-- Enable new part dragging
		DragNewParts = true;
		Core.Targeting.CancelSelecting();

		-- Create the part
		CreatePart(NewPartTool.Type);

	end);

	-- Listen for click releases
	Connections.ClickReleaseListener = Support.AddUserInputListener('Ended', 'MouseButton1', true, function ()

		-- Cancel dragging new parts if mouse button is released
		DragNewParts = false;

	end);

end;

function CreatePart(Type)

	-- Send the creation request to the server
	local Part = Core.SyncAPI:Invoke('CreatePart', Type, CFrame.new(Core.Mouse.Hit.p));

	-- Make sure the part creation succeeds
	if not Part then
		return;
	end;

	-- Put together the history record
	local HistoryRecord = {
		Part = Part;

		Unapply = function (HistoryRecord)
			-- Reverts this change

			-- Remove the part
			Core.SyncAPI:Invoke('Remove', { HistoryRecord.Part });

		end;

		Apply = function (HistoryRecord)
			-- Reapplies this change

			-- Restore the part
			Core.SyncAPI:Invoke('UndoRemove', { HistoryRecord.Part });

		end;

	};

	-- Register the history record
	Core.History.Add(HistoryRecord);

	-- Select the part
	Selection.Replace({ Part });

	-- Switch to the move tool
	local MoveTool = require(Core.Tool.Tools.MoveTool);
	Core.EquipTool(MoveTool);

	-- Enable dragging to allow easy positioning of the created part
	if DragNewParts then
		MoveTool.SetUpDragging(Part);
	end;

end;

-- Return the tool
return NewPartTool;