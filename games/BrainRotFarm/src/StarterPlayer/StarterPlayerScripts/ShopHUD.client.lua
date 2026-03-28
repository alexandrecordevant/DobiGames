-- StarterPlayerScripts/Common/ShopHUD.client.lua
-- DobiGames — Interface du Shop
-- Rendu dynamique depuis Config.ShopUpgrades (aucun upgrade hardcodé ici)

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local TweenService        = game:GetService("TweenService")
local MarketplaceService  = game:GetService("MarketplaceService")
local UserInputService    = game:GetService("UserInputService")

local localPlayer = Players.LocalPlayer
local playerGui   = localPlayer:WaitForChild("PlayerGui")

-- GameConfig
local Config = require(ReplicatedStorage.GameConfig)
local T      = require(ReplicatedStorage.SharedLib.Shared.UITheme)

-- ============================================================
-- Couleurs (thème Farm Brain Rot)
-- ============================================================
local C_BG          = T.fondPrincipal
local C_BG_ALT      = T.fondSecondaire
local C_BORDER      = T.bordure
local C_TITLE       = T.texteTitre
local C_TEXT        = T.texte
local C_DIM         = T.texteSecondaire
local C_GREEN_BG    = T.fondBouton
local C_GREEN_TXT   = T.texte
local C_GREY_BG     = Color3.fromRGB(55, 40, 20)
local C_GREY_TXT    = T.texteSecondaire
local C_GOLD_BG     = T.fondBoutonRobux
local C_GOLD_TXT    = T.fondPrincipal
local C_MAX_BG      = Color3.fromRGB(60, 80, 20)
local C_MAX_TXT     = T.barrePleine
local C_OVERLAY     = Color3.fromRGB(0, 0, 0)
local C_COINS       = T.texteTitre
local C_SEP         = T.bordure

-- ============================================================
-- Constantes layout
-- ============================================================
local PANEL_W          = 460
local PANEL_H          = 560
local HEADER_H         = 54
local COINS_H          = 36
local SCROLL_TOP       = HEADER_H + COINS_H + 6
local SCROLL_H         = PANEL_H - SCROLL_TOP - 10
local UPGRADE_H        = 116   -- hauteur d'un bloc upgrade
local UPGRADE_PAD      = 8     -- espacement entre blocs
local SEUIL_H          = 96    -- hauteur du bloc seuil tracteur
local BTN_H            = 38
local BTN_CORNER       = UDim.new(0, 6)

-- ============================================================
-- ScreenGui
-- ============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "ShopGui"
screenGui.ResetOnSpawn   = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder   = 10
screenGui.Enabled        = false
screenGui.Parent         = playerGui

-- Overlay sombre
local overlay = Instance.new("Frame")
overlay.Name                   = "Overlay"
overlay.Size                   = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3       = C_OVERLAY
overlay.BackgroundTransparency = 0.55
overlay.BorderSizePixel        = 0
overlay.Parent                 = screenGui

-- Panneau principal
local panel = Instance.new("Frame")
panel.Name             = "Panel"
panel.Size             = UDim2.new(0, PANEL_W, 0, PANEL_H)
panel.Position         = UDim2.new(0.5, -PANEL_W / 2, 0.5, -PANEL_H / 2)
panel.BackgroundColor3 = C_BG
panel.BorderSizePixel  = 0
panel.Parent           = screenGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 10)
panelCorner.Parent       = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color     = C_BORDER
panelStroke.Thickness = 1.5
panelStroke.Parent    = panel

-- ── Barre titre ──────────────────────────────────────────────
local headerBar = Instance.new("Frame")
headerBar.Name             = "Header"
headerBar.Size             = UDim2.new(1, 0, 0, HEADER_H)
headerBar.BackgroundColor3 = T.fondSecondaire
headerBar.BorderSizePixel  = 0
headerBar.Parent           = panel

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 10)
headerCorner.Parent       = headerBar

local titreLbl = Instance.new("TextLabel")
titreLbl.Size                = UDim2.new(1, -60, 1, 0)
titreLbl.Position            = UDim2.new(0, 14, 0, 0)
titreLbl.BackgroundTransparency = 1
titreLbl.Text                = "🛒  SHOP"
titreLbl.TextColor3          = C_TITLE
titreLbl.Font                = Enum.Font.GothamBold
titreLbl.TextScaled          = true
titreLbl.TextXAlignment      = Enum.TextXAlignment.Left
titreLbl.Parent              = headerBar

local closeBtn = Instance.new("TextButton")
closeBtn.Name              = "Close"
closeBtn.Size              = UDim2.new(0, 38, 0, 38)
closeBtn.Position          = UDim2.new(1, -46, 0.5, -19)
closeBtn.BackgroundColor3  = T.fondBoutonDanger
closeBtn.Text              = "✕"
closeBtn.TextColor3        = T.texte
closeBtn.Font              = Enum.Font.GothamBold
closeBtn.TextScaled        = true
closeBtn.BorderSizePixel   = 0
closeBtn.Parent            = headerBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

-- ── Affichage coins ───────────────────────────────────────────
local coinsBar = Instance.new("Frame")
coinsBar.Name             = "CoinsBar"
coinsBar.Size             = UDim2.new(1, -20, 0, COINS_H)
coinsBar.Position         = UDim2.new(0, 10, 0, HEADER_H + 4)
coinsBar.BackgroundColor3 = C_BG_ALT
coinsBar.BorderSizePixel  = 0
coinsBar.Parent           = panel
Instance.new("UICorner", coinsBar).CornerRadius = UDim.new(0, 6)

local coinsLbl = Instance.new("TextLabel")
coinsLbl.Name                = "CoinsLabel"
coinsLbl.Size                = UDim2.new(1, -12, 1, 0)
coinsLbl.Position            = UDim2.new(0, 10, 0, 0)
coinsLbl.BackgroundTransparency = 1
coinsLbl.Text                = "💰 0 coins"
coinsLbl.TextColor3          = C_COINS
coinsLbl.Font                = Enum.Font.GothamBold
coinsLbl.TextScaled          = true
coinsLbl.TextXAlignment      = Enum.TextXAlignment.Left
coinsLbl.Parent              = coinsBar

-- ── ScrollingFrame ─────────────────────────────────────────────
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name                  = "Scroll"
scrollFrame.Size                  = UDim2.new(1, -10, 0, SCROLL_H)
scrollFrame.Position              = UDim2.new(0, 5, 0, SCROLL_TOP)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel       = 0
scrollFrame.ScrollBarThickness    = 4
scrollFrame.ScrollBarImageColor3  = C_BORDER
scrollFrame.CanvasSize            = UDim2.new(0, 0, 0, 0)
scrollFrame.Parent                = panel

-- ============================================================
-- État local
-- ============================================================
local donneesShop      = nil   -- dernières données reçues
local upgradeFrames    = {}    -- { [nomUpgrade] = Frame }
local upgradeOrdre     = {}    -- table triée par ordre

-- ============================================================
-- Utilitaires
-- ============================================================
local function FormatCoins(n)
    n = math.floor(n or 0)
    if n >= 1_000_000 then
        return string.format("%.1fM", n / 1_000_000)
    elseif n >= 1_000 then
        return string.format("%.1fk", n / 1_000)
    else
        return tostring(n)
    end
end

-- Retourne le niveau actuel pour un upgrade dans les données du shop
local function getNiveauActuel(donnes, upgradeConfig)
    if upgradeConfig.isGamePass then
        return donnes[upgradeConfig.dataField] and 1 or 0
    end
    local pu = donnes.playerUpgrades or {}
    return pu[upgradeConfig.dataField] or 0
end

-- Calcule l'état d'un bouton de niveau
-- Retourne : "owned" | "affordable" | "locked" | "robux" | "future" | "max"
local function getEtatBouton(donnes, upgradeConfig, niveauNum, niveauConfig)
    local niveauActuel = getNiveauActuel(donnes, upgradeConfig)

    -- Déjà possédé
    if niveauNum <= niveauActuel then
        if niveauConfig.isMax then return "max" end
        return "owned"
    end

    -- Prochain niveau accessible
    if niveauNum == niveauActuel + 1 then
        if niveauConfig.type == "robux" then
            return "robux"
        elseif niveauConfig.type == "coins" then
            if (donnes.playerCoins or 0) >= niveauConfig.prix then
                return "affordable"
            else
                return "locked"
            end
        end
    end

    -- Niveaux futurs (non encore débloqués)
    return "future"
end

-- ============================================================
-- Construction UI d'un bloc upgrade
-- ============================================================
local AchatUpgrade         = nil
local DemandeAchatRobux    = nil
local ChangerSeuilTracteur = nil

local function creerBouton(parent, texte, couleurBg, couleurTxt, xPos, largeur, cliquable)
    local btn = Instance.new(cliquable and "TextButton" or "TextLabel")
    btn.Size             = UDim2.new(0, largeur, 0, BTN_H)
    btn.Position         = UDim2.new(0, xPos, 0, 0)
    btn.BackgroundColor3 = couleurBg
    btn.Text             = texte
    btn.TextColor3       = couleurTxt
    btn.Font             = Enum.Font.GothamBold
    btn.TextScaled       = true
    btn.BorderSizePixel  = 0
    btn.Parent           = parent
    Instance.new("UICorner", btn).CornerRadius = BTN_CORNER
    return btn
end

local function construireUpgradeFrame(nomUpgrade, upgradeConfig, yPos)
    local frame = Instance.new("Frame")
    frame.Name             = "Upgrade_" .. nomUpgrade
    frame.Size             = UDim2.new(1, -10, 0, UPGRADE_H)
    frame.Position         = UDim2.new(0, 5, 0, yPos)
    frame.BackgroundColor3 = C_BG_ALT
    frame.BorderSizePixel  = 0
    frame.Parent           = scrollFrame
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    local stroke = Instance.new("UIStroke")
    stroke.Color     = C_SEP
    stroke.Thickness = 1
    stroke.Parent    = frame

    -- Icone + Nom
    local nomLbl = Instance.new("TextLabel")
    nomLbl.Name                = "Nom"
    nomLbl.Size                = UDim2.new(1, -12, 0, 28)
    nomLbl.Position            = UDim2.new(0, 10, 0, 6)
    nomLbl.BackgroundTransparency = 1
    nomLbl.Text                = upgradeConfig.icone .. "  " .. string.upper(upgradeConfig.nom)
    nomLbl.TextColor3          = C_TEXT
    nomLbl.Font                = Enum.Font.GothamBold
    nomLbl.TextScaled          = true
    nomLbl.TextXAlignment      = Enum.TextXAlignment.Left
    nomLbl.Parent              = frame

    -- Description
    local descLbl = Instance.new("TextLabel")
    descLbl.Name               = "Desc"
    descLbl.Size               = UDim2.new(1, -12, 0, 20)
    descLbl.Position           = UDim2.new(0, 10, 0, 36)
    descLbl.BackgroundTransparency = 1
    descLbl.Text               = upgradeConfig.description
    descLbl.TextColor3         = C_DIM
    descLbl.Font               = Enum.Font.Gotham
    descLbl.TextScaled         = true
    descLbl.TextXAlignment     = Enum.TextXAlignment.Left
    descLbl.Parent             = frame

    -- Séparateur
    local sep = Instance.new("Frame")
    sep.Size             = UDim2.new(1, -20, 0, 1)
    sep.Position         = UDim2.new(0, 10, 0, 60)
    sep.BackgroundColor3 = C_SEP
    sep.BorderSizePixel  = 0
    sep.Parent           = frame

    -- Conteneur boutons
    local btnsContainer = Instance.new("Frame")
    btnsContainer.Name             = "Boutons"
    btnsContainer.Size             = UDim2.new(1, -16, 0, BTN_H)
    btnsContainer.Position         = UDim2.new(0, 8, 0, 68)
    btnsContainer.BackgroundTransparency = 1
    btnsContainer.Parent           = frame

    upgradeFrames[nomUpgrade] = {
        frame         = frame,
        btnsContainer = btnsContainer,
    }
end

-- ============================================================
-- Mise à jour des boutons dans un bloc upgrade
-- ============================================================
local function mettreAJourBoutons(nomUpgrade, upgradeConfig, donnes)
    local info = upgradeFrames[nomUpgrade]
    if not info then return end

    local container = info.btnsContainer

    -- Effacer les anciens boutons
    for _, child in ipairs(container:GetChildren()) do
        child:Destroy()
    end

    local maxNiveau    = upgradeConfig.maxNiveau
    local niveauActuel = getNiveauActuel(donnes, upgradeConfig)
    local panelWidth   = PANEL_W - 16 - 10  -- largeur du container (approx)
    local pad          = 6
    local nbBoutons    = maxNiveau

    -- Si game pass à 1 niveau, afficher 1 gros bouton
    local largeurBouton = math.floor((panelWidth - (nbBoutons - 1) * pad) / nbBoutons)

    for niveauNum = 1, maxNiveau do
        local niveauConfig = upgradeConfig.niveaux[niveauNum]
        if not niveauConfig then continue end

        local etat   = getEtatBouton(donnes, upgradeConfig, niveauNum, niveauConfig)
        local xPos   = (niveauNum - 1) * (largeurBouton + pad)
        local texte  = ""
        local bgCol  = C_GREY_BG
        local txtCol = C_GREY_TXT
        local cliquable = false

        if etat == "owned" then
            texte    = "✅ " .. niveauConfig.label
            bgCol    = C_GREEN_BG
            txtCol   = C_GREEN_TXT
            cliquable = false

        elseif etat == "max" then
            texte    = "MAX ✅"
            bgCol    = C_MAX_BG
            txtCol   = C_MAX_TXT
            cliquable = false

        elseif etat == "affordable" then
            texte    = "→ " .. niveauConfig.label .. "  " .. FormatCoins(niveauConfig.prix) .. "💰"
            bgCol    = C_GREEN_BG
            txtCol   = C_GREEN_TXT
            cliquable = true

        elseif etat == "locked" then
            texte    = "🔒 " .. niveauConfig.label .. "  " .. FormatCoins(niveauConfig.prix) .. "💰"
            bgCol    = C_GREY_BG
            txtCol   = C_GREY_TXT
            cliquable = false

        elseif etat == "robux" then
            if niveauActuel >= niveauNum - 1 or niveauActuel == maxNiveau - 1 then
                texte     = tostring(niveauConfig.prix) .. " R$ 🔥"
                bgCol     = C_GOLD_BG
                txtCol    = C_GOLD_TXT
                cliquable = true
            else
                texte    = "🔒 " .. niveauConfig.label
                bgCol    = C_GREY_BG
                txtCol   = C_GREY_TXT
                cliquable = false
            end

        elseif etat == "future" then
            texte    = niveauConfig.label
            bgCol    = C_GREY_BG
            txtCol   = Color3.fromRGB(55, 55, 65)
            cliquable = false
        end

        local btn = creerBouton(container, texte, bgCol, txtCol, xPos, largeurBouton, cliquable)

        -- Connexion du clic
        if cliquable and btn:IsA("TextButton") then
            if etat == "affordable" then
                btn.MouseButton1Click:Connect(function()
                    if AchatUpgrade then
                        AchatUpgrade:FireServer(nomUpgrade, niveauNum)
                    end
                end)
            elseif etat == "robux" then
                btn.MouseButton1Click:Connect(function()
                    if DemandeAchatRobux then
                        DemandeAchatRobux:FireServer(nomUpgrade, niveauNum)
                    end
                end)
            end
        end
    end
end

-- ============================================================
-- Bloc seuil Tracteur
-- ============================================================
local seuilFrame = nil

local function construireSeuilTracteur(donnes, yPos)
    -- Supprimer l'ancien bloc si présent
    if seuilFrame and seuilFrame.Parent then seuilFrame:Destroy() end
    seuilFrame = nil

    if not donnes.hasTracteur then return yPos end

    local tracteurConfig = donnes.upgrades and donnes.upgrades.Tracteur
    local seuils = tracteurConfig and tracteurConfig.seuilsDisponibles
    if not seuils then return yPos end

    local frame = Instance.new("Frame")
    frame.Name             = "SeuilTracteur"
    frame.Size             = UDim2.new(1, -10, 0, SEUIL_H)
    frame.Position         = UDim2.new(0, 5, 0, yPos)
    frame.BackgroundColor3 = T.fondSecondaire
    frame.BorderSizePixel  = 0
    frame.Parent           = scrollFrame
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    local stroke = Instance.new("UIStroke")
    stroke.Color     = T.bordure
    stroke.Thickness = 1.5
    stroke.Parent    = frame

    local titre = Instance.new("TextLabel")
    titre.Size                = UDim2.new(1, -12, 0, 26)
    titre.Position            = UDim2.new(0, 10, 0, 6)
    titre.BackgroundTransparency = 1
    titre.Text                = "🚜  SEUIL TRACTEUR"
    titre.TextColor3          = C_GOLD_TXT
    titre.Font                = Enum.Font.GothamBold
    titre.TextScaled          = true
    titre.TextXAlignment      = Enum.TextXAlignment.Left
    titre.Parent              = frame

    local seuilActuel = donnes.tracteurSeuilMin or "RARE"
    local nbSeuils    = #seuils
    local pad         = 6
    local containerW  = PANEL_W - 16 - 10
    local btnW        = math.floor((containerW - (nbSeuils - 1) * pad) / nbSeuils)

    local btnContainer = Instance.new("Frame")
    btnContainer.Size             = UDim2.new(1, -16, 0, BTN_H)
    btnContainer.Position         = UDim2.new(0, 8, 0, 48)
    btnContainer.BackgroundTransparency = 1
    btnContainer.Parent           = frame

    for i, s in ipairs(seuils) do
        local estSelectionne = (s.rareteMin == seuilActuel)
        local xPos = (i - 1) * (btnW + pad)

        local bgCol  = estSelectionne and C_GREEN_BG  or C_GREY_BG
        local txtCol = estSelectionne and C_GREEN_TXT or C_GREY_TXT

        local texte = s.label
        if s.prix and s.prix > 0 and not estSelectionne then
            texte = s.label .. " · " .. FormatCoins(s.prix) .. "💰"
        elseif estSelectionne then
            texte = "✅ " .. s.label
        end

        local btn = Instance.new("TextButton")
        btn.Size             = UDim2.new(0, btnW, 0, BTN_H)
        btn.Position         = UDim2.new(0, xPos, 0, 0)
        btn.BackgroundColor3 = bgCol
        btn.Text             = texte
        btn.TextColor3       = txtCol
        btn.Font             = Enum.Font.GothamBold
        btn.TextScaled       = true
        btn.BorderSizePixel  = 0
        btn.Parent           = btnContainer
        Instance.new("UICorner", btn).CornerRadius = BTN_CORNER

        local rareteMin = s.rareteMin  -- capture locale pour le Connect
        if not estSelectionne then
            btn.MouseButton1Click:Connect(function()
                if ChangerSeuilTracteur then
                    ChangerSeuilTracteur:FireServer(rareteMin)
                end
            end)
        end
    end

    seuilFrame = frame
    return yPos + SEUIL_H + UPGRADE_PAD
end

-- ============================================================
-- Construction complète du shop depuis les données reçues
-- ============================================================
local function construireShop(donnes)
    -- Vider les anciens blocs
    for _, child in ipairs(scrollFrame:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    upgradeFrames = {}
    upgradeOrdre  = {}

    -- Trier les upgrades par `ordre`
    for nom, cfg in pairs(donnes.upgrades) do
        table.insert(upgradeOrdre, { nom = nom, cfg = cfg, ordre = cfg.ordre or 99 })
    end
    table.sort(upgradeOrdre, function(a, b) return a.ordre < b.ordre end)

    -- Créer les frames
    local y = 6
    for _, entry in ipairs(upgradeOrdre) do
        construireUpgradeFrame(entry.nom, entry.cfg, y)
        mettreAJourBoutons(entry.nom, entry.cfg, donnes)
        y = y + UPGRADE_H + UPGRADE_PAD
    end

    -- Bloc seuil Tracteur (visible seulement si hasTracteur)
    y = construireSeuilTracteur(donnes, y)

    -- Ajuster le canvas de scroll
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, y + 4)

    -- Coins
    coinsLbl.Text = "💰 " .. FormatCoins(donnes.playerCoins) .. " coins"
end

-- ============================================================
-- Mise à jour légère (après achat — ne recrée pas toute l'UI)
-- ============================================================
local function mettreAJourShop(donnes)
    -- Reconstruire complètement si la structure a changé
    local ordreChange = false
    if #upgradeOrdre ~= (function() local n=0; for _ in pairs(donnes.upgrades) do n=n+1 end; return n end)() then
        ordreChange = true
    end

    if ordreChange or next(upgradeFrames) == nil then
        construireShop(donnes)
        return
    end

    -- Sinon, juste mettre à jour les boutons, coins, et seuil tracteur
    coinsLbl.Text = "💰 " .. FormatCoins(donnes.playerCoins) .. " coins"
    for _, entry in ipairs(upgradeOrdre) do
        mettreAJourBoutons(entry.nom, entry.cfg, donnes)
    end
    -- Recalculer la position Y du bloc seuil
    local y = 6 + #upgradeOrdre * (UPGRADE_H + UPGRADE_PAD)
    construireSeuilTracteur(donnes, y)
    local totalH = y + (donnes.hasTracteur and (SEUIL_H + UPGRADE_PAD) or 0)
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, totalH + 4)
end

-- ============================================================
-- Ouverture / Fermeture
-- ============================================================
local panelPosOuverte = UDim2.new(0.5, -PANEL_W / 2, 0.5, -PANEL_H / 2)
local panelPosFermee  = UDim2.new(1.5, 0,             0.5, -PANEL_H / 2)

local function ouvrirShop(donnes)
    donneesShop = donnes
    construireShop(donnes)
    screenGui.Enabled = true
    panel.Position = panelPosFermee
    TweenService:Create(panel,
        TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Position = panelPosOuverte }
    ):Play()
end

local function fermerShop()
    TweenService:Create(panel,
        TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { Position = panelPosFermee }
    ):Play()
    task.delay(0.26, function()
        screenGui.Enabled = false
    end)
end

-- ============================================================
-- Connexions des contrôles
-- ============================================================
closeBtn.MouseButton1Click:Connect(fermerShop)

-- Fermer en cliquant sur l'overlay
overlay.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        fermerShop()
    end
end)

-- Fermer avec Escape
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.Escape and screenGui.Enabled then
        fermerShop()
    end
end)

-- ============================================================
-- Écoute des RemoteEvents (attente asynchrone)
-- ============================================================
task.spawn(function()
    local OuvrirShopEvent = ReplicatedStorage:WaitForChild("OuvrirShop", 15)
    local ShopUpdateEvent = ReplicatedStorage:WaitForChild("ShopUpdate",  15)
    local FermerShopEvent = ReplicatedStorage:WaitForChild("FermerShop",  15)

    AchatUpgrade         = ReplicatedStorage:WaitForChild("AchatUpgrade",         15)
    DemandeAchatRobux    = ReplicatedStorage:WaitForChild("DemandeAchatRobux",    15)
    ChangerSeuilTracteur = ReplicatedStorage:WaitForChild("ChangerSeuilTracteur", 15)

    if OuvrirShopEvent then
        OuvrirShopEvent.OnClientEvent:Connect(function(donnes)
            if type(donnes) == "table" then
                ouvrirShop(donnes)
            end
        end)
    end

    if ShopUpdateEvent then
        ShopUpdateEvent.OnClientEvent:Connect(function(donnes)
            if type(donnes) == "table" and screenGui.Enabled then
                mettreAJourShop(donnes)
            end
        end)
    end

    if FermerShopEvent then
        FermerShopEvent.OnClientEvent:Connect(fermerShop)
    end
end)

-- ============================================================
-- Confirmation achat Game Pass (PromptGamePassPurchaseFinished → serveur)
-- ============================================================
task.spawn(function()
    local ConfirmerGP = ReplicatedStorage:WaitForChild("ConfirmerGamePass", 15)
    if not ConfirmerGP then return end

    MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, purchased)
        if purchased then
            ConfirmerGP:FireServer(gamePassId)
        end
    end)
end)
