-- StarterPlayerScripts/HUDController.client.lua
local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService     = game:GetService("TweenService")
local player           = Players.LocalPlayer
local Config           = require(ReplicatedStorage.Specialized.GameConfig)

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
local UpdateHUD = ReplicatedStorage:WaitForChild("UpdateHUD")
UpdateHUD.OnClientEvent:Connect(function(data)
    coinsLabel.Text = "💰 " .. tostring(math.floor(data.coins))
    local tier = "Tier " .. data.tier .. " / " .. Config.TotalTiers
    if data.prestige > 0 then tier = tier .. "  (P" .. data.prestige .. ")" end
    tierLabel.Text = tier
end)

-- Event démarré
local EventStarted = ReplicatedStorage:WaitForChild("EventStarted")
EventStarted.OnClientEvent:Connect(function(_, duree)
    eventFrame.Visible = true
    local t = duree
    task.spawn(function()
        while t > 0 do
            eventLabel.Text = "🔥 EVENT  " .. math.ceil(t) .. "s"
            task.wait(1) ; t = t - 1
        end
        eventFrame.Visible = false
    end)
end)

-- Offline income
local OIN = ReplicatedStorage:WaitForChild("OfflineIncomeNotif")
OIN.OnClientEvent:Connect(function(montant)
    local notif = Instance.new("TextLabel", gui)
    notif.Size                   = UDim2.new(0,320,0,60)
    notif.Position               = UDim2.new(0.5,-160,0.5,-30)
    notif.BackgroundColor3       = Color3.fromRGB(0,150,0)
    notif.BackgroundTransparency = 0.1
    notif.TextColor3             = Color3.fromRGB(255,255,255)
    notif.TextScaled             = true
    notif.Font                   = Enum.Font.GothamBold
    notif.Text                   = "💤 Offline : +" .. montant .. " coins !"
    TweenService:Create(notif, TweenInfo.new(3),
        { Position = UDim2.new(0.5,-160,0.3,0) }):Play()
    task.delay(4, function() notif:Destroy() end)
end)

-- Collect VFX
local CollectVFX = ReplicatedStorage:WaitForChild("CollectVFX")
CollectVFX.OnClientEvent:Connect(function(montant, rarete)
    local popup = Instance.new("TextLabel", gui)
    popup.Size                   = UDim2.new(0,150,0,40)
    popup.Position               = UDim2.new(math.random(30,70)/100,-75, math.random(30,70)/100,-20)
    popup.BackgroundTransparency = 1
    popup.TextColor3             = rarete and rarete.couleur or Color3.fromRGB(255,255,255)
    popup.TextStrokeTransparency = 0
    popup.TextScaled             = true
    popup.Font                   = Enum.Font.GothamBold
    popup.Text                   = "+" .. montant
    TweenService:Create(popup, TweenInfo.new(1.5),
        { Position = UDim2.new(popup.Position.X.Scale, -75, popup.Position.Y.Scale - 0.1, -20),
          TextTransparency = 1 }):Play()
    task.delay(1.5, function() popup:Destroy() end)
end)
