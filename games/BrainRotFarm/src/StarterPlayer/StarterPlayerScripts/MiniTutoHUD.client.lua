-- StarterPlayer/StarterPlayerScripts/MiniTutoHUD.client.lua
-- DobiGames BrainRotFarm — Mini Tutorial button (left HUD, below FlowerPot)

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local UIS               = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local function _getCloseEvent()
    local e = playerGui:FindFirstChild("__CloseMenuEvent")
    if not e then e = Instance.new("BindableEvent") ; e.Name = "__CloseMenuEvent" ; e.Parent = playerGui end
    return e
end
local closeMenuEvent = _getCloseEvent()

local UI           = require(ReplicatedStorage:WaitForChild("SharedLib"):WaitForChild("UIConfig"))
local ModalManager = require(ReplicatedStorage:WaitForChild("SharedLib"):WaitForChild("ModalManager"))

-- ============================================================
-- ScreenGui
-- ============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "MiniTutoHUD"
screenGui.ResetOnSpawn   = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder   = 16   -- au-dessus du SideMenuHUD (DisplayOrder=15)
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
btn.Size                   = UDim2.new(0, 80, 0, 80)
btn.Position               = UDim2.new(0, 5, 0.5, 45)
btn.BackgroundColor3       = Color3.fromRGB(10, 10, 10)
btn.BackgroundTransparency = 0.05
btn.TextColor3             = Color3.fromRGB(220, 220, 220)
btn.Font                   = Enum.Font.GothamBold
btn.TextSize               = 12
btn.Text                   = "Tutorial"
btn.TextWrapped            = true
btn.BorderSizePixel        = 0
btn.ZIndex                 = 10
Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
local btnStroke = Instance.new("UIStroke", btn)
btnStroke.Color     = Color3.fromRGB(60, 60, 60)
btnStroke.Thickness = 1
btn.Text = ""
local _tutoIcon = Instance.new("ImageLabel", btn)
_tutoIcon.Size                   = UDim2.new(1, -4, 1, -4)
_tutoIcon.Position               = UDim2.new(0, 2, 0, 2)
_tutoIcon.BackgroundTransparency = 1
_tutoIcon.Image                  = "rbxassetid://127251872068787"
_tutoIcon.ScaleType              = Enum.ScaleType.Fit
_tutoIcon.ZIndex                 = 11
local _tutoConstraint = Instance.new("UISizeConstraint", btn)
_tutoConstraint.MinSize = Vector2.new(80, 80)
_tutoConstraint.MaxSize = Vector2.new(80, 80)

-- ============================================================
-- Dimensions calculées lazily au moment de l'ouverture (vp.X peut être 0 au boot)
-- ============================================================
local function calcTutoDimensions()
    local vp  = workspace.CurrentCamera.ViewportSize
    local vpX = vp.X > 0 and vp.X or 500
    local vpY = vp.Y > 0 and vp.Y or 700
    local w = math.min(math.floor(vpX * UI.Modal.WidthScale), UI.Modal.WidthMaxPx)
    local h = math.min(math.floor(vpY * UI.Modal.HeightScale), vpY - 20)
    return w, h
end

-- Valeurs initiales (peuvent être 0 si viewport pas encore initialisé)
local PANEL_W, PANEL_H = calcTutoDimensions()

local overlay = Instance.new("Frame", screenGui)
overlay.Size                   = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3       = UI.Colors.Overlay
overlay.BackgroundTransparency = 0.55
overlay.BorderSizePixel        = 0
overlay.Visible                = false
overlay.ZIndex                 = 20

local panel = Instance.new("Frame", screenGui)
panel.Name                   = "TutoPanel"
panel.AnchorPoint            = Vector2.new(0.5, 0.5)
panel.Size                   = UDim2.new(0, PANEL_W, 0, PANEL_H)
panel.Position               = UDim2.new(0.5, 0, 0.5, 0)
panel.BackgroundColor3       = UI.Colors.ModalBackground
panel.BackgroundTransparency = 0.04
panel.BorderSizePixel        = 0
panel.Visible                = false
panel.ZIndex                 = 21
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, UI.Modal.CornerRadius)
local panelStroke = Instance.new("UIStroke", panel)
panelStroke.Color           = Color3.fromRGB(255, 180, 30)
panelStroke.Thickness       = 5
panelStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
panel.ClipsDescendants      = true

-- Barre de titre
local _titleBg = Instance.new("Frame", panel)
_titleBg.Size                   = UDim2.new(1, 0, 0, 54)
_titleBg.Position               = UDim2.new(0, 0, 0, 0)
_titleBg.BackgroundColor3       = Color3.fromRGB(255, 200, 50)
_titleBg.BackgroundTransparency = 0
_titleBg.BorderSizePixel        = 0
_titleBg.ZIndex                 = 21
local _hdrStuds = Instance.new("ImageLabel", _titleBg)
_hdrStuds.Size               = UDim2.new(1,0,1,0) ; _hdrStuds.BackgroundTransparency = 1
_hdrStuds.Image              = "rbxassetid://6927295847" ; _hdrStuds.ScaleType = Enum.ScaleType.Tile
_hdrStuds.TileSize           = UDim2.fromOffset(30,30)
_hdrStuds.ImageTransparency  = 0.15 ; _hdrStuds.ImageColor3 = Color3.fromRGB(160, 90, 0)
_hdrStuds.ZIndex             = 3
local titleLbl = Instance.new("TextLabel", panel)
titleLbl.Size                   = UDim2.new(1, 0, 0, 54)
titleLbl.Position               = UDim2.new(0, 0, 0, 0)
titleLbl.BackgroundColor3       = Color3.fromRGB(255, 200, 50)
titleLbl.BackgroundTransparency = 1
titleLbl.Text                   = "  HOW TO PLAY"
titleLbl.TextColor3             = Color3.fromRGB(255, 255, 255)
titleLbl.TextStrokeColor3       = Color3.fromRGB(80, 40, 0)
titleLbl.TextStrokeTransparency = 0
titleLbl.Font                   = UI.Fonts.Title
titleLbl.TextSize               = UI.TextSizes.H1
titleLbl.TextScaled             = false
titleLbl.TextXAlignment         = Enum.TextXAlignment.Left
titleLbl.ZIndex                 = 22

local closeBtn = Instance.new("TextButton", panel)
closeBtn.Size              = UDim2.new(0, UI.Modal.CloseButtonSize, 0, UI.Modal.CloseButtonSize)
closeBtn.Position          = UDim2.new(1, -50, 0, 4)
closeBtn.BackgroundColor3  = Color3.fromRGB(230, 50, 50)
closeBtn.Text              = "X"
closeBtn.TextColor3        = Color3.fromRGB(255, 255, 255)
closeBtn.Font              = UI.Fonts.Title
closeBtn.TextSize          = UI.TextSizes.H2
closeBtn.TextScaled        = false
closeBtn.BorderSizePixel   = 0
closeBtn.ZIndex            = 23
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
local _cbs = Instance.new("UIStroke", closeBtn)
_cbs.Color = Color3.fromRGB(255, 255, 255) ; _cbs.Thickness = 3

local sep = Instance.new("Frame", panel)
sep.Size             = UDim2.new(1, -24, 0, 1)
sep.Position         = UDim2.new(0, 12, 0, 54)
sep.BackgroundColor3 = UI.Colors.ModalBorder
sep.BorderSizePixel  = 0
sep.ZIndex           = 22

-- Zone de contenu scrollable
local scroll = Instance.new("ScrollingFrame", panel)
scroll.Size                   = UDim2.new(1, -16, 1, -70)
scroll.Position               = UDim2.new(0, 8, 0, 62)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel        = 0
scroll.ScrollBarThickness     = UI.Modal.ScrollBarThickness
scroll.ScrollBarImageColor3   = UI.Colors.ModalBorder
scroll.AutomaticCanvasSize    = Enum.AutomaticSize.None
scroll.CanvasSize             = UDim2.new(0, 0, 0, 0)
scroll.ZIndex                 = 22

local layout = Instance.new("UIListLayout", scroll)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding   = UDim.new(0, 10)

local padding = Instance.new("UIPadding", scroll)
padding.PaddingTop    = UDim.new(0, 6)
padding.PaddingBottom = UDim.new(0, 6)
padding.PaddingLeft   = UDim.new(0, 6)
padding.PaddingRight  = UDim.new(0, 10)  -- marge extra : évite que le UIStroke des cartes soit clippé

-- ============================================================
-- Helper : carte de section
-- ============================================================
local function makeCard(icon, title, body, order, accentColor)
    local card = Instance.new("Frame", scroll)
    card.Size             = UDim2.new(1, 0, 0, 0)  -- hauteur pilotée par AutomaticSize
    card.AutomaticSize    = Enum.AutomaticSize.Y
    card.BackgroundColor3 = UI.Colors.SectionBackground
    card.BorderSizePixel  = 0
    card.LayoutOrder      = order
    card.ZIndex           = 23
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)
    local cs = Instance.new("UIStroke", card)
    cs.Color     = accentColor or UI.Colors.ModalBorder
    cs.Thickness = 2.5

    local cp = Instance.new("UIPadding", card)
    cp.PaddingTop    = UDim.new(0, UI.Spacing.SM)
    cp.PaddingBottom = UDim.new(0, UI.Spacing.SM)
    cp.PaddingLeft   = UDim.new(0, UI.Spacing.SM)
    cp.PaddingRight  = UDim.new(0, UI.Spacing.SM)

    local cardLayout = Instance.new("UIListLayout", card)
    cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
    cardLayout.Padding   = UDim.new(0, 4)

    -- Ligne d'en-tête
    local header = Instance.new("TextLabel", card)
    header.Size                   = UDim2.new(1, 0, 0, 22)
    header.BackgroundTransparency = 1
    header.Text                   = icon .. "  " .. title
    header.TextColor3             = accentColor or UI.Colors.TextOnDark
    header.Font                   = UI.Fonts.Title
    header.TextSize               = UI.TextSizes.H2
    header.TextScaled             = false
    header.TextXAlignment         = Enum.TextXAlignment.Left
    header.LayoutOrder            = 1
    header.ZIndex                 = 24

    -- Corps de la carte
    local bodyLbl = Instance.new("TextLabel", card)
    bodyLbl.Size                   = UDim2.new(1, 0, 0, 0)
    bodyLbl.AutomaticSize          = Enum.AutomaticSize.Y
    bodyLbl.BackgroundTransparency = 1
    bodyLbl.Text                   = body
    bodyLbl.TextColor3             = UI.Colors.TextOnDark
    bodyLbl.Font                   = UI.Fonts.Body
    bodyLbl.TextSize               = UI.TextSizes.Body
    bodyLbl.TextScaled             = false
    bodyLbl.TextXAlignment         = Enum.TextXAlignment.Left
    bodyLbl.TextWrapped            = true
    bodyLbl.RichText               = true
    bodyLbl.LayoutOrder            = 2
    bodyLbl.ZIndex                 = 24
end

-- ============================================================
-- Contenu du tutoriel
-- ============================================================
makeCard(
    "🕐", "TIMINGS — QUICK REFERENCE",
    "<b>🌱 Daily Seed</b> — Every <b>24 hours</b> (claim with the 🌱 button on the left)\n\n<b>🌳 Sacred Trees</b> — Drop a seed every <b>30 min</b>: <b>70% MYTHIC ⚡ / 30% SECRET 🔴</b>. You have <b>5 min</b> to collect it before it disappears.\n\n<b>🗺️ Common Field</b> — <b>MYTHIC ⚡ every 8 min</b> · <b>SECRET 🔴 every 20 min</b>. A countdown appears above the spawn point before they land!\n\n<b>⚡ In-game Events</b> (Rain · Night · Meteor · Golden · Lucky Hour · Secret Spawn) — One triggers every <b>2 hours</b> in the Common Field. Watch the top-bar timer!\n\n<b>🌈 Admin Abuse</b> — Every <b>Saturday at 8 PM UTC</b>, 45 min of ×50 spawn + ×5 coins. Be there at the start for a <b>free MYTHIC Seed</b>!",
    0,
    Color3.fromRGB(80, 210, 200)
)

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
    "⚡", "EVENTS",
    "Events trigger automatically every few minutes in the <b>Common Field</b>. Watch the top bar for the timer!\n\n<b>🌧️ Rain</b> — Rain clouds flood the field. Common Field spawn rate <b>×3</b>. Puddles &amp; thunder.\n\n<b>🌙 Night Mode</b> — Sudden darkness. EPIC+ brainrots <b>glow in the dark</b>. Stars appear in the sky.\n\n<b>☄️ Meteor Drop</b> — Meteors crash into the field. Each impact spawns a <b>LEGENDARY / MYTHIC / SECRET</b> brainrot.\n\n<b>✨ Golden</b> — All earnings multiplied <b>×5</b> for 60 seconds. Rush your deposits!\n\n<b>⭐ Lucky Hour</b> — Rare brainrots (RARE / EPIC / LEGENDARY) spawn directly on <b>your base</b>.\n\n<b>🔴 Secret Spawn</b> — A secret window where <b>SECRET</b> brainrots can appear in the Common Field.",
    6,
    Color3.fromRGB(80, 200, 255)
)

makeCard(
    "⚡", "WEEKLY ADMIN ABUSE",
    "Every <b>Saturday at 8pm UTC</b>, the admins go wild for <b>45 minutes</b>!\n\n• Spawn rate <b>×50</b> — brainrots everywhere\n• All earnings <b>×5</b>\n• <b>Auto-collect</b> fires every 20 seconds for everyone\n• Rainbow ground + Rainbow Clouds appear\n\n<b>🌈 Early Bird bonus:</b> Be online when it starts → you instantly receive a <b>free MYTHIC Seed</b>. Join after and you miss it!\n\n<b>Flash Quests</b> during the event:\n• 10 BRs collected → +1 000 coins\n• 25 BRs → +3 000 coins\n• 50 BRs → +7 500 coins\n• 100 BRs → +20 000 coins\n\nJoin our <b>Discord</b> to get the @everyone ping before it starts!",
    7,
    Color3.fromRGB(255, 80, 80)
)

makeCard(
    "🔥", "ROBUX UPGRADES",
    "Some Shop upgrades show an <b>orange 🔥 button</b> — those require <b>Robux</b> and are permanent (GamePass).\n\n<b>Shop upgrades:</b>\n• <b>Tracteur</b> (299 R$) — automatically drives across your field and <b>auto-collects</b> all brainrots, crediting coins directly with your income multiplier (no carry needed). When <b>you</b> manually collect a <b>RARE or higher</b>, it also rolls for a bonus spawn: <b>4% MYTHIC / 1% SECRET / 1% jackpot (both)</b>. ⚠️ If the tractor auto-collects the RARE+, the bonus roll does <b>not</b> trigger.\n• <b>Lucky Charm</b> (149 R$) — <b>COMMON never spawns</b> on your base + OG brainrots are worth <b>2× coins</b>\n• <b>Arroseur MAX / Speed MAX / Carry+ MAX</b> — unlock the final level of each upgrade\n\n<b>Flower Pot:</b>\n• <b>Pot 4</b> (149 R$) — 4th pot slot\n• <b>SeedDoubler</b> — claim 2 Daily Seeds per day instead of 1\n• <b>Instant Grow</b> (35 R$) — skip the grow timer on any pot\n\nAll Robux purchases are <b>one-time</b> and stay forever on your account.",
    8,
    Color3.fromRGB(255, 140, 30)
)

-- Recalcul du CanvasSize apres generation du contenu (et à chaque changement)
local function majCanvasSize()
    scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 12)
end
layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(majCanvasSize)
task.wait(0)
majCanvasSize()

-- ============================================================
-- Fermeture des autres menus (1 seul ouvert a la fois)
-- ============================================================
local function fermerAutresMenus()
    local indexGui = playerGui:FindFirstChild("IndexGui")
    if indexGui then
        local p = indexGui:FindFirstChild("IndexPanel")
        if p and p.Visible then p.Visible = false end
    end
    -- Fermer le ShopGui (coin shop)
    local shopGui = playerGui:FindFirstChild("ShopGui")
    if shopGui and shopGui.Enabled then shopGui.Enabled = false end
    -- Fermer le FlowerPotHUD panneau principal
    local fpGui = playerGui:FindFirstChild("FlowerPotHUD")
    if fpGui then
        local mf = fpGui:FindFirstChild("MainFrame")
        if mf then mf.Visible = false end
        local ds = fpGui:FindFirstChild("DailySeedPanel")
        if ds then
            ModalManager.Close(ModalManager.Modals.DAILY_SEEDS)
            ds:Destroy()
        end
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
    closeMenuEvent:Fire("HOW_TO_PLAY")
    ModalManager.Open(ModalManager.Modals.HOW_TO_PLAY)
    fermerAutresMenus()
    -- Recalcul au moment de l'ouverture (vp.X peut être 0 au boot)
    local pw, ph = calcTutoDimensions()
    panelOpen       = true
    overlay.Visible = true
    panel.Visible   = true
    panel.Size      = UDim2.new(0, 0, 0, 0)
    TweenService:Create(panel, TweenInfo.new(0.22, Enum.EasingStyle.Back), {
        Size = UDim2.new(0, pw, 0, ph),
    }):Play()
end

local function closePanel()
    if not panelOpen then return end
    ModalManager.Close(ModalManager.Modals.HOW_TO_PLAY)
    panelOpen = false
    TweenService:Create(panel, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
        Size = UDim2.new(0, 0, 0, 0),
    }):Play()
    task.delay(0.16, function()
        panel.Visible   = false
        overlay.Visible = false
    end)
end

-- Reinitialiser l'etat si ferme par un autre menu (sécurité auto-close)
panel:GetPropertyChangedSignal("Visible"):Connect(function()
    if not panel.Visible then
        panelOpen       = false
        overlay.Visible = false
        ModalManager.Close(ModalManager.Modals.HOW_TO_PLAY)
    end
end)

-- Adaptation mobile (UIScale recalculee sur chaque changement de viewport)
local uiScale = Instance.new("UIScale", panel)
local function ajusterScaleTuto()
    local vp = workspace.CurrentCamera.ViewportSize
    local s = math.min(vp.X / (UI.Modal.WidthMaxPx + 40), vp.Y / (PANEL_H + 40), 1)
    uiScale.Scale = math.max(0.5, s)
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(ajusterScaleTuto)
ajusterScaleTuto()

closeMenuEvent.Event:Connect(function(exceptName)
    if exceptName ~= "HOW_TO_PLAY" and panelOpen then closePanel() end
end)

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
