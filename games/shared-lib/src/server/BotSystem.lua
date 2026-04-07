-- BotSystem.lua
-- ServerScriptService/Systems/BotSystem.lua
-- Simule des joueurs IA sur les bases vides pour donner vie au serveur

local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Logger = require(script.Parent.Logger)

-- Configuration des bots
local BOT_CONFIG = {
    -- Noms affichés au-dessus des bots
    noms = {
        "xXBrainRotKingXx", "FarmerPro2026", "ChampMaster99",
        "BrainRotFan", "GigaFarmer", "SkibidiCollector", "NoobFarmer42"
    },
    -- UserIds Roblox dont le skin sera appliqué aux bots (un par bot, en rotation)
    -- Remplace par les IDs de tes amis / ton propre ID pour des avatars réalistes
    userIds = {
        1,          -- Roblox (compte officiel)
        156,        -- Builderman
        261,        -- john doe
        2096945,    -- exemple — remplace par ton UserId si tu veux ton skin
    },
    -- Délai avant de spawner les bots (attendre que la map charge)
    delaiDemarrage = 5,
    -- Vitesse de déplacement des bots (studs/sec)
    vitesseDeplacement = 14,
    -- Intervalle entre chaque cycle (pick up → deposit)
    cycleMin = 8,
    cycleMax = 18,
    -- Hauteur du personnage au sol
    hauteurPerso = 3,
    -- Activer uniquement si moins de X vrais joueurs
    seuilJoueursReels = 4,
}

-- Données de navigation par base
-- { fieldModel, basePos, spawnPos }
local WAYPOINTS = {}
-- Position du ChampCommun (partagé entre tous les bots)
local champCommunPos = nil

-- Génère un point aléatoire sur le sol d'un Model (en utilisant sa bounding box)
local function pointAleatoireDansModel(model)
    local cf, size = model:GetBoundingBox()
    local dx = (math.random() - 0.5) * size.X * 0.8
    local dz = (math.random() - 0.5) * size.Z * 0.8
    return cf.Position + Vector3.new(dx, BOT_CONFIG.hauteurPerso - size.Y / 2, dz)
end

-- Lit workspace.Bases et workspace.ChampCommun pour calculer les positions de navigation
local function calculerWaypoints()
    local basesFolder = workspace:FindFirstChild("Bases")
    if not basesFolder then
        Logger.warn("Bot", "workspace.Bases introuvable — bots désactivés")
        return false
    end

    -- ChampCommun : position centrale pour les visites occasionnelles
    -- (peut être un Folder ou un Model — on cherche la première BasePart descendante)
    local champContainer = workspace:FindFirstChild("ChampCommun")
    if champContainer then
        local premierePart = champContainer:FindFirstChildOfClass("BasePart", true)
        if premierePart then
            champCommunPos = premierePart.Position + Vector3.new(0, BOT_CONFIG.hauteurPerso, 0)
        end
    end

    for i = 1, 6 do
        local baseId    = "Base_" .. i
        local baseModel = basesFolder:FindFirstChild(baseId)
        if not baseModel then continue end

        -- Field : modèle stocké pour générer des points aléatoires à chaque cycle
        local specificFolder = baseModel:FindFirstChild("Specific")
        local fieldModel     = specificFolder and specificFolder:FindFirstChild("Field")

        -- Base (deposit) : Shared/Base modèle — pivot au centre des slots
        local sharedFolder = baseModel:FindFirstChild("Shared")
        local baseContainer = sharedFolder and sharedFolder:FindFirstChild("Base")
        local basePos
        if baseContainer then
            basePos = baseContainer:GetPivot().Position + Vector3.new(0, BOT_CONFIG.hauteurPerso, 0)
        end

        -- Spawn : SpawnLocation dans Shared — point de départ du bot
        local spawnLoc = sharedFolder and sharedFolder:FindFirstChild("SpawnLocation")
        local spawnPos = spawnLoc and (spawnLoc.Position + Vector3.new(0, BOT_CONFIG.hauteurPerso, 0))

        if fieldModel and basePos and spawnPos then
            WAYPOINTS[baseId] = { fieldModel = fieldModel, base = basePos, spawn = spawnPos }
            Logger.debug("Bot", "Base_%d — base=(%.0f,%.0f,%.0f) spawn=(%.0f,%.0f,%.0f)", i, basePos.X, basePos.Y, basePos.Z, spawnPos.X, spawnPos.Y, spawnPos.Z)
        else
            Logger.warn("Bot", "Waypoints incomplets pour %s (Field=%s Base=%s Spawn=%s)", baseId, tostring(fieldModel ~= nil), tostring(basePos ~= nil), tostring(spawnPos ~= nil))
        end
    end

    return next(WAYPOINTS) ~= nil
end

-- Table des bots actifs : baseId → { rig, nomBot, actif, coins, totalCollecte }
local botsActifs = {}

-- Coins fictifs gagnés par cycle (simule une progression crédible)
local COINS_PAR_CYCLE_MIN = 80
local COINS_PAR_CYCLE_MAX = 350

-- IDs des animations R6 par défaut (Roblox)
local ANIM_IDS = {
    marche = "rbxassetid://180426354",
    idle   = "rbxassetid://180435571",
}

-- Créer un personnage Dummy depuis ServerStorage.BotDummy
local function creerDummy(nomBot, spawnPosition)
    local modele = ServerStorage:FindFirstChild("BotDummy")
    if not modele then
        Logger.warn("Bot", "ServerStorage.BotDummy introuvable — bots désactivés")
        return nil
    end

    local dummy = modele:Clone()
    dummy.Name = "Bot_" .. nomBot

    -- Désactiver les collisions sans ancrer (la physique gère le mouvement)
    for _, part in ipairs(dummy:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end

    -- Humanoid : vitesse + désactiver la mort
    local humanoid = dummy:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.WalkSpeed    = BOT_CONFIG.vitesseDeplacement
        humanoid.MaxHealth    = math.huge
        humanoid.Health       = math.huge
        humanoid.DisplayName  = nomBot
        humanoid.NameDisplayDistance = 40
    end

    dummy:PivotTo(CFrame.new(spawnPosition))
    dummy.Parent = workspace

    -- Ownership serveur après ajout au Workspace (API exige un descendant de Workspace)
    local hrp = dummy:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp:SetNetworkOwner(nil)
    end

    -- Appliquer le skin d'un vrai joueur Roblox (async, ne bloque pas le spawn)
    if humanoid and #BOT_CONFIG.userIds > 0 then
        local userId = BOT_CONFIG.userIds[math.random(1, #BOT_CONFIG.userIds)]
        task.spawn(function()
            local ok, description = pcall(function()
                return Players:GetHumanoidDescriptionFromUserId(userId)
            end)
            if ok and description and dummy.Parent then
                pcall(function()
                    humanoid:ApplyDescription(description)
                end)
            end
        end)
    end

    -- Charger les animations (côté serveur via Animator)
    local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = humanoid
    end

    local trackMarche, trackIdle
    local animMarche = Instance.new("Animation")
    animMarche.AnimationId = ANIM_IDS.marche
    trackMarche = animator:LoadAnimation(animMarche)
    trackMarche.Priority = Enum.AnimationPriority.Movement

    local animIdle = Instance.new("Animation")
    animIdle.AnimationId = ANIM_IDS.idle
    trackIdle = animator:LoadAnimation(animIdle)
    trackIdle.Priority = Enum.AnimationPriority.Idle
    trackIdle:Play()

    -- Retourner le dummy et les tracks (stockés dans botsActifs, pas sur l'Instance)
    return dummy, trackMarche, trackIdle
end

-- Déplacer le dummy vers une position cible via Humanoid:MoveTo()
local function deplacerVers(dummy, cible, trackMarche, trackIdle)
    if not dummy or not dummy.Parent then return end

    local humanoid = dummy:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    -- Basculer sur l'animation de marche
    if trackIdle   then trackIdle:Stop() end
    if trackMarche then trackMarche:Play() end

    humanoid:MoveTo(cible)

    -- Attendre l'arrivée (timeout = distance / vitesse + 2s de marge)
    local hrp      = dummy:FindFirstChild("HumanoidRootPart")
    local distance = hrp and (hrp.Position - cible).Magnitude or 0
    local timeout  = (distance / BOT_CONFIG.vitesseDeplacement) + 2

    local arrived = false
    local conn = humanoid.MoveToFinished:Connect(function()
        arrived = true
    end)
    local t = 0
    while not arrived and t < timeout do
        t += task.wait(0.1)
    end
    conn:Disconnect()

    -- Repasser en idle à l'arrivée
    if trackMarche then trackMarche:Stop() end
    if trackIdle   then trackIdle:Play() end
end

-- Boucle principale d'un bot sur une base donnée
local function boucleBot(baseId, nomBot, spawnPos)
    local waypoints = WAYPOINTS[baseId]
    if not waypoints then
        Logger.warn("Bot", "Pas de waypoints pour %s", tostring(baseId))
        return
    end

    local dummy, trackMarche, trackIdle = creerDummy(nomBot, spawnPos)
    if not dummy then return end

    -- Coins de départ aléatoires pour éviter que tous les bots démarrent à 0
    local coinsDepart = math.random(500, 8000)
    botsActifs[baseId] = {
        rig          = dummy,
        nom          = nomBot,
        actif        = true,
        coins        = coinsDepart,
        totalCollecte = coinsDepart,
    }

    while botsActifs[baseId] and botsActifs[baseId].actif do
        -- Phase 1 : aller à un point aléatoire dans le field (20% chance : ChampCommun)
        local destination
        if champCommunPos and math.random(1, 5) == 1 then
            destination = champCommunPos + Vector3.new(
                math.random(-15, 15), 0, math.random(-15, 15)
            )
        else
            destination = pointAleatoireDansModel(waypoints.fieldModel)
        end
        deplacerVers(dummy, destination, trackMarche, trackIdle)
        task.wait(math.random(1, 3)) -- simulation ramassage

        -- Optionnel : 2ème point dans le field avant de rentrer
        if math.random(1, 2) == 1 then
            deplacerVers(dummy, pointAleatoireDansModel(waypoints.fieldModel), trackMarche, trackIdle)
            task.wait(math.random(1, 2))
        end

        -- Phase 2 : retour à la base (deposit)
        deplacerVers(dummy, waypoints.base, trackMarche, trackIdle)
        task.wait(math.random(1, 2)) -- simulation dépôt

        -- Gains fictifs de ce cycle
        local gains = math.random(COINS_PAR_CYCLE_MIN, COINS_PAR_CYCLE_MAX)
        if botsActifs[baseId] then
            botsActifs[baseId].coins         = botsActifs[baseId].coins + gains
            botsActifs[baseId].totalCollecte = botsActifs[baseId].totalCollecte + gains
        end

        -- Phase 3 : attendre avant prochain cycle
        task.wait(math.random(BOT_CONFIG.cycleMin, BOT_CONFIG.cycleMax))

        if not botsActifs[baseId] or not botsActifs[baseId].actif then
            break
        end
    end

    -- Nettoyage
    if dummy and dummy.Parent then
        dummy:Destroy()
    end
end

-- Détermine quelles bases sont occupées par de vrais joueurs
local function getBasesOccupees()
    local occupees = {}
    for _, joueur in ipairs(Players:GetPlayers()) do
        -- Cherche l'attribut "BaseAssignee" ou la folder structure
        -- Adapte selon ton AssignationSystem
        local baseId = joueur:GetAttribute("BaseAssignee")
        if baseId then
            occupees[baseId] = true
        end
    end
    return occupees
end

-- Spawner des bots sur les bases vides
local function mettreAJourBots()
    local nbJoueursReels = #Players:GetPlayers()

    -- Pas besoin de bots si assez de joueurs
    if nbJoueursReels >= BOT_CONFIG.seuilJoueursReels then
        -- Tuer tous les bots actifs
        for baseId, botData in pairs(botsActifs) do
            botData.actif = false
            botsActifs[baseId] = nil
        end
        return
    end

    local basesOccupees = getBasesOccupees()

    for baseId, waypoints in pairs(WAYPOINTS) do
        local baseOccupee = basesOccupees[baseId]
        local botExistant = botsActifs[baseId]

        if not baseOccupee and not botExistant then
            -- Spawner un bot sur cette base vide (spawn au SpawnLocation)
            local nomAleatoire = BOT_CONFIG.noms[math.random(1, #BOT_CONFIG.noms)]
            local spawnPos = waypoints.spawn

            task.spawn(function()
                boucleBot(baseId, nomAleatoire, spawnPos)
            end)

        elseif baseOccupee and botExistant then
            -- Un vrai joueur a pris cette base → tuer le bot
            botExistant.actif = false
            botsActifs[baseId] = nil
        end
    end
end

-- Démarrage du système
task.wait(BOT_CONFIG.delaiDemarrage)

-- Calcul des waypoints depuis workspace.Bases (map déjà chargée à ce stade)
local waypointsOk = calculerWaypoints()
if not waypointsOk then
    Logger.warn("Bot", "Aucun waypoint calculé — système désactivé")
    return true
end

-- Vérification périodique (toutes les 15 secondes)
task.spawn(function()
    while true do
        mettreAJourBots()
        task.wait(15)
    end
end)

-- Réagir aux arrivées/départs de joueurs
Players.PlayerAdded:Connect(function()
    task.wait(3) -- attendre l'assignation de base
    mettreAJourBots()
end)

Players.PlayerRemoving:Connect(function()
    task.wait(1)
    mettreAJourBots()
end)

Logger.info("Bot", "Systeme de bots demarre")

return true