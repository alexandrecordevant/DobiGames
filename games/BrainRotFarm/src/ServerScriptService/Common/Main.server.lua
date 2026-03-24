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
local CollectSystem      = require(ReplicatedStorage.SharedLib.Shared.CollectSystem)
local UpgradeSystem      = require(ReplicatedStorage.SharedLib.Shared.UpgradeSystem)

local DataStoreManager      = require(ServerScriptService.Common.DataStoreManager)
local EventManager          = require(ReplicatedStorage.SharedLib.Server.EventManager)
local MonetizationHandler   = require(ReplicatedStorage.SharedLib.Server.MonetizationHandler)
local SpawnManager          = require(ServerScriptService.Common.SpawnManager)
local BaseProgressionSystem = require(ReplicatedStorage.SharedLib.Server.BaseProgressionSystem)
local CarrySystem           = require(ReplicatedStorage.SharedLib.Server.CarrySystem)
local RebirthSystem         = require(ReplicatedStorage.SharedLib.Server.RebirthSystem)
local AssignationSystem     = require(ReplicatedStorage.SharedLib.Server.AssignationSystem)
local DropSystem            = require(ReplicatedStorage.SharedLib.Server.DropSystem)
local IncomeSystem          = require(ReplicatedStorage.SharedLib.Server.IncomeSystem)
local LeaderboardSystem     = require(ServerScriptService.Common.LeaderboardSystem)
local ShopSystem            = require(ServerScriptService.Common.ShopSystem)
local SprinklerSystem       = require(ServerScriptService.Specialized.SprinklerSystem)
local TracteurSystem        = require(ServerScriptService.Specialized.TracteurSystem)
local FlowerPotSystem       = require(ServerScriptService.Specialized.FlowerPotSystem)
local DiscordWebhook        = require(ServerScriptService.Common.DiscordWebhook)
local BoardSystem           = require(ServerScriptService.Common.BoardSystem)
local ArbreSystem           = require(ServerScriptService.Common.ArbreSystem)

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
local OuvrirRebirth      = CreerRemoteEvent("OuvrirRebirth")
local UpdateGraines      = CreerRemoteEvent("UpdateGraines")
local OuvrirMenuSlot     = CreerRemoteEvent("OuvrirMenuSlot")  -- serveur → client : ouvre menu slot
local ActionSlot         = CreerRemoteEvent("ActionSlot")      -- client → serveur : Retrieve / Sell

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
local sessionStart    = {}  -- { [userId] = os.time() au moment du join } (Top Farmer hebdo)

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
    local data = DataStoreManager.Load(player)
    SetData(player, data)

    -- Vérifier Game Passes
    MonetizationHandler.CheckGamePasses(player, data)

    -- Envoyer HUD initial
    task.wait(1)  -- laisser le client charger
    UpdateHUD:FireClient(player, data)

    -- Assigner une base (AssignationSystem remplace SpawnManager.AssignerBase)
    local baseIndex = AssignationSystem.AssignerJoueur(player)
    if baseIndex then
        -- Informer SpawnManager de la base assignée (pour le spawn des BRs dans le bon champ)
        if SpawnManager.SetBase then
            SpawnManager.SetBase(player, baseIndex)
        elseif SpawnManager.AssignerBase then
            -- Compatibilité ascendante
            pcall(SpawnManager.AssignerBase, player, baseIndex)
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

        -- Réactiver le sprinkler si upgrade Arroseur acheté
        local niveauArroseur = data.upgrades and data.upgrades.upgradeArroseur or 0
        if niveauArroseur > 0 then
            pcall(SprinklerSystem.ActiverBase, baseIndex, niveauArroseur)
        end

        -- Réactiver l'animation tracteur si upgrade Tracteur acheté
        if data.hasTracteur then
            pcall(TracteurSystem.Activer, player, baseIndex)
        end

        -- Initialiser les pots de fleurs
        FlowerPotSystem.Init(player, baseIndex, data)

        -- Initialiser le système de Rebirth (callbacks Farm injectés ici)
        RebirthSystem.Config = Config.RebirthConfig
        RebirthSystem.IsProgressionComplete = function(playerData)
            return playerData.progression and playerData.progression["4_10"] == true
        end
        RebirthSystem.OnRebirthComplete = function(player, niveau, cfg)
            -- Débloquer le floor suivant visuellement
            pcall(BaseProgressionSystem.DebloquerFloorApresRebirth, player, niveau)
            -- Mettre à jour le board (etat minimal pour afficher le nouveau niveau)
            pcall(BoardSystem.MettreAJourBoard, player, {
                rebirthLevel   = niveau,
                coinsActuels   = 0,
                coinsRequis    = cfg and cfg.coinsRequis or 0,
                brainRotRequis = cfg and cfg.brainRotRequis and cfg.brainRotRequis.rarete or "?",
                manqueBR       = "pending",  -- vient d'être reset, BR consommé
                label          = cfg and cfg.label or nil,
            })
            -- Notification Discord
            pcall(function()
                DiscordWebhook.Envoyer(
                    "🔥 " .. player.Name .. " — " .. cfg.label,
                    string.format(
                        "**%s** vient d'effectuer son **%s** sur BrainRotFarm !\n" ..
                        "Multiplicateur : **×%.1f** | Slots bonus : **+%d**",
                        player.Name, cfg.label, cfg.multiplicateur, cfg.slotsBonus
                    ),
                    cfg.couleurHex
                )
            end)
        end
        RebirthSystem.Init(player, data, baseIndex)

        -- Afficher les données Rebirth actuelles sur le board de la base
        task.delay(2, function()
            if not GetData(player) then return end
            local ok2, manques = RebirthSystem.VerifierConditions(player)
            pcall(BoardSystem.MettreAJourBoard, player, {
                rebirthLevel   = data.rebirthLevel or 0,
                coinsActuels   = data.coins or 0,
                coinsRequis    = manques and manques.manqueCoins
                    and (data.coins or 0) + manques.manqueCoins or 0,
                brainRotRequis = manques and manques.manqueBR or nil,
                manqueBR       = manques and manques.manqueBR or nil,
            })
        end)

        -- Toujours respawn devant la base assignée (spawn initial + respawns)
        if player.Character then
            TeleporterVersBaseAssignee(player, baseIndex, player.Character)
        end
        player.CharacterAdded:Connect(function(character)
            TeleporterVersBaseAssignee(player, baseIndex, character)
        end)
    end

    -- Mettre à jour le leaderboard (même en mode spectateur, leaderstats créés)
    LeaderboardSystem.MettreAJour(player, data)

    -- Lancer auto-save (inclut spotsOccupes synchronisé par IncomeSystem)
    DataStoreManager.StartAutoSave(player, function()
        return GetData(player)
    end)

    -- Début de session (pour tracking temps de jeu hebdo Top Farmer)
    sessionStart[player.UserId] = os.time()

    print("[" .. Config.NomDuJeu .. "] " .. player.Name .. " connecté (Tier " .. data.tier .. ", Prestige " .. data.prestige .. ")")
end

local function OnPlayerRemoving(player)
    -- Arrêter la boucle income avant la sauvegarde (évite les doublons de +coins)
    IncomeSystem.Stop(player)

    local data = GetData(player)
    if data then
        -- Accumuler le temps de jeu hebdo (Top Farmer Discord)
        local dureeSession = os.time() - (sessionStart[player.UserId] or os.time())
        data.tempsJeuSemaine = (data.tempsJeuSemaine or 0) + dureeSession
        data.tempsJeuTotal   = (data.tempsJeuTotal   or 0) + dureeSession
        sessionStart[player.UserId] = nil

        -- Synchroniser spotsOccupes une dernière fois avant sauvegarde
        local spotsSerial = DropSystem.GetSpotsOccupesSerialisables(player)
        data.spotsOccupes = spotsSerial

        DataStoreManager.Save(player, data)
        playerDataCache[player.UserId] = nil
        BaseProgressionSystem.Reset(player)
        RebirthSystem.Reset(player)
        DropSystem.Stop(player)
        -- Arrêter l'animation tracteur (évite une boucle orpheline)
        local baseIndexSortie = AssignationSystem.GetBaseIndex(player)
        if baseIndexSortie then
            pcall(TracteurSystem.Desactiver, baseIndexSortie)
        end
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
        NotifEvent:FireClient(player, "PRESTIGE", "Prestige " .. result.prestige .. " reached! Multiplier x" .. (result.prestige * (Config.PrestigeMultiplier - 1) + 1))
    else
        NotifEvent:FireClient(player, "ERREUR", result)
    end
end)

-- Gestion slot occupé : Retrieve ou Sell via menu client
ActionSlot.OnServerEvent:Connect(function(player, action, spotKey)
    -- Validation anti-exploit
    if action ~= "retrieve" and action ~= "sell" then return end
    if type(spotKey) ~= "string" then return end

    -- Retrouver la touchPart depuis la clé de slot
    local touchPart = DropSystem.GetTouchPart(player, spotKey)
    if not touchPart then
        warn("[ActionSlot] touchPart introuvable pour " .. player.Name .. " slot=" .. spotKey)
        return
    end

    if action == "retrieve" then
        DropSystem.RecupererBrainRot(player, touchPart)
    elseif action == "sell" then
        DropSystem.VendreBR(player, touchPart)
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

-- Hook CarrySystem → ProximityPrompt pour tous les BRs (onCapture forwarded pour RARE+)
SpawnManager.OnBRSpawned = function(brModel, baseIndex, rarete, onCapture)
    CarrySystem.OnBRSpawned(brModel, baseIndex, rarete, onCapture)
end

-- Hook LeaderboardSystem → notifié quand un joueur capture un RARE+ via ProximityPrompt
SpawnManager.OnRareCollecte = function(player, rareteNom)
    LeaderboardSystem.EnregistrerRare(player, rareteNom)
    -- Discord : BRAINROT_GOD uniquement (très rare → toujours envoyer)
    if rareteNom == "BRAINROT_GOD" then
        pcall(DiscordWebhook.BrainrotGodCapture, player.Name)
    end
end

-- Collecte Touched (COMMON/OG/RARE) → ramassage carry avec le modèle monde
SpawnManager.OnCollecte = function(player, baseIndex, rarete, brModel)
    return CarrySystem.AjouterAuCarry(player, brModel, rarete)
end

-- CarrySystem utilise AssignationSystem comme source de vérité pour la base du joueur
CarrySystem.GetBaseJoueur = function(player) return AssignationSystem.GetBaseIndex(player) end
CarrySystem.OnCarryChange = function(player, portes)
    FlowerPotSystem.OnCarryChange(player, portes)
end
CarrySystem.Init()

-- ZoneCommune (MYTHIC + SECRET)
local CommunSpawner = require(ServerScriptService.Common.CommunSpawner)
CommunSpawner.OnCollecte = function(player, typeNom)
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
-- MYTHIC/SECRET utilisent ProximityPrompt sans restriction de base (nil = ZoneCommune)
CommunSpawner.OnBRSpawned = function(clone, typeNom, onCapture)
    local rarete = { nom = typeNom, dossier = typeNom }
    CarrySystem.OnBRSpawned(clone, nil, rarete, onCapture)
end
CommunSpawner.Init()

-- Connexion récompenses Brainrot (champs individuel + commun)
-- FindFirstChild + création manuelle : WaitForChild bloquerait tout si l'objet n'existe pas encore
local BrainrotReward = ServerScriptService:FindFirstChild("_BrainrotReward")
if not BrainrotReward then
    BrainrotReward        = Instance.new("BindableEvent")
    BrainrotReward.Name   = "_BrainrotReward"
    BrainrotReward.Parent = ServerScriptService
    print("[Main] _BrainrotReward BindableEvent créé ✓")
end

BrainrotReward.Event:Connect(function(player, montant, rarete)
    local data = GetData(player)
    if not data then return end
    local multiplier      = CollectSystem.GetMultiplier(data)
    local coinsGagnes     = math.floor(
        montant * multiplier * RebirthSystem.GetMultiplicateur(player)
    )
    data.coins            = data.coins + coinsGagnes
    data.totalCoinsGagnes = (data.totalCoinsGagnes or 0) + coinsGagnes
    data.totalCollecte    = (data.totalCollecte or 0) + 1
    UpdateHUD:FireClient(player, data)
    CollectVFX:FireClient(player, coinsGagnes, rarete)
    BaseProgressionSystem.VerifierDeblocages(player, data)
    RebirthSystem.MettreAJourBouton(player)
    LeaderboardSystem.MettreAJour(player, data)
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

-- Masquer floors > 1 sur toutes les bases avant que les joueurs rejoignent
BaseProgressionSystem.InitBasesInactives()

-- Initialiser les boards cliquables devant chaque base
BoardSystem.Init()

-- Initialiser AssignationSystem (connecte PlayerRemoving, assigne joueurs déjà présents)
AssignationSystem.GetSpawnCFrame = function(baseIndex)
    local bases = workspace:FindFirstChild("Bases")
    if not bases then return nil end
    local baseRoot = bases:FindFirstChild("Base_" .. tostring(baseIndex))
    if not baseRoot then return nil end

    local sl = baseRoot:FindFirstChildWhichIsA("SpawnLocation")
        or (function()
            for _, d in ipairs(baseRoot:GetDescendants()) do
                if d:IsA("SpawnLocation") then return d end
            end
        end)()
    if sl then return sl.CFrame + Vector3.new(0, 4, 0) end

    for _, d in ipairs(baseRoot:GetDescendants()) do
        if d:IsA("BasePart") then
            local n = string.lower(d.Name or "")
            if n == "spawnlocation" or n == "spawnpoint" or n == "spawn" then
                return d.CFrame + Vector3.new(0, 4, 0)
            end
        end
    end

    local spawnZone = baseRoot:FindFirstChild("SpawnZone")
    if spawnZone then
        if spawnZone:IsA("BasePart") then return spawnZone.CFrame + Vector3.new(0, 4, 0) end
        local wT = spawnZone:FindFirstChild("Wall_Top")
        local wB = spawnZone:FindFirstChild("Wall_Bottom")
        local wL = spawnZone:FindFirstChild("Wall_Left")
        local wR = spawnZone:FindFirstChild("Wall_Right")
        if wT and wB and wL and wR then
            return CFrame.new(
                (wL.Position.X + wR.Position.X) / 2,
                math.max(wT.Position.Y, wB.Position.Y, wL.Position.Y, wR.Position.Y) + 4,
                (wT.Position.Z + wB.Position.Z) / 2
            )
        end
    end

    local ok, cf = pcall(function() return baseRoot:GetPivot() end)
    return ok and cf and (cf + Vector3.new(0, 5, 0)) or nil
end
AssignationSystem.Init()

-- LeaderboardSystem : connecter la source de données et démarrer la boucle
LeaderboardSystem.GetPlayerData = GetData
LeaderboardSystem.Init()

-- ShopSystem : connecter la source de données et démarrer les ProximityPrompts
ShopSystem.GetPlayerData = GetData
ShopSystem.Init()

-- SprinklerSystem : désactiver tous les sprinklers par défaut
SprinklerSystem.Init()

-- TracteurSystem : prêt (aucun tracteur actif au démarrage)
TracteurSystem.Init()

-- MonetizationHandler : injecter l'accesseur de données (pour ProcessReceipt)
MonetizationHandler.SetGetData(GetData)

-- FlowerPotSystem : connecter la source de données et initialiser
FlowerPotSystem.SetGetData(GetData)
FlowerPotSystem.InitServeur()

-- ArbreSystem : graines sur les arbres du ChampCommun
ArbreSystem.GetData = GetData
ArbreSystem.Init()

-- ═══════════════════════════════════════════════
-- 7. TOP FARMER HEBDOMADAIRE (chaque lundi minuit UTC)
-- ═══════════════════════════════════════════════
task.spawn(function()
    while true do
        task.wait(60)
        local date = os.date("!*t", os.time())
        -- Lundi = 2, minuit UTC (wday 1=dim, 2=lun, ...)
        if date.wday == 2 and date.hour == 0 and date.min == 0 then
            local topPlayer = nil
            local topTemps  = 0
            for _, p in ipairs(Players:GetPlayers()) do
                local d = GetData(p)
                if d and (d.tempsJeuSemaine or 0) > topTemps then
                    topTemps  = d.tempsJeuSemaine
                    topPlayer = p
                end
            end
            if topPlayer then
                local heures = math.floor(topTemps / 3600)
                pcall(DiscordWebhook.TopFarmerHebdo, topPlayer.Name, heures, os.date("!%V"))
                -- Reset des compteurs hebdomadaires pour tous les joueurs en ligne
                for _, p in ipairs(Players:GetPlayers()) do
                    local d = GetData(p)
                    if d then d.tempsJeuSemaine = 0 end
                end
            end
        end
    end
end)

print("[" .. Config.NomDuJeu .. "] 🚀 Serveur démarré · " .. os.date("%d/%m/%Y %H:%M"))
