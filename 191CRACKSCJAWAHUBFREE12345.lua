-- ======================================================
--   JAWA HUB - AUTO MARSHMALLOW (FULL FIX)
--   GUI RAPI + INVENTORY SYNC
-- ======================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VIM = game:GetService("VirtualInputManager")
local UIS = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player.PlayerGui
local character = player.Character or player.CharacterAdded:Wait()
local hrp = character:WaitForChild("HumanoidRootPart")

-- ========================
-- KONFIGURASI
-- ========================

local CONFIG = {
	WATER_WAIT = 20,
	COOK_WAIT = 46,
}

local ITEM_WATER = "Water"
local ITEM_SUGAR = "Sugar Block Bag"
local ITEM_GEL = "Gelatin"
local ITEM_EMPTY = "Empty Bag"

local ITEM_MS_SMALL = "Small Marshmallow"
local ITEM_MS_MEDIUM = "Medium Marshmallow"
local ITEM_MS_LARGE = "Large Marshmallow"

-- ========================
-- STATE
-- ========================

local isRunning = false
local isCooking = false

local stats = {
	totalMS = 0,
	small = 0,
	medium = 0,
	large = 0
}

-- ========================
-- PRESS E
-- ========================

local function pressE()

	local ok = pcall(function()
		VIM:SendKeyEvent(true,Enum.KeyCode.E,false,game)
		task.wait(0.1)
		VIM:SendKeyEvent(false,Enum.KeyCode.E,false,game)
	end)

	if not ok then

		for _,obj in ipairs(workspace:GetDescendants()) do

			if obj:IsA("ProximityPrompt") then

				local part = obj.Parent

				if part and part:IsA("BasePart") then

					local dist = (hrp.Position - part.Position).Magnitude

					if dist <= (obj.MaxActivationDistance or 10) then

						pcall(function()
							fireproximityprompt(obj)
						end)

					end

				end

			end

		end

	end

end

-- ========================
-- INVENTORY
-- ========================

local function countItem(name)

	local n = 0

	for _,t in ipairs(player.Backpack:GetChildren()) do
		if t.Name == name then
			n += 1
		end
	end

	local char = player.Character

	if char then
		for _,t in ipairs(char:GetChildren()) do
			if t:IsA("Tool") and t.Name == name then
				n += 1
			end
		end
	end

	return n

end


local function countMS(name)

	local n = 0

	for _,t in ipairs(player.Backpack:GetChildren()) do
		if t.Name == name then
			n += 1
		end
	end

	local char = player.Character

	if char then
		for _,t in ipairs(char:GetChildren()) do
			if t:IsA("Tool") and t.Name == name then
				n += 1
			end
		end
	end

	return n

end


local function equipTool(name)

	local char = player.Character
	if not char then return false end

	local hum = char:FindFirstChildOfClass("Humanoid")
	local t = player.Backpack:FindFirstChild(name)

	if hum and t then
		hum:EquipTool(t)
		task.wait(0.3)
		return true
	end

	return false

end


local function hasAllIngredients()

	return countItem(ITEM_WATER) >= 1
	and countItem(ITEM_SUGAR) >= 1
	and countItem(ITEM_GEL) >= 1

end

-- ========================
-- GUI
-- ========================

if playerGui:FindFirstChild("JawaHubGUI") then
	playerGui.JawaHubGUI:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "JawaHubGUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0,250,0,340)
panel.Position = UDim2.new(0,15,0.5,-170)
panel.BackgroundColor3 = Color3.fromRGB(24,24,36)
panel.BorderSizePixel = 0
panel.Parent = screenGui

Instance.new("UICorner",panel).CornerRadius = UDim.new(0,14)
Instance.new("UIStroke",panel).Color = Color3.fromRGB(60,60,90)

-- HEADER

local header = Instance.new("Frame")
header.Size = UDim2.new(1,0,0,45)
header.BackgroundColor3 = Color3.fromRGB(30,30,46)
header.BorderSizePixel = 0
header.Parent = panel

Instance.new("UICorner",header).CornerRadius = UDim.new(0,14)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,0,1,0)
title.BackgroundTransparency = 1
title.Text = "DSR Auto Marshmallow"
title.TextColor3 = Color3.fromRGB(255,255,255)
title.Font = Enum.Font.GothamBold
title.TextScaled = true
title.Parent = header

-- MS TOTAL

local sisaMS = Instance.new("TextLabel")
sisaMS.Size = UDim2.new(1,0,0,28)
sisaMS.Position = UDim2.new(0,0,0,55)
sisaMS.BackgroundTransparency = 1
sisaMS.Text = "MS Selesai: 0"
sisaMS.TextColor3 = Color3.fromRGB(80,220,255)
sisaMS.Font = Enum.Font.GothamBold
sisaMS.TextScaled = true
sisaMS.Parent = panel

-- LIST

local function makeLabel(text,y)

	local lbl = Instance.new("TextLabel")

	lbl.Size = UDim2.new(1,-20,0,22)
	lbl.Position = UDim2.new(0,12,0,y)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = Color3.fromRGB(210,210,210)
	lbl.TextScaled = true
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Font = Enum.Font.Gotham

	lbl.Parent = panel

	return lbl

end

local lblSmall = makeLabel("Small: 0",95)
local lblMedium = makeLabel("Medium: 0",118)
local lblLarge = makeLabel("Large: 0",141)

local lblWater = makeLabel("Water: 0",185)
local lblSugar = makeLabel("Sugar Block Bag: 0",208)
local lblGel = makeLabel("Gelatin: 0",231)

-- STATUS

local lblStatus = Instance.new("TextLabel")
lblStatus.Size = UDim2.new(1,-10,0,22)
lblStatus.Position = UDim2.new(0,5,0,260)
lblStatus.BackgroundTransparency = 1
lblStatus.Text = ""
lblStatus.TextScaled = true
lblStatus.Font = Enum.Font.Gotham
lblStatus.TextColor3 = Color3.fromRGB(255,210,80)
lblStatus.Parent = panel

-- BUTTON

local btnFrame = Instance.new("Frame")
btnFrame.Size = UDim2.new(1,-20,0,44)
btnFrame.Position = UDim2.new(0,10,1,-50)
btnFrame.BackgroundColor3 = Color3.fromRGB(40,185,80)
btnFrame.BorderSizePixel = 0
btnFrame.Parent = panel

Instance.new("UICorner",btnFrame).CornerRadius = UDim.new(0,10)

local btn = Instance.new("TextButton")
btn.Size = UDim2.new(1,0,1,0)
btn.BackgroundTransparency = 1
btn.Text = "Start AutoMS"
btn.Font = Enum.Font.GothamBold
btn.TextScaled = true
btn.TextColor3 = Color3.new(1,1,1)
btn.Parent = btnFrame

-- ========================
-- DRAG GUI
-- ========================

local dragging = false
local dragInput
local dragStart
local startPos

local function update(input)

	local delta = input.Position - dragStart

	panel.Position = UDim2.new(
		startPos.X.Scale,
		startPos.X.Offset + delta.X,
		startPos.Y.Scale,
		startPos.Y.Offset + delta.Y
	)

end

header.InputBegan:Connect(function(input)

	if input.UserInputType == Enum.UserInputType.MouseButton1
	or input.UserInputType == Enum.UserInputType.Touch then

		dragging = true
		dragStart = input.Position
		startPos = panel.Position

		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
			end
		end)

	end

end)

header.InputChanged:Connect(function(input)

	if input.UserInputType == Enum.UserInputType.MouseMovement
	or input.UserInputType == Enum.UserInputType.Touch then
		dragInput = input
	end

end)

UIS.InputChanged:Connect(function(input)

	if input == dragInput and dragging then
		update(input)
	end

end)

-- ========================
-- DISPLAY
-- ========================

local function updateDisplay()

	local small = countMS(ITEM_MS_SMALL)
	local medium = countMS(ITEM_MS_MEDIUM)
	local large = countMS(ITEM_MS_LARGE)

	stats.small = small
	stats.medium = medium
	stats.large = large
	stats.totalMS = small + medium + large

	lblSmall.Text = "Small: "..small
	lblMedium.Text = "Medium: "..medium
	lblLarge.Text = "Large: "..large

	lblWater.Text = "Water: "..countItem(ITEM_WATER)
	lblSugar.Text = "Sugar Block Bag: "..countItem(ITEM_SUGAR)
	lblGel.Text = "Gelatin: "..countItem(ITEM_GEL)

	sisaMS.Text = "MS Selesai: "..stats.totalMS

end

RunService.Heartbeat:Connect(updateDisplay)

-- ========================
-- AUTO LOOP
-- ========================

local function autoLoop()

	while isRunning do

		if not hasAllIngredients() then

			lblStatus.Text = "Bahan habis!"

			isRunning = false
			break

		end

		pressE()

		task.wait(CONFIG.COOK_WAIT)

	end

	btn.Text = "Start AutoMS"
	btnFrame.BackgroundColor3 = Color3.fromRGB(40,185,80)

end

-- ========================
-- BUTTON
-- ========================

btn.MouseButton1Click:Connect(function()

	if isRunning then

		isRunning = false
		btn.Text = "Start AutoMS"
		btnFrame.BackgroundColor3 = Color3.fromRGB(40,185,80)

	else

		if not hasAllIngredients() then
			lblStatus.Text = "Bahan tidak lengkap!"
			return
		end

		isRunning = true
		btn.Text = "Stop AutoMS"
		btnFrame.BackgroundColor3 = Color3.fromRGB(200,60,60)

		task.spawn(autoLoop)

	end

end)

player.CharacterAdded:Connect(function(char)

	character = char
	hrp = char:WaitForChild("HumanoidRootPart")

end)

print("JawaHub AutoMS FULL FIX Loaded")
