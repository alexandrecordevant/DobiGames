-- ServerScriptService/TeleportSystem.server.lua
-- Gestion des téléportations du menu TP
-- Destinations : TOUR_VITE (TP_VIP), TOUR_COMMUNE (TP_Tour), BASE (spawn joueur)
-- InTower/TowerEntered est géré par TourCycle au moment du TP réel, pas ici.

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage       = game:GetService("ServerStorage")
local Workspace           = game:GetService("Workspace")

local Logger            = require(ServerScriptService.SharedLib.Server.Logger)
local AssignationSystem = require(ServerScriptService.SharedLib.Server.AssignationSystem)

local function getOrCreate(name)
    local e = ReplicatedStorage:FindFirstChild(name)
    if e then return e end
    e = Instance.new("RemoteEvent"); e.Name = name; e.Parent = ReplicatedStorage
    return e
end

local TeleportRequest = getOrCreate("TeleportRequest")

local COOLDOWN = 2
local DESTINATIONS_VALIDES = { TOUR_VITE = true, TOUR_COMMUNE = true, BASE = true }
local TOUR_NOM = { TOUR_VITE = "TP_VIP", TOUR_COMMUNE = "TP_Tour" }

-- ============================================================
-- Résolution de la CFrame de destination
-- ============================================================
local function getCFrame(destination, player)
    if destination == "TOUR_VITE" or destination == "TOUR_COMMUNE" then
        local folder    = Workspace:FindFirstChild("TP")
        local toxicFlag = ServerStorage:FindFirstChild("ToxicEventActif")
        local nebulaFlag = ServerStorage:FindFirstChild("NebulaEventActif")
        local eventActif = (toxicFlag and toxicFlag.Value) or (nebulaFlag and nebulaFlag.Value)
        local searchFolder = folder
        if eventActif then
            local eventFolder = folder and folder:FindFirstChild("Event")
            if eventFolder then searchFolder = eventFolder end
        end
        local model = searchFolder and searchFolder:FindFirstChild(TOUR_NOM[destination])
        if not model then
            Logger.warn("Teleport", "%s introuvable dans Workspace.TP", TOUR_NOM[destination])
            return nil
        end
        local spawn = model:FindFirstChild("InterriorSpawn", true)
        if spawn and spawn:IsA("BasePart") then
            return spawn.CFrame * CFrame.new(0, 3, 0)
        end
        return model:GetPivot() * CFrame.new(0, 3, 0)

    elseif destination == "BASE" then
        local baseIndex = AssignationSystem.GetBaseIndex(player)
        if not baseIndex then
            Logger.warn("Teleport", "Pas de base assignée pour %s", player.Name)
            return nil
        end
        if AssignationSystem.GetSpawnCFrame then
            return AssignationSystem.GetSpawnCFrame(baseIndex)
        end
        Logger.warn("Teleport", "GetSpawnCFrame non initialisé")
        return nil
    end

    return nil
end

-- ============================================================
-- Traitement des requêtes de téléportation
-- ============================================================
local cooldowns = {}

TeleportRequest.OnServerEvent:Connect(function(player, destination)
    if type(destination) ~= "string" or not DESTINATIONS_VALIDES[destination] then
        Logger.warn("Teleport", "Destination invalide '%s' de %s", tostring(destination), player.Name)
        return
    end

    local now = os.clock()
    if now - (cooldowns[player.UserId] or 0) < COOLDOWN then return end
    cooldowns[player.UserId] = now

    local character = player.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local cf = getCFrame(destination, player)
    if not cf then return end

    pcall(function() character:PivotTo(cf) end)
    Logger.info("Teleport", "%s → %s", player.Name, destination)
end)

-- ============================================================
-- Nettoyage à la déconnexion
-- ============================================================
Players.PlayerRemoving:Connect(function(player)
    cooldowns[player.UserId] = nil
end)

Logger.info("Teleport", "TeleportSystem initialisé")
