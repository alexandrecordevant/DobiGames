-- ServerScriptService/Common/Events/EventRain.lua
-- BrainRotFarm — Rain Event
-- MovingClouds + Rain (zone entière) + FloodLevel + boost spawn

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
local movingClouds     = nil
local rainEffects      = {}   -- grille de tuiles Rain
local floodLevel       = nil
local savedChampignons = {}   -- { [BasePart] = { saColor, material } }

-- ============================================================
-- Utilitaires
-- ============================================================
local function notifierTous(message)
    local ev = ReplicatedStorage:FindFirstChild("NotifEvent")
    if ev then pcall(function() ev:FireAllClients("INFO", message) end) end
end

-- ============================================================
-- MovingClouds
-- ============================================================
local function activerMovingClouds()
    local template = getMovingCloudsTemplate()
    if not template then return end
    movingClouds        = template:Clone()
    movingClouds.Parent = Workspace
end

local function retirerMovingClouds()
    if movingClouds and movingClouds.Parent then
        pcall(function() movingClouds:Destroy() end)
    end
    movingClouds = nil
end

-- ============================================================
-- Rain : grille de tuiles couvrant uniformément la ChampCommunZone
-- ============================================================
local function activerRainEffect()
    local template = getRainTemplate()
    if not template then return end

    local rainCfg = Config.EventsVisuels.Rain
    local colonnes = rainCfg.rainGridCols or 4
    local rangees  = rainCfg.rainGridRows or 8
    local hauteurY

    local xMin, xMax, zMin, zMax

    if rainCfg.pluieTouteMap then
        -- Utiliser les bounds de la Baseplate
        local bp = nil
        local map = Workspace:FindFirstChild("Map")
        if map then bp = map:FindFirstChild("Baseplate") end
        if not bp then bp = Workspace:FindFirstChild("Baseplate") end
        if not bp then return end
        local bpSurfaceY = bp.Position.Y + bp.Size.Y / 2
        hauteurY = bpSurfaceY + (rainCfg.hauteurRain or 15)
        xMin = bp.Position.X - bp.Size.X / 2
        xMax = bp.Position.X + bp.Size.X / 2
        zMin = bp.Position.Z - bp.Size.Z / 2
        zMax = bp.Position.Z + bp.Size.Z / 2
    else
        local zone = Config.ChampCommunZone
        if not zone then return end
        hauteurY = (zone.y or 2) + (rainCfg.hauteurRain or 15)
        xMin = zone.xMin ; xMax = zone.xMax
        zMin = zone.zMin ; zMax = zone.zMax
    end

    local largeur = xMax - xMin
    local profond = zMax - zMin
    local tileW   = largeur / colonnes
    local tileD   = profond / rangees

    rainEffects = {}

    for col = 0, colonnes - 1 do
        for row = 0, rangees - 1 do
            local tileX = xMin + (col + 0.5) * tileW
            local tileZ = zMin + (row + 0.5) * tileD

            local clone    = template:Clone()
            clone.Name     = "RainEffect"
            clone.Parent   = Workspace

            local mainPart = nil
            if clone:IsA("BasePart") then
                mainPart = clone
            elseif clone:IsA("Model") then
                mainPart = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart")
            end

            if mainPart then
                local origX = mainPart.Size.X
                local origZ = mainPart.Size.Z
                local ratio = (tileW * tileD) / math.max(origX * origZ, 1)

                pcall(function()
                    mainPart.Size = Vector3.new(tileW, mainPart.Size.Y, tileD)
                end)

                for _, pe in ipairs(clone:GetDescendants()) do
                    if pe:IsA("ParticleEmitter") then
                        pcall(function()
                            pe.Rate = math.max(math.min(pe.Rate * ratio, 5000), 80)
                        end)
                    end
                end

                pcall(function()
                    mainPart.Position = Vector3.new(tileX, hauteurY, tileZ)
                end)
            end

            if clone:IsA("Model") then
                pcall(function() clone:PivotTo(CFrame.new(tileX, hauteurY, tileZ)) end)
            end

            table.insert(rainEffects, clone)
        end
    end

    Logger.info("Event", "RainEffect activé (%dx%d tuiles, %.0fx%.0f studs)",
        colonnes, rangees, largeur, profond)
end

local function retirerRainEffect()
    for _, r in ipairs(rainEffects) do
        if r and r.Parent then pcall(function() r:Destroy() end) end
    end
    rainEffects = {}
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
-- Champignons : neon cyan (pluie)
-- ============================================================
local function appliquerChampignons()
    savedChampignons = {}
    local deco = Workspace:FindFirstChild("Deco")
    if not deco then return end
    for _, obj in ipairs(deco:GetChildren()) do
        if obj.Name == "Meshes/Mushroom" and obj:IsA("BasePart") then
            local sa = obj:FindFirstChildOfClass("SurfaceAppearance")
            savedChampignons[obj] = { saColor = sa and sa.Color or nil, material = obj.Material }
            obj.Material = Enum.Material.Neon
            if sa then sa.Color = Color3.fromRGB(0, 220, 255) end
        end
    end
end

local function restaurerChampignons()
    for obj, saved in pairs(savedChampignons) do
        if obj and obj.Parent then
            pcall(function()
                obj.Material = saved.material
                local sa = obj:FindFirstChildOfClass("SurfaceAppearance")
                if sa and saved.saColor then sa.Color = saved.saColor end
            end)
        end
    end
    savedChampignons = {}
end

-- ============================================================
-- API
-- ============================================================

function EventRain.Demarrer(config)
    -- Notifier + EventStarted
    notifierTous(config.message)
    local es = ReplicatedStorage:FindFirstChild("EventStarted")
    if es then pcall(function() es:FireAllClients("Rain", config.duree) end) end

    activerMovingClouds()
    activerRainEffect()
    activerFloodLevel()
    appliquerChampignons()

    -- Booster le spawn du ChampCommun
    local CCS = getCCS()
    if CCS and CCS.SetMultiplier then
        pcall(CCS.SetMultiplier, config.spawnMultiplier or 3)
    end

    -- Système météo (Atmosphere, sol mouillé, éclairs, sync clients)
    local weatherConfig = {}
    for k, v in pairs(config) do weatherConfig[k] = v end
    weatherConfig.champCommunZone = Config.ChampCommunZone
    RainWeatherSystem.Demarrer(weatherConfig, config.duree or EventRain.DUREE_DEFAUT)

    Logger.info("Event", "▶ Rain Event démarré (%ds)", config.duree or 90)
end

function EventRain.Terminer()
    retirerMovingClouds()
    retirerRainEffect()
    retirerFloodLevel()
    restaurerChampignons()

    local CCS = getCCS()
    if CCS and CCS.SetMultiplier then
        pcall(CCS.SetMultiplier, 1)
    end

    RainWeatherSystem.Terminer()

    Logger.info("Event", "■ Rain Event terminé")
end

return EventRain
