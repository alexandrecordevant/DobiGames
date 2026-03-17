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

-- ============================================================
-- Mode : Choisir quel pot ecraser (tous les pots occupes)
-- ============================================================

local function afficherMenuChoisirPot(extraData)
    clearContent()
    titleLabel.Text = "🌱 Choose a Pot to Plant"

    local etatsPots    = extraData and extraData.etatsPots    or {}
    local raretyDuJour = extraData and extraData.raretyDuJour or "MYTHIC"

    creerLigne("All pots are occupied. Choose one to overwrite:",
        Color3.fromRGB(220, 200, 100), 32, 1)

    for i = 1, 4 do
        local pot = etatsPots[i]
        if pot and pot.debloque then
            local texte = "Pot " .. i
            if pot.rarete then
                texte = texte .. " — " .. pot.rarete .. " Stage " .. (pot.stage or 0) .. "/4"
            else
                texte = texte .. " — Empty"
            end
            local btn = creerBouton(scrollFrame,
                texte,
                pot.rarete and Color3.fromRGB(160, 60, 60) or Color3.fromRGB(60, 130, 60),
                nil,
                UDim2.new(1, 0, 0, 36),
                12,
                function()
                    local re = ReplicatedStorage:FindFirstChild("ClaimDailySeed")
                    if re then re:FireServer(i) end
                    fermer()
                end)
            btn.LayoutOrder = i + 1
        end
    end

    creerBouton(actionFrame, "Cancel",
        Color3.fromRGB(140, 40, 40),
        UDim2.new(0.25, 0, 0, 0),
        UDim2.new(0.5, 0, 1, 0),
        12, fermer)
end

-- ============================================================
-- Mode : Confirmer ecrasement d'un pot occupe
-- ============================================================

local function afficherMenuConfirmerEcrasement(potIndex, extraData)
    clearContent()
    titleLabel.Text = "⚠️ Overwrite Pot " .. potIndex .. "?"

    local ancienne = extraData and extraData.ancienne or "?"
    local stage    = extraData and extraData.stage    or 0
    local rarete   = extraData and extraData.rarete   or "MYTHIC"

    creerLigne(
        "Pot " .. potIndex .. " already has <b>" .. ancienne
        .. "</b> at Stage <b>" .. stage .. "/4</b>.",
        Color3.fromRGB(220, 180, 100), 36, 1)

    creerLigne(
        "Replace it with today's <b>" .. rarete .. "</b> seed?",
        Color3.fromRGB(200, 200, 200), 28, 2)

    creerBouton(actionFrame, "Confirm",
        Color3.fromRGB(60, 160, 80),
        UDim2.new(0, 0, 0, 0),
        UDim2.new(0.48, 0, 1, 0),
        12,
        function()
            local re = ReplicatedStorage:FindFirstChild("ConfirmerEcrasement")
            if re then re:FireServer(potIndex) end
            fermer()
        end)

    creerBouton(actionFrame, "Cancel",
        Color3.fromRGB(140, 40, 40),
        UDim2.new(0.52, 0, 0, 0),
        UDim2.new(0.48, 0, 1, 0),
        12, fermer)
end

OuvrirPot.OnClientEvent:Connect(function(potIndex, mode, extraData)
    currentPotIndex = potIndex

    if mode == "empty" then
        afficherMenuEmpty(potIndex, extraData)
    elseif mode == "infos" then
        afficherMenuInfos(potIndex, extraData)
    elseif mode == "debloque" then
        afficherMenuDebloque(potIndex)
    elseif mode == "choisir_pot" then
        afficherMenuChoisirPot(extraData)
    elseif mode == "confirmer_ecrasement" then
        afficherMenuConfirmerEcrasement(potIndex, extraData)
        ouvrirPanel()
        return
    else
        return
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

-- ============================================================
-- Bouton Daily Seed (bas gauche du HUD)
-- ============================================================

local dailySeedButton = Instance.new("TextButton", screenGui)
dailySeedButton.Name                   = "DailySeedButton"
dailySeedButton.Size                   = UDim2.new(0, 140, 0, 40)
dailySeedButton.Position               = UDim2.new(0, 10, 1, -200)
dailySeedButton.BackgroundColor3       = Color3.fromRGB(30, 120, 30)
dailySeedButton.BackgroundTransparency = 0.2
dailySeedButton.TextColor3             = Color3.fromRGB(255, 255, 255)
dailySeedButton.Font                   = Enum.Font.GothamBold
dailySeedButton.TextSize               = 14
dailySeedButton.RichText               = true
dailySeedButton.Text                   = "🌱 Day 1/7"
dailySeedButton.BorderSizePixel        = 0
dailySeedButton.ZIndex                 = 10
local _dsCorner = Instance.new("UICorner", dailySeedButton)
_dsCorner.CornerRadius = UDim.new(0, 8)

local _pulseTween = nil

local function SetSeedReady(ready)
    if _pulseTween then _pulseTween:Cancel() end
    if ready then
        dailySeedButton.BackgroundColor3 = Color3.fromRGB(0, 180, 0)
        _pulseTween = TweenService:Create(
            dailySeedButton,
            TweenInfo.new(0.8, Enum.EasingStyle.Sine,
                Enum.EasingDirection.InOut, -1, true),
            { BackgroundTransparency = 0.5 }
        )
        _pulseTween:Play()
    else
        dailySeedButton.BackgroundColor3       = Color3.fromRGB(30, 120, 30)
        dailySeedButton.BackgroundTransparency = 0.2
    end
end

-- ============================================================
-- Panel Daily Seed
-- ============================================================

local _dailySeedData = nil  -- donnees recues du serveur

local function FormatTempsLocal(secondes)
    secondes = math.floor(secondes)
    if secondes <= 0 then return "0s" end
    local h = math.floor(secondes / 3600)
    local m = math.floor((secondes % 3600) / 60)
    local s = secondes % 60
    if h > 0 then return h .. "h " .. m .. "m"
    elseif m > 0 then return m .. "m " .. s .. "s"
    else return s .. "s" end
end

local function OuvrirDailySeedPanel()
    -- Fermer panel existant
    local existing = screenGui:FindFirstChild("DailySeedPanel")
    if existing then existing:Destroy() end

    local panel = Instance.new("Frame", screenGui)
    panel.Name                   = "DailySeedPanel"
    panel.Size                   = UDim2.new(0, 320, 0, 480)
    panel.Position               = UDim2.new(0.5, -160, 0.5, -240)
    panel.BackgroundColor3       = Color3.fromRGB(20, 20, 20)
    panel.BackgroundTransparency = 0.1
    panel.BorderSizePixel        = 0
    panel.ZIndex                 = 20
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)

    -- Titre
    local titre = Instance.new("TextLabel", panel)
    titre.Size                   = UDim2.new(1, -50, 0, 40)
    titre.Position               = UDim2.new(0, 10, 0, 10)
    titre.BackgroundTransparency = 1
    titre.Text                   = "🌱 DAILY SEEDS"
    titre.TextColor3             = Color3.fromRGB(255, 255, 255)
    titre.Font                   = Enum.Font.GothamBold
    titre.TextSize               = 18
    titre.TextXAlignment         = Enum.TextXAlignment.Left
    titre.ZIndex                 = 21

    -- Bouton fermer
    local btnClose = Instance.new("TextButton", panel)
    btnClose.Size                   = UDim2.new(0, 30, 0, 30)
    btnClose.Position               = UDim2.new(1, -40, 0, 8)
    btnClose.BackgroundTransparency = 1
    btnClose.Text                   = "✕"
    btnClose.TextColor3             = Color3.fromRGB(200, 200, 200)
    btnClose.Font                   = Enum.Font.GothamBold
    btnClose.TextSize               = 18
    btnClose.ZIndex                 = 21
    btnClose.MouseButton1Click:Connect(function() panel:Destroy() end)

    -- Separateur
    local sep1 = Instance.new("Frame", panel)
    sep1.Size             = UDim2.new(1, -20, 0, 1)
    sep1.Position         = UDim2.new(0, 10, 0, 55)
    sep1.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    sep1.BorderSizePixel  = 0
    sep1.ZIndex           = 21

    -- Donnees cycle
    local dsCfg       = FPConfig and FPConfig.dailySeed or {}
    local cycle       = dsCfg.cycle or { "MYTHIC","MYTHIC","SECRET","MYTHIC","MYTHIC","SECRET","MYTHIC" }
    local jourActuel  = 1
    local graineDispo = false
    local tempsRestant = 0
    if _dailySeedData then
        if _dailySeedData.cycle then cycle = _dailySeedData.cycle end
        jourActuel   = _dailySeedData.jourActuel  or 1
        graineDispo  = _dailySeedData.graineDispo or false
        tempsRestant = _dailySeedData.tempsRestant or 0
    end

    local icones = { MYTHIC = "☄️", SECRET = "🔴" }

    for i = 1, 7 do
        local rarete = cycle[i] or "MYTHIC"
        local statut
        if i < jourActuel then
            statut = "claimed"
        elseif i == jourActuel then
            statut = graineDispo and "dispo" or "timer"
        else
            statut = "locked"
        end

        local yPos  = 65 + (i - 1) * 48
        local ligne = Instance.new("Frame", panel)
        ligne.Size                   = UDim2.new(1, -20, 0, 42)
        ligne.Position               = UDim2.new(0, 10, 0, yPos)
        ligne.BackgroundTransparency = statut == "dispo" and 0.6 or 0.9
        ligne.BackgroundColor3       = statut == "dispo"
            and Color3.fromRGB(0, 120, 0) or Color3.fromRGB(40, 40, 40)
        ligne.BorderSizePixel        = 0
        ligne.ZIndex                 = 21
        Instance.new("UICorner", ligne).CornerRadius = UDim.new(0, 6)

        local function lbl(text, x, w, color, bold, size)
            local l = Instance.new("TextLabel", ligne)
            l.Size                   = UDim2.new(0, w, 1, 0)
            l.Position               = UDim2.new(0, x, 0, 0)
            l.BackgroundTransparency = 1
            l.Text                   = text
            l.TextColor3             = color or Color3.fromRGB(200, 200, 200)
            l.Font                   = bold and Enum.Font.GothamBold or Enum.Font.Gotham
            l.TextSize               = size or 13
            l.TextXAlignment         = Enum.TextXAlignment.Left
            l.ZIndex                 = 22
            return l
        end

        lbl("Day " .. i, 8, 44, Color3.fromRGB(150, 150, 150), false, 12)
        lbl(icones[rarete] or "🌱", 52, 24, nil, false, 18)
        lbl(rarete, 78, 80,
            rarete == "SECRET" and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(180, 100, 255),
            true, 13)

        if statut == "claimed" then
            lbl("✅ Claimed", 160, 100, Color3.fromRGB(100, 200, 100), false, 12)
        elseif statut == "dispo" then
            lbl("🔓 Ready!", 160, 80, Color3.fromRGB(255, 255, 100), true, 12)
            local btnClaim = Instance.new("TextButton", ligne)
            btnClaim.Size                   = UDim2.new(0, 55, 0, 26)
            btnClaim.Position               = UDim2.new(1, -62, 0.5, -13)
            btnClaim.BackgroundColor3       = Color3.fromRGB(0, 180, 0)
            btnClaim.TextColor3             = Color3.fromRGB(255, 255, 255)
            btnClaim.Font                   = Enum.Font.GothamBold
            btnClaim.TextSize               = 12
            btnClaim.Text                   = "Claim"
            btnClaim.BorderSizePixel        = 0
            btnClaim.ZIndex                 = 23
            Instance.new("UICorner", btnClaim).CornerRadius = UDim.new(0, 6)
            btnClaim.MouseButton1Click:Connect(function()
                local re = ReplicatedStorage:FindFirstChild("ClaimDailySeed")
                if re then re:FireServer() end
                panel:Destroy()
            end)
        elseif statut == "timer" then
            lbl("⏱ " .. FormatTempsLocal(tempsRestant), 160, 130,
                Color3.fromRGB(150, 150, 150), false, 12)
        else
            lbl("🔒 Locked", 160, 100, Color3.fromRGB(100, 100, 100), false, 12)
        end
    end

    -- Separateur bas
    local sep2 = Instance.new("Frame", panel)
    sep2.Size             = UDim2.new(1, -20, 0, 1)
    sep2.Position         = UDim2.new(0, 10, 0, 405)
    sep2.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    sep2.BorderSizePixel  = 0
    sep2.ZIndex           = 21

    -- Boutons R$
    local btnSkip = Instance.new("TextButton", panel)
    btnSkip.Size                   = UDim2.new(0, 135, 0, 32)
    btnSkip.Position               = UDim2.new(0, 10, 1, -45)
    btnSkip.BackgroundColor3       = Color3.fromRGB(255, 140, 0)
    btnSkip.TextColor3             = Color3.fromRGB(255, 255, 255)
    btnSkip.Font                   = Enum.Font.GothamBold
    btnSkip.TextSize               = 12
    btnSkip.Text                   = "⚡ Skip — 25 R$"
    btnSkip.BorderSizePixel        = 0
    btnSkip.ZIndex                 = 21
    Instance.new("UICorner", btnSkip).CornerRadius = UDim.new(0, 6)

    local btnPack = Instance.new("TextButton", panel)
    btnPack.Size                   = UDim2.new(0, 145, 0, 32)
    btnPack.Position               = UDim2.new(1, -155, 1, -45)
    btnPack.BackgroundColor3       = Color3.fromRGB(150, 0, 255)
    btnPack.TextColor3             = Color3.fromRGB(255, 255, 255)
    btnPack.Font                   = Enum.Font.GothamBold
    btnPack.TextSize               = 12
    btnPack.Text                   = "🎁 Pack x3 — 99 R$"
    btnPack.BorderSizePixel        = 0
    btnPack.ZIndex                 = 21
    Instance.new("UICorner", btnPack).CornerRadius = UDim.new(0, 6)

    -- Fermer avec Escape
    local uis = game:GetService("UserInputService")
    local conn
    conn = uis.InputBegan:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.Escape and panel.Parent then
            panel:Destroy()
            conn:Disconnect()
        end
    end)
end

dailySeedButton.MouseButton1Click:Connect(OuvrirDailySeedPanel)

-- ============================================================
-- LeaderboardUpdate : mise a jour bouton Daily Seed
-- ============================================================

local LeaderboardUpdate = ReplicatedStorage:WaitForChild("LeaderboardUpdate", 10)
if LeaderboardUpdate then
    LeaderboardUpdate.OnClientEvent:Connect(function(payload)
        local dailySeedInfo = payload and payload.dailySeedInfo
        if dailySeedInfo then
            _dailySeedData = dailySeedInfo
            if dailySeedInfo.graineDispo then
                dailySeedButton.Text = "🌱 Seed Ready!"
                SetSeedReady(true)
            else
                local j         = dailySeedInfo.jourActuel or 1
                local remaining = dailySeedInfo.tempsRestant or 0
                if remaining > 0 then
                    dailySeedButton.Text = "🌱 Day " .. j .. "/7 " .. FormatTempsLocal(remaining)
                else
                    dailySeedButton.Text = "🌱 Day " .. j .. "/7"
                end
                SetSeedReady(false)
            end
        end
    end)
end

print("[FlowerPotHUD] ✓ Initialized")
