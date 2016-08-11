local View = script.Parent;
local Component = { View = View };

function Component.Start(Options, CurrentOption, Callback)

	-- Toggle options when clicked
	View.MouseButton1Click:connect(Component.Toggle);

	-- Draw the component with the given options
	Component.Draw(Options, CurrentOption, Callback);

	-- Return component for chaining
	return Component;

end;

function Component.Toggle()
	-- Toggles the visibility of the dropdown options

	-- Show each option button open or closed
	local Buttons = View.Options:GetChildren();
	for _, Button in pairs(Buttons) do
		Button.Visible = not Button.Visible;
	end;

end;

function Component.SetOption(Option)
	-- Draws the current option into the dropdown

	-- Set the label
	View.CurrentOption.Text = Option:upper();

end;

function Component.Draw(Options, CurrentOption, Callback)
	-- Draws the dropdown with the given data

	-- Clear existing buttons
	View.Options:ClearAllChildren();

	-- Create a button for each option
	for Index, Option in ipairs(Options) do

		-- Create the button
		local Button = View.OptionButton:Clone();
		Button.Parent = View.Options;
		Button.OptionLabel.Text = Option:upper();
		Button.MouseButton1Click:connect(function ()
			Callback(Option);
			Component.SetOption(Option);
			Component.Toggle();
		end);

		-- Position the button
		Button.Position = UDim2.new(
			math.ceil(Index / 9) - 1, Button.Position.X.Offset + (math.ceil(Index / 9) * -1) + 1,
			(Index % 9 == 0 and 9 or Index % 9) * Button.Size.Y.Scale, Button.Position.Y.Offset
		);

	end;

	-- Show the view
	View.Visible = true;

end;

return Component;