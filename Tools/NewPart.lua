Tool = script.Parent.Parent;
Core = require(Tool.Core);
local Vendor = Tool:WaitForChild('Vendor')
local UI = Tool:WaitForChild('UI')
local Libraries = Tool:WaitForChild('Libraries')

-- Services
local ContextActionService = game:GetService 'ContextActionService'

-- Libraries
local ListenForManualWindowTrigger = require(Tool.Core:WaitForChild('ListenForManualWindowTrigger'))
local Roact = require(Vendor:WaitForChild('Roact'))
local Dropdown = require(UI:WaitForChild('Dropdown'))
local Signal = require(Libraries:WaitForChild('Signal'))

-- Import relevant references
Selection = Core.Selection;
Support = Core.Support;
Security = Core.Security;
Support.ImportServices();

-- Initialize the tool
local NewPartTool = {
	Name = 'New Part Tool';
	Color = BrickColor.new 'Really black';

	-- Default options
	Type = 'Normal';

	-- Signals
	OnTypeChanged = Signal.new();
}

NewPartTool.ManualText = [[<font face="GothamBlack" size="16">New Part Tool  🛠</font>
Lets you create new parts.<font size="6"><br /></font>

<b>TIP:</b> Click and drag where you want your part to be.]]

-- Container for temporary connections (disconnected automatically)
local Connections = {};

function NewPartTool:Equip()
	-- Enables the tool's equipped functionality

	-- Start up our interface
	self:ShowUI()
	EnableClickCreation();

	-- Set our current type
	self:SetType(NewPartTool.Type)

end;

function NewPartTool:Unequip()
	-- Disables the tool's equipped functionality

	-- Clear unnecessary resources
	self:HideUI()
	ClearConnections();
	ContextActionService:UnbindAction('BT: Create part')

end;

function ClearConnections()
	-- Clears out temporary connections

	for ConnectionKey, Connection in pairs(Connections) do
		Connection:Disconnect();
		Connections[ConnectionKey] = nil;
	end;

end;

function NewPartTool:ShowUI()
	-- Creates and reveals the UI

	-- Reveal UI if already created
	if self.UI then

		-- Reveal the UI
		self.UI.Visible = true;

		-- Skip UI creation
		return;

	end;

	-- Create the UI
	self.UI = Core.Tool.Interfaces.BTNewPartToolGUI:Clone()
	self.UI.Parent = Core.UI
	self.UI.Visible = true

	-- Creatable part types
	Types = {
		'Normal';
		'Truss';
		'Wedge';
		'Corner';
		'Cylinder';
		'Ball';
		'Seat';
		'Vehicle Seat';
		'Spawn';
	}

	-- Create type dropdown
	local function BuildTypeDropdown()
		return Roact.createElement(Dropdown, {
			Position = UDim2.new(0, 70, 0, 0);
			Size = UDim2.new(0, 140, 0, 25);
			Options = Types;
			MaxRows = 5;
			CurrentOption = self.Type;
			OnOptionSelected = function (Option)
				self:SetType(Option)
			end;
		})
	end

	-- Mount type dropdown
	local TypeDropdownHandle = Roact.mount(BuildTypeDropdown(), self.UI.TypeOption, 'Dropdown')
	self.OnTypeChanged:Connect(function ()
		Roact.update(TypeDropdownHandle, BuildTypeDropdown())
	end)

	-- Hook up manual triggering
	local SignatureButton = self.UI:WaitForChild('Title'):WaitForChild('Signature')
	ListenForManualWindowTrigger(NewPartTool.ManualText, NewPartTool.Color.Color, SignatureButton)
end

function NewPartTool:HideUI()
	-- Hides the tool UI

	-- Make sure there's a UI
	if not self.UI then
		return
	end

	-- Hide the UI
	self.UI.Visible = false

end;

function NewPartTool:SetType(Type)
	if self.Type ~= Type then
		self.Type = Type
		self.OnTypeChanged:Fire(Type)
	end
end

function EnableClickCreation()
	-- Allows the user to click anywhere and create a new part

	local function CreateAtTarget(Action, State, Input)

		-- Drag new parts
		if State.Name == 'Begin' then
			DragNewParts = true
			Core.Targeting.CancelSelecting()

			-- Create new part
			CreatePart(NewPartTool.Type)

		-- Disable dragging on release
		elseif State.Name == 'End' then
			DragNewParts = nil
		end

	end

	-- Register input handler
	ContextActionService:BindAction('BT: Create part', CreateAtTarget, false,
		Enum.UserInputType.MouseButton1,
		Enum.UserInputType.Touch
	)

end;

function CreatePart(Type)

	-- Send the creation request to the server
	local Part = Core.SyncAPI:Invoke('CreatePart', Type, CFrame.new(Core.Mouse.Hit.p), Core.Targeting.Scope)

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
	local MoveTool = require(Core.Tool.Tools.Move);
	Core.EquipTool(MoveTool);

	-- Enable dragging to allow easy positioning of the created part
	if DragNewParts then
		MoveTool.FreeDragging:SetUpDragging(Part)
	end;

end;

-- Return the tool
return NewPartTool;