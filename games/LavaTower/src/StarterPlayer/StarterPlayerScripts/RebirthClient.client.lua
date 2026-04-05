-- StarterPlayer/StarterPlayerScripts/RebirthClient.client.lua
-- Interface Rebirth — compatible shared-lib RebirthSystem
-- Remotes : RebirthButtonUpdate (push), DemandeRebirth, RebirthAnimation, OuvrirRebirth

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ═══════════════════════════════════════════════
-- 1. REMOTES (shared-lib RebirthSystem)
-- ═══════════════════════════════════════════════

local RebirthButtonUpdate = ReplicatedStorage:WaitForChild("RebirthButtonUpdate", 15)
local DemandeRebirth      = ReplicatedStorage:WaitForChild("DemandeRebirth",      15)
local RebirthAnimation    = ReplicatedStorage:WaitForChild("RebirthAnimation",     15)
local OuvrirRebirth       = ReplicatedStorage:WaitForChild("OuvrirRebirth",        15)

if not RebirthButtonUpdate or not DemandeRebirth then
    warn("[RebirthClient] Remotes introuvables — vérifier RebirthSystem dans Main.server.lua")
    return
end

-- ═══════════════════════════════════════════════
-- 2. ÉTAT LOCAL
-- ═══════════════════════════════════════════════

local menuOuvert     = false
local rebirthEnCours = false
local dernierEtat    = nil

-- ═══════════════════════════════════════════════
-- 3. PALETTE DE COULEURS
-- ═══════════════════════════════════════════════

local C = {
    BG          = Color3.fromRGB(58,  58,  59 ),
    CARD        = Color3.fromRGB(75,  75,  76 ),
    SECTION     = Color3.fromRGB(88,  72,  58 ),
    BORDER      = Color3.fromRGB(108, 108, 110),
    BLUE        = Color3.fromRGB(53,  137, 189),
    BLUE_DARK   = Color3.fromRGB(38,  100, 145),
    GREEN       = Color3.fromRGB(95,  170, 85 ),
    GREEN_DARK  = Color3.fromRGB(70,  130, 62 ),
    GREEN_DIM   = Color3.fromRGB(52,  80,  48 ),
    BROWN       = Color3.fromRGB(120, 85,  55 ),
    RED         = Color3.fromRGB(185, 65,  55 ),
    WHITE       = Color3.fromRGB(232, 230, 225),
    MUTED       = Color3.fromRGB(158, 156, 152),
    BAR_BG      = Color3.fromRGB(48,  48,  50 ),
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
    local result, count = "", 0
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

-- ═══════════════════════════════════════════════
-- 6. BOUTON PRINCIPAL REBIRTH
-- ═══════════════════════════════════════════════

local mainBtn = Instance.new("TextButton")
mainBtn.Name             = "MainRebirthButton"
mainBtn.Size             = UDim2.new(0, 72, 0, 92)
mainBtn.Position         = UDim2.new(0, 12, 0.5, -46)
mainBtn.BackgroundColor3 = C.GREEN
mainBtn.BorderSizePixel  = 0
mainBtn.Text             = ""
mainBtn.AutoButtonColor  = false
mainBtn.Visible          = false   -- caché jusqu'à IsProgressionComplete
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

mainBtn.MouseEnter:Connect(function()
    tween(mainBtn, TweenInfo.new(0.1), { BackgroundColor3 = C.GREEN_DARK, Size = UDim2.new(0, 78, 0, 98) })
end)
mainBtn.MouseLeave:Connect(function()
    tween(mainBtn, TweenInfo.new(0.1), { BackgroundColor3 = C.GREEN, Size = UDim2.new(0, 72, 0, 92) })
end)

-- ═══════════════════════════════════════════════
-- 7. POPUP REBIRTH
-- ═══════════════════════════════════════════════

local overlay = Instance.new("Frame")
overlay.Name                   = "Overlay"
overlay.Size                   = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
overlay.BackgroundTransparency = 0.55
overlay.BorderSizePixel        = 0
overlay.Visible                = false
overlay.ZIndex                 = 9
overlay.Parent                 = screenGui

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

-- Header
local header = Instance.new("Frame")
header.Size             = UDim2.new(1, 0, 0, 56)
header.BackgroundColor3 = C.BLUE
header.BorderSizePixel  = 0
header.ZIndex           = 11
header.Parent           = popup
addCorner(header, 8)

local headerFill = Instance.new("Frame")
headerFill.Size             = UDim2.new(1, 0, 0, 8)
headerFill.Position         = UDim2.new(0, 0, 1, -8)
headerFill.BackgroundColor3 = C.BLUE
headerFill.BorderSizePixel  = 0
headerFill.ZIndex           = 11
headerFill.Parent           = header

local titleLabel = Instance.new("TextLabel")
titleLabel.Text                   = "REBIRTH"
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

local levelLabel = Instance.new("TextLabel")
levelLabel.Name                   = "LevelLabel"
levelLabel.Text                   = "Niveau 0  →  1"
levelLabel.Size                   = UDim2.new(1, -50, 0, 18)
levelLabel.Position               = UDim2.new(0, 16, 0, 38)
levelLabel.BackgroundTransparency = 1
levelLabel.TextColor3             = Color3.fromRGB(180, 212, 235)
levelLabel.TextSize               = 12
levelLabel.Font                   = Enum.Font.GothamBold
levelLabel.TextXAlignment         = Enum.TextXAlignment.Left
levelLabel.ZIndex                 = 12
levelLabel.Parent                 = popup

local closeBtn = Instance.new("TextButton")
closeBtn.Name             = "CloseBtn"
closeBtn.Text             = "X"
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

-- Requirements
makeLabel(popup, "REQUIREMENTS",
    UDim2.new(0, 16, 0, 68), UDim2.new(1, -32, 0, 20),
    C.MUTED, 10, Enum.Font.GothamBold, Enum.TextXAlignment.Left).ZIndex = 11

local moneyBlock = Instance.new("Frame")
moneyBlock.Size             = UDim2.new(1, -24, 0, 76)
moneyBlock.Position         = UDim2.new(0, 12, 0, 90)
moneyBlock.BackgroundColor3 = C.SECTION
moneyBlock.BorderSizePixel  = 0
moneyBlock.ZIndex           = 11
moneyBlock.Parent           = popup
addCorner(moneyBlock, 6)
addStroke(moneyBlock, C.BORDER, 1)

makeLabel(moneyBlock, "Money",
    UDim2.new(0, 12, 0, 6), UDim2.new(0.5, 0, 0, 22),
    C.WHITE, 13, Enum.Font.GothamBold, Enum.TextXAlignment.Left).ZIndex = 12

local moneyAmounts = Instance.new("TextLabel")
moneyAmounts.Name                   = "MoneyAmounts"
moneyAmounts.Text                   = "0 / —"
moneyAmounts.Size                   = UDim2.new(0.5, -8, 0, 22)
moneyAmounts.Position               = UDim2.new(0.5, 0, 0, 6)
moneyAmounts.BackgroundTransparency = 1
moneyAmounts.TextColor3             = C.WHITE
moneyAmounts.TextSize               = 12
moneyAmounts.Font                   = Enum.Font.GothamBold
moneyAmounts.TextXAlignment         = Enum.TextXAlignment.Right
moneyAmounts.ZIndex                 = 12
moneyAmounts.Parent                 = moneyBlock

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
barText.Text                   = "0 / —"
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
moneyStatus.Text                   = "Insuffisant"
moneyStatus.Size                   = UDim2.new(1, -24, 0, 18)
moneyStatus.Position               = UDim2.new(0, 12, 0, 54)
moneyStatus.BackgroundTransparency = 1
moneyStatus.TextColor3             = C.RED
moneyStatus.TextSize               = 11
moneyStatus.Font                   = Enum.Font.GothamBold
moneyStatus.TextXAlignment         = Enum.TextXAlignment.Left
moneyStatus.ZIndex                 = 12
moneyStatus.Parent                 = moneyBlock

local rarityBlock = Instance.new("Frame")
rarityBlock.Size             = UDim2.new(1, -24, 0, 68)
rarityBlock.Position         = UDim2.new(0, 12, 0, 174)
rarityBlock.BackgroundColor3 = C.SECTION
rarityBlock.BorderSizePixel  = 0
rarityBlock.ZIndex           = 11
rarityBlock.Parent           = popup
addCorner(rarityBlock, 6)
addStroke(rarityBlock, C.BORDER, 1)

makeLabel(rarityBlock, "Stone Rarity",
    UDim2.new(0, 12, 0, 6), UDim2.new(0.55, 0, 0, 22),
    C.WHITE, 13, Enum.Font.GothamBold, Enum.TextXAlignment.Left).ZIndex = 12

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
rarityStatus.Text                   = "Not owned"
rarityStatus.Size                   = UDim2.new(0.5, -12, 0, 18)
rarityStatus.Position               = UDim2.new(0.5, 4, 0, 6)
rarityStatus.BackgroundTransparency = 1
rarityStatus.TextColor3             = C.RED
rarityStatus.TextSize               = 12
rarityStatus.Font                   = Enum.Font.GothamBold
rarityStatus.TextXAlignment         = Enum.TextXAlignment.Right
rarityStatus.ZIndex                 = 12
rarityStatus.Parent                 = rarityBlock

-- Rewards
makeLabel(popup, "REWARDS",
    UDim2.new(0, 16, 0, 252), UDim2.new(1, -32, 0, 20),
    C.MUTED, 10, Enum.Font.GothamBold, Enum.TextXAlignment.Left).ZIndex = 11

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
rewardText.Text                   = "+1 Slot  x1.2 multiplicateur"
rewardText.Size                   = UDim2.new(1, -24, 1, 0)
rewardText.Position               = UDim2.new(0, 12, 0, 0)
rewardText.BackgroundTransparency = 1
rewardText.TextColor3             = Color3.fromRGB(228, 185, 40)
rewardText.TextSize               = 14
rewardText.Font                   = Enum.Font.GothamBlack
rewardText.TextXAlignment         = Enum.TextXAlignment.Left
rewardText.ZIndex                 = 12
rewardText.Parent                 = rewardBlock

local warnLabel = makeLabel(popup,
    "You will lose all your Stones and money!",
    UDim2.new(0, 12, 0, 334), UDim2.new(1, -24, 0, 34),
    Color3.fromRGB(198, 165, 95), 11, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
warnLabel.TextWrapped = true
warnLabel.ZIndex = 11

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

local slotsLabel = Instance.new("TextLabel")
slotsLabel.Name                   = "SlotsLabel"
slotsLabel.Text                   = "Rebirth level: 0"
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
-- 8. MISE À JOUR DE L'INTERFACE DEPUIS L'ÉTAT
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

local function updateFromEtat(etat)
    if not etat then return end
    dernierEtat = etat

    -- Bouton principal désactivé — accès uniquement via le Board devant la base
    mainBtn.Visible = false

    if not menuOuvert then return end

    local niveau    = etat.rebirthLevel or 0
    local prochain  = etat.prochainLevel or (niveau + 1)
    local coinsA    = etat.coinsActuels or 0
    local coinsR    = etat.coinsRequis  or 0
    local rarete    = etat.brainRotRequis or "?"
    local brOk      = etat.manqueBR == nil
    local mult      = etat.multiplicateur or 1

    levelLabel.Text = "Level " .. niveau .. "  →  " .. prochain
    if etat.label then
        levelLabel.Text = etat.label .. "  (Level " .. niveau .. " → " .. prochain .. ")"
    end

    -- Coins
    local ratio = coinsR > 0 and math.min(coinsA / coinsR, 1) or 0
    tween(barFill, TweenInfo.new(0.3), { Size = UDim2.new(ratio, 0, 1, 0) })
    barFill.BackgroundColor3 = ratio >= 1 and C.GREEN or C.BROWN
    barText.Text      = fmtNumber(coinsA) .. " / " .. fmtNumber(coinsR)
    moneyAmounts.Text = fmtCompact(coinsA) .. " / " .. fmtCompact(coinsR)

    local coinsOk = (etat.manqueCoins or 0) == 0
    if coinsOk then
        moneyStatus.Text       = "Suffisant"
        moneyStatus.TextColor3 = C.GREEN
    else
        moneyStatus.Text       = fmtNumber(etat.manqueCoins) .. " manquant"
        moneyStatus.TextColor3 = C.RED
    end

    -- Rareté
    local rarityColor = C.RARITY[rarete] or C.WHITE
    rarityRequired.Text       = "Required: " .. rarete
    rarityRequired.TextColor3 = rarityColor
    if brOk then
        rarityStatus.Text       = "Owned"
        rarityStatus.TextColor3 = C.GREEN
    else
        rarityStatus.Text       = "Not owned (" .. (etat.manqueBRActuel or 0) .. "/" .. (etat.manqueBRRequis or 1) .. ")"
        rarityStatus.TextColor3 = C.RED
    end

    -- Récompense
    rewardText.Text = "+1 Slot  x" .. string.format("%.1f", mult) .. " multiplicateur"

    -- Bas du popup
    slotsLabel.Text = "Rebirth level: " .. niveau

    -- Bouton confirm
    setConfirmEnabled(etat.disponible == true)
    resultLabel.Text = ""
end

-- ═══════════════════════════════════════════════
-- 9. OUVERTURE / FERMETURE
-- ═══════════════════════════════════════════════

local function openMenu()
    menuOuvert      = true
    overlay.Visible = true
    popup.Visible   = true
    popup.Size      = UDim2.new(0, 440, 0, 0)
    tween(popup, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        { Size = UDim2.new(0, 440, 0, 530) })
    -- Afficher l'état déjà connu (RebirthButtonUpdate est en push)
    if dernierEtat then updateFromEtat(dernierEtat) end
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
-- 10. CONNEXION DES BOUTONS
-- ═══════════════════════════════════════════════

mainBtn.MouseButton1Click:Connect(function()
    if menuOuvert then closeMenu() else openMenu() end
end)

closeBtn.MouseButton1Click:Connect(closeMenu)
overlay.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then closeMenu() end
end)

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

confirmBtn.MouseButton1Click:Connect(function()
    if not confirmBtn.Active or rebirthEnCours then return end
    rebirthEnCours        = true
    confirmBtn.Text       = "En cours..."
    confirmBtn.Active     = false
    resultLabel.Text      = ""
    resultLabel.TextColor3 = C.MUTED
    DemandeRebirth:FireServer()
end)

-- ═══════════════════════════════════════════════
-- 11. REMOTES ENTRANTS
-- ═══════════════════════════════════════════════

-- Push toutes les 5s + après chaque collecte
RebirthButtonUpdate.OnClientEvent:Connect(function(etat)
    rebirthEnCours = false  -- débloquer le bouton si un rebirth vient de se terminer
    updateFromEtat(etat)
end)

-- Animation rebirth (cosmétique)
if RebirthAnimation then
    RebirthAnimation.OnClientEvent:Connect(function(info)
        resultLabel.Text       = (info.label or "REBIRTH") .. "  x" .. string.format("%.1f", info.multiplicateur or 1)
        resultLabel.TextColor3 = C.GREEN
        if menuOuvert then
            task.delay(2, closeMenu)
        end
    end)
end

-- Ouverture depuis un Board cliqué
if OuvrirRebirth then
    OuvrirRebirth.OnClientEvent:Connect(function()
        if not menuOuvert then openMenu() end
    end)
end

print("[RebirthClient] Système Rebirth client prêt ✓")