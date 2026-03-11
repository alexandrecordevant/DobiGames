-- StarterPlayer/StarterPlayerScripts/RebirthClient.client.lua
-- Interface Rebirth complète — créée par Instance.new, parentée dans PlayerGui

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
print("[RebirthClient] PlayerGui trouvé ✓")

-- ═══════════════════════════════════════════════
-- 1. REMOTES (attendus depuis RebirthServer)
-- ═══════════════════════════════════════════════

local rfGetRebirthData = ReplicatedStorage:WaitForChild("GetRebirthData", 15)
local reRequestRebirth = ReplicatedStorage:WaitForChild("RequestRebirth",  15)
local reRebirthResult  = ReplicatedStorage:WaitForChild("RebirthResult",   15)

if not rfGetRebirthData or not reRequestRebirth or not reRebirthResult then
	warn("[RebirthClient] Remotes introuvables — vérifier RebirthServer.server.lua")
	return
end

-- ═══════════════════════════════════════════════
-- 2. ÉTAT LOCAL
-- ═══════════════════════════════════════════════

local menuOuvert      = false
local rebirthEnCours  = false
local dernierPayload  = nil   -- dernière réponse serveur

-- ═══════════════════════════════════════════════
-- 3. PALETTE DE COULEURS
-- ═══════════════════════════════════════════════

local C = {
	BG          = Color3.fromRGB(13,  13,  20 ),
	CARD        = Color3.fromRGB(20,  20,  32 ),
	SECTION     = Color3.fromRGB(28,  28,  44 ),
	BORDER      = Color3.fromRGB(55,  55,  80 ),
	ORANGE      = Color3.fromRGB(255, 107, 0  ),
	ORANGE_DARK = Color3.fromRGB(200, 80,  0  ),
	GREEN       = Color3.fromRGB(50,  210, 90 ),
	GREEN_DARK  = Color3.fromRGB(35,  140, 60 ),
	RED         = Color3.fromRGB(220, 50,  50 ),
	WHITE       = Color3.fromRGB(240, 240, 250),
	MUTED       = Color3.fromRGB(140, 140, 165),
	BAR_BG      = Color3.fromRGB(35,  35,  52 ),
	RARITY = {
		Common    = Color3.fromRGB(200, 200, 200),
		Uncommon  = Color3.fromRGB(80,  210, 100),
		Rare      = Color3.fromRGB(100, 130, 255),
		Epic      = Color3.fromRGB(180, 50,  255),
		Legendary = Color3.fromRGB(255, 200, 0  ),
		Secret    = Color3.fromRGB(255, 50,  50 ),
	},
}

-- ═══════════════════════════════════════════════
-- 4. UTILITAIRES
-- ═══════════════════════════════════════════════

-- Supprime l'ancienne ScreenGui si elle existe (évite les doublons)
local existing = playerGui:FindFirstChild("RebirthGui")
if existing then existing:Destroy() end

-- Formate un nombre avec virgules : 1500000 → "1,500,000"
local function fmtNumber(n)
	n = math.floor(tonumber(n) or 0)
	local s = tostring(n)
	local result = ""
	local count  = 0
	for i = #s, 1, -1 do
		count = count + 1
		result = s:sub(i, i) .. result
		if count % 3 == 0 and i > 1 then result = "," .. result end
	end
	return result
end

-- Formate en compact : 1500000 → "1.5M"
local function fmtCompact(n)
	n = tonumber(n) or 0
	if n >= 1e9 then  return string.format("%.1fB", n/1e9)
	elseif n >= 1e6 then return string.format("%.1fM", n/1e6)
	elseif n >= 1e3 then return string.format("%.1fK", n/1e3)
	else return tostring(math.floor(n)) end
end

-- Tween rapide sur une propriété d'une instance
local function tween(inst, info, props)
	TweenService:Create(inst, info, props):Play()
end

-- Création rapide d'un UICorner
local function addCorner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 8)
	c.Parent = parent
	return c
end

-- Création rapide d'un UIStroke
local function addStroke(parent, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color or C.BORDER
	s.Thickness = thickness or 1.5
	s.Parent = parent
	return s
end

-- Crée un TextLabel simple
local function makeLabel(parent, text, pos, size, color, textSize, font, xAlign)
	local l = Instance.new("TextLabel")
	l.Text                   = text
	l.Position               = pos
	l.Size                   = size
	l.BackgroundTransparency = 1
	l.TextColor3             = color or C.WHITE
	l.TextSize               = textSize or 14
	l.Font                   = font or Enum.Font.GothamBold
	l.TextXAlignment         = xAlign or Enum.TextXAlignment.Left
	l.TextYAlignment         = Enum.TextYAlignment.Center
	l.TextWrapped            = true
	l.Parent                 = parent
	return l
end

-- ═══════════════════════════════════════════════
-- 5. CONSTRUCTION DE LA SCREENGUI
-- ═══════════════════════════════════════════════

local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "RebirthGui"
screenGui.ResetOnSpawn   = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent         = playerGui
print("[RebirthClient] ScreenGui créé ✓")

-- ═══════════════════════════════════════════════
-- 6. BOUTON PRINCIPAL REBIRTH (bord gauche, centré)
-- ═══════════════════════════════════════════════

local mainBtn = Instance.new("TextButton")
mainBtn.Name             = "MainRebirthButton"
mainBtn.Size             = UDim2.new(0, 68, 0, 88)
mainBtn.Position         = UDim2.new(0, 10, 0.5, -44)
mainBtn.BackgroundColor3 = C.ORANGE
mainBtn.BorderSizePixel  = 0
mainBtn.Text             = ""
mainBtn.AutoButtonColor  = false
mainBtn.ZIndex           = 5
mainBtn.Parent           = screenGui
addCorner(mainBtn, 12)
addStroke(mainBtn, Color3.fromRGB(255, 160, 60), 2)

local mainArrow = Instance.new("TextLabel")
mainArrow.Text                   = "↺"
mainArrow.Size                   = UDim2.new(1, 0, 0, 46)
mainArrow.Position               = UDim2.new(0, 0, 0, 4)
mainArrow.BackgroundTransparency = 1
mainArrow.TextColor3             = C.WHITE
mainArrow.TextSize               = 30
mainArrow.Font                   = Enum.Font.GothamBlack
mainArrow.TextXAlignment         = Enum.TextXAlignment.Center
mainArrow.ZIndex                 = 6
mainArrow.Parent                 = mainBtn

local mainLabel = Instance.new("TextLabel")
mainLabel.Text                   = "REBIRTH"
mainLabel.Size                   = UDim2.new(1, 0, 0, 28)
mainLabel.Position               = UDim2.new(0, 0, 1, -32)
mainLabel.BackgroundTransparency = 1
mainLabel.TextColor3             = C.WHITE
mainLabel.TextSize               = 11
mainLabel.Font                   = Enum.Font.GothamBold
mainLabel.TextXAlignment         = Enum.TextXAlignment.Center
mainLabel.ZIndex                 = 6
mainLabel.Parent                 = mainBtn

print("[RebirthClient] Bouton principal créé ✓")

-- Hover du bouton principal
mainBtn.MouseEnter:Connect(function()
	tween(mainBtn, TweenInfo.new(0.12), { BackgroundColor3 = C.ORANGE_DARK, Size = UDim2.new(0, 74, 0, 96) })
end)
mainBtn.MouseLeave:Connect(function()
	tween(mainBtn, TweenInfo.new(0.12), { BackgroundColor3 = C.ORANGE, Size = UDim2.new(0, 68, 0, 88) })
end)

-- ═══════════════════════════════════════════════
-- 7. POPUP REBIRTH
-- ═══════════════════════════════════════════════

-- Overlay sombre derrière le popup
local overlay = Instance.new("Frame")
overlay.Name                   = "Overlay"
overlay.Size                   = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
overlay.BackgroundTransparency = 0.5
overlay.BorderSizePixel        = 0
overlay.Visible                = false
overlay.ZIndex                 = 9
overlay.Parent                 = screenGui

-- Popup principal
local popup = Instance.new("Frame")
popup.Name             = "PopupRebirth"
popup.Size             = UDim2.new(0, 440, 0, 530)
popup.Position         = UDim2.new(0.5, -220, 0.5, -265)
popup.BackgroundColor3 = C.CARD
popup.BorderSizePixel  = 0
popup.Visible          = false
popup.ZIndex           = 10
popup.Parent           = screenGui
addCorner(popup, 16)
addStroke(popup, C.BORDER, 2)

print("[RebirthClient] Popup créé ✓")

-- ── En-tête ──────────────────────────────────────────────────────────────────

local header = Instance.new("Frame")
header.Size             = UDim2.new(1, 0, 0, 58)
header.BackgroundColor3 = C.ORANGE
header.BorderSizePixel  = 0
header.ZIndex           = 11
header.Parent           = popup
addCorner(header, 16)

-- Coin inférieur carré pour le header (hack pour ne pas avoir de coins en bas)
local headerFill = Instance.new("Frame")
headerFill.Size             = UDim2.new(1, 0, 0, 16)
headerFill.Position         = UDim2.new(0, 0, 1, -16)
headerFill.BackgroundColor3 = C.ORANGE
headerFill.BorderSizePixel  = 0
headerFill.ZIndex           = 11
headerFill.Parent           = header

local titleLabel = Instance.new("TextLabel")
titleLabel.Text                   = "✦  REBIRTH"
titleLabel.Size                   = UDim2.new(1, -50, 1, 0)
titleLabel.Position               = UDim2.new(0, 18, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3             = C.WHITE
titleLabel.TextSize               = 22
titleLabel.Font                   = Enum.Font.GothamBlack
titleLabel.TextXAlignment         = Enum.TextXAlignment.Left
titleLabel.TextYAlignment         = Enum.TextYAlignment.Center
titleLabel.ZIndex                 = 12
titleLabel.Parent                 = header

-- Sous-titre niveau actuel → prochain
local levelLabel = Instance.new("TextLabel")
levelLabel.Name                   = "LevelLabel"
levelLabel.Text                   = "Niveau 0  →  1"
levelLabel.Size                   = UDim2.new(1, -50, 0, 20)
levelLabel.Position               = UDim2.new(0, 18, 0, 36)
levelLabel.BackgroundTransparency = 1
levelLabel.TextColor3             = Color3.fromRGB(255, 220, 160)
levelLabel.TextSize               = 13
levelLabel.Font                   = Enum.Font.GothamBold
levelLabel.TextXAlignment         = Enum.TextXAlignment.Left
levelLabel.ZIndex                 = 12
levelLabel.Parent                 = popup

-- Bouton X fermeture
local closeBtn = Instance.new("TextButton")
closeBtn.Name             = "CloseBtn"
closeBtn.Text             = "✕"
closeBtn.Size             = UDim2.new(0, 36, 0, 36)
closeBtn.Position         = UDim2.new(1, -46, 0, 11)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
closeBtn.TextColor3       = C.WHITE
closeBtn.TextSize         = 16
closeBtn.Font             = Enum.Font.GothamBlack
closeBtn.BorderSizePixel  = 0
closeBtn.ZIndex           = 13
closeBtn.Parent           = popup
addCorner(closeBtn, 8)

-- ── Section REQUIREMENTS ─────────────────────────────────────────────────────

local reqTitle = makeLabel(popup, "REQUIREMENTS",
	UDim2.new(0, 18, 0, 68), UDim2.new(1, -36, 0, 22),
	C.MUTED, 11, Enum.Font.GothamBold, Enum.TextXAlignment.Left)
reqTitle.ZIndex = 11

-- Bloc Money
local moneyBlock = Instance.new("Frame")
moneyBlock.Size             = UDim2.new(1, -28, 0, 74)
moneyBlock.Position         = UDim2.new(0, 14, 0, 92)
moneyBlock.BackgroundColor3 = C.SECTION
moneyBlock.BorderSizePixel  = 0
moneyBlock.ZIndex           = 11
moneyBlock.Parent           = popup
addCorner(moneyBlock, 10)
addStroke(moneyBlock, C.BORDER, 1)

local moneyIcon = makeLabel(moneyBlock, "💰  Money",
	UDim2.new(0, 12, 0, 6), UDim2.new(0.5, 0, 0, 22),
	C.WHITE, 13, Enum.Font.GothamBold, Enum.TextXAlignment.Left)
moneyIcon.ZIndex = 12

local moneyAmounts = Instance.new("TextLabel")
moneyAmounts.Name                   = "MoneyAmounts"
moneyAmounts.Text                   = "0 / 10,000"
moneyAmounts.Size                   = UDim2.new(0.5, -8, 0, 22)
moneyAmounts.Position               = UDim2.new(0.5, 0, 0, 6)
moneyAmounts.BackgroundTransparency = 1
moneyAmounts.TextColor3             = C.WHITE
moneyAmounts.TextSize               = 12
moneyAmounts.Font                   = Enum.Font.GothamBold
moneyAmounts.TextXAlignment         = Enum.TextXAlignment.Right
moneyAmounts.ZIndex                 = 12
moneyAmounts.Parent                 = moneyBlock

-- Barre de progression argent
local barBg = Instance.new("Frame")
barBg.Size             = UDim2.new(1, -24, 0, 16)
barBg.Position         = UDim2.new(0, 12, 0, 34)
barBg.BackgroundColor3 = C.BAR_BG
barBg.BorderSizePixel  = 0
barBg.ZIndex           = 12
barBg.Parent           = moneyBlock
addCorner(barBg, 6)

local barFill = Instance.new("Frame")
barFill.Name             = "BarFill"
barFill.Size             = UDim2.new(0, 0, 1, 0)
barFill.BackgroundColor3 = C.GREEN
barFill.BorderSizePixel  = 0
barFill.ZIndex           = 13
barFill.Parent           = barBg
addCorner(barFill, 6)

local barText = Instance.new("TextLabel")
barText.Name                   = "BarText"
barText.Text                   = "0 / 10,000"
barText.Size                   = UDim2.new(1, 0, 1, 0)
barText.BackgroundTransparency = 1
barText.TextColor3             = C.WHITE
barText.TextSize               = 10
barText.Font                   = Enum.Font.GothamBold
barText.TextXAlignment         = Enum.TextXAlignment.Center
barText.ZIndex                 = 14
barText.Parent                 = barBg

local moneyStatus = Instance.new("TextLabel")
moneyStatus.Name                   = "MoneyStatus"
moneyStatus.Text                   = "✗  Insuffisant"
moneyStatus.Size                   = UDim2.new(1, -24, 0, 18)
moneyStatus.Position               = UDim2.new(0, 12, 0, 52)
moneyStatus.BackgroundTransparency = 1
moneyStatus.TextColor3             = C.RED
moneyStatus.TextSize               = 12
moneyStatus.Font                   = Enum.Font.GothamBold
moneyStatus.TextXAlignment         = Enum.TextXAlignment.Left
moneyStatus.ZIndex                 = 12
moneyStatus.Parent                 = moneyBlock

-- Bloc BrainRot Rarity
local rarityBlock = Instance.new("Frame")
rarityBlock.Size             = UDim2.new(1, -28, 0, 68)
rarityBlock.Position         = UDim2.new(0, 14, 0, 174)
rarityBlock.BackgroundColor3 = C.SECTION
rarityBlock.BorderSizePixel  = 0
rarityBlock.ZIndex           = 11
rarityBlock.Parent           = popup
addCorner(rarityBlock, 10)
addStroke(rarityBlock, C.BORDER, 1)

local rarityTitle = makeLabel(rarityBlock, "🎲  BrainRot Rarity",
	UDim2.new(0, 12, 0, 6), UDim2.new(0.55, 0, 0, 22),
	C.WHITE, 13, Enum.Font.GothamBold, Enum.TextXAlignment.Left)
rarityTitle.ZIndex = 12

local rarityRequired = Instance.new("TextLabel")
rarityRequired.Name                   = "RarityRequired"
rarityRequired.Text                   = "Required: Common"
rarityRequired.Size                   = UDim2.new(1, -24, 0, 22)
rarityRequired.Position               = UDim2.new(0, 12, 0, 28)
rarityRequired.BackgroundTransparency = 1
rarityRequired.TextColor3             = C.RARITY.Common
rarityRequired.TextSize               = 14
rarityRequired.Font                   = Enum.Font.GothamBlack
rarityRequired.TextXAlignment         = Enum.TextXAlignment.Left
rarityRequired.ZIndex                 = 12
rarityRequired.Parent                 = rarityBlock

local rarityStatus = Instance.new("TextLabel")
rarityStatus.Name                   = "RarityStatus"
rarityStatus.Text                   = "✗  Not owned"
rarityStatus.Size                   = UDim2.new(0.5, -12, 0, 18)
rarityStatus.Position               = UDim2.new(0.5, 4, 0, 6)
rarityStatus.BackgroundTransparency = 1
rarityStatus.TextColor3             = C.RED
rarityStatus.TextSize               = 12
rarityStatus.Font                   = Enum.Font.GothamBold
rarityStatus.TextXAlignment         = Enum.TextXAlignment.Right
rarityStatus.ZIndex                 = 12
rarityStatus.Parent                 = rarityBlock

-- ── Section REWARDS ───────────────────────────────────────────────────────────

local rewTitle = makeLabel(popup, "REWARDS",
	UDim2.new(0, 18, 0, 252), UDim2.new(1, -36, 0, 22),
	C.MUTED, 11, Enum.Font.GothamBold, Enum.TextXAlignment.Left)
rewTitle.ZIndex = 11

local rewardBlock = Instance.new("Frame")
rewardBlock.Size             = UDim2.new(1, -28, 0, 50)
rewardBlock.Position         = UDim2.new(0, 14, 0, 276)
rewardBlock.BackgroundColor3 = C.SECTION
rewardBlock.BorderSizePixel  = 0
rewardBlock.ZIndex           = 11
rewardBlock.Parent           = popup
addCorner(rewardBlock, 10)
addStroke(rewardBlock, C.BORDER, 1)

local rewardText = Instance.new("TextLabel")
rewardText.Name                   = "RewardText"
rewardText.Text                   = "📦  +1 Slot"
rewardText.Size                   = UDim2.new(1, -24, 1, 0)
rewardText.Position               = UDim2.new(0, 12, 0, 0)
rewardText.BackgroundTransparency = 1
rewardText.TextColor3             = Color3.fromRGB(255, 218, 50)
rewardText.TextSize               = 16
rewardText.Font                   = Enum.Font.GothamBlack
rewardText.TextXAlignment         = Enum.TextXAlignment.Left
rewardText.ZIndex                 = 12
rewardText.Parent                 = rewardBlock

-- ── Avertissement ─────────────────────────────────────────────────────────────

local warnLabel = makeLabel(popup,
	"⚠  You will lose all your BrainRots and money!",
	UDim2.new(0, 14, 0, 336), UDim2.new(1, -28, 0, 34),
	Color3.fromRGB(255, 160, 60), 12, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
warnLabel.TextWrapped = true
warnLabel.ZIndex = 11

-- ── Bouton CONFIRM REBIRTH ────────────────────────────────────────────────────

local confirmBtn = Instance.new("TextButton")
confirmBtn.Name             = "ConfirmBtn"
confirmBtn.Text             = "CONFIRM REBIRTH"
confirmBtn.Size             = UDim2.new(1, -28, 0, 54)
confirmBtn.Position         = UDim2.new(0, 14, 0, 378)
confirmBtn.BackgroundColor3 = C.GREEN
confirmBtn.TextColor3       = C.WHITE
confirmBtn.TextSize         = 18
confirmBtn.Font             = Enum.Font.GothamBlack
confirmBtn.BorderSizePixel  = 0
confirmBtn.AutoButtonColor  = false
confirmBtn.ZIndex           = 11
confirmBtn.Parent           = popup
addCorner(confirmBtn, 12)
addStroke(confirmBtn, C.GREEN_DARK, 2)

-- Message de résultat (success / fail) sous le bouton confirm
local resultLabel = Instance.new("TextLabel")
resultLabel.Name                   = "ResultLabel"
resultLabel.Text                   = ""
resultLabel.Size                   = UDim2.new(1, -28, 0, 36)
resultLabel.Position               = UDim2.new(0, 14, 0, 438)
resultLabel.BackgroundTransparency = 1
resultLabel.TextColor3             = C.GREEN
resultLabel.TextSize               = 13
resultLabel.Font                   = Enum.Font.GothamBold
resultLabel.TextXAlignment         = Enum.TextXAlignment.Center
resultLabel.TextWrapped            = true
resultLabel.ZIndex                 = 11
resultLabel.Parent                 = popup

-- ── Slots actuels (bas du popup) ─────────────────────────────────────────────

local slotsLabel = Instance.new("TextLabel")
slotsLabel.Name                   = "SlotsLabel"
slotsLabel.Text                   = "Current slots: 1"
slotsLabel.Size                   = UDim2.new(1, -28, 0, 26)
slotsLabel.Position               = UDim2.new(0, 14, 0, 482)
slotsLabel.BackgroundTransparency = 1
slotsLabel.TextColor3             = C.MUTED
slotsLabel.TextSize               = 12
slotsLabel.Font                   = Enum.Font.GothamBold
slotsLabel.TextXAlignment         = Enum.TextXAlignment.Center
slotsLabel.ZIndex                 = 11
slotsLabel.Parent                 = popup

-- ═══════════════════════════════════════════════
-- 8. MISE À JOUR DE L'INTERFACE DEPUIS LE PAYLOAD
-- ═══════════════════════════════════════════════

local function setConfirmEnabled(enabled)
	if enabled then
		confirmBtn.BackgroundColor3 = C.GREEN
		confirmBtn.TextColor3       = C.WHITE
		confirmBtn.Active           = true
		confirmBtn.Text             = "CONFIRM REBIRTH"
	else
		confirmBtn.BackgroundColor3 = Color3.fromRGB(55, 55, 70)
		confirmBtn.TextColor3       = C.MUTED
		confirmBtn.Active           = false
	end
end

local function updatePopupFromPayload(payload)
	if not payload then
		levelLabel.Text = "Loading..."
		setConfirmEnabled(false)
		return
	end

	dernierPayload = payload

	-- En-tête niveau
	if payload.maxReached then
		levelLabel.Text = "Level " .. payload.rebirthCount .. "  —  MAX REBIRTH REACHED"
		confirmBtn.Text = "MAX REBIRTH REACHED"
		setConfirmEnabled(false)

		-- Cacher les requirements, montrer le max
		moneyBlock.Visible  = false
		rarityBlock.Visible = false
		rewardBlock.Visible = false
		warnLabel.Visible   = false
		slotsLabel.Text     = "Slots: " .. payload.slots .. " (maximum atteint)"
		return
	end

	moneyBlock.Visible  = true
	rarityBlock.Visible = true
	rewardBlock.Visible = true
	warnLabel.Visible   = true

	levelLabel.Text = "Level " .. payload.rebirthCount .. "  →  " .. payload.nextLevel

	local req     = payload.required
	local cur     = payload.current
	local canReb  = true

	-- ── Argent ──
	local ratio = math.min(cur.money / math.max(req.money, 1), 1)
	tween(barFill, TweenInfo.new(0.3), { Size = UDim2.new(ratio, 0, 1, 0) })
	barFill.BackgroundColor3 = (ratio >= 1) and C.GREEN or Color3.fromRGB(220, 80, 50)
	barText.Text   = fmtNumber(cur.money) .. " / " .. fmtNumber(req.money)
	moneyAmounts.Text = fmtCompact(cur.money) .. " / " .. fmtCompact(req.money)

	if cur.money >= req.money then
		moneyStatus.Text       = "✔  Suffisant"
		moneyStatus.TextColor3 = C.GREEN
	else
		moneyStatus.Text       = "✗  " .. fmtNumber(req.money - cur.money) .. " manquant"
		moneyStatus.TextColor3 = C.RED
		canReb = false
	end

	-- ── Rareté ──
	local rarityColor = C.RARITY[req.rarity] or C.WHITE
	rarityRequired.Text       = "Required: " .. req.rarity
	rarityRequired.TextColor3 = rarityColor

	if cur.hasRarity then
		rarityStatus.Text       = "✔  Owned"
		rarityStatus.TextColor3 = C.GREEN
	else
		rarityStatus.Text       = "✗  Not owned"
		rarityStatus.TextColor3 = C.RED
		canReb = false
	end

	-- ── Récompense ──
	local slots = req.reward and req.reward.slots or 1
	rewardText.Text = "📦  +" .. slots .. " Slot" .. (slots > 1 and "s" or "")

	-- ── Slots actuels ──
	slotsLabel.Text = "Current slots: " .. payload.slots

	-- ── Bouton confirm ──
	setConfirmEnabled(canReb)
	resultLabel.Text = ""
end

-- ═══════════════════════════════════════════════
-- 9. RÉCUPÉRATION DES DONNÉES SERVEUR
-- ═══════════════════════════════════════════════

local function fetchData()
	print("[RebirthClient] Récupération données serveur...")
	local ok, payload = pcall(function()
		return rfGetRebirthData:InvokeServer()
	end)
	if ok and payload then
		print("[RebirthClient] Données reçues ✓")
		updatePopupFromPayload(payload)
	else
		warn("[RebirthClient] Échec récupération données: " .. tostring(payload))
		resultLabel.Text = "Erreur chargement des données."
	end
end

-- ═══════════════════════════════════════════════
-- 10. OUVERTURE / FERMETURE DU MENU
-- ═══════════════════════════════════════════════

local function openMenu()
	menuOuvert           = true
	overlay.Visible      = true
	popup.Visible        = true
	popup.Size           = UDim2.new(0, 440, 0, 0)
	tween(popup, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.new(0, 440, 0, 530) })
	print("[RebirthClient] Menu ouvert ✓")
	fetchData()
end

local function closeMenu()
	menuOuvert = false
	tween(popup, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Size = UDim2.new(0, 440, 0, 0) })
	task.delay(0.18, function()
		popup.Visible   = false
		overlay.Visible = false
	end)
end

-- ═══════════════════════════════════════════════
-- 11. CONNEXION DES BOUTONS
-- ═══════════════════════════════════════════════

mainBtn.MouseButton1Click:Connect(function()
	if menuOuvert then closeMenu() else openMenu() end
end)

closeBtn.MouseButton1Click:Connect(closeMenu)
overlay.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then closeMenu() end
end)

-- Hover du bouton confirm
confirmBtn.MouseEnter:Connect(function()
	if confirmBtn.Active then
		tween(confirmBtn, TweenInfo.new(0.1), { BackgroundColor3 = C.GREEN_DARK })
	end
end)
confirmBtn.MouseLeave:Connect(function()
	if confirmBtn.Active then
		tween(confirmBtn, TweenInfo.new(0.1), { BackgroundColor3 = C.GREEN })
	end
end)

-- Clic confirm → envoie la demande de rebirth au serveur
confirmBtn.MouseButton1Click:Connect(function()
	if not confirmBtn.Active or rebirthEnCours then return end

	rebirthEnCours          = true
	confirmBtn.Text         = "En cours..."
	confirmBtn.Active       = false
	resultLabel.Text        = ""
	resultLabel.TextColor3  = C.MUTED

	print("[RebirthClient] Envoi RequestRebirth...")
	reRequestRebirth:FireServer()
end)

-- ═══════════════════════════════════════════════
-- 12. RÉCEPTION DU RÉSULTAT
-- ═══════════════════════════════════════════════

reRebirthResult.OnClientEvent:Connect(function(result)
	rebirthEnCours = false

	if result.success then
		print("[RebirthClient] ✓ Rebirth " .. result.newCount .. " réussi !")
		resultLabel.Text       = "✦  REBIRTH " .. result.newCount .. " !  +" .. (result.payload and result.payload.required == nil and "1" or "1") .. " slot débloqué"
		resultLabel.TextColor3 = C.GREEN

		-- Rafraîchir l'affichage avec le nouveau payload
		if result.payload then
			updatePopupFromPayload(result.payload)
			resultLabel.Text       = "✦  REBIRTH " .. result.newCount .. " réussi !  Slots: " .. result.newSlots
			resultLabel.TextColor3 = C.GREEN
		end
	else
		print("[RebirthClient] ✗ Rebirth refusé: " .. tostring(result.reason))
		resultLabel.Text       = "✗  " .. (result.reason or "Rebirth refusé.")
		resultLabel.TextColor3 = C.RED

		-- Rétablir le bouton si les conditions le permettent
		if dernierPayload then
			updatePopupFromPayload(dernierPayload)
		end
	end
end)

print("[RebirthClient] Système Rebirth client prêt ✓")
