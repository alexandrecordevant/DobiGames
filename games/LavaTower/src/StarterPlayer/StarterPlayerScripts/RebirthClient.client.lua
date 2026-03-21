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
local dernierPayload  = nil

-- ═══════════════════════════════════════════════
-- 3. PALETTE DE COULEURS
-- ═══════════════════════════════════════════════

local C = {
	-- Fonds
	BG          = Color3.fromRGB(58,  58,  59 ),   -- fond très sombre / overlay
	CARD        = Color3.fromRGB(75,  75,  76 ),   -- fond popup principal
	SECTION     = Color3.fromRGB(88,  72,  58 ),   -- blocs internes (teinté BROWN)
	BORDER      = Color3.fromRGB(108, 108, 110),   -- bordures discrètes

	-- Accent BLUE (header / info / navigation)
	BLUE        = Color3.fromRGB(53,  137, 189),
	BLUE_DARK   = Color3.fromRGB(38,  100, 145),
	BLUE_LIGHT  = Color3.fromRGB(78,  160, 212),

	-- Accent GREEN (action principale / succès / progression)
	GREEN       = Color3.fromRGB(95,  170, 85 ),
	GREEN_DARK  = Color3.fromRGB(70,  130, 62 ),
	GREEN_DIM   = Color3.fromRGB(52,  80,  48 ),

	-- BROWN (économie / items / progression rebirth)
	BROWN       = Color3.fromRGB(120, 85,  55 ),
	BROWN_LIGHT = Color3.fromRGB(148, 108, 72 ),

	-- États
	RED         = Color3.fromRGB(185, 65,  55 ),   -- erreur / insuffisant

	-- Textes
	WHITE       = Color3.fromRGB(232, 230, 225),   -- texte principal
	MUTED       = Color3.fromRGB(158, 156, 152),   -- texte secondaire désaturé

	-- Barre de progression
	BAR_BG      = Color3.fromRGB(48,  48,  50 ),

	-- Raretés (harmonisées avec la palette)
	RARITY = {
		Common    = Color3.fromRGB(198, 198, 198),
		Uncommon  = Color3.fromRGB(95,  200, 110),
		Rare      = Color3.fromRGB(75,  140, 215),
		Epic      = Color3.fromRGB(162, 60,  228),
		Legendary = Color3.fromRGB(228, 185, 40 ),
		Secret    = Color3.fromRGB(210, 58,  58 ),
	},
}

-- ═══════════════════════════════════════════════
-- 4. UTILITAIRES
-- ═══════════════════════════════════════════════

local existing = playerGui:FindFirstChild("RebirthGui")
if existing then existing:Destroy() end

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

local function fmtCompact(n)
	n = tonumber(n) or 0
	if n >= 1e9 then  return string.format("%.1fB", n/1e9)
	elseif n >= 1e6 then return string.format("%.1fM", n/1e6)
	elseif n >= 1e3 then return string.format("%.1fK", n/1e3)
	else return tostring(math.floor(n)) end
end

local function tween(inst, info, props)
	TweenService:Create(inst, info, props):Play()
end

-- Arrondi par défaut réduit à 5 (style semi-carré)
local function addCorner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 5)
	c.Parent = parent
	return c
end

local function addStroke(parent, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color or C.BORDER
	s.Thickness = thickness or 1.5
	s.Parent = parent
	return s
end

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
mainBtn.Size             = UDim2.new(0, 72, 0, 92)
mainBtn.Position         = UDim2.new(0, 12, 0.5, -46)
mainBtn.BackgroundColor3 = C.GREEN
mainBtn.BorderSizePixel  = 0
mainBtn.Text             = ""
mainBtn.AutoButtonColor  = false
mainBtn.ZIndex           = 5
mainBtn.Parent           = screenGui
addCorner(mainBtn, 6)
addStroke(mainBtn, C.GREEN_DARK, 2)

local mainArrow = Instance.new("TextLabel")
mainArrow.Text                   = "↺"
mainArrow.Size                   = UDim2.new(1, 0, 0, 50)
mainArrow.Position               = UDim2.new(0, 0, 0, 6)
mainArrow.BackgroundTransparency = 1
mainArrow.TextColor3             = C.WHITE
mainArrow.TextSize               = 28
mainArrow.Font                   = Enum.Font.GothamBlack
mainArrow.TextXAlignment         = Enum.TextXAlignment.Center
mainArrow.ZIndex                 = 6
mainArrow.Parent                 = mainBtn

local mainLabel = Instance.new("TextLabel")
mainLabel.Text                   = "REBIRTH"
mainLabel.Size                   = UDim2.new(1, 0, 0, 26)
mainLabel.Position               = UDim2.new(0, 0, 1, -30)
mainLabel.BackgroundTransparency = 1
mainLabel.TextColor3             = C.WHITE
mainLabel.TextSize               = 10
mainLabel.Font                   = Enum.Font.GothamBold
mainLabel.TextXAlignment         = Enum.TextXAlignment.Center
mainLabel.ZIndex                 = 6
mainLabel.Parent                 = mainBtn

print("[RebirthClient] Bouton principal créé ✓")

-- Hover du bouton principal (subtil, +6px width/height)
mainBtn.MouseEnter:Connect(function()
	tween(mainBtn, TweenInfo.new(0.1), { BackgroundColor3 = C.GREEN_DARK, Size = UDim2.new(0, 78, 0, 98) })
end)
mainBtn.MouseLeave:Connect(function()
	tween(mainBtn, TweenInfo.new(0.1), { BackgroundColor3 = C.GREEN, Size = UDim2.new(0, 72, 0, 92) })
end)

-- ═══════════════════════════════════════════════
-- 7. POPUP REBIRTH
-- ═══════════════════════════════════════════════

-- Overlay sombre derrière le popup
local overlay = Instance.new("Frame")
overlay.Name                   = "Overlay"
overlay.Size                   = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
overlay.BackgroundTransparency = 0.55
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
addCorner(popup, 8)
addStroke(popup, C.BORDER, 2)

print("[RebirthClient] Popup créé ✓")

-- ── En-tête ──────────────────────────────────────────────────────────────────

local header = Instance.new("Frame")
header.Size             = UDim2.new(1, 0, 0, 56)
header.BackgroundColor3 = C.BLUE
header.BorderSizePixel  = 0
header.ZIndex           = 11
header.Parent           = popup
addCorner(header, 8)

-- Masque les coins arrondis en bas du header
local headerFill = Instance.new("Frame")
headerFill.Size             = UDim2.new(1, 0, 0, 8)
headerFill.Position         = UDim2.new(0, 0, 1, -8)
headerFill.BackgroundColor3 = C.BLUE
headerFill.BorderSizePixel  = 0
headerFill.ZIndex           = 11
headerFill.Parent           = header

local titleLabel = Instance.new("TextLabel")
titleLabel.Text                   = "✦  REBIRTH"
titleLabel.Size                   = UDim2.new(1, -50, 1, 0)
titleLabel.Position               = UDim2.new(0, 16, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3             = C.WHITE
titleLabel.TextSize               = 20
titleLabel.Font                   = Enum.Font.GothamBlack
titleLabel.TextXAlignment         = Enum.TextXAlignment.Left
titleLabel.TextYAlignment         = Enum.TextYAlignment.Center
titleLabel.ZIndex                 = 12
titleLabel.Parent                 = header

-- Sous-titre niveau actuel → prochain (positionné dans la zone header)
local levelLabel = Instance.new("TextLabel")
levelLabel.Name                   = "LevelLabel"
levelLabel.Text                   = "Niveau 0  →  1"
levelLabel.Size                   = UDim2.new(1, -50, 0, 18)
levelLabel.Position               = UDim2.new(0, 16, 0, 38)
levelLabel.BackgroundTransparency = 1
levelLabel.TextColor3             = Color3.fromRGB(180, 212, 235)  -- bleu clair désaturé
levelLabel.TextSize               = 12
levelLabel.Font                   = Enum.Font.GothamBold
levelLabel.TextXAlignment         = Enum.TextXAlignment.Left
levelLabel.ZIndex                 = 12
levelLabel.Parent                 = popup

-- Bouton X fermeture
local closeBtn = Instance.new("TextButton")
closeBtn.Name             = "CloseBtn"
closeBtn.Text             = "✕"
closeBtn.Size             = UDim2.new(0, 32, 0, 32)
closeBtn.Position         = UDim2.new(1, -42, 0, 12)
closeBtn.BackgroundColor3 = C.BLUE_DARK
closeBtn.TextColor3       = C.WHITE
closeBtn.TextSize         = 14
closeBtn.Font             = Enum.Font.GothamBlack
closeBtn.BorderSizePixel  = 0
closeBtn.ZIndex           = 13
closeBtn.Parent           = popup
addCorner(closeBtn, 4)

-- ── Section REQUIREMENTS ─────────────────────────────────────────────────────

local reqTitle = makeLabel(popup, "REQUIREMENTS",
	UDim2.new(0, 16, 0, 68), UDim2.new(1, -32, 0, 20),
	C.MUTED, 10, Enum.Font.GothamBold, Enum.TextXAlignment.Left)
reqTitle.ZIndex = 11

-- Bloc Money
local moneyBlock = Instance.new("Frame")
moneyBlock.Size             = UDim2.new(1, -24, 0, 76)
moneyBlock.Position         = UDim2.new(0, 12, 0, 90)
moneyBlock.BackgroundColor3 = C.SECTION
moneyBlock.BorderSizePixel  = 0
moneyBlock.ZIndex           = 11
moneyBlock.Parent           = popup
addCorner(moneyBlock, 6)
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
barBg.Size             = UDim2.new(1, -24, 0, 14)
barBg.Position         = UDim2.new(0, 12, 0, 34)
barBg.BackgroundColor3 = C.BAR_BG
barBg.BorderSizePixel  = 0
barBg.ZIndex           = 12
barBg.Parent           = moneyBlock
addCorner(barBg, 3)

local barFill = Instance.new("Frame")
barFill.Name             = "BarFill"
barFill.Size             = UDim2.new(0, 0, 1, 0)
barFill.BackgroundColor3 = C.GREEN
barFill.BorderSizePixel  = 0
barFill.ZIndex           = 13
barFill.Parent           = barBg
addCorner(barFill, 3)

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
moneyStatus.Position               = UDim2.new(0, 12, 0, 54)
moneyStatus.BackgroundTransparency = 1
moneyStatus.TextColor3             = C.RED
moneyStatus.TextSize               = 11
moneyStatus.Font                   = Enum.Font.GothamBold
moneyStatus.TextXAlignment         = Enum.TextXAlignment.Left
moneyStatus.ZIndex                 = 12
moneyStatus.Parent                 = moneyBlock

-- Bloc BrainRot Rarity
local rarityBlock = Instance.new("Frame")
rarityBlock.Size             = UDim2.new(1, -24, 0, 68)
rarityBlock.Position         = UDim2.new(0, 12, 0, 174)
rarityBlock.BackgroundColor3 = C.SECTION
rarityBlock.BorderSizePixel  = 0
rarityBlock.ZIndex           = 11
rarityBlock.Parent           = popup
addCorner(rarityBlock, 6)
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
	UDim2.new(0, 16, 0, 252), UDim2.new(1, -32, 0, 20),
	C.MUTED, 10, Enum.Font.GothamBold, Enum.TextXAlignment.Left)
rewTitle.ZIndex = 11

local rewardBlock = Instance.new("Frame")
rewardBlock.Size             = UDim2.new(1, -24, 0, 50)
rewardBlock.Position         = UDim2.new(0, 12, 0, 274)
rewardBlock.BackgroundColor3 = C.SECTION
rewardBlock.BorderSizePixel  = 0
rewardBlock.ZIndex           = 11
rewardBlock.Parent           = popup
addCorner(rewardBlock, 6)
addStroke(rewardBlock, C.BORDER, 1)

local rewardText = Instance.new("TextLabel")
rewardText.Name                   = "RewardText"
rewardText.Text                   = "📦  +1 Slot"
rewardText.Size                   = UDim2.new(1, -24, 1, 0)
rewardText.Position               = UDim2.new(0, 12, 0, 0)
rewardText.BackgroundTransparency = 1
rewardText.TextColor3             = Color3.fromRGB(228, 185, 40)   -- or Legendary
rewardText.TextSize               = 16
rewardText.Font                   = Enum.Font.GothamBlack
rewardText.TextXAlignment         = Enum.TextXAlignment.Left
rewardText.ZIndex                 = 12
rewardText.Parent                 = rewardBlock

-- ── Avertissement ─────────────────────────────────────────────────────────────

local warnLabel = makeLabel(popup,
	"⚠  You will lose all your BrainRots and money!",
	UDim2.new(0, 12, 0, 334), UDim2.new(1, -24, 0, 34),
	Color3.fromRGB(198, 165, 95), 11, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
warnLabel.TextWrapped = true
warnLabel.ZIndex = 11

-- ── Bouton CONFIRM REBIRTH ────────────────────────────────────────────────────

local confirmBtn = Instance.new("TextButton")
confirmBtn.Name             = "ConfirmBtn"
confirmBtn.Text             = "CONFIRM REBIRTH"
confirmBtn.Size             = UDim2.new(1, -24, 0, 52)
confirmBtn.Position         = UDim2.new(0, 12, 0, 376)
confirmBtn.BackgroundColor3 = C.GREEN
confirmBtn.TextColor3       = C.WHITE
confirmBtn.TextSize         = 17
confirmBtn.Font             = Enum.Font.GothamBlack
confirmBtn.BorderSizePixel  = 0
confirmBtn.AutoButtonColor  = false
confirmBtn.ZIndex           = 11
confirmBtn.Parent           = popup
addCorner(confirmBtn, 6)
addStroke(confirmBtn, C.GREEN_DARK, 2)

-- Message de résultat (success / fail) sous le bouton confirm
local resultLabel = Instance.new("TextLabel")
resultLabel.Name                   = "ResultLabel"
resultLabel.Text                   = ""
resultLabel.Size                   = UDim2.new(1, -24, 0, 36)
resultLabel.Position               = UDim2.new(0, 12, 0, 436)
resultLabel.BackgroundTransparency = 1
resultLabel.TextColor3             = C.GREEN
resultLabel.TextSize               = 12
resultLabel.Font                   = Enum.Font.GothamBold
resultLabel.TextXAlignment         = Enum.TextXAlignment.Center
resultLabel.TextWrapped            = true
resultLabel.ZIndex                 = 11
resultLabel.Parent                 = popup

-- ── Slots actuels (bas du popup) ─────────────────────────────────────────────

local slotsLabel = Instance.new("TextLabel")
slotsLabel.Name                   = "SlotsLabel"
slotsLabel.Text                   = "Current slots: 1"
slotsLabel.Size                   = UDim2.new(1, -24, 0, 24)
slotsLabel.Position               = UDim2.new(0, 12, 0, 482)
slotsLabel.BackgroundTransparency = 1
slotsLabel.TextColor3             = C.MUTED
slotsLabel.TextSize               = 11
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
		confirmBtn.BackgroundColor3 = Color3.fromRGB(62, 62, 64)
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
	barFill.BackgroundColor3 = (ratio >= 1) and C.GREEN or C.BROWN
	barText.Text      = fmtNumber(cur.money) .. " / " .. fmtNumber(req.money)
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
	tween(popup, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{ Size = UDim2.new(0, 440, 0, 530) })
	print("[RebirthClient] Menu ouvert ✓")
	fetchData()
end

local function closeMenu()
	menuOuvert = false
	tween(popup, TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
		{ Size = UDim2.new(0, 440, 0, 0) })
	task.delay(0.16, function()
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
