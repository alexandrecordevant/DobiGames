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
local AmelioConfig          = require(ReplicatedStorage.SharedLib.Shared.AmelioConfig)
local UpgradeSystem         = require(ReplicatedStorage.Modules.UpgradeSystem)
local DataStoreManager      = require(ServerScriptService.DataStoreManager)
local MonetizationHandler   = require(ServerScriptService.MonetizationHandler)
local AssignationSystem     = require(ServerScriptService.SharedLib.Server.AssignationSystem)
local BaseProgressionSystem = require(ServerScriptService.SharedLib.Server.BaseProgressionSystem)
local AmelioSystem          = require(ServerScriptService.SharedLib.Server.AmelioSystem)
local CarrySystem           = require(ServerScriptService.SharedLib.Server.CarrySystem)
local DropSystem                = require(ServerScriptService.SharedLib.Server.DropSystem)
local IncomeSystem              = require(ServerScriptService.SharedLib.Server.IncomeSystem)
IncomeSystem.AutoVerifierDeblocages = false   -- LavaTower : étages via Board uniquement
local BoardSystem               = require(ServerScriptService.SharedLib.Server.BoardSystem)
local AmelioCosmeticsSystem     = require(ServerScriptService.SharedLib.Server.AmelioCosmeticsSystem)
local ShopSystem = require(ServerScriptService.ShopSystem)
local _fuseOk, FuseSystem = pcall(require, ServerScriptService.SharedLib.Server.FuseSystem.FuseSystem)
if not _fuseOk then
    Logger.error("Main", "[FuseSystem] ERREUR require : %s", tostring(FuseSystem))
    FuseSystem = nil
else
    Logger.info("Main", "[FuseSystem] Module chargé ✓")
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
        -- objets boutique
        hasBat                  = false,
        batEquipped             = false,
        hasGoldSlap             = false,
        goldSlapEquipped        = false,
        hasSpeedCoil            = false,
        speedCoilEquipped       = false,
        hasGravityCoil          = false,
        gravityCoilEquipped     = false,
        -- BRs portés non déposés (sauvegardés à la déconnexion, restaurés au login)
        carryPortes             = {},
    }
end)

-- ═══════════════════════════════════════════════
-- 1b. LOGIQUE REBIRTH → SLOTS  (délégué à shared-lib)
-- Ordre de déblocage : Floor 2 Spot 1-10, Floor 3 Spot 1-10, Floor 4 Spot 1-10
-- ═══════════════════════════════════════════════

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

-- AmelioSystem — config amélioration de base (pas de condition de progression requise)
AmelioSystem.Config = AmelioConfig

-- CarrySystem — source de vérité pour la base du joueur
CarrySystem.GetBaseJoueur = function(player)
    return AssignationSystem.GetBaseIndex(player)
end

-- Sérialiser le carry avant que CarrySystem détruise les Tools (PlayerRemoving)
CarrySystem.OnBeforeClean = function(player, portes)
    local data = GetData(player)
    if not data then return end
    local carrySerial = {}
    for _, entree in ipairs(portes) do
        if entree.rarete and entree.toolRef and entree.toolRef.Parent then
            local brNom = nil
            for _, child in ipairs(entree.toolRef:GetChildren()) do
                if child.Name ~= "Handle" and (child:IsA("Model") or child:IsA("BasePart")) then
                    brNom = child:GetAttribute("OriginalName") or child.Name
                    break
                end
            end
            table.insert(carrySerial, {
                nom         = entree.rarete.nom,
                dossier     = entree.rarete.dossier or entree.rarete.nom,
                isMutant    = entree.rarete.isMutant or false,
                valeur      = entree.rarete.valeur,
                elementType = entree.rarete.elementType,
                brNom       = brNom,
            })
        end
    end
    data.carryPortes = carrySerial
    Logger.info("Main", "%s carry sauvegardé : %d BR(s)", player.Name, #carrySerial)
end

-- DropSystem — mise à jour du bouton après dépôt/retrait/vente
DropSystem.OnSpotChange = function(player)
    AmelioSystem.MettreAJourBouton(player)
end
AmelioSystem.OnButtonUpdate = function(player, etat)
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

-- AmelioCosmeticsSystem — source de données
AmelioCosmeticsSystem.GetData = GetData

-- ═══════════════════════════════════════════════
-- 5. CONNEXION JOUEUR
-- ═══════════════════════════════════════════════

local function OnPlayerAdded(player)
    local data = DataStoreManager.Load(player)
    SetData(player, data)

    MonetizationHandler.CheckGamePasses(player, data)

    task.wait(0.3)
    EnvoyerHUD(player, data)

    local baseIndex = AssignationSystem.AssignerJoueur(player)
    if baseIndex then
        -- Reconstruire la progression à partir du niveau rebirth AVANT Init.
        -- Garantit que les slots débloqués par rebirth sont corrects même après
        -- un changement de système ou une reconnexion.
        data.progression = BaseProgressionSystem.BuildProgressionFromRebirth(data.rebirthLevel or 0)

        BaseProgressionSystem.Init(player, baseIndex, data)
        -- LavaTower : pas de VerifierDeblocages au join — les étages se débloquent
        -- uniquement via le Board (AmelioSystem), jamais par seuil de coins.

        local spotsActifs = BaseProgressionSystem.GetSpotsActifs(player)
        CarrySystem.InitDepotSpotsBase(player, spotsActifs)

        DropSystem.Init(player, baseIndex, data)
        IncomeSystem.Init(player, function() return GetData(player) end)

        -- Restaurer le carry sauvegardé (BRs portés à la déconnexion)
        if data.carryPortes and #data.carryPortes > 0 then
            -- Appliquer la capacité depuis les upgrades sauvés avant de restaurer
            local carryLevel = data.shopUpgrades and data.shopUpgrades.carry or 0
            if carryLevel > 0 then
                CarrySystem.SetCapacite(player, carryLevel)
            end
            local BrainrotsFolder = ReplicatedStorage:FindFirstChild("Brainrots")
            for _, porteeData in ipairs(data.carryPortes) do
                local rareteObj = {
                    nom         = porteeData.nom,
                    dossier     = porteeData.dossier or porteeData.nom,
                    isMutant    = porteeData.isMutant,
                    valeur      = porteeData.valeur,
                    elementType = porteeData.elementType,
                }
                local clone = nil
                if porteeData.brNom and BrainrotsFolder then
                    local dossier = BrainrotsFolder:FindFirstChild(porteeData.dossier or porteeData.nom)
                    local modele = dossier and dossier:FindFirstChild(porteeData.brNom)
                    if modele then
                        clone = modele:Clone()
                        clone.Parent = ReplicatedStorage
                    end
                end
                pcall(CarrySystem.AjouterAuCarry, player, clone, rareteObj)
            end
        end

        AmelioSystem.OnLevelUp = function(p, niveau, cfg)
            local d = GetData(p)
            if not d then return end
            -- Appliquer le slot visuellement (floor + spot) via shared-lib
            local slotInfo = BaseProgressionSystem.GetSlotInfoForRebirth(niveau)
            if slotInfo then
                pcall(BaseProgressionSystem.AppliquerSlotRebirth, p, slotInfo.floor, slotInfo.spot)
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
            -- Mettre à jour le board
            local nextCfg = AmelioSystem.Config[niveau + 1]
            pcall(BoardSystem.MettreAJourBoard, p, {
                rebirthLevel = niveau,
                coinsActuels = d.coins or 0,
                coinsRequis  = nextCfg and nextCfg.coinsRequis or 0,
            })
        end
        AmelioSystem.Init(player, data, baseIndex)

        -- Notifier le client de son baseIndex (après AmelioSystem.Init pour que le BoardGui soit prêt)
        if player.Parent then
            AssignBase:FireClient(player, baseIndex)
        end

        -- AmelioCosmeticsSystem désactivé pour LavaTower (pas d'auras/trails voulus)
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
        -- Sérialiser le carry maintenant (avant que nettoyerJoueur détruise les Tools)
        if CarrySystem.OnBeforeClean then
            pcall(CarrySystem.OnBeforeClean, player, CarrySystem.GetPortes(player))
        end

        -- Synchroniser spotsOccupes avant sauvegarde
        data.spotsOccupes = DropSystem.GetSpotsOccupesSerialisables(player)

        DataStoreManager.Save(player, data)
        playerDataCache[player.UserId] = nil
        BaseProgressionSystem.Reset(player)
        AmelioSystem.Reset(player)
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
-- AmelioCosmeticsSystem.Init() désactivé pour LavaTower

-- ═══════════════════════════════════════════════
-- 9. FUSE SYSTEM
-- ═══════════════════════════════════════════════

if FuseSystem then
    FuseSystem.OnResultatPret = function(player, brainrotClone)
        local rarete    = brainrotClone:GetAttribute("Rarete") or "Common"
        local rareteObj = {
            nom         = rarete,
            dossier     = rarete,
            isMutant    = brainrotClone:GetAttribute("IsMutant") == true,
            valeur      = brainrotClone:GetAttribute("Valeur")
                          or (Config.ValeurParRarete and Config.ValeurParRarete[rarete])
                          or 1,
            elementType = brainrotClone:GetAttribute("ElementType"),
        }
        brainrotClone.Parent = game:GetService("ServerStorage")
        local ok, err = pcall(CarrySystem.AjouterAuCarry, player, brainrotClone, rareteObj)
        if not ok then
            Logger.warn("Main", "[FuseSystem] AjouterAuCarry echec : %s", tostring(err))
            pcall(function()
                brainrotClone.Parent = player:FindFirstChildOfClass("Backpack") or player.Character
            end)
        end
    end
    local ok, err = pcall(FuseSystem.Init, Config)
    if not ok then
        Logger.error("Main", "[FuseSystem] ERREUR Init() : %s", tostring(err))
    end
else
    Logger.warn("Main", "[FuseSystem] Init() ignore — module non charge")
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
