presetPadding.PaddingLeft = UDim.new(0, 5)
presetPadding.PaddingRight = UDim.new(0, 5)
presetPadding.PaddingTop = UDim.new(0, 5)
presetPadding.PaddingBottom = UDim.new(0, 5)
presetPadding.Parent = presetRow

local presetLayout = Instance.new("UIListLayout")
presetLayout.FillDirection = Enum.FillDirection.Horizontal
presetLayout.Padding = UDim.new(0, 5)
presetLayout.SortOrder = Enum.SortOrder.LayoutOrder
presetLayout.Parent = presetRow

local presetButtons = {}
local speedLabel
local stopLabel

local function refreshLabels()
	local pushing = settings.mode == "push"
	if speedLabel then
		speedLabel.Text = pushing and "Push Speed" or "Pull Speed"
	end
	if stopLabel then
		stopLabel.Text = pushing and "Stop Distance (n/a)" or "Stop Distance"
		stopLabel.TextColor3 = pushing and SUBTEXT or TEXT
	end
end

local function refreshPresetButtons()
	for name, button in pairs(presetButtons) do
		local on = name == activePreset
		button.BackgroundColor3 = on and ACCENT or Color3.fromRGB(0, 0, 0)
		button.TextColor3 = on and Color3.fromRGB(255, 255, 255) or SUBTEXT
	end
end

for i, info in ipairs({ { "OL", "OL Settings" }, { "DE", "DE Settings" } }) do
	local name, text = info[1], info[2]
	local button = Instance.new("TextButton")
	button.LayoutOrder = i
	button.Size = UDim2.new(0.5, -3, 1, 0)
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Font = Enum.Font.GothamBold
	button.Text = text
	button.TextSize = 13
	button.Parent = presetRow

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = button

	button.MouseButton1Click:Connect(function()
		activePreset = name
		settings = presets[name]
		refreshPresetButtons()
		refreshAll()
		refreshLabels()
		currentSpeed = 0
	end)

	presetButtons[name] = button
end
refreshPresetButtons()

speedLabel = numberRow("Pull Speed", "pullSpeed", 0, 200)
stopLabel = numberRow("Stop Distance", "stopDistance", 0, 50)
numberRow("Pull Smoothing", "pullSmoothing", 0, 50)
toggleRow("Show Box", "showBox")
sizeRow("Box Size")
numberRow("Front Offset", "frontOffset", -50, 50)
refreshLabels()

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == HIDE_UI_KEY then
		gui.Enabled = not gui.Enabled
	end
end)

local dragging = false
local dragStart
local startPos

header.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = main.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
			end
		end)
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragStart
		main.Position = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + delta.X,
			startPos.Y.Scale, startPos.Y.Offset + delta.Y
		)
	end
end)
