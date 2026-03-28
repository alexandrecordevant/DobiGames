-- ServerScriptService/Main.server.lua
-- LavaTower — Boot principal (sans système de spawn idle)

local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players             = game:GetService("Players")

-- ═══════════════════════════════════════════════
-- 1. MODULES
-- ═══════════════════════════════════════════════

local Config              = require(ReplicatedStorage.Modules.GameConfig)
local UpgradeSystem       = require(ReplicatedStorage.Modules.UpgradeSystem)
local DataStoreManager    = require(ServerScriptService.DataStoreManager)
local MonetizationHandler = require(ServerScriptService.MonetizationHandler)
local RebirthCallbacks    = require(ServerScriptService._RebirthCallbacks)

-- DataStore — nom explicite (garde la clé existante des joueurs)
DataStoreManager.Setup("BrainRotIdleV1")

-- ═══════════════════════════════════════════════
-- 2. REMOTEEVENTS
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

local UpdateHUD          = CreerRemoteEvent("UpdateHUD")
local NotifEvent         = CreerRemoteEvent("NotifEvent")
local OfflineIncomeNotif = CreerRemoteEvent("OfflineIncomeNotif")
local DemandeUpgrade     = CreerRemoteEvent("DemandeUpgrade")
local DemandePrestige    = CreerRemoteEvent("DemandePrestige")
local GetPlayerData      = CreerRemoteFunction("GetPlayerData")
local GetUpgradeCost     = CreerRemoteFunction("GetUpgradeCost")

print("[" .. Config.NomDuJeu .. "] RemoteEvents créés ✓")

-- ═══════════════════════════════════════════════
-- 3. DONNÉES JOUEURS
-- ═══════════════════════════════════════════════

local playerDataCache = {}

local function GetData(player)
    return playerDataCache[player.UserId]
end

local function SetData(player, data)
    playerDataCache[player.UserId] = data
end

-- Injection des callbacks pour RebirthServer
RebirthCallbacks.SetCallbacks(
    -- GetMoney
    function(player)
        local data = GetData(player)
        return data and data.coins or 0
    end,
    -- DeductMoney
    function(player, amount)
        local data = GetData(player)
        if data then
            data.coins = math.max(0, data.coins - amount)
            UpdateHUD:FireClient(player, data)
        end
    end,
    -- ConsumeRarity : délégué à BrainrotInventoryService si disponible
    function(player, rarity)
        local ok, BrainrotInventoryService = pcall(function()
            return require(ServerScriptService.SharedLib.Server.BrainrotInventoryService)
        end)
        if ok and BrainrotInventoryService and BrainrotInventoryService.RemoveOneOfRarity then
            BrainrotInventoryService.RemoveOneOfRarity(player, rarity)
        else
            warn("[Main] ConsumeRarity: BrainrotInventoryService.RemoveOneOfRarity indisponible")
        end
    end
)

-- ═══════════════════════════════════════════════
-- 4. CONNEXION JOUEUR
-- ═══════════════════════════════════════════════

local function OnPlayerAdded(player)
    local data = DataStoreManager.Load(player)
    SetData(player, data)

    MonetizationHandler.CheckGamePasses(player, data)

    task.wait(1)
    UpdateHUD:FireClient(player, data)

    DataStoreManager.StartAutoSave(player, function()
        return GetData(player)
    end)

    print("[" .. Config.NomDuJeu .. "] " .. player.Name .. " connecté")
end

local function OnPlayerRemoving(player)
    local data = GetData(player)
    if data then
        DataStoreManager.Save(player, data)
        playerDataCache[player.UserId] = nil
        print("[" .. Config.NomDuJeu .. "] " .. player.Name .. " sauvegardé")
    end
end

Players.PlayerAdded:Connect(OnPlayerAdded)
Players.PlayerRemoving:Connect(OnPlayerRemoving)

game:BindToClose(function()
    for _, player in ipairs(Players:GetPlayers()) do
        local data = GetData(player)
        if data then DataStoreManager.Save(player, data) end
    end
end)

-- ═══════════════════════════════════════════════
-- 5. ACTIONS JOUEUR
-- ═══════════════════════════════════════════════

DemandeUpgrade.OnServerEvent:Connect(function(player)
    local data = GetData(player)
    if not data then return end

    local success, result = UpgradeSystem.AppliquerUpgrade(data)
    if success then
        SetData(player, result)
        UpdateHUD:FireClient(player, result)
        local rule = MonetizationHandler.CheckPromptRules(result)
        if rule then NotifEvent:FireClient(player, "PROMPT_MONETISATION", rule) end
    else
        NotifEvent:FireClient(player, "ERREUR", result)
    end
end)

DemandePrestige.OnServerEvent:Connect(function(player)
    local data = GetData(player)
    if not data then return end

    local success, result = UpgradeSystem.AppliquerPrestige(data)
    if success then
        SetData(player, result)
        UpdateHUD:FireClient(player, result)
        NotifEvent:FireClient(player, "PRESTIGE", "Prestige " .. result.prestige .. " atteint !")
    else
        NotifEvent:FireClient(player, "ERREUR", result)
    end
end)

GetPlayerData.OnServerInvoke = function(player)
    return GetData(player)
end

GetUpgradeCost.OnServerInvoke = function(player)
    local data = GetData(player)
    if not data then return 0 end
    return UpgradeSystem.GetCoutUpgrade(data.tier)
end

-- ═══════════════════════════════════════════════
-- 6. DÉMARRAGE
-- ═══════════════════════════════════════════════

print("[" .. Config.NomDuJeu .. "] 🚀 Serveur démarré · " .. os.date("%d/%m/%Y %H:%M"))
