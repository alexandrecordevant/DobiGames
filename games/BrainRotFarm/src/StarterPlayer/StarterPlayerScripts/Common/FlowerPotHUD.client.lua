-- StarterPlayer/StarterPlayerScripts/Common/FlowerPotHUD.client.lua
-- DobiGames — Interface pots de fleurs : plantation, croissance, Daily Seed

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ============================================================
-- RemoteEvents
-- ============================================================
local OuvrirPot        = ReplicatedStorage:WaitForChild("OuvrirPot",    10)
local PotUpdate        = ReplicatedStorage:WaitForChild("PotUpdate",    10)
local DebloquerPot     = ReplicatedStorage:WaitForChild("DebloquerPot", 10)
local InstantGrowPot   = ReplicatedStorage:WaitForChild("InstantGrowPot", 10)
local ClaimDailySeed   = ReplicatedStorage:WaitForChild("ClaimDailySeed", 10)

if not OuvrirPot then
    warn("[FlowerPotHUD] OuvrirPot RemoteEvent not found — aborting")
    return
end

-- ============================================================
-- Config locale (pour les prix/textes affichés)
-- ============================================================
local Config   = require(ReplicatedStorage:WaitForChild("Specialized")
    :WaitForChild("GameConfig"))
local FPConfig = Config.FlowerPotConfig

-- ============================================================
-- GUI principale
-- ============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "FlowerPotHUD"
screenGui.ResetOnSpawn   = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset = true
screenGui.Parent         = playerGui

-- Fond sombre semi-transparent (modal)
local overlay = Instance.new("Frame")
overlay.Name                   = "Overlay"
overlay.Size                   = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3       = Color3.new(0, 0, 0)
overlay.BackgroundTransparency = 0.6
overlay.BorderSizePixel        = 0
overlay.Visible                = false
overlay.ZIndex                 = 10
overlay.Parent                 = screenGui

-- Frame principale
local mainFrame = Instance.new("Frame")
mainFrame.Name                   = "MainFrame"
mainFrame.Size                   = UDim2.new(0, 340, 0, 320)
mainFrame.Position               = UDim2.new(0.5, -170, 0.5, -160)
mainFrame.BackgroundColor3       = Color3.fromRGB(18, 18, 28)
mainFrame.BackgroundTransparency = 0
mainFrame.BorderSizePixel        = 0
mainFrame.Visible                = false
mainFrame.ZIndex                 = 11
mainFrame.Parent                 = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 14)

local uiStroke = Instance.new("UIStroke", mainFrame)
uiStroke.Color     = Color3.fromRGB(120, 60, 200)
uiStroke.Thickness = 2

-- Titre
local titleLabel = Instance.new("TextLabel")
titleLabel.Name                   = "Title"
titleLabel.Size                   = UDim2.new(1, -44, 0, 44)
titleLabel.Position               = UDim2.new(0, 12, 0, 6)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3             = Color3.fromRGB(255, 255, 255)
titleLabel.Font                   = Enum.Font.GothamBold
titleLabel.TextSize               = 18
titleLabel.TextXAlignment         = Enum.TextXAlignment.Left
titleLabel.RichText               = true
titleLabel.Text                   = "🌱 Flower Pot"
titleLabel.ZIndex                 = 12
titleLabel.Parent                 = mainFrame

-- Séparateur
local sep = Instance.new("Frame")
sep.Size             = UDim2.new(1, -24, 0, 1)
sep.Position         = UDim2.new(0, 12, 0, 52)
sep.BackgroundColor3 = Color3.fromRGB(120, 60, 200)
sep.BorderSizePixel  = 0
sep.ZIndex           = 12
sep.Parent           = mainFrame

-- Bouton fermer
local closeBtn = Instance.new("TextButton")
closeBtn.Size              = UDim2.new(0, 32, 0, 32)
closeBtn.Position          = UDim2.new(1, -38, 0, 6)
closeBtn.BackgroundColor3  = Color3.fromRGB(180, 40, 40)
closeBtn.Text              = "✕"
closeBtn.TextColor3        = Color3.new(1, 1, 1)
closeBtn.Font              = Enum.Font.GothamBold
closeBtn.TextSize          = 16
closeBtn.BorderSizePixel   = 0
closeBtn.ZIndex            = 12
closeBtn.Parent            = mainFrame
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

-- Zone de contenu scrollable
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name              = "Content"
scrollFrame.Size              = UDim2.new(1, -24, 1, -110)
scrollFrame.Position          = UDim2.new(0, 12, 0, 58)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel   = 0
scrollFrame.ScrollBarThickness = 4
scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(120, 60, 200)
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollFrame.ZIndex            = 12
scrollFrame.Parent            = mainFrame

local contentLayout = Instance.new("UIListLayout", scrollFrame)
contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
contentLayout.Padding   = UDim.new(0, 8)

-- Zone des boutons d'action (bas)
local actionFrame = Instance.new("Frame")
actionFrame.Name                   = "Actions"
actionFrame.Size                   = UDim2.new(1, -24, 0, 44)
actionFrame.Position               = UDim2.new(0, 12, 1, -52)
actionFrame.BackgroundTransparency = 1
actionFrame.ZIndex                 = 12
actionFrame.Parent                 = mainFrame

-- ============================================================
-- Utilitaires UI
-- ============================================================

local currentPotIndex = nil

local function clearContent()
    for _, c in ipairs(scrollFrame:GetChildren()) do
        if not c:IsA("UIListLayout") then c:Destroy() end
    end
    for _, c in ipairs(actionFrame:GetChildren()) do c:Destroy() end
end

local function creerBouton(parent, text, color, pos, size, zIndex, callback)
    local btn = Instance.new("TextButton")
    btn.Size              = size or UDim2.new(0.48, 0, 1, 0)
    btn.Position          = pos  or UDim2.new(0, 0, 0, 0)
    btn.BackgroundColor3  = color or Color3.fromRGB(60, 160, 80)
    btn.Text              = text
    btn.TextColor3        = Color3.new(1, 1, 1)
    btn.Font              = Enum.Font.GothamBold
    btn.TextSize          = 14
    btn.BorderSizePixel   = 0
    btn.TextWrapped       = true
    btn.ZIndex            = zIndex or 12
    btn.Parent            = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    if callback then btn.MouseButton1Click:Connect(callback) end
    return btn
end

local function creerLigne(texte, couleur, taille, ordre, zIndex)
    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.new(1, 0, 0, taille or 28)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = texte
    lbl.TextColor3             = couleur or Color3.fromRGB(220, 220, 220)
    lbl.Font                   = Enum.Font.Gotham
    lbl.TextSize               = 14
    lbl.TextXAlignment         = Enum.TextXAlignment.Left
    lbl.TextWrapped            = true
    lbl.RichText               = true
    lbl.LayoutOrder            = ordre or 1
    lbl.ZIndex                 = zIndex or 12
    lbl.Parent                 = scrollFrame
    return lbl
end

local function ouvrirPanel()
    overlay.Visible   = true
    mainFrame.Visible = true
    mainFrame.Size    = UDim2.new(0, 0, 0, 0)
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    TweenService:Create(mainFrame, TweenInfo.new(0.22, Enum.EasingStyle.Back),
        {
            Size     = UDim2.new(0, 340, 0, 320),
            Position = UDim2.new(0.5, -170, 0.5, -160),
        }):Play()
end

local function fermer()
    TweenService:Create(mainFrame, TweenInfo.new(0.15, Enum.EasingStyle.Quad),
        {
            Size     = UDim2.new(0, 0, 0, 0),
            Position = UDim2.new(0.5, 0, 0.5, 0),
        }):Play()
    task.wait(0.16)
    mainFrame.Visible = false
    overlay.Visible   = false
    currentPotIndex   = nil
end

closeBtn.MouseButton1Click:Connect(fermer)
overlay.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
        fermer()
    end
end)

local function formatTemps(secs)
    if not secs or secs <= 0 then return "Ready!" end
    secs = math.floor(secs)
    local h = math.floor(secs / 3600)
    local m = math.floor((secs % 3600) / 60)
    local s = secs % 60
    if h > 0 then
        return h .. "h " .. string.format("%02d", m) .. "m"
    elseif m > 0 then
        return m .. "m " .. string.format("%02d", s) .. "s"
    else
        return s .. "s"
    end
end

-- ============================================================
-- Mode : Pot vide (pas de BR plantable dans carry)
-- ============================================================

local function afficherMenuEmpty(potIndex, dailySeedData)
    clearContent()
    titleLabel.Text = "🌱 FLOWER POT " .. potIndex

    -- Instruction principale
    creerLigne(
        "Carry a <b>MYTHIC</b> or <b>SECRET</b> Brain Rot to plant it here.",
        Color3.fromRGB(200, 200, 200), 40, 1)

    -- Séparateur Daily Seed
    local sepLbl = Instance.new("Frame")
    sepLbl.Size             = UDim2.new(1, 0, 0, 1)
    sepLbl.BackgroundColor3 = Color3.fromRGB(120, 60, 200)
    sepLbl.BorderSizePixel  = 0
    sepLbl.LayoutOrder      = 2
    sepLbl.ZIndex           = 12
    sepLbl.Parent           = scrollFrame

    -- Titre Daily Seed
    creerLigne("🎁 DAILY SEED",
        Color3.fromRGB(255, 215, 0), 28, 3)

    -- État daily seed
    local dsCfg = FPConfig and FPConfig.dailySeed
    local ds    = dailySeedData or {}
    local jour  = ds.jourActuel or 1
    local cycle = dsCfg and dsCfg.cycle or {}
    local prochainRarete = cycle[jour] or "MYTHIC"

    creerLigne("Day " .. jour .. " — " .. prochainRarete .. " Seed",
        Color3.fromRGB(180, 180, 255), 24, 4)

    if ds.graineDispo then
        -- Disponible
        creerLigne("✅ Ready to claim!",
            Color3.fromRGB(100, 255, 120), 24, 5)

        local claimBtn = creerBouton(scrollFrame,
            "🌱 Claim",
            Color3.fromRGB(60, 160, 80),
            nil,
            UDim2.new(1, 0, 0, 36),
            12,
            function()
                ClaimDailySeed:FireServer()
                fermer()
            end)
        claimBtn.LayoutOrder = 6

    else
        -- Pas encore disponible
        local derniere = ds.dernieresClaim or 0
        local seuil    = dsCfg and dsCfg.intervalleHeures * 3600 or 86400
        local remaining = math.max(0, seuil - (os.time() - derniere))

        creerLigne("⏱ Next in: " .. formatTemps(remaining),
            Color3.fromRGB(200, 180, 100), 24, 5)

        -- Skip R$
        if dsCfg and dsCfg.skipPrixRobux and dsCfg.skipPrixRobux > 0 then
            local skipBtn = creerBouton(scrollFrame,
                "⚡ Skip — " .. dsCfg.skipPrixRobux .. " R$",
                Color3.fromRGB(100, 40, 180),
                nil,
                UDim2.new(1, 0, 0, 36),
                12,
                function()
                    warn("[FlowerPotHUD] Skip Daily Seed — R$ not configured")
                end)
            skipBtn.LayoutOrder = 6
        end
    end

    -- Séparateur packs R$
    local sepPacks = Instance.new("Frame")
    sepPacks.Size             = UDim2.new(1, 0, 0, 1)
    sepPacks.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
    sepPacks.BorderSizePixel  = 0
    sepPacks.LayoutOrder      = 7
    sepPacks.ZIndex           = 12
    sepPacks.Parent           = scrollFrame

    -- Pack ×3 MYTHIC
    if dsCfg and dsCfg.packPrixRobux and dsCfg.packPrixRobux > 0 then
        local packBtn = creerBouton(scrollFrame,
            "🎁 Seed Pack ×3 MYTHIC — " .. dsCfg.packPrixRobux .. " R$",
            Color3.fromRGB(120, 60, 0),
            nil,
            UDim2.new(1, 0, 0, 36),
            12,
            function()
                warn("[FlowerPotHUD] Seed Pack — R$ not configured")
            end)
        packBtn.LayoutOrder = 8
    end

    -- 1 SECRET garanti
    if dsCfg and dsCfg.premiumPrixRobux and dsCfg.premiumPrixRobux > 0 then
        local premBtn = creerBouton(scrollFrame,
            "👑 1 SECRET Seed — " .. dsCfg.premiumPrixRobux .. " R$",
            Color3.fromRGB(150, 0, 0),
            nil,
            UDim2.new(1, 0, 0, 36),
            12,
            function()
                warn("[FlowerPotHUD] SECRET Seed Pack — R$ not configured")
            end)
        premBtn.LayoutOrder = 9
    end

    -- Bouton fermer
    creerBouton(actionFrame, "Close",
        Color3.fromRGB(140, 40, 40),
        UDim2.new(0.25, 0, 0, 0),
        UDim2.new(0.5, 0, 1, 0),
        12, fermer)
end

-- ============================================================
-- Mode : Infos croissance
-- ============================================================

local function afficherMenuInfos(potIndex, potData)
    clearContent()
    local rarete    = potData and potData.rarete    or "?"
    local stage     = potData and potData.stage     or 0
    local tRestant  = potData and potData.tempsRestant or 0

    local graineCfg = FPConfig and FPConfig.graines and FPConfig.graines[rarete]

    if stage >= 4 then
        titleLabel.Text = "🌟 POT " .. potIndex .. " — MATURE!"
    else
        titleLabel.Text = "🌱 POT " .. potIndex .. " — Growing..."
    end

    -- Rareté
    creerLigne("<b>" .. rarete .. " Seed</b>",
        Color3.fromRGB(255, 215, 0), 28, 1)

    -- Barre de progression stage
    local barContainer = Instance.new("Frame")
    barContainer.Size             = UDim2.new(1, 0, 0, 30)
    barContainer.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
    barContainer.BorderSizePixel  = 0
    barContainer.LayoutOrder      = 2
    barContainer.ZIndex           = 12
    barContainer.Parent           = scrollFrame
    Instance.new("UICorner", barContainer).CornerRadius = UDim.new(0, 6)

    local barFill = Instance.new("Frame", barContainer)
    barFill.Size             = UDim2.new(math.min(stage / 4, 1), 0, 1, 0)
    barFill.BackgroundColor3 = graineCfg and graineCfg.couleurStage4
                             or Color3.fromRGB(120, 60, 200)
    barFill.BorderSizePixel  = 0
    barFill.ZIndex           = 13
    Instance.new("UICorner", barFill).CornerRadius = UDim.new(0, 6)

    local stageLbl = Instance.new("TextLabel", barContainer)
    stageLbl.Size                   = UDim2.new(1, 0, 1, 0)
    stageLbl.BackgroundTransparency = 1
    stageLbl.Text                   = "Stage " .. stage .. " / 4"
    stageLbl.TextColor3             = Color3.new(1, 1, 1)
    stageLbl.Font                   = Enum.Font.GothamBold
    stageLbl.TextSize               = 13
    stageLbl.TextXAlignment         = Enum.TextXAlignment.Center
    stageLbl.ZIndex                 = 14

    -- Temps restant / prêt
    if stage < 4 then
        creerLigne("⏱ Ready in: " .. formatTemps(tRestant),
            Color3.fromRGB(180, 230, 255), 26, 3)

        -- Multiplicateur
        if graineCfg then
            creerLigne("💰 ×" .. graineCfg.multiplicateur .. " income when deposited",
                Color3.fromRGB(255, 215, 0), 24, 4)
        end
    else
        creerLigne("✅ Ready to harvest! Approach the pot.",
            Color3.fromRGB(100, 255, 120), 26, 3)
    end

    -- Boutons d'action
    if stage < 4 then
        local igCfg = FPConfig and FPConfig.instantGrow
        creerBouton(actionFrame,
            (igCfg and igCfg.label or "⚡ Instant Grow")
            .. "  " .. (igCfg and igCfg.prixRobux or 35) .. " R$",
            Color3.fromRGB(100, 40, 180),
            UDim2.new(0, 0, 0, 0),
            UDim2.new(0.48, 0, 1, 0),
            12,
            function()
                InstantGrowPot:FireServer(potIndex)
                fermer()
            end)
    end

    creerBouton(actionFrame, "Close",
        Color3.fromRGB(140, 40, 40),
        stage < 4 and UDim2.new(0.52, 0, 0, 0) or UDim2.new(0.25, 0, 0, 0),
        stage < 4 and UDim2.new(0.48, 0, 1, 0) or UDim2.new(0.5, 0, 1, 0),
        12, fermer)
end

-- ============================================================
-- Mode : Déblocage
-- ============================================================

local function afficherMenuDebloque(potIndex)
    clearContent()
    titleLabel.Text = "🔒 POT " .. potIndex .. " — Locked"

    local potCfg = FPConfig and FPConfig.pots and FPConfig.pots[potIndex]

    local prixTexte = "Locked"
    if potCfg then
        if potCfg.prixCoins and potCfg.prixCoins > 0 then
            prixTexte = "Unlock for " .. potCfg.prixCoins .. " 💰"
        elseif potCfg.prixRobux and potCfg.prixRobux > 0 then
            prixTexte = "Unlock for " .. potCfg.prixRobux .. " R$"
        end
    end

    creerLigne(prixTexte, Color3.fromRGB(220, 220, 220), 40, 1)

    creerBouton(actionFrame, "Unlock",
        Color3.fromRGB(60, 160, 80),
        UDim2.new(0, 0, 0, 0),
        UDim2.new(0.48, 0, 1, 0),
        12,
        function()
            DebloquerPot:FireServer(potIndex)
            fermer()
        end)

    creerBouton(actionFrame, "Cancel",
        Color3.fromRGB(140, 40, 40),
        UDim2.new(0.52, 0, 0, 0),
        UDim2.new(0.48, 0, 1, 0),
        12, fermer)
end

-- ============================================================
-- Écouter OuvrirPot depuis le serveur
-- ============================================================

OuvrirPot.OnClientEvent:Connect(function(potIndex, mode, extraData)
    currentPotIndex = potIndex

    if mode == "empty" then
        afficherMenuEmpty(potIndex, extraData)
    elseif mode == "infos" then
        afficherMenuInfos(potIndex, extraData)
    elseif mode == "debloque" then
        afficherMenuDebloque(potIndex)
    end

    ouvrirPanel()
end)

-- Mise à jour temps restant (envoi serveur toutes les 10s)
if PotUpdate then
    PotUpdate.OnClientEvent:Connect(function(potIndex, potData)
        if potIndex ~= currentPotIndex then return end
        if not mainFrame.Visible then return end
        -- Mettre à jour l'affichage si le panel est ouvert sur ce pot
        afficherMenuInfos(potIndex, potData)
    end)
end

print("[FlowerPotHUD] ✓ Initialized")
