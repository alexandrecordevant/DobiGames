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

local Config             = require(ReplicatedStorage.Specialized.GameConfig)
local CollectSystem      = require(ReplicatedStorage.Common.CollectSystem)
local UpgradeSystem      = require(ReplicatedStorage.Common.UpgradeSystem)

local DataStoreManager      = require(ServerScriptService.Common.DataStoreManager)
local EventManager          = require(ServerScriptService.Common.EventManager)
local MonetizationHandler   = require(ServerScriptService.Common.MonetizationHandler)
local BrainRotSpawner       = require(ServerScriptService.Specialized.BrainRotSpawner)
local BaseProgressionSystem = require(ServerScriptService.Common.BaseProgressionSystem)
local CarrySystem           = require(ServerScriptService.Common.CarrySystem)
local RebirthSystem         = require(ServerScriptService.Common.RebirthSystem)
local AssignationSystem     = require(ServerScriptService.Common.AssignationSystem)
local DropSystem            = require(ServerScriptService.Common.DropSystem)
local IncomeSystem          = require(ServerScriptService.Common.IncomeSystem)
local LeaderboardSystem     = require(ServerScriptService.Common.LeaderboardSystem)
local ShopSystem            = require(ServerScriptService.Common.ShopSystem)

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

local function TrouverSpawnBase(baseIndex)
    local bases = workspace:FindFirstChild("Bases")
    if not bases then return nil end
    local baseModel = bases:FindFirstChild("Base_" .. tostring(baseIndex))
    if not baseModel then return nil end

    local function estNomSpawn(nom)
        local n = string.lower(nom or "")
        return n == "spawnpoint" or n == "spawnlocation" or n == "playerspawn" or n == "spawn"
    end

    for _, d in ipairs(baseModel:GetDescendants()) do
        if d:IsA("BasePart") and estNomSpawn(d.Name) then
            return d.CFrame + Vector3.new(0, 4, 0)
        end
    end

    local spawnZone = baseModel:FindFirstChild("SpawnZone")
    if spawnZone and spawnZone:IsA("BasePart") then
        return spawnZone.CFrame + Vector3.new(0, 4, 0)
    end

    if spawnZone then
        local wallTop    = spawnZone:FindFirstChild("Wall_Top")
        local wallBottom = spawnZone:FindFirstChild("Wall_Bottom")
        local wallLeft   = spawnZone:FindFirstChild("Wall_Left")
        local wallRight  = spawnZone:FindFirstChild("Wall_Right")
        if wallTop and wallBottom and wallLeft and wallRight then
            local x = (wallLeft.Position.X + wallRight.Position.X) / 2
            local z = (wallTop.Position.Z + wallBottom.Position.Z) / 2
            local y = math.max(wallTop.Position.Y, wallBottom.Position.Y, wallLeft.Position.Y, wallRight.Position.Y) + 4
            return CFrame.new(x, y, z)
        end
    end

    return baseModel:GetPivot() + Vector3.new(0, 5, 0)
end

local function TeleporterVersBaseAssignee(player, baseIndex, character)
    if not player or not character or not baseIndex then return end
    task.spawn(function()
        local hrp = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 5)
        if not hrp then return end
        local cframeSpawn = TrouverSpawnBase(baseIndex)
        if not cframeSpawn then return end
        pcall(function()
            character:PivotTo(cframeSpawn)
        end)
    end)
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

    -- Assigner une base (AssignationSystem remplace BrainRotSpawner.AssignerBase)
    local baseIndex = AssignationSystem.AssignerJoueur(player)
    if baseIndex then
        -- Informer BrainRotSpawner de la base assignée (pour le spawn des BRs dans le bon champ)
        if BrainRotSpawner.SetBase then
            BrainRotSpawner.SetBase(player, baseIndex)
        elseif BrainRotSpawner.AssignerBase then
            -- Compatibilité ascendante : BrainRotSpawner.AssignerBase peut toujours être appelé
            -- avec baseIndex si la signature l'accepte, sinon on ignore
            pcall(BrainRotSpawner.AssignerBase, player, baseIndex)
        end

        -- Initialiser la progression visuelle de la base
        BaseProgressionSystem.Init(player, baseIndex, data)
        BaseProgressionSystem.VerifierDeblocages(player, data)

        -- Créer les ProximityPrompts de dépôt sur les spots actifs
        local spotsActifs = BaseProgressionSystem.GetSpotsActifs(player)
        CarrySystem.InitDepotSpotsBase(player, spotsActifs)

        -- Restaurer les BR déposés et initialiser le système de dépôt
        DropSystem.Init(player, baseIndex, data)

        -- Lancer la boucle de revenus passifs
        IncomeSystem.Init(player, function() return GetData(player) end)

        -- Réappliquer tous les upgrades shop achetés (WalkSpeed, Carry, etc.)
        ShopSystem.AppliquerTousUpgrades(player, data)

        -- Mettre à jour le leaderboard pour ce joueur
        LeaderboardSystem.MettreAJour(player, data)

        -- Initialiser le système de Rebirth
        RebirthSystem.Init(player, data, baseIndex)

        -- Toujours respawn devant la base assignée (spawn initial + respawns)
        if player.Character then
            TeleporterVersBaseAssignee(player, baseIndex, player.Character)
        end
        player.CharacterAdded:Connect(function(character)
            TeleporterVersBaseAssignee(player, baseIndex, character)
        end)
    end

    -- Lancer auto-save (inclut spotsOccupes synchronisé par IncomeSystem)
    DataStoreManager.StartAutoSave(player, function()
        return GetData(player)
    end)

    print("[" .. Config.NomDuJeu .. "] " .. player.Name .. " connecté (Tier " .. data.tier .. ", Prestige " .. data.prestige .. ")")
end

local function OnPlayerRemoving(player)
    -- Arrêter la boucle income avant la sauvegarde (évite les doublons de +coins)
    IncomeSystem.Stop(player)

    local data = GetData(player)
    if data then
        -- Synchroniser spotsOccupes une dernière fois avant sauvegarde
        local spotsSerial = DropSystem.GetSpotsOccupesSerialisables(player)
        data.spotsOccupes = spotsSerial

        DataStoreManager.Save(player, data)
        playerDataCache[player.UserId] = nil
        BaseProgressionSystem.Reset(player)
        RebirthSystem.Reset(player)
        DropSystem.Stop(player)
        AssignationSystem.LibererBase(player)
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
    local coinsGagnes = math.floor(valeur * multiplier * RebirthSystem.GetMultiplicateur(player))

    data.coins = data.coins + coinsGagnes
    data.totalCoinsGagnes = (data.totalCoinsGagnes or 0) + coinsGagnes
    data.totalCollecte = (data.totalCollecte or 0) + 1

    -- Mettre à jour coinsParMinute (moyenne mobile)
    data.coinsParMinute = math.max(data.coinsParMinute or 1, coinsGagnes)

    -- Supprimer le collectible du serveur
    collectible:Destroy()

    -- Notifier le client (VFX + HUD)
    CollectVFX:FireClient(player, coinsGagnes, rarete)
    UpdateHUD:FireClient(player, data)
    BaseProgressionSystem.VerifierDeblocages(player, data)
    RebirthSystem.MettreAJourBouton(player)
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
BrainRotSpawner.Init()

-- Hook CarrySystem → ProximityPrompt pour les BRs EPIC+
BrainRotSpawner.OnBRSpawned = function(brModel, baseIndex, rarete)
    CarrySystem.OnBRSpawned(brModel, baseIndex, rarete)
end

-- Collecte Touched (COMMON/OG/RARE) → ramassage carry avec le modèle monde
BrainRotSpawner.OnCollecte = function(player, baseIndex, rarete, brModel)
    return CarrySystem.RamasserBR(player, rarete, brModel)
end

-- CarrySystem utilise AssignationSystem comme source de vérité pour la base du joueur
CarrySystem.GetBaseJoueur = function(player) return AssignationSystem.GetBaseIndex(player) end
CarrySystem.Init()

-- ChampCommun (MYTHIC + SECRET)
local ChampCommunSpawner = require(ServerScriptService.Specialized.ChampCommunSpawner)
ChampCommunSpawner.OnCollecte = function(player, typeNom)
    local data = GetData(player)
    if not data then return end
    local cfg = { MYTHIC = { valeur = 300 }, SECRET = { valeur = 1000 } }
    local valeur = cfg[typeNom] and cfg[typeNom].valeur or 100
    local multiplier  = CollectSystem.GetMultiplier(data)
    local coinsGagnes = math.floor(valeur * multiplier * RebirthSystem.GetMultiplicateur(player))
    data.coins              = data.coins + coinsGagnes
    data.totalCoinsGagnes   = (data.totalCoinsGagnes or 0) + coinsGagnes
    data.totalCollecte      = (data.totalCollecte or 0) + 1
    UpdateHUD:FireClient(player, data)
    CollectVFX:FireClient(player, coinsGagnes, { nom = typeNom, valeur = valeur })
    BaseProgressionSystem.VerifierDeblocages(player, data)
    RebirthSystem.MettreAJourBouton(player)
end
-- Bug 3 : MYTHIC/SECRET utilisent ProximityPrompt sans restriction de base (nil = ChampCommun)
ChampCommunSpawner.OnBRSpawned = function(clone, typeNom, onCapture)
    local rarete = { nom = typeNom, dossier = typeNom }
    CarrySystem.OnBRSpawned(clone, nil, rarete, onCapture)
end
ChampCommunSpawner.Init()

-- Connexion récompenses Brainrot (champs individuel + commun)
local BrainrotReward = ServerScriptService:WaitForChild("_BrainrotReward")
BrainrotReward.Event:Connect(function(player, montant, rarete)
    local data = GetData(player)
    if not data then return end
    local multiplier   = CollectSystem.GetMultiplier(data)
    local coinsGagnes       = math.floor(montant * multiplier * RebirthSystem.GetMultiplicateur(player))
    data.coins              = data.coins + coinsGagnes
    data.totalCoinsGagnes   = (data.totalCoinsGagnes or 0) + coinsGagnes
    data.totalCollecte      = (data.totalCollecte or 0) + 1
    UpdateHUD:FireClient(player, data)
    CollectVFX:FireClient(player, coinsGagnes, rarete)
    BaseProgressionSystem.VerifierDeblocages(player, data)
    RebirthSystem.MettreAJourBouton(player)
end)

-- Démarrer les events automatiques (Admin Abuse, Lucky Hour...)
-- Hook EventManager → IncomeSystem pour appliquer le multiplicateur event
if EventManager.OnEventStart then
    EventManager.OnEventStart = function(multiplier)
        IncomeSystem.SetEventMultiplier(multiplier or Config.EventSpawnMultiplier)
    end
end
if EventManager.OnEventEnd then
    EventManager.OnEventEnd = function()
        IncomeSystem.SetEventMultiplier(1)
    end
end
EventManager.Init()

-- Initialiser AssignationSystem (connecte PlayerRemoving, assigne joueurs déjà présents)
AssignationSystem.Init()

-- LeaderboardSystem : connecter la source de données et démarrer la boucle
LeaderboardSystem.GetPlayerData = GetData
LeaderboardSystem.Init()

-- ShopSystem : connecter la source de données et démarrer les ProximityPrompts
ShopSystem.GetPlayerData = GetData
ShopSystem.Init()

-- Démarrer TestRunner + ResetSystem si TEST_MODE actif (aucun overhead si false)
if Config.TEST_MODE then
    local ok, TestRunner = pcall(require, ReplicatedStorage.Test.TestRunner)
    if ok and TestRunner then
        task.spawn(TestRunner.Init)
    end
    local okRS, ResetSystem = pcall(require, ReplicatedStorage.Test.ResetSystem)
    if okRS and ResetSystem then
        pcall(ResetSystem.Init)
    end
    warn("⚠️  TEST_MODE ACTIVÉ — Désactiver GameConfig.TEST_MODE avant publish !")
end

print("[" .. Config.NomDuJeu .. "] 🚀 Serveur démarré · " .. os.date("%d/%m/%Y %H:%M"))
