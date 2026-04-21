-- StarterPlayer/StarterPlayerScripts/MiniTutoHUD.client.lua
-- DobiGames BrainRotFarm — Mini Tutorial button (left HUD, below FlowerPot)

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS          = game:GetService("UserInputService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local T = require(game:GetService("ReplicatedStorage"):WaitForChild("SharedLib")
    :WaitForChild("Shared"):WaitForChild("UITheme"))

-- ============================================================
-- ScreenGui
-- ============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "MiniTutoHUD"
screenGui.ResetOnSpawn   = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset = true
screenGui.Parent         = playerGui

-- ============================================================
-- Left button — same style as DailySeed / FlowerPot buttons
-- Shop        : (0,10, 0.5,-132) h=55  → bottom at -77
-- [GAP FREE ~127px — no Rebirth in BrainRotFarm]
-- Tutorial    : (0,10, 0.5,-25)  h=55  ← here, in the gap
-- Daily Seed  : (0,10, 0.5, 50)  h=55
-- FlowerPot   : (0,10, 0.5,113)  h=55
-- Collect All : (0,10, 0.5,180)  h=55
-- ============================================================
-- Bouton Tutorial — style identique au bouton FlowerPot (reference)
local btn = Instance.new("TextButton", screenGui)
btn.Name                   = "TutoButton"
btn.Size                   = UDim2.new(0.25, 0, 0, 55)
btn.Position               = UDim2.new(0, 10, 0.5, -90)
btn.BackgroundColor3       = Color3.fromRGB(10, 10, 10)
btn.BackgroundTransparency = 0.05
btn.TextColor3             = Color3.fromRGB(220, 220, 220)
btn.Font                   = Enum.Font.GothamBold
btn.TextSize               = 13
btn.Text                   = "Tutorial"
btn.TextWrapped            = true
btn.BorderSizePixel        = 0
btn.ZIndex                 = 10
Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 2)
local btnStroke = Instance.new("UIStroke", btn)
btnStroke.Color     = Color3.fromRGB(60, 60, 60)
btnStroke.Thickness = 1
local _tutoConstraint = Instance.new("UISizeConstraint", btn)
_tutoConstraint.MinSize = Vector2.new(80, 44)
_tutoConstraint.MaxSize = Vector2.new(120, 55)

-- ============================================================
-- Tutorial panel
-- ============================================================
local PANEL_W = 360
local PANEL_H = 500

local overlay = Instance.new("Frame", screenGui)
overlay.Size                   = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3       = Color3.new(0, 0, 0)
overlay.BackgroundTransparency = 0.55
overlay.BorderSizePixel        = 0
overlay.Visible                = false
overlay.ZIndex                 = 20

local panel = Instance.new("Frame", screenGui)
panel.Name                   = "TutoPanel"
panel.AnchorPoint            = Vector2.new(0.5, 0.5)
panel.Size                   = UDim2.new(0, PANEL_W, 0, PANEL_H)
panel.Position               = UDim2.new(0.5, 0, 0.5, 0)
panel.BackgroundColor3       = T.fondPrincipal
panel.BackgroundTransparency = 0.04
panel.BorderSizePixel        = 0
panel.Visible                = false
panel.ZIndex                 = 21
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 0)
local panelStroke = Instance.new("UIStroke", panel)
panelStroke.Color     = T.bordure
panelStroke.Thickness = 1

-- Title bar
local titleLbl = Instance.new("TextLabel", panel)
titleLbl.Size                   = UDim2.new(1, -50, 0, 44)
titleLbl.Position               = UDim2.new(0, 14, 0, 6)
titleLbl.BackgroundTransparency = 1
titleLbl.Text                   = "HOW TO PLAY"
titleLbl.TextColor3             = T.texteTitre
titleLbl.Font                   = Enum.Font.GothamBold
titleLbl.TextSize               = 18
titleLbl.TextXAlignment         = Enum.TextXAlignment.Left
titleLbl.ZIndex                 = 22

local closeBtn = Instance.new("TextButton", panel)
closeBtn.Size              = UDim2.new(0, 44, 0, 44)
closeBtn.Position          = UDim2.new(1, -50, 0, 4)
closeBtn.BackgroundColor3  = Color3.fromRGB(50, 50, 50)
closeBtn.Text              = "X"
closeBtn.TextColor3        = Color3.fromRGB(180, 180, 180)
closeBtn.Font              = Enum.Font.GothamBold
closeBtn.TextSize          = 16
closeBtn.TextScaled        = false
closeBtn.BorderSizePixel   = 0
closeBtn.ZIndex            = 22
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 2)
local _cbs = Instance.new("UIStroke", closeBtn)
_cbs.Color = T.bordure ; _cbs.Thickness = 1

local sep = Instance.new("Frame", panel)
sep.Size             = UDim2.new(1, -24, 0, 1)
sep.Position         = UDim2.new(0, 12, 0, 54)
sep.BackgroundColor3 = T.bordure
sep.BorderSizePixel  = 0
sep.ZIndex           = 22

-- Scrollable content
local scroll = Instance.new("ScrollingFrame", panel)
scroll.Size                  = UDim2.new(1, -16, 1, -70)
scroll.Position              = UDim2.new(0, 8, 0, 62)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel       = 0
scroll.ScrollBarThickness    = 4
scroll.ScrollBarImageColor3  = T.bordure
scroll.AutomaticCanvasSize   = Enum.AutomaticSize.Y
scroll.ZIndex                = 22

local layout = Instance.new("UIListLayout", scroll)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding   = UDim.new(0, 10)

local padding = Instance.new("UIPadding", scroll)
padding.PaddingTop    = UDim.new(0, 6)
padding.PaddingBottom = UDim.new(0, 6)
padding.PaddingLeft   = UDim.new(0, 6)
padding.PaddingRight  = UDim.new(0, 6)

-- ============================================================
-- Helper: section card
-- ============================================================
local function makeCard(icon, title, body, order, accentColor)
    local card = Instance.new("Frame", scroll)
    card.Size             = UDim2.new(1, 0, 0, 0)  -- height driven by AutomaticSize
    card.AutomaticSize    = Enum.AutomaticSize.Y
    card.BackgroundColor3 = T.fondSecondaire
    card.BorderSizePixel  = 0
    card.LayoutOrder      = order
    card.ZIndex           = 23
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)
    local cs = Instance.new("UIStroke", card)
    cs.Color     = accentColor or T.bordure
    cs.Thickness = 1.5

    local cp = Instance.new("UIPadding", card)
    cp.PaddingTop    = UDim.new(0, 8)
    cp.PaddingBottom = UDim.new(0, 10)
    cp.PaddingLeft   = UDim.new(0, 10)
    cp.PaddingRight  = UDim.new(0, 10)

    local cardLayout = Instance.new("UIListLayout", card)
    cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
    cardLayout.Padding   = UDim.new(0, 4)

    -- Header row
    local header = Instance.new("TextLabel", card)
    header.Size                   = UDim2.new(1, 0, 0, 22)
    header.BackgroundTransparency = 1
    header.Text                   = icon .. "  " .. title
    header.TextColor3             = accentColor or T.texteTitre
    header.Font                   = Enum.Font.GothamBold
    header.TextSize               = 15
    header.TextXAlignment         = Enum.TextXAlignment.Left
    header.LayoutOrder            = 1
    header.ZIndex                 = 24

    -- Body text
    local bodyLbl = Instance.new("TextLabel", card)
    bodyLbl.Size                   = UDim2.new(1, 0, 0, 0)
    bodyLbl.AutomaticSize          = Enum.AutomaticSize.Y
    bodyLbl.BackgroundTransparency = 1
    bodyLbl.Text                   = body
    bodyLbl.TextColor3             = T.texte
    bodyLbl.Font                   = Enum.Font.Gotham
    bodyLbl.TextSize               = 12
    bodyLbl.TextXAlignment         = Enum.TextXAlignment.Left
    bodyLbl.TextWrapped            = true
    bodyLbl.RichText               = true
    bodyLbl.LayoutOrder            = 2
    bodyLbl.ZIndex                 = 24
end

-- ============================================================
-- Tutorial content
-- ============================================================
makeCard(
    "🧠", "BASICS",
    "Collect <b>Brainrots</b> that spawn on the map and carry them to the <b>Deposit Zone</b> to earn coins.\n\nUse coins in the <b>Shop</b> (left button) to unlock upgrades: more carry slots, faster brainrots, and more.",
    1,
    Color3.fromRGB(100, 160, 255)
)

makeCard(
    "☣️", "MUTANTS",
    "Some brainrots are <b>Mutants</b> — they glow with a special colour (Toxic, Rainbow, Galaxy, Void…).\n\nMutants are worth <b>much more coins</b> when deposited. Watch out for them — they're rarer but highly valuable!",
    2,
    Color3.fromRGB(160, 80, 255)
)

makeCard(
    "🌱", "SEEDS",
    "Seeds are special items dropped by the <b>Sacred Trees</b> on the map. You can also claim a <b>Daily Seed</b> every day (left button 🌱).\n\nTwo rarities exist: <b>MYTHIC</b> (⚡) and <b>SECRET</b> (🔴). Higher rarity = bigger bonus.",
    3,
    Color3.fromRGB(100, 220, 120)
)

makeCard(
    "🌱", "FLOWER POTS",
    "Plant a seed in a <b>Flower Pot</b> (left button 🌱) and wait for it to grow through <b>4 stages</b>.\n\nOnce fully grown, carry the brainrot that comes out to the deposit — it applies a <b>coin multiplier</b> based on seed rarity. Don't forget to unlock more pots in the Shop!",
    4,
    Color3.fromRGB(220, 150, 50)
)

makeCard(
    "💡", "TIPS",
    "• Upgrade <b>Carry Slots</b> first — more brainrots per trip = faster coins.\n• Check the <b>Daily Seed</b> button every day for a free seed.\n• Mutant brainrots stack with FlowerPot multipliers!\n• Sacred Trees reset on a timer — check the 🌱 panel for the countdown.",
    5,
    Color3.fromRGB(255, 200, 50)
)

makeCard(
    "🔥", "ROBUX UPGRADES",
    "Some Shop upgrades show an <b>orange 🔥 button</b> — those require <b>Robux</b> and are permanent (GamePass).\n\n<b>Shop upgrades:</b>\n• <b>Tracteur</b> (299 R$) — bonus MYTHIC &amp; SECRET spawns in your field\n• <b>LuckyCharm</b> (99 R$) — +25% rarity chance on every spawn\n• <b>Arroseur MAX / Speed MAX / Carry+ MAX</b> — unlock the final level of each upgrade\n\n<b>Flower Pot:</b>\n• <b>Pot 4</b> (149 R$) — 4th pot slot\n• <b>SeedDoubler</b> — claim 2 Daily Seeds per day instead of 1\n• <b>Instant Grow</b> (35 R$) — skip the grow timer on any pot\n\nAll Robux purchases are <b>one-time</b> and stay forever on your account.",
    6,
    Color3.fromRGB(255, 140, 30)
)

-- Recalcul du CanvasSize apres generation du contenu
task.wait(0)
scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 12)

-- ============================================================
-- Fermeture des autres menus (1 seul ouvert a la fois)
-- ============================================================
local function fermerAutresMenus()
    -- Fermer le ShopGui (coin shop)
    local shopGui = playerGui:FindFirstChild("ShopGui")
    if shopGui and shopGui.Enabled then shopGui.Enabled = false end
    -- Fermer le FlowerPotHUD panneau principal
    local fpGui = playerGui:FindFirstChild("FlowerPotHUD")
    if fpGui then
        local mf = fpGui:FindFirstChild("MainFrame")
        if mf then mf.Visible = false end
        local ds = fpGui:FindFirstChild("DailySeedPanel")
        if ds then ds:Destroy() end
        local fp = fpGui:FindFirstChild("FlowerPotPanel")
        if fp then fp.Visible = false end
    end
    -- Fermer le Robux shop
    local hud = playerGui:FindFirstChild("HUD")
    if hud then
        local rp = hud:FindFirstChild("ShopRobuxPanel")
        if rp then rp.Visible = false end
    end
end

-- ============================================================
-- Open / Close
-- ============================================================
local panelOpen = false

local function openPanel()
    fermerAutresMenus()
    panelOpen       = true
    overlay.Visible = true
    panel.Visible   = true
    panel.Size      = UDim2.new(0, 0, 0, 0)
    TweenService:Create(panel, TweenInfo.new(0.22, Enum.EasingStyle.Back), {
        Size = UDim2.new(0, PANEL_W, 0, PANEL_H),
    }):Play()
end

local function closePanel()
    if not panelOpen then return end
    panelOpen = false
    TweenService:Create(panel, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
        Size = UDim2.new(0, 0, 0, 0),
    }):Play()
    task.delay(0.16, function()
        panel.Visible   = false
        overlay.Visible = false
    end)
end

-- Reinitialiser l'etat si ferme par un autre menu
panel:GetPropertyChangedSignal("Visible"):Connect(function()
    if not panel.Visible then
        panelOpen       = false
        overlay.Visible = false
    end
end)

-- Adaptation mobile
local uiScale = Instance.new("UIScale", panel)
local function ajusterScaleTuto()
    local vp = workspace.CurrentCamera.ViewportSize
    local s = math.min(vp.X / 400, vp.Y / 540, 1)
    uiScale.Scale = math.max(0.5, s)
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(ajusterScaleTuto)
ajusterScaleTuto()

btn.MouseButton1Click:Connect(function()
    if panelOpen then closePanel() else openPanel() end
end)

closeBtn.MouseButton1Click:Connect(closePanel)

overlay.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
        closePanel()
    end
end)

UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.Escape and panelOpen then
        closePanel()
    end
end)
