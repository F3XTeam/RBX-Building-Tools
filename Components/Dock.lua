local View = script.Parent;
while not _G.GetLibraries do wait() end;

-- Load libraries
local Support, Cheer = _G.GetLibraries(
	'F3X/SupportLibrary@^1.0.0',
	'F3X/Cheer@^0.0.0'
);

-- Create component
local Component = Cheer.CreateComponent('BTDock', View, true);

function Component.Start(Core)

	-- Show the view
	View.Visible = true;

	-- Store core API reference
	getfenv(1).Core = Core;

	-- Create selection buttons
	local UndoButton = Component.AddSelectionButton(Core.Assets.UndoInactiveDecal, 'UNDO\n(Shift + Z)');
	local RedoButton = Component.AddSelectionButton(Core.Assets.RedoInactiveDecal, 'REDO\n(Shift + Y)');
	local DeleteButton = Component.AddSelectionButton(Core.Assets.DeleteInactiveDecal, 'DELETE\n(Shift + X)');
	local ExportButton = Component.AddSelectionButton(Core.Assets.ExportInactiveDecal, 'EXPORT\n(Shift + P)');
	local CloneButton = Component.AddSelectionButton(Core.Assets.CloneInactiveDecal, 'CLONE\n(Shift + C)');

	-- Connect selection buttons to core systems
	Cheer.Bind(UndoButton, Core.History.Undo);
	Cheer.Bind(RedoButton, Core.History.Redo);
	Cheer.Bind(CloneButton, Core.CloneSelection);
	Cheer.Bind(DeleteButton, Core.DeleteSelection);
	Cheer.Bind(ExportButton, Core.ExportSelection);

	-- Highlight history selection buttons according to state
	Cheer.Bind(Core.History.Changed, function ()
		UndoButton.Image = (Core.History.Index == 0) and Core.Assets.UndoInactiveDecal or Core.Assets.UndoActiveDecal;
		RedoButton.Image = (Core.History.Index == #Core.History.Stack) and Core.Assets.RedoInactiveDecal or Core.Assets.RedoActiveDecal;
	end);

	-- Highlight clone/delete/export buttons according to selection state
	Cheer.Bind(Core.Selection.Changed, function ()
		CloneButton.Image = (#Core.Selection.Items == 0) and Core.Assets.CloneInactiveDecal or Core.Assets.CloneActiveDecal;
		DeleteButton.Image = (#Core.Selection.Items == 0) and Core.Assets.DeleteInactiveDecal or Core.Assets.DeleteActiveDecal;
		ExportButton.Image = (#Core.Selection.Items == 0) and Core.Assets.ExportInactiveDecal or Core.Assets.ExportActiveDecal;
	end);

	-- Highlight current tools
	Cheer.Bind(Core.ToolChanged, function ()
		for Tool, Button in pairs(Component.ToolButtons) do
			Button.BackgroundTransparency = (Tool == Core.CurrentTool) and 0 or 1;
		end;
	end);

	-- Toggle help section on help button click
	Cheer.Bind(View.InfoButtons.HelpButton, function ()
		Cheer(View.ToolInformation).HideCurrentSection();
		View.HelpInfo.Visible = not View.HelpInfo.Visible;
	end);

	-- Start tool information section manager
	Cheer(View.ToolInformation).Start(Core);

	-- Return component for chaining
	return Component;

end;

function Component.AddSelectionButton(InitialIcon, Tooltip)

	-- Create the button
	local Button = View.SelectionButton:Clone();
	local Index = #View.SelectionButtons:GetChildren();
	Button.Parent = View.SelectionButtons;
	Button.Image = InitialIcon;
	Button.Visible = true;

	-- Position the button
	Button.Position = UDim2.new(Index % 2 * 0.5, 0, 0, Button.AbsoluteSize.Y * math.floor(Index / 2));

	-- Add a tooltip to the button
	Cheer(View.Tooltip, Button).Start(Tooltip);

	-- Return the button
	return Button;

end;

Component.ToolButtons = {};

function Component.AddToolButton(Icon, Hotkey, Tool, InfoSection)

	-- Create the button
	local Button = View.ToolButton:Clone();
	local Index = #View.ToolButtons:GetChildren();
	Button.Parent = View.ToolButtons;
	Button.BackgroundColor3 = Tool.Color and Tool.Color.Color or Color3.new(0, 0, 0);
	Button.BackgroundTransparency = (Core.CurrentTool == Tool) and 0 or 1;
	Button.Image = Icon;
	Button.Visible = true;
	Button.Hotkey.Text = Hotkey;

	-- Register the button
	Component.ToolButtons[Tool] = Button;

	-- Trigger tool when button is pressed
	Cheer.Bind(Button, Support.Call(Core.EquipTool, Tool));

	-- Register information section
	Cheer(View.ToolInformation).RegisterSection(InfoSection);

	-- Trigger information section on interactions with button
	Support.AddGuiInputListener(Button, 'Began', {'MouseButton1'}, false, function ()
		Cheer(View.ToolInformation).ProcessClick(Tool, InfoSection)
	end)
	Support.AddGuiInputListener(Button, 'Began', {'MouseMovement'}, false, function ()
		Cheer(View.ToolInformation).ProcessHover(Tool, InfoSection)
	end)
	Support.AddGuiInputListener(Button, 'Ended', {'MouseMovement'}, true, function ()
		Cheer(View.ToolInformation).ProcessUnhover(Tool, InfoSection)
	end)

	-- Time how long each press on the button lasts
	local TouchStart = nil
	Support.AddGuiInputListener(Button, 'Began', {'Touch'}, false, function ()
		local Timestamp = tick()
		TouchStart = Timestamp
		wait(0.5)

		-- Trigger tool info if still touching after delay
		if TouchStart == Timestamp then
			Cheer(View.ToolInformation).ProcessClick(Tool, InfoSection)
		end
	end)
	Support.AddGuiInputListener(Button, 'Ended', {'Touch'}, true, function ()
		TouchStart = nil
	end)

	-- Position the button
	Button.Position = UDim2.new(Index % 2 * 0.5, 0, 0, Button.AbsoluteSize.Y * math.floor(Index / 2));

	-- Return the button
	return Button;

end;

-- Indicate readiness
Component.Ready = true;

return Component;