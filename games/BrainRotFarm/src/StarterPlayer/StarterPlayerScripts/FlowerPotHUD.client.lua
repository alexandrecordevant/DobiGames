-- StarterPlayer/StarterPlayerScripts/Common/FlowerPotHUD.client.lua
-- DobiGames — Interface pots de fleurs : plantation, croissance, Daily Seed

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local Logger            = require(game:GetService("ReplicatedStorage").SharedLib.Logger)

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
local UpdateGraines    = ReplicatedStorage:WaitForChild("UpdateGraines",  10)

if not OuvrirPot then
    Logger.warn("HUD", "[FlowerPotHUD] OuvrirPot RemoteEvent not found — aborting")
    return
end

-- ============================================================
-- Config locale (pour les prix/textes affichés)
-- ============================================================
local Config   = require(ReplicatedStorage:WaitForChild("GameConfig"))
local FPConfig = Config.FlowerPotConfig
local T        = require(ReplicatedStorage:WaitForChild("SharedLib")
    :WaitForChild("Shared"):WaitForChild("UITheme"))

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
mainFrame.BackgroundColor3       = T.fondPrincipal
mainFrame.BackgroundTransparency = 0
mainFrame.BorderSizePixel        = 0
mainFrame.Visible                = false
mainFrame.ZIndex                 = 11
mainFrame.Parent                 = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 14)

local uiStroke = Instance.new("UIStroke", mainFrame)
uiStroke.Color     = T.bordureAccent
uiStroke.Thickness = 2

-- Titre
local titleLabel = Instance.new("TextLabel")
titleLabel.Name                   = "Title"
titleLabel.Size                   = UDim2.new(1, -44, 0, 44)
titleLabel.Position               = UDim2.new(0, 12, 0, 6)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3             = T.texteTitre
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
sep.BackgroundColor3 = T.bordure
sep.BorderSizePixel  = 0
sep.ZIndex           = 12
sep.Parent           = mainFrame

-- Bouton fermer
local closeBtn = Instance.new("TextButton")
closeBtn.Size              = UDim2.new(0, 32, 0, 32)
closeBtn.Position          = UDim2.new(1, -38, 0, 6)
closeBtn.BackgroundColor3  = T.fondBoutonDanger
closeBtn.Text              = "✕"
closeBtn.TextColor3        = T.texte
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
scrollFrame.ScrollBarImageColor3 = T.bordure
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
    btn.BackgroundColor3  = color or T.fondBouton
    btn.Text              = text
    btn.TextColor3        = T.texte
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
    lbl.TextColor3             = couleur or T.texte
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
        "No seeds in your inventory. Collect seeds from the <b>Sacred Trees</b> or claim your Daily Seed below.",
        Color3.fromRGB(200, 200, 200), 40, 1)

    -- Séparateur Daily Seed
    local sepLbl = Instance.new("Frame")
    sepLbl.Size             = UDim2.new(1, 0, 0, 1)
    sepLbl.BackgroundColor3 = T.bordure
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
            T.fondBouton,
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
                T.fondBoutonRobux,
                nil,
                UDim2.new(1, 0, 0, 36),
                12,
                function()
                    Logger.warn("HUD", "[FlowerPotHUD] Skip Daily Seed — R$ not configured")
                end)
            skipBtn.LayoutOrder = 6
        end
    end

    -- Séparateur packs R$
    local sepPacks = Instance.new("Frame")
    sepPacks.Size             = UDim2.new(1, 0, 0, 1)
    sepPacks.BackgroundColor3 = T.bordure
    sepPacks.BorderSizePixel  = 0
    sepPacks.LayoutOrder      = 7
    sepPacks.ZIndex           = 12
    sepPacks.Parent           = scrollFrame

    -- Pack ×3 MYTHIC
    if dsCfg and dsCfg.packPrixRobux and dsCfg.packPrixRobux > 0 then
        local packBtn = creerBouton(scrollFrame,
            "🎁 Seed Pack ×3 MYTHIC — " .. dsCfg.packPrixRobux .. " R$",
            T.fondBoutonRobux,
            nil,
            UDim2.new(1, 0, 0, 36),
            12,
            function()
                Logger.warn("HUD", "[FlowerPotHUD] Seed Pack — R$ not configured")
            end)
        packBtn.LayoutOrder = 8
    end

    -- 1 SECRET garanti
    if dsCfg and dsCfg.premiumPrixRobux and dsCfg.premiumPrixRobux > 0 then
        local premBtn = creerBouton(scrollFrame,
            "👑 1 SECRET Seed — " .. dsCfg.premiumPrixRobux .. " R$",
            T.fondBoutonDanger,
            nil,
            UDim2.new(1, 0, 0, 36),
            12,
            function()
                Logger.warn("HUD", "[FlowerPotHUD] SECRET Seed Pack — R$ not configured")
            end)
        premBtn.LayoutOrder = 9
    end

    -- Bouton fermer
    creerBouton(actionFrame, "Close",
        T.fondBoutonDanger,
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
    barContainer.BackgroundColor3 = T.barreVide
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

    -- Temps restant / prêt (countdown local)
    if stage < 4 then
        local timerLbl = creerLigne("⏱ Ready in: " .. formatTemps(tRestant),
            Color3.fromRGB(180, 230, 255), 26, 3)
        local countdown = tRestant
        task.spawn(function()
            while mainFrame.Visible and timerLbl.Parent and countdown > 0 do
                task.wait(1)
                countdown = countdown - 1
                if timerLbl.Parent then
                    timerLbl.Text = "⏱ Ready in: " .. formatTemps(countdown)
                end
            end
        end)

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
            T.fondBoutonRobux,
            UDim2.new(0, 0, 0, 0),
            UDim2.new(0.48, 0, 1, 0),
            12,
            function()
                InstantGrowPot:FireServer(potIndex)
                fermer()
            end)
    end

    creerBouton(actionFrame, "Close",
        T.fondBoutonDanger,
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
        T.fondBouton,
        UDim2.new(0, 0, 0, 0),
        UDim2.new(0.48, 0, 1, 0),
        12,
        function()
            DebloquerPot:FireServer(potIndex)
            fermer()
        end)

    creerBouton(actionFrame, "Cancel",
        T.fondBoutonDanger,
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
                pot.rarete and T.fondBoutonDanger or T.fondBouton,
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
        T.fondBoutonDanger,
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
        T.fondBouton,
        UDim2.new(0, 0, 0, 0),
        UDim2.new(0.48, 0, 1, 0),
        12,
        function()
            local re = ReplicatedStorage:FindFirstChild("ConfirmerEcrasement")
            if re then re:FireServer(potIndex) end
            fermer()
        end)

    creerBouton(actionFrame, "Cancel",
        T.fondBoutonDanger,
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
dailySeedButton.Size                   = UDim2.new(0, 120, 0, 55)
dailySeedButton.Position               = UDim2.new(0, 10, 0.5, 50)
dailySeedButton.BackgroundColor3       = T.fondBouton
dailySeedButton.BackgroundTransparency = 0.1
dailySeedButton.TextColor3             = T.texte
dailySeedButton.Font                   = Enum.Font.GothamBold
dailySeedButton.TextSize               = 14
dailySeedButton.RichText               = true
dailySeedButton.Text                   = "🌱 Day 1/7"
dailySeedButton.BorderSizePixel        = 0
dailySeedButton.ZIndex                 = 10
local _dsCorner = Instance.new("UICorner", dailySeedButton)
_dsCorner.CornerRadius = UDim.new(0, 10)

local _pulseTween = nil

local function SetSeedReady(ready)
    if _pulseTween then _pulseTween:Cancel() end
    if ready then
        dailySeedButton.BackgroundColor3 = T.barrePleine
        _pulseTween = TweenService:Create(
            dailySeedButton,
            TweenInfo.new(0.8, Enum.EasingStyle.Sine,
                Enum.EasingDirection.InOut, -1, true),
            { BackgroundTransparency = 0.5 }
        )
        _pulseTween:Play()
    else
        dailySeedButton.BackgroundColor3       = T.fondBouton
        dailySeedButton.BackgroundTransparency = 0.1
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
    panel.BackgroundColor3       = T.fondPrincipal
    panel.BackgroundTransparency = 0.05
    panel.BorderSizePixel        = 0
    panel.ZIndex                 = 20
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
    local _panelStroke = Instance.new("UIStroke", panel)
    _panelStroke.Color     = T.bordureAccent
    _panelStroke.Thickness = 2

    -- Titre
    local titre = Instance.new("TextLabel", panel)
    titre.Size                   = UDim2.new(1, -50, 0, 40)
    titre.Position               = UDim2.new(0, 10, 0, 10)
    titre.BackgroundTransparency = 1
    titre.Text                   = "🌱 DAILY SEEDS"
    titre.TextColor3             = T.texteTitre
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
    btnClose.TextColor3             = T.texteSecondaire
    btnClose.Font                   = Enum.Font.GothamBold
    btnClose.TextSize               = 18
    btnClose.ZIndex                 = 21
    btnClose.MouseButton1Click:Connect(function() panel:Destroy() end)

    -- Separateur
    local sep1 = Instance.new("Frame", panel)
    sep1.Size             = UDim2.new(1, -20, 0, 1)
    sep1.Position         = UDim2.new(0, 10, 0, 55)
    sep1.BackgroundColor3 = T.bordure
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
        ligne.BackgroundTransparency = statut == "dispo" and 0.3 or 0.7
        ligne.BackgroundColor3       = statut == "dispo"
            and T.fondBouton or T.fondSecondaire
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
            btnClaim.BackgroundColor3       = T.barrePleine
            btnClaim.TextColor3             = T.texte
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
    sep2.BackgroundColor3 = T.bordure
    sep2.BorderSizePixel  = 0
    sep2.ZIndex           = 21

    -- Boutons R$
    local btnSkip = Instance.new("TextButton", panel)
    btnSkip.Size                   = UDim2.new(0, 135, 0, 32)
    btnSkip.Position               = UDim2.new(0, 10, 1, -45)
    btnSkip.BackgroundColor3       = T.fondBoutonRobux
    btnSkip.TextColor3             = T.fondPrincipal
    btnSkip.Font                   = Enum.Font.GothamBold
    btnSkip.TextSize               = 12
    btnSkip.Text                   = "⚡ Skip — 25 R$"
    btnSkip.BorderSizePixel        = 0
    btnSkip.ZIndex                 = 21
    Instance.new("UICorner", btnSkip).CornerRadius = UDim.new(0, 6)

    local btnPack = Instance.new("TextButton", panel)
    btnPack.Size                   = UDim2.new(0, 145, 0, 32)
    btnPack.Position               = UDim2.new(1, -155, 1, -45)
    btnPack.BackgroundColor3       = T.fondBoutonRobux
    btnPack.TextColor3             = T.fondPrincipal
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
-- Bouton FlowerPot + Panel standalone (sous Day, même espace inset)
-- ============================================================

-- Panel pots (caché par défaut)
local fpPanel = Instance.new("Frame", screenGui)
fpPanel.Name                   = "FlowerPotPanel"
fpPanel.Size                   = UDim2.new(0, 280, 0, 180)
fpPanel.Position               = UDim2.new(0, 140, 0.5, 50)
fpPanel.BackgroundColor3       = T.fondPrincipal
fpPanel.BackgroundTransparency = 0.05
fpPanel.BorderSizePixel        = 0
fpPanel.Visible                = false
fpPanel.ZIndex                 = 20
Instance.new("UICorner", fpPanel).CornerRadius = UDim.new(0, 12)
local _fpStroke = Instance.new("UIStroke", fpPanel)
_fpStroke.Color = T.bordureAccent ; _fpStroke.Thickness = 2

local fpTitre = Instance.new("TextLabel", fpPanel)
fpTitre.Size = UDim2.new(1,-44,0,32) ; fpTitre.Position = UDim2.new(0,10,0,4)
fpTitre.BackgroundTransparency = 1 ; fpTitre.TextColor3 = T.texteTitre
fpTitre.Font = Enum.Font.GothamBold ; fpTitre.TextSize = 14
fpTitre.TextXAlignment = Enum.TextXAlignment.Left
fpTitre.Text = "🪴 État des FlowerPots" ; fpTitre.ZIndex = 21

local fpClose = Instance.new("TextButton", fpPanel)
fpClose.Size = UDim2.new(0,28,0,28) ; fpClose.Position = UDim2.new(1,-34,0,4)
fpClose.BackgroundColor3 = T.fondBoutonDanger ; fpClose.Text = "✕"
fpClose.TextColor3 = T.texte ; fpClose.Font = Enum.Font.GothamBold
fpClose.TextSize = 13 ; fpClose.BorderSizePixel = 0 ; fpClose.ZIndex = 21
Instance.new("UICorner", fpClose).CornerRadius = UDim.new(0, 6)
fpClose.MouseButton1Click:Connect(function() fpPanel.Visible = false end)

-- Inventaire graines
local fpInv = Instance.new("Frame", fpPanel)
fpInv.Size = UDim2.new(1,-20,0,26) ; fpInv.Position = UDim2.new(0,10,0,40)
fpInv.BackgroundColor3 = T.fondSecondaire ; fpInv.BorderSizePixel = 0 ; fpInv.ZIndex = 21
Instance.new("UICorner", fpInv).CornerRadius = UDim.new(0, 6)
local fpMythicLbl = Instance.new("TextLabel", fpInv)
fpMythicLbl.Size = UDim2.new(0.5,0,1,0) ; fpMythicLbl.BackgroundTransparency = 1
fpMythicLbl.Text = "⚡ MYTHIC: 0" ; fpMythicLbl.TextColor3 = Color3.fromRGB(180,0,255)
fpMythicLbl.Font = Enum.Font.GothamBold ; fpMythicLbl.TextSize = 11
fpMythicLbl.TextXAlignment = Enum.TextXAlignment.Center ; fpMythicLbl.ZIndex = 22
local fpSecretLbl = Instance.new("TextLabel", fpInv)
fpSecretLbl.Size = UDim2.new(0.5,0,1,0) ; fpSecretLbl.Position = UDim2.new(0.5,0,0,0)
fpSecretLbl.BackgroundTransparency = 1
fpSecretLbl.Text = "🔴 SECRET: 0" ; fpSecretLbl.TextColor3 = Color3.fromRGB(255,80,80)
fpSecretLbl.Font = Enum.Font.GothamBold ; fpSecretLbl.TextSize = 11
fpSecretLbl.TextXAlignment = Enum.TextXAlignment.Center ; fpSecretLbl.ZIndex = 22

-- 4 cellules pots
local FP_ELEM = { water="💧", fire="🔥", earth="🌍", wind="💨" }
local FP_RARCOL = { MYTHIC=Color3.fromRGB(180,0,255), SECRET=Color3.fromRGB(255,80,80) }
local fpCells = {}
for i = 1, 4 do
    local cw, ch = 58, 82
    local cell = Instance.new("Frame", fpPanel)
    cell.Size = UDim2.new(0,cw,0,ch)
    cell.Position = UDim2.new(0, 10+(i-1)*(cw+6), 0, 74)
    cell.BackgroundColor3 = T.fondSecondaire ; cell.BorderSizePixel = 0 ; cell.ZIndex = 21
    Instance.new("UICorner", cell).CornerRadius = UDim.new(0, 8)
    local function cl(txt, sz, pos, ts, bold)
        local l = Instance.new("TextLabel", cell)
        l.Size=sz ; l.Position=pos ; l.BackgroundTransparency=1
        l.Text=txt ; l.TextColor3=T.texte
        l.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
        l.TextSize=ts ; l.ZIndex=22 ; return l
    end
    cl("Pot "..i, UDim2.new(1,0,0,14), UDim2.new(0,0,0,2),  8,  false)
    local ic = cl("🔒",  UDim2.new(1,0,0,28), UDim2.new(0,0,0,16), 20, true)
    local ra = cl("",    UDim2.new(1,-4,0,14),UDim2.new(0,2,0,44),  8,  true)
    local el = cl("",    UDim2.new(1,0,0,14), UDim2.new(0,0,0,60), 10,  false)
    table.insert(fpCells, {cell=cell, ic=ic, ra=ra, el=el})
end

local function fpMajAffichage(pots, graines)
    local nbReady, nbGrow = 0, 0
    for i, f in ipairs(fpCells) do
        local p = pots and pots[i]
        if not p then f.ic.Text="?"; f.ra.Text=""; f.el.Text=""
        elseif not p.debloque then
            f.ic.Text="🔒"; f.ic.TextColor3=T.texte; f.ra.Text="Verr."; f.el.Text=""
            f.cell.BackgroundColor3=T.fondSecondaire
        elseif p.statut == nil then
            f.ic.Text="🪴"; f.ic.TextColor3=T.texte; f.ra.Text="Vide"; f.el.Text=""
            f.cell.BackgroundColor3=T.fondSecondaire
        elseif p.statut.statut == "growing" then
            local s=p.statut
            f.ic.Text="🌱"; f.ic.TextColor3=Color3.fromRGB(100,200,255)
            f.ra.Text=(s.rarity=="SECRET" and "SEC" or "MYT").." S"..math.max(0,s.stage or 0)
            f.ra.TextColor3=FP_RARCOL[s.rarity] or T.texte
            f.el.Text=s.elementType and FP_ELEM[s.elementType] or ""
            f.cell.BackgroundColor3=Color3.fromRGB(15,28,35); nbGrow=nbGrow+1
        elseif p.statut.statut == "ready" then
            local s=p.statut
            f.ic.Text="🎯"; f.ic.TextColor3=Color3.fromRGB(255,180,0)
            f.ra.Text=s.rarity=="SECRET" and "SECRET" or "MYTHIC"
            f.ra.TextColor3=FP_RARCOL[s.rarity] or T.texte
            f.el.Text=s.elementType and FP_ELEM[s.elementType] or "✨"
            f.cell.BackgroundColor3=Color3.fromRGB(35,25,10); nbReady=nbReady+1
        end
    end
    if graines then
        fpMythicLbl.Text = "⚡ MYTHIC: "..(graines.MYTHIC or 0)
        fpSecretLbl.Text = "🔴 SECRET: "..(graines.SECRET or 0)
    end
    -- Texte bouton
    local btnFlowerPot = screenGui:FindFirstChild("FlowerPotButton")
    if btnFlowerPot then
        if nbReady > 0 then btnFlowerPot.Text = "🪴 FlowerPot\n✅ "..nbReady.." prêt!"
        elseif nbGrow > 0 then btnFlowerPot.Text = "🪴 FlowerPot\n🌱 "..nbGrow.." pousse"
        else btnFlowerPot.Text = "🪴 FlowerPot" end
    end
end

-- Cache local des données (mis à jour par événements)
local fpPotsCache   = {}
local fpGrainesCache = nil

-- Surcharge de fpMajAffichage pour sauvegarder dans le cache
local _fpMajBase = fpMajAffichage
fpMajAffichage = function(pots, graines)
    if pots   then fpPotsCache    = pots   end
    if graines then fpGrainesCache = graines end
    _fpMajBase(fpPotsCache, fpGrainesCache)
end

local fpGetSeedInfo = nil
task.spawn(function()
    fpGetSeedInfo = ReplicatedStorage:WaitForChild("GetSeedInfo", 20)
end)

-- Bouton FlowerPot
local btnFlowerPot = Instance.new("TextButton", screenGui)
btnFlowerPot.Name                   = "FlowerPotButton"
btnFlowerPot.Size                   = UDim2.new(0, 120, 0, 55)
btnFlowerPot.Position               = UDim2.new(0, 10, 0.5, 113)
btnFlowerPot.BackgroundColor3       = T.fondBouton
btnFlowerPot.BackgroundTransparency = 0.1
btnFlowerPot.TextColor3             = T.texte
btnFlowerPot.Font                   = Enum.Font.GothamBold
btnFlowerPot.TextSize               = 14
btnFlowerPot.Text                   = "🪴 FlowerPot"
btnFlowerPot.TextWrapped            = true
btnFlowerPot.BorderSizePixel        = 0
btnFlowerPot.ZIndex                 = 10
Instance.new("UICorner", btnFlowerPot).CornerRadius = UDim.new(0, 10)

btnFlowerPot.MouseButton1Click:Connect(function()
    fpPanel.Visible = not fpPanel.Visible
    if fpPanel.Visible and fpGetSeedInfo then
        task.spawn(function()
            local ok, info = pcall(function() return fpGetSeedInfo:InvokeServer() end)
            if ok and info then fpMajAffichage(info.pots, info.graines) end
        end)
    end
end)

-- Mise à jour automatique quand un pot change (PotUpdate envoie 1 pot à la fois)
if PotUpdate then
    PotUpdate.OnClientEvent:Connect(function(potIndex, potData)
        fpPotsCache[potIndex] = potData
        if fpPanel.Visible then
            fpMajAffichage(fpPotsCache, fpGrainesCache)
        end
    end)
end

-- Mise à jour automatique quand les graines changent
if UpdateGraines then
    UpdateGraines.OnClientEvent:Connect(function(graines)
        fpGrainesCache = graines
        if fpPanel.Visible then
            fpMajAffichage(fpPotsCache, fpGrainesCache)
        end
    end)
end

-- Auto-refresh toutes les 3s quand le panel est ouvert
task.spawn(function()
    while true do
        task.wait(3)
        if fpPanel.Visible and fpGetSeedInfo then
            local ok, info = pcall(function() return fpGetSeedInfo:InvokeServer() end)
            if ok and info then fpMajAffichage(info.pots, info.graines) end
        end
    end
end)

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

-- Mise à jour stock de graines (depuis ArbreSystem via UpdateGraines)
local _grainesLocales = {}
if UpdateGraines then
    UpdateGraines.OnClientEvent:Connect(function(graines)
        _grainesLocales = graines or {}
    end)
end

-- ============================================================
-- BillboardGui 3D au-dessus des pots en cours de croissance
-- ============================================================

local PotBillboardUpdate = ReplicatedStorage:WaitForChild("PotBillboardUpdate", 10)

local _billboardThreads = {}  -- [potFullName] = thread

local function supprimerBillboard(potModel)
    local key = potModel:GetFullName()
    if _billboardThreads[key] then
        pcall(task.cancel, _billboardThreads[key])
        _billboardThreads[key] = nil
    end
    local potPart = potModel:FindFirstChildWhichIsA("BasePart", true)
    if potPart then
        local gui = potPart:FindFirstChild("PotStatusBillboard")
        if gui then gui:Destroy() end
    end
end

local function creerBillboard(potModel, plantedAt, dureeStage)
    local potPart = potModel:FindFirstChildWhichIsA("BasePart", true)
    if not potPart then return end

    supprimerBillboard(potModel)

    local billboard = Instance.new("BillboardGui")
    billboard.Name             = "PotStatusBillboard"
    billboard.Size             = UDim2.new(0, 200, 0, 76)
    billboard.StudsOffset      = Vector3.new(0, 10, 0) -- mis à jour dynamiquement par la boucle
    billboard.AlwaysOnTop      = false
    billboard.MaxDistance      = 60
    billboard.ResetOnSpawn     = false
    billboard.Parent           = potPart

    -- Fond arrondi
    local bg = Instance.new("Frame", billboard)
    bg.Size                   = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3       = Color3.fromRGB(10, 10, 20)
    bg.BackgroundTransparency = 0.35
    bg.BorderSizePixel        = 0
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 8)

    local stageLbl = Instance.new("TextLabel", bg)
    stageLbl.Name                  = "StageLabel"
    stageLbl.Size                  = UDim2.new(1, 0, 0.52, 0)
    stageLbl.Position              = UDim2.new(0, 0, 0, 0)
    stageLbl.BackgroundTransparency = 1
    stageLbl.TextColor3            = Color3.fromRGB(255, 255, 255)
    stageLbl.Font                  = Enum.Font.GothamBold
    stageLbl.TextSize              = 20
    stageLbl.TextStrokeTransparency = 0.4
    stageLbl.TextStrokeColor3      = Color3.fromRGB(0, 0, 0)

    local timerLbl = Instance.new("TextLabel", bg)
    timerLbl.Name                  = "TimerLabel"
    timerLbl.Size                  = UDim2.new(1, 0, 0.48, 0)
    timerLbl.Position              = UDim2.new(0, 0, 0.52, 0)
    timerLbl.BackgroundTransparency = 1
    timerLbl.TextColor3            = Color3.fromRGB(150, 210, 255)
    timerLbl.Font                  = Enum.Font.Gotham
    timerLbl.TextSize              = 17
    timerLbl.TextStrokeTransparency = 0.4
    timerLbl.TextStrokeColor3      = Color3.fromRGB(0, 0, 0)

    -- Offset Y par stage (monte avec la plante)
    local offsetParStage = { [0]=10, [1]=13, [2]=16, [3]=19, [4]=23, [5]=23 }

    local key = potModel:GetFullName()
    _billboardThreads[key] = task.spawn(function()
        while billboard.Parent do
            local elapsed      = os.time() - plantedAt
            local etape        = math.min(5, math.floor(elapsed / dureeStage))
            local remaining    = math.max(0, dureeStage - (elapsed % dureeStage))
            local stageAffiche = math.min(4, etape)

            -- Ajuster la hauteur selon le stage courant
            local offsetY = offsetParStage[etape] or 23
            billboard.StudsOffset = Vector3.new(0, offsetY, 0)

            if etape >= 5 then
                stageLbl.Text = "🌱 Ready!"
                timerLbl.Text = "Tap to collect"
                task.wait(2)
            else
                stageLbl.Text = "🌱 Stage " .. stageAffiche .. " / 4"
                timerLbl.Text = "⏱ " .. formatTemps(remaining)
                task.wait(1)
            end
        end
        _billboardThreads[key] = nil
    end)
end

if PotBillboardUpdate then
    PotBillboardUpdate.OnClientEvent:Connect(function(potModel, data)
        if not potModel or not potModel.Parent then return end
        if not data then
            supprimerBillboard(potModel)
        else
            creerBillboard(potModel, data.plantedAt, data.dureeStage)
        end
    end)
end

Logger.info("HUD", "✓ FlowerPotHUD Initialized")
