-- StarterPlayerScripts/IndexClient.client.lua
-- Interface index des Brainrots -- LavaTower
-- Affiche tous les Brainrots du jeu, indique les obtenus, rendu 3D via ViewportFrame

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local TextService       = game:GetService("TextService")

local player = Players.LocalPlayer
local pg     = player:WaitForChild("PlayerGui")

-- ================================================================
-- Palette et constantes
-- ================================================================

local C = {
    PanelBg    = Color3.fromRGB(10,  10,  10),
    CarteBg    = Color3.fromRGB(20,  20,  20),
    TabActif   = Color3.fromRGB(180, 90,  20),
    TabInactif = Color3.fromRGB(30,  30,  30),
    TextPrim   = Color3.fromRGB(220, 220, 220),
    TextSec    = Color3.fromRGB(130, 130, 130),
    BordureOk  = Color3.fromRGB(180, 90,  20),
    BordureNon = Color3.fromRGB(60,  60,  60),
}

local COULEURS_RARETE = {
    COMMON    = Color3.fromRGB(180, 180, 180),
    RARE      = Color3.fromRGB(80,  120, 220),
    EPIC      = Color3.fromRGB(160, 80,  220),
    LEGENDARY = Color3.fromRGB(220, 160, 20),
    MYTHIC    = Color3.fromRGB(220, 80,  80),
}

local TABS = { "NORMAL", "GOLD", "DIAMANT", "RAINBOW", "NEBULA", "TOXIC" }

-- Correspondance tab -> dossier dans Mutation/
local NOM_DOSSIER_MUTATION = {
    GOLD    = "BrainrotsGold",
    DIAMANT = "BrainrotsDiamant",
    NEBULA  = "BrainrotsNebula",
    RAINBOW = "BrainrotsRainbow",
    TOXIC   = "BrainrotsToxic",
}

-- Ordre de tri par rarete (du plus commun au plus rare)
local ORDRE_RARETE = {
    COMMON = 1, RARE = 2, EPIC = 3, LEGENDARY = 4, MYTHIC = 5, GOD = 6, SECRET = 7, OG = 8
}

-- Degradés spéciaux appliqués sur le TextLabel de rareté
local RARETES_DEGRADE = {
    GOD = function(label)
        local g = Instance.new("UIGradient")
        g.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0,    Color3.fromRGB(255, 0,   0)),
            ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 165, 0)),
            ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 255, 0)),
            ColorSequenceKeypoint.new(0.5,  Color3.fromRGB(0,   200, 50)),
            ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0,   80,  255)),
            ColorSequenceKeypoint.new(0.83, Color3.fromRGB(148, 0,   211)),
            ColorSequenceKeypoint.new(1,    Color3.fromRGB(255, 0,   150)),
        })
        g.Parent = label
    end,
    SECRET = function(label)
        local g = Instance.new("UIGradient")
        g.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0,   Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(1,   Color3.fromRGB(20,  20,  20)),
        })
        g.Parent = label
    end,
    OG = function(label)
        local g = Instance.new("UIGradient")
        g.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0,   Color3.fromRGB(255, 200, 0)),
            ColorSequenceKeypoint.new(1,   Color3.fromRGB(20,  20,  20)),
        })
        g.Parent = label
    end,
}

-- ================================================================
-- Etat
-- ================================================================

local panelOuvert = false
local ongletActif = "NORMAL"
local indexObtenu = {}
local fillCounter = 0

-- ================================================================
-- Utilitaires UI
-- ================================================================

local function newInst(class, props)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do
        inst[k] = v
    end
    return inst
end

local function addCorner(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = r or UDim.new(0, 2)
    c.Parent = parent
    return c
end

local function addStroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color     = color or C.BordureNon
    s.Thickness = thickness or 1
    s.Parent    = parent
    return s
end

-- ================================================================
-- ScreenGui
-- ================================================================

local gui = newInst("ScreenGui", {
    Name           = "IndexGui",
    ResetOnSpawn   = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    Parent         = pg,
})

-- ================================================================
-- Bouton INDEX (HUD, gauche sous le bouton boutique)
-- Meme style que le bouton FlowerPot : fond clair, texte noir
-- ================================================================

local btnIndex = newInst("TextButton", {
    Name                   = "IndexBtn",
    Size                   = UDim2.new(0, 100, 0, 100),
    AnchorPoint            = Vector2.new(0, 0.5),
    Position               = UDim2.new(0, 0, 0.5, 110),
    BackgroundColor3       = Color3.fromRGB(50, 50, 60),
    BackgroundTransparency = 0,
    BorderSizePixel        = 0,
    Text                   = "INDEX",
    TextColor3             = Color3.fromRGB(220, 220, 220),
    TextScaled             = false,
    TextSize               = 16,
    Font                   = Enum.Font.GothamBold,
    ZIndex                 = 10,
    Parent                 = gui,
})
addCorner(btnIndex, UDim.new(0, 16))

-- ================================================================
-- Panneau principal (centre a l'ecran)
-- ================================================================

local PANEL_W = 700
local PANEL_H = 520

local panel = newInst("Frame", {
    Name                   = "IndexPanel",
    Size                   = UDim2.new(0, PANEL_W, 0, PANEL_H),
    AnchorPoint            = Vector2.new(0.5, 0.5),
    Position               = UDim2.new(0.5, 0, 1.5, 0),
    BackgroundColor3       = C.PanelBg,
    BackgroundTransparency = 0.05,
    BorderSizePixel        = 0,
    Visible                = false,
    ZIndex                 = 20,
    Parent                 = gui,
})
addCorner(panel, UDim.new(0, 2))
addStroke(panel, C.BordureNon, 1)

-- Titre "INDEX"
newInst("TextLabel", {
    Size                   = UDim2.new(1, -55, 0, 40),
    Position               = UDim2.new(0, 12, 0, 0),
    BackgroundTransparency = 1,
    Text                   = "INDEX",
    TextColor3             = C.TextPrim,
    TextScaled             = false,
    TextSize               = 22,
    Font                   = Enum.Font.GothamBold,
    TextXAlignment         = Enum.TextXAlignment.Left,
    TextYAlignment         = Enum.TextYAlignment.Center,
    ZIndex                 = 21,
    Parent                 = panel,
})

-- Bouton fermer "X"
local btnFermer = newInst("TextButton", {
    Size                   = UDim2.new(0, 40, 0, 40),
    Position               = UDim2.new(1, -45, 0, 0),
    BackgroundTransparency = 1,
    Text                   = "X",
    TextColor3             = Color3.fromRGB(180, 180, 180),
    TextScaled             = false,
    TextSize               = 18,
    Font                   = Enum.Font.GothamBold,
    ZIndex                 = 21,
    Parent                 = panel,
})

-- Separateur sous le header
newInst("Frame", {
    Size             = UDim2.new(1, 0, 0, 1),
    Position         = UDim2.new(0, 0, 0, 40),
    BackgroundColor3 = Color3.fromRGB(50, 50, 50),
    BorderSizePixel  = 0,
    ZIndex           = 21,
    Parent           = panel,
})

-- ================================================================
-- Conteneur des tabs
-- ================================================================

local tabsFrame = newInst("Frame", {
    Size                   = UDim2.new(1, -10, 0, 34),
    Position               = UDim2.new(0, 5, 0, 44),
    BackgroundTransparency = 1,
    BorderSizePixel        = 0,
    ZIndex                 = 21,
    Parent                 = panel,
})

local tabsLayout = Instance.new("UIListLayout")
tabsLayout.FillDirection = Enum.FillDirection.Horizontal
tabsLayout.Padding       = UDim.new(0, 4)
tabsLayout.SortOrder     = Enum.SortOrder.LayoutOrder
tabsLayout.Parent        = tabsFrame

local tabButtons = {}

-- ================================================================
-- Grille scrollable des cartes
-- ================================================================

local grille = newInst("ScrollingFrame", {
    Size                 = UDim2.new(1, -10, 1, -90),
    Position             = UDim2.new(0, 5, 0, 84),
    BackgroundTransparency = 1,
    BorderSizePixel      = 0,
    ScrollBarThickness   = 6,
    ScrollBarImageColor3 = Color3.fromRGB(80, 80, 80),
    CanvasSize           = UDim2.new(0, 0, 0, 0),
    ZIndex               = 21,
    Parent               = panel,
})

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize            = UDim2.new(0, 100, 0, 130)
gridLayout.CellPadding         = UDim2.new(0, 8, 0, 8)
gridLayout.SortOrder           = Enum.SortOrder.LayoutOrder
gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
gridLayout.VerticalAlignment   = Enum.VerticalAlignment.Top
gridLayout.Parent              = grille

local gridPadding = Instance.new("UIPadding")
gridPadding.PaddingLeft   = UDim.new(0, 4)
gridPadding.PaddingTop    = UDim.new(0, 4)
gridPadding.PaddingRight  = UDim.new(0, 4)
gridPadding.PaddingBottom = UDim.new(0, 4)
gridPadding.Parent        = grille

-- Mise a jour automatique du CanvasSize quand le contenu change
gridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    grille.CanvasSize = UDim2.new(0, 0, 0, gridLayout.AbsoluteContentSize.Y + 8)
end)

-- ================================================================
-- Animations ouverture / fermeture (slide bas vers centre)
-- ================================================================

local TWEEN_INFO = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local POS_OUVERT = UDim2.new(0.5, 0, 0.5, 0)
local POS_FERME  = UDim2.new(0.5, 0, 1.5, 0)

local function ouvrirPanel()
    panelOuvert   = true
    panel.Visible = true
    TweenService:Create(panel, TWEEN_INFO, { Position = POS_OUVERT }):Play()
end

local function fermerPanel()
    panelOuvert = false
    local t = TweenService:Create(panel, TWEEN_INFO, { Position = POS_FERME })
    t:Play()
    t.Completed:Once(function()
        if not panelOuvert then
            panel.Visible = false
        end
    end)
end

-- ================================================================
-- Construction ViewportFrame avec rendu 3D du modele
-- ================================================================

local function creerViewportFrame(parent, modeleSource, obtenu)
    local vp = newInst("ViewportFrame", {
        Size                   = UDim2.new(0, 80, 0, 80),
        Position               = UDim2.new(0.5, -40, 0, 5),
        BackgroundColor3       = Color3.fromRGB(25, 25, 25),
        BackgroundTransparency = 0,
        BorderSizePixel        = 0,
        ZIndex                 = 22,
        Parent                 = parent,
    })
    addCorner(vp, UDim.new(0, 2))

    -- Cloner le modele dans le viewport et positionner la camera
    if modeleSource then
        pcall(function()
            local clone = modeleSource:Clone()
            clone.Parent = vp

            local cf, size = clone:GetBoundingBox()
            local maxSize  = math.max(size.X, size.Y, size.Z)
            if maxSize < 0.1 then maxSize = 4 end
            local distance = maxSize * 1.05

            local cam = Instance.new("Camera")
            cam.CFrame = CFrame.new(
                cf.Position + Vector3.new(0, size.Y * 0.2, distance),
                cf.Position
            )
            vp.CurrentCamera = cam
            cam.Parent       = vp
        end)
    end

    -- Overlay sombre + "?" pour les brainrots non obtenus
    if not obtenu then
        newInst("Frame", {
            Size                   = UDim2.new(1, 0, 1, 0),
            BackgroundColor3       = Color3.fromRGB(0, 0, 0),
            BackgroundTransparency = 0.4,
            BorderSizePixel        = 0,
            ZIndex                 = 23,
            Parent                 = vp,
        })
        newInst("TextLabel", {
            Size                   = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text                   = "?",
            TextColor3             = Color3.fromRGB(255, 255, 255),
            TextScaled             = false,
            TextSize               = 32,
            Font                   = Enum.Font.GothamBold,
            TextXAlignment         = Enum.TextXAlignment.Center,
            TextYAlignment         = Enum.TextYAlignment.Center,
            ZIndex                 = 24,
            Parent                 = vp,
        })
    end

    return vp
end

-- ================================================================
-- Construction d'une carte Brainrot (100x130)
-- ================================================================

local function creerCarte(parent, brInfo, obtenu, layoutOrder)
    local carte = newInst("Frame", {
        Size             = UDim2.new(0, 100, 0, 130),
        BackgroundColor3 = C.CarteBg,
        BorderSizePixel  = 0,
        LayoutOrder      = layoutOrder or 0,
        ZIndex           = 22,
        Parent           = parent,
    })
    addCorner(carte, UDim.new(0, 2))
    -- Bordure orange si obtenu, grise sinon
    addStroke(carte, obtenu and C.BordureOk or C.BordureNon, obtenu and 2 or 1)

    creerViewportFrame(carte, brInfo.model, obtenu)

    -- Nom : visible uniquement si decouvert, defilant si trop long
    if obtenu then
        local CLIP_W    = 96
        local clipFrame = newInst("Frame", {
            Size                   = UDim2.new(1, -4, 0, 24),
            Position               = UDim2.new(0, 2, 0, 88),
            BackgroundTransparency = 1,
            ClipsDescendants       = true,
            BorderSizePixel        = 0,
            ZIndex                 = 22,
            Parent                 = carte,
        })
        local bounds   = TextService:GetTextSize(brInfo.nom, 11, Enum.Font.GothamBold, Vector2.new(1000, 24))
        local overflow = bounds.X - CLIP_W
        local nomLabel = newInst("TextLabel", {
            BackgroundTransparency = 1,
            Text                   = brInfo.nom,
            TextColor3             = C.TextPrim,
            TextScaled             = false,
            TextSize               = 11,
            Font                   = Enum.Font.GothamBold,
            ZIndex                 = 22,
            Parent                 = clipFrame,
        })
        if overflow > 0 then
            nomLabel.Size           = UDim2.new(0, bounds.X + 10, 1, 0)
            nomLabel.Position       = UDim2.new(0, 0, 0, 0)
            nomLabel.TextXAlignment = Enum.TextXAlignment.Left
            TweenService:Create(nomLabel,
                TweenInfo.new(overflow / 30, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true, 1),
                { Position = UDim2.new(0, -(overflow + 10), 0, 0) }
            ):Play()
        else
            nomLabel.Size           = UDim2.new(1, 0, 1, 0)
            nomLabel.Position       = UDim2.new(0, 0, 0, 0)
            nomLabel.TextXAlignment = Enum.TextXAlignment.Center
        end
    end

    -- Rarete avec couleur ou degrade specifique
    local rareteStr   = brInfo.rarete or "COMMON"
    local rareteLabel = newInst("TextLabel", {
        Size                   = UDim2.new(1, -4, 0, 14),
        Position               = UDim2.new(0, 2, 0, 113),
        BackgroundTransparency = 1,
        Text                   = rareteStr,
        TextColor3             = Color3.fromRGB(255, 255, 255),
        TextScaled             = false,
        TextSize               = 10,
        Font                   = Enum.Font.Gotham,
        TextXAlignment         = Enum.TextXAlignment.Center,
        ZIndex                 = 22,
        Parent                 = carte,
    })
    local appliquer = RARETES_DEGRADE[rareteStr]
    if appliquer then
        appliquer(rareteLabel)
    else
        rareteLabel.TextColor3 = COULEURS_RARETE[rareteStr] or COULEURS_RARETE.COMMON
    end

    return carte
end

-- ================================================================
-- Enumeration des modeles Brainrot depuis ReplicatedStorage
-- ================================================================

-- Collecte les modeles depuis un dossier (avec sous-dossiers de rarete, profondeur 2)
local function collecterDepuisDossier(dossier)
    local liste = {}
    if not dossier then return liste end

    for _, enfant in ipairs(dossier:GetChildren()) do
        if enfant.Name == "ToUseAfter" then
            -- Ignore : brainrots pas encore integres au jeu
        elseif enfant:IsA("Folder") then
            -- Sous-dossier de rarete (COMMON, RARE, EPIC, GOD, SECRET...)
            local rarete = enfant.Name
            for _, child in ipairs(enfant:GetChildren()) do
                if child:IsA("Model") then
                    table.insert(liste, {
                        nom    = child.Name,
                        rarete = rarete,
                        model  = child,
                        tri    = (ORDRE_RARETE[rarete] or 99) * 10000 + #liste,
                    })
                elseif child:IsA("Folder") then
                    -- Sous-sous-dossier (ex: GOD/1, GOD/2, SECRET/1..5)
                    for _, modele in ipairs(child:GetChildren()) do
                        if modele:IsA("Model") then
                            table.insert(liste, {
                                nom    = modele.Name,
                                rarete = rarete,
                                model  = modele,
                                tri    = (ORDRE_RARETE[rarete] or 99) * 10000 + #liste,
                            })
                        end
                    end
                end
            end
        elseif enfant:IsA("Model") then
            -- Modele directement dans le dossier racine (sans sous-dossier de rarete)
            local rarete = "COMMON"
            table.insert(liste, {
                nom    = enfant.Name,
                rarete = rarete,
                model  = enfant,
                tri    = (ORDRE_RARETE[rarete] or 99) * 10000 + #liste,
            })
        end
    end

    table.sort(liste, function(a, b) return a.tri < b.tri end)
    return liste
end

-- Retourne la liste de brainrots pour l'onglet actif
local function listerBrainrotsTab(tab)
    local RS = ReplicatedStorage

    if tab == "NORMAL" then
        local dossier = RS:FindFirstChild("Brainrots")
        return collecterDepuisDossier(dossier)
    else
        local nomDossier = NOM_DOSSIER_MUTATION[tab]
        if not nomDossier then return {} end
        local mutFolder = RS:FindFirstChild("Mutation")
        local dossier   = mutFolder and mutFolder:FindFirstChild(nomDossier)
        return collecterDepuisDossier(dossier)
    end
end

-- ================================================================
-- Gestion de la grille
-- ================================================================

local function estObtenu(brNom, tab)
    local liste = indexObtenu[tab]
    if not liste then return false end
    for _, nom in ipairs(liste) do
        if nom == brNom then return true end
    end
    return false
end

local function viderGrille()
    for _, child in ipairs(grille:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
end

-- Remplit la grille avec les cartes du tab actif
-- Utilise fillCounter pour annuler un remplissage si le tab change
local function remplirGrille(tab)
    fillCounter += 1
    local monCompteur = fillCounter

    viderGrille()
    grille.CanvasPosition = Vector2.new(0, 0)

    local brainrots = listerBrainrotsTab(tab)

    for i, br in ipairs(brainrots) do
        if fillCounter ~= monCompteur then return end
        local obtenu = estObtenu(br.nom, tab)
        creerCarte(grille, br, obtenu, i)
        -- Yield tous les 5 elements pour eviter le lag
        if i % 5 == 0 then
            task.wait()
        end
    end
end

-- ================================================================
-- Systeme de tabs
-- ================================================================

local function selectionnerTab(tab)
    ongletActif = tab
    -- Mettre a jour les visuels des boutons
    for _, t in ipairs(TABS) do
        local btn = tabButtons[t]
        if btn then
            btn.BackgroundColor3 = (t == tab) and C.TabActif or C.TabInactif
        end
    end
    -- Remplir la grille en arriere-plan
    task.spawn(remplirGrille, tab)
end

-- Creer les boutons de tabs (largeur calculee pour remplir le conteneur)
local TAB_BTN_W = math.floor((PANEL_W - 10 - (#TABS - 1) * 4) / #TABS)
for i, tabName in ipairs(TABS) do
    local btn = newInst("TextButton", {
        Size             = UDim2.new(0, TAB_BTN_W, 1, 0),
        BackgroundColor3 = (tabName == "NORMAL") and C.TabActif or C.TabInactif,
        BorderSizePixel  = 0,
        Text             = tabName,
        TextColor3       = C.TextPrim,
        TextScaled       = false,
        TextSize         = 11,
        Font             = Enum.Font.GothamBold,
        LayoutOrder      = i,
        ZIndex           = 22,
        Parent           = tabsFrame,
    })
    addCorner(btn, UDim.new(0, 2))
    tabButtons[tabName] = btn

    btn.Activated:Connect(function()
        selectionnerTab(tabName)
    end)
end

-- ================================================================
-- Signal inter-menus : ferme ce panneau quand un autre menu s'ouvre
-- ================================================================

local fermerMenusSignal
do
    local existing = ReplicatedStorage:FindFirstChild("FermerMenusSignal")
    if existing and existing:IsA("BindableEvent") then
        fermerMenusSignal = existing
    else
        fermerMenusSignal = Instance.new("BindableEvent")
        fermerMenusSignal.Name   = "FermerMenusSignal"
        fermerMenusSignal.Parent = ReplicatedStorage
    end
end

fermerMenusSignal.Event:Connect(function(source)
    if source ~= "Index" and panelOuvert then
        fermerPanel()
    end
end)

-- ================================================================
-- RemoteEvents
-- ================================================================

local IndexDemander = ReplicatedStorage:WaitForChild("IndexDemander", 20)
local IndexRecevoir = ReplicatedStorage:WaitForChild("IndexRecevoir", 20)

if not IndexDemander or not IndexRecevoir then
    warn("[IndexClient] RemoteEvents introuvables -- IndexSystem non demarre")
    return
end

-- Reception des donnees d'index depuis le serveur
IndexRecevoir.OnClientEvent:Connect(function(data)
    indexObtenu = data or {}
    -- Si le panneau est ouvert, rafraichir la grille pour mettre a jour les indicateurs
    if panelOuvert then
        task.spawn(remplirGrille, ongletActif)
    end
end)

-- ================================================================
-- Interactions boutons
-- ================================================================

btnIndex.Activated:Connect(function()
    if panelOuvert then
        fermerPanel()
    else
        -- Fermer les autres menus ouverts
        fermerMenusSignal:Fire("Index")
        -- Demander les donnees a jour au serveur
        IndexDemander:FireServer()
        -- Afficher l'onglet actif et ouvrir le panneau
        selectionnerTab(ongletActif)
        ouvrirPanel()
    end
end)

btnFermer.Activated:Connect(function()
    fermerPanel()
end)
