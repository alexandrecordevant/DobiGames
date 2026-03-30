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
local CollectSystem      = require(ServerScriptService.SharedLib.Shared.CollectSystem)
local UpgradeSystem      = require(ServerScriptService.SharedLib.Shared.UpgradeSystem)

local DataStoreManager      = require(ServerScriptService.DataStoreManager)
local EventManager          = require(ServerScriptService.SharedLib.Server.EventManager)
local MonetizationHandler   = require(ServerScriptService.SharedLib.Server.MonetizationHandler)
local SpawnManager          = require(ServerScriptService.SpawnManager)
local BaseProgressionSystem = require(ServerScriptService.SharedLib.Server.BaseProgressionSystem)
local CarrySystem           = require(ServerScriptService.SharedLib.Server.CarrySystem)
local RebirthSystem         = require(ServerScriptService.SharedLib.Server.RebirthSystem)
local AssignationSystem     = require(ServerScriptService.SharedLib.Server.AssignationSystem)
local DropSystem            = require(ServerScriptService.SharedLib.Server.DropSystem)
local IncomeSystem          = require(ServerScriptService.SharedLib.Server.IncomeSystem)
local LeaderboardSystem     = require(ServerScriptService.LeaderboardSystem)
local ShopSystem            = require(ServerScriptService.ShopSystem)
local SprinklerSystem       = require(ServerScriptService.SprinklerSystem)
local TracteurSystem        = require(ServerScriptService.TracteurSystem)
local FlowerPotGrowthSystem = require(ServerScriptService.Systems.FlowerPotSystem.FlowerPotGrowthSystem)
local SeedInventory         = require(ServerScriptService.SeedInventory)
local DiscordWebhook        = require(ServerScriptService.DiscordWebhook)
local BoardSystem               = require(ServerScriptService.BoardSystem)
local ArbreSystem               = require(ServerScriptService.ArbreSystem)
local BaleSystem                = require(ServerScriptService.BaleSystem)
local RebirthCosmeticsSystem    = require(ServerScriptService.SharedLib.Server.RebirthCosmeticsSystem)

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
local OuvrirPot          = CreerRemoteEvent("OuvrirPot")
local PotUpdate          = CreerRemoteEvent("PotUpdate")
local PotBillboardUpdate = CreerRemoteEvent("PotBillboardUpdate")

-- Events client → serveur (actions joueur)
local DemandeUpgrade        = CreerRemoteEvent("DemandeUpgrade")
local DemandePrestige       = CreerRemoteEvent("DemandePrestige")
local DemandeCollecte       = CreerRemoteEvent("DemandeCollecte")
local DebloquerPot          = CreerRemoteEvent("DebloquerPot")
local InstantGrowPot        = CreerRemoteEvent("InstantGrowPot")
local DemandeOuvrirRebirth  = CreerRemoteEvent("DemandeOuvrirRebirth")
local ClaimDailySeed        = CreerRemoteEvent("ClaimDailySeed")

-- Functions (requêtes avec réponse)
local GetPlayerData      = CreerRemoteFunction("GetPlayerData")
local GetUpgradeCost     = CreerRemoteFunction("GetUpgradeCost")
local GetSeedInfo        = CreerRemoteFunction("GetSeedInfo")

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
-- INITIALISATION DES FLOWER POTS (remplace FlowerPotSystem.Init)
-- Placé ici pour que GetData/SetData soient en portée (upvalues)
-- ═══════════════════════════════════════════════

-- Retourne un callback onElementChosen qui persiste l'élément dans data.pots
local function makeOnElementChosen(player, potIndex)
    return function(elem)
        local d = GetData(player)
        if d and d.pots and d.pots[potIndex] then
            d.pots[potIndex].elementType = elem
        end
    end
end

-- Retourne un callback onBRNomChosen qui persiste le nom du modèle mutant
local function makeOnBRNomChosen(player, potIndex)
    return function(nom)
        local d = GetData(player)
        if d and d.pots and d.pots[potIndex] then
            d.pots[potIndex].brNom = nom
        end
    end
end

local InitialiserPots  -- déclaration forward (la fonction s'appelle elle-même)
InitialiserPots = function(player, baseIndex, playerData)
    print("[InitialiserPots] START player=" .. player.Name .. " baseIndex=" .. tostring(baseIndex))
    local bases = workspace:FindFirstChild("Bases")
    local base  = bases and bases:FindFirstChild("Base_" .. baseIndex)
    if not base then
        warn("[InitialiserPots] Base_" .. tostring(baseIndex) .. " introuvable dans workspace.Bases")
        return
    end

    local FPCfg = Config.FlowerPotConfig
    if not FPCfg then
        warn("[InitialiserPots] Config.FlowerPotConfig manquant")
        return
    end

    for potIndex = 1, 4 do
        local potModel = base:FindFirstChild("FlowerPot_" .. potIndex)
        if not potModel then
            warn("[InitialiserPots] FlowerPot_" .. potIndex .. " introuvable dans Base_" .. baseIndex)
            continue
        end

        -- Migration : créer le potData manquant si la save est ancienne
        if playerData.pots and not playerData.pots[potIndex] then
            playerData.pots[potIndex] = { debloque=(potIndex==1), rarete=nil, stage=0, tempsRestant=0, instantGrow=false }
        end
        local potData = playerData.pots and playerData.pots[potIndex]
        local potCfg  = FPCfg.pots and FPCfg.pots[potIndex]
        if not potData or not potCfg then
            warn("[InitialiserPots] potData ou potCfg manquant pour pot", potIndex, "— skip")
            continue
        end

        local potPart = potModel:IsA("BasePart") and potModel
            or potModel:FindFirstChildWhichIsA("BasePart", true)
        if not potPart then
            warn("[InitialiserPots] Aucun BasePart trouvé dans", potModel.Name, "— pot ignoré")
            continue
        end

        print("[InitialiserPots] Pot" .. potIndex .. " | part=" .. potPart.Name .. " | debloque=" .. tostring(potData.debloque) .. " | rarete=" .. tostring(potData.rarete))

        -- Nettoyer ProximityPrompts ET BillboardGuis sur tout le modèle
        for _, desc in ipairs(potModel:GetDescendants()) do
            if desc:IsA("ProximityPrompt") or desc:IsA("BillboardGui") then
                desc:Destroy()
            end
        end

        -- Cacher/montrer le modèle cadenas physique selon l'état du pot
        local cadenas = base:FindFirstChild("Cadenas_B" .. baseIndex .. "_P" .. potIndex)
        if cadenas then
            local visible = not potData.debloque
            for _, desc in ipairs(cadenas:GetDescendants()) do
                if desc:IsA("BasePart") then
                    desc.Transparency = visible and 0 or 1
                    desc.CanCollide   = visible
                elseif desc:IsA("BillboardGui") or desc:IsA("SurfaceGui") then
                    desc.Enabled = visible
                end
            end
            if cadenas:IsA("BasePart") then
                cadenas.Transparency = visible and 0 or 1
                cadenas.CanCollide   = visible
            end
        end

        -- Helper billboard minimaliste pour l'état du pot
        local function creerBillboardPot(texte, couleur)
            local bb = Instance.new("BillboardGui", potPart)
            bb.Name        = "PotBillboard"
            bb.Size        = UDim2.new(0, 220, 0, 56)
            bb.StudsOffset = Vector3.new(0, 12, 0)
            bb.AlwaysOnTop = false
            bb.MaxDistance = 60
            local bg = Instance.new("Frame", bb)
            bg.Size = UDim2.new(1,0,1,0)
            bg.BackgroundColor3 = Color3.fromRGB(10,10,20)
            bg.BackgroundTransparency = 0.3
            bg.BorderSizePixel = 0
            Instance.new("UICorner", bg).CornerRadius = UDim.new(0,6)
            local lbl = Instance.new("TextLabel", bg)
            lbl.Size = UDim2.new(1,0,1,0)
            lbl.BackgroundTransparency = 1
            lbl.TextColor3 = couleur or Color3.fromRGB(255,255,255)
            lbl.Font = Enum.Font.GothamBold
            lbl.TextSize = 17
            lbl.Text = texte
            lbl.TextWrapped = true
            lbl.RichText = true
        end

        -- ── Pot verrouillé ──
        if not potData.debloque then
            PotBillboardUpdate:FireClient(player, potModel, nil)
            local prixCoins = potCfg.prixCoins or 0
            local prixRobux = potCfg.prixRobux or 0
            local prixLabel = prixCoins > 0
                and prixCoins .. " 💰"
                or  prixRobux .. " R$"

            creerBillboardPot("🔒 " .. prixLabel, Color3.fromRGB(255, 180, 50))

            local prompt = Instance.new("ProximityPrompt")
            prompt.ActionText            = "Unlock"
            prompt.ObjectText            = "🔒 FlowerPot " .. potIndex .. " — " .. prixLabel
            prompt.HoldDuration          = 0
            prompt.MaxActivationDistance = 8
            prompt.RequiresLineOfSight   = false
            prompt.Parent                = potPart

            -- Ouvrir la modal de déblocage (gérée via DebloquerPot RemoteEvent)
            prompt.Triggered:Connect(function(p)
                if p ~= player then return end
                OuvrirPot:FireClient(p, potIndex, "debloque")
            end)

        -- ── Pot avec graine en cours (rejoin) → reprendre croissance au bon stage ──
        elseif potData.rarete then
            if not FlowerPotGrowthSystem.EstEnCroissance(potModel) then
                -- Calculer l'avancement depuis le temps de plantation
                local dureeStage  = (FPCfg and FPCfg.GrowthDuration) or 120
                local plantedAt   = potData.plantedAt or os.time()
                local elapsed     = os.time() - plantedAt
                local etape       = math.min(5, math.floor(elapsed / dureeStage))
                local premAttente = math.max(1, dureeStage - (elapsed % dureeStage))
                print(string.format("[DEBUG FlowerPot] Pot%d rejoin | rarete=%s | plantedAt=%s | elapsed=%ds | etape=%d | premAttente=%ds",
                    potIndex, tostring(potData.rarete), tostring(plantedAt), elapsed, etape, premAttente))
                task.spawn(function()
                    FlowerPotGrowthSystem.PlantSeed(potModel, potData.rarete, player,
                        function(tp, elem, mult)
                            local d = GetData(player)
                            if d and d.pots and d.pots[potIndex] then
                                d.pots[potIndex].rarete      = nil
                                d.pots[potIndex].stage       = 0
                                d.pots[potIndex].plantedAt   = nil
                                d.pots[potIndex].elementType = nil
                                d.pots[potIndex].brNom       = nil
                            end
                            local latest = GetData(player)
                            if latest then InitialiserPots(player, baseIndex, latest) end
                        end,
                        {
                            etapeCourante   = etape,
                            premiereAttente = premAttente,
                            elementType     = potData.elementType,
                            brNom           = potData.brNom,
                            onElementChosen = makeOnElementChosen(player, potIndex),
                            onBRNomChosen   = makeOnBRNomChosen(player, potIndex),
                        })
                end)
            end

            -- Prompt pour voir l'état du pot en cours de croissance
            local promptInfos = Instance.new("ProximityPrompt")
            promptInfos.ActionText            = "Info"
            promptInfos.ObjectText            = "🌱 FlowerPot " .. potIndex .. " — Growing"
            promptInfos.HoldDuration          = 0
            promptInfos.MaxActivationDistance = 8
            promptInfos.RequiresLineOfSight   = false
            promptInfos.Parent                = potPart

            -- Envoyer les données au client pour la BillboardGui 3D
            do
                local dureeStage = (FPCfg and FPCfg.GrowthDuration) or 120
                PotBillboardUpdate:FireClient(player, potModel, {
                    plantedAt  = potData.plantedAt or os.time(),
                    dureeStage = dureeStage,
                    rarete     = potData.rarete,
                })
            end

            promptInfos.Triggered:Connect(function(p)
                if p ~= player then return end
                local d = GetData(player)
                if not d or not d.pots or not d.pots[potIndex] then return end
                -- Lire le statut réel depuis le système de croissance
                local statut = FlowerPotGrowthSystem.GetStatut(potModel)
                local stageInterne = (statut and statut.stage) or d.pots[potIndex].stage or -1
                local rarete = (statut and statut.rarity) or d.pots[potIndex].rarete or "MYTHIC"
                -- Stage affiché : interne (-1 à 3) → display (0 à 4)
                local stageAffiche = math.max(0, stageInterne + 1)
                -- Calculer le temps restant réel depuis plantedAt
                local dureeStage = (FPCfg and FPCfg.GrowthDuration) or 120
                local tempsRestant = 0
                if stageAffiche < 5 then
                    local plantedAt = d.pots[potIndex].plantedAt
                    if plantedAt then
                        local elapsed = os.time() - plantedAt
                        local etapeActuelle = math.min(5, math.floor(elapsed / dureeStage))
                        tempsRestant = math.max(0, dureeStage - (elapsed % dureeStage))
                        -- Si déjà terminé
                        if etapeActuelle >= 5 then tempsRestant = 0 end
                    else
                        tempsRestant = dureeStage
                    end
                end
                OuvrirPot:FireClient(p, potIndex, "infos", {
                    rarete       = rarete,
                    stage        = stageAffiche,
                    tempsRestant = tempsRestant,
                })
            end)

        -- ── Pot vide et débloqué → prompt "Planter" ──
        else
            PotBillboardUpdate:FireClient(player, potModel, nil)
            creerBillboardPot(
                FPCfg.labelPotVide or "🌱 Plant MYTHIC / SECRET",
                Color3.fromRGB(120, 220, 100))

            local prompt = Instance.new("ProximityPrompt")
            prompt.ActionText            = "Plant"
            prompt.ObjectText            = "🌱 FlowerPot " .. potIndex
            prompt.HoldDuration          = 0
            prompt.MaxActivationDistance = 8
            prompt.RequiresLineOfSight   = false
            prompt.Parent                = potPart

            local cnx = nil
            cnx = prompt.Triggered:Connect(function(p)
                if p ~= player then return end

                -- Si le joueur a des graines → planter directement
                local carriedSeeds = p:FindFirstChild("CarriedSeeds")
                if carriedSeeds and #carriedSeeds:GetChildren() > 0 then

                    -- Prendre la meilleure graine portée (SECRET prioritaire sur MYTHIC)
                    local seedToUse = nil
                    for _, sv in ipairs(carriedSeeds:GetChildren()) do
                        if sv.Value == "SECRET" then seedToUse = sv; break end
                    end
                    if not seedToUse then
                        for _, sv in ipairs(carriedSeeds:GetChildren()) do
                            if sv.Value == "MYTHIC" then seedToUse = sv; break end
                        end
                    end
                    if not seedToUse then seedToUse = carriedSeeds:GetChildren()[1] end
                    if not seedToUse then return end

                    local bestRarity = seedToUse.Value

                    -- Retirer la graine des mains
                    seedToUse:Destroy()

                    local freshData = GetData(player)
                    if not freshData then return end

                    -- Mémoriser dans les données (persistance DataStore)
                    local now = os.time()
                    if freshData.pots and freshData.pots[potIndex] then
                        freshData.pots[potIndex].rarete    = bestRarity
                        freshData.pots[potIndex].stage     = 0
                        freshData.pots[potIndex].plantedAt = now
                    end

                    -- Billboard 3D immédiatement
                    local dureeStage = (FPCfg and FPCfg.GrowthDuration) or 120
                    PotBillboardUpdate:FireClient(player, potModel, {
                        plantedAt  = now,
                        dureeStage = dureeStage,
                        rarete     = bestRarity,
                    })

                    -- Détruire le prompt "Plant" avant de lancer la croissance
                    if cnx then cnx:Disconnect() cnx = nil end
                    if prompt.Parent then prompt:Destroy() end

                    -- Lancer la séquence de croissance
                    FlowerPotGrowthSystem.PlantSeed(potModel, bestRarity, player,
                        function(tp, elem, mult)
                            local d = GetData(player)
                            if d and d.pots and d.pots[potIndex] then
                                d.pots[potIndex].rarete      = nil
                                d.pots[potIndex].stage       = 0
                                d.pots[potIndex].plantedAt   = nil
                                d.pots[potIndex].elementType = nil
                                d.pots[potIndex].brNom       = nil
                            end
                            local latest = GetData(player)
                            if latest then InitialiserPots(player, baseIndex, latest) end
                        end,
                        {
                            onElementChosen = makeOnElementChosen(player, potIndex),
                            onBRNomChosen   = makeOnBRNomChosen(player, potIndex),
                        })

                    -- Recréer les prompts immédiatement (pot passe en mode "growing")
                    -- task.defer laisse le thread PlantSeed démarrer avant
                    task.defer(function()
                        local latest = GetData(player)
                        if latest then InitialiserPots(player, baseIndex, latest) end
                    end)

                else
                    -- Pas de graines → ouvrir la modal (daily seed, etc.)
                    local d = GetData(p)
                    local dailySeedData = d and d.dailySeed or {}
                    OuvrirPot:FireClient(p, potIndex, "empty", dailySeedData)
                end
            end)
        end
    end
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
    EnvoyerHUD(player, data)

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
                local clone = nil
                if porteeData.brNom and BrainrotsFolder then
                    local dossier = BrainrotsFolder:FindFirstChild(porteeData.dossier or porteeData.nom)
                    local modele = dossier and dossier:FindFirstChild(porteeData.brNom)
                    if modele then
                        clone = modele:Clone()
                        -- Parent temporaire requis : effectuerRamassage vérifie source.Parent ~= nil
                        clone.Parent = game:GetService("ServerStorage")
                    end
                end
                pcall(CarrySystem.AjouterAuCarry, player, clone, rareteObj)
            end
        end

        -- Réactiver le sprinkler si upgrade Arroseur acheté
        local niveauArroseur = data.upgrades and data.upgrades.upgradeArroseur or 0
        if niveauArroseur > 0 then
            pcall(SprinklerSystem.ActiverBase, baseIndex, niveauArroseur)
        end

        -- Réactiver l'animation tracteur si upgrade Tracteur acheté
        if data.hasTracteur then
            pcall(TracteurSystem.Activer, player, baseIndex)
        end

        -- BaleSystem 
        BaleSystem.Init();

        -- Initialiser les pots de fleurs
        InitialiserPots(player, baseIndex, data)

        -- Restaurer les graines sauvegardées dans CarriedSeeds (data.graines → dossier joueur)
        local graines = data.graines
        if graines then
            local carriedSeeds = player:FindFirstChild("CarriedSeeds")
            if not carriedSeeds then
                carriedSeeds = Instance.new("Folder")
                carriedSeeds.Name   = "CarriedSeeds"
                carriedSeeds.Parent = player
            end
            for rarete, count in pairs(graines) do
                for _ = 1, count do
                    local sv       = Instance.new("StringValue")
                    sv.Value       = rarete
                    sv.Parent      = carriedSeeds
                end
            end
            UpdateGraines:FireClient(player, graines)
        end

        -- Initialiser le système de Rebirth (callbacks Farm injectés ici)
        RebirthSystem.Config = Config.RebirthConfig
        RebirthSystem.IsProgressionComplete = function(playerData)
            return playerData.progression and playerData.progression["4_10"] == true
        end
        RebirthSystem.OnRebirthComplete = function(player, niveau, cfg)
            -- Recréer les ProximityPrompts pour les spots du floor 1 (après Init)
            local spotsActifs = BaseProgressionSystem.GetSpotsActifs(player)
            CarrySystem.InitDepotSpotsBase(player, spotsActifs)
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
        -- GetExtraCoins non injecté : le rebirth ne compte que data.coins (coins réellement collectés)
        RebirthSystem.OnButtonUpdate = function(p, etat)
            BoardSystem.MettreAJourBoard(p, etat)
        end
        RebirthSystem.OnResetBase = function(p, bIndex, d)
            -- Arrêter et vider DropSystem (mini BRs sur spots détruits)
            DropSystem.Stop(p)
            -- Vider les coinsEnAttente d'IncomeSystem (les slots sont maintenant vides)
            IncomeSystem.Stop(p)
            -- Réinitialiser DropSystem avec les données réinitialisées (spotsOccupes = {})
            DropSystem.Init(p, bIndex, d)
            -- Relancer IncomeSystem
            IncomeSystem.Init(p, function() return GetData(p) end)
            -- Note : CarrySystem.InitDepotSpotsBase est appelé APRÈS BaseProgressionSystem.Init
            -- dans RebirthSystem.OnRebirthComplete (via GetSpotsActifs sur la nouvelle progression)
        end
        RebirthSystem.Init(player, data, baseIndex)

        -- Toujours respawn devant la base assignée (spawn initial + respawns)
        if player.Character then
            TeleporterVersBaseAssignee(player, baseIndex, player.Character)
            RebirthCosmeticsSystem.AppliquerPourJoueur(player, player.Character)
        end
        player.CharacterAdded:Connect(function(character)
            TeleporterVersBaseAssignee(player, baseIndex, character)
            RebirthCosmeticsSystem.AppliquerPourJoueur(player, character)
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

        -- carryPortes déjà sérialisé via CarrySystem.OnBeforeClean (avant destruction des Tools)

        -- Synchroniser spotsOccupes une dernière fois avant sauvegarde
        local spotsSerial = DropSystem.GetSpotsOccupesSerialisables(player)
        data.spotsOccupes = spotsSerial

        if data.pots then
            for pi, pd in pairs(data.pots) do
                print(string.format("[DEBUG FlowerPot] SAVE Pot%d | rarete=%s | plantedAt=%s",
                    pi, tostring(pd.rarete), tostring(pd.plantedAt)))
            end
        end
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

-- Débloquer un pot via modal FlowerPotHUD
DebloquerPot.OnServerEvent:Connect(function(player, potIndex)
    local data = GetData(player)
    if not data or not data.pots or not data.pots[potIndex] then return end
    if data.pots[potIndex].debloque then return end

    local FPCfg  = Config.FlowerPotConfig
    local potCfg = FPCfg and FPCfg.pots and FPCfg.pots[potIndex]
    if not potCfg then return end

    local prixCoins = potCfg.prixCoins or 0
    local prixRobux = potCfg.prixRobux or 0

    if prixCoins > 0 then
        if data.coins < prixCoins then
            NotifEvent:FireClient(player, "ERROR",
                "❌ Pas assez de coins! Il te faut " .. prixCoins .. " 💰")
            return
        end
        data.coins = data.coins - prixCoins
        data.pots[potIndex].debloque = true
        NotifEvent:FireClient(player, "SUCCESS", "✅ FlowerPot " .. potIndex .. " débloqué!")
        EnvoyerHUD(player, data)
        local baseIndex = AssignationSystem.GetBaseIndex(player)
        if baseIndex then InitialiserPots(player, baseIndex, data) end

    elseif prixRobux > 0 then
        local gpId = potCfg.gamePassId or Config.GamePassIds.FlowerPot4 or 0
        if gpId == 0 then
            NotifEvent:FireClient(player, "ERROR", "❌ Game Pass non configuré")
            return
        end
        local ok, owned = pcall(function()
            return game:GetService("MarketplaceService"):UserOwnsGamePassAsync(player.UserId, gpId)
        end)
        if ok and owned then
            data.pots[potIndex].debloque = true
            NotifEvent:FireClient(player, "SUCCESS", "✅ FlowerPot 4 débloqué via Game Pass!")
            EnvoyerHUD(player, data)
            local baseIndex = AssignationSystem.GetBaseIndex(player)
            if baseIndex then InitialiserPots(player, baseIndex, data) end
        else
            game:GetService("MarketplaceService"):PromptGamePassPurchase(player, gpId)
        end
    end
end)

-- Croissance instantanée via modal FlowerPotHUD (bouton Instant Grow)
InstantGrowPot.OnServerEvent:Connect(function(player, potIndex)
    local data = GetData(player)
    if not data or not data.pots or not data.pots[potIndex] then return end
    if not data.pots[potIndex].debloque or not data.pots[potIndex].rarete then
        NotifEvent:FireClient(player, "ERROR", "❌ Aucune graine dans ce pot!")
        return
    end
    local igCfg = Config.FlowerPotConfig and Config.FlowerPotConfig.instantGrow
    local gpId  = igCfg and igCfg.gamePassId or 0
    if gpId > 0 then
        local ok, owned = pcall(function()
            return game:GetService("MarketplaceService"):UserOwnsGamePassAsync(player.UserId, gpId)
        end)
        if ok and owned then
            FlowerPotGrowthSystem.InstantGrow(player, potIndex)
        else
            game:GetService("MarketplaceService"):PromptGamePassPurchase(player, gpId)
        end
    else
        -- DevProduct → géré dans MonetizationHandler via ProcessReceipt
        NotifEvent:FireClient(player, "INFO", "⚡ Instant Grow : achat Robux requis.")
    end
end)

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
    EnvoyerHUD(player, data)
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
    RebirthSystem.MettreAJourBouton(player)  -- fire RebirthButtonUpdate avec données fraîches
    local ouvrirEv = ReplicatedStorage:FindFirstChild("OuvrirRebirth")
    if ouvrirEv then pcall(function() ouvrirEv:FireClient(player) end) end
end)

-- Réclamer la Daily Seed (cycle 7 jours)
ClaimDailySeed.OnServerEvent:Connect(function(player)
    local data = GetData(player)
    if not data or not data.dailySeed then return end

    if not data.dailySeed.graineDispo then
        NotifEvent:FireClient(player, "INFO", "⏳ Daily Seed pas encore disponible!")
        return
    end

    -- Rareté selon le cycle configuré dans GameConfig
    local cfg         = Config.FlowerPotConfig and Config.FlowerPotConfig.dailySeed
    local jourActuel  = data.dailySeed.jourActuel or 1
    local rarity      = (cfg and cfg.cycle and cfg.cycle[jourActuel]) or "MYTHIC"

    -- Compteur statistique permanent (jamais prélevé pour planter)
    SeedInventory.Add(data, rarity, 1)
    SeedInventory.NotifyClient(player, data)

    -- Ajouter la graine dans les mains du joueur (CarriedSeeds)
    local dCarriedSeeds = player:FindFirstChild("CarriedSeeds")
    if not dCarriedSeeds then
        dCarriedSeeds        = Instance.new("Folder")
        dCarriedSeeds.Name   = "CarriedSeeds"
        dCarriedSeeds.Parent = player
    end
    local dSeedVal       = Instance.new("StringValue")
    dSeedVal.Name        = "Seed"
    dSeedVal.Value       = rarity
    dSeedVal.Parent      = dCarriedSeeds

    -- Mettre à jour l'état daily seed
    data.dailySeed.graineDispo    = false
    data.dailySeed.dernieresClaim = os.time()
    data.dailySeed.jourActuel     = (jourActuel % 7) + 1  -- cycle 1 → 7 → 1

    NotifEvent:FireClient(player, "SUCCESS",
        "🌱 Daily Seed " .. rarity .. " reçue ! (Jour " .. jourActuel .. "/7)")
    EnvoyerHUD(player, data)
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

-- RemoteFunction : état complet des graines (daily seed + arbres + pots)
GetSeedInfo.OnServerInvoke = function(player)
    local data = GetData(player)
    if not data then return nil end

    local timerRestant, graineDispo = ArbreSystem.GetTimerRestant()

    -- Statut des 4 pots de la base du joueur
    local potsStatus = {}
    local baseIndex  = AssignationSystem.GetBaseIndex(player)
    if baseIndex then
        local bases = workspace:FindFirstChild("Bases")
        local base  = bases and bases:FindFirstChild("Base_" .. baseIndex)
        for potIndex = 1, 4 do
            local potData = data.pots and data.pots[potIndex]
            local debloque = potData and potData.debloque or false
            local statut = nil
            if debloque and base then
                local potModel = base:FindFirstChild("FlowerPot_" .. potIndex)
                if potModel then
                    statut = FlowerPotGrowthSystem.GetStatut(potModel)
                end
            end
            potsStatus[potIndex] = {
                debloque = debloque,
                statut   = statut,  -- nil=vide, ou { statut, rarity, stage, elementType, ... }
            }
        end
    end

    return {
        graines           = data.graines or { MYTHIC=0, SECRET=0 },
        dailySeed         = data.dailySeed,
        dailyCycle        = Config.FlowerPotConfig.dailySeed.cycle,
        intervalleHeures  = Config.FlowerPotConfig.dailySeed.intervalleHeures,
        arbreTimerRestant = timerRestant,
        arbreGraineDispo  = graineDispo,
        pots              = potsStatus,
    }
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
CarrySystem.OnCarryChange = nil  -- FlowerPotSystem supprimé (illumination pots retirée)

-- Sérialiser le carry avant que CarrySystem détruise les Tools (PlayerRemoving)
CarrySystem.OnBeforeClean = function(player, portes)
    local data = GetData(player)
    if not data then return end
    local carrySerial = {}
    for _, entree in ipairs(portes) do
        if entree.rarete then
            -- Trouver le nom original du modèle (OriginalName sur le visuel dans le Tool)
            local brNom = nil
            if entree.toolRef then
                for _, child in ipairs(entree.toolRef:GetChildren()) do
                    if child.Name ~= "Handle" and (child:IsA("Model") or child:IsA("BasePart")) then
                        brNom = child:GetAttribute("OriginalName") or child.Name
                        break
                    end
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
    print("[" .. Config.NomDuJeu .. "] " .. player.Name .. " carry sauvegardé : " .. #carrySerial .. " BR(s)")
end

CarrySystem.Init()

-- ZoneCommune (MYTHIC + SECRET)
local CommunSpawner = require(ServerScriptService.CommunSpawner)
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
    EnvoyerHUD(player, data)
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
    EnvoyerHUD(player, data)
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
ShopSystem.FireUpdateHUD = function(player, data) EnvoyerHUD(player, data) end
ShopSystem.Init()

-- SprinklerSystem : désactiver tous les sprinklers par défaut
SprinklerSystem.Init()

-- TracteurSystem : prêt (aucun tracteur actif au démarrage)
TracteurSystem.Init()

-- MonetizationHandler : injecter l'accesseur de données (pour ProcessReceipt)
MonetizationHandler.SetGetData(GetData)

-- ArbreSystem : graines sur les arbres du ChampCommun
ArbreSystem.GetData = GetData
ArbreSystem.Init()

-- RebirthCosmeticsSystem : auras + trails selon niveau rebirth
RebirthCosmeticsSystem.GetData = GetData
RebirthCosmeticsSystem.Init()

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
	print("[" .. Config.NomDuJeu .. "] PvP activé → chargement des systèmes Combat")

	local SafeZoneTracker      = require(ServerScriptService.SharedLib.Server.Combat.SafeZoneTracker)
	local RespawnInvincibility = require(ServerScriptService.SharedLib.Server.Combat.RespawnInvincibility)
	local BatEquipHandler      = require(ServerScriptService.SharedLib.Server.Combat.BatEquipHandler)
	local BatSystem            = require(ServerScriptService.SharedLib.Server.Combat.BatSystem)

	-- Init dans l'ordre : zones safe → invincibilité → équipement → hit detection
	SafeZoneTracker.Init(Config.Combat)
	RespawnInvincibility.Init(Config.Combat)
	BatEquipHandler.Init(Config.Combat)
	BatSystem.Init(Config.Combat, SafeZoneTracker)

	print("[" .. Config.NomDuJeu .. "] Systèmes Combat initialisés")
else
	print("[" .. Config.NomDuJeu .. "] PvP désactivé (Config.PvPEnabled = false)")
end

print("[" .. Config.NomDuJeu .. "] Serveur démarré · " .. os.date("%d/%m/%Y %H:%M"))
