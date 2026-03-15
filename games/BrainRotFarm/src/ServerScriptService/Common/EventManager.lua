-- ServerScriptService/EventManager.lua
local EventManager = {}
local Config        = require(game.ReplicatedStorage.Specialized.GameConfig)
local CollectSystem = require(game.ReplicatedStorage.Common.CollectSystem)

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
local Players       = game:GetService("Players")
local HttpService   = game:GetService("HttpService")

local function NotifierTous(message, couleur)
    local event = game.ReplicatedStorage:FindFirstChild("NotifEvent")
    if not event then return end
    for _, p in ipairs(Players:GetPlayers()) do
        event:FireClient(p, "INFO", message)
    end
end

local function EnvoyerDiscord(titre, message)
    if Config.DiscordWebhookURL == "" then return end
    local ok = pcall(function()
        HttpService:PostAsync(Config.DiscordWebhookURL,
            HttpService:JSONEncode({
                embeds = {{ title=titre, description=message,
                    footer={ text="DobiGames · " .. Config.NomDuJeu } }}
            }),
            Enum.HttpContentType.ApplicationJson)
    end)
end

local function DemarrerEvent(typeEvent)
    -- En TEST_MODE : durée de l'event réduite (EventDureeMinutes = 0.1 → 6s)
    local dureeEvent = GetConfig("EventDureeMinutes", 5) * 60
    local configs = {
        LuckyHour   = { mult=10, duree=dureeEvent, msg="⭐ LUCKY HOUR ! Spawn ×10 !"                                },
        MeteorDrop  = { mult=20, duree=dureeEvent, msg="☄️ METEOR DROP ! Rares tombent du ciel !"                   },
        DoubleCoins = { mult=5,  duree=dureeEvent, msg="💰 DOUBLE COINS ! ×5 !"                                     },
        SecretSpawn = { mult=1,  duree=dureeEvent, msg="🔴 SECRET SPAWN ! " .. Config.CollectibleName .. " rare !" },
    }
    local cfg = configs[typeEvent]
    if not cfg then return end
    NotifierTous(cfg.msg, Color3.fromRGB(255,200,0))
    BrainRotSpawner.SetEventMultiplier(cfg.mult)
    local es = game.ReplicatedStorage:FindFirstChild("EventStarted")
    if es then es:FireAllClients(typeEvent, cfg.duree) end
    task.delay(cfg.duree, function()
        BrainRotSpawner.SetEventMultiplier(1)
        local ee = game.ReplicatedStorage:FindFirstChild("EventEnded")
        if ee then ee:FireAllClients() end
    end)
end

local function BoucleAuto()
    local intervalle   = GetConfig("EventIntervalleMinutes", Config.EventIntervalleMinutes) * 60
    -- En test l'earlyBird est ignoré (intervalle trop court pour avoir un pre-avis)
    local earlyBird    = Config.TEST_MODE and 0 or (Config.EarlyBirdBonusMinutes * 60)
    local types        = { "LuckyHour", "MeteorDrop", "DoubleCoins", "SecretSpawn" }
    while true do
        task.wait(intervalle - earlyBird)
        NotifierTous("⏰ Event dans 1h ! Reste connecté pour l'Early Bird 🎁", Color3.fromRGB(100,200,255))
        EnvoyerDiscord("⏰ Event dans 1h !", "**" .. Config.NomDuJeu .. "** — Admin Abuse dans 1 heure !\n🎁 Early Bird pour ceux déjà connectés !")
        task.wait(earlyBird)
        local choix = types[math.random(1, #types)]
        DemarrerEvent(choix)
        EnvoyerDiscord("🔥 EVENT EN COURS !", "**" .. Config.NomDuJeu .. "** — " .. choix .. " actif maintenant !")
    end
end

local function BoucleAdminAbuseHebdo()
    local cfg = Config.AdminAbuseHebdo
    while true do
        task.wait(60)
        local now = os.date("!*t")
        if now.wday == cfg.jourSemaine and now.hour == cfg.heureUTC and now.min == 0 then
            NotifierTous("🔥 ADMIN ABUSE HEBDO ! Spawn ×" .. cfg.spawnMultiplier .. " pendant " .. cfg.dureeMinutes .. " min !", Color3.fromRGB(255,50,50))
            EnvoyerDiscord("🔥 ADMIN ABUSE HEBDOMADAIRE !", "@everyone\n**" .. Config.NomDuJeu .. "** — Spawn ×" .. cfg.spawnMultiplier .. " pendant " .. cfg.dureeMinutes .. " min !\n[Jouer maintenant](https://www.roblox.com/games)")
            CollectSystem.SetEventMultiplier(cfg.spawnMultiplier)
            task.delay(cfg.dureeMinutes * 60, function()
                CollectSystem.SetEventMultiplier(1)
                NotifierTous("Admin Abuse terminé. À samedi prochain !", Color3.fromRGB(200,200,200))
                EnvoyerDiscord("✅ Admin Abuse terminé", "Merci à tous ! Prochain event **samedi prochain**. 🔔")
            end)
        end
    end
end

function EventManager.Init()
    task.spawn(BoucleAuto)
    task.spawn(BoucleAdminAbuseHebdo)
    print("[EventManager] Events automatiques démarrés ✓")
end

function EventManager.DeclenchemantManuel(typeEvent)
    DemarrerEvent(typeEvent)
end

return EventManager
