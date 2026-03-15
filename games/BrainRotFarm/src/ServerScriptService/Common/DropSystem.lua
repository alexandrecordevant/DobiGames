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
local VALEUR_PAR_RARETE = {
    COMMON       = 1,
    OG           = 3,
    RARE         = 8,
    EPIC         = 20,
    LEGENDARY    = 60,
    MYTHIC       = 200,
    SECRET       = 500,
    BRAINROT_GOD = 2000,
}

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
        local ok, m = pcall(require, ServerScriptService.Common.IncomeSystem)
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

-- Place et anime le mini modèle sur un spot
-- Le modèle est ancré au centre du TouchPart + léger offset vertical
local function placerMiniModele(touchPart, rarete)
    local clone = cloneMiniModele(rarete)
    if not clone then return nil end

    -- Mise à l'échelle réduite
    if clone:IsA("Model") then
        pcall(function() clone:ScaleTo(MINI_SCALE) end)
    end

    -- Position : au-dessus du TouchPart
    local pos = touchPart.Position + Vector3.new(0, touchPart.Size.Y * 0.5 + 0.6, 0)

    -- Anchorer toutes les BaseParts et rendre non-collidables
    for _, v in ipairs(clone:GetDescendants()) do
        if v:IsA("BasePart") then
            pcall(function()
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

    -- Fade in en 0.3s
    local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    for _, v in ipairs(clone:GetDescendants()) do
        if v:IsA("BasePart") then
            pcall(function()
                TweenService:Create(v, tweenInfo, { Transparency = 0 }):Play()
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

-- Ajoute ou met à jour le prompt de récupération sur un spot occupé
local function creerPromptRecuperer(touchPart, player)
    -- Supprimer l'ancien si présent
    local ancien = touchPart:FindFirstChild("RecupererPrompt")
    if ancien then ancien:Destroy() end

    local prompt = Instance.new("ProximityPrompt")
    prompt.Name                  = "RecupererPrompt"
    prompt.ActionText            = "Récupérer"
    prompt.ObjectText            = "Brain Rot"
    prompt.HoldDuration          = 0
    prompt.MaxActivationDistance = 10
    prompt.KeyboardKeyCode       = Enum.KeyCode.E
    prompt.RequiresLineOfSight   = false
    prompt.Parent                = touchPart

    prompt.Triggered:Connect(function(triggerPlayer)
        if triggerPlayer ~= player then return end
        DropSystem.RecupererBrainRot(player, touchPart)
    end)

    -- Désactiver le DepotPrompt tant que le spot est occupé
    local depotPrompt = touchPart:FindFirstChild("DepotPrompt")
    if depotPrompt then
        pcall(function() depotPrompt.Enabled = false end)
    end
end

local function supprimerPromptRecuperer(touchPart)
    local ancien = touchPart:FindFirstChild("RecupererPrompt")
    if ancien then pcall(function() ancien:Destroy() end) end

    -- Réactiver le DepotPrompt
    local depotPrompt = touchPart:FindFirstChild("DepotPrompt")
    if depotPrompt then
        pcall(function() depotPrompt.Enabled = true end)
    end
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
                    local touchPart = spotModel:FindFirstChild("TouchPart")
                    if touchPart then
                        local cle = floorDef.index .. "_" .. spotNum
                        spotIndex[player.UserId][cle] = touchPart
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
            local valeur    = VALEUR_PAR_RARETE[info.rarete] or 1
            local miniModel = placerMiniModele(touchPart, info.rarete)

            spotsData[uid][touchPart] = {
                spotKey   = spotKey,
                rarete    = info.rarete,
                valeurSec = valeur,
                miniModel = miniModel,
            }

            mettreAJourGui(touchPart, valeur)
            creerPromptRecuperer(touchPart, player)
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

-- Enregistre un spot nouvellement débloqué (appelé depuis BaseProgressionSystem via hook dans Main)
function DropSystem.InitSpot(player, touchPart)
    -- Rien à faire ici car le scan initial couvre tous les spots du fichier config.
    -- Cette fonction est conservée pour l'API publique et les hooks futurs.
    -- Le touchPart est déjà dans spotIndex s'il correspond à un spot de la config.
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
        notifierJoueur(player, "INFO", "❌ Ce spot n'appartient pas à ta base !")
        return
    end

    -- Spot déjà occupé ?
    if spotsData[uid][touchPart] then
        notifierJoueur(player, "INFO", "🔒 Ce spot est déjà occupé — récupère le Brain Rot d'abord.")
        return
    end

    -- Récupérer le carry du joueur via CarrySystem
    local CarrySystem = require(ServerScriptService.Common.CarrySystem)
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
    -- Roblox ne permet pas de retirer un seul élément du carry proprement
    -- sans reconstruire la liste. On adopte l'approche "tout vider, re-attach".
    -- En pratique le joueur dépose 1 BR par interaction — carry restant réattaché.
    local tous = CarrySystem.ViderCarry(player)
    -- tous[1] = BR déposé, tous[2..n] = à conserver
    -- Note : ViderCarry détache les modèles. Ils sont dans Workspace mais libres.
    -- Les BR "à conserver" seront ré-attachés via RamasserBR en cascade.
    for i = 2, #tous do
        local restant = tous[i]
        if restant and restant.rarete then
            -- Ré-attacher au carry (RamasserBR accepte un modèle existant)
            pcall(CarrySystem.RamasserBR, player, restant.rarete, restant.modele)
        end
    end

    -- Calculer la valeur par seconde
    local valeurSec = VALEUR_PAR_RARETE[rarete] or 1

    -- Placer le mini modèle sur le spot
    local miniModel = placerMiniModele(touchPart, rarete)

    -- Enregistrer en mémoire locale
    spotsData[uid][touchPart] = {
        spotKey   = spotKey,
        rarete    = rarete,
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

    -- Ajouter le prompt de récupération (désactive automatiquement le DepotPrompt)
    creerPromptRecuperer(touchPart, player)

    -- Informer le joueur
    notifierJoueur(player, "INFO",
        "✅ Brain Rot [" .. rarete .. "] déposé ! +" .. valeurSec .. " coins/sec")

    -- Recalculer l'income total du joueur
    local IS = getIncomeSystem()
    if IS then
        IS.RecalculerIncome(player, construireSpotsTable(player))
    end

    -- Mettre à jour le HUD
    local UpdateHUD = ReplicatedStorage:FindFirstChild("UpdateHUD")
    if UpdateHUD then
        -- On n'a pas accès à playerData ici → Main le mettra à jour via IncomeSystem
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
    local CarrySystem = require(ServerScriptService.Common.CarrySystem)
    local portes = CarrySystem.GetPortes(player)
    local max    = CarrySystem.GetCapaciteMax(player)

    if #portes >= max then
        notifierJoueur(player, "INFO", "🎒 Sac plein — vide ton carry avant de récupérer !")
        return
    end

    -- Retirer du spot
    local rarete    = entree.rarete
    local miniModel = entree.miniModel
    spotsData[uid][touchPart] = nil

    -- Supprimer le mini modèle
    supprimerMiniModele(miniModel)

    -- Supprimer le prompt de récupération et réactiver le DepotPrompt
    supprimerPromptRecuperer(touchPart)

    -- Remettre le BR dans le carry du joueur
    local rareteObj = { nom = rarete, dossier = rarete }
    pcall(CarrySystem.RamasserBR, player, rareteObj, nil)

    -- Remettre le SurfaceGui à vide
    viderGui(touchPart)

    -- Recalculer l'income
    local IS = getIncomeSystem()
    if IS then
        IS.RecalculerIncome(player, construireSpotsTable(player))
    end

    notifierJoueur(player, "INFO", "↩️ Brain Rot [" .. rarete .. "] récupéré dans ton sac !")
    print("[DropSystem] " .. player.Name .. " a récupéré " .. rarete .. " du spot " .. entree.spotKey)
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

    local CarrySystem = require(ServerScriptService.Common.CarrySystem)
    local nbPortes = #CarrySystem.GetPortes(player)

    for _, touchPart in pairs(index) do
        local depotPrompt = touchPart:FindFirstChild("DepotPrompt")
        if depotPrompt then
            -- Désactiver si spot occupé OU carry vide
            local estOccupe = spotsData[uid][touchPart] ~= nil
            pcall(function()
                depotPrompt.Enabled = (not estOccupe) and (nbPortes > 0)
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
        }
    end
    return result
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
