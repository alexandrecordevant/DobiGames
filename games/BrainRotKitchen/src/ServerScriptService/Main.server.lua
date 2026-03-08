-- ServerScriptService/Main.server.lua
-- BrainRot Idle Engine v1 — Boot principal
-- DobiGames · Ne pas modifier sauf ajout de RemoteEvents

local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")

-- ═══════════════════════════════════════════════
-- 1. CHARGEMENT DES MODULES
-- ═══════════════════════════════════════════════

local Config             = require(ReplicatedStorage.Modules.GameConfig)
local CollectSystem      = require(ReplicatedStorage.Modules.CollectSystem)
local UpgradeSystem      = require(ReplicatedStorage.Modules.UpgradeSystem)

local DataStoreManager   = require(ServerScriptService.DataStoreManager)
local SpawnManager       = require(ServerScriptService.SpawnManager)
local EventManager       = require(ServerScriptService.EventManager)
local MonetizationHandler = require(ServerScriptService.MonetizationHandler)

-- ═══════════════════════════════════════════════
-- 2. CRÉATION DES REMOTEEVENTS (côté serveur, toujours ici)
-- ═══════════════════════════════════════════════

local function CreerRemoteEvent(nom)
    local existing = ReplicatedStorage:FindFirstChild(nom)
    if existing then return existing end
    local re = Instance.new("RemoteEvent")
    re.Name = nom
    re.Parent = ReplicatedStorage
    return re
end

local function CreerRemoteFunction(nom)
    local existing = ReplicatedStorage:FindFirstChild(nom)
    if existing then return existing end
    local rf = Instance.new("RemoteFunction")
    rf.Name = nom
    rf.Parent = ReplicatedStorage
    return rf
end

-- Events serveur → client
local UpdateHUD          = CreerRemoteEvent("UpdateHUD")
local NotifEvent         = CreerRemoteEvent("NotifEvent")
local EventStarted       = CreerRemoteEvent("EventStarted")
local EventEnded         = CreerRemoteEvent("EventEnded")
local OfflineIncomeNotif = CreerRemoteEvent("OfflineIncomeNotif")
local SecretRevealNotif  = CreerRemoteEvent("SecretRevealNotif")
local CollectVFX         = CreerRemoteEvent("CollectVFX")

-- Events client → serveur (actions joueur)
local DemandeUpgrade     = CreerRemoteEvent("DemandeUpgrade")
local DemandePrestige    = CreerRemoteEvent("DemandePrestige")
local DemandeCollecte    = CreerRemoteEvent("DemandeCollecte")

-- Functions (requêtes avec réponse)
local GetPlayerData      = CreerRemoteFunction("GetPlayerData")
local GetUpgradeCost     = CreerRemoteFunction("GetUpgradeCost")

print("[" .. Config.NomDuJeu .. "] RemoteEvents créés ✓")

-- ═══════════════════════════════════════════════
-- 3. STOCKAGE DES DONNÉES EN MÉMOIRE (par joueur)
-- ═══════════════════════════════════════════════

local playerDataCache = {}  -- { [userId] = data }

local function GetData(player)
    return playerDataCache[player.UserId]
end

local function SetData(player, data)
    playerDataCache[player.UserId] = data
end

-- ═══════════════════════════════════════════════
-- 4. CONNEXION JOUEUR
-- ═══════════════════════════════════════════════

local function OnPlayerAdded(player)
    -- Charger données (avec calcul offline income)
    local data = DataStoreManager.Load(player)
    SetData(player, data)
    
    -- Vérifier Game Passes
    MonetizationHandler.CheckGamePasses(player, data)
    
    -- Envoyer HUD initial
    task.wait(1)  -- laisser le client charger
    UpdateHUD:FireClient(player, data)
    
    -- Lancer auto-save
    DataStoreManager.StartAutoSave(player, function()
        return GetData(player)
    end)
    
    -- Lancer collecte automatique si Auto Collect Pass
    if data.hasAutoCollect then
        SpawnManager.StartAutoCollect(player, data)
    end
    
    print("[" .. Config.NomDuJeu .. "] " .. player.Name .. " connecté (Tier " .. data.tier .. ", Prestige " .. data.prestige .. ")")
end

local function OnPlayerRemoving(player)
    local data = GetData(player)
    if data then
        DataStoreManager.Save(player, data)
        playerDataCache[player.UserId] = nil
        print("[" .. Config.NomDuJeu .. "] " .. player.Name .. " sauvegardé et déconnecté")
    end
end

Players.PlayerAdded:Connect(OnPlayerAdded)
Players.PlayerRemoving:Connect(OnPlayerRemoving)

-- Sauvegarde d'urgence si le serveur s'arrête
game:BindToClose(function()
    for _, player in ipairs(Players:GetPlayers()) do
        local data = GetData(player)
        if data then
            DataStoreManager.Save(player, data)
        end
    end
    print("[" .. Config.NomDuJeu .. "] Sauvegarde d'urgence terminée")
end)

-- ═══════════════════════════════════════════════
-- 5. GESTION DES ACTIONS JOUEUR (validation serveur)
-- ═══════════════════════════════════════════════

-- Collecte manuelle (touch d'un collectible)
DemandeCollecte.OnServerEvent:Connect(function(player, collectibleId, rarete)
    local data = GetData(player)
    if not data then return end
    
    -- Anti-exploit : valider que le collectible existe bien
    local collectible = workspace.SpawnZones:FindFirstChild(collectibleId)
    if not collectible then return end
    
    -- Distance check (anti-exploit téléportation)
    local char = player.Character
    if char and char.PrimaryPart then
        local distance = (char.PrimaryPart.Position - collectible.Position).Magnitude
        if distance > 20 then return end  -- trop loin = exploit
    end
    
    -- Appliquer la collecte
    local valeur = rarete and rarete.valeur or 1
    local multiplier = CollectSystem.GetMultiplier(data)
    local coinsGagnes = math.floor(valeur * multiplier)
    
    data.coins = data.coins + coinsGagnes
    data.totalCollecte = (data.totalCollecte or 0) + 1
    
    -- Mettre à jour coinsParMinute (moyenne mobile)
    data.coinsParMinute = math.max(data.coinsParMinute or 1, coinsGagnes)
    
    -- Supprimer le collectible du serveur
    collectible:Destroy()
    
    -- Notifier le client (VFX + HUD)
    CollectVFX:FireClient(player, coinsGagnes, rarete)
    UpdateHUD:FireClient(player, data)
end)

-- Upgrade
DemandeUpgrade.OnServerEvent:Connect(function(player)
    local data = GetData(player)
    if not data then return end
    
    local success, result = UpgradeSystem.AppliquerUpgrade(data)
    if success then
        SetData(player, result)
        UpdateHUD:FireClient(player, result)
        
        -- Proposer monétisation au bon moment
        local rule = MonetizationHandler.CheckPromptRules(result)
        if rule then
            NotifEvent:FireClient(player, "PROMPT_MONETISATION", rule)
        end
    else
        NotifEvent:FireClient(player, "ERREUR", result)
    end
end)

-- Prestige
DemandePrestige.OnServerEvent:Connect(function(player)
    local data = GetData(player)
    if not data then return end
    
    local success, result = UpgradeSystem.AppliquerPrestige(data)
    if success then
        SetData(player, result)
        UpdateHUD:FireClient(player, result)
        NotifEvent:FireClient(player, "PRESTIGE", "Prestige " .. result.prestige .. " atteint ! Multiplicateur x" .. (result.prestige * (Config.PrestigeMultiplier - 1) + 1))
    else
        NotifEvent:FireClient(player, "ERREUR", result)
    end
end)

-- RemoteFunction : données joueur (pour HUD)
GetPlayerData.OnServerInvoke = function(player)
    return GetData(player)
end

-- RemoteFunction : coût prochain upgrade
GetUpgradeCost.OnServerInvoke = function(player)
    local data = GetData(player)
    if not data then return 0 end
    return UpgradeSystem.GetCoutUpgrade(data.tier)
end

-- ═══════════════════════════════════════════════
-- 6. INIT DES SYSTÈMES
-- ═══════════════════════════════════════════════

-- Spawn des collectibles sur la map
SpawnManager.Init()

-- Démarrer les events automatiques (Admin Abuse, Lucky Hour...)
EventManager.Init()

print("[" .. Config.NomDuJeu .. "] 🚀 Serveur démarré · " .. os.date("%d/%m/%Y %H:%M"))
