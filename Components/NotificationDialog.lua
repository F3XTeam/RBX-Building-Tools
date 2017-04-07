local View = script.Parent;
while not _G.GetLibraries do wait() end;

-- Load libraries
local Support, Cheer = _G.GetLibraries(
	'F3X/SupportLibrary@^1.0.0',
	'F3X/Cheer@^0.0.0'
);

-- Create component
local Component = Cheer.CreateComponent('BTNotificationDialog', View);

function Component.Start(OnExpandCallback)

	-- Destroy dialog on OK button click
	Cheer.Bind(View.OKButton, function ()
		View:Destroy();
	end);

	-- Open help section on button click
	Cheer.Bind(View.HelpButton, function ()

		-- Expand OK button
		View.HelpButton:Destroy();
		View.ButtonSeparator:Destroy();
		View.OKButton:TweenSize(UDim2.new(1, 0, 0, 22), nil, nil, 0.2);

		-- Replace notice with help section
		View.Notice:Destroy();
		View.Help.Visible = true;
		View:TweenSize(
			UDim2.new(View.Size.X.Scale, View.Size.X.Offset, View.Size.Y.Scale, View.Help.NotificationSize.Value),
			nil, nil, 0.2, false, OnExpandCallback
		);

	end);

	-- Show dialog
	View.Visible = true;

	-- Return component for chaining
	return Component;

end;

return Component;