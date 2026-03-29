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

-- ============================================================
-- Constantes (lues depuis GameConfig si disponibles)
-- ============================================================

-- Durée par stage en secondes (2 min par défaut)
local DUREE_PAR_STAGE   = (FPConfig and FPConfig.GrowthDuration)   or 120
-- Stage à partir duquel le BR Mutant apparaît au-dessus
local MUTANT_SPAWN_STAGE = (FPConfig and FPConfig.MutantSpawnStage) or 2
-- Offset Y au-dessus de la plante (studs)
local MUTANT_OFFSET_Y   = (FPConfig and FPConfig.MutantOffsetY)    or 3

-- Éléments disponibles
local ELEMENTS = (FPConfig and FPConfig.ElementTypes)
    or { "water", "fire", "earth", "wind" }

-- Multiplicateurs de revenu par élément
local ELEMENT_MULTIPLIERS = (FPConfig and FPConfig.ElementMultipliers)
    or { water=2, fire=4, earth=6, wind=8 }

-- Config particules par élément
local ELEMENT_PARTICLES = (FPConfig and FPConfig.ElementParticles)
    or {
        water = { Color=Color3.fromRGB(0,   150, 255), Lifetime=2.0, SpeedMax=3 },
        fire  = { Color=Color3.fromRGB(255, 100, 0),   Lifetime=1.0, SpeedMax=5 },
        earth = { Color=Color3.fromRGB(100, 200, 50),  Lifetime=3.0, SpeedMax=2 },
        wind  = { Color=Color3.fromRGB(230, 230, 230), Lifetime=1.5, SpeedMax=6 },
    }

-- Emojis par élément (affichage billboard)
local ELEMENT_EMOJIS = { water="💧", fire="🔥", earth="🌍", wind="💨" }

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
        warn("[FlowerPotGrowthSystem] ServerStorage/Seeds introuvable — créer le dossier dans Studio")
        return nil
    end

    local src = dossierGraines:FindFirstChild("GenericSeed")
    if not src then
        warn("[FlowerPotGrowthSystem] GenericSeed introuvable dans Seeds/ — créer le modèle dans Studio")
        return nil
    end

    local clone = nil
    local ok = pcall(function() clone = src:Clone() end)
    if not ok or not clone then
        warn("[FlowerPotGrowthSystem] Échec clone GenericSeed")
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
        warn("[FlowerPotGrowthSystem] ServerStorage/Plants introuvable — créer le dossier dans Studio")
        return nil
    end

    local nomStage = "Plant_Stage" .. stageIndex
    local src = dossierPlants:FindFirstChild(nomStage)
    if not src then
        warn("[FlowerPotGrowthSystem] Modèle introuvable :", nomStage, "— créer dans Studio")
        return nil
    end

    local clone = nil
    local ok = pcall(function() clone = src:Clone() end)
    if not ok or not clone then
        warn("[FlowerPotGrowthSystem] Échec clone :", nomStage)
        return nil
    end

    ancrerClone(clone)
    positionnerClone(clone, getSurfacePot(potPart))
    clone.Name   = "FlowerPotPlant"
    clone.Parent = Workspace
    return clone
end

-- Clone un BR Mutant depuis ServerStorage/Brainrots/MYTHIC/ ou /SECRET/
-- Choisit un modèle aléatoire dans le dossier de la rareté
local function clonerBRMutant(seedRarity)
    local brainrots = ServerStorage:FindFirstChild("Brainrots")
    if not brainrots then
        warn("[FlowerPotGrowthSystem] ServerStorage/Brainrots introuvable")
        return nil
    end

    local dossier = brainrots:FindFirstChild(seedRarity)
    if not dossier then
        warn("[FlowerPotGrowthSystem] Dossier rareté introuvable :", seedRarity)
        return nil
    end

    local modeles = dossier:GetChildren()
    if #modeles == 0 then
        warn("[FlowerPotGrowthSystem] Aucun modèle dans :", seedRarity)
        return nil
    end

    local clone = nil
    local ok = pcall(function()
        clone = modeles[math.random(1, #modeles)]:Clone()
    end)
    if not ok or not clone then
        warn("[FlowerPotGrowthSystem] Échec clone BR Mutant depuis :", seedRarity)
        return nil
    end

    ancrerClone(clone)
    return clone
end

-- ============================================================
-- Effets visuels sur le BR Mutant
-- ============================================================

-- Applique les particules élémentaires sur le BasePart racine du clone
local function appliquerParticulesElement(clone, elementType)
    local cfg = ELEMENT_PARTICLES[elementType]
    if not cfg then return end

    -- Trouver la part racine pour les particules
    local root = nil
    if clone:IsA("Model") then
        root = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart")
    elseif clone:IsA("BasePart") then
        root = clone
    end
    if not root then
        warn("[FlowerPotGrowthSystem] Aucun BasePart racine pour les particules :", elementType)
        return
    end

    local ok = pcall(function()
        local emitter          = Instance.new("ParticleEmitter", root)
        emitter.Name           = "ElementParticles"
        emitter.Color          = ColorSequence.new(cfg.Color)
        emitter.Lifetime       = NumberRange.new(cfg.Lifetime * 0.6, cfg.Lifetime)
        emitter.Speed          = NumberRange.new(0.5, cfg.SpeedMax)
        emitter.Rate           = 18
        emitter.Size           = NumberSequence.new({
            NumberSequenceKeypoint.new(0,   0.35),
            NumberSequenceKeypoint.new(0.7, 0.25),
            NumberSequenceKeypoint.new(1,   0),
        })
        emitter.LightEmission  = 0.7
        emitter.LightInfluence = 0.3
        emitter.RotSpeed       = NumberRange.new(-45, 45)
    end)

    if not ok then
        warn("[FlowerPotGrowthSystem] Erreur création particules :", elementType)
    end
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
    @param seedRarity (string)  — "MYTHIC" ou "SECRET"
    @param player     (Player)  — propriétaire du pot (validation carry)
    @param onHarvest  (function, optionnel) — callback après récolte réussie
                      signature: onHarvest(player, elementType, multiplier)
]]
function FlowerPotGrowthSystem.PlantSeed(potModel, seedRarity, player, onHarvest)
    -- Validation des paramètres
    if not potModel or not potModel.Parent then
        warn("[FlowerPotGrowthSystem] potModel invalide")
        return
    end
    if seedRarity ~= "MYTHIC" and seedRarity ~= "SECRET" then
        warn("[FlowerPotGrowthSystem] seedRarity invalide (doit être MYTHIC ou SECRET) :", seedRarity)
        return
    end

    local potPart = getPotPart(potModel)
    if not potPart then
        warn("[FlowerPotGrowthSystem] Pas de BasePart dans :", potModel.Name)
        return
    end

    -- Identifiant unique du pot (chemin complet dans Workspace)
    local potId = potModel:GetFullName()

    -- Annuler toute croissance précédente sur ce pot
    nettoyerPot(potId)

    -- Mémoriser rareté et stage courant (exposé via GetStatut)
    _plantages[potId] = { rarity = seedRarity, stage = -1 }

    -- Choisir élément aléatoire
    local elementType = ELEMENTS[math.random(1, #ELEMENTS)]
    local multiplier  = ELEMENT_MULTIPLIERS[elementType] or 2
    local emoji       = ELEMENT_EMOJIS[elementType] or "✨"

    print(string.format(
        "[FlowerPotGrowthSystem] Début croissance | Pot: %s | Graine: %s | Élément: %s %s | ×%d",
        potModel.Name, seedRarity, elementType, emoji, multiplier))

    -- ══════════════════════════════════════════════════════
    -- Thread principal de croissance
    -- ══════════════════════════════════════════════════════
    _threads[potId] = task.spawn(function()
        local plantActuel = nil   -- modèle plant visible dans le Workspace
        local mutantClone = nil   -- BR Mutant spawné au stage 2

        -- ────────────────────────────────────────────────
        -- ÉTAPE INITIALE : Afficher GenericSeed (instant)
        -- ────────────────────────────────────────────────
        local graine = clonerGraine(potPart)
        if graine then
            plantActuel = graine
            print("[FlowerPotGrowthSystem]", potModel.Name, "→ GenericSeed affiché")
        end

        -- ────────────────────────────────────────────────
        -- STAGES 0 à 3 (4 stages × DUREE_PAR_STAGE)
        -- ────────────────────────────────────────────────
        for stage = 0, 3 do
            -- Attendre la durée du stage
            task.wait(DUREE_PAR_STAGE)

            -- Vérifier validité du pot (peut être détruit si joueur quitte)
            if not potModel or not potModel.Parent then
                print("[FlowerPotGrowthSystem] Pot détruit — croissance annulée :", potId)
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

            print(string.format("[FlowerPotGrowthSystem] %s → Plant_Stage%d",
                potModel.Name, stage))

            -- ─── STAGE 2 : Spawn BR Mutant au-dessus ───
            if stage == MUTANT_SPAWN_STAGE then
                mutantClone = clonerBRMutant(seedRarity)

                if mutantClone then
                    -- Position au-dessus du pot
                    local posAuDessus = getSurfacePot(potPart)
                        + Vector3.new(0, MUTANT_OFFSET_Y, 0)

                    positionnerClone(mutantClone, posAuDessus)

                    -- Attributs élémentaires (serveur uniquement)
                    pcall(function()
                        mutantClone:SetAttribute("IsMutant",    true)
                        mutantClone:SetAttribute("ElementType", elementType)
                        mutantClone:SetAttribute("Rarity",      seedRarity)
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

                    print(string.format(
                        "[FlowerPotGrowthSystem] BR Mutant %s spawné à Y+%d | %s | Pot: %s",
                        seedRarity, MUTANT_OFFSET_Y, elementType, potModel.Name))
                else
                    warn("[FlowerPotGrowthSystem] Échec spawn BR Mutant — vérifier ServerStorage/Brainrots/" .. seedRarity)
                end
            end
        end

        -- ────────────────────────────────────────────────
        -- FIN DU DERNIER STAGE : Plante meurt
        -- ────────────────────────────────────────────────
        task.wait(DUREE_PAR_STAGE)

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

        print("[FlowerPotGrowthSystem]", potModel.Name, "→ Plante morte")

        -- ────────────────────────────────────────────────
        -- CHUTE : BR Mutant tombe sur le pot
        -- ────────────────────────────────────────────────
        if not mutantClone or not mutantClone.Parent then
            warn("[FlowerPotGrowthSystem] BR Mutant introuvable à la fin de croissance :", potId)
            _threads[potId] = nil
            return
        end

        -- Position finale : surface du pot
        local posSurPot = getSurfacePot(potPart) + Vector3.new(0, 0.5, 0)

        -- Burst visuel au moment de la chute
        burstParticulesChute(mutantClone)

        -- Animation de chute
        animerChute(mutantClone, posSurPot, 0.8)

        print(string.format(
            "[FlowerPotGrowthSystem] BR Mutant tombé sur %s — élément: %s | ×%d",
            potModel.Name, elementType, multiplier))

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
                warn("[FlowerPotGrowthSystem] FlowerPotPickupHandler indisponible — BR Mutant non récoltable")
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
    print("[FlowerPotGrowthSystem] Croissance annulée :", potModel.Name)
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

return FlowerPotGrowthSystem
