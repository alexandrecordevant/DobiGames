-- ServerScriptService/Main.server.lua
-- LavaTower — Boot principal

local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players             = game:GetService("Players")
local Workspace           = game:GetService("Workspace")

-- ═══════════════════════════════════════════════
-- 1. MODULES
-- ═══════════════════════════════════════════════

local Config                = require(ReplicatedStorage.Modules.GameConfig)
local RebirthConfig         = require(ReplicatedStorage.Modules.RebirthConfig)
local UpgradeSystem         = require(ReplicatedStorage.Modules.UpgradeSystem)
local DataStoreManager      = require(ServerScriptService.DataStoreManager)
local MonetizationHandler   = require(ServerScriptService.MonetizationHandler)
local AssignationSystem     = require(ServerScriptService.SharedLib.Server.AssignationSystem)
local BaseProgressionSystem = require(ServerScriptService.SharedLib.Server.BaseProgressionSystem)
local RebirthSystem         = require(ServerScriptService.SharedLib.Server.RebirthSystem)
local CarrySystem           = require(ServerScriptService.SharedLib.Server.CarrySystem)
local DropSystem                = require(ServerScriptService.SharedLib.Server.DropSystem)
local IncomeSystem              = require(ServerScriptService.SharedLib.Server.IncomeSystem)
local BoardSystem               = require(ServerScriptService.BoardSystem)
local RebirthCosmeticsSystem    = require(ServerScriptService.SharedLib.Server.RebirthCosmeticsSystem)

-- DataStore — inclut les champs requis par shared-lib
DataStoreManager.Setup("LavaTowerV1", function()
    return {
        coins                   = 0,
        tier                    = 0,
        prestige                = 0,
        inventory               = {},
        hasVIP                  = false,
        hasOfflineVault         = false,
        hasAutoCollect          = false,
        derniereConnexion       = os.time(),
        totalCollecte           = 0,
        stats                   = { sessionsCount = 0, totalHeuresJeu = 0 },
        -- champs requis par shared-lib
        rebirthLevel            = 0,
        multiplicateurPermanent = 1.0,
        slotsBonus              = 0,
        progression             = {},
        spotsOccupes            = {},
    }
end)

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

-- HUD avec coins réels (data.coins + coins en attente dans les slots)
local function EnvoyerHUD(player, data)
    local extraCoins  = IncomeSystem.GetCoinsEnAttente(player) or 0
    local hudData     = {}
    for k, v in pairs(data) do hudData[k] = v end
    hudData.coins     = (data.coins or 0) + extraCoins
    UpdateHUD:FireClient(player, hudData)
end

-- ═══════════════════════════════════════════════
-- 4. INJECTIONS SHARED-LIB (globales)
-- ═══════════════════════════════════════════════

-- RebirthSystem — config tiers + condition progression (identique BrainRotFarm)
RebirthSystem.Config = RebirthConfig.Tiers
RebirthSystem.IsProgressionComplete = function(playerData)
    return playerData.progression and playerData.progression["4_10"] == true
end

-- CarrySystem — source de vérité pour la base du joueur
CarrySystem.GetBaseJoueur = function(player)
    return AssignationSystem.GetBaseIndex(player)
end

-- RebirthSystem — coins en attente comptent pour vérifier les conditions
RebirthSystem.GetExtraCoins = function(player)
    return IncomeSystem.GetCoinsEnAttente(player) or 0
end
RebirthSystem.OnButtonUpdate = function(player, etat)
    BoardSystem.MettreAJourBoard(player, etat)
end

-- RebirthCosmeticsSystem — source de données
RebirthCosmeticsSystem.GetData = GetData

-- ═══════════════════════════════════════════════
-- 5. CONNEXION JOUEUR
-- ═══════════════════════════════════════════════

local function OnPlayerAdded(player)
    local data = DataStoreManager.Load(player)
    SetData(player, data)

    MonetizationHandler.CheckGamePasses(player, data)

    task.wait(1)
    EnvoyerHUD(player, data)

    local baseIndex = AssignationSystem.AssignerJoueur(player)
    if baseIndex then
        BaseProgressionSystem.Init(player, baseIndex, data)
        BaseProgressionSystem.VerifierDeblocages(player, data)

        local spotsActifs = BaseProgressionSystem.GetSpotsActifs(player)
        CarrySystem.InitDepotSpotsBase(player, spotsActifs)

        DropSystem.Init(player, baseIndex, data)
        IncomeSystem.Init(player, function() return GetData(player) end)

        RebirthSystem.OnRebirthComplete = function(p, niveau, cfg)
            local spotsApres = BaseProgressionSystem.GetSpotsActifs(p)
            CarrySystem.InitDepotSpotsBase(p, spotsApres)
            pcall(BaseProgressionSystem.DebloquerFloorApresRebirth, p, niveau)
            pcall(BoardSystem.MettreAJourBoard, p, {
                rebirthLevel   = niveau,
                coinsActuels   = 0,
                coinsRequis    = cfg and cfg.coinsRequis or 0,
                brainRotRequis = cfg and cfg.brainRotRequis and cfg.brainRotRequis.rarete or "?",
                label          = cfg and cfg.label or nil,
            })
        end
        RebirthSystem.OnResetBase = function(p, bIndex, d)
            DropSystem.Stop(p)
            IncomeSystem.Stop(p)
            DropSystem.Init(p, bIndex, d)
            IncomeSystem.Init(p, function() return GetData(p) end)
        end
        RebirthSystem.Init(player, data, baseIndex)

        if player.Character then
            RebirthCosmeticsSystem.AppliquerPourJoueur(player, player.Character)
        end
        player.CharacterAdded:Connect(function(character)
            RebirthCosmeticsSystem.AppliquerPourJoueur(player, character)
        end)
    end

    DataStoreManager.StartAutoSave(player, function()
        return GetData(player)
    end)

    print("[" .. Config.NomDuJeu .. "] " .. player.Name .. " connecté")
end

local function OnPlayerRemoving(player)
    IncomeSystem.Stop(player)

    local data = GetData(player)
    if data then
        -- Synchroniser spotsOccupes avant sauvegarde
        data.spotsOccupes = DropSystem.GetSpotsOccupesSerialisables(player)

        DataStoreManager.Save(player, data)
        playerDataCache[player.UserId] = nil
        BaseProgressionSystem.Reset(player)
        RebirthSystem.Reset(player)
        DropSystem.Stop(player)
        AssignationSystem.LibererBase(player)
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
-- 6. ACTIONS JOUEUR
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
-- 7. ASSIGNATION — spawn devant la base assignée
-- ═══════════════════════════════════════════════

AssignationSystem.GetSpawnCFrame = function(baseIndex)
    local bases    = Workspace:FindFirstChild("Bases")
    local base     = bases and bases:FindFirstChild("Base_" .. baseIndex)
    local shared   = base and base:FindFirstChild("Shared")
    local spawnLoc = shared and shared:FindFirstChild("SpawnLocation")
    if spawnLoc then
        return spawnLoc.CFrame + Vector3.new(0, 3, 0)
    end
    return nil
end

AssignationSystem.Init()
BoardSystem.Init()
RebirthCosmeticsSystem.Init()

-- ═══════════════════════════════════════════════
-- 8. DÉMARRAGE
-- ═══════════════════════════════════════════════

print("[" .. Config.NomDuJeu .. "] 🚀 Serveur démarré · " .. os.date("%d/%m/%Y %H:%M"))
