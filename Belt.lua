-- ROBLOX Object Properties =========
-- [Name] Building Tools by F3X
-- [ClassName] LocalScript
-- [Parent] Building Tools
-- ==================================

------------------------------------------
-- Create references to important objects
------------------------------------------
Services = {
	["Workspace"] = game:GetService( "Workspace" );
	["Players"] = game:GetService( "Players" );
	["Lighting"] = game:GetService( "Lighting" );
	["Teams"] = game:GetService( "Teams" );
	["Debris"] = game:GetService( "Debris" );
	["MarketplaceService"] = game:GetService( "MarketplaceService" );
	["JointsService"] = game.JointsService;
	["BadgeService"] = game:GetService( "BadgeService" );
	["RunService"] = game:GetService( "RunService" );
	["ContentProvider"] = game:GetService( "ContentProvider" );
	["TeleportService"] = game:GetService( "TeleportService" );
	["SoundService"] = game:GetService( "SoundService" );
	["InsertService"] = game:GetService( "InsertService" );
	["CollectionService"] = game:GetService( "CollectionService" );
	["UserInputService"] = game:GetService( "UserInputService" );
	["GamePassService"] = game:GetService( "GamePassService" );
	["StarterPack"] = game:GetService( "StarterPack" );
	["StarterGui"] = game:GetService( "StarterGui" );
};

Tool = script.Parent;
Player = Services.Players.LocalPlayer;

------------------------------------------
-- Define functions that are depended-upon
------------------------------------------
function _findTableOccurrences( haystack, needle )
	-- Returns the positions of instances of `needle` in table `haystack`
	local positions = {};

	-- Add any indexes from `haystack` that have `needle`
	for index, value in pairs( haystack ) do
		if value == needle then
			table.insert( positions, index );
		end;
	end;

	return positions;
end;

------------------------------------------
-- Create data containers
------------------------------------------
ActiveKeys = {};

Options = setmetatable( {

	["_options"] = {
		["Tool"] = nil
	}

}, {

	__newindex = function ( self, key, value )

		-- Do different special things depending on `key`
		if key == "Tool" then

			-- If it's a different tool than the current one
			if self.Tool ~= value then

				-- Run (if existent) the old tool's `Unequipped` listener
				if Options.Tool and Options.Tool.Listeners.Unequipped then
					Options.Tool.Listeners.Unequipped();
				end;

				rawget( self, "_options" ).Tool = nil;

				-- Replace the current handle with `value.Handle`
				local Handle = Tool:FindFirstChild( "Handle" );
				if Handle then
					Handle.Parent = nil;
				end;
				value.Handle.Parent = Tool;

				-- Adjust the grip for the new handle
				Tool.Grip = value.Grip;

				-- Run (if existent) the new tool's `Equipped` listener
				if value.Listeners.Equipped then
					value.Listeners.Equipped();
				end;

			end;
		end;

		-- Set the value normally to `self._options`
		rawget( self, "_options" )[key] = value;

	end;

	-- Get any options from `self._options` instead of `self` directly
	__index = function ( self, key )
		return rawget( self, "_options" )[key];
	end;

} );

-- Keep some state data
clicking = false;
selecting = false;
click_x, click_y = 0, 0;

SelectionBoxes = {};

Selection = {

	["Items"] = {};

	-- Provide a method to add items to the selection
	["add"] = function ( self, NewPart )

		-- Make sure `NewPart` isn't already in the selection
		if #_findTableOccurrences( self.Items, NewPart ) > 0 then
			return false;
		end;

		-- Insert it into the selection
		table.insert( self.Items, NewPart );

		-- Add its SelectionBox
		SelectionBoxes[NewPart] = Instance.new( "SelectionBox", Player.PlayerGui );
		SelectionBoxes[NewPart].Name = "BTSelectionBox";
		SelectionBoxes[NewPart].Color = BrickColor.new( "Cyan" );
		SelectionBoxes[NewPart].Adornee = NewPart;

	end;

	-- Provide a method to remove items from the selection
	["remove"] = function ( self, Item )

		-- Look for `Item` in the selection
		local Item = _findTableOccurrences( self.Items, Item );

		-- Make sure selection item `index` exists
		if #Item == 0 then
			return false;
		end

		-- Store the index of the item and get the actual item
		local index = Item[1];
		Item = self.Items[index];

		-- Remove `Item`'s SelectionBox
		local SelectionBox = SelectionBoxes[Item];
		if SelectionBox then
			SelectionBox:Destroy();
		end;
		SelectionBoxes[Item] = nil;

		-- Delete the item from the selection
		self.Items[index] = nil;

	end;

	-- Provide a method to clear the selection
	["clear"] = function ( self )

		-- Go through all the items in the selection and call `self.remove` on them
		for index, Item in pairs( self.Items ) do
			self:remove( Item );
		end;

	end;

};

Tools = {};

------------------------------------------
-- Default tool
------------------------------------------

-- Create the main container for this tool
Tools.Default = {};

-- Keep a container for the tool's listeners
Tools.Default.Listeners = {};

-- Create the handle
Tools.Default.Handle = Instance.new( "Part" );
Tools.Default.Handle.Name = "Handle";
Tools.Default.Handle.CanCollide = false;

Instance.new( "SpecialMesh", Tools.Default.Handle ).Name = "Mesh";
Tools.Default.Handle.Mesh.MeshId = "http://www.roblox.com/asset/?id=16884681";
Tools.Default.Handle.Mesh.MeshType = Enum.MeshType.FileMesh;
Tools.Default.Handle.Mesh.Scale = Vector3.new( 0.6, 0.6, 0.6 );
Tools.Default.Handle.Mesh.TextureId = "http://www.roblox.com/asset/?id=16884673";

-- Set the grip for the handle
Tools.Default.Grip = CFrame.new( 0, 0, -0.4 ) * CFrame.Angles( math.rad( 90 ), math.rad( 90 ), 0 );

------------------------------------------
-- Paint tool
------------------------------------------

-- Create the main container for this tool
Tools.Paint = {};

-- Define options
Tools.Paint.Options = setmetatable( {

	["_options"] = {
		["Color"] = BrickColor.new( "Institutional white" ),
		["PaletteGUI"] = nil
	}

}, {

	-- Get the option from `self._options` instead of `self` directly
	__index = function ( self, key )
		return rawget( self, "_options" )[key];
	end;

	-- Let's do some special stuff if certain options are touched
	__newindex = function ( self, key, value )

		if key == "Color" then

			-- Mark the appropriate color in the palette
			if self.PaletteGUI then

				-- Clear any mark on any other color button from the palette
				for _, PaletteColorButton in pairs( self.PaletteGUI.Palette:GetChildren() ) do
					PaletteColorButton.Text = "";
				end;

				-- Mark the right color button in the palette
				self.PaletteGUI.Palette[value.Name].Text = "X";

			end;

			-- Change the color of selected items
			for _, Item in pairs( Selection.Items ) do
				Item.BrickColor = value;
			end;

		end;

		-- Set the option normally
		rawget( self, "_options" )[key] = value;

	end;

} );

-- Add listeners
Tools.Paint.Listeners = {};

Tools.Paint.Listeners.Equipped = function ()
	showPalette();
end;

Tools.Paint.Listeners.Unequipped = function ()
	hidePalette();
end;

Tools.Paint.Listeners.Button1Up = function ( Mouse )

	-- Make sure that they clicked on one of the items in their selection
	if #_findTableOccurrences( Selection.Items, Mouse.Target ) > 0 then

		-- Paint all of the selected items `Tools.Paint.Options.Color`
		if Tools.Paint.Options.Color then
			for _, Item in pairs( Selection.Items ) do
				Item.BrickColor = Tools.Paint.Options.Color;
			end;
		end;

	end;

end;

-- Create the handle
Tools.Paint.Handle = Instance.new( "Part" );
Tools.Paint.Handle.Name = "Handle";
Tools.Paint.Handle.CanCollide = false;

Instance.new( "SpecialMesh", Tools.Paint.Handle ).Name = "Mesh";
Tools.Paint.Handle.Mesh.MeshId = "http://www.roblox.com/asset/?id=15952512";
Tools.Paint.Handle.Mesh.MeshType = Enum.MeshType.FileMesh;
Tools.Paint.Handle.Mesh.Scale = Vector3.new( 0.25, 0.25, 0.25 );
Tools.Paint.Handle.Mesh.TextureId = "http://www.roblox.com/asset/?id=15952494";

-- Set the grip for the handle
Tools.Paint.Grip = CFrame.new( 0, 1, 0 ) * CFrame.Angles( 0, math.rad( 90 ), 0 );

function showPalette()
	-- Reveals a color palette

	-- Create the GUI container
	local PaletteGUI = Instance.new( "ScreenGui", Player.PlayerGui );
	PaletteGUI.Name = "BTColorPalette";

	-- Register the GUI
	Tools.Paint.Options.PaletteGUI = PaletteGUI;

	-- Create the frame that will contain the colors
	local PaletteFrame = Instance.new( "Frame", PaletteGUI );
	PaletteFrame.Name = "Palette";
	PaletteFrame.BackgroundColor3 = Color3.new( 0, 0, 0 );
	PaletteFrame.Transparency = 1;
	PaletteFrame.Size = UDim2.new( 0, 205, 0, 205 );
	PaletteFrame.Position = UDim2.new( 0, 0, 1 / 3, 0 );
	PaletteFrame.Draggable = true;
	PaletteFrame.Active = true;

	-- Insert the colors
	for palette_index = 0, 63 do

		-- Get BrickColor `palette_index` from the palette
		local Color = BrickColor.palette( palette_index );

		-- Calculate the row and column in the 8x8 grid
		local row = ( palette_index - ( palette_index % 8 ) ) / 8;
		local column = palette_index % 8;

		-- Create the button
		local ColorButton = Instance.new( "TextButton", PaletteFrame );
		ColorButton.Name = Color.Name;
		ColorButton.BackgroundColor3 = Color.Color;
		ColorButton.Size = UDim2.new( 0, 20, 0, 20 );
		ColorButton.Text = "";
		ColorButton.TextStrokeTransparency = 0.75;
		ColorButton.Font = Enum.Font.ArialBold;
		ColorButton.FontSize = Enum.FontSize.Size18;
		ColorButton.TextColor3 = Color3.new( 1, 1, 1 );
		ColorButton.TextStrokeColor3 = Color3.new( 0, 0, 0 );
		ColorButton.Position = UDim2.new( 0, column * 25 + 5, 0, row * 25 + 5 );
		ColorButton.BorderSizePixel = 0;

		-- Make the button change the `Color` option
		ColorButton.MouseButton1Click:connect( function ()
			Tools.Paint.Options.Color = Color;
		end );

	end;

end;

function hidePalette()

	if Tools.Paint.Options.PaletteGUI then
		Tools.Paint.Options.PaletteGUI:Destroy();
		Tools.Paint.Options.PaletteGUI = nil;
	end;

end;

------------------------------------------
-- Attach listeners
------------------------------------------

Tool.Equipped:connect( function ( Mouse )

	Options.TargetBox = Instance.new( "SelectionBox", Player.PlayerGui );
	Options.TargetBox.Name = "BTTargetBox";
	Options.TargetBox.Color = BrickColor.new( "Institutional white" );

	-- Enable any temporarily-disabled selection boxes
	for _, SelectionBox in pairs( SelectionBoxes ) do
		SelectionBox.Parent = Player.PlayerGui;
	end;

	-- Call the `Equipped` listener of the current tool
	if Options.Tool and Options.Tool.Listeners.Equipped then
		Options.Tool.Listeners.Equipped();
	end;

	Mouse.KeyDown:connect( function ( key )

		local key = key:lower();
		local key_code = key:byte();

		if key == "v" then
			Options.Tool = Tools.Paint;

		elseif key == "q" then
			Selection:clear();

		elseif key == "e" then
			Options.Tool = Tools.Default;

		end;

		ActiveKeys[key_code] = key_code;
		ActiveKeys[key] = key;

		-- If it's now in multiselection mode, update `selecting`
		-- (these are the left/right ctrl & shift keys)
		if ActiveKeys[47] or ActiveKeys[48] or ActiveKeys[49] or ActiveKeys[50] then
			selecting = ActiveKeys[47] or ActiveKeys[48] or ActiveKeys[49] or ActiveKeys[50];
		end;

	end );

	Mouse.KeyUp:connect( function ( key )

		local key = key:lower();
		local key_code = key:byte();

		ActiveKeys[key_code] = nil;
		ActiveKeys[key] = nil;

		-- If it's no longer in multiselection mode, update `selecting`
		if selecting and not ActiveKeys[selecting] then
			selecting = false;
		end;

	end );

	Mouse.Button1Down:connect( function ()

		clicking = true;
		click_x, click_y = Mouse.X, Mouse.Y;

		-- If multiselection is, just add to the selection
		if selecting then
			return;
		end;

		-- Fire tool listeners
		if Options.Tool and Options.Tool.Listeners.Button1Down then
			Options.Tool.Listeners.Button1Down( Mouse );
		end;

	end );

	Mouse.Move:connect( function ()

		-- If the target has changed, update the selectionbox appropriately
		if Mouse.Target then
			if Mouse.Target:IsA( "Part" ) and not Mouse.Target.Locked and Options.TargetBox.Adornee ~= Mouse.Target then
				Options.TargetBox.Adornee = Mouse.Target;
			end;
		end;

		-- When aiming at something invalid, don't highlight any targets
		if not Mouse.Target or ( Mouse.Target and Mouse.Target:IsA( "Part" ) and Mouse.Target.Locked ) then
			Options.TargetBox.Adornee = nil;
		end;

		-- If spay-like multi-selecting, add this current target to the selection
		if selecting and clicking then
			if Mouse.Target and Mouse.Target:IsA( "Part" ) and not Mouse.Target.Locked then
				Selection:add( Mouse.Target );
			end;
		end;

		-- Fire tool listeners
		if Options.Tool and Options.Tool.Listeners.Move then
			Options.Tool.Listeners.Move( Mouse );
		end;

	end );

	Mouse.Button1Up:connect( function ()

		clicking = false;

		-- If the target when clicking was invalid then clear the selection (unless we're multi-selecting)
		if not selecting and ( not Mouse.Target or ( Mouse.Target and Mouse.Target:IsA( "Part" ) and Mouse.Target.Locked ) ) then
			Selection:clear();
		end;

		-- If multi-selecting, add to/remove from the selection
		if selecting then

			-- If the item isn't already selected, add it to the selection
			if #_findTableOccurrences( Selection.Items, Mouse.Target ) == 0 then
				if Mouse.Target and Mouse.Target:IsA( "Part" ) and not Mouse.Target.Locked then
					Selection:add( Mouse.Target );
				end;
			
			-- If the item _is_ already selected, remove it from the selection
			-- (unless they're finishing a spray-like selection)
			else
				if ( Mouse.X == click_x and Mouse.Y == click_y ) and Mouse.Target and Mouse.Target:IsA( "Part" ) and not Mouse.Target.Locked then
					Selection:remove( Mouse.Target );
				end;
			end;

		-- If not multi-selecting, replace the selection
		else
			if Mouse.Target and Mouse.Target:IsA( "Part" ) and not Mouse.Target.Locked then
				Selection:clear();
				Selection:add( Mouse.Target );
			end;
		end;

		-- Fire tool listeners
		if Options.Tool and Options.Tool.Listeners.Button1Up then
			Options.Tool.Listeners.Button1Up( Mouse );
		end;

	end );

end );

Tool.Unequipped:connect( function ()

	-- Remove the mouse target SelectionBox from `Player`
	local TargetBox = Player.PlayerGui:FindFirstChild( "BTTargetBox" );
	if TargetBox then
		TargetBox:Destroy();
	end;

	-- Disable all the selection boxes temporarily
	for _, SelectionBox in pairs( SelectionBoxes ) do
		SelectionBox.Parent = nil;
	end;

	-- Call the `Unequipped` listener of the current tool
	if Options.Tool and Options.Tool.Listeners.Unequipped then
		Options.Tool.Listeners.Unequipped();
	end;

end );

-- Enable `Tools.Default` as the first tool
Options.Tool = Tools.Default;