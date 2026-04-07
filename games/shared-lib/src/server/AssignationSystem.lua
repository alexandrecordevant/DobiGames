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
local Config = require(
    ReplicatedStorage:FindFirstChild("GameConfig")
    or ReplicatedStorage.Specialized.GameConfig
)
local Logger = require(script.Parent.Logger)

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

-- Callback fourni par Main.server.lua pour localiser le point de spawn d'une base
-- Signature : function(baseIndex) → CFrame ou nil
-- Permet à chaque jeu de définir sa propre structure de map
AssignationSystem.GetSpawnCFrame = nil

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

-- Téléporte le joueur vers sa base (attend le personnage si nécessaire)
local function teleporterVersBase(player, baseIndex)
    task.spawn(function()
        local char = player.Character
        if not char then
            char = player.CharacterAdded:Wait()
        end
        local hrp = char:FindFirstChild("HumanoidRootPart")
                    or char:WaitForChild("HumanoidRootPart", 5)
        if not hrp then return end

        task.wait(0.3)
        if not AssignationSystem.GetSpawnCFrame then return end
        local cframe = AssignationSystem.GetSpawnCFrame(baseIndex)
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
        notifierJoueur(player, "INFO", "Server full — spectator mode")
        Logger.warn("Assign", "%s → spectateur (toutes les bases occupées)", player.Name)
        return nil
    end

    -- Enregistrer l'assignation
    assignations[player.UserId] = baseIndex
    joueurParBase[baseIndex]    = player

    -- Marquer l'attribut BaseAssignee pour que BotSystem détecte la base occupée
    player:SetAttribute("BaseAssignee", "Base_" .. baseIndex)

    -- Informer le joueur et le téléporter
    notifierJoueur(player, "INFO", "Base " .. baseIndex .. " assigned — welcome!")
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

    Logger.info("Assign", "%s → Base_%s", player.Name, tostring(baseIndex))

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

    -- Retirer l'attribut BaseAssignee pour libérer la base côté BotSystem
    pcall(function() player:SetAttribute("BaseAssignee", nil) end)

    notifierTous("INFO", player.Name .. " left — Base " .. baseIndex .. " available!")
    Logger.info("Assign", "Base_%s libérée (départ de %s)", tostring(baseIndex), player.Name)
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

    Logger.info("Assign", "✓ Initialisé (MAX_BASES = %d)", MAX_BASES)
end

return AssignationSystem
