-- ServerScriptService/ToxicEventSystem.server.lua
-- Événement Toxic : swap Deco <-> DecoMutation (vert fluo) + Map CrackedLava vert, durée 15 min

local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage       = game:GetService("ServerStorage")
local Workspace           = game:GetService("Workspace")

local Logger = require(ServerScriptService.SharedLib.Server.Logger)

local DUREE_SECONDES  = 15 * 60
local VERT_FLUO       = Color3.fromRGB(0, 255, 0)

-- Refs workspace (Deco et DecoMutation à la racine du workspace)
local deco         = Workspace:FindFirstChild("Deco")
local decoMutation = Workspace:FindFirstChild("DecoMutation")
local mapFolder    = Workspace:FindFirstChild("Map")

if not deco         then Logger.warn("ToxicEvent", "Deco introuvable dans Workspace")         end
if not decoMutation then Logger.warn("ToxicEvent", "DecoMutation introuvable dans Workspace") end
if not mapFolder    then Logger.warn("ToxicEvent", "Map introuvable dans Workspace")          end

-- Sauvegarde matériaux/couleurs originaux de la Map
local originalMapData = {}

local function sauvegarderMap()
    if not mapFolder then return end
    originalMapData = {}
    for _, desc in ipairs(mapFolder:GetDescendants()) do
        if desc:IsA("BasePart") then
            originalMapData[desc] = { material = desc.Material, color = desc.Color }
        end
    end
end

local function hideFolder(parent)
    if not parent then return end
    for _, desc in ipairs(parent:GetDescendants()) do
        if desc:IsA("BasePart") then
            desc.Transparency = 1
            desc.CanCollide   = false
            desc.CastShadow   = false
        end
    end
end

local function showFolder(parent)
    if not parent then return end
    for _, desc in ipairs(parent:GetDescendants()) do
        if desc:IsA("BasePart") then
            desc.Transparency = 0
            desc.CanCollide   = true
            desc.CastShadow   = true
        end
    end
end

local function colorierFolder(parent, couleur)
    if not parent then return end
    for _, desc in ipairs(parent:GetDescendants()) do
        if desc:IsA("BasePart") then
            desc.Color = couleur
        end
    end
end

-- Flag partagé avec PadTP pour le swap de lave au prochain cycle
local toxicFlag       = Instance.new("BoolValue")
toxicFlag.Name        = "ToxicEventActif"
toxicFlag.Value       = false
toxicFlag.Parent      = ServerStorage

-- DecoMutation invisible par défaut au démarrage
if decoMutation then
    hideFolder(decoMutation)
    Logger.info("ToxicEvent", "DecoMutation masqué au démarrage ✓")
end

-- RemoteEvents
local function CreerRE(nom)
    local existing = ReplicatedStorage:FindFirstChild(nom)
    if existing then return existing end
    local re = Instance.new("RemoteEvent")
    re.Name   = nom
    re.Parent = ReplicatedStorage
    return re
end

local ActivateToxicEvent = CreerRE("ActivateToxicEvent")  -- client → serveur (toggle)
local ToxicEventState    = CreerRE("ToxicEventState")     -- serveur → clients (active, endTime)

-- État
local toxicActif   = false
local toxicEndTime = 0
local toxicThread  = nil

local function stopperToxic()
    if not toxicActif then return end
    toxicActif = false
    if toxicThread then
        task.cancel(toxicThread)
        toxicThread = nil
    end

    showFolder(deco)
    hideFolder(decoMutation)

    if mapFolder then
        for _, desc in ipairs(mapFolder:GetDescendants()) do
            if desc:IsA("BasePart") then
                local orig = originalMapData[desc]
                if orig then
                    desc.Material = orig.material
                    desc.Color    = orig.color
                end
            end
        end
        Logger.info("ToxicEvent", "Map restaurée ✓")
    end

    toxicFlag.Value = false
    ToxicEventState:FireAllClients(false, 0)
    Logger.info("ToxicEvent", "Événement Toxic terminé")
end

local function activerToxic()
    if toxicActif then return end
    toxicActif   = true
    toxicEndTime = os.time() + DUREE_SECONDES

    sauvegarderMap()
    hideFolder(deco)
    showFolder(decoMutation)
    colorierFolder(decoMutation, VERT_FLUO)

    if mapFolder then
        for _, desc in ipairs(mapFolder:GetDescendants()) do
            if desc:IsA("BasePart") then
                desc.Material = Enum.Material.CrackedLava
                desc.Color    = VERT_FLUO
            end
        end
        Logger.info("ToxicEvent", "Map convertie CrackedLava vert fluo ✓")
    end

    toxicFlag.Value = true
    ToxicEventState:FireAllClients(true, toxicEndTime)
    Logger.info("ToxicEvent", "Événement Toxic activé pour %d min", DUREE_SECONDES / 60)

    toxicThread = task.delay(DUREE_SECONDES, function()
        stopperToxic()
    end)
end

ActivateToxicEvent.OnServerEvent:Connect(function(player)
    if toxicActif then
        Logger.info("ToxicEvent", "Stop demandé par %s", player.Name)
        stopperToxic()
    else
        Logger.info("ToxicEvent", "Start demandé par %s", player.Name)
        activerToxic()
    end
end)

Logger.info("ToxicEvent", "ToxicEventSystem initialisé ✓")
