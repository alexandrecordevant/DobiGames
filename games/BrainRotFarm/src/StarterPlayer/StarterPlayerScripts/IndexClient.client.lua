-- StarterPlayerScripts/IndexClient.client.lua
-- Interface index des Brainrots -- BrainRotFarm
-- Affiche tous les Brainrots du jeu, indique les obtenus, rendu 3D via ViewportFrame
-- Les modeles sont lus depuis RS/BRPreviews (shells clones par BRPreviewsBuilder au boot)

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

local TABS = { "NORMAL", "GOLD", "DIAMANT", "RAINBOW", "NEBULA", "TOXIC", "MUTANTS" }

-- Correspondance tab -> dossier dans BRPreviews/Mutation/
local NOM_DOSSIER_MUTATION = {
    GOLD    = "BrainrotsGold",
    DIAMANT = "BrainrotsDiamant",
    NEBULA  = "BrainrotsNebula",
    RAINBOW = "BrainrotsRainbow",
    TOXIC   = "BrainrotsToxic",
}

-- Types elementaires des Mutants FlowerPot (dans l'ordre d'affichage des badges)
local MUTANT_TYPES  = { "GALAXY", "TOXIC", "RAINBOW", "VOID" }
local MUTANT_EMOJIS = { GALAXY = "🌌", TOXIC = "☠️", RAINBOW = "🌈", VOID = "🕳️" }
local MUTANT_COULEURS = {
    GALAXY  = Color3.fromRGB(80,  100, 220),
    TOXIC   = Color3.fromRGB(80,  200, 80),
    RAINBOW = Color3.fromRGB(220, 100, 180),
    VOID    = Color3.fromRGB(140, 50,  210),
}

-- Ordre de tri par rarete (du plus commun au plus rare)
local ORDRE_RARETE = {
    COMMON = 1, RARE = 2, EPIC = 3, LEGENDARY = 4, MYTHIC = 5, GOD = 6, SECRET = 7, OG = 8
}

-- Degrades speciaux appliques sur le TextLabel de rarete
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
    IgnoreGuiInset = true,
    Parent         = pg,
})

-- ================================================================
-- Bouton INDEX (HUD)
-- ================================================================

local btnIndex = newInst("TextButton", {
    Name                   = "IndexBtn",
    Size                   = UDim2.new(0, 80, 0, 80),
    AnchorPoint            = Vector2.new(0, 0),
    Position               = UDim2.new(0, 90, 0.5, -125),
    BackgroundColor3       = Color3.fromRGB(10, 10, 10),
    BackgroundTransparency = 0.05,
    BorderSizePixel        = 0,
    Text                   = "Index",
    TextColor3             = Color3.fromRGB(220, 220, 220),
    TextScaled             = false,
    TextSize               = 12,
    Font                   = Enum.Font.GothamBold,
    ZIndex                 = 10,
    Parent                 = gui,
})
addCorner(btnIndex, UDim.new(0, 8))
local _idxStroke = Instance.new("UIStroke", btnIndex)
_idxStroke.Color = Color3.fromRGB(60, 60, 60) ; _idxStroke.Thickness = 1

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
    Size                   = UDim2.new(1, -10, 1, -90),
    Position               = UDim2.new(0, 5, 0, 84),
    BackgroundTransparency = 1,
    BorderSizePixel        = 0,
    ScrollBarThickness     = 6,
    ScrollBarImageColor3   = Color3.fromRGB(80, 80, 80),
    CanvasSize             = UDim2.new(0, 0, 0, 0),
    ZIndex                 = 21,
    Parent                 = panel,
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

gridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    grille.CanvasSize = UDim2.new(0, 0, 0, gridLayout.AbsoluteContentSize.Y + 8)
end)

-- ================================================================
-- Animations ouverture / fermeture
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

-- mutantData : table { GALAXY=bool, TOXIC=bool, ... } si onglet MUTANTS, nil sinon
local function creerCarte(parent, brInfo, obtenu, layoutOrder, mutantData)
    local carte = newInst("Frame", {
        Size             = UDim2.new(0, 100, 0, 130),
        BackgroundColor3 = C.CarteBg,
        BorderSizePixel  = 0,
        LayoutOrder      = layoutOrder or 0,
        ZIndex           = 22,
        Parent           = parent,
    })
    addCorner(carte, UDim.new(0, 2))
    addStroke(carte, obtenu and C.BordureOk or C.BordureNon, obtenu and 2 or 1)

    creerViewportFrame(carte, brInfo.model, obtenu)

    if mutantData then
        -- Onglet MUTANTS : 4 badges elementaires a la place du nom
        local badgesFrame = newInst("Frame", {
            Size                   = UDim2.new(1, -4, 0, 22),
            Position               = UDim2.new(0, 2, 0, 88),
            BackgroundTransparency = 1,
            BorderSizePixel        = 0,
            ZIndex                 = 22,
            Parent                 = carte,
        })
        local layout = Instance.new("UIListLayout")
        layout.FillDirection       = Enum.FillDirection.Horizontal
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        layout.VerticalAlignment   = Enum.VerticalAlignment.Center
        layout.Padding             = UDim.new(0, 2)
        layout.Parent              = badgesFrame

        for _, mType in ipairs(MUTANT_TYPES) do
            local ok = mutantData[mType] == true
            local badge = newInst("TextLabel", {
                Size                   = UDim2.new(0, 20, 0, 20),
                BackgroundColor3       = ok and MUTANT_COULEURS[mType] or Color3.fromRGB(35, 35, 35),
                BackgroundTransparency = ok and 0.2 or 0.4,
                BorderSizePixel        = 0,
                Text                   = MUTANT_EMOJIS[mType],
                TextScaled             = true,
                TextTransparency       = ok and 0 or 0.55,
                Font                   = Enum.Font.Gotham,
                ZIndex                 = 23,
                Parent                 = badgesFrame,
            })
            addCorner(badge, UDim.new(0, 3))
        end

    elseif obtenu then
        -- Onglets normaux : nom defilant si trop long
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
-- Enumeration des modeles depuis RS/BRPreviews
-- ================================================================

local function collecterDepuisDossier(dossier)
    local liste = {}
    if not dossier then return liste end

    for _, enfant in ipairs(dossier:GetChildren()) do
        if enfant.Name == "ToUseAfter" then
            -- Ignore : brainrots pas encore integres au jeu
        elseif enfant:IsA("Folder") then
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
                    -- Sous-sous-dossier (ex: GOD/1, SECRET/1..5)
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
            table.insert(liste, {
                nom    = enfant.Name,
                rarete = "COMMON",
                model  = enfant,
                tri    = 10000 + #liste,
            })
        end
    end

    table.sort(liste, function(a, b) return a.tri < b.tri end)
    return liste
end

local function listerBrainrotsTab(tab)
    local previews = ReplicatedStorage:FindFirstChild("BRPreviews")
    if not previews then return {} end

    if tab == "NORMAL" then
        return collecterDepuisDossier(previews:FindFirstChild("Brainrots"))
    elseif tab == "MUTANTS" then
        -- Uniquement les raretés MYTHIC et SECRET (seules graines compatibles FlowerPot)
        local brainrotsFolder = previews:FindFirstChild("Brainrots")
        if not brainrotsFolder then return {} end
        local liste = {}
        for _, rareteFolder in ipairs(brainrotsFolder:GetChildren()) do
            if rareteFolder:IsA("Folder") and (rareteFolder.Name == "MYTHIC" or rareteFolder.Name == "SECRET") then
                local rarete = rareteFolder.Name
                for _, child in ipairs(rareteFolder:GetChildren()) do
                    if child:IsA("Model") then
                        table.insert(liste, {
                            nom   = child.Name,
                            rarete = rarete,
                            model  = child,
                            tri    = (ORDRE_RARETE[rarete] or 99) * 10000 + #liste,
                        })
                    elseif child:IsA("Folder") then
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
            end
        end
        table.sort(liste, function(a, b) return a.tri < b.tri end)
        return liste
    else
        local nomDossier = NOM_DOSSIER_MUTATION[tab]
        if not nomDossier then return {} end
        local mutFolder = previews:FindFirstChild("Mutation")
        return collecterDepuisDossier(mutFolder and mutFolder:FindFirstChild(nomDossier))
    end
end

-- ================================================================
-- Gestion de la grille
-- ================================================================

local function estObtenu(brNom, tab)
    if tab == "MUTANTS" then
        -- Bordure dorée si le BR a été obtenu normalement (onglet NORMAL)
        local liste = indexObtenu["NORMAL"]
        if not liste then return false end
        for _, nom in ipairs(liste) do
            if nom == brNom then return true end
        end
        return false
    end
    local liste = indexObtenu[tab]
    if not liste then return false end
    for _, nom in ipairs(liste) do
        if nom == brNom then return true end
    end
    return false
end

local function viderGrille()
    for _, child in ipairs(grille:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
end

local function remplirGrille(tab)
    fillCounter += 1
    local monCompteur = fillCounter

    viderGrille()
    grille.CanvasPosition = Vector2.new(0, 0)

    local brainrots = listerBrainrotsTab(tab)

    local mutantsData = (tab == "MUTANTS") and (indexObtenu.MUTANTS or {}) or nil

    for i, br in ipairs(brainrots) do
        if fillCounter ~= monCompteur then return end
        local obtenu     = estObtenu(br.nom, tab)
        local mutantData = mutantsData and (mutantsData[br.nom] or {}) or nil
        creerCarte(grille, br, obtenu, i, mutantData)
        if i % 5 == 0 then task.wait() end
    end
end

-- ================================================================
-- Systeme de tabs
-- ================================================================

local function selectionnerTab(tab)
    ongletActif = tab
    for _, t in ipairs(TABS) do
        local btn = tabButtons[t]
        if btn then
            btn.BackgroundColor3 = (t == tab) and C.TabActif or C.TabInactif
        end
    end
    task.spawn(remplirGrille, tab)
end

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
-- Signal inter-menus
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

IndexRecevoir.OnClientEvent:Connect(function(data)
    indexObtenu = data or {}
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
        fermerMenusSignal:Fire("Index")
        IndexDemander:FireServer()
        selectionnerTab(ongletActif)
        ouvrirPanel()
    end
end)

btnFermer.Activated:Connect(function()
    fermerPanel()
end)
