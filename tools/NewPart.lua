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
local NewPartTool = {

	Name = 'New Part Tool';
	Color = BrickColor.new 'Really black';

	-- Default options
	Type = 'Normal';

	-- Standard platform event interface
	Listeners = {};

};

-- Container for temporary connections (disconnected automatically)
local Connections = {};

function Equip()
	-- Enables the tool's equipped functionality

	-- Start up our interface
	ShowUI();
	EnableClickCreation();

	-- Set our current type
	SetType(NewPartTool.Type);

end;

function Unequip()
	-- Disables the tool's equipped functionality

	-- Clear unnecessary resources
	HideUI();
	ClearConnections();

end;

NewPartTool.Listeners.Equipped = Equip;
NewPartTool.Listeners.Unequipped = Unequip;

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
	local Types = { 'Normal', 'Truss', 'Wedge', 'Corner', 'Cylinder', 'Ball', 'Seat', 'Vehicle Seat', 'Spawn' };

	-- Create the type selection dropdown
	TypeDropdown = Core.createDropdown();
	TypeDropdown.Frame.Parent = UI.TypeOption;
	TypeDropdown.Frame.Position = UDim2.new(0, 70, 0, 0);
	TypeDropdown.Frame.Size = UDim2.new(0, 140, 0, 25);

	-- Add the part type options to the dropdown
	for _, Type in pairs(Types) do

		-- Capitalize the part type label
		TypeLabel = Type:upper();

		-- Enable the option button
		TypeDropdown:addOption(TypeLabel).MouseButton1Click:connect(function ()
			SetType(Type);
			TypeDropdown:toggle();
		end);

	end;

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
	TypeDropdown:selectOption(Type:upper());

end;

function EnableClickCreation()
	-- Allows the user to click anywhere and create a new part

	-- Listen for clicks
	Connections.ClickCreationListener = UserInputService.InputBegan:connect(function (Input, GameProcessedEvent)

		-- Make sure this is an intentional event
		if GameProcessedEvent then
			return;
		end;

		-- Make sure this was button 1 being released
		if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return;
		end;

		-- Create the part
		CreatePart(NewPartTool.Type);

	end);

end;

function CreatePart(Type)

	-- Send the creation request to the server
	local Part = Core.ServerAPI:InvokeServer('CreatePart', Type, CFrame.new(Core.Mouse.Hit.p));

	-- Make sure the part creation succeeds
	if not Part then
		return;
	end;

	-- Put together the history record
	local HistoryRecord = {
		Part = Part;

		Unapply = function (HistoryRecord)
			-- Reverts this change

			-- Remove the decorations
			Core.ServerAPI:InvokeServer('Remove', { HistoryRecord.Part });

		end;

		Apply = function (HistoryRecord)
			-- Reapplies this change

			-- Restore the decorations
			Core.ServerAPI:InvokeServer('UndoRemove', { HistoryRecord.Part });

		end;

	};

	-- Register the history record
	Core.History:Add(HistoryRecord);

	-- Select the part
	Selection:clear();
	Selection:add(Part);

	-- Switch to the move tool
	Core.equipTool(Core.Tools.Move);

	-- Enable dragging to allow easy positioning of the created part
	Core.Tools.Move.SetUpDragging(Part);

end;


-- Mark the tool as fully loaded
Core.Tools.NewPart = NewPartTool;
NewPartTool.Loaded = true;