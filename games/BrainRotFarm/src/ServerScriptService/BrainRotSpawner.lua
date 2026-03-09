-- ServerScriptService/BrainRotSpawner.lua
-- Spawn les vrais modèles Brain Rot dans le champ
-- Remplace les BaseParts génériques du SpawnManager

local BrainRotSpawner = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")
local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local Config            = require(ReplicatedStorage.Modules.GameConfig)

-- ═══════════════════════════════════════════
-- CONFIGURATION DU CHAMP
-- ═══════════════════════════════════════════

local CHAMP = {
    X_MIN  = -39.00,
    X_MAX  =  18.80,
    Z_MIN  = -151.09,
    Z_MAX  =  -84.23,
    Y      =   8.542,  -- hauteur fixe
}

local MAX_BRAINROTS_MAP  = 40   -- max simultanés sur le champ
local DESPAWN_SECONDES   = 25   -- disparaît si non collecté
local SPAWN_INTERVALLE   = 3    -- secondes entre chaque spawn

-- ═══════════════════════════════════════════
-- MAPPING RARETÉS → DOSSIERS
-- ═══════════════════════════════════════════

-- Dossier Brainrots dans ServerStorage (ou Workspace — adapte si besoin)
local BRAINROTS_FOLDER = ServerStorage:WaitForChild("Brainrots")

local RARETE_DOSSIERS = {
    { nom = "Common",    dossier = "COMMON",      chance = 60,  valeur = 1   },
    { nom = "Uncommon",  dossier = "OG",           chance = 20,  valeur = 3   },
    { nom = "Rare",      dossier = "RARE",         chance = 10,  valeur = 10  },
    { nom = "Epic",      dossier = "EPIC",         chance = 5,   valeur = 30  },
    { nom = "Legendary", dossier = "LEGENDARY",    chance = 3,   valeur = 100 },
    { nom = "Mythic",    dossier = "MYTHIC",       chance = 1.5, valeur = 300 },
    { nom = "Secret",    dossier = "SECRET",       chance = 0.4, valeur = 500 },
    { nom = "God",       dossier = "BRAINROT_GOD", chance = 0.1, valeur = 2000},
}

-- ═══════════════════════════════════════════
-- UTILITAIRES
-- ═══════════════════════════════════════════

local actifs = {}  -- liste des Brain Rots spawned
local idCounter = 0

local function GenererID()
    idCounter = idCounter + 1
    return "BR_" .. idCounter
end

-- Position aléatoire dans le champ
local function PositionAleatoire()
    return Vector3.new(
        math.random() * (CHAMP.X_MAX - CHAMP.X_MIN) + CHAMP.X_MIN,
        CHAMP.Y + 1.5,  -- légèrement au-dessus du sol
        math.random() * (CHAMP.Z_MAX - CHAMP.Z_MIN) + CHAMP.Z_MIN
    )
end

-- Tire une rareté selon les probabilités
local function TirerRarete()
    local rand = math.random() * 100
    local cumul = 0
    for _, r in ipairs(RARETE_DOSSIERS) do
        cumul = cumul + r.chance
        if rand <= cumul then return r end
    end
    return RARETE_DOSSIERS[1]
end

-- Récupère un modèle aléatoire depuis un dossier de rareté
local function GetModeleAleatoire(nomDossier)
    local dossier = BRAINROTS_FOLDER:FindFirstChild(nomDossier)
    if not dossier then return nil end
    local modeles = dossier:GetChildren()
    if #modeles == 0 then return nil end
    return modeles[math.random(1, #modeles)]
end

-- ═══════════════════════════════════════════
-- SPAWN D'UN BRAIN ROT
-- ═══════════════════════════════════════════

local function SpawnerUnBrainRot()
    if #actifs >= MAX_BRAINROTS_MAP then return end

    local rarete  = TirerRarete()
    local modele  = GetModeleAleatoire(rarete.dossier)
    if not modele then return end

    -- Cloner le modèle
    local clone = modele:Clone()
    local id    = GenererID()
    clone.Name  = id

    -- Positionner dans le champ
    local position = PositionAleatoire()
    clone:PivotTo(CFrame.new(position))

    -- ══ CACHÉ AU DÉPART (sauvegarde transparences originales) ══
    local transparencesOriginales = {}
    for _, part in ipairs(clone:GetDescendants()) do
        if part:IsA("BasePart") then
            transparencesOriginales[part] = part.Transparency
            part.Transparency = 1
            part.CanCollide   = false
        end
    end

    clone.Parent = workspace

    -- ══ APPARITION PROGRESSIVE (restaure transparences originales) ══
    task.delay(0.1, function()
        for _, part in ipairs(clone:GetDescendants()) do
            if part:IsA("BasePart") then
                local cible = transparencesOriginales[part] or 0
                TweenService:Create(part,
                    TweenInfo.new(0.5, Enum.EasingStyle.Quad),
                    { Transparency = cible }
                ):Play()
            end
        end
        -- Activer collision après apparition
        task.delay(0.5, function()
            for _, part in ipairs(clone:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false  -- pas de collision physique
                end
            end
        end)
    end)

    -- Billboard avec nom + rareté
    local anchorPart = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart", true)
    if anchorPart then
        local billboard = Instance.new("BillboardGui")
        billboard.Size         = UDim2.new(0, 120, 0, 40)
        billboard.StudsOffset  = Vector3.new(0, 3, 0)
        billboard.AlwaysOnTop  = false
        billboard.Parent       = anchorPart

        local label = Instance.new("TextLabel", billboard)
        label.Size                    = UDim2.new(1,0,1,0)
        label.BackgroundTransparency  = 1
        label.TextColor3              = Color3.fromRGB(255,255,255)
        label.TextStrokeTransparency  = 0
        label.TextScaled              = true
        label.Font                    = Enum.Font.GothamBold
        label.Text                    = "⭐ " .. rarete.nom .. " · " .. modele.Name
    end

    -- Touch detection → collecte
    local touched = false
    for _, part in ipairs(clone:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Touched:Connect(function(hit)
                if touched then return end
                local character = hit.Parent
                local player    = Players:GetPlayerByCharacter(character)
                if not player then return end
                touched = true

                -- Disparition (fade out)
                for _, p in ipairs(clone:GetDescendants()) do
                    if p:IsA("BasePart") then
                        TweenService:Create(p,
                            TweenInfo.new(0.3),
                            { Transparency = 1, Size = p.Size * 1.3 }
                        ):Play()
                    end
                end

                -- Notifier le serveur (collecte + coins)
                local collectEvent = ReplicatedStorage:FindFirstChild("_InternalCollect")
                if collectEvent then
                    collectEvent:Fire(player, id, rarete)
                end

                task.delay(0.4, function()
                    clone:Destroy()
                    -- Retirer de la liste actifs
                    for i, entry in ipairs(actifs) do
                        if entry.id == id then
                            table.remove(actifs, i)
                            break
                        end
                    end
                end)
            end)
        end
    end

    -- Enregistrer
    actifs[#actifs + 1] = {
        id       = id,
        clone    = clone,
        rarete   = rarete,
        expireAt = os.time() + DESPAWN_SECONDES,
    }
end

-- ═══════════════════════════════════════════
-- NETTOYAGE DESPAWN
-- ═══════════════════════════════════════════

local function NettoyerExpires()
    local now     = os.time()
    local nouveaux = {}
    for _, entry in ipairs(actifs) do
        if entry.expireAt <= now then
            if entry.clone and entry.clone.Parent then
                -- Fade out avant destroy
                for _, p in ipairs(entry.clone:GetDescendants()) do
                    if p:IsA("BasePart") then
                        TweenService:Create(p, TweenInfo.new(0.5), { Transparency = 1 }):Play()
                    end
                end
                task.delay(0.6, function()
                    if entry.clone and entry.clone.Parent then
                        entry.clone:Destroy()
                    end
                end)
            end
        else
            nouveaux[#nouveaux + 1] = entry
        end
    end
    actifs = nouveaux
end

-- ═══════════════════════════════════════════
-- MULTIPLICATEUR EVENT (Admin Abuse)
-- ═══════════════════════════════════════════

BrainRotSpawner.EventMultiplier = 1

function BrainRotSpawner.SetEventMultiplier(mult)
    BrainRotSpawner.EventMultiplier = mult
end

-- ═══════════════════════════════════════════
-- BOUCLE PRINCIPALE
-- ═══════════════════════════════════════════

local function BoucleSpawn()
    local tick = 0
    while true do
        local nbJoueurs = #Players:GetPlayers()
        if nbJoueurs == 0 then
            task.wait(5)
            continue
        end

        local intervalle = SPAWN_INTERVALLE / BrainRotSpawner.EventMultiplier
        task.wait(intervalle)

        -- Spawner 1 à 3 selon le nb de joueurs
        local nbSpawn = math.min(nbJoueurs, 3)
        for i = 1, nbSpawn do
            SpawnerUnBrainRot()
        end

        -- Nettoyer toutes les 15 itérations
        tick = tick + 1
        if tick % 15 == 0 then
            NettoyerExpires()
        end
    end
end

-- ═══════════════════════════════════════════
-- INIT
-- ═══════════════════════════════════════════

function BrainRotSpawner.Init()
    -- S'assurer que le dossier Brainrots existe
    if not BRAINROTS_FOLDER then
        error("[BrainRotSpawner] Dossier 'Brainrots' introuvable dans ServerStorage !")
        return
    end

    -- Compter les modèles disponibles
    local total = 0
    for _, r in ipairs(RARETE_DOSSIERS) do
        local d = BRAINROTS_FOLDER:FindFirstChild(r.dossier)
        if d then
            local n = #d:GetChildren()
            total = total + n
            print("[BrainRotSpawner] " .. r.dossier .. " : " .. n .. " modèles")
        else
            warn("[BrainRotSpawner] Dossier manquant : " .. r.dossier)
        end
    end

    print("[BrainRotSpawner] Total modèles disponibles : " .. total)
    print("[BrainRotSpawner] Champ : X[" .. CHAMP.X_MIN .. " → " .. CHAMP.X_MAX .. "] Z[" .. CHAMP.Z_MIN .. " → " .. CHAMP.Z_MAX .. "]")

    task.spawn(BoucleSpawn)
    print("[BrainRotSpawner] ✓ Spawn démarré")
end

return BrainRotSpawner