-- PadTP.server.lua
-- Téléportation immédiate sur les tours personnelles (Tour1, Tour2, …)
-- Chaque tour est configurée automatiquement : aucun hardcode sur un nom précis.

-- ============================================================
-- CONFIGURATION
-- ============================================================

-- Nom du dossier des triggers dans chaque tour personnelle
local NOM_TRIGGERS   = "Triggers"
-- Nom de la part de déclenchement du TP
local NOM_START_ZONE = "StartZone"
-- Nom du point d'arrivée à l'intérieur de la tour
local NOM_SPAWN      = "InterriorSpawn"
-- Délai minimum entre deux TP pour le même joueur (anti-spam Touched)
local TP_COOLDOWN    = 1  -- secondes

local Players = game:GetService("Players")

-- ============================================================
-- Utilitaire : est-ce une tour personnelle ?
-- Tour personnelle = "Tour" suivi uniquement de chiffres  (Tour1, Tour2…)
-- Exclut : TourCommune, TourVIP, TourBoss, etc.
-- ============================================================
local function estTourPersonnelle(nom)
    return nom:match("^Tour%d+$") ~= nil
end

-- ============================================================
-- Setup du pad de TP d'une tour personnelle
-- ============================================================
local function setupTourPersonnelle(tour)
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

    -- Anti-spam par joueur : { [userId] = os.clock() du dernier TP }
    local derniersTP = {}

    startZone.Touched:Connect(function(hit)
        local character = hit.Parent
        local player    = Players:GetPlayerFromCharacter(character)
        if not player then return end

        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        -- Anti-spam : ignorer si TP trop récent
        local now = os.clock()
        if now - (derniersTP[player.UserId] or 0) < TP_COOLDOWN then return end
        derniersTP[player.UserId] = now

        -- Téléportation vers l'intérieur de CETTE tour uniquement
        hrp.CFrame = interiorSpawn.CFrame + Vector3.new(0, 3, 0)
        print(("[PadTP] %s → %s"):format(player.Name, tour.Name))
    end)

    print(("[PadTP] ✓ %s configurée"):format(tour.Name))
end

-- ============================================================
-- Scan au démarrage + écoute des tours ajoutées dynamiquement
-- ============================================================
task.spawn(function()
    task.wait(2)  -- laisser workspace se charger

    for _, enfant in ipairs(workspace:GetChildren()) do
        if enfant:IsA("Model") and estTourPersonnelle(enfant.Name) then
            setupTourPersonnelle(enfant)
        end
    end

    -- Tours ajoutées dynamiquement (spawner de tours runtime)
    workspace.ChildAdded:Connect(function(enfant)
        if enfant:IsA("Model") and estTourPersonnelle(enfant.Name) then
            setupTourPersonnelle(enfant)
        end
    end)
end)
