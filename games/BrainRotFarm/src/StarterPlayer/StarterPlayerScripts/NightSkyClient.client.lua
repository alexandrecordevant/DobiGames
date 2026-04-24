-- StarterPlayerScripts/NightSkyClient.client.lua
-- BrainRotFarm — Effets visuels/sonores NightMode côté client
-- Écoute NightModeStart (début) et NightModeSkyEnd (fin)
-- Effets : flash écran blanc → nuit + son ambiant en boucle

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local SoundService      = game:GetService("SoundService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Config lue depuis GameConfig (serveur → client via ReplicatedStorage)
local GameConfig     = require(ReplicatedStorage:WaitForChild("GameConfig"))
local nightCfg       = GameConfig.EventsVisuels and GameConfig.EventsVisuels.NightMode or {}

-- ============================================================
-- Config locale
-- ============================================================
local FLASH_DUREE    = 0.4
local SON_FADE_DUREE = 2
local SON_VOLUME     = 0.35
local SON_AMBIANT_ID = nightCfg.soundIdNuit or 0

-- ============================================================
-- État local
-- ============================================================
local screenGui     = nil
local soundAmbiant  = nil
local tacheCleanup  = nil  -- task.delay pour auto-cleanup si NightModeSkyEnd manqué

-- ============================================================
-- Flash écran blanc → fondu nuit
-- ============================================================
local function lancerFlash()
    -- Créer le ScreenGui de flash (détruit automatiquement après l'animation)
    local gui = Instance.new("ScreenGui")
    gui.Name            = "NightFlash"
    gui.ResetOnSpawn    = false
    gui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
    gui.IgnoreGuiInset  = true
    gui.Parent          = playerGui

    local frame = Instance.new("Frame")
    frame.Size             = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    frame.BackgroundTransparency = 0
    frame.BorderSizePixel  = 0
    frame.Parent           = gui

    -- Flash blanc rapide puis fade complet
    local infoFlash = TweenInfo.new(FLASH_DUREE, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local tween = TweenService:Create(frame, infoFlash, { BackgroundTransparency = 1 })
    tween:Play()
    tween.Completed:Connect(function()
        if gui and gui.Parent then gui:Destroy() end
    end)
end

-- ============================================================
-- Son ambiant nuit
-- ============================================================
local function demarrerSon()
    if SON_AMBIANT_ID == 0 then return end  -- SoundId non configuré

    soundAmbiant          = Instance.new("Sound")
    soundAmbiant.SoundId  = "rbxassetid://" .. SON_AMBIANT_ID
    soundAmbiant.Volume   = 0
    soundAmbiant.Looped   = true
    soundAmbiant.RollOffMaxDistance = 0  -- son global (non-positionnel)
    soundAmbiant.Parent   = SoundService
    soundAmbiant:Play()

    -- Fade in progressif
    local infoFade = TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(soundAmbiant, infoFade, { Volume = SON_VOLUME }):Play()
end

local function arreterSon()
    if not soundAmbiant then return end
    local son = soundAmbiant
    soundAmbiant = nil

    -- Fade out puis destroy
    local infoFade = TweenInfo.new(SON_FADE_DUREE, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    local tween = TweenService:Create(son, infoFade, { Volume = 0 })
    tween:Play()
    tween.Completed:Connect(function()
        if son and son.Parent then son:Destroy() end
    end)
end

-- ============================================================
-- Cleanup complet (appelé à la fin de l'event)
-- ============================================================
local function cleanup()
    if tacheCleanup then
        task.cancel(tacheCleanup)
        tacheCleanup = nil
    end
    arreterSon()
end

-- ============================================================
-- Écoute des RemoteEvents
-- ============================================================

-- Début de l'event : flash + son + auto-cleanup de secours
local reStart = ReplicatedStorage:WaitForChild("NightModeStart", 10)
if reStart then
    reStart.OnClientEvent:Connect(function(duree)
        lancerFlash()
        demarrerSon()

        -- Auto-cleanup si NightModeSkyEnd n'arrive pas (sécurité)
        if tacheCleanup then task.cancel(tacheCleanup) end
        local dureeSecours = (tonumber(duree) or 90) + 10
        tacheCleanup = task.delay(dureeSecours, cleanup)
    end)
end

-- Fin de l'event
local reEnd = ReplicatedStorage:WaitForChild("NightModeSkyEnd", 10)
if reEnd then
    reEnd.OnClientEvent:Connect(function()
        cleanup()
    end)
end
