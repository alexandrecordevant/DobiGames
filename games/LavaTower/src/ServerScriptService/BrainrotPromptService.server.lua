-- ServerScriptService/BrainrotPromptService.server.lua
-- Gère les ProximityPrompts sur tous les Brainrots taggés "BrainrotCollectible".
-- Détecte les instances existantes ET les futures (spawn dynamique).

local CollectionService  = game:GetService("CollectionService")
local Players            = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local BrainrotInventoryService = require(ServerScriptService:WaitForChild("BrainrotInventoryService"))

local TAG = "BrainrotCollectible"

-- ── Paramètres du ProximityPrompt ──────────────────────────────────────────
local HOLD_DURATION        = 3    -- secondes à maintenir
local MAX_DISTANCE         = 10   -- distance d'activation (studs)
local PROMPT_ACTION_TEXT   = "Collect"

-- ─────────────────────────────────────────────────────────────────────────────
-- Utilitaires
-- ─────────────────────────────────────────────────────────────────────────────

-- Retourne la Part principale d'un brainrot (BasePart si Model, ou la Part elle-même)
local function GetRootPart(instance)
    if instance:IsA("Model") then
        return instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart")
    elseif instance:IsA("BasePart") then
        return instance
    end
    return nil
end

-- Construit un identifiant unique stable pour le brainrot.
-- Priorité : Attribute "BrainrotId" → Name + position arrondie
local function GetBrainrotId(instance)
    local attrId = instance:GetAttribute("BrainrotId")
    if attrId and attrId ~= "" then
        return tostring(attrId)
    end
    -- Fallback : nom + position (assez unique dans un niveau)
    local root = GetRootPart(instance)
    if root then
        local p = root.Position
        return ("%s_%.0f_%.0f_%.0f"):format(instance.Name, p.X, p.Y, p.Z)
    end
    return instance.Name .. "_" .. tostring(instance:GetDebugId())
end

-- Retourne la rareté de l'instance (Attribute "Rarity" ou "Common" par défaut)
local function GetRarity(instance)
    return instance:GetAttribute("Rarity") or "Common"
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Initialisation des joueurs (pour l'inventaire)
-- ─────────────────────────────────────────────────────────────────────────────

Players.PlayerAdded:Connect(function(player)
    BrainrotInventoryService.Init(player)
end)

-- Initialise les joueurs déjà connectés au démarrage du script
for _, player in ipairs(Players:GetPlayers()) do
    BrainrotInventoryService.Init(player)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Ajout du ProximityPrompt
-- ─────────────────────────────────────────────────────────────────────────────

local function AjouterPrompt(instance)
    local root = GetRootPart(instance)
    if not root then
        warn(("[BrainrotPrompt] Pas de BasePart pour : %s"):format(instance.Name))
        return
    end

    -- Évite les doublons si le prompt existe déjà dans le workspace
    if root:FindFirstChildOfClass("ProximityPrompt") then return end

    local rarity = GetRarity(instance)
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText      = PROMPT_ACTION_TEXT
    prompt.ObjectText      = ("%s [%s]"):format(instance.Name, rarity)
    prompt.HoldDuration    = HOLD_DURATION
    prompt.MaxActivationDistance = MAX_DISTANCE
    prompt.RequiresLineOfSight   = false
    prompt.Parent          = root

    -- ── Gestion de la collecte ─────────────────────────────────────────────
    prompt.Triggered:Connect(function(player)
        -- 1. Vérifie que l'instance existe encore (pas déjà détruite)
        if not instance or not instance.Parent then return end

        -- 2. Verrou anti-race : empêche deux joueurs de collecter simultanément
        if instance:GetAttribute("_Collecting") then return end
        instance:SetAttribute("_Collecting", true)

        -- 3. Récupère les métadonnées
        local brainrotId   = GetBrainrotId(instance)
        local brainrotName = instance.Name
        local brainrotRarity = rarity

        -- 4. Tente l'ajout dans l'inventaire (vérifie doublon côté serveur)
        local success, reason = BrainrotInventoryService.Add(player, {
            id     = brainrotId,
            name   = brainrotName,
            rarity = brainrotRarity,
        })

        if not success then
            -- Annule le verrou si la collecte est rejetée
            instance:SetAttribute("_Collecting", nil)
            warn(("[BrainrotPrompt] Collecte refusée pour %s : %s"):format(player.Name, reason))
            return
        end

        -- 5. Supprime le brainrot de la map
        instance:Destroy()
    end)

    print(("[BrainrotPrompt] Prompt ajouté sur : %s (%s)"):format(instance.Name, rarity))
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Détection via CollectionService
-- ─────────────────────────────────────────────────────────────────────────────

-- Instances déjà taggées au démarrage
for _, instance in ipairs(CollectionService:GetTagged(TAG)) do
    task.spawn(AjouterPrompt, instance)
end

-- Instances taggées dynamiquement (brainrots spawnés en cours de partie)
CollectionService:GetInstanceAddedSignal(TAG):Connect(function(instance)
    task.spawn(AjouterPrompt, instance)
end)

print("[BrainrotPromptService] Démarré — en écoute du tag : " .. TAG)
