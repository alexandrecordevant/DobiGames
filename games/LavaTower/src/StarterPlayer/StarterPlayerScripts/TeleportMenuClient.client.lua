-- StarterPlayerScripts/TeleportMenuClient.client.lua
-- Bouton TP + menu de téléportation — thème coloré par destination

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ============================================================================
-- PALETTE
-- ============================================================================
local C = {
    PanelBg      = Color3.fromRGB(15,  12,  8),
    Bordure      = Color3.fromRGB(60,  60,  60),
    AccentHdr    = Color3.fromRGB(50,  130, 255),
    AccentHdrStr = Color3.fromRGB(110, 185, 255),
    TextPrim     = Color3.fromRGB(220, 220, 220),
    TextSec      = Color3.fromRGB(130, 130, 130),
    Disabled     = Color3.fromRGB(50,  50,  50),
    PanelStroke  = Color3.fromRGB(180, 90,  20),
}

-- Couleurs destination — même palette que le reste du jeu (highlight subtil → base)
local DEST_STYLES = {
    TOUR_VITE    = {  -- ambre doré (même famille que Carry / 10h CASH)
        cardTop   = Color3.fromRGB(255, 205, 65),
        cardBot   = Color3.fromRGB(220, 165, 20),
        cardStr   = Color3.fromRGB(255, 230, 110),
        btnColor  = Color3.fromRGB(235, 180, 30),
        btnStroke = Color3.fromRGB(255, 220, 90),
        btnDark   = true,
    },
    TOUR_COMMUNE = {  -- bleu (même famille que SpeedCoil / 30min CASH)
        cardTop   = Color3.fromRGB(90,  155, 255),
        cardBot   = Color3.fromRGB(55,  115, 230),
        cardStr   = Color3.fromRGB(140, 195, 255),
        btnColor  = Color3.fromRGB(75,  140, 250),
        btnStroke = Color3.fromRGB(140, 195, 255),
        btnDark   = false,
    },
    BASE         = {  -- teal (variante verte distincte)
        cardTop   = Color3.fromRGB(70,  215, 160),
        cardBot   = Color3.fromRGB(38,  180, 125),
        cardStr   = Color3.fromRGB(110, 245, 195),
        btnColor  = Color3.fromRGB(50,  198, 142),
        btnStroke = Color3.fromRGB(110, 245, 195),
        btnDark   = true,
    },
}

local PANEL_W, PANEL_H = 360, 316

-- TweenInfo
local TI_BACK35 = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TI_QUAD20 = TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

-- ============================================================================
-- UTILITAIRES
-- ============================================================================
local function newInst(class, props)
    local inst = Instance.new(class)
    for k, v in pairs(props) do inst[k] = v end
    return inst
end

local function addCorner(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 2)
    c.Parent = parent
end

local function addStrokeColor(parent, color, thick)
    local s = Instance.new("UIStroke")
    s.Color = color; s.Thickness = thick or 1; s.Parent = parent
    return s
end

local function addGradient(parent, c0, c1, rotation)
    local g = Instance.new("UIGradient")
    g.Color    = ColorSequence.new(c0, c1)
    g.Rotation = rotation or 90
    g.Parent   = parent
    return g
end

local function addHover(btn, normalColor, strokeColor)
    local hoverColor = Color3.new(
        math.min(1, normalColor.R + 0.1),
        math.min(1, normalColor.G + 0.1),
        math.min(1, normalColor.B + 0.1))
    local stroke = btn:FindFirstChildWhichIsA("UIStroke")
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.08), { BackgroundColor3 = hoverColor }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.08), { BackgroundColor3 = normalColor }):Play()
    end)
end

-- ============================================================================
-- BOUTON TP (bord gauche)
-- ============================================================================
local hudGui = newInst("ScreenGui", {
    Name           = "TeleportHudGui",
    ResetOnSpawn   = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    Enabled        = true,
    Parent         = playerGui,
})

local tpOpenBtn = newInst("TextButton", {
    Name                   = "TeleportBtn",
    Size                   = UDim2.new(0, 100, 0, 100),
    AnchorPoint            = Vector2.new(0, 0.5),
    Position               = UDim2.new(0, 0, 0.5, -110),
    BackgroundTransparency = 1,
    Text                   = "",
    BorderSizePixel        = 0,
    ZIndex                 = 10,
    Parent                 = hudGui,
})

local tpIcon = newInst("ImageLabel", {
    Size                   = UDim2.fromScale(1, 1),
    BackgroundColor3       = Color3.fromRGB(80, 80, 80),
    BackgroundTransparency = 0,
    Image                  = "rbxassetid://99643573079886",
    ScaleType              = Enum.ScaleType.Crop,
    ZIndex                 = 11,
    Parent                 = tpOpenBtn,
})
local _tpCorner = Instance.new("UICorner")
_tpCorner.CornerRadius = UDim.new(0, 16)
_tpCorner.Parent = tpIcon

tpOpenBtn.MouseEnter:Connect(function()
    TweenService:Create(tpIcon, TweenInfo.new(0.1), { ImageTransparency = 0.35 }):Play()
end)
tpOpenBtn.MouseLeave:Connect(function()
    TweenService:Create(tpIcon, TweenInfo.new(0.1), { ImageTransparency = 0 }):Play()
end)

-- ============================================================================
-- MENU TP
-- ============================================================================
local menuGui = newInst("ScreenGui", {
    Name           = "TeleportMenuGui",
    ResetOnSpawn   = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    Enabled        = false,
    Parent         = playerGui,
})

local mainFrame = newInst("Frame", {
    Size            = UDim2.new(0, PANEL_W, 0, PANEL_H),
    AnchorPoint     = Vector2.new(0.5, 0.5),
    Position        = UDim2.new(0.5, 0, 0.5, 0),
    BackgroundColor3= C.PanelBg,
    BorderSizePixel = 0,
    ZIndex          = 2,
    Parent          = menuGui,
})
addCorner(mainFrame, 4)
addStrokeColor(mainFrame, C.PanelStroke, 2)

local uiScale = Instance.new("UIScale")
uiScale.Parent = mainFrame
local function ajusterScale()
    local vp = workspace.CurrentCamera.ViewportSize
    uiScale.Scale = math.max(0.5, math.min(vp.X / 480, vp.Y / 640, 1))
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(ajusterScale)
ajusterScale()

-- ── En-tête avec gradient orange ─────────────────────────────────────────────
local titleBar = newInst("Frame", {
    Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = C.AccentHdr,
    BorderSizePixel = 0, ZIndex = 3, Parent = mainFrame,
})
addCorner(titleBar, 4)
addGradient(titleBar, Color3.fromRGB(80, 165, 255), Color3.fromRGB(30, 90, 215), 0)

newInst("TextLabel", {
    Size = UDim2.new(1, -60, 1, 0), Position = UDim2.new(0, 16, 0, 0),
    BackgroundTransparency = 1, Text = "TELEPORT",
    Font = Enum.Font.GothamBold, TextSize = 18, TextScaled = false,
    TextColor3 = Color3.fromRGB(255, 255, 255),
    TextStrokeColor3 = Color3.fromRGB(80, 30, 0), TextStrokeTransparency = 0.5,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 4, Parent = titleBar,
})

local closeBtn = newInst("TextButton", {
    Size = UDim2.new(0, 44, 0, 44), Position = UDim2.new(1, -50, 0, 4),
    BackgroundColor3 = C.Disabled, Text = "X",
    Font = Enum.Font.GothamBold, TextSize = 16, TextScaled = false,
    TextColor3 = C.TextSec, BorderSizePixel = 0, ZIndex = 5, Parent = titleBar,
})
addCorner(closeBtn, 2)
addStrokeColor(closeBtn, C.Bordure, 1)
addHover(closeBtn, C.Disabled)

-- Séparateur
newInst("Frame", {
    Size = UDim2.new(1, -24, 0, 1), Position = UDim2.new(0, 12, 0, 52),
    BackgroundColor3 = C.Bordure, BorderSizePixel = 0, ZIndex = 3, Parent = mainFrame,
})

-- ── Zone de contenu ───────────────────────────────────────────────────────────
local contentFrame = newInst("Frame", {
    Size = UDim2.new(1, -24, 1, -70),
    Position = UDim2.new(0, 12, 0, 62),
    BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 3, Parent = mainFrame,
})
newInst("UIListLayout", {
    SortOrder     = Enum.SortOrder.LayoutOrder,
    FillDirection = Enum.FillDirection.Vertical,
    Padding       = UDim.new(0, 8),
    Parent        = contentFrame,
})

-- ============================================================================
-- CARTES DESTINATIONS
-- ============================================================================
local DESTINATIONS = {
    { key = "TOUR_VITE",    label = "VIP Tower"       },
    { key = "TOUR_COMMUNE", label = "Community Tower" },
    { key = "BASE",         label = "My Base"         },
}

local cardFrames = {}  -- pour stagger à l'ouverture
local fermerMenu       -- déclaration anticipée

for i, dest in ipairs(DESTINATIONS) do
    local style = DEST_STYLES[dest.key]

    local card = newInst("Frame", {
        Size             = UDim2.new(1, 0, 0, 72),
        BackgroundColor3 = style.cardBot,
        BorderSizePixel  = 0,
        LayoutOrder      = i,
        ZIndex           = 4,
        Parent           = contentFrame,
    })
    addCorner(card, 4)
    addStrokeColor(card, style.cardStr, 1.5)
    addGradient(card, style.cardTop, style.cardBot, 90)
    cardFrames[i] = card

    newInst("TextLabel", {
        Size = UDim2.new(1, -110, 1, 0), Position = UDim2.new(0, 16, 0, 0),
        BackgroundTransparency = 1, Text = dest.label,
        Font = Enum.Font.GothamBold, TextSize = 15, TextScaled = false,
        TextColor3 = Color3.fromRGB(240, 240, 240),
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 5, Parent = card,
    })

    local tpBtn = newInst("TextButton", {
        Size             = UDim2.new(0, 88, 0, 44),
        AnchorPoint      = Vector2.new(1, 0.5),
        Position         = UDim2.new(1, -10, 0.5, 0),
        BackgroundColor3 = style.btnColor,
        Text             = "Go",
        Font             = Enum.Font.GothamBold,
        TextSize         = 14,
        TextScaled       = false,
        TextColor3       = style.btnDark and Color3.fromRGB(10, 10, 10) or Color3.fromRGB(255, 255, 255),
        BorderSizePixel  = 0,
        ZIndex           = 5,
        Parent           = card,
    })
    addCorner(tpBtn, 6)
    addStrokeColor(tpBtn, style.btnStroke, 2)
    addHover(tpBtn, style.btnColor)

    local destKey = dest.key
    tpBtn.MouseButton1Click:Connect(function()
        local re = ReplicatedStorage:FindFirstChild("TeleportRequest")
        if re then re:FireServer(destKey) end
        if fermerMenu then fermerMenu() end
    end)
end

-- ============================================================================
-- ANIMATIONS OUVERTURE / FERMETURE
-- ============================================================================
local fermerMenusSignal do
    local existing = ReplicatedStorage:FindFirstChild("FermerMenusSignal")
    if existing and existing:IsA("BindableEvent") then
        fermerMenusSignal = existing
    else
        fermerMenusSignal = Instance.new("BindableEvent")
        fermerMenusSignal.Name   = "FermerMenusSignal"
        fermerMenusSignal.Parent = ReplicatedStorage
    end
end

local function ouvrirMenu()
    fermerMenusSignal:Fire("TP")
    menuGui.Enabled  = true
    mainFrame.Size   = UDim2.new(0, 0, 0, 0)
    TweenService:Create(mainFrame, TI_BACK35, { Size = UDim2.new(0, PANEL_W, 0, PANEL_H) }):Play()
    -- Stagger des cartes : fade in décalé
    for i, card in ipairs(cardFrames) do
        card.BackgroundTransparency = 1
        task.delay(0.25 + (i - 1) * 0.08, function()
            TweenService:Create(card, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
                BackgroundTransparency = 0
            }):Play()
        end)
    end
end

fermerMenu = function()
    local tw = TweenService:Create(mainFrame, TI_QUAD20, { Size = UDim2.new(0, 0, 0, 0) })
    tw:Play()
    tw.Completed:Connect(function()
        menuGui.Enabled = false
        mainFrame.Size  = UDim2.new(0, PANEL_W, 0, PANEL_H)
    end)
end

fermerMenusSignal.Event:Connect(function(source)
    if source ~= "TP" and menuGui.Enabled then
        fermerMenu()
    end
end)

-- ============================================================================
-- CONNEXIONS
-- ============================================================================
tpOpenBtn.MouseButton1Click:Connect(function()
    if menuGui.Enabled then fermerMenu() else ouvrirMenu() end
end)

closeBtn.MouseButton1Click:Connect(fermerMenu)

-- Masquer bouton + fermer menu en tour
task.spawn(function()
    local TowerEntered = ReplicatedStorage:WaitForChild("TowerEntered", 30)
    local TowerExited  = ReplicatedStorage:WaitForChild("TowerExited",  30)
    local function masquer()
        tpOpenBtn.Visible = false
        if menuGui.Enabled then fermerMenu() end
    end
    local function afficher()
        tpOpenBtn.Visible = true
    end
    if TowerEntered then TowerEntered.OnClientEvent:Connect(masquer) end
    if TowerExited  then TowerExited.OnClientEvent:Connect(afficher)  end
    if player:GetAttribute("InTower") then masquer() end
    player:GetAttributeChangedSignal("InTower"):Connect(function()
        if player:GetAttribute("InTower") then masquer() else afficher() end
    end)
end)
