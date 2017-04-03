local View = script.Parent;
while not _G.GetLibraries do wait() end;

-- Load libraries
local Support, Cheer = _G.GetLibraries(
	'F3X/SupportLibrary@^1.0.0',
	'F3X/Cheer@^0.0.0'
);

-- Create component
local Component = Cheer.CreateComponent('Tooltip', View);

local Connections = {};

function Component.Start(Text)

	-- Hide the view
	View.Visible = false;

	-- Set the tooltip text
	View.Text = Text;

	-- Show the tooltip on hover
	Connections.ShowOnEnter = Support.AddGuiInputListener(View.Parent, 'Began', 'MouseMovement', true, Component.Show);
	Connections.HideOnLeave = Support.AddGuiInputListener(View.Parent, 'Ended', 'MouseMovement', true, Component.Hide);

	-- Clear connections when the component is removed
	Cheer.Bind(Component.OnRemove, ClearConnections);

	-- Return component for chaining
	return Component;

end;

function Component.Show()
	View.Size = UDim2.new(0, View.TextBounds.X + 10, 0, View.TextBounds.Y + 10);
	View.Position = UDim2.new(0.5, -View.AbsoluteSize.X / 2, 1, 3);
	View.Visible = true;
end;

function Component.Hide()
	View.Visible = false;
end;

function ClearConnections()
	-- Clears out temporary connections

	for ConnectionKey, Connection in pairs(Connections) do
		Connection:disconnect();
		Connections[ConnectionKey] = nil;
	end;

end;