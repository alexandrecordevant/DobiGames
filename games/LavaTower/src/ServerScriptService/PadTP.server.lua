-- PadTP.server.lua
-- Téléportation vers la tour personnelle du joueur (Tour_1, Tour_2, …)
-- Chaque base est scannée automatiquement : seul le joueur propriétaire de la base peut entrer.

local Players             = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace           = game:GetService("Workspace")

local AssignationSystem = require(ServerScriptService.SharedLib.Server.AssignationSystem)

-- ============================================================
-- CONFIGURATION
-- ============================================================

-- Nom du dossier des triggers dans chaque tour
local NOM_TRIGGERS   = "Triggers"
-- Nom de la part de déclenchement du TP
local NOM_START_ZONE = "StartZone"
-- Nom du point d'arrivée à l'intérieur de la tour
local NOM_SPAWN      = "InterriorSpawn"
-- Nom de la part de sortie de la tour (optionnel)
local NOM_EXIT_ZONE  = "ExitZone"
-- Délai minimum entre deux TP pour le même joueur (anti-spam Touched)
local TP_COOLDOWN    = 1

-- ============================================================
-- Utilitaire : est-ce une tour personnelle ?
-- Tour personnelle = "Tour_" suivi de chiffres  (Tour_1, Tour_2…)
-- Exclut : TourCommune, TourVIP, etc.
-- ============================================================
local function estTourPersonnelle(nom)
    return nom:match("^Tour_%d+$") ~= nil
end

-- ============================================================
-- Setup du pad de TP d'une tour
-- baseIndex = index de la Base_X qui contient cette tour
-- ============================================================
local function setupTour(tour, baseIndex)
    local triggers = tour:FindFirstChild(NOM_TRIGGERS)
    if not triggers then
        warn(("[PadTP] '%s' manquant dans %s"):format(NOM_TRIGGERS, tour.Name))
        return
    end

    local startZone = triggers:FindFirstChild(NOM_START_ZONE)
    if not startZone then
        warn(("[PadTP] '%s' manquant dans %s.%s"):format(NOM_START_ZONE, tour.Name, NOM_TRIGGERS))
        return
    end

    local interiorSpawn = tour:FindFirstChild(NOM_SPAWN)
    if not interiorSpawn then
        warn(("[PadTP] '%s' manquant dans %s"):format(NOM_SPAWN, tour.Name))
        return
    end

    local derniersTP = {}

    startZone.Touched:Connect(function(hit)
        local character = hit.Parent
        local player    = Players:GetPlayerFromCharacter(character)
        if not player then return end

        -- Vérification ownership : uniquement le joueur assigné à cette base
        if AssignationSystem.GetBaseIndex(player) ~= baseIndex then return end

        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        local now = os.clock()
        if now - (derniersTP[player.UserId] or 0) < TP_COOLDOWN then return end
        derniersTP[player.UserId] = now

        hrp.CFrame = interiorSpawn.CFrame + Vector3.new(0, 3, 0)
        print(("[PadTP] %s → %s (Base_%d)"):format(player.Name, tour.Name, baseIndex))
    end)

    local exitZone = triggers:FindFirstChild(NOM_EXIT_ZONE)
    if exitZone then
        exitZone.Touched:Connect(function(hit)
            local character = hit.Parent
            local player    = Players:GetPlayerFromCharacter(character)
            if not player then return end
            if AssignationSystem.GetBaseIndex(player) ~= baseIndex then return end

            local hrp = character:FindFirstChild("HumanoidRootPart")
            if not hrp then return end

            local now = os.clock()
            if now - (derniersTP[player.UserId] or 0) < TP_COOLDOWN then return end
            derniersTP[player.UserId] = now

            local spawnCFrame = AssignationSystem.GetSpawnCFrame(baseIndex)
            if spawnCFrame then
                hrp.CFrame = spawnCFrame
                print(("[PadTP] %s ← %s (Base_%d)"):format(player.Name, tour.Name, baseIndex))
            end
        end)
    end

    print(("[PadTP] ✓ %s configurée (Base_%d)"):format(tour.Name, baseIndex))
end

-- ============================================================
-- Scanner le dossier Specific d'une base et écouter les ajouts
-- ============================================================
local function scannerSpecific(specific, baseIndex)
    for _, enfant in ipairs(specific:GetChildren()) do
        if enfant:IsA("Model") and estTourPersonnelle(enfant.Name) then
            setupTour(enfant, baseIndex)
        end
    end

    specific.ChildAdded:Connect(function(enfant)
        if enfant:IsA("Model") and estTourPersonnelle(enfant.Name) then
            setupTour(enfant, baseIndex)
        end
    end)
end

-- ============================================================
-- Démarrage : scanner toutes les bases présentes + écouter les nouvelles
-- ============================================================
task.spawn(function()
    task.wait(2)  -- laisser workspace se charger

    local bases = Workspace:WaitForChild("Bases", 10)
    if not bases then
        warn("[PadTP] ❌ Workspace.Bases introuvable")
        return
    end

    for _, base in ipairs(bases:GetChildren()) do
        local indexStr = base.Name:match("^Base_(%d+)$")
        if indexStr then
            local baseIndex = tonumber(indexStr)
            local specific  = base:FindFirstChild("Specific")
            if specific then
                scannerSpecific(specific, baseIndex)
            else
                warn(("[PadTP] Pas de dossier Specific dans %s"):format(base.Name))
            end
        end
    end

    -- Bases ajoutées dynamiquement (runtime)
    bases.ChildAdded:Connect(function(base)
        local indexStr = base.Name:match("^Base_(%d+)$")
        if not indexStr then return end
        local baseIndex = tonumber(indexStr)
        local specific  = base:WaitForChild("Specific", 5)
        if specific then
            scannerSpecific(specific, baseIndex)
        end
    end)
end)