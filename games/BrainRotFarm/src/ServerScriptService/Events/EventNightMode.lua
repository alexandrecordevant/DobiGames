-- ServerScriptService/Common/Events/EventNightMode.lua
-- BrainRotFarm — Event Night Mode
-- Obscurité soudaine, ciel étoilé, son ambiant, BR EPIC+ brillent dans le noir
--
-- Changelog :
--   Added: savedAtmosphere snapshot (Density, Color, Decay, Glare, Haze)
--   Added: ColorShift_Top/Bottom dans la sauvegarde et la restauration
--   Added: restauration Atmosphere avec fallback Brainrot (rose/violet)
--   Added: transition Atmosphere vers ambiance nuit au demarrage de l'event
--   Modified: fallbacks restaurerLighting maintenant Brainrot (rose/violet) et ClockTime 17

local EventNightMode = {}
EventNightMode.NOM          = "NightMode"
EventNightMode.DUREE_DEFAUT = 90

-- ============================================================
-- Services
-- ============================================================
local TweenService      = game:GetService("TweenService")
local Lighting          = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

-- ============================================================
-- Dépendances shared-lib
-- ============================================================
local SharedLib      = game:GetService("ServerScriptService").SharedLib.Server
local Logger         = require(SharedLib.Logger)
local NightSkySystem = require(SharedLib.NightSkySystem)

-- ============================================================
-- Ordre de rareté (EPIC = 4)
-- ============================================================
local RARETE_ORDRE = {
    COMMON=1, OG=2, RARE=3, EPIC=4,
    LEGENDARY=5, MYTHIC=6, SECRET=7, BRAINROT_GOD=8,
}
local SEUIL_BOOST_NIGHT = 4  -- EPIC et au-dessus

-- ============================================================
-- État interne (réinitialisé à chaque Demarrer)
-- ============================================================
local savedLighting    = {}   -- snapshot complet du Lighting
local savedAtmosphere  = nil  -- snapshot des proprietes Atmosphere
local savedStarCount   = nil
local skyCreated       = false
local pulseTasks       = {}
local savedLights      = {}
local createdLights    = {}
local materiauOriginel = {}   -- { [BasePart] = Enum.Material } pour restauration Map

-- ============================================================
-- Utilitaires
-- ============================================================
local function notifierTous(message)
    local ev = ReplicatedStorage:FindFirstChild("NotifEvent")
    if ev then pcall(function() ev:FireAllClients("INFO", message) end) end
end

-- ============================================================
-- Sauvegarde / restauration Lighting (snapshot complet)
-- ============================================================
local function sauvegarderLighting()
    savedLighting = {
        Brightness               = Lighting.Brightness,
        Ambient                  = Lighting.Ambient,
        OutdoorAmbient           = Lighting.OutdoorAmbient,
        FogEnd                   = Lighting.FogEnd,
        FogStart                 = Lighting.FogStart,
        FogColor                 = Lighting.FogColor,
        ClockTime                = Lighting.ClockTime,
        EnvironmentDiffuseScale  = Lighting.EnvironmentDiffuseScale,
        EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
        ColorShift_Top           = Lighting.ColorShift_Top,
        ColorShift_Bottom        = Lighting.ColorShift_Bottom,
    }

    -- Sauvegarder l'Atmosphere
    local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
    if atmo then
        savedAtmosphere = {
            Density = atmo.Density,
            Color   = atmo.Color,
            Decay   = atmo.Decay,
            Glare   = atmo.Glare,
            Haze    = atmo.Haze,
        }
    else
        savedAtmosphere = nil
    end

    local sky = Lighting:FindFirstChildOfClass("Sky")
    if sky then
        savedStarCount = sky.StarCount
        skyCreated     = false
    else
        savedStarCount = nil
        skyCreated     = false
    end
end

local function restaurerLighting()
    local ok, err = pcall(function()
        -- ClockTime ne se tween pas : set direct avec fallback Brainrot (coucher soleil)
        Lighting.ClockTime = savedLighting.ClockTime or 17

        local info = TweenInfo.new(5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        TweenService:Create(Lighting, info, {
            Brightness               = savedLighting.Brightness               or 2,
            Ambient                  = savedLighting.Ambient                  or Color3.fromRGB(180, 100, 255),
            OutdoorAmbient           = savedLighting.OutdoorAmbient           or Color3.fromRGB(255, 150, 200),
            FogEnd                   = savedLighting.FogEnd                   or 100000,
            FogStart                 = savedLighting.FogStart                 or 0,
            FogColor                 = savedLighting.FogColor                 or Color3.fromRGB(191, 191, 191),
            EnvironmentDiffuseScale  = savedLighting.EnvironmentDiffuseScale  or 1,
            EnvironmentSpecularScale = savedLighting.EnvironmentSpecularScale or 1,
            ColorShift_Top           = savedLighting.ColorShift_Top           or Color3.fromRGB(255, 100, 200),
            ColorShift_Bottom        = savedLighting.ColorShift_Bottom        or Color3.fromRGB(150, 50, 255),
        }):Play()

        -- Restaurer l'Atmosphere
        local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
        if atmo and savedAtmosphere then
            local infoAtmo = TweenInfo.new(5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            TweenService:Create(atmo, infoAtmo, {
                Density = savedAtmosphere.Density,
                Color   = savedAtmosphere.Color,
                Decay   = savedAtmosphere.Decay,
                Glare   = savedAtmosphere.Glare,
                Haze    = savedAtmosphere.Haze,
            }):Play()
        elseif atmo then
            -- Pas de snapshot : forcer valeurs Brainrot (rose/violet)
            local infoAtmo = TweenInfo.new(5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            TweenService:Create(atmo, infoAtmo, {
                Density = 0.45,
                Color   = Color3.fromRGB(255, 150, 200),
                Decay   = Color3.fromRGB(180, 100, 255),
                Glare   = 0.8,
                Haze    = 2,
            }):Play()
        end
    end)
    if not ok then
        Logger.warn("Sky", "restaurerLighting : erreur %s", tostring(err))
    end
end

-- ============================================================
-- Ciel étoilé
-- ============================================================
local function activerEtoiles(starCount)
    local sky = Lighting:FindFirstChildOfClass("Sky")
    if not sky then
        sky        = Instance.new("Sky")
        sky.Parent = Lighting
        skyCreated = true
    end
    sky.StarCount = starCount or 3000
end

local function restaurerEtoiles()
    local sky = Lighting:FindFirstChildOfClass("Sky")
    if not sky then return end
    if skyCreated then
        pcall(function() sky:Destroy() end)
        skyCreated = false
    else
        sky.StarCount = savedStarCount or 0
    end
end

-- ============================================================
-- Matériau Map : Limestone pendant NightMode
-- ============================================================
local function appliquerMateriauMap()
    materiauOriginel = {}
    local map = Workspace:FindFirstChild("Map")
    if not map then return end
    for _, obj in ipairs(map:GetDescendants()) do
        if obj:IsA("BasePart") then
            materiauOriginel[obj] = { Material = obj.Material, Color = obj.Color }
            obj.Material = Enum.Material.Basalt
            obj.Color    = Color3.fromRGB(30, 30, 35)
        end
    end
end

local function restaurerMateriauMap()
    for part, saved in pairs(materiauOriginel) do
        if part and part.Parent then
            pcall(function()
                part.Material = saved.Material
                part.Color    = saved.Color
            end)
        end
    end
    materiauOriginel = {}
end

-- ============================================================
-- Pulsation des PointLights des BR EPIC+
-- ============================================================
local function lancerPulsation(light, brightnessBase)
    local thread = task.spawn(function()
        local infoHaut = TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
        local infoBas  = TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
        while light and light.Parent do
            pcall(function()
                TweenService:Create(light, infoHaut, { Brightness = brightnessBase * 3 }):Play()
            end)
            task.wait(0.9)
            if not (light and light.Parent) then break end
            pcall(function()
                TweenService:Create(light, infoBas, { Brightness = brightnessBase * 1.2 }):Play()
            end)
            task.wait(0.9)
        end
    end)
    return thread
end

local RARETE_COULEUR = {
    EPIC         = Color3.fromRGB(163, 73, 255),
    LEGENDARY    = Color3.fromRGB(255, 165, 0),
    MYTHIC       = Color3.fromRGB(255, 50, 50),
    SECRET       = Color3.fromRGB(0, 255, 200),
    BRAINROT_GOD = Color3.fromRGB(255, 255, 100),
}
local RARETE_LIGHT = {
    EPIC         = { brightness = 2,  range = 18 },
    LEGENDARY    = { brightness = 3,  range = 25 },
    MYTHIC       = { brightness = 5,  range = 35 },
    SECRET       = { brightness = 7,  range = 42 },
    BRAINROT_GOD = { brightness = 10, range = 55 },
}

local function boosterLumieresBR()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj.Name:match("^BR_") then
            local rareteNom = obj:GetAttribute("Rarete")
            local rareteKey = rareteNom and rareteNom:upper() or nil
            local ordre     = rareteKey and (RARETE_ORDRE[rareteKey] or 0) or 0
            if ordre >= SEUIL_BOOST_NIGHT then
                local root = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                if root then
                    local cfg   = RARETE_LIGHT[rareteKey] or { brightness = 2, range = 18 }
                    local light = root:FindFirstChildOfClass("PointLight")
                    if not light then
                        light = Instance.new("PointLight")
                        light.Parent = root
                        table.insert(createdLights, light)
                    end
                    light.Brightness = cfg.brightness
                    light.Range      = cfg.range
                    light.Color      = RARETE_COULEUR[rareteKey] or Color3.fromRGB(255, 255, 255)
                    table.insert(savedLights, { light = light, brightness = cfg.brightness })
                    table.insert(pulseTasks, lancerPulsation(light, cfg.brightness))
                end
            end
        end
    end
end

local function stopperPulsations()
    for _, thread in ipairs(pulseTasks) do pcall(task.cancel, thread) end
    pulseTasks = {}
    for _, entry in ipairs(savedLights) do
        if entry.light and entry.light.Parent then
            pcall(function() entry.light.Brightness = entry.brightness end)
        end
    end
    savedLights = {}
    for _, light in ipairs(createdLights) do
        if light and light.Parent then pcall(function() light:Destroy() end) end
    end
    createdLights = {}
end

-- ============================================================
-- Callback sync joueur rejoignant en cours d'event
-- ============================================================
local function syncNouveauJoueur(player, dureeRestante)
    local re = ReplicatedStorage:FindFirstChild("NightModeStart")
    if re then
        pcall(function() re:FireClient(player, dureeRestante) end)
    end
end

-- ============================================================
-- API
-- ============================================================

function EventNightMode.Demarrer(config)
    -- Sauvegarder l'état complet du Lighting
    sauvegarderLighting()

    -- Transition Lighting vers la nuit (3s)
    local infoNuit = TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    pcall(function()
        Lighting.ClockTime = config.clockTimeNuit or 0  -- minuit immediat
        TweenService:Create(Lighting, infoNuit, {
            Brightness               = config.brightnessMin  or 0.3,
            Ambient                  = config.ambientNuit    or Color3.fromRGB(40, 40, 80),
            OutdoorAmbient           = config.outdoorAmbientNuit or Color3.fromRGB(20, 20, 60),
            FogEnd                   = config.fogEndNuit     or 500,
            FogColor                 = config.fogColorNuit   or Color3.fromRGB(20, 20, 50),
            EnvironmentDiffuseScale  = config.envDiffuseNuit or 0.2,
            EnvironmentSpecularScale = config.envSpecNuit    or 0.2,
        }):Play()
    end)

    -- Atmosphere : transition vers ambiance nuit (sombre, brume bleue)
    local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
    if atmo then
        local infoAtmoNuit = TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        pcall(function()
            TweenService:Create(atmo, infoAtmoNuit, {
                Density = config.atmoDensiteNuit or 0.6,
                Color   = config.atmoColorNuit   or Color3.fromRGB(20, 20, 50),
                Decay   = config.atmoDecayNuit   or Color3.fromRGB(0, 0, 30),
                Glare   = config.atmoGlareNuit   or 0,
                Haze    = config.atmoHazeNuit    or 3,
            }):Play()
        end)
    end

    -- Notifier joueurs + EventStarted
    notifierTous(config.message)
    local es = ReplicatedStorage:FindFirstChild("EventStarted")
    if es then pcall(function() es:FireAllClients("NightMode", config.duree) end) end

    -- Flash client + son ambiant (passe la durée pour l'auto-cleanup client)
    local reStart = ReplicatedStorage:FindFirstChild("NightModeStart")
    if reStart then pcall(function() reStart:FireAllClients(config.duree) end) end

    -- Étoiles après la transition (ciel sombre visible)
    task.delay(3, function()
        activerEtoiles(config.starCount)
    end)

    -- Boost des PointLights des BR après transition
    task.delay(3.5, function()
        boosterLumieresBR()
    end)

    -- Matériau Map → Limestone
    appliquerMateriauMap()

    -- NightSkySystem : tracking état + sync joueurs qui rejoignent
    NightSkySystem.Demarrer(config.duree or EventNightMode.DUREE_DEFAUT, syncNouveauJoueur)

end

function EventNightMode.Terminer()
    stopperPulsations()
    restaurerEtoiles()
    restaurerMateriauMap()
    restaurerLighting()

    -- Signal fin aux clients (arrêt son + cleanup)
    local reEnd = ReplicatedStorage:FindFirstChild("NightModeSkyEnd")
    if reEnd then pcall(function() reEnd:FireAllClients() end) end

    -- Terminer le tracking NightSkySystem
    NightSkySystem.Terminer(nil)

end

return EventNightMode
