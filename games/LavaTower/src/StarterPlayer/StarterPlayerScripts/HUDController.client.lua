-- StarterPlayerScripts/HUDController.client.lua
-- HUD LavaTower

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local player            = Players.LocalPlayer
local FormatNumber      = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("FormatNumber"))

-- Palette
local C = {
    PanelBg  = Color3.fromRGB(10,  10,  10),
    Bordure  = Color3.fromRGB(60,  60,  60),
    Accent   = Color3.fromRGB(160, 80,  15),
    TextPrim = Color3.fromRGB(220, 220, 220),
    TextSec  = Color3.fromRGB(130, 130, 130),
}

local gui = Instance.new("ScreenGui")
gui.Name          = "HUD"
gui.ResetOnSpawn  = false
gui.Parent        = player.PlayerGui

-- Coins (bas gauche)
local coinsLabel = Instance.new("TextLabel", gui)
coinsLabel.Size                   = UDim2.new(0, 260, 0, 60)
coinsLabel.Position               = UDim2.new(0, 10, 1, -70)
coinsLabel.BackgroundTransparency = 1
coinsLabel.Text                   = "0"
coinsLabel.TextColor3             = C.Accent
coinsLabel.TextStrokeColor3       = Color3.fromRGB(255, 255, 255)
coinsLabel.TextStrokeTransparency = 0
coinsLabel.TextScaled             = false
coinsLabel.TextSize               = 36
coinsLabel.Font                   = Enum.Font.GothamBold
coinsLabel.TextXAlignment         = Enum.TextXAlignment.Left

-- Banniere evenement (haut centre, cachee par defaut)
local eventFrame  = Instance.new("Frame", gui)
eventFrame.Size                   = UDim2.new(0, 320, 0, 50)
eventFrame.Position               = UDim2.new(0.5, -160, 0, 10)
eventFrame.BackgroundColor3       = C.PanelBg
eventFrame.BackgroundTransparency = 0.05
eventFrame.BorderSizePixel        = 0
eventFrame.Visible                = false
local evtCorner = Instance.new("UICorner", eventFrame)
evtCorner.CornerRadius = UDim.new(0, 0)
local evtStroke = Instance.new("UIStroke", eventFrame)
evtStroke.Color     = C.Bordure
evtStroke.Thickness = 1
local eventLabel = Instance.new("TextLabel", eventFrame)
eventLabel.Size                   = UDim2.new(1, 0, 1, 0)
eventLabel.BackgroundTransparency = 1
eventLabel.TextColor3             = C.TextPrim
eventLabel.TextScaled             = false
eventLabel.TextSize               = 15
eventLabel.Font                   = Enum.Font.GothamBold
eventLabel.Text                   = ""

-- Mise a jour HUD
local UpdateHUD = ReplicatedStorage:WaitForChild("UpdateHUD", 15)
if not UpdateHUD then warn("[HUD] UpdateHUD introuvable -- Main.server.lua a crashe ?") return end

UpdateHUD.OnClientEvent:Connect(function(data)
    coinsLabel.Text = FormatNumber.format(data.coins)
end)

-- Inventaire Brainrot (bas gauche, au-dessus des coins)
local brainrotFrame = Instance.new("Frame", gui)
brainrotFrame.Size                   = UDim2.new(0, 280, 0, 50)
brainrotFrame.Position               = UDim2.new(0, 10, 1, -116)
brainrotFrame.BackgroundColor3       = C.PanelBg
brainrotFrame.BackgroundTransparency = 0.05
brainrotFrame.BorderSizePixel        = 0
brainrotFrame.Visible                = false
local brCorner = Instance.new("UICorner", brainrotFrame)
brCorner.CornerRadius = UDim.new(0, 0)
local brStroke = Instance.new("UIStroke", brainrotFrame)
brStroke.Color     = C.Bordure
brStroke.Thickness = 1
local brainrotLabel = Instance.new("TextLabel", brainrotFrame)
brainrotLabel.Size                   = UDim2.new(1, 0, 1, 0)
brainrotLabel.BackgroundTransparency = 1
brainrotLabel.TextColor3             = Color3.fromRGB(200, 160, 255)
brainrotLabel.TextScaled             = false
brainrotLabel.TextSize               = 13
brainrotLabel.Font                   = Enum.Font.GothamBold
brainrotLabel.Text                   = ""

local evtPickedUp = ReplicatedStorage:FindFirstChild("BrainrotPickedUp")
local evtDropped  = ReplicatedStorage:FindFirstChild("BrainrotDropped")

if evtPickedUp then
    evtPickedUp.OnClientEvent:Connect(function(nom, rarete)
        brainrotLabel.Text    = "Brainrot : " .. nom .. " (" .. rarete .. ")"
        brainrotFrame.Visible = true
    end)
end

if evtDropped then
    evtDropped.OnClientEvent:Connect(function()
        brainrotFrame.Visible = false
    end)
end

-- Bouton Escape the Tower (droite ecran)
local ORANGE = Color3.fromRGB(160, 80, 15)

local escapeFrame = Instance.new("Frame", gui)
escapeFrame.Size                   = UDim2.new(0, 170, 0, 50)
escapeFrame.Position               = UDim2.new(1, -180, 0.5, -25)
escapeFrame.BackgroundColor3       = ORANGE
escapeFrame.BackgroundTransparency = 0.05
escapeFrame.BorderSizePixel        = 0
escapeFrame.Visible                = false

local escCorner = Instance.new("UICorner", escapeFrame)
escCorner.CornerRadius = UDim.new(0, 2)

local escStroke = Instance.new("UIStroke", escapeFrame)
escStroke.Color     = Color3.fromRGB(60, 60, 60)
escStroke.Thickness = 1

local escapeButton = Instance.new("TextButton", escapeFrame)
escapeButton.Size                   = UDim2.new(1, 0, 1, 0)
escapeButton.BackgroundTransparency = 1
escapeButton.TextColor3             = Color3.fromRGB(220, 220, 220)
escapeButton.TextScaled             = false
escapeButton.TextSize               = 15
escapeButton.Font                   = Enum.Font.GothamBold
escapeButton.Text                   = "Escape the Tower"

-- Countdown (haut centre pendant l'escape)
local countdownFrame = Instance.new("Frame", gui)
countdownFrame.Size                   = UDim2.new(0, 200, 0, 60)
countdownFrame.Position               = UDim2.new(0.5, -100, 0, 20)
countdownFrame.BackgroundTransparency = 1
countdownFrame.BorderSizePixel        = 0
countdownFrame.Visible                = false

local countdownLabel = Instance.new("TextLabel", countdownFrame)
countdownLabel.Size                   = UDim2.new(1, 0, 1, 0)
countdownLabel.BackgroundTransparency = 1
countdownLabel.TextColor3             = ORANGE
countdownLabel.TextStrokeColor3       = Color3.fromRGB(255, 255, 255)
countdownLabel.TextStrokeTransparency = 0
countdownLabel.TextScaled             = false
countdownLabel.TextSize               = 42
countdownLabel.Font                   = Enum.Font.GothamBold
countdownLabel.Text                   = "3"

-- Connexions RemoteEvents tour
local EscapeTowerRE  = ReplicatedStorage:WaitForChild("EscapeTower",  15)
local TowerEnteredRE = ReplicatedStorage:WaitForChild("TowerEntered", 15)
local TowerExitedRE  = ReplicatedStorage:WaitForChild("TowerExited",  15)

local countdownActive = false

local function resetEscape()
    countdownActive        = false
    countdownFrame.Visible = false
    escapeFrame.Visible    = false
end

if TowerEnteredRE then
    TowerEnteredRE.OnClientEvent:Connect(function()
        countdownActive        = false
        countdownFrame.Visible = false
        escapeFrame.Visible    = true
    end)
end

if TowerExitedRE then
    TowerExitedRE.OnClientEvent:Connect(function()
        resetEscape()
    end)
end

if player:GetAttribute("InTower") then
    escapeFrame.Visible = true
end
player:GetAttributeChangedSignal("InTower"):Connect(function()
    if player:GetAttribute("InTower") then
        countdownActive        = false
        countdownFrame.Visible = false
        escapeFrame.Visible    = true
    else
        resetEscape()
    end
end)

if EscapeTowerRE then
    escapeButton.Activated:Connect(function()
        if countdownActive then return end
        countdownActive        = true
        escapeFrame.Visible    = false
        countdownFrame.Visible = true

        task.spawn(function()
            for t = 3, 1, -1 do
                if not countdownActive then return end
                countdownLabel.Text = tostring(t)
                task.wait(1)
            end
            if not countdownActive then return end
            countdownFrame.Visible = false
            countdownActive        = false
            EscapeTowerRE:FireServer()
        end)
    end)
end
