-- ServerScriptService/Common/AssignationSystem.lua
-- DobiGames — Assignation automatique base ↔ joueur
-- Libère la base à la déconnexion, notifie les autres joueurs

local AssignationSystem = {}

-- ============================================================
-- Services
-- ============================================================
local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ============================================================
-- Config
-- ============================================================
local Config = require(ReplicatedStorage.Specialized.GameConfig)

-- ============================================================
-- Configuration
-- ============================================================
-- Nombre maximum de bases disponibles en simultané
local MAX_BASES = Config.MaxBases

-- ============================================================
-- État interne
-- ============================================================
local assignations   = {}  -- [userId]    = baseIndex
local joueurParBase  = {}  -- [baseIndex] = player

-- Callback déclenché après une assignation réussie
-- Main.server.lua doit brancher :
--   AssignationSystem.OnAssigned = function(player, baseIndex) ... end
AssignationSystem.OnAssigned = nil

-- ============================================================
-- Utilitaires — notifications
-- ============================================================

local function notifierJoueur(player, typeNotif, msg)
    local ev = ReplicatedStorage:FindFirstChild("NotifEvent")
    if ev then pcall(function() ev:FireClient(player, typeNotif, msg) end) end
end

local function notifierTous(typeNotif, msg)
    local ev = ReplicatedStorage:FindFirstChild("NotifEvent")
    if ev then pcall(function() ev:FireAllClients(typeNotif, msg) end) end
end

-- ============================================================
-- Utilitaires — spawn / téléportation
-- ============================================================

-- Calcule le CFrame de spawn d'une base
-- Priorité : SpawnLocation Roblox → BasePart nommé spawn* → Fallback pivot
local function trouverCFrameSpawn(baseIndex)
    local bases = Workspace:FindFirstChild("Bases")
    if not bases then return nil end
    local baseRoot = bases:FindFirstChild("Base_" .. tostring(baseIndex))
    if not baseRoot then return nil end

    -- Priorité 1 : objet SpawnLocation Roblox (face au ChampCommun)
    -- FindFirstChildWhichIsA cherche dans les enfants directs
    local sl = baseRoot:FindFirstChildWhichIsA("SpawnLocation")
    if sl then
        return sl.CFrame + Vector3.new(0, 4, 0)
    end
    -- Chercher aussi en descendants
    for _, desc in ipairs(baseRoot:GetDescendants()) do
        if desc:IsA("SpawnLocation") then
            return desc.CFrame + Vector3.new(0, 4, 0)
        end
    end

    -- Priorité 2 : BasePart nommé "spawnlocation", "spawnpoint" ou "spawn"
    for _, desc in ipairs(baseRoot:GetDescendants()) do
        if desc:IsA("BasePart") then
            local n = string.lower(desc.Name or "")
            if n == "spawnlocation" or n == "spawnpoint" or n == "spawn" then
                return desc.CFrame + Vector3.new(0, 4, 0)
            end
        end
    end

    -- Priorité 3 : SpawnZone (Folder avec murs = zone de spawn des BRs)
    -- ATTENTION : retourne le centre du champ — utilisé seulement en dernier recours
    local spawnZone = baseRoot:FindFirstChild("SpawnZone")
    if spawnZone then
        if spawnZone:IsA("BasePart") then
            return spawnZone.CFrame + Vector3.new(0, 4, 0)
        end
        local wallTop    = spawnZone:FindFirstChild("Wall_Top")
        local wallBottom = spawnZone:FindFirstChild("Wall_Bottom")
        local wallLeft   = spawnZone:FindFirstChild("Wall_Left")
        local wallRight  = spawnZone:FindFirstChild("Wall_Right")
        if wallTop and wallBottom and wallLeft and wallRight then
            local x = (wallLeft.Position.X  + wallRight.Position.X) / 2
            local z = (wallTop.Position.Z   + wallBottom.Position.Z) / 2
            local y = math.max(
                wallTop.Position.Y, wallBottom.Position.Y,
                wallLeft.Position.Y, wallRight.Position.Y
            ) + 4
            return CFrame.new(x, y, z)
        end
    end

    -- Fallback : pivot du modèle
    local ok, cf = pcall(function() return baseRoot:GetPivot() end)
    if ok and cf then return cf + Vector3.new(0, 5, 0) end
    return nil
end

-- Téléporte le joueur vers sa base (attend le personnage si nécessaire)
local function teleporterVersBase(player, baseIndex)
    task.spawn(function()
        -- Attendre le personnage (connexion initiale ou respawn)
        local char = player.Character
        if not char then
            char = player.CharacterAdded:Wait()
        end
        local hrp = char:FindFirstChild("HumanoidRootPart")
                    or char:WaitForChild("HumanoidRootPart", 5)
        if not hrp then return end

        -- Petit délai pour que le client finisse de charger
        task.wait(0.3)
        local cframe = trouverCFrameSpawn(baseIndex)
        if cframe then
            pcall(function() char:PivotTo(cframe) end)
        end
    end)
end

-- ============================================================
-- Logique d'assignation
-- ============================================================

-- Retourne le premier index de base libre (1 en priorité)
local function premierBaseLibe()
    for i = 1, MAX_BASES do
        if not joueurParBase[i] then
            return i
        end
    end
    return nil
end

-- Assigne une base au joueur et déclenche le callback OnAssigned
-- Retourne le baseIndex assigné, ou nil si serveur plein
local function assigner(player)
    -- Ne jamais réassigner un joueur déjà en jeu
    if assignations[player.UserId] then
        return assignations[player.UserId]
    end

    local baseIndex = premierBaseLibe()

    if not baseIndex then
        -- Serveur plein → mode spectateur (observer uniquement)
        notifierJoueur(player, "INFO", "👀 Server full — spectator mode")
        warn("[AssignationSystem] " .. player.Name .. " → spectateur (toutes les bases occupées)")
        return nil
    end

    -- Enregistrer l'assignation
    assignations[player.UserId] = baseIndex
    joueurParBase[baseIndex]    = player

    -- Informer le joueur et le téléporter
    notifierJoueur(player, "INFO", "🏠 Base " .. baseIndex .. " assigned — welcome!")
    teleporterVersBase(player, baseIndex)

    -- Re-téléporter à chaque respawn pour toujours revenir face à la base
    player.CharacterAdded:Connect(function()
        local idx = assignations[player.UserId]
        if idx then
            task.delay(0.3, function()
                if player.Parent then
                    teleporterVersBase(player, idx)
                end
            end)
        end
    end)

    print("[AssignationSystem] " .. player.Name .. " → Base_" .. baseIndex)

    -- Déclencher le callback (Main.server.lua init BaseProgression, DropSystem, IncomeSystem...)
    if AssignationSystem.OnAssigned then
        task.spawn(function()
            pcall(AssignationSystem.OnAssigned, player, baseIndex)
        end)
    end

    return baseIndex
end

-- Libère la base d'un joueur (déconnexion)
local function liberer(player)
    local baseIndex = assignations[player.UserId]
    if not baseIndex then return end

    assignations[player.UserId] = nil
    joueurParBase[baseIndex]    = nil

    notifierTous("INFO", "🏠 " .. player.Name .. " left — Base " .. baseIndex .. " available!")
    print("[AssignationSystem] Base_" .. baseIndex .. " libérée (départ de " .. player.Name .. ")")
end

-- ============================================================
-- API publique
-- ============================================================

-- Retourne l'index de base du joueur (nil si non assigné / spectateur)
function AssignationSystem.GetBaseIndex(player)
    return assignations[player.UserId]
end

-- Retourne le Model Studio de la base du joueur
function AssignationSystem.GetBaseModel(player)
    local baseIndex = assignations[player.UserId]
    if not baseIndex then return nil end
    local bases = Workspace:FindFirstChild("Bases")
    return bases and bases:FindFirstChild("Base_" .. baseIndex)
end

-- Retourne le joueur occupant une base donnée (nil si libre)
function AssignationSystem.GetJoueurBase(baseIndex)
    return joueurParBase[baseIndex]
end

-- Vrai si le joueur a une base assignée
function AssignationSystem.IsAssigned(player)
    return assignations[player.UserId] ~= nil
end

-- Assigne explicitement un joueur (appelé depuis Main.server.lua après chargement des données)
-- Retourne baseIndex ou nil
function AssignationSystem.AssignerJoueur(player)
    return assigner(player)
end

-- Libère la base d'un joueur (appelé depuis Main.server.lua OnPlayerRemoving)
function AssignationSystem.LibererBase(player)
    liberer(player)
end

-- Initialise le système (connexion PlayerRemoving uniquement —
-- Main.server.lua appelle AssignerJoueur manuellement depuis OnPlayerAdded)
function AssignationSystem.Init()
    -- Libérer automatiquement à la déconnexion
    Players.PlayerRemoving:Connect(liberer)

    -- Gérer les joueurs déjà présents en mémoire (redémarrage à chaud, edge case)
    for _, player in ipairs(Players:GetPlayers()) do
        if not assignations[player.UserId] then
            assigner(player)
        end
    end

    print("[AssignationSystem] ✓ Initialisé (MAX_BASES = " .. MAX_BASES .. ")")
end

return AssignationSystem
