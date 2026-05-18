-- StarterPlayerScripts/ShopClient.client.lua
-- Interface graphique du shop LavaTower

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local Logger            = require(game:GetService("ReplicatedStorage").SharedLib.Logger)

local ShopConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ShopConfig"))

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ShopOpen     = ReplicatedStorage:WaitForChild("ShopOpen",     30)
local ShopPurchase = ReplicatedStorage:WaitForChild("ShopPurchase", 30)
local ShopRefresh  = ReplicatedStorage:WaitForChild("ShopRefresh",  30)

if not ShopOpen or not ShopPurchase or not ShopRefresh then
    Logger.warn("Shop", "RemoteEvents du shop introuvables -- GUI desactive")
    return
end

-- Palette : thème LavaTower avec couleurs vives par catégorie
local C = {
    PanelBg  = Color3.fromRGB(12,  10,  8),
    CardBg   = Color3.fromRGB(22,  20,  18),
    Bordure  = Color3.fromRGB(60,  60,  60),
    Accent   = Color3.fromRGB(220, 110, 15),
    AccentStr= Color3.fromRGB(255, 150, 40),
    Succes   = Color3.fromRGB(60,  140, 70),
    Danger   = Color3.fromRGB(140, 70,  70),
    TextPrim = Color3.fromRGB(230, 230, 230),
    TextSec  = Color3.fromRGB(130, 130, 130),
    Fermer   = Color3.fromRGB(50,  50,  50),
    Gold     = Color3.fromRGB(255, 200, 50),
    OrangeStroke = Color3.fromRGB(200, 90, 10),
}

-- Couleurs par item et upgrade — top = highlight subtil, bot = base (gradient propre)
-- Palette cohérente : bleu, violet, ambre, vert, orange
local ITEM_STYLES = {
    SpeedCoil   = { top = Color3.fromRGB(90,  155, 255), bot = Color3.fromRGB(55,  115, 230), str = Color3.fromRGB(140, 195, 255) },
    GravityCoil = { top = Color3.fromRGB(175, 110, 255), bot = Color3.fromRGB(135, 68,  220), str = Color3.fromRGB(215, 160, 255) },
    VoidCape    = { top = Color3.fromRGB(130, 68,  230), bot = Color3.fromRGB(95,  35,  190), str = Color3.fromRGB(170, 115, 255) },
    Rocket      = { top = Color3.fromRGB(255, 120, 55),  bot = Color3.fromRGB(225, 80,  18),  str = Color3.fromRGB(255, 165, 95)  },
}
local UPGRADE_STYLES = {
    Carry = { top = Color3.fromRGB(255, 190, 65),  bot = Color3.fromRGB(220, 150, 22), str = Color3.fromRGB(255, 218, 105) },
    Speed = { top = Color3.fromRGB(90,  155, 255), bot = Color3.fromRGB(55,  115, 230), str = Color3.fromRGB(140, 195, 255) },
    Jump  = { top = Color3.fromRGB(75,  225, 125), bot = Color3.fromRGB(42,  190, 88),  str = Color3.fromRGB(115, 255, 165) },
}

local function addGradientV(parent, c0, c1)
    local g = Instance.new("UIGradient")
    g.Color    = ColorSequence.new(c0, c1)
    g.Rotation = 90
    g.Parent   = parent
    return g
end

local currentData = nil
local activeTab   = "Upgrades"

-- Utilitaires UI
local function newInst(class, props)
    local inst = Instance.new(class)
    for k, v in pairs(props) do inst[k] = v end
    return inst
end

local function addCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 0)
    c.Parent = parent
    return c
end

local function addStroke(parent)
    local s = Instance.new("UIStroke")
    s.Name      = "Stroke"
    s.Color     = C.Bordure
    s.Thickness = 1
    s.Parent    = parent
    return s
end

local function addPadding(parent, px)
    local p = Instance.new("UIPadding")
    p.PaddingLeft   = UDim.new(0, px)
    p.PaddingRight  = UDim.new(0, px)
    p.PaddingTop    = UDim.new(0, px)
    p.PaddingBottom = UDim.new(0, px)
    p.Parent = parent
end

-- Hover sans accumulation : couleur originale capturee une seule fois
local function addHover(btn)
    local couleurBase = nil
    local tweenActif  = nil
    local strokeInst  = btn:FindFirstChild("Stroke")

    btn.MouseEnter:Connect(function()
        couleurBase = btn.BackgroundColor3
        local cible = Color3.new(
            math.min(1, couleurBase.R + 0.08),
            math.min(1, couleurBase.G + 0.08),
            math.min(1, couleurBase.B + 0.08)
        )
        if tweenActif then tweenActif:Cancel() end
        tweenActif = TweenService:Create(btn, TweenInfo.new(0.08), { BackgroundColor3 = cible })
        tweenActif:Play()
        if strokeInst then
            TweenService:Create(strokeInst, TweenInfo.new(0.08), { Color = C.OrangeStroke }):Play()
        end
    end)

    btn.MouseLeave:Connect(function()
        if not couleurBase then return end
        local restaurer = couleurBase
        couleurBase = nil
        if tweenActif then tweenActif:Cancel() end
        tweenActif = TweenService:Create(btn, TweenInfo.new(0.08), { BackgroundColor3 = restaurer })
        tweenActif:Play()
        if strokeInst then
            TweenService:Create(strokeInst, TweenInfo.new(0.08), { Color = C.Bordure }):Play()
        end
    end)
end

-- ScreenGui
local screenGui = newInst("ScreenGui", {
    Name           = "ShopGui",
    ResetOnSpawn   = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    Enabled        = false,
    Parent         = playerGui,
})

-- Overlay invisible pour fermer en cliquant a cote
local backdrop = newInst("TextButton", {
    Name                   = "Backdrop",
    Size                   = UDim2.fromScale(1, 1),
    BackgroundColor3       = Color3.new(0, 0, 0),
    BackgroundTransparency = 1,
    BorderSizePixel        = 0,
    Text                   = "",
    ZIndex                 = 1,
    Parent                 = screenGui,
})

-- Fenetre principale
local mainFrame = newInst("Frame", {
    Name                   = "MainFrame",
    Size                   = UDim2.new(0, 420, 0, 560),
    AnchorPoint            = Vector2.new(0.5, 0.5),
    Position               = UDim2.new(0.5, 0, 1.5, 0),
    BackgroundColor3       = C.PanelBg,
    BackgroundTransparency = 0,
    BorderSizePixel        = 0,
    ZIndex                 = 2,
    Parent                 = screenGui,
})
addCorner(mainFrame, 4)
do
    local s = Instance.new("UIStroke")
    s.Name = "Stroke"; s.Color = C.AccentStr; s.Thickness = 2; s.Parent = mainFrame
end

-- UIScale sur mainFrame uniquement (le backdrop reste plein ecran)
local uiScale = Instance.new("UIScale")
uiScale.Parent = mainFrame

local function ajusterScale()
    local vp = workspace.CurrentCamera.ViewportSize
    local s  = math.min(vp.X / 480, vp.Y / 640, 1)
    uiScale.Scale = math.max(0.55, s)
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(ajusterScale)
ajusterScale()

-- Header avec gradient orange lava
local titleBar = newInst("Frame", {
    Name            = "TitleBar",
    Size            = UDim2.new(1, 0, 0, 52),
    BackgroundColor3= C.Accent,
    BorderSizePixel = 0,
    ZIndex          = 3,
    Parent          = mainFrame,
})
addCorner(titleBar, 4)
addGradientV(titleBar, Color3.fromRGB(220, 110, 15), Color3.fromRGB(150, 65, 5))

newInst("TextLabel", {
    Size                   = UDim2.new(1, -60, 1, 0),
    Position               = UDim2.new(0, 16, 0, 0),
    BackgroundTransparency = 1,
    Text                   = "SHOP",
    Font                   = Enum.Font.GothamBold,
    TextSize               = 18,
    TextScaled             = false,
    TextColor3             = Color3.fromRGB(255, 255, 255),
    TextStrokeColor3       = Color3.fromRGB(80, 30, 0),
    TextStrokeTransparency = 0.5,
    TextXAlignment         = Enum.TextXAlignment.Left,
    ZIndex                 = 4,
    Parent                 = titleBar,
})

local closeBtn = newInst("TextButton", {
    Name             = "CloseBtn",
    Size             = UDim2.new(0, 44, 0, 44),
    Position         = UDim2.new(1, -50, 0, 4),
    BackgroundColor3 = C.Fermer,
    Text             = "X",
    Font             = Enum.Font.GothamBold,
    TextSize         = 16,
    TextScaled       = false,
    TextColor3       = Color3.fromRGB(180, 180, 180),
    BorderSizePixel  = 0,
    ZIndex           = 5,
    Parent           = titleBar,
})
addCorner(closeBtn, 2)
addStroke(closeBtn)
addHover(closeBtn)

-- Separateur sous le header
newInst("Frame", {
    Size             = UDim2.new(1, -24, 0, 1),
    Position         = UDim2.new(0, 12, 0, 52),
    BackgroundColor3 = C.Bordure,
    BorderSizePixel  = 0,
    ZIndex           = 3,
    Parent           = mainFrame,
})

-- Onglets
local tabBar = newInst("Frame", {
    Name                   = "TabBar",
    Size                   = UDim2.new(1, -24, 0, 44),
    Position               = UDim2.new(0, 12, 0, 60),
    BackgroundTransparency = 1,
    BorderSizePixel        = 0,
    ZIndex                 = 3,
    Parent                 = mainFrame,
})

newInst("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    SortOrder     = Enum.SortOrder.LayoutOrder,
    Padding       = UDim.new(0, 8),
    Parent        = tabBar,
})

local function creerOnglet(lbl, order)
    local btn = newInst("TextButton", {
        Name             = "Tab_" .. lbl,
        Size             = UDim2.new(0.5, -4, 1, 0),
        BackgroundColor3 = C.Bordure,
        Text             = lbl:upper(),
        Font             = Enum.Font.GothamBold,
        TextSize         = 13,
        TextScaled       = false,
        TextColor3       = C.TextSec,
        BorderSizePixel  = 0,
        LayoutOrder      = order,
        ZIndex           = 4,
        Parent           = tabBar,
    })
    addCorner(btn, 4)
    addStroke(btn)
    return btn
end

local tabObjets   = creerOnglet("Objets",   1)
local tabUpgrades = creerOnglet("Upgrades", 2)

-- Separateur sous les tabs
newInst("Frame", {
    Size             = UDim2.new(1, -24, 0, 1),
    Position         = UDim2.new(0, 12, 0, 112),
    BackgroundColor3 = C.Bordure,
    BorderSizePixel  = 0,
    ZIndex           = 3,
    Parent           = mainFrame,
})

-- Zone de contenu
local contentFrame = newInst("Frame", {
    Name                   = "Content",
    Size                   = UDim2.new(1, -24, 1, -124),
    Position               = UDim2.new(0, 12, 0, 118),
    BackgroundTransparency = 1,
    BorderSizePixel        = 0,
    ZIndex                 = 3,
    Parent                 = mainFrame,
})

-- ══════════════════════════════════════════════════════════════════════════════
-- TAB OBJETS
-- ══════════════════════════════════════════════════════════════════════════════
local objetsFrame = newInst("Frame", {
    Name                   = "ObjetsFrame",
    Size                   = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Visible                = false,
    ZIndex                 = 4,
    Parent                 = contentFrame,
})

local objetsScroll = newInst("ScrollingFrame", {
    Name                   = "ObjetsScroll",
    Size                   = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    BorderSizePixel        = 0,
    ScrollBarThickness     = 4,
    ScrollBarImageColor3   = C.Accent,
    CanvasSize             = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize    = Enum.AutomaticSize.Y,
    ZIndex                 = 5,
    Parent                 = objetsFrame,
})
newInst("UIListLayout", {
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding   = UDim.new(0, 8),
    Parent    = objetsScroll,
})

-- creerRowObjet : stylise avec gradient et stroke colorés selon l'item
local function creerRowObjet(layoutOrder, style)
    local s = style or { top = C.CardBg, bot = C.CardBg, str = C.Bordure }
    local row = newInst("Frame", {
        Size            = UDim2.new(1, 0, 0, 100),
        BackgroundColor3= s.bot,
        BorderSizePixel = 0,
        LayoutOrder     = layoutOrder,
        ZIndex          = 6,
        Parent          = objetsScroll,
    })
    addCorner(row, 4)
    do
        local sk = Instance.new("UIStroke")
        sk.Name = "Stroke"; sk.Color = s.str; sk.Thickness = 1.5; sk.Parent = row
    end
    addGradientV(row, s.top, s.bot)
    addPadding(row, 10)
    return row
end

-- creerIconeRow : carré coloré (sans emoji)
local function creerIconeRow(parent, _unused, bgColor)
    local frame = newInst("Frame", {
        Size             = UDim2.new(0, 72, 0, 72),
        Position         = UDim2.new(0, 0, 0.5, -36),
        BackgroundColor3 = bgColor or Color3.fromRGB(35, 35, 35),
        BorderSizePixel  = 0,
        ZIndex           = 7,
        Parent           = parent,
    })
    addCorner(frame, 10)
    return frame
end

local function creerNomRow(parent, texte)
    return newInst("TextLabel", {
        Size                   = UDim2.new(0, 160, 0, 28),
        Position               = UDim2.new(0, 90, 0.5, -14),
        BackgroundTransparency = 1,
        Text                   = texte,
        Font                   = Enum.Font.GothamBold,
        TextSize               = 15,
        TextScaled             = false,
        TextXAlignment         = Enum.TextXAlignment.Left,
        TextColor3             = C.TextPrim,
        ZIndex                 = 7,
        Parent                 = parent,
    })
end

local function creerBoutonRow(parent, texte, couleur, offsetX)
    local btn = newInst("TextButton", {
        Size             = UDim2.new(0, 90, 0, 44),
        Position         = UDim2.new(1, offsetX, 0.5, -22),
        BackgroundColor3 = couleur,
        Text             = texte,
        Font             = Enum.Font.GothamBold,
        TextSize         = 12,
        TextScaled       = false,
        TextColor3       = C.TextPrim,
        BorderSizePixel  = 0,
        ZIndex           = 8,
        Parent           = parent,
    })
    addCorner(btn, 2)
    addStroke(btn)
    addHover(btn)
    return btn
end

-- ROW SPEEDCOIL
local speedCoilRow = creerRowObjet(1, ITEM_STYLES.SpeedCoil)
speedCoilRow.Name  = "SpeedCoilRow"
creerIconeRow(speedCoilRow, ITEM_STYLES.SpeedCoil.icon, ITEM_STYLES.SpeedCoil.top)
creerNomRow(speedCoilRow, "SpeedCoil")

local speedCoilPriceBtn   = creerBoutonRow(speedCoilRow, ShopConfig.FormatNumber(ShopConfig.SpeedCoil.Price), C.Succes, -94)
local speedCoilEquipBtn   = creerBoutonRow(speedCoilRow, "Equiper",    C.Accent,  -94)
local speedCoilUnequipBtn = creerBoutonRow(speedCoilRow, "Desequiper", C.Bordure, -94)
speedCoilEquipBtn.Visible   = false
speedCoilUnequipBtn.Visible = false

local function refreshSpeedCoil(data)
    local has      = data.hasSpeedCoil      or false
    local equipped = data.speedCoilEquipped or false
    speedCoilPriceBtn.Visible   = not has
    speedCoilEquipBtn.Visible   = has and not equipped
    speedCoilUnequipBtn.Visible = has and equipped
end

speedCoilPriceBtn:SetAttribute("PlayCollect", true)
speedCoilPriceBtn.MouseButton1Click:Connect(function()   ShopPurchase:FireServer("SpeedCoil_Buy")     end)
speedCoilEquipBtn.MouseButton1Click:Connect(function()   ShopPurchase:FireServer("SpeedCoil_Equip")   end)
speedCoilUnequipBtn.MouseButton1Click:Connect(function() ShopPurchase:FireServer("SpeedCoil_Unequip") end)

-- ROW GRAVITYCOIL
local gravityCoilRow = creerRowObjet(2, ITEM_STYLES.GravityCoil)
gravityCoilRow.Name  = "GravityCoilRow"
creerIconeRow(gravityCoilRow, ITEM_STYLES.GravityCoil.icon, ITEM_STYLES.GravityCoil.top)
creerNomRow(gravityCoilRow, "GravityCoil")

local gravityCoilPriceBtn   = creerBoutonRow(gravityCoilRow, ShopConfig.FormatNumber(ShopConfig.GravityCoil.Price), C.Succes, -94)
local gravityCoilEquipBtn   = creerBoutonRow(gravityCoilRow, "Equiper",    C.Accent,  -94)
local gravityCoilUnequipBtn = creerBoutonRow(gravityCoilRow, "Desequiper", C.Bordure, -94)
gravityCoilEquipBtn.Visible   = false
gravityCoilUnequipBtn.Visible = false

local function refreshGravityCoil(data)
    local has      = data.hasGravityCoil      or false
    local equipped = data.gravityCoilEquipped or false
    gravityCoilPriceBtn.Visible   = not has
    gravityCoilEquipBtn.Visible   = has and not equipped
    gravityCoilUnequipBtn.Visible = has and equipped
end

gravityCoilPriceBtn:SetAttribute("PlayCollect", true)
gravityCoilPriceBtn.MouseButton1Click:Connect(function()   ShopPurchase:FireServer("GravityCoil_Buy")     end)
gravityCoilEquipBtn.MouseButton1Click:Connect(function()   ShopPurchase:FireServer("GravityCoil_Equip")   end)
gravityCoilUnequipBtn.MouseButton1Click:Connect(function() ShopPurchase:FireServer("GravityCoil_Unequip") end)

-- ROW VOID CAPE
local capeRow = creerRowObjet(3, ITEM_STYLES.VoidCape)
capeRow.Name = "VoidCapeRow"
creerIconeRow(capeRow, ITEM_STYLES.VoidCape.icon, ITEM_STYLES.VoidCape.top)
creerNomRow(capeRow, "The Void Cape")

local capePriceBtn   = creerBoutonRow(capeRow, ShopConfig.FormatNumber(ShopConfig.Cape.Price), C.Succes,  -94)
local capeEquipBtn   = creerBoutonRow(capeRow, "Equiper",    C.Accent,  -94)
local capeUnequipBtn = creerBoutonRow(capeRow, "Desequiper", C.Bordure, -94)
capeEquipBtn.Visible   = false
capeUnequipBtn.Visible = false

local function refreshCape(data)
    local has      = data.hasCape      or false
    local equipped = data.capeEquipped or false
    capePriceBtn.Visible   = not has
    capeEquipBtn.Visible   = has and not equipped
    capeUnequipBtn.Visible = has and equipped
end

capePriceBtn:SetAttribute("PlayCollect", true)
capePriceBtn.MouseButton1Click:Connect(function()   ShopPurchase:FireServer("Cape_Buy")     end)
capeEquipBtn.MouseButton1Click:Connect(function()   ShopPurchase:FireServer("Cape_Equip")   end)
capeUnequipBtn.MouseButton1Click:Connect(function() ShopPurchase:FireServer("Cape_Unequip") end)

-- ROW ROCKET
local rocketRow = creerRowObjet(4, ITEM_STYLES.Rocket)
rocketRow.Name  = "RocketRow"
creerIconeRow(rocketRow, ITEM_STYLES.Rocket.icon, ITEM_STYLES.Rocket.top)
creerNomRow(rocketRow, "Rocket")

local rocketPriceBtn   = creerBoutonRow(rocketRow, ShopConfig.FormatNumber(ShopConfig.Rocket.Price), C.Succes,  -94)
local rocketEquipBtn   = creerBoutonRow(rocketRow, "Equiper",    C.Accent,  -94)
local rocketUnequipBtn = creerBoutonRow(rocketRow, "Desequiper", C.Bordure, -94)
rocketEquipBtn.Visible   = false
rocketUnequipBtn.Visible = false

local function refreshRocket(data)
    local has      = data.hasRocket      or false
    local equipped = data.rocketEquipped or false
    rocketPriceBtn.Visible   = not has
    rocketEquipBtn.Visible   = has and not equipped
    rocketUnequipBtn.Visible = has and equipped
end

rocketPriceBtn:SetAttribute("PlayCollect", true)
rocketPriceBtn.MouseButton1Click:Connect(function()   ShopPurchase:FireServer("Rocket_Buy")     end)
rocketEquipBtn.MouseButton1Click:Connect(function()   ShopPurchase:FireServer("Rocket_Equip")   end)
rocketUnequipBtn.MouseButton1Click:Connect(function() ShopPurchase:FireServer("Rocket_Unequip") end)

-- ══════════════════════════════════════════════════════════════════════════════
-- TAB UPGRADES
-- ══════════════════════════════════════════════════════════════════════════════
local upgradesFrame = newInst("Frame", {
    Name                   = "UpgradesFrame",
    Size                   = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Visible                = true,
    ZIndex                 = 4,
    Parent                 = contentFrame,
})

local upgradeScroll = newInst("ScrollingFrame", {
    Name                   = "UpgradeScroll",
    Size                   = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    BorderSizePixel        = 0,
    ScrollBarThickness     = 4,
    ScrollBarImageColor3   = C.Accent,
    CanvasSize             = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize    = Enum.AutomaticSize.Y,
    ZIndex                 = 5,
    Parent                 = upgradesFrame,
})
addPadding(upgradeScroll, 4)
newInst("UIListLayout", {
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding   = UDim.new(0, 8),
    Parent    = upgradeScroll,
})

local upgradeRows = {}

local function creerBoutonAchat(lbl, color, parent, onClick)
    local btn = newInst("TextButton", {
        Size             = UDim2.new(0, 56, 0, 44),
        BackgroundColor3 = color,
        Text             = lbl,
        Font             = Enum.Font.GothamBold,
        TextSize         = 12,
        TextScaled       = false,
        TextColor3       = C.TextPrim,
        BorderSizePixel  = 0,
        ZIndex           = 8,
        Parent           = parent,
    })
    addCorner(btn, 2)
    addStroke(btn)
    addHover(btn)
    btn:SetAttribute("PlayCollect", true)
    btn.MouseButton1Click:Connect(onClick)
    return btn
end

-- Ligne Carry
local function creerRowCarry()
    local s = UPGRADE_STYLES.Carry
    local row = newInst("Frame", {
        Name            = "RowCarry",
        Size            = UDim2.new(1, 0, 0, 80),
        BackgroundColor3= s.bot,
        BorderSizePixel = 0,
        LayoutOrder     = 1,
        ZIndex          = 6,
        Parent          = upgradeScroll,
    })
    addCorner(row, 4)
    do
        local sk = Instance.new("UIStroke")
        sk.Name = "Stroke"; sk.Color = s.str; sk.Thickness = 1.5; sk.Parent = row
    end
    addGradientV(row, s.top, s.bot)
    addPadding(row, 10)
    -- Bande colorée décorative en haut de la carte
    local topBand = newInst("Frame", {
        Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = s.str,
        BorderSizePixel = 0, ZIndex = 5, Parent = row,
    })
    addCorner(topBand, 4)

    local title = newInst("TextLabel", {
        Size                   = UDim2.new(1, -100, 0, 22),
        BackgroundTransparency = 1,
        Font                   = Enum.Font.GothamBold,
        TextSize               = 15,
        TextScaled             = false,
        TextXAlignment         = Enum.TextXAlignment.Left,
        TextColor3             = C.TextPrim,
        ZIndex                 = 7,
        Parent                 = row,
    })

    local priceLabel = newInst("TextLabel", {
        Size                   = UDim2.new(0.6, 0, 0, 18),
        Position               = UDim2.new(0, 0, 0, 28),
        BackgroundTransparency = 1,
        Font                   = Enum.Font.GothamBold,
        TextSize               = 12,
        TextScaled             = false,
        TextXAlignment         = Enum.TextXAlignment.Left,
        TextColor3             = C.Gold,
        ZIndex                 = 7,
        Parent                 = row,
    })

    local buyBtn = newInst("TextButton", {
        Size             = UDim2.new(0, 90, 0, 44),
        Position         = UDim2.new(1, -90, 0.5, -22),
        BackgroundColor3 = C.Succes,
        Text             = "Acheter",
        Font             = Enum.Font.GothamBold,
        TextSize         = 13,
        TextScaled       = false,
        TextColor3       = C.TextPrim,
        BorderSizePixel  = 0,
        ZIndex           = 8,
        Parent           = row,
    })
    addCorner(buyBtn, 2)
    addStroke(buyBtn)
    addHover(buyBtn)
    buyBtn:SetAttribute("PlayCollect", true)

    buyBtn.MouseButton1Click:Connect(function()
        ShopPurchase:FireServer("Carry", 1)
    end)

    local function refresh(data)
        local level   = (data.upgrades and data.upgrades.carry) or 0
        local maxed   = level >= ShopConfig.Carry.MaxLevel
        local nextLvl = level + 1
        local prix    = maxed and "--" or ShopConfig.FormatNumber(ShopConfig.GetCarryPrice(nextLvl))

        title.Text      = "Carry   Niv. " .. level .. "/" .. ShopConfig.Carry.MaxLevel
        priceLabel.Text = maxed and "Maximum atteint" or ("Prochain : " .. prix)
        buyBtn.Visible          = not maxed
        buyBtn.BackgroundColor3 = maxed and C.Bordure or C.Succes
    end

    upgradeRows["Carry"] = { frame = row, refresh = refresh }
end

-- Ligne Speed / Jump (x1 x10 MAX)
local function creerRowStatMulti(cfg, upgradeType, layoutOrder)
    local s = UPGRADE_STYLES[upgradeType] or { top = C.CardBg, bot = C.CardBg, str = C.Bordure, icon = "⬜" }

    local row = newInst("Frame", {
        Name            = "Row" .. upgradeType,
        Size            = UDim2.new(1, 0, 0, 104),
        BackgroundColor3= s.bot,
        BorderSizePixel = 0,
        LayoutOrder     = layoutOrder,
        ZIndex          = 6,
        Parent          = upgradeScroll,
    })
    addCorner(row, 4)
    do
        local sk = Instance.new("UIStroke")
        sk.Name = "Stroke"; sk.Color = s.str; sk.Thickness = 1.5; sk.Parent = row
    end
    addGradientV(row, s.top, s.bot)
    addPadding(row, 10)
    -- Bande colorée décorative en haut de la carte
    local topBand = newInst("Frame", {
        Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = s.str,
        BorderSizePixel = 0, ZIndex = 5, Parent = row,
    })
    addCorner(topBand, 4)

    local title = newInst("TextLabel", {
        Size                   = UDim2.new(1, 0, 0, 22),
        BackgroundTransparency = 1,
        Font                   = Enum.Font.GothamBold,
        TextSize               = 15,
        TextScaled             = false,
        TextXAlignment         = Enum.TextXAlignment.Left,
        TextColor3             = C.TextPrim,
        ZIndex                 = 7,
        Parent                 = row,
    })

    local priceLabel = newInst("TextLabel", {
        Size                   = UDim2.new(1, 0, 0, 16),
        Position               = UDim2.new(0, 0, 0, 26),
        BackgroundTransparency = 1,
        Font                   = Enum.Font.GothamBold,
        TextSize               = 12,
        TextScaled             = false,
        TextXAlignment         = Enum.TextXAlignment.Left,
        TextColor3             = C.Gold,
        ZIndex                 = 7,
        Parent                 = row,
    })

    local btnContainer = newInst("Frame", {
        Size                   = UDim2.new(1, 0, 0, 44),
        Position               = UDim2.new(0, 0, 0, 46),
        BackgroundTransparency = 1,
        ZIndex                 = 7,
        Parent                 = row,
    })
    newInst("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding       = UDim.new(0, 8),
        SortOrder     = Enum.SortOrder.LayoutOrder,
        Parent        = btnContainer,
    })

    local btn1   = creerBoutonAchat("x1",  C.Succes, btnContainer, function() ShopPurchase:FireServer(upgradeType, 1)     end)
    local btn10  = creerBoutonAchat("x10", C.Succes, btnContainer, function() ShopPurchase:FireServer(upgradeType, 10)    end)
    local btnMax = creerBoutonAchat("MAX", C.Accent, btnContainer, function() ShopPurchase:FireServer(upgradeType, "Max") end)
    btn1.LayoutOrder   = 1
    btn10.LayoutOrder  = 2
    btnMax.LayoutOrder = 3

    local function refresh(data)
        local level = (data.upgrades and data.upgrades[upgradeType:lower()]) or 0
        local maxed = level >= cfg.MaxLevel

        title.Text = cfg.Label .. "   Niv. " .. level .. "/" .. cfg.MaxLevel

        if maxed then
            priceLabel.Text = "Maximum atteint"
        else
            local prix1 = ShopConfig["Get" .. upgradeType .. "Price"](level + 1)
            priceLabel.Text = "Prochain : " .. ShopConfig.FormatNumber(prix1)
        end

        btn1.Visible   = not maxed
        btn10.Visible  = not maxed
        btnMax.Visible = not maxed
    end

    upgradeRows[upgradeType] = { frame = row, refresh = refresh }
end

-- Construction initiale
creerRowCarry()
creerRowStatMulti(ShopConfig.Speed, "Speed", 2)
creerRowStatMulti(ShopConfig.Jump,  "Jump",  3)

-- Refresh de l'UI avec les donnees serveur
local function refreshUI(data)
    if not data then return end
    currentData = data
    for _, row in pairs(upgradeRows) do
        row.refresh(data)
    end
    refreshSpeedCoil(data)
    refreshGravityCoil(data)
    refreshCape(data)
    refreshRocket(data)
end

-- Gestion des onglets (onglet actif = gradient orange, inactif = gris)
local function setTab(tab)
    activeTab = tab
    objetsFrame.Visible   = (tab == "Objets")
    upgradesFrame.Visible = (tab == "Upgrades")

    local function styleTab(btn, isActive)
        btn.BackgroundColor3 = isActive and C.Accent or C.Bordure
        btn.TextColor3       = isActive and Color3.fromRGB(255,255,255) or C.TextSec
        local g = btn:FindFirstChildWhichIsA("UIGradient")
        if g then g:Destroy() end
        if isActive then
            addGradientV(btn, Color3.fromRGB(240, 130, 20), Color3.fromRGB(160, 70, 5))
        end
        local sk = btn:FindFirstChild("Stroke")
        if sk then sk.Color = isActive and C.AccentStr or C.Bordure end
    end
    styleTab(tabObjets,   tab == "Objets")
    styleTab(tabUpgrades, tab == "Upgrades")
end

setTab("Upgrades")

tabObjets.MouseButton1Click:Connect(function()   setTab("Objets")   end)
tabUpgrades.MouseButton1Click:Connect(function() setTab("Upgrades") end)

-- Ouvrir : slide depuis le bas (0.2s Quad Out)
local function ouvrirShop(data)
    local tpGui    = playerGui:FindFirstChild("TeleportMenuGui")
    if tpGui    then tpGui.Enabled    = false end
    local monetGui = playerGui:FindFirstChild("ShopMonetGui")
    if monetGui then monetGui.Enabled = false end
    local voteGui  = playerGui:FindFirstChild("EventVoteGui")
    if voteGui  then voteGui.Enabled  = false end
    local fuseGui  = playerGui:FindFirstChild("FuseSystemUI")
    if fuseGui  then fuseGui.Enabled  = false end
    refreshUI(data)
    screenGui.Enabled  = true
    mainFrame.Position = UDim2.new(0.5, 0, 1.5, 0)
    TweenService:Create(mainFrame,
        TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Position = UDim2.new(0.5, 0, 0.5, 0) }):Play()
end

-- Fermer : slide vers le bas (0.2s Quad In)
local function fermerShop()
    local tween = TweenService:Create(mainFrame,
        TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { Position = UDim2.new(0.5, 0, 1.5, 0) })
    tween:Play()
    tween.Completed:Connect(function()
        screenGui.Enabled = false
    end)
end

closeBtn.MouseButton1Click:Connect(fermerShop)
backdrop.MouseButton1Click:Connect(fermerShop)

-- Connexions RemoteEvents
ShopOpen.OnClientEvent:Connect(function(data)
    ouvrirShop(data)
end)

ShopRefresh.OnClientEvent:Connect(function(data)
    refreshUI(data)
end)
