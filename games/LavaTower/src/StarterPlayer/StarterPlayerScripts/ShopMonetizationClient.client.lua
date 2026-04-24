-- StarterPlayerScripts/ShopMonetizationClient.client.lua
-- Interface graphique : Cash, Lucky Blocks, Pack Demarrage, Luck
-- Le bouton BOUTIQUE est cree immediatement.
-- Le reste du shop se charge en arriere-plan une fois les RemoteEvents disponibles.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ============================================================================
-- BOUTON BOUTIQUE -- cree immediatement, sans attendre les RemoteEvents
-- ============================================================================

local hudGui = Instance.new("ScreenGui")
hudGui.Name           = "ShopMonetHudGui"
hudGui.ResetOnSpawn   = false
hudGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
hudGui.AutoLocalize   = true
hudGui.Enabled        = true
hudGui.Parent         = playerGui

-- Bouton d'ouverture (bord gauche, centre vertical)
local shopOpenBtn = Instance.new("TextButton")
shopOpenBtn.Name                   = "BoutiqueBtn"
shopOpenBtn.Size                   = UDim2.new(0, 100, 0, 100)
shopOpenBtn.AnchorPoint            = Vector2.new(0, 0.5)
shopOpenBtn.Position               = UDim2.new(0, 0, 0.5, 0)
shopOpenBtn.BackgroundTransparency = 1
shopOpenBtn.Text                   = ""
shopOpenBtn.Font                   = Enum.Font.GothamBold
shopOpenBtn.TextSize               = 14
shopOpenBtn.TextScaled             = false
shopOpenBtn.BorderSizePixel        = 0
shopOpenBtn.ZIndex                 = 10
shopOpenBtn.Parent                 = hudGui

local shopIcon = Instance.new("ImageLabel")
shopIcon.Size                   = UDim2.fromScale(1, 1)
shopIcon.BackgroundTransparency = 1
shopIcon.Image                  = "rbxassetid://108897847737947"
shopIcon.ScaleType              = Enum.ScaleType.Crop
shopIcon.ZIndex                 = 11
shopIcon.Parent                 = shopOpenBtn

local _iconCorner = Instance.new("UICorner")
_iconCorner.CornerRadius = UDim.new(0, 16)
_iconCorner.Parent = shopIcon

-- Hover : assombrir l'icône au survol
local TweenServiceEarly = game:GetService("TweenService")
shopOpenBtn.MouseEnter:Connect(function()
    TweenServiceEarly:Create(shopIcon,
        TweenInfo.new(0.1), { ImageTransparency = 0.35 }):Play()
end)
shopOpenBtn.MouseLeave:Connect(function()
    TweenServiceEarly:Create(shopIcon,
        TweenInfo.new(0.1), { ImageTransparency = 0 }):Play()
end)

-- HUD Luck (bas droite)
local hudFrame = Instance.new("Frame")
hudFrame.Name                   = "LuckHud"
hudFrame.Size                   = UDim2.new(0, 130, 0, 36)
hudFrame.AnchorPoint            = Vector2.new(1, 1)
hudFrame.Position               = UDim2.new(1, -12, 1, -12)
hudFrame.BackgroundColor3       = Color3.fromRGB(10, 10, 10)
hudFrame.BackgroundTransparency = 0.2
hudFrame.BorderSizePixel        = 0
hudFrame.Visible                = false
hudFrame.ZIndex                 = 10
hudFrame.Parent                 = hudGui

local _hc = Instance.new("UICorner")
_hc.CornerRadius = UDim.new(0, 2)
_hc.Parent = hudFrame

local _hs = Instance.new("UIStroke")
_hs.Color     = Color3.fromRGB(60, 60, 60)
_hs.Thickness = 1
_hs.Parent    = hudFrame

local hudLabel = Instance.new("TextLabel")
hudLabel.Size                   = UDim2.fromScale(1, 1)
hudLabel.BackgroundTransparency = 1
hudLabel.Text                   = "x1 - 0:00"
hudLabel.Font                   = Enum.Font.GothamBold
hudLabel.TextSize               = 14
hudLabel.TextScaled             = false
hudLabel.TextColor3             = Color3.fromRGB(220, 220, 220)
hudLabel.ZIndex                 = 11
hudLabel.Parent                 = hudFrame

-- ============================================================================
-- CHARGEMENT EN ARRIERE-PLAN
-- ============================================================================

task.spawn(function()

    -- Charger les modules
    local ok, Logger = pcall(require,
        ReplicatedStorage:WaitForChild("SharedLib"):WaitForChild("Logger"))
    if not ok then Logger = { debug=function()end, info=function()end, warn=function()end, error=function()end } end

    local Modules      = ReplicatedStorage:WaitForChild("Modules")
    local Config       = require(Modules:WaitForChild("GameConfig"))
    local FormatNumber = require(Modules:WaitForChild("FormatNumber"))

    local shopCfg = Config and Config.Shop
    if not shopCfg then
        Logger.warn("Shop", "Config.Shop manquant -- ShopMonetizationClient non initialise")
        return
    end

    -- Attendre les RemoteEvents (avec timeout)
    local ShopMonetOpen     = ReplicatedStorage:WaitForChild("ShopMonetOpen",        30)
    local ShopMonetPurchase = ReplicatedStorage:WaitForChild("ShopMonetPurchase",     30)
    local ShopMonetRefresh  = ReplicatedStorage:WaitForChild("ShopMonetRefresh",      30)
    local LuckTimerUpdate   = ReplicatedStorage:WaitForChild("LuckTimerUpdate",       30)
    local ShopMonetOpenReq  = ReplicatedStorage:WaitForChild("ShopMonetOpenRequest",  30)

    if not ShopMonetOpen or not ShopMonetPurchase or not ShopMonetRefresh then
        Logger.warn("Shop", "RemoteEvents ShopMonet introuvables apres 30s")
        return
    end

    -- ========================================================================
    -- PALETTE
    -- ========================================================================

    local C = {
        PanelBg      = Color3.fromRGB(10,  10,  10),
        CardBg       = Color3.fromRGB(20,  20,  20),
        Bordure      = Color3.fromRGB(60,  60,  60),
        Accent       = Color3.fromRGB(180, 90,  20),
        Succes       = Color3.fromRGB(80,  140, 80),
        Danger       = Color3.fromRGB(140, 50,  50),
        TextPrim     = Color3.fromRGB(220, 220, 220),
        TextSec      = Color3.fromRGB(130, 130, 130),
        Thumb        = Color3.fromRGB(40,  40,  40),
        Disabled     = Color3.fromRGB(50,  50,  50),
        Badge        = Color3.fromRGB(80,  140, 80),
        OrangeStroke = Color3.fromRGB(200, 90,  10),
    }

    local currentData = {
        coins = 0, packAchete = false, serverLuck = 1,
        luckSecondes = 0, luckPalierActuel = 0,
        revenuParSeconde = 0, slotsLibres = 0,
    }
    local activeTab = "CASH"

    -- ========================================================================
    -- UTILITAIRES UI
    -- ========================================================================

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

    local function addPadding(parent, px)
        local p = Instance.new("UIPadding")
        p.PaddingLeft   = UDim.new(0, px)
        p.PaddingRight  = UDim.new(0, px)
        p.PaddingTop    = UDim.new(0, px)
        p.PaddingBottom = UDim.new(0, px)
        p.Parent = parent
    end

    local function addHover(btn)
        local base, tw = nil, nil
        local stroke = btn:FindFirstChildWhichIsA("UIStroke")
        btn.MouseEnter:Connect(function()
            base = btn.BackgroundColor3
            local t = Color3.new(
                math.min(1, base.R + 0.08),
                math.min(1, base.G + 0.08),
                math.min(1, base.B + 0.08))
            if tw then tw:Cancel() end
            tw = TweenService:Create(btn, TweenInfo.new(0.08), { BackgroundColor3 = t })
            tw:Play()
            if stroke then TweenService:Create(stroke, TweenInfo.new(0.08), { Color = C.OrangeStroke }):Play() end
        end)
        btn.MouseLeave:Connect(function()
            if not base then return end
            local r = base; base = nil
            if tw then tw:Cancel() end
            tw = TweenService:Create(btn, TweenInfo.new(0.08), { BackgroundColor3 = r })
            tw:Play()
            if stroke then TweenService:Create(stroke, TweenInfo.new(0.08), { Color = C.Bordure }):Play() end
        end)
    end

    local function formaterChance(c)
        if c >= 1 then return tostring(math.floor(c + 0.5)) .. "%" end
        return string.format("%.1f", c) .. "%"
    end

    local function formaterTimer(s)
        s = math.max(0, math.floor(s))
        return string.format("%d:%02d", math.floor(s / 60), s % 60)
    end

    -- ========================================================================
    -- PANNEAU PRINCIPAL
    -- ========================================================================

    local screenGui = newInst("ScreenGui", {
        Name           = "ShopMonetGui",
        ResetOnSpawn   = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        AutoLocalize   = true,
        Enabled        = false,
        Parent         = playerGui,
    })

    local backdrop = newInst("TextButton", {
        Size                   = UDim2.fromScale(1, 1),
        BackgroundColor3       = Color3.new(0, 0, 0),
        BackgroundTransparency = 1,
        BorderSizePixel        = 0,
        Text                   = "",
        ZIndex                 = 1,
        Parent                 = screenGui,
    })

    local mainFrame = newInst("Frame", {
        Size                   = UDim2.new(0, 420, 0, 560),
        AnchorPoint            = Vector2.new(0.5, 0.5),
        Position               = UDim2.new(0.5, 0, 1.5, 0),
        BackgroundColor3       = C.PanelBg,
        BackgroundTransparency = 0.05,
        BorderSizePixel        = 0,
        ZIndex                 = 2,
        Parent                 = screenGui,
    })
    addCorner(mainFrame, 2)
    addStroke(mainFrame)

    local uiScale = Instance.new("UIScale")
    uiScale.Parent = mainFrame
    local function ajusterScale()
        local vp = workspace.CurrentCamera.ViewportSize
        uiScale.Scale = math.max(0.5, math.min(vp.X / 480, vp.Y / 640, 1))
    end
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(ajusterScale)
    ajusterScale()

    -- Titre
    local titleBar = newInst("Frame", {
        Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1,
        BorderSizePixel = 0, ZIndex = 3, Parent = mainFrame,
    })
    newInst("TextLabel", {
        Size = UDim2.new(1, -60, 1, 0), Position = UDim2.new(0, 16, 0, 0),
        BackgroundTransparency = 1, Text = "SHOP",
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
    addCorner(closeBtn, 2); addStroke(closeBtn); addHover(closeBtn)

    newInst("Frame", {
        Size = UDim2.new(1, -24, 0, 1), Position = UDim2.new(0, 12, 0, 52),
        BackgroundColor3 = C.Bordure, BorderSizePixel = 0, ZIndex = 3, Parent = mainFrame,
    })

    -- Barre onglets
    local tabBar = newInst("Frame", {
        Size = UDim2.new(1, -24, 0, 44), Position = UDim2.new(0, 12, 0, 60),
        BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 3, Parent = mainFrame,
    })
    newInst("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 5), Parent = tabBar,
    })

    local function creerOnglet(lbl, order)
        local b = newInst("TextButton", {
            Name = "Tab_" .. lbl, Size = UDim2.new(0.25, -4, 1, 0),
            BackgroundColor3 = Color3.fromRGB(30, 30, 30), Text = lbl,
            Font = Enum.Font.GothamBold, TextSize = 11, TextScaled = false,
            TextColor3 = C.TextSec, BorderSizePixel = 0, LayoutOrder = order,
            ZIndex = 4, Parent = tabBar,
        })
        addCorner(b, 2); addStroke(b)
        return b
    end

    local tabCash  = creerOnglet("CASH",         1)
    local tabLucky = creerOnglet("LUCKY BLOCKS", 2)
    local tabPack  = creerOnglet("PACKS",        3)
    local tabLuck  = creerOnglet("LUCK",         4)

    newInst("Frame", {
        Size = UDim2.new(1, -24, 0, 1), Position = UDim2.new(0, 12, 0, 112),
        BackgroundColor3 = C.Bordure, BorderSizePixel = 0, ZIndex = 3, Parent = mainFrame,
    })

    local contentFrame = newInst("Frame", {
        Name = "Content", Size = UDim2.new(1, -24, 1, -124),
        Position = UDim2.new(0, 12, 0, 118),
        BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 3, Parent = mainFrame,
    })

    -- ========================================================================
    -- SECTION CASH
    -- ========================================================================

    local cashFrame = newInst("Frame", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        Visible = true, ZIndex = 4, Parent = contentFrame,
    })
    local cashScroll = newInst("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        BorderSizePixel = 0, ScrollBarThickness = 4,
        ScrollBarImageColor3 = C.Accent,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ZIndex = 5, Parent = cashFrame,
    })
    newInst("UIGridLayout", {
        CellSize = UDim2.new(0, 116, 0, 200), CellPadding = UDim2.new(0, 8, 0, 8),
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder, Parent = cashScroll,
    })
    addPadding(cashScroll, 6)

    local cashCartes = {}

    for i, cfg in ipairs(shopCfg.Cash) do
        local carte = newInst("Frame", {
            BackgroundColor3 = C.CardBg, BorderSizePixel = 0,
            LayoutOrder = i, ZIndex = 6, Parent = cashScroll,
        })
        addCorner(carte, 2); addStroke(carte); addPadding(carte, 8)
        newInst("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder, FillDirection = Enum.FillDirection.Vertical,
            Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center,
            Parent = carte,
        })

        local thumb = newInst("Frame", {
            Size = UDim2.new(0, 80, 0, 80), BackgroundColor3 = C.Thumb,
            BorderSizePixel = 0, LayoutOrder = 1, ZIndex = 7, Parent = carte,
        })
        addCorner(thumb, 2); addStroke(thumb)

        newInst("TextLabel", {
            Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1,
            Text = cfg.duree or cfg.label, Font = Enum.Font.Gotham, TextSize = 12,
            TextScaled = false, TextColor3 = C.TextSec, LayoutOrder = 2, ZIndex = 7, Parent = carte,
        })

        local montantLabel = newInst("TextLabel", {
            Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1,
            Text = "...", Font = Enum.Font.GothamBold, TextSize = 13,
            TextScaled = false, TextColor3 = C.Accent, TextWrapped = true,
            LayoutOrder = 3, ZIndex = 7, Parent = carte,
        })

        local buyBtn = newInst("TextButton", {
            Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = C.Succes,
            Text = tostring(cfg.prix) .. " R", Font = Enum.Font.GothamBold,
            TextSize = 12, TextScaled = false, TextColor3 = C.TextPrim,
            BorderSizePixel = 0, LayoutOrder = 4, ZIndex = 7, Parent = carte,
        })
        addCorner(buyBtn, 2); addStroke(buyBtn); addHover(buyBtn)

        local capturedIdx = i
        buyBtn.MouseButton1Click:Connect(function()
            ShopMonetPurchase:FireServer("Cash", capturedIdx)
        end)

        cashCartes[i] = { montantLabel = montantLabel }
    end

    -- ========================================================================
    -- SECTION LUCKY BLOCKS
    -- ========================================================================

    local luckyFrame = newInst("Frame", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        Visible = false, ZIndex = 4, Parent = contentFrame,
    })
    local luckyScroll = newInst("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        BorderSizePixel = 0, ScrollBarThickness = 4,
        ScrollBarImageColor3 = C.Accent,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ZIndex = 5, Parent = luckyFrame,
    })
    newInst("UIGridLayout", {
        CellSize = UDim2.new(0, 116, 0, 260), CellPadding = UDim2.new(0, 8, 0, 8),
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder, Parent = luckyScroll,
    })
    addPadding(luckyScroll, 6)

    local luckyCartes = {}

    for i, cfg in ipairs(shopCfg.LuckyBlocks) do
        local carte = newInst("Frame", {
            BackgroundColor3 = C.CardBg, BorderSizePixel = 0,
            LayoutOrder = i, ZIndex = 6, Parent = luckyScroll,
        })
        addCorner(carte, 2); addStroke(carte); addPadding(carte, 8)
        newInst("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder, FillDirection = Enum.FillDirection.Vertical,
            Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center,
            Parent = carte,
        })

        newInst("TextLabel", {
            Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1,
            Text = cfg.nom, Font = Enum.Font.GothamBold, TextSize = 13,
            TextScaled = false, TextColor3 = C.Accent, LayoutOrder = 1, ZIndex = 7, Parent = carte,
        })

        local thumb = newInst("Frame", {
            Size = UDim2.new(0, 100, 0, 100), BackgroundColor3 = C.Thumb,
            BorderSizePixel = 0, LayoutOrder = 2, ZIndex = 7, Parent = carte,
        })
        addCorner(thumb, 2); addStroke(thumb)

        local chanceLabel = newInst("TextLabel", {
            Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1,
            Text = formaterChance(cfg.weights[1].chance),
            Font = Enum.Font.GothamBold, TextSize = 13, TextScaled = false,
            TextColor3 = C.TextPrim, LayoutOrder = 3, ZIndex = 7, Parent = carte,
        })

        -- Animation defilante des chances (2s par slot)
        local capturedWeights = cfg.weights
        task.spawn(function()
            local idx = 1
            while true do
                local w = capturedWeights[idx]
                if w and chanceLabel and chanceLabel.Parent then
                    chanceLabel.Text = formaterChance(w.chance)
                end
                idx = idx + 1
                if idx > #capturedWeights then idx = 1 end
                task.wait(2)
            end
        end)

        local buyBtn = newInst("TextButton", {
            Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = C.Succes,
            Text = tostring(cfg.prix) .. " R", Font = Enum.Font.GothamBold,
            TextSize = 12, TextScaled = false, TextColor3 = C.TextPrim,
            BorderSizePixel = 0, LayoutOrder = 4, ZIndex = 7, Parent = carte,
        })
        addCorner(buyBtn, 2); addStroke(buyBtn); addHover(buyBtn)

        local capturedIdx = i
        buyBtn.MouseButton1Click:Connect(function()
            ShopMonetPurchase:FireServer("LuckyBlock", capturedIdx)
        end)

        luckyCartes[i] = { buyBtn = buyBtn }
    end

    -- ========================================================================
    -- SECTION PACK
    -- ========================================================================

    local packFrame = newInst("Frame", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        Visible = false, ZIndex = 4, Parent = contentFrame,
    })

    local packScroll = newInst("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        BorderSizePixel = 0, ScrollBarThickness = 4,
        ScrollBarImageColor3 = C.Accent,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ZIndex = 5, Parent = packFrame,
    })
    newInst("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder, FillDirection = Enum.FillDirection.Vertical,
        Padding = UDim.new(0, 12), HorizontalAlignment = Enum.HorizontalAlignment.Center,
        Parent = packScroll,
    })
    addPadding(packScroll, 8)

    newInst("TextLabel", {
        Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1,
        Text = "STARTER PACK", Font = Enum.Font.GothamBold, TextSize = 16,
        TextScaled = false, TextColor3 = C.Accent,
        TextXAlignment = Enum.TextXAlignment.Center,
        LayoutOrder = 1, ZIndex = 6, Parent = packScroll,
    })

    local thumbRow = newInst("Frame", {
        Size = UDim2.new(1, 0, 0, 90), BackgroundTransparency = 1,
        BorderSizePixel = 0, LayoutOrder = 2, ZIndex = 6, Parent = packScroll,
    })
    newInst("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10),
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder, Parent = thumbRow,
    })
    for ti = 1, 3 do
        local t = newInst("Frame", {
            Size = UDim2.new(0, 80, 0, 80), BackgroundColor3 = C.Thumb,
            BorderSizePixel = 0, LayoutOrder = ti, ZIndex = 7, Parent = thumbRow,
        })
        addCorner(t, 2); addStroke(t)
    end

    newInst("TextLabel", {
        Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1,
        Text = "2 exclusive Brainrots + " .. FormatNumber.format(shopCfg.PackDemarrage.Cash) .. " coins",
        Font = Enum.Font.Gotham, TextSize = 13, TextScaled = false,
        TextColor3 = C.TextSec, TextXAlignment = Enum.TextXAlignment.Center,
        TextWrapped = true, LayoutOrder = 3, ZIndex = 6, Parent = packScroll,
    })

    local packBuyBtn = newInst("TextButton", {
        Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = C.Succes,
        Text = tostring(shopCfg.PackDemarrage.Prix) .. " Robux",
        Font = Enum.Font.GothamBold, TextSize = 15, TextScaled = false,
        TextColor3 = C.TextPrim, BorderSizePixel = 0, LayoutOrder = 4, ZIndex = 6, Parent = packScroll,
    })
    addCorner(packBuyBtn, 2); addStroke(packBuyBtn); addHover(packBuyBtn)

    packBuyBtn.MouseButton1Click:Connect(function()
        if currentData.packAchete then return end
        ShopMonetPurchase:FireServer("Pack")
    end)

    -- ── Séparateur ──
    newInst("Frame", {
        Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = C.Bordure,
        BorderSizePixel = 0, LayoutOrder = 5, ZIndex = 6, Parent = packScroll,
    })

    -- ── Pack VIP ──
    newInst("TextLabel", {
        Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1,
        Text = "VIP PACK", Font = Enum.Font.GothamBold, TextSize = 16, TextScaled = false,
        TextColor3 = Color3.fromRGB(255, 215, 0), TextXAlignment = Enum.TextXAlignment.Center,
        LayoutOrder = 6, ZIndex = 6, Parent = packScroll,
    })

    local vipThumbRow = newInst("Frame", {
        Size = UDim2.new(1, 0, 0, 72), BackgroundTransparency = 1,
        BorderSizePixel = 0, LayoutOrder = 7, ZIndex = 6, Parent = packScroll,
    })
    newInst("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8),
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder, Parent = vipThumbRow,
    })
    for ti = 1, 3 do
        local t = newInst("Frame", {
            Size = UDim2.new(0, 64, 0, 64), BackgroundColor3 = Color3.fromRGB(50, 40, 5),
            BorderSizePixel = 0, LayoutOrder = ti, ZIndex = 7, Parent = vipThumbRow,
        })
        addCorner(t, 2)
        local s = Instance.new("UIStroke"); s.Color = Color3.fromRGB(200, 160, 20); s.Thickness = 1; s.Parent = t
    end

    newInst("TextLabel", {
        Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1,
        Text = "VIP Tower Access · x2 Luck 15min · " .. FormatNumber.format(shopCfg.PackVIP.Cash) .. " coins",
        Font = Enum.Font.Gotham, TextSize = 12, TextScaled = false,
        TextColor3 = C.TextSec, TextXAlignment = Enum.TextXAlignment.Center,
        TextWrapped = true, LayoutOrder = 8, ZIndex = 6, Parent = packScroll,
    })

    local vipBuyBtn = newInst("TextButton", {
        Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = Color3.fromRGB(140, 110, 10),
        Text = tostring(shopCfg.PackVIP.Prix) .. " Robux",
        Font = Enum.Font.GothamBold, TextSize = 15, TextScaled = false,
        TextColor3 = C.TextPrim, BorderSizePixel = 0, LayoutOrder = 9, ZIndex = 6, Parent = packScroll,
    })
    addCorner(vipBuyBtn, 2)
    do local s = Instance.new("UIStroke"); s.Color = Color3.fromRGB(200, 160, 20); s.Thickness = 1; s.Parent = vipBuyBtn end
    addHover(vipBuyBtn)

    vipBuyBtn.MouseButton1Click:Connect(function()
        if currentData.hasVIP then return end
        ShopMonetPurchase:FireServer("PackVIP")
    end)

    -- ========================================================================
    -- SECTION LUCK
    -- ========================================================================

    local luckFrame = newInst("Frame", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        Visible = false, ZIndex = 4, Parent = contentFrame,
    })

    local luckHeader = newInst("Frame", {
        Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = C.CardBg,
        BorderSizePixel = 0, ZIndex = 5, Parent = luckFrame,
    })
    addCorner(luckHeader, 2); addStroke(luckHeader)

    local luckHeaderLabel = newInst("TextLabel", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        Text = "Server Luck: x1", Font = Enum.Font.GothamBold, TextSize = 15,
        TextScaled = false, TextColor3 = C.Accent, ZIndex = 6, Parent = luckHeader,
    })

    -- Carte unique d'upgrade — se met à jour en fonction du palier actuel
    local luckCard = newInst("Frame", {
        Size = UDim2.new(1, 0, 0, 80), Position = UDim2.new(0, 0, 0, 52),
        BackgroundColor3 = C.CardBg, BorderSizePixel = 0, ZIndex = 5, Parent = luckFrame,
    })
    addCorner(luckCard, 2); addStroke(luckCard); addPadding(luckCard, 10)

    local luckCardThumb = newInst("Frame", {
        Size = UDim2.new(0, 60, 0, 60), Position = UDim2.new(0, 0, 0.5, -30),
        BackgroundColor3 = C.Thumb, BorderSizePixel = 0, ZIndex = 6, Parent = luckCard,
    })
    addCorner(luckCardThumb, 2); addStroke(luckCardThumb)

    local luckUpgradeLabel = newInst("TextLabel", {
        Size = UDim2.new(0, 160, 0, 28), Position = UDim2.new(0, 76, 0.5, -14),
        BackgroundTransparency = 1, Text = "x2 Luck",
        Font = Enum.Font.GothamBold, TextSize = 15, TextScaled = false,
        TextColor3 = C.TextPrim, TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 6, Parent = luckCard,
    })

    local luckUpgradeBtn = newInst("TextButton", {
        Size = UDim2.new(0, 90, 0, 44), Position = UDim2.new(1, -90, 0.5, -22),
        BackgroundColor3 = C.Succes, Text = "49 R",
        Font = Enum.Font.GothamBold, TextSize = 12, TextScaled = false,
        TextColor3 = C.TextPrim, BorderSizePixel = 0, ZIndex = 6, Parent = luckCard,
    })
    addCorner(luckUpgradeBtn, 2); addStroke(luckUpgradeBtn); addHover(luckUpgradeBtn)

    luckUpgradeBtn.MouseButton1Click:Connect(function()
        local palierActuel = currentData.luckPalierActuel or 0
        local nextPalier   = palierActuel + 1
        if nextPalier > #shopCfg.Luck.Paliers then return end
        ShopMonetPurchase:FireServer("Luck", nextPalier)
    end)

    local function mettreAJourCarteLuck(palierActuel)
        local nextPalier = palierActuel + 1
        if nextPalier > #shopCfg.Luck.Paliers then
            luckUpgradeLabel.Text        = "MAX Luck"
            luckUpgradeBtn.Text          = "MAX"
            luckUpgradeBtn.BackgroundColor3 = C.Disabled
        else
            luckUpgradeLabel.Text        = "x" .. tostring(shopCfg.Luck.Paliers[nextPalier]) .. " Luck"
            luckUpgradeBtn.Text          = tostring(shopCfg.Luck.Prix[nextPalier] or 0) .. " R"
            luckUpgradeBtn.BackgroundColor3 = C.Succes
        end
    end

    -- ========================================================================
    -- REFRESH UI
    -- ========================================================================

    local function refreshUI(data)
        if not data then return end
        currentData = data

        for i, cfg in ipairs(shopCfg.Cash) do
            local c = cashCartes[i]
            if c then
                local montant = math.max(cfg.minCash or 0, math.floor((data.revenuParSeconde or 0) * cfg.multiplicateur))
                c.montantLabel.Text = FormatNumber.format(montant) .. " coins"
            end
        end

        local carryLibres = data.carryLibres or 0
        for i, c in ipairs(luckyCartes) do
            if c and c.buyBtn then
                if carryLibres <= 0 then
                    c.buyBtn.BackgroundColor3 = C.Danger
                    c.buyBtn.Text = "Inventory full"
                else
                    local lb = shopCfg.LuckyBlocks[i]
                    c.buyBtn.BackgroundColor3 = C.Succes
                    c.buyBtn.Text = lb and (tostring(lb.prix) .. " R") or "Acheter"
                end
            end
        end

        local packNbItems = data.packNbItems or 2
        if data.packAchete then
            packBuyBtn.BackgroundColor3 = C.Disabled
            packBuyBtn.Text = "Already purchased"
        elseif carryLibres < packNbItems then
            packBuyBtn.BackgroundColor3 = C.Danger
            packBuyBtn.Text = "Inventory full"
        else
            packBuyBtn.BackgroundColor3 = C.Succes
            packBuyBtn.Text = tostring(shopCfg.PackDemarrage.Prix) .. " Robux"
        end

        if data.hasVIP then
            vipBuyBtn.BackgroundColor3 = C.Disabled
            vipBuyBtn.Text = "VIP already purchased"
        else
            vipBuyBtn.BackgroundColor3 = Color3.fromRGB(140, 110, 10)
            vipBuyBtn.Text = tostring(shopCfg.PackVIP.Prix) .. " Robux"
        end

        local palierActuel = data.luckPalierActuel or 0
        local luck = data.serverLuck or 1
        luckHeaderLabel.Text = "Server Luck: x" .. tostring(luck)
        mettreAJourCarteLuck(palierActuel)
    end

    -- ========================================================================
    -- GESTION ONGLETS + OUVERTURE/FERMETURE
    -- ========================================================================

    local function setTab(tab)
        activeTab = tab
        cashFrame.Visible  = (tab == "CASH")
        luckyFrame.Visible = (tab == "LUCKY BLOCKS")
        packFrame.Visible  = (tab == "PACKS")
        luckFrame.Visible  = (tab == "LUCK")
        local tabs = {
            { btn = tabCash,  nom = "CASH"         },
            { btn = tabLucky, nom = "LUCKY BLOCKS"  },
            { btn = tabPack,  nom = "PACKS"         },
            { btn = tabLuck,  nom = "LUCK"          },
        }
        for _, t in ipairs(tabs) do
            local actif = (t.nom == tab)
            t.btn.BackgroundColor3 = actif and Color3.fromRGB(180, 90, 20) or Color3.fromRGB(30, 30, 30)
            t.btn.TextColor3       = actif and Color3.fromRGB(220, 220, 220) or Color3.fromRGB(130, 130, 130)
        end
    end

    tabCash.MouseButton1Click:Connect(function()  setTab("CASH")         end)
    tabLucky.MouseButton1Click:Connect(function() setTab("LUCKY BLOCKS")  end)
    tabPack.MouseButton1Click:Connect(function()  setTab("PACKS")         end)
    tabLuck.MouseButton1Click:Connect(function()  setTab("LUCK")          end)

    local function ouvrirShop(data)
        local tpGui = playerGui:FindFirstChild("TeleportMenuGui")
        if tpGui then tpGui.Enabled = false end
        refreshUI(data)
        setTab("CASH")
        screenGui.Enabled  = true
        mainFrame.Position = UDim2.new(0.5, 0, 1.6, 0)
        TweenService:Create(mainFrame,
            TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            { Position = UDim2.new(0.5, 0, 0.5, 0) }):Play()
    end

    local function fermerShop()
        local tw = TweenService:Create(mainFrame,
            TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            { Position = UDim2.new(0.5, 0, 1.6, 0) })
        tw:Play()
        tw.Completed:Connect(function() screenGui.Enabled = false end)
    end

    closeBtn.MouseButton1Click:Connect(fermerShop)
    backdrop.MouseButton1Click:Connect(fermerShop)

    -- Bouton BOUTIQUE (cree plus haut) : connecter maintenant qu'on a tout
    shopOpenBtn.MouseButton1Click:Connect(function()
        -- Reset l'assombrissement du hover immédiatement au clic
        local icon = shopOpenBtn:FindFirstChildWhichIsA("ImageLabel")
        if icon then icon.ImageTransparency = 0 end
        if screenGui.Enabled then
            fermerShop()
        elseif ShopMonetOpenReq then
            ShopMonetOpenReq:FireServer()
        end
    end)

    -- ========================================================================
    -- CONNEXIONS REMOTEEVENTS
    -- ========================================================================

    ShopMonetOpen.OnClientEvent:Connect(function(data)
        ouvrirShop(data)
    end)

    ShopMonetRefresh.OnClientEvent:Connect(function(data)
        refreshUI(data)
    end)

    if LuckTimerUpdate then
        LuckTimerUpdate.OnClientEvent:Connect(function(luck, secondes, palierActuel)
            if luck and luck > 1 then
                hudFrame.Visible = true
                hudLabel.Text    = "x" .. tostring(luck) .. " - " .. formaterTimer(secondes)
            else
                hudFrame.Visible = false
            end
            if screenGui.Enabled and activeTab == "LUCK" then
                luckHeaderLabel.Text = "Server Luck: x" .. tostring(luck or 1)
                mettreAJourCarteLuck(palierActuel or 0)
            end
        end)
    end


    -- ── Masquer bouton + fermer shop en tour ─────────────────────────────────
    local function masquerShop()
        shopOpenBtn.Visible = false
        if screenGui.Enabled then fermerShop() end
    end
    local function afficherShop()
        shopOpenBtn.Visible = true
    end

    local TowerEnteredShop = ReplicatedStorage:WaitForChild("TowerEntered", 15)
    local TowerExitedShop  = ReplicatedStorage:WaitForChild("TowerExited",  15)
    if TowerEnteredShop then TowerEnteredShop.OnClientEvent:Connect(masquerShop) end
    if TowerExitedShop  then TowerExitedShop.OnClientEvent:Connect(afficherShop)  end
    if player:GetAttribute("InTower") then masquerShop() end
    player:GetAttributeChangedSignal("InTower"):Connect(function()
        if player:GetAttribute("InTower") then masquerShop() else afficherShop() end
    end)
    -- ─────────────────────────────────────────────────────────────────────────

    Logger.info("Shop", "ShopMonetizationClient charge")

end) -- fin task.spawn
