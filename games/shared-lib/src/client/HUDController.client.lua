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
EventStarted.OnClientEvent:Connect(function(typeEvent, duree)
    eventFrame.Visible = true
    local nomAffiche = typeEvent or "EVENT"
    local t = duree
    task.spawn(function()
        while t > 0 do
            eventLabel.Text = "🔥 " .. nomAffiche .. "  " .. math.ceil(t) .. "s"
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

-- ============================================================
-- Effets visuels events
-- ============================================================

-- NightMode : flash noir
task.spawn(function()
    local NightModeStart = ReplicatedStorage:WaitForChild("NightModeStart", 15)
    if not NightModeStart then return end
    NightModeStart.OnClientEvent:Connect(function()
        local flash = Instance.new("Frame", gui)
        flash.Size                    = UDim2.new(1, 0, 1, 0)
        flash.BackgroundColor3        = Color3.new(0, 0, 0)
        flash.BackgroundTransparency  = 0
        flash.BorderSizePixel         = 0
        flash.ZIndex                  = 10
        -- Fade in rapide (0.3s) puis fade out (0.5s)
        TweenService:Create(flash, TweenInfo.new(0.3), { BackgroundTransparency = 0 }):Play()
        task.wait(0.35)
        TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
        task.delay(0.9, function() flash:Destroy() end)
    end)
end)

-- MeteorImpact : shake caméra selon distance au joueur
task.spawn(function()
    local MeteorImpact = ReplicatedStorage:WaitForChild("MeteorImpact", 15)
    if not MeteorImpact then return end
    local camera = workspace.CurrentCamera
    MeteorImpact.OnClientEvent:Connect(function(impactPos)
        if not camera or not player.Character then return end
        local hrp = player.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        -- Intensité diminue avec la distance
        local dist      = (hrp.Position - Vector3.new(impactPos.X, hrp.Position.Y, impactPos.Z)).Magnitude
        local intensite = math.clamp(1 - dist / 200, 0, 1)
        if intensite < 0.05 then return end

        task.spawn(function()
            local cameraOffset = Vector3.new(0, 0, 0)
            local infoShake    = TweenInfo.new(0.05, Enum.EasingStyle.Quad)
            for i = 1, 8 do
                if not camera then break end
                local amplitude = intensite * 0.5 * (1 - i / 10)
                cameraOffset = Vector3.new(
                    math.random(-100, 100) / 100 * amplitude,
                    math.random(-100, 100) / 100 * amplitude,
                    0
                )
                pcall(function()
                    camera.CFrame = camera.CFrame * CFrame.new(cameraOffset)
                end)
                task.wait(0.05)
            end
        end)
    end)
end)

-- GoldenStart : flash doré + texte ×5
task.spawn(function()
    local GoldenStart = ReplicatedStorage:WaitForChild("GoldenStart", 15)
    if not GoldenStart then return end
    GoldenStart.OnClientEvent:Connect(function()
        -- Flash doré
        local flash = Instance.new("Frame", gui)
        flash.Size                   = UDim2.new(1, 0, 1, 0)
        flash.BackgroundColor3       = Color3.fromRGB(255, 200, 0)
        flash.BackgroundTransparency = 0.3
        flash.BorderSizePixel        = 0
        flash.ZIndex                 = 10
        TweenService:Create(flash, TweenInfo.new(0.3),  { BackgroundTransparency = 0.3 }):Play()
        task.wait(0.35)
        TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
        task.delay(0.9, function() flash:Destroy() end)

        -- Texte ×5 flottant au centre
        local texte = Instance.new("TextLabel", gui)
        texte.Size                   = UDim2.new(0, 300, 0, 70)
        texte.Position               = UDim2.new(0.5, -150, 0.5, -35)
        texte.BackgroundTransparency = 1
        texte.TextColor3             = Color3.fromRGB(255, 215, 0)
        texte.TextStrokeTransparency = 0
        texte.TextStrokeColor3       = Color3.fromRGB(100, 60, 0)
        texte.TextScaled             = true
        texte.Font                   = Enum.Font.GothamBold
        texte.Text                   = "✨ ×5 GOLDEN !"
        texte.ZIndex                 = 11
        TweenService:Create(texte, TweenInfo.new(2),
            { Position = UDim2.new(0.5, -150, 0.35, -35), TextTransparency = 1 }
        ):Play()
        task.delay(2.1, function() texte:Destroy() end)
    end)
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


-- ============================================================
-- Notifications générales (NotifEvent)
-- ============================================================
local NotifEvent = game.ReplicatedStorage:WaitForChild("NotifEvent")

-- Couleurs par type de notification
local NOTIF_COULEURS = {
    INFO    = Color3.fromRGB(0, 150, 255),
    SUCCESS = Color3.fromRGB(0, 200, 0),
    ERROR   = Color3.fromRGB(255, 50, 50),
    WARNING = Color3.fromRGB(255, 165, 0),
}

-- Label réutilisable (créé une seule fois)
local notifLabel = Instance.new("TextLabel", gui)
notifLabel.Name                   = "NotifLabel"
notifLabel.Size                   = UDim2.new(0, 400, 0, 50)
notifLabel.Position               = UDim2.new(0.5, -200, 0, 20)
notifLabel.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
notifLabel.BackgroundTransparency = 0.3
notifLabel.TextColor3             = Color3.fromRGB(255, 255, 255)
notifLabel.Font                   = Enum.Font.GothamBold
notifLabel.TextSize               = 16
notifLabel.RichText               = true
notifLabel.BorderSizePixel        = 0
notifLabel.Visible                = false
notifLabel.ZIndex                 = 20
local notifCorner = Instance.new("UICorner", notifLabel)
notifCorner.CornerRadius = UDim.new(0, 8)

local notifMasque = false  -- empêche les chevauchements

NotifEvent.OnClientEvent:Connect(function(typeNotif, message)
    if not message then return end

    -- Couleur selon le type
    notifLabel.BackgroundColor3 = NOTIF_COULEURS[typeNotif] or Color3.fromRGB(0, 0, 0)
    notifLabel.Text             = message
    notifLabel.Visible          = true

    -- Annuler le masquage précédent puis masquer après 3s
    notifMasque = false
    task.delay(3, function()
        if not notifMasque then
            notifLabel.Visible = false
        end
    end)
    notifMasque = true
end)

print("[HUDController] NotifEvent connecté ✓")
