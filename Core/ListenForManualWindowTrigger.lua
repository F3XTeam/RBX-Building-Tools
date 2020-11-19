local Tool = script:FindFirstAncestorWhichIsA('Tool')
local Core = require(Tool.Core)
local UI = Tool:WaitForChild('UI')
local Vendor = Tool:WaitForChild('Vendor')

-- Libraries
local Roact = require(Vendor:WaitForChild('Roact'))
local ToolManualWindow = require(UI:WaitForChild('ToolManualWindow'))

local function ListenForManualWindowTrigger(Text, ThemeColor, SignatureButton)
    local HelpButton = SignatureButton:WaitForChild('HelpButton')

	local IsManualOpen = false
	local ManualHandle = nil

	local function BeginHover()
		if not IsManualOpen then
			HelpButton.TextTransparency = 0
			HelpButton:WaitForChild('Background').BackgroundTransparency = 0
		end
	end

	local function EndHover()
		if not IsManualOpen then
			HelpButton.TextTransparency = 0.5
			HelpButton:WaitForChild('Background').BackgroundTransparency = 0.75
		end
	end

	local function ToggleManual()
		HelpButton.TextTransparency = IsManualOpen and 0 or 0.5
		HelpButton:WaitForChild('Background').BackgroundTransparency = IsManualOpen and 0 or 0.75

        -- Close manual if open
        if IsManualOpen then
			EndHover()
			IsManualOpen = false
			ManualHandle = Roact.unmount(ManualHandle)

        -- Open manual if closed
        else
			BeginHover()
			IsManualOpen = true
			local ManualElement = Roact.createElement(ToolManualWindow, {
				Text = Text;
				ThemeColor = ThemeColor;
			})
			ManualHandle = Roact.mount(ManualElement, Core.UI, 'ToolManualWindow')
		end
	end

	-- Enable help button
	SignatureButton.Activated:Connect(ToggleManual)
	HelpButton.Activated:Connect(ToggleManual)
	SignatureButton.InputBegan:Connect(BeginHover)
	SignatureButton.InputEnded:Connect(EndHover)
	HelpButton.InputBegan:Connect(BeginHover)
	HelpButton.InputEnded:Connect(EndHover)
end

return ListenForManualWindowTrigger