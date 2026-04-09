-- ServerScriptService/Events/EventLuckyHour.lua
-- BrainRotFarm — Lucky Hour Event
-- Des BR RARE/EPIC/LEGENDARY spawnnent directement sur les bases occupées des joueurs

local EventLuckyHour = {}
EventLuckyHour.NOM          = "LuckyHour"
EventLuckyHour.DUREE_DEFAUT = 60

-- ============================================================
-- Services
-- ============================================================
local Players             = game:GetService("Players")
local Lighting            = game:GetService("Lighting")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- ============================================================
-- Dépendances
-- ============================================================
local Logger      = require(ServerScriptService.SharedLib.Server.Logger)

-- ============================================================
-- Chargement différé de SpawnManager
-- ============================================================
local _SpawnManager = nil
local function getSpawnManager()
    if not _SpawnManager then
        local ok, m = pcall(require, ServerScriptService.SpawnManager)
        if ok and m then _SpawnManager = m end
    end
    return _SpawnManager
end

-- ============================================================
-- État interne
-- ============================================================
local actif          = false
local spawnThread    = nil
local colorCorrection = nil  -- Instance ColorCorrection créée pendant l'event

-- ============================================================
-- Utilitaires
-- ============================================================
local function notifierTous(message)
    local ev = ReplicatedStorage:FindFirstChild("NotifEvent")
    if ev then pcall(function() ev:FireAllClients("INFO", message) end) end
end

-- Tirage pondéré dans le pool de rareté
-- rarityPool = { RARE = 60, EPIC = 35, LEGENDARY = 5 }
local function tirerRarete(rarityPool)
    local total = 0
    for _, poids in pairs(rarityPool) do
        total = total + poids
    end
    local roll = math.random() * total
    local cumul = 0
    for nom, poids in pairs(rarityPool) do
        cumul = cumul + poids
        if roll <= cumul then
            return nom
        end
    end
    -- Fallback au cas où
    return "RARE"
end

-- ============================================================
-- Visuel : ColorCorrection violette
-- ============================================================
local function activerAmbiance(couleur)
    -- Chercher ou créer le ColorCorrection dans Lighting
    colorCorrection = Lighting:FindFirstChildOfClass("ColorCorrection")
    if not colorCorrection then
        colorCorrection = Instance.new("ColorCorrection")
        colorCorrection.Parent = Lighting
    end
    -- Teinte violette via TintColor
    pcall(function()
        colorCorrection.TintColor = couleur
        colorCorrection.Saturation = 0.4
        colorCorrection.Brightness = 0.05
    end)
end

local function desactiverAmbiance()
    if colorCorrection then
        pcall(function()
            colorCorrection.TintColor   = Color3.fromRGB(255, 255, 255)
            colorCorrection.Saturation  = 0
            colorCorrection.Brightness  = 0
        end)
        -- Ne pas détruire si le ColorCorrection existait déjà avant l'event
        colorCorrection = nil
    end
end

-- ============================================================
-- Boucle de spawn sur les bases occupées
-- ============================================================
local function boucleSpawn(config)
    local rarityPool    = config.rarityPool    or { RARE = 60, EPIC = 35, LEGENDARY = 5 }
    local spawnInterval = config.spawnInterval or 10

    while actif do
        task.wait(spawnInterval)
        if not actif then break end

        local SM = getSpawnManager()
        if not SM then continue end

        -- Itérer sur tous les joueurs connectés
        for _, player in ipairs(Players:GetPlayers()) do
            local baseIndex = SM.GetBase(player)
            if baseIndex then
                local rareteNom = tirerRarete(rarityPool)
                pcall(SM.SpawnerBRDansBase, baseIndex, rareteNom)
                Logger.debug("Event", "LuckyHour : %s spawné sur Base_%d (%s)", rareteNom, baseIndex, player.Name)
            end
        end
    end
end

-- ============================================================
-- API
-- ============================================================

function EventLuckyHour.Demarrer(config)
    actif = true

    -- Notifier + EventStarted
    notifierTous(config.message)
    local es = ReplicatedStorage:FindFirstChild("EventStarted")
    if es then pcall(function() es:FireAllClients("LuckyHour", config.duree) end) end

    -- Ambiance violette
    activerAmbiance(config.couleurAmbiance or Color3.fromRGB(180, 0, 255))

    -- Lancer la boucle de spawn
    spawnThread = task.spawn(function()
        -- Premier spawn immédiat après un court délai
        task.wait(2)
        if not actif then return end

        local SM = getSpawnManager()
        if SM then
            for _, player in ipairs(Players:GetPlayers()) do
                local baseIndex = SM.GetBase(player)
                if baseIndex then
                    local rareteNom = tirerRarete(config.rarityPool or { RARE = 60, EPIC = 35, LEGENDARY = 5 })
                    pcall(SM.SpawnerBRDansBase, baseIndex, rareteNom)
                end
            end
        end

        boucleSpawn(config)
    end)

    Logger.info("Event", "▶ Lucky Hour démarré (%ds) — interval %ds", config.duree or EventLuckyHour.DUREE_DEFAUT, config.spawnInterval or 10)
end

function EventLuckyHour.Terminer()
    actif = false

    -- Arrêter la boucle
    if spawnThread then
        pcall(task.cancel, spawnThread)
        spawnThread = nil
    end

    -- Restaurer l'ambiance
    desactiverAmbiance()

    Logger.info("Event", "■ Lucky Hour terminé")
end

return EventLuckyHour
