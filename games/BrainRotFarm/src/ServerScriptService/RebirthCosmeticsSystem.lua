-- ServerScriptService/RebirthCosmeticsSystem.lua
-- BrainRotFarm — Cosmétiques visuels progressifs par palier de Rebirth
-- Auras + Trails + Effets spéciaux appliqués au character du joueur
-- Dépendance injectée : RebirthCosmeticsSystem.GetData = GetData (depuis Main.server.lua)

local RebirthCosmeticsSystem = {}

local Players = game:GetService("Players")

-- Source de données injectée depuis Main.server.lua
RebirthCosmeticsSystem.GetData = nil

-- ============================================================
-- Paliers cosmétiques par niveau de rebirth
-- Seul le palier le plus élevé atteint est appliqué
-- ============================================================
local PALIERS_COSMETIQUES = {
    [1] = {
        -- Rebirth 1 : Aura bleue subtile
        couleurAura   = Color3.fromRGB(100, 150, 255),
        auraActif     = true,
        trailActif    = false,
        particuleRate = 15,
        lumiereBrillance = 1.0,
        lumiereRange     = 10,
    },
    [3] = {
        -- Rebirth 3 : Aura violette + trail
        couleurAura   = Color3.fromRGB(138, 43, 226),
        auraActif     = true,
        trailActif    = true,
        couleurTrail  = Color3.fromRGB(138, 43, 226),
        particuleRate = 25,
        lumiereBrillance = 1.5,
        lumiereRange     = 14,
    },
    [5] = {
        -- Rebirth 5 : Aura dorée + trail brillant
        couleurAura   = Color3.fromRGB(255, 215, 0),
        auraActif     = true,
        trailActif    = true,
        couleurTrail  = Color3.fromRGB(255, 215, 0),
        particuleRate = 30,
        lumiereBrillance = 2.0,
        lumiereRange     = 18,
    },
    [10] = {
        -- Rebirth 10 : Aura rouge feu + trail orange + flammes sur tête
        couleurAura   = Color3.fromRGB(255, 0, 0),
        auraActif     = true,
        trailActif    = true,
        couleurTrail  = Color3.fromRGB(255, 100, 0),
        particuleRate = 50,
        lumiereBrillance = 3.0,
        lumiereRange     = 24,
        effetSpecial  = "REBIRTH_GOD",
    },
}

-- ============================================================
-- Utilitaires
-- ============================================================

-- Retourne la config cosmétique du palier le plus élevé atteint
local function obtenirPalier(rebirthLevel)
    local configRetenu  = nil
    local niveauRetenu  = 0
    for palier, config in pairs(PALIERS_COSMETIQUES) do
        if rebirthLevel >= palier and palier > niveauRetenu then
            niveauRetenu = palier
            configRetenu = config
        end
    end
    return configRetenu
end

-- Supprime tous les effets cosmétiques précédents sur le character
local function nettoyerEffets(character)
    -- Aura + lumière sur HumanoidRootPart
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if hrp then
        for _, obj in ipairs(hrp:GetChildren()) do
            if obj.Name == "RebirthAura" or obj.Name == "RebirthLight" then
                obj:Destroy()
            end
        end
    end

    -- Flammes tête (REBIRTH_GOD)
    local head = character:FindFirstChild("Head")
    if head then
        for _, obj in ipairs(head:GetChildren()) do
            if obj.Name == "RebirthAura" then obj:Destroy() end
        end
    end

    -- Attachments + trails (UpperTorso / LowerTorso)
    for _, partName in ipairs({ "UpperTorso", "LowerTorso" }) do
        local part = character:FindFirstChild(partName)
        if part then
            for _, obj in ipairs(part:GetChildren()) do
                if obj.Name == "RebirthAttUpper"
                or obj.Name == "RebirthAttLower"
                or obj.Name == "RebirthTrail"
                then
                    obj:Destroy()
                end
            end
        end
    end
end

-- Crée l'aura (ParticleEmitter) sur HumanoidRootPart
local function creerAura(hrp, config)
    local emitter = Instance.new("ParticleEmitter")
    emitter.Name  = "RebirthAura"
    emitter.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   config.couleurAura),
        ColorSequenceKeypoint.new(0.5, config.couleurAura),
        ColorSequenceKeypoint.new(1,   Color3.new(1, 1, 1)),
    })
    emitter.LightEmission = 0.6
    emitter.LightInfluence = 0.2
    emitter.Rate          = config.particuleRate or 15
    emitter.Lifetime      = NumberRange.new(0.8, 1.6)
    emitter.Speed         = NumberRange.new(2, 6)
    emitter.SpreadAngle   = Vector2.new(180, 180)
    emitter.Size          = NumberSequence.new({
        NumberSequenceKeypoint.new(0,   0.35),
        NumberSequenceKeypoint.new(0.5, 0.55),
        NumberSequenceKeypoint.new(1,   0),
    })
    emitter.Transparency  = NumberSequence.new({
        NumberSequenceKeypoint.new(0,   0.2),
        NumberSequenceKeypoint.new(0.7, 0.5),
        NumberSequenceKeypoint.new(1,   1),
    })
    emitter.Parent = hrp

    -- Point de lumière colorée
    local lumiere = Instance.new("PointLight")
    lumiere.Name       = "RebirthLight"
    lumiere.Brightness = config.lumiereBrillance or 1.5
    lumiere.Range      = config.lumiereRange     or 12
    lumiere.Color      = config.couleurAura
    lumiere.Parent     = hrp
end

-- Crée le trail entre UpperTorso et LowerTorso
local function creerTrail(character, config)
    local upperTorso = character:FindFirstChild("UpperTorso")
    local lowerTorso = character:FindFirstChild("LowerTorso")
    if not upperTorso or not lowerTorso then return end

    local attUpper = Instance.new("Attachment")
    attUpper.Name   = "RebirthAttUpper"
    attUpper.Parent = upperTorso

    local attLower = Instance.new("Attachment")
    attLower.Name   = "RebirthAttLower"
    attLower.Parent = lowerTorso

    local trail              = Instance.new("Trail")
    trail.Name               = "RebirthTrail"
    trail.Attachment0        = attUpper
    trail.Attachment1        = attLower
    trail.Color              = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   config.couleurTrail or config.couleurAura),
        ColorSequenceKeypoint.new(0.5, config.couleurTrail or config.couleurAura),
        ColorSequenceKeypoint.new(1,   Color3.new(1, 1, 1)),
    })
    trail.Transparency       = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(1, 1),
    })
    trail.Lifetime           = 0.45
    trail.LightEmission      = 0.6
    trail.MinLength          = 0.1
    trail.FaceCamera         = false
    trail.Parent             = upperTorso
end

-- Crée les flammes intensifiées sur la tête (REBIRTH_GOD uniquement)
local function creerFlammesGod(character)
    local head = character:FindFirstChild("Head")
    if not head then return end

    local flameEmitter = Instance.new("ParticleEmitter")
    flameEmitter.Name  = "RebirthAura"
    flameEmitter.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   Color3.fromRGB(255,  50,   0)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 150,   0)),
        ColorSequenceKeypoint.new(1,   Color3.fromRGB(255, 255, 100)),
    })
    flameEmitter.LightEmission  = 1
    flameEmitter.LightInfluence = 0
    flameEmitter.Rate           = 35
    flameEmitter.Lifetime       = NumberRange.new(0.4, 1.0)
    flameEmitter.Speed          = NumberRange.new(3, 9)
    flameEmitter.SpreadAngle    = Vector2.new(25, 25)
    flameEmitter.RotSpeed       = NumberRange.new(-180, 180)
    flameEmitter.Size           = NumberSequence.new({
        NumberSequenceKeypoint.new(0,   0.6),
        NumberSequenceKeypoint.new(0.6, 0.4),
        NumberSequenceKeypoint.new(1,   0),
    })
    flameEmitter.Transparency   = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(1, 1),
    })
    flameEmitter.Parent = head
end

-- Applique les cosmétiques sur le character selon la config du palier
local function appliquerCosmetiques(character, config)
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- Aura permanente autour du joueur
    if config.auraActif then
        creerAura(hrp, config)
    end

    -- Trail de déplacement
    if config.trailActif then
        creerTrail(character, config)
    end

    -- Effet spécial Rebirth GOD (flammes sur tête)
    if config.effetSpecial == "REBIRTH_GOD" then
        creerFlammesGod(character)
    end
end

-- ============================================================
-- Logique principale
-- ============================================================

-- Applique ou retire les cosmétiques selon rebirthLevel du joueur
local function initialiserPourJoueur(player, character)
    -- Laisser le character se charger complètement
    task.wait(1)

    -- Vérifier que le character est encore valide (peut avoir respawn entre temps)
    if not character or not character.Parent then return end

    -- Récupérer les données du joueur via le callback injecté
    local getData = RebirthCosmeticsSystem.GetData
    if not getData then
        warn("[RebirthCosmetics] GetData non injecté — cosmétiques ignorés pour " .. player.Name)
        return
    end
    local data = getData(player)
    if not data then return end

    local rebirthLevel = data.rebirthLevel or 0

    -- Toujours nettoyer les anciens effets (évite les doublons après respawn)
    nettoyerEffets(character)

    -- Pas de cosmétiques avant Rebirth 1
    if rebirthLevel <= 0 then return end

    local config = obtenirPalier(rebirthLevel)
    if not config then return end

    appliquerCosmetiques(character, config)

    print(string.format(
        "[RebirthCosmetics] %s → Rebirth %d — cosmétiques palier appliqués",
        player.Name, rebirthLevel
    ))
end

-- ============================================================
-- API publique
-- ============================================================

-- Appelé depuis Main.server.lua lors de chaque CharacterAdded
function RebirthCosmeticsSystem.AppliquerPourJoueur(player, character)
    task.spawn(initialiserPourJoueur, player, character)
end

-- Initialisation du système (hook Players.PlayerAdded automatique)
function RebirthCosmeticsSystem.Init()
    -- Connecter les joueurs déjà présents (jointure avant Init)
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then
            RebirthCosmeticsSystem.AppliquerPourJoueur(player, player.Character)
        end
        player.CharacterAdded:Connect(function(character)
            RebirthCosmeticsSystem.AppliquerPourJoueur(player, character)
        end)
    end

    -- Connecter les futurs joueurs
    Players.PlayerAdded:Connect(function(player)
        player.CharacterAdded:Connect(function(character)
            RebirthCosmeticsSystem.AppliquerPourJoueur(player, character)
        end)
    end)

    print("[RebirthCosmetics] Initialisé ✓")
end

return RebirthCosmeticsSystem
