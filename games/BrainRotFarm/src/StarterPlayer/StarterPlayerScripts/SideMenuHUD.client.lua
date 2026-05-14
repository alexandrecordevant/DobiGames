-- StarterPlayerScripts/SideMenuHUD.client.lua
-- BrainRotFarm — Menu HUD : grille 2×3 de boutons carrés, toggleable via hamburger

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local SoundService      = game:GetService("SoundService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Logger = require(ReplicatedStorage.SharedLib.Logger)

local MenuCfg = Config.MenuHUD or {}

-- Valeurs avec fallback
local BSIZE = MenuCfg.BurgerSize    or 50
local CELL  = MenuCfg.TailleBouton  or 80
local COLS  = MenuCfg.NbColonnes    or 2
local GAP   = MenuCfg.GrilleGap     or 6
local PAD   = MenuCfg.GrillePadding or 8
local RAYON = MenuCfg.RayonCoin     or 10
local DUREE = MenuCfg.DureeAnimation or 0.2
local ROWS  = 3  -- 6 boutons / 2 colonnes

-- Dimensions du panneau
local panelW = COLS * CELL + (COLS - 1) * GAP + 2 * PAD   -- 182 px
local panelH = ROWS * CELL + (ROWS - 1) * GAP + 2 * PAD   -- 268 px

-- ============================================================
-- ScreenGui — IgnoreGuiInset=false → sous la topbar Roblox
-- ============================================================
local gui = Instance.new("ScreenGui")
gui.Name           = "SideMenuHUD"
gui.ResetOnSpawn   = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset = false
gui.DisplayOrder   = 15
gui.Parent         = playerGui

-- Overlay transparent : clic en dehors ferme le menu
local overlay = Instance.new("TextButton")
overlay.Name                   = "CloseOverlay"
overlay.Size                   = UDim2.new(1, 0, 1, 0)
overlay.BackgroundTransparency = 1
overlay.Text                   = ""
overlay.BorderSizePixel        = 0
overlay.ZIndex                 = 14
overlay.Visible                = false
overlay.Parent                 = gui

-- ============================================================
-- Bouton hamburger (toujours visible)
-- ============================================================
local burgerBtn = Instance.new("TextButton")
burgerBtn.Name                   = "BurgerButton"
burgerBtn.Size                   = UDim2.new(0, BSIZE, 0, BSIZE)
burgerBtn.Position               = UDim2.new(0, 10, 0, 10)
burgerBtn.AnchorPoint            = Vector2.new(0, 0)
burgerBtn.BackgroundColor3       = Color3.fromRGB(10, 10, 10)
burgerBtn.BackgroundTransparency = 0.05
burgerBtn.Text                   = ""
burgerBtn.BorderSizePixel        = 0
burgerBtn.ZIndex                 = 20
burgerBtn.Parent                 = gui
Instance.new("UICorner", burgerBtn).CornerRadius = UDim.new(0, 8)
local burgerStroke = Instance.new("UIStroke", burgerBtn)
burgerStroke.Color     = Color3.fromRGB(60, 60, 60)
burgerStroke.Thickness = 1

-- 3 barres horizontales (☰ n'est pas dans la police Roblox)
do
    local BAR_W   = 26
    local BAR_H   = 4
    local BAR_GAP = 6
    local totalH  = 3 * BAR_H + 2 * BAR_GAP
    local sy = math.floor((BSIZE - totalH) / 2)
    local sx = math.floor((BSIZE - BAR_W)  / 2)
    for i = 1, 3 do
        local barre = Instance.new("Frame", burgerBtn)
        barre.Size             = UDim2.new(0, BAR_W, 0, BAR_H)
        barre.Position         = UDim2.new(0, sx, 0, sy + (i - 1) * (BAR_H + BAR_GAP))
        barre.BackgroundColor3 = Color3.fromRGB(210, 210, 210)
        barre.BorderSizePixel  = 0
        barre.ZIndex           = 21
        Instance.new("UICorner", barre).CornerRadius = UDim.new(0, 2)
    end
end

-- ============================================================
-- Panneau grille (hauteur = 0 quand fermé, ClipsDescendants masque les boutons)
-- ============================================================
local menuPanel = Instance.new("Frame")
menuPanel.Name                   = "MenuPanel"
menuPanel.Size                   = UDim2.new(0, panelW, 0, 0)
menuPanel.Position               = UDim2.new(0, 10, 0, 10 + BSIZE + 6)
menuPanel.BackgroundColor3       = Color3.fromRGB(12, 12, 12)
menuPanel.BackgroundTransparency = 0.08
menuPanel.BorderSizePixel        = 0
menuPanel.ClipsDescendants       = true
menuPanel.ZIndex                 = 15
menuPanel.Parent                 = gui
Instance.new("UICorner", menuPanel).CornerRadius = UDim.new(0, 8)
local panelStroke = Instance.new("UIStroke", menuPanel)
panelStroke.Color     = Color3.fromRGB(50, 50, 50)
panelStroke.Thickness = 1

-- Grille 2 colonnes
local gridLayout = Instance.new("UIGridLayout", menuPanel)
gridLayout.CellSize            = UDim2.new(0, CELL, 0, CELL)
gridLayout.CellPadding         = UDim2.new(0, GAP, 0, GAP)
gridLayout.SortOrder           = Enum.SortOrder.LayoutOrder
gridLayout.FillDirection       = Enum.FillDirection.Horizontal
gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
gridLayout.VerticalAlignment   = Enum.VerticalAlignment.Top

local gridPad = Instance.new("UIPadding", menuPanel)
gridPad.PaddingTop    = UDim.new(0, PAD)
gridPad.PaddingLeft   = UDim.new(0, PAD)
gridPad.PaddingRight  = UDim.new(0, PAD)
gridPad.PaddingBottom = UDim.new(0, PAD)

-- ============================================================
-- Toggle expand / collapse
-- ============================================================
local menuOuvert = false

-- Ferme tous les panneaux modaux connus avant d'ouvrir le grid
local function fermerAutresMenus()
    -- ShopRobuxPanel (HUD)
    local hud = playerGui:FindFirstChild("HUD")
    if hud then
        local rp = hud:FindFirstChild("ShopRobuxPanel")
        if rp and rp.Visible then rp.Visible = false end
    end
    -- ShopGui (shop coins)
    local shopGui = playerGui:FindFirstChild("ShopGui")
    if shopGui and shopGui.Enabled then shopGui.Enabled = false end
    -- IndexPanel
    local indexGui = playerGui:FindFirstChild("IndexGui")
    if indexGui then
        local p = indexGui:FindFirstChild("IndexPanel")
        if p and p.Visible then p.Visible = false end
    end
    -- FlowerPotHUD (MainFrame + DailySeedPanel + FlowerPotPanel)
    local fpGui = playerGui:FindFirstChild("FlowerPotHUD")
    if fpGui then
        local mf = fpGui:FindFirstChild("MainFrame")
        if mf then mf.Visible = false end
        local ds = fpGui:FindFirstChild("DailySeedPanel")
        if ds then ds:Destroy() end
        local fp = fpGui:FindFirstChild("FlowerPotPanel")
        if fp then fp.Visible = false end
    end
    -- TutoPanel
    local tutoGui = playerGui:FindFirstChild("MiniTutoHUD")
    if tutoGui then
        local p = tutoGui:FindFirstChild("TutoPanel")
        if p then p.Visible = false end
    end
end

local function ouvrirMenu()
    if menuOuvert then return end
    fermerAutresMenus()
    menuOuvert         = true
    overlay.Visible    = true
    menuPanel.Visible  = true   -- révéler avant l'animation
    TweenService:Create(menuPanel,
        TweenInfo.new(DUREE, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Size = UDim2.new(0, panelW, 0, panelH) }
    ):Play()
    Logger.debug("Menu", "ouvert")
end

local function fermerMenu()
    if not menuOuvert then return end
    menuOuvert      = false
    overlay.Visible = false
    local tween = TweenService:Create(menuPanel,
        TweenInfo.new(DUREE, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { Size = UDim2.new(0, panelW, 0, 0) })
    tween:Play()
    -- Masquer complètement après fermeture : fond + UIStroke disparaissent
    tween.Completed:Connect(function()
        if not menuOuvert then
            menuPanel.Visible = false
        end
    end)
    Logger.debug("Menu", "fermé")
end

burgerBtn.MouseButton1Click:Connect(function()
    if menuOuvert then fermerMenu() else ouvrirMenu() end
end)
overlay.MouseButton1Click:Connect(fermerMenu)

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.Escape and menuOuvert then fermerMenu() end
end)

-- Ferme le grid quand un autre panneau s'ouvre (surveillance des Visible/Enabled)
task.spawn(function()
    -- ShopGui (ouvert par le serveur via OuvrirShop)
    local shopGui = playerGui:WaitForChild("ShopGui", 30)
    if shopGui then
        shopGui:GetPropertyChangedSignal("Enabled"):Connect(function()
            if shopGui.Enabled and menuOuvert then fermerMenu() end
        end)
    end
    -- ShopRobuxPanel
    local hud = playerGui:WaitForChild("HUD", 30)
    if hud then
        local rp = hud:WaitForChild("ShopRobuxPanel", 10)
        if rp then
            rp:GetPropertyChangedSignal("Visible"):Connect(function()
                if rp.Visible and menuOuvert then fermerMenu() end
            end)
        end
    end
    -- IndexPanel
    local indexGui = playerGui:WaitForChild("IndexGui", 30)
    if indexGui then
        local p = indexGui:WaitForChild("IndexPanel", 10)
        if p then
            p:GetPropertyChangedSignal("Visible"):Connect(function()
                if p.Visible and menuOuvert then fermerMenu() end
            end)
        end
    end
    -- FlowerPotHUD — MainFrame
    local fpGui = playerGui:WaitForChild("FlowerPotHUD", 30)
    if fpGui then
        local mf = fpGui:WaitForChild("MainFrame", 10)
        if mf then
            mf:GetPropertyChangedSignal("Visible"):Connect(function()
                if mf.Visible and menuOuvert then fermerMenu() end
            end)
        end
        local fp = fpGui:WaitForChild("FlowerPotPanel", 10)
        if fp then
            fp:GetPropertyChangedSignal("Visible"):Connect(function()
                if fp.Visible and menuOuvert then fermerMenu() end
            end)
        end
    end
    -- TutoPanel
    local tutoGui = playerGui:WaitForChild("MiniTutoHUD", 30)
    if tutoGui then
        local p = tutoGui:WaitForChild("TutoPanel", 10)
        if p then
            p:GetPropertyChangedSignal("Visible"):Connect(function()
                if p.Visible and menuOuvert then fermerMenu() end
            end)
        end
    end
end)

-- ============================================================
-- Préparation d'un bouton reparenté dans la grille
-- UIGridLayout gère la taille → on retire seulement la UISizeConstraint
-- ============================================================
local function preparerBouton(btn, layoutOrder)
    local c = btn:FindFirstChildWhichIsA("UISizeConstraint")
    if c then c:Destroy() end
    btn.ZIndex      = 16
    btn.TextWrapped = true
    btn.LayoutOrder = layoutOrder
    btn.MouseButton1Click:Connect(fermerMenu)
    btn.Parent = menuPanel
end

-- ============================================================
-- Reparentage des 5 boutons existants (asynchrone)
-- ============================================================
task.spawn(function()

    -- 1. Shop
    local shopGui = playerGui:WaitForChild("ShopRobuxButtonGui", 30)
    if shopGui then
        local b = shopGui:WaitForChild("ShopRobuxButton", 10)
        if b then preparerBouton(b, 1) else Logger.warn("Menu", "ShopRobuxButton introuvable") end
    end

    -- 2. Index
    local indexGui = playerGui:WaitForChild("IndexGui", 30)
    if indexGui then
        local b = indexGui:WaitForChild("IndexBtn", 10)
        if b then preparerBouton(b, 2) else Logger.warn("Menu", "IndexBtn introuvable") end
    end

    -- 3. Daily Seed  +  4. FlowerPot
    local fpGui = playerGui:WaitForChild("FlowerPotHUD", 30)
    if fpGui then
        local bDS = fpGui:WaitForChild("DailySeedButton", 10)
        if bDS then preparerBouton(bDS, 3) else Logger.warn("Menu", "DailySeedButton introuvable") end
        local bFP = fpGui:WaitForChild("FlowerPotButton", 10)
        if bFP then preparerBouton(bFP, 4) else Logger.warn("Menu", "FlowerPotButton introuvable") end
    end

    -- 5. Tutorial
    local tutoGui = playerGui:WaitForChild("MiniTutoHUD", 30)
    if tutoGui then
        local b = tutoGui:WaitForChild("TutoButton", 10)
        if b then preparerBouton(b, 5) else Logger.warn("Menu", "TutoButton introuvable") end
    end

    Logger.info("Menu", "Grille 2x3 montée")
end)

-- ============================================================
-- Proxy Collect All (gardé séparé : son animation TweenSize est incompatible)
-- ============================================================
task.spawn(function()
    local collectGui = playerGui:WaitForChild("CollectAllGui", 30)
    if not collectGui then return end
    local origBtn = collectGui:WaitForChild("CollectAllBtn", 10)
    if origBtn then origBtn.Visible = false end

    local collectAllEvent = ReplicatedStorage:WaitForChild("CollectAllEvent", 30)
    if not collectAllEvent then return end

    local proxyBtn = Instance.new("TextButton")
    proxyBtn.Name                   = "CollectAllProxy"
    proxyBtn.BackgroundColor3       = Color3.fromRGB(10, 10, 10)
    proxyBtn.BackgroundTransparency = 0.05
    proxyBtn.Text                   = "Collect\nAll"
    proxyBtn.TextColor3             = Color3.fromRGB(220, 220, 220)
    proxyBtn.Font                   = Enum.Font.GothamBold
    proxyBtn.TextSize               = 11
    proxyBtn.TextWrapped            = true
    proxyBtn.BorderSizePixel        = 0
    proxyBtn.ZIndex                 = 16
    proxyBtn.LayoutOrder            = 6
    proxyBtn.Parent                 = menuPanel
    Instance.new("UICorner", proxyBtn).CornerRadius = UDim.new(0, RAYON)
    local s = Instance.new("UIStroke", proxyBtn)
    s.Color = Color3.fromRGB(60, 60, 60) ; s.Thickness = 1

    local enCooldown = false
    proxyBtn.MouseButton1Click:Connect(function()
        if enCooldown then return end
        enCooldown = true
        fermerMenu()
        collectAllEvent:FireServer()
        proxyBtn.BackgroundColor3 = Color3.fromRGB(80, 140, 80)
        local son = SoundService:FindFirstChild("SonUpgrade")
        if son then son:Play() end
        task.wait(0.15)
        proxyBtn.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
        task.wait(0.85)
        enCooldown = false
    end)

    Logger.info("Menu", "Proxy CollectAll créé")
end)

Logger.info("Menu", "SideMenuHUD initialisé")
