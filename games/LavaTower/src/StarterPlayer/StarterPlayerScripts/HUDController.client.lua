-- StarterPlayerScripts/HUDController.client.lua
local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService     = game:GetService("TweenService")
local player           = Players.LocalPlayer
local Config           = require(ReplicatedStorage.Modules.GameConfig)

local gui = Instance.new("ScreenGui")
gui.Name          = "HUD"
gui.ResetOnSpawn  = false
gui.Parent        = player.PlayerGui

local function NouveauLabel(parent, size, pos, bgColor, textColor, text)
    local f = Instance.new("Frame", parent)
    f.Size                    = size
    f.Position                = pos
    f.BackgroundColor3        = bgColor
    f.BackgroundTransparency  = 0.3
    f.BorderSizePixel         = 0
    local l = Instance.new("TextLabel", f)
    l.Size                    = UDim2.new(1,0,1,0)
    l.BackgroundTransparency  = 1
    l.TextColor3              = textColor
    l.TextScaled              = true
    l.Font                    = Enum.Font.GothamBold
    l.Text                    = text
    return f, l
end

-- Coins
local _, coinsLabel = NouveauLabel(gui,
    UDim2.new(0,220,0,50), UDim2.new(0,10,0,10),
    Color3.fromRGB(0,0,0), Config.CouleurAccent, "0")

-- Tier
local _, tierLabel = NouveauLabel(gui,
    UDim2.new(0,220,0,40), UDim2.new(0,10,0,65),
    Color3.fromRGB(0,0,0), Color3.fromRGB(255,255,255), "Tier 0")

-- Event banner
local eventFrame, eventLabel = NouveauLabel(gui,
    UDim2.new(0,320,0,55), UDim2.new(0.5,-160,0,10),
    Color3.fromRGB(200,50,0), Color3.fromRGB(255,255,255), "")
eventFrame.Visible = false

-- Mise à jour HUD
local UpdateHUD = ReplicatedStorage:WaitForChild("UpdateHUD", 15)
if not UpdateHUD then warn("[HUD] UpdateHUD introuvable — Main.server.lua a crashé ?") return end
UpdateHUD.OnClientEvent:Connect(function(data)
    coinsLabel.Text = tostring(math.floor(data.coins))
    local tier = "Tier " .. data.tier .. " / " .. Config.TotalTiers
    if data.prestige > 0 then tier = tier .. "  (P" .. data.prestige .. ")" end
    tierLabel.Text = tier
end)

-- Inventaire brainrot
local brainrotFrame, brainrotLabel = NouveauLabel(gui,
    UDim2.new(0, 280, 0, 50), UDim2.new(0, 10, 0, 112),
    Color3.fromRGB(80, 0, 120), Color3.fromRGB(255, 200, 255), "")
brainrotFrame.Visible = false

local evtPickedUp = ReplicatedStorage:WaitForChild("BrainrotPickedUp", 15)
local evtDropped  = ReplicatedStorage:WaitForChild("BrainrotDropped",  15)

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

-- ============================================================
-- Bouton "Escape the Tower" (visible uniquement dans la tour)
-- ============================================================
local ORANGE = Color3.fromRGB(220, 120, 0)

local escapeFrame = Instance.new("Frame", gui)
escapeFrame.Size                   = UDim2.new(0, 170, 0, 50)
escapeFrame.Position               = UDim2.new(1, -180, 0.5, -25)
escapeFrame.BackgroundColor3       = ORANGE
escapeFrame.BackgroundTransparency = 0.15
escapeFrame.BorderSizePixel        = 0
escapeFrame.Visible                = false
local escapeCorner = Instance.new("UICorner", escapeFrame)
escapeCorner.CornerRadius = UDim.new(0, 8)

local escapeButton = Instance.new("TextButton", escapeFrame)
escapeButton.Size                   = UDim2.new(1, 0, 1, 0)
escapeButton.BackgroundTransparency = 1
escapeButton.TextColor3             = Color3.fromRGB(255, 255, 255)
escapeButton.TextScaled             = true
escapeButton.Font                   = Enum.Font.GothamBold
escapeButton.Text                   = "Escape the Tower"

-- Countdown affiché en haut au centre
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

local EscapeTowerRE  = ReplicatedStorage:WaitForChild("EscapeTower",  15)
local TowerEnteredRE = ReplicatedStorage:WaitForChild("TowerEntered", 15)
local TowerExitedRE  = ReplicatedStorage:WaitForChild("TowerExited",  15)

local countdownActive = false

local function resetEscape()
    countdownActive       = false
    countdownFrame.Visible = false
    escapeFrame.Visible    = false
end

if TowerEnteredRE then
    TowerEnteredRE.OnClientEvent:Connect(function()
        countdownActive = false
        countdownFrame.Visible = false
        escapeFrame.Visible    = true
    end)
end

if TowerExitedRE then
    TowerExitedRE.OnClientEvent:Connect(function()
        resetEscape()
    end)
end

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
