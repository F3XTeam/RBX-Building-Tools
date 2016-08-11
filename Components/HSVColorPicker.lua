-- Libraries
Support = require(script.SupportLibrary);
Cheer = require(script.Cheer);

local View = script.Parent;
local Component = Cheer.CreateComponent('HSVColorPicker', View);

local Connections = {};

function Component.Start(InitialColor, Callback)

	-- Show the UI
	View.Visible = true;

	-- Start the color
	InitialColor = InitialColor or Color3.new(1, 1, 1);
	Hue, Saturation, Brightness = Color3.toHSV(InitialColor);
	Hue, Saturation, Brightness = Cheer.Link(Hue), Cheer.Link(Saturation), Cheer.Link(Brightness);

	-- Connect direct inputs to color setting
	Cheer.Bind(View.HueOption.Input, Cheer.Clamp(0, 360), Cheer.Divide(360), Hue);
	Cheer.Bind(View.SaturationOption.Input, Cheer.Clamp(0, 100), Cheer.Divide(100), Saturation);
	Cheer.Bind(View.BrightnessOption.Input, Cheer.Clamp(0, 100), Cheer.Divide(100), Brightness);

	-- Connect color to inputs
	Cheer.Bind(Hue, Cheer.Multiply(360), Cheer.Round(0), View.HueOption.Input):Trigger();
	Cheer.Bind(Saturation, Cheer.Multiply(100), Cheer.Round(0), tostring, Cheer.Append('%'), View.SaturationOption.Input):Trigger();
	Cheer.Bind(Brightness, Cheer.Multiply(100), Cheer.Round(0), tostring, Cheer.Append('%'), View.BrightnessOption.Input):Trigger();

	-- Connect color to color display
	Cheer.Bind(Hue, UpdateDisplay):Trigger();
	Cheer.Bind(Saturation, UpdateDisplay):Trigger();
	Cheer.Bind(Brightness, UpdateDisplay):Trigger();

	-- Connect mouse to interactive picker
	Connections.TrackColor = Support.AddGuiInputListener(View.HueSaturation, 'Began', 'MouseButton1', true, Support.Call(StartTrackingMouse, 'HS'));
	Connections.TrackBrightness = Support.AddGuiInputListener(View.Brightness, 'Began', 'MouseButton1', true, Support.Call(StartTrackingMouse, 'B'));
	Connections.StopTrackingMouse = Support.AddUserInputListener('Ended', 'MouseButton1', true, StopTrackingMouse);

	-- Connect OK/Cancel buttons
	Cheer.Bind(View.OkButton, function () View:Destroy(); return Color3.fromHSV(#Hue, #Saturation, #Brightness) end, Callback);
	Cheer.Bind(View.CancelButton, function () View:Destroy() end);

	-- Clear connections when the component is removed
	Cheer.Bind(Component.OnRemove, ClearConnections);

end;

function StartTrackingMouse(TrackingType)

	-- Only start tracking if not already tracking
	if Connections.MouseTracking then
		return;
	end;

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

end;

function StopTrackingMouse()
	-- Releases any tracking

	-- Ensure ongoing tracking
	if not Connections.MouseTracking then
		return;
	end;

	-- Disable any current tracking
	Connections.MouseTracking:disconnect();
	Connections.MouseTracking = nil;

end;

function UpdateDisplay()
	-- Updates the display based on the current color

	-- Update the color display
	View.ColorDisplay.BackgroundColor3 = Color3.fromHSV(#Hue, #Saturation, #Brightness);

	-- Update the interactive color picker
	View.HueSaturation.Cursor.Position = UDim2.new(
		#Hue, View.HueSaturation.Cursor.Position.X.Offset,
		1 - #Saturation, View.HueSaturation.Cursor.Position.Y.Offset
	);

	-- Update the interactive brightness picker
	View.Brightness.ColorBG.BackgroundColor3 = Color3.fromHSV(#Hue, #Saturation, 1);
	View.Brightness.Cursor.Position = UDim2.new(
		View.Brightness.Cursor.Position.X.Scale, View.Brightness.Cursor.Position.X.Offset,
		1 - #Brightness, View.Brightness.Cursor.Position.Y.Offset
	);

end;

function ClearConnections()
	-- Clears out temporary connections

	for ConnectionKey, Connection in pairs(Connections) do
		Connection:disconnect();
		Connections[ConnectionKey] = nil;
	end;

end;

return Component;