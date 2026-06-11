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

local Config             = require(ReplicatedStorage.GameConfig)
local Logger             = require(ServerScriptService.SharedLib.Server.Logger)
Logger.init(Config.LOG_LEVEL)
local AmelioConfig       = require(ReplicatedStorage.SharedLib.Shared.AmelioConfig)
local CollectSystem      = require(ServerScriptService.SharedLib.Shared.CollectSystem)
local UpgradeSystem      = require(ServerScriptService.SharedLib.Shared.UpgradeSystem)

local DataStoreManager      = require(ServerScriptService.DataStoreManager)
local EventManager          = require(ServerScriptService.SharedLib.Server.EventManager)
local MonetizationHandler   = require(ServerScriptService.SharedLib.Server.MonetizationHandler)
local SpawnManager          = require(ServerScriptService.SpawnManager)
local BaseProgressionSystem = require(ServerScriptService.SharedLib.Server.BaseProgressionSystem)
local CarrySystem           = require(ServerScriptService.SharedLib.Server.CarrySystem)
local AmelioSystem          = require(ServerScriptService.SharedLib.Server.AmelioSystem)
local AssignationSystem     = require(ServerScriptService.SharedLib.Server.AssignationSystem)
local DropSystem            = require(ServerScriptService.SharedLib.Server.DropSystem)
local IncomeSystem          = require(ServerScriptService.SharedLib.Server.IncomeSystem)
local LeaderboardSystem     = require(ServerScriptService.LeaderboardSystem)
local ShopSystem            = require(ServerScriptService.ShopSystem)




local DiscordWebhook        = require(ServerScriptService.DiscordWebhook)
local BoardSystem               = require(ServerScriptService.SharedLib.Server.BoardSystem)


local AmelioCosmeticsSystem     = require(ServerScriptService.SharedLib.Server.AmelioCosmeticsSystem)
local _abOk, EventAdminAbuse = pcall(require, ServerScriptService.Events.EventAdminAbuse)
if not _abOk then EventAdminAbuse = nil end  -- DEBUG TEMP

local BRPreviewsBuilder  = require(ServerScriptService.BRPreviewsBuilder)
local IndexSystem        = require(ServerScriptService.IndexSystem)
local CodeRedeemSystem   = require(ServerScriptService.Systems.CodeRedeemSystem)

local _fuseOk, FuseSystem = pcall(require, ServerScriptService.SharedLib.Server.FuseSystem.FuseSystem)
if not _fuseOk then
    Logger.error("Main", "[FuseSystem] ERREUR require : %s", tostring(FuseSystem))
    FuseSystem = nil
else
    Logger.info("Main", "[FuseSystem] Module chargé ✓")
end


-- Chargement différé d'EventVisuals (dépendance circulaire au boot)
local _EventVisualsMain = nil
local function getEventVisualsMain()
    if not _EventVisualsMain then
        local ok, m = pcall(require, ServerScriptService.EventVisuals)
        if ok then _EventVisualsMain = m end
    end
    return _EventVisualsMain
end

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
local AssignBase         = CreerRemoteEvent("AssignBase")
local UpdateHUD          = CreerRemoteEvent("UpdateHUD")
local NotifEvent         = CreerRemoteEvent("NotifEvent")
local EventStarted       = CreerRemoteEvent("EventStarted")
local EventEnded         = CreerRemoteEvent("EventEnded")
local OfflineIncomeNotif = CreerRemoteEvent("OfflineIncomeNotif")
local SecretRevealNotif  = CreerRemoteEvent("SecretRevealNotif")
local CollectVFX         = CreerRemoteEvent("CollectVFX")
local SoundEvent         = CreerRemoteEvent("SoundEvent")
local OuvrirRebirth      = CreerRemoteEvent("OuvrirRebirth")




local OnboardingEvent    = CreerRemoteEvent("OnboardingEvent")

-- Events client → serveur (actions joueur)
local DemandeUpgrade        = CreerRemoteEvent("DemandeUpgrade")
local DemandePrestige       = CreerRemoteEvent("DemandePrestige")
local DemandeCollecte       = CreerRemoteEvent("DemandeCollecte")


local DemandeOuvrirRebirth  = CreerRemoteEvent("DemandeOuvrirRebirth")


local CollectAllEvent        = CreerRemoteEvent("CollectAllEvent")
local IndexDemander          = CreerRemoteEvent("IndexDemander")
local IndexRecevoir          = CreerRemoteEvent("IndexRecevoir")

-- Functions (requêtes avec réponse)
local GetPlayerData      = CreerRemoteFunction("GetPlayerData")
local GetUpgradeCost     = CreerRemoteFunction("GetUpgradeCost")

local CodeRedeem         = CreerRemoteFunction("CodeRedeem")
local GetTimerData       = CreerRemoteFunction("GetTimerData")

Logger.info("Main", "RemoteEvents créés ✓")

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

-- Envoie le HUD avec les coins réels (données + coins en attente dans les slots)
local function EnvoyerHUD(player, data)
    local extraCoins = IncomeSystem.GetCoinsEnAttente(player) or 0
    local coinsAffiches = (data.coins or 0) + extraCoins
    local hudData = {}
    for k, v in pairs(data) do hudData[k] = v end
    hudData.coins = coinsAffiches
    UpdateHUD:FireClient(player, hudData)
end

-- ═══════════════════════════════════════════════
-- (FlowerPots retirés — Kong)

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

    -- SpawnZone dans Specific/ (structure Shared/Specific)
    local specificFolder = baseModel:FindFirstChild("Specific")
    local spawnZone      = specificFolder and specificFolder:FindFirstChild("SpawnZone")
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

    -- Migrer / initialiser l'index des Brainrots
    IndexSystem.MigrerData(data)

    -- Envoyer HUD initial
    task.wait(1)  -- laisser le client charger
    EnvoyerHUD(player, data)
    IndexRecevoir:FireClient(player, data.indexObtenu)

    -- Sync event en cours pour les joueurs qui rejoignent mid-event
    local EV = getEventVisualsMain()
    if EV then
        local infoEvent = EV.GetTempsRestantEvent()
        if infoEvent.actif and infoEvent.tempsRestant > 0 then
            local evStarted = game.ReplicatedStorage:FindFirstChild("EventStarted")
            if evStarted then
                evStarted:FireClient(player, infoEvent.nom, infoEvent.tempsRestant)
            end
        end
    end

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

        -- Reconstruire la progression à partir du niveau rebirth AVANT Init.
        -- Garantit que les slots débloqués par rebirth sont corrects après reconnexion.
        data.progression = BaseProgressionSystem.BuildProgressionFromRebirth(data.rebirthLevel or 0)

        -- Initialiser la progression visuelle de la base
        BaseProgressionSystem.Init(player, baseIndex, data)

        -- Créer les ProximityPrompts de dépôt sur les spots actifs
        local spotsActifs = BaseProgressionSystem.GetSpotsActifs(player)
        CarrySystem.InitDepotSpotsBase(player, spotsActifs)

        -- Restaurer les BR déposés et initialiser le système de dépôt
        DropSystem.Init(player, baseIndex, data)

        -- Lancer la boucle de revenus passifs
        IncomeSystem.Init(player, function() return GetData(player) end)

        -- Réappliquer tous les upgrades shop achetés (WalkSpeed, Carry, etc.)
        ShopSystem.AppliquerTousUpgrades(player, data)

        -- Restaurer le carry sauvegardé (BRs portés à la déconnexion)
        if data.carryPortes and #data.carryPortes > 0 then
            local BrainrotsFolder = game:GetService("ServerStorage"):FindFirstChild("Brainrots")
            for _, porteeData in ipairs(data.carryPortes) do
                local rareteObj = {
                    nom         = porteeData.nom,
                    dossier     = porteeData.dossier or porteeData.nom,
                    isMutant    = porteeData.isMutant,
                    valeur      = porteeData.valeur,
                    elementType = porteeData.elementType,
                }
                -- Cloner le modèle exact si le nom est connu
                -- Cherche en direct puis dans les sous-dossiers numérotés (SECRET/1..5, GOD/1..2)
                local clone = nil
                if porteeData.brNom and BrainrotsFolder then
                    local dossier = BrainrotsFolder:FindFirstChild(porteeData.dossier or porteeData.nom)
                    local modele = nil
                    if dossier then
                        modele = dossier:FindFirstChild(porteeData.brNom)
                        if not modele then
                            for _, sub in ipairs(dossier:GetChildren()) do
                                if sub:IsA("Folder") and tonumber(sub.Name) then
                                    modele = sub:FindFirstChild(porteeData.brNom)
                                    if modele then break end
                                end
                            end
                        end
                    end
                    if modele then
                        clone = modele:Clone()
                        -- Parent temporaire requis : effectuerRamassage vérifie source.Parent ~= nil
                        clone.Parent = game:GetService("ServerStorage")
                    end
                end
                pcall(CarrySystem.AjouterAuCarry, player, clone, rareteObj)
            end
        end

        -- Initialiser le système d'Amélioration de Base
        AmelioSystem.Config = AmelioConfig
        AmelioSystem.OnButtonUpdate = function(p, etat)
            BoardSystem.MettreAJourBoard(p, etat)
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
            -- Notification Discord
            pcall(function()
                DiscordWebhook.Envoyer(
                    "🏗️ " .. p.Name .. " — Amélioration de base niveau " .. niveau,
                    string.format(
                        "**%s** a amélioré sa base au niveau **%d** \n" ..
                        "Multiplicateur : **×%.1f** | Slots bonus : **+%d**",
                        p.Name, niveau, cfg.multiplicateur, cfg.slotsBonus
                    ),
                    0x44BB66
                )
            end)
        end
        AmelioSystem.Init(player, data, baseIndex)

        -- Notifier le client de son baseIndex → RebirthHUD connecte le bouton Board
        task.delay(0.5, function()
            if player.Parent then
                AssignBase:FireClient(player, baseIndex)
            end
        end)

        -- Toujours respawn devant la base assignée (spawn initial + respawns)
        if player.Character then
            TeleporterVersBaseAssignee(player, baseIndex, player.Character)
            AmelioCosmeticsSystem.AppliquerPourJoueur(player, player.Character)
        end
        player.CharacterAdded:Connect(function(character)
            TeleporterVersBaseAssignee(player, baseIndex, character)
            AmelioCosmeticsSystem.AppliquerPourJoueur(player, character)
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

    Logger.info("Main", "%s connecté (Tier %s, Prestige %s)", player.Name, tostring(data.tier), tostring(data.prestige))
end

local function OnPlayerRemoving(player)
    -- Arrêter la boucle income avant la sauvegarde (évite les doublons de +coins)
    IncomeSystem.Stop(player)
    CodeRedeemSystem.OnPlayerRemoving(player)

    local data = GetData(player)
    if data then
        -- Accumuler le temps de jeu hebdo (Top Farmer Discord)
        local dureeSession = os.time() - (sessionStart[player.UserId] or os.time())
        data.tempsJeuSemaine = (data.tempsJeuSemaine or 0) + dureeSession
        data.tempsJeuTotal   = (data.tempsJeuTotal   or 0) + dureeSession
        sessionStart[player.UserId] = nil

        -- Sérialiser le carry maintenant (avant que nettoyerJoueur détruise les Tools)
        if CarrySystem.OnBeforeClean then
            pcall(CarrySystem.OnBeforeClean, player, CarrySystem.GetPortes(player))
        end

        -- Synchroniser spotsOccupes une dernière fois avant sauvegarde
        local spotsSerial = DropSystem.GetSpotsOccupesSerialisables(player)
        data.spotsOccupes = spotsSerial

        DataStoreManager.Save(player, data)
        playerDataCache[player.UserId] = nil
        BaseProgressionSystem.Reset(player)
        AmelioSystem.Reset(player)
        DropSystem.Stop(player)
        AssignationSystem.LibererBase(player)
        Logger.info("Main", "%s sauvegardé et déconnecté", player.Name)
    end
end

Players.PlayerAdded:Connect(OnPlayerAdded)
Players.PlayerRemoving:Connect(OnPlayerRemoving)

-- Sauvegarde d'urgence si le serveur s'arrête
-- task.wait() laisse OnPlayerRemoving traiter et vider playerDataCache avant qu'on itère
game:BindToClose(function()
    task.wait()
    for _, player in ipairs(Players:GetPlayers()) do
        local data = GetData(player)
        if data then
            DataStoreManager.Save(player, data)
        end
    end
    Logger.info("Main", "Sauvegarde d'urgence terminée")
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
    local coinsGagnes = math.floor(valeur * multiplier * AmelioSystem.GetMultiplicateur(player))

    data.coins = data.coins + coinsGagnes
    data.totalCoinsGagnes = (data.totalCoinsGagnes or 0) + coinsGagnes
    data.totalCollecte = (data.totalCollecte or 0) + 1
    if EventAdminAbuse and EventAdminAbuse.EstActif() then EventAdminAbuse.OnCollect(player) end

    -- Mettre à jour coinsParMinute (moyenne mobile)
    data.coinsParMinute = math.max(data.coinsParMinute or 1, coinsGagnes)

    -- Supprimer le collectible du serveur
    collectible:Destroy()

    -- Notifier le client (VFX + HUD)
    CollectVFX:FireClient(player, coinsGagnes, rarete)
    EnvoyerHUD(player, data)
    AmelioSystem.MettreAJourBouton(player)
end)

-- Upgrade
DemandeUpgrade.OnServerEvent:Connect(function(player)
    local data = GetData(player)
    if not data then return end
    
    local success, result = UpgradeSystem.AppliquerUpgrade(data)
    if success then
        SetData(player, result)
        EnvoyerHUD(player, result)

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
        EnvoyerHUD(player, result)
        NotifEvent:FireClient(player, "PRESTIGE", "Prestige " .. result.prestige .. " reached! Multiplier x" .. (result.prestige * (Config.PrestigeMultiplier - 1) + 1))
    else
        NotifEvent:FireClient(player, "ERREUR", result)
    end
end)


-- Ouvrir panel Rebirth depuis le bouton permanent (actualise les données avant d'ouvrir)
DemandeOuvrirRebirth.OnServerEvent:Connect(function(player)
    AmelioSystem.MettreAJourBouton(player)  -- fire RebirthButtonUpdate avec données fraîches
    local ouvrirEv = ReplicatedStorage:FindFirstChild("OuvrirRebirth")
    if ouvrirEv then pcall(function() ouvrirEv:FireClient(player) end) end
end)

-- Collect All — collecte tous les coins accumulés dans les slots en 1 action
CollectAllEvent.OnServerEvent:Connect(function(player)
    -- Anti-spam côté serveur (1 seconde de cooldown)
    local dernierTemps = player:GetAttribute("LastCollectAllTime") or 0
    local maintenant   = tick()
    if maintenant - dernierTemps < 1 then
        Logger.warn("Main", "[CollectAll] Spam détecté : %s", player.Name)
        return
    end
    player:SetAttribute("LastCollectAllTime", maintenant)

    local totalCollecte = IncomeSystem.CollecterTousLesSlots(player)

    if totalCollecte > 0 then
        local data = GetData(player)
        if data then
            -- Formater les coins pour la notification
            local affichage
            if totalCollecte >= 1e6 then
                affichage = string.format("%.1fM", totalCollecte / 1e6)
            elseif totalCollecte >= 1e3 then
                affichage = string.format("%.0fK", totalCollecte / 1e3)
            else
                affichage = tostring(math.floor(totalCollecte))
            end
            NotifEvent:FireClient(player, "SUCCESS", "+" .. affichage .. " coins collected!")
            EnvoyerHUD(player, data)
        end
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

-- RemoteFunction : timers affichés dans le widget HUD bottom-right (TimerHUD)
-- CommunSpawner est requis en bas du fichier (ligne ~1480) → require() en inline
-- (le module est déjà chargé à ce stade, require() renvoie l'instance cached)
GetTimerData.OnServerInvoke = function(_player)
    local CS           = require(ServerScriptService.CommunSpawner)
    local EV           = getEventVisualsMain()
    local eventInfo    = EV and EV.GetTempsRestantEvent() or { actif = false, tempsRestant = 0 }
    local prochainEv   = EventManager.GetProchainEvent()

    local mythic          = CS.GetProchainSpawn("MYTHIC")
    local secret          = CS.GetProchainSpawn("SECRET")



    local candidats = {
        { type = "MYTHIC", secondes = mythic.tempsRestant },
        { type = "SECRET", secondes = secret.tempsRestant },

    }
    local meilleur = nil
    for _, c in ipairs(candidats) do
        if c.secondes >= 0 then
            if not meilleur or c.secondes < meilleur.secondes then
                meilleur = c
            end
        end
    end

    return {
        eventActif        = eventInfo.actif,
        eventNom          = eventInfo.nom,
        eventTempsRestant = eventInfo.actif and eventInfo.tempsRestant or prochainEv,
        prochainSpecial   = meilleur or { type = "MYTHIC", secondes = -1 },
    }
end

-- ═══════════════════════════════════════════════
-- 6. INIT DES SYSTÈMES
-- ═══════════════════════════════════════════════

-- Brainrots dans ServerStorage (fallback par défaut de DropSystem)

-- Construire les previews visuels dans RS (shells pour ViewportFrame IndexClient)
BRPreviewsBuilder.Build()

-- IndexSystem : injecter les dépendances et initialiser
IndexSystem.GetData          = GetData
IndexSystem.DataStoreManager = DataStoreManager
IndexSystem.Init(IndexDemander, IndexRecevoir)

-- Hook DropSystem → IndexSystem (détection nouveaux BR déposés)
DropSystem.OnSpotChange = function(player)
    IndexSystem.OnSpotChange(player)
end

-- Hook premier dépôt BR (onboarding) : +100 coins one-time + notif client
DropSystem.OnBRDepose = function(player, _touchPart, _modeleSlot, _rarete)
    local data = GetData(player)
    if not data or data.hasFirstDeposit then return end
    data.hasFirstDeposit = true
    data.coins = (data.coins or 0) + 100
    Logger.debug("Onboard", "Premier dépôt : %s — +100 coins, hasFirstDeposit=true", player.Name)
    pcall(function() OnboardingEvent:FireClient(player, "firstDeposit", 100) end)
    EnvoyerHUD(player, data)
end

-- Visuels spot Mutant (doré + particules) — spécifique BRF, absent de LavaTower
DropSystem.OnMutantDepose = function(touchPart, modeleSlot, _elementType)
    local spotColor = Color3.fromRGB(255, 215, 0)
    touchPart.Color = spotColor
    local light = touchPart:FindFirstChild("MutantLight")
               or Instance.new("PointLight", touchPart)
    light.Name       = "MutantLight"
    light.Brightness = 2
    light.Range      = 10
    light.Color      = Color3.fromRGB(255, 215, 0)
    if modeleSlot then
        local root = modeleSlot.PrimaryPart
                  or modeleSlot:FindFirstChildWhichIsA("BasePart")
        if root then
            local p = Instance.new("ParticleEmitter", root)
            p.Rate     = 8
            p.Lifetime = NumberRange.new(0.5, 1.2)
            p.Speed    = NumberRange.new(2, 4)
            p.Color    = ColorSequence.new(Color3.fromRGB(255, 215, 0))
            p.Size     = NumberSequence.new(0.2)
            p.LightEmission = 0.8
        end
    end
end

DropSystem.OnMutantRetire = function(touchPart)
    touchPart.Color = Color3.fromRGB(106, 127, 63)
    local light = touchPart:FindFirstChild("MutantLight")
    if light then light:Destroy() end
end

-- Spawn des collectibles sur la map
SpawnManager.Init()
SpawnManager.SetGetData(GetData)

-- Hook CarrySystem → ProximityPrompt pour tous les BRs
-- wrappedCapture : détecte le premier pickup onboarding pour COMMON/OG/RARE/EPIC/LEGENDARY/GOD
SpawnManager.OnBRSpawned = function(brModel, baseIndex, rarete, onCapture)
    local wrappedCapture = function(player)
        local data = GetData(player)
        if data and not data.hasCompletedOnboarding then
            data.hasCompletedOnboarding = true
            Logger.debug("Onboard", "Premier pickup : %s — hasCompletedOnboarding=true", player.Name)
            pcall(function() OnboardingEvent:FireClient(player, "firstPickup") end)
        end
        if onCapture then onCapture(player) end
    end
    CarrySystem.OnBRSpawned(brModel, baseIndex, rarete, wrappedCapture)
end

-- Hook LeaderboardSystem → notifié quand un joueur capture un RARE+ via ProximityPrompt
SpawnManager.OnRareCollecte = function(player, rareteNom)
    LeaderboardSystem.EnregistrerRare(player, rareteNom)
    -- Discord : GOD uniquement (très rare → toujours envoyer)
    if rareteNom == "GOD" then
        pcall(DiscordWebhook.BrainrotGodCapture, player.Name)
    end
end

-- Collecte Touched (COMMON/OG/RARE) → ramassage carry avec le modèle monde
SpawnManager.OnCollecte = function(player, baseIndex, rarete, brModel)
    local ok = CarrySystem.AjouterAuCarry(player, brModel, rarete)
    -- Détection premier pickup (onboarding)
    if ok then
        local data = GetData(player)
        if data and not data.hasCompletedOnboarding then
            data.hasCompletedOnboarding = true
            Logger.debug("Onboard", "Premier pickup : %s — hasCompletedOnboarding=true", player.Name)
            pcall(function() OnboardingEvent:FireClient(player, "firstPickup") end)
        end
    end
    return ok
end

-- CarrySystem utilise AssignationSystem comme source de vérité pour la base du joueur
CarrySystem.GetBaseJoueur = function(player) return AssignationSystem.GetBaseIndex(player) end
CarrySystem.OnCarryChange = nil  -- FlowerPotSystem supprimé (illumination pots retirée)

-- Sérialiser le carry avant que CarrySystem détruise les Tools (PlayerRemoving)
CarrySystem.OnBeforeClean = function(player, portes)
    local data = GetData(player)
    if not data then return end
    local carrySerial = {}
    for _, entree in ipairs(portes) do
        -- Ne sauvegarder que les entrées avec un Tool encore vivant (évite les fantômes)
        if entree.rarete and entree.toolRef and entree.toolRef.Parent then
            -- Trouver le nom original du modèle (OriginalName sur le visuel dans le Tool)
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

CarrySystem.Init()

-- ZoneCommune (MYTHIC + SECRET)
local CommunSpawner = require(ServerScriptService.CommunSpawner)
CommunSpawner.OnCollecte = function(player, typeNom)
    local data = GetData(player)
    if not data then return end
    if not data.hasCompletedOnboarding then
        data.hasCompletedOnboarding = true
        Logger.debug("Onboard", "Premier pickup MYTHIC/SECRET : %s — hasCompletedOnboarding=true", player.Name)
        pcall(function() OnboardingEvent:FireClient(player, "firstPickup") end)
    end
    local cfg = { MYTHIC = { valeur = 300 }, SECRET = { valeur = 1000 } }
    local valeur = cfg[typeNom] and cfg[typeNom].valeur or 100
    local multiplier  = CollectSystem.GetMultiplier(data)
    local coinsGagnes = math.floor(valeur * multiplier * AmelioSystem.GetMultiplicateur(player))
    data.coins              = data.coins + coinsGagnes
    data.totalCoinsGagnes   = (data.totalCoinsGagnes or 0) + coinsGagnes
    data.totalCollecte      = (data.totalCollecte or 0) + 1
    EnvoyerHUD(player, data)
    CollectVFX:FireClient(player, coinsGagnes, { nom = typeNom, valeur = valeur })
    AmelioSystem.MettreAJourBouton(player)
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
    Logger.debug("Main", "_BrainrotReward BindableEvent créé ✓")
end

BrainrotReward.Event:Connect(function(player, montant, rarete)
    local data = GetData(player)
    if not data then return end
    local multiplier      = CollectSystem.GetMultiplier(data)
    local coinsGagnes     = math.floor(
        montant * multiplier * AmelioSystem.GetMultiplicateur(player)
    )
    data.coins            = data.coins + coinsGagnes
    data.totalCoinsGagnes = (data.totalCoinsGagnes or 0) + coinsGagnes
    data.totalCollecte    = (data.totalCollecte or 0) + 1
    EnvoyerHUD(player, data)
    CollectVFX:FireClient(player, coinsGagnes, rarete)
    AmelioSystem.MettreAJourBouton(player)
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

-- Injecter les dépendances dans EventAdminAbuse
if EventAdminAbuse then
    EventAdminAbuse.GetPlayerData = GetData
    EventAdminAbuse.FireUpdateHUD = function(p, d) UpdateHUD:FireClient(p, d) end
end

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

    -- SpawnZone dans Specific/ (structure Shared/Specific)
    local specificFolderSC = baseRoot:FindFirstChild("Specific")
    local spawnZone        = specificFolderSC and specificFolderSC:FindFirstChild("SpawnZone")
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
ShopSystem.FireUpdateHUD = function(player, data) EnvoyerHUD(player, data) end
ShopSystem.Init()

-- MonetizationHandler : injecter l'accesseur de données (pour ProcessReceipt)
MonetizationHandler.SetGetData(GetData)

-- CodeRedeemSystem : injecter les dépendances et connecter la RemoteFunction
CodeRedeemSystem.GetData       = GetData
CodeRedeemSystem.FireUpdateHUD = function(player, data) EnvoyerHUD(player, data) end

CodeRedeemSystem.CarrySystem   = CarrySystem

CodeRedeem.OnServerInvoke = function(player, code)
    return CodeRedeemSystem.Redeem(player, code)
end

-- AmelioCosmeticsSystem : auras + trails selon niveau rebirth
AmelioCosmeticsSystem.GetData = GetData
AmelioCosmeticsSystem.Init()

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

-- ═══════════════════════════════════════════════
-- 8. SYSTÈMES COMBAT PVP (chargés uniquement si Config.PvPEnabled)
-- ═══════════════════════════════════════════════

if Config.PvPEnabled then
	Logger.info("Main", "PvP activé → chargement des systèmes Combat")

	local SafeZoneTracker      = require(ServerScriptService.SharedLib.Server.Combat.SafeZoneTracker)
	local RespawnInvincibility = require(ServerScriptService.SharedLib.Server.Combat.RespawnInvincibility)
	local BatEquipHandler      = require(ServerScriptService.SharedLib.Server.Combat.BatEquipHandler)
	local BatSystem            = require(ServerScriptService.SharedLib.Server.Combat.BatSystem)

	-- Init dans l'ordre : zones safe → invincibilité → équipement → hit detection
	SafeZoneTracker.Init(Config.Combat)
	RespawnInvincibility.Init(Config.Combat)
	BatEquipHandler.Init(Config.Combat)
	BatSystem.Init(Config.Combat, SafeZoneTracker)

	Logger.info("Main", "Systèmes Combat initialisés")
else
	Logger.info("Main", "PvP désactivé (Config.PvPEnabled = false)")
end

-- ═══════════════════════════════════════════════
-- FUSE SYSTEM (tier par CashParSeconde, résultat dans le carry)
-- ═══════════════════════════════════════════════

-- Mapping slot interne FuseSystem → MutantType FlowerPot (pour filtre visuel)
local FUSE_SLOT_TO_MUTANT_TYPE = {
    GOLD    = "GALAXY",
    DIAMANT = "VOID",
    RAINBOW = "RAINBOW",
    TOXIC   = "TOXIC",
}
if FuseSystem then
    -- Ownership : seul le propriétaire de la base peut déposer dans sa Fuse Machine
    -- machine hiérarchie : Workspace/Bases/Base_X/Shared/Fuse
    FuseSystem.OnCheckOwnership = function(player, machine)
        local playerBase = AssignationSystem.GetBaseIndex(player)
        if not playerBase then return false end
        local shared     = machine.Parent
        local baseFolder = shared and shared.Parent
        if not baseFolder then return false end
        local machineBase = tonumber(baseFolder.Name:match("Base_(%d+)"))
        return machineBase == playerBase
    end

    -- Notifications Fuse → client (même canal que le reste du jeu)
    FuseSystem.OnNotif = function(player, type, message)
        if player and player.Parent then
            pcall(function() NotifEvent:FireClient(player, type, message) end)
        end
    end

    -- Résultat : cloner dans le carry via CarrySystem
    FuseSystem.OnResultatPret = function(player, brainrotClone)
        local rarete    = brainrotClone:GetAttribute("Rarete") or "COMMON"

        -- Appliquer filtre visuel si mutation FlowerPot
        local mutation   = brainrotClone:GetAttribute("Mutation")
        local mutantType = mutation and FUSE_SLOT_TO_MUTANT_TYPE[mutation]
        if mutantType then
            local mtInfo = Config.MutantTypesByName and Config.MutantTypesByName[mutantType]
            if mtInfo then
                brainrotClone:SetAttribute("IsMutant",   true)
                brainrotClone:SetAttribute("MutantType", mutantType)
                -- Parent requis avant Apply (FilterManager exige Parent ~= nil)
                brainrotClone.Parent = game:GetService("ServerStorage")
                -- (Filtre visuel BRFilterSystem retiré — Kong)
            end
        else
            brainrotClone.Parent = game:GetService("ServerStorage")
        end

        local rareteObj = {
            nom         = rarete,
            dossier     = rarete,
            isMutant    = brainrotClone:GetAttribute("IsMutant") == true,
            valeur      = brainrotClone:GetAttribute("Valeur")
                          or (Config.ValeurParRarete and Config.ValeurParRarete[rarete])
                          or 1,
            elementType = mutantType,
        }
        CarrySystem.SynchroniserCarry(player)
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
    Logger.warn("Main", "[FuseSystem] Init() ignoré — module non chargé")
end


Logger.info("Main", "Serveur démarré · %s", os.date("%d/%m/%Y %H:%M"))
