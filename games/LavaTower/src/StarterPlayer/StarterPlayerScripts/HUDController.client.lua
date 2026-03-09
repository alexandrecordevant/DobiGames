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
    Color3.fromRGB(0,0,0), Config.CouleurAccent, "💰 0")

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
    coinsLabel.Text = "💰 " .. tostring(math.floor(data.coins))
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
