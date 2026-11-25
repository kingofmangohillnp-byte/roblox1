local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer

local PLAYER_PADDING = 1
local IGNORE_TEAMMATES = true

local ACTIVATE_KEY = Enum.KeyCode.X
local ACTIVATE_GAMEPAD_KEY = Enum.KeyCode.ButtonL2
local ACTIVE_TIME = 2.3
local HIDE_UI_KEY = Enum.KeyCode.LeftControl

local BOX_COLOR = Color3.fromRGB(150, 60, 255)
local BOX_TRANSPARENCY = 0.85

local function newPreset(mode)
	return {
		mode = mode,
		pullSpeed = 8,
		stopDistance = 4.5,
		pullSmoothing = 2,
		showBox = false,
		sizeX = 6,
		sizeY = 5,
		sizeZ = 4,
		frontOffset = 4,
	}
end

local presets = {
	OL = newPreset("pull"),
	DE = newPreset("push"),
}
local activePreset = "OL"
local settings = presets[activePreset]

local function getBoxSize()
	return Vector3.new(settings.sizeX, settings.sizeY, settings.sizeZ)
end

local visuals = {}
local currentSpeed = 0
local lastDir = Vector3.zero
local activeUntil = 0

local function getTorso(character)
	return character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
end

local function getBoxCFrame(torso)
	local look = torso.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude < 0.01 then
		flatLook = Vector3.new(0, 0, -1)
	end
	flatLook = flatLook.Unit
	local center = torso.Position + flatLook * settings.frontOffset
	return CFrame.lookAt(center, center + flatLook)
end

local function ensureVisual(player)
	if visuals[player] then return visuals[player] end
	local part = Instance.new("Part")
	part.Name = "PullBox"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Size = getBoxSize()
	part.Color = BOX_COLOR
	part.Material = Enum.Material.Neon
	part.Transparency = BOX_TRANSPARENCY
	part.Parent = Workspace
	visuals[player] = part
	return part
end

local function removeVisual(player)
	local v = visuals[player]
	if v then
		v:Destroy()
		visuals[player] = nil
	end
end

Players.PlayerRemoving:Connect(removeVisual)

local function isTeammate(player)
	local myTeam = localPlayer.Team
	return myTeam ~= nil and player.Team == myTeam
end

local function activateBox()
	if os.clock() >= activeUntil then
		activeUntil = os.clock() + ACTIVE_TIME
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.KeyCode == ACTIVATE_GAMEPAD_KEY then
		activateBox()
		return
	end
	if gameProcessed then return end
	if input.KeyCode == ACTIVATE_KEY then
		activateBox()
	end
end)

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

RunService.Heartbeat:Connect(function(dt)
	local isActive = os.clock() < activeUntil
	local boxSize = getBoxSize()

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local torso = character and getTorso(character)
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")

		if settings.showBox and torso and humanoid and humanoid.Health > 0 then
			local v = ensureVisual(player)
			v.Size = boxSize
			v.CFrame = getBoxCFrame(torso)
		else
			removeVisual(player)
		end
	end

	local myChar = localPlayer.Character
	local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
	local myTorso = myChar and getTorso(myChar)
	local myHumanoid = myChar and myChar:FindFirstChildOfClass("Humanoid")

	if not myRoot or not myTorso or not myHumanoid or myHumanoid.Health <= 0 then
		currentSpeed = 0
		return
	end

	local boxCF = getBoxCFrame(myTorso)
	local half = boxSize / 2 + Vector3.one * PLAYER_PADDING
	local pushing = settings.mode == "push"

	local pullDir = nil
	local pullDistance = math.huge

	if isActive then
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= localPlayer and not (IGNORE_TEAMMATES and isTeammate(player)) then
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")

				if root and humanoid and humanoid.Health > 0 then
					local rel = boxCF:PointToObjectSpace(root.Position)
					if math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z then
						local toThem = root.Position - myRoot.Position
						local flat = Vector3.new(toThem.X, 0, toThem.Z)
						if flat.Magnitude < pullDistance then
							pullDistance = flat.Magnitude
							pullDir = flat
						end
					end
				end
			end
		end
	end

	local targetSpeed = 0
	if pullDir then
		if pushing then
			targetSpeed = settings.pullSpeed
			lastDir = -pullDir.Unit
		elseif pullDistance > settings.stopDistance then
			targetSpeed = settings.pullSpeed
			lastDir = pullDir.Unit
		end
	end

	currentSpeed += (targetSpeed - currentSpeed) * math.min(1, dt * settings.pullSmoothing)
	if currentSpeed < 0.05 or lastDir.Magnitude < 0.01 then
		currentSpeed = 0
		return
	end

	local step = lastDir * currentSpeed * dt

	local filter = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(filter, p.Character)
		end
	end
	rayParams.FilterDescendantsInstances = filter

	local hit = Workspace:Raycast(myRoot.Position, step.Unit * (step.Magnitude + 1.5), rayParams)
	if hit then
		currentSpeed = 0
		return
	end

	myRoot.CFrame = myRoot.CFrame + step
end)

local ACCENT = Color3.fromRGB(150, 60, 255)
local BASE = Color3.fromRGB(10, 10, 10)
local ROW = Color3.fromRGB(24, 24, 24)
local TEXT = Color3.fromRGB(235, 235, 235)
local SUBTEXT = Color3.fromRGB(150, 150, 150)
local FIELD_STROKE = Color3.fromRGB(55, 55, 55)

local playerGui = localPlayer:WaitForChild("PlayerGui")
local old = playerGui:FindFirstChild("AutoJamAndShed")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "AutoJamAndShed"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0, 280, 0, 0)
main.AutomaticSize = Enum.AutomaticSize.Y
main.Position = UDim2.new(0, 20, 0.5, -170)
main.BackgroundColor3 = BASE
main.BorderSizePixel = 0
main.Parent = gui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 10)
mainCorner.Parent = main

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(45, 45, 45)
mainStroke.Thickness = 1
mainStroke.Parent = main

local mainPadding = Instance.new("UIPadding")
mainPadding.PaddingTop = UDim.new(0, 8)
mainPadding.PaddingBottom = UDim.new(0, 10)
mainPadding.PaddingLeft = UDim.new(0, 10)
mainPadding.PaddingRight = UDim.new(0, 10)
mainPadding.Parent = main

local mainLayout = Instance.new("UIListLayout")
mainLayout.Padding = UDim.new(0, 6)
mainLayout.SortOrder = Enum.SortOrder.LayoutOrder
mainLayout.Parent = main

local header = Instance.new("Frame")
header.Name = "Header"
header.LayoutOrder = 0
header.Size = UDim2.new(1, 0, 0, 30)
header.BackgroundTransparency = 1
header.Active = true
header.Parent = main

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "Auto Jam and Shed"
title.TextColor3 = TEXT
title.TextSize = 17
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header


local hint = Instance.new("TextLabel")
hint.AnchorPoint = Vector2.new(1, 0)
hint.Position = UDim2.new(1, 0, 0, 0)
hint.Size = UDim2.new(0, 120, 0, 30)
hint.BackgroundTransparency = 1
hint.Font = Enum.Font.Gotham
hint.Text = "L-Ctrl hides"
hint.TextColor3 = SUBTEXT
hint.TextSize = 12
hint.TextXAlignment = Enum.TextXAlignment.Right
hint.Parent = header

local order = 1
local refreshers = {}

local function refreshAll()
	for _, fn in ipairs(refreshers) do
		fn()
	end
end

local function makeRow(labelText)
	local row = Instance.new("Frame")
	row.LayoutOrder = order
	order += 1
	row.Size = UDim2.new(1, 0, 0, 34)
	row.BackgroundColor3 = ROW
	row.BorderSizePixel = 0
	row.Parent = main

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 7)
	corner.Parent = row

	local label = Instance.new("TextLabel")
	label.Position = UDim2.new(0, 10, 0, 0)
	label.Size = UDim2.new(0.4, -10, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.Text = labelText
	label.TextColor3 = TEXT
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = row

	return row, label
end

local function makeNumberField(parent, key, minV, maxV)
	local box = Instance.new("TextBox")
	box.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	box.BorderSizePixel = 0
	box.Font = Enum.Font.GothamMedium
	box.Text = tostring(settings[key])
	box.TextColor3 = TEXT
	box.TextSize = 13
	box.ClearTextOnFocus = false
	box.PlaceholderText = "0"
	box.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = box

	local stroke = Instance.new("UIStroke")
	stroke.Color = FIELD_STROKE
	stroke.Thickness = 1
	stroke.Parent = box

	box.Focused:Connect(function()
		stroke.Color = ACCENT
	end)

	box:GetPropertyChangedSignal("Text"):Connect(function()
		local n = tonumber(box.Text)
		if n then
			settings[key] = math.clamp(n, minV, maxV)
		end
	end)

	box.FocusLost:Connect(function()
		stroke.Color = FIELD_STROKE
		box.Text = tostring(settings[key])
	end)

	table.insert(refreshers, function()
		if not box:IsFocused() then
			box.Text = tostring(settings[key])
		end
	end)

	return box
end

local function numberRow(labelText, key, minV, maxV)
	local row, label = makeRow(labelText)
	local box = makeNumberField(row, key, minV, maxV)
	box.AnchorPoint = Vector2.new(1, 0.5)
	box.Position = UDim2.new(1, -6, 0.5, 0)
	box.Size = UDim2.new(0.5, 0, 0, 24)
	return label
end

local function sizeRow(labelText)
	local row = makeRow(labelText)

	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(1, 0.5)
	holder.Position = UDim2.new(1, -6, 0.5, 0)
	holder.Size = UDim2.new(0.6, -6, 0, 24)
	holder.BackgroundTransparency = 1
	holder.Parent = row

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = holder

	for i, key in ipairs({ "sizeX", "sizeY", "sizeZ" }) do
		local box = makeNumberField(holder, key, 0, 100)
		box.LayoutOrder = i
		box.Size = UDim2.new(1 / 3, -3, 1, 0)
	end
end

local function toggleRow(labelText, key)
	local row = makeRow(labelText)

	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -6, 0.5, 0)
	button.Size = UDim2.new(0.5, 0, 0, 24)
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Font = Enum.Font.GothamBold
	button.TextSize = 13
	button.Parent = row

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = button

	local function refresh()
		local on = settings[key]
		button.Text = on and "ON" or "OFF"
		button.BackgroundColor3 = on and ACCENT or Color3.fromRGB(0, 0, 0)
		button.TextColor3 = on and Color3.fromRGB(255, 255, 255) or SUBTEXT
	end

	button.MouseButton1Click:Connect(function()
		settings[key] = not settings[key]
		refresh()
	end)

	table.insert(refreshers, refresh)
	refresh()
end

local presetRow = Instance.new("Frame")
presetRow.LayoutOrder = order
order += 1
presetRow.Size = UDim2.new(1, 0, 0, 34)
presetRow.BackgroundColor3 = ROW
presetRow.BorderSizePixel = 0
presetRow.Parent = main

local presetCorner = Instance.new("UICorner")
presetCorner.CornerRadius = UDim.new(0, 7)
presetCorner.Parent = presetRow

local presetPadding = Instance.new("UIPadding")
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
