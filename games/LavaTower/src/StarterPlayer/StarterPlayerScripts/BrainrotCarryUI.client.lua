-- StarterPlayerScripts/BrainrotCarryUI.client.lua
-- UI : jauge de portage Brainrots + menu d'amélioration

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player = Players.LocalPlayer

-- ─────────────────────────────────────────────────────────────
-- RemoteEvents (créés par BrainrotPickupModule côté serveur)
-- ─────────────────────────────────────────────────────────────

local function WaitRemote(name)
    return ReplicatedStorage:WaitForChild(name, 10)
end

local CarryUpdateEvent  = WaitRemote("BrainrotCarryUpdate")
local CarryErrorEvent   = WaitRemote("BrainrotCarryError")
local UpgradeCarryEvent = WaitRemote("BrainrotUpgradeCarry")

-- ─────────────────────────────────────────────────────────────
-- ÉCRAN
-- ─────────────────────────────────────────────────────────────

local gui = Instance.new("ScreenGui")
gui.Name         = "BrainrotCarryGui"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent       = player.PlayerGui

-- ─────────────────────────────────────────────────────────────
-- BOUTON PRINCIPAL (coin bas droite)
-- ─────────────────────────────────────────────────────────────

local mainBtn = Instance.new("TextButton")
mainBtn.Name                  = "CarryButton"
mainBtn.Size                  = UDim2.new(0, 160, 0, 48)
mainBtn.Position              = UDim2.new(1, -170, 1, -220)
mainBtn.AnchorPoint           = Vector2.new(0, 0)
mainBtn.BackgroundColor3      = Color3.fromRGB(20, 20, 20)
mainBtn.BackgroundTransparency = 0.2
mainBtn.BorderSizePixel       = 0
mainBtn.Text                  = "Carry 0/1"
mainBtn.TextColor3            = Color3.fromRGB(255, 255, 255)
mainBtn.TextScaled            = true
mainBtn.TextWrapped           = false
mainBtn.Font                  = Enum.Font.GothamBold
mainBtn.Parent                = gui

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 10)
uiCorner.Parent       = mainBtn

-- ─────────────────────────────────────────────────────────────
-- MENU (panneau qui s'ouvre au-dessus du bouton)
-- ─────────────────────────────────────────────────────────────

local panel = Instance.new("Frame")
panel.Name                   = "UpgradePanel"
panel.Size                   = UDim2.new(0, 220, 0, 110)
panel.Position               = UDim2.new(1, -230, 1, -345)
panel.BackgroundColor3       = Color3.fromRGB(15, 15, 15)
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel        = 0
panel.Visible                = false
panel.Parent                 = gui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 12)
panelCorner.Parent       = panel

-- Titre du panneau
local titleLabel = Instance.new("TextLabel")
titleLabel.Size                  = UDim2.new(1, 0, 0, 32)
titleLabel.Position              = UDim2.new(0, 0, 0, 8)
titleLabel.BackgroundTransparency = 1
titleLabel.Text                  = "Carry Upgrade"
titleLabel.TextColor3            = Color3.fromRGB(255, 220, 80)
titleLabel.TextScaled            = true
titleLabel.Font                  = Enum.Font.GothamBold
titleLabel.Parent                = panel

-- Info capacité actuelle
local infoLabel = Instance.new("TextLabel")
infoLabel.Size                  = UDim2.new(1, -20, 0, 24)
infoLabel.Position              = UDim2.new(0, 10, 0, 42)
infoLabel.BackgroundTransparency = 1
infoLabel.Text                  = "Capacity : 1"
infoLabel.TextColor3            = Color3.fromRGB(200, 200, 200)
infoLabel.TextScaled            = true
infoLabel.Font                  = Enum.Font.Gotham
infoLabel.Parent                = panel

-- Bouton Upgrade
local upgradeBtn = Instance.new("TextButton")
upgradeBtn.Size                  = UDim2.new(1, -20, 0, 36)
upgradeBtn.Position              = UDim2.new(0, 10, 1, -46)
upgradeBtn.BackgroundColor3      = Color3.fromRGB(50, 180, 80)
upgradeBtn.BorderSizePixel       = 0
upgradeBtn.Text                  = "Upgrade  +1 Carry  (Free)"
upgradeBtn.TextColor3            = Color3.fromRGB(255, 255, 255)
upgradeBtn.TextScaled            = true
upgradeBtn.Font                  = Enum.Font.GothamBold
upgradeBtn.Parent                = panel

local upgradeBtnCorner = Instance.new("UICorner")
upgradeBtnCorner.CornerRadius = UDim.new(0, 8)
upgradeBtnCorner.Parent       = upgradeBtn

-- ─────────────────────────────────────────────────────────────
-- NOTIFICATION D'ERREUR (centre haut)
-- ─────────────────────────────────────────────────────────────

local errorLabel = Instance.new("TextLabel")
errorLabel.Name                  = "ErrorLabel"
errorLabel.Size                  = UDim2.new(0, 380, 0, 44)
errorLabel.Position              = UDim2.new(0.5, -190, 0, 80)
errorLabel.BackgroundColor3      = Color3.fromRGB(180, 30, 30)
errorLabel.BackgroundTransparency = 0.15
errorLabel.BorderSizePixel       = 0
errorLabel.Text                  = ""
errorLabel.TextColor3            = Color3.fromRGB(255, 255, 255)
errorLabel.TextScaled            = true
errorLabel.Font                  = Enum.Font.GothamBold
errorLabel.Visible               = false
errorLabel.Parent                = gui

local errorCorner = Instance.new("UICorner")
errorCorner.CornerRadius = UDim.new(0, 10)
errorCorner.Parent       = errorLabel

-- ─────────────────────────────────────────────────────────────
-- ÉTAT LOCAL
-- ─────────────────────────────────────────────────────────────

local currentCarried = 0
local currentCapacity = 1
local menuOpen = false
local errorTween = nil

-- ─────────────────────────────────────────────────────────────
-- HELPERS
-- ─────────────────────────────────────────────────────────────

local function RefreshUI()
    mainBtn.Text = ("Carry %d/%d"):format(currentCarried, currentCapacity)
    infoLabel.Text = ("Capacity : %d"):format(currentCapacity)

    -- Couleur du bouton principal : vert si place libre, rouge si plein
    if currentCarried >= currentCapacity then
        mainBtn.BackgroundColor3 = Color3.fromRGB(120, 20, 20)
    else
        mainBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    end
end

local function ShowError(msg)
    if errorTween then errorTween:Cancel() end
    errorLabel.Text            = msg
    errorLabel.Visible         = true
    errorLabel.BackgroundTransparency = 0.15
    errorLabel.TextTransparency      = 0

    errorTween = TweenService:Create(errorLabel,
        TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 2.2),
        { BackgroundTransparency = 1, TextTransparency = 1 }
    )
    errorTween:Play()
    errorTween.Completed:Connect(function()
        errorLabel.Visible = false
    end)
end

local function SetMenuOpen(open)
    menuOpen = open
    panel.Visible = open
end

-- ─────────────────────────────────────────────────────────────
-- INTERACTIONS
-- ─────────────────────────────────────────────────────────────

mainBtn.MouseButton1Click:Connect(function()
    SetMenuOpen(not menuOpen)
end)

upgradeBtn.MouseButton1Click:Connect(function()
    UpgradeCarryEvent:FireServer()
end)

-- Fermer le menu en cliquant en dehors (clic sur le fond du ScreenGui)
gui.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if menuOpen then
            -- Ferme seulement si le clic n'est pas sur le panel ou le bouton
            SetMenuOpen(false)
        end
    end
end)
-- Empêcher la propagation depuis le panel et le bouton principal
panel.InputBegan:Connect(function(input) input:Handled() end)
mainBtn.InputBegan:Connect(function(input) input:Handled() end)

-- ─────────────────────────────────────────────────────────────
-- ÉVÉNEMENTS SERVEUR
-- ─────────────────────────────────────────────────────────────

CarryUpdateEvent.OnClientEvent:Connect(function(carried, capacity)
    currentCarried  = carried
    currentCapacity = capacity
    RefreshUI()
end)

CarryErrorEvent.OnClientEvent:Connect(function(msg)
    ShowError(msg)
end)

-- ─────────────────────────────────────────────────────────────
-- INIT
-- ─────────────────────────────────────────────────────────────

RefreshUI()
