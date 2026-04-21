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

-- Palette revisee : noir dominant, orange fonce en accent
local C = {
    PanelBg  = Color3.fromRGB(10,  10,  10),
    CardBg   = Color3.fromRGB(20,  20,  20),
    Bordure  = Color3.fromRGB(60,  60,  60),
    Accent   = Color3.fromRGB(220, 110, 15),
    Succes   = Color3.fromRGB(80,  140, 80),
    Danger   = Color3.fromRGB(140, 70,  70),
    TextPrim = Color3.fromRGB(220, 220, 220),
    TextSec  = Color3.fromRGB(130, 130, 130),
    Fermer   = Color3.fromRGB(50,  50,  50),
    Gold     = Color3.fromRGB(255, 200, 50),
    OrangeStroke = Color3.fromRGB(200, 90, 10),
}

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
    BackgroundTransparency = 0.05,
    BorderSizePixel        = 0,
    ZIndex                 = 2,
    Parent                 = screenGui,
})
addCorner(mainFrame, 0)
addStroke(mainFrame)

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

-- Header
local titleBar = newInst("Frame", {
    Name                   = "TitleBar",
    Size                   = UDim2.new(1, 0, 0, 52),
    BackgroundTransparency = 1,
    BorderSizePixel        = 0,
    ZIndex                 = 3,
    Parent                 = mainFrame,
})

newInst("TextLabel", {
    Size                   = UDim2.new(1, -60, 1, 0),
    Position               = UDim2.new(0, 16, 0, 0),
    BackgroundTransparency = 1,
    Text                   = "SHOP",
    Font                   = Enum.Font.GothamBold,
    TextSize               = 18,
    TextScaled             = false,
    TextColor3             = C.TextPrim,
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
    addCorner(btn, 2)
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

local function creerRowObjet(layoutOrder)
    local row = newInst("Frame", {
        Size                   = UDim2.new(1, 0, 0, 72),
        BackgroundColor3       = C.CardBg,
        BackgroundTransparency = 0,
        BorderSizePixel        = 0,
        LayoutOrder            = layoutOrder,
        ZIndex                 = 6,
        Parent                 = objetsScroll,
    })
    addCorner(row, 0)
    addStroke(row)
    addPadding(row, 10)
    return row
end

local function creerIconeRow(parent)
    local img = newInst("ImageLabel", {
        Size             = UDim2.new(0, 48, 0, 48),
        Position         = UDim2.new(0, 0, 0.5, -24),
        BackgroundColor3 = C.Bordure,
        Image            = "",
        BorderSizePixel  = 0,
        ZIndex           = 7,
        Parent           = parent,
    })
    addCorner(img, 2)
    return img
end

local function creerNomRow(parent, texte)
    return newInst("TextLabel", {
        Size                   = UDim2.new(0, 160, 0, 28),
        Position               = UDim2.new(0, 68, 0.5, -14),
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

-- ROW BAT
local batRow = creerRowObjet(1)
batRow.Name  = "BatRow"
creerIconeRow(batRow)
creerNomRow(batRow, "Bat")

local batPriceBtn   = creerBoutonRow(batRow, ShopConfig.FormatNumber(ShopConfig.Bat.Price), C.Succes,  -94)
local batEquipBtn   = creerBoutonRow(batRow, "Equiper",    C.Succes,  -192)
local batUnequipBtn = creerBoutonRow(batRow, "Desequiper", C.Danger,  -94)
batEquipBtn.Visible   = false
batUnequipBtn.Visible = false

local function refreshBat(data)
    local hasBat      = data.hasBat      or false
    local batEquipped = data.batEquipped or false
    batPriceBtn.Visible   = not hasBat
    batEquipBtn.Visible   = hasBat
    batUnequipBtn.Visible = hasBat
    if hasBat then
        batEquipBtn.BackgroundColor3   = batEquipped and C.Bordure or C.Succes
        batUnequipBtn.BackgroundColor3 = batEquipped and C.Danger  or C.Bordure
    end
end

batPriceBtn.MouseButton1Click:Connect(function()   ShopPurchase:FireServer("Bat_Buy")     end)
batEquipBtn.MouseButton1Click:Connect(function()   ShopPurchase:FireServer("Bat_Equip")   end)
batUnequipBtn.MouseButton1Click:Connect(function() ShopPurchase:FireServer("Bat_Unequip") end)

-- ROW GOLDSLAP
local goldSlapRow = creerRowObjet(2)
goldSlapRow.Name  = "GoldSlapRow"
creerIconeRow(goldSlapRow)
creerNomRow(goldSlapRow, "GoldSlap")

local goldSlapPriceBtn   = creerBoutonRow(goldSlapRow, ShopConfig.FormatNumber(ShopConfig.GoldSlap.Price), C.Succes, -94)
local goldSlapEquipBtn   = creerBoutonRow(goldSlapRow, "Equiper",    C.Succes, -192)
local goldSlapUnequipBtn = creerBoutonRow(goldSlapRow, "Desequiper", C.Danger, -94)
goldSlapEquipBtn.Visible   = false
goldSlapUnequipBtn.Visible = false

local function refreshGoldSlap(data)
    local has      = data.hasGoldSlap      or false
    local equipped = data.goldSlapEquipped or false
    goldSlapPriceBtn.Visible   = not has
    goldSlapEquipBtn.Visible   = has
    goldSlapUnequipBtn.Visible = has
    if has then
        goldSlapEquipBtn.BackgroundColor3   = equipped and C.Bordure or C.Succes
        goldSlapUnequipBtn.BackgroundColor3 = equipped and C.Danger  or C.Bordure
    end
end

goldSlapPriceBtn.MouseButton1Click:Connect(function()   ShopPurchase:FireServer("GoldSlap_Buy")     end)
goldSlapEquipBtn.MouseButton1Click:Connect(function()   ShopPurchase:FireServer("GoldSlap_Equip")   end)
goldSlapUnequipBtn.MouseButton1Click:Connect(function() ShopPurchase:FireServer("GoldSlap_Unequip") end)

-- ROW SPEEDCOIL
local speedCoilRow = creerRowObjet(3)
speedCoilRow.Name  = "SpeedCoilRow"
creerIconeRow(speedCoilRow)
creerNomRow(speedCoilRow, "SpeedCoil")

local speedCoilPriceBtn   = creerBoutonRow(speedCoilRow, ShopConfig.FormatNumber(ShopConfig.SpeedCoil.Price), C.Succes, -94)
local speedCoilEquipBtn   = creerBoutonRow(speedCoilRow, "Equiper",    C.Succes, -192)
local speedCoilUnequipBtn = creerBoutonRow(speedCoilRow, "Desequiper", C.Danger, -94)
speedCoilEquipBtn.Visible   = false
speedCoilUnequipBtn.Visible = false

local function refreshSpeedCoil(data)
    local has      = data.hasSpeedCoil      or false
    local equipped = data.speedCoilEquipped or false
    speedCoilPriceBtn.Visible   = not has
    speedCoilEquipBtn.Visible   = has
    speedCoilUnequipBtn.Visible = has
    if has then
        speedCoilEquipBtn.BackgroundColor3   = equipped and C.Bordure or C.Succes
        speedCoilUnequipBtn.BackgroundColor3 = equipped and C.Danger  or C.Bordure
    end
end

speedCoilPriceBtn.MouseButton1Click:Connect(function()   ShopPurchase:FireServer("SpeedCoil_Buy")     end)
speedCoilEquipBtn.MouseButton1Click:Connect(function()   ShopPurchase:FireServer("SpeedCoil_Equip")   end)
speedCoilUnequipBtn.MouseButton1Click:Connect(function() ShopPurchase:FireServer("SpeedCoil_Unequip") end)

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
    btn.MouseButton1Click:Connect(onClick)
    return btn
end

-- Ligne Carry
local function creerRowCarry()
    local row = newInst("Frame", {
        Name                   = "RowCarry",
        Size                   = UDim2.new(1, 0, 0, 72),
        BackgroundColor3       = C.CardBg,
        BackgroundTransparency = 0,
        BorderSizePixel        = 0,
        LayoutOrder            = 1,
        ZIndex                 = 6,
        Parent                 = upgradeScroll,
    })
    addCorner(row, 0)
    addStroke(row)
    addPadding(row, 10)

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
    local isJump = upgradeType == "Jump"

    local row = newInst("Frame", {
        Name                   = "Row" .. upgradeType,
        Size                   = UDim2.new(1, 0, 0, 96),
        BackgroundColor3       = C.CardBg,
        BackgroundTransparency = 0,
        BorderSizePixel        = 0,
        LayoutOrder            = layoutOrder,
        ZIndex                 = 6,
        Parent                 = upgradeScroll,
    })
    addCorner(row, 0)
    addStroke(row)
    addPadding(row, 10)

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
    refreshBat(data)
    refreshGoldSlap(data)
    refreshSpeedCoil(data)
end

-- Gestion des onglets
local function setTab(tab)
    activeTab = tab
    objetsFrame.Visible   = (tab == "Objets")
    upgradesFrame.Visible = (tab == "Upgrades")
    tabObjets.BackgroundColor3   = (tab == "Objets")   and C.Accent or C.Bordure
    tabUpgrades.BackgroundColor3 = (tab == "Upgrades") and C.Accent or C.Bordure
    tabObjets.TextColor3   = (tab == "Objets")   and C.TextPrim or C.TextSec
    tabUpgrades.TextColor3 = (tab == "Upgrades") and C.TextPrim or C.TextSec
end

setTab("Upgrades")

tabObjets.MouseButton1Click:Connect(function()   setTab("Objets")   end)
tabUpgrades.MouseButton1Click:Connect(function() setTab("Upgrades") end)

-- Ouvrir : slide depuis le bas (0.2s Quad Out)
local function ouvrirShop(data)
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
