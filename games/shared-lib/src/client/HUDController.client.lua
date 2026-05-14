-- StarterPlayerScripts/HUDController.client.lua
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local player            = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local _uiThemeModule = ReplicatedStorage.SharedLib.Shared:FindFirstChild("UITheme")
if not _uiThemeModule then return end  -- HUDController BRF-only : pas de UITheme = mauvais jeu
local T = require(_uiThemeModule)

local estMobile = UserInputService.TouchEnabled
local UI_SHOP   = (Config.UI and Config.UI.Shop) or {}
local Logger       = require(game:GetService("ReplicatedStorage").SharedLib.Logger)
local FormatNumber = require(ReplicatedStorage.SharedLib.Shared.FormatNumber)

local gui = Instance.new("ScreenGui")
gui.Name          = "HUD"
gui.ResetOnSpawn  = false
gui.Parent        = player.PlayerGui

local function NouveauLabel(parent, size, pos, bgColor, textColor, text)
    local f = Instance.new("Frame", parent)
    f.Size                    = size
    f.Position                = pos
    f.BackgroundColor3        = bgColor
    f.BackgroundTransparency  = 0.3
    f.BorderSizePixel         = 0
    local l = Instance.new("TextLabel", f)
    l.Size                    = UDim2.new(1,0,1,0)
    l.BackgroundTransparency  = 1
    l.TextColor3              = textColor
    l.TextScaled              = true
    l.Font                    = Enum.Font.GothamBold
    l.Text                    = text
    return f, l
end

-- Coins (bas gauche — texte orange, outline blanc, pas de fond)
local coinsLabel = Instance.new("TextLabel", gui)
coinsLabel.Size                   = UDim2.new(0, 320, 0, 70)
coinsLabel.Position               = UDim2.new(0, 10, 1, -90)
coinsLabel.BackgroundTransparency = 1
coinsLabel.Text                   = "0"
coinsLabel.TextColor3             = Color3.fromRGB(255, 140, 42)
coinsLabel.TextStrokeColor3       = Color3.fromRGB(255, 255, 255)
coinsLabel.TextStrokeTransparency = 0
coinsLabel.TextScaled             = false
coinsLabel.TextSize               = 52
coinsLabel.Font                   = Enum.Font.GothamBold
coinsLabel.TextXAlignment         = Enum.TextXAlignment.Left

-- Event banner — bas droite, sans fond, sans emoji
local eventLabel = Instance.new("TextLabel", gui)
eventLabel.Name                   = "EventLabel"
eventLabel.Size                   = UDim2.new(0, 260, 0, 36)
eventLabel.AnchorPoint            = Vector2.new(1, 1)
eventLabel.Position               = UDim2.new(1, -12, 1, -12)
eventLabel.BackgroundTransparency = 1
eventLabel.TextColor3             = Color3.fromRGB(220, 220, 220)
eventLabel.TextXAlignment         = Enum.TextXAlignment.Right
eventLabel.TextScaled             = false
eventLabel.TextSize               = 20
eventLabel.Font                   = Enum.Font.Gotham
eventLabel.Text                   = ""
eventLabel.Visible                = false
local eventStroke = Instance.new("UIStroke", eventLabel)
eventStroke.Color     = Color3.new(0, 0, 0)
eventStroke.Thickness = 1.5
local eventFrame = eventLabel  -- alias pour compatibilité

-- Mise à jour HUD
local UpdateHUD = ReplicatedStorage:WaitForChild("UpdateHUD")
UpdateHUD.OnClientEvent:Connect(function(data)
    coinsLabel.Text = FormatNumber.format(data.coins)
end)

-- Event démarré
local EventStarted = ReplicatedStorage:WaitForChild("EventStarted")
local function formatDuree(s)
    s = math.ceil(s)
    if s >= 60 then
        return string.format("%dm %02ds", math.floor(s/60), s % 60)
    end
    return s .. "s"
end

EventStarted.OnClientEvent:Connect(function(typeEvent, duree)
    eventFrame.Visible = true
    local nomAffiche = typeEvent or "Event"
    local t = duree
    task.spawn(function()
        while t > 0 do
            eventLabel.Text = nomAffiche .. "  " .. formatDuree(t)
            task.wait(1) ; t = t - 1
        end
        eventFrame.Visible = false
    end)
end)

-- Offline income
local OIN = ReplicatedStorage:WaitForChild("OfflineIncomeNotif")
OIN.OnClientEvent:Connect(function(montant)
    local notif = Instance.new("TextLabel", gui)
    notif.Size                   = UDim2.new(0,320,0,60)
    notif.Position               = UDim2.new(0.5,-160,0.5,-30)
    notif.BackgroundColor3       = T.fondBouton
    notif.BackgroundTransparency = 0.1
    notif.TextColor3             = T.texte
    notif.TextScaled             = true
    notif.Font                   = Enum.Font.GothamBold
    notif.Text                   = "Offline : +" .. montant .. " coins"
    TweenService:Create(notif, TweenInfo.new(3),
        { Position = UDim2.new(0.5,-160,0.3,0) }):Play()
    task.delay(4, function() notif:Destroy() end)
end)

-- ============================================================
-- Effets visuels events
-- ============================================================

-- NightMode : flash noir
task.spawn(function()
    local NightModeStart = ReplicatedStorage:WaitForChild("NightModeStart", 15)
    if not NightModeStart then return end
    NightModeStart.OnClientEvent:Connect(function()
        local flash = Instance.new("Frame", gui)
        flash.Size                    = UDim2.new(1, 0, 1, 0)
        flash.BackgroundColor3        = Color3.new(0, 0, 0)
        flash.BackgroundTransparency  = 0
        flash.BorderSizePixel         = 0
        flash.ZIndex                  = 10
        -- Fade in rapide (0.3s) puis fade out (0.5s)
        TweenService:Create(flash, TweenInfo.new(0.3), { BackgroundTransparency = 0 }):Play()
        task.wait(0.35)
        TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
        task.delay(0.9, function() flash:Destroy() end)
    end)
end)

-- MeteorImpact : shake caméra selon distance au joueur
task.spawn(function()
    local MeteorImpact = ReplicatedStorage:WaitForChild("MeteorImpact", 15)
    if not MeteorImpact then return end
    local camera = workspace.CurrentCamera
    MeteorImpact.OnClientEvent:Connect(function(impactPos)
        if not camera or not player.Character then return end
        local hrp = player.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        -- Intensité diminue avec la distance
        local dist      = (hrp.Position - Vector3.new(impactPos.X, hrp.Position.Y, impactPos.Z)).Magnitude
        local intensite = math.clamp(1 - dist / 200, 0, 1)
        if intensite < 0.05 then return end

        task.spawn(function()
            local cameraOffset = Vector3.new(0, 0, 0)
            local infoShake    = TweenInfo.new(0.05, Enum.EasingStyle.Quad)
            for i = 1, 8 do
                if not camera then break end
                local amplitude = intensite * 0.5 * (1 - i / 10)
                cameraOffset = Vector3.new(
                    math.random(-100, 100) / 100 * amplitude,
                    math.random(-100, 100) / 100 * amplitude,
                    0
                )
                pcall(function()
                    camera.CFrame = camera.CFrame * CFrame.new(cameraOffset)
                end)
                task.wait(0.05)
            end
        end)
    end)
end)

-- GoldenStart : flash doré + texte ×5
task.spawn(function()
    local GoldenStart = ReplicatedStorage:WaitForChild("GoldenStart", 15)
    if not GoldenStart then return end
    GoldenStart.OnClientEvent:Connect(function()
        -- Flash doré
        local flash = Instance.new("Frame", gui)
        flash.Size                   = UDim2.new(1, 0, 1, 0)
        flash.BackgroundColor3       = Color3.fromRGB(255, 200, 0)
        flash.BackgroundTransparency = 0.3
        flash.BorderSizePixel        = 0
        flash.ZIndex                 = 10
        TweenService:Create(flash, TweenInfo.new(0.3),  { BackgroundTransparency = 0.3 }):Play()
        task.wait(0.35)
        TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
        task.delay(0.9, function() flash:Destroy() end)

        -- Texte ×5 flottant au centre
        local texte = Instance.new("TextLabel", gui)
        texte.Size                   = UDim2.new(0, 300, 0, 70)
        texte.Position               = UDim2.new(0.5, -150, 0.5, -35)
        texte.BackgroundTransparency = 1
        texte.TextColor3             = Color3.fromRGB(255, 215, 0)
        texte.TextStrokeTransparency = 0
        texte.TextStrokeColor3       = Color3.fromRGB(100, 60, 0)
        texte.TextScaled             = true
        texte.Font                   = Enum.Font.GothamBold
        texte.Text                   = "x5 GOLDEN"
        texte.ZIndex                 = 11
        TweenService:Create(texte, TweenInfo.new(2),
            { Position = UDim2.new(0.5, -150, 0.35, -35), TextTransparency = 1 }
        ):Play()
        task.delay(2.1, function() texte:Destroy() end)
    end)
end)

-- Collect VFX
local CollectVFX = ReplicatedStorage:WaitForChild("CollectVFX")
CollectVFX.OnClientEvent:Connect(function(montant, rarete)
    local popup = Instance.new("TextLabel", gui)
    popup.Size                   = UDim2.new(0,150,0,40)
    popup.Position               = UDim2.new(math.random(30,70)/100,-75, math.random(30,70)/100,-20)
    popup.BackgroundTransparency = 1
    popup.TextColor3             = rarete and rarete.couleur or Color3.fromRGB(255,255,255)
    popup.TextStrokeTransparency = 0
    popup.TextScaled             = true
    popup.Font                   = Enum.Font.GothamBold
    popup.Text                   = "+" .. montant
    TweenService:Create(popup, TweenInfo.new(1.5),
        { Position = UDim2.new(popup.Position.X.Scale, -75, popup.Position.Y.Scale - 0.1, -20),
          TextTransparency = 1 }):Play()
    task.delay(1.5, function() popup:Destroy() end)
end)


-- ============================================================
-- Notifications générales (NotifEvent)
-- ============================================================
local NotifEvent = game.ReplicatedStorage:WaitForChild("NotifEvent")

-- Couleurs par type de notification
local NOTIF_COULEURS = {
    INFO    = Color3.fromRGB(0, 150, 255),
    SUCCESS = Color3.fromRGB(0, 200, 0),
    ERROR   = Color3.fromRGB(255, 50, 50),
    WARNING = Color3.fromRGB(255, 165, 0),
}

-- Label réutilisable (créé une seule fois) — texte flottant sans fond
local notifLabel = Instance.new("TextLabel", gui)
notifLabel.Name                   = "NotifLabel"
notifLabel.Size                   = UDim2.new(0, 500, 0, 50)
notifLabel.Position               = UDim2.new(0.5, -250, 0, 75)
notifLabel.BackgroundTransparency = 1
notifLabel.TextColor3             = Color3.fromRGB(255, 255, 255)
notifLabel.Font                   = Enum.Font.GothamBold
notifLabel.TextSize               = 16
notifLabel.RichText               = true
notifLabel.BorderSizePixel        = 0
notifLabel.Visible                = false
notifLabel.ZIndex                 = 20

local notifStroke = Instance.new("UIStroke", notifLabel)
notifStroke.Color           = Color3.new(0, 0, 0)
notifStroke.Thickness       = 2
notifStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual

local notifGen = 0

NotifEvent.OnClientEvent:Connect(function(typeNotif, message)
    if not message then return end
    -- REBIRTH_GLOBAL et RARE sont gérés par NotificationHandler → ignorer ici
    if typeNotif == "REBIRTH_GLOBAL" or typeNotif == "RARE" then return end

    notifGen = notifGen + 1
    local gen = notifGen

    notifLabel.TextColor3       = NOTIF_COULEURS[typeNotif] or Color3.fromRGB(255, 255, 255)
    notifLabel.Text             = message
    notifLabel.TextTransparency = 0
    notifLabel.Visible          = true

    task.delay(3, function()
        if notifGen ~= gen then return end
        TweenService:Create(notifLabel, TweenInfo.new(0.5, Enum.EasingStyle.Quad),
            { TextTransparency = 1 }):Play()
        task.delay(0.6, function()
            if notifGen ~= gen then return end
            notifLabel.Visible          = false
            notifLabel.TextTransparency = 0
        end)
    end)
end)

Logger.info("HUD", "NotifEvent connecté ✓")

-- ============================================================
-- Bouton Shop (gauche) — ScreenGui separe avec IgnoreGuiInset=true
-- pour aligner les coordonnees avec les autres boutons gauche
-- ============================================================
local shopBtnGui = Instance.new("ScreenGui")
shopBtnGui.Name           = "ShopRobuxButtonGui"
shopBtnGui.ResetOnSpawn   = false
shopBtnGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
shopBtnGui.IgnoreGuiInset = true
shopBtnGui.Parent         = player.PlayerGui

local btnShop = Instance.new("TextButton", shopBtnGui)
btnShop.Name                   = "ShopRobuxButton"
btnShop.Size                   = UDim2.new(0, 80, 0, 80)
btnShop.Position               = UDim2.new(0, 5, 0.5, -125)
btnShop.BackgroundColor3       = Color3.fromRGB(10, 10, 10)
btnShop.BackgroundTransparency = 0.05
btnShop.TextColor3             = Color3.fromRGB(220, 220, 220)
btnShop.Font                   = Enum.Font.GothamBold
btnShop.TextSize               = 14
btnShop.TextScaled             = true
btnShop.Text                   = "Shop"
btnShop.TextWrapped            = true
btnShop.BorderSizePixel        = 0
btnShop.ZIndex                 = 5
Instance.new("UICorner", btnShop).CornerRadius = UDim.new(0, 8)
local _btnShopStroke = Instance.new("UIStroke", btnShop)
_btnShopStroke.Color = Color3.fromRGB(60, 60, 60) ; _btnShopStroke.Thickness = 1

-- Fermeture des autres menus (1 seul ouvert a la fois)
local function fermerAutresMenusRobux()
    local shopGui = player.PlayerGui:FindFirstChild("ShopGui")
    if shopGui and shopGui.Enabled then shopGui.Enabled = false end
    local tutoGui = player.PlayerGui:FindFirstChild("MiniTutoHUD")
    if tutoGui then
        local p = tutoGui:FindFirstChild("TutoPanel")
        if p then p.Visible = false end
    end
    local fpGui = player.PlayerGui:FindFirstChild("FlowerPotHUD")
    if fpGui then
        local mf = fpGui:FindFirstChild("MainFrame")
        if mf then mf.Visible = false end
        local ds = fpGui:FindFirstChild("DailySeedPanel")
        if ds then ds:Destroy() end
    end
end

local robuxPanelOpen = false

local function ouvrirRobuxPanel()
    local panel = gui:FindFirstChild("ShopRobuxPanel")
    if not panel then return end
    fermerAutresMenusRobux()
    robuxPanelOpen = true
    panel.Visible  = true
    panel.Size     = UDim2.new(0, 0, 0, 0)
    TweenService:Create(panel, TweenInfo.new(0.22, Enum.EasingStyle.Back),
        { Size = UDim2.new(0, 340, 0, 500) }):Play()
end

local function fermerRobuxPanel()
    local panel = gui:FindFirstChild("ShopRobuxPanel")
    if not panel or not robuxPanelOpen then return end
    robuxPanelOpen = false
    TweenService:Create(panel, TweenInfo.new(0.15, Enum.EasingStyle.Quad),
        { Size = UDim2.new(0, 0, 0, 0) }):Play()
    task.delay(0.16, function()
        if panel.Parent then panel.Visible = false end
    end)
end

btnShop.MouseButton1Click:Connect(function()
    if robuxPanelOpen then fermerRobuxPanel() else ouvrirRobuxPanel() end
end)

-- ============================================================
-- ShopRobuxPanel — items lus depuis Config.ShopUpgrades
-- ============================================================
local function creerShopRobuxPanel()
    local panel = Instance.new("Frame", gui)
    panel.Name                   = "ShopRobuxPanel"
    panel.AnchorPoint            = Vector2.new(0.5, 0.5)
    panel.Size                   = UDim2.new(0, 340, 0, 500)
    panel.Position               = UDim2.new(0.5, 0, 0.5, 0)
    panel.BackgroundColor3       = T.fondPrincipal
    panel.BackgroundTransparency = 0.05
    panel.BorderSizePixel        = 0
    panel.Visible                = false
    panel.ZIndex                 = 10
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)

    -- Reinitialiser l'etat si ferme par un autre menu
    panel:GetPropertyChangedSignal("Visible"):Connect(function()
        if not panel.Visible then
            robuxPanelOpen = false
            panel.Size = UDim2.new(0, 340, 0, 500)
        end
    end)

    -- Adaptation mobile
    local uiScale = Instance.new("UIScale", panel)
    local function ajusterScale()
        local vp = workspace.CurrentCamera.ViewportSize
        local s = math.min(vp.X / 380, vp.Y / 540, 1)
        uiScale.Scale = math.max(0.5, s)
    end
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(ajusterScale)
    ajusterScale()

    local stroke = Instance.new("UIStroke", panel)
    stroke.Color     = T.bordure
    stroke.Thickness = 1

    -- Titre
    local titre = Instance.new("TextLabel", panel)
    titre.Size                   = UDim2.new(1, -50, 0, 40)
    titre.Position               = UDim2.new(0, 10, 0, 5)
    titre.BackgroundTransparency = 1
    titre.TextColor3             = T.texteTitre
    titre.Font                   = Enum.Font.GothamBold
    titre.TextSize               = 18
    titre.TextXAlignment         = Enum.TextXAlignment.Left
    titre.Text                   = "ROBUX SHOP"
    titre.ZIndex                 = 11

    -- Bouton fermer
    local btnFermer = Instance.new("TextButton", panel)
    btnFermer.Size                   = UDim2.new(0, 44, 0, 44)
    btnFermer.Position               = UDim2.new(1, -50, 0, 4)
    btnFermer.BackgroundColor3       = Color3.fromRGB(50, 50, 50)
    btnFermer.TextColor3             = Color3.fromRGB(180, 180, 180)
    btnFermer.Font                   = Enum.Font.GothamBold
    btnFermer.TextSize               = 16
    btnFermer.TextScaled             = true
    btnFermer.Text                   = "X"
    btnFermer.BorderSizePixel        = 0
    btnFermer.ZIndex                 = 11
    Instance.new("UICorner", btnFermer).CornerRadius = UDim.new(0, 8)
    local _bcs = Instance.new("UIStroke", btnFermer)
    _bcs.Color = T.bordure ; _bcs.Thickness = 1
    btnFermer.MouseButton1Click:Connect(function() panel.Visible = false end)

    -- ScrollingFrame
    local scroll = Instance.new("ScrollingFrame", panel)
    scroll.Size                   = UDim2.new(1, -10, 1, -55)
    scroll.Position               = UDim2.new(0, 5, 0, 50)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel        = 0
    scroll.ScrollBarThickness     = estMobile and (UI_SHOP.ScrollBarMobile or 6) or (UI_SHOP.ScrollBarDesktop or 4)
    scroll.ScrollBarImageColor3   = T.bordure
    scroll.CanvasSize             = UDim2.new(0, 0, 0, 0)
    scroll.ZIndex                 = 11

    local layout = Instance.new("UIListLayout", scroll)
    layout.Padding       = UDim.new(0, 8)
    layout.SortOrder     = Enum.SortOrder.LayoutOrder
    layout.FillDirection = Enum.FillDirection.Vertical

    -- Collecter les items Robux depuis GameConfig uniquement
    local items = {}
    if Config.ShopUpgrades then
        for nomUpgrade, upgrade in pairs(Config.ShopUpgrades) do
            for niveauIdx, niveau in pairs(upgrade.niveaux or {}) do
                if niveau.type == "robux" and (niveau.prix or 0) > 0 then
                    table.insert(items, {
                        nom        = (upgrade.nom or nomUpgrade) .. " " .. (niveau.label or ""),
                        prix       = niveau.prix,
                        gamePassId = niveau.gamePassId or 0,
                        nomUpgrade = nomUpgrade,
                        niveauIdx  = niveauIdx,
                        ordre      = upgrade.ordre or 99,
                    })
                end
            end
        end
    end
    table.sort(items, function(a, b) return a.ordre < b.ordre end)

    local totalHeight = 0
    for idx, item in ipairs(items) do
        local ligne = Instance.new("Frame", scroll)
        ligne.Name                   = "Item_" .. idx
        ligne.Size                   = UDim2.new(1, -10, 0, 60)
        ligne.BackgroundColor3       = T.fondSecondaire
        ligne.BackgroundTransparency = 0.1
        ligne.BorderSizePixel        = 0
        ligne.LayoutOrder            = idx
        ligne.ZIndex                 = 12
        Instance.new("UICorner", ligne).CornerRadius = UDim.new(0, 8)

        local lblNom = Instance.new("TextLabel", ligne)
        lblNom.Size                   = UDim2.new(0.6, 0, 1, 0)
        lblNom.Position               = UDim2.new(0, 10, 0, 0)
        lblNom.BackgroundTransparency = 1
        lblNom.TextColor3             = T.texte
        lblNom.Font                   = Enum.Font.GothamBold
        lblNom.TextSize               = 13
        lblNom.TextScaled             = true
        lblNom.TextXAlignment         = Enum.TextXAlignment.Left
        lblNom.TextWrapped            = true
        lblNom.ZIndex                 = 13
        lblNom.Text                   = item.nom

        local btnAcheter = Instance.new("TextButton", ligne)
        btnAcheter.Size             = UDim2.new(0, 95, 0, 36)
        btnAcheter.Position         = UDim2.new(1, -105, 0.5, -18)
        btnAcheter.BackgroundColor3 = T.fondBoutonRobux
        btnAcheter.TextColor3       = T.fondPrincipal
        btnAcheter.Font             = Enum.Font.GothamBold
        btnAcheter.TextSize         = 12
        btnAcheter.TextScaled       = true
        btnAcheter.Text             = item.prix .. " R$"
        btnAcheter.BorderSizePixel  = 0
        btnAcheter.ZIndex           = 13
        Instance.new("UICorner", btnAcheter).CornerRadius = UDim.new(0, 8)
        local _bap = Instance.new("UIPadding", btnAcheter)
        _bap.PaddingLeft = UDim.new(0, 6) ; _bap.PaddingRight = UDim.new(0, 6)
        _bap.PaddingTop = UDim.new(0, 2)  ; _bap.PaddingBottom = UDim.new(0, 2)

        local capturedItem = item
        btnAcheter.MouseButton1Click:Connect(function()
            local achatEv = ReplicatedStorage:FindFirstChild("DemandeAchatRobux")
            if achatEv then
                pcall(function()
                    achatEv:FireServer(capturedItem.nomUpgrade, capturedItem.niveauIdx)
                end)
            end
        end)

        totalHeight = totalHeight + 68
    end

    scroll.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
    return panel
end

creerShopRobuxPanel()
