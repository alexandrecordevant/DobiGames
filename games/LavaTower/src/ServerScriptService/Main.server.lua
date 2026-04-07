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
local Logger                = require(ServerScriptService.SharedLib.Server.Logger)
Logger.init(Config.LOG_LEVEL)
local RebirthConfig         = require(ReplicatedStorage.SharedLib.Shared.RebirthConfig)
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
Logger.debug("Main", "[FuseMachine] Chargement du module...")
local ShopSystem = require(ServerScriptService.ShopSystem)
local _fuseOk, FuseMachineSystem = pcall(require, ServerScriptService.FuseMachineSystem)
if not _fuseOk then
    Logger.error("Main", "[FuseMachine] ERREUR require : %s", tostring(FuseMachineSystem))
    FuseMachineSystem = nil
else
    Logger.info("Main", "[FuseMachine] Module chargé ✓")
end

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
        -- shop upgrades
        shopUpgrades            = { carry = 0, speed = 0, jump = 0 },
    }
end)

-- ═══════════════════════════════════════════════
-- 1b. LOGIQUE REBIRTH → SLOTS
-- Ordre de déblocage des slots par niveau de rebirth :
--   Rebirth 1  → Floor 2, Spot 1
--   Rebirth 2  → Floor 2, Spot 2  ...  Rebirth 10 → Floor 2, Spot 10
--   Rebirth 11 → Floor 3, Spot 1  ...  Rebirth 20 → Floor 3, Spot 10
--   Rebirth 21 → Floor 4, Spot 1  ...  Rebirth 30 → Floor 4, Spot 10
-- ═══════════════════════════════════════════════

local REBIRTH_SLOT_ORDER = {}
do
    for etage = 2, 4 do
        for spot = 1, 10 do
            table.insert(REBIRTH_SLOT_ORDER, { floor = etage, spot = spot })
        end
    end
end

-- Construit data.progression depuis le niveau de rebirth.
-- Appelé avant BaseProgressionSystem.Init pour que l'état visuel soit correct.
local function BuildProgressionFromRebirth(rebirthLevel)
    local prog = {}
    for i = 1, (rebirthLevel or 0) do
        local slotInfo = REBIRTH_SLOT_ORDER[i]
        if slotInfo then
            prog[slotInfo.floor .. "_" .. slotInfo.spot] = true
        end
    end
    return prog
end

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
local AssignBase         = CreerRemoteEvent("AssignBase")         -- notifie le client de son baseIndex
local GetPlayerData      = CreerRemoteFunction("GetPlayerData")
local GetUpgradeCost     = CreerRemoteFunction("GetUpgradeCost")

Logger.info("Main", "RemoteEvents créés ✓")

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

-- HUD avec coins réels collectés uniquement (pas les coins en attente dans les slots)
local function EnvoyerHUD(player, data)
    UpdateHUD:FireClient(player, data)
end

-- ═══════════════════════════════════════════════
-- 4. INJECTIONS SHARED-LIB (globales)
-- ═══════════════════════════════════════════════

-- RebirthSystem — config amélioration de base (pas de condition de progression requise)
RebirthSystem.Config = RebirthConfig

-- CarrySystem — source de vérité pour la base du joueur
CarrySystem.GetBaseJoueur = function(player)
    return AssignationSystem.GetBaseIndex(player)
end

-- DropSystem — mise à jour du bouton après dépôt/retrait/vente
DropSystem.OnSpotChange = function(player)
    RebirthSystem.MettreAJourBouton(player)
end
RebirthSystem.OnButtonUpdate = function(player, etat)
    BoardSystem.MettreAJourBoard(player, etat)
end

-- CarrySystem + DropSystem — dossier Brainrots dans ReplicatedStorage (LavaTower)
-- IMPORTANT : CarrySystem.Init() doit être appelé pour initialiser BRAINROTS_FOLDER
-- (utilisé par le fallback de clonage et par Retrieve)
local BrainrotsFolder = ReplicatedStorage:FindFirstChild("Brainrots")
if not BrainrotsFolder then
    Logger.warn("Main", "ReplicatedStorage.Brainrots introuvable — CarrySystem/DropSystem dégradés")
end
CarrySystem.Init(BrainrotsFolder)
DropSystem.SetBrainrotsFolder(BrainrotsFolder)

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
        -- Reconstruire la progression à partir du niveau rebirth AVANT Init.
        -- Garantit que les slots débloqués par rebirth sont corrects même après
        -- un changement de système ou une reconnexion.
        data.progression = BuildProgressionFromRebirth(data.rebirthLevel or 0)

        BaseProgressionSystem.Init(player, baseIndex, data)
        BaseProgressionSystem.VerifierDeblocages(player, data)

        local spotsActifs = BaseProgressionSystem.GetSpotsActifs(player)
        CarrySystem.InitDepotSpotsBase(player, spotsActifs)

        DropSystem.Init(player, baseIndex, data)
        IncomeSystem.Init(player, function() return GetData(player) end)

        -- Notifier le client de son baseIndex assigné (utilisé pour SlotTextStyle)
        task.delay(0.5, function()
            if player.Parent then
                AssignBase:FireClient(player, baseIndex)
            end
        end)

        RebirthSystem.OnLevelUp = function(p, niveau, cfg)
            local d = GetData(p)
            if not d then return end
            -- Ajouter le nouveau slot de tour à la progression
            local slotInfo = REBIRTH_SLOT_ORDER[niveau]
            if slotInfo then
                d.progression[slotInfo.floor .. "_" .. slotInfo.spot] = true
            end
            -- Réinitialiser les systèmes pour que le nouveau slot soit actif
            local bIndex = AssignationSystem.GetBaseIndex(p)
            if bIndex then
                DropSystem.Stop(p)
                IncomeSystem.Stop(p)
                DropSystem.Init(p, bIndex, d)
                IncomeSystem.Init(p, function() return GetData(p) end)
                local spotsApres = BaseProgressionSystem.GetSpotsActifs(p)
                CarrySystem.InitDepotSpotsBase(p, spotsApres)
            end
            -- Débloquer un floor visuellement au premier slot de chaque étage
            -- Amélioration 1 → Floor 2 · Amélioration 11 → Floor 3 · Amélioration 21 → Floor 4
            local SPOTS_PAR_ETAGE = 10
            for etageIdx = 2, 4 do
                if niveau == (etageIdx - 2) * SPOTS_PAR_ETAGE + 1 then
                    pcall(BaseProgressionSystem.DebloquerFloorApresRebirth, p, etageIdx - 1)
                    break
                end
            end
            -- Mettre à jour le board
            local nextCfg = RebirthSystem.Config[niveau + 1]
            pcall(BoardSystem.MettreAJourBoard, p, {
                rebirthLevel = niveau,
                coinsActuels = d.coins or 0,
                coinsRequis  = nextCfg and nextCfg.coinsRequis or 0,
            })
        end
        RebirthSystem.Init(player, data, baseIndex)

        -- RebirthCosmeticsSystem désactivé pour LavaTower (pas d'auras/trails voulus)
    end

    DataStoreManager.StartAutoSave(player, function()
        return GetData(player)
    end)

    Logger.info("Main", "%s connecté", player.Name)
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
        Logger.info("Main", "%s sauvegardé", player.Name)
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
-- RebirthCosmeticsSystem.Init() désactivé pour LavaTower

-- ═══════════════════════════════════════════════
-- 9. FUSE MACHINE
-- ═══════════════════════════════════════════════

-- GetCoins inclut les coins en attente dans les slots (comme EnvoyerHUD)
FuseMachineSystem.GetCoins = function(player)
    local data = GetData(player)
    if not data then return 0 end
    return (data.coins or 0) + (IncomeSystem.GetCoinsEnAttente(player) or 0)
end

-- Déduction uniquement sur data.coins (les coins en attente restent dans les slots)
FuseMachineSystem.DeductCoins = function(player, montant)
    local data = GetData(player)
    if not data then return end
    data.coins = math.max(0, (data.coins or 0) - montant)
    SetData(player, data)
end

FuseMachineSystem.UpdateHUD = function(player)
    local data = GetData(player)
    if data then EnvoyerHUD(player, data) end
end

if FuseMachineSystem then
    Logger.debug("Main", "[FuseMachine] Appel Init()...")
    local ok, err = pcall(FuseMachineSystem.Init)
    if not ok then
        Logger.error("Main", "[FuseMachine] ERREUR Init() : %s", tostring(err))
    end
else
    Logger.warn("Main", "[FuseMachine] Init() ignoré — module non chargé")
end

-- ═══════════════════════════════════════════════
-- 10. SHOP SYSTEM
-- ═══════════════════════════════════════════════

ShopSystem.GetData    = GetData
ShopSystem.SetData    = SetData
ShopSystem.NotifEvent = NotifEvent
ShopSystem.UpdateHUD  = function(player)
    local data = GetData(player)
    if data then EnvoyerHUD(player, data) end
end

local _shopOk, shopErr = pcall(ShopSystem.Init)
if not _shopOk then
    Logger.error("Main", "[ShopSystem] ERREUR Init() : %s", tostring(shopErr))
end

-- ═══════════════════════════════════════════════
-- 8. DÉMARRAGE
-- ═══════════════════════════════════════════════

Logger.info("Main", "🚀 Serveur démarré · %s", os.date("%d/%m/%Y %H:%M"))
