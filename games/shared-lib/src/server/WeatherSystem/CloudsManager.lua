-- shared-lib/server/WeatherSystem/CloudsManager.lua
-- Gère Atmosphere (Lighting) + Clouds (Workspace.Terrain) + Lighting pendant la pluie

local CloudsManager = {}

local Lighting     = game:GetService("Lighting")
local Workspace    = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Logger       = require(script.Parent.Parent.Logger)

-- ============================================================
-- État sauvegardé
-- ============================================================
local savedLighting     = {}
local savedAtmosphere   = {}
local savedClouds       = {}
local atmosphereCreated = false
local cloudsCreated     = false

-- ============================================================
-- Utilitaires
-- ============================================================
local function getAtmosphere()
    return Lighting:FindFirstChildOfClass("Atmosphere")
end

local function getClouds()
    local terrain = Workspace:FindFirstChildOfClass("Terrain")
    return terrain and terrain:FindFirstChildOfClass("Clouds") or nil
end

-- ============================================================
-- API
-- ============================================================

function CloudsManager.Appliquer(config)
    local tweenInfo = TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    -- Sauvegarder + tweener Lighting
    savedLighting = {
        Brightness     = Lighting.Brightness,
        FogEnd         = Lighting.FogEnd,
        FogStart       = Lighting.FogStart,
        FogColor       = Lighting.FogColor,
        Ambient        = Lighting.Ambient,
        OutdoorAmbient = Lighting.OutdoorAmbient,
    }
    pcall(function()
        TweenService:Create(Lighting, tweenInfo, {
            Brightness     = config.brightnessRain or 0.4,
            FogEnd         = config.fogEndRain     or 300,
            FogColor       = config.fogColorRain   or Color3.fromRGB(130, 140, 155),
            Ambient        = config.ambientRain    or Color3.fromRGB(90, 95, 110),
            OutdoorAmbient = config.ambientRain    or Color3.fromRGB(90, 95, 110),
        }):Play()
    end)

    -- Atmosphere
    local atmo = getAtmosphere()
    if atmo then
        savedAtmosphere   = {
            Density = atmo.Density,
            Offset  = atmo.Offset,
            Color   = atmo.Color,
            Decay   = atmo.Decay,
            Glare   = atmo.Glare,
            Haze    = atmo.Haze,
        }
        atmosphereCreated = false
    else
        atmo              = Instance.new("Atmosphere")
        atmo.Parent       = Lighting
        savedAtmosphere   = {}
        atmosphereCreated = true
    end
    pcall(function()
        TweenService:Create(atmo, tweenInfo, {
            Density = config.atmosphereDensity or 0.85,
            Offset  = config.atmosphereOffset  or 0.25,
            Color   = config.atmosphereColor   or Color3.fromRGB(150, 160, 175),
            Decay   = config.atmosphereDecay   or Color3.fromRGB(100, 110, 130),
            Haze    = config.atmosphereHaze    or 3.5,
            Glare   = 0,
        }):Play()
    end)

    -- Clouds (sous Workspace.Terrain)
    local terrain = Workspace:FindFirstChildOfClass("Terrain")
    if terrain then
        local clouds = getClouds()
        if clouds then
            savedClouds   = { Density = clouds.Density, Cover = clouds.Cover, Color = clouds.Color }
            cloudsCreated = false
        else
            clouds        = Instance.new("Clouds")
            clouds.Parent = terrain
            savedClouds   = {}
            cloudsCreated = true
        end
        pcall(function()
            clouds.Density = config.cloudsDensity or 0.8
            clouds.Cover   = config.cloudsCover   or 0.95
            clouds.Color   = config.cloudsColor   or Color3.fromRGB(120, 130, 140)
        end)
    end

end

function CloudsManager.Restaurer()
    local tweenInfo = TweenInfo.new(5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    -- Restaurer Lighting
    pcall(function()
        TweenService:Create(Lighting, tweenInfo, {
            Brightness     = savedLighting.Brightness     or 2,
            FogEnd         = savedLighting.FogEnd         or 100000,
            FogColor       = savedLighting.FogColor       or Color3.fromRGB(191, 191, 191),
            Ambient        = savedLighting.Ambient        or Color3.fromRGB(70, 70, 70),
            OutdoorAmbient = savedLighting.OutdoorAmbient or Color3.fromRGB(70, 70, 70),
        }):Play()
    end)

    -- Restaurer Atmosphere
    local atmo = getAtmosphere()
    if atmo then
        if atmosphereCreated then
            task.delay(5, function()
                if atmo and atmo.Parent then pcall(function() atmo:Destroy() end) end
            end)
        else
            pcall(function()
                TweenService:Create(atmo, tweenInfo, {
                    Density = savedAtmosphere.Density or 0,
                    Offset  = savedAtmosphere.Offset  or 0,
                    Color   = savedAtmosphere.Color   or Color3.fromRGB(199, 170, 143),
                    Decay   = savedAtmosphere.Decay   or Color3.fromRGB(106, 112, 125),
                    Haze    = savedAtmosphere.Haze    or 0,
                    Glare   = savedAtmosphere.Glare   or 0,
                }):Play()
            end)
        end
    end

    -- Restaurer Clouds
    local clouds = getClouds()
    if clouds then
        if cloudsCreated then
            task.delay(1, function()
                if clouds and clouds.Parent then pcall(function() clouds:Destroy() end) end
            end)
        else
            pcall(function()
                clouds.Density = savedClouds.Density or 0.06
                clouds.Cover   = savedClouds.Cover   or 0.5
                clouds.Color   = savedClouds.Color   or Color3.fromRGB(186, 186, 186)
            end)
        end
    end

    savedLighting     = {}
    savedAtmosphere   = {}
    savedClouds       = {}
    atmosphereCreated = false
    cloudsCreated     = false

end

return CloudsManager
