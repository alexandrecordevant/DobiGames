-- StarterPlayerScripts/ShopClient.client.lua
-- Interface graphique du shop pour LavaTower

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local Logger            = require(game:GetService("ReplicatedStorage").SharedLib.Logger)

local ShopConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ShopConfig"))

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ShopOpen    = ReplicatedStorage:WaitForChild("ShopOpen",    30)
local ShopPurchase = ReplicatedStorage:WaitForChild("ShopPurchase", 30)
local ShopRefresh  = ReplicatedStorage:WaitForChild("ShopRefresh",  30)

if not ShopOpen or not ShopPurchase or not ShopRefresh then
    Logger.warn("Shop", "RemoteEvents du shop introuvables — GUI désactivé")
    return
end

-- ── Couleurs ──────────────────────────────────────────────────────────────────
local C = {
    BG          = Color3.fromRGB(15, 15, 15),
    BG2         = Color3.fromRGB(25, 25, 25),
    TabInactive = Color3.fromRGB(40, 40, 40),
    TabActive   = Color3.fromRGB(220, 80, 20),   -- orange lave
    Text        = Color3.fromRGB(240, 240, 240),
    TextDim     = Color3.fromRGB(160, 160, 160),
    Gold        = Color3.fromRGB(255, 200, 50),
    Green       = Color3.fromRGB(80, 200, 80),
    Red         = Color3.fromRGB(200, 80, 80),
    Row         = Color3.fromRGB(35, 35, 35),
    RowHover    = Color3.fromRGB(50, 50, 50),
    MaxBtn      = Color3.fromRGB(60, 30, 180),
}

-- ── État local ────────────────────────────────────────────────────────────────
local currentData = nil   -- { upgrades = {carry,speed,jump}, coins = N }
local activeTab   = "Upgrades"

-- ── Utilitaires UI ────────────────────────────────────────────────────────────
local function newInst(class, props)
    local inst = Instance.new(class)
    for k, v in pairs(props) do
        inst[k] = v
    end
    return inst
end

local function addCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = parent
end

local function addPadding(parent, px)
    local p = Instance.new("UIPadding")
    p.PaddingLeft   = UDim.new(0, px)
    p.PaddingRight  = UDim.new(0, px)
    p.PaddingTop    = UDim.new(0, px)
    p.PaddingBottom = UDim.new(0, px)
    p.Parent = parent
end

-- ── Construction de la fenêtre principale ────────────────────────────────────
local screenGui = newInst("ScreenGui", {
    Name            = "ShopGui",
    ResetOnSpawn    = false,
    ZIndexBehavior  = Enum.ZIndexBehavior.Sibling,
    Enabled         = false,
    Parent          = playerGui,
})

-- Fond cliquable pour fermer
local backdrop = newInst("TextButton", {
    Name               = "Backdrop",
    Size               = UDim2.fromScale(1, 1),
    BackgroundColor3   = Color3.new(0, 0, 0),
    BackgroundTransparency = 0.5,
    BorderSizePixel    = 0,
    Text               = "",
    ZIndex             = 1,
    Parent             = screenGui,
})

-- Fenêtre principale
local mainFrame = newInst("Frame", {
    Name               = "MainFrame",
    Size               = UDim2.new(0, 420, 0, 560),
    Position           = UDim2.new(0.5, -210, 0.5, -280),
    BackgroundColor3   = C.BG,
    BorderSizePixel    = 0,
    ZIndex             = 2,
    Parent             = screenGui,
})
addCorner(mainFrame, 12)

-- Barre titre
local titleBar = newInst("Frame", {
    Name             = "TitleBar",
    Size             = UDim2.new(1, 0, 0, 50),
    BackgroundColor3 = C.TabActive,
    BorderSizePixel  = 0,
    ZIndex           = 3,
    Parent           = mainFrame,
})
addCorner(titleBar, 12)
-- Rectangler le bas de la titleBar
newInst("Frame", {
    Size             = UDim2.new(1, 0, 0.5, 0),
    Position         = UDim2.new(0, 0, 0.5, 0),
    BackgroundColor3 = C.TabActive,
    BorderSizePixel  = 0,
    ZIndex           = 3,
    Parent           = titleBar,
})

newInst("TextLabel", {
    Size                   = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Text                   = "SHOP",
    Font                   = Enum.Font.GothamBold,
    TextSize               = 26,
    TextColor3             = Color3.new(1, 1, 1),
    ZIndex                 = 4,
    Parent                 = titleBar,
})

-- Bouton fermer
local closeBtn = newInst("TextButton", {
    Name               = "CloseBtn",
    Size               = UDim2.new(0, 36, 0, 36),
    Position           = UDim2.new(1, -43, 0, 7),
    BackgroundColor3   = Color3.fromRGB(200, 60, 60),
    Text               = "✕",
    Font               = Enum.Font.GothamBold,
    TextSize           = 16,
    TextColor3         = Color3.new(1, 1, 1),
    ZIndex             = 5,
    Parent             = titleBar,
})
addCorner(closeBtn, 6)

-- ── Onglets ───────────────────────────────────────────────────────────────────
local tabBar = newInst("Frame", {
    Name             = "TabBar",
    Size             = UDim2.new(1, -20, 0, 38),
    Position         = UDim2.new(0, 10, 0, 58),
    BackgroundColor3 = C.BG2,
    BorderSizePixel  = 0,
    ZIndex           = 3,
    Parent           = mainFrame,
})
addCorner(tabBar, 8)

local tabLayout = newInst("UIListLayout", {
    FillDirection  = Enum.FillDirection.Horizontal,
    SortOrder      = Enum.SortOrder.LayoutOrder,
    Padding        = UDim.new(0, 4),
    Parent         = tabBar,
})
addPadding(tabBar, 4)

local function creerOnglet(label, order)
    local btn = newInst("TextButton", {
        Name             = "Tab_" .. label,
        Size             = UDim2.new(0.5, -6, 1, -8),
        BackgroundColor3 = C.TabInactive,
        Text             = label:upper(),
        Font             = Enum.Font.GothamBold,
        TextSize         = 13,
        TextColor3       = C.TextDim,
        BorderSizePixel  = 0,
        LayoutOrder      = order,
        ZIndex           = 4,
        Parent           = tabBar,
    })
    addCorner(btn, 6)
    return btn
end

local tabObjets   = creerOnglet("Objets",   1)
local tabUpgrades = creerOnglet("Upgrades", 2)

-- ── Zone de contenu ───────────────────────────────────────────────────────────
local contentFrame = newInst("Frame", {
    Name             = "Content",
    Size             = UDim2.new(1, -20, 1, -110),
    Position         = UDim2.new(0, 10, 0, 105),
    BackgroundColor3 = C.BG2,
    BorderSizePixel  = 0,
    ZIndex           = 3,
    Parent           = mainFrame,
})
addCorner(contentFrame, 8)

-- ── TAB OBJETS ────────────────────────────────────────────────────────────────
local objetsFrame = newInst("Frame", {
    Name                   = "ObjetsFrame",
    Size                   = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Visible                = false,
    ZIndex                 = 4,
    Parent                 = contentFrame,
})

newInst("TextLabel", {
    Size                   = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Text                   = "Aucun objet disponible pour l'instant.",
    Font                   = Enum.Font.Gotham,
    TextSize               = 15,
    TextColor3             = C.TextDim,
    TextWrapped            = true,
    ZIndex                 = 5,
    Parent                 = objetsFrame,
})

-- ── TAB UPGRADES ──────────────────────────────────────────────────────────────
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
    ScrollBarImageColor3   = C.TabActive,
    CanvasSize             = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize    = Enum.AutomaticSize.Y,
    ZIndex                 = 5,
    Parent                 = upgradesFrame,
})
addPadding(upgradeScroll, 8)

local upgradeLayout = newInst("UIListLayout", {
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding   = UDim.new(0, 8),
    Parent    = upgradeScroll,
})

-- ── Construction des lignes d'upgrade ─────────────────────────────────────────
-- Les "rows" sont stockés pour pouvoir les mettre à jour

local upgradeRows = {}   -- [type] = { frame, refresh = function }

local function creerBoutonAchat(label, color, parent, onClick)
    local btn = newInst("TextButton", {
        Size             = UDim2.new(0, 48, 0, 28),
        BackgroundColor3 = color,
        Text             = label,
        Font             = Enum.Font.GothamBold,
        TextSize         = 11,
        TextColor3       = Color3.new(1, 1, 1),
        BorderSizePixel  = 0,
        ZIndex           = 8,
        Parent           = parent,
    })
    addCorner(btn, 5)
    btn.MouseButton1Click:Connect(onClick)
    return btn
end

-- Row CARRY ─────────────────────────────────────────────────────────────────
local function creerRowCarry()
    local row = newInst("Frame", {
        Name             = "RowCarry",
        Size             = UDim2.new(1, 0, 0, 80),
        BackgroundColor3 = C.Row,
        BorderSizePixel  = 0,
        LayoutOrder      = 1,
        ZIndex           = 6,
        Parent           = upgradeScroll,
    })
    addCorner(row, 8)
    addPadding(row, 10)

    local title = newInst("TextLabel", {
        Size                   = UDim2.new(1, 0, 0, 22),
        BackgroundTransparency = 1,
        Font                   = Enum.Font.GothamBold,
        TextSize               = 15,
        TextXAlignment         = Enum.TextXAlignment.Left,
        TextColor3             = Color3.new(1, 1, 1),
        ZIndex                 = 7,
        Parent                 = row,
    })

    local subLabel = newInst("TextLabel", {
        Size                   = UDim2.new(0.6, 0, 0, 18),
        Position               = UDim2.new(0, 0, 0, 26),
        BackgroundTransparency = 1,
        Font                   = Enum.Font.Gotham,
        TextSize               = 12,
        TextXAlignment         = Enum.TextXAlignment.Left,
        TextColor3             = C.TextDim,
        ZIndex                 = 7,
        Parent                 = row,
    })

    local priceLabel = newInst("TextLabel", {
        Size                   = UDim2.new(0.55, 0, 0, 18),
        Position               = UDim2.new(0, 0, 0, 48),
        BackgroundTransparency = 1,
        Font                   = Enum.Font.GothamBold,
        TextSize               = 13,
        TextXAlignment         = Enum.TextXAlignment.Left,
        TextColor3             = C.Gold,
        ZIndex                 = 7,
        Parent                 = row,
    })

    local buyBtn = newInst("TextButton", {
        Size             = UDim2.new(0, 90, 0, 30),
        Position         = UDim2.new(1, -90, 0.5, -15),
        BackgroundColor3 = C.Green,
        Text             = "Acheter",
        Font             = Enum.Font.GothamBold,
        TextSize         = 13,
        TextColor3       = Color3.new(1, 1, 1),
        BorderSizePixel  = 0,
        ZIndex           = 8,
        Parent           = row,
    })
    addCorner(buyBtn, 6)

    buyBtn.MouseButton1Click:Connect(function()
        ShopPurchase:FireServer("Carry", 1)
    end)

    local function refresh(data)
        local level    = (data.upgrades and data.upgrades.carry) or 0
        local maxed    = level >= ShopConfig.Carry.MaxLevel
        local bonus    = level * ShopConfig.Carry.BonusPerLevel
        local nextLvl  = level + 1
        local prix     = maxed and "—" or ShopConfig.FormatNumber(ShopConfig.GetCarryPrice(nextLvl)) .. " 🪙"

        title.Text     = "🎒 Carry   Niv. " .. level .. "/" .. ShopConfig.Carry.MaxLevel
        subLabel.Text  = level == 0 and "Aucun Brainrot portable" or (level .. " BR max")
        priceLabel.Text = maxed and "✅ Maximum atteint" or ("Prochain : " .. prix)
        buyBtn.Visible        = not maxed
        buyBtn.BackgroundColor3 = maxed and C.TabInactive or C.Green
    end

    upgradeRows["Carry"] = { frame = row, refresh = refresh }
end

-- Row générique SPEED / JUMP ─────────────────────────────────────────────────
local function creerRowStatMulti(cfg, upgradeType, layoutOrder)
    local isJump = upgradeType == "Jump"

    local row = newInst("Frame", {
        Name             = "Row" .. upgradeType,
        Size             = UDim2.new(1, 0, 0, 100),
        BackgroundColor3 = C.Row,
        BorderSizePixel  = 0,
        LayoutOrder      = layoutOrder,
        ZIndex           = 6,
        Parent           = upgradeScroll,
    })
    addCorner(row, 8)
    addPadding(row, 10)

    local title = newInst("TextLabel", {
        Size                   = UDim2.new(1, 0, 0, 22),
        BackgroundTransparency = 1,
        Font                   = Enum.Font.GothamBold,
        TextSize               = 15,
        TextXAlignment         = Enum.TextXAlignment.Left,
        TextColor3             = Color3.new(1, 1, 1),
        ZIndex                 = 7,
        Parent                 = row,
    })

    local subLabel = newInst("TextLabel", {
        Size                   = UDim2.new(1, 0, 0, 16),
        Position               = UDim2.new(0, 0, 0, 26),
        BackgroundTransparency = 1,
        Font                   = Enum.Font.Gotham,
        TextSize               = 11,
        TextXAlignment         = Enum.TextXAlignment.Left,
        TextColor3             = C.TextDim,
        ZIndex                 = 7,
        Parent                 = row,
    })

    local priceLabel = newInst("TextLabel", {
        Size                   = UDim2.new(1, 0, 0, 16),
        Position               = UDim2.new(0, 0, 0, 46),
        BackgroundTransparency = 1,
        Font                   = Enum.Font.GothamBold,
        TextSize               = 12,
        TextXAlignment         = Enum.TextXAlignment.Left,
        TextColor3             = C.Gold,
        ZIndex                 = 7,
        Parent                 = row,
    })

    -- Boutons x1 / x10 / MAX
    local btnContainer = newInst("Frame", {
        Size                   = UDim2.new(1, 0, 0, 30),
        Position               = UDim2.new(0, 0, 0, 66),
        BackgroundTransparency = 1,
        ZIndex                 = 7,
        Parent                 = row,
    })
    local btnLayout = newInst("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding       = UDim.new(0, 6),
        SortOrder     = Enum.SortOrder.LayoutOrder,
        Parent        = btnContainer,
    })

    local btn1   = creerBoutonAchat("×1",  C.Green,  btnContainer, function() ShopPurchase:FireServer(upgradeType, 1)     end)
    local btn10  = creerBoutonAchat("×10", C.TabActive, btnContainer, function() ShopPurchase:FireServer(upgradeType, 10)    end)
    local btnMax = creerBoutonAchat("MAX", C.MaxBtn, btnContainer, function() ShopPurchase:FireServer(upgradeType, "Max") end)
    btn1.LayoutOrder  = 1
    btn10.LayoutOrder = 2
    btnMax.LayoutOrder = 3

    local function refresh(data)
        local level = (data.upgrades and data.upgrades[upgradeType:lower()]) or 0
        local maxed = level >= cfg.MaxLevel
        local icon  = isJump and "🦘" or "⚡"
        local note  = isJump and " (tours)" or ""

        title.Text = icon .. " " .. cfg.Label .. "   Niv. " .. level .. "/" .. cfg.MaxLevel .. note

        if isJump then
            local jp      = ShopConfig.GetJumpStat(level)
            local antiPct = math.floor(ShopConfig.GetAntiGravFactor(level) * 100)
            local antiTxt = antiPct > 0 and ("  |  Anti-grav : " .. antiPct .. "%") or ""
            subLabel.Text = "JumpPower : " .. jp .. antiTxt
        else
            local ws  = ShopConfig.GetSpeedStat(level)
            local bon = level * cfg.SpeedPerLevel
            local bonTxt = bon > 0 and ("  (+" .. bon .. ")") or "  (base)"
            subLabel.Text = "WalkSpeed : " .. ws .. bonTxt
        end

        if maxed then
            priceLabel.Text = "✅ Maximum atteint"
        else
            local prix1 = ShopConfig["Get" .. upgradeType .. "Price"](level + 1)
            priceLabel.Text = "Prochain : " .. ShopConfig.FormatNumber(prix1) .. " 🪙"
        end

        btn1.Visible   = not maxed
        btn10.Visible  = not maxed
        btnMax.Visible = not maxed
    end

    upgradeRows[upgradeType] = { frame = row, refresh = refresh }
end

-- ── Construction initiale ─────────────────────────────────────────────────────
creerRowCarry()
creerRowStatMulti(ShopConfig.Speed, "Speed", 2)
creerRowStatMulti(ShopConfig.Jump,  "Jump",  3)

-- ── Refresh de l'UI avec les données reçues ───────────────────────────────────
local function refreshUI(data)
    if not data then return end
    currentData = data
    for _, row in pairs(upgradeRows) do
        row.refresh(data)
    end
end

-- ── Gestion des onglets ───────────────────────────────────────────────────────
local function setTab(tab)
    activeTab = tab
    objetsFrame.Visible   = (tab == "Objets")
    upgradesFrame.Visible = (tab == "Upgrades")

    tabObjets.BackgroundColor3   = (tab == "Objets")   and C.TabActive or C.TabInactive
    tabUpgrades.BackgroundColor3 = (tab == "Upgrades") and C.TabActive or C.TabInactive
    tabObjets.TextColor3   = (tab == "Objets")   and Color3.new(1,1,1) or C.TextDim
    tabUpgrades.TextColor3 = (tab == "Upgrades") and Color3.new(1,1,1) or C.TextDim
end

setTab("Upgrades")

tabObjets.MouseButton1Click:Connect(function()   setTab("Objets")   end)
tabUpgrades.MouseButton1Click:Connect(function() setTab("Upgrades") end)

-- ── Ouvrir / Fermer ───────────────────────────────────────────────────────────
local function ouvrirShop(data)
    refreshUI(data)
    screenGui.Enabled = true
    mainFrame.Position = UDim2.new(0.5, -210, 0.6, -280)
    local tween = TweenService:Create(mainFrame,
        TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Position = UDim2.new(0.5, -210, 0.5, -280) })
    tween:Play()
end

local function fermerShop()
    local tween = TweenService:Create(mainFrame,
        TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { Position = UDim2.new(0.5, -210, 0.6, -280) })
    tween:Play()
    tween.Completed:Connect(function()
        screenGui.Enabled = false
    end)
end

closeBtn.MouseButton1Click:Connect(fermerShop)
backdrop.MouseButton1Click:Connect(fermerShop)

-- ── Connexions RemoteEvents ───────────────────────────────────────────────────
ShopOpen.OnClientEvent:Connect(function(data)
    ouvrirShop(data)
end)

ShopRefresh.OnClientEvent:Connect(function(data)
    refreshUI(data)
end)
