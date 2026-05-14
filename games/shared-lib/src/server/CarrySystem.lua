-- ServerScriptService/CarrySystem.lua
-- DobiGames shared-lib — Transport via Roblox Backpack (Tools)
-- Remplace le système Motor6D flottant par des Tools dans le Backpack du joueur.
-- ProximityPrompt pour capture (BrainRotFarm) — voir aussi PickupSystem pour LavaTower.

local CarrySystem = {}

-- API publique — assignée depuis Main.server.lua
-- function(player) → baseIndex ou nil
CarrySystem.GetBaseJoueur = nil

local _GameConfig = require(
    game.ReplicatedStorage:FindFirstChild("GameConfig")
    or game.ReplicatedStorage.Specialized.GameConfig
)

-- ============================================================
-- Services
-- ============================================================
local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")
local Workspace         = game:GetService("Workspace")
local Debris            = game:GetService("Debris")
local Logger            = require(game:GetService("ServerScriptService").SharedLib.Server.Logger)

-- Callback injecté par Main.server.lua si le jeu utilise un système de pots
-- Signature : function(player, portes) → nil
CarrySystem.OnCarryChange = nil

-- Callback appelé avant que nettoyerJoueur détruise les Tools (PlayerRemoving)
-- Permet au jeu de sérialiser le carry avant destruction
-- Signature : function(player, portes) → nil
CarrySystem.OnBeforeClean = nil

-- Callback pour compter les items supplémentaires dans le carry (ex : graines portées)
-- Signature : function(player) → number
-- Assigné par le jeu (ex : BrainRotFarm → compte CarriedSeeds)
CarrySystem.GetExtraCount = nil

-- ============================================================
-- Configuration capture hybride
-- ============================================================
local CAPTURE_CONFIG = _GameConfig.CaptureConfig
local VALEURS_RARETE = _GameConfig.ValeurParRarete
local CARRY_NIVEAUX  = _GameConfig.CarryNiveaux
local CARRY_PRICES   = _GameConfig.CarryPrices

local CARRY_CONFIG = {
	niveaux = CARRY_NIVEAUX,
	prixUpgrade = {
		[1] = CARRY_PRICES[1],
		[2] = CARRY_PRICES[2],
		[3] = CARRY_PRICES[3],
	},
	rayonDrop         = 3,
	dureeDropSecondes = 15,
	sonCollecte       = 0,
	depotMaxDistance  = 8,
}

-- Couleurs du handle Tool par rareté (handle Transparency=1, valeur cosmétique uniquement)
local RARETE_COULEURS = {
	COMMON       = Color3.fromRGB(200, 200, 200),
	RARE         = Color3.fromRGB(0,   120, 255),
	EPIC         = Color3.fromRGB(150,   0, 255),
	LEGENDARY    = Color3.fromRGB(255, 200,   0),
	MYTHIC       = Color3.fromRGB(255,  50,  50),
	GOD          = Color3.fromRGB(255, 140,   0),
	SECRET       = Color3.fromRGB(255, 255, 255),
	OG           = Color3.fromRGB(100, 220, 255),
	BRAINROT_GOD = Color3.fromRGB(255,  80, 200),
}

-- ============================================================
-- État interne par joueur
-- ============================================================
-- portes = { { rarete = rareteObj, toolRef = Tool } }
local donneesJoueurs = {}
-- Bonus de slots carry par joueur (shopUpgrade Carry)
local carryBonuses   = {}
-- Rayon aimant par joueur (shopUpgrade Aimant)
local rayonAimant    = {}

local initJoueur  -- forward declaration (défini plus bas, utilisé dans InitDepotSpotsBase)

local CarryUpdate      = nil
local BRAINROTS_FOLDER = nil

local function getExtraCount(player)
	return CarrySystem.GetExtraCount and CarrySystem.GetExtraCount(player) or 0
end

-- ============================================================
-- Utilitaires
-- ============================================================

local function obtenirRacine(instance)
	if instance:IsA("BasePart") then return instance end
	if instance.PrimaryPart then return instance.PrimaryPart end
	local bestPart, bestVol = nil, 0
	for _, v in ipairs(instance:GetDescendants()) do
		if v:IsA("BasePart") then
			local vol = v.Size.X * v.Size.Y * v.Size.Z
			if vol > bestVol then
				bestVol = vol
				bestPart = v
			end
		end
	end
	return bestPart
end

local function choisirModele(nomDossier)
	if not BRAINROTS_FOLDER then return nil end
	local dossier = BRAINROTS_FOLDER:FindFirstChild(nomDossier)
	if not dossier then
		Logger.warn("Carry", "Dossier introuvable : %s", tostring(nomDossier))
		return nil
	end
	-- Si un enfant a un nom numerique c'est un sous-conteneur (SECRET/1, GOD/2…)
	-- et on collecte ses enfants. Sinon, l'enfant est directement un modele.
	local modeles = {}
	for _, enfant in ipairs(dossier:GetChildren()) do
		if tonumber(enfant.Name) ~= nil then
			for _, modele in ipairs(enfant:GetChildren()) do
				table.insert(modeles, modele)
			end
		else
			table.insert(modeles, enfant)
		end
	end
	if #modeles == 0 then return nil end
	return modeles[math.random(1, #modeles)]
end

local function envoyerCarryUpdate(player)
	if not CarryUpdate then return end
	local data = donneesJoueurs[player.UserId]
	if not data then return end
	local max = CarrySystem.GetCapaciteMax(player)
	local extra = getExtraCount(player)
	pcall(function()
		CarryUpdate:FireClient(player, { portes = #data.portes + extra, max = max })
	end)
	-- Compatibilité BrainrotCarryUI (LavaTower)
	local brEvent = ReplicatedStorage:FindFirstChild("BrainrotCarryUpdate")
	if brEvent then
		pcall(function()
			brEvent:FireClient(player, #data.portes + extra, max)
		end)
	end
	if CarrySystem.OnCarryChange then
		local portes = data and data.portes or {}
		pcall(CarrySystem.OnCarryChange, player, portes)
	end
end

local function notifierJoueur(player, typeNotif, message)
	local ev = ReplicatedStorage:FindFirstChild("NotifEvent")
	if ev then pcall(function() ev:FireClient(player, typeNotif, message) end) end
end

local function notifierTous(message)
	local ev = ReplicatedStorage:FindFirstChild("NotifEvent")
	if ev then pcall(function() ev:FireAllClients("INFO", message) end) end
	Logger.info("Carry", "%s", message)
end

local function notifierAutresJoueurs(excluPlayer, typeNotif, message)
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= excluPlayer then
			notifierJoueur(player, typeNotif, message)
		end
	end
end

local function jouerSon(player)
	if CARRY_CONFIG.sonCollecte == 0 then return end
	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	pcall(function()
		local son   = Instance.new("Sound")
		son.SoundId = "rbxassetid://" .. CARRY_CONFIG.sonCollecte
		son.Volume  = 0.5
		son.Parent  = hrp
		son:Play()
		Debris:AddItem(son, 3)
	end)
end

local function calculerCoinsPortes(data)
	local total = 0
	for _, entree in ipairs(data.portes) do
		if entree.rarete then
			total = total + (VALEURS_RARETE[entree.rarete.nom or ""] or 1)
		end
	end
	return total
end

-- ============================================================
-- Gestion Tools (remplace Motor6D)
-- ============================================================

-- Crée un Tool Roblox avec le visuel du BR soudé à un Handle invisible,
-- puis l'ajoute au Backpack du joueur.
-- Retourne le Tool créé, ou nil en cas d'échec.
local function creerTool(player, clone, rarete)
	local nomRarete = rarete and rarete.nom or "COMMON"
	local couleur   = RARETE_COULEURS[nomRarete] or Color3.fromRGB(200, 200, 200)
	local nomBR     = (clone and (clone:GetAttribute("OriginalName") or clone.Name)) or nomRarete

	local tool = Instance.new("Tool")
	tool.Name           = nomBR
	tool.ToolTip        = "[" .. nomRarete .. "] " .. nomBR
	tool.CanBeDropped   = false
	tool.RequiresHandle = true
	tool:SetAttribute("Rarete",       nomRarete)
	tool:SetAttribute("BrainrotName", nomBR)
	if rarete and rarete.isMutant then
		tool:SetAttribute("IsMutant", true)
	end
	if rarete and rarete.valeur then
		tool:SetAttribute("Valeur", rarete.valeur)
	end
	if rarete and rarete.elementType then
		tool:SetAttribute("ElementType", rarete.elementType)
	end
	-- Copier les attributs économiques du modèle source vers le Tool
	-- (le modèle est cloné puis détaché du workspace, les attributs seraient perdus sinon)
	if clone then
		local cps  = clone:GetAttribute("CashParSeconde")
		local prix = clone:GetAttribute("Prix")
		if cps  then tool:SetAttribute("CashParSeconde", cps)  end
		if prix then tool:SetAttribute("Prix",           prix) end
	end
	-- Type de mutation : depuis rarete (PickupSystem) ou depuis le clone (fallback)
	local mutation = (rarete and rarete.mutation)
		or (clone and clone:GetAttribute("Mutation"))
	if mutation then
		tool:SetAttribute("Mutation", mutation)
		tool:SetAttribute("IsMutant", true)
	end
	local isToxic = (rarete and rarete.isToxic)
		or (clone and clone:GetAttribute("IsToxic") == true)
	if isToxic then
		tool:SetAttribute("IsToxic", true)
		tool:SetAttribute("IsMutant", true)
	end
	local isNebula = (rarete and rarete.isNebula)
		or (clone and clone:GetAttribute("IsNebula") == true)
	if isNebula then
		tool:SetAttribute("IsNebula", true)
		tool:SetAttribute("IsMutant", true)
	end

	-- Handle invisible — jamais lâché (CanBeDropped = false)
	local handle = Instance.new("Part")
	handle.Name         = "Handle"
	handle.Shape        = Enum.PartType.Ball
	handle.Size         = Vector3.new(1, 1, 1)
	handle.Color        = couleur
	handle.Material     = Enum.Material.Neon
	handle.Transparency = 1
	handle.Anchored     = false
	handle.CanCollide   = false
	handle.Parent       = tool

	-- Visuel soudé au Handle
	if clone then
		-- Nettoyer billboards/prompts résiduels du monde
		-- _BRBillboard est préservé (sans LTimer) pour qu'il survive jusqu'au dépôt sur slot
		for _, desc in ipairs(clone:GetDescendants()) do
			if desc:IsA("ProximityPrompt") then
				pcall(function() desc:Destroy() end)
			elseif desc:IsA("BillboardGui") then
				if desc.Name == "_BRBillboard" then
					local lTimer = desc:FindFirstChild("LTimer")
					if lTimer then pcall(function() lTimer:Destroy() end) end
				else
					pcall(function() desc:Destroy() end)
				end
			end
		end

		-- Centrer le visuel à l'origine avant de souder
		-- Assigner PrimaryPart si absent (modeles avec FakeRootPart : Strawberry Elephant, Los Noobinis)
		-- Sans cela, PivotTo echoue silencieusement et le fallback deplace chaque part
		-- individuellement a (0,0,0), detruisant la structure du modele.
		if clone:IsA("Model") and not clone.PrimaryPart then
			local fakePart = clone:FindFirstChild("FakeRootPart")
			if fakePart then
				clone.PrimaryPart = fakePart
			end
		end
		-- Fallback BasePart si PivotTo échoue (modèle sans PrimaryPart ou model vide)
		local pivotOk = pcall(function() clone:PivotTo(CFrame.new(0, 0, 0)) end)
		if not pivotOk then
			-- Tentative directe sur chaque BasePart racine (modèle plat sans PrimaryPart)
			if clone:IsA("BasePart") then
				pivotOk = pcall(function() clone.CFrame = CFrame.new(0, 0, 0) end)
			else
				for _, part in ipairs(clone:GetDescendants()) do
					if part:IsA("BasePart") then
						pcall(function() part.CFrame = CFrame.new(0, 0, 0) end)
					end
				end
				pivotOk = true  -- on continue même si le centrage est approximatif
			end
			Logger.warn("Carry", "PivotTo échoué pour %s — centrage de secours utilisé", nomBR)
		end
		-- Supprimer Motor6D apres centrage, avant la creation des WeldConstraints.
		-- Motor6D et WeldConstraint sont des contraintes incompatibles : Motor6D
		-- repositionne les parts animees (Cube, Cube.001...) independamment du pivot,
		-- ce qui produit l'explosion visuelle sur le slot pour les modeles comme
		-- Strawberry Elephant et Los Noobinis (FakeRootPart + joints Motor6D).
		for _, v in ipairs(clone:GetDescendants()) do
			if v:IsA("Motor6D") or v:IsA("Animator") or v:IsA("AnimationController") then
				pcall(function() v:Destroy() end)
			end
		end
		for _, part in ipairs(clone:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Anchored   = false
				part.CanCollide = false
				local wc  = Instance.new("WeldConstraint")
				wc.Part0  = handle
				wc.Part1  = part
				wc.Parent = handle
			end
		end
		if clone:IsA("BasePart") then
			clone.Anchored   = false
			clone.CanCollide = false
			local wc  = Instance.new("WeldConstraint")
			wc.Part0  = handle
			wc.Part1  = clone
			wc.Parent = handle
		end
		clone.Parent = tool
	end

	-- Ajouter dans le Backpack
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		pcall(function() tool:Destroy() end)
		return nil
	end
	tool.Parent = backpack
	return tool
end

-- Extrait le visuel du Tool (Model ou BasePart non-Handle) vers Workspace,
-- supprime les WeldConstraints, puis détruit le Tool.
-- Retourne le modèle extrait ou nil.
local function extraireVisuel(tool)
	if not tool or not tool.Parent then return nil end

	local visuel = nil
	for _, child in ipairs(tool:GetChildren()) do
		if (child:IsA("Model") or child:IsA("BasePart")) and child.Name ~= "Handle" then
			visuel = child
			break
		end
	end

	if visuel then
		-- Supprimer les welds du Handle
		local handle = tool:FindFirstChild("Handle")
		if handle then
			for _, wc in ipairs(handle:GetChildren()) do
				if wc:IsA("WeldConstraint") then
					pcall(function() wc:Destroy() end)
				end
			end
		end
		-- Libérer les parts
		for _, v in ipairs(visuel:GetDescendants()) do
			if v:IsA("BasePart") then
				pcall(function()
					v.Anchored   = false
					v.CanCollide = false
				end)
			end
		end
		visuel.Parent = Workspace
	end

	pcall(function() tool:Destroy() end)
	return visuel
end

-- ============================================================
-- Message sac plein
-- ============================================================

local function messageSacPlein(player, _pData)
	-- Utiliser GetCapaciteMax pour inclure le bonus (SetCapacite) dans le max réel
	local max = CarrySystem.GetCapaciteMax(player)
	-- Retrouver le palier courant depuis la capacité réelle (SetCapacite ignore niveauCarry)
	local niveauCourant = 0
	for n = 0, 10 do
		local cap = CARRY_CONFIG.niveaux[n]
		if cap == nil then break end
		if cap <= max then niveauCourant = n end
	end
	local prochainNiveau = niveauCourant + 1
	local prochainBase   = CARRY_CONFIG.niveaux[prochainNiveau]
	local niveauMax = prochainBase == nil

	-- Envoyer via BrainrotCarryError si disponible (BrainrotCarryUI)
	local brErrEvent = ReplicatedStorage:FindFirstChild("BrainrotCarryError")

	local msg
	if niveauMax then
		msg = "Carry full! (" .. max .. "/" .. max .. ") — Deposit your Brain Rots first."
	else
		local prochainMax = prochainBase
		local prix        = CARRY_CONFIG.prixUpgrade[prochainNiveau] or 0
		msg = "Carry full! (" .. max .. "/" .. max .. ") — "
			.. "Upgrade carry to " .. prochainMax .. " slots for " .. prix .. " coins!"
	end

	if brErrEvent then
		pcall(function() brErrEvent:FireClient(player, msg) end)
	else
		notifierJoueur(player, "INFO", msg)
	end
end

-- ============================================================
-- Logique commune de ramassage
-- ============================================================

-- Utilise modeleExistant s'il est fourni, sinon clone depuis ServerStorage
local function effectuerRamassage(player, rarete, modeleExistant)
	local data = donneesJoueurs[player.UserId]
	if not data then return false end

	local max = CarrySystem.GetCapaciteMax(player)
	if #data.portes + getExtraCount(player) >= max then
		messageSacPlein(player, data)
		return false
	end

	local clone
	if modeleExistant and modeleExistant.Parent then
		clone = modeleExistant
	else
		local nomDossier   = rarete and rarete.dossier or "COMMON"
		local modeleSource = choisirModele(nomDossier)
		if not modeleSource then return false end
		local ok = pcall(function() clone = modeleSource:Clone() end)
		if not ok or not clone then return false end
	end

	local tool = creerTool(player, clone, rarete)
	if not tool then return false end

	local entree = { rarete = rarete, toolRef = tool }
	table.insert(data.portes, entree)

	jouerSon(player)
	envoyerCarryUpdate(player)
	CarrySystem.UpdateDepotPrompts(player)
	return true
end

-- ============================================================
-- ProximityPrompt — Capture des Brain Rots EPIC+
-- ============================================================
-- ⚠️ Utilisé par BrainRotFarm (spawner appelle CarrySystem.OnBRSpawned).
-- Pour LavaTower (CollectionService), utiliser PickupSystem à la place.

local function creerPromptCapture(brModel, rarete, baseIndex, onCapture)
	local cfg = CAPTURE_CONFIG[rarete.nom]
	if not cfg or cfg.mode ~= "prompt" then
		return
	end

	local racine = obtenirRacine(brModel)
	if not racine then
		Logger.warn("Carry", "creerPromptCapture : racine introuvable sur %s", tostring(brModel and brModel.Name))
		return
	end

	-- Ancre au centre du bounding box (gros modèles type LEGENDARY)
	local ancre = racine
	if brModel:IsA("Model") then
		local ok, cf = pcall(function() local c, _ = brModel:GetBoundingBox(); return c end)
		if ok and cf then
			local p = Instance.new("Part")
			p.Name         = "PromptAnchor"
			p.Size         = Vector3.new(0.1, 0.1, 0.1)
			p.CFrame       = cf
			p.Anchored     = true
			p.CanCollide   = false
			p.Transparency = 1
			p.Parent       = brModel
			ancre = p
		end
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText            = cfg.actionText or "Capturer"
	prompt.ObjectText            = brModel.Name or rarete.nom
	prompt.HoldDuration          = cfg.holdDuration
	prompt.MaxActivationDistance = 20
	prompt.KeyboardKeyCode       = Enum.KeyCode.E
	prompt.RequiresLineOfSight   = false
	prompt.Style                 = Enum.ProximityPromptStyle.Default
	prompt.Parent                = ancre

	local holdingPlayer = nil
	local nomModele     = brModel.Name

	local function notifProgression(player, duree)
		task.spawn(function()
			local restant = duree
			while holdingPlayer == player and restant > 0 and brModel and brModel.Parent do
				notifierJoueur(player, "INFO", "⏳ Capturing... " .. math.ceil(restant) .. "s")
				task.wait(0.5)
				restant = restant - 0.5
			end
		end)
	end

	prompt.PromptButtonHoldBegan:Connect(function(player)
		if baseIndex ~= nil and CarrySystem.GetBaseJoueur then
			if CarrySystem.GetBaseJoueur(player) ~= baseIndex then
				notifierJoueur(player, "INFO", "This Brain Rot is not in your field!")
				prompt.Enabled = false
				task.delay(0.1, function()
					if prompt and prompt.Parent then prompt.Enabled = true end
				end)
				return
			end
		end

		local pData = donneesJoueurs[player.UserId]
		local max   = CarrySystem.GetCapaciteMax(player)
		if pData and (#pData.portes + getExtraCount(player)) >= max then
			prompt.Enabled = false
			messageSacPlein(player, pData)
			task.delay(0.1, function()
				if prompt and prompt.Parent then prompt.Enabled = true end
			end)
			return
		end

		if holdingPlayer and holdingPlayer ~= player then
			local precedent = holdingPlayer
			holdingPlayer   = nil
			prompt.Enabled  = false
			notifierJoueur(precedent, "INFO", player.Name .. " interrupted you!")
			task.delay(0.1, function()
				if prompt and prompt.Parent then prompt.Enabled = true end
			end)
		else
			holdingPlayer = player
			notifProgression(player, cfg.holdDuration)
		end
	end)

	prompt.PromptButtonHoldEnded:Connect(function(player)
		if holdingPlayer == player then
			holdingPlayer = nil
		end
	end)

	prompt.Triggered:Connect(function(player)
		if not brModel or not brModel.Parent then return end

		if baseIndex ~= nil and CarrySystem.GetBaseJoueur then
			if CarrySystem.GetBaseJoueur(player) ~= baseIndex then
				notifierJoueur(player, "INFO", "This Brain Rot is not in your field!")
				return
			end
		end

		local pData = donneesJoueurs[player.UserId]
		local max   = CarrySystem.GetCapaciteMax(player)
		if pData and (#pData.portes + getExtraCount(player)) >= max then
			messageSacPlein(player, pData)
			return
		end

		prompt.Enabled = false
		holdingPlayer  = nil
		pcall(function() brModel:SetAttribute("Captured", true) end)

		-- Notifier uniquement pour les raretés notables (valeur >= 8 → RARE et au-dessus)
		if (rarete.valeur or 0) >= 8 then
			notifierJoueur(player, "SUCCESS", "✅ [" .. nomModele .. "] " .. rarete.nom .. " grabbed!")
		end

		local success = effectuerRamassage(player, rarete, brModel)
		if success then
			-- Signaler à CommunSpawner (ou SpawnManager) que le BR a été capturé
			-- CRITIQUE : sans cet appel, collected reste false → le timer despawn
			-- détruit le clone à l'intérieur du Tool, corrompant le dépôt
			if onCapture then pcall(onCapture, player) end
		else
			pcall(function() brModel:SetAttribute("Captured", false) end)
			if prompt and prompt.Parent then prompt.Enabled = true end
		end
	end)
end

-- ============================================================
-- ProximityPrompt — Dépôt à la base
-- ============================================================

local function creerPromptDepot(player, touchPart)
	local ancien = touchPart:FindFirstChild("DepotPrompt")
	if ancien then ancien:Destroy() end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name                  = "DepotPrompt"
	prompt.ActionText            = "Deposit"
	prompt.ObjectText            = "0 Brain Rot"
	prompt.HoldDuration          = 0
	prompt.MaxActivationDistance = CARRY_CONFIG.depotMaxDistance
	prompt.KeyboardKeyCode       = Enum.KeyCode.E
	prompt.RequiresLineOfSight   = false
	prompt.Enabled               = false
	prompt.Parent                = touchPart

	prompt.Triggered:Connect(function(triggerPlayer)
		if triggerPlayer ~= player then return end
		local data = donneesJoueurs[player.UserId]
		if not data then return end

		-- Vérifier qu'il y a au moins 1 entrée avec toolRef valide (pas de fantômes)
		local nbValides = 0
		for _, entree in ipairs(data.portes) do
			if entree.toolRef and entree.toolRef.Parent then
				nbValides = nbValides + 1
			end
		end
		if nbValides == 0 then
			-- Nettoyer les entrées fantômes éventuelles puis bloquer le dépôt
			if #data.portes > 0 then
				CarrySystem.SynchroniserCarry(player)
			end
			return
		end

		local ok, DropSystem = pcall(require, game:GetService("ServerScriptService").SharedLib.Server.DropSystem)
		if ok and DropSystem and DropSystem.DeposerBrainRots then
			DropSystem.DeposerBrainRots(player, touchPart)
			return
		end
		Logger.warn("Carry", "DropSystem introuvable — carry vidé sans récompense")
		CarrySystem.ViderCarry(player)
	end)

	return prompt
end

-- ============================================================
-- Mise à jour du texte des prompts de dépôt (temps réel)
-- ============================================================

function CarrySystem.UpdateDepotPrompts(player)
	local data = donneesJoueurs[player.UserId]
	if not data or not data.depotPrompts then return end

	-- Compter uniquement les entrées avec toolRef valide (évite les fantômes activer les prompts)
	local nb = 0
	for _, entree in ipairs(data.portes) do
		if entree.toolRef and entree.toolRef.Parent then
			nb = nb + 1
		end
	end

	local coins = calculerCoinsPortes(data)
	local texte = nb .. " Brain Rot" .. (nb > 1 and "s" or "") .. " · +" .. coins .. " coins"

	for _, prompt in pairs(data.depotPrompts) do
		if prompt and prompt.Parent then
			pcall(function()
				prompt.Enabled    = nb > 0
				prompt.ObjectText = texte
			end)
		end
	end
end

-- ============================================================
-- Initialisation des spots de dépôt (appelé depuis Main.server.lua)
-- ============================================================

function CarrySystem.InitDepotSpotsBase(player, spotsActifs)
	if not donneesJoueurs[player.UserId] then initJoueur(player) end
	local data = donneesJoueurs[player.UserId]
	if not data then return end

	if data.depotPrompts then
		for _, prompt in pairs(data.depotPrompts) do
			if prompt and prompt.Parent then pcall(function() prompt:Destroy() end) end
		end
	end
	data.depotPrompts = {}

	for _, touchPart in ipairs(spotsActifs) do
		data.depotPrompts[touchPart] = creerPromptDepot(player, touchPart)
	end
	CarrySystem.UpdateDepotPrompts(player)
end

function CarrySystem.AjouterDepotSpot(player, touchPart)
	if not donneesJoueurs[player.UserId] then initJoueur(player) end
	local data = donneesJoueurs[player.UserId]
	if not data then return end
	if not data.depotPrompts then data.depotPrompts = {} end
	if data.depotPrompts[touchPart] then return end
	data.depotPrompts[touchPart] = creerPromptDepot(player, touchPart)
	CarrySystem.UpdateDepotPrompts(player)
end

-- ============================================================
-- Drop au sol (mort du joueur)
-- ============================================================

local function dropBrainRot(entree, positionMort)
	local modele = entree.modele
	if not modele then return end

	-- Assurer que le modèle est dans Workspace
	if modele.Parent ~= Workspace then
		modele.Parent = Workspace
	end

	local parts = {}
	if modele:IsA("BasePart") then
		table.insert(parts, modele)
	else
		for _, v in ipairs(modele:GetDescendants()) do
			if v:IsA("BasePart") then table.insert(parts, v) end
		end
	end

	local angle   = math.random() * math.pi * 2
	local rayon   = math.random() * CARRY_CONFIG.rayonDrop
	local posDrop = positionMort + Vector3.new(math.cos(angle) * rayon, 0.5, math.sin(angle) * rayon)

	pcall(function()
		if modele:IsA("Model") and modele.PrimaryPart then
			modele:PivotTo(CFrame.new(posDrop))
		elseif parts[1] then
			parts[1].CFrame = CFrame.new(posDrop)
		end
	end)

	for _, part in ipairs(parts) do
		part.CanCollide = false
		part.Anchored   = false
	end

	local collected = false

	local function tenterRamassage(player)
		if collected then return end
		local data = donneesJoueurs[player.UserId]
		if not data then return end
		local max = CarrySystem.GetCapaciteMax(player)
		if #data.portes + getExtraCount(player) >= max then
			messageSacPlein(player, data)
			return
		end
		collected = true
		local success = effectuerRamassage(player, entree.rarete, modele)
		if not success then collected = false end
	end

	for _, part in ipairs(parts) do
		part.Touched:Connect(function(hit)
			if collected then return end
			local char   = hit.Parent
			local player = Players:GetPlayerFromCharacter(char)
			if not player then
				char   = hit.Parent and hit.Parent.Parent
				player = char and Players:GetPlayerFromCharacter(char)
			end
			if player then tenterRamassage(player) end
		end)
	end

	task.delay(CARRY_CONFIG.dureeDropSecondes, function()
		if collected or not modele or not modele.Parent then return end
		collected = true
		local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad)
		for _, part in ipairs(parts) do
			if part and part.Parent then
				pcall(function() TweenService:Create(part, tweenInfo, { Transparency = 1 }):Play() end)
			end
		end
		task.delay(0.6, function()
			if modele and modele.Parent then modele:Destroy() end
		end)
	end)
end

-- ============================================================
-- Gestion mort + respawn
-- ============================================================

local function onMort(player)
	-- BRs conservés dans data.portes ; SynchroniserCarry les restaure au respawn
end

local function configurerMort(player, char)
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	humanoid.Died:Connect(function() onMort(player) end)
end

-- ============================================================
-- Init / nettoyage par joueur
-- ============================================================

initJoueur = function(player)
	-- Idempotent
	if donneesJoueurs[player.UserId] then return end
	donneesJoueurs[player.UserId] = {
		portes        = {},
		niveauCarry   = 0,
		hasProtection = false,
		depotPrompts  = {},
	}

	player.CharacterAdded:Connect(function(char)
		local data = donneesJoueurs[player.UserId]
		if not data then return end
		task.wait(0.5)
		-- Restaurer les BRs après respawn (Tools du Backpack précédent détruits par Roblox)
		CarrySystem.SynchroniserCarry(player)
		envoyerCarryUpdate(player)
		CarrySystem.UpdateDepotPrompts(player)
		configurerMort(player, char)
	end)

	if player.Character then
		task.spawn(function() configurerMort(player, player.Character) end)
	end

	envoyerCarryUpdate(player)
end

local function nettoyerJoueur(player)
	local data = donneesJoueurs[player.UserId]
	if data then
		-- Callback avant destruction (permet la sérialisation du carry)
		if CarrySystem.OnBeforeClean then
			pcall(CarrySystem.OnBeforeClean, player, data.portes)
		end
		for _, entree in ipairs(data.portes) do
			if entree.toolRef and entree.toolRef.Parent then
				pcall(function() entree.toolRef:Destroy() end)
			end
		end
		if data.depotPrompts then
			for _, prompt in pairs(data.depotPrompts) do
				if prompt and prompt.Parent then
					pcall(function() prompt:Destroy() end)
				end
			end
		end
	end
	donneesJoueurs[player.UserId] = nil
	carryBonuses[player.UserId]   = nil
	rayonAimant[player.UserId]    = nil
end

-- ============================================================
-- API publique
-- ============================================================

function CarrySystem.GetPortes(player)
	local data = donneesJoueurs[player.UserId]
	return data and data.portes or {}
end

function CarrySystem.GetCapaciteMax(player)
	local data = donneesJoueurs[player.UserId]
	if not data then return 1 end
	local base  = CARRY_CONFIG.niveaux[data.niveauCarry] or 1
	local bonus = carryBonuses[player.UserId] or 0
	return base + bonus
end

function CarrySystem.GetPrixUpgrade(player)
	local data = donneesJoueurs[player.UserId]
	if not data then return nil end
	return CARRY_CONFIG.prixUpgrade[data.niveauCarry + 1]
end

function CarrySystem.UpgraderCarry(player)
	local data = donneesJoueurs[player.UserId]
	if not data then return false, "Player not found" end
	local niveauSuivant = data.niveauCarry + 1
	if not CARRY_CONFIG.niveaux[niveauSuivant] then return false, "Max level reached" end
	if niveauSuivant == 3 and not data.hasProtection then return false, "VIP required for level 3" end
	data.niveauCarry = niveauSuivant
	envoyerCarryUpdate(player)
	return true, "Carry level " .. niveauSuivant .. " unlocked"
end

-- Vide le carry et retourne la liste des BR : { modele, rarete }
-- Le visuel est extrait du Tool et placé dans Workspace (prêt pour placerMiniModele du DropSystem).
function CarrySystem.ViderCarry(player)
	local data = donneesJoueurs[player.UserId]
	if not data then return {} end
	local deposes = {}
	for _, entree in ipairs(data.portes) do
		local modele = nil
		if entree.toolRef and entree.toolRef.Parent then
			modele = extraireVisuel(entree.toolRef)
		end
		table.insert(deposes, { modele = modele, rarete = entree.rarete })
	end
	data.portes = {}
	envoyerCarryUpdate(player)
	CarrySystem.UpdateDepotPrompts(player)
	return deposes
end

-- Ajouter un BR directement au carry (utilisé par FlowerPotSystem, DropSystem, PickupSystem)
-- clone  : Model ou BasePart existant (nil → clone depuis ServerStorage via rarete.dossier)
-- rarete : table { nom=string, dossier=string?, isMutant=bool?, valeur=number? }
-- Retourne true si succès, false si carry plein
function CarrySystem.AjouterAuCarry(player, clone, rarete)
	return effectuerRamassage(player, rarete, clone)
end

-- Retourne true si le carry est plein (items portés + items extra comme les graines)
function CarrySystem.EstPlein(player)
	local data = donneesJoueurs[player.UserId]
	if not data then return false end
	return (#data.portes + getExtraCount(player)) >= CarrySystem.GetCapaciteMax(player)
end

-- Déclenche manuellement une mise à jour du HUD carry
-- Utile après un changement d'items extra (ex : graine ajoutée/retirée)
function CarrySystem.EnvoyerCarryUpdate(player)
	envoyerCarryUpdate(player)
end

-- Insère un BR en tête du carry (position 1) au lieu de l'ajouter en fin.
-- Utilisé par DropSystem.RecupererBrainRot pour que le BR récupéré soit
-- le prochain à être déposé (portes[1] dans DeposerBrainRots).
function CarrySystem.InsererEnTeteCarry(player, clone, rarete)
	local data = donneesJoueurs[player.UserId]
	if not data then return false end

	local max = CarrySystem.GetCapaciteMax(player)
	if #data.portes >= max then
		messageSacPlein(player, data)
		return false
	end

	local source = clone
	if not source or not source.Parent then
		local nomDossier   = rarete and rarete.dossier or "COMMON"
		local modeleSource = choisirModele(nomDossier)
		if not modeleSource then return false end
		local ok = pcall(function() source = modeleSource:Clone() end)
		if not ok or not source then return false end
	end

	local tool = creerTool(player, source, rarete)
	if not tool then return false end

	local entree = { rarete = rarete, toolRef = tool }
	table.insert(data.portes, 1, entree)  -- en tête, pas en fin

	envoyerCarryUpdate(player)
	jouerSon(player)
	CarrySystem.UpdateDepotPrompts(player)
	return true
end

-- Synchronise data.portes après un changement de character :
-- les Tools du Backpack précédent sont détruits par Roblox → entrées fantômes.
-- Pour chaque fantôme, on recrée un Tool depuis ServerStorage afin que le joueur
-- retrouve ses BRs intacts après un respawn.
function CarrySystem.SynchroniserCarry(player)
	local data = donneesJoueurs[player.UserId]
	if not data then return end

	local valides = {}
	local raretesARestorer = {}
	for _, entree in ipairs(data.portes) do
		if entree.toolRef and entree.toolRef.Parent then
			table.insert(valides, entree)
		else
			if entree.toolRef then
				pcall(function() entree.toolRef:Destroy() end)
			end
			table.insert(raretesARestorer, entree.rarete)
		end
	end

	data.portes = valides
	envoyerCarryUpdate(player)
	CarrySystem.UpdateDepotPrompts(player)

	-- Restaurer les BRs dont le Tool a été détruit lors du changement de character
	for _, rarete in ipairs(raretesARestorer) do
		CarrySystem.AjouterAuCarry(player, nil, rarete)
	end
	if #raretesARestorer > 0 then
		Logger.info("Carry", "SynchroniserCarry : %d BR(s) restauré(s) pour %s", #raretesARestorer, player.Name)
	end
end

function CarrySystem.SetProtection(player, valeur)
	local data = donneesJoueurs[player.UserId]
	if data then data.hasProtection = valeur == true end
end

-- Définit la capacité TOTALE de carry (shopUpgrade Carry)
-- totalSlots = nombre de slots voulus au total (ex : 3, 5, 8)
-- Le bonus est calculé en soustrayant la base (CarryNiveaux[0])
function CarrySystem.SetCapacite(player, totalSlots)
	local base = CARRY_CONFIG.niveaux[0] or 1
	carryBonuses[player.UserId] = math.max(0, (totalSlots or base) - base)
	envoyerCarryUpdate(player)
end

-- Définit le rayon aimant du joueur (shopUpgrade Aimant)
function CarrySystem.SetRayonAimant(player, rayon)
	rayonAimant[player.UserId] = math.max(0, rayon or 0)
end

function CarrySystem.GetRayonAimant(player)
	return rayonAimant[player.UserId] or 0
end

-- Appelé depuis Main.server.lua / SpawnManager pour attacher un ProximityPrompt au BR.
-- ⚠️ Spécifique BrainRotFarm — pour LavaTower, utiliser PickupSystem.
function CarrySystem.OnBRSpawned(brModel, baseIndex, rarete, onCapture)
	if not rarete then
		Logger.warn("Carry", "OnBRSpawned : rarete nil")
		return
	end
	creerPromptCapture(brModel, rarete, baseIndex, onCapture)
end

-- ============================================================
-- Init (appelé par Main.server.lua)
-- ============================================================
function CarrySystem.Init(brainrotsFolder)
	BRAINROTS_FOLDER = brainrotsFolder or ServerStorage:WaitForChild("Brainrots")

	local existing = ReplicatedStorage:FindFirstChild("CarryUpdate")
	if existing then
		CarryUpdate = existing
	else
		CarryUpdate        = Instance.new("RemoteEvent")
		CarryUpdate.Name   = "CarryUpdate"
		CarryUpdate.Parent = ReplicatedStorage
	end

	-- RemoteEvents compatibles BrainrotCarryUI (LavaTower / PickupSystem)
	local function getOrCreate(name)
		local e = ReplicatedStorage:FindFirstChild(name)
		if e then return e end
		local re = Instance.new("RemoteEvent")
		re.Name   = name
		re.Parent = ReplicatedStorage
		return re
	end
	getOrCreate("BrainrotCarryUpdate")
	getOrCreate("BrainrotCarryError")

	for _, player in ipairs(Players:GetPlayers()) do
		initJoueur(player)
	end
	Players.PlayerAdded:Connect(initJoueur)
	Players.PlayerRemoving:Connect(nettoyerJoueur)

	Logger.info("Carry", "✓ Initialisé (Tool/Backpack)")
end

return CarrySystem
