-- Load the main tool's core environment when it's ready
repeat wait() until (
	_G.BTCoreEnv and
	_G.BTCoreEnv[script.Parent.Parent] and
	_G.BTCoreEnv[script.Parent.Parent].CoreReady
);
setfenv( 1, _G.BTCoreEnv[script.Parent.Parent] );

------------------------------------------
-- Decorate tool
------------------------------------------

-- Create the tool
Tools.Decorate = {};

-- Define the tool's color
Tools.Decorate.Color = BrickColor.new( "Really black" );

-- Keep a container for state data
Tools.Decorate.State = {};

-- Keep a container for temporary connections
Tools.Decorate.Connections = {};

-- Keep a container for platform event connections
Tools.Decorate.Listeners = {};

-- Start adding functionality to the tool
Tools.Decorate.Listeners.Equipped = function ()

	local self = Tools.Decorate;

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
		self.stopGUIUpdater = function ( self )
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

Tools.Decorate.Listeners.Unequipped = function ()

	local self = Tools.Decorate;

	-- Stop the GUI updater
	self:stopGUIUpdater();

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

Tools.Decorate.updateGUI = function ( self )

	-- Make sure the GUI exists
	if not self.GUI then
		return;
	end;

	-- If there are items, display the regular interface
	if #Selection.Items > 0 then
		local smoke = self:getSmoke();
		local fire = self:getFire();
		local sparkles = self:getSparkles();

		-- Get the properties of the decorations
		local smoke_color_r, smoke_color_g, smoke_color_b, smoke_opacity, smoke_velocity, smoke_size;
		local fire_color_r, fire_color_g, fire_color_b, fire_2nd_color_r, fire_2nd_color_g, fire_2nd_color_b, fire_heat, fire_size;
		local sparkles_color_r, sparkles_color_g, sparkles_color_b;

		for smoke_index, Smoke in pairs( smoke ) do
			-- Set the initial values for later comparison
			if smoke_index == 1 then
				smoke_color_r, smoke_color_g, smoke_color_b = Smoke.Color.r, Smoke.Color.g, Smoke.Color.b;
				smoke_opacity = Smoke.Opacity;
				smoke_velocity = Smoke.RiseVelocity;
				smoke_size = Smoke.Size;
			-- Set the values to `nil` if they vary across the selection
			else
				if smoke_color_r ~= Smoke.Color.r then
					smoke_color_r = nil;
				end;
				if smoke_color_g ~= Smoke.Color.g then
					smoke_color_g = nil;
				end;
				if smoke_color_b ~= Smoke.Color.b then
					smoke_color_b = nil;
				end;
				if smoke_opacity ~= Smoke.Opacity then
					smoke_opacity = nil;
				end;
				if smoke_velocity ~= Smoke.RiseVelocity then
					smoke_velocity = nil;
				end;
				if smoke_size ~= Smoke.Size then
					smoke_size = nil;
				end;
			end;
		end;

		for fire_index, Fire in pairs( fire ) do
			if fire_index == 1 then
				fire_color_r, fire_color_g, fire_color_b = Fire.Color.r, Fire.Color.g, Fire.Color.b;
				fire_2nd_color_r, fire_2nd_color_g, fire_2nd_color_b = Fire.SecondaryColor.r, Fire.SecondaryColor.g, Fire.SecondaryColor.b;
				fire_heat = Fire.Heat;
				fire_size = Fire.Size;
			else
				if fire_color_r ~= Fire.Color.r then
					fire_color_r = nil;
				end;
				if fire_color_g ~= Fire.Color.g then
					fire_color_g = nil;
				end;
				if fire_color_b ~= Fire.Color.b then
					fire_color_b = nil;
				end;
				if fire_2nd_color_r ~= Fire.SecondaryColor.r then
					fire_2nd_color_r = nil;
				end;
				if fire_2nd_color_g ~= Fire.SecondaryColor.g then
					fire_2nd_color_g = nil;
				end;
				if fire_2nd_color_b ~= Fire.SecondaryColor.b then
					fire_2nd_color_b = nil;
				end;
				if fire_heat ~= Fire.Heat then
					fire_heat = nil;
				end;
				if fire_size ~= Fire.Size then
					fire_size = nil;
				end;
			end;
		end;

		for sparkles_index, Sparkles in pairs( sparkles ) do
			if sparkles_index == 1 then
				sparkles_color_r, sparkles_color_g, sparkles_color_b = Sparkles.SparkleColor.r, Sparkles.SparkleColor.g, Sparkles.SparkleColor.b;
			else
				if sparkles_color_r ~= Sparkles.SparkleColor.r then
					sparkles_color_r = nil;
				end;
				if sparkles_color_g ~= Sparkles.SparkleColor.g then
					sparkles_color_g = nil;
				end;
				if sparkles_color_b ~= Sparkles.SparkleColor.b then
					sparkles_color_b = nil;
				end;
			end;
		end;

		self.State.smoke_color = ( smoke_color_r and smoke_color_g and smoke_color_b ) and Color3.new( smoke_color_r, smoke_color_g, smoke_color_b ) or nil;
		self.State.fire_color = ( fire_color_r and fire_color_g and fire_color_b ) and Color3.new( fire_color_r, fire_color_g, fire_color_b ) or nil;
		self.State.fire_2nd_color = ( fire_2nd_color_r and fire_2nd_color_g and fire_2nd_color_b ) and Color3.new( fire_2nd_color_r, fire_2nd_color_g, fire_2nd_color_b ) or nil;
		self.State.sparkles_color = ( sparkles_color_r and sparkles_color_g and sparkles_color_b ) and Color3.new( sparkles_color_r, sparkles_color_g, sparkles_color_b ) or nil;

		-- Update the smoke GUI data
		if not self.State.smoke_color_r_focused then
			self.GUI.Smoke.Options.ColorOption.RInput.TextBox.Text = smoke_color_r and _round( smoke_color_r * 255, 0 ) or '*';
		end;
		if not self.State.smoke_color_g_focused then
			self.GUI.Smoke.Options.ColorOption.GInput.TextBox.Text = smoke_color_g and _round( smoke_color_g * 255, 0 ) or '*';
		end;
		if not self.State.smoke_color_b_focused then
			self.GUI.Smoke.Options.ColorOption.BInput.TextBox.Text = smoke_color_b and _round( smoke_color_b * 255, 0 ) or '*';
		end;
		if not self.State.smoke_opacity_focused then
			self.GUI.Smoke.Options.OpacityOption.Input.TextBox.Text = smoke_opacity and _round( smoke_opacity, 2 ) or '*';
		end;
		if not self.State.smoke_velocity_focused then
			self.GUI.Smoke.Options.VelocityOption.Input.TextBox.Text = smoke_velocity and _round( smoke_velocity, 2 ) or '*';
		end;
		if not self.State.smoke_size_focused then
			self.GUI.Smoke.Options.SizeOption.Input.TextBox.Text = smoke_size and _round( smoke_size, 2 ) or '*';
		end;

		-- Update the fire GUI data
		if not self.State.fire_color_r_focused then
			self.GUI.Fire.Options.ColorOption.RInput.TextBox.Text = fire_color_r and _round( fire_color_r * 255, 0 ) or '*';
		end;
		if not self.State.fire_color_g_focused then
			self.GUI.Fire.Options.ColorOption.GInput.TextBox.Text = fire_color_g and _round( fire_color_g * 255, 0 ) or '*';
		end;
		if not self.State.fire_color_b_focused then
			self.GUI.Fire.Options.ColorOption.BInput.TextBox.Text = fire_color_b and _round( fire_color_b * 255, 0 ) or '*';
		end;
		if not self.State.fire_2nd_color_r_focused then
			self.GUI.Fire.Options.SecondColorOption.RInput.TextBox.Text = fire_2nd_color_r and _round( fire_2nd_color_r * 255, 0 ) or '*';
		end;
		if not self.State.fire_2nd_color_g_focused then
			self.GUI.Fire.Options.SecondColorOption.GInput.TextBox.Text = fire_2nd_color_g and _round( fire_2nd_color_g * 255, 0 ) or '*';
		end;
		if not self.State.fire_2nd_color_b_focused then
			self.GUI.Fire.Options.SecondColorOption.BInput.TextBox.Text = fire_2nd_color_b and _round( fire_2nd_color_b * 255, 0 ) or '*';
		end;
		if not self.State.fire_heat_focused then
			self.GUI.Fire.Options.HeatOption.Input.TextBox.Text = fire_heat and _round( fire_heat, 2 ) or '*';
		end;
		if not self.State.fire_size_focused then
			self.GUI.Fire.Options.SizeOption.Input.TextBox.Text = fire_size and _round( fire_size, 2 ) or '*';
		end;

		-- Update the sparkles GUI data
		if not self.State.sparkles_color_r_focused then
			self.GUI.Sparkles.Options.ColorOption.RInput.TextBox.Text = sparkles_color_r and _round( sparkles_color_r * 255, 0 ) or '*';
		end;
		if not self.State.sparkles_color_g_focused then
			self.GUI.Sparkles.Options.ColorOption.GInput.TextBox.Text = sparkles_color_g and _round( sparkles_color_g * 255, 0 ) or '*';
		end;
		if not self.State.sparkles_color_b_focused then
			self.GUI.Sparkles.Options.ColorOption.BInput.TextBox.Text = sparkles_color_b and _round( sparkles_color_b * 255, 0 ) or '*';
		end;

		if self.GUI.SelectNote.Visible then
			self:closeSmoke();
			self:closeFire();
			self:closeSparkles();
		end;
		self.GUI.Smoke.Visible = true;
		self.GUI.Fire.Visible = true;
		self.GUI.Sparkles.Visible = true;
		self.GUI.SelectNote.Visible = false;

		if not self.State.smoke_open and not self.State.fire_open and not self.State.sparkles_open then
			self.GUI:TweenSize( UDim2.new( 0, 200, 0, 125 ), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true );
		end;

		-- If there is no smoke
		if #smoke == 0 then
			self.GUI.Smoke.Options.Size = UDim2.new( 1, -3, 0, 0 );
			self.GUI.Smoke.AddButton.Visible = true;
			self.GUI.Smoke.RemoveButton.Visible = false;
			if self.State.smoke_open then
				self:closeSmoke();
			end;

		-- If only some items have smoke
		elseif #smoke ~= #Selection.Items then
			self.GUI.Smoke.AddButton.Visible = true;
			self.GUI.Smoke.RemoveButton.Position = UDim2.new( 0, 90, 0, 3 );
			self.GUI.Smoke.RemoveButton.Visible = true;

		-- If all items have smoke
		elseif #smoke == #Selection.Items then
			self.GUI.Smoke.AddButton.Visible = false;
			self.GUI.Smoke.RemoveButton.Position = UDim2.new( 0, 127, 0, 3 );
			self.GUI.Smoke.RemoveButton.Visible = true;
			if self.GUI.Smoke.Size == UDim2.new( 0, 200, 0, 52 ) then
				self.GUI.Smoke.Size = UDim2.new( 0, 200, 0, 125 );
			end;
		end;

		-- If there is no fire
		if #fire == 0 then
			self.GUI.Fire.Options.Size = UDim2.new( 1, -3, 0, 0 );
			self.GUI.Fire.AddButton.Visible = true;
			self.GUI.Fire.RemoveButton.Visible = false;
			if self.State.fire_open then
				self:closeFire();
			end;

		-- If only some items have fire
		elseif #fire ~= #Selection.Items then
			self.GUI.Fire.AddButton.Visible = true;
			self.GUI.Fire.RemoveButton.Position = UDim2.new( 0, 90, 0, 3 );
			self.GUI.Fire.RemoveButton.Visible = true;

		-- If all items have fire
		elseif #fire == #Selection.Items then
			self.GUI.Fire.AddButton.Visible = false;
			self.GUI.Fire.RemoveButton.Position = UDim2.new( 0, 127, 0, 3 );
			self.GUI.Fire.RemoveButton.Visible = true;
		end;

		-- If there are no sparkles
		if #sparkles == 0 then
			self.GUI.Sparkles.Options.Size = UDim2.new( 1, -3, 0, 0 );
			self.GUI.Sparkles.AddButton.Visible = true;
			self.GUI.Sparkles.RemoveButton.Visible = false;
			if self.State.sparkles_open then
				self:closeSparkles();
			end;

		-- If only some items have sparkles
		elseif #sparkles ~= #Selection.Items then
			self.GUI.Sparkles.AddButton.Visible = true;
			self.GUI.Sparkles.RemoveButton.Position = UDim2.new( 0, 90, 0, 3 );
			self.GUI.Sparkles.RemoveButton.Visible = true;

		-- If all items have sparkles
		elseif #sparkles == #Selection.Items then
			self.GUI.Sparkles.AddButton.Visible = false;
			self.GUI.Sparkles.RemoveButton.Position = UDim2.new( 0, 127, 0, 3 );
			self.GUI.Sparkles.RemoveButton.Visible = true;
		end;

	-- If nothing is selected, show the select something note
	else
		self.GUI.Smoke.Visible = false;
		self.GUI.Fire.Visible = false;
		self.GUI.Sparkles.Visible = false;
		self.GUI.SelectNote.Visible = true;
		self.GUI.Size = UDim2.new( 0, 200, 0, 52 );
	end;

end;

Tools.Decorate.openSmoke = function ( self )
	self.State.smoke_open = true;
	self:closeFire();
	self:closeSparkles();
	self.GUI.Smoke.Options:TweenSize( UDim2.new( 1, -3, 0, 110 ), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true );
	self.GUI.Smoke:TweenPosition( UDim2.new( 0, 10, 0, 30 ), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true );
	self.GUI:TweenSize( UDim2.new( 0, 200, 0, 235 ), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true );
end;

Tools.Decorate.openFire = function ( self )
	self.State.fire_open = true;
	self:closeSmoke();
	self:closeSparkles();
	self.GUI.Fire.Options:TweenSize( UDim2.new( 1, -3, 0, 110 ), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true );
	self.GUI.Fire:TweenPosition( UDim2.new( 0, 10, 0, 60 ), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true );
	self.GUI:TweenSize( UDim2.new( 0, 200, 0, 235 ), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true );
end;

Tools.Decorate.openSparkles = function ( self )
	self.State.sparkles_open = true;
	self:closeSmoke();
	self:closeFire();
	self.GUI.Sparkles.Options:TweenSize( UDim2.new( 1, -3, 0, 40 ), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true );
	self.GUI.Sparkles:TweenPosition( UDim2.new( 0, 10, 0, 90 ), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true );
	self.GUI:TweenSize( UDim2.new( 0, 200, 0, 160 ), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true );
end;

Tools.Decorate.closeSmoke = function ( self )
	self.State.smoke_open = false;
	self.GUI.Smoke.Options:TweenSize( UDim2.new( 1, -3, 0, 0 ), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true );
	self.GUI.Fire:TweenPosition( UDim2.new( 0, 10, 0, 60 ), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true );
	if not self.State.fire_open then
		self.GUI.Sparkles:TweenPosition( UDim2.new( 0, 10, 0, 90 ), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true );
	end;
	if not self.State.fire_open and not self.State.sparkles_open then
		self.GUI:TweenSize( UDim2.new( 0, 200, 0, 125 ), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true );
	end;
end;

Tools.Decorate.closeFire = function ( self )
	self.State.fire_open = false;
	if self.State.smoke_open then
		self.GUI.Fire:TweenPosition( UDim2.new( 0, 10, 0, 170 ), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true );
	else
		self.GUI.Fire:TweenPosition( UDim2.new( 0, 10, 0, 60 ), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true );
	end;
	self.GUI.Fire.Options:TweenSize( UDim2.new( 1, -3, 0, 0 ), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true );
	if not self.State.smoke_open then
		self.GUI.Sparkles:TweenPosition( UDim2.new( 0, 10, 0, 90 ), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true );
	end;
	if not self.State.smoke_open and not self.State.sparkles_open then
		self.GUI:TweenSize( UDim2.new( 0, 200, 0, 125 ), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true );
	end;
end;

Tools.Decorate.closeSparkles = function ( self )
	self.State.sparkles_open = false;
	if self.State.smoke_open or self.State.fire_open then
		self.GUI.Sparkles:TweenPosition( UDim2.new( 0, 10, 0, 200 ), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true );
	else
		self.GUI.Sparkles:TweenPosition( UDim2.new( 0, 10, 0, 90 ), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true );
	end;
	self.GUI.Sparkles.Options:TweenSize( UDim2.new( 1, -3, 0, 0 ), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true );
	if not self.State.smoke_open and not self.State.fire_open then
		self.GUI:TweenSize( UDim2.new( 0, 200, 0, 125 ), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true );
	end;
end;

Tools.Decorate.showGUI = function ( self )

	-- Initialize the GUI if it's not ready yet
	if not self.GUI then
		local Container = Tool.Interfaces.BTDecorateToolGUI:Clone();
		Container.Parent = UI;

		Container.Smoke.ArrowButton.MouseButton1Up:connect( function ()
			if not self.State.smoke_open and #self:getSmoke() > 0 then
				self:openSmoke();
			else
				self:closeSmoke();
			end;
		end );
		Container.Fire.ArrowButton.MouseButton1Up:connect( function ()
			if not self.State.fire_open and #self:getFire() > 0 then
				self:openFire();
			else
				self:closeFire();
			end;
		end );
		Container.Sparkles.ArrowButton.MouseButton1Up:connect( function ()
			if not self.State.sparkles_open and #self:getSparkles() > 0 then
				self:openSparkles();
			else
				self:closeSparkles();
			end;
		end );

		Container.Smoke.AddButton.MouseButton1Up:connect( function ()
			self:addSmoke();
			self:openSmoke();
		end );
		Container.Fire.AddButton.MouseButton1Up:connect( function ()
			self:addFire();
			self:openFire();
		end );
		Container.Sparkles.AddButton.MouseButton1Up:connect( function ()
			self:addSparkles();
			self:openSparkles();
		end );
		Container.Smoke.RemoveButton.MouseButton1Up:connect( function ()
			self:removeSmoke()
			self:closeSmoke();
		end );
		Container.Fire.RemoveButton.MouseButton1Up:connect( function ()
			self:removeFire();
			self:closeFire();
		end );
		Container.Sparkles.RemoveButton.MouseButton1Up:connect( function ()
			self:removeSparkles();
			self:closeSparkles();
		end );

		-- Add functionality to smoke inputs
		local SmokeUI = Container.Smoke;

		local SmokeColor = SmokeUI.Options.ColorOption;
		SmokeColor.RInput.TextButton.MouseButton1Down:connect( function ()
			self.State.smoke_color_r_focused = true;
			SmokeColor.RInput.TextBox:CaptureFocus();
		end );
		SmokeColor.RInput.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( SmokeColor.RInput.TextBox.Text );
			if potential_new then
				if potential_new > 255 then
					potential_new = 255;
				elseif potential_new < 0 then
					potential_new = 0;
				end;
				self:changeSmokeColor( 'r', potential_new / 255 );
			end;
			self.State.smoke_color_r_focused = false;
		end );
		SmokeColor.GInput.TextButton.MouseButton1Down:connect( function ()
			self.State.smoke_color_g_focused = true;
			SmokeColor.GInput.TextBox:CaptureFocus();
		end );
		SmokeColor.GInput.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( SmokeColor.GInput.TextBox.Text );
			if potential_new then
				if potential_new > 255 then
					potential_new = 255;
				elseif potential_new < 0 then
					potential_new = 0;
				end;
				self:changeSmokeColor( 'g', potential_new / 255 );
			end;
			self.State.smoke_color_g_focused = false;
		end );
		SmokeColor.BInput.TextButton.MouseButton1Down:connect( function ()
			self.State.smoke_color_b_focused = true;
			SmokeColor.BInput.TextBox:CaptureFocus();
		end );
		SmokeColor.BInput.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( SmokeColor.BInput.TextBox.Text );
			if potential_new then
				if potential_new > 255 then
					potential_new = 255;
				elseif potential_new < 0 then
					potential_new = 0;
				end;
				self:changeSmokeColor( 'b', potential_new / 255 );
			end;
			self.State.smoke_color_b_focused = false;
		end );

		SmokeColor.HSVPicker.MouseButton1Up:connect( function ()
			ColorPicker:start( function ( ... )
				local args = { ... };
				-- If a color was picked, change the smoke's color
				-- to the selected color
				if #args == 3 then
					self:changeSmokeColor( _HSVToRGB( ... ) );
				end;
			end, self.State.smoke_color );
		end );

		local SmokeOpacity = SmokeUI.Options.OpacityOption.Input;
		SmokeOpacity.TextButton.MouseButton1Down:connect( function ()
			self.State.smoke_opacity_focused = true;
			SmokeOpacity.TextBox:CaptureFocus();
		end );
		SmokeOpacity.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( SmokeOpacity.TextBox.Text );
			if potential_new then
				if potential_new > 1 then
					potential_new = 1;
				elseif potential_new < 0 then
					potential_new = 0;
				end;
				self:changeSmokeOpacity( potential_new );
			end;
			self.State.smoke_opacity_focused = false;
		end );

		local SmokeVelocity = SmokeUI.Options.VelocityOption.Input;
		SmokeVelocity.TextButton.MouseButton1Down:connect( function ()
			self.State.smoke_velocity_focused = true;
			SmokeVelocity.TextBox:CaptureFocus();
		end );
		SmokeVelocity.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( SmokeVelocity.TextBox.Text );
			if potential_new then
				if potential_new > 25 then
					potential_new = 25;
				elseif potential_new < -25 then
					potential_new = -25;
				end;
				self:changeSmokeVelocity( potential_new );
			end;
			self.State.smoke_velocity_focused = false;
		end );

		local SmokeSize = SmokeUI.Options.SizeOption.Input;
		SmokeSize.TextButton.MouseButton1Down:connect( function ()
			self.State.smoke_size_focused = true;
			SmokeSize.TextBox:CaptureFocus();
		end );
		SmokeSize.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( SmokeSize.TextBox.Text );
			if potential_new then
				if potential_new > 100 then
					potential_new = 100;
				elseif potential_new < 0.1 then
					potential_new = 0.1;
				end;
				self:changeSmokeSize( potential_new );
			end;
			self.State.smoke_size_focused = false;
		end );

		-- Add functionality to fire inputs
		local FireUI = Container.Fire;

		local FireColor = FireUI.Options.ColorOption;
		FireColor.RInput.TextButton.MouseButton1Down:connect( function ()
			self.State.fire_color_r_focused = true;
			FireColor.RInput.TextBox:CaptureFocus();
		end );
		FireColor.RInput.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( FireColor.RInput.TextBox.Text );
			if potential_new then
				if potential_new > 255 then
					potential_new = 255;
				elseif potential_new < 0 then
					potential_new = 0;
				end;
				self:changeFireColor( 'r', potential_new / 255 );
			end;
			self.State.fire_color_r_focused = false;
		end );
		FireColor.GInput.TextButton.MouseButton1Down:connect( function ()
			self.State.fire_color_g_focused = true;
			FireColor.GInput.TextBox:CaptureFocus();
		end );
		FireColor.GInput.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( FireColor.GInput.TextBox.Text );
			if potential_new then
				if potential_new > 255 then
					potential_new = 255;
				elseif potential_new < 0 then
					potential_new = 0;
				end;
				self:changeFireColor( 'g', potential_new / 255 );
			end;
			self.State.fire_color_g_focused = false;
		end );
		FireColor.BInput.TextButton.MouseButton1Down:connect( function ()
			self.State.fire_color_b_focused = true;
			FireColor.BInput.TextBox:CaptureFocus();
		end );
		FireColor.BInput.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( FireColor.BInput.TextBox.Text );
			if potential_new then
				if potential_new > 255 then
					potential_new = 255;
				elseif potential_new < 0 then
					potential_new = 0;
				end;
				self:changeFireColor( 'b', potential_new / 255 );
			end;
			self.State.fire_color_b_focused = false;
		end );
		FireColor.HSVPicker.MouseButton1Up:connect( function ()
			ColorPicker:start( function ( ... )
				local args = { ... };
				-- If a color was picked, change the fire's color
				-- to the selected color
				if #args == 3 then
					self:changeFireColor( _HSVToRGB( ... ) );
				end;
			end, self.State.fire_color );
		end );

		local FireColor2 = FireUI.Options.SecondColorOption;
		FireColor2.RInput.TextButton.MouseButton1Down:connect( function ()
			self.State.fire_2nd_color_r_focused = true;
			FireColor2.RInput.TextBox:CaptureFocus();
		end );
		FireColor2.RInput.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( FireColor2.RInput.TextBox.Text );
			if potential_new then
				if potential_new > 255 then
					potential_new = 255;
				elseif potential_new < 0 then
					potential_new = 0;
				end;
				self:changeFireColor2( 'r', potential_new / 255 );
			end;
			self.State.fire_2nd_color_r_focused = false;
		end );
		FireColor2.GInput.TextButton.MouseButton1Down:connect( function ()
			self.State.fire_2nd_color_g_focused = true;
			FireColor2.GInput.TextBox:CaptureFocus();
		end );
		FireColor2.GInput.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( FireColor2.GInput.TextBox.Text );
			if potential_new then
				if potential_new > 255 then
					potential_new = 255;
				elseif potential_new < 0 then
					potential_new = 0;
				end;
				self:changeFireColor2( 'g', potential_new / 255 );
			end;
			self.State.fire_2nd_color_g_focused = false;
		end );
		FireColor2.BInput.TextButton.MouseButton1Down:connect( function ()
			self.State.fire_2nd_color_b_focused = true;
			FireColor2.BInput.TextBox:CaptureFocus();
		end );
		FireColor2.BInput.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( FireColor2.BInput.TextBox.Text );
			if potential_new then
				if potential_new > 255 then
					potential_new = 255;
				elseif potential_new < 0 then
					potential_new = 0;
				end;
				self:changeFireColor2( 'b', potential_new / 255 );
			end;
			self.State.fire_2nd_color_b_focused = false;
		end );
		FireColor2.HSVPicker.MouseButton1Up:connect( function ()
			ColorPicker:start( function ( ... )
				local args = { ... };
				-- If a color was picked, change the fire's secondary color
				-- to the selected color
				if #args == 3 then
					self:changeFireColor2( _HSVToRGB( ... ) );
				end;
			end, self.State.fire_2nd_color );
		end );

		local FireHeat = FireUI.Options.HeatOption.Input;
		FireHeat.TextButton.MouseButton1Down:connect( function ()
			self.State.fire_heat_focused = true;
			FireHeat.TextBox:CaptureFocus();
		end );
		FireHeat.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( FireHeat.TextBox.Text );
			if potential_new then
				if potential_new > 25 then
					potential_new = 25;
				elseif potential_new < -25 then
					potential_new = -25;
				end;
				self:changeFireHeat( potential_new );
			end;
			self.State.fire_heat_focused = false;
		end );

		local FireSize = FireUI.Options.SizeOption.Input;
		FireSize.TextButton.MouseButton1Down:connect( function ()
			self.State.fire_size_focused = true;
			FireSize.TextBox:CaptureFocus();
		end );
		FireSize.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( FireSize.TextBox.Text );
			if potential_new then
				if potential_new > 30 then
					potential_new = 30;
				elseif potential_new < 2 then
					potential_new = 2;
				end;
				self:changeFireSize( potential_new );
			end;
			self.State.fire_size_focused = false;
		end );

		-- Add functionality to sparkles inputs
		local SparklesUI = Container.Sparkles;

		local SparklesColor = SparklesUI.Options.ColorOption;
		SparklesColor.RInput.TextButton.MouseButton1Down:connect( function ()
			self.State.sparkles_color_r_focused = true;
			SparklesColor.RInput.TextBox:CaptureFocus();
		end );
		SparklesColor.RInput.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( SparklesColor.RInput.TextBox.Text );
			if potential_new then
				if potential_new > 255 then
					potential_new = 255;
				elseif potential_new < 0 then
					potential_new = 0;
				end;
				self:changeSparklesColor( 'r', potential_new / 255 );
			end;
			self.State.sparkles_color_r_focused = false;
		end );
		SparklesColor.GInput.TextButton.MouseButton1Down:connect( function ()
			self.State.sparkles_color_g_focused = true;
			SparklesColor.GInput.TextBox:CaptureFocus();
		end );
		SparklesColor.GInput.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( SparklesColor.GInput.TextBox.Text );
			if potential_new then
				if potential_new > 255 then
					potential_new = 255;
				elseif potential_new < 0 then
					potential_new = 0;
				end;
				self:changeSparklesColor( 'g', potential_new / 255 );
			end;
			self.State.sparkles_color_g_focused = false;
		end );
		SparklesColor.BInput.TextButton.MouseButton1Down:connect( function ()
			self.State.sparkles_color_b_focused = true;
			SparklesColor.BInput.TextBox:CaptureFocus();
		end );
		SparklesColor.BInput.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( SparklesColor.BInput.TextBox.Text );
			if potential_new then
				if potential_new > 255 then
					potential_new = 255;
				elseif potential_new < 0 then
					potential_new = 0;
				end;
				self:changeSparklesColor( 'b', potential_new / 255 );
			end;
			self.State.sparkles_color_b_focused = false;
		end );
		SparklesColor.HSVPicker.MouseButton1Up:connect( function ()
			ColorPicker:start( function ( ... )
				local args = { ... };
				-- If a color was picked, change the sparkles' color
				-- to the selected color
				if #args == 3 then
					self:changeSparklesColor( _HSVToRGB( ... ) );
				end;
			end, self.State.sparkles_color );
		end );

		self.GUI = Container;
	end;

	-- Reveal the GUI
	self.GUI.Visible = true;

end;

Tools.Decorate.changeSmokeOpacity = function ( self, new_opacity )

	local smoke = self:getSmoke();

	self:startHistoryRecord( smoke );
	for _, Smoke in pairs( smoke ) do
		Smoke.Opacity = new_opacity;
	end;
	self:finishHistoryRecord();

end;

Tools.Decorate.changeSmokeVelocity = function ( self, new_velocity )

	local smoke = self:getSmoke();

	self:startHistoryRecord( smoke );
	for _, Smoke in pairs( smoke ) do
		Smoke.RiseVelocity = new_velocity;
	end;
	self:finishHistoryRecord();

end;

Tools.Decorate.changeSmokeSize = function ( self, new_size )

	local smoke = self:getSmoke();

	self:startHistoryRecord( smoke );
	for _, Smoke in pairs( smoke ) do
		Smoke.Size = new_size;
	end;
	self:finishHistoryRecord();

end;

Tools.Decorate.changeFireHeat = function ( self, new_velocity )

	local fire = self:getFire();

	self:startHistoryRecord( fire );
	for _, Fire in pairs( fire ) do
		Fire.Heat = new_velocity;
	end;
	self:finishHistoryRecord();

end;

Tools.Decorate.changeFireSize = function ( self, new_size )

	local fire = self:getFire();

	self:startHistoryRecord( fire );
	for _, Fire in pairs( fire ) do
		Fire.Size = new_size;
	end;
	self:finishHistoryRecord();

end;

Tools.Decorate.getSmoke = function ( self )
	-- Returns a list of all the relevant smoke in the selection items

	local smoke = {};

	for _, Item in pairs( Selection.Items ) do
		local Smoke = _getChildOfClass( Item, 'Smoke' );
		if Smoke then
			table.insert( smoke, Smoke );
		end;
	end;

	return smoke;

end;

Tools.Decorate.getFire = function ( self )
	-- Returns a list of all the relevant fire in the selection items

	local fire = {};

	for _, Item in pairs( Selection.Items ) do
		local Fire = _getChildOfClass( Item, 'Fire' );
		if Fire then
			table.insert( fire, Fire );
		end;
	end;

	return fire;

end;

Tools.Decorate.getSparkles = function ( self )
	-- Returns a list of all the relevant sparkles in the selection items

	local sparkles = {};

	for _, Item in pairs( Selection.Items ) do
		local Sparkles = _getChildOfClass( Item, 'Sparkles' );
		if Sparkles then
			table.insert( sparkles, Sparkles );
		end;
	end;

	return sparkles;

end;

Tools.Decorate.changeSmokeColor = function ( self, ... )

	local args = { ... };
	local targets = self:getSmoke();

	self:startHistoryRecord( targets );

	-- If only one component is being changed at a time
	if #args == 2 then
		local component = args[1];
		local component_value = args[2];

		for _, Smoke in pairs( targets ) do
			Smoke.Color = Color3.new(
				component == 'r' and component_value or Smoke.Color.r,
				component == 'g' and component_value or Smoke.Color.g,
				component == 'b' and component_value or Smoke.Color.b
			);
		end;

	-- If all 3 components of the color are being changed
	elseif #args == 3 then
		local r, g, b = ...;

		for _, Smoke in pairs( targets ) do
			Smoke.Color = Color3.new( r, g, b );
		end;
	end;

	self:finishHistoryRecord();
end;

Tools.Decorate.changeFireColor = function ( self, ... )

	local args = { ... };
	local targets = self:getFire();

	self:startHistoryRecord( targets );

	-- If only one component is being changed at a time
	if #args == 2 then
		local component = args[1];
		local component_value = args[2];

		for _, Fire in pairs( targets ) do
			Fire.Color = Color3.new(
				component == 'r' and component_value or Fire.Color.r,
				component == 'g' and component_value or Fire.Color.g,
				component == 'b' and component_value or Fire.Color.b
			);
		end;

	-- If all 3 components of the color are being changed
	elseif #args == 3 then
		local r, g, b = ...;

		for _, Fire in pairs( targets ) do
			Fire.Color = Color3.new( r, g, b );
		end;
	end;

	self:finishHistoryRecord();
end;

Tools.Decorate.changeFireColor2 = function ( self, ... )

	local args = { ... };
	local targets = self:getFire();

	self:startHistoryRecord( targets );

	-- If only one component is being changed at a time
	if #args == 2 then
		local component = args[1];
		local component_value = args[2];

		for _, Fire in pairs( targets ) do
			Fire.SecondaryColor = Color3.new(
				component == 'r' and component_value or Fire.Color.r,
				component == 'g' and component_value or Fire.Color.g,
				component == 'b' and component_value or Fire.Color.b
			);
		end;

	-- If all 3 components of the color are being changed
	elseif #args == 3 then
		local r, g, b = ...;

		for _, Fire in pairs( targets ) do
			Fire.SecondaryColor = Color3.new( r, g, b );
		end;
	end;

	self:finishHistoryRecord();
end;

Tools.Decorate.changeSparklesColor = function ( self, ... )

	local args = { ... };
	local targets = self:getSparkles();

	self:startHistoryRecord( targets );

	-- If only one component is being changed at a time
	if #args == 2 then
		local component = args[1];
		local component_value = args[2];

		for _, Sparkles in pairs( targets ) do
			Sparkles.SparkleColor = Color3.new(
				component == 'r' and component_value or Sparkles.SparkleColor.r,
				component == 'g' and component_value or Sparkles.SparkleColor.g,
				component == 'b' and component_value or Sparkles.SparkleColor.b
			);
		end;

	-- If all 3 components of the color are being changed
	elseif #args == 3 then
		local r, g, b = ...;

		for _, Sparkles in pairs( targets ) do
			Sparkles.SparkleColor = Color3.new( r, g, b );
		end;
	end;

	self:finishHistoryRecord();
end;

Tools.Decorate.addSmoke = function ( self )

	local HistoryRecord = {
		apply = function ( self )
			Selection:clear();
			for _, Smoke in pairs( self.smoke ) do
				Smoke.Parent = self.smoke_parents[Smoke];
				Selection:add( Smoke.Parent );
			end;
		end;
		unapply = function ( self )
			Selection:clear();
			for _, Smoke in pairs( self.smoke ) do
				Selection:add( Smoke.Parent );
				Smoke.Parent = nil;
			end;
		end;
	};

	-- Add smoke to all the items from the selection that
	-- don't already have smoke
	local smoke = {};
	local smoke_parents = {};
	for _, Item in pairs( Selection.Items ) do
		local Smoke = _getChildOfClass( Item, 'Smoke' );
		if not Smoke then
			local Smoke = RbxUtility.Create( 'Smoke' ) {
				Parent = Item;
			};
			table.insert( smoke, Smoke );
			smoke_parents[Smoke] = Item;
		end;
	end;

	HistoryRecord.smoke = smoke;
	HistoryRecord.smoke_parents = smoke_parents;
	History:add( HistoryRecord );

end;

Tools.Decorate.removeSmoke = function ( self )

	local HistoryRecord = {
		apply = function ( self )
			Selection:clear();
			for _, Smoke in pairs( self.smoke ) do
				Selection:add( Smoke.Parent );
				Smoke.Parent = nil;
			end;
		end;
		unapply = function ( self )
			Selection:clear();
			for _, Smoke in pairs( self.smoke ) do
				Smoke.Parent = self.smoke_parents[Smoke];
				Selection:add( Smoke.Parent );
			end;
		end;
	};

	local smoke = self:getSmoke();
	local smoke_parents = {};

	-- Remove smoke from all the selected items
	for _, Smoke in pairs( smoke ) do
		smoke_parents[Smoke] = Smoke.Parent;
		Smoke.Parent = nil;
	end;

	HistoryRecord.smoke = smoke;
	HistoryRecord.smoke_parents = smoke_parents;
	History:add( HistoryRecord );

end;

Tools.Decorate.addFire = function ( self )

	local HistoryRecord = {
		apply = function ( self )
			Selection:clear();
			for _, Fire in pairs( self.fire ) do
				Fire.Parent = self.fire_parents[Fire];
				Selection:add( Fire.Parent );
			end;
		end;
		unapply = function ( self )
			Selection:clear();
			for _, Fire in pairs( self.fire ) do
				Selection:add( Fire.Parent );
				Fire.Parent = nil;
			end;
		end;
	};

	-- Add fire to all the items from the selection that
	-- don't already have fire
	local fire = {};
	local fire_parents = {};
	for _, Item in pairs( Selection.Items ) do
		local Fire = _getChildOfClass( Item, 'Fire' );
		if not Fire then
			local Fire = RbxUtility.Create( 'Fire' ) {
				Parent = Item;
			};
			table.insert( fire, Fire );
			fire_parents[Fire] = Item;
		end;
	end;

	HistoryRecord.fire = fire;
	HistoryRecord.fire_parents = fire_parents;
	History:add( HistoryRecord );

end;

Tools.Decorate.removeFire = function ( self )

	local HistoryRecord = {
		apply = function ( self )
			Selection:clear();
			for _, Fire in pairs( self.fire ) do
				Selection:add( Fire.Parent );
				Fire.Parent = nil;
			end;
		end;
		unapply = function ( self )
			Selection:clear();
			for _, Fire in pairs( self.fire ) do
				Fire.Parent = self.fire_parents[Fire];
				Selection:add( Fire.Parent );
			end;
		end;
	};

	local fire = self:getFire();
	local fire_parents = {};

	-- Remove fire from all the selected items
	for _, Fire in pairs( fire ) do
		fire_parents[Fire] = Fire.Parent;
		Fire.Parent = nil;
	end;

	HistoryRecord.fire = fire;
	HistoryRecord.fire_parents = fire_parents;
	History:add( HistoryRecord );

end;

Tools.Decorate.addSparkles = function ( self )

	local HistoryRecord = {
		apply = function ( self )
			Selection:clear();
			for _, Sparkles in pairs( self.sparkles ) do
				Sparkles.Parent = self.sparkles_parents[Sparkles];
				Selection:add( Sparkles.Parent );
			end;
		end;
		unapply = function ( self )
			Selection:clear();
			for _, Sparkles in pairs( self.sparkles ) do
				Selection:add( Sparkles.Parent );
				Sparkles.Parent = nil;
			end;
		end;
	};

	-- Add sparkles to all the items from the selection that
	-- don't already have sparkles
	local sparkles = {};
	local sparkles_parents = {};
	for _, Item in pairs( Selection.Items ) do
		local Sparkles = _getChildOfClass( Item, 'Sparkles' );
		if not Sparkles then
			local Sparkles = RbxUtility.Create( 'Sparkles' ) {
				Parent = Item;
				SparkleColor = Color3.new( 1, 0, 0 );
			};
			table.insert( sparkles, Sparkles );
			sparkles_parents[Sparkles] = Item;
		end;
	end;

	HistoryRecord.sparkles = sparkles;
	HistoryRecord.sparkles_parents = sparkles_parents;
	History:add( HistoryRecord );

end;

Tools.Decorate.removeSparkles = function ( self )

	local HistoryRecord = {
		apply = function ( self )
			Selection:clear();
			for _, Sparkles in pairs( self.sparkles ) do
				Selection:add( Sparkles.Parent );
				Sparkles.Parent = nil;
			end;
		end;
		unapply = function ( self )
			Selection:clear();
			for _, Sparkles in pairs( self.sparkles ) do
				Sparkles.Parent = self.sparkles_parents[Sparkles];
				Selection:add( Sparkles.Parent );
			end;
		end;
	};

	local sparkles = self:getSparkles();
	local sparkles_parents = {};

	-- Remove fire from all the selected items
	for _, Sparkles in pairs( sparkles ) do
		sparkles_parents[Sparkles] = Sparkles.Parent;
		Sparkles.Parent = nil;
	end;

	HistoryRecord.sparkles = sparkles;
	HistoryRecord.sparkles_parents = sparkles_parents;
	History:add( HistoryRecord );

end;

Tools.Decorate.startHistoryRecord = function ( self, decorations )

	if self.State.HistoryRecord then
		self.State.HistoryRecord = nil;
	end;

	-- Create a history record
	self.State.HistoryRecord = {
		targets = _cloneTable( decorations );
		initial_color = {};			terminal_color = {};
		initial_2nd_color = {};		terminal_2nd_color = {};
		initial_opacity = {};		terminal_opacity = {};
		initial_velocity = {};		terminal_velocity = {};
		initial_size = {};			terminal_size = {};
		initial_heat = {};			terminal_heat = {};
		unapply = function ( self )
			Selection:clear();
			for _, Target in pairs( self.targets ) do
				if Target then
					Selection:add( Target.Parent );
					if Target:IsA( 'Sparkles' ) then
						Target.SparkleColor = self.initial_color[Target];
					else
						Target.Color = self.initial_color[Target];
						Target.Size = self.initial_size[Target];
					end;
					if Target:IsA( 'Smoke' ) then
						Target.Opacity = self.initial_opacity[Target];
						Target.RiseVelocity = self.initial_velocity[Target];
					end;
					if Target:IsA( 'Fire' ) then
						Target.SecondaryColor = self.initial_2nd_color[Target];
						Target.Heat = self.initial_heat[Target];
					end;
				end;
			end;
		end;
		apply = function ( self )
			Selection:clear();
			for _, Target in pairs( self.targets ) do
				if Target then
					Selection:add( Target.Parent );
					if Target:IsA( 'Sparkles' ) then
						Target.SparkleColor = self.terminal_color[Target];
					else
						Target.Color = self.terminal_color[Target];
						Target.Size = self.terminal_size[Target];
					end;
					if Target:IsA( 'Smoke' ) then
						Target.Opacity = self.terminal_opacity[Target];
						Target.RiseVelocity = self.terminal_velocity[Target];
					end;
					if Target:IsA( 'Fire' ) then
						Target.SecondaryColor = self.terminal_2nd_color[Target];
						Target.Heat = self.terminal_heat[Target];
					end;
				end;
			end;
		end;
	};
	for _, Item in pairs( self.State.HistoryRecord.targets ) do
		if Item then
			if Item:IsA( 'Sparkles' ) then
				self.State.HistoryRecord.initial_color[Item] = Item.SparkleColor;
			else
				self.State.HistoryRecord.initial_color[Item] = Item.Color;
				self.State.HistoryRecord.initial_size[Item] = Item.Size;
			end;
			if Item:IsA( 'Smoke' ) then
				self.State.HistoryRecord.initial_opacity[Item] = Item.Opacity;
				self.State.HistoryRecord.initial_velocity[Item] = Item.RiseVelocity;
			end;
			if Item:IsA( 'Fire' ) then
				self.State.HistoryRecord.initial_2nd_color[Item] = Item.SecondaryColor;
				self.State.HistoryRecord.initial_heat[Item] = Item.Heat;
			end;
		end;
	end;

end;

Tools.Decorate.finishHistoryRecord = function ( self )

	if not self.State.HistoryRecord then
		return;
	end;

	for _, Item in pairs( self.State.HistoryRecord.targets ) do
		if Item then
			if Item:IsA( 'Sparkles' ) then
				self.State.HistoryRecord.terminal_color[Item] = Item.SparkleColor;
			else
				self.State.HistoryRecord.terminal_color[Item] = Item.Color;
				self.State.HistoryRecord.terminal_size[Item] = Item.Size;
			end;
			if Item:IsA( 'Smoke' ) then
				self.State.HistoryRecord.terminal_opacity[Item] = Item.Opacity;
				self.State.HistoryRecord.terminal_velocity[Item] = Item.RiseVelocity;
			end;
			if Item:IsA( 'Fire' ) then
				self.State.HistoryRecord.terminal_2nd_color[Item] = Item.SecondaryColor;
				self.State.HistoryRecord.terminal_heat[Item] = Item.Heat;
			end;
		end;
	end;
	History:add( self.State.HistoryRecord );
	self.State.HistoryRecord = nil;

end;

Tools.Decorate.hideGUI = function ( self )

	-- Hide the GUI if it exists already
	if self.GUI then
		self.GUI.Visible = false;
	end;

end;

Tools.Decorate.Loaded = true;