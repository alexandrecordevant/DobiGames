-- StarterPlayerScripts/BrainrotCarryUI.client.lua
-- DobiGames BrainRotFarm — UI : jauge de portage
-- Écoute BrainrotCarryUpdate { carried, capacity } et BrainrotCarryError { message }.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local Logger            = require(ReplicatedStorage.SharedLib.Logger)

local player = Players.LocalPlayer

-- Attente des RemoteEvents créés par CarrySystem.Init()
local CarryUpdateEvent  = ReplicatedStorage:WaitForChild("BrainrotCarryUpdate", 15)
local CarryErrorEvent   = ReplicatedStorage:WaitForChild("BrainrotCarryError",  15)
local UpgradeCarryEvent = ReplicatedStorage:FindFirstChild("BrainrotUpgradeCarry")

if not CarryUpdateEvent or not CarryErrorEvent then
	Logger.warn("Carry", "BrainrotCarryUpdate/Error introuvables — CarryUI désactivé")
	return
end

-- ─────────────────────────────────────────────────────────────
-- ÉCRAN
-- ─────────────────────────────────────────────────────────────

local gui = Instance.new("ScreenGui")
gui.Name           = "BrainrotCarryGui"
gui.ResetOnSpawn   = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent         = player.PlayerGui

-- ─────────────────────────────────────────────────────────────
-- BOUTON PRINCIPAL (coin bas droite)
-- ─────────────────────────────────────────────────────────────

local mainBtn = Instance.new("TextButton")
mainBtn.Name                   = "CarryButton"
mainBtn.Size                   = UDim2.new(0, 220, 0, 40)
mainBtn.Position               = UDim2.new(0, 10, 0, 110)
mainBtn.AnchorPoint            = Vector2.new(0, 0)
mainBtn.BackgroundTransparency = 1
mainBtn.BorderSizePixel        = 0
mainBtn.Text                   = "Carry 0/1"
mainBtn.TextColor3             = Color3.fromRGB(255, 255, 255)
mainBtn.TextScaled             = false
mainBtn.TextSize               = 28
mainBtn.TextWrapped            = false
mainBtn.RichText               = false
mainBtn.Font                   = Enum.Font.GothamBold
mainBtn.Parent                 = gui

local mainBtnStroke = Instance.new("UIStroke")
mainBtnStroke.Color     = Color3.new(0, 0, 0)
mainBtnStroke.Thickness = 2
mainBtnStroke.Parent    = mainBtn

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 10)
uiCorner.Parent       = mainBtn

-- ─────────────────────────────────────────────────────────────
-- MENU (panneau qui s'ouvre au-dessus du bouton)
-- ─────────────────────────────────────────────────────────────

local panel = Instance.new("Frame")
panel.Name                   = "UpgradePanel"
panel.Size                   = UDim2.new(0, 220, 0, 110)
panel.Position               = UDim2.new(0, 10, 0, 168)
panel.BackgroundColor3       = Color3.fromRGB(15, 15, 15)
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel        = 0
panel.Visible                = false
panel.Parent                 = gui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 12)
panelCorner.Parent       = panel

local titleLabel = Instance.new("TextLabel")
titleLabel.Size                   = UDim2.new(1, 0, 0, 32)
titleLabel.Position               = UDim2.new(0, 0, 0, 8)
titleLabel.BackgroundTransparency = 1
titleLabel.Text                   = "Carry Upgrade"
titleLabel.TextColor3             = Color3.fromRGB(255, 220, 80)
titleLabel.TextScaled             = true
titleLabel.Font                   = Enum.Font.GothamBold
titleLabel.Parent                 = panel

local infoLabel = Instance.new("TextLabel")
infoLabel.Size                   = UDim2.new(1, -20, 0, 24)
infoLabel.Position               = UDim2.new(0, 10, 0, 42)
infoLabel.BackgroundTransparency = 1
infoLabel.Text                   = "Capacity : 1"
infoLabel.TextColor3             = Color3.fromRGB(200, 200, 200)
infoLabel.TextScaled             = true
infoLabel.Font                   = Enum.Font.Gotham
infoLabel.Parent                 = panel

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
errorLabel.Name                   = "ErrorLabel"
errorLabel.Size                   = UDim2.new(0, 380, 0, 44)
errorLabel.Position               = UDim2.new(0.5, -190, 0, 80)
errorLabel.BackgroundColor3       = Color3.fromRGB(180, 30, 30)
errorLabel.BackgroundTransparency = 0.15
errorLabel.BorderSizePixel        = 0
errorLabel.Text                   = ""
errorLabel.TextColor3             = Color3.fromRGB(255, 255, 255)
errorLabel.TextScaled             = true
errorLabel.Font                   = Enum.Font.GothamBold
errorLabel.Visible                = false
errorLabel.Parent                 = gui

local errorCorner = Instance.new("UICorner")
errorCorner.CornerRadius = UDim.new(0, 10)
errorCorner.Parent       = errorLabel

-- ─────────────────────────────────────────────────────────────
-- ÉTAT LOCAL
-- ─────────────────────────────────────────────────────────────

local currentCarried  = 0
local currentCapacity = 1
local menuOpen        = false
local errorTween      = nil
local errorTweenConn  = nil

-- ─────────────────────────────────────────────────────────────
-- HELPERS
-- ─────────────────────────────────────────────────────────────

local function RefreshUI()
	local full = currentCarried >= currentCapacity
	mainBtn.Text      = ("Carry %d/%d"):format(currentCarried, currentCapacity)
	mainBtn.TextColor3 = full and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(255, 220, 80)
	infoLabel.Text    = ("Capacity : %d"):format(currentCapacity)
end

local function ShowError(msg)
	if errorTween     then errorTween:Cancel() end
	if errorTweenConn then errorTweenConn:Disconnect(); errorTweenConn = nil end

	errorLabel.Text                   = msg
	errorLabel.Visible                = true
	errorLabel.BackgroundTransparency = 0.15
	errorLabel.TextTransparency       = 0

	errorTween = TweenService:Create(errorLabel,
		TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 2.2),
		{ BackgroundTransparency = 1, TextTransparency = 1 }
	)
	errorTween:Play()
	errorTweenConn = errorTween.Completed:Connect(function()
		errorLabel.Visible = false
		errorTweenConn     = nil
	end)
end

local function SetMenuOpen(open)
	menuOpen      = open
	panel.Visible = open
end

-- ─────────────────────────────────────────────────────────────
-- INTERACTIONS
-- ─────────────────────────────────────────────────────────────

mainBtn.MouseButton1Click:Connect(function()
	SetMenuOpen(not menuOpen)
end)

upgradeBtn.MouseButton1Click:Connect(function()
	if UpgradeCarryEvent then
		UpgradeCarryEvent:FireServer()
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if menuOpen then SetMenuOpen(false) end
	end
end)

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
Logger.info("Carry", "BrainrotCarryUI initialisé")
