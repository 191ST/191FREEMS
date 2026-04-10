-- ======================================================
--   JAWA HUB - AUTO MARSHMALLOW v6
--   StarterPlayer > StarterPlayerScripts (LocalScript)
-- ======================================================

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local VIM          = game:GetService("VirtualInputManager")
local UIS          = game:GetService("UserInputService")
local HttpService  = game:GetService("HttpService")

local player    = Players.LocalPlayer
local playerGui = player.PlayerGui
local character = player.Character or player.CharacterAdded:Wait()
local hrp       = character:WaitForChild("HumanoidRootPart")

-- ============================================================
-- AUTH SYSTEM
-- ============================================================
local ADMIN_WHITELIST = { "JeranBian" }

-- ============================================================
-- AUTH GUI
-- ============================================================

-- Warna auth (sama dengan main GUI)
local AC = {
	bg      = Color3.fromRGB(14, 14, 18),
	panel   = Color3.fromRGB(20, 20, 26),
	card    = Color3.fromRGB(28, 28, 36),
	input   = Color3.fromRGB(16, 16, 22),
	blue    = Color3.fromRGB(50, 118, 255),
	green   = Color3.fromRGB(46, 200, 100),
	red     = Color3.fromRGB(210, 40, 40),
	orange  = Color3.fromRGB(255, 155, 35),
	purple  = Color3.fromRGB(148, 52, 255),
	txt     = Color3.fromRGB(228, 228, 235),
	txtM    = Color3.fromRGB(155, 160, 178),
	txtD    = Color3.fromRGB(85, 90, 108),
	line    = Color3.fromRGB(38, 38, 50),
}

local authSG = Instance.new("ScreenGui")
authSG.Name           = "191FREE"
authSG.ResetOnSpawn   = false
authSG.IgnoreGuiInset = true
authSG.DisplayOrder   = 999
authSG.Parent         = playerGui


-- ============================================================
-- KONFIGURASI — sesuaikan jika nama berbeda di game kamu
-- ============================================================
local CFG = {
	WATER_WAIT    = 20,
	COOK_WAIT     = 46,

	-- Nama item bahan
	ITEM_WATER = "Water",
	ITEM_SUGAR = "Sugar Block Bag",
	ITEM_GEL   = "Gelatin",
	ITEM_EMPTY = "Empty Bag",

	-- Nama marshmallow sesuai ukuran di game (dari screenshot inventory)
	ITEM_MS_SMALL  = "Small Marshmallow Bag",
	ITEM_MS_MEDIUM = "Medium Marshmallow Bag",
	ITEM_MS_LARGE  = "Large Marshmallow Bag",

	-- Radius karakter harus berada di dekat NPC
	SELL_RADIUS  = 10,
	BUY_RADIUS   = 10,

	-- Timeout tunggu item berkurang setelah jual
	SELL_TIMEOUT = 8,

	-- Timeout tunggu dialog/GUI muncul setelah E ke NPC
	BUY_DIALOG_WAIT = 4,   -- detik tunggu GUI muncul
	BUY_ITEM_WAIT   = 2,   -- detik tunggu setelah klik item

	-- Keyword tombol konfirmasi dialog (huruf kecil, partial match)
	BUY_CONFIRM_KW = "yea",

	-- Item di menu toko (keyword huruf kecil, cocokkan dengan teks tombol di game)
	BUY_ITEMS = {
		{ keyword = "gelatin",  name = "Gelatin"        },
		{ keyword = "sugar",    name = "Sugar Block Bag" },  -- "Sugar Block" di menu
		{ keyword = "water",    name = "Water"           },  -- "Water" di menu
	},
}

-- ============================================================
-- STATE
-- ============================================================
local isRunning = false
local isBusy    = false
local totalSold = 0
local totalBuy  = 0
local stats     = { small = 0, medium = 0, large = 0 }

local function totalMS() return stats.small + stats.medium + stats.large end

-- ============================================================
-- CORE UTILITIES
-- ============================================================
local function pressE()
	-- Coba VIM dulu, fallback ke fireproximityprompt
	pcall(function()
		VIM:SendKeyEvent(true,  Enum.KeyCode.E, false, game)
		task.wait(0.15)
		VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
	end)
end

local function fireAllNearbyPrompts(radius)
	-- Fire SEMUA ProximityPrompt dalam radius tanpa filter keyword
	-- (karena kita tidak tahu nama prompt NPC di game)
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

-- Cari button berdasarkan Name object (bukan teks)
local function findButtonByName(guiName, btnName, timeout)
	local elapsed = 0
	timeout = timeout or 5
	while elapsed < timeout do
		for _, sg in ipairs(playerGui:GetChildren()) do
			if sg:IsA("ScreenGui") and (guiName == "" or sg.Name == guiName) then
				for _, obj in ipairs(sg:GetDescendants()) do
					if (obj:IsA("TextButton") or obj:IsA("ImageButton"))
						and obj.Visible
						and obj.Name == btnName then
						return obj
					end
				end
			end
		end
		task.wait(0.2)
		elapsed += 0.2
	end
	return nil
end

-- Cari SEMUA button dengan Name tertentu sekaligus
local function findAllButtonsByName(guiName, btnName)
	local list = {}
	for _, sg in ipairs(playerGui:GetChildren()) do
		if sg:IsA("ScreenGui") and (guiName == "" or sg.Name == guiName) then
			for _, obj in ipairs(sg:GetDescendants()) do
				if (obj:IsA("TextButton") or obj:IsA("ImageButton"))
					and obj.Visible
					and obj.Name == btnName then
					table.insert(list, obj)
				end
			end
		end
	end
	return list
end

-- Klik TextButton — pakai semua metode yang tersedia di executor
local function clickButton(btn)
	if not btn then return false end

	-- Metode 1: VIM SendMouseButtonEvent (paling umum di executor)
	pcall(function()
		local pos = btn.AbsolutePosition
		local sz  = btn.AbsoluteSize
		local cx  = math.floor(pos.X + sz.X / 2)
		local cy  = math.floor(pos.Y + sz.Y / 2)
		VIM:SendMouseButtonEvent(cx, cy, 0, true,  game, 0)
		task.wait(0.1)
		VIM:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
	end)
	task.wait(0.05)

	-- Metode 2: firebutton (executor function khusus TextButton)
	pcall(function()
		-- luau executor function
		local ok = firebutton ~= nil
		if ok then firebutton(btn) end
	end)

	-- Metode 3: Simulasi MouseButton1Click signal langsung
	pcall(function()
		btn.MouseButton1Click:Fire()
	end)

	-- Metode 4: Activate button
	pcall(function()
		btn:Activate()
	end)

	return true
end

-- ============================================================
-- AUTO JUAL
-- Logika:
--   Karakter HARUS sudah berdiri dekat NPC jual (dalam radius)
--   1. Equip 1 Marshmallow
--   2. Fire semua ProximityPrompt di sekitar + pressE
--   3. Tunggu MS berkurang (konfirmasi terjual)
--   4. Ulangi sampai inventory MS = 0
-- ============================================================
-- Ambil nama item MS pertama yang ada di inventory (small → medium → large)
local function getEquippableMS()
	if countItem(CFG.ITEM_MS_SMALL)  > 0 then return CFG.ITEM_MS_SMALL  end
	if countItem(CFG.ITEM_MS_MEDIUM) > 0 then return CFG.ITEM_MS_MEDIUM end
	if countItem(CFG.ITEM_MS_LARGE)  > 0 then return CFG.ITEM_MS_LARGE  end
	return nil
end

local function countAllMS()
	return countItem(CFG.ITEM_MS_SMALL)
		+ countItem(CFG.ITEM_MS_MEDIUM)
		+ countItem(CFG.ITEM_MS_LARGE)
end

local function doAutoSell(setStatus)
	local msTotal = countAllMS()

	if msTotal == 0 then
		setStatus("ℹ️ Tidak ada MS di inventory", Color3.fromRGB(160,160,180))
		return
	end

	setStatus("💰 Memulai jual "..msTotal.." MS...", Color3.fromRGB(50,210,110))
	task.wait(0.3)

	local sold       = 0
	local maxFail    = 5
	local failStreak = 0

	while countAllMS() > 0 do
		local msName = getEquippableMS()
		if not msName then break end

		-- Equip 1 marshmallow (tipe apapun yang ada)
		local equipped = equipTool(msName)
		if not equipped then
			failStreak += 1
			setStatus("❌ Gagal equip MS! ("..failStreak.."/"..maxFail..")", Color3.fromRGB(210,40,40))
			task.wait(1)
			if failStreak >= maxFail then break end
			continue
		end

		local beforeS = countItem(CFG.ITEM_MS_SMALL)
		local beforeM = countItem(CFG.ITEM_MS_MEDIUM)
		local beforeL = countItem(CFG.ITEM_MS_LARGE)

		-- Double fire: pressE + semua prompt dalam radius
		pressE()
		task.wait(0.1)
		fireAllNearbyPrompts(CFG.SELL_RADIUS)
		task.wait(0.1)
		pressE()

		-- Tunggu salah satu jenis MS berkurang
		local elapsed = 0
		local terjual = false
		while elapsed < CFG.SELL_TIMEOUT do
			local diffS = beforeS - countItem(CFG.ITEM_MS_SMALL)
			local diffM = beforeM - countItem(CFG.ITEM_MS_MEDIUM)
			local diffL = beforeL - countItem(CFG.ITEM_MS_LARGE)
			local diff  = diffS + diffM + diffL
			if diff > 0 then
				sold      += diff
				totalSold += diff
				terjual    = true
				failStreak = 0
				break
			end
			task.wait(0.25)
			elapsed += 0.25
		end

		if terjual then
			setStatus("💰 Terjual "..sold.." | Sisa: "..countAllMS().." MS",
				Color3.fromRGB(50,210,110))
			task.wait(0.2)
		else
			failStreak += 1
			setStatus("⚠️ Tidak terjual ("..failStreak.."/"..maxFail..") — Pastikan dekat NPC!",
				Color3.fromRGB(255,155,35))
			task.wait(1)
			if failStreak >= maxFail then
				setStatus("❌ Gagal jual. Dekati NPC jual!", Color3.fromRGB(210,40,40))
				break
			end
		end
	end

	unequipAll()

	if sold > 0 then
		setStatus("✅ Selesai! Terjual "..sold.." MS (total: "..totalSold..")",
			Color3.fromRGB(50,210,110))
	else
		setStatus("⚠️ Tidak ada MS terjual. Pastikan di dekat NPC!", Color3.fromRGB(255,155,35))
	end
	task.wait(1)
end

-- ============================================================
-- AUTO BELI BAHAN
-- Logika:
--   Karakter HARUS sudah berdiri dekat NPC toko (dalam radius)
--   1. Tekan E / fire prompt → tunggu GUI dialog muncul
--   2. Klik "Ya kamu orangnya?"
--   3. Tunggu GUI toko muncul
--   4. Klik tiap item (Gelatin, Gula, Air)
--   5. Klik KELUAR / tutup
-- ============================================================
-- ============================================================
-- AUTO BELI — PASIF: detect GUI Shop otomatis saat terbuka
-- Player buka shop sendiri (E ke NPC → klik "Yea")
-- Script detect GUI Shop lalu auto klik semua item sejumlah qty
-- ============================================================
local buyQty       = { 1, 1, 1 }  -- qty per item [1]=item1, [2]=item2, [3]=item3
local shopWatching = false         -- apakah sedang monitor Shop GUI
local buyBusy      = false

local function runShopBuy(setStatus)
	-- Tunggu GUI Shop muncul (max 30 detik, player buka sendiri)
	setStatus("👀 Menunggu GUI Shop terbuka...", Color3.fromRGB(100,180,255))
	local shopOpen = false
	local elapsed  = 0
	repeat
		task.wait(0.3)
		elapsed += 0.3
		local items = findAllButtonsByName("Shop", "PurchaseableItem")
		if #items > 0 then shopOpen = true break end
	until elapsed > 30

	if not shopOpen then
		setStatus("⏰ Timeout. GUI Shop tidak terbuka.", Color3.fromRGB(255,155,35))
		return
	end

	task.wait(0.3) -- buffer setelah shop terbuka

	-- Ambil semua PurchaseableItem
	local items = findAllButtonsByName("Shop", "PurchaseableItem")
	setStatus("🛒 Shop terbuka! "..#items.." item ditemukan.", Color3.fromRGB(80,220,130))
	task.wait(0.4)

	local bought = 0
	for idx, itemBtn in ipairs(items) do
		local qty = buyQty[idx] or 1
		setStatus("🛒 Beli item "..idx.." × "..qty.."...", Color3.fromRGB(100,180,255))

		for q = 1, qty do
			-- Cek tombol masih ada dan visible
			if not itemBtn or not itemBtn.Parent or not itemBtn.Visible then
				-- Coba cari ulang
				local refreshed = findAllButtonsByName("Shop", "PurchaseableItem")
				itemBtn = refreshed[idx]
				if not itemBtn then break end
			end
			clickButton(itemBtn)
			task.wait(0.5)
			bought += 1
		end
		totalBuy += qty
		setStatus("✅ Item "..idx.." selesai (×"..qty..")", Color3.fromRGB(80,220,130))
		task.wait(0.3)
	end

	-- Tutup shop (klik Exit)
	task.wait(0.2)
	local exitBtn = findButtonByName("Shop", "Exit", 3)
	if exitBtn then
		clickButton(exitBtn)
		setStatus("✅ Shop ditutup. Total beli: "..bought.."x", Color3.fromRGB(80,220,130))
	else
		setStatus("✅ Selesai! Total beli: "..bought.."x (tutup manual)", Color3.fromRGB(80,220,130))
	end
	task.wait(1)
end

-- ============================================================
-- AUTO MASAK
-- ============================================================
local lblStatus  -- forward declare

local function setStatus(msg, color)
	if lblStatus then
		lblStatus.Text       = msg
		lblStatus.TextColor3 = color or Color3.fromRGB(155,165,200)
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

	-- Snapshot inventory MS sebelum masak
	local snapS = countItem(CFG.ITEM_MS_SMALL)
	local snapM = countItem(CFG.ITEM_MS_MEDIUM)
	local snapL = countItem(CFG.ITEM_MS_LARGE)

	setStatus("💧 Water...", Color3.fromRGB(100,180,255))
	equipTool(CFG.ITEM_WATER)
	task.wait(0.5)
	pressE()
	fireAllNearbyPrompts(6)
	task.wait(0.7)

	if not countdown(CFG.WATER_WAIT, "💧 Mendidih... ⏱ %ds", Color3.fromRGB(80,150,255)) then
		isBusy = false return false
	end

	setStatus("🧂 Sugar Bag...", Color3.fromRGB(255,220,100))
	equipTool(CFG.ITEM_SUGAR)
	task.wait(0.5)
	pressE()
	fireAllNearbyPrompts(6)
	task.wait(2)

	setStatus("🟡 Gelatin...", Color3.fromRGB(255,200,50))
	equipTool(CFG.ITEM_GEL)
	task.wait(0.5)
	pressE()
	fireAllNearbyPrompts(6)
	task.wait(1)

	if not countdown(CFG.COOK_WAIT, "🔥 Memasak... ⏱ %ds", Color3.fromRGB(80,140,255)) then
		isBusy = false return false
	end

	-- Tunggu Empty Bag
	setStatus("🎒 Tunggu Tas Kosong...", Color3.fromRGB(100,160,255))
	local bag, t2 = nil, 0
	repeat
		bag = player.Backpack:FindFirstChild(CFG.ITEM_EMPTY)
		task.wait(0.5)
		t2 += 0.5
	until bag or t2 > 12

	if not bag then
		setStatus("❌ Tas kosong tidak ditemukan!", Color3.fromRGB(210,40,40))
		task.wait(1.5)
		isBusy = false
		return false
	end

	setStatus("🎒 Ambil Marshmallow...", Color3.fromRGB(100,180,255))
	equipTool(CFG.ITEM_EMPTY)
	task.wait(0.5)
	pressE()
	fireAllNearbyPrompts(6)

	-- Tunggu sampai ada MS baru masuk inventory (max 8 detik)
	setStatus("🎒 Tunggu MS masuk inventory...", Color3.fromRGB(100,160,255))
	local waitMS = 0
	local newS, newM, newL = 0, 0, 0
	repeat
		task.wait(0.4)
		waitMS += 0.4
		newS = countItem(CFG.ITEM_MS_SMALL)  - snapS
		newM = countItem(CFG.ITEM_MS_MEDIUM) - snapM
		newL = countItem(CFG.ITEM_MS_LARGE)  - snapL
	until (newS > 0 or newM > 0 or newL > 0) or waitMS > 8

	-- Catat jenis MS yang masuk
	if newS > 0 then
		stats.small += newS
		setStatus("✅ Small MS Bag! (S:"..stats.small.." M:"..stats.medium.." L:"..stats.large..")", Color3.fromRGB(80,210,255))
	elseif newM > 0 then
		stats.medium += newM
		setStatus("✅ Medium MS Bag! (S:"..stats.small.." M:"..stats.medium.." L:"..stats.large..")", Color3.fromRGB(80,210,255))
	elseif newL > 0 then
		stats.large += newL
		setStatus("✅ Large MS Bag! (S:"..stats.small.." M:"..stats.medium.." L:"..stats.large..")", Color3.fromRGB(80,210,255))
	else
		-- Tidak terdeteksi, hitung manual dari total yang ada sekarang
		local totalNow = countAllMS()
		local totalBefore = snapS + snapM + snapL
		if totalNow > totalBefore then
			stats.small += (totalNow - totalBefore)
		else
			stats.small += 1 -- fallback
		end
		setStatus("✅ MS ke-"..(totalMS()).." selesai! (tipe tidak terdeteksi)", Color3.fromRGB(80,210,255))
	end
	task.wait(0.5)

	isBusy = false
	return true
end

local function autoLoop()
	while isRunning do
		if not hasAllIngredients() then
			setStatus("❌ Bahan habis! Gunakan Auto Beli.", Color3.fromRGB(210,40,40))
			isRunning = false
			break
		end
		doOneCook()
		if isRunning then task.wait(0.3) end
	end
end

-- ============================================================
-- GUI  — CloudWare style, 4 tab
-- ============================================================

if playerGui:FindFirstChild("JawaHubGUI") then
	playerGui.JawaHubGUI:Destroy()
end

local sg = Instance.new("ScreenGui")
sg.Name           = "JawaHubGUI"
sg.ResetOnSpawn   = false
sg.IgnoreGuiInset = true
sg.DisplayOrder   = 10
sg.Parent         = playerGui

-- Warna
local C = {
	bg      = Color3.fromRGB(20, 20, 24),
	panel   = Color3.fromRGB(25, 25, 30),
	card    = Color3.fromRGB(32, 32, 40),
	tabBg   = Color3.fromRGB(18, 18, 22),
	line    = Color3.fromRGB(42, 42, 52),
	blue    = Color3.fromRGB(50, 118, 255),
	blueL   = Color3.fromRGB(72, 142, 255),
	green   = Color3.fromRGB(46, 200, 100),
	red     = Color3.fromRGB(210, 40, 40),
	orange  = Color3.fromRGB(255, 155, 35),
	txt     = Color3.fromRGB(228, 228, 235),
	txtM    = Color3.fromRGB(158, 162, 178),
	txtD    = Color3.fromRGB(88, 92, 108),
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
	local l = T(p, txt, C.txtD, Enum.Font.GothamBold, Enum.TextXAlignment.Left, 3, 11)
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

	local vl = T(row, "0", valCol or C.blue, Enum.Font.GothamBold, Enum.TextXAlignment.Right, 3, 14)
	vl.Size     = UDim2.new(0.42, -12, 1, 0)
	vl.Position = UDim2.new(0.58, 0, 0, 0)

	return vl
end

local function actionBtn(p, y, txt, bg, txtC)
	local w = F(p, bg or C.blue, 3)
	w.Size     = UDim2.new(1, -32, 0, 38)
	w.Position = UDim2.new(0, 16, 0, y)
	corner(w, 6)
	local b = B(w, txt, txtC or Color3.fromRGB(255,255,255), Enum.Font.GothamBold, 4)
	b.Size = UDim2.new(1, 0, 1, 0)
	return w, b
end

-- ── PANEL ──────────────────────────────────────────────────
local PW, PH = 340, 490

local panel = F(sg, C.panel, 1)
panel.Name     = "Panel"
panel.Size     = UDim2.new(0, PW, 0, PH)
panel.Position = UDim2.new(0, 14, 0.5, -PH/2)
corner(panel, 10)
stroke(panel, C.line, 1.5)

-- ── TITLE BAR ──────────────────────────────────────────────
local titleBar = F(panel, C.bg, 3)
titleBar.Size     = UDim2.new(1, 0, 0, 44)
titleBar.Position = UDim2.new(0, 0, 0, 0)
corner(titleBar, 10)

-- Logo dot biru
local dot = F(titleBar, C.blue, 4)
dot.Size     = UDim2.new(0, 8, 0, 8)
dot.Position = UDim2.new(0, 14, 0.5, -4)
corner(dot, 4)

local titleL = T(titleBar, "BLDWHUB", C.txt, Enum.Font.GothamBold, Enum.TextXAlignment.Left, 4, 15)
titleL.Size     = UDim2.new(0.5, 0, 1, 0)
titleL.Position = UDim2.new(0, 30, 0, 0)

local verL = T(titleBar, "v6.0", C.txtD, Enum.Font.Gotham, Enum.TextXAlignment.Left, 4, 11)
verL.Size     = UDim2.new(0, 30, 1, 0)
verL.Position = UDim2.new(0, 92, 0, 0)

-- Close
local closeW = F(titleBar, Color3.fromRGB(48, 48, 58), 4)
closeW.Size     = UDim2.new(0, 26, 0, 26)
closeW.Position = UDim2.new(1, -36, 0.5, -13)
corner(closeW, 6)
local closeB = B(closeW, "×", C.txtM, Enum.Font.GothamBold, 5)
closeB.Size     = UDim2.new(1, 0, 1, 0)
closeB.TextSize = 16
closeB.TextScaled = false

closeB.MouseButton1Click:Connect(function()
	panel.Visible = not panel.Visible
end)
closeB.MouseEnter:Connect(function()
	TweenService:Create(closeW, TweenInfo.new(0.1), {BackgroundColor3 = C.red}):Play()
	closeB.TextColor3 = C.txt
end)
closeB.MouseLeave:Connect(function()
	TweenService:Create(closeW, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(48,48,58)}):Play()
	closeB.TextColor3 = C.txtM
end)

-- ── TAB BAR ────────────────────────────────────────────────
local tabBar = F(panel, C.tabBg, 3)
tabBar.Size     = UDim2.new(1, 0, 0, 34)
tabBar.Position = UDim2.new(0, 0, 0, 44)
line(panel, 78)

local TABS    = { "MASAK", "JUAL", "BELI", "STATS" }
local tabBtns = {}
local pages   = {}
local tw      = PW / #TABS

for i, name in ipairs(TABS) do
	-- Tab button
	local tb = B(tabBar, name, C.txtD, Enum.Font.GothamBold, 4, 12)
	tb.BackgroundTransparency = 0
	tb.BackgroundColor3       = C.tabBg
	tb.Size     = UDim2.new(0, tw, 1, 0)
	tb.Position = UDim2.new(0, (i-1)*tw, 0, 0)
	tabBtns[i]  = tb

	-- Underline
	local ul = F(tb, C.blue, 5)
	ul.Name     = "UL"
	ul.Size     = UDim2.new(0.65, 0, 0, 2)
	ul.Position = UDim2.new(0.175, 0, 1, -2)
	ul.Visible  = (i == 1)

	-- Page
	local pg = F(panel, C.panel, 2)
	pg.Size     = UDim2.new(1, 0, 1, -78)
	pg.Position = UDim2.new(0, 0, 0, 78)
	pg.Visible  = (i == 1)
	pg.ClipsDescendants = true
	pages[i] = pg
end

local function switchTab(idx)
	for i = 1, #TABS do
		pages[i].Visible = (i == idx)
		tabBtns[i].TextColor3 = (i == idx) and C.txt or C.txtD
		local ul = tabBtns[i]:FindFirstChild("UL")
		if ul then ul.Visible = (i == idx) end
	end
end
for i, tb in ipairs(tabBtns) do
	tb.MouseButton1Click:Connect(function() switchTab(i) end)
end

-- ============================================================
-- PAGE 1 — MASAK
-- ============================================================
local pg1 = pages[1]

-- Status box
local statusCard = F(pg1, C.bg, 3)
statusCard.Size     = UDim2.new(1, -32, 0, 34)
statusCard.Position = UDim2.new(0, 16, 0, 14)
corner(statusCard, 6)

lblStatus = T(statusCard, "Siap digunakan", C.txtM, Enum.Font.Gotham,
	Enum.TextXAlignment.Center, 4, 12)
lblStatus.Size     = UDim2.new(1, -8, 1, 0)
lblStatus.Position = UDim2.new(0, 4, 0, 0)

line(pg1, 60)
secHdr(pg1, 68, "BAHAN TERSEDIA")

local vW  = statRow(pg1,  90, "💧", "Water",       Color3.fromRGB(130,200,255))
local vSu = statRow(pg1, 126, "🧂", "Sugar Bag",   Color3.fromRGB(255,228,115))
local vGe = statRow(pg1, 162, "🟡", "Gelatin",     Color3.fromRGB(255,195,65))
line(pg1, 200)

secHdr(pg1, 208, "HASIL MASAK")

-- Counter MS besar
local msCard = F(pg1, C.bg, 3)
msCard.Size     = UDim2.new(1, -32, 0, 52)
msCard.Position = UDim2.new(0, 16, 0, 228)
corner(msCard, 8)

local msBig = T(msCard, "0", C.blue, Enum.Font.GothamBold,
	Enum.TextXAlignment.Center, 4, 28)
msBig.Size     = UDim2.new(0.5, 0, 1, 0)
msBig.Position = UDim2.new(0, 0, 0, 0)

local msSubL = T(msCard, "Marshmallow\ndibuat", C.txtM, Enum.Font.Gotham,
	Enum.TextXAlignment.Left, 4, 11)
msSubL.Size     = UDim2.new(0.5, -10, 1, 0)
msSubL.Position = UDim2.new(0.5, 0, 0, 0)

line(pg1, 292)

-- Tombol
local startW, startB = actionBtn(pg1, 302, "▶  Start Auto Masak",
	Color3.fromRGB(34, 92, 215), Color3.fromRGB(210,228,255))
local stopW, stopB   = actionBtn(pg1, 302, "■  Stop Auto Masak",
	Color3.fromRGB(175, 28, 28), Color3.fromRGB(255,210,210))
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
	setStatus("▶ Auto Masak berjalan...", C.blue)
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

-- hover
startB.MouseEnter:Connect(function()
	TweenService:Create(startW, TweenInfo.new(0.1),
		{BackgroundColor3 = Color3.fromRGB(44,108,245)}):Play()
end)
startB.MouseLeave:Connect(function()
	TweenService:Create(startW, TweenInfo.new(0.1),
		{BackgroundColor3 = Color3.fromRGB(34,92,215)}):Play()
end)
stopB.MouseEnter:Connect(function()
	TweenService:Create(stopW, TweenInfo.new(0.1),
		{BackgroundColor3 = Color3.fromRGB(210,36,36)}):Play()
end)
stopB.MouseLeave:Connect(function()
	TweenService:Create(stopW, TweenInfo.new(0.1),
		{BackgroundColor3 = Color3.fromRGB(175,28,28)}):Play()
end)

-- ============================================================
-- PAGE 2 — JUAL
-- ============================================================
local pg2 = pages[2]

secHdr(pg2, 14, "AUTO JUAL MARSHMALLOW")

-- Info box
local jualInfo = F(pg2, C.bg, 3)
jualInfo.Size     = UDim2.new(1, -32, 0, 54)
jualInfo.Position = UDim2.new(0, 16, 0, 34)
corner(jualInfo, 6)

local jualInfoT = T(jualInfo,
	"Pastikan karakter sudah berdiri\ndekat NPC Jual, lalu tekan tombol.\nScript equip MS → tekan E otomatis.",
	C.txtM, Enum.Font.Gotham, Enum.TextXAlignment.Left, 4, 11)
jualInfoT.Size        = UDim2.new(1, -10, 1, 0)
jualInfoT.Position    = UDim2.new(0, 8, 0, 0)
jualInfoT.TextWrapped = true

line(pg2, 100)
secHdr(pg2, 108, "STATISTIK")

local vSold = statRow(pg2, 130, "💰", "Total Terjual",    Color3.fromRGB(46,200,100))
local vMSInv = statRow(pg2, 166, "🍬", "MS di Inventory", Color3.fromRGB(100,180,255))

line(pg2, 205)

-- Status jual
local jualStatBox = F(pg2, C.bg, 3)
jualStatBox.Size     = UDim2.new(1, -32, 0, 28)
jualStatBox.Position = UDim2.new(0, 16, 0, 214)
corner(jualStatBox, 6)

local jualStatL = T(jualStatBox, "", C.txtM, Enum.Font.Gotham,
	Enum.TextXAlignment.Center, 4, 11)
jualStatL.Size     = UDim2.new(1, -8, 1, 0)
jualStatL.Position = UDim2.new(0, 4, 0, 0)

line(pg2, 254)

local jualBtnW, jualBtnB = actionBtn(pg2, 264,
	"💰  Jual Semua Marshmallow",
	Color3.fromRGB(28, 136, 66), Color3.fromRGB(210,255,225))

local jualBusy = false
local function setJualStatus(msg, col)
	jualStatL.Text       = msg
	jualStatL.TextColor3 = col or C.txtM
	setStatus(msg, col)
end

jualBtnB.MouseButton1Click:Connect(function()
	if jualBusy then return end
	jualBusy = true
	jualBtnW.BackgroundColor3 = Color3.fromRGB(18, 88, 42)
	jualBtnB.Text = "⏳  Menjual..."
	task.spawn(function()
		doAutoSell(setJualStatus)
		jualBtnW.BackgroundColor3 = Color3.fromRGB(28,136,66)
		jualBtnB.Text = "💰  Jual Semua Marshmallow"
		jualBusy = false
	end)
end)
jualBtnB.MouseEnter:Connect(function()
	if not jualBusy then
		TweenService:Create(jualBtnW, TweenInfo.new(0.1),
			{BackgroundColor3 = Color3.fromRGB(36,160,78)}):Play()
	end
end)
jualBtnB.MouseLeave:Connect(function()
	if not jualBusy then
		TweenService:Create(jualBtnW, TweenInfo.new(0.1),
			{BackgroundColor3 = Color3.fromRGB(28,136,66)}):Play()
	end
end)

-- ============================================================
-- PAGE 3 — BELI
-- ============================================================
local pg3 = pages[3]

secHdr(pg3, 14, "AUTO BELI BAHAN")

-- Info box — instruksi baru
local beliInfo = F(pg3, C.bg, 3)
beliInfo.Size     = UDim2.new(1, -32, 0, 42)
beliInfo.Position = UDim2.new(0, 16, 0, 34)
corner(beliInfo, 6)
local beliInfoT = T(beliInfo,
	"1. Tekan Aktifkan  2. Buka shop manual (E → Yea)\n3. Script otomatis beli semua item",
	C.txtM, Enum.Font.Gotham, Enum.TextXAlignment.Left, 4, 11)
beliInfoT.Size        = UDim2.new(1, -10, 1, 0)
beliInfoT.Position    = UDim2.new(0, 8, 0, 0)
beliInfoT.TextWrapped = true

line(pg3, 86)
secHdr(pg3, 94, "JUMLAH BELI PER ITEM")

-- Item rows dengan +/- control
local itemData = {
	{ icon = "🟡", name = "Gelatin",        price = "$70"  },
	{ icon = "🧂", name = "Sugar Block Bag", price = "$100" },
	{ icon = "💧", name = "Water",           price = "$20"  },
}

local qtyLabels = {}

for i, item in ipairs(itemData) do
	local ry = 116 + (i-1) * 46
	local row = F(pg3, C.card, 3)
	row.Size     = UDim2.new(1, -32, 0, 40)
	row.Position = UDim2.new(0, 16, 0, ry)
	corner(row, 6)

	-- Icon
	local ic = T(row, item.icon, C.txt, Enum.Font.Gotham, Enum.TextXAlignment.Center, 4, 14)
	ic.Size     = UDim2.new(0, 26, 1, 0)
	ic.Position = UDim2.new(0, 4, 0, 0)

	-- Nama
	local nm = T(row, item.name, C.txt, Enum.Font.Gotham, Enum.TextXAlignment.Left, 4, 11)
	nm.Size     = UDim2.new(0.45, -30, 1, 0)
	nm.Position = UDim2.new(0, 32, 0, 0)

	-- Harga
	local pr = T(row, item.price, C.txtD, Enum.Font.Gotham, Enum.TextXAlignment.Left, 4, 10)
	pr.Size     = UDim2.new(0.2, 0, 1, 0)
	pr.Position = UDim2.new(0.45, 0, 0, 0)

	-- Tombol minus
	local minusW = F(row, Color3.fromRGB(50,50,62), 4)
	minusW.Size     = UDim2.new(0, 26, 0, 26)
	minusW.Position = UDim2.new(1, -86, 0.5, -13)
	corner(minusW, 5)
	local minusB = B(minusW, "−", C.txt, Enum.Font.GothamBold, 5, 16)
	minusB.Size = UDim2.new(1, 0, 1, 0)

	-- Qty label
	local qtyLbl = T(row, tostring(buyQty[i]), C.blue, Enum.Font.GothamBold,
		Enum.TextXAlignment.Center, 4, 14)
	qtyLbl.Size     = UDim2.new(0, 28, 1, 0)
	qtyLbl.Position = UDim2.new(1, -58, 0, 0)
	qtyLabels[i]    = qtyLbl

	-- Tombol plus
	local plusW = F(row, Color3.fromRGB(50,50,62), 4)
	plusW.Size     = UDim2.new(0, 26, 0, 26)
	plusW.Position = UDim2.new(1, -30, 0.5, -13)
	corner(plusW, 5)
	local plusB = B(plusW, "+", C.txt, Enum.Font.GothamBold, 5, 16)
	plusB.Size = UDim2.new(1, 0, 1, 0)

	-- Events +/-
	local idx = i
	minusB.MouseButton1Click:Connect(function()
		if buyQty[idx] > 1 then
			buyQty[idx] -= 1
			qtyLabels[idx].Text = tostring(buyQty[idx])
		end
	end)
	plusB.MouseButton1Click:Connect(function()
		if buyQty[idx] < 99 then
			buyQty[idx] += 1
			qtyLabels[idx].Text = tostring(buyQty[idx])
		end
	end)

	-- Hover +/-
	minusB.MouseEnter:Connect(function()
		TweenService:Create(minusW,TweenInfo.new(0.1),{BackgroundColor3=Color3.fromRGB(70,70,85)}):Play()
	end)
	minusB.MouseLeave:Connect(function()
		TweenService:Create(minusW,TweenInfo.new(0.1),{BackgroundColor3=Color3.fromRGB(50,50,62)}):Play()
	end)
	plusB.MouseEnter:Connect(function()
		TweenService:Create(plusW,TweenInfo.new(0.1),{BackgroundColor3=Color3.fromRGB(70,70,85)}):Play()
	end)
	plusB.MouseLeave:Connect(function()
		TweenService:Create(plusW,TweenInfo.new(0.1),{BackgroundColor3=Color3.fromRGB(50,50,62)}):Play()
	end)
end

line(pg3, 260)
secHdr(pg3, 268, "STATISTIK")
local vBuy = statRow(pg3, 288, "🛒", "Total Beli", Color3.fromRGB(100,180,255))
line(pg3, 326)

-- Status beli
local beliStatBox = F(pg3, C.bg, 3)
beliStatBox.Size     = UDim2.new(1, -32, 0, 28)
beliStatBox.Position = UDim2.new(0, 16, 0, 336)
corner(beliStatBox, 6)
local beliStatL = T(beliStatBox, "Tekan Aktifkan lalu buka shop", C.txtM,
	Enum.Font.Gotham, Enum.TextXAlignment.Center, 4, 11)
beliStatL.Size     = UDim2.new(1, -8, 1, 0)
beliStatL.Position = UDim2.new(0, 4, 0, 0)

line(pg3, 376)

-- Tombol Aktifkan / Batal
local beliAktifW, beliAktifB = actionBtn(pg3, 386,
	"👀  Aktifkan Auto Beli",
	Color3.fromRGB(20, 68, 175), Color3.fromRGB(210,225,255))
local beliBatalW, beliBatalB = actionBtn(pg3, 386,
	"⏹  Batalkan",
	Color3.fromRGB(140, 25, 25), Color3.fromRGB(255,210,210))
beliBatalW.Visible = false

local function setBeliStatus(msg, col)
	beliStatL.Text       = msg
	beliStatL.TextColor3 = col or C.txtM
	setStatus(msg, col)
end

beliAktifB.MouseButton1Click:Connect(function()
	if buyBusy then return end
	buyBusy = true
	beliAktifW.Visible = false
	beliBatalW.Visible = true
	setBeliStatus("👀 Menunggu GUI Shop terbuka...", Color3.fromRGB(100,180,255))
	task.spawn(function()
		runShopBuy(setBeliStatus)
		beliAktifW.Visible = true
		beliBatalW.Visible = false
		buyBusy = false
	end)
end)

beliBatalB.MouseButton1Click:Connect(function()
	buyBusy = false
	beliAktifW.Visible = true
	beliBatalW.Visible = false
	setBeliStatus("⏹ Dibatalkan", C.txtM)
end)

-- hover
beliAktifB.MouseEnter:Connect(function()
	if not buyBusy then
		TweenService:Create(beliAktifW,TweenInfo.new(0.1),{BackgroundColor3=Color3.fromRGB(28,84,205)}):Play()
	end
end)
beliAktifB.MouseLeave:Connect(function()
	if not buyBusy then
		TweenService:Create(beliAktifW,TweenInfo.new(0.1),{BackgroundColor3=Color3.fromRGB(20,68,175)}):Play()
	end
end)

-- ============================================================
-- PAGE 4 — STATS
-- ============================================================
local pg4 = pages[4]

secHdr(pg4, 14, "STATISTIK SESSION")

local sData = {
	{ icon="🍬", lbl="Total MS Dibuat",   col=Color3.fromRGB(100,190,255) },
	{ icon="🔹", lbl="Small MS",          col=Color3.fromRGB(130,205,255) },
	{ icon="🔷", lbl="Medium MS",         col=Color3.fromRGB(80, 160,255) },
	{ icon="🔵", lbl="Large MS",          col=Color3.fromRGB(55, 115,220) },
	{ icon="💰", lbl="Total MS Terjual",  col=Color3.fromRGB(46,200,100)  },
	{ icon="🛒", lbl="Total Beli Bahan",  col=Color3.fromRGB(100,180,255) },
}

local sVals = {}
for i, s in ipairs(sData) do
	local y = 36 + (i-1) * 38
	local v = statRow(pg4, y, s.icon, s.lbl, s.col)
	sVals[i] = v
	if i < #sData then line(pg4, y+36) end
end

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
	-- Page 1
	vW.Text    = tostring(countItem(CFG.ITEM_WATER))
	vSu.Text   = tostring(countItem(CFG.ITEM_SUGAR))
	vGe.Text   = tostring(countItem(CFG.ITEM_GEL))
	msBig.Text = tostring(totalMS())

	-- Page 2
	vSold.Text  = tostring(totalSold)
	vMSInv.Text = tostring(countAllMS())

	-- Page 3
	vBuy.Text = tostring(totalBuy)

	-- Page 4
	sVals[1].Text = tostring(totalMS())
	sVals[2].Text = tostring(stats.small)
	sVals[3].Text = tostring(stats.medium)
	sVals[4].Text = tostring(stats.large)
	sVals[5].Text = tostring(totalSold)
	sVals[6].Text = tostring(totalBuy)
end)

-- ============================================================
player.CharacterAdded:Connect(function(char)
	character = char
	hrp       = char:WaitForChild("HumanoidRootPart")
end)

print("[JawaHub v6.1] Loaded! Small/Medium/Large MS tracking fixed")
