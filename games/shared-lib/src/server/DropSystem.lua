-- ServerScriptService/Common/DropSystem.lua
-- DobiGames — Dépôt des Brain Rots dans les spots de la base
-- Gère les visuels (mini modèles), SurfaceGui, et la récupération

local DropSystem = {}

-- ============================================================
-- Services
-- ============================================================
local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService      = game:GetService("TweenService")

-- ============================================================
-- Config
-- ============================================================
local Config     = require(ReplicatedStorage.Specialized.GameConfig)
local ProgConfig = Config.ProgressionConfig

-- Valeur en coins par dépôt immédiat (one-shot, distinct du revenu/sec)
-- Décision : le dépôt ne donne PAS de one-shot coins, seulement le revenu passif.
-- Les coins sont générés par IncomeSystem en continu.
-- Cette table reste pour l'affichage texte du prompt avant dépôt.
local VALEUR_PAR_RARETE = Config.ValeurParRarete

-- Facteur de miniaturisation du modèle déposé sur le spot
local MINI_SCALE = 0.35

-- ============================================================
-- Chargement différé de IncomeSystem (évite la dépendance circulaire)
-- DropSystem requiert IncomeSystem, IncomeSystem requiert BaseProgressionSystem —
-- en chargeant après le premier tick, tous les modules sont déjà en mémoire.
-- ============================================================
local _IncomeSystem = nil
local function getIncomeSystem()
    if not _IncomeSystem then
        local ok, m = pcall(require, ReplicatedStorage.SharedLib.Server.IncomeSystem)
        if ok and m then _IncomeSystem = m end
    end
    return _IncomeSystem
end

-- ============================================================
-- État interne par joueur
-- ============================================================
-- spotsData[userId] = {
--   [touchPart] = {
--     spotKey   = "floor_spot" (ex : "1_3"),
--     rarete    = "EPIC",
--     valeurSec = 20,
--     miniModel = Model (instance dans Workspace),
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
    -- Préférer Base_X/Base s'il contient des floors
    local candidat = baseRoot:FindFirstChild("Base")
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
-- Utilitaires — mini modèle Brain Rot
-- ============================================================

-- Clone un mini modèle depuis ServerStorage.Brainrots/[dossier]
-- Décision : on clone un aléatoire parmi les modèles du dossier (cohérent avec CarrySystem)
local function cloneMiniModele(rarete)
    local brainrots = ServerStorage:FindFirstChild("Brainrots")
    if not brainrots then return nil end

    local dossier = brainrots:FindFirstChild(rarete)
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

    -- BillboardGui et ProximityPrompts résiduels (texte "EPIC", prompt de capture)
    for _, v in ipairs(clone:GetDescendants()) do
        if v:IsA("BillboardGui") or v:IsA("ProximityPrompt") then
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
end

-- Place et anime le mini modèle sur un spot
-- modeleSource (optionnel) = le modèle exact porté par le joueur (prioritaire sur ServerStorage)
local function placerMiniModele(touchPart, rarete, modeleSource)
    local clone

    -- Priorité : cloner le modèle porté (évite les cubes gris si ServerStorage mal configuré)
    if modeleSource and modeleSource.Parent then
        pcall(function() clone = modeleSource:Clone() end)
        -- Supprimer le modèle détaché flottant dans le Workspace
        pcall(function() modeleSource:Destroy() end)
        print("[DropSystem] Mini modèle issu du carry (modèle exact)")
    end

    -- Fallback : clone aléatoire depuis ServerStorage
    if not clone then
        clone = cloneMiniModele(rarete)
    end

    if not clone then return nil end

    -- Nettoyer les parasites AVANT tout autre traitement
    -- (PromptAnchor, VfxInstance, constraints → cubes gris si laissés)
    nettoyerParasites(clone)

    -- Mise à l'échelle réduite
    if clone:IsA("Model") then
        pcall(function() clone:ScaleTo(MINI_SCALE) end)
    end

    -- Position : au-dessus du TouchPart
    local pos = touchPart.Position + Vector3.new(0, touchPart.Size.Y * 0.5 + 0.6, 0)

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

    -- Pivoter au bon endroit
    if clone:IsA("Model") then
        pcall(function()
            clone:PivotTo(CFrame.new(pos) * CFrame.Angles(0, math.random() * math.pi * 2, 0))
        end)
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

-- Supprime le mini modèle avec un fade out
local function supprimerMiniModele(miniModel)
    if not miniModel or not miniModel.Parent then return end
    local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad)
    local parts     = {}
    for _, v in ipairs(miniModel:GetDescendants()) do
        if v:IsA("BasePart") then table.insert(parts, v) end
    end
    for _, part in ipairs(parts) do
        if part and part.Parent then
            pcall(function() TweenService:Create(part, tweenInfo, { Transparency = 1 }):Play() end)
        end
    end
    task.delay(0.25, function()
        if miniModel and miniModel.Parent then
            pcall(function() miniModel:Destroy() end)
        end
    end)
end

-- ============================================================
-- Utilitaires — ProximityPrompts
-- ============================================================

-- PP unique "Manage" sur TouchPart : ouvre menu Retrieve/Sell côté client
local function creerPromptRecuperer(touchPart, player)
    -- Supprimer les anciens prompts (Manage, Retrieve, Vendre — compatibilité)
    for _, child in ipairs(touchPart:GetChildren()) do
        if child:IsA("ProximityPrompt")
            and child.Name ~= "DepotPrompt"
            and child.Name ~= "RemplacerPrompt" then
            pcall(function() child:Destroy() end)
        end
    end

    local uid    = player.UserId
    local entree = spotsData[uid] and spotsData[uid][touchPart]
    if not entree then return end

    local rareteNom = entree.rarete or "BR"
    local spotKey   = entree.spotKey

    -- PP unique "Manage" (touche E, instant) → envoie menu au client
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name                  = "ManagePrompt"
    prompt.ActionText            = "Manage"
    prompt.ObjectText            = "🎮 " .. rareteNom
    prompt.HoldDuration          = 0
    prompt.MaxActivationDistance = 10
    prompt.KeyboardKeyCode       = Enum.KeyCode.E
    prompt.RequiresLineOfSight   = false
    prompt.Parent                = touchPart

    prompt.Triggered:Connect(function(triggerPlayer)
        if triggerPlayer ~= player then return end
        local OuvrirMenuSlot = ReplicatedStorage:FindFirstChild("OuvrirMenuSlot")
        if OuvrirMenuSlot then
            pcall(function()
                OuvrirMenuSlot:FireClient(triggerPlayer, {
                    spotKey  = spotKey,
                    rarete   = entree.rarete,
                    brNom    = entree.brNom or rareteNom,
                    income   = entree.valeurSec or 0,
                })
            end)
        end
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
        local CS     = require(ReplicatedStorage.SharedLib.Server.CarrySystem)
        local portes = CS.GetPortes(player)
        if #portes == 0 then
            notifierJoueur(player, "INFO", "🎒 You are not carrying any Brain Rot!")
            return
        end
        -- Éjecter le BR actuel dans le champ, puis déposer le BR porté
        DropSystem.EjecterBR(player, touchPart)
        DropSystem.DeposerBrainRots(player, touchPart)
    end)
end

local function supprimerPromptRecuperer(touchPart)
    -- Supprimer tous les PP de gestion (compatibilité ancien nommage inclus)
    for _, name in ipairs({ "ManagePrompt", "RecupererPrompt", "VendrePrompt", "RemplacerPrompt" }) do
        local p = touchPart:FindFirstChild(name)
        if p then pcall(function() p:Destroy() end) end
    end

    local depotPrompt = touchPart:FindFirstChild("DepotPrompt")
    if depotPrompt then pcall(function() depotPrompt.Enabled = true end) end
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
        warn("[DropSystem] BaseFolder introuvable pour Base_" .. tostring(baseIndex))
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
                        warn("[DropSystem] Aucune Part trouvée dans " .. spotModel.Name)
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
            -- Utiliser valeurSec sauvegardée (préserve le multiplicateur Mutant)
            local valeur   = info.valeurSec or (VALEUR_PAR_RARETE[info.rarete] or 1)
            local isMutant = info.isMutant == true

            -- Tenter de restaurer le modèle exact via brNom
            -- Les modèles Mutant (_MUTANT) n'existent pas dans ServerStorage → fallback rareté
            local modeleSource = nil
            if info.brNom and not isMutant then
                local brainrots = ServerStorage:FindFirstChild("Brainrots")
                local dossier   = brainrots and brainrots:FindFirstChild(info.rarete)
                local brSource  = dossier and dossier:FindFirstChild(info.brNom)
                if brSource then
                    pcall(function() modeleSource = brSource:Clone() end)
                end
            end

            local miniModel = placerMiniModele(touchPart, info.rarete, modeleSource)

            -- Restaurer le visuel Mutant (spot doré + particules)
            if isMutant then
                local spotColor = (Config.FlowerPotConfig
                    and Config.FlowerPotConfig.spotMutantCouleur)
                    or Color3.fromRGB(255, 215, 0)
                pcall(function()
                    touchPart.Color = spotColor
                    local light = touchPart:FindFirstChild("MutantLight")
                               or Instance.new("PointLight", touchPart)
                    light.Name       = "MutantLight"
                    light.Brightness = 2
                    light.Range      = 10
                    light.Color      = Color3.fromRGB(255, 215, 0)
                end)
                if miniModel then
                    pcall(function()
                        local root = miniModel.PrimaryPart
                                  or miniModel:FindFirstChildWhichIsA("BasePart")
                        if root then
                            local p = Instance.new("ParticleEmitter", root)
                            p.Rate     = 8
                            p.Lifetime = NumberRange.new(0.5, 1.2)
                            p.Speed    = NumberRange.new(2, 4)
                            p.Color    = ColorSequence.new(Color3.fromRGB(255, 215, 0))
                            p.Size     = NumberSequence.new(0.2)
                            p.LightEmission = 0.8
                        end
                    end)
                end
            end

            spotsData[uid][touchPart] = {
                spotKey   = spotKey,
                rarete    = info.rarete,
                brNom     = info.brNom,
                isMutant  = isMutant,
                valeurSec = valeur,
                miniModel = miniModel,
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
-- API publique — Init
-- ============================================================

-- Initialise DropSystem pour un joueur (appelé depuis Main.server.lua après chargement des données)
function DropSystem.Init(player, baseIndex, playerData)
    spotsData[player.UserId] = {}

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
    print("[DropSystem] SpotIndex mis à jour : " .. spotKey .. " → " .. player.Name)
end

-- Enregistre un spot nouvellement débloqué depuis un spotModel (API alternative)
-- Trouve la touchPart automatiquement et l'ajoute au spotIndex
function DropSystem.InitSpot(player, spotModel, spotKey)
    if not spotModel then return end
    local touchPart = trouverTouchPart(spotModel)
    if not touchPart then
        warn("[DropSystem] InitSpot : aucune Part trouvée dans " .. spotModel.Name)
        return
    end
    if spotKey then
        DropSystem.AjouterSpotIndex(player, spotKey, touchPart)
    end
    print("[DropSystem] InitSpot : " .. spotModel.Name .. " enregistré pour " .. player.Name)
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
        notifierJoueur(player, "INFO", "❌ This spot doesn't belong to your base!")
        return
    end

    -- Spot déjà occupé ?
    if spotsData[uid][touchPart] then
        notifierJoueur(player, "INFO", "🔒 This spot is already occupied — retrieve the Brain Rot first.")
        return
    end

    -- Récupérer le carry du joueur via CarrySystem
    local CarrySystem = require(ReplicatedStorage.SharedLib.Server.CarrySystem)
    local portes = CarrySystem.GetPortes(player)
    if #portes == 0 then return end

    -- Prendre le PREMIER Brain Rot du carry uniquement (un BR par spot)
    -- Décision : on dépose 1 BR à la fois sur un spot. Le joueur doit re-trigger
    -- pour chaque spot supplémentaire. Cela encourage l'activité et valorise le gameplay.
    local entree = portes[1]
    if not entree or not entree.rarete then return end

    local rarete = entree.rarete.nom or "COMMON"

    -- Retirer ce BR du carry (on utilise ViderCarry puis re-add les autres)
    -- Décision : ViderCarry vide tout, puis on remet les BR restants en mémoire.
    -- En pratique le joueur dépose 1 BR par interaction — carry restant réattaché.
    local tous = CarrySystem.ViderCarry(player)
    -- tous[1] = { modele, rarete } à déposer, tous[2..n] = à conserver
    local modeleDepose = tous[1] and tous[1].modele  -- vrai modèle porté (évite cube gris)
    for i = 2, #tous do
        local restant = tous[i]
        if restant and restant.rarete then
            -- Remettre les BR restants dans le carry
            pcall(CarrySystem.AjouterAuCarry, player, restant.modele, restant.rarete)
        end
    end

    -- Calculer la valeur par seconde
    local isMutant  = entree.rarete.isMutant == true
    local valeurSec = VALEUR_PAR_RARETE[rarete] or 1
    -- Multiplier par le multiplicateur si BR Mutant
    if isMutant and entree.rarete.valeur then
        valeurSec = valeurSec * entree.rarete.valeur
    end

    -- Mémoriser le nom original du BR (Attribute posé par SpawnManager/CommunSpawner)
    -- Le modèle est renommé "BR_1_42" / "CC_MYTHIC_7" au spawn → utiliser OriginalName
    -- pour retrouver le bon modèle dans ServerStorage lors de la restauration
    local brNom = nil
    if modeleDepose then
        brNom = modeleDepose:GetAttribute("OriginalName") or modeleDepose.Name
    end

    -- Placer le mini modèle sur le spot (utilise le modèle exact du carry)
    local miniModel = placerMiniModele(touchPart, rarete, modeleDepose)

    -- Spot doré si BR Mutant
    if isMutant then
        local spotColor = (Config.FlowerPotConfig and Config.FlowerPotConfig.spotMutantCouleur)
                       or Color3.fromRGB(255, 215, 0)
        pcall(function()
            touchPart.Color = spotColor
            local light = touchPart:FindFirstChild("MutantLight")
                       or Instance.new("PointLight", touchPart)
            light.Name       = "MutantLight"
            light.Brightness = 2
            light.Range      = 10
            light.Color      = Color3.fromRGB(255, 215, 0)
        end)
        -- Ajouter particules dorées sur le mini modèle
        if miniModel then
            pcall(function()
                local root = miniModel.PrimaryPart
                          or miniModel:FindFirstChildWhichIsA("BasePart")
                if root then
                    local p = Instance.new("ParticleEmitter", root)
                    p.Rate     = 8
                    p.Lifetime = NumberRange.new(0.5, 1.2)
                    p.Speed    = NumberRange.new(2, 4)
                    p.Color    = ColorSequence.new(Color3.fromRGB(255, 215, 0))
                    p.Size     = NumberSequence.new(0.2)
                    p.LightEmission = 0.8
                end
            end)
        end
    end

    -- Enregistrer en mémoire locale
    spotsData[uid][touchPart] = {
        spotKey   = spotKey,
        rarete    = rarete,
        brNom     = brNom,      -- nom exact du modèle BR (ex: "Tralalero_Tralala")
        isMutant  = isMutant,   -- pour restauration fidèle après reconnexion
        valeurSec = valeurSec,
        miniModel = miniModel,
    }

    -- Persister dans playerData pour le DataStore
    -- playerData est accédé via le getData fourni à IncomeSystem
    -- Décision : DropSystem ne connaît pas playerData directement —
    -- il délègue la persistance à IncomeSystem.RecalculerIncome qui reçoit getData.
    -- Voir GetSpotsOccupes → appelé par IncomeSystem pour synchro playerData.

    -- Mettre à jour le SurfaceGui
    mettreAJourGui(touchPart, valeurSec)

    -- Ajouter le prompt de récupération + remplacement
    creerPromptRecuperer(touchPart, player)
    creerPromptRemplacer(touchPart, player, rarete)

    -- Informer le joueur
    notifierJoueur(player, "INFO",
        "✅ Brain Rot [" .. rarete .. "] deposited! +" .. valeurSec .. " coins/sec")

    -- Recalculer l'income total du joueur + connecter Button immédiatement
    local IS = getIncomeSystem()
    if IS then
        IS.RecalculerIncome(player, construireSpotsTable(player))
        -- Afficher $offline dès le dépôt (montant = 0, income/s = valeurSec)
        IS.MettreAJourVisuel(touchPart, 0, valeurSec)
        IS.ConnecterButton(player, touchPart, spotKey)
    end

    print("[DropSystem] " .. player.Name .. " a déposé " .. rarete .. " sur spot " .. spotKey)
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
    local CarrySystem = require(ReplicatedStorage.SharedLib.Server.CarrySystem)
    local portes = CarrySystem.GetPortes(player)
    local max    = CarrySystem.GetCapaciteMax(player)

    if #portes >= max then
        notifierJoueur(player, "INFO", "🎒 Carry full — empty your carry before retrieving!")
        return
    end

    -- Retirer du spot
    local rarete    = entree.rarete
    local miniModel = entree.miniModel
    local spotKey   = entree.spotKey
    spotsData[uid][touchPart] = nil

    -- Supprimer les visuels income (billboard + CollectPart) + créditer coins en attente
    local IS = getIncomeSystem()
    if IS then IS.SupprimerSlotVisuel(player, touchPart, spotKey) end

    -- Supprimer le mini modèle
    supprimerMiniModele(miniModel)

    -- Supprimer le prompt de récupération et réactiver le DepotPrompt
    supprimerPromptRecuperer(touchPart)

    -- Cloner le modèle exact depuis ServerStorage via brNom (évite un BR aléatoire au retrieve)
    local modeleRestitue = nil
    local brNom = entree.brNom
    if brNom then
        local brainrots = ServerStorage:FindFirstChild("Brainrots")
        local dossierRarete = brainrots and brainrots:FindFirstChild(rarete)
        if dossierRarete then
            local brSource = dossierRarete:FindFirstChild(brNom)
            if brSource then
                pcall(function() modeleRestitue = brSource:Clone() end)
            end
            -- Fallback : premier BR de la rareté si le modèle exact est introuvable
            if not modeleRestitue then
                local premiers = dossierRarete:GetChildren()
                if #premiers > 0 then
                    pcall(function() modeleRestitue = premiers[1]:Clone() end)
                end
            end
        end
    end

    -- Remettre le BR dans le carry du joueur (avec le bon modèle visuel)
    local rareteObj = { nom = rarete, dossier = rarete }
    pcall(CarrySystem.AjouterAuCarry, player, modeleRestitue, rareteObj)

    -- Remettre le SurfaceGui à vide
    viderGui(touchPart)

    -- Recalculer l'income
    if IS then
        IS.RecalculerIncome(player, construireSpotsTable(player))
    end

    notifierJoueur(player, "INFO", "↩️ Brain Rot [" .. rarete .. "] retrieved to your carry!")
    print("[DropSystem] " .. player.Name .. " a récupéré " .. rarete .. " du spot " .. spotKey)
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

    local CarrySystem = require(ReplicatedStorage.SharedLib.Server.CarrySystem)
    local nbPortes = #CarrySystem.GetPortes(player)

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
            rarete    = entry.rarete,
            valeurSec = entry.valeurSec,
            brNom     = entry.brNom,
            isMutant  = entry.isMutant,
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
function DropSystem.DeposerBRDirect(player, touchPart, rarete)
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

    local valeurSec = VALEUR_PAR_RARETE[rarete] or 1
    local miniModel = placerMiniModele(touchPart, rarete)

    spotsData[uid][touchPart] = {
        spotKey   = spotKey,
        rarete    = rarete,
        valeurSec = valeurSec,
        miniModel = miniModel,
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

    print("[DropSystem] Tracteur a déposé " .. rarete .. " sur spot " .. spotKey)
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
    local miniModel = entree.miniModel
    local spotKey   = entree.spotKey
    spotsData[uid][touchPart] = nil

    -- Supprimer les visuels income (billboard + CollectPart) + créditer coins en attente
    local IS = getIncomeSystem()
    if IS then IS.SupprimerSlotVisuel(player, touchPart, spotKey) end

    supprimerMiniModele(miniModel)
    supprimerPromptRecuperer(touchPart)
    viderGui(touchPart)

    -- Cloner un modèle taille réelle dans le terrain près du spot
    local brainrots = ServerStorage:FindFirstChild("Brainrots")
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
                        local CS = require(ReplicatedStorage.SharedLib.Server.CarrySystem)
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

    print("[DropSystem] BR éjecté : " .. rarete .. " du spot " .. spotKey)
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
    local miniModel = entree.miniModel
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
    supprimerMiniModele(miniModel)
    supprimerPromptRecuperer(touchPart)
    viderGui(touchPart)

    -- Recalculer l'income
    if IS then IS.RecalculerIncome(player, construireSpotsTable(player)) end

    notifierJoueur(player, "INFO",
        "💰 Brain Rot [" .. rarete .. "] sold! +" .. tostring(bonusVente) .. " coins")
    print("[DropSystem] " .. player.Name .. " a vendu " .. rarete .. " du spot " .. spotKey)
end

-- Nettoie l'état du joueur (appelé à la déconnexion)
function DropSystem.Stop(player)
    local uid = player.UserId
    if spotsData[uid] then
        -- Supprimer tous les mini modèles
        for _, entry in pairs(spotsData[uid]) do
            if entry.miniModel then
                pcall(function() entry.miniModel:Destroy() end)
            end
        end
    end
    spotsData[uid] = nil
    spotIndex[uid] = nil
end

return DropSystem
