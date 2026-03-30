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
local Config = require(
    ReplicatedStorage:FindFirstChild("GameConfig")
    or ReplicatedStorage.Specialized.GameConfig
)
local ProgConfig = Config.ProgressionConfig

-- Valeur en coins par dépôt immédiat (one-shot, distinct du revenu/sec)
-- Décision : le dépôt ne donne PAS de one-shot coins, seulement le revenu passif.
-- Les coins sont générés par IncomeSystem en continu.
-- Cette table reste pour l'affichage texte du prompt avant dépôt.
local VALEUR_PAR_RARETE = Config.ValeurParRarete


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

-- Clone un modèle depuis ServerStorage.Brainrots/[dossier]
-- Décision : on clone un aléatoire parmi les modèles du dossier (cohérent avec CarrySystem)
local function clonerModeleSlot(rarete)
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

-- Place et anime le modèle sur un spot (taille originale)
-- modeleSource (optionnel) = le modèle exact porté par le joueur (prioritaire sur ServerStorage)
local function placerModeleSlot(touchPart, rarete, modeleSource)
    local clone

    -- Priorité : cloner le modèle porté (évite les cubes gris si ServerStorage mal configuré)
    if modeleSource and modeleSource.Parent then
        pcall(function() clone = modeleSource:Clone() end)
        -- Supprimer le modèle détaché flottant dans le Workspace
        pcall(function() modeleSource:Destroy() end)
        print("[DropSystem] Modèle issu du carry (modèle exact)")
    end

    -- Fallback : clone aléatoire depuis ServerStorage
    if not clone then
        clone = clonerModeleSlot(rarete)
    end

    if not clone then return nil end

    -- Nettoyer les parasites AVANT tout autre traitement
    -- (PromptAnchor, VfxInstance, constraints → cubes gris si laissés)
    nettoyerParasites(clone)

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
            notifierJoueur(player, "INFO", "🎒 You are not carrying any Brain Rot!")
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

            -- Tenter de restaurer le modèle exact via brNom (mutants inclus)
            local modeleSource = nil
            if info.brNom then
                local brainrots = ServerStorage:FindFirstChild("Brainrots")
                local dossier   = brainrots and brainrots:FindFirstChild(info.rarete)
                local brSource  = dossier and dossier:FindFirstChild(info.brNom)
                if brSource then
                    pcall(function()
                        modeleSource = brSource:Clone()
                        -- CRITIQUE : Parent doit être non-nil sinon placerMiniModele
                        -- interprète le modèle comme invalide et clone un BR aléatoire
                        modeleSource.Parent = Workspace
                    end)
                else
                    -- brNom sauvegardé mais modèle introuvable dans ServerStorage
                    -- (renommage Studio ou modèle supprimé) → fallback déterministe
                    warn("[DropSystem] Restauration : modèle '" .. tostring(info.brNom)
                        .. "' introuvable dans ServerStorage/" .. tostring(info.rarete)
                        .. " → fallback premier modèle du dossier")
                end
            elseif not isMutant then
                -- brNom nil : donnée ancienne (sauvegardée avant le fix onCapture)
                -- Fallback déterministe sur modeles[1] pour éviter le changement
                -- de BR à chaque reconnexion (math.random dans clonerModeleSlot)
                local brainrots = ServerStorage:FindFirstChild("Brainrots")
                local dossier   = brainrots and brainrots:FindFirstChild(info.rarete)
                if dossier then
                    local modeles = dossier:GetChildren()
                    if #modeles > 0 then
                        pcall(function()
                            modeleSource = modeles[1]:Clone()
                            modeleSource.Parent = Workspace
                        end)
                        print("[DropSystem] Restauration : brNom nil pour " .. tostring(info.rarete)
                            .. " → modèle fixe '" .. modeles[1].Name .. "' (donnée ancienne)")
                    end
                end
            end

            local modeleSlot = placerModeleSlot(touchPart, info.rarete, modeleSource)

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
                if modeleSlot then
                    pcall(function()
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
                    end)
                end
            end

            spotsData[uid][touchPart] = {
                spotKey   = spotKey,
                rarete    = info.rarete,
                brNom     = info.brNom,
                isMutant  = isMutant,
                valeurSec = valeur,
                modeleSlot = modeleSlot,
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

    local rarete = entree.rarete.nom or "COMMON"

    -- Retirer ce BR du carry (on utilise ViderCarry puis re-add les autres)
    local tous = CarrySystem.ViderCarry(player)
    -- Guard renforcé : vérifier qu'au moins 1 entrée a un vrai modèle (pas seulement fantômes)
    local aModeleValide = false
    for _, item in ipairs(tous) do
        if item.modele then aModeleValide = true; break end
    end
    if not aModeleValide then
        warn("[DropSystem] DeposerBrainRots : carry sans modèle réel pour " .. player.Name .. " — dépôt annulé")
        return
    end
    -- tous[indexADeposer] = BR à déposer, les autres = à conserver
    local modeleDepose = tous[indexADeposer] and tous[indexADeposer].modele
    for i, restant in ipairs(tous) do
        if i ~= indexADeposer and restant and restant.rarete then
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
    local modeleSlot = placerModeleSlot(touchPart, rarete, modeleDepose)
    -- Détruire le modèle pleine taille extrait du carry (le mini clone suffit)
    if modeleDepose and modeleDepose.Parent then
        pcall(function() modeleDepose:Destroy() end)
    end

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
        if modeleSlot then
            pcall(function()
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
        modeleSlot = modeleSlot,
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

    -- Recalculer tous les prompts : active RemplacerPrompt si carry > 0, désactive DepotPrompt du slot occupé
    DropSystem.RecalculerPrompts(player)

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
    local CarrySystem = require(game:GetService("ServerScriptService").SharedLib.Server.CarrySystem)
    local portes = CarrySystem.GetPortes(player)
    local max    = CarrySystem.GetCapaciteMax(player)

    if #portes >= max then
        notifierJoueur(player, "INFO", "🎒 Carry full — empty your carry before retrieving!")
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

    -- Supprimer le prompt de récupération et recalculer les prompts selon le carry réel
    supprimerPromptRecuperer(player, touchPart)

    -- Cloner le modèle exact depuis ServerStorage via brNom (évite un BR aléatoire au retrieve)
    local modeleRestitue = nil
    local brNom = entree.brNom
    if brNom then
        local brainrots = ServerStorage:FindFirstChild("Brainrots")
        local dossierRarete = brainrots and brainrots:FindFirstChild(rarete)
        if dossierRarete then
            local brSource = dossierRarete:FindFirstChild(brNom)
            if brSource then
                pcall(function()
                    modeleRestitue = brSource:Clone()
                    -- CRITIQUE : Parent doit être non-nil sinon InsererEnTeteCarry
                    -- interprète le modèle comme invalide et clone un BR aléatoire
                    modeleRestitue.Parent = Workspace
                end)
            end
            -- Fallback : premier BR de la rareté si le modèle exact est introuvable
            if not modeleRestitue then
                local premiers = dossierRarete:GetChildren()
                if #premiers > 0 then
                    pcall(function()
                        modeleRestitue = premiers[1]:Clone()
                        modeleRestitue.Parent = Workspace
                    end)
                end
            end
        end
    end

    -- Remettre le BR en TÊTE du carry (position 1) pour qu'il soit déposé en premier
    -- isMutant préservé pour que le re-dépôt calcule le bon income
    local rareteObj = { nom = rarete, dossier = rarete, isMutant = entree.isMutant }
    pcall(CarrySystem.InsererEnTeteCarry, player, modeleRestitue, rareteObj)

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
    local modeleSlot = placerModeleSlot(touchPart, rarete)

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
    local modeleSlot = entree.modeleSlot
    local spotKey   = entree.spotKey
    spotsData[uid][touchPart] = nil

    -- Supprimer les visuels income (billboard + CollectPart) + créditer coins en attente
    local IS = getIncomeSystem()
    if IS then IS.SupprimerSlotVisuel(player, touchPart, spotKey) end

    supprimerModeleSlot(modeleSlot)
    supprimerPromptRecuperer(player, touchPart)
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
            if entry.modeleSlot then
                pcall(function() entry.modeleSlot:Destroy() end)
            end
        end
    end
    spotsData[uid] = nil
    spotIndex[uid] = nil
end

return DropSystem
