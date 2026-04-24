-- StarterPlayerScripts/TeleportMenuClient.client.lua
-- Bouton TP (au-dessus du shop) + menu de téléportation
-- 3 destinations : Tour Vite (TP_VIP), Tour Commune (TP_Tour), Ma Baie (spawn base)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ============================================================================
-- PALETTE — même DA que le shop, accent crimson-orange
-- ============================================================================
local C = {
    PanelBg      = Color3.fromRGB(10,  10,  10),
    CardBg       = Color3.fromRGB(20,  20,  20),
    Bordure      = Color3.fromRGB(60,  60,  60),
    Accent       = Color3.fromRGB(180, 90,  20),
    TextPrim     = Color3.fromRGB(220, 220, 220),
    TextSec      = Color3.fromRGB(130, 130, 130),
    Disabled     = Color3.fromRGB(50,  50,  50),
    OrangeStroke = Color3.fromRGB(200, 90,  10),
    BtnGrey      = Color3.fromRGB(90,  90,  90),
}

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

local function addStroke(parent)
    local s = Instance.new("UIStroke")
    s.Color     = C.Bordure
    s.Thickness = 1
    s.Parent    = parent
    return s
end

local function addHover(btn, normalColor)
    local hoverColor = Color3.new(
        math.min(1, normalColor.R + 0.08),
        math.min(1, normalColor.G + 0.08),
        math.min(1, normalColor.B + 0.08)
    )
    local stroke = btn:FindFirstChildWhichIsA("UIStroke")
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.08), { BackgroundColor3 = hoverColor }):Play()
        if stroke then TweenService:Create(stroke, TweenInfo.new(0.08), { Color = C.OrangeStroke }):Play() end
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.08), { BackgroundColor3 = normalColor }):Play()
        if stroke then TweenService:Create(stroke, TweenInfo.new(0.08), { Color = C.Bordure }):Play() end
    end)
end

-- ============================================================================
-- BOUTON TP — bord gauche, juste au-dessus du shop (0.5, -110)
-- Shop : AnchorPoint (0, 0.5), Position (0, 0, 0.5, 0), Size 100x100
-- TP   : centre à (0, 0, 0.5, -110) → gap de 10px entre les deux
-- ============================================================================
local hudGui = newInst("ScreenGui", {
    Name           = "TeleportHudGui",
    ResetOnSpawn   = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    Enabled        = true,
    Parent         = playerGui,
})

-- Structure identique au bouton shop : TextButton transparent + ImageLabel
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

-- Hover identique au shop : assombrit l'icône au survol
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
    Size                   = UDim2.new(0, 360, 0, 316),
    AnchorPoint            = Vector2.new(0.5, 0.5),
    Position               = UDim2.new(0.5, 0, 1.6, 0),
    BackgroundColor3       = C.PanelBg,
    BackgroundTransparency = 0.05,
    BorderSizePixel        = 0,
    ZIndex                 = 2,
    Parent                 = menuGui,
})
addCorner(mainFrame, 2)
addStroke(mainFrame)

-- Scale adaptatif (même logique que le shop)
local uiScale = Instance.new("UIScale")
uiScale.Parent = mainFrame
local function ajusterScale()
    local vp = workspace.CurrentCamera.ViewportSize
    uiScale.Scale = math.max(0.5, math.min(vp.X / 480, vp.Y / 640, 1))
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(ajusterScale)
ajusterScale()

-- ── En-tête ──────────────────────────────────────────────────────────────────
local titleBar = newInst("Frame", {
    Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1,
    BorderSizePixel = 0, ZIndex = 3, Parent = mainFrame,
})

newInst("TextLabel", {
    Size = UDim2.new(1, -60, 1, 0), Position = UDim2.new(0, 16, 0, 0),
    BackgroundTransparency = 1, Text = "TELEPORT",
    Font = Enum.Font.GothamBold, TextSize = 18, TextScaled = false,
    TextColor3 = C.TextPrim, TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 4, Parent = titleBar,
})

local closeBtn = newInst("TextButton", {
    Size = UDim2.new(0, 44, 0, 44), Position = UDim2.new(1, -50, 0, 4),
    BackgroundColor3 = C.Disabled, Text = "X",
    Font = Enum.Font.GothamBold, TextSize = 16, TextScaled = false,
    TextColor3 = C.TextSec, BorderSizePixel = 0, ZIndex = 5, Parent = titleBar,
})
addCorner(closeBtn, 2)
addStroke(closeBtn)
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
    { key = "TOUR_VITE",    label = "VIP Tower"    },
    { key = "TOUR_COMMUNE", label = "Community Tower" },
    { key = "BASE",         label = "My Base"      },
}

local fermerMenu  -- déclaration anticipée pour les closures des boutons

for i, dest in ipairs(DESTINATIONS) do
    local card = newInst("Frame", {
        Size             = UDim2.new(1, 0, 0, 72),
        BackgroundColor3 = C.CardBg,
        BorderSizePixel  = 0,
        LayoutOrder      = i,
        ZIndex           = 4,
        Parent           = contentFrame,
    })
    addCorner(card, 2)
    addStroke(card)

    -- Nom
    newInst("TextLabel", {
        Size = UDim2.new(1, -110, 1, 0), Position = UDim2.new(0, 16, 0, 0),
        BackgroundTransparency = 1, Text = dest.label,
        Font = Enum.Font.GothamBold, TextSize = 15, TextScaled = false,
        TextColor3 = C.TextPrim, TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 5, Parent = card,
    })

    -- Bouton Aller
    local tpBtn = newInst("TextButton", {
        Size             = UDim2.new(0, 88, 0, 42),
        AnchorPoint      = Vector2.new(1, 0.5),
        Position         = UDim2.new(1, -10, 0.5, 0),
        BackgroundColor3 = C.Accent,
        Text             = "Go",
        Font             = Enum.Font.GothamBold,
        TextSize         = 13,
        TextScaled       = false,
        TextColor3       = C.TextPrim,
        BorderSizePixel  = 0,
        ZIndex           = 5,
        Parent           = card,
    })
    addCorner(tpBtn, 2)
    addStroke(tpBtn)
    addHover(tpBtn, C.Accent)

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
local function ouvrirMenu()
    local shopGui = playerGui:FindFirstChild("ShopMonetGui")
    if shopGui then shopGui.Enabled = false end
    menuGui.Enabled    = true
    mainFrame.Position = UDim2.new(0.5, 0, 1.6, 0)
    TweenService:Create(mainFrame,
        TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Position = UDim2.new(0.5, 0, 0.5, 0) }):Play()
end

fermerMenu = function()
    local tw = TweenService:Create(mainFrame,
        TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { Position = UDim2.new(0.5, 0, 1.6, 0) })
    tw:Play()
    tw.Completed:Connect(function() menuGui.Enabled = false end)
end

-- ============================================================================
-- CONNEXIONS
-- ============================================================================
tpOpenBtn.MouseButton1Click:Connect(function()
    if menuGui.Enabled then
        fermerMenu()
    else
        ouvrirMenu()
    end
end)

closeBtn.MouseButton1Click:Connect(fermerMenu)

-- ── Masquer bouton + fermer menu en tour ─────────────────────────────────────
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
-- ─────────────────────────────────────────────────────────────────────────────
