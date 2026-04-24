-- StarterPlayerScripts/RainWeatherClient.client.lua
-- BrainRotFarm — Effets visuels pluie côté client
-- Blur + ColorCorrection + son ambiant + flash éclair
-- (les particules pluie viennent du Rain model et des Cloud server-side)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local SoundService      = game:GetService("SoundService")
local Lighting          = game:GetService("Lighting")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local rainCfg    = (GameConfig.EventsVisuels and GameConfig.EventsVisuels.Rain) or {}

-- ============================================================
-- État
-- ============================================================
local actif       = false
local rainSound   = nil
local blurEffect  = nil
local colorEffect = nil
local autoCleanup = nil

-- ============================================================
-- Effets Lighting (blur + légère désaturation)
-- ============================================================
local function activerEffetsLighting()
    blurEffect        = Instance.new("BlurEffect")
    blurEffect.Size   = 0
    blurEffect.Parent = Lighting
    TweenService:Create(blurEffect, TweenInfo.new(2), { Size = 2 }):Play()

    colorEffect            = Instance.new("ColorCorrectionEffect")
    colorEffect.Saturation = 0
    colorEffect.Brightness = 0
    colorEffect.Contrast   = 0
    colorEffect.Parent     = Lighting
    TweenService:Create(colorEffect, TweenInfo.new(2), {
        Saturation = -0.25,
        Brightness = -0.04,
        Contrast   = 0.04,
    }):Play()
end

local function desactiverEffetsLighting()
    if blurEffect then
        local b = blurEffect ; blurEffect = nil
        TweenService:Create(b, TweenInfo.new(2), { Size = 0 }):Play()
        task.delay(2.2, function() if b and b.Parent then b:Destroy() end end)
    end
    if colorEffect then
        local c = colorEffect ; colorEffect = nil
        TweenService:Create(c, TweenInfo.new(2), {
            Saturation = 0, Brightness = 0, Contrast = 0,
        }):Play()
        task.delay(2.2, function() if c and c.Parent then c:Destroy() end end)
    end
end

-- ============================================================
-- Son ambiant pluie
-- ============================================================
local function demarrerSon()
    local sid = rainCfg.soundIdRain or 0
    if sid == 0 then return end
    rainSound                    = Instance.new("Sound")
    rainSound.SoundId            = "rbxassetid://" .. sid
    rainSound.Volume             = 0
    rainSound.Looped             = true
    rainSound.RollOffMaxDistance = 0
    rainSound.Parent             = SoundService
    rainSound:Play()
    TweenService:Create(rainSound, TweenInfo.new(2), { Volume = 0.5 }):Play()
end

local function arreterSon()
    if not rainSound then return end
    local s = rainSound ; rainSound = nil
    TweenService:Create(s, TweenInfo.new(2), { Volume = 0 }):Play()
    task.delay(2.2, function() if s and s.Parent then s:Destroy() end end)
end

-- ============================================================
-- Cleanup
-- ============================================================
local function cleanup()
    if not actif then return end
    actif = false
    if autoCleanup then task.cancel(autoCleanup) ; autoCleanup = nil end
    arreterSon()
    desactiverEffetsLighting()
end

-- ============================================================
-- Éclair : double flash + tonnerre
-- ============================================================
local function jouerEclair()
    local flash        = Instance.new("ColorCorrectionEffect")
    flash.Brightness   = 2.5
    flash.Parent       = Lighting
    TweenService:Create(flash, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Brightness = 0,
    }):Play()
    task.delay(0.18, function() if flash and flash.Parent then flash:Destroy() end end)

    task.delay(0.1, function()
        local flash2      = Instance.new("ColorCorrectionEffect")
        flash2.Brightness = 0.8
        flash2.Parent     = Lighting
        TweenService:Create(flash2, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Brightness = 0,
        }):Play()
        task.delay(0.25, function() if flash2 and flash2.Parent then flash2:Destroy() end end)
    end)

    local thunder                    = Instance.new("Sound")
    thunder.SoundId                  = "rbxassetid://6042503798"
    thunder.Volume                   = 0.7
    thunder.RollOffMaxDistance       = 0
    thunder.Parent                   = SoundService
    thunder:Play()
    task.delay(5, function() if thunder and thunder.Parent then thunder:Destroy() end end)
end

-- ============================================================
-- Écoute des RemoteEvents
-- ============================================================
local reStart = ReplicatedStorage:WaitForChild("RainEventStart", 10)
if reStart then
    reStart.OnClientEvent:Connect(function(duree)
        if actif then cleanup() end
        actif = true
        activerEffetsLighting()
        demarrerSon()
        if autoCleanup then task.cancel(autoCleanup) end
        autoCleanup = task.delay((tonumber(duree) or 90) + 10, cleanup)
    end)
end

local reEnd = ReplicatedStorage:WaitForChild("RainEventEnd", 10)
if reEnd then
    reEnd.OnClientEvent:Connect(cleanup)
end

local reLightning = ReplicatedStorage:WaitForChild("RainLightning", 10)
if reLightning then
    reLightning.OnClientEvent:Connect(function()
        if actif then jouerEclair() end
    end)
end
