-- Load the main tool's core environment when it's ready
repeat wait() until (
	_G.BTCoreEnv and
	_G.BTCoreEnv[script.Parent.Parent] and
	_G.BTCoreEnv[script.Parent.Parent].CoreReady
);
setfenv( 1, _G.BTCoreEnv[script.Parent.Parent] );

------------------------------------------
-- Lighting tool
------------------------------------------

-- Create the tool
Tools.Lighting = {};
Tools.Lighting.Name = 'Lighting Tool';

-- Define the tool's color
Tools.Lighting.Color = BrickColor.new( "Really black" );

-- Keep a container for state data
Tools.Lighting.State = {};

-- Keep a container for temporary connections
Tools.Lighting.Connections = {};

-- Keep a container for platform event connections
Tools.Lighting.Listeners = {};

-- Start adding functionality to the tool
Tools.Lighting.Listeners.Equipped = function ()

	local self = Tools.Lighting;

	-- Change the color of selection boxes temporarily
	self.State.PreviousSelectionBoxColor = SelectionBoxColor;
	SelectionBoxColor = self.Color;
	updateSelectionBoxColor();

	-- Reveal the GUI
	self:showGUI();

	-- Update the GUI regularly
	coroutine.wrap( function ()
		updater_on = true;

		-- Provide a function to stop the loop
		self.Updater = function ()
			updater_on = false;
		end;

		while wait( 0.1 ) and updater_on do

			-- Make sure the tool's equipped
			if CurrentTool == self then

				-- Update the GUI if it's visible
				if self.GUI and self.GUI.Visible then
					self:updateGUI();
				end;

			end;

		end;

	end )();

end;

Tools.Lighting.Listeners.Unequipped = function ()

	local self = Tools.Lighting;

	-- Stop the GUI updater
	if self.Updater then
		self.Updater();
		self.Updater = nil;
	end;

	-- Hide the GUI
	self:hideGUI();

	-- Disconnect temporary connections
	for connection_index, Connection in pairs( self.Connections ) do
		Connection:disconnect();
		self.Connections[connection_index] = nil;
	end;

	-- Restore the original color of selection boxes
	SelectionBoxColor = self.State.PreviousSelectionBoxColor;
	updateSelectionBoxColor();

end;

Tools.Lighting.Listeners.Button2Down = function ()

	local self = Tools.Lighting;

	-- Capture the camera rotation (for later use
	-- in determining whether a surface was being
	-- selected or the camera was being rotated
	-- with the right mouse button)
	local cr_x, cr_y, cr_z = Workspace.CurrentCamera.CoordinateFrame:toEulerAnglesXYZ();
	self.State.PreB2DownCameraRotation = Vector3.new( cr_x, cr_y, cr_z );

end;

Tools.Lighting.Listeners.Button2Up = function ()

	local self = Tools.Lighting;

	local cr_x, cr_y, cr_z = Workspace.CurrentCamera.CoordinateFrame:toEulerAnglesXYZ();
	local CameraRotation = Vector3.new( cr_x, cr_y, cr_z );

	-- If a surface is selected, change the side option
	if Selection:find( Mouse.Target ) and self.State.PreB2DownCameraRotation == CameraRotation then
		self:changeSide( Mouse.TargetSurface );
	end;

end;

Tools.Lighting.updateGUI = function ( self )

	-- Make sure the GUI exists
	if not self.GUI then
		return;
	end;

	-- If there are items, display the regular interface
	if #Selection.Items > 0 then
		local spotlights = self:getSpotlights();
		local pointlights = self:getPointLights();

		-- Get the properties of the spot/point lights
		local sl_color_r, sl_color_g, sl_color_b, sl_brightness, sl_range, sl_shadows, sl_angle, sl_side;
		local pl_color_r, pl_color_g, pl_color_b, pl_brightness, pl_range, pl_shadows;
		for light_index, Light in pairs( spotlights ) do

			-- Set the initial values for later comparison
			if light_index == 1 then
				sl_color_r, sl_color_g, sl_color_b = Light.Color.r, Light.Color.g, Light.Color.b;
				sl_brightness = Light.Brightness;
				sl_range = Light.Range;
				sl_shadows = Light.Shadows;
				sl_angle = Light.Angle;
				sl_side = Light.Face;

			-- Set the values to `nil` if they vary across the selection
			else
				if sl_color_r ~= Light.Color.r then
					sl_color_r = nil;
				end;
				if sl_color_g ~= Light.Color.g then
					sl_color_g = nil;
				end;
				if sl_color_b ~= Light.Color.b then
					sl_color_b = nil;
				end;
				if sl_brightness ~= Light.Brightness then
					sl_brightness = nil;
				end;
				if sl_range ~= Light.Range then
					sl_range = nil;
				end;
				if sl_shadows ~= Light.Shadows then
					sl_shadows = nil;
				end;
				if sl_angle ~= Light.Angle then
					sl_angle = nil;
				end;
				if sl_side ~= Light.Face then
					sl_side = nil;
				end;
			end;

		end;

		for light_index, Light in pairs( pointlights ) do

			-- Set the initial values for later comparison
			if light_index == 1 then
				pl_color_r, pl_color_g, pl_color_b = Light.Color.r, Light.Color.g, Light.Color.b;
				pl_brightness = Light.Brightness;
				pl_range = Light.Range;
				pl_shadows = Light.Shadows;

			-- Set the values to `nil` if they vary across the selection
			else
				if pl_color_r ~= Light.Color.r then
					pl_color_r = nil;
				end;
				if pl_color_g ~= Light.Color.g then
					pl_color_g = nil;
				end;
				if pl_color_b ~= Light.Color.b then
					pl_color_b = nil;
				end;
				if pl_brightness ~= Light.Brightness then
					pl_brightness = nil;
				end;
				if pl_range ~= Light.Range then
					pl_range = nil;
				end;
				if pl_shadows ~= Light.Shadows then
					pl_shadows = nil;
				end;
			end;

		end;

		self.State.sl_color = ( sl_color_r and sl_color_g and sl_color_b ) and Color3.new( sl_color_r, sl_color_g, sl_color_b ) or nil;
		self.State.pl_color = ( pl_color_r and pl_color_g and pl_color_b ) and Color3.new( pl_color_r, pl_color_g, pl_color_b ) or nil;

		-- Update the spotlight GUI data
		if not self.State.sl_color_r_focused then
			self.GUI.Spotlight.Options.ColorOption.RInput.TextBox.Text = sl_color_r and Support.Round(sl_color_r * 255, 0) or '*';
		end;
		if not self.State.sl_color_g_focused then
			self.GUI.Spotlight.Options.ColorOption.GInput.TextBox.Text = sl_color_g and Support.Round(sl_color_g * 255, 0) or '*';
		end;
		if not self.State.sl_color_b_focused then
			self.GUI.Spotlight.Options.ColorOption.BInput.TextBox.Text = sl_color_b and Support.Round(sl_color_b * 255, 0) or '*';
		end;
		if not self.State.sl_brightness_focused then
			self.GUI.Spotlight.Options.BrightnessOption.Input.TextBox.Text = sl_brightness and Support.Round(sl_brightness, 2) or '*';
		end;
		if not self.State.sl_range_focused then
			self.GUI.Spotlight.Options.RangeOption.Input.TextBox.Text = sl_range and Support.Round(sl_range, 2) or '*';
		end;
		if sl_shadows == nil then
			self.GUI.Spotlight.Options.ShadowsOption.On.Background.Image = Assets.LightSlantedRectangle;
			self.GUI.Spotlight.Options.ShadowsOption.On.SelectedIndicator.BackgroundTransparency = 1;
			self.GUI.Spotlight.Options.ShadowsOption.Off.Background.Image = Assets.LightSlantedRectangle;
			self.GUI.Spotlight.Options.ShadowsOption.Off.SelectedIndicator.BackgroundTransparency = 1;
		elseif sl_shadows == true then
			self.GUI.Spotlight.Options.ShadowsOption.On.Background.Image = Assets.DarkSlantedRectangle;
			self.GUI.Spotlight.Options.ShadowsOption.On.SelectedIndicator.BackgroundTransparency = 0;
			self.GUI.Spotlight.Options.ShadowsOption.Off.Background.Image = Assets.LightSlantedRectangle;
			self.GUI.Spotlight.Options.ShadowsOption.Off.SelectedIndicator.BackgroundTransparency = 1;
		elseif sl_shadows == false then
			self.GUI.Spotlight.Options.ShadowsOption.On.Background.Image = Assets.LightSlantedRectangle;
			self.GUI.Spotlight.Options.ShadowsOption.On.SelectedIndicator.BackgroundTransparency = 1;
			self.GUI.Spotlight.Options.ShadowsOption.Off.Background.Image = Assets.DarkSlantedRectangle;
			self.GUI.Spotlight.Options.ShadowsOption.Off.SelectedIndicator.BackgroundTransparency = 0;
		end;
		if not self.State.sl_angle_focused then
			self.GUI.Spotlight.Options.AngleOption.Input.TextBox.Text = sl_angle and Support.Round(sl_angle, 2) or '*';
		end;
		self.SideDropdown:selectOption( sl_side and sl_side.Name:upper() or '*' );

		-- Update the point light GUI info
		if not self.State.pl_color_r_focused then
			self.GUI.PointLight.Options.ColorOption.RInput.TextBox.Text = pl_color_r and Support.Round(pl_color_r * 255, 0) or '*';
		end;
		if not self.State.pl_color_g_focused then
			self.GUI.PointLight.Options.ColorOption.GInput.TextBox.Text = pl_color_g and Support.Round(pl_color_g * 255, 0) or '*';
		end;
		if not self.State.pl_color_b_focused then
			self.GUI.PointLight.Options.ColorOption.BInput.TextBox.Text = pl_color_b and Support.Round(pl_color_b * 255, 0) or '*';
		end;
		if not self.State.pl_brightness_focused then
			self.GUI.PointLight.Options.BrightnessOption.Input.TextBox.Text = pl_brightness and Support.Round(pl_brightness, 2) or '*';
		end;
		if not self.State.pl_range_focused then
			self.GUI.PointLight.Options.RangeOption.Input.TextBox.Text = pl_range and Support.Round(pl_range, 2) or '*';
		end;
		if pl_shadows == nil then
			self.GUI.PointLight.Options.ShadowsOption.On.Background.Image = Assets.LightSlantedRectangle;
			self.GUI.PointLight.Options.ShadowsOption.On.SelectedIndicator.BackgroundTransparency = 1;
			self.GUI.PointLight.Options.ShadowsOption.Off.Background.Image = Assets.LightSlantedRectangle;
			self.GUI.PointLight.Options.ShadowsOption.Off.SelectedIndicator.BackgroundTransparency = 1;
		elseif pl_shadows == true then
			self.GUI.PointLight.Options.ShadowsOption.On.Background.Image = Assets.DarkSlantedRectangle;
			self.GUI.PointLight.Options.ShadowsOption.On.SelectedIndicator.BackgroundTransparency = 0;
			self.GUI.PointLight.Options.ShadowsOption.Off.Background.Image = Assets.LightSlantedRectangle;
			self.GUI.PointLight.Options.ShadowsOption.Off.SelectedIndicator.BackgroundTransparency = 1;
		elseif pl_shadows == false then
			self.GUI.PointLight.Options.ShadowsOption.On.Background.Image = Assets.LightSlantedRectangle;
			self.GUI.PointLight.Options.ShadowsOption.On.SelectedIndicator.BackgroundTransparency = 1;
			self.GUI.PointLight.Options.ShadowsOption.Off.Background.Image = Assets.DarkSlantedRectangle;
			self.GUI.PointLight.Options.ShadowsOption.Off.SelectedIndicator.BackgroundTransparency = 0;
		end;

		if self.GUI.SelectNote.Visible then
			self:closePointLight();
			self:closeSpotlight();
		end;
		self.GUI.Spotlight.Visible = true;
		self.GUI.PointLight.Visible = true;
		self.GUI.SelectNote.Visible = false;

		if not self.State.spotlight_open and not self.State.pointlight_open then
			self.GUI:TweenSize( UDim2.new( 0, 200, 0, 95 ), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true );
		end;

		-- If there are no spotlights
		if #spotlights == 0 then
			self.GUI.Spotlight.Options.Size = UDim2.new( 1, -3, 0, 0 );
			self.GUI.Spotlight.AddButton.Visible = true;
			self.GUI.Spotlight.RemoveButton.Visible = false;
			if self.State.spotlight_open then
				self:closeSpotlight();
			end;

		-- If only some items have spotlights
		elseif #spotlights ~= #Selection.Items then
			self.GUI.Spotlight.AddButton.Visible = true;
			self.GUI.Spotlight.RemoveButton.Position = UDim2.new( 0, 90, 0, 3 );
			self.GUI.Spotlight.RemoveButton.Visible = true;

		-- If all items have spotlights
		elseif #spotlights == #Selection.Items then
			self.GUI.Spotlight.AddButton.Visible = false;
			self.GUI.Spotlight.RemoveButton.Position = UDim2.new( 0, 127, 0, 3 );
			self.GUI.Spotlight.RemoveButton.Visible = true;
			if self.GUI.Spotlight.Size == UDim2.new( 0, 200, 0, 52 ) then
				self.GUI.Spotlight.Size = UDim2.new( 0, 200, 0, 95 );
			end;
		end;

		-- If there are no point lights
		if #pointlights == 0 then
			self.GUI.PointLight.Options.Size = UDim2.new( 1, -3, 0, 0 );
			self.GUI.PointLight.AddButton.Visible = true;
			self.GUI.PointLight.RemoveButton.Visible = false;
			if self.State.pointlight_open then
				self:closePointLight();
			end;

		-- If only some items have point lights
		elseif #pointlights ~= #Selection.Items then
			self.GUI.PointLight.AddButton.Visible = true;
			self.GUI.PointLight.RemoveButton.Position = UDim2.new( 0, 90, 0, 3 );
			self.GUI.PointLight.RemoveButton.Visible = true;

		-- If all items have point lights
		elseif #pointlights == #Selection.Items then
			self.GUI.PointLight.AddButton.Visible = false;
			self.GUI.PointLight.RemoveButton.Position = UDim2.new( 0, 127, 0, 3 );
			self.GUI.PointLight.RemoveButton.Visible = true;
		end;

	-- If nothing is selected, show the select something note
	else
		self.GUI.Spotlight.Visible = false;
		self.GUI.PointLight.Visible = false;
		self.GUI.SelectNote.Visible = true;
		self.GUI.Size = UDim2.new( 0, 200, 0, 52 );
	end;

end;

Tools.Lighting.openSpotlight = function ( self )
	self.State.spotlight_open = true;
	self:closePointLight();
	self.GUI.Spotlight.Options:TweenSize( UDim2.new( 1, -3, 0, 300 ), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true );
	self.GUI.Spotlight:TweenPosition( UDim2.new( 0, 10, 0, 30 ), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true );
	self.GUI:TweenSize( UDim2.new( 0, 200, 0, 275 ), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true );
end;

Tools.Lighting.openPointLight = function ( self )
	self.State.pointlight_open = true;
	self:closeSpotlight();
	self.GUI.PointLight.Options:TweenSize( UDim2.new( 1, -3, 0, 110 ), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true );
	self.GUI.PointLight:TweenPosition( UDim2.new( 0, 10, 0, 60 ), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true );
	self.GUI:TweenSize( UDim2.new( 0, 200, 0, 200 ), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true );
end;

Tools.Lighting.closeSpotlight = function ( self )
	self.State.spotlight_open = false;
	self.GUI.Spotlight.Options:TweenSize( UDim2.new( 1, -3, 0, 0 ), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true );
	self.GUI.PointLight:TweenPosition( UDim2.new( 0, 10, 0, 60 ), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true );
	if not self.State.pointlight_open then
		self.GUI:TweenSize( UDim2.new( 0, 200, 0, 95 ), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true );
	end;
end;

Tools.Lighting.closePointLight = function ( self )
	self.State.pointlight_open = false;
	self.GUI.PointLight:TweenPosition( UDim2.new( 0, 10, 0, self.State.spotlight_open and 240 or 60 ), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true );
	self.GUI.PointLight.Options:TweenSize( UDim2.new( 1, -3, 0, 0 ), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true );
	if not self.State.spotlight_open then
		self.GUI:TweenSize( UDim2.new( 0, 200, 0, 95 ), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true );
	end;
end;

Tools.Lighting.showGUI = function ( self )

	-- Initialize the GUI if it's not ready yet
	if not self.GUI then
		local Container = Tool.Interfaces.BTLightingToolGUI:Clone();
		Container.Parent = UI;

		Container.Spotlight.ArrowButton.MouseButton1Up:connect( function ()
			if not self.State.spotlight_open and #self:getSpotlights() > 0 then
				self:openSpotlight();
			else
				self:closeSpotlight();
			end;
		end );
		Container.PointLight.ArrowButton.MouseButton1Up:connect( function ()
			if not self.State.pointlight_open and #self:getPointLights() > 0 then
				self:openPointLight();
			else
				self:closePointLight();
			end;
		end );

		Container.Spotlight.AddButton.MouseButton1Up:connect( function ()
			self:addLight( 'SpotLight' );
			self:openSpotlight();
		end );
		Container.PointLight.AddButton.MouseButton1Up:connect( function ()
			self:addLight( 'PointLight' );
			self:openPointLight();
		end );
		Container.Spotlight.RemoveButton.MouseButton1Up:connect( function ()
			self:removeLight( 'spotlight' );
			self:closeSpotlight();
		end );
		Container.PointLight.RemoveButton.MouseButton1Up:connect( function ()
			self:removeLight( 'pointlight' );
			self:closePointLight();
		end );

		-- Create the spotlight interface's side dropdown
		local SideDropdown = createDropdown();
		self.SideDropdown = SideDropdown;
		SideDropdown.Frame.Parent = Container.Spotlight.Options.SideOption;
		SideDropdown.Frame.Position = UDim2.new( 0, 35, 0, 0 );
		SideDropdown.Frame.Size = UDim2.new( 0, 90, 0, 25 );

		SideDropdown:addOption( "TOP" ).MouseButton1Up:connect( function ()
			self:changeSide( Enum.NormalId.Top );
		end );
		SideDropdown:addOption( "BOTTOM" ).MouseButton1Up:connect( function ()
			self:changeSide( Enum.NormalId.Bottom );
		end );
		SideDropdown:addOption( "FRONT" ).MouseButton1Up:connect( function ()
			self:changeSide( Enum.NormalId.Front );
		end );
		SideDropdown:addOption( "BACK" ).MouseButton1Up:connect( function ()
			self:changeSide( Enum.NormalId.Back );
		end );
		SideDropdown:addOption( "LEFT" ).MouseButton1Up:connect( function ()
			self:changeSide( Enum.NormalId.Left );
		end );
		SideDropdown:addOption( "RIGHT" ).MouseButton1Up:connect( function ()
			self:changeSide( Enum.NormalId.Right );
		end );

		-- Add functionality to spotlight inputs
		local SpotlightUI = Container.Spotlight;

		local SLColor = SpotlightUI.Options.ColorOption;
		SLColor.RInput.TextButton.MouseButton1Down:connect( function ()
			self.State.sl_color_r_focused = true;
			SLColor.RInput.TextBox:CaptureFocus();
		end );
		SLColor.RInput.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( SLColor.RInput.TextBox.Text );
			if potential_new then
				if potential_new > 255 then
					potential_new = 255;
				elseif potential_new < 0 then
					potential_new = 0;
				end;
				self:changeColor( 'spotlight', 'r', potential_new / 255 );
			end;
			self.State.sl_color_r_focused = false;
		end );
		SLColor.GInput.TextButton.MouseButton1Down:connect( function ()
			self.State.sl_color_g_focused = true;
			SLColor.GInput.TextBox:CaptureFocus();
		end );
		SLColor.GInput.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( SLColor.GInput.TextBox.Text );
			if potential_new then
				if potential_new > 255 then
					potential_new = 255;
				elseif potential_new < 0 then
					potential_new = 0;
				end;
				self:changeColor( 'spotlight', 'g', potential_new / 255 );
			end;
			self.State.sl_color_g_focused = false;
		end );
		SLColor.BInput.TextButton.MouseButton1Down:connect( function ()
			self.State.sl_color_b_focused = true;
			SLColor.BInput.TextBox:CaptureFocus();
		end );
		SLColor.BInput.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( SLColor.BInput.TextBox.Text );
			if potential_new then
				if potential_new > 255 then
					potential_new = 255;
				elseif potential_new < 0 then
					potential_new = 0;
				end;
				self:changeColor( 'spotlight', 'b', potential_new / 255 );
			end;
			self.State.sl_color_b_focused = false;
		end );

		SLColor.HSVPicker.MouseButton1Up:connect( function ()
			ColorPicker:start( function ( ... )
				local args = { ... };
				-- If a color was picked, change the spotlights' color
				-- to the selected color
				if #args == 3 then
					self:changeColor('spotlight', Support.HSVToRGB(...));
				end;
			end, self.State.sl_color );
		end );

		local SLBrightness = SpotlightUI.Options.BrightnessOption.Input;
		SLBrightness.TextButton.MouseButton1Down:connect( function ()
			self.State.sl_brightness_focused = true;
			SLBrightness.TextBox:CaptureFocus();
		end );
		SLBrightness.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( SLBrightness.TextBox.Text );
			if potential_new then
				if potential_new > 5 then
					potential_new = 5;
				elseif potential_new < 0 then
					potential_new = 0;
				end;
				self:changeBrightness( 'spotlight', potential_new );
			end;
			self.State.sl_brightness_focused = false;
		end );

		local SLAngle = SpotlightUI.Options.AngleOption.Input;
		SLAngle.TextButton.MouseButton1Down:connect( function ()
			self.State.sl_angle_focused = true;
			SLAngle.TextBox:CaptureFocus();
		end );
		SLAngle.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( SLAngle.TextBox.Text );
			if potential_new then
				self:changeAngle( potential_new );
			end;
			self.State.sl_angle_focused = false;
		end );

		local SLRange = SpotlightUI.Options.RangeOption.Input;
		SLRange.TextButton.MouseButton1Down:connect( function ()
			self.State.sl_range_focused = true;
			SLRange.TextBox:CaptureFocus();
		end );
		SLRange.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( SLRange.TextBox.Text );
			if potential_new then
				if potential_new > 60 then
					potential_new = 60;
				elseif potential_new < 0 then
					potential_new = 0;
				end;
				self:changeRange( 'spotlight', potential_new );
			end;
			self.State.sl_range_focused = false;
		end );

		local SLShadows = SpotlightUI.Options.ShadowsOption;
		SLShadows.On.Button.MouseButton1Down:connect( function ()
			self:changeShadows( 'spotlight', true );
		end );
		SLShadows.Off.Button.MouseButton1Down:connect( function ()
			self:changeShadows( 'spotlight', false );
		end );

		-- Add functionality to point light inputs
		local PointLightUI = Container.PointLight;

		local PLColor = PointLightUI.Options.ColorOption;
		PLColor.RInput.TextButton.MouseButton1Down:connect( function ()
			self.State.pl_color_r_focused = true;
			PLColor.RInput.TextBox:CaptureFocus();
		end );
		PLColor.RInput.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( PLColor.RInput.TextBox.Text );
			if potential_new then
				if potential_new > 255 then
					potential_new = 255;
				elseif potential_new < 0 then
					potential_new = 0;
				end;
				self:changeColor( 'pointlight', 'r', potential_new / 255 );
			end;
			self.State.pl_color_r_focused = false;
		end );
		PLColor.GInput.TextButton.MouseButton1Down:connect( function ()
			self.State.pl_color_g_focused = true;
			PLColor.GInput.TextBox:CaptureFocus();
		end );
		PLColor.GInput.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( PLColor.GInput.TextBox.Text );
			if potential_new then
				if potential_new > 255 then
					potential_new = 255;
				elseif potential_new < 0 then
					potential_new = 0;
				end;
				self:changeColor( 'pointlight', 'g', potential_new / 255 );
			end;
			self.State.pl_color_g_focused = false;
		end );
		PLColor.BInput.TextButton.MouseButton1Down:connect( function ()
			self.State.pl_color_b_focused = true;
			PLColor.BInput.TextBox:CaptureFocus();
		end );
		PLColor.BInput.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( PLColor.BInput.TextBox.Text );
			if potential_new then
				if potential_new > 255 then
					potential_new = 255;
				elseif potential_new < 0 then
					potential_new = 0;
				end;
				self:changeColor( 'pointlight', 'b', potential_new / 255 );
			end;
			self.State.pl_color_b_focused = false;
		end );

		PLColor.HSVPicker.MouseButton1Up:connect( function ()
			ColorPicker:start( function ( ... )
				local args = { ... };
				-- If a color was picked, change the point lights' color
				-- to the selected color
				if #args == 3 then
					self:changeColor('pointlight', Support.HSVToRGB(...));
				end;
			end, self.State.pl_color );
		end );

		local PLBrightness = PointLightUI.Options.BrightnessOption.Input;
		PLBrightness.TextButton.MouseButton1Down:connect( function ()
			self.State.pl_brightness_focused = true;
			PLBrightness.TextBox:CaptureFocus();
		end );
		PLBrightness.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( PLBrightness.TextBox.Text );
			if potential_new then
				if potential_new > 5 then
					potential_new = 5;
				elseif potential_new < 0 then
					potential_new = 0;
				end;
				self:changeBrightness( 'pointlight', potential_new );
			end;
			self.State.pl_brightness_focused = false;
		end );

		local PLRange = PointLightUI.Options.RangeOption.Input;
		PLRange.TextButton.MouseButton1Down:connect( function ()
			self.State.pl_range_focused = true;
			PLRange.TextBox:CaptureFocus();
		end );
		PLRange.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( PLRange.TextBox.Text );
			if potential_new then
				if potential_new > 60 then
					potential_new = 60;
				elseif potential_new < 0 then
					potential_new = 0;
				end;
				self:changeRange( 'pointlight', potential_new );
			end;
			self.State.pl_range_focused = false;
		end );

		local PLShadows = PointLightUI.Options.ShadowsOption;
		PLShadows.On.Button.MouseButton1Down:connect( function ()
			self:changeShadows( 'pointlight', true );
		end );
		PLShadows.Off.Button.MouseButton1Down:connect( function ()
			self:changeShadows( 'pointlight', false );
		end );

		self.GUI = Container;
	end;

	-- Reveal the GUI
	self.GUI.Visible = true;

end;

Tools.Lighting.changeSide = function ( self, side )

	local lights = self:getSpotlights();

	self:startHistoryRecord( lights );
	for _, Light in pairs( lights ) do
		Light.Face = side;
	end;
	self:finishHistoryRecord();

	if self.SideDropdown.open then
		self.SideDropdown:toggle();
	end;

end;

Tools.Lighting.changeAngle = function ( self, angle )

	local lights = self:getSpotlights();

	self:startHistoryRecord( lights );
	for _, Light in pairs( lights ) do
		Light.Angle = angle;
	end;
	self:finishHistoryRecord();

end;

Tools.Lighting.getSpotlights = function ( self )
	-- Returns a list of all the relevant spotlights in the selection items

	local spotlights = {};

	for _, Item in pairs( Selection.Items ) do
		local Spotlight = Support.GetChildOfClass(Item, 'SpotLight');
		if Spotlight then
			table.insert( spotlights, Spotlight );
		end;
	end;

	return spotlights;

end;

Tools.Lighting.getPointLights = function ( self )
	-- Returns a list of all the relevant point lights in the selection items

	local pointlights = {};

	for _, Item in pairs( Selection.Items ) do
		local PointLight = Support.GetChildOfClass(Item, 'PointLight');
		if PointLight then
			table.insert( pointlights, PointLight );
		end;
	end;

	return pointlights;

end;

Tools.Lighting.changeColor = function ( self, target, ... )

	local args = { ... };
	local targets;

	if target == 'spotlight' then
		targets = self:getSpotlights();
	elseif target == 'pointlight' then
		targets = self:getPointLights();
	end;

	self:startHistoryRecord( targets );

	-- If only one component is being changed at a time
	if #args == 2 then
		local component = args[1];
		local component_value = args[2];

		for _, Light in pairs( targets ) do
			Light.Color = Color3.new(
				component == 'r' and component_value or Light.Color.r,
				component == 'g' and component_value or Light.Color.g,
				component == 'b' and component_value or Light.Color.b
			);
		end;

	-- If all 3 components of the color are being changed
	elseif #args == 3 then
		local r, g, b = ...;

		for _, Light in pairs( targets ) do
			Light.Color = Color3.new( r, g, b );
		end;
	end;

	self:finishHistoryRecord();
end;

Tools.Lighting.changeBrightness = function ( self, target, new_brightness )

	local targets;

	if target == 'spotlight' then
		targets = self:getSpotlights();
	elseif target == 'pointlight' then
		targets = self:getPointLights();
	end;

	self:startHistoryRecord( targets );

	for _, Light in pairs( targets ) do
		Light.Brightness = new_brightness;
	end;

	self:finishHistoryRecord();

end;

Tools.Lighting.changeRange = function ( self, target, new_range )

	local targets;

	if target == 'spotlight' then
		targets = self:getSpotlights();
	elseif target == 'pointlight' then
		targets = self:getPointLights();
	end;

	self:startHistoryRecord( targets );

	for _, Light in pairs( targets ) do
		Light.Range = new_range;
	end;

	self:finishHistoryRecord();

end;

Tools.Lighting.changeShadows = function ( self, target, new_shadows )

	local targets;

	if target == 'spotlight' then
		targets = self:getSpotlights();
	elseif target == 'pointlight' then
		targets = self:getPointLights();
	end;

	self:startHistoryRecord( targets );

	for _, Light in pairs( targets ) do
		Light.Shadows = new_shadows;
	end;

	self:finishHistoryRecord();

end;

Tools.Lighting.addLight = function ( self, light_type )

	local HistoryRecord = {
		apply = function ( self )
			Selection:clear();
			for _, Light in pairs( self.lights ) do
				Light.Parent = self.light_parents[Light];
				Selection:add( Light.Parent );
			end;
		end;
		unapply = function ( self )
			Selection:clear();
			for _, Light in pairs( self.lights ) do
				Selection:add( Light.Parent );
				Light.Parent = nil;
			end;
		end;
	};

	-- Add lights to all the items from the selection that
	-- don't already have one
	local lights = {};
	local light_parents = {};
	for _, Item in pairs( Selection.Items ) do
		local Light = Support.GetChildOfClass(Item, light_type);
		if not Light then
			local Light = RbxUtility.Create( light_type ) {
				Parent = Item;
			};
			table.insert( lights, Light );
			light_parents[Light] = Item;
		end;
	end;

	HistoryRecord.lights = lights;
	HistoryRecord.light_parents = light_parents;
	History:add( HistoryRecord );

end;

Tools.Lighting.removeLight = function ( self, light_type )

	local HistoryRecord = {
		apply = function ( self )
			Selection:clear();
			for _, Light in pairs( self.lights ) do
				Selection:add( Light.Parent );
				Light.Parent = nil;
			end;
		end;
		unapply = function ( self )
			Selection:clear();
			for _, Light in pairs( self.lights ) do
				Light.Parent = self.light_parents[Light];
				Selection:add( Light.Parent );
			end;
		end;
	};

	local lights = {};
	local light_parents = {};

	-- Remove lights from all the selected items
	local lights;
	if light_type == 'spotlight' then
		lights = self:getSpotlights();
	elseif light_type == 'pointlight' then
		lights = self:getPointLights();
	end;

	for _, Light in pairs( lights ) do
		light_parents[Light] = Light.Parent;
		Light.Parent = nil;
	end;

	HistoryRecord.lights = lights;
	HistoryRecord.light_parents = light_parents;
	History:add( HistoryRecord );

end;

Tools.Lighting.startHistoryRecord = function ( self, lights )

	if self.State.HistoryRecord then
		self.State.HistoryRecord = nil;
	end;

	-- Create a history record
	self.State.HistoryRecord = {
		targets = Support.CloneTable(lights);
		initial_color = {};			terminal_color = {};
		initial_brightness = {};	terminal_brightness = {};
		initial_range = {};			terminal_range = {};
		initial_shadows = {};		terminal_shadows = {};
		-- Spotlights only
		initial_side = {};			terminal_side = {};
		initial_angle = {};			terminal_angle = {};
		unapply = function ( self )
			Selection:clear();
			for _, Target in pairs( self.targets ) do
				if Target then
					Selection:add( Target.Parent );
					Target.Color = self.initial_color[Target];
					Target.Brightness = self.initial_brightness[Target];
					Target.Range = self.initial_range[Target];
					Target.Shadows = self.initial_shadows[Target];
					if Target:IsA( 'SpotLight' ) then
						Target.Face = self.initial_side[Target];
						Target.Angle = self.initial_angle[Target];
					end;
				end;
			end;
		end;
		apply = function ( self )
			Selection:clear();
			for _, Target in pairs( self.targets ) do
				if Target then
					Selection:add( Target.Parent );
					Target.Color = self.terminal_color[Target];
					Target.Brightness = self.terminal_brightness[Target];
					Target.Range = self.terminal_range[Target];
					Target.Shadows = self.terminal_shadows[Target];
					if Target:IsA( 'SpotLight' ) then
						Target.Face = self.terminal_side[Target];
						Target.Angle = self.terminal_angle[Target];
					end;
				end;
			end;
		end;
	};
	for _, Item in pairs( self.State.HistoryRecord.targets ) do
		if Item then
			self.State.HistoryRecord.initial_color[Item] = Item.Color;
			self.State.HistoryRecord.initial_brightness[Item] = Item.Brightness;
			self.State.HistoryRecord.initial_range[Item] = Item.Range;
			self.State.HistoryRecord.initial_shadows[Item] = Item.Shadows;
			if Item:IsA( 'SpotLight' ) then
				self.State.HistoryRecord.initial_side[Item] = Item.Face;
				self.State.HistoryRecord.initial_angle[Item] = Item.Angle;
			end;
		end;
	end;

end;

Tools.Lighting.finishHistoryRecord = function ( self )

	if not self.State.HistoryRecord then
		return;
	end;

	for _, Item in pairs( self.State.HistoryRecord.targets ) do
		if Item then
			self.State.HistoryRecord.terminal_color[Item] = Item.Color;
			self.State.HistoryRecord.terminal_brightness[Item] = Item.Brightness;
			self.State.HistoryRecord.terminal_range[Item] = Item.Range;
			self.State.HistoryRecord.terminal_shadows[Item] = Item.Shadows;
			if Item:IsA( 'SpotLight' ) then
				self.State.HistoryRecord.terminal_side[Item] = Item.Face;
				self.State.HistoryRecord.terminal_angle[Item] = Item.Angle;
			end;
		end;
	end;
	History:add( self.State.HistoryRecord );
	self.State.HistoryRecord = nil;

end;

Tools.Lighting.hideGUI = function ( self )

	-- Hide the GUI if it exists already
	if self.GUI then
		self.GUI.Visible = false;
	end;

end;

Tools.Lighting.Loaded = true;