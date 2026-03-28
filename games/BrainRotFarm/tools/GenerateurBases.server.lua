-- shared-lib/server/GenerateurBases.server.lua
-- DobiGames — Générateur de structure Workspace pour le système Base + Rebirth
-- Studio UNIQUEMENT — supprime et recrée Workspace.Bases à chaque exécution
--
-- UTILISATION :
--   1. Coller ce script dans ServerScriptService via Studio
--   2. Lancer Play (ou Run) une fois → structure générée dans Workspace
--   3. Positionner manuellement les Base_X dans la map
--   4. Supprimer ce script avant publication
--
-- PARAMÈTRES CONFIGURABLES (section CONFIG ci-dessous)

local RunService = game:GetService("RunService")
if not RunService:IsStudio() then return end

-- ============================================================
-- CONFIG — adapter selon le jeu
-- ============================================================

local CONFIG = {
    -- Nombre de bases joueurs
    nbBases = 6,

    -- Floors par base (index → { nom Studio, nbSpots })
    floors = {
        { index = 1, nom = "Floor_1", nbSpots = 10 },
        { index = 2, nom = "Floor_2", nbSpots = 10 },
        { index = 3, nom = "Floor_3", nbSpots = 10 },
        { index = 4, nom = "Floor_4", nbSpots = 10 },
    },

    -- Disposition des bases (grille simple, ajustable manuellement ensuite)
    -- Espacement entre chaque base (studs)
    espacementX = 120,
    espacementZ = 0,

    -- Hauteur de départ (Y)
    hauteurBase = 5,

    -- Taille des parts de structure et spots
    tailleFloor     = Vector3.new(60, 2, 60),    -- Tous les floors (Plancher à l'intérieur du Model)
    tailleSpot      = Vector3.new(8, 1, 8),      -- Spot visible
    tailleTouchPart = Vector3.new(8, 2, 8),      -- TouchPart (collidable + trigger)

    -- Décalage vertical entre floors
    hauteurEntreFloors = 12,

    -- Espacement des spots en grille 2×5 dans chaque floor
    spacingSpotX = 10,
    spacingSpotZ = 10,

    -- Couleurs
    couleurFloor1   = Color3.fromRGB(120, 80,  40),   -- marron bois
    couleurFloorSup = Color3.fromRGB(100, 70,  30),
    couleurSpot     = Color3.fromRGB(200, 200, 200),  -- gris clair
    couleurSpawn    = Color3.fromRGB(0,   200, 100),  -- vert spawn
    couleurBoard    = Color3.fromRGB(60,  40,  20),   -- marron foncé

    -- Générer un Board (panneau rebirth) devant chaque base
    genererBoard = true,
    tailleBoard  = Vector3.new(4, 6, 0.5),
}

-- ============================================================
-- Utilitaires
-- ============================================================

local Workspace = game:GetService("Workspace")

local function creerPart(nom, taille, couleur, parent, ancrage)
    local p = Instance.new("Part")
    p.Name        = nom
    p.Size        = taille
    p.BrickColor  = BrickColor.new(couleur)
    p.Color       = couleur
    p.Anchored    = (ancrage == nil) and true or ancrage
    p.CanCollide  = true
    p.CastShadow  = true
    p.Parent      = parent
    return p
end

local function creerModel(nom, parent)
    local m = Instance.new("Model")
    m.Name   = nom
    m.Parent = parent
    return m
end

-- Calcule la position d'un spot dans sa grille (2 colonnes × 5 lignes)
-- index 1..10 → position locale dans le floor
local function positionSpot(spotIndex, floorPos)
    local col = (spotIndex - 1) % 2       -- 0 ou 1
    local row = math.floor((spotIndex - 1) / 2)  -- 0..4
    local ox  = (col - 0.5) * CONFIG.spacingSpotX
    local oz  = (row - 2)   * CONFIG.spacingSpotZ
    return Vector3.new(floorPos.X + ox, floorPos.Y + 1, floorPos.Z + oz)
end

-- ============================================================
-- Génération d'un spot (Model avec Part visible + TouchPart)
-- ============================================================

local function creerSpot(nom, position, parent)
    local spotModel = creerModel(nom, parent)

    -- Part visible (décorative, transparente à 0)
    local partVisible = Instance.new("Part")
    partVisible.Name        = "Part"
    partVisible.Size        = CONFIG.tailleSpot
    partVisible.CFrame      = CFrame.new(position)
    partVisible.Anchored    = true
    partVisible.CanCollide  = true
    partVisible.Color       = CONFIG.couleurSpot
    partVisible.Material    = Enum.Material.SmoothPlastic
    partVisible.Parent      = spotModel

    -- TouchPart (déclencheur de dépôt, légèrement surélevé)
    local touchPart = Instance.new("Part")
    touchPart.Name        = "TouchPart"
    touchPart.Size        = CONFIG.tailleTouchPart
    touchPart.CFrame      = CFrame.new(position + Vector3.new(0, 0.5, 0))
    touchPart.Anchored    = true
    touchPart.CanCollide  = true
    touchPart.Transparency = 0.8
    touchPart.Color       = Color3.fromRGB(100, 255, 100)
    touchPart.Material    = Enum.Material.Neon
    touchPart.Parent      = spotModel

    -- PrimaryPart = TouchPart (utilisé par DropSystem)
    spotModel.PrimaryPart = touchPart

    return spotModel
end

-- ============================================================
-- Génération d'une base complète
-- ============================================================

local function genererBase(baseIndex, originPos)
    local baseRoot = creerModel("Base_" .. baseIndex, nil)

    -- Conteneur interne "Base" (attendu par BaseProgressionSystem)
    local baseContainer = creerModel("Base", baseRoot)

    local posActuelle = originPos

    -- Tous les floors sont des Models (structure uniforme — renommable, compatible système)
    for _, floorDef in ipairs(CONFIG.floors) do
        local floorPos   = posActuelle
        local floorModel = creerModel(floorDef.nom, baseContainer)

        -- Plancher (Part physique à l'intérieur du Model)
        local couleur  = floorDef.index == 1 and CONFIG.couleurFloor1 or CONFIG.couleurFloorSup
        local plancher = creerPart("Plancher", CONFIG.tailleFloor, couleur, floorModel)
        plancher.CFrame = CFrame.new(floorPos)

        -- Spots 1-10
        for spotNum = 1, floorDef.nbSpots do
            local spotPos = positionSpot(spotNum, floorPos + Vector3.new(0, 1, 0))
            creerSpot("spot_" .. spotNum, spotPos, floorModel)
        end

        posActuelle = posActuelle + Vector3.new(0, CONFIG.hauteurEntreFloors, 0)
    end

    -- Board rebirth (dans Base, comme dans le workspace réel)
    if CONFIG.genererBoard then
        local boardPart = creerPart("Board", CONFIG.tailleBoard, CONFIG.couleurBoard, baseContainer)
        boardPart.CFrame = CFrame.new(originPos + Vector3.new(0, 4, -35))

        local bb = Instance.new("BillboardGui")
        bb.Name           = "Gui"
        bb.Size           = UDim2.new(0, 200, 0, 80)
        bb.StudsOffset    = Vector3.new(0, 0, 0.3)
        bb.AlwaysOnTop    = false
        bb.Parent         = boardPart

        local lblBoard = Instance.new("TextLabel", bb)
        lblBoard.Name                   = "Texto"
        lblBoard.Size                   = UDim2.new(1, 0, 1, 0)
        lblBoard.BackgroundTransparency = 1
        lblBoard.Text                   = "🔄 REBIRTH\nClick to view"
        lblBoard.Font                   = Enum.Font.GothamBold
        lblBoard.TextSize               = 18
        lblBoard.TextColor3             = Color3.new(1, 1, 1)
        lblBoard.TextWrapped            = true

        local cd = Instance.new("ClickDetector")
        cd.MaxActivationDistance = 20
        cd.Parent = boardPart
    end

    -- SpawnZone (dossier vide — à remplir manuellement dans la map)
    local spawnZone      = Instance.new("Folder")
    spawnZone.Name       = "SpawnZone"
    spawnZone.Parent     = baseRoot

    -- SpawnLocation devant la base
    local spawnLoc = Instance.new("SpawnLocation")
    spawnLoc.Name      = "SpawnLocation"
    spawnLoc.Size      = Vector3.new(6, 1, 6)
    spawnLoc.CFrame    = CFrame.new(originPos + Vector3.new(0, 1, -40))
    spawnLoc.Anchored  = true
    spawnLoc.Color     = BrickColor.new(CONFIG.couleurSpawn)
    spawnLoc.TeamColor = BrickColor.new("Bright green")
    spawnLoc.Neutral   = true
    spawnLoc.Parent    = baseRoot

    -- Attacher au bon endroit
    baseRoot.Parent = Workspace:FindFirstChild("Bases") or Workspace

    print(string.format("[GenerateurBases] Base_%d créée à (%.0f, %.0f, %.0f)",
        baseIndex, originPos.X, originPos.Y, originPos.Z))

    return baseRoot
end

-- ============================================================
-- Génération principale
-- ============================================================

print("[GenerateurBases] Démarrage...")

-- Créer ou vider le dossier Bases
local basesFolder = Workspace:FindFirstChild("Bases")
if basesFolder then
    basesFolder:Destroy()
    task.wait(0.1)
end
basesFolder = Instance.new("Folder")
basesFolder.Name   = "Bases"
basesFolder.Parent = Workspace

-- Générer chaque base sur une ligne horizontale
for i = 1, CONFIG.nbBases do
    local originX = (i - 1) * CONFIG.espacementX
    local originZ = CONFIG.espacementZ
    local originY = CONFIG.hauteurBase

    genererBase(i, Vector3.new(originX, originY, originZ))
    task.wait(0.05)  -- Laisser respirer l'éditeur entre chaque base
end

print(string.format(
    "[GenerateurBases] ✅ %d bases générées dans Workspace.Bases",
    CONFIG.nbBases
))
print("[GenerateurBases] → Positionner les bases manuellement dans la map")
print("[GenerateurBases] → Supprimer ce script avant publication")
