-- ======================================================
--   191 FREE - AUTO MARSHMALLOW v1
--   StarterPlayer > StarterPlayerScripts (LocalScript)
--   Created by Jeranbian
-- ======================================================

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local VIM          = game:GetService("VirtualInputManager")
local UIS          = game:GetService("UserInputService")

local player    = Players.LocalPlayer
local playerGui = player.PlayerGui
local character = player.Character or player.CharacterAdded:Wait()
local hrp       = character:WaitForChild("HumanoidRootPart")

-- ============================================================
-- KONFIGURASI
-- ============================================================
local CFG = {
	WATER_WAIT    = 20,
	COOK_WAIT     = 46,

	ITEM_WATER = "Water",
	ITEM_SUGAR = "Sugar Block Bag",
	ITEM_GEL   = "Gelatin",
	ITEM_EMPTY = "Empty Bag",

	ITEM_MS_SMALL  = "Small Marshmallow Bag",
	ITEM_MS_MEDIUM = "Medium Marshmallow Bag",
	ITEM_MS_LARGE  = "Large Marshmallow Bag",

	SELL_RADIUS  = 10,
	BUY_RADIUS   = 10,
	SELL_TIMEOUT = 8,
}

-- ============================================================
-- STATE
-- ============================================================
local isRunning = false
local isBusy    = false
local stats     = { small = 0, medium = 0, large = 0 }

local function totalMS() return stats.small + stats.medium + stats.large end

-- ============================================================
-- CORE UTILITIES
-- ============================================================
local function pressE()
	pcall(function()
		VIM:SendKeyEvent(true,  Enum.KeyCode.E, false, game)
		task.wait(0.15)
		VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
	end)
end

local function fireAllNearbyPrompts(radius)
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("ProximityPrompt") then
			local part = obj.Parent
			if part and part:IsA("BasePart") then
				local dist = (hrp.Position - part.Position).Magnitude
				if dist <= (radius or 10) then
					pcall(function() fireproximityprompt(obj) end)
				end
			end
		end
	end
end

local function countItem(name)
	local n = 0
	for _, t in ipairs(player.Backpack:GetChildren()) do
		if t.Name == name then n += 1 end
	end
	local char = player.Character
	if char then
		for _, t in ipairs(char:GetChildren()) do
			if t:IsA("Tool") and t.Name == name then n += 1 end
		end
	end
	return n
end

local function equipTool(name)
	local char = player.Character
	if not char then return false end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local t   = player.Backpack:FindFirstChild(name)
	if hum and t then
		hum:EquipTool(t)
		task.wait(0.4)
		return true
	end
	return false
end

local function unequipAll()
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then hum:UnequipTools() end
end

local function hasAllIngredients()
	return countItem(CFG.ITEM_WATER) >= 1
		and countItem(CFG.ITEM_SUGAR) >= 1
		and countItem(CFG.ITEM_GEL)   >= 1
end

-- ============================================================
-- AUTO MASAK
-- ============================================================
local lblStatus

local function setStatus(msg, color)
	if lblStatus then
		lblStatus.Text       = msg
		lblStatus.TextColor3 = color or Color3.fromRGB(200,200,200)
	end
end

local function countdown(secs, fmt, color)
	for i = secs, 1, -1 do
		if not isRunning then return false end
		setStatus(string.format(fmt, i), color)
		task.wait(1)
	end
	return true
end

local function doOneCook()
	isBusy = true

	local snapS = countItem(CFG.ITEM_MS_SMALL)
	local snapM = countItem(CFG.ITEM_MS_MEDIUM)
	local snapL = countItem(CFG.ITEM_MS_LARGE)

	setStatus("💧 Water...", Color3.fromRGB(255,200,0))
	equipTool(CFG.ITEM_WATER)
	task.wait(0.5)
	pressE()
	fireAllNearbyPrompts(6)
	task.wait(0.7)

	if not countdown(CFG.WATER_WAIT, "💧 Mendidih... %ds", Color3.fromRGB(255,180,0)) then
		isBusy = false return false
	end

	setStatus("🧂 Sugar Bag...", Color3.fromRGB(255,200,0))
	equipTool(CFG.ITEM_SUGAR)
	task.wait(0.5)
	pressE()
	fireAllNearbyPrompts(6)
	task.wait(2)

	setStatus("🟡 Gelatin...", Color3.fromRGB(255,200,0))
	equipTool(CFG.ITEM_GEL)
	task.wait(0.5)
	pressE()
	fireAllNearbyPrompts(6)
	task.wait(1)

	if not countdown(CFG.COOK_WAIT, "🔥 Memasak... %ds", Color3.fromRGB(255,160,0)) then
		isBusy = false return false
	end

	setStatus("🎒 Tunggu Tas Kosong...", Color3.fromRGB(255,200,0))
	local bag, t2 = nil, 0
	repeat
		bag = player.Backpack:FindFirstChild(CFG.ITEM_EMPTY)
		task.wait(0.5)
		t2 += 0.5
	until bag or t2 > 12

	if not bag then
		setStatus("❌ Tas kosong tidak ditemukan!", Color3.fromRGB(255,50,50))
		task.wait(1.5)
		isBusy = false
		return false
	end

	setStatus("🎒 Ambil Marshmallow...", Color3.fromRGB(255,200,0))
	equipTool(CFG.ITEM_EMPTY)
	task.wait(0.5)
	pressE()
	fireAllNearbyPrompts(6)

	setStatus("🎒 Tunggu MS masuk inventory...", Color3.fromRGB(255,180,0))
	local waitMS = 0
	local newS, newM, newL = 0, 0, 0
	repeat
		task.wait(0.4)
		waitMS += 0.4
		newS = countItem(CFG.ITEM_MS_SMALL)  - snapS
		newM = countItem(CFG.ITEM_MS_MEDIUM) - snapM
		newL = countItem(CFG.ITEM_MS_LARGE)  - snapL
	until (newS > 0 or newM > 0 or newL > 0) or waitMS > 8

	if newS > 0 then
		stats.small += newS
		setStatus("✅ Small MS Bag! (S:"..stats.small.." M:"..stats.medium.." L:"..stats.large..")", Color3.fromRGB(255,200,0))
	elseif newM > 0 then
		stats.medium += newM
		setStatus("✅ Medium MS Bag! (S:"..stats.small.." M:"..stats.medium.." L:"..stats.large..")", Color3.fromRGB(255,200,0))
	elseif newL > 0 then
		stats.large += newL
		setStatus("✅ Large MS Bag! (S:"..stats.small.." M:"..stats.medium.." L:"..stats.large..")", Color3.fromRGB(255,200,0))
	else
		local totalNow = countItem(CFG.ITEM_MS_SMALL) + countItem(CFG.ITEM_MS_MEDIUM) + countItem(CFG.ITEM_MS_LARGE)
		local totalBefore = snapS + snapM + snapL
		if totalNow > totalBefore then
			stats.small += (totalNow - totalBefore)
		else
			stats.small += 1
		end
		setStatus("✅ MS ke-"..(totalMS()).." selesai!", Color3.fromRGB(255,200,0))
	end
	task.wait(0.5)

	isBusy = false
	return true
end

local function autoLoop()
	while isRunning do
		if not hasAllIngredients() then
			setStatus("❌ Bahan habis!", Color3.fromRGB(255,50,50))
			isRunning = false
			break
		end
		doOneCook()
		if isRunning then task.wait(0.3) end
	end
end

-- ============================================================
-- GUI — HITAM + KUNING, 1 TAB (AUTO MS)
-- ============================================================

if playerGui:FindFirstChild("191FREE_GUI") then
	playerGui["191FREE_GUI"]:Destroy()
end

local sg = Instance.new("ScreenGui")
sg.Name           = "191FREE_GUI"
sg.ResetOnSpawn   = false
sg.IgnoreGuiInset = true
sg.DisplayOrder   = 10
sg.Parent         = playerGui

-- Warna HITAM + KUNING
local C = {
	bg      = Color3.fromRGB(10, 10, 12),
	panel   = Color3.fromRGB(15, 15, 20),
	card    = Color3.fromRGB(22, 22, 28),
	line    = Color3.fromRGB(45, 45, 55),
	yellow  = Color3.fromRGB(255, 200, 0),
	yellowD = Color3.fromRGB(200, 150, 0),
	yellowL = Color3.fromRGB(255, 220, 80),
	green   = Color3.fromRGB(46, 200, 100),
	red     = Color3.fromRGB(210, 40, 40),
	txt     = Color3.fromRGB(230, 230, 235),
	txtM    = Color3.fromRGB(160, 160, 175),
	txtD    = Color3.fromRGB(90, 90, 105),
}

-- Helpers
local function F(p, bg, zi)
	local f = Instance.new("Frame")
	f.BackgroundColor3 = bg or C.card
	f.BorderSizePixel  = 0
	f.ZIndex           = zi or 2
	if p then f.Parent = p end
	return f
end

local function T(p, txt, col, font, xAlign, zi, ts)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text           = txt or ""
	l.TextColor3     = col or C.txt
	l.Font           = font or Enum.Font.Gotham
	l.TextXAlignment = xAlign or Enum.TextXAlignment.Left
	l.ZIndex         = zi or 3
	if ts then l.TextScaled = false l.TextSize = ts
	else       l.TextScaled = true end
	if p then l.Parent = p end
	return l
end

local function B(p, txt, col, font, zi, ts)
	local b = Instance.new("TextButton")
	b.BackgroundTransparency = 1
	b.Text           = txt or ""
	b.TextColor3     = col or C.txt
	b.Font           = font or Enum.Font.Gotham
	b.ZIndex         = zi or 3
	if ts then b.TextScaled = false b.TextSize = ts
	else       b.TextScaled = true end
	if p then b.Parent = p end
	return b
end

local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = p
end

local function stroke(p, col, th)
	local s = Instance.new("UIStroke")
	s.Color     = col or C.line
	s.Thickness = th or 1
	s.Parent    = p
	return s
end

local function line(p, y)
	local d = F(p, C.line, 2)
	d.Size     = UDim2.new(1, 0, 0, 1)
	d.Position = UDim2.new(0, 0, 0, y)
end

local function secHdr(p, y, txt)
	local l = T(p, txt, C.yellow, Enum.Font.GothamBold, Enum.TextXAlignment.Left, 3, 12)
	l.Size     = UDim2.new(1, -32, 0, 18)
	l.Position = UDim2.new(0, 16, 0, y)
	return l
end

local function statRow(p, y, icon, lbl, valCol)
	local row = F(p, Color3.fromRGB(0,0,0), 2)
	row.BackgroundTransparency = 1
	row.Size     = UDim2.new(1, 0, 0, 36)
	row.Position = UDim2.new(0, 0, 0, y)

	local ic = T(row, icon, C.txt, Enum.Font.Gotham, Enum.TextXAlignment.Center, 3, 14)
	ic.Size     = UDim2.new(0, 26, 1, 0)
	ic.Position = UDim2.new(0, 10, 0, 0)

	local nm = T(row, lbl, C.txtM, Enum.Font.Gotham, Enum.TextXAlignment.Left, 3, 13)
	nm.Size     = UDim2.new(0.58, -36, 1, 0)
	nm.Position = UDim2.new(0, 38, 0, 0)

	local vl = T(row, "0", valCol or C.yellow, Enum.Font.GothamBold, Enum.TextXAlignment.Right, 3, 14)
	vl.Size     = UDim2.new(0.42, -12, 1, 0)
	vl.Position = UDim2.new(0.58, 0, 0, 0)

	return vl
end

local function actionBtn(p, y, txt, bg, txtC)
	local w = F(p, bg or C.yellowD, 3)
	w.Size     = UDim2.new(1, -32, 0, 38)
	w.Position = UDim2.new(0, 16, 0, y)
	corner(w, 6)
	local b = B(w, txt, txtC or Color3.fromRGB(10,10,15), Enum.Font.GothamBold, 4)
	b.Size = UDim2.new(1, 0, 1, 0)
	return w, b
end

-- ── PANEL ──────────────────────────────────────────────────
local PW, PH = 340, 420

local panel = F(sg, C.panel, 1)
panel.Name     = "Panel"
panel.Size     = UDim2.new(0, PW, 0, PH)
panel.Position = UDim2.new(0.5, -PW/2, 0.5, -PH/2)
corner(panel, 10)
stroke(panel, C.line, 1.5)

-- ── TITLE BAR ──────────────────────────────────────────────
local titleBar = F(panel, C.bg, 3)
titleBar.Size     = UDim2.new(1, 0, 0, 44)
titleBar.Position = UDim2.new(0, 0, 0, 0)
corner(titleBar, 10)

-- Logo dot kuning
local dot = F(titleBar, C.yellow, 4)
dot.Size     = UDim2.new(0, 8, 0, 8)
dot.Position = UDim2.new(0, 14, 0.5, -4)
corner(dot, 4)

local titleL = T(titleBar, "191 FREE", C.yellow, Enum.Font.GothamBold, Enum.TextXAlignment.Left, 4, 16)
titleL.Size     = UDim2.new(0.5, 0, 1, 0)
titleL.Position = UDim2.new(0, 30, 0, 0)

local verL = T(titleBar, "v1.0", C.txtD, Enum.Font.Gotham, Enum.TextXAlignment.Left, 4, 11)
verL.Size     = UDim2.new(0, 35, 1, 0)
verL.Position = UDim2.new(0, 100, 0, 0)

-- Close button
local closeW = F(titleBar, Color3.fromRGB(48, 48, 58), 4)
closeW.Size     = UDim2.new(0, 26, 0, 26)
closeW.Position = UDim2.new(1, -36, 0.5, -13)
corner(closeW, 6)
local closeB = B(closeW, "×", C.txtM, Enum.Font.GothamBold, 5)
closeB.Size       = UDim2.new(1, 0, 1, 0)
closeB.TextSize   = 16
closeB.TextScaled = false

closeB.MouseButton1Click:Connect(function()
	sg:Destroy()
end)
closeB.MouseEnter:Connect(function()
	TweenService:Create(closeW, TweenInfo.new(0.1), {BackgroundColor3 = C.red}):Play()
	closeB.TextColor3 = C.txt
end)
closeB.MouseLeave:Connect(function()
	TweenService:Create(closeW, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(48,48,58)}):Play()
	closeB.TextColor3 = C.txtM
end)

-- ── CONTENT ────────────────────────────────────────────────
local content = F(panel, C.panel, 2)
content.Size     = UDim2.new(1, 0, 1, -44)
content.Position = UDim2.new(0, 0, 0, 44)
content.ClipsDescendants = true

-- ============================================================
-- PAGE AUTO MS
-- ============================================================
secHdr(content, 14, "AUTO MASAK")

-- Status box
local statusCard = F(content, C.bg, 3)
statusCard.Size     = UDim2.new(1, -32, 0, 34)
statusCard.Position = UDim2.new(0, 16, 0, 40)
corner(statusCard, 6)

lblStatus = T(statusCard, "Siap digunakan", C.txtM, Enum.Font.Gotham,
	Enum.TextXAlignment.Center, 4, 12)
lblStatus.Size     = UDim2.new(1, -8, 1, 0)
lblStatus.Position = UDim2.new(0, 4, 0, 0)

line(content, 86)
secHdr(content, 94, "BAHAN TERSEDIA")

local vW  = statRow(content, 116, "💧", "Water",       C.yellow)
local vSu = statRow(content, 152, "🧂", "Sugar Bag",   C.yellow)
local vGe = statRow(content, 188, "🟡", "Gelatin",     C.yellow)
line(content, 226)

secHdr(content, 234, "HASIL MASAK")

-- Counter MS besar
local msCard = F(content, C.bg, 3)
msCard.Size     = UDim2.new(1, -32, 0, 52)
msCard.Position = UDim2.new(0, 16, 0, 254)
corner(msCard, 8)

local msBig = T(msCard, "0", C.yellow, Enum.Font.GothamBold,
	Enum.TextXAlignment.Center, 4, 28)
msBig.Size     = UDim2.new(0.5, 0, 1, 0)
msBig.Position = UDim2.new(0, 0, 0, 0)

local msSubL = T(msCard, "Marshmallow\ndibuat", C.txtM, Enum.Font.Gotham,
	Enum.TextXAlignment.Left, 4, 11)
msSubL.Size     = UDim2.new(0.5, -10, 1, 0)
msSubL.Position = UDim2.new(0.5, 0, 0, 0)

line(content, 318)

-- Tombol
local startW, startB = actionBtn(content, 328, "▶  START AUTO MASAK", C.yellowD, Color3.fromRGB(10,10,15))
local stopW, stopB   = actionBtn(content, 328, "■  STOP AUTO MASAK", C.red, Color3.fromRGB(255,255,255))
stopW.Visible = false

local function setRunUI(running)
	startW.Visible = not running
	stopW.Visible  = running
end

startB.MouseButton1Click:Connect(function()
	if isBusy then return end
	if not hasAllIngredients() then
		setStatus("❌ Bahan tidak lengkap!", C.red)
		return
	end
	isRunning = true
	setRunUI(true)
	setStatus("▶ Auto Masak berjalan...", C.yellow)
	task.spawn(function()
		autoLoop()
		setRunUI(false)
		if not isRunning then
			setStatus("⏹ Selesai / Dihentikan", C.txtM)
		end
	end)
end)

stopB.MouseButton1Click:Connect(function()
	isRunning = false
	isBusy    = false
	setRunUI(false)
	setStatus("⏹ Dihentikan", C.txtM)
end)

-- Hover effects
startB.MouseEnter:Connect(function()
	TweenService:Create(startW, TweenInfo.new(0.1), {BackgroundColor3 = C.yellowL}):Play()
end)
startB.MouseLeave:Connect(function()
	TweenService:Create(startW, TweenInfo.new(0.1), {BackgroundColor3 = C.yellowD}):Play()
end)
stopB.MouseEnter:Connect(function()
	TweenService:Create(stopW, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(210,36,36)}):Play()
end)
stopB.MouseLeave:Connect(function()
	TweenService:Create(stopW, TweenInfo.new(0.1), {BackgroundColor3 = C.red}):Play()
end)

-- ============================================================
-- DRAG
-- ============================================================
local dragging, dragInput, dragStart, startPos

titleBar.InputBegan:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1
	or i.UserInputType == Enum.UserInputType.Touch then
		dragging  = true
		dragStart = i.Position
		startPos  = panel.Position
		i.Changed:Connect(function()
			if i.UserInputState == Enum.UserInputState.End then
				dragging = false
			end
		end)
	end
end)

titleBar.InputChanged:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseMovement
	or i.UserInputType == Enum.UserInputType.Touch then
		dragInput = i
	end
end)

UIS.InputChanged:Connect(function(i)
	if i == dragInput and dragging then
		local d = i.Position - dragStart
		panel.Position = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + d.X,
			startPos.Y.Scale, startPos.Y.Offset + d.Y
		)
	end
end)

-- ============================================================
-- LIVE DISPLAY
-- ============================================================
RunService.Heartbeat:Connect(function()
	vW.Text    = tostring(countItem(CFG.ITEM_WATER))
	vSu.Text   = tostring(countItem(CFG.ITEM_SUGAR))
	vGe.Text   = tostring(countItem(CFG.ITEM_GEL))
	msBig.Text = tostring(totalMS())
end)

-- ============================================================
player.CharacterAdded:Connect(function(char)
	character = char
	hrp       = char:WaitForChild("HumanoidRootPart")
end)

print("[191 FREE v1] Loaded! Created by Jeranbian")
