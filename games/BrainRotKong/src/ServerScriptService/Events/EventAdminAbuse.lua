-- ServerScriptService/Events/EventAdminAbuse.lua
-- Admin Abuse : arc-en-ciel sol + Rainbow With Clouds + auto-collect + quêtes flash

local EventAdminAbuse = {}

-- ============================================================
-- Services
-- ============================================================
local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")
local ServerStorage     = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Logger = require(ServerScriptService.SharedLib.Server.Logger)

-- ============================================================
-- Modules chargés à la demande (évite les dépendances circulaires)
-- ============================================================
local _CollectSystem, _IncomeSystem, _SpawnManager = nil, nil, nil

local function getCollectSystem()
    if not _CollectSystem then
        local ok, m = pcall(require, ServerScriptService.SharedLib.Shared.CollectSystem)
        if ok then _CollectSystem = m end
    end
    return _CollectSystem
end

local function getIncomeSystem()
    if not _IncomeSystem then
        local ok, m = pcall(require, ServerScriptService.SharedLib.Server.IncomeSystem)
        if ok then _IncomeSystem = m end
    end
    return _IncomeSystem
end

local function getSpawnManager()
    if not _SpawnManager then
        local ok, m = pcall(require, ServerScriptService.SpawnManager)
        if ok then
            _SpawnManager = m
        else
            Logger.warn("Event", "[AdminAbuse] require SpawnManager échoué : %s", tostring(m))
        end
    end
    return _SpawnManager
end

-- ============================================================
-- Dépendances injectées depuis Main.server.lua
-- (même pattern que LeaderboardSystem.GetPlayerData)
-- ============================================================
EventAdminAbuse.GetPlayerData    = nil
EventAdminAbuse.FireUpdateHUD    = nil

-- ============================================================
-- État interne
-- ============================================================
local actif             = false
local savedMap          = {}
local rainbowThread     = nil
local autoCollectThread = nil
local rainbowClouds     = nil
local compteurs         = {}   -- { [userId] = nbCollectes }
local questAcomplis     = {}   -- { [userId] = { [seuilIndex] = true } }
local questSeuils       = {}   -- copie depuis config

-- ============================================================
-- API publique (lue depuis Main.server.lua)
-- ============================================================
function EventAdminAbuse.EstActif()
    return actif
end

-- Appelé depuis DemandeCollecte.OnServerEvent à chaque collecte
function EventAdminAbuse.OnCollect(player)
    if not actif then return end
    local uid = player.UserId
    compteurs[uid] = (compteurs[uid] or 0) + 1
    -- Vérifier les seuils de quête
    for i, q in ipairs(questSeuils) do
        if compteurs[uid] >= q.seuil and not (questAcomplis[uid] and questAcomplis[uid][i]) then
            questAcomplis[uid]    = questAcomplis[uid] or {}
            questAcomplis[uid][i] = true
            -- Récompense : spawn de Brainrots de la rareté voulue dans la base du joueur
            local rarete = q.rarete or q.seed or "MYTHIC"  -- q.seed = compat ancienne config BRF
            local qty    = q.qty or 1
            local SM = getSpawnManager()
            if SM and SM.GetBase and SM.SpawnerBRDansBase then
                local baseIndex = SM.GetBase(player)
                if baseIndex then
                    for _ = 1, qty do
                        pcall(SM.SpawnerBRDansBase, baseIndex, rarete)
                    end
                end
            end
            local label = (qty > 1) and (qty .. "x " .. rarete) or rarete
            local ev = ReplicatedStorage:FindFirstChild("NotifEvent")
            if ev then
                pcall(function()
                    ev:FireClient(player, "SUCCESS",
                        string.format("QUEST! %d BRs collected! +%s Brainrot!", q.seuil, label))
                end)
            end
            Logger.info("Event", "AdminAbuse quête %d accomplie par %s (+%dx %s Brainrot)", q.seuil, player.Name, qty, rarete)
        end
    end
end

-- ============================================================
-- Notifications
-- ============================================================
local function notifierTous(message)
    local ev = ReplicatedStorage:FindFirstChild("NotifEvent")
    if ev then pcall(function() ev:FireAllClients("INFO", message) end) end
end

-- ============================================================
-- Rainbow With Clouds
-- ============================================================
local function spawnRainbowClouds()
    local folder = ServerStorage:FindFirstChild("events") or ServerStorage:FindFirstChild("Events")
    if not folder then
        Logger.warn("Event", "AdminAbuse : ServerStorage/events introuvable")
        return
    end
    local template = folder:FindFirstChild("Rainbow With Clouds")
    if not template then
        Logger.warn("Event", "AdminAbuse : 'Rainbow With Clouds' introuvable dans ServerStorage/events")
        return
    end
    rainbowClouds = template:Clone()
    rainbowClouds.Parent = Workspace
    Logger.info("Event", "AdminAbuse : Rainbow With Clouds spawné")
end

local function retirerRainbowClouds()
    if rainbowClouds and rainbowClouds.Parent then
        rainbowClouds:Destroy()
    end
    rainbowClouds = nil
end

-- ============================================================
-- Sol arc-en-ciel (couleur uniquement, pas de changement de matériau)
-- ============================================================
local function appliquerSol()
    savedMap = {}
    local map = Workspace:FindFirstChild("Map")
    if not map then return end
    for _, obj in ipairs(map:GetDescendants()) do
        if obj:IsA("BasePart") then
            savedMap[obj] = obj.Color
        end
    end
end

local function restaurerSol()
    for part, color in pairs(savedMap) do
        if part and part.Parent then
            pcall(function() part.Color = color end)
        end
    end
    savedMap = {}
end

local function demarrerRainbow()
    rainbowThread = task.spawn(function()
        local hue = 0
        while actif do
            hue = (hue + 0.002) % 1
            local couleur = Color3.fromHSV(hue, 1, 1)
            for part in pairs(savedMap) do
                if part.Parent then
                    part.Color = couleur
                end
            end
            task.wait(0.05)
        end
    end)
end

local function arreterRainbow()
    if rainbowThread then
        pcall(task.cancel, rainbowThread)
        rainbowThread = nil
    end
end

-- ============================================================
-- Auto-collect global (toutes les N secondes)
-- ============================================================
local function demarrerAutoCollect(interval)
    local IS = getIncomeSystem()
    if not IS then
        Logger.warn("Event", "AdminAbuse : IncomeSystem indisponible, auto-collect désactivé")
        return
    end
    autoCollectThread = task.spawn(function()
        while actif do
            task.wait(interval)
            if not actif then break end
            for _, player in ipairs(Players:GetPlayers()) do
                pcall(function()
                    local collecte = IS.CollecterTousLesSlots(player)
                    if collecte > 0 and EventAdminAbuse.GetPlayerData and EventAdminAbuse.FireUpdateHUD then
                        local data = EventAdminAbuse.GetPlayerData(player)
                        if data then EventAdminAbuse.FireUpdateHUD(player, data) end
                    end
                end)
            end
        end
    end)
end

local function arreterAutoCollect()
    if autoCollectThread then
        pcall(task.cancel, autoCollectThread)
        autoCollectThread = nil
    end
end

-- ============================================================
-- API — Demarrer / Terminer (appelés par EventVisuals)
-- ============================================================
function EventAdminAbuse.Demarrer(config)
    actif         = true
    questSeuils   = config.questSeuils or {}
    compteurs     = {}
    questAcomplis = {}

    -- Notification + EventStarted (pour le client HUD)
    notifierTous(config.message or "ADMIN ABUSE!")
    local es = ReplicatedStorage:FindFirstChild("EventStarted")
    if es then pcall(function() es:FireAllClients("AdminAbuse", config.duree or 2700) end) end

    -- Annoncer les quêtes flash avec un délai pour ne pas noyer la notif principale
    task.delay(4, function()
        if not actif then return end
        notifierTous("QUESTS: 10 BRs=1 MYTHIC · 25=2 MYTHIC · 50=3 MYTHIC · 100=1 SECRET Brainrot!")
    end)

    -- Annoncer la chance OG
    task.delay(8, function()
        if not actif then return end
        notifierTous("OG Brain Rots can appear during Admin Abuse! Extremely rare — good luck!")
    end)

    -- Multiplicateurs spawn + income
    local CS = getCollectSystem()
    if CS then CS.SetEventMultiplier(config.spawnMultiplier or 50) end
    local IS = getIncomeSystem()
    if IS then IS.SetEventMultiplier(config.incomeMultiplier or 5) end

    -- Pool de spawn Admin Abuse (tous les BR + mutants)
    local SM = getSpawnManager()
    if SM and SM.SetAdminAbuseMode then
        local ok, err = pcall(SM.SetAdminAbuseMode, true, config)
        if not ok then
            Logger.warn("Event", "[AdminAbuse] SetAdminAbuseMode erreur : %s", tostring(err))
        end
    else
        Logger.warn("Event", "[AdminAbuse] SpawnManager ou SetAdminAbuseMode introuvable (SM=%s)", tostring(SM))
    end

    -- Visuels
    spawnRainbowClouds()
    appliquerSol()
    demarrerRainbow()

    -- Auto-collect
    demarrerAutoCollect(config.autoCollectInterval or 20)

    Logger.info("Event", "▶ AdminAbuse démarré — spawn×%d income×%d autocollect/%ds",
        config.spawnMultiplier or 50, config.incomeMultiplier or 5, config.autoCollectInterval or 20)
end

function EventAdminAbuse.Terminer()
    actif = false

    arreterRainbow()
    arreterAutoCollect()
    restaurerSol()
    retirerRainbowClouds()

    local CS = getCollectSystem()
    if CS then CS.SetEventMultiplier(1) end
    local IS = getIncomeSystem()
    if IS then IS.SetEventMultiplier(1) end

    -- Désactiver la pool Admin Abuse — retour spawn normal
    local SM = getSpawnManager()
    if SM and SM.SetAdminAbuseMode then
        pcall(SM.SetAdminAbuseMode, false)
    end

    compteurs     = {}
    questAcomplis = {}

    notifierTous("Admin Abuse ended. See you next Saturday!")
    Logger.info("Event", "■ AdminAbuse terminé")
end

return EventAdminAbuse
