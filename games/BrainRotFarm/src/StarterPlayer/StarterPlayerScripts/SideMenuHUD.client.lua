-- StarterPlayerScripts/SideMenuHUD.client.lua
-- BrainRotFarm — Menu latéral gauche toggleable (hamburger + slide-in)
--
-- Stratégie : reparente les 5 boutons HUD existants dans le panneau menu
-- afin de conserver toutes leurs connexions RemoteEvent/closures intactes.
-- CollectAll reçoit un proxy séparé (animation interne incompatible UIListLayout).

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local SoundService      = game:GetService("SoundService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Logger = require(ReplicatedStorage.SharedLib.Logger)

-- Fallback si GameConfig n'a pas encore été synced avec la section MenuHUD
local MenuCfg = Config.MenuHUD or {
    LargeurMobile  = 0.25,
    LargeurDesktop = 0.15,
    HauteurBouton  = 60,
    RayonCoin      = 10,
    DureeAnimation = 0.2,
    BurgerSize     = 50,
}

-- ============================================================
-- Détection mobile / calcul largeur
-- ============================================================
local function estMobile()
    return UserInputService.TouchEnabled
end

local function calculerLargeurMenu()
    local vp    = workspace.CurrentCamera.ViewportSize
    local ratio = estMobile() and MenuCfg.LargeurMobile or MenuCfg.LargeurDesktop
    return math.max(90, math.floor(vp.X * ratio))
end

-- ============================================================
-- ScreenGui — IgnoreGuiInset=false : coordonnées sous la topbar Roblox
-- Garantit que le bouton hamburger n'est pas masqué par la barre CoreGui
-- ============================================================
local gui = Instance.new("ScreenGui")
gui.Name           = "SideMenuHUD"
gui.ResetOnSpawn   = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset = false
gui.DisplayOrder   = 15
gui.Parent         = playerGui

-- Overlay transparent — ferme le menu au clic en dehors
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
-- Panneau menu (démarre hors écran à gauche)
-- ============================================================
local largeurInit = calculerLargeurMenu()

local menuPanel = Instance.new("Frame")
menuPanel.Name                   = "MenuPanel"
menuPanel.Size                   = UDim2.new(0, largeurInit, 1, 0)
menuPanel.Position               = UDim2.new(0, -largeurInit, 0, 0)
menuPanel.BackgroundColor3       = Color3.fromRGB(12, 12, 12)
menuPanel.BackgroundTransparency = 0.08
menuPanel.BorderSizePixel        = 0
menuPanel.ClipsDescendants       = true
menuPanel.ZIndex                 = 15
menuPanel.Parent                 = gui

Instance.new("UIStroke", menuPanel).Color     = Color3.fromRGB(50, 50, 50)
Instance.new("UIStroke", menuPanel).Thickness = 1

-- Disposition verticale des boutons dans le panneau
local listLayout = Instance.new("UIListLayout", menuPanel)
listLayout.SortOrder           = Enum.SortOrder.LayoutOrder
listLayout.FillDirection       = Enum.FillDirection.Vertical
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
listLayout.VerticalAlignment   = Enum.VerticalAlignment.Top
listLayout.Padding             = UDim.new(0, 6)

-- PaddingTop = 70 : espace réservé au bouton hamburger (50px) + marges
local listPadding = Instance.new("UIPadding", menuPanel)
listPadding.PaddingTop    = UDim.new(0, 70)
listPadding.PaddingLeft   = UDim.new(0, 6)
listPadding.PaddingRight  = UDim.new(0, 6)
listPadding.PaddingBottom = UDim.new(0, 10)

-- ============================================================
-- Bouton hamburger ☰ — coin supérieur gauche, ZIndex > panel
-- ============================================================
local burgerBtn = Instance.new("TextButton")
burgerBtn.Name                   = "BurgerButton"
burgerBtn.Size                   = UDim2.new(0, MenuCfg.BurgerSize, 0, MenuCfg.BurgerSize)
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

-- 3 barres horizontales dessinées en Frame (☰ ne s'affiche pas en police Roblox)
local BAR_W = 26   -- largeur des barres (px)
local BAR_H = 4    -- épaisseur (px)
local BAR_GAP = 6  -- espace entre barres (px)
local totalH = 3 * BAR_H + 2 * BAR_GAP   -- = 24px
local startY = math.floor((MenuCfg.BurgerSize - totalH) / 2)
local startX = math.floor((MenuCfg.BurgerSize - BAR_W) / 2)
for i = 1, 3 do
    local barre = Instance.new("Frame", burgerBtn)
    barre.Size             = UDim2.new(0, BAR_W, 0, BAR_H)
    barre.Position         = UDim2.new(0, startX, 0, startY + (i - 1) * (BAR_H + BAR_GAP))
    barre.BackgroundColor3 = Color3.fromRGB(210, 210, 210)
    barre.BorderSizePixel  = 0
    barre.ZIndex           = 21
    Instance.new("UICorner", barre).CornerRadius = UDim.new(0, 2)
end

-- ============================================================
-- Animations ouverture / fermeture
-- ============================================================
local menuOuvert = false

local function ouvrirMenu()
    if menuOuvert then return end
    menuOuvert      = true
    overlay.Visible = true
    local l = calculerLargeurMenu()
    menuPanel.Size     = UDim2.new(0, l, 1, 0)
    menuPanel.Position = UDim2.new(0, -l, 0, 0)
    TweenService:Create(menuPanel,
        TweenInfo.new(MenuCfg.DureeAnimation, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Position = UDim2.new(0, 0, 0, 0) }
    ):Play()
    Logger.debug("Menu", "Menu ouvert")
end

local function fermerMenu()
    if not menuOuvert then return end
    menuOuvert      = false
    overlay.Visible = false
    local l = calculerLargeurMenu()
    TweenService:Create(menuPanel,
        TweenInfo.new(MenuCfg.DureeAnimation, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { Position = UDim2.new(0, -l, 0, 0) }
    ):Play()
    Logger.debug("Menu", "Menu fermé")
end

burgerBtn.MouseButton1Click:Connect(function()
    if menuOuvert then fermerMenu() else ouvrirMenu() end
end)
overlay.MouseButton1Click:Connect(fermerMenu)

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.Escape and menuOuvert then
        fermerMenu()
    end
end)

workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
    local l = calculerLargeurMenu()
    menuPanel.Size = UDim2.new(0, l, 1, 0)
    if not menuOuvert then
        menuPanel.Position = UDim2.new(0, -l, 0, 0)
    end
end)

-- ============================================================
-- Préparation d'un bouton reparenté dans le menu
-- ============================================================
local function preparerBouton(btn, layoutOrder)
    local c = btn:FindFirstChildWhichIsA("UISizeConstraint")
    if c then c:Destroy() end
    btn.Size        = UDim2.new(1, 0, 0, MenuCfg.HauteurBouton)
    btn.Position    = UDim2.new(0, 0, 0, 0)
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

    local shopGui = playerGui:WaitForChild("ShopRobuxButtonGui", 30)
    if shopGui then
        local b = shopGui:WaitForChild("ShopRobuxButton", 10)
        if b then preparerBouton(b, 1) else Logger.warn("Menu", "ShopRobuxButton introuvable") end
    else
        Logger.warn("Menu", "ShopRobuxButtonGui introuvable")
    end

    local indexGui = playerGui:WaitForChild("IndexGui", 30)
    if indexGui then
        local b = indexGui:WaitForChild("IndexBtn", 10)
        if b then preparerBouton(b, 2) else Logger.warn("Menu", "IndexBtn introuvable") end
    else
        Logger.warn("Menu", "IndexGui introuvable")
    end

    local fpGui = playerGui:WaitForChild("FlowerPotHUD", 30)
    if fpGui then
        local bDS = fpGui:WaitForChild("DailySeedButton", 10)
        if bDS then preparerBouton(bDS, 3) else Logger.warn("Menu", "DailySeedButton introuvable") end
        local bFP = fpGui:WaitForChild("FlowerPotButton", 10)
        if bFP then preparerBouton(bFP, 4) else Logger.warn("Menu", "FlowerPotButton introuvable") end
    else
        Logger.warn("Menu", "FlowerPotHUD introuvable")
    end

    local tutoGui = playerGui:WaitForChild("MiniTutoHUD", 30)
    if tutoGui then
        local b = tutoGui:WaitForChild("TutoButton", 10)
        if b then preparerBouton(b, 5) else Logger.warn("Menu", "TutoButton introuvable") end
    else
        Logger.warn("Menu", "MiniTutoHUD introuvable")
    end

    Logger.info("Menu", "Boutons reparentés")
end)

-- ============================================================
-- Proxy Collect All (bouton d'origine masqué)
-- ============================================================
task.spawn(function()
    local collectGui = playerGui:WaitForChild("CollectAllGui", 30)
    if not collectGui then
        Logger.warn("Menu", "CollectAllGui introuvable")
        return
    end
    local origBtn = collectGui:WaitForChild("CollectAllBtn", 10)
    if origBtn then origBtn.Visible = false end

    local collectAllEvent = ReplicatedStorage:WaitForChild("CollectAllEvent", 30)
    if not collectAllEvent then
        Logger.warn("Menu", "CollectAllEvent introuvable")
        return
    end

    local proxyBtn = Instance.new("TextButton")
    proxyBtn.Name                   = "CollectAllProxy"
    proxyBtn.Size                   = UDim2.new(1, 0, 0, MenuCfg.HauteurBouton)
    proxyBtn.BackgroundColor3       = Color3.fromRGB(10, 10, 10)
    proxyBtn.BackgroundTransparency = 0.05
    proxyBtn.Text                   = "Collect All"
    proxyBtn.TextColor3             = Color3.fromRGB(220, 220, 220)
    proxyBtn.Font                   = Enum.Font.GothamBold
    proxyBtn.TextSize               = 14
    proxyBtn.TextScaled             = true
    proxyBtn.TextWrapped            = true
    proxyBtn.BorderSizePixel        = 0
    proxyBtn.ZIndex                 = 16
    proxyBtn.LayoutOrder            = 6
    proxyBtn.Parent                 = menuPanel
    Instance.new("UICorner", proxyBtn).CornerRadius = UDim.new(0, MenuCfg.RayonCoin)
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
