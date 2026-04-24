-- ServerScriptService/Common/Events/EventRain.lua
-- BrainRotFarm — Rain Event
-- Nuages depuis ServerStorage.Events (Cloud + MovingClouds), pluie + boost spawn

local EventRain = {}
EventRain.NOM          = "Rain"
EventRain.DUREE_DEFAUT = 90

-- ============================================================
-- Services
-- ============================================================
local Workspace           = game:GetService("Workspace")
local ServerStorage       = game:GetService("ServerStorage")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- ============================================================
-- Config & dépendances
-- ============================================================
local Logger = require(ServerScriptService.SharedLib.Server.Logger)
local Config = require(ReplicatedStorage.GameConfig)

local RainWeatherSystem = require(ServerScriptService.SharedLib.Server.WeatherSystem.RainWeatherSystem)

-- ============================================================
-- Chargement différé de ChampCommunSpawner
-- ============================================================
local _CCS = nil
local function getCCS()
    if not _CCS then
        local ok, m = pcall(require, ServerScriptService.CommunSpawner)
        if ok and m then _CCS = m end
    end
    return _CCS
end

-- ============================================================
-- Accès aux templates ServerStorage
-- ============================================================
local function getEventsFolder()
    return ServerStorage:FindFirstChild("Events")
end

local function getCloudTemplate()
    local events = getEventsFolder()
    if not events then return nil end
    local cloudsFolder = events:FindFirstChild("clouds")
    if cloudsFolder then
        local t = cloudsFolder:FindFirstChild("Cloud")
        if t then return t end
    end
    return events:FindFirstChild("Cloud")
end

local function getMovingCloudsTemplate()
    local events = getEventsFolder()
    return events and events:FindFirstChild("MovingClouds")
end

local function getRainTemplate()
    local events = getEventsFolder()
    return events and events:FindFirstChild("Rain")
end

local function getFloodLevelTemplate()
    local events = getEventsFolder()
    return events and events:FindFirstChild("FloodLevel")
end

-- ============================================================
-- État interne
-- ============================================================
local nuages       = {}   -- modèles Cloud clonés dans Workspace
local movingClouds = nil  -- modèle MovingClouds cloné dans Workspace
local rainEffect   = nil  -- modèle Rain cloné (couvre toute la zone)
local floodLevel   = nil  -- modèle FloodLevel cloné dans Workspace

-- ============================================================
-- Utilitaires
-- ============================================================
local function notifierTous(message)
    local ev = ReplicatedStorage:FindFirstChild("NotifEvent")
    if ev then pcall(function() ev:FireAllClients("INFO", message) end) end
end

-- ============================================================
-- MovingClouds (nuages de fond animés)
-- ============================================================
local function activerMovingClouds()
    local template = getMovingCloudsTemplate()
    if not template then return end
    movingClouds = template:Clone()
    movingClouds.Parent = Workspace
end

local function retirerMovingClouds()
    if movingClouds and movingClouds.Parent then
        pcall(function() movingClouds:Destroy() end)
    end
    movingClouds = nil
end

-- ============================================================
-- Rain (effet pluie couvrant toute la ChampCommunZone)
-- ============================================================
local function activerRainEffect()
    local template = getRainTemplate()
    if not template then return end

    local zone = Config.ChampCommunZone
    if not zone then return end

    local largeur  = zone.xMax - zone.xMin           -- 150
    local profond  = zone.zMax - zone.zMin            -- 370
    local centreX  = (zone.xMin + zone.xMax) / 2     -- 225
    local centreZ  = (zone.zMin + zone.zMax) / 2     -- -85
    local hauteurY = (zone.y or 16) + 50             -- 50 studs au-dessus du sol

    rainEffect      = template:Clone()
    rainEffect.Name = "RainEffect"

    -- Identifier la part principale (BasePart direct ou PrimaryPart du Model)
    local mainPart = nil
    if rainEffect:IsA("BasePart") then
        mainPart = rainEffect
    elseif rainEffect:IsA("Model") then
        mainPart = rainEffect.PrimaryPart or rainEffect:FindFirstChildWhichIsA("BasePart")
    end

    if mainPart then
        -- Redimensionner pour couvrir toute la zone d'un coup
        pcall(function()
            mainPart.Size     = Vector3.new(largeur, 1, profond)
            mainPart.Position = Vector3.new(centreX, hauteurY, centreZ)
        end)
    end

    -- Repositionner le modèle entier si nécessaire
    if rainEffect:IsA("Model") then
        pcall(function()
            rainEffect:PivotTo(CFrame.new(centreX, hauteurY, centreZ))
        end)
    end

    rainEffect.Parent = Workspace
end

local function retirerRainEffect()
    if rainEffect and rainEffect.Parent then
        pcall(function() rainEffect:Destroy() end)
    end
    rainEffect = nil
end

-- ============================================================
-- FloodLevel
-- ============================================================
local function activerFloodLevel()
    local template = getFloodLevelTemplate()
    if not template then return end
    floodLevel        = template:Clone()
    floodLevel.Name   = "FloodLevel"
    floodLevel.Parent = Workspace
end

local function retirerFloodLevel()
    if floodLevel and floodLevel.Parent then
        pcall(function() floodLevel:Destroy() end)
    end
    floodLevel = nil
end

-- ============================================================
-- Création d'un nuage Cloud avec effet de pluie
-- ============================================================
local function creerNuageModele(position, config)
    local template = getCloudTemplate()
    if not template then return nil end

    local nuage  = template:Clone()
    nuage.Name   = "RainCloud"
    nuage.Parent = Workspace

    -- Position de départ : 60 studs plus haut (animation d'entrée)
    local cfFin    = CFrame.new(position)
    local cfDepart = CFrame.new(position + Vector3.new(0, 60, 0))
    pcall(function() nuage:PivotTo(cfDepart) end)

    -- Animation de descente (3s, ease-out)
    task.spawn(function()
        local duree = 3
        local t     = 0
        while t < duree do
            t = math.min(t + task.wait(0.05), duree)
            local alpha = 1 - (1 - t / duree) ^ 2  -- ease out quad
            pcall(function() nuage:PivotTo(cfDepart:Lerp(cfFin, alpha)) end)
        end
    end)

    -- Trouver la part principale pour attacher les effets
    local anchor = nil
    if nuage:IsA("BasePart") then
        anchor = nuage
    elseif nuage:IsA("Model") then
        anchor = nuage.PrimaryPart or nuage:FindFirstChildWhichIsA("BasePart")
    end

    if anchor then
        -- ParticleEmitter pluie dense, émission vers le bas
        local rain = Instance.new("ParticleEmitter")
        rain.Name              = "RainEmitter"
        rain.Rate              = config.particleRate or 80
        rain.Lifetime          = NumberRange.new(1.2, 2.0)
        rain.Speed             = NumberRange.new(45, 65)
        rain.SpreadAngle       = Vector2.new(10, 10)
        rain.EmissionDirection = Enum.NormalId.Bottom
        rain.Color             = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 215, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 180, 245)),
        })
        rain.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.09),
            NumberSequenceKeypoint.new(0.5, 0.06),
            NumberSequenceKeypoint.new(1, 0.02),
        })
        rain.LightEmission  = 0
        rain.LightInfluence = 1
        rain.Texture        = "rbxasset://textures/particles/sparkles_main.dds"
        rain.Parent         = anchor

        -- Lumière bleutée douce sous le nuage
        local light = Instance.new("PointLight")
        light.Brightness = 0.7
        light.Range      = 45
        light.Color      = Color3.fromRGB(130, 170, 255)
        light.Parent     = anchor
    end

    return nuage
end

-- ============================================================
-- API
-- ============================================================

function EventRain.Demarrer(config)
    nuages = {}

    -- Notifier + EventStarted
    notifierTous(config.message)
    local es = ReplicatedStorage:FindFirstChild("EventStarted")
    if es then pcall(function() es:FireAllClients("Rain", config.duree) end) end

    -- Nuages de fond + pluie zone complète + inondation
    activerMovingClouds()
    activerRainEffect()
    activerFloodLevel()

    -- Nuages Cloud avec pluie dans la ChampCommunZone
    local nb      = config.nbNuages   or 6
    local hauteur = config.hauteurNuages or 35
    local zone    = Config.ChampCommunZone
    local baseY   = (zone and zone.y or 16)

    for _ = 1, nb do
        local x, z
        if zone then
            x = zone.xMin + math.random() * (zone.xMax - zone.xMin)
            z = zone.zMin + math.random() * (zone.zMax - zone.zMin)
        else
            local pts = Config.ChampCommunPoints or {}
            local pt  = pts[math.random(1, math.max(1, #pts))] or { x=190, y=16, z=66 }
            x     = pt.x + math.random(-20, 20)
            z     = pt.z + math.random(-20, 20)
            baseY = pt.y
        end
        local nuage = creerNuageModele(Vector3.new(x, baseY + hauteur, z), config)
        if nuage then table.insert(nuages, nuage) end
    end

    -- Booster le spawn du ChampCommun
    local CCS = getCCS()
    if CCS and CCS.SetMultiplier then
        pcall(CCS.SetMultiplier, config.spawnMultiplier or 3)
    end

    -- Système météo (Atmosphere légère, sol mouillé, éclairs, sync clients)
    local weatherConfig = {}
    for k, v in pairs(config) do weatherConfig[k] = v end
    weatherConfig.champCommunZone = Config.ChampCommunZone
    RainWeatherSystem.Demarrer(weatherConfig, config.duree or EventRain.DUREE_DEFAUT)

end

function EventRain.Terminer()
    -- Remonter les nuages puis les détruire
    for _, nuage in ipairs(nuages) do
        if nuage and nuage.Parent then
            local ref     = nuage
            local cfStart = ref:GetPivot()
            local cfHaut  = CFrame.new(cfStart.Position + Vector3.new(0, 80, 0))
            task.spawn(function()
                local duree = 3
                local t     = 0
                while t < duree and ref and ref.Parent do
                    t = math.min(t + task.wait(0.05), duree)
                    local alpha = (t / duree) ^ 2  -- ease in quad
                    pcall(function() ref:PivotTo(cfStart:Lerp(cfHaut, alpha)) end)
                end
                if ref and ref.Parent then pcall(function() ref:Destroy() end) end
            end)
        end
    end
    nuages = {}

    retirerMovingClouds()
    retirerRainEffect()
    retirerFloodLevel()

    -- Remettre le multiplicateur de spawn à 1
    local CCS = getCCS()
    if CCS and CCS.SetMultiplier then
        pcall(CCS.SetMultiplier, 1)
    end

    -- Terminer le système météo
    RainWeatherSystem.Terminer()

end

return EventRain
