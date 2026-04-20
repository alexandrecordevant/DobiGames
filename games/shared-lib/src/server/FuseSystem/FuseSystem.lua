-- shared-lib/src/server/FuseSystem/FuseSystem.lua
-- Systeme Fuse Machine partage entre jeux
-- Tier determine par somme CashParSeconde des 4 brainrots
-- Config injectee via FuseSystem.Init(GameConfig)

local FuseSystem = {}

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService  = game:GetService("DataStoreService")
local CollectionService = game:GetService("CollectionService")
local Logger            = require(game:GetService("ServerScriptService").SharedLib.Server.Logger)

-- Config injectee via Init
local FuseConfig = nil

-- DataStore (nil si DataStoreName absent de la config)
local ds = nil

-- RemoteEvents
local OuvrirUI = nil
local FermerUI = nil
local Lancer   = nil

-- Etat par machine (Instance → table)
local machineEtats = {}

-- Etat actif par joueur (userId → { actif, machine })
local joueurEtats = {}

-- Guard anti double-init (Main.server.lua + FuseSystemLoader peuvent tous deux appeler Init)
local initialise = false

-- Callback injecte par Main.server.lua
-- function(player, brainrotClone) → nil
-- Si absent : clone parent directement dans le Backpack
FuseSystem.OnResultatPret = nil

-- ═══════════════════════════════════════════════
-- Utilitaires
-- ═══════════════════════════════════════════════

local function creerRemoteEvent(nom)
	local e = ReplicatedStorage:FindFirstChild(nom)
	if e then return e end
	local re = Instance.new("RemoteEvent")
	re.Name   = nom
	re.Parent = ReplicatedStorage
	return re
end

local function getPartMachine(machine)
	if machine:IsA("BasePart") then return machine end
	if machine:IsA("Model") and machine.PrimaryPart then return machine.PrimaryPart end
	return machine:FindFirstChildWhichIsA("BasePart", true)
end

local function formaterTemps(sec)
	sec = math.max(0, math.floor(sec))
	local h = math.floor(sec / 3600)
	local m = math.floor((sec % 3600) / 60)
	local s = sec % 60
	return string.format("%02d:%02d:%02d", h, m, s)
end

-- ═══════════════════════════════════════════════
-- DataStore
-- ═══════════════════════════════════════════════

local function dsKey(player)
	return (FuseConfig.DataStoreKeyPrefix or "fuse_") .. player.UserId
end

local function chargerDonnees(player)
	if not ds then return nil end
	local ok, data = pcall(function() return ds:GetAsync(dsKey(player)) end)
	if not ok then
		Logger.error("Fuse", "Erreur chargement DataStore pour %s : %s", player.Name, tostring(data))
		return nil
	end
	return data
end

local function sauvegarderDonnees(player, data)
	if not ds then return end
	local ok, err = pcall(function() ds:SetAsync(dsKey(player), data) end)
	if not ok then
		Logger.error("Fuse", "Erreur sauvegarde DataStore pour %s : %s", player.Name, tostring(err))
	end
end

local function effacerDonnees(player)
	if not ds then return end
	local ok, err = pcall(function() ds:RemoveAsync(dsKey(player)) end)
	if not ok then
		Logger.warn("Fuse", "Erreur suppression DataStore pour %s : %s", player.Name, tostring(err))
	end
end

-- ═══════════════════════════════════════════════
-- Calcul du tier
-- ═══════════════════════════════════════════════

local function determinerTier(totalCPS)
	for i, tierCfg in ipairs(FuseConfig.Tiers) do
		if totalCPS <= tierCfg.maxTotal then
			return i
		end
	end
	return #FuseConfig.Tiers
end

-- ═══════════════════════════════════════════════
-- Tirage pondere du brainrot resultant
-- ═══════════════════════════════════════════════

local function tirerBrainrot(tier)
	if not FuseConfig.FuseBrainrotsFolder then
		Logger.warn("Fuse", "FuseBrainrotsFolder nil — tirage impossible")
		return nil
	end

	local tierFolder = FuseConfig.FuseBrainrotsFolder:FindFirstChild("Tier_" .. tier)
	if not tierFolder then
		Logger.warn("Fuse", "Dossier Tier_%d introuvable dans FuseBrainrotsFolder", tier)
		return nil
	end

	local totalPoids = 0
	for _, w in ipairs(FuseConfig.Weights) do
		totalPoids = totalPoids + w.weight
	end

	local rand  = math.random(1, totalPoids)
	local cumul = 0

	for _, w in ipairs(FuseConfig.Weights) do
		cumul = cumul + w.weight
		if rand <= cumul then
			local sousDossier = tierFolder:FindFirstChild(tostring(w.folder))
			if not sousDossier then
				Logger.warn("Fuse", "Sous-dossier '%s' introuvable dans Tier_%d", tostring(w.folder), tier)
				return nil
			end
			local enfants = sousDossier:GetChildren()
			if #enfants == 0 then
				Logger.warn("Fuse", "Sous-dossier '%s'/Tier_%d vide", tostring(w.folder), tier)
				return nil
			end
			return enfants[1]
		end
	end

	return nil
end

-- ═══════════════════════════════════════════════
-- BillboardGui (cree cote serveur, visible par tous)
-- ═══════════════════════════════════════════════

local function supprimerBillboard(etat)
	if etat.billboard and etat.billboard.Parent then
		etat.billboard:Destroy()
	end
	etat.billboard      = nil
	etat.billboardLabel = nil
	etat.billboardActif = false
end

local function creerBillboard(machine)
	local etat = machineEtats[machine]
	if not etat then return end

	local part = getPartMachine(machine)
	if not part then return end

	supprimerBillboard(etat)

	local bb = Instance.new("BillboardGui")
	bb.Name           = "FuseBillboard"
	bb.Size           = UDim2.new(0, 220, 0, 54)
	bb.StudsOffset    = Vector3.new(0, 7, 0)
	bb.AlwaysOnTop    = false
	bb.MaxDistance    = 80
	bb.LightInfluence = 0
	bb.Parent         = part

	local fond = Instance.new("Frame")
	fond.Size                  = UDim2.new(1, 0, 1, 0)
	fond.BackgroundColor3      = Color3.fromRGB(13, 13, 13)
	fond.BackgroundTransparency = 0.15
	fond.BorderSizePixel       = 0
	fond.Parent                = bb
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 12)
	c.Parent       = fond

	local label = Instance.new("TextLabel")
	label.Size                  = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextColor3            = Color3.fromRGB(255, 140, 42)
	label.TextSize              = 24
	label.Font                  = Enum.Font.GothamBold
	label.Text                  = ""
	label.Parent                = fond

	etat.billboard      = bb
	etat.billboardLabel = label
	etat.billboardActif = true
end

local function demarrerCountdown(machine)
	local etat = machineEtats[machine]
	if not etat then return end

	task.spawn(function()
		while etat.billboardActif and etat.billboard and etat.billboard.Parent and etat.actif and not etat.pret do
			local restant = math.max(0, etat.endTime - os.time())
			if etat.billboardLabel then
				etat.billboardLabel.Text = formaterTemps(restant)
			end
			if restant <= 0 then break end
			task.wait(1)
		end
	end)
end

local function afficherPret(machine)
	local etat = machineEtats[machine]
	if not etat then return end

	if not etat.billboard or not etat.billboard.Parent then
		creerBillboard(machine)
	end

	task.spawn(function()
		local couleurs = {
			Color3.fromRGB(123, 198, 126),
			Color3.fromRGB(200, 255, 200),
		}
		local i = 1
		while etat.billboard and etat.billboard.Parent and etat.pret do
			if etat.billboardLabel then
				etat.billboardLabel.Text       = "PRET !"
				etat.billboardLabel.TextColor3 = couleurs[i]
			end
			i = (i % 2) + 1
			task.wait(0.5)
		end
	end)
end

-- ═══════════════════════════════════════════════
-- Cycle de vie machine
-- ═══════════════════════════════════════════════

local function reinitialiserMachine(machine)
	local etat = machineEtats[machine]
	if not etat then return end

	if etat.promptCollecte and etat.promptCollecte.Parent then
		etat.promptCollecte:Destroy()
	end

	supprimerBillboard(etat)

	etat.actif          = false
	etat.pret           = false
	etat.joueurId       = nil
	etat.endTime        = nil
	etat.tier           = nil
	etat.promptCollecte = nil

	if etat.promptOuvrir and etat.promptOuvrir.Parent then
		etat.promptOuvrir.Enabled = true
	end

	Logger.debug("Fuse", "Machine reinitialisee : %s", machine.Name)
end

local function onCollecte(player, machine)
	local etat = machineEtats[machine]
	if not etat or not etat.pret then return end

	if etat.joueurId ~= player.UserId then
		Logger.debug("Fuse", "%s tente de recuperer la fusion de %d", player.Name, etat.joueurId or 0)
		return
	end

	if etat.promptCollecte and etat.promptCollecte.Parent then
		etat.promptCollecte:Destroy()
		etat.promptCollecte = nil
	end

	local modele = tirerBrainrot(etat.tier)
	if modele then
		local clone = modele:Clone()
		if FuseSystem.OnResultatPret then
			FuseSystem.OnResultatPret(player, clone)
		else
			Logger.warn("Fuse", "OnResultatPret non injecte — clone parent Backpack directement")
			clone.Parent = player:FindFirstChildOfClass("Backpack") or player.Character
		end
		Logger.info("Fuse", "%s collecte Tier %d => %s", player.Name, etat.tier, modele.Name)
	else
		Logger.warn("Fuse", "Tirage vide pour Tier %d (joueur %s)", etat.tier, player.Name)
	end

	effacerDonnees(player)
	joueurEtats[player.UserId] = nil

	reinitialiserMachine(machine)
end

local function fusionTerminee(machine, joueurId)
	local etat = machineEtats[machine]
	if not etat or not etat.actif then return end
	if etat.joueurId ~= joueurId then return end

	etat.pret = true

	Logger.info("Fuse", "Fusion terminee sur %s (joueur %d)", machine.Name, joueurId)

	afficherPret(machine)

	local part = getPartMachine(machine)
	if not part then return end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText            = "Recuperer"
	prompt.ObjectText            = "Fusion terminee"
	prompt.HoldDuration          = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight   = false
	prompt.Parent                = part

	etat.promptCollecte = prompt

	local conn
	conn = prompt.Triggered:Connect(function(trigPlayer)
		if trigPlayer.UserId ~= etat.joueurId then return end
		conn:Disconnect()
		onCollecte(trigPlayer, machine)
	end)
end

local function demarrerFusion(machine, player, tier, endTime)
	local etat = machineEtats[machine]
	if not etat then return end

	etat.actif    = true
	etat.pret     = false
	etat.joueurId = player.UserId
	etat.endTime  = endTime
	etat.tier     = tier

	if etat.promptOuvrir and etat.promptOuvrir.Parent then
		etat.promptOuvrir.Enabled = false
	end

	creerBillboard(machine)
	demarrerCountdown(machine)

	local delai    = math.max(0, endTime - os.time())
	local joueurId = player.UserId

	task.delay(delai, function()
		fusionTerminee(machine, joueurId)
	end)
end

local function setupMachine(machine)
	print("[FUSE-DIAG] setupMachine : " .. machine.Name .. " | Classe=" .. machine.ClassName)

	local part = getPartMachine(machine)
	if not part then
		warn("[FUSE-DIAG] ERREUR setupMachine : aucune BasePart trouvee dans " .. machine.Name)
		return
	end
	print("[FUSE-DIAG] BasePart trouvee : " .. part.Name)

	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("ProximityPrompt") then child:Destroy() end
	end

	machineEtats[machine] = {
		actif          = false,
		pret           = false,
		joueurId       = nil,
		endTime        = nil,
		tier           = nil,
		promptOuvrir   = nil,
		promptCollecte = nil,
		billboard      = nil,
		billboardLabel = nil,
		billboardActif = false,
	}

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText            = "Fusionner"
	prompt.ObjectText            = "Fuse Machine"
	prompt.HoldDuration          = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight   = false
	prompt.Parent                = part

	machineEtats[machine].promptOuvrir = prompt

	prompt.Triggered:Connect(function(player)
		print("[FUSE-DIAG] ProximityPrompt declenche par " .. player.Name .. " sur " .. machine.Name)
		local etat = machineEtats[machine]
		if not etat then
			warn("[FUSE-DIAG] etat machine nil pour " .. machine.Name)
			return
		end
		if etat.actif then
			print("[FUSE-DIAG] Machine deja active — prompt ignore")
			return
		end
		print("[FUSE-DIAG] OuvrirUI => " .. player.Name)
		OuvrirUI:FireClient(player, machine)
	end)
end

-- ═══════════════════════════════════════════════
-- Gestionnaire Lancer (client → serveur)
-- ═══════════════════════════════════════════════

local function onLancer(player, machine, toolInstances)
	print("[FUSE-DIAG] onLancer recu de " .. player.Name)

	if not machine or not machine.Parent then
		warn("[FUSE-DIAG] ERREUR onLancer : machine invalide ou nil")
		return
	end
	print("[FUSE-DIAG] Machine : " .. machine.Name)

	local etat = machineEtats[machine]
	if not etat then
		warn("[FUSE-DIAG] ERREUR onLancer : machine non geree dans machineEtats")
		return
	end

	if etat.actif then
		print("[FUSE-DIAG] Machine deja active — lancer ignore")
		return
	end

	if joueurEtats[player.UserId] and joueurEtats[player.UserId].actif then
		print("[FUSE-DIAG] " .. player.Name .. " a deja une fusion active")
		return
	end

	if type(toolInstances) ~= "table" then
		warn("[FUSE-DIAG] ERREUR onLancer : toolInstances n'est pas une table (type=" .. type(toolInstances) .. ")")
		return
	end
	print("[FUSE-DIAG] toolInstances recus : " .. #toolInstances .. " items")
	if #toolInstances ~= 4 then
		warn("[FUSE-DIAG] ERREUR onLancer : attendu 4 tools, recu " .. #toolInstances)
		return
	end

	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		warn("[FUSE-DIAG] ERREUR onLancer : backpack nil pour " .. player.Name)
		return
	end

	local totalCPS = 0
	local vus      = {}

	for idx, tool in ipairs(toolInstances) do
		if not tool then
			warn("[FUSE-DIAG] ERREUR onLancer : tool[" .. idx .. "] est nil")
			return
		end
		if not tool:IsA("Tool") then
			warn("[FUSE-DIAG] ERREUR onLancer : tool[" .. idx .. "] classe=" .. tool.ClassName .. " (pas un Tool)")
			return
		end
		if tool.Parent ~= backpack then
			warn("[FUSE-DIAG] ERREUR onLancer : tool[" .. idx .. "] parent=" .. tostring(tool.Parent and tool.Parent.Name) .. " (pas le Backpack)")
			return
		end
		if vus[tool] then
			warn("[FUSE-DIAG] ERREUR onLancer : doublon detecte")
			return
		end
		vus[tool] = true

		local cps = tool:GetAttribute("CashParSeconde")
		if not cps or type(cps) ~= "number" then
			warn("[FUSE-DIAG] ERREUR onLancer : tool[" .. idx .. "] '" .. tool.Name .. "' sans CashParSeconde (valeur=" .. tostring(cps) .. ")")
			return
		end
		print("[FUSE-DIAG]   tool[" .. idx .. "] = " .. tool.Name .. " | CashParSeconde=" .. cps)

		totalCPS = totalCPS + cps
	end
	print("[FUSE-DIAG] Total CPS = " .. totalCPS)

	local tier    = determinerTier(totalCPS)
	local endTime = os.time() + FuseConfig.FuseDuration
	print("[FUSE-DIAG] Tier calcule = " .. tier .. " | EndTime dans " .. FuseConfig.FuseDuration .. "s")

	-- Detruire les 4 brainrots
	for _, tool in ipairs(toolInstances) do
		tool:Destroy()
	end
	print("[FUSE-DIAG] 4 brainrots detruits")

	FermerUI:FireClient(player)

	-- Persistance
	sauvegarderDonnees(player, {
		fuseActive      = true,
		fuseEndTime     = endTime,
		fuseTier        = tier,
		fuseMachineName = machine.Name,
	})

	joueurEtats[player.UserId] = { actif = true, machine = machine }

	demarrerFusion(machine, player, tier, endTime)

	Logger.info("Fuse", "%s lance fusion | CPS total : %.0f | Tier : %d | Duree : %ds",
		player.Name, totalCPS, tier, FuseConfig.FuseDuration)
end

-- ═══════════════════════════════════════════════
-- Reconnexion joueur
-- ═══════════════════════════════════════════════

local function onJoueurConnecte(player)
	task.spawn(function()
		task.wait(3)

		local data = chargerDonnees(player)
		if not data or not data.fuseActive then return end

		Logger.info("Fuse", "%s reconnecte avec fusion active (Tier %d)", player.Name, data.fuseTier or 0)

		local machine = nil
		for m in pairs(machineEtats) do
			if m.Name == data.fuseMachineName then
				machine = m
				break
			end
		end

		if not machine then
			Logger.warn("Fuse", "Machine '%s' introuvable pour restauration de %s",
				tostring(data.fuseMachineName), player.Name)
			effacerDonnees(player)
			return
		end

		local etat = machineEtats[machine]
		if not etat then return end

		if etat.actif and etat.joueurId ~= player.UserId then
			Logger.warn("Fuse", "Machine '%s' occupee au reconnect de %s", machine.Name, player.Name)
			return
		end

		joueurEtats[player.UserId] = { actif = true, machine = machine }

		if data.fuseEndTime <= os.time() then
			-- Fusion terminee pendant l'absence
			etat.actif    = true
			etat.pret     = false
			etat.joueurId = player.UserId
			etat.endTime  = data.fuseEndTime
			etat.tier     = data.fuseTier

			if etat.promptOuvrir and etat.promptOuvrir.Parent then
				etat.promptOuvrir.Enabled = false
			end

			creerBillboard(machine)
			fusionTerminee(machine, player.UserId)

			Logger.info("Fuse", "%s : fusion expiree pendant absence, PRET ! affiche", player.Name)
		else
			-- Fusion toujours en cours
			demarrerFusion(machine, player, data.fuseTier, data.fuseEndTime)

			Logger.info("Fuse", "%s : timer restaure (%ds restants)",
				player.Name, math.max(0, data.fuseEndTime - os.time()))
		end
	end)
end

local function onJoueurDeconnecte(player)
	joueurEtats[player.UserId] = nil
end

-- ═══════════════════════════════════════════════
-- Init
-- ═══════════════════════════════════════════════

function FuseSystem.Init(gameConfig)
	print("[FUSE-DIAG] FuseSystem.Init appele")

	if initialise then
		print("[FUSE-DIAG] Init() deja effectue — ignore (double appel Main+Loader normal)")
		return
	end

	if not gameConfig then
		warn("[FUSE-DIAG] ERREUR : gameConfig est nil")
		return
	end
	if not gameConfig.Fuse then
		warn("[FUSE-DIAG] ERREUR : gameConfig.Fuse est nil — verifier GameConfig.lua")
		return
	end

	initialise = true

	FuseConfig = gameConfig.Fuse
	print("[FUSE-DIAG] FuseConfig charge | MachineTag=" .. tostring(FuseConfig.MachineTag)
		.. " | FuseDuration=" .. tostring(FuseConfig.FuseDuration)
		.. " | FuseBrainrotsFolder=" .. tostring(FuseConfig.FuseBrainrotsFolder)
		.. " | DataStoreName=" .. tostring(FuseConfig.DataStoreName))

	-- DataStore
	if FuseConfig.DataStoreName then
		local ok, store = pcall(function()
			return DataStoreService:GetDataStore(FuseConfig.DataStoreName)
		end)
		if ok and store then
			ds = store
			print("[FUSE-DIAG] DataStore '" .. FuseConfig.DataStoreName .. "' ouvert OK")
		else
			warn("[FUSE-DIAG] Impossible d'ouvrir DataStore '" .. tostring(FuseConfig.DataStoreName) .. "' : " .. tostring(store))
		end
	else
		print("[FUSE-DIAG] Pas de DataStoreName — persistance desactivee")
	end

	-- RemoteEvents
	OuvrirUI = creerRemoteEvent("FuseSystem_OuvrirUI")
	FermerUI = creerRemoteEvent("FuseSystem_FermerUI")
	Lancer   = creerRemoteEvent("FuseSystem_Lancer")
	print("[FUSE-DIAG] RemoteEvents crees dans ReplicatedStorage")

	Lancer.OnServerEvent:Connect(onLancer)

	-- Detection machines via CollectionService
	local tag = FuseConfig.MachineTag or "FuseMachine"
	print("[FUSE-DIAG] Scan CollectionService tag='" .. tag .. "'")

	CollectionService:GetInstanceAddedSignal(tag):Connect(function(machine)
		print("[FUSE-DIAG] Nouvelle machine taguee detectee : " .. machine.Name)
		setupMachine(machine)
	end)

	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(machine)
		machineEtats[machine] = nil
	end)

	local machines = CollectionService:GetTagged(tag)
	print("[FUSE-DIAG] Machines trouvees avec tag '" .. tag .. "' : " .. #machines)
	for i, machine in ipairs(machines) do
		print("[FUSE-DIAG]   [" .. i .. "] " .. machine.Name .. " | Classe=" .. machine.ClassName)
		setupMachine(machine)
	end

	if #machines == 0 then
		warn("[FUSE-DIAG] AUCUNE machine trouvee ! Verifier que le tag '" .. tag .. "' est bien applique dans Studio (CollectionService)")
	end

	-- Evenements joueurs
	Players.PlayerAdded:Connect(onJoueurConnecte)
	Players.PlayerRemoving:Connect(onJoueurDeconnecte)

	for _, player in ipairs(Players:GetPlayers()) do
		onJoueurConnecte(player)
	end

	print("[FUSE-DIAG] FuseSystem.Init termine — " .. #machines .. " machine(s) configuree(s)")
	Logger.info("Fuse", "Systeme initialise (%d machine(s), tag='%s')", #machines, tag)
end

return FuseSystem
