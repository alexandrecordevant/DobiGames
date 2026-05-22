-- ServerScriptService/Systems/FlowerPotSystem/FlowerPotGrowthSystem.lua
-- DobiGames BrainRotFarm — Séquence de croissance des FlowerPots
-- GenericSeed → Plant_Stage0-3 → BR Mutant élémentaire
-- 8 minutes total (2 min par stage × 4 stages)
-- Stage 2 : BR Mutant spawn au-dessus (Y+3)
-- Fin Stage 3 : plante meurt, BR Mutant tombe sur le pot

local FlowerPotGrowthSystem = {}

-- ============================================================
-- Services
-- ============================================================
local ServerStorage       = game:GetService("ServerStorage")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace           = game:GetService("Workspace")
local TweenService        = game:GetService("TweenService")

-- ============================================================
-- Config
-- ============================================================
local Logger  = require(game:GetService("ServerScriptService").SharedLib.Server.Logger)
local Config  = require(ReplicatedStorage.GameConfig)
local FPConfig = Config.FlowerPotConfig

-- ============================================================
-- Lazy loader CarrySystem (éviter dépendances circulaires)
-- ============================================================
local _CarrySystem = nil
local function getCarrySystem()
    if not _CarrySystem then
        local ok, m = pcall(require,
            ServerScriptService.SharedLib.Server.CarrySystem)
        if ok and m then _CarrySystem = m end
    end
    return _CarrySystem
end

-- Lazy loader FlowerPotPickupHandler
local _PickupHandler = nil
local function getPickupHandler()
    if not _PickupHandler then
        local ok, m = pcall(require,
            ServerScriptService.Systems.FlowerPotSystem.FlowerPotPickupHandler)
        if ok and m then _PickupHandler = m end
    end
    return _PickupHandler
end

-- Lazy loader BrainrotBillboard (billboard uniformisé)
local _BRBillboard = nil
local function getBRBillboard()
    if not _BRBillboard then
        local ok, m = pcall(require,
            ServerScriptService.SharedLib.Server.BrainrotBillboard)
        if ok and m then _BRBillboard = m end
    end
    return _BRBillboard
end

-- Lazy loader FilterManager (effets visuels élémentaires centralisés)
local _FilterManager = nil
local function getFilterManager()
    if not _FilterManager then
        local ok, m = pcall(function()
            return require(ServerScriptService:WaitForChild("SharedLib")
                :WaitForChild("BRFilterSystem")
                :WaitForChild("FilterManager"))
        end)
        if ok and m then _FilterManager = m end
    end
    return _FilterManager
end

-- ============================================================
-- Constantes (lues depuis GameConfig si disponibles)
-- ============================================================

-- Durée par stage en secondes (2 min par défaut)
local DUREE_PAR_STAGE   = (FPConfig and FPConfig.GrowthDuration)   or 120
-- Stage à partir duquel le BR Mutant apparaît au-dessus
local MUTANT_SPAWN_STAGE = (FPConfig and FPConfig.MutantSpawnStage) or 2
-- Offset Y au-dessus du sommet de la plante (studs)
local MUTANT_OFFSET_Y   = (FPConfig and FPConfig.MutantOffsetY)    or 0.5

-- Types Mutants disponibles (lus depuis GameConfig.MutantTypes — source de vérité canonique)
local ELEMENTS = {}
local ELEMENT_MULTIPLIERS = {}
local ELEMENT_TO_FILTRE   = {}
local ELEMENT_EMOJIS      = {}
local ELEMENT_MIN_REBIRTH = {}

for _, mt in ipairs(Config.MutantTypes) do
    table.insert(ELEMENTS, mt.Name)
    ELEMENT_MULTIPLIERS[mt.Name] = mt.Multiplier
    ELEMENT_TO_FILTRE[mt.Name]   = mt.Filtre
    ELEMENT_EMOJIS[mt.Name]      = mt.Emoji
    ELEMENT_MIN_REBIRTH[mt.Name] = mt.MinRebirth or 0
end

-- ============================================================
-- État interne
-- ============================================================

-- Threads de croissance actifs [potId] = thread
local _threads = {}

-- BR Mutants actifs [potId] = { clone=Instance, elementType=string }
local _mutants = {}

-- Données de plantation actives [potId] = { rarity=string, stage=number }
local _plantages = {}

-- ============================================================
-- Utilitaires internes
-- ============================================================

-- Retourne le BasePart principal d'un pot (Model ou BasePart)
local function getPotPart(potModel)
    if potModel:IsA("BasePart") then return potModel end
    return potModel:FindFirstChildWhichIsA("BasePart")
end

-- Retourne la position de surface supérieure du pot (Y + moitié hauteur)
local function getSurfacePot(potPart)
    return potPart.Position + Vector3.new(0, potPart.Size.Y / 2, 0)
end

-- Retourne la position Y du sommet d'un modèle de plante (bounding box)
local function getSommetPlante(clone, potPart)
    if clone then
        if clone:IsA("Model") then
            local ok, cf, size = pcall(function()
                return clone:GetBoundingBox()
            end)
            if ok and cf and size then
                return cf.Position.Y + size.Y / 2
            end
        elseif clone:IsA("BasePart") then
            return clone.Position.Y + clone.Size.Y / 2
        end
    end
    -- Fallback : surface du pot
    return getSurfacePot(potPart).Y
end

-- Ancre toutes les parts d'un clone (évite la physique)
local function ancrerClone(clone)
    if clone:IsA("BasePart") then
        pcall(function()
            clone.Anchored   = true
            clone.CanCollide = false
            clone.CanTouch   = false
        end)
    end
    for _, part in ipairs(clone:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function()
                part.Anchored   = true
                part.CanCollide = false
                part.CanTouch   = false
            end)
        end
    end
end

-- Positionne un clone (Model ou BasePart) à une position donnée
local function positionnerClone(clone, position)
    local ok = false
    if clone:IsA("Model") then
        ok = pcall(function() clone:PivotTo(CFrame.new(position)) end)
    else
        ok = pcall(function() clone.CFrame = CFrame.new(position) end)
    end
    return ok
end

-- Retourne la CFrame pivot actuelle d'un clone
local function getPivot(clone)
    if clone:IsA("Model") then
        local ok, cf = pcall(function() return clone:GetPivot() end)
        if ok and cf then return cf end
    end
    if clone:IsA("BasePart") then return clone.CFrame end
    return CFrame.new(0, 0, 0)
end

-- ============================================================
-- Animation de chute (startPos → endPos) via PivotTo loop
-- Fonctionne pour Model et BasePart avec parts ancrées
-- ============================================================
local function animerChute(clone, positionCible, duree)
    duree = duree or 0.8
    local startCFrame = getPivot(clone)
    local endCFrame   = CFrame.new(positionCible)
    local steps       = math.max(1, math.floor(duree * 30))  -- ~30 fps
    local dt          = duree / steps

    for i = 1, steps do
        if not clone.Parent then break end

        local alpha = i / steps
        -- Ease Out Bounce simplifié (rebond léger)
        local eased = 1 - math.pow(1 - alpha, 3)
        local currentCFrame = startCFrame:Lerp(endCFrame, eased)

        if clone:IsA("Model") then
            pcall(function() clone:PivotTo(currentCFrame) end)
        else
            pcall(function() clone.CFrame = currentCFrame end)
        end

        task.wait(dt)
    end

    -- Garantir position finale exacte
    if clone.Parent then
        positionnerClone(clone, positionCible)
    end
end

-- ============================================================
-- Clonage assets ServerStorage
-- ============================================================

-- Clone GenericSeed depuis ServerStorage/Seeds/
local function clonerGraine(potPart)
    local dossierGraines = ServerStorage:FindFirstChild("Seeds")
    if not dossierGraines then
        Logger.warn("Pot", "ServerStorage/Seeds introuvable — créer le dossier dans Studio")
        return nil
    end

    local src = dossierGraines:FindFirstChild("GenericSeed")
    if not src then
        Logger.warn("Pot", "GenericSeed introuvable dans Seeds/ — créer le modèle dans Studio")
        return nil
    end

    local clone = nil
    local ok = pcall(function() clone = src:Clone() end)
    if not ok or not clone then
        Logger.warn("Pot", "Échec clone GenericSeed")
        return nil
    end

    ancrerClone(clone)
    positionnerClone(clone, getSurfacePot(potPart))
    clone.Parent = Workspace
    return clone
end

-- Clone Plant_StageX depuis ServerStorage/Plants/
local function clonerPlantStage(stageIndex, potPart)
    local dossierPlants = ServerStorage:FindFirstChild("Plants")
    if not dossierPlants then
        Logger.warn("Pot", "ServerStorage/Plants introuvable — créer le dossier dans Studio")
        return nil
    end

    local nomStage = "Plant_Stage" .. stageIndex
    local src = dossierPlants:FindFirstChild(nomStage)
    if not src then
        Logger.warn("Pot", "Modèle introuvable : %s — créer dans Studio", nomStage)
        return nil
    end

    local clone = nil
    local ok = pcall(function() clone = src:Clone() end)
    if not ok or not clone then
        Logger.warn("Pot", "Échec clone : %s", nomStage)
        return nil
    end

    ancrerClone(clone)
    positionnerClone(clone, getSurfacePot(potPart))
    clone.Name   = "FlowerPotPlant"
    clone.Parent = Workspace
    return clone
end

-- Clone un BR Mutant depuis ServerStorage/Brainrots/MYTHIC/ ou /SECRET/
-- nomModele optionnel : réutilise le même modèle (persistance rejoin)
-- Retourne (clone, nomChoisi) ou (nil, nil)
local function clonerBRMutant(seedRarity, nomModele)
    local brainrots = ServerStorage:FindFirstChild("Brainrots")
    if not brainrots then
        Logger.warn("Pot", "ServerStorage/Brainrots introuvable")
        return nil, nil
    end

    local dossier = brainrots:FindFirstChild(seedRarity)
    if not dossier then
        Logger.warn("Pot", "Dossier rareté introuvable : %s", seedRarity)
        return nil, nil
    end

    -- Construit un pool plat en incluant les modèles dans les sous-dossiers numérotés
    local pool = {}
    for _, enfant in ipairs(dossier:GetChildren()) do
        if enfant:IsA("Folder") and tonumber(enfant.Name) then
            for _, m in ipairs(enfant:GetChildren()) do table.insert(pool, m) end
        else
            table.insert(pool, enfant)
        end
    end
    if #pool == 0 then
        Logger.warn("Pot", "Aucun modèle dans : %s", seedRarity)
        return nil, nil
    end

    -- Cherche le modèle exact (direct ou dans un sous-dossier numéroté)
    local src = nil
    if nomModele then
        src = dossier:FindFirstChild(nomModele)
        if not src then
            for _, sub in ipairs(dossier:GetChildren()) do
                if sub:IsA("Folder") and tonumber(sub.Name) then
                    src = sub:FindFirstChild(nomModele)
                    if src then break end
                end
            end
        end
    end
    if not src then
        src = pool[math.random(1, #pool)]
    end

    local clone = nil
    local ok = pcall(function() clone = src:Clone() end)
    if not ok or not clone then
        Logger.warn("Pot", "Échec clone BR Mutant depuis : %s", seedRarity)
        return nil, nil
    end

    -- Attribut pour restauration fidèle par DropSystem
    pcall(function() clone:SetAttribute("OriginalName", src.Name) end)

    ancrerClone(clone)
    return clone, src.Name
end

-- ============================================================
-- Effets visuels sur le BR Mutant
-- ============================================================

-- Applique les effets visuels élémentaires via FilterManager (shared-lib)
local function appliquerParticulesElement(clone, elementType)
    local FM = getFilterManager()
    if not FM then
        Logger.warn("Pot", "FilterManager indisponible — effets ignorés pour : %s", elementType)
        return
    end
    local nomFiltre = ELEMENT_TO_FILTRE[elementType]
    if not nomFiltre then
        Logger.warn("Pot", "Élément inconnu : %s", elementType)
        return
    end
    FM.Apply(clone, { { Name = nomFiltre } })

    -- Billboard uniformisé (même format que le dépôt en base)
    local BB = getBRBillboard()
    if BB then pcall(BB.SetupBase, clone) end
end

-- Burst de particules au moment de la chute (feedback visuel)
local function burstParticulesChute(clone)
    local root = nil
    if clone:IsA("Model") then
        root = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart")
    elseif clone:IsA("BasePart") then
        root = clone
    end
    if not root then return end

    local emitter = root:FindFirstChild("ElementParticles")
    if emitter then
        -- Burst temporaire : 3× le taux normal pendant 0.5s
        pcall(function()
            emitter.Rate = emitter.Rate * 3
            task.delay(0.5, function()
                if emitter.Parent then
                    emitter.Rate = emitter.Rate / 3
                end
            end)
        end)
    end
end

-- ============================================================
-- Nettoyage d'un pot (thread + mutant)
-- ============================================================
local function nettoyerPot(potId)
    -- Annuler thread de croissance
    if _threads[potId] then
        pcall(function() task.cancel(_threads[potId]) end)
        _threads[potId] = nil
    end

    -- Détruire le BR Mutant visible s'il existe
    local mutantData = _mutants[potId]
    if mutantData and mutantData.clone and mutantData.clone.Parent then
        pcall(function() mutantData.clone:Destroy() end)
    end
    _mutants[potId]  = nil
    _plantages[potId] = nil
end

-- ============================================================
-- PlantSeed — lance la séquence complète de croissance
-- ============================================================
--[[
    @param potModel   (Instance) — Model FlowerPot dans Workspace
    @param seedRarity (string)  — "MYTHIC", "SECRET" ou "RARE"
    @param player     (Player)  — propriétaire du pot (validation carry)
    @param onHarvest  (function, optionnel) — callback après récolte réussie
                      signature: onHarvest(player, elementType, multiplier)
]]
function FlowerPotGrowthSystem.PlantSeed(potModel, seedRarity, player, onHarvest, resumeOptions)
    -- Validation des paramètres
    if not potModel or not potModel.Parent then
        Logger.warn("Pot", "potModel invalide")
        return
    end
    if seedRarity ~= "MYTHIC" and seedRarity ~= "SECRET" and seedRarity ~= "RARE" then
        Logger.warn("Pot", "seedRarity invalide (doit être MYTHIC, SECRET ou RARE) : %s", seedRarity)
        return
    end

    local potPart = getPotPart(potModel)
    if not potPart then
        Logger.warn("Pot", "Pas de BasePart dans : %s", potModel.Name)
        return
    end

    -- Identifiant unique du pot (chemin complet dans Workspace)
    local potId = potModel:GetFullName()

    -- Annuler toute croissance précédente sur ce pot
    nettoyerPot(potId)

    -- Mémoriser rareté et stage courant (exposé via GetStatut)
    _plantages[potId] = { rarity = seedRarity, stage = -1 }

    -- Choisir élément (réutiliser si reprise, sinon aléatoire parmi ceux débloqués par le rebirth)
    local function getElementsDisponibles()
        local rebirthLevel = 0
        if FlowerPotGrowthSystem.GetPlayerData and player then
            local pd = FlowerPotGrowthSystem.GetPlayerData(player)
            rebirthLevel = (pd and pd.rebirthLevel) or 0
        end
        local dispo = {}
        for _, nom in ipairs(ELEMENTS) do
            if (ELEMENT_MIN_REBIRTH[nom] or 0) <= rebirthLevel then
                table.insert(dispo, nom)
            end
        end
        return #dispo > 0 and dispo or ELEMENTS
    end

    local elementType = (resumeOptions and resumeOptions.elementType)
        or (function() local d = getElementsDisponibles() return d[math.random(1, #d)] end)()
    local multiplier  = ELEMENT_MULTIPLIERS[elementType] or 2
    local emoji       = ELEMENT_EMOJIS[elementType] or "✨"

    -- Notifier l'appelant de l'élément choisi (pour persistance DataStore)
    if resumeOptions and resumeOptions.onElementChosen then
        pcall(resumeOptions.onElementChosen, elementType)
    end

    Logger.info("Pot", "Début croissance | Pot: %s | Graine: %s | Élément: %s %s | ×%d", potModel.Name, seedRarity, elementType, emoji, multiplier)

    -- Étape courante pour la reprise (0=GenericSeed, 1-4=Plant_StageX, 5=terminé)
    local etapeCourante   = (resumeOptions and resumeOptions.etapeCourante) or 0
    local premiereAttente = (resumeOptions and resumeOptions.premiereAttente) or DUREE_PAR_STAGE
    -- Nom du modèle mutant sauvegardé (nil = choix aléatoire)
    local brNomSauvegarde = resumeOptions and resumeOptions.brNom

    -- Notifie l'appelant du nom choisi (une seule fois par PlantSeed)
    local _brNomNotifie = false
    local function notifierBRNom(nom)
        if _brNomNotifie or not nom then return end
        _brNomNotifie = true
        if resumeOptions and resumeOptions.onBRNomChosen then
            pcall(resumeOptions.onBRNomChosen, nom)
        end
    end

    -- ══════════════════════════════════════════════════════
    -- Thread principal de croissance
    -- ══════════════════════════════════════════════════════
    _threads[potId] = task.spawn(function()
        local plantActuel = nil   -- modèle plant visible dans le Workspace
        local mutantClone = nil   -- BR Mutant spawné au stage 2

        -- ────────────────────────────────────────────────
        -- CAS REPRISE TERMINÉE : spawn mutant directement
        -- ────────────────────────────────────────────────
        if etapeCourante >= 5 then
            local brNomChoisi
            mutantClone, brNomChoisi = clonerBRMutant(seedRarity, brNomSauvegarde)
            notifierBRNom(brNomChoisi)
            if mutantClone then
                local posSurPot = getSurfacePot(potPart) + Vector3.new(0, 0.5, 0)
                positionnerClone(mutantClone, posSurPot)
                pcall(function()
                    mutantClone:SetAttribute("IsMutant",    true)
                    mutantClone:SetAttribute("MutantType",  elementType)
                    mutantClone:SetAttribute("Rarity",      seedRarity)
                    mutantClone:SetAttribute("Rarete",      seedRarity)
                    mutantClone:SetAttribute("Multiplier",  multiplier)
                end)
                appliquerParticulesElement(mutantClone, elementType)
                mutantClone.Parent = Workspace
                _mutants[potId] = {
                    clone       = mutantClone,
                    elementType = elementType,
                    seedRarity  = seedRarity,
                    multiplier  = multiplier,
                }
                local PH = getPickupHandler()
                if PH then
                    PH.Setup(mutantClone, potModel, player, {
                        elementType = elementType,
                        seedRarity  = seedRarity,
                        multiplier  = multiplier,
                        emoji       = emoji,
                        potId       = potId,
                        onHarvest   = onHarvest,
                    })
                end
            else
                -- Échec spawn mutant au rejoin (assets manquants, erreur) → reset auto du pot
                Logger.warn("Pot", "Échec spawn mutant (etape>=5) pour %s — reset auto", potModel.Name)
                if onHarvest then pcall(onHarvest, player, elementType, multiplier) end
            end
            _threads[potId] = nil
            return
        end

        -- ────────────────────────────────────────────────
        -- AFFICHAGE IMMÉDIAT selon l'étape courante
        -- ────────────────────────────────────────────────
        if etapeCourante == 0 then
            -- Départ normal : GenericSeed
            local graine = clonerGraine(potPart)
            if graine then
                plantActuel = graine
                Logger.debug("Pot", "%s → GenericSeed affiché", potModel.Name)
            end
        else
            -- Reprise : afficher le stage déjà atteint
            local stageAffiche = etapeCourante - 1  -- 0 à 3
            plantActuel = clonerPlantStage(stageAffiche, potPart)
            if _plantages[potId] then _plantages[potId].stage = stageAffiche end
            Logger.debug("Pot", "%s → Plant_Stage%d (reprise étape %d)", potModel.Name, stageAffiche, etapeCourante)

            -- Si le mutant aurait déjà dû spawner (stage >= MUTANT_SPAWN_STAGE)
            if stageAffiche >= MUTANT_SPAWN_STAGE then
                local brNomChoisi
                mutantClone, brNomChoisi = clonerBRMutant(seedRarity, brNomSauvegarde)
                notifierBRNom(brNomChoisi)
                if mutantClone then
                    local sommetY = getSommetPlante(plantActuel, potPart)
                    local surfacePot = getSurfacePot(potPart)
                    local posAuDessus = Vector3.new(surfacePot.X, sommetY + MUTANT_OFFSET_Y, surfacePot.Z)
                    positionnerClone(mutantClone, posAuDessus)
                    pcall(function()
                        mutantClone:SetAttribute("IsMutant",    true)
                        mutantClone:SetAttribute("MutantType",  elementType)
                        mutantClone:SetAttribute("Rarity",      seedRarity)
                    mutantClone:SetAttribute("Rarete",      seedRarity)
                        mutantClone:SetAttribute("Multiplier",  multiplier)
                    end)
                    appliquerParticulesElement(mutantClone, elementType)
                    mutantClone.Parent = Workspace
                    _mutants[potId] = {
                        clone       = mutantClone,
                        elementType = elementType,
                        seedRarity  = seedRarity,
                        multiplier  = multiplier,
                    }
                end
            end
        end

        -- ────────────────────────────────────────────────
        -- STAGES (loop depuis etapeCourante jusqu'à 3)
        -- ────────────────────────────────────────────────
        for stage = etapeCourante, 3 do
            -- Attente réduite pour le premier stage lors d'une reprise
            local attente = (stage == etapeCourante) and premiereAttente or DUREE_PAR_STAGE
            task.wait(attente)

            -- Vérifier validité du pot (peut être détruit si joueur quitte)
            if not potModel or not potModel.Parent then
                Logger.debug("Pot", "Pot détruit — croissance annulée : %s", potId)
                break
            end

            -- ─── Remplacer visuel par Plant_StageX ───
            if plantActuel and plantActuel.Parent then
                pcall(function() plantActuel:Destroy() end)
                plantActuel = nil
            end

            local nouveauPlant = clonerPlantStage(stage, potPart)
            plantActuel = nouveauPlant

            -- Mettre à jour le stage courant (visible via GetStatut)
            if _plantages[potId] then _plantages[potId].stage = stage end

            Logger.debug("Pot", "%s → Plant_Stage%d", potModel.Name, stage)

            -- ─── STAGE 2 : Spawn BR Mutant au-dessus (seulement si pas déjà spawné) ───
            if stage == MUTANT_SPAWN_STAGE and not mutantClone then
                local brNomChoisi
                mutantClone, brNomChoisi = clonerBRMutant(seedRarity, brNomSauvegarde)
                notifierBRNom(brNomChoisi)

                if mutantClone then
                    -- Position au-dessus du sommet de la plante courante
                    local sommetY = getSommetPlante(plantActuel, potPart)
                    local surfacePot = getSurfacePot(potPart)
                    local posAuDessus = Vector3.new(surfacePot.X, sommetY + MUTANT_OFFSET_Y, surfacePot.Z)

                    positionnerClone(mutantClone, posAuDessus)

                    -- Attributs élémentaires (serveur uniquement)
                    pcall(function()
                        mutantClone:SetAttribute("IsMutant",    true)
                        mutantClone:SetAttribute("MutantType",  elementType)
                        mutantClone:SetAttribute("Rarity",      seedRarity)
                    mutantClone:SetAttribute("Rarete",      seedRarity)
                        mutantClone:SetAttribute("Multiplier",  multiplier)
                    end)

                    -- Particules élémentaires
                    appliquerParticulesElement(mutantClone, elementType)

                    mutantClone.Parent = Workspace

                    -- Mémoriser l'état du mutant
                    _mutants[potId] = {
                        clone       = mutantClone,
                        elementType = elementType,
                        seedRarity  = seedRarity,
                        multiplier  = multiplier,
                    }

                    Logger.info("Pot", "BR Mutant %s spawné à Y+%d | %s | Pot: %s", seedRarity, MUTANT_OFFSET_Y, elementType, potModel.Name)
                else
                    Logger.warn("Pot", "Échec spawn BR Mutant — vérifier ServerStorage/Brainrots/%s", seedRarity)
                end
            end
        end

        -- ────────────────────────────────────────────────
        -- FIN DU DERNIER STAGE : Plante meurt
        -- ────────────────────────────────────────────────
        -- Attente réduite si reprise à l'étape finale (etapeCourante=4)
        local attenteFinal = (etapeCourante == 4) and premiereAttente or DUREE_PAR_STAGE
        task.wait(attenteFinal)

        -- Détruire la plante (fondu vers invisible puis destroy)
        if plantActuel and plantActuel.Parent then
            -- Fade out rapide avant destruction
            for _, part in ipairs(plantActuel:GetDescendants()) do
                if part:IsA("BasePart") then
                    pcall(function()
                        TweenService:Create(part,
                            TweenInfo.new(0.4, Enum.EasingStyle.Quad),
                            { Transparency = 1 }):Play()
                    end)
                end
            end
            if plantActuel:IsA("BasePart") then
                pcall(function()
                    TweenService:Create(plantActuel,
                        TweenInfo.new(0.4, Enum.EasingStyle.Quad),
                        { Transparency = 1 }):Play()
                end)
            end
            task.wait(0.5)
            pcall(function() plantActuel:Destroy() end)
            plantActuel = nil
        end

        Logger.debug("Pot", "%s → Plante morte", potModel.Name)

        -- ────────────────────────────────────────────────
        -- CHUTE : BR Mutant tombe sur le pot
        -- ────────────────────────────────────────────────
        if not mutantClone or not mutantClone.Parent then
            Logger.warn("Pot", "BR Mutant introuvable à la fin de croissance : %s — reset auto", potId)
            if onHarvest then pcall(onHarvest, player, elementType, multiplier) end
            _threads[potId] = nil
            return
        end

        -- Position finale : surface du pot
        local posSurPot = getSurfacePot(potPart) + Vector3.new(0, 0.5, 0)

        -- Burst visuel au moment de la chute
        burstParticulesChute(mutantClone)

        -- Animation de chute
        animerChute(mutantClone, posSurPot, 0.8)

        Logger.info("Pot", "BR Mutant tombé sur %s — élément: %s | ×%d", potModel.Name, elementType, multiplier)

        -- ────────────────────────────────────────────────
        -- PICKUP : Déléguer au FlowerPotPickupHandler
        -- ────────────────────────────────────────────────
        if mutantClone.Parent then
            local PH = getPickupHandler()
            if PH then
                PH.Setup(mutantClone, potModel, player, {
                    elementType = elementType,
                    seedRarity  = seedRarity,
                    multiplier  = multiplier,
                    emoji       = emoji,
                    potId       = potId,
                    onHarvest   = onHarvest,
                })
            else
                Logger.warn("Pot", "FlowerPotPickupHandler indisponible — BR Mutant non récoltable")
            end
        end

        _threads[potId] = nil
    end)
end

-- ============================================================
-- Annuler — stoppe la croissance et nettoie les visuels
-- ============================================================
--[[
    @param potModel (Instance) — le Model FlowerPot
]]
function FlowerPotGrowthSystem.Annuler(potModel)
    if not potModel then return end
    local potId = potModel:GetFullName()
    nettoyerPot(potId)
    Logger.debug("Pot", "Croissance annulée : %s", potModel.Name)
end

-- ============================================================
-- Accesseurs de config (utilisés par FlowerPotPickupHandler et tests)
-- ============================================================

function FlowerPotGrowthSystem.GetElements()
    return ELEMENTS
end

function FlowerPotGrowthSystem.GetElementMultipliers()
    return ELEMENT_MULTIPLIERS
end

function FlowerPotGrowthSystem.GetElementEmojis()
    return ELEMENT_EMOJIS
end

function FlowerPotGrowthSystem.GetElementParticles()
    return ELEMENT_PARTICLES
end

-- Retourne true si une croissance est en cours sur ce pot
function FlowerPotGrowthSystem.EstEnCroissance(potModel)
    if not potModel then return false end
    return _threads[potModel:GetFullName()] ~= nil
end

-- Retourne les données du mutant actif sur ce pot (ou nil)
function FlowerPotGrowthSystem.GetMutantActif(potModel)
    if not potModel then return nil end
    return _mutants[potModel:GetFullName()]
end

-- Retourne l'état complet d'un pot pour le HUD Seeds
-- statut : "growing" | "ready" | nil (vide)
function FlowerPotGrowthSystem.GetStatut(potModel)
    if not potModel then return nil end
    local potId    = potModel:GetFullName()
    local plantage = _plantages[potId]
    local mutant   = _mutants[potId]
    local enCours  = _threads[potId] ~= nil

    if enCours and plantage then
        return {
            statut      = "growing",
            rarity      = plantage.rarity,
            stage       = plantage.stage,
            elementType = mutant and mutant.elementType or nil,
        }
    elseif mutant then
        -- Thread terminé mais mutant toujours actif → prêt à récolter
        return {
            statut      = "ready",
            rarity      = mutant.seedRarity or (plantage and plantage.rarity),
            elementType = mutant.elementType,
            multiplier  = mutant.multiplier,
        }
    end
    return nil
end

-- Callback injecté par Main.server.lua pour accéder à playerData sans dépendance circulaire
-- signature: function(player) → playerData ou nil
FlowerPotGrowthSystem.GetPlayerData = nil

return FlowerPotGrowthSystem
