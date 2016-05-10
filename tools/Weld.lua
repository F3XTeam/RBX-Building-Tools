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
local WeldTool = {

	Name = 'Weld Tool';
	Color = BrickColor.new 'Really black';

	-- Standard platform event interface
	Listeners = {};

};

-- Container for temporary connections (disconnected automatically)
local Connections = {};

function Equip()
	-- Enables the tool's equipped functionality

	-- Start up our interface
	ShowUI();

end;

function Unequip()
	-- Disables the tool's equipped functionality

	-- Clear unnecessary resources
	HideUI();
	ClearConnections();

end;

WeldTool.Listeners.Equipped = Equip;
WeldTool.Listeners.Unequipped = Unequip;

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
	UI = Core.Tool.Interfaces.BTWeldToolGUI:Clone();
	UI.Parent = Core.UI;
	UI.Visible = true;

	-- Hook up the buttons
	UI.Interface.WeldButton.MouseButton1Click:connect(CreateWelds);
	UI.Interface.BreakWeldsButton.MouseButton1Click:connect(BreakWelds);

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

function CreateWelds()
	-- Creates welds for every selected part to the focused part

	-- Send the change request to the server API
	local Welds = Core.ServerAPI:InvokeServer('CreateWelds', Selection.Items, Selection.Last);

	-- Update the UI with the number of welds created
	UI.Changes.Text.Text = ('created %s weld%s'):format(#Welds, #Welds == 1 and '' or 's');

	-- Play a confirmation sound
	local Sound = Create 'Sound' {
		Name = 'BTActionCompletionSound';
		Pitch = 1.5;
		SoundId = Core.Assets.ActionCompletionSound;
		Volume = 1;
		Parent = Player or SoundService;
	};
	Sound:Play();
	Sound:Destroy();

	-- Put together the history record
	local HistoryRecord = {
		Welds = Welds;

		Unapply = function (HistoryRecord)
			-- Reverts this change

			-- Remove the welds
			Core.ServerAPI:InvokeServer('RemoveWelds', HistoryRecord.Welds);

		end;

		Apply = function (HistoryRecord)
			-- Reapplies this change

			-- Restore the welds
			Core.ServerAPI:InvokeServer('UndoRemovedWelds', HistoryRecord.Welds);

		end;

	};

	-- Register the history record
	Core.History:Add(HistoryRecord);

end;

function BreakWelds()
	-- Search for any selection-connecting, BT-created welds and remove them

	local Welds = {};

	-- Go through each selected part
	for _, Part in pairs(Selection.Items) do

		-- Search JointsService for relevant joints
		for _, Joint in pairs(Game.JointsService:GetChildren()) do

			-- Collect this joint if it is a BT-created weld connecting `Part`
			if Joint.Name == 'BTWeld' and Joint.ClassName == 'Weld' and (Joint.Part0 == Part or Joint.Part1 == Part) then
				table.insert(Welds, Joint);
			end;

		end;

	end;

	-- Send the change request to the server API
	local WeldsRemoved = Core.ServerAPI:InvokeServer('RemoveWelds', Welds);

	-- Update the UI with the number of welds removed
	UI.Changes.Text.Text = ('removed %s weld%s'):format(WeldsRemoved, WeldsRemoved == 1 and '' or 's');

	-- Put together the history record
	local HistoryRecord = {
		Welds = Welds;

		Unapply = function (HistoryRecord)
			-- Reverts this change

			-- Restore the welds
			Core.ServerAPI:InvokeServer('UndoRemovedWelds', HistoryRecord.Welds);

		end;

		Apply = function (HistoryRecord)
			-- Reapplies this change

			-- Remove the welds
			Core.ServerAPI:InvokeServer('RemoveWelds', HistoryRecord.Welds);

		end;

	};

	-- Register the history record
	Core.History:Add(HistoryRecord);

end;

-- Mark the tool as fully loaded
Core.Tools.Weld = WeldTool;
WeldTool.Loaded = true;