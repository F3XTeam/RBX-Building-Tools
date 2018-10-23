local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Roact = require(ReplicatedStorage:WaitForChild("Roact"))
local TweenService = require(ReplicatedStorage:WaitForChild("TweenService"))
local Utility = require(ReplicatedStorage:WaitForChild("Utility"))
local CreateElement = Roact.createElement

local ImageLabel = require(script.Parent:WaitForChild("ImageLabel"))
local TextLabel = require(script.Parent:WaitForChild("TextLabel"))
local Snackbar = Roact.PureComponent:extend("Snackbar")

function Snackbar:init()
	self.instance = Roact.createRef()
end

function Snackbar:didMount()
	spawn(function() -- This can be coroutine.wrap if you feel it's a good idea.
		self.Running = true
		TweenService:SimpleTween(self.instance.current, 1, "Sine", "Out", { Position = UDim2.new(1, -5, 1, -5) })
		
		delay(1.5, function()
			TweenService:SimpleTween(self.instance.current, 1, "Sine", "In", { Position = UDim2.new(1, -5, 1.5, -5) })
			self.Running = false
		end)
	end)
end

function Snackbar:willUnmount()
	self.Running = nil
end

function Snackbar:render()
	local SnackbarTextString = self.props.SnackbarText or "No text given"
	local SizeVector = TextService:GetTextSize(SnackbarTextString, 20, Enum.Font.SourceSans.Value, Vector2.new(1 / 0, 1 / 0))
	local SnackbarSize = UDim2.new(0, SizeVector.X + 48 > 344 and SizeVector.X + 48 or 344, 0, 48)
	
	return CreateElement(ImageLabel, {
		[Roact.Ref] = self.instance,
		AnchorPoint = Vector2.new(1, 1),
		ImageColor3 = Color3.fromRGB(50, 50, 50),
		ScaleType = Enum.ScaleType.Slice.Value,
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -5, 1.5, -5),
		Size = SnackbarSize, --UDim2.new(0, 344, 0, 48),
		Image = "rbxassetid://1934624205",
		SliceCenter = Rect.new(4, 4, 252, 252),
		ZIndex = 2
	}, {
		AmbientShadow = CreateElement(ImageLabel, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			ImageColor3 = Color3.fromRGB(0, 0, 0),
			ScaleType = Enum.ScaleType.Slice.Value,
			ImageTransparency = 0.8,
			BackgroundTransparency = 1,
			Name = "AmbientShadow",
			Position = UDim2.new(0.5, 0, 0.5, 3),
			Size = UDim2.new(1, 5, 1, 5),
			Image = "rbxassetid://1316045217",
			SliceCenter = Rect.new(10, 10, 118, 118)
		}),
		
		PenumbraShadow = CreateElement(ImageLabel, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			ImageColor3 = Color3.fromRGB(0, 0, 0),
			ScaleType = Enum.ScaleType.Slice.Value,
			ImageTransparency = 0.88,
			BackgroundTransparency = 1,
			Name = "PenumbraShadow",
			Position = UDim2.new(0.5, 0, 0.5, 1),
			Size = UDim2.new(1, 18, 1, 18),
			Image = "rbxassetid://1316045217",
			SliceCenter = Rect.new(10, 10, 118, 118)
		}),
		
		UmbraShadow = CreateElement(ImageLabel, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			ImageColor3 = Color3.fromRGB(0, 0, 0),
			ScaleType = Enum.ScaleType.Slice.Value,
			ImageTransparency = 0.86,
			BackgroundTransparency = 1,
			Name = "UmbraShadow",
			Position = UDim2.new(0.5, 0, 0.5, 6),
			Size = UDim2.new(1, 10, 1, 10),
			Image = "rbxassetid://1316045217",
			SliceCenter = Rect.new(10, 10, 118, 118)
		}),
		
		SnackbarText = CreateElement(TextLabel, {
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			Name = "SnackbarText",
			Position = UDim2.new(0, 16, 0.5, 0),
			Size = UDim2.new(1, -32, 1, -12),
			ZIndex = 3,
			Font = Enum.Font.SourceSans.Value,
			Text = SnackbarTextString,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 20,
			TextXAlignment = Enum.TextXAlignment.Left.Value
		})
	})
end

return Snackbar
