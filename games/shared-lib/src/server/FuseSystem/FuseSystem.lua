-- shared-lib/src/server/FuseSystem/FuseSystem.lua
-- Systeme Fuse Machine partage entre jeux
-- Tier determine par somme CashParSeconde des 4 brainrots
-- Config injectee via FuseSystem.Init(GameConfig)

local FuseSystem = {}

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService  = game:GetService("DataStoreService")
local CollectionService = game:GetService("CollectionService")
local ServerStorage     = game:GetService("ServerStorage")
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

-- Timers actifs par machine (Instance → true) pour éviter doublons sur reconnexion
local timersActifs = {}

-- Guard anti double-init (Main.server.lua + FuseSystemLoader peuvent tous deux appeler Init)
local initialise = false

-- Callback injecte par Main.server.lua
-- function(player, brainrotClone) → nil
-- Si absent : clone parent directement dans le Backpack
FuseSystem.OnResultatPret = nil

-- Callback optionnel pour envoyer une notification au joueur
-- function(player, type, message) → nil
-- type : "SUCCESS" | "INFO" | "WARN"
FuseSystem.OnNotif = nil

-- ═══════════════════════════════════════════════
-- Constantes mutation (surchargées par FuseConfig.MutationConfig si présent)
-- ═══════════════════════════════════════════════

local MUTATION_GOLD_PAR_INPUT    = 10  -- % par input Gold/Diamant/Rainbow
local MUTATION_TOXIC_PAR_INPUT   = 10  -- % par input Toxic
local MUTATION_NORMAL_PAR_INPUT  = 1   -- % Toxic par input Normal
local MUTATION_TOXIC_EVENT_BONUS = 10  -- % Toxic bonus si ToxicEventActif

-- Multiplicateurs CPS par type de mutation
local MULTI_CPS = {
	GOLD    = 2,
	DIAMANT = 3,
	RAINBOW = 10,
	TOXIC   = 5,
}

-- Sub-chances dans un roll Gold réussi (sur 100)
local RAINBOW_SUB_CHANCE = 2   -- 2% RAINBOW
local DIAMANT_SUB_CHANCE = 10  -- 10% → 8% DIAMANT (après RAINBOW exclus)

-- Noms des dossiers mutation (surchargés par FuseConfig.MutationFolderNames si présent)
local NOMS_DOSSIERS_MUTATION = {
	GOLD    = "BrainrotsGold",
	DIAMANT = "BrainrotsDiamant",
	RAINBOW = "BrainrotsRainbow",
	TOXIC   = "BrainrotsToxic",
}

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
-- Helpers mutation
-- ═══════════════════════════════════════════════

local function isToxicEventActif()
	local flag = ServerStorage:FindFirstChild("ToxicEventActif")
	return flag ~= nil and flag.Value == true
end

-- Analyse les 4 tools et retourne les chances par type (en %)
-- Chaque mutation input ajoute 10% pour le type correspondant
-- Les brainrots normaux n'ajoutent rien
local function analyserMutations(toolInstances)
	local nbGold, nbDiamant, nbRainbow, nbToxic = 0, 0, 0, 0
	for _, tool in ipairs(toolInstances) do
		local mutation = tool:GetAttribute("Mutation")
		if tool:GetAttribute("IsToxic") then
			nbToxic   += 1
		elseif mutation == "GOLD" then
			nbGold    += 1
		elseif mutation == "DIAMANT" then
			nbDiamant += 1
		elseif mutation == "RAINBOW" then
			nbRainbow += 1
		elseif tool:GetAttribute("IsMutant") and FuseConfig.MutantTypeToSlot then
			local slot = FuseConfig.MutantTypeToSlot[tool:GetAttribute("MutantType")]
			if     slot == "GOLD"    then nbGold    += 1
			elseif slot == "DIAMANT" then nbDiamant += 1
			elseif slot == "RAINBOW" then nbRainbow += 1
			elseif slot == "TOXIC"   then nbToxic   += 1
			end
		end
	end

	local toxicBonus    = isToxicEventActif() and MUTATION_TOXIC_EVENT_BONUS or 0
	local goldChance    = nbGold    * MUTATION_GOLD_PAR_INPUT
	local diamantChance = nbDiamant * MUTATION_GOLD_PAR_INPUT
	local rainbowChance = nbRainbow * MUTATION_GOLD_PAR_INPUT
	local toxicChance   = nbToxic   * MUTATION_TOXIC_PAR_INPUT + toxicBonus
	return goldChance, diamantChance, rainbowChance, toxicChance
end

-- Tire aléatoirement une mutation (nil = aucune)
-- Ordre de priorité : RAINBOW > DIAMANT > GOLD > TOXIC
local function roulerMutation(goldChance, diamantChance, rainbowChance, toxicChance)
	if rainbowChance > 0 and math.random(100) <= rainbowChance then return "RAINBOW"  end
	if diamantChance > 0 and math.random(100) <= diamantChance then return "DIAMANT"  end
	if goldChance    > 0 and math.random(100) <= goldChance    then return "GOLD"     end
	if toxicChance   > 0 and math.random(100) <= toxicChance   then return "TOXIC"    end
	return nil
end

-- Cherche le modèle muté par nom dans le dossier Mutation
local function trouverModeleMute(modeleBase, typeMutation)
	local mutRoot = FuseConfig.MutationRoot
	if not mutRoot then return nil end

	local nomDossier = NOMS_DOSSIERS_MUTATION[typeMutation]
	if not nomDossier then return nil end

	local dossierType = mutRoot:FindFirstChild(nomDossier)
	if not dossierType then return nil end

	for _, subFolder in ipairs(dossierType:GetChildren()) do
		if subFolder:IsA("Folder") or subFolder:IsA("Model") then
			local found = subFolder:FindFirstChild(modeleBase.Name)
			if found then return found end
		end
	end
	return nil
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
	if not FuseConfig.FuseBrainrotsFolder then return nil end

	local tierFolder = FuseConfig.FuseBrainrotsFolder:FindFirstChild("Tier_" .. tier)
	if not tierFolder then return nil end

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
			if not sousDossier then return nil end
			local enfants = sousDossier:GetChildren()
			if #enfants == 0 then return nil end
			return enfants[math.random(1, #enfants)]
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
	timersActifs[machine] = nil

	if etat.promptOuvrir and etat.promptOuvrir.Parent then
		etat.promptOuvrir.Enabled = true
	end
end

local function onCollecte(player, machine)
	local etat = machineEtats[machine]
	if not etat or not etat.pret then return end

	if etat.joueurId ~= player.UserId then return end

	if etat.promptCollecte and etat.promptCollecte.Parent then
		etat.promptCollecte:Destroy()
		etat.promptCollecte = nil
	end

	local modele = tirerBrainrot(etat.tier)
	if modele then
		local goldChance    = etat.goldChance    or 0
		local diamantChance = etat.diamantChance or 0
		local rainbowChance = etat.rainbowChance or 0
		local toxicChance   = etat.toxicChance   or 0
		local mutation      = roulerMutation(goldChance, diamantChance, rainbowChance, toxicChance)

		local sourceModele = modele
		if mutation then
			local mutModele = trouverModeleMute(modele, mutation)
			if mutModele then
				sourceModele = mutModele
				Logger.info("Fuse", "%s | Mutation %s => modele muté : %s", player.Name, mutation, mutModele.Name)
			end
		end

		local clone = sourceModele:Clone()

		if mutation then
			if mutation == "TOXIC" then
				clone:SetAttribute("IsToxic", true)
			else
				if not clone:GetAttribute("Mutation") then
					clone:SetAttribute("Mutation", mutation)
				end
			end
			local cpsSrc = clone:GetAttribute("CashParSeconde")
			if cpsSrc then
				clone:SetAttribute("CashParSeconde", cpsSrc * (MULTI_CPS[mutation] or 1))
			end
		end

		if FuseSystem.OnResultatPret then
			FuseSystem.OnResultatPret(player, clone)
		else
			clone.Parent = player:FindFirstChildOfClass("Backpack") or player.Character
		end
		Logger.info("Fuse", "%s collecte Tier %d => %s [mutation=%s]",
			player.Name, etat.tier, modele.Name, tostring(mutation))
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

local function demarrerFusion(machine, player, tier, endTime, goldChance, diamantChance, rainbowChance, toxicChance)
	local etat = machineEtats[machine]
	if not etat then return end

	etat.actif         = true
	etat.pret          = false
	etat.joueurId      = player.UserId
	etat.endTime       = endTime
	etat.tier          = tier
	etat.goldChance    = goldChance    or 0
	etat.diamantChance = diamantChance or 0
	etat.rainbowChance = rainbowChance or 0
	etat.toxicChance   = toxicChance   or 0

	if etat.promptOuvrir and etat.promptOuvrir.Parent then
		etat.promptOuvrir.Enabled = false
	end

	creerBillboard(machine)
	demarrerCountdown(machine)

	local delai    = math.max(0, endTime - os.time())
	local joueurId = player.UserId

	-- Guard : ne pas créer un second timer si un est déjà actif pour cette machine
	if not timersActifs[machine] then
		timersActifs[machine] = true
		task.delay(delai, function()
			timersActifs[machine] = nil
			fusionTerminee(machine, joueurId)
		end)
	end
end

local function setupMachine(machine)
	local part = getPartMachine(machine)
	if not part then return end

	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("ProximityPrompt") then child:Destroy() end
	end

	machineEtats[machine] = {
		actif          = false,
		pret           = false,
		joueurId       = nil,
		endTime        = nil,
		tier           = nil,
		goldChance     = 0,
		diamantChance  = 0,
		rainbowChance  = 0,
		toxicChance    = 0,
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
		local etat = machineEtats[machine]
		if not etat or etat.actif then return end
		OuvrirUI:FireClient(player, machine)
	end)
end

-- ═══════════════════════════════════════════════
-- Gestionnaire Lancer (client → serveur)
-- ═══════════════════════════════════════════════

local function onLancer(player, machine, toolInstances)
	if not machine or not machine.Parent then return end

	local etat = machineEtats[machine]
	if not etat or etat.actif then return end

	if joueurEtats[player.UserId] and joueurEtats[player.UserId].actif then return end

	if type(toolInstances) ~= "table" or #toolInstances ~= 4 then return end

	local backpack  = player:FindFirstChildOfClass("Backpack")
	local character = player.Character

	local totalCPS = 0
	local vus      = {}

	for _, tool in ipairs(toolInstances) do
		if not tool or not tool:IsA("Tool") then return end
		local parentOk = (backpack and tool.Parent == backpack)
			or (character and tool.Parent == character)
		if not parentOk then return end
		if vus[tool] then return end
		vus[tool] = true

		local cps = tool:GetAttribute("CashParSeconde")
		if not cps or type(cps) ~= "number" then return end

		totalCPS = totalCPS + cps
	end

	local tier    = determinerTier(totalCPS)
	local endTime = os.time() + FuseConfig.FuseDuration
	local goldChance, diamantChance, rainbowChance, toxicChance = analyserMutations(toolInstances)

	for _, tool in ipairs(toolInstances) do
		tool:Destroy()
	end

	FermerUI:FireClient(player)

	sauvegarderDonnees(player, {
		fuseActive      = true,
		fuseEndTime     = endTime,
		fuseTier        = tier,
		fuseMachineName = machine.Name,
		goldChance      = goldChance,
		diamantChance   = diamantChance,
		rainbowChance   = rainbowChance,
		toxicChance     = toxicChance,
	})

	joueurEtats[player.UserId] = { actif = true, machine = machine }

	demarrerFusion(machine, player, tier, endTime, goldChance, diamantChance, rainbowChance, toxicChance)

	Logger.info("Fuse", "%s | Tier: %d | Gold: %d%% Diamant: %d%% Rainbow: %d%% Toxic: %d%%",
		player.Name, tier, goldChance, diamantChance, rainbowChance, toxicChance)
end

-- ═══════════════════════════════════════════════
-- Reconnexion joueur
-- ═══════════════════════════════════════════════

local function onJoueurConnecte(player)
	task.spawn(function()
		task.wait(3)

		local data = chargerDonnees(player)
		if not data or not data.fuseActive then return end

		local machine = nil
		for m in pairs(machineEtats) do
			if m.Name == data.fuseMachineName then
				machine = m
				break
			end
		end

		-- Bug fix : ne plus effacer les données si la machine est introuvable.
		-- Les données restent intactes pour la prochaine reconnexion
		-- (changement de serveur, serveur qui redémarre, tag manquant temporaire).
		if not machine then
			Logger.warn("Fuse", "%s | Machine '%s' introuvable — fusion conservée pour reconnexion ultérieure",
				player.Name, tostring(data.fuseMachineName))
			return
		end

		local etat = machineEtats[machine]
		if not etat then return end

		-- Machine déjà occupée par un autre joueur
		if etat.actif and etat.joueurId ~= player.UserId then return end

		joueurEtats[player.UserId] = { actif = true, machine = machine }

		local fusionDejaDansEtat = etat.actif and etat.joueurId == player.UserId

		if data.fuseEndTime <= os.time() then
			-- Fusion terminée pendant l'absence du joueur
			if not fusionDejaDansEtat then
				etat.actif         = true
				etat.pret          = false
				etat.joueurId      = player.UserId
				etat.endTime       = data.fuseEndTime
				etat.tier          = data.fuseTier
				etat.goldChance    = data.goldChance    or 0
				etat.diamantChance = data.diamantChance or 0
				etat.rainbowChance = data.rainbowChance or 0
				etat.toxicChance   = data.toxicChance   or 0

				if etat.promptOuvrir and etat.promptOuvrir.Parent then
					etat.promptOuvrir.Enabled = false
				end

				creerBillboard(machine)
			end

			-- Créer le prompt de collecte seulement s'il n'existe pas encore
			if not etat.pret then
				fusionTerminee(machine, player.UserId)
			end

			if FuseSystem.OnNotif then
				pcall(FuseSystem.OnNotif, player, "SUCCESS",
					"🔥 Fusion complete! Pick up your Brainrot at the Fuse Machine!")
			end
		else
			-- Fusion encore en cours
			local restantMin = math.ceil((data.fuseEndTime - os.time()) / 60)

			if fusionDejaDansEtat then
				-- Même serveur : timer déjà actif, juste notifier
				if FuseSystem.OnNotif then
					pcall(FuseSystem.OnNotif, player, "INFO",
						"⏳ Fusion in progress — " .. restantMin .. " min remaining.")
				end
			else
				-- Nouveau serveur ou machine libre : démarrer le timer
				demarrerFusion(machine, player, data.fuseTier, data.fuseEndTime,
					data.goldChance or 0, data.diamantChance or 0,
					data.rainbowChance or 0, data.toxicChance or 0)

				if FuseSystem.OnNotif then
					pcall(FuseSystem.OnNotif, player, "INFO",
						"⏳ Fusion in progress — " .. restantMin .. " min remaining.")
				end
			end
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
	if initialise then return end
	if not gameConfig or not gameConfig.Fuse then return end

	initialise = true
	FuseConfig = gameConfig.Fuse

	-- Surcharger les constantes mutation si fournies dans la config
	if FuseConfig.MutationConfig then
		local mc = FuseConfig.MutationConfig
		MUTATION_GOLD_PAR_INPUT    = mc.GoldParInput     or MUTATION_GOLD_PAR_INPUT
		MUTATION_TOXIC_PAR_INPUT   = mc.ToxicParInput    or MUTATION_TOXIC_PAR_INPUT
		MUTATION_NORMAL_PAR_INPUT  = mc.NormalParInput   or MUTATION_NORMAL_PAR_INPUT
		MUTATION_TOXIC_EVENT_BONUS = mc.ToxicEventBonus  or MUTATION_TOXIC_EVENT_BONUS
		RAINBOW_SUB_CHANCE         = mc.RainbowSubChance or RAINBOW_SUB_CHANCE
		DIAMANT_SUB_CHANCE         = mc.DiamantSubChance or DIAMANT_SUB_CHANCE
	end
	if FuseConfig.MutationCPS then
		for k, v in pairs(FuseConfig.MutationCPS) do MULTI_CPS[k] = v end
	end
	if FuseConfig.MutationFolderNames then
		for k, v in pairs(FuseConfig.MutationFolderNames) do NOMS_DOSSIERS_MUTATION[k] = v end
	end

	if FuseConfig.DataStoreName then
		local ok, store = pcall(function()
			return DataStoreService:GetDataStore(FuseConfig.DataStoreName)
		end)
		if ok and store then
			ds = store
		else
			Logger.error("Fuse", "Impossible d'ouvrir DataStore '%s' : %s",
				tostring(FuseConfig.DataStoreName), tostring(store))
		end
	end

	OuvrirUI = creerRemoteEvent("FuseSystem_OuvrirUI")
	FermerUI = creerRemoteEvent("FuseSystem_FermerUI")
	Lancer   = creerRemoteEvent("FuseSystem_Lancer")

	Lancer.OnServerEvent:Connect(onLancer)

	local tag = FuseConfig.MachineTag or "FuseMachine"

	CollectionService:GetInstanceAddedSignal(tag):Connect(function(machine)
		setupMachine(machine)
	end)

	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(machine)
		machineEtats[machine] = nil
	end)

	local machines = CollectionService:GetTagged(tag)
	for _, machine in ipairs(machines) do
		setupMachine(machine)
	end

	Players.PlayerAdded:Connect(onJoueurConnecte)
	Players.PlayerRemoving:Connect(onJoueurDeconnecte)

	for _, player in ipairs(Players:GetPlayers()) do
		onJoueurConnecte(player)
	end
end

return FuseSystem
