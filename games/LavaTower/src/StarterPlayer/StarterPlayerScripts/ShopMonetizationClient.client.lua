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
hudFrame.Size                   = UDim2.new(0, 150, 0, 44)
hudFrame.AnchorPoint            = Vector2.new(1, 1)
hudFrame.Position               = UDim2.new(1, -12, 1, -12)
hudFrame.BackgroundTransparency = 1
hudFrame.BorderSizePixel        = 0
hudFrame.Visible                = false
hudFrame.ZIndex                 = 10
hudFrame.Parent                 = hudGui

local hudThumb = Instance.new("ImageLabel")
hudThumb.Name                   = "LuckThumb"
hudThumb.Size                   = UDim2.new(0, 40, 0, 40)
hudThumb.Position               = UDim2.new(0, 0, 0.5, -20)
hudThumb.BackgroundTransparency = 1
hudThumb.Image                  = ""
hudThumb.ScaleType              = Enum.ScaleType.Fit
hudThumb.ZIndex                 = 11
hudThumb.Parent                 = hudFrame
local _htc = Instance.new("UICorner")
_htc.CornerRadius = UDim.new(0, 8)
_htc.Parent = hudThumb

local hudLabel = Instance.new("TextLabel")
hudLabel.Size                   = UDim2.new(1, -48, 1, 0)
hudLabel.Position               = UDim2.new(0, 48, 0, 0)
hudLabel.BackgroundTransparency = 1
hudLabel.Text                   = "0:00"
hudLabel.Font                   = Enum.Font.GothamBold
hudLabel.TextSize               = 22
hudLabel.TextScaled             = false
hudLabel.TextColor3             = Color3.fromRGB(255, 255, 255)
hudLabel.TextXAlignment         = Enum.TextXAlignment.Left
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
        PanelBg      = Color3.fromRGB(12,  10,  8),
        CardBg       = Color3.fromRGB(22,  20,  18),
        Bordure      = Color3.fromRGB(60,  60,  60),
        Accent       = Color3.fromRGB(200, 100, 20),
        AccentStr    = Color3.fromRGB(255, 150, 40),
        Succes       = Color3.fromRGB(70,  150, 80),
        Danger       = Color3.fromRGB(140, 50,  50),
        TextPrim     = Color3.fromRGB(230, 230, 230),
        TextSec      = Color3.fromRGB(130, 130, 130),
        Thumb        = Color3.fromRGB(40,  40,  40),
        Disabled     = Color3.fromRGB(50,  50,  50),
        Badge        = Color3.fromRGB(80,  140, 80),
        OrangeStroke = Color3.fromRGB(200, 90,  10),
    }

    -- Couleurs CASH : top = highlight (+30 luminosité), bot = couleur base — gradient subtil et propre
    local CASH_STYLES = {
        { top = Color3.fromRGB(90,  155, 255), bot = Color3.fromRGB(55,  115, 230), str = Color3.fromRGB(140, 195, 255) },
        { top = Color3.fromRGB(175, 110, 255), bot = Color3.fromRGB(135, 68,  220), str = Color3.fromRGB(215, 160, 255) },
        { top = Color3.fromRGB(255, 205, 65),  bot = Color3.fromRGB(220, 165, 20),  str = Color3.fromRGB(255, 230, 110) },
    }

    local function addGradientV(parent, c0, c1)
        local g = Instance.new("UIGradient")
        g.Color    = ColorSequence.new(c0, c1)
        g.Rotation = 90
        g.Parent   = parent
        return g
    end

    -- Pulse discret sur le stroke du bouton (n'interfère pas avec les clics)
    local function addPulseBtn(btn)
        local sk = btn:FindFirstChildWhichIsA("UIStroke")
        if not sk then return end
        TweenService:Create(sk,
            TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { Thickness = 3 }):Play()
    end

    local currentData = {
        coins = 0, packAchete = false, serverLuck = 1,
        luckSecondes = 0, luckPalierActuel = 0,
        revenuParSeconde = 0, slotsLibres = 0,
    }
    local activeTab = "CASH"

    local LUCK_THUMBNAILS = {
        [2]  = "rbxassetid://111745539282701",
        [4]  = "rbxassetid://137698896976042",
        [8]  = "rbxassetid://130005113801836",
        [10] = "rbxassetid://107848322283156",
        [15] = "rbxassetid://104594587868527",
        [20] = "rbxassetid://131234471865617",
        [25] = "rbxassetid://115112170622704",
        [30] = "rbxassetid://99957610639343",
    }

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
        Size             = UDim2.new(0, 420, 0, 560),
        AnchorPoint      = Vector2.new(0.5, 0.5),
        Position         = UDim2.new(0.5, 0, 1.5, 0),
        BackgroundColor3 = C.PanelBg,
        BorderSizePixel  = 0,
        ZIndex           = 2,
        Parent           = screenGui,
    })
    addCorner(mainFrame, 4)
    do local s = Instance.new("UIStroke"); s.Color = Color3.fromRGB(140, 195, 255); s.Thickness = 2; s.Parent = mainFrame end

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
        Size             = UDim2.new(1, 0, 0, 52),
        BackgroundColor3 = C.Accent,
        BorderSizePixel  = 0,
        ZIndex           = 3,
        Parent           = mainFrame,
    })
    addCorner(titleBar, 4)
    addGradientV(titleBar, Color3.fromRGB(60, 140, 255), Color3.fromRGB(30, 80, 200))
    newInst("TextLabel", {
        Size = UDim2.new(1, -60, 1, 0), Position = UDim2.new(0, 16, 0, 0),
        BackgroundTransparency = 1, Text = "SHOP",
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
    -- UIListLayout vertical : 3 cartes pleine largeur → plus d'espace vide
    local cashScroll = newInst("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        BorderSizePixel = 0, ScrollBarThickness = 4,
        ScrollBarImageColor3 = C.Accent,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ZIndex = 5, Parent = cashFrame,
    })
    newInst("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder, FillDirection = Enum.FillDirection.Vertical,
        Padding = UDim.new(0, 10), Parent = cashScroll,
    })
    addPadding(cashScroll, 8)

    local cashCartes = {}

    for i, cfg in ipairs(shopCfg.Cash) do
        local style = CASH_STYLES[i] or CASH_STYLES[1]

        -- Carte horizontale pleine largeur
        local carte = newInst("Frame", {
            Size             = UDim2.new(1, -16, 0, 110),
            BackgroundColor3 = style.bot,
            BorderSizePixel  = 0,
            LayoutOrder      = i,
            ZIndex           = 6,
            Parent           = cashScroll,
        })
        addCorner(carte, 6)
        do local sk = Instance.new("UIStroke"); sk.Color = style.str; sk.Thickness = 1.5; sk.Parent = carte end
        addGradientV(carte, style.top, style.bot)

        -- Thumbnail image (gauche) — utilise l'asset de la config si disponible
        local iconFrame = newInst("Frame", {
            Size             = UDim2.new(0, 72, 0, 72),
            AnchorPoint      = Vector2.new(0, 0.5),
            Position         = UDim2.new(0, 12, 0.5, 0),
            BackgroundColor3 = style.bot,
            BorderSizePixel  = 0,
            ZIndex           = 7,
            ClipsDescendants = true,
            Parent           = carte,
        })
        addCorner(iconFrame, 8)
        do local sk = Instance.new("UIStroke"); sk.Color = style.str; sk.Thickness = 1.5; sk.Parent = iconFrame end
        if cfg.image and cfg.image ~= "" then
            newInst("ImageLabel", {
                Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
                Image = cfg.image, ScaleType = Enum.ScaleType.Fit,
                ZIndex = 8, Parent = iconFrame,
            })
        end

        -- Texte durée (milieu)
        newInst("TextLabel", {
            Size             = UDim2.new(0, 140, 0, 24),
            AnchorPoint      = Vector2.new(0, 0.5),
            Position         = UDim2.new(0, 96, 0.5, -16),
            BackgroundTransparency = 1,
            Text             = cfg.duree or cfg.label,
            Font             = Enum.Font.GothamBold,
            TextSize         = 14,
            TextScaled       = false,
            TextColor3       = Color3.fromRGB(240, 240, 240),
            TextXAlignment   = Enum.TextXAlignment.Left,
            ZIndex           = 7,
            Parent           = carte,
        })

        -- Montant coins (milieu, dessous)
        local montantLabel = newInst("TextLabel", {
            Size             = UDim2.new(0, 140, 0, 22),
            AnchorPoint      = Vector2.new(0, 0.5),
            Position         = UDim2.new(0, 96, 0.5, 12),
            BackgroundTransparency = 1,
            Text             = "...",
            Font             = Enum.Font.GothamBold,
            TextSize         = 12,
            TextScaled       = false,
            TextColor3       = Color3.fromRGB(255, 210, 70),
            TextXAlignment   = Enum.TextXAlignment.Left,
            ZIndex           = 7,
            Parent           = carte,
        })

        -- Bouton Robux (droite)
        local buyBtn = newInst("TextButton", {
            Size             = UDim2.new(0, 100, 0, 46),
            AnchorPoint      = Vector2.new(1, 0.5),
            Position         = UDim2.new(1, -12, 0.5, 0),
            BackgroundColor3 = C.Succes,
            Text             = tostring(cfg.prix) .. " R",
            Font             = Enum.Font.GothamBold,
            TextSize         = 13,
            TextScaled       = false,
            TextColor3       = Color3.fromRGB(255, 255, 255),
            BorderSizePixel  = 0,
            ZIndex           = 7,
            Parent           = carte,
        })
        addCorner(buyBtn, 8)
        do local sk = Instance.new("UIStroke"); sk.Color = Color3.fromRGB(100, 200, 110); sk.Thickness = 1.5; sk.Parent = buyBtn end
        addHover(buyBtn)
        addPulseBtn(buyBtn)
        buyBtn:SetAttribute("NoSound", true)

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

    -- Resout un chemin "Service.Dossier.Sous" en instance (cote client)
    local function resoudreDossierClient(chemin)
        local parties = {}
        for p in chemin:gmatch("[^%.]+") do table.insert(parties, p) end
        if #parties == 0 then return nil end
        local ok, svc = pcall(function() return game:GetService(parties[1]) end)
        if not ok or not svc then return nil end
        local noeud = svc
        for i2 = 2, #parties do
            if not noeud then return nil end
            noeud = noeud:FindFirstChild(parties[i2])
        end
        return noeud
    end

    -- Cree un ViewportFrame 3D pour la bande defilante des Lucky Blocks
    local function creerVpBande(parent, modeleSource)
        local vp = newInst("ViewportFrame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Color3.fromRGB(18, 18, 28),
            BackgroundTransparency = 0,
            BorderSizePixel = 0,
            ZIndex = 10,
            Parent = parent,
        })
        addCorner(vp, 4)
        if modeleSource then
            pcall(function()
                local clone = modeleSource:Clone()
                clone.Parent = vp
                local cf, size = clone:GetBoundingBox()
                local maxSz = math.max(size.X, size.Y, size.Z)
                if maxSz < 0.1 then maxSz = 4 end
                local dist = maxSz * 1.1
                local cam = Instance.new("Camera")
                cam.CFrame = CFrame.new(
                    cf.Position + Vector3.new(0, size.Y * 0.2, dist),
                    cf.Position
                )
                vp.CurrentCamera = cam
                cam.Parent = vp
            end)
        end
        return vp
    end

    for i, cfg in ipairs(shopCfg.LuckyBlocks) do
        local carte = newInst("Frame", {
            BackgroundColor3 = Color3.fromRGB(15, 8, 40), BorderSizePixel = 0,
            LayoutOrder = i, ZIndex = 6, Parent = luckyScroll,
        })
        addCorner(carte, 4)
        do local sk = Instance.new("UIStroke"); sk.Color = Color3.fromRGB(175, 110, 255); sk.Thickness = 1.5; sk.Parent = carte end
        addGradientV(carte, Color3.fromRGB(175, 110, 255), Color3.fromRGB(135, 68, 220))
        addPadding(carte, 8)
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
        addCorner(thumb, 8); addStroke(thumb)
        if cfg.image then
            local img = newInst("ImageLabel", {
                Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
                Image = cfg.image, ScaleType = Enum.ScaleType.Fit,
                ZIndex = 8, Parent = thumb,
            })
            addCorner(img, 8)
        end

        -- Bande defilante : ViewportFrames 3D + pourcentages
        local BAND_H   = 58
        local ITEM_W   = 52
        local ITEM_GAP = 4
        local VP_H     = 42

        -- Collecter les brainrots du tier avec leur chance individuelle
        local bandItems = {}
        local tierFolder = resoudreDossierClient(cfg.folder)
        if tierFolder then
            for _, w in ipairs(cfg.weights) do
                local sous = tierFolder:FindFirstChild(w.label)
                if sous then
                    local modeles = {}
                    for _, m in ipairs(sous:GetChildren()) do
                        if (m:IsA("Model") or m:IsA("BasePart")) and m.Name ~= "Lucky Block" then
                            table.insert(modeles, m)
                        end
                    end
                    if #modeles > 0 then
                        local chanceIndiv = w.chance / #modeles
                        for _, m in ipairs(modeles) do
                            table.insert(bandItems, { model = m, chance = chanceIndiv })
                        end
                    end
                end
            end
        end

        local bandContainer = newInst("Frame", {
            Size = UDim2.new(1, 0, 0, BAND_H),
            BackgroundTransparency = 1,
            ClipsDescendants = true,
            LayoutOrder = 3, ZIndex = 7, Parent = carte,
        })

        if #bandItems == 0 then
            -- Fallback texte si le dossier n'est pas encore peuple
            newInst("TextLabel", {
                Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
                Text = formaterChance(cfg.weights[1].chance),
                Font = Enum.Font.GothamBold, TextSize = 13, TextScaled = false,
                TextColor3 = C.TextPrim, ZIndex = 8, Parent = bandContainer,
            })
        else
            local singleW = #bandItems * (ITEM_W + ITEM_GAP)

            -- Frame interieur mobile (contenu double pour boucle seamless)
            local inner = newInst("Frame", {
                Size = UDim2.new(0, singleW * 2, 1, 0),
                Position = UDim2.fromOffset(0, 0),
                BackgroundTransparency = 1,
                ZIndex = 8, Parent = bandContainer,
            })

            for pass = 0, 1 do
                for j, item in ipairs(bandItems) do
                    local xOff = (pass * #bandItems + (j - 1)) * (ITEM_W + ITEM_GAP)
                    local itemF = newInst("Frame", {
                        Size = UDim2.new(0, ITEM_W, 1, 0),
                        Position = UDim2.fromOffset(xOff, 0),
                        BackgroundTransparency = 1,
                        ZIndex = 9, Parent = inner,
                    })
                    local vpHolder = newInst("Frame", {
                        Size = UDim2.new(0, ITEM_W, 0, VP_H),
                        Position = UDim2.fromOffset(0, 0),
                        BackgroundTransparency = 1,
                        ZIndex = 9, Parent = itemF,
                    })
                    creerVpBande(vpHolder, item.model)
                    newInst("TextLabel", {
                        Size = UDim2.new(1, 0, 0, BAND_H - VP_H),
                        Position = UDim2.fromOffset(0, VP_H),
                        BackgroundTransparency = 1,
                        Text = formaterChance(item.chance),
                        Font = Enum.Font.GothamBold, TextSize = 10, TextScaled = false,
                        TextColor3 = C.TextPrim,
                        TextXAlignment = Enum.TextXAlignment.Center,
                        ZIndex = 10, Parent = itemF,
                    })
                end
            end

            -- Animation de defilement continu
            local capturedInner  = inner
            local capturedSingleW = singleW
            task.spawn(function()
                local pos = 0
                while capturedInner.Parent do
                    local dt = task.wait()
                    pos = pos + 35 * dt  -- 35 px/s
                    if pos >= capturedSingleW then pos = pos - capturedSingleW end
                    capturedInner.Position = UDim2.fromOffset(-math.floor(pos), 0)
                end
            end)
        end

        local buyBtn = newInst("TextButton", {
            Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = C.Succes,
            Text = tostring(cfg.prix) .. " R", Font = Enum.Font.GothamBold,
            TextSize = 12, TextScaled = false, TextColor3 = C.TextPrim,
            BorderSizePixel = 0, LayoutOrder = 4, ZIndex = 7, Parent = carte,
        })
        addCorner(buyBtn, 2); addStroke(buyBtn); addHover(buyBtn)
        buyBtn:SetAttribute("NoSound", true)

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
    local STARTER_THUMBS    = { [3] = "rbxassetid://88226292288257" }
    local STARTER_BRAINROTS = { [1] = "Nuclearo Dinossauro", [2] = "67" }

    local function trouverBrainrot(nom)
        local brainrotsFolder = ReplicatedStorage:FindFirstChild("Brainrots")
        if not brainrotsFolder then return nil end
        for _, dossierRarete in ipairs(brainrotsFolder:GetChildren()) do
            if dossierRarete:IsA("Folder") then
                for _, enfant in ipairs(dossierRarete:GetChildren()) do
                    if enfant:IsA("Folder") then
                        local m = enfant:FindFirstChild(nom)
                        if m then return m end
                    elseif enfant:IsA("Model") and enfant.Name == nom then
                        return enfant
                    end
                end
            end
        end
        return nil
    end

    local function creerViewportThumb(parent, modeleSource)
        local vp = newInst("ViewportFrame", {
            Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(25, 25, 25),
            BackgroundTransparency = 0, BorderSizePixel = 0, ZIndex = 8, Parent = parent,
        })
        addCorner(vp, 8)
        if modeleSource then
            pcall(function()
                local clone = modeleSource:Clone()
                clone.Parent = vp
                local cf, size = clone:GetBoundingBox()
                local maxSize = math.max(size.X, size.Y, size.Z)
                if maxSize < 0.1 then maxSize = 4 end
                local dist = maxSize * 0.7
                local cam = Instance.new("Camera")
                cam.CFrame = CFrame.new(
                    cf.Position + Vector3.new(dist, size.Y * 0.25, dist),
                    cf.Position
                )
                vp.CurrentCamera = cam
                cam.Parent = vp
            end)
        end
        return vp
    end

    for ti = 1, 3 do
        local t = newInst("Frame", {
            Size = UDim2.new(0, 80, 0, 80), BackgroundColor3 = C.Thumb,
            BorderSizePixel = 0, LayoutOrder = ti, ZIndex = 7, Parent = thumbRow,
            ClipsDescendants = true,
        })
        addCorner(t, 8); addStroke(t)
        if STARTER_THUMBS[ti] then
            local img = newInst("ImageLabel", {
                Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
                Image = STARTER_THUMBS[ti], ScaleType = Enum.ScaleType.Fit,
                ZIndex = 8, Parent = t,
            })
            addCorner(img, 8)
        elseif STARTER_BRAINROTS[ti] then
            creerViewportThumb(t, trouverBrainrot(STARTER_BRAINROTS[ti]))
        end
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
    packBuyBtn:SetAttribute("NoSound", true)

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
        Size = UDim2.new(1, 0, 0, 90), BackgroundTransparency = 1,
        BorderSizePixel = 0, LayoutOrder = 7, ZIndex = 6, Parent = packScroll,
    })
    newInst("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8),
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder, Parent = vipThumbRow,
    })
    local VIP_THUMBS = { [1] = "rbxassetid://130750210611017", [2] = "rbxassetid://111745539282701", [3] = "rbxassetid://88226292288257" }
    for ti = 1, 3 do
        local t = newInst("Frame", {
            Size = UDim2.new(0, 80, 0, 80), BackgroundColor3 = Color3.fromRGB(50, 40, 5),
            BorderSizePixel = 0, LayoutOrder = ti, ZIndex = 7, Parent = vipThumbRow,
            ClipsDescendants = true,
        })
        addCorner(t, 8)
        local s = Instance.new("UIStroke"); s.Color = Color3.fromRGB(200, 160, 20); s.Thickness = 1; s.Parent = t
        if VIP_THUMBS[ti] then
            local img = newInst("ImageLabel", {
                Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
                Image = VIP_THUMBS[ti], ScaleType = Enum.ScaleType.Fit,
                ZIndex = 8, Parent = t,
            })
            addCorner(img, 8)
        end
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
    vipBuyBtn:SetAttribute("NoSound", true)

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

    -- Badge Server Luck (visible, fond orange)
    local luckHeader = newInst("Frame", {
        Size             = UDim2.new(1, 0, 0, 48),
        BackgroundColor3 = C.Accent,
        BorderSizePixel  = 0,
        ZIndex           = 5,
        Parent           = luckFrame,
    })
    addCorner(luckHeader, 4)
    addGradientV(luckHeader, Color3.fromRGB(200, 100, 10), Color3.fromRGB(130, 60, 5))

    local luckHeaderLabel = newInst("TextLabel", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        Text = "Server Luck: x1", Font = Enum.Font.GothamBold, TextSize = 16,
        TextScaled = false, TextColor3 = Color3.fromRGB(255, 255, 255),
        TextStrokeColor3 = Color3.fromRGB(80, 30, 0), TextStrokeTransparency = 0.5,
        ZIndex = 6, Parent = luckHeader,
    })

    -- Carte unique Luck — fond vert citron
    local luckCard = newInst("Frame", {
        Size             = UDim2.new(1, 0, 0, 86),
        Position         = UDim2.new(0, 0, 0, 56),
        BackgroundColor3 = Color3.fromRGB(18, 55, 12),
        BorderSizePixel  = 0,
        ZIndex           = 5,
        Parent           = luckFrame,
    })
    addCorner(luckCard, 4)
    do local sk = Instance.new("UIStroke"); sk.Color = Color3.fromRGB(80, 220, 80); sk.Thickness = 1.5; sk.Parent = luckCard end
    addGradientV(luckCard, Color3.fromRGB(30, 90, 20), Color3.fromRGB(18, 55, 12))
    addPadding(luckCard, 10)

    local luckCardThumb = newInst("ImageLabel", {
        Size = UDim2.new(0, 60, 0, 60), Position = UDim2.new(0, 0, 0.5, -30),
        BackgroundTransparency = 1, BorderSizePixel = 0, Image = "",
        ScaleType = Enum.ScaleType.Fit, ZIndex = 6, Parent = luckCard,
    })
    do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = luckCardThumb end

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
    luckUpgradeBtn:SetAttribute("NoSound", true)

    luckUpgradeBtn.MouseButton1Click:Connect(function()
        local palierActuel = currentData.luckPalierActuel or 0
        local nextPalier   = palierActuel + 1
        if nextPalier > #shopCfg.Luck.Paliers then return end
        ShopMonetPurchase:FireServer("Luck", nextPalier)
    end)

    local function mettreAJourCarteLuck(palierActuel)
        local nextPalier = palierActuel + 1
        if nextPalier > #shopCfg.Luck.Paliers then
            luckUpgradeLabel.Text           = "MAX Luck"
            luckUpgradeBtn.Text             = "MAX"
            luckUpgradeBtn.BackgroundColor3 = C.Disabled
            luckCardThumb.Image             = LUCK_THUMBNAILS[shopCfg.Luck.Paliers[#shopCfg.Luck.Paliers]] or ""
        else
            local palierVal = shopCfg.Luck.Paliers[nextPalier]
            luckUpgradeLabel.Text           = "x" .. tostring(palierVal) .. " Luck"
            luckUpgradeBtn.Text             = tostring(shopCfg.Luck.Prix[nextPalier] or 0) .. " R"
            luckUpgradeBtn.BackgroundColor3 = C.Succes
            luckCardThumb.Image             = LUCK_THUMBNAILS[palierVal] or ""
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
            t.btn.BackgroundColor3 = actif and Color3.fromRGB(50, 130, 255) or Color3.fromRGB(30, 30, 30)
            t.btn.TextColor3       = actif and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(130, 130, 130)
            local g = t.btn:FindFirstChildWhichIsA("UIGradient")
            if g then g:Destroy() end
            if actif then
                addGradientV(t.btn, Color3.fromRGB(80, 160, 255), Color3.fromRGB(35, 90, 210))
            end
        end
    end

    tabCash.MouseButton1Click:Connect(function()  setTab("CASH")         end)
    tabLucky.MouseButton1Click:Connect(function() setTab("LUCKY BLOCKS")  end)
    tabPack.MouseButton1Click:Connect(function()  setTab("PACKS")         end)
    tabLuck.MouseButton1Click:Connect(function()  setTab("LUCK")          end)

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

    local function ouvrirShop(data)
        fermerMenusSignal:Fire("Shop")
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

    fermerMenusSignal.Event:Connect(function(source)
        if source ~= "Shop" and screenGui.Enabled then
            fermerShop()
        end
    end)

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
                hudLabel.Text    = formaterTimer(secondes)
                hudThumb.Image   = LUCK_THUMBNAILS[luck] or ""
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
