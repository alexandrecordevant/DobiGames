-- CarryServer.lua
-- ServerScriptService/CarryServer
-- Gère toute la logique serveur du système carry brainrot :
--   - Création des RemoteEvents
--   - Initialisation des ProximityPrompts sur les brainrots
--   - Pickup / drop / reward
--   - Rescue en cas de déconnexion ou CharacterRemoving

local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local Workspace          = game:GetService("Workspace")

-- ─── Config ──────────────────────────────────────────────────────────────────
local CarryConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CarryConfig"))

-- ─── RemoteEvents ─────────────────────────────────────────────────────────────
-- Création d'un dossier CarryEvents dans ReplicatedStorage pour regrouper les events.
local eventsFolder = ReplicatedStorage:FindFirstChild("CarryEvents")
if not eventsFolder then
    eventsFolder = Instance.new("Folder")
    eventsFolder.Name = "CarryEvents"
    eventsFolder.Parent = ReplicatedStorage
end

local function getOrCreateEvent(name)
    local existing = eventsFolder:FindFirstChild(name)
    if existing then return existing end
    local ev = Instance.new("RemoteEvent")
    ev.Name = name
    ev.Parent = eventsFolder
    return ev
end

local evCarryStarted  = getOrCreateEvent("CarryStarted")   -- Server → Client : début du carry
local evCarryStopped  = getOrCreateEvent("CarryStopped")   -- Server → Client : fin du carry
local evRewardReceived = getOrCreateEvent("RewardReceived") -- Server → Client : récompense accordée

-- ─── État global ──────────────────────────────────────────────────────────────
-- playerCarrying[player] = { brainrot, originalCFrame, originalParent, weld }
local playerCarrying = {}

-- brainrotTaken[brainrot] = true quand un joueur le transporte (évite double pickup).
local brainrotTaken = {}

-- dropZoneDebounce[part][player] = true pendant le cooldown du Touched.
local dropZoneDebounce = {}

-- ─── Helpers ──────────────────────────────────────────────────────────────────

-- Retourne le HumanoidRootPart du character d'un joueur, ou nil.
local function getHRP(player)
    local char = player.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

-- Applique l'état "ghost" sur tous les descendants BasePart d'un model
-- pendant le carry (CanCollide=false, Massless=true, Anchored=false).
local function setGhostState(model, isGhost)
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            if isGhost then
                part.CanCollide = false
                part.Massless   = true
                part.Anchored   = false
            else
                -- Restauration : on ré-ancre simplement ; les propriétés
                -- CanCollide/Massless doivent être reset selon vos valeurs par défaut.
                part.CanCollide = true
                part.Massless   = false
                part.Anchored   = true
            end
        end
    end
end

-- ─── Reward ───────────────────────────────────────────────────────────────────

-- Accorde au joueur sa récompense et fire l'event client.
local function rewardPlayer(player, brainrot)
    local current = player:GetAttribute(CarryConfig.CASH_ATTRIBUTE) or 0
    player:SetAttribute(CarryConfig.CASH_ATTRIBUTE, current + CarryConfig.DEFAULT_REWARD)
    evRewardReceived:FireClient(player, CarryConfig.DEFAULT_REWARD, brainrot.Name)
end

-- ─── Drop / rescue ────────────────────────────────────────────────────────────

-- Réinitialise l'état d'un brainrot après dépôt ou rescue :
-- - Supprime le weld
-- - Ré-ancre et repositionne le brainrot à son CFrame d'origine
-- - Nettoie les tables d'état
local function releaseBrainrot(player, skipReward)
    local state = playerCarrying[player]
    if not state then return end

    local brainrot       = state.brainrot
    local originalCFrame = state.originalCFrame
    local weld           = state.weld

    -- Destruction du WeldConstraint en sécurité.
    if weld and weld.Parent then
        weld:Destroy()
    end

    -- Restore physics : ré-ancrer et repositionner.
    if brainrot and brainrot.Parent then
        setGhostState(brainrot, false)
        if brainrot.PrimaryPart then
            brainrot:SetPrimaryPartCFrame(originalCFrame)
        end
    end

    -- Nettoyage de l'état.
    playerCarrying[player] = nil

    -- On ne nettoie PAS brainrotTaken ici : c'est fait après le délai de respawn.
end

-- Déclenché après un dépôt réussi sur un DropPad.
-- Récompense le joueur, relâche le brainrot, puis le fait réapparaître après délai.
local function dropBrainrot(player, withReward)
    local state = playerCarrying[player]
    if not state then return end

    local brainrot = state.brainrot

    if withReward then
        rewardPlayer(player, brainrot)
    end

    releaseBrainrot(player, false)

    -- Fire l'event de fin de carry vers le client.
    evCarryStopped:FireClient(player)

    -- Réapparition du brainrot après délai.
    task.delay(CarryConfig.RESPAWN_DELAY, function()
        brainrotTaken[brainrot] = nil
        -- Ré-active le ProximityPrompt si présent.
        if brainrot and brainrot.PrimaryPart then
            local pp = brainrot.PrimaryPart:FindFirstChildOfClass("ProximityPrompt")
            if pp then
                pp.Enabled = true
            end
        end
    end)
end

-- ─── Pickup ───────────────────────────────────────────────────────────────────

-- Valide et effectue le ramassage d'un brainrot par un joueur.
local function pickupBrainrot(player, brainrot)
    -- Vérifications de base.
    if not brainrot or not brainrot.Parent then return end
    if not brainrot.PrimaryPart then
        warn("[CarryServer] pickupBrainrot: PrimaryPart manquant sur", brainrot.Name)
        return
    end
    if playerCarrying[player] then return end  -- Déjà en train de porter.
    if brainrotTaken[brainrot] then return end  -- Déjà pris par un autre.

    local hrp = getHRP(player)
    if not hrp then return end

    -- Anti-exploit : vérification de la distance réelle au moment du pickup.
    local dist = (hrp.Position - brainrot.PrimaryPart.Position).Magnitude
    if dist > CarryConfig.MAX_PICKUP_DISTANCE then
        warn("[CarryServer] Pickup refusé (distance trop grande) :", dist, "studs pour", player.Name)
        return
    end

    -- Marquer le brainrot comme pris.
    brainrotTaken[brainrot] = true

    -- Sauvegarder l'état original AVANT toute modification.
    local originalCFrame  = brainrot:GetPrimaryPartCFrame()
    local originalParent  = brainrot.Parent

    -- Désactiver le ProximityPrompt pendant le carry.
    local prompt = brainrot.PrimaryPart:FindFirstChildOfClass("ProximityPrompt")
    if prompt then
        prompt.Enabled = false
    end

    -- Appliquer l'état "ghost" (no collision, no mass, unanchored).
    setGhostState(brainrot, true)

    -- Créer le WeldConstraint : Part0 = HRP, Part1 = PrimaryPart du brainrot.
    -- Le brainrot RESTE dans son parent d'origine (Workspace/Brainrots/).
    local weld = Instance.new("WeldConstraint")
    weld.Name  = "CarryWeld"
    weld.Part0 = hrp
    weld.Part1 = brainrot.PrimaryPart
    weld.Parent = brainrot.PrimaryPart  -- parent dans le brainrot, pas le character

    -- Positionner immédiatement au-dessus de la tête.
    brainrot:SetPrimaryPartCFrame(hrp.CFrame * CarryConfig.CARRY_OFFSET)

    -- Enregistrer l'état dans la table.
    playerCarrying[player] = {
        brainrot       = brainrot,
        originalCFrame = originalCFrame,
        originalParent = originalParent,
        weld           = weld,
    }

    -- Notifier le client pour animer le personnage.
    evCarryStarted:FireClient(player)
end

-- ─── ProximityPrompt setup ────────────────────────────────────────────────────

-- Ajoute un ProximityPrompt sur le PrimaryPart d'un brainrot.
local function setupPrompt(brainrot)
    if not brainrot.PrimaryPart then
        warn("[CarryServer] setupPrompt: PrimaryPart manquant sur", brainrot.Name)
        return
    end

    -- Éviter les doublons.
    if brainrot.PrimaryPart:FindFirstChildOfClass("ProximityPrompt") then return end

    local prompt = Instance.new("ProximityPrompt")
    prompt.ObjectText    = brainrot.Name
    prompt.ActionText    = "Ramasser"
    prompt.HoldDuration  = CarryConfig.HOLD_DURATION
    prompt.MaxActivationDistance = CarryConfig.MAX_DISTANCE
    prompt.RequiresLineOfSight   = false
    prompt.Parent = brainrot.PrimaryPart

    prompt.Triggered:Connect(function(player)
        pickupBrainrot(player, brainrot)
    end)
end

-- ─── Init brainrots ───────────────────────────────────────────────────────────

-- Itère sur Workspace/Brainrots et setup un prompt sur chaque Model valide.
-- On ne setup que les Models dont le parent est :
--   - le dossier racine Brainrots (Model direct)
--   - ou un Folder enfant direct de Brainrots (groupe de brainrots organisés en sous-dossiers)
-- Cela évite de setup des prompts sur des sous-parties de Models.
local function initBrainrots()
    local brainrotsFolder = Workspace:WaitForChild("Brainrots", 10)
    if not brainrotsFolder then
        warn("[CarryServer] Workspace.Brainrots introuvable !")
        return
    end

    for _, obj in ipairs(brainrotsFolder:GetDescendants()) do
        if obj:IsA("Model") then
            local parent = obj.Parent
            -- Parent direct du dossier racine.
            local isDirectChild = (parent == brainrotsFolder)
            -- Parent = Folder enfant direct du dossier racine (organisation en sous-dossiers).
            local isInSubFolder = parent:IsA("Folder") and (parent.Parent == brainrotsFolder)

            if isDirectChild or isInSubFolder then
                setupPrompt(obj)
            end
        end
    end

    -- Écoute les ajouts futurs (brainrots spawnés dynamiquement).
    brainrotsFolder.DescendantAdded:Connect(function(obj)
        if obj:IsA("Model") then
            local parent = obj.Parent
            local isDirectChild = (parent == brainrotsFolder)
            local isInSubFolder = parent:IsA("Folder") and (parent.Parent == brainrotsFolder)
            if isDirectChild or isInSubFolder then
                -- Petit délai pour que le Model soit complètement chargé (PrimaryPart défini).
                task.defer(function()
                    setupPrompt(obj)
                end)
            end
        end
    end)
end

-- ─── Drop zones ───────────────────────────────────────────────────────────────

-- Applique un style visuel basique et un BillboardGui de label sur une DropZone.
local function styleDropZone(part)
    part.Material     = Enum.Material.Neon
    part.BrickColor   = BrickColor.new("Bright blue")
    part.Transparency = 0.5
    part.CanCollide   = false  -- Le joueur passe dessus sans être bloqué.

    -- Label flottant au-dessus du pad.
    local billboard = Instance.new("BillboardGui")
    billboard.Size          = UDim2.new(0, 200, 0, 50)
    billboard.StudsOffset   = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop   = false
    billboard.Parent        = part

    local label = Instance.new("TextLabel")
    label.Size              = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3        = Color3.fromRGB(255, 255, 255)
    label.TextScaled        = true
    label.Font              = Enum.Font.GothamBold
    label.Text              = "DÉPOSER ICI"
    label.Parent            = billboard
end

-- Configure un DropPad : style visuel + détection Touched avec debounce.
local function setupDropZone(part)
    styleDropZone(part)
    dropZoneDebounce[part] = {}

    part.Touched:Connect(function(hit)
        -- Identifier le joueur depuis la partie touchante.
        local character = hit.Parent
        local player    = Players:GetPlayerFromCharacter(character)
        if not player then return end

        -- Debounce par joueur sur ce pad.
        if dropZoneDebounce[part][player] then return end

        local state = playerCarrying[player]
        if not state then return end

        -- Activer le debounce.
        dropZoneDebounce[part][player] = true

        -- Effectuer le dépôt avec récompense.
        dropBrainrot(player, true)

        -- Libérer le debounce après un court délai.
        task.delay(1, function()
            dropZoneDebounce[part][player] = nil
        end)
    end)
end

-- Initialise toutes les DropZones présentes dans Workspace/DropZones.
local function initDropZones()
    local zonesFolder = Workspace:WaitForChild("DropZones", 10)
    if not zonesFolder then
        warn("[CarryServer] Workspace.DropZones introuvable !")
        return
    end

    for _, obj in ipairs(zonesFolder:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name == "DropPad" then
            setupDropZone(obj)
        end
    end

    -- Écoute les ajouts futurs de DropPads.
    zonesFolder.DescendantAdded:Connect(function(obj)
        if obj:IsA("BasePart") and obj.Name == "DropPad" then
            task.defer(function()
                setupDropZone(obj)
            end)
        end
    end)
end

-- ─── Gestion des joueurs / disconnexion ───────────────────────────────────────

-- Rescue d'urgence : déclenché quand le character est sur le point d'être supprimé.
-- On doit relâcher le brainrot AVANT que le weld soit invalidé.
local function rescueBrainrot(player)
    local state = playerCarrying[player]
    if not state then return end

    local brainrot       = state.brainrot
    local originalCFrame = state.originalCFrame
    local weld           = state.weld

    -- Détruire le weld en premier pour déconnecter proprement.
    if weld and weld.Parent then
        weld:Destroy()
    end

    -- Ré-ancrer et repositionner le brainrot à son emplacement d'origine.
    if brainrot and brainrot.Parent then
        setGhostState(brainrot, false)
        if brainrot.PrimaryPart then
            brainrot:SetPrimaryPartCFrame(originalCFrame)
        end
        -- Ré-activer le prompt immédiatement (pas de récompense, pas de délai).
        if brainrot.PrimaryPart then
            local prompt = brainrot.PrimaryPart:FindFirstChildOfClass("ProximityPrompt")
            if prompt then
                prompt.Enabled = true
            end
        end
    end

    -- Nettoyer l'état.
    playerCarrying[player] = nil
    brainrotTaken[brainrot] = nil
end

-- CharacterRemoving : déclenché juste avant que le character soit retiré.
-- C'est le moment idéal pour le rescue car le character existe encore.
local function onCharacterRemoving(character, player)
    rescueBrainrot(player)
end

-- PlayerRemoving : dernier filet de sécurité au cas où CharacterRemoving
-- n'aurait pas suffi (déconnexion brutale, etc.).
local function onPlayerRemoving(player)
    rescueBrainrot(player)
end

-- Branche les handlers sur chaque joueur dès sa connexion.
local function onPlayerAdded(player)
    player.CharacterRemoving:Connect(function(character)
        onCharacterRemoving(character, player)
    end)
end

-- Connexions globales.
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Brancher sur les joueurs déjà connectés (cas de rechargement de script en studio).
for _, player in ipairs(Players:GetPlayers()) do
    onPlayerAdded(player)
end

-- ─── Lancement ────────────────────────────────────────────────────────────────
initBrainrots()
initDropZones()

print("[CarryServer] Système carry brainrot initialisé.")
