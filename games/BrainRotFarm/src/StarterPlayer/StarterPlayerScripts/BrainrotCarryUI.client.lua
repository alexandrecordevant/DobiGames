-- StarterPlayerScripts/BrainrotCarryUI.client.lua
-- DobiGames BrainRotFarm — UI : jauge de portage
-- Écoute BrainrotCarryUpdate { carried, capacity } et BrainrotCarryError { message }.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local Logger            = require(ReplicatedStorage.SharedLib.Logger)
local ModalManager      = require(ReplicatedStorage.SharedLib.ModalManager)

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
mainBtn.TextColor3             = Color3.fromRGB(220, 220, 220)
mainBtn.TextScaled             = false
mainBtn.TextSize               = 28
mainBtn.TextWrapped            = false
mainBtn.RichText               = false
mainBtn.Font                   = Enum.Font.GothamBold
mainBtn.Visible                = false
mainBtn.Parent                 = gui

local mainBtnStroke = Instance.new("UIStroke")
mainBtnStroke.Color     = Color3.new(0, 0, 0)
mainBtnStroke.Thickness = 2
mainBtnStroke.Parent    = mainBtn

-- ─────────────────────────────────────────────────────────────
-- MENU (panneau qui s'ouvre au-dessus du bouton)
-- ─────────────────────────────────────────────────────────────

local panel = Instance.new("Frame")
panel.Name                   = "UpgradePanel"
panel.Size                   = UDim2.new(0, 220, 0, 110)
panel.Position               = UDim2.new(0, 10, 0, 168)
panel.BackgroundColor3       = Color3.fromRGB(10, 10, 10)
panel.BackgroundTransparency = 0.05
panel.BorderSizePixel        = 0
panel.Visible                = false
panel.Parent                 = gui

local _panelCorner = Instance.new("UICorner")
_panelCorner.CornerRadius = UDim.new(0, 2)
_panelCorner.Parent       = panel
local _panelStroke = Instance.new("UIStroke", panel)
_panelStroke.Color = Color3.fromRGB(60, 60, 60) ; _panelStroke.Thickness = 1

local titleLabel = Instance.new("TextLabel")
titleLabel.Size                   = UDim2.new(1, 0, 0, 28)
titleLabel.Position               = UDim2.new(0, 10, 0, 6)
titleLabel.BackgroundTransparency = 1
titleLabel.Text                   = "Carry Upgrade"
titleLabel.TextColor3             = Color3.fromRGB(220, 220, 220)
titleLabel.TextScaled             = false
titleLabel.TextSize               = 14
titleLabel.Font                   = Enum.Font.GothamBold
titleLabel.TextXAlignment         = Enum.TextXAlignment.Left
titleLabel.Parent                 = panel

local infoLabel = Instance.new("TextLabel")
infoLabel.Size                   = UDim2.new(1, -20, 0, 18)
infoLabel.Position               = UDim2.new(0, 10, 0, 36)
infoLabel.BackgroundTransparency = 1
infoLabel.Text                   = "Capacity : 1"
infoLabel.TextColor3             = Color3.fromRGB(130, 130, 130)
infoLabel.TextScaled             = false
infoLabel.TextSize               = 11
infoLabel.Font                   = Enum.Font.Gotham
infoLabel.TextXAlignment         = Enum.TextXAlignment.Left
infoLabel.Parent                 = panel

local upgradeBtn = Instance.new("TextButton")
upgradeBtn.Size                  = UDim2.new(1, -20, 0, 32)
upgradeBtn.Position              = UDim2.new(0, 10, 1, -42)
upgradeBtn.BackgroundColor3      = Color3.fromRGB(80, 140, 80)
upgradeBtn.BorderSizePixel       = 0
upgradeBtn.Text                  = "Upgrade  +1 Carry"
upgradeBtn.TextColor3            = Color3.fromRGB(220, 220, 220)
upgradeBtn.TextScaled            = false
upgradeBtn.TextSize              = 12
upgradeBtn.Font                  = Enum.Font.GothamBold
upgradeBtn.Parent                = panel
local _upCorner = Instance.new("UICorner", upgradeBtn)
_upCorner.CornerRadius = UDim.new(0, 2)
local _upStroke = Instance.new("UIStroke", upgradeBtn)
_upStroke.Color = Color3.fromRGB(60, 60, 60) ; _upStroke.Thickness = 1

-- ─────────────────────────────────────────────────────────────
-- NOTIFICATION D'ERREUR (centre haut)
-- ─────────────────────────────────────────────────────────────

local errorLabel = Instance.new("TextLabel")
errorLabel.Name                   = "ErrorLabel"
errorLabel.Size                   = UDim2.new(0, 380, 0, 44)
errorLabel.Position               = UDim2.new(0.5, -190, 0, 80)
errorLabel.BackgroundColor3       = Color3.fromRGB(140, 70, 70)
errorLabel.BackgroundTransparency = 0.1
errorLabel.BorderSizePixel        = 0
errorLabel.Text                   = ""
errorLabel.TextColor3             = Color3.fromRGB(220, 220, 220)
errorLabel.TextScaled             = false
errorLabel.TextSize               = 13
errorLabel.Font                   = Enum.Font.GothamBold
errorLabel.Visible                = false
errorLabel.Parent                 = gui
Instance.new("UICorner", errorLabel).CornerRadius = UDim.new(0, 2)

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
	mainBtn.Text       = ("Carry %d/%d"):format(currentCarried, currentCapacity)
	mainBtn.TextColor3 = full and Color3.fromRGB(220, 110, 15) or Color3.fromRGB(220, 220, 220)
	infoLabel.Text     = ("Capacity : %d"):format(currentCapacity)
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

-- Masquer le HUD inventaire quand une modale est ouverte
ModalManager.OnModalStateChanged:Connect(function(isAnyOpen)
	gui.Enabled = not isAnyOpen
end)

-- Remettre le HUD visible au respawn et vider les modales enregistrées
player.CharacterAdded:Connect(function()
	ModalManager.Reset()
end)

Logger.info("Carry", "BrainrotCarryUI initialisé")
