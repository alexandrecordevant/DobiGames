-- ServerScriptService/SpawnManager.lua
-- BrainRot Idle Engine v1 — Spawn des collectibles
-- DobiGames · Gère le spawn/despawn des Brain Rots sur la map

local SpawnManager = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")

local Config        = require(ReplicatedStorage.Specialized.GameConfig)
local CollectSystem = require(ReplicatedStorage.Common.CollectSystem)

-- ═══════════════════════════════════════════════
-- CONFIGURATION SPAWN
-- ═══════════════════════════════════════════════

local MAX_COLLECTIBLES_MAP    = 50    -- max simultanés sur la map
local DESPAWN_APRES_SECONDES  = 30   -- disparaît si non collecté
local HAUTEUR_SPAWN           = 5    -- hauteur au-dessus du sol

-- Couleurs par rareté (fallback si Config non défini)
local COULEURS_RARETE = {
    Common    = Color3.fromRGB(200, 200, 200),
    Uncommon  = Color3.fromRGB(100, 200, 100),
    Rare      = Color3.fromRGB(100, 100, 255),
    Epic      = Color3.fromRGB(180, 50, 255),
    Legendary = Color3.fromRGB(255, 200, 0),
    Secret    = Color3.fromRGB(255, 50, 50),
}

-- Zones de spawn définies dans Workspace/SpawnZones
-- Chaque zone = Part nommée "Zone_1", "Zone_2", etc.
local spawnZones = {}
local collectiblesActifs = {}  -- { [id] = {part, expireAt} }
local idCounter = 0

-- ═══════════════════════════════════════════════
-- UTILITAIRES
-- ═══════════════════════════════════════════════

local function GenererID()
    idCounter = idCounter + 1
    return "Collectible_" .. idCounter
end

-- Position aléatoire dans une zone (Part Roblox)
local function PositionAleatoireDansZone(zone)
    local size = zone.Size
    local pos  = zone.Position
    return Vector3.new(
        pos.X + math.random(-size.X/2, size.X/2),
        pos.Y + HAUTEUR_SPAWN,
        pos.Z + math.random(-size.Z/2, size.Z/2)
    )
end

-- Crée visuellement le collectible sur la map
local function CreerCollectiblePart(id, position, rarete)
    local part = Instance.new("Part")
    part.Name = id
    part.Size = Vector3.new(2, 2, 2)
    part.Position = position
    part.Anchored = true
    part.CanCollide = false
    part.CastShadow = false
    
    -- Couleur selon rareté
    local couleur = rarete.couleur or COULEURS_RARETE[rarete.nom] or Color3.fromRGB(255, 255, 255)
    part.BrickColor = BrickColor.new(couleur)
    part.Material = Enum.Material.Neon
    
    -- Glow effect pour les rares+
    if rarete.nom == "Rare" or rarete.nom == "Epic" or rarete.nom == "Legendary" or rarete.nom == "Secret" then
        local light = Instance.new("PointLight")
        light.Brightness = 2
        light.Range = 8
        light.Color = couleur
        light.Parent = part
    end
    
    -- Billboard avec le nom de la rareté
    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 80, 0, 30)
    billboard.StudsOffset = Vector3.new(0, 2, 0)
    billboard.AlwaysOnTop = false
    billboard.Parent = part
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextStrokeTransparency = 0
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.Text = rarete.nom == "Common" and Config.CollectibleName or ("⭐ " .. rarete.nom)
    label.Parent = billboard
    
    -- Rotation animation
    local weld = Instance.new("BodyAngularVelocity")
    weld.AngularVelocity = Vector3.new(0, 1, 0)
    weld.MaxTorque = Vector3.new(0, math.huge, 0)
    weld.Parent = part
    
    -- Stocker les métadonnées dans les attributs
    part:SetAttribute("Rarete", rarete.nom)
    part:SetAttribute("Valeur", rarete.valeur)
    
    part.Parent = workspace.SpawnZones
    
    return part
end

-- ═══════════════════════════════════════════════
-- SPAWN D'UN COLLECTIBLE
-- ═══════════════════════════════════════════════

local function SpawnerUnCollectible()
    if #collectiblesActifs >= MAX_COLLECTIBLES_MAP then return end
    if #spawnZones == 0 then return end
    
    -- Choisir zone aléatoire
    local zone = spawnZones[math.random(1, #spawnZones)]
    local position = PositionAleatoireDansZone(zone)
    
    -- Tirer la rareté
    local rarete = CollectSystem.TirerRarete()
    
    -- Créer le collectible
    local id = GenererID()
    local part = CreerCollectiblePart(id, position, rarete)
    
    -- Enregistrer avec timer de despawn
    collectiblesActifs[#collectiblesActifs + 1] = {
        id       = id,
        part     = part,
        rarete   = rarete,
        expireAt = os.time() + DESPAWN_APRES_SECONDES,
    }
    
    -- Touch detection (collecte par le joueur)
    part.Touched:Connect(function(hit)
        local character = hit.Parent
        local player = Players:GetPlayerByCharacter(character)
        if not player then return end
        if not part.Parent then return end  -- déjà collecté
        
        -- Signaler au serveur (Main.server.lua gère la validation)
        local DemandeCollecte = ReplicatedStorage:FindFirstChild("DemandeCollecte")
        if DemandeCollecte then
            -- Le client envoie la demande, mais ici c'est le serveur qui valide
            -- On fire directement la logique via un événement interne
            local collectEvent = ReplicatedStorage:FindFirstChild("_InternalCollect")
            if collectEvent then
                collectEvent:Fire(player, id, rarete)
            end
        end
    end)
end

-- ═══════════════════════════════════════════════
-- NETTOYAGE DES COLLECTIBLES EXPIRÉS
-- ═══════════════════════════════════════════════

local function NettoyerExpires()
    local now = os.time()
    local nouveauxActifs = {}
    
    for _, entry in ipairs(collectiblesActifs) do
        if entry.expireAt <= now then
            -- Despawn avec effet
            if entry.part and entry.part.Parent then
                entry.part:Destroy()
            end
        else
            nouveauxActifs[#nouveauxActifs + 1] = entry
        end
    end
    
    collectiblesActifs = nouveauxActifs
end

-- Supprime un collectible par ID (après collecte)
function SpawnManager.SupprimerCollectible(id)
    for i, entry in ipairs(collectiblesActifs) do
        if entry.id == id then
            if entry.part and entry.part.Parent then
                entry.part:Destroy()
            end
            table.remove(collectiblesActifs, i)
            return
        end
    end
end

-- ═══════════════════════════════════════════════
-- AUTO COLLECT (Game Pass)
-- ═══════════════════════════════════════════════

function SpawnManager.StartAutoCollect(player, data)
    task.spawn(function()
        while player.Parent do
            task.wait(3)  -- collecte auto toutes les 3 secondes
            if not player.Parent then break end
            
            -- Collecter le collectible le plus proche
            local char = player.Character
            if not char or not char.PrimaryPart then continue end
            
            local playerPos = char.PrimaryPart.Position
            local plusProche = nil
            local distMin = 15  -- rayon de collecte auto
            
            for _, entry in ipairs(collectiblesActifs) do
                if entry.part and entry.part.Parent then
                    local dist = (entry.part.Position - playerPos).Magnitude
                    if dist < distMin then
                        distMin = dist
                        plusProche = entry
                    end
                end
            end
            
            if plusProche then
                -- Simuler une collecte
                local collectEvent = ReplicatedStorage:FindFirstChild("_InternalCollect")
                if collectEvent then
                    collectEvent:Fire(player, plusProche.id, plusProche.rarete)
                end
            end
        end
    end)
end

-- ═══════════════════════════════════════════════
-- BOUCLE PRINCIPALE DE SPAWN
-- ═══════════════════════════════════════════════

local function BoucleSpawn()
    while true do
        -- Calcul du délai selon le nombre de joueurs connectés
        local nbJoueurs = #Players:GetPlayers()
        if nbJoueurs == 0 then
            task.wait(5)
            continue
        end
        
        -- Spawner selon le taux de base
        local delai = Config.BaseSpawnRate
        
        -- Boost si event actif
        if CollectSystem.EventMultiplier > 1 then
            delai = delai / CollectSystem.EventMultiplier
        end
        
        task.wait(delai)
        
        -- Spawner plusieurs collectibles selon joueurs connectés
        local nbASpawner = math.min(nbJoueurs, 3)
        for i = 1, nbASpawner do
            SpawnerUnCollectible()
        end
        
        -- Nettoyer les expirés toutes les 10 spawns
        if idCounter % 10 == 0 then
            NettoyerExpires()
        end
    end
end

-- ═══════════════════════════════════════════════
-- INIT
-- ═══════════════════════════════════════════════

function SpawnManager.Init()
    -- Créer le dossier SpawnZones s'il n'existe pas
    local spawnZonesFolder = workspace:FindFirstChild("SpawnZones")
    if not spawnZonesFolder then
        spawnZonesFolder = Instance.new("Folder")
        spawnZonesFolder.Name = "SpawnZones"
        spawnZonesFolder.Parent = workspace
        
        -- Créer une zone par défaut (à remplacer dans Studio)
        local defaultZone = Instance.new("Part")
        defaultZone.Name = "Zone_1"
        defaultZone.Size = Vector3.new(100, 1, 100)
        defaultZone.Position = Vector3.new(0, 0, 0)
        defaultZone.Anchored = true
        defaultZone.Transparency = 1
        defaultZone.CanCollide = false
        defaultZone.Parent = spawnZonesFolder
        
        warn("[SpawnManager] Zone par défaut créée. Remplace Zone_1 dans Workspace/SpawnZones.")
    end
    
    -- Charger toutes les zones
    for _, child in ipairs(spawnZonesFolder:GetChildren()) do
        if child:IsA("Part") and child.Name:sub(1, 5) == "Zone_" then
            spawnZones[#spawnZones + 1] = child
        end
    end
    
    -- Créer l'événement interne pour la collecte
    local bindable = Instance.new("BindableEvent")
    bindable.Name = "_InternalCollect"
    bindable.Parent = ReplicatedStorage
    
    print("[SpawnManager] " .. #spawnZones .. " zone(s) de spawn chargée(s) ✓")
    
    -- Lancer la boucle de spawn
    task.spawn(BoucleSpawn)
    
    print("[SpawnManager] Boucle de spawn démarrée ✓")
end

return SpawnManager
