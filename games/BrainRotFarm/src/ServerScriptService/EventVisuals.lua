-- ServerScriptService/Common/EventVisuals.lua
-- BrainRotFarm — Coordinateur des events visuels
-- Orchestre NightMode, MeteorDrop, Rain, Golden et les events sans visuel

local EventVisuals = {}

-- ============================================================
-- Services
-- ============================================================
local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- ============================================================
-- Config
-- ============================================================
local Config = require(ReplicatedStorage.GameConfig)

-- ============================================================
-- Chargement différé des modules visuels
-- ============================================================
local modulesCache = {}

local function chargerModule(nomEvent)
    if modulesCache[nomEvent] ~= nil then return modulesCache[nomEvent] end

    local Events = ServerScriptService:FindFirstChild("Events")
    if not Events then
        modulesCache[nomEvent] = false
        return false
    end

    local moduleScript = Events:FindFirstChild("Event" .. nomEvent)
    if not moduleScript then
        modulesCache[nomEvent] = false
        return false
    end

    local ok, m = pcall(require, moduleScript)
    if ok and m then
        modulesCache[nomEvent] = m
        return m
    end

    warn("[EventVisuals] Erreur chargement module " .. nomEvent .. ": " .. tostring(m))
    modulesCache[nomEvent] = false
    return false
end

-- ============================================================
-- Chargement différé des systèmes gameplay
-- ============================================================
local _SpawnManager = nil
local function getBrainRotSpawner()
    if not _SpawnManager then
        local ok, m = pcall(require, ServerScriptService.SpawnManager)
        if ok and m then _SpawnManager = m end
    end
    return _SpawnManager
end

local _IncomeSystem = nil
local function getIncomeSystem()
    if not _IncomeSystem then
        local ok, m = pcall(require, game:GetService("ServerScriptService").SharedLib.Server.IncomeSystem)
        if ok and m then _IncomeSystem = m end
    end
    return _IncomeSystem
end

local _CollectSystem = nil
local function getCollectSystem()
    if not _CollectSystem then
        local ok, m = pcall(require, ReplicatedStorage.SharedLib.Shared.CollectSystem)
        if ok and m then _CollectSystem = m end
    end
    return _CollectSystem
end

-- ============================================================
-- Config gameplay des events sans module visuel
-- LuckyHour, DoubleCoins, SecretSpawn gardent leurs effets ici
-- ============================================================
local function getDureeEvent()
    return Config.EventDureeMinutes * 60
end

local CONFIGS_GAMEPLAY = {
    LuckyHour = {
        duree     = getDureeEvent,  -- fonction appelée au lancement
        msg       = "⭐ LUCKY HOUR! Spawn ×10!",
        msgFin    = "⭐ Lucky Hour ended.",
        appliquer = function()
            local BRS = getBrainRotSpawner()
            if BRS then pcall(BRS.SetEventMultiplier, 10) end
        end,
        terminer  = function()
            local BRS = getBrainRotSpawner()
            if BRS then pcall(BRS.SetEventMultiplier, 1) end
        end,
    },
    DoubleCoins = {
        duree     = getDureeEvent,
        msg       = "💰 DOUBLE COINS! ×5!",
        msgFin    = "💰 Double Coins ended.",
        appliquer = function()
            local IS = getIncomeSystem()
            local CS = getCollectSystem()
            if IS then pcall(IS.SetEventMultiplier, 5) end
            if CS then pcall(CS.SetEventMultiplier, 5) end
        end,
        terminer  = function()
            local IS = getIncomeSystem()
            local CS = getCollectSystem()
            if IS then pcall(IS.SetEventMultiplier, 1) end
            if CS then pcall(CS.SetEventMultiplier, 1) end
        end,
    },
    SecretSpawn = {
        duree     = getDureeEvent,
        msg       = "🔴 SECRET SPAWN! Rare " .. Config.CollectibleName .. "!",
        msgFin    = "🔴 Secret Spawn ended.",
        appliquer = function() end,  -- ChampCommunSpawner gère le SECRET de façon autonome
        terminer  = function() end,
    },
}

-- ============================================================
-- Utilitaires RemoteEvents
-- ============================================================
local function creerRemoteEvent(nom)
    local existing = ReplicatedStorage:FindFirstChild(nom)
    if existing then return existing end
    local re = Instance.new("RemoteEvent")
    re.Name   = nom
    re.Parent = ReplicatedStorage
    return re
end

local function notifierTous(message)
    local ev = ReplicatedStorage:FindFirstChild("NotifEvent")
    if ev then pcall(function() ev:FireAllClients("INFO", message) end) end
end

local function fireEventStarted(typeEvent, duree)
    local ev = ReplicatedStorage:FindFirstChild("EventStarted")
    if ev then pcall(function() ev:FireAllClients(typeEvent, duree) end) end
end

local function fireEventEnded()
    local ev = ReplicatedStorage:FindFirstChild("EventEnded")
    if ev then pcall(function() ev:FireAllClients() end) end
end

-- ============================================================
-- État interne
-- ============================================================
local eventActif     = nil
local terminerThread = nil
local eventStartTime = nil  -- os.time() au lancement de l'event actif
local eventDuree     = nil  -- durée totale en secondes

-- ============================================================
-- API publique
-- ============================================================

function EventVisuals.GetEventActif()
    return eventActif
end

-- Retourne le temps restant de l'event en cours
-- { actif=bool, nom=string|nil, tempsRestant=secondes, dureeTotal=secondes }
function EventVisuals.GetTempsRestantEvent()
    if not eventActif or not eventStartTime or not eventDuree then
        return { actif = false, nom = nil, tempsRestant = 0, dureeTotal = 0 }
    end
    local ecoule  = os.time() - eventStartTime
    local restant = math.max(0, eventDuree - ecoule)
    return { actif = true, nom = eventActif, tempsRestant = restant, dureeTotal = eventDuree }
end

function EventVisuals.TerminerActif()
    if not eventActif then return end
    local nomEvent = eventActif
    eventActif     = nil
    eventStartTime = nil
    eventDuree     = nil

    -- Annuler le timer de terminaison automatique
    if terminerThread then
        pcall(task.cancel, terminerThread)
        terminerThread = nil
    end

    -- Terminer le module visuel s'il existe
    local module = chargerModule(nomEvent)
    if module and module.Terminer then
        pcall(module.Terminer)
    end

    -- Terminer les effets gameplay (events sans visuel)
    local cfgGameplay = CONFIGS_GAMEPLAY[nomEvent]
    if cfgGameplay and cfgGameplay.terminer then
        pcall(cfgGameplay.terminer)
    end

    fireEventEnded()
    print("[EventVisuals] ■ Event terminé : " .. nomEvent)
end

function EventVisuals.Lancer(nomEvent)
    -- Terminer proprement l'event actif avant d'en lancer un nouveau
    if eventActif then
        EventVisuals.TerminerActif()
        task.wait(2)
    end

    local module = chargerModule(nomEvent)
    local duree  = nil

    if module and module.Demarrer then
        -- Event avec module visuel (NightMode, MeteorDrop, Rain, Golden)
        local cfgVisuelle = Config.EventsVisuels and Config.EventsVisuels[nomEvent]
        if not cfgVisuelle then
            warn("[EventVisuals] Config.EventsVisuels." .. nomEvent .. " manquante")
            return
        end
        duree      = cfgVisuelle.duree
        eventActif = nomEvent
        pcall(module.Demarrer, cfgVisuelle)
    else
        -- Event sans module visuel (LuckyHour, DoubleCoins, SecretSpawn)
        local cfgGameplay = CONFIGS_GAMEPLAY[nomEvent]
        if not cfgGameplay then
            warn("[EventVisuals] Event inconnu : " .. tostring(nomEvent))
            return
        end
        duree      = type(cfgGameplay.duree) == "function" and cfgGameplay.duree() or cfgGameplay.duree
        eventActif = nomEvent
        notifierTous(cfgGameplay.msg)
        fireEventStarted(nomEvent, duree)
        pcall(cfgGameplay.appliquer)
    end

    if not duree then duree = 60 end

    eventStartTime = os.time()
    eventDuree     = duree

    -- Terminaison automatique après la durée
    terminerThread = task.delay(duree, function()
        if eventActif == nomEvent then
            EventVisuals.TerminerActif()
        end
    end)

    print("[EventVisuals] ▶ Event lancé : " .. nomEvent .. " (" .. tostring(duree) .. "s)")
end

function EventVisuals.Init()
    -- Créer les RemoteEvents nécessaires aux effets client
    creerRemoteEvent("NightModeStart")
    creerRemoteEvent("MeteorImpact")
    creerRemoteEvent("GoldenStart")
    print("[EventVisuals] ✓ Coordinateur initialisé")
end

return EventVisuals
