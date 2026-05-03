-- ServerScriptService/EventVoteSystem.server.lua
-- Vote cross-serveurs Toxic vs Nebula.
-- Chaque cycle dure VOTE_DURATION secondes à partir du premier démarrage.
-- Si 0 vote → aucun event. En prod passer VOTE_DURATION = 3600.

local DataStoreService    = game:GetService("DataStoreService")
local MessagingService    = game:GetService("MessagingService")
local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage       = game:GetService("ServerStorage")
local Workspace           = game:GetService("Workspace")

local Logger = require(ServerScriptService.SharedLib.Server.Logger)

local VOTE_DURATION = 30        -- secondes (test ; passer à 3600 pour 1 heure en prod)
local DS_KEY        = "EventVotes_v2"
local MSG_TOPIC     = "EventVoteSync"

local votesDS = DataStoreService:GetDataStore("EventVotesDS")

-- ── BindableEvents (déclenchent ToxicEventSystem / NebulaEventSystem) ────────
local function getOrCreateBE(name)
	local ex = ServerStorage:FindFirstChild(name)
	if ex then return ex end
	local be = Instance.new("BindableEvent")
	be.Name   = name
	be.Parent = ServerStorage
	return be
end

local LaunchToxicBE  = getOrCreateBE("LaunchToxicEventBE")
local LaunchNebulaBE = getOrCreateBE("LaunchNebulaEventBE")

-- ── RemoteEvents ──────────────────────────────────────────────────────────────
local function creerRE(nom)
	local ex = ReplicatedStorage:FindFirstChild(nom)
	if ex then return ex end
	local re = Instance.new("RemoteEvent")
	re.Name   = nom
	re.Parent = ReplicatedStorage
	return re
end

local EventVoteSubmit = creerRE("EventVoteSubmit")  -- client → serveur
local EventVoteUpdate = creerRE("EventVoteUpdate")  -- serveur → clients (tv, nv, cycleEnd)
local EventVoteResult = creerRE("EventVoteResult")  -- serveur → clients (winner|"none")
local OpenVoteMenu    = creerRE("OpenVoteMenu")     -- serveur → client (ouvre le menu)

-- ── État local ────────────────────────────────────────────────────────────────
local localCycleEnd  = 0
local localToxic     = 0
local localNebula    = 0
local votedThisCycle = {}   -- [userId] = true

-- ── DataStore : structure { toxic, nebula, cycleEndTime } ────────────────────
local function dsLire()
	local ok, data = pcall(function() return votesDS:GetAsync(DS_KEY) end)
	if ok and type(data) == "table" then return data end
	return nil
end

local function dsEcrire(toxic, nebula, cycleEnd)
	pcall(function()
		votesDS:SetAsync(DS_KEY, { toxic = toxic, nebula = nebula, cycleEndTime = cycleEnd })
	end)
end

-- ── Broadcast clients ─────────────────────────────────────────────────────────
local function broadcastClients()
	EventVoteUpdate:FireAllClients(localToxic, localNebula, localCycleEnd)
end

-- ── MessagingService ──────────────────────────────────────────────────────────
local function publierUpdate()
	pcall(function()
		MessagingService:PublishAsync(MSG_TOPIC, {
			toxic        = localToxic,
			nebula       = localNebula,
			cycleEndTime = localCycleEnd,
		})
	end)
end

pcall(function()
	MessagingService:SubscribeAsync(MSG_TOPIC, function(message)
		local d = message.Data
		if type(d) ~= "table" then return end
		-- Ignorer si ce n'est pas le même cycle
		if d.cycleEndTime ~= localCycleEnd then return end
		local incoming = (d.toxic or 0) + (d.nebula or 0)
		if incoming > localToxic + localNebula then
			localToxic  = d.toxic  or 0
			localNebula = d.nebula or 0
			broadcastClients()
		end
	end)
end)

-- ── Initialisation du cycle ───────────────────────────────────────────────────
-- Si un cycle actif existe dans le DataStore, on s'y joint.
-- Sinon on démarre un cycle frais VOTE_DURATION secondes à partir de maintenant.
local function initCycle()
	local data = dsLire()
	local now  = os.time()

	if data and type(data.cycleEndTime) == "number" and data.cycleEndTime > now + 2 then
		localCycleEnd = data.cycleEndTime
		localToxic    = data.toxic  or 0
		localNebula   = data.nebula or 0
		Logger.info("Vote", "Cycle rejoint — fin dans %ds (T=%d N=%d)",
			localCycleEnd - now, localToxic, localNebula)
	else
		-- FIX : cycle frais depuis maintenant, pas depuis une borne modulo
		localCycleEnd = now + VOTE_DURATION
		localToxic    = 0
		localNebula   = 0
		dsEcrire(0, 0, localCycleEnd)
		Logger.info("Vote", "Nouveau cycle démarré — fin dans %ds", VOTE_DURATION)
	end

	votedThisCycle = {}
	broadcastClients()
end

-- ── Réception d'un vote ───────────────────────────────────────────────────────
EventVoteSubmit.OnServerEvent:Connect(function(player, choix)
	if choix ~= "toxic" and choix ~= "nebula" then return end
	if os.time() >= localCycleEnd then return end            -- cycle terminé
	if votedThisCycle[player.UserId] then return end         -- déjà voté

	votedThisCycle[player.UserId] = true
	if choix == "toxic" then
		localToxic = localToxic + 1
	else
		localNebula = localNebula + 1
	end

	dsEcrire(localToxic, localNebula, localCycleEnd)
	publierUpdate()
	broadcastClients()
	Logger.info("Vote", "%s → %s (T=%d N=%d)", player.Name, choix, localToxic, localNebula)
end)

-- ── ProximityPrompt ───────────────────────────────────────────────────────────
task.spawn(function()
	-- WaitForChild pour éviter les problèmes de chargement tardif
	local eventFolder = Workspace:WaitForChild("Event", 20)
	if not eventFolder then
		Logger.warn("Vote", "Workspace.Event introuvable après 20s")
		return
	end

	-- Chercher le modèle : d'abord par nom "Event", puis n'importe quel Model
	local model = eventFolder:FindFirstChild("Event")
	if not model or not model:IsA("Model") then
		model = eventFolder:FindFirstChildWhichIsA("Model")
	end
	-- Fallback : chercher dans tous les descendants
	if not model then
		for _, desc in ipairs(eventFolder:GetDescendants()) do
			if desc:IsA("Model") and desc.PrimaryPart then
				model = desc
				break
			end
		end
	end

	if not model then
		Logger.warn("Vote", "Aucun Model dans Workspace.Event")
		return
	end

	local primary = model.PrimaryPart
	if not primary then
		-- Dernier recours : première BasePart trouvée
		for _, c in ipairs(model:GetDescendants()) do
			if c:IsA("BasePart") then primary = c; break end
		end
	end
	if not primary then
		Logger.warn("Vote", "Aucune BasePart trouvée dans le Model Event")
		return
	end

	-- Retirer un PP existant puis en créer un nouveau
	local old = primary:FindFirstChildOfClass("ProximityPrompt")
	if old then old:Destroy() end

	local pp = Instance.new("ProximityPrompt")
	pp.ActionText            = "Vote"
	pp.ObjectText            = "Event"
	pp.HoldDuration          = 0
	pp.MaxActivationDistance = 30
	pp.Style                 = Enum.ProximityPromptStyle.Default
	pp.Parent                = primary

	-- Le serveur détecte l'activation et ouvre le menu chez le bon joueur
	pp.Triggered:Connect(function(player)
		OpenVoteMenu:FireClient(player, localToxic, localNebula, localCycleEnd)
		Logger.info("Vote", "%s ouvre le menu de vote", player.Name)
	end)

	Logger.info("Vote", "ProximityPrompt installé sur '%s' (model='%s')", primary.Name, model.Name)

	-- ── BillboardGui (serveur → réplication automatique à tous les clients) ───
	local oldBB = primary:FindFirstChild("VoteBillboard")
	if oldBB then oldBB:Destroy() end

	-- Texte flottant sans fond — "Vote here" orange + timer blanc
	local bb = Instance.new("BillboardGui")
	bb.Name        = "VoteBillboard"
	bb.Size        = UDim2.new(0, 200, 0, 80)
	bb.StudsOffset = Vector3.new(0, 5, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 100
	bb.Enabled     = true
	bb.Parent      = primary

	local bbTitle = Instance.new("TextLabel")
	bbTitle.Name                   = "Title"
	bbTitle.Size                   = UDim2.new(1, 0, 0.55, 0)
	bbTitle.Position               = UDim2.new(0, 0, 0, 0)
	bbTitle.BackgroundTransparency = 1
	bbTitle.TextColor3             = Color3.fromRGB(220, 110, 15)
	bbTitle.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
	bbTitle.TextStrokeTransparency = 0.3
	bbTitle.TextScaled             = true
	bbTitle.Font                   = Enum.Font.GothamBold
	bbTitle.Text                   = "Vote here"
	bbTitle.Parent                 = bb

	local bbTimer = Instance.new("TextLabel")
	bbTimer.Name                   = "Timer"
	bbTimer.Size                   = UDim2.new(1, 0, 0.45, 0)
	bbTimer.Position               = UDim2.new(0, 0, 0.55, 0)
	bbTimer.BackgroundTransparency = 1
	bbTimer.TextColor3             = Color3.fromRGB(255, 255, 255)
	bbTimer.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
	bbTimer.TextStrokeTransparency = 0
	bbTimer.TextScaled             = true
	bbTimer.Font                   = Enum.Font.GothamBold
	bbTimer.Text                   = "--:--"
	bbTimer.Parent                 = bb

	Logger.info("Vote", "BillboardGui créé sur '%s'", primary.Name)

	-- Le serveur met à jour le timer (réplication automatique vers tous les clients)
	task.spawn(function()
		while primary.Parent do
			local remaining = math.max(0, localCycleEnd - os.time())
			local m = math.floor(remaining / 60)
			local s = remaining % 60
			bbTimer.Text = string.format("%02d:%02d", m, s)
			task.wait(1)
		end
	end)
end)

-- ── Boucle principale ─────────────────────────────────────────────────────────
task.spawn(function()
	initCycle()

	while true do
		local remaining = localCycleEnd - os.time()
		if remaining > 0 then
			task.wait(remaining)
		else
			task.wait(1)   -- sécurité contre boucle serrée
		end

		-- Lire le résultat final depuis DS (plus précis cross-serveur)
		local data       = dsLire()
		local finalToxic  = (data and data.toxic)  or localToxic
		local finalNebula = (data and data.nebula) or localNebula
		local total       = finalToxic + finalNebula

		Logger.info("Vote", "Cycle terminé — T=%d N=%d (total=%d)", finalToxic, finalNebula, total)

		if total > 0 then
			-- FIX : lancer uniquement s'il y a eu des votes
			local winner
			if finalToxic > finalNebula then
				winner = "toxic"
			elseif finalNebula > finalToxic then
				winner = "nebula"
			else
				winner = (math.random(2) == 1) and "toxic" or "nebula"
			end

			Logger.info("Vote", "Winner : %s", winner)
			EventVoteResult:FireAllClients(winner)

			if winner == "toxic" then
				LaunchToxicBE:Fire()
			else
				LaunchNebulaBE:Fire()
			end
		else
			Logger.info("Vote", "Aucun vote ce cycle — aucun event lancé")
			EventVoteResult:FireAllClients("none")
		end

		-- Démarrer le cycle suivant
		localCycleEnd  = os.time() + VOTE_DURATION
		localToxic     = 0
		localNebula    = 0
		votedThisCycle = {}
		dsEcrire(0, 0, localCycleEnd)
		publierUpdate()
		broadcastClients()
	end
end)

-- Envoyer l'état courant aux joueurs qui rejoignent après initCycle()
Players.PlayerAdded:Connect(function(player)
	task.wait(2)  -- laisser le client charger
	EventVoteUpdate:FireClient(player, localToxic, localNebula, localCycleEnd)
end)

Logger.info("Vote", "EventVoteSystem initialisé ✓ (cycle=%ds)", VOTE_DURATION)
