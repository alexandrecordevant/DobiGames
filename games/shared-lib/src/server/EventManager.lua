-- ServerScriptService/EventManager.lua
local EventManager = {}
local Config = require(
    game.ReplicatedStorage:FindFirstChild("GameConfig")
    or game.ReplicatedStorage.Specialized.GameConfig
)
local CollectSystem = require(game:GetService("ServerScriptService").SharedLib.Shared.CollectSystem)
local Logger = require(script.Parent.Logger)

-- Chargement différé de EventVisuals (coordinateur visuel+gameplay)
local _EventVisuals = nil
local function getEventVisuals()
    if not _EventVisuals then
        local SSS = game:GetService("ServerScriptService")
        local ok, m = pcall(require, SSS.EventVisuals)
        if ok and m then _EventVisuals = m end
    end
    return _EventVisuals
end

local Players = game:GetService("Players")

local function NotifierTous(message, couleur)
    local event = game.ReplicatedStorage:FindFirstChild("NotifEvent")
    if not event then return end
    for _, p in ipairs(Players:GetPlayers()) do
        event:FireClient(p, "INFO", message)
    end
end

local function DemarrerEvent(typeEvent)
    -- EventVisuals gère tout : visuel + gameplay + notifications
    local EV = getEventVisuals()
    if EV then
        pcall(EV.Lancer, typeEvent)
    else
        Logger.warn("Event", "EventVisuals non disponible, event ignoré : %s", tostring(typeEvent))
    end
end

-- Timestamp (os.time) du prochain event — lu par GetProchainEvent()
local prochainEventTimestamp = nil

local function BoucleAuto()
    local intervalle = Config.EventIntervalleMinutes * 60
    local earlyBird  = Config.EarlyBirdBonusMinutes * 60
    --local types      = { "NightMode", "MeteorDrop", "Rain", "Golden", "LuckyHour"}
    local types      = { "NightMode"}


    -- Premier event après 6s (test) — remettre 1200 en prod
    prochainEventTimestamp = os.time() + 6
    task.wait(6)
    prochainEventTimestamp = nil
    DemarrerEvent(types[math.random(1, #types)])
    task.wait((Config.EventDureeMinutes * 60) + 5)

    while true do
        prochainEventTimestamp = os.time() + intervalle
        -- Early bird uniquement si l'intervalle est assez long
        if intervalle > earlyBird then
            task.wait(intervalle - earlyBird)
            NotifierTous("Event in 1h! Stay connected for the Early Bird bonus", Color3.fromRGB(100,200,255))
            task.wait(earlyBird)
        else
            task.wait(intervalle)
        end
        prochainEventTimestamp = nil
        local choix = types[math.random(1, #types)]
        DemarrerEvent(choix)
        -- Attendre la durée de l'event avant d'en lancer un nouveau
        local dureeEvent = (Config.EventsVisuels and Config.EventsVisuels[choix] and Config.EventsVisuels[choix].duree)
            or (Config.EventDureeMinutes * 60)
        task.wait(dureeEvent + 5)  -- +5s de marge pour la transition retour
    end
end

local function BoucleAdminAbuseHebdo()
    local cfg = Config.AdminAbuseHebdo
    while true do
        task.wait(60)
        local now = os.date("!*t")
        if now.wday == cfg.jourSemaine and now.hour == cfg.heureUTC and now.min == 0 then
            NotifierTous("WEEKLY ADMIN ABUSE! Spawn x" .. cfg.spawnMultiplier .. " for " .. cfg.dureeMinutes .. " min!", Color3.fromRGB(255,50,50))
            CollectSystem.SetEventMultiplier(cfg.spawnMultiplier)
            task.delay(cfg.dureeMinutes * 60, function()
                CollectSystem.SetEventMultiplier(1)
                NotifierTous("Admin Abuse ended. See you next Saturday!", Color3.fromRGB(200,200,200))
            end)
        end
    end
end

function EventManager.Init()
    -- Initialiser EventVisuals en premier
    local EV = getEventVisuals()
    if EV then pcall(EV.Init) end

    task.spawn(BoucleAuto)
    task.spawn(BoucleAdminAbuseHebdo)
end

function EventManager.DeclenchemantManuel(typeEvent)
    DemarrerEvent(typeEvent)
end

-- Retourne le temps restant avant le prochain event automatique (secondes)
-- Retourne 0 si event imminent ou données absentes
function EventManager.GetProchainEvent()
    if not prochainEventTimestamp then return 0 end
    return math.max(0, prochainEventTimestamp - os.time())
end

return EventManager
