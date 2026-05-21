-- StarterPlayerScripts/Common/ShopHUD.client.lua
-- DobiGames — Interface du Shop
-- Rendu dynamique depuis Config.ShopUpgrades (aucun upgrade hardcodé ici)

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local TweenService        = game:GetService("TweenService")
local MarketplaceService  = game:GetService("MarketplaceService")
local UserInputService    = game:GetService("UserInputService")
local SoundService        = game:GetService("SoundService")

local localPlayer = Players.LocalPlayer
local playerGui   = localPlayer:WaitForChild("PlayerGui")

-- Un seul menu ouvert à la fois
local function _getCloseEvent()
    local e = playerGui:FindFirstChild("__CloseMenuEvent")
    if not e then e = Instance.new("BindableEvent") ; e.Name = "__CloseMenuEvent" ; e.Parent = playerGui end
    return e
end
local closeMenuEvent = _getCloseEvent()

-- GameConfig
local Config       = require(ReplicatedStorage.GameConfig)
local UI           = require(ReplicatedStorage.SharedLib.UIConfig)
local ModalManager = require(ReplicatedStorage.SharedLib.ModalManager)

local estMobile = UserInputService.TouchEnabled
local UI_SHOP   = (Config.UI and Config.UI.Shop) or {}

-- ============================================================
-- Couleurs (via UIConfig)
-- ============================================================
local C_BG       = UI.Colors.ModalBackground
local C_BG_ALT   = UI.Colors.SectionBackground
local C_BORDER   = UI.Colors.ModalBorder
local C_SEP      = UI.Colors.ModalBorder
local C_TITLE    = UI.Colors.TextOnDark
local C_TEXT     = UI.Colors.TextOnDark
local C_DIM      = Color3.fromRGB(255, 255, 255)
local C_GREEN_BG = UI.Colors.GreenNormal
local C_GREEN_TXT = UI.Colors.TextOnDark
local C_GREY_BG  = UI.Colors.GrayLocked
local C_GREY_TXT = UI.Colors.TextLocked
local C_GOLD_BG  = Color3.fromRGB(140, 220, 70)
local C_GOLD_TXT = UI.Colors.TextOnDark
local C_MAX_BG   = UI.Colors.GrayOwned
local C_MAX_TXT  = UI.Colors.TextDim
local C_OVERLAY  = Color3.fromRGB(0, 0, 0)
local C_COINS    = UI.Colors.TextGold

-- Couleurs d'état des boutons upgrade (lues depuis GameConfig.UI.Shop)
local CS_OWNED_BG    = UI_SHOP.ColAchete        or Color3.fromRGB(27,  94,  32)
local CS_OWNED_TXT   = UI_SHOP.ColAcheteTxt     or Color3.fromRGB(255, 255, 255)
local CS_AVAIL_BG    = UI_SHOP.ColDisponible    or Color3.fromRGB(76,  175,  80)
local CS_AVAIL_TXT   = UI_SHOP.ColDisponibleTxt or Color3.fromRGB(255, 255, 255)
local CS_LOCK_BG     = UI_SHOP.ColVerrouille    or Color3.fromRGB(30,   30,  30)
local CS_LOCK_TXT    = UI_SHOP.ColVerrouilleTxt or Color3.fromRGB(255, 255, 255)
local CS_MAX_BG      = UI_SHOP.ColMax           or Color3.fromRGB(255, 179,   0)
local CS_MAX_TXT     = UI_SHOP.ColMaxTxt        or Color3.fromRGB(0,     0,   0)
local CS_FUTURE_TXT  = UI_SHOP.ColFutureTxt     or Color3.fromRGB(255, 255, 255)
local CS_STROKE_DISP = UI_SHOP.ColStrokeDisp    or Color3.fromRGB(180, 255, 180)

-- ============================================================
-- Constantes layout
-- ============================================================
local PANEL_W          = 460   -- valeur fixe pour compatibilité du scroll/layout existant
local PANEL_H          = 560
local HEADER_H         = 54
local COINS_H          = 36
local SCROLL_TOP       = HEADER_H + COINS_H + 6
local SCROLL_H         = PANEL_H - SCROLL_TOP - 10
local UPGRADE_PAD      = UI_SHOP.UpgradeGap    or 16   -- espacement entre blocs
local BTN_GAP          = UI_SHOP.BtnGap        or 8    -- espacement entre boutons d'une même row
local BTN_H            = UI.ButtonSizes.Medium.Height
local UPGRADE_H        = 68 + BTN_H + 10   -- hauteur dynamique selon BTN_H
local SEUIL_H          = 48 + BTN_H + 10   -- même logique
local BOOST_H          = 68 + BTN_H + 10
local BTN_CORNER       = UDim.new(0, UI.Modal.CornerRadius)

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

-- Backdrop invisible (ferme en cliquant à côté)
local overlay = Instance.new("TextButton")
overlay.Name                   = "Overlay"
overlay.Size                   = UDim2.new(1, 0, 1, 0)
overlay.BackgroundTransparency = 1
overlay.BorderSizePixel        = 0
overlay.Text                   = ""
overlay.ZIndex                 = 1
overlay.Parent                 = screenGui

-- Panneau principal
local panel = Instance.new("Frame")
panel.Name             = "Panel"
panel.AnchorPoint      = Vector2.new(0.5, 0.5)
panel.Size             = UDim2.new(0, PANEL_W, 0, PANEL_H)
panel.Position         = UDim2.new(0.5, 0, 1.5, 0)
panel.BackgroundColor3 = C_BG
panel.BackgroundTransparency = 0.05
panel.BorderSizePixel  = 0
panel.ZIndex           = 2
panel.Parent           = screenGui

local panelCorner = Instance.new("UICorner", panel)
panelCorner.CornerRadius = UDim.new(0, UI.Modal.CornerRadius)

local panelStroke = Instance.new("UIStroke")
panelStroke.Color           = Color3.fromRGB(255, 180, 30)
panelStroke.Thickness       = 5
panelStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
panelStroke.Parent          = panel

panel.ClipsDescendants = true

-- UIScale pour mobile
local uiScale = Instance.new("UIScale")
uiScale.Parent = panel
local function ajusterScale()
    local vp = workspace.CurrentCamera.ViewportSize
    local s  = math.min(vp.X / 500, vp.Y / 620, 1)
    uiScale.Scale = math.max(0.55, s)
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(ajusterScale)
ajusterScale()

-- ── Barre titre ──────────────────────────────────────────────
local headerBar = Instance.new("Frame")
headerBar.Name                   = "Header"
headerBar.Size                   = UDim2.new(1, 0, 0, HEADER_H)
headerBar.BackgroundColor3       = Color3.fromRGB(255, 200, 50)
headerBar.BackgroundTransparency = 0
headerBar.BorderSizePixel        = 0
headerBar.ZIndex                 = 3
headerBar.Parent                 = panel

local _hdrStuds = Instance.new("ImageLabel", headerBar)
_hdrStuds.Size = UDim2.new(1,0,1,0) ; _hdrStuds.BackgroundTransparency = 1
_hdrStuds.Image = "rbxassetid://6927295847" ; _hdrStuds.ScaleType = Enum.ScaleType.Tile
_hdrStuds.TileSize = UDim2.fromOffset(30,30) ; _hdrStuds.ImageTransparency =  0.15
_hdrStuds.ImageColor3 = Color3.fromRGB(160, 90, 0)
_hdrStuds.ZIndex = 3

local titreLbl = Instance.new("TextLabel")
titreLbl.Size                = UDim2.new(1, -60, 1, 0)
titreLbl.Position            = UDim2.new(0, 16, 0, 0)
titreLbl.BackgroundTransparency = 1
titreLbl.Text                = "SHOP"
titreLbl.TextColor3          = C_TITLE
titreLbl.Font                = UI.Fonts.Title
titreLbl.TextSize            = UI.TextSizes.H1
titreLbl.TextScaled          = false
titreLbl.TextXAlignment      = Enum.TextXAlignment.Left
titreLbl.ZIndex                  = 4
titreLbl.TextStrokeColor3        = Color3.fromRGB(80, 40, 0)
titreLbl.TextStrokeTransparency  = 0
titreLbl.Parent                  = headerBar

local closeBtn = Instance.new("TextButton")
closeBtn.Name              = "Close"
closeBtn.Size              = UDim2.new(0, 44, 0, 44)
closeBtn.Position          = UDim2.new(1, -50, 0, 4)
closeBtn.BackgroundColor3  = Color3.fromRGB(230, 50, 50)
closeBtn.Text              = "X"
closeBtn.TextColor3        = Color3.fromRGB(255, 255, 255)
closeBtn.Font              = UI.Fonts.Title
closeBtn.TextSize          = UI.TextSizes.H2
closeBtn.TextScaled        = false
closeBtn.BorderSizePixel   = 0
closeBtn.ZIndex            = 4
closeBtn.Parent            = headerBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
local closeBtnStroke = Instance.new("UIStroke", closeBtn)
closeBtnStroke.Color = Color3.fromRGB(255, 255, 255) ; closeBtnStroke.Thickness = 3

-- ── Séparateur titre ─────────────────────────────────────────
local headerSep = Instance.new("Frame")
headerSep.Size             = UDim2.new(1, -24, 0, 1)
headerSep.Position         = UDim2.new(0, 12, 0, HEADER_H)
headerSep.BackgroundColor3 = C_BORDER
headerSep.BorderSizePixel  = 0
headerSep.ZIndex           = 3
headerSep.Parent           = panel

-- ── Affichage coins ───────────────────────────────────────────
local coinsBar = Instance.new("Frame")
coinsBar.Name                   = "CoinsBar"
coinsBar.Size                   = UDim2.new(1, -24, 0, COINS_H)
coinsBar.Position               = UDim2.new(0, 12, 0, HEADER_H + 6)
coinsBar.BackgroundTransparency = 1
coinsBar.BorderSizePixel        = 0
coinsBar.ZIndex                 = 3
coinsBar.Parent                 = panel

local coinsLbl = Instance.new("TextLabel")
coinsLbl.Name                = "CoinsLabel"
coinsLbl.Size                = UDim2.new(1, 0, 1, 0)
coinsLbl.BackgroundTransparency = 1
coinsLbl.Text                = "0 coins"
coinsLbl.TextColor3          = C_COINS
coinsLbl.Font                = UI.Fonts.Title
coinsLbl.TextSize            = UI.TextSizes.Caption
coinsLbl.TextScaled          = false
coinsLbl.TextXAlignment      = Enum.TextXAlignment.Left
coinsLbl.ZIndex              = 4
coinsLbl.Parent              = coinsBar

-- ── ScrollingFrame ─────────────────────────────────────────────
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name                  = "Scroll"
scrollFrame.Size                  = UDim2.new(1, -10, 0, SCROLL_H)
scrollFrame.Position              = UDim2.new(0, 5, 0, SCROLL_TOP)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel       = 0
scrollFrame.ScrollBarThickness    = UI.Modal.ScrollBarThickness
scrollFrame.ScrollBarImageColor3  = UI.Colors.OrangeNormal
scrollFrame.CanvasSize            = UDim2.new(0, 0, 0, 0)
scrollFrame.ZIndex                = 3
scrollFrame.Parent                = panel

-- Dégradé en bas du scroll pour indiquer qu'il y a plus de contenu
local scrollFade = Instance.new("Frame")
scrollFade.Name                   = "ScrollFade"
scrollFade.Size                   = UDim2.new(1, -10, 0, 40)
scrollFade.Position               = UDim2.new(0, 5, 0, SCROLL_TOP + SCROLL_H - 40)
scrollFade.BackgroundColor3       = C_BG
scrollFade.BackgroundTransparency = 0
scrollFade.BorderSizePixel        = 0
scrollFade.ZIndex                 = 6
scrollFade.Visible                = false
scrollFade.Parent                 = panel
local fadeGrad = Instance.new("UIGradient")
fadeGrad.Rotation     = 90
fadeGrad.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 1),
    NumberSequenceKeypoint.new(1, 0),
})
fadeGrad.Parent = scrollFade

local function majScrollFade()
    local canvasH = scrollFrame.CanvasSize.Y.Offset
    scrollFade.Visible = canvasH > SCROLL_H
end

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
    local function fmt(v, s)
        return (math.floor(v * 10) % 10 == 0 and tostring(math.floor(v)) or string.format("%.1f", v)) .. s
    end
    if n >= 1e9 then return fmt(n / 1e9, "B")
    elseif n >= 1e6 then return fmt(n / 1e6, "M")
    elseif n >= 1e3 then return fmt(n / 1e3, "K")
    else return tostring(n) end
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

local SECTION_COLORS = {
    Color3.fromRGB(80,  180, 255),
    Color3.fromRGB(190, 100, 230),
    Color3.fromRGB(120, 220, 90),
}
local _sectionIdx = 0

local function creerBouton(parent, texte, couleurBg, couleurTxt, xPos, largeur, cliquable, etat)
    local btn = Instance.new(cliquable and "TextButton" or "TextLabel")
    btn.Size             = UDim2.new(0, largeur, 0, BTN_H)
    btn.Position         = UDim2.new(0, xPos, 0, 0)
    btn.BackgroundColor3 = couleurBg
    btn.Text             = texte
    btn.TextColor3       = couleurTxt
    btn.Font             = UI.Fonts.Title
    btn.TextSize         = UI.ButtonSizes.Medium.TextSize
    btn.TextScaled       = false
    btn.BorderSizePixel  = 0
    if etat == "locked" or etat == "future" then
        btn.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
        btn.TextStrokeTransparency = 0.4
    end
    btn.Parent           = parent
    Instance.new("UICorner", btn).CornerRadius = (etat == "robux") and UDim.new(0, 20) or BTN_CORNER
    local pad = Instance.new("UIPadding", btn)
    pad.PaddingLeft   = UDim.new(0, 4)
    pad.PaddingRight  = UDim.new(0, 4)
    pad.PaddingTop    = UDim.new(0, 2)
    pad.PaddingBottom = UDim.new(0, 2)
    -- Bordure brillante uniquement sur le bouton disponible
    if etat == "affordable" then
        local s = Instance.new("UIStroke", btn)
        s.Color     = CS_STROKE_DISP
        s.Thickness = UI_SHOP.StrokeAvailable or 1.5
    elseif etat == "owned" then
        local s = Instance.new("UIStroke", btn)
        s.Color     = C_BORDER
        s.Thickness = 1
    elseif etat == "robux" then
        local s = Instance.new("UIStroke", btn)
        s.Color     = Color3.fromRGB(60, 120, 30)
        s.Thickness = 2
    end
    return btn
end

local function construireUpgradeFrame(nomUpgrade, upgradeConfig, yPos)
    _sectionIdx = _sectionIdx + 1
    local frame = Instance.new("Frame")
    frame.Name             = "Upgrade_" .. nomUpgrade
    frame.Size             = UDim2.new(1, -10, 0, UPGRADE_H)
    frame.Position         = UDim2.new(0, 5, 0, yPos)
    frame.BackgroundColor3 = SECTION_COLORS[(_sectionIdx - 1) % 3 + 1]
    frame.BorderSizePixel  = 0
    frame.Parent           = scrollFrame
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    local stroke = Instance.new("UIStroke")
    stroke.Color        = Color3.fromRGB(255, 255, 255)
    stroke.Thickness    = 2
    stroke.Transparency = 0.5
    stroke.Parent       = frame

    -- Nom
    local nomLbl = Instance.new("TextLabel")
    nomLbl.Name                = "Nom"
    nomLbl.Size                = UDim2.new(1, -12, 0, 22)
    nomLbl.Position            = UDim2.new(0, 10, 0, 8)
    nomLbl.BackgroundTransparency = 1
    nomLbl.Text                = string.upper(upgradeConfig.nom)
    nomLbl.TextColor3          = C_TEXT
    nomLbl.Font                = UI.Fonts.Title
    nomLbl.TextSize            = UI.TextSizes.H2
    nomLbl.TextScaled          = false
    nomLbl.TextXAlignment      = Enum.TextXAlignment.Left
    nomLbl.Parent              = frame

    -- Description
    local descLbl = Instance.new("TextLabel")
    descLbl.Name               = "Desc"
    descLbl.Size               = UDim2.new(1, -12, 0, 16)
    descLbl.Position           = UDim2.new(0, 10, 0, 32)
    descLbl.BackgroundTransparency = 1
    descLbl.Text               = upgradeConfig.description
    descLbl.TextColor3         = C_DIM
    descLbl.Font               = UI.Fonts.Body
    descLbl.TextSize           = UI.TextSizes.Caption
    descLbl.TextScaled         = false
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
local MAX_VISIBLE_BOUTONS = 4  -- fenêtre glissante pour les upgrades multi-paliers

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
    local pad          = BTN_GAP

    -- Indicateur de progression dans le titre (si plus de 4 paliers)
    if maxNiveau > MAX_VISIBLE_BOUTONS then
        local nomLbl = info.frame:FindFirstChild("Nom")
        if nomLbl then
            local progressText = niveauActuel >= maxNiveau
                and "MAX"
                or ("Lv." .. niveauActuel .. "/" .. maxNiveau)
            nomLbl.Text = string.upper(upgradeConfig.nom) .. "  [" .. progressText .. "]"
        end
    end

    -- Fenêtre glissante : montre le dernier acheté + les suivants jusqu'à MAX_VISIBLE_BOUTONS
    local startIdx = 1
    if maxNiveau > MAX_VISIBLE_BOUTONS then
        startIdx = math.max(1, niveauActuel)
        local endIdx = math.min(maxNiveau, startIdx + MAX_VISIBLE_BOUTONS - 1)
        -- Décaler si on est en fin de liste pour toujours afficher MAX_VISIBLE_BOUTONS boutons
        if endIdx - startIdx + 1 < MAX_VISIBLE_BOUTONS then
            startIdx = math.max(1, endIdx - MAX_VISIBLE_BOUTONS + 1)
        end
    end
    local nbBoutons = math.min(maxNiveau - startIdx + 1, maxNiveau > MAX_VISIBLE_BOUTONS and MAX_VISIBLE_BOUTONS or maxNiveau)

    local largeurBouton = math.floor((panelWidth - (nbBoutons - 1) * pad) / nbBoutons)

    for niveauNum = startIdx, startIdx + nbBoutons - 1 do
        local niveauConfig = upgradeConfig.niveaux[niveauNum]
        if not niveauConfig then continue end

        local etat   = getEtatBouton(donnes, upgradeConfig, niveauNum, niveauConfig)
        local xPos   = (niveauNum - startIdx) * (largeurBouton + pad)
        local texte  = ""
        local bgCol  = C_GREY_BG
        local txtCol = C_GREY_TXT
        local cliquable = false

        if etat == "owned" then
            texte    = "✓ " .. niveauConfig.label
            bgCol    = CS_OWNED_BG
            txtCol   = CS_OWNED_TXT
            cliquable = false

        elseif etat == "max" then
            texte    = niveauConfig.label  -- "MAX 🔥" défini dans ShopUpgrades
            bgCol    = CS_MAX_BG
            txtCol   = CS_MAX_TXT
            cliquable = false

        elseif etat == "affordable" then
            texte    = niveauConfig.label .. "  " .. FormatCoins(niveauConfig.prix)
            bgCol    = CS_AVAIL_BG
            txtCol   = CS_AVAIL_TXT
            cliquable = true

        elseif etat == "locked" then
            texte    = niveauConfig.label .. "  " .. FormatCoins(niveauConfig.prix)
            bgCol    = CS_LOCK_BG
            txtCol   = CS_LOCK_TXT
            cliquable = false

        elseif etat == "robux" then
            if niveauActuel >= niveauNum - 1 or niveauActuel == maxNiveau - 1 then
                texte     = tostring(niveauConfig.prix) .. " R$"
                bgCol     = C_GOLD_BG
                txtCol    = C_GOLD_TXT
                cliquable = true
            else
                texte    = niveauConfig.label
                bgCol    = CS_LOCK_BG
                txtCol   = CS_LOCK_TXT
                cliquable = false
            end

        elseif etat == "future" then
            local px = niveauConfig.prix or 0
            texte    = px > 0 and (niveauConfig.label .. "  " .. FormatCoins(px)) or niveauConfig.label
            bgCol    = CS_LOCK_BG
            txtCol   = CS_FUTURE_TXT
            cliquable = false
        end

        local btn = creerBouton(container, texte, bgCol, txtCol, xPos, largeurBouton, cliquable, etat)

        -- Pulse léger sur le bouton achetable pour le mettre en valeur
        if etat == "affordable" and btn:IsA("TextButton") then
            TweenService:Create(btn,
                TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                { BackgroundTransparency = 0.3 }
            ):Play()
        end

        -- Connexion du clic
        if cliquable and btn:IsA("TextButton") then
            if etat == "affordable" then
                btn.MouseButton1Click:Connect(function()
                    if AchatUpgrade then
                        AchatUpgrade:FireServer(nomUpgrade, niveauNum)
                        local s = SoundService:FindFirstChild("SonUpgrade")
                        if s then s:Play() end
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
    frame.BackgroundColor3 = C_BG_ALT
    frame.BorderSizePixel  = 0
    frame.Parent           = scrollFrame
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, UI.Modal.CornerRadius)

    local stroke = Instance.new("UIStroke")
    stroke.Color     = C_BORDER
    stroke.Thickness = 1.5
    stroke.Parent    = frame

    local titre = Instance.new("TextLabel")
    titre.Size                = UDim2.new(1, -12, 0, 26)
    titre.Position            = UDim2.new(0, 10, 0, 6)
    titre.BackgroundTransparency = 1
    titre.Text                = "SEUIL TRACTEUR"
    titre.TextColor3          = C_GOLD_TXT
    titre.Font                = Enum.Font.GothamBold
    titre.TextScaled          = false
    titre.TextSize            = 13
    titre.TextXAlignment      = Enum.TextXAlignment.Left
    titre.Parent              = frame

    local seuilActuel = donnes.tracteurSeuilMin or "RARE"
    local nbSeuils    = #seuils
    local pad         = BTN_GAP
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
            texte = s.label .. " · " .. FormatCoins(s.prix)
        end

        local btn = Instance.new("TextButton")
        btn.Size             = UDim2.new(0, btnW, 0, BTN_H)
        btn.Position         = UDim2.new(0, xPos, 0, 0)
        btn.BackgroundColor3 = bgCol
        btn.Text             = texte
        btn.TextColor3       = txtCol
        btn.Font             = Enum.Font.GothamBold
        btn.TextScaled       = false
        btn.TextSize         = UI.ButtonSizes.Medium.TextSize
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
-- Bloc Boosts (LuckyHour)
-- ============================================================
local boostFrame = nil

local function construireBoostsFrame(yPos)
    if boostFrame and boostFrame.Parent then boostFrame:Destroy() end
    boostFrame = nil

    local devP = Config.DevProductIds or {}
    local pid  = devP.LuckyHour
    if not pid or pid == 0 then return yPos end

    local frame = Instance.new("Frame")
    frame.Name             = "Boosts"
    frame.Size             = UDim2.new(1, -10, 0, BOOST_H)
    frame.Position         = UDim2.new(0, 5, 0, yPos)
    frame.BackgroundColor3 = Color3.fromRGB(255, 80, 140)
    frame.BorderSizePixel  = 0
    frame.Parent           = scrollFrame
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = Color3.fromRGB(255, 255, 255) ; stroke.Thickness = 2 ; stroke.Transparency = 0.5

    local titre = Instance.new("TextLabel", frame)
    titre.Size                = UDim2.new(1, -12, 0, 22)
    titre.Position            = UDim2.new(0, 10, 0, 8)
    titre.BackgroundTransparency = 1
    titre.Text                = "BOOSTS"
    titre.TextColor3          = C_TITLE
    titre.Font                = UI.Fonts.Title
    titre.TextSize            = UI.TextSizes.H2
    titre.TextScaled          = false
    titre.TextXAlignment      = Enum.TextXAlignment.Left

    local desc = Instance.new("TextLabel", frame)
    desc.Size                = UDim2.new(1, -12, 0, 16)
    desc.Position            = UDim2.new(0, 10, 0, 32)
    desc.BackgroundTransparency = 1
    desc.Text                = "x5 income for ALL players — 30 min"
    desc.TextColor3          = C_DIM
    desc.Font                = UI.Fonts.Body
    desc.TextSize            = UI.TextSizes.Caption
    desc.TextScaled          = false
    desc.TextXAlignment      = Enum.TextXAlignment.Left

    local sep = Instance.new("Frame", frame)
    sep.Size             = UDim2.new(1, -20, 0, 1)
    sep.Position         = UDim2.new(0, 10, 0, 60)
    sep.BackgroundColor3 = C_BORDER
    sep.BorderSizePixel  = 0

    local btn = creerBouton(frame, "Server Boost ×5  99 R$", C_GOLD_BG, C_GOLD_TXT, 8, PANEL_W - 16 - 10 - 16, true, "robux")
    btn.Size     = UDim2.new(1, -16, 0, BTN_H)
    btn.Position = UDim2.new(0, 8, 0, 68)
    btn.MouseButton1Click:Connect(function()
        MarketplaceService:PromptProductPurchase(localPlayer, pid)
    end)

    boostFrame = frame
    return yPos + BOOST_H + UPGRADE_PAD
end

-- ============================================================
-- Construction complète du shop depuis les données reçues
-- ============================================================
local function construireShop(donnes)
    _sectionIdx = 0
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

    -- Bloc boosts (LuckyHour)
    y = construireBoostsFrame(y)

    -- Ajuster le canvas de scroll
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, y + 4)
    majScrollFade()

    -- Coins
    coinsLbl.Text = FormatCoins(donnes.playerCoins) .. " coins"
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
    coinsLbl.Text = FormatCoins(donnes.playerCoins) .. " coins"
    for _, entry in ipairs(upgradeOrdre) do
        mettreAJourBoutons(entry.nom, entry.cfg, donnes)
    end
    -- Recalculer la position Y du bloc seuil
    local y = 6 + #upgradeOrdre * (UPGRADE_H + UPGRADE_PAD)
    y = construireSeuilTracteur(donnes, y)
    y = construireBoostsFrame(y)
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, y + 4)
    majScrollFade()
end

-- ============================================================
-- Fermeture des autres menus (1 seul ouvert a la fois)
-- ============================================================
local function fermerAutresMenus()
    local indexGui = playerGui:FindFirstChild("IndexGui")
    if indexGui then
        local p = indexGui:FindFirstChild("IndexPanel")
        if p and p.Visible then p.Visible = false end
    end
    local tutoGui = playerGui:FindFirstChild("MiniTutoHUD")
    if tutoGui then
        local p = tutoGui:FindFirstChild("TutoPanel")
        if p then p.Visible = false end
    end
    local fpGui = playerGui:FindFirstChild("FlowerPotHUD")
    if fpGui then
        local mf = fpGui:FindFirstChild("MainFrame")
        if mf then mf.Visible = false end
        local ds = fpGui:FindFirstChild("DailySeedPanel")
        if ds then
            ModalManager.Close(ModalManager.Modals.DAILY_SEEDS)
            ds:Destroy()
        end
        local fp = fpGui:FindFirstChild("FlowerPotPanel")
        if fp then fp.Visible = false end
    end
    local hud = playerGui:FindFirstChild("HUD")
    if hud then
        local rp = hud:FindFirstChild("ShopRobuxPanel")
        if rp then rp.Visible = false end
    end
end

-- ============================================================
-- Ouverture / Fermeture (slide depuis le bas)
-- ============================================================
local function ouvrirShop(donnes)
    closeMenuEvent:Fire("SHOP")
    ModalManager.Open(ModalManager.Modals.SHOP)
    fermerAutresMenus()
    donneesShop = donnes
    construireShop(donnes)
    screenGui.Enabled  = true
    panel.Position     = UDim2.new(0.5, 0, 1.5, 0)
    TweenService:Create(panel,
        TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Position = UDim2.new(0.5, 0, 0.5, 0) }
    ):Play()
end

local function fermerShop()
    ModalManager.Close(ModalManager.Modals.SHOP)
    local tween = TweenService:Create(panel,
        TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { Position = UDim2.new(0.5, 0, 1.5, 0) })
    tween:Play()
    tween.Completed:Connect(function()
        screenGui.Enabled = false
    end)
end

closeMenuEvent.Event:Connect(function(exceptName)
    if exceptName ~= "SHOP" and screenGui.Enabled then fermerShop() end
end)

-- Reinitialiser position si ferme par un autre menu (sécurité auto-close)
screenGui:GetPropertyChangedSignal("Enabled"):Connect(function()
    if not screenGui.Enabled then
        panel.Position = UDim2.new(0.5, 0, 1.5, 0)
        ModalManager.Close(ModalManager.Modals.SHOP)
    end
end)

-- ============================================================
-- Connexions des contrôles
-- ============================================================
closeBtn.MouseButton1Click:Connect(fermerShop)
overlay.MouseButton1Click:Connect(fermerShop)

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

    AchatUpgrade         = ReplicatedStorage:WaitForChild("AchatUpgrade",      15)
    DemandeAchatRobux    = ReplicatedStorage:WaitForChild("DemandeAchatRobux", 15)
    -- ChangerSeuilTracteur supprimé côté serveur (7beec9d) — FindFirstChild sans timeout
    ChangerSeuilTracteur = ReplicatedStorage:FindFirstChild("ChangerSeuilTracteur")

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
            local s = SoundService:FindFirstChild("SonUpgrade")
            if s then s:Play() end
        end
    end)
end)
