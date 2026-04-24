-- ServerScriptService/Common/DropSystem.lua
-- DobiGames — Dépôt des Brain Rots dans les spots de la base
-- Gère les visuels (mini modèles), SurfaceGui, et la récupération

local DropSystem = {}

-- ============================================================
-- Services
-- ============================================================
local Players             = game:GetService("Players")
local Workspace           = game:GetService("Workspace")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerStorage       = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService        = game:GetService("TweenService")
local CollectionService   = game:GetService("CollectionService")
local Logger              = require(ServerScriptService.SharedLib.Server.Logger)
local BrainrotBillboard   = require(ServerScriptService.SharedLib.Server.BrainrotBillboard)
local BrainrotPositioner  = require(ServerScriptService.SharedLib.Server.BrainrotPositioner)

-- ============================================================
-- Config
-- ============================================================
local Config = require(
    ReplicatedStorage:FindFirstChild("GameConfig")
    or ReplicatedStorage.Specialized.GameConfig
)
local ProgConfig = Config.ProgressionConfig

-- Dossier source des Brainrots (ServerStorage par défaut, ReplicatedStorage pour LavaTower)
-- Configurable via DropSystem.SetBrainrotsFolder(folder) depuis Main.server.lua
local _brainrotsFolder = nil
local function getBrainrotsFolder()
    return _brainrotsFolder or ServerStorage:FindFirstChild("Brainrots")
end

-- ============================================================
-- Chargement différé de IncomeSystem (évite la dépendance circulaire)
-- DropSystem requiert IncomeSystem, IncomeSystem requiert BaseProgressionSystem —
-- en chargeant après le premier tick, tous les modules sont déjà en mémoire.
-- ============================================================
local _IncomeSystem = nil
local function getIncomeSystem()
    if not _IncomeSystem then
        local ok, m = pcall(require, game:GetService("ServerScriptService").SharedLib.Server.IncomeSystem)
        if ok and m then _IncomeSystem = m end
    end
    return _IncomeSystem
end

-- Chargement différé de FilterManager (effets visuels élémentaires Mutant)
local _FilterManager = nil
local function getFilterManager()
    if not _FilterManager then
        local ok, m = pcall(function()
            return require(ServerScriptService
                :FindFirstChild("SharedLib")
                :FindFirstChild("BRFilterSystem")
                :FindFirstChild("FilterManager"))
        end)
        if ok and m then _FilterManager = m end
    end
    return _FilterManager
end

-- Correspondance type Mutant → nom filtre FilterManager
-- Construit dynamiquement depuis GameConfig.MutantTypes (source de vérité canonique)
-- Pattern identique à FlowerPotGrowthSystem : MutantTypes[].Name → MutantTypes[].Filtre
local ELEMENT_TO_FILTRE = {}
if Config.MutantTypes then
    for _, mt in ipairs(Config.MutantTypes) do
        if mt.Name and mt.Filtre then
            ELEMENT_TO_FILTRE[mt.Name] = mt.Filtre
        end
    end
end

-- ============================================================
-- Callback injecté par Main.server.lua (optionnel)
-- Appelé après chaque dépôt / récupération / vente
-- Exemple : DropSystem.OnSpotChange = function(player) RebirthSystem.MettreAJourBouton(player) end
-- ============================================================
DropSystem.OnSpotChange  = nil
-- Appelé quand un Mutant est déposé sur un spot (touchPart, modeleSlot, elementType)
DropSystem.OnMutantDepose = nil
-- Appelé quand un Mutant est retiré d'un spot (touchPart)
DropSystem.OnMutantRetire = nil

-- ============================================================
-- Centre de base par joueur (calculé à l'Init, utilisé pour orienter les BRs)
-- ============================================================
local baseCentres = {}

-- Retourne le centre XZ de la base (Vector3 avec Y=0) depuis le modèle workspace
local function calculerCentreBase(baseIndex)
    local bases = Workspace:FindFirstChild("Bases")
    if not bases then return nil end
    local baseRoot = bases:FindFirstChild("Base_" .. tostring(baseIndex))
    if not baseRoot then return nil end
    local ok, bbCF = pcall(function()
        local cf, _ = baseRoot:GetBoundingBox()
        return cf
    end)
    if ok and bbCF then
        return Vector3.new(bbCF.Position.X, 0, bbCF.Position.Z)
    end
    return nil
end

-- ============================================================
-- État interne par joueur
-- ============================================================
-- spotsData[userId] = {
--   [touchPart] = {
--     spotKey   = "floor_spot" (ex : "1_3"),
--     rarete    = "EPIC",
--     valeurSec = 20,
--     modeleSlot = Model (instance dans Workspace),
--   }
-- }
-- spotIndex[userId] = {
--   ["floor_spot"] = touchPart   (lookup inverse)
-- }
local spotsData  = {}
local spotIndex  = {}

-- ============================================================
-- Utilitaires — notifications
-- ============================================================

local function notifierJoueur(player, typeNotif, msg)
    local ev = ReplicatedStorage:FindFirstChild("NotifEvent")
    if ev then pcall(function() ev:FireClient(player, typeNotif, msg) end) end
end

-- ============================================================
-- Utilitaires — recherche dans la base
-- ============================================================

-- Normalise le nom d'un objet Studio (espaces/underscore/tirets ignorés, minuscules)
local function normaliser(nom)
    return string.lower((nom:gsub("[%s_%-]", "")))
end

-- Cherche un étage dans baseFolder avec fallback tolérant
local function trouverFloor(baseFolder, floorDef)
    if not baseFolder then return nil end
    -- Nom exact depuis la config (ATTENTION : Floor 1 a un double espace)
    local direct = baseFolder:FindFirstChild(floorDef.nom)
    if direct then return direct end
    -- Fallback : "floor1", "Floor_1", etc.
    local cible = "floor" .. tostring(floorDef.index)
    for _, child in ipairs(baseFolder:GetChildren()) do
        if normaliser(child.Name) == cible then return child end
    end
    return nil
end

-- Cherche un spot_X dans un floor avec fallback tolérant
local function trouverSpot(floorObj, spotNum)
    if not floorObj then return nil end
    local direct = floorObj:FindFirstChild("spot_" .. tostring(spotNum))
    if direct then return direct end
    local cible = "spot" .. tostring(spotNum)
    for _, child in ipairs(floorObj:GetChildren()) do
        if normaliser(child.Name) == cible then return child end
    end
    return nil
end

-- Trouve le baseFolder actif (Base_X ou Base_X/Base selon structure)
local function trouverBaseFolder(baseIndex)
    local bases = Workspace:FindFirstChild("Bases")
    if not bases then return nil end
    local baseRoot = bases:FindFirstChild("Base_" .. tostring(baseIndex))
    if not baseRoot then return nil end
    -- Préférer Base_X/Shared/Base s'il contient des floors (structure Shared/Specific)
    local sharedFolder = baseRoot:FindFirstChild("Shared")
    local candidat     = sharedFolder and sharedFolder:FindFirstChild("Base")
    if candidat then
        for _, floorDef in ipairs(ProgConfig.floors) do
            if trouverFloor(candidat, floorDef) then return candidat end
        end
    end
    return baseRoot
end

-- ============================================================
-- Utilitaires — SurfaceGui
-- ============================================================

-- Met à jour les TextLabel $amount et $offline d'un spot
local function mettreAJourGui(touchPart, valeurSec)
    -- Chercher le SurfaceGui nommé "Text" (ou n'importe quel SurfaceGui)
    local gui = touchPart:FindFirstChild("Text")
    if not gui then
        gui = touchPart:FindFirstChildOfClass("SurfaceGui")
    end
    if not gui then return end

    local amount  = gui:FindFirstChild("$amount")
    local offline = gui:FindFirstChild("$offline")

    if amount then
        pcall(function()
            amount.Text = "+" .. tostring(valeurSec) .. "/s"
        end)
    end
    if offline then
        pcall(function()
            local valOffline = math.max(1, math.floor(valeurSec * 0.1))
            offline.Text = "⏱ +" .. tostring(valOffline) .. "/s"
        end)
    end
end

-- Remet le SurfaceGui à l'état vide
local function viderGui(touchPart)
    local gui = touchPart:FindFirstChild("Text")
    if not gui then gui = touchPart:FindFirstChildOfClass("SurfaceGui") end
    if not gui then return end

    local amount  = gui:FindFirstChild("$amount")
    local offline = gui:FindFirstChild("$offline")
    if amount  then pcall(function() amount.Text  = "" end) end
    if offline then pcall(function() offline.Text = "" end) end
end

-- ============================================================
-- Utilitaires — dossiers mutation
-- ============================================================

local NOMS_DOSSIERS_MUTATION = {
    GOLD    = "BrainrotsGold",
    DIAMANT = "BrainrotsDiamant",
    RAINBOW = "BrainrotsRainbow",
}

-- Retourne le dossier rareté dans Mutation/[type]/[rarity], ou nil si inexistant.
-- mutation = "GOLD"|"DIAMANT"|"RAINBOW"|nil, isToxic = bool, rarity = "COMMON"|"RARE"|…
local function getDossierMutation(mutation, isToxic, rarity)
    local mutRoot = ReplicatedStorage:FindFirstChild("Mutation")
    if not mutRoot then return nil end
    local nomDossier
    if mutation then
        nomDossier = NOMS_DOSSIERS_MUTATION[mutation]
    elseif isToxic then
        nomDossier = "BrainrotsToxic"
    end
    if not nomDossier then return nil end
    local mutDossier = mutRoot:FindFirstChild(nomDossier)
    if not mutDossier then return nil end
    return mutDossier:FindFirstChild(rarity)
        or mutDossier:FindFirstChild(string.upper(rarity))
        or mutDossier:FindFirstChild(string.lower(rarity):gsub("^%l", string.upper))
end

-- ============================================================
-- Utilitaires — mini modèle Brain Rot
-- ============================================================

-- Clone un modèle depuis ServerStorage.Brainrots/[dossier]
-- Décision : on clone un aléatoire parmi les modèles du dossier (cohérent avec CarrySystem)
local function clonerModeleSlot(rarete)
    local brainrots = getBrainrotsFolder()
    if not brainrots then return nil end

    local dossier = brainrots:FindFirstChild(rarete)
                 or brainrots:FindFirstChild(string.upper(rarete))
                 or brainrots:FindFirstChild(string.lower(rarete):gsub("^%l", string.upper))
    if not dossier then
        -- Fallback au dossier COMMON si la rareté n'est pas trouvée
        dossier = brainrots:FindFirstChild("COMMON")
    end
    if not dossier then return nil end

    local modeles = dossier:GetChildren()
    if #modeles == 0 then return nil end

    local source = modeles[math.random(1, #modeles)]
    local clone  = nil
    pcall(function() clone = source:Clone() end)
    return clone
end

-- Réapplique les effets visuels élémentaires sur un modèle déposé/restauré
-- (appel FilterManager identique à FlowerPotGrowthSystem.appliquerParticulesElement)
local function appliquerEffetsMutant(modeleSlot, elementType)
    if not modeleSlot or not elementType then return end
    local FM = getFilterManager()
    if not FM then
        Logger.warn("Drop", "FilterManager indisponible — effets Mutant ignorés pour : %s", tostring(elementType))
        return
    end
    local nomFiltre = ELEMENT_TO_FILTRE[elementType]
    if not nomFiltre then
        Logger.warn("Drop", "Élément inconnu : %s", tostring(elementType))
        return
    end
    pcall(function() FM.Apply(modeleSlot, { { Name = nomFiltre } }) end)
end

-- Supprime les instances parasites ajoutées pendant le cycle carry/capture
-- qui deviendraient des cubes gris si on les rend visibles par erreur
local function nettoyerParasites(clone)
    -- PromptAnchor : Part 0.1×0.1×0.1 injectée par CarrySystem.creerPromptCapture
    -- Elle est Transparency=1 dans le monde, mais le fade-in la rendrait visible (cube gris)
    for _, v in ipairs(clone:GetDescendants()) do
        if v.Name == "PromptAnchor" then
            pcall(function() v:Destroy() end)
        end
    end

    -- VfxInstance : dossier contenant speccloud1/2, saltfloor, etc.
    -- Parts sans mesh → cubes gris si rendus opaques
    local vfx = clone:FindFirstChild("VfxInstance")
    if vfx then pcall(function() vfx:Destroy() end) end

    -- BillboardGui : garder _BRBillboard mais supprimer LTimer dedans
    -- ProximityPrompts : tous supprimés (Collect, Capture, etc.)
    for _, v in ipairs(clone:GetDescendants()) do
        if v:IsA("BillboardGui") then
            if v.Name == "_BRBillboard" then
                -- Conserver le billboard d'info mais retirer le timer
                local lTimer = v:FindFirstChild("LTimer")
                if lTimer then pcall(function() lTimer:Destroy() end) end
            else
                pcall(function() v:Destroy() end)
            end
        elseif v:IsA("ProximityPrompt") then
            pcall(function() v:Destroy() end)
        end
    end

    -- Constraints et forces physiques résiduels de la session carry
    for _, v in ipairs(clone:GetDescendants()) do
        if v:IsA("WeldConstraint") or v:IsA("Weld") or v:IsA("Motor6D")
           or v:IsA("BodyForce") or v:IsA("BodyVelocity") or v:IsA("BodyGyro")
           or v:IsA("BodyPosition") or v:IsA("BodyAngularVelocity") then
            pcall(function() v:Destroy() end)
        end
    end

    -- Retirer le tag BrainrotCollectible (Clone() le copie depuis le modèle source).
    -- Sans ce retrait, PickupSystem.GetInstanceAddedSignal se déclenche quand le clone
    -- entre dans Workspace → recrée Collect prompt + LTimer + StartCountdown.
    pcall(function()
        if CollectionService:HasTag(clone, "BrainrotCollectible") then
            CollectionService:RemoveTag(clone, "BrainrotCollectible")
        end
    end)
end

-- Place et anime le modèle sur un spot (taille originale)
-- modeleSource (optionnel) = le modèle exact porté par le joueur (prioritaire sur ServerStorage)
-- baseCenter   (optionnel) = Vector3 vers lequel le modèle doit regarder (centre de la base)
local function placerModeleSlot(touchPart, rarete, modeleSource, baseCenter)
    local clone

    -- Priorité : cloner le modèle porté (évite les cubes gris si ServerStorage mal configuré)
    if modeleSource and modeleSource.Parent then
        pcall(function() clone = modeleSource:Clone() end)
        -- Supprimer le modèle détaché flottant dans le Workspace
        pcall(function() modeleSource:Destroy() end)
        Logger.debug("Drop", "Modèle issu du carry (modèle exact)")
    end

    -- Fallback : clone aléatoire depuis ServerStorage
    if not clone then
        clone = clonerModeleSlot(rarete)
    end

    if not clone then return nil end

    -- Nettoyer les parasites AVANT tout autre traitement
    -- (PromptAnchor, VfxInstance, constraints → cubes gris si laissés)
    nettoyerParasites(clone)

    -- Surface du slot : dessus du TouchPart
    local surfaceY = touchPart.Position.Y + touchPart.Size.Y * 0.5
    local posX     = touchPart.Position.X
    local posZ     = touchPart.Position.Z

    -- Mémoriser la transparence ORIGINALE de chaque part avant le fade-in
    -- IMPORTANT : ne jamais tweener vers 0 — certaines parts sont intentionnellement
    -- invisibles (FakeRootPart, hitbox, helpers). Les forcer à 0 crée les cubes gris.
    local transparencesOriginales = {}
    for _, v in ipairs(clone:GetDescendants()) do
        if v:IsA("BasePart") then
            pcall(function()
                transparencesOriginales[v] = v.Transparency
                v.Anchored    = true
                v.CanCollide  = false
                v.Transparency = 1  -- départ invisible pour fade in
            end)
        end
    end

    clone.Parent = Workspace

    -- Positionner : bas du bounding box sur la surface + offset 0.6 stud,
    -- droit et orienté vers le centre de la base si disponible.
    -- (corrige le bug : avant, le PIVOT était placé à surfaceY, enfouissant
    --  les grands modèles à moitié sous le sol)
    if clone:IsA("Model") then
        BrainrotPositioner.positionnerSurSurface(clone, surfaceY, posX, posZ, baseCenter, 0.6)
    end

    -- Fade in vers la transparence ORIGINALE (pas vers 0)
    -- → les parts invisibles du modèle restent invisibles après le fade
    local fadeInDuree = (Config.AnimationConfig and Config.AnimationConfig.brDepotDuree) or 0.3
    local tweenInfo = TweenInfo.new(fadeInDuree, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    for _, v in ipairs(clone:GetDescendants()) do
        if v:IsA("BasePart") then
            local transpCible = transparencesOriginales[v] or 0
            pcall(function()
                TweenService:Create(v, tweenInfo, { Transparency = transpCible }):Play()
            end)
        end
    end

    return clone
end

-- Supprime le modèle d'un slot avec un fade out
local function supprimerModeleSlot(modeleSlot)
    if not modeleSlot or not modeleSlot.Parent then return end
    local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad)
    local parts     = {}
    for _, v in ipairs(modeleSlot:GetDescendants()) do
        if v:IsA("BasePart") then table.insert(parts, v) end
    end
    for _, part in ipairs(parts) do
        if part and part.Parent then
            pcall(function() TweenService:Create(part, tweenInfo, { Transparency = 1 }):Play() end)
        end
    end
    task.delay(0.25, function()
        if modeleSlot and modeleSlot.Parent then
            pcall(function() modeleSlot:Destroy() end)
        end
    end)
end

-- ============================================================
-- Utilitaires — ProximityPrompts
-- ============================================================

-- Deux prompts Default sur des ancres décalées gauche/droite du slot
-- E = Sell (bord gauche), R = Retrieve (bord droit) — déclenchés côté serveur
local function creerPromptRecuperer(touchPart, player)
    -- Supprimer anciens prompts et ancres (compatibilité)
    for _, child in ipairs(touchPart:GetChildren()) do
        if child:IsA("ProximityPrompt")
            and child.Name ~= "DepotPrompt"
            and child.Name ~= "RemplacerPrompt" then
            pcall(function() child:Destroy() end)
        end
        if child:IsA("BasePart")
            and (child.Name == "AnchorSell" or child.Name == "AnchorRetrieve") then
            pcall(function() child:Destroy() end)
        end
    end

    local uid    = player.UserId
    local entree = spotsData[uid] and spotsData[uid][touchPart]
    if not entree then return end

    local rareteNom = entree.rarete or "BR"
    local brNom     = entree.brNom and entree.brNom:gsub("_", " ") or rareteNom

    -- Créer une Part-ancre invisible décalée en X par rapport au slot
    local halfW = (touchPart.Size.X / 2) + 1
    local function creerAncre(name, offsetX)
        local part = Instance.new("Part")
        part.Name         = name
        part.Size         = Vector3.new(0.1, 0.1, 0.1)
        part.Anchored     = true
        part.CanCollide   = false
        part.Transparency = 1
        part.CFrame       = touchPart.CFrame * CFrame.new(offsetX, 0, 0)
        part.Parent       = touchPart
        return part
    end

    local ancreLeft  = creerAncre("AnchorSell",     -halfW)
    local ancreRight = creerAncre("AnchorRetrieve",  halfW)

    -- Prompt E = Sell (bord gauche)
    local promptSell = Instance.new("ProximityPrompt")
    promptSell.Name                  = "SellPrompt"
    promptSell.ActionText            = "Sell"
    promptSell.ObjectText            = brNom
    promptSell.HoldDuration          = 0
    promptSell.MaxActivationDistance = 10
    promptSell.KeyboardKeyCode       = Enum.KeyCode.S
    promptSell.RequiresLineOfSight   = false
    promptSell:SetAttribute("SpotKey", entree.spotKey)
    promptSell.Parent                = ancreLeft

    promptSell.Triggered:Connect(function(triggerPlayer)
        if triggerPlayer ~= player then return end
        DropSystem.VendreBR(player, touchPart)
    end)

    -- Prompt R = Retrieve (bord droit)
    local promptRetrieve = Instance.new("ProximityPrompt")
    promptRetrieve.Name                  = "RetrievePrompt"
    promptRetrieve.ActionText            = "Retrieve"
    promptRetrieve.ObjectText            = brNom
    promptRetrieve.HoldDuration          = 0
    promptRetrieve.MaxActivationDistance = 10
    promptRetrieve.KeyboardKeyCode       = Enum.KeyCode.R
    promptRetrieve.RequiresLineOfSight   = false
    promptRetrieve:SetAttribute("SpotKey", entree.spotKey)
    promptRetrieve.Parent                = ancreRight

    promptRetrieve.Triggered:Connect(function(triggerPlayer)
        if triggerPlayer ~= player then return end
        DropSystem.RecupererBrainRot(player, touchPart)
    end)

    local depotPrompt = touchPart:FindFirstChild("DepotPrompt")
    if depotPrompt then pcall(function() depotPrompt.Enabled = false end) end
end


-- Prompt "Remplacer" : éjecte le BR actuel et dépose le BR porté
local function creerPromptRemplacer(touchPart, player, rarete)
    local ancien = touchPart:FindFirstChild("RemplacerPrompt")
    if ancien then ancien:Destroy() end

    local prompt = Instance.new("ProximityPrompt")
    prompt.Name                  = "RemplacerPrompt"
    prompt.ActionText            = "Replace"
    prompt.ObjectText            = rarete or "Brain Rot"
    prompt.HoldDuration          = 0
    prompt.MaxActivationDistance = 8
    prompt.KeyboardKeyCode       = Enum.KeyCode.F
    prompt.RequiresLineOfSight   = false
    prompt.Enabled               = false  -- activé dynamiquement si carry > 0
    prompt.Parent                = touchPart

    prompt.Triggered:Connect(function(triggerPlayer)
        if triggerPlayer ~= player then return end
        local CS     = require(game:GetService("ServerScriptService").SharedLib.Server.CarrySystem)
        local portes = CS.GetPortes(player)
        -- Compter uniquement les entrées avec toolRef valide (pas de fantômes)
        local nbValides = 0
        for _, entree in ipairs(portes) do
            if entree.toolRef and entree.toolRef.Parent then
                nbValides = nbValides + 1
            end
        end
        if nbValides == 0 then
            notifierJoueur(player, "INFO", "You are not carrying any Brain Rot!")
            return
        end
        -- Éjecter le BR actuel dans le champ, puis déposer le BR porté
        DropSystem.EjecterBR(player, touchPart)
        DropSystem.DeposerBrainRots(player, touchPart)
    end)
end

local function supprimerPromptRecuperer(player, touchPart)
    for _, name in ipairs({ "SellPrompt", "RetrievePrompt", "AnchorSell", "AnchorRetrieve",
                             "SlotPrompt", "ManagePrompt", "RecupererPrompt", "VendrePrompt", "RemplacerPrompt" }) do
        local p = touchPart:FindFirstChild(name)
        if p then pcall(function() p:Destroy() end) end
    end

    -- Recalculer l'état de tous les prompts selon le carry réel (évite d'activer le DepotPrompt à tort)
    DropSystem.RecalculerPrompts(player)
end

-- ============================================================
-- Utilitaire — trouver la Part de dépôt dans un spotModel
-- Cherche dans cet ordre : TouchPart nommé, Part direct, PrimaryPart, premier BasePart
-- ============================================================

local function trouverTouchPart(spotModel)
    -- 1. Child explicitement nommé "TouchPart"
    local tp = spotModel:FindFirstChild("TouchPart")
    if tp and tp:IsA("BasePart") then return tp end
    -- 2. Le spot EST lui-même une BasePart
    if spotModel:IsA("BasePart") then return spotModel end
    -- 3. Child nommé "Part"
    tp = spotModel:FindFirstChild("Part")
    if tp and tp:IsA("BasePart") then return tp end
    -- 4. PrimaryPart du Model
    if spotModel:IsA("Model") and spotModel.PrimaryPart then
        return spotModel.PrimaryPart
    end
    -- 5. Premier BasePart descendant
    return spotModel:FindFirstChildWhichIsA("BasePart")
end

-- ============================================================
-- Construction de la table de lookup spots (Init)
-- ============================================================

-- Scanne tous les spots de la base et construit les lookups
-- spotIndex[userId]["floor_spot"] = touchPart
local function scannerSpots(player, baseIndex)
    local baseFolder = trouverBaseFolder(baseIndex)
    if not baseFolder then
        Logger.warn("Drop", "BaseFolder introuvable pour Base_%s", tostring(baseIndex))
        return
    end

    spotIndex[player.UserId] = {}

    for _, floorDef in ipairs(ProgConfig.floors) do
        local floorObj = trouverFloor(baseFolder, floorDef)
        if floorObj then
            for spotNum = 1, (floorDef.spots or 10) do
                local spotModel = trouverSpot(floorObj, spotNum)
                if spotModel then
                    local touchPart = trouverTouchPart(spotModel)
                    if touchPart then
                        local cle = floorDef.index .. "_" .. spotNum
                        spotIndex[player.UserId][cle] = touchPart
                    else
                        Logger.warn("Drop", "Aucune Part trouvée dans %s", spotModel.Name)
                    end
                end
            end
        end
    end
end


-- ============================================================
-- Restauration des spots depuis playerData (reconnexion)
-- ============================================================

local function restaurerDepots(player, playerData)
    if not playerData.spotsOccupes then return end

    local uid   = player.UserId
    local index = spotIndex[uid]
    if not index then return end

    if not spotsData[uid] then spotsData[uid] = {} end

    for spotKey, info in pairs(playerData.spotsOccupes) do
        local touchPart = index[spotKey]
        if touchPart and info and info.rarete then
            -- valeurSec sauvegardée lors du dépôt initial (attribut CashParSeconde du modèle)
            -- Sera complété via fallback modèle source si 0/nil (anciens saves ou BR sans attribut)
            local valeur   = (info.valeurSec and info.valeurSec > 0) and info.valeurSec or nil
            local isMutant = info.isMutant == true

            -- Tenter de restaurer le modèle exact via brNom (mutants inclus)
            local modeleSource = nil
            -- Trouver le bon dossier : mutation d'abord, normal en fallback
            local function trouverDossier()
                local d = getDossierMutation(info.mutation, info.isToxic, info.rarete)
                if d then return d end
                local brainrots = getBrainrotsFolder()
                return brainrots and (
                    brainrots:FindFirstChild(info.rarete)
                    or brainrots:FindFirstChild(string.upper(info.rarete))
                    or brainrots:FindFirstChild(string.lower(info.rarete):gsub("^%l", string.upper))
                )
            end
            if info.brNom then
                local dossier  = trouverDossier()
                local brSource = dossier and dossier:FindFirstChild(info.brNom)
                if brSource then
                    pcall(function()
                        modeleSource = brSource:Clone()
                        -- Garantir les attributs mutation pour le watcher DescendantAdded
                        if info.mutation then modeleSource:SetAttribute("Mutation", info.mutation) end
                        if info.isToxic  then modeleSource:SetAttribute("IsToxic",  true)         end
                        modeleSource.Parent = Workspace
                    end)
                else
                    Logger.warn("Drop", "Restauration : modèle '%s' introuvable → fallback premier modèle du dossier", tostring(info.brNom))
                end
            else
                -- brNom nil : donnée ancienne OU mutant sans brNom sauvegardé
                local dossier = trouverDossier()
                if dossier then
                    local modeles = dossier:GetChildren()
                    if #modeles > 0 then
                        pcall(function()
                            modeleSource = modeles[1]:Clone()
                            if info.mutation then modeleSource:SetAttribute("Mutation", info.mutation) end
                            if info.isToxic  then modeleSource:SetAttribute("IsToxic",  true)         end
                            modeleSource.Parent = Workspace
                        end)
                        Logger.debug("Drop", "Restauration : brNom nil pour %s → modèle fixe '%s'", tostring(info.rarete), modeles[1].Name)
                    end
                end
            end

            -- Fallback : lire CashParSeconde depuis le modèle cloné si valeur inconnue
            -- (anciens saves sans valeurSec, ou BR dont l'attribut n'était pas encore posé)
            local function appliquerMultiplicateurs(base)
                local v = base
                if isMutant and info.elementType then
                    local multElem = (Config.MutantConfig
                        and Config.MutantConfig.ElementMultipliers
                        and Config.MutantConfig.ElementMultipliers[info.elementType]) or 1
                    v = v * multElem
                end
                local mutCPS2  = Config.Fuse and Config.Fuse.MutationCPS
                local mutMult2 = (mutCPS2 and info.mutation and mutCPS2[info.mutation]) or 1
                if mutMult2 > 1 then v = math.floor(v * mutMult2) end
                return v
            end
            if not valeur and modeleSource then
                local cpsAttr = modeleSource:GetAttribute("CashParSeconde")
                if cpsAttr and cpsAttr > 0 then
                    valeur = appliquerMultiplicateurs(cpsAttr)
                end
            end
            local modeleSlot = placerModeleSlot(touchPart, info.rarete, modeleSource, baseCentres[uid])

            -- Fallback définitif : lire CashParSeconde depuis le modèle restauré sur le slot.
            if (not valeur or valeur == 0) and modeleSlot then
                local cpsSlot = modeleSlot:GetAttribute("CashParSeconde")
                if cpsSlot and cpsSlot > 0 then
                    valeur = appliquerMultiplicateurs(cpsSlot)
                end
            end
            valeur = valeur or 0

            -- Billboard base (Nom · Rareté · $Prix · $CPS/s — sans timer)
            if modeleSlot then
                pcall(function()
                    modeleSlot:SetAttribute("CashParSeconde", valeur)
                    if isMutant then
                        modeleSlot:SetAttribute("IsMutant", true)
                        if info.elementType then modeleSlot:SetAttribute("MutantType", info.elementType) end
                        if info.mutation    then modeleSlot:SetAttribute("Mutation",   info.mutation)    end
                    end
                    if info.isToxic then modeleSlot:SetAttribute("IsToxic", true) end
                end)
                pcall(BrainrotBillboard.SetupBase, modeleSlot)
            end

            if isMutant then
                -- Réappliquer les effets visuels élémentaires (particles + highlight + emoji)
                appliquerEffetsMutant(modeleSlot, info.elementType)
                if DropSystem.OnMutantDepose then
                    pcall(DropSystem.OnMutantDepose, touchPart, modeleSlot, info.elementType)
                end
            end

            spotsData[uid][touchPart] = {
                spotKey           = spotKey,
                rarete            = info.rarete,
                brNom             = info.brNom,
                isMutant          = isMutant,
                elementType       = info.elementType,
                mutation          = info.mutation,
                isToxic           = info.isToxic,
                valeurSec         = valeur,
                modeleSlot        = modeleSlot,
            }

            mettreAJourGui(touchPart, valeur)
            creerPromptRecuperer(touchPart, player)
            creerPromptRemplacer(touchPart, player, info.rarete)
        end
    end
end

-- ============================================================
-- Calcul du total de coins/sec pour passer à IncomeSystem
-- ============================================================

local function construireSpotsTable(player)
    local uid    = player.UserId
    local result = {}
    if not spotsData[uid] then return result end

    for touchPart, entry in pairs(spotsData[uid]) do
        table.insert(result, {
            touchPart = touchPart,
            rarete    = entry.rarete,
            valeurSec = entry.valeurSec,
        })
    end
    return result
end

-- ============================================================
-- API publique — Configuration
-- ============================================================

-- Configure le dossier source des Brainrots (à appeler avant Init si les BRs ne sont pas dans ServerStorage)
-- Exemple LavaTower : DropSystem.SetBrainrotsFolder(ReplicatedStorage:FindFirstChild("Brainrots"))
function DropSystem.SetBrainrotsFolder(folder)
    _brainrotsFolder = folder
end

-- ============================================================
-- API publique — Init
-- ============================================================

-- Initialise DropSystem pour un joueur (appelé depuis Main.server.lua après chargement des données)
function DropSystem.Init(player, baseIndex, playerData)
    spotsData[player.UserId] = {}
    baseCentres[player.UserId] = calculerCentreBase(baseIndex)

    -- Construire le lookup spots
    scannerSpots(player, baseIndex)

    -- Restaurer les BR déposés lors d'une session précédente
    if playerData then
        restaurerDepots(player, playerData)
    end
end

-- Ajoute un spot au spotIndex (appelé par BaseProgressionSystem lors d'un déblocage runtime)
-- spotKey = "floor_spot" (ex : "2_3"), touchPart = la Part de dépôt
function DropSystem.AjouterSpotIndex(player, spotKey, touchPart)
    if not spotIndex[player.UserId] then spotIndex[player.UserId] = {} end
    if spotIndex[player.UserId][spotKey] then return end  -- déjà enregistré
    spotIndex[player.UserId][spotKey] = touchPart
    Logger.debug("Drop", "SpotIndex mis à jour : %s → %s", spotKey, player.Name)
end

-- Enregistre un spot nouvellement débloqué depuis un spotModel (API alternative)
-- Trouve la touchPart automatiquement et l'ajoute au spotIndex
function DropSystem.InitSpot(player, spotModel, spotKey)
    if not spotModel then return end
    local touchPart = trouverTouchPart(spotModel)
    if not touchPart then
        Logger.warn("Drop", "InitSpot : aucune Part trouvée dans %s", spotModel.Name)
        return
    end
    if spotKey then
        DropSystem.AjouterSpotIndex(player, spotKey, touchPart)
    end
    Logger.debug("Drop", "InitSpot : %s enregistré pour %s", spotModel.Name, player.Name)
end

-- ============================================================
-- API publique — Dépôt
-- ============================================================

function DropSystem.DeposerBrainRots(player, touchPart)
    local uid = player.UserId
    if not spotsData[uid] then return end

    -- Validation : le spot appartient-il à la base du joueur ?
    local index = spotIndex[uid]
    if not index then return end

    -- Chercher la clé de ce touchPart
    local spotKey = nil
    for cle, tp in pairs(index) do
        if tp == touchPart then spotKey = cle break end
    end
    if not spotKey then
        Logger.warn("Drop", "%s : spot invalide (hors base)", player.Name)
        return
    end

    -- Spot déjà occupé ?
    if spotsData[uid][touchPart] then
        notifierJoueur(player, "INFO", "This spot is already occupied — retrieve the Brain Rot first.")
        return
    end

    -- Récupérer le carry du joueur via CarrySystem
    local CarrySystem = require(game:GetService("ServerScriptService").SharedLib.Server.CarrySystem)

    -- Nettoyer les entrées fantômes AVANT de vérifier le carry
    -- (cas typique : mort avec Protection → Tools détruits → entrées fantômes résiduelles)
    CarrySystem.SynchroniserCarry(player)

    local portes = CarrySystem.GetPortes(player)
    if #portes == 0 then return end

    -- Prendre le BR actuellement en main (Tool équipé dans le Character)
    -- Fallback sur portes[1] si rien n'est équipé en main
    local indexADeposer = 1
    local char = player.Character
    local equippedTool = char and char:FindFirstChildOfClass("Tool")
    if equippedTool then
        for i, p in ipairs(portes) do
            if p.toolRef == equippedTool then
                indexADeposer = i
                break
            end
        end
    end

    local entree = portes[indexADeposer]
    if not entree or not entree.rarete then return end

    local rarete    = entree.rarete.nom or "COMMON"
    local mutation  = entree.rarete.mutation
    local isToxic   = entree.rarete.isToxic == true

    -- Lire le nom et les attributs du BR depuis le Tool AVANT ViderCarry (le Tool est détruit après)
    local brNomFallback  = nil
    local cashParSeconde = nil
    if entree.toolRef and entree.toolRef.Parent then
        brNomFallback  = entree.toolRef:GetAttribute("BrainrotName")
        cashParSeconde = entree.toolRef:GetAttribute("CashParSeconde")
    end

    -- Retirer ce BR du carry (on utilise ViderCarry puis re-add les autres)
    local tous = CarrySystem.ViderCarry(player)
    -- tous[indexADeposer] = BR à déposer, les autres = à conserver
    local modeleDepose = tous[indexADeposer] and tous[indexADeposer].modele
    for i, restant in ipairs(tous) do
        if i ~= indexADeposer and restant and restant.rarete then
            -- Remettre les BR restants dans le carry
            pcall(CarrySystem.AjouterAuCarry, player, restant.modele, restant.rarete)
        end
    end

    -- Valeur par seconde : lue depuis l'attribut CashParSeconde (Tool ou modèle déposé)
    -- Fallback sur modeleDepose si l'attribut n'était pas encore sur le Tool (spawn avant fix)
    local isMutant  = entree.rarete.isMutant == true
    local valeurSec = cashParSeconde
    if (not valeurSec or valeurSec == 0) and modeleDepose then
        valeurSec = modeleDepose:GetAttribute("CashParSeconde")
    end
    valeurSec = valeurSec or 0
    -- Multiplicateur Mutant partagé (système elementType — BrainRotFarm uniquement)
    if isMutant and entree.rarete.valeur and valeurSec > 0 then
        valeurSec = valeurSec * entree.rarete.valeur
    end
    -- NOTE : le multiplicateur LavaTower (GOLD/DIAMANT/RAINBOW/TOXIC) est appliqué
    -- directement sur CashParSeconde à la naissance du brainrot (BrainrotPlatformSpawner).
    -- On NE re-multiplie PAS ici pour éviter le double-calcul.

    -- Mémoriser le nom original du BR (Attribute posé par SpawnManager/CommunSpawner)
    -- Le modèle est renommé "BR_1_42" / "CC_MYTHIC_7" au spawn → utiliser OriginalName
    -- pour retrouver le bon modèle dans ServerStorage lors de la restauration
    local brNom = nil
    if modeleDepose then
        brNom = modeleDepose:GetAttribute("OriginalName") or modeleDepose.Name
    elseif brNomFallback then
        -- modèle nil (PivotTo échoué dans creerTool) → nom récupéré depuis l'attribut du Tool
        brNom = brNomFallback
    end

    -- Si modeleDepose nil mais brNom connu → cloner depuis le bon dossier (mutation ou normal)
    local modeleSource = modeleDepose
    if not modeleSource and brNom then
        local dossier = getDossierMutation(mutation, isToxic, rarete)
        if not dossier then
            local brainrots = getBrainrotsFolder()
            dossier = brainrots and (
                brainrots:FindFirstChild(rarete)
                or brainrots:FindFirstChild(string.upper(rarete))
            )
        end
        local brSource = dossier and dossier:FindFirstChild(brNom)
        if brSource then
            pcall(function()
                modeleSource = brSource:Clone()
                if mutation then modeleSource:SetAttribute("Mutation", mutation) end
                if isToxic  then modeleSource:SetAttribute("IsToxic",  true)    end
                modeleSource.Parent = Workspace
            end)
        else
            Logger.warn("Drop", "DeposerBrainRots : modèle '%s' introuvable — fallback aléatoire", brNom)
        end
    end

    -- Placer le mini modèle sur le spot (utilise le modèle exact du carry)
    local modeleSlot = placerModeleSlot(touchPart, rarete, modeleSource, baseCentres[uid])
    -- Détruire le modèle pleine taille (le mini clone suffit)
    if modeleSource and modeleSource.Parent then
        pcall(function() modeleSource:Destroy() end)
    end

    -- Fallback définitif : lire CashParSeconde depuis le modèle posé sur le slot.
    -- À ce stade, le modèle vient du carry (CPS déjà multiplié par le spawner).
    if valeurSec == 0 and modeleSlot then
        local cpsSlot = modeleSlot:GetAttribute("CashParSeconde")
        if cpsSlot and cpsSlot > 0 then
            valeurSec = cpsSlot
            if isMutant and entree.rarete.valeur then
                valeurSec = valeurSec * entree.rarete.valeur
            end
        end
    end

    -- Récupérer le type d'élément du Mutant (nil si BR normal)
    local elementType = isMutant and entree.rarete.elementType or nil

    if isMutant then
        -- Réappliquer les effets visuels élémentaires (particles + highlight + emoji)
        appliquerEffetsMutant(modeleSlot, elementType)
        if DropSystem.OnMutantDepose then
            pcall(DropSystem.OnMutantDepose, touchPart, modeleSlot, elementType)
        end
    end

    -- Enregistrer en mémoire locale
    spotsData[uid][touchPart] = {
        spotKey           = spotKey,
        rarete            = rarete,
        brNom             = brNom,        -- nom exact du modèle BR (ex: "Tralalero_Tralala")
        isMutant          = isMutant,     -- pour restauration fidèle après reconnexion
        elementType       = elementType,  -- type élément Mutant ("water"/"fire"/"earth"/"wind")
        mutation          = mutation,     -- "GOLD"|"DIAMANT"|"RAINBOW"|nil
        isToxic           = isToxic or nil,
        valeurSec         = valeurSec,
        modeleSlot        = modeleSlot,
    }

    -- Persister dans playerData pour le DataStore
    -- playerData est accédé via le getData fourni à IncomeSystem
    -- Décision : DropSystem ne connaît pas playerData directement —
    -- il délègue la persistance à IncomeSystem.RecalculerIncome qui reçoit getData.
    -- Voir GetSpotsOccupes → appelé par IncomeSystem pour synchro playerData.

    -- Billboard base (Nom · Rareté · $Prix · $CPS/s — sans timer)
    if modeleSlot then
        pcall(function()
            modeleSlot:SetAttribute("CashParSeconde", valeurSec)
            if isMutant then
                modeleSlot:SetAttribute("IsMutant", true)
                if elementType then modeleSlot:SetAttribute("MutantType", elementType) end
                if mutation    then modeleSlot:SetAttribute("Mutation",   mutation)    end
            end
            if isToxic then modeleSlot:SetAttribute("IsToxic", true) end
        end)
        pcall(BrainrotBillboard.SetupBase, modeleSlot)
    end

    -- Mettre à jour le SurfaceGui
    mettreAJourGui(touchPart, valeurSec)

    -- Ajouter le prompt de récupération + remplacement
    creerPromptRecuperer(touchPart, player)
    creerPromptRemplacer(touchPart, player, rarete)

    -- Informer le joueur
    notifierJoueur(player, "INFO",
        "Brain Rot [" .. rarete .. "] deposited! +" .. valeurSec .. " coins/sec")

    -- Recalculer l'income total du joueur + connecter Button immédiatement
    local IS = getIncomeSystem()
    if IS then
        IS.RecalculerIncome(player, construireSpotsTable(player))
        -- Afficher $offline dès le dépôt (montant = 0, income/s = valeurSec)
        IS.MettreAJourVisuel(touchPart, 0, valeurSec)
        IS.ConnecterButton(player, touchPart, spotKey)
    end

    -- Recalculer tous les prompts : active RemplacerPrompt si carry > 0, désactive DepotPrompt du slot occupé
    DropSystem.RecalculerPrompts(player)

    -- Notifier les systèmes externes (ex : RebirthSystem pour détecter le BR requis)
    if DropSystem.OnSpotChange then pcall(DropSystem.OnSpotChange, player) end

    Logger.info("Drop", "%s a déposé %s sur spot %s", player.Name, rarete, spotKey)
end

-- ============================================================
-- API publique — Récupération
-- ============================================================

function DropSystem.RecupererBrainRot(player, touchPart)
    local uid = player.UserId
    if not spotsData[uid] then return end

    local entree = spotsData[uid][touchPart]
    if not entree then return end

    -- Vérifier si le joueur a de la place dans son carry
    local CarrySystem = require(game:GetService("ServerScriptService").SharedLib.Server.CarrySystem)
    local portes = CarrySystem.GetPortes(player)
    local max    = CarrySystem.GetCapaciteMax(player)

    if #portes >= max then
        notifierJoueur(player, "INFO", "Carry full — empty your carry before retrieving!")
        return
    end

    -- Retirer du spot
    local rarete    = entree.rarete
    local modeleSlot = entree.modeleSlot
    local spotKey   = entree.spotKey
    spotsData[uid][touchPart] = nil

    -- Supprimer les visuels income (billboard + CollectPart) + créditer coins en attente
    local IS = getIncomeSystem()
    if IS then IS.SupprimerSlotVisuel(player, touchPart, spotKey) end

    -- Supprimer le mini modèle
    supprimerModeleSlot(modeleSlot)

    if entree.isMutant and DropSystem.OnMutantRetire then
        pcall(DropSystem.OnMutantRetire, touchPart)
    end

    -- Supprimer le prompt de récupération et recalculer les prompts selon le carry réel
    supprimerPromptRecuperer(player, touchPart)

    -- Cloner le modèle exact via brNom — dossier mutation d'abord, fallback normal
    local modeleRestitue = nil
    local brNom = entree.brNom
    if brNom then
        local dossierRarete = getDossierMutation(entree.mutation, entree.isToxic, rarete)
        if not dossierRarete then
            local brainrots = getBrainrotsFolder()
            dossierRarete = brainrots and (
                brainrots:FindFirstChild(rarete)
                or brainrots:FindFirstChild(string.upper(rarete))
                or brainrots:FindFirstChild(string.lower(rarete):gsub("^%l", string.upper))
            )
        end
        if dossierRarete then
            local function appliquerMutSurClone(c, source)
                if entree.mutation then c:SetAttribute("Mutation", entree.mutation) end
                if entree.isToxic  then c:SetAttribute("IsToxic",  true)            end
                -- Pré-multiplier le CPS (le clone vient du template → CPS de base)
                local mutCPS3 = Config.Fuse and Config.Fuse.MutationCPS
                local baseCPS = source:GetAttribute("CashParSeconde") or 0
                local mult3   = (mutCPS3 and entree.mutation and mutCPS3[entree.mutation])
                             or (entree.isToxic and mutCPS3 and mutCPS3["TOXIC"])
                             or 1
                if mult3 > 1 and baseCPS > 0 then
                    c:SetAttribute("CashParSeconde", math.floor(baseCPS * mult3))
                end
                c.Parent = Workspace
            end
            local brSource = dossierRarete:FindFirstChild(brNom)
            if brSource then
                pcall(function()
                    modeleRestitue = brSource:Clone()
                    appliquerMutSurClone(modeleRestitue, brSource)
                end)
            end
            if not modeleRestitue then
                local premiers = dossierRarete:GetChildren()
                if #premiers > 0 then
                    pcall(function()
                        modeleRestitue = premiers[1]:Clone()
                        appliquerMutSurClone(modeleRestitue, premiers[1])
                    end)
                end
            end
        end
    end

    -- Remettre le BR en TÊTE du carry avec tous les champs mutation préservés
    local rareteObj = {
        nom      = rarete,
        dossier  = rarete,
        isMutant = entree.isMutant,
        mutation = entree.mutation,
        isToxic  = entree.isToxic,
    }
    pcall(CarrySystem.InsererEnTeteCarry, player, modeleRestitue, rareteObj)

    -- Remettre le SurfaceGui à vide
    viderGui(touchPart)

    -- Recalculer l'income
    if IS then
        IS.RecalculerIncome(player, construireSpotsTable(player))
    end

    -- Notifier les systèmes externes (ex : RebirthSystem)
    if DropSystem.OnSpotChange then pcall(DropSystem.OnSpotChange, player) end

    Logger.info("Drop", "%s a récupéré %s du spot %s", player.Name, rarete, spotKey)
end

-- ============================================================
-- API publique — Mise à jour prompts
-- ============================================================

-- Recalcule l'état de tous les prompts de dépôt du joueur
-- (appelé après un changement de carry)
function DropSystem.RecalculerPrompts(player)
    local uid = player.UserId
    if not spotsData[uid] then return end

    local index = spotIndex[uid]
    if not index then return end

    local CarrySystem = require(game:GetService("ServerScriptService").SharedLib.Server.CarrySystem)
    -- Compter uniquement les entrées avec toolRef valide (pas les fantômes)
    local nbPortes = 0
    for _, entree in ipairs(CarrySystem.GetPortes(player)) do
        if entree.toolRef and entree.toolRef.Parent then
            nbPortes = nbPortes + 1
        end
    end

    for _, touchPart in pairs(index) do
        local estOccupe = spotsData[uid][touchPart] ~= nil

        local depotPrompt     = touchPart:FindFirstChild("DepotPrompt")
        local remplacerPrompt = touchPart:FindFirstChild("RemplacerPrompt")

        if depotPrompt then
            pcall(function()
                depotPrompt.Enabled = (not estOccupe) and (nbPortes > 0)
            end)
        end
        if remplacerPrompt then
            -- "Remplacer" : spot occupé ET joueur porte au moins 1 BR
            pcall(function()
                remplacerPrompt.Enabled = estOccupe and (nbPortes > 0)
            end)
        end
    end
end

-- ============================================================
-- API publique — Données
-- ============================================================

-- Retourne la table des spots occupés avec leurs instances
-- Utilisé par IncomeSystem pour mettre à jour les SurfaceGui et playerData
function DropSystem.GetSpotsOccupes(player)
    local uid    = player.UserId
    local result = {}
    if not spotsData[uid] then return result end
    for touchPart, entry in pairs(spotsData[uid]) do
        table.insert(result, {
            touchPart = touchPart,
            spotKey   = entry.spotKey,
            rarete    = entry.rarete,
            valeurSec = entry.valeurSec,
        })
    end
    return result
end

-- Retourne le format DataStore-safe pour sauvegarder dans playerData
function DropSystem.GetSpotsOccupesSerialisables(player)
    local uid    = player.UserId
    local result = {}
    if not spotsData[uid] then return result end
    for _, entry in pairs(spotsData[uid]) do
        result[entry.spotKey] = {
            rarete      = entry.rarete,
            valeurSec   = entry.valeurSec,
            brNom       = entry.brNom,
            isMutant    = entry.isMutant,
            elementType = entry.elementType,
            mutation    = entry.mutation,
            isToxic     = entry.isToxic,
        }
    end
    return result
end

-- Retourne la liste des touchParts libres (non occupés) du joueur
function DropSystem.GetSpotsLibres(player)
    local uid = player.UserId
    if not spotIndex[uid] then return {} end
    local occupes = spotsData[uid] or {}
    local libres  = {}
    for _, touchPart in pairs(spotIndex[uid]) do
        if not occupes[touchPart] then
            table.insert(libres, touchPart)
        end
    end
    return libres
end

-- Dépose un BR directement sur un spot libre, sans passer par le carry
-- Utilisé par le Tracteur pour déposer automatiquement
-- cashParSeconde : attribut CashParSeconde du modèle BR (lu par l'appelant avant dépôt)
function DropSystem.DeposerBRDirect(player, touchPart, rarete, cashParSeconde)
    local uid = player.UserId
    if not spotsData[uid] then return false end

    local index = spotIndex[uid]
    if not index then return false end

    -- Trouver la clé du spot
    local spotKey = nil
    for cle, tp in pairs(index) do
        if tp == touchPart then spotKey = cle break end
    end
    if not spotKey then return false end

    -- Spot déjà occupé ?
    if spotsData[uid][touchPart] then return false end

    local valeurSec = cashParSeconde or 0
    local modeleSlot = placerModeleSlot(touchPart, rarete, nil, baseCentres[uid])

    spotsData[uid][touchPart] = {
        spotKey   = spotKey,
        rarete    = rarete,
        valeurSec = valeurSec,
        modeleSlot = modeleSlot,
    }

    mettreAJourGui(touchPart, valeurSec)
    creerPromptRecuperer(touchPart, player)
    creerPromptRemplacer(touchPart, player, rarete)

    local IS = getIncomeSystem()
    if IS then
        IS.RecalculerIncome(player, construireSpotsTable(player))
        IS.MettreAJourVisuel(touchPart, 0, valeurSec)
        IS.ConnecterButton(player, touchPart, spotKey)
    end

    Logger.info("Drop", "Tracteur a déposé %s sur spot %s", rarete, spotKey)
    return true
end

-- Éjecte le BR d'un spot occupé vers le terrain (clone taille réelle, 15s lifetime)
-- Le joueur peut ensuite le ramasser manuellement
function DropSystem.EjecterBR(player, touchPart)
    local uid = player.UserId
    if not spotsData[uid] then return end

    local entree = spotsData[uid][touchPart]
    if not entree then return end

    local rarete    = entree.rarete
    local modeleSlot = entree.modeleSlot
    local spotKey   = entree.spotKey
    spotsData[uid][touchPart] = nil

    -- Supprimer les visuels income (billboard + CollectPart) + créditer coins en attente
    local IS = getIncomeSystem()
    if IS then IS.SupprimerSlotVisuel(player, touchPart, spotKey) end

    supprimerModeleSlot(modeleSlot)
    supprimerPromptRecuperer(player, touchPart)
    viderGui(touchPart)

    if entree.isMutant and DropSystem.OnMutantRetire then
        pcall(DropSystem.OnMutantRetire, touchPart)
    end

    -- Cloner un modèle taille réelle dans le terrain près du spot
    local brainrots = getBrainrotsFolder()
    if brainrots then
        local dossier = brainrots:FindFirstChild(rarete) or brainrots:FindFirstChild("COMMON")
        if dossier then
            local modeles = dossier:GetChildren()
            if #modeles > 0 then
                local source = modeles[math.random(1, #modeles)]
                local clone  = nil
                pcall(function() clone = source:Clone() end)
                if clone then
                    -- Nettoyer les parasites visuels (VfxInstance, PromptAnchor → cubes gris)
                    nettoyerParasites(clone)
                    -- Position légèrement décalée du spot
                    local offset = Vector3.new(math.random(-4, 4), 1, math.random(-4, 4))
                    local pos    = touchPart.Position + offset
                    clone.Parent = Workspace
                    if clone:IsA("Model") then
                        pcall(function()
                            clone:PivotTo(CFrame.new(pos) * CFrame.Angles(0, math.random() * math.pi * 2, 0))
                        end)
                    end
                    -- Prompt de ramassage manuel
                    local pickupPrompt = Instance.new("ProximityPrompt")
                    pickupPrompt.Name                  = "PickupPrompt"
                    pickupPrompt.ActionText            = "Pick up"
                    pickupPrompt.ObjectText            = rarete
                    pickupPrompt.HoldDuration          = 0
                    pickupPrompt.MaxActivationDistance = 8
                    pickupPrompt.KeyboardKeyCode       = Enum.KeyCode.E
                    pickupPrompt.RequiresLineOfSight   = false
                    local primaryPart = clone:IsA("Model") and (clone.PrimaryPart or clone:FindFirstChildOfClass("BasePart"))
                    if primaryPart then
                        pickupPrompt.Parent = primaryPart
                    else
                        pickupPrompt.Parent = clone
                    end
                    pickupPrompt.Triggered:Connect(function(triggerPlayer)
                        if triggerPlayer ~= player then return end
                        local CS = require(game:GetService("ServerScriptService").SharedLib.Server.CarrySystem)
                        local rareteObj = { nom = rarete, dossier = rarete }
                        pcall(CS.AjouterAuCarry, player, nil, rareteObj)
                        pcall(function() clone:Destroy() end)
                    end)
                    -- Auto-destroy après 15s
                    task.delay(15, function()
                        if clone and clone.Parent then
                            pcall(function() clone:Destroy() end)
                        end
                    end)
                end
            end
        end
    end

    -- Recalculer l'income
    if IS then IS.RecalculerIncome(player, construireSpotsTable(player)) end

    -- Notifier les systèmes externes (ex : RebirthSystem)
    if DropSystem.OnSpotChange then pcall(DropSystem.OnSpotChange, player) end

    Logger.debug("Drop", "BR éjecté : %s du spot %s", rarete, spotKey)
end

-- Retourne la touchPart d'un slot depuis sa clé (utilisé par ActionSlot handler dans Main)
function DropSystem.GetTouchPart(player, spotKey)
    local idx = spotIndex[player.UserId]
    return idx and idx[spotKey] or nil
end

-- ============================================================
-- API publique — Vente directe d'un BR déposé (sans passer par le carry)
-- ============================================================

-- Vend le BR sur touchPart : crédite les coins en attente + coins de vente immédiate,
-- détruit le visuel, libère le slot.
function DropSystem.VendreBR(player, touchPart)
    local uid = player.UserId
    if not spotsData[uid] then return end

    local entree = spotsData[uid][touchPart]
    if not entree then return end

    local rarete    = entree.rarete
    local modeleSlot = entree.modeleSlot
    local spotKey   = entree.spotKey
    spotsData[uid][touchPart] = nil

    -- Récupérer IncomeSystem une seule fois
    local IS = getIncomeSystem()

    -- Créditer les coins en attente ET supprimer les visuels income (billboard + CollectPart)
    if IS then IS.SupprimerSlotVisuel(player, touchPart, spotKey) end

    -- Bonus vente immédiate : valeur de 10s de revenu
    local bonusVente = math.floor(entree.valeurSec * 10)
    if IS and bonusVente > 0 then
        IS.AjouterCoins(player, bonusVente)
    end

    -- Supprimer le mini modèle et les prompts
    supprimerModeleSlot(modeleSlot)
    supprimerPromptRecuperer(player, touchPart)
    viderGui(touchPart)

    if entree.isMutant and DropSystem.OnMutantRetire then
        pcall(DropSystem.OnMutantRetire, touchPart)
    end

    -- Recalculer l'income
    if IS then IS.RecalculerIncome(player, construireSpotsTable(player)) end

    -- Notifier les systèmes externes (ex : RebirthSystem)
    if DropSystem.OnSpotChange then pcall(DropSystem.OnSpotChange, player) end

    notifierJoueur(player, "INFO",
        "Brain Rot [" .. rarete .. "] sold! +" .. tostring(bonusVente) .. " coins")
    Logger.info("Drop", "%s a vendu %s du spot %s", player.Name, rarete, spotKey)
end

-- Nettoie l'état du joueur (appelé à la déconnexion)
function DropSystem.Stop(player)
    local uid = player.UserId
    if spotsData[uid] then
        for touchPart, entry in pairs(spotsData[uid]) do
            -- Supprimer le mini modèle BR (annuler les tweens en forçant transparence=1 avant destroy)
            if entry.modeleSlot and entry.modeleSlot.Parent then
                pcall(function()
                    for _, v in ipairs(entry.modeleSlot:GetDescendants()) do
                        if v:IsA("BasePart") then
                            v.Transparency = 1
                            v.CanCollide   = false
                        end
                    end
                    entry.modeleSlot:Destroy()
                end)
            end
            -- Supprimer les ancres de prompts (AnchorSell, AnchorRetrieve)
            -- et tous les ProximityPrompts directs sur le touchPart
            if touchPart and touchPart.Parent then
                for _, child in ipairs(touchPart:GetChildren()) do
                    if (child:IsA("BasePart") and
                        (child.Name == "AnchorSell" or child.Name == "AnchorRetrieve"))
                    or (child:IsA("ProximityPrompt") and child.Name ~= "DepotPrompt") then
                        pcall(function() child:Destroy() end)
                    end
                end
            end
        end
    end
    -- Nettoyer aussi via spotIndex les slots sans entrée dans spotsData
    -- (cas où le slot était libre mais avait des ancres résiduelles)
    if spotIndex[uid] then
        for _, touchPart in pairs(spotIndex[uid]) do
            if touchPart and touchPart.Parent then
                for _, child in ipairs(touchPart:GetChildren()) do
                    if (child:IsA("BasePart") and
                        (child.Name == "AnchorSell" or child.Name == "AnchorRetrieve"))
                    or (child:IsA("ProximityPrompt") and child.Name ~= "DepotPrompt") then
                        pcall(function() child:Destroy() end)
                    end
                end
            end
        end
    end
    spotsData[uid]   = nil
    spotIndex[uid]   = nil
    baseCentres[uid] = nil
end

return DropSystem
