local View = script.Parent;
while not _G.GetLibraries do wait() end;

-- Load libraries
local Support, Cheer = _G.GetLibraries(
	'F3X/SupportLibrary@^1.0.0',
	'F3X/Cheer@^0.0.0'
);

-- Create component
local Component = Cheer.CreateComponent('BTExportDialog', View);

function Component.Start()

	-- Show the view
	View.Visible = true;

	-- Animate opening
	View.Loading.Size = UDim2.new(1, 0, 0, 0);
	View.Loading:TweenSize(UDim2.new(1, 0, 0, 80), nil, nil, 0.25);

	-- Enable close buttons
	Cheer.Bind(View.Close.Button, Component.Close);
	Cheer.Bind(View.Loading.CloseButton, Component.Close);

	-- Return component for chaining
	return Component;

end;

function Component.Close()
	-- Closes the dialog

	-- Destroy the view
	View:Destroy();

end;

function Component.SetError(Error)
	-- Sets the dialog error

	-- Set error text
	View.Loading.TextLabel.Text = Error;

end;

function Component.SetResult(Result)
	-- Sets the dialog result

	-- Hide loading message
	View.Loading.Visible = false;	

	-- Set result text
	View.Info.CreationID.Text = Result;

	-- Animate opening for result UI
	View.Info.Size = UDim2.new(1, 0, 0, 0);
	View.Info.Visible = true;
	View.Info:TweenSize(UDim2.new(1, 0, 0, 75), nil, nil, 0.25);
	View.Tip.Size = UDim2.new(1, 0, 0, 0);
	View.Tip.Visible = true;
	View.Tip:TweenSize(UDim2.new(1, 0, 0, 30), nil, nil, 0.25);
	View.Close.Size = UDim2.new(1, 0, 0, 0);
	View.Close.Visible = true;
	View.Close:TweenSize(UDim2.new(1, 0, 0, 20), nil, nil, 0.25);

end;

return Component;