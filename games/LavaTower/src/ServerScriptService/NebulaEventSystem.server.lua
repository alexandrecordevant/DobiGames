-- ServerScriptService/NebulaEventSystem.server.lua
-- Événement Nebula : swap Deco <-> DecoMutation (rose fluo) + Map CrackedLava rose, durée 15 min

local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage       = game:GetService("ServerStorage")
local Workspace           = game:GetService("Workspace")

local Logger = require(ServerScriptService.SharedLib.Server.Logger)

local DUREE_SECONDES = 15 * 60
local ROSE_NEBULA    = Color3.fromRGB(255, 0, 200)

-- Refs workspace (mêmes dossiers que ToxicEventSystem)
local deco         = Workspace:FindFirstChild("Deco")
local decoMutation = Workspace:FindFirstChild("DecoMutation")
local mapFolder    = Workspace:FindFirstChild("Map")

if not deco         then Logger.warn("NebulaEvent", "Deco introuvable dans Workspace")         end
if not decoMutation then Logger.warn("NebulaEvent", "DecoMutation introuvable dans Workspace") end
if not mapFolder    then Logger.warn("NebulaEvent", "Map introuvable dans Workspace")          end

-- Refs plateformes TP
local tpFolder      = Workspace:FindFirstChild("TP")
local tpTourNormal  = tpFolder and tpFolder:FindFirstChild("TP_Tour")
local tpVIPNormal   = tpFolder and tpFolder:FindFirstChild("TP_VIP")
local tpEventFolder = tpFolder and tpFolder:FindFirstChild("Event")

if not tpTourNormal  then Logger.warn("NebulaEvent", "TP/TP_Tour introuvable")  end
if not tpVIPNormal   then Logger.warn("NebulaEvent", "TP/TP_VIP introuvable")   end
if not tpEventFolder then Logger.warn("NebulaEvent", "TP/Event introuvable")    end

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

-- TP Event invisible par défaut au démarrage
if tpEventFolder then
	hideFolder(tpEventFolder)
end

-- Flag partagé (lu par BrainrotPlatformSpawner)
local nebulaFlag       = Instance.new("BoolValue")
nebulaFlag.Name        = "NebulaEventActif"
nebulaFlag.Value       = false
nebulaFlag.Parent      = ServerStorage

local function CreerRE(nom)
	local existing = ReplicatedStorage:FindFirstChild(nom)
	if existing then return existing end
	local re = Instance.new("RemoteEvent")
	re.Name   = nom
	re.Parent = ReplicatedStorage
	return re
end

local ActivateNebulaEvent = CreerRE("ActivateNebulaEvent")  -- client → serveur (toggle)
local NebulaEventState    = CreerRE("NebulaEventState")     -- serveur → clients (active, endTime)

local nebulaActif   = false
local nebulaEndTime = 0
local nebulaThread  = nil

local function stopperNebula()
	if not nebulaActif then return end
	nebulaActif = false
	if nebulaThread then
		task.cancel(nebulaThread)
		nebulaThread = nil
	end

	showFolder(deco)
	hideFolder(decoMutation)
	showFolder(tpTourNormal)
	showFolder(tpVIPNormal)
	hideFolder(tpEventFolder)

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
		Logger.info("NebulaEvent", "Map restaurée ✓")
	end

	nebulaFlag.Value = false
	NebulaEventState:FireAllClients(false, 0)
	Logger.info("NebulaEvent", "Événement Nebula terminé")
end

local function activerNebula()
	if nebulaActif then return end
	nebulaActif   = true
	nebulaEndTime = os.time() + DUREE_SECONDES

	sauvegarderMap()
	hideFolder(deco)
	showFolder(decoMutation)
	colorierFolder(decoMutation, ROSE_NEBULA)
	hideFolder(tpTourNormal)
	hideFolder(tpVIPNormal)
	showFolder(tpEventFolder)

	if mapFolder then
		for _, desc in ipairs(mapFolder:GetDescendants()) do
			if desc:IsA("BasePart") then
				desc.Material = Enum.Material.CrackedLava
				desc.Color    = ROSE_NEBULA
			end
		end
		Logger.info("NebulaEvent", "Map convertie CrackedLava rose fluo ✓")
	end

	nebulaFlag.Value = true
	NebulaEventState:FireAllClients(true, nebulaEndTime)
	Logger.info("NebulaEvent", "Événement Nebula activé pour %d min", DUREE_SECONDES / 60)

	nebulaThread = task.delay(DUREE_SECONDES, function()
		stopperNebula()
	end)
end

ActivateNebulaEvent.OnServerEvent:Connect(function(player)
	if nebulaActif then
		Logger.info("NebulaEvent", "Stop demandé par %s", player.Name)
		stopperNebula()
	else
		Logger.info("NebulaEvent", "Start demandé par %s", player.Name)
		activerNebula()
	end
end)

Logger.info("NebulaEvent", "NebulaEventSystem initialisé ✓")
