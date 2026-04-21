-- ServerScriptService/Common/Events/EventNightMode.lua
-- BrainRotFarm — Event Night Mode
-- Obscurité soudaine, les BR EPIC+ brillent dans le noir

local EventNightMode = {}
EventNightMode.NOM          = "NightMode"
EventNightMode.DUREE_DEFAUT = 45

-- ============================================================
-- Services
-- ============================================================
local TweenService      = game:GetService("TweenService")
local Lighting          = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local Logger            = require(game:GetService("ServerScriptService").SharedLib.Server.Logger)

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
local savedLighting = {}
local pulseTasks    = {}   -- threads de pulsation PointLight
local savedLights   = {}   -- { { light, brightnessSaved } }

-- ============================================================
-- Utilitaires
-- ============================================================
local function notifierTous(message)
    local ev = ReplicatedStorage:FindFirstChild("NotifEvent")
    if ev then pcall(function() ev:FireAllClients("INFO", message) end) end
end

-- Sauvegarde les propriétés clés de Lighting
local function sauvegarderLighting()
    savedLighting = {
        Brightness       = Lighting.Brightness,
        Ambient          = Lighting.Ambient,
        OutdoorAmbient   = Lighting.OutdoorAmbient,
        FogEnd           = Lighting.FogEnd,
        FogColor         = Lighting.FogColor,
    }
end

-- ============================================================
-- Pulsation des PointLights
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
local createdLights = {}  -- PointLights créés dynamiquement (à détruire à la fin)

-- Booste les PointLights des BR EPIC+ dans le Workspace (champ uniquement, pas les slots dépôt)
local function boosterLumieresBR()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj.Name:match("^BR_") then
            local rareteNom = obj:GetAttribute("Rarete")
            -- Normaliser en majuscules pour gérer "Legendary" et "LEGENDARY"
            local rareteKey = rareteNom and rareteNom:upper() or nil
            local ordre = rareteKey and (RARETE_ORDRE[rareteKey] or 0) or 0
            if ordre >= SEUIL_BOOST_NIGHT then
                local root = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                if root then
                    local cfg = RARETE_LIGHT[rareteKey] or { brightness = 2, range = 18 }
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
                    local thread = lancerPulsation(light, cfg.brightness)
                    table.insert(pulseTasks, thread)
                end
            end
        end
    end
end

-- Arrête toutes les pulsations et restaure les PointLights
local function stopperPulsations()
    for _, thread in ipairs(pulseTasks) do
        pcall(task.cancel, thread)
    end
    pulseTasks = {}

    for _, entry in ipairs(savedLights) do
        if entry.light and entry.light.Parent then
            pcall(function() entry.light.Brightness = entry.brightness end)
        end
    end
    savedLights = {}

    -- Détruire les PointLights créés dynamiquement
    for _, light in ipairs(createdLights) do
        if light and light.Parent then pcall(function() light:Destroy() end) end
    end
    createdLights = {}
end

-- ============================================================
-- API
-- ============================================================

function EventNightMode.Demarrer(config)
    -- Sauvegarder l'état actuel de Lighting
    sauvegarderLighting()

    -- Transition vers la nuit (3 secondes)
    local infoNuit = TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    pcall(function()
        TweenService:Create(Lighting, infoNuit, {
            Brightness     = config.brightnessMin or 0,
            Ambient        = config.ambientNuit   or Color3.fromRGB(0, 0, 20),
            OutdoorAmbient = Color3.fromRGB(5, 5, 30),
            FogEnd         = config.fogEndNuit    or 200,
        }):Play()
    end)

    -- Notifier les joueurs + EventStarted
    notifierTous(config.message)
    local es = ReplicatedStorage:FindFirstChild("EventStarted")
    if es then pcall(function() es:FireAllClients("NightMode", config.duree) end) end

    -- Flash client (noir → sombre)
    local re = ReplicatedStorage:FindFirstChild("NightModeStart")
    if re then pcall(function() re:FireAllClients() end) end

    -- Booster les PointLights des BR après la transition (attendre 3.5s)
    task.delay(3.5, function()
        boosterLumieresBR()
    end)

    Logger.info("Event", "▶ Night Mode démarré (%ds)", config.duree or 45)
end

function EventNightMode.Terminer()
    -- Arrêter les pulsations et restaurer les lights
    stopperPulsations()

    -- Transition retour jour (5 secondes progressifs)
    local infoJour = TweenInfo.new(5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    pcall(function()
        TweenService:Create(Lighting, infoJour, {
            Brightness     = savedLighting.Brightness     or 2,
            Ambient        = savedLighting.Ambient        or Color3.fromRGB(70, 70, 70),
            OutdoorAmbient = savedLighting.OutdoorAmbient or Color3.fromRGB(70, 70, 70),
            FogEnd         = savedLighting.FogEnd         or 100000,
        }):Play()
    end)

    Logger.info("Event", "■ Night Mode terminé")
end

return EventNightMode
