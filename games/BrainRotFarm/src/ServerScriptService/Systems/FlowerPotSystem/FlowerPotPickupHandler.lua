-- ServerScriptService/Systems/FlowerPotSystem/FlowerPotPickupHandler.lua
-- DobiGames BrainRotFarm — Gestion du pickup du BR Mutant tombé sur le pot
-- Crée ProximityPrompt "Récolter" sur le BR Mutant posé
-- Vérifie IsMutant=true, appelle CarrySystem, preserve les attributs élémentaires

local FlowerPotPickupHandler = {}

-- ============================================================
-- Services
-- ============================================================
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage       = game:GetService("ServerStorage")
local TweenService        = game:GetService("TweenService")
local Logger              = require(game:GetService("ServerScriptService").SharedLib.Server.Logger)

-- ============================================================
-- Lazy loader CarrySystem
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

-- ============================================================
-- Utilitaires internes
-- ============================================================

-- Envoie une notification au client via NotifEvent
local function notifier(player, typeNotif, message)
    local ev = ReplicatedStorage:FindFirstChild("NotifEvent")
    if ev then
        pcall(function() ev:FireClient(player, typeNotif, message) end)
    end
end

-- Son de récolte via SoundService (fallback silencieux si absent)
local function jouerSonRecolte(position)
    pcall(function()
        local sound = Instance.new("Sound")
        sound.SoundId  = "rbxassetid://9120386446"  -- Son "collecte" Roblox
        sound.Volume   = 0.8
        sound.RollOffMaxDistance = 20
        sound.Parent   = workspace
        sound:Play()
        game:GetService("Debris"):AddItem(sound, 3)
    end)
end

-- Burst de particules dorées au moment du pickup
local function burstPickup(clone)
    local root = nil
    if clone:IsA("Model") then
        root = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart")
    elseif clone:IsA("BasePart") then
        root = clone
    end
    if not root then return end

    pcall(function()
        local burst = Instance.new("ParticleEmitter", root)
        burst.Color    = ColorSequence.new(Color3.fromRGB(255, 215, 0))
        burst.Lifetime = NumberRange.new(0.3, 0.6)
        burst.Speed    = NumberRange.new(5, 12)
        burst.Rate     = 0  -- Emission manuelle
        burst.Size     = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.4),
            NumberSequenceKeypoint.new(1, 0),
        })
        burst.LightEmission = 1
        burst:Emit(25)  -- 25 particules en burst

        game:GetService("Debris"):AddItem(burst, 1)
    end)
end

-- Supprime le ProximityPrompt existant sur une instance
local function supprimerPrompt(instance)
    local prompt = instance:FindFirstChildOfClass("ProximityPrompt")
    if prompt then pcall(function() prompt:Destroy() end) end
end

-- ============================================================
-- Setup — configure le ProximityPrompt sur le BR Mutant tombé
-- ============================================================
--[[
    @param clone    (Instance) — le BR Mutant cloné dans Workspace
    @param potModel (Instance) — le Model FlowerPot (pour référence)
    @param player   (Player)  — propriétaire du pot (validation)
    @param config   (table)   — {
        elementType (string),   — "water"/"fire"/"earth"/"wind"
        seedRarity  (string),   — "MYTHIC"/"SECRET"
        multiplier  (number),   — 2/4/6/8
        emoji       (string),   — "💧"/"🔥"/"🌍"/"💨"
        potId       (string),   — identifiant unique du pot
        onHarvest   (function), — callback après récolte réussie
    }
]]
function FlowerPotPickupHandler.Setup(clone, potModel, player, config)
    -- Validation IsMutant
    local isMutant = clone:GetAttribute("IsMutant")
    if not isMutant then
        Logger.warn("Pickup", "Clone sans attribut IsMutant — pickup annulé")
        return
    end

    -- Lire attributs depuis le clone (source de vérité serveur)
    local elementType = clone:GetAttribute("MutantType") or config.elementType or "GALAXY"
    local seedRarity  = clone:GetAttribute("Rarity")      or config.seedRarity  or "MYTHIC"
    local multiplier  = clone:GetAttribute("Multiplier")  or config.multiplier  or 2
    local emoji       = config.emoji or "✨"

    -- Trouver la part racine pour y attacher le ProximityPrompt
    local promptParent = nil
    if clone:IsA("Model") then
        promptParent = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart")
    elseif clone:IsA("BasePart") then
        promptParent = clone
    end

    if not promptParent then
        Logger.warn("Pickup", "Aucun BasePart trouvé pour attacher le prompt")
        return
    end

    -- Supprimer prompt existant si présent
    supprimerPrompt(promptParent)

    -- ─── Créer ProximityPrompt de récolte ───
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText            = "Harvest"
    prompt.ObjectText            = string.format("%s BR Mutant %s (×%d)",
        emoji, elementType, multiplier)
    prompt.HoldDuration          = 0.3   -- Mobile-compatible (court hold)
    prompt.MaxActivationDistance = 6
    prompt.RequiresLineOfSight   = false
    prompt.KeyboardKeyCode       = Enum.KeyCode.E
    prompt.Enabled               = true
    prompt.Parent                = promptParent

    Logger.debug("Pickup", "Prompt 'Récolter' créé | %s %s ×%d | Pot: %s", emoji, elementType, multiplier, potModel.Name)

    -- ─── Connexion au trigger ───
    local connexion = nil
    connexion = prompt.Triggered:Connect(function(triggerPlayer)
        -- Validation : seul le propriétaire peut récolter
        if triggerPlayer ~= player then
            notifier(triggerPlayer, "INFO", "❌ This pot belongs to another player!")
            return
        end

        -- Désactiver le prompt immédiatement (évite double-trigger)
        prompt.Enabled = false
        if connexion then
            connexion:Disconnect()
            connexion = nil
        end

        -- Vérifier que le clone existe encore
        if not clone or not clone.Parent then
            Logger.warn("Pickup", "Clone introuvable lors du trigger")
            return
        end

        -- Récupérer CarrySystem
        local CS = getCarrySystem()
        if not CS then
            Logger.warn("Pickup", "CarrySystem indisponible — récolte annulée")
            -- Réactiver le prompt si erreur système
            prompt.Enabled = true
            return
        end

        -- Construire l'objet rareté pour CarrySystem
        -- valeur = multiplier élémentaire → utilisé par DropSystem pour income
        local Config = require(ReplicatedStorage.GameConfig)
        local valeurBase = (Config.ValeurParRarete and Config.ValeurParRarete[seedRarity]) or 200
        local rareteObj = {
            nom         = seedRarity,        -- "MYTHIC" ou "SECRET"
            dossier     = seedRarity,        -- dossier dans ServerStorage/Brainrots/
            isMutant    = true,              -- flag pour DropSystem (spot doré)
            valeur      = multiplier,        -- ×2/4/6/8 selon élément → income = valeurBase × multiplier
            couleur     = nil,               -- couleur optionnelle (nil = couleur du modèle)
            elementType = elementType,       -- conservé pour affichage billboard
        }

        -- Ajouter au carry (serveur-side via CarrySystem)
        local ok, success = pcall(CS.AjouterAuCarry, triggerPlayer, clone, rareteObj)

        if ok and success then
            -- ─── Pickup réussi ───

            -- Burst de particules dorées
            burstPickup(clone)

            -- Son de récolte
            local rootPart = clone:IsA("Model")
                and (clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart"))
                or  clone
            if rootPart then
                jouerSonRecolte(rootPart.Position)
            end

            Logger.info("Pickup", "%s récolté par %s | %s ×%d | Pot: %s", seedRarity, triggerPlayer.Name, elementType, multiplier, potModel.Name)

            -- Nettoyer prompt (clone sera détruit par CarrySystem)
            pcall(function() prompt:Destroy() end)

            -- Callback externe (ex: reset UI, relancer animation pot vide)
            if config.onHarvest then
                pcall(config.onHarvest, triggerPlayer, elementType, multiplier)
            end

            -- Notifier le joueur avec le multiplicateur
            notifier(triggerPlayer, "SUCCESS",
                string.format("✨ BR Mutant %s récolté! %s ×%d income!",
                    seedRarity, emoji, multiplier))

        else
            -- ─── Carry plein ───
            -- Réactiver le prompt pour que le joueur réessaie
            prompt.Enabled = true
            if not connexion then
                -- Reconnecter après refus carry plein
                connexion = prompt.Triggered:Connect(function(tp)
                    if tp ~= player then return end
                    prompt.Enabled = false
                    if connexion then connexion:Disconnect() connexion = nil end
                    -- Ré-essayer via Setup récursif simplifié
                    FlowerPotPickupHandler.Setup(clone, potModel, player, config)
                end)
            end

            notifier(triggerPlayer, "WARNING",
                "🎒 Carry plein! Dépose tes Brain Rots d'abord, puis récolte.")

            Logger.debug("Pickup", "Carry plein pour %s — prompt réactivé", triggerPlayer.Name)
        end
    end)
end

-- ============================================================
-- Cleanup — supprime le ProximityPrompt d'un BR Mutant
-- (utile si le joueur quitte avant de récolter)
-- ============================================================
function FlowerPotPickupHandler.Cleanup(clone)
    if not clone then return end

    local root = nil
    if clone:IsA("Model") then
        root = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart")
    elseif clone:IsA("BasePart") then
        root = clone
    end

    if root then
        supprimerPrompt(root)
    end

    pcall(function() clone:Destroy() end)
end

return FlowerPotPickupHandler
