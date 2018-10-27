-- Load libraries
while not _G.GetLibraries do wait() end;
local Support, Cheer = _G.GetLibraries(
	'F3X/SupportLibrary@^1.0.0',
	'F3X/Cheer@^0.0.0'
);

local View = script.Parent;
local Component = Cheer.CreateComponent('BTHSVColorPicker', View);

local Connections = {};

function Component.Start(InitialColor, Callback, SelectionPreventionCallback, PreviewCallback)

	-- Show the UI
	View.Visible = true;

	-- Start the color
	InitialColor = InitialColor or Color3.new(1, 1, 1);
	Hue, Saturation, Brightness = Color3.toHSV(InitialColor);
	Hue, Saturation, Brightness = Cheer.Link(Hue), Cheer.Link(Saturation), Cheer.Link(Brightness);

	-- Connect direct inputs to color setting
	Cheer.Bind(View.HueOption.Input, { Cheer.Clamp(0, 360), Cheer.Divide(360) }, Hue);
	Cheer.Bind(View.SaturationOption.Input, { Cheer.Clamp(0, 100), Cheer.Divide(100) }, Saturation);
	Cheer.Bind(View.BrightnessOption.Input, { Cheer.Clamp(0, 100), Cheer.Divide(100) }, Brightness);

	-- Connect color to inputs
	Cheer.Bind(Hue, { Cheer.Multiply(360), Cheer.Round(0) }, View.HueOption.Input):Trigger();
	Cheer.Bind(Saturation, { Cheer.Multiply(100), Cheer.Round(0), tostring, Cheer.Append('%') }, View.SaturationOption.Input):Trigger();
	Cheer.Bind(Brightness, { Cheer.Multiply(100), Cheer.Round(0), tostring, Cheer.Append('%') }, View.BrightnessOption.Input):Trigger();

	-- Connect color to color display
	Cheer.Bind(Hue, UpdateDisplay):Trigger();
	Cheer.Bind(Saturation, UpdateDisplay):Trigger();
	Cheer.Bind(Brightness, UpdateDisplay):Trigger();

	-- Connect mouse to interactive picker
	Connections.TrackColor = Support.AddGuiInputListener(View.HueSaturation, 'Began', 'MouseButton1', true, Support.Call(StartTrackingMouse, 'HS'));
	Connections.TrackBrightness = Support.AddGuiInputListener(View.Brightness, 'Began', 'MouseButton1', true, Support.Call(StartTrackingMouse, 'B'));
	Connections.StopTrackingMouse = Support.AddUserInputListener('Ended', 'MouseButton1', true, StopTrackingMouse);

	-- Connect OK button to finish color picking
	Cheer.Bind(View.OkButton, function ()

		-- Clear any preview
		if PreviewCallback then
			PreviewCallback();
		end;

		-- Remove the UI
		View:Destroy();

		-- Return the selected color
		Callback(Color3.fromHSV(#Hue, #Saturation, #Brightness));

	end);

	-- Connect cancel button to clear preview and remove UI
	Cheer.Bind(View.CancelButton, function () if PreviewCallback then PreviewCallback() end; View:Destroy(); end);

	-- Store reference to callbacks
	Component.SelectionPreventionCallback = SelectionPreventionCallback;
	Component.PreviewCallback = PreviewCallback;

	-- Clear connections when the component is removed
	Cheer.Bind(Component.OnRemove, ClearConnections);

end;

function StartTrackingMouse(TrackingType)

	-- Only start tracking if not already tracking
	if Connections.MouseTracking then
		return;
	end;

	-- Watch mouse movement and adjust current color
	Connections.MouseTracking = Support.AddUserInputListener('Changed', 'MouseMovement', true, function (Input)

		-- Track for hue-saturation
		if TrackingType == 'HS' then
			Hue('Update', Support.Clamp((Input.Position.X - View.HueSaturation.AbsolutePosition.X) / View.HueSaturation.AbsoluteSize.X, 0, 1));
			Saturation('Update', 1 - Support.Clamp((Input.Position.Y - View.HueSaturation.AbsolutePosition.Y) / View.HueSaturation.AbsoluteSize.Y, 0, 1));

		-- Track for brightness
		elseif TrackingType == 'B' then
			Brightness('Update', 1 - Support.Clamp((Input.Position.Y - View.Brightness.AbsolutePosition.Y) / View.Brightness.AbsoluteSize.Y, 0, 1));
		end;

	end);

	-- Prevent selection if a callback to do so is provided
	if Component.SelectionPreventionCallback then
		Component.SelectionPreventionCallback();
	end;

end;

function StopTrackingMouse()
	-- Releases any tracking

	-- Ensure ongoing tracking
	if not Connections.MouseTracking then
		return;
	end;

	-- Disable any current tracking
	Connections.MouseTracking:Disconnect();
	Connections.MouseTracking = nil;

end;

function UpdateDisplay()
	-- Updates the display based on the current color

	-- Get current color
	local CurrentColor = Color3.fromHSV(#Hue, #Saturation, #Brightness);

	-- Update the color display
	View.ColorDisplay.BackgroundColor3 = CurrentColor;
	View.HueOption.Bar.BackgroundColor3 = CurrentColor;
	View.SaturationOption.Bar.BackgroundColor3 = CurrentColor;
	View.BrightnessOption.Bar.BackgroundColor3 = CurrentColor;

	-- Update the interactive color picker
	View.HueSaturation.Cursor.Position = UDim2.new(
		#Hue, View.HueSaturation.Cursor.Position.X.Offset,
		1 - #Saturation, View.HueSaturation.Cursor.Position.Y.Offset
	);

	-- Update the interactive brightness picker
	View.Brightness.ColorBG.BackgroundColor3 = CurrentColor;
	View.Brightness.Cursor.Position = UDim2.new(
		View.Brightness.Cursor.Position.X.Scale, View.Brightness.Cursor.Position.X.Offset,
		1 - #Brightness, View.Brightness.Cursor.Position.Y.Offset
	);

	-- Update the preview if enabled
	if Component.PreviewCallback then
		Component.PreviewCallback(CurrentColor);
	end;

end;

function ClearConnections()
	-- Clears out temporary connections

	for ConnectionKey, Connection in pairs(Connections) do
		Connection:Disconnect();
		Connections[ConnectionKey] = nil;
	end;

end;

return Component;