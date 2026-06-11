-- StarterPlayerScripts/SideMenuHUD.client.lua
-- BrainRotKong — Menu HUD : grille 2×3 de boutons carrés, toggleable via hamburger

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local SoundService      = game:GetService("SoundService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Config       = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Logger       = require(ReplicatedStorage.SharedLib.Logger)
local ModalManager = require(ReplicatedStorage.SharedLib.ModalManager)

local function _getCloseEvent()
    local e = playerGui:FindFirstChild("__CloseMenuEvent")
    if not e then e = Instance.new("BindableEvent") ; e.Name = "__CloseMenuEvent" ; e.Parent = playerGui end
    return e
end
local closeMenuEvent = _getCloseEvent()

local MenuCfg = Config.MenuHUD or {}

-- Valeurs avec fallback
local BSIZE = MenuCfg.BurgerSize    or 50
local CELL  = MenuCfg.TailleBouton  or 80
local COLS  = MenuCfg.NbColonnes    or 2
local GAP   = MenuCfg.GrilleGap     or 6
local PAD   = MenuCfg.GrillePadding or 8
local RAYON = MenuCfg.RayonCoin     or 10
local DUREE = MenuCfg.DureeAnimation or 0.2
local ROWS  = 4  -- 7 boutons / 2 colonnes (+ proxy CollectAll = 8 slots)

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

-- Overlay (conservé comme placeholder, non utilisé pour fermer le menu)
local overlay = Instance.new("Frame")
overlay.Name                   = "CloseOverlay"
overlay.Size                   = UDim2.new(0, 0, 0, 0)
overlay.BackgroundTransparency = 1
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
burgerStroke.Color     = Color3.fromRGB(255, 180, 30)
burgerStroke.Thickness = 3

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
menuPanel.Position               = UDim2.new(0, 10 + BSIZE + 6, 0, 10)
menuPanel.BackgroundColor3       = Color3.fromRGB(12, 12, 12)
menuPanel.BackgroundTransparency = 0.08
menuPanel.BorderSizePixel        = 0
menuPanel.ClipsDescendants       = true
menuPanel.ZIndex                 = 15
menuPanel.Parent                 = gui
Instance.new("UICorner", menuPanel).CornerRadius = UDim.new(0, 8)
local panelStroke = Instance.new("UIStroke", menuPanel)
panelStroke.Color           = Color3.fromRGB(255, 180, 30)
panelStroke.Thickness       = 4
panelStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
menuPanel.Visible = false

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
    -- (FlowerPotHUD / Daily Seed retiré — Kong)
    -- TutoPanel
    local tutoGui = playerGui:FindFirstChild("MiniTutoHUD")
    if tutoGui then
        local p = tutoGui:FindFirstChild("TutoPanel")
        if p then p.Visible = false end
    end
    -- CodeRedeemGUI
    local codeGui = playerGui:FindFirstChild("CodeRedeemGUI")
    if codeGui then
        local p = codeGui:FindFirstChild("CodePanel")
        if p and p.Visible then
            p.Visible = false
            local ov = codeGui:FindFirstChild("Overlay")
            if ov then ov.Visible = false end
            ModalManager.Close("CodeRedeem")
        end
    end
end

local function ouvrirMenu()
    if menuOuvert then return end
    closeMenuEvent:Fire("SIDE_MENU")
    fermerAutresMenus()
    menuOuvert         = true
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

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.Escape and menuOuvert then fermerMenu() end
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

    -- (Daily Seed / FlowerPot retirés — Kong)

    -- 5. Tutorial
    local tutoGui = playerGui:WaitForChild("MiniTutoHUD", 30)
    if tutoGui then
        local b = tutoGui:WaitForChild("TutoButton", 10)
        if b then preparerBouton(b, 5) else Logger.warn("Menu", "TutoButton introuvable") end
    end

    -- 7. Codes promo
    local codeRedeemGui = playerGui:WaitForChild("CodeRedeemGUI", 60)
    if codeRedeemGui then
        local b = codeRedeemGui:WaitForChild("CodesButton", 30)
        if b then preparerBouton(b, 7) else Logger.warn("Menu", "CodesButton introuvable") end
    end

    Logger.info("Menu", "Grille 2x4 montee")
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
    proxyBtn.Text                   = ""
    proxyBtn.Font                   = Enum.Font.GothamBold
    proxyBtn.TextSize               = 11
    proxyBtn.TextWrapped            = true
    proxyBtn.BorderSizePixel        = 0
    proxyBtn.ZIndex                 = 16
    proxyBtn.LayoutOrder            = 6
    proxyBtn.Parent                 = menuPanel
    Instance.new("UICorner", proxyBtn).CornerRadius = UDim.new(0, RAYON)
    local _s = Instance.new("UIStroke", proxyBtn)
    _s.Color = Color3.fromRGB(60, 60, 60) ; _s.Thickness = 1
    local _caIcon = Instance.new("ImageLabel", proxyBtn)
    _caIcon.Size                   = UDim2.new(1, -4, 1, -4)
    _caIcon.Position               = UDim2.new(0, 2, 0, 2)
    _caIcon.BackgroundTransparency = 1
    _caIcon.Image                  = "rbxassetid://79352018655308"
    _caIcon.ScaleType              = Enum.ScaleType.Fit
    _caIcon.ZIndex                 = 17

    local enCooldown = false
    proxyBtn.MouseButton1Click:Connect(function()
        if enCooldown then return end
        enCooldown = true
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

closeMenuEvent.Event:Connect(function(exceptName)
    if exceptName ~= "SIDE_MENU" and menuOuvert then fermerMenu() end
end)

Logger.info("Menu", "SideMenuHUD initialisé")
