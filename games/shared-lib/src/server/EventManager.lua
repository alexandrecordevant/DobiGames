-- ServerScriptService/EventManager.lua
local EventManager = {}
local Config        = require(game.ReplicatedStorage.Specialized.GameConfig)
local CollectSystem = require(game.ReplicatedStorage.SharedLib.Shared.CollectSystem)

-- Chargement différé de EventVisuals (coordinateur visuel+gameplay)
local _EventVisuals = nil
local function getEventVisuals()
    if not _EventVisuals then
        local SSS = game:GetService("ServerScriptService")
        local ok, m = pcall(require, SSS.Common.EventVisuals)
        if ok and m then _EventVisuals = m end
    end
    return _EventVisuals
end

-- TEST_MODE : intervalles réduits pour valider le flow en studio
local _TestConfig = Config.TEST_MODE
    and require(game.ReplicatedStorage.Test.TestConfig)
    or nil

local function GetConfig(nomValeur, valeurNormale)
    if _TestConfig and _TestConfig[nomValeur] ~= nil then
        return _TestConfig[nomValeur]
    end
    return valeurNormale
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
        warn("[EventManager] EventVisuals non disponible, event ignoré : " .. tostring(typeEvent))
    end
end

local function BoucleAuto()
    local intervalle = GetConfig("EventIntervalleMinutes", Config.EventIntervalleMinutes) * 60
    local earlyBird  = Config.TEST_MODE and 0 or (Config.EarlyBirdBonusMinutes * 60)
    local types      = { "NightMode", "MeteorDrop", "Rain", "Golden", "LuckyHour", "DoubleCoins" }
    while true do
        task.wait(intervalle - earlyBird)
        NotifierTous("⏰ Event in 1h! Stay connected for the Early Bird bonus 🎁", Color3.fromRGB(100,200,255))
        task.wait(earlyBird)
        local choix = types[math.random(1, #types)]
        DemarrerEvent(choix)
        -- Pas de Discord pour ces events fréquents (Lucky Hour, Golden, etc.)
    end
end

local function BoucleAdminAbuseHebdo()
    local cfg = Config.AdminAbuseHebdo
    while true do
        task.wait(60)
        local now = os.date("!*t")
        if now.wday == cfg.jourSemaine and now.hour == cfg.heureUTC and now.min == 0 then
            NotifierTous("🔥 WEEKLY ADMIN ABUSE! Spawn ×" .. cfg.spawnMultiplier .. " for " .. cfg.dureeMinutes .. " min!", Color3.fromRGB(255,50,50))
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
    print("[EventManager] Events automatiques démarrés ✓")
end

function EventManager.DeclenchemantManuel(typeEvent)
    DemarrerEvent(typeEvent)
end

return EventManager
