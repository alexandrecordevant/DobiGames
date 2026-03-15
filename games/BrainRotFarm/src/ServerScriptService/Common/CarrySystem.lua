-- ServerScriptService/CarrySystem.lua
-- BrainRotFarm — Transport + Capture des Brain Rots
-- Touched pour COMMON/OG/RARE
-- ProximityPrompt avec HoldDuration progressif pour EPIC → BRAINROT_GOD
-- ProximityPrompt instantané pour dépôt à la base

local CarrySystem = {}

-- API publique — assignée depuis Main.server.lua
-- function(player) → baseIndex ou nil
CarrySystem.GetBaseJoueur = nil

-- ============================================================
-- Services
-- ============================================================
local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")
local Workspace         = game:GetService("Workspace")
local Debris            = game:GetService("Debris")

-- ============================================================
-- Configuration capture hybride
-- ============================================================
local CAPTURE_CONFIG = {
	COMMON       = { mode = "prompt",  holdDuration = 0,   actionText = "Ramasser"           },
	OG           = { mode = "prompt",  holdDuration = 0,   actionText = "Ramasser !"         },
	RARE         = { mode = "prompt",  holdDuration = 0,   actionText = "🌟 Saisir !"        },
	EPIC         = { mode = "prompt",  holdDuration = 0.5, actionText = "Capturer"           },
	LEGENDARY    = { mode = "prompt",  holdDuration = 1.5, actionText = "Saisir !"           },
	MYTHIC       = { mode = "prompt",  holdDuration = 3.0, actionText = "⚡ Attraper !!"     },
	SECRET       = { mode = "prompt",  holdDuration = 5.0, actionText = "🔴 Capturer !!!"   },
	BRAINROT_GOD = { mode = "prompt",  holdDuration = 8.0, actionText = "👑 LÉGENDAIRE !!!" },
}

-- Valeur estimée par rareté (pour l'affichage du texte de dépôt)
local VALEURS_PAR_RARETE = {
	COMMON       = 1,
	OG           = 3,
	RARE         = 10,
	EPIC         = 30,
	LEGENDARY    = 100,
	MYTHIC       = 300,
	SECRET       = 1000,
	BRAINROT_GOD = 500,
}

local CARRY_CONFIG = {
	niveaux = {
		[0] = 3,  -- défaut : 3 BR
		[1] = 5,
		[2] = 8,
		[3] = 15, -- VIP uniquement
	},
	prixUpgrade = {
		[1] = 1000,
		[2] = 5000,
		[3] = 0,    -- VIP
	},
	-- Offsets {x, y, z} par slot — spirale étagée autour du joueur
	slotOffsets = {
		[1]  = { x =  0.0, y =  5.5, z =  0.0 },
		[2]  = { x =  0.0, y =  7.0, z =  3.5 },
		[3]  = { x =  0.0, y =  7.0, z = -3.5 },
		[4]  = { x =  3.5, y =  8.5, z =  0.0 },
		[5]  = { x = -3.5, y =  8.5, z =  0.0 },
		[6]  = { x =  3.0, y = 10.5, z =  3.0 },
		[7]  = { x = -3.0, y = 10.5, z =  3.0 },
		[8]  = { x =  0.0, y = 12.0, z =  0.0 },
		[9]  = { x =  3.0, y = 13.5, z = -3.0 },
		[10] = { x = -3.0, y = 13.5, z = -3.0 },
		[11] = { x =  3.5, y = 15.0, z =  0.0 },
		[12] = { x = -3.5, y = 15.0, z =  0.0 },
		[13] = { x =  0.0, y = 16.5, z =  3.5 },
		[14] = { x =  0.0, y = 16.5, z = -3.5 },
		[15] = { x =  0.0, y = 18.5, z =  0.0 },
	},
	rayonDrop         = 3,
	dureeDropSecondes = 15,
	bobbingAmplitude  = 0.3,
	bobbingVitesse    = 1.0,
	sonCollecte       = 0,
	depotMaxDistance  = 8,
}

-- ============================================================
-- État interne par joueur
-- ============================================================
-- { portes, niveauCarry, hasProtection, depotPrompts = {touchPart→prompt} }
local donneesJoueurs = {}

local CarryUpdate      = nil
local BRAINROTS_FOLDER = nil

-- ============================================================
-- Utilitaires
-- ============================================================

local function obtenirRacine(instance)
	if instance:IsA("BasePart") then return instance end
	if instance.PrimaryPart then return instance.PrimaryPart end
	-- Fallback : part la plus grande par volume (évite les hitbox invisibles)
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

local function obtenirBaseParts(instance)
	local parts = {}
	if instance:IsA("BasePart") then table.insert(parts, instance) end
	for _, v in ipairs(instance:GetDescendants()) do
		if v:IsA("BasePart") then table.insert(parts, v) end
	end
	return parts
end

local function choisirModele(nomDossier)
	if not BRAINROTS_FOLDER then return nil end
	local dossier = BRAINROTS_FOLDER:FindFirstChild(nomDossier)
	if not dossier then
		warn("[CarrySystem] Dossier introuvable : " .. tostring(nomDossier))
		return nil
	end
	local modeles = dossier:GetChildren()
	if #modeles == 0 then return nil end
	return modeles[math.random(1, #modeles)]
end

local function envoyerCarryUpdate(player)
	if not CarryUpdate then return end
	local data = donneesJoueurs[player.UserId]
	if not data then return end
	local max = CARRY_CONFIG.niveaux[data.niveauCarry] or 1
	pcall(function()
		CarryUpdate:FireClient(player, { portes = #data.portes, max = max })
	end)
end

local function notifierJoueur(player, typeNotif, message)
	local ev = ReplicatedStorage:FindFirstChild("NotifEvent")
	if ev then pcall(function() ev:FireClient(player, typeNotif, message) end) end
end

local function notifierTous(message)
	local ev = ReplicatedStorage:FindFirstChild("NotifEvent")
	if ev then pcall(function() ev:FireAllClients("INFO", message) end) end
	print("[CarrySystem] " .. message)
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
			total = total + (VALEURS_PAR_RARETE[entree.rarete.nom or ""] or 1)
		end
	end
	return total
end

-- ============================================================
-- Attachement visuel (Motor6D + bobbing)
-- ============================================================

local function attacherModele(player, modele, slotIndex)
	local char = player.Character
	if not char then modele:Destroy() return nil end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then modele:Destroy() return nil end

	local racine = obtenirRacine(modele)
	if not racine then modele:Destroy() return nil end

	local parts = obtenirBaseParts(modele)
	for _, part in ipairs(parts) do
		part.CanCollide = false
		part.Anchored   = false
	end
	modele.Parent = Workspace

	local off  = CARRY_CONFIG.slotOffsets[slotIndex]
	           or { x = 0, y = 5 + (slotIndex - 1) * 2, z = 0 }
	local rotY = math.random() * math.pi * 2

	local motor = nil
	local ok = pcall(function()
		motor        = Instance.new("Motor6D")
		motor.Name   = "CarryMotor_" .. slotIndex
		motor.Part0  = hrp
		motor.Part1  = racine
		motor.C0     = CFrame.new(off.x, off.y, off.z) * CFrame.Angles(0, rotY, 0)
		motor.C1     = CFrame.new()
		motor.Parent = hrp
	end)
	if not ok or not motor then
		pcall(function() modele:Destroy() end)
		return nil
	end

	-- Bobbing via loop Motor6D.C0
	local bobbingThread = task.spawn(function()
		local t = 0
		while motor and motor.Parent do
			t = t + task.wait(0.03)
			local bob = math.sin(t * math.pi * 2 * CARRY_CONFIG.bobbingVitesse) * CARRY_CONFIG.bobbingAmplitude
			pcall(function()
				motor.C0 = CFrame.new(off.x, off.y + bob, off.z) * CFrame.Angles(0, rotY, 0)
			end)
		end
	end)

	return {
		modele        = modele,
		racine        = racine,
		motor         = motor,
		bobbingThread = bobbingThread,
		off           = off,
		rotY          = rotY,
	}
end

local function messageSacPlein(player, pData)
	local niveau    = pData and pData.niveauCarry or 0
	local max       = CARRY_CONFIG.niveaux[niveau] or 1
	local niveauMax = CARRY_CONFIG.niveaux[niveau + 1] == nil

	if niveauMax then
		notifierJoueur(player, "INFO",
			"🎒 Sac plein ! (" .. max .. "/" .. max .. ") — Dépose tes Brain Rots à la base d'abord.")
	else
		local prochainMax = CARRY_CONFIG.niveaux[niveau + 1]
		local prix        = CARRY_CONFIG.prixUpgrade[niveau + 1] or 0
		notifierJoueur(player, "INFO",
			"🎒 Sac plein ! (" .. max .. "/" .. max .. ") — "
			.. "💡 Option : augmente ta capacité à " .. prochainMax .. " slots pour "
			.. prix .. " coins au Shop !")
	end
end

local function detacherModele(entree)
	if entree.bobbingThread then
		pcall(function() task.cancel(entree.bobbingThread) end)
		entree.bobbingThread = nil
	end
	if entree.motor and entree.motor.Parent then
		pcall(function() entree.motor:Destroy() end)
		entree.motor = nil
	end
end

-- Logique commune : utilise modeleExistant s'il est fourni, sinon clone depuis ServerStorage
local function effectuerRamassage(player, rarete, modeleExistant)
	local data = donneesJoueurs[player.UserId]
	if not data then return false end

	local max = CARRY_CONFIG.niveaux[data.niveauCarry] or 1
	if #data.portes >= max then
		messageSacPlein(player, data)
		return false
	end

	local clone
	if modeleExistant and modeleExistant.Parent then
		clone = modeleExistant
		-- Supprimer le billboard du monde et le ProximityPrompt s'ils existent encore
		pcall(function()
			for _, child in ipairs(clone:GetDescendants()) do
				if child:IsA("BillboardGui") or child:IsA("ProximityPrompt") then
					child:Destroy()
				end
			end
		end)
	else
		local nomDossier   = rarete and rarete.dossier or "COMMON"
		local modeleSource = choisirModele(nomDossier)
		if not modeleSource then return false end
		local ok = pcall(function() clone = modeleSource:Clone() end)
		if not ok or not clone then return false end
	end

	local slotIndex = #data.portes + 1
	local entree    = attacherModele(player, clone, slotIndex)
	if not entree then return false end

	entree.rarete = rarete
	table.insert(data.portes, entree)
	jouerSon(player)
	envoyerCarryUpdate(player)
	CarrySystem.UpdateDepotPrompts(player)
	return true
end

-- ============================================================
-- ProximityPrompt — Capture des Brain Rots EPIC+
-- ============================================================
-- ⚠️  Pour fonctionner, BrainRotSpawner doit exposer :
--      BrainRotSpawner.OnBRSpawned = nil
--      → Appeler pcall(BrainRotSpawner.OnBRSpawned, clone, baseIndex, rarete)
--        à la fin de spawnerUnBrainRot(), après l'animation de pousse de terre.

local function creerPromptCapture(brModel, rarete, baseIndex, onCapture)
	local cfg = CAPTURE_CONFIG[rarete.nom]
	if not cfg or cfg.mode ~= "prompt" then
		return
	end

	local racine = obtenirRacine(brModel)
	if not racine then
		warn("[CarrySystem] creerPromptCapture : racine introuvable sur", brModel and brModel.Name)
		return
	end

	-- Ancre au centre du bounding box (Bug 2 : gros modèles comme LEGENDARY elephant)
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
	prompt.MaxActivationDistance = 20  -- Bug 2 : distance augmentée (était 10)
	prompt.KeyboardKeyCode       = Enum.KeyCode.E
	prompt.RequiresLineOfSight   = false
	prompt.Style                 = Enum.ProximityPromptStyle.Default
	prompt.Parent                = ancre

	local holdingPlayer = nil  -- joueur en train de tenir le prompt
	local nomModele     = brModel.Name

	-- Progression toutes les 0.5s pendant un hold
	local function notifProgression(player, duree)
		task.spawn(function()
			local restant = duree
			while holdingPlayer == player and restant > 0 and brModel and brModel.Parent do
				notifierJoueur(player, "INFO", "⏳ Capture en cours... " .. math.ceil(restant) .. "s")
				task.wait(0.5)
				restant = restant - 0.5
			end
		end)
	end

	-- Début de hold
	prompt.PromptButtonHoldBegan:Connect(function(player)
		-- Bug 1 : vérification base (nil = ChampCommun, tout le monde peut capturer)
		if baseIndex ~= nil and CarrySystem.GetBaseJoueur then
			if CarrySystem.GetBaseJoueur(player) ~= baseIndex then
				notifierJoueur(player, "INFO", "❌ Ce Brain Rot n'est pas dans ton champ !")
				prompt.Enabled = false
				task.delay(0.1, function()
					if prompt and prompt.Parent then prompt.Enabled = true end
				end)
				return
			end
		end

		-- Sac plein → interrompre immédiatement
		local pData = donneesJoueurs[player.UserId]
		local max   = pData and (CARRY_CONFIG.niveaux[pData.niveauCarry] or 1) or 1
		if pData and #pData.portes >= max then
			prompt.Enabled = false
			messageSacPlein(player, pData)
			task.delay(0.1, function()
				if prompt and prompt.Parent then prompt.Enabled = true end
			end)
			return
		end

		if holdingPlayer and holdingPlayer ~= player then
			-- Compétition : annuler le hold du joueur précédent
			local precedent = holdingPlayer
			holdingPlayer   = nil

			-- Désactiver le prompt cancel le hold côté client
			prompt.Enabled = false
			notifierJoueur(precedent, "INFO", "❌ " .. player.Name .. " t'a interrompu !")
			notifierJoueur(player,    "INFO", "⚡ Tu peux tenter de capturer !")
			notifierAutresJoueurs(player, "INFO",
				"⚠️ " .. player.Name .. " tente d'attraper un " .. rarete.nom .. " !")

			task.delay(0.1, function()
				if prompt and prompt.Parent then prompt.Enabled = true end
			end)
		else
			holdingPlayer = player
			notifProgression(player, cfg.holdDuration)
			notifierAutresJoueurs(player, "INFO",
				"⚠️ " .. player.Name .. " tente d'attraper un " .. rarete.nom .. " !")
		end
	end)

	-- Fin de hold (annulé ou lâché)
	prompt.PromptButtonHoldEnded:Connect(function(player)
		if holdingPlayer == player then
			holdingPlayer = nil
		end
	end)

	-- Capture réussie
	prompt.Triggered:Connect(function(player)
		if not brModel or not brModel.Parent then return end

		-- Bug 1 : vérification base dans Triggered aussi
		if baseIndex ~= nil and CarrySystem.GetBaseJoueur then
			if CarrySystem.GetBaseJoueur(player) ~= baseIndex then
				notifierJoueur(player, "INFO", "❌ Ce Brain Rot n'est pas dans ton champ !")
				return
			end
		end

		-- Double-check sac plein (cas rare où la capacité change pendant le hold)
		local pData = donneesJoueurs[player.UserId]
		local max   = pData and (CARRY_CONFIG.niveaux[pData.niveauCarry] or 1) or 1
		if pData and #pData.portes >= max then
			messageSacPlein(player, pData)
			return
		end

		prompt.Enabled = false
		holdingPlayer  = nil

		-- Marquer comme capturé pour que le despawn timer de BrainRotSpawner l'ignore
		pcall(function() brModel:SetAttribute("Captured", true) end)

		notifierTous("🏆 " .. player.Name .. " a attrapé [" .. nomModele .. "] " .. rarete.nom .. " !")

		-- Passer le modèle monde directement (pas de clone depuis ServerStorage)
		local success = effectuerRamassage(player, rarete, brModel)
		if success then
			if onCapture then pcall(onCapture, player) end
		else
			-- Échec ramassage : re-permettre capture
			pcall(function() brModel:SetAttribute("Captured", false) end)
			if prompt and prompt.Parent then prompt.Enabled = true end
		end
	end)
end

-- ============================================================
-- ProximityPrompt — Dépôt à la base
-- ============================================================

local function creerPromptDepot(player, touchPart)
	-- Supprimer l'ancien prompt si présent
	local ancien = touchPart:FindFirstChild("DepotPrompt")
	if ancien then ancien:Destroy() end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name                  = "DepotPrompt"
	prompt.ActionText            = "Déposer"
	prompt.ObjectText            = "0 Brain Rot"
	prompt.HoldDuration          = 0
	prompt.MaxActivationDistance = CARRY_CONFIG.depotMaxDistance
	prompt.KeyboardKeyCode       = Enum.KeyCode.E
	prompt.RequiresLineOfSight   = false
	prompt.Enabled               = false  -- activé seulement si carry > 0
	prompt.Parent                = touchPart

	prompt.Triggered:Connect(function(triggerPlayer)
		-- Seul le propriétaire de la base peut déposer
		if triggerPlayer ~= player then return end
		local data = donneesJoueurs[player.UserId]
		if not data or #data.portes == 0 then return end

		-- Appeler DropSystem si disponible
		local SSS = game:GetService("ServerScriptService")
		local commonFolder = SSS:FindFirstChild("Common")
		local dropChild = commonFolder and commonFolder:FindFirstChild("DropSystem")
		if dropChild then
			local ok, DropSystem = pcall(require, dropChild)
			if ok and DropSystem and DropSystem.DeposerBrainRots then
				DropSystem.DeposerBrainRots(player, touchPart)
				return
			end
		end
		-- Fallback avant création de DropSystem
		warn("[CarrySystem] DropSystem introuvable — carry vidé sans récompense")
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

	local nb     = #data.portes
	local coins  = calculerCoinsPortes(data)
	local texte  = nb .. " Brain Rot" .. (nb > 1 and "s" or "") .. " · +" .. coins .. " coins"

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

-- Crée les prompts de dépôt pour tous les spots actifs d'un joueur
function CarrySystem.InitDepotSpotsBase(player, spotsActifs)
	local data = donneesJoueurs[player.UserId]
	if not data then return end

	-- Nettoyer les anciens prompts
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

-- Ajoute un prompt pour un nouveau spot débloqué après Init
function CarrySystem.AjouterDepotSpot(player, touchPart)
	local data = donneesJoueurs[player.UserId]
	if not data then return end
	if not data.depotPrompts then data.depotPrompts = {} end
	if data.depotPrompts[touchPart] then return end  -- déjà existant

	data.depotPrompts[touchPart] = creerPromptDepot(player, touchPart)
	CarrySystem.UpdateDepotPrompts(player)
end

-- ============================================================
-- Drop au sol (mort du joueur)
-- ============================================================

local function dropBrainRot(entree, positionMort)
	local modele = entree.modele
	if not modele or not modele.Parent then return end

	local parts   = obtenirBaseParts(modele)
	local angle   = math.random() * math.pi * 2
	local rayon   = math.random() * CARRY_CONFIG.rayonDrop
	local posDrop = positionMort + Vector3.new(math.cos(angle) * rayon, 0.5, math.sin(angle) * rayon)

	pcall(function()
		if modele:IsA("Model") and modele.PrimaryPart then
			modele:PivotTo(CFrame.new(posDrop))
		elseif entree.racine then
			entree.racine.CFrame = CFrame.new(posDrop)
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
		local max = CARRY_CONFIG.niveaux[data.niveauCarry] or 1
		if #data.portes >= max then
			messageSacPlein(player, data)
			return
		end
		collected = true
		local slotIndex      = #data.portes + 1
		local nouvelleEntree = attacherModele(player, modele, slotIndex)
		if not nouvelleEntree then collected = false return end
		nouvelleEntree.rarete = entree.rarete
		table.insert(data.portes, nouvelleEntree)
		envoyerCarryUpdate(player)
		CarrySystem.UpdateDepotPrompts(player)
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
	local data = donneesJoueurs[player.UserId]
	if not data or #data.portes == 0 then return end
	if data.hasProtection then return end

	local hrp     = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local posMort = hrp and hrp.Position or Vector3.new(0, 5, 0)

	notifierTous("💀 " .. player.Name .. " a lâché ses Brain Rots !")

	local portesADrop = data.portes
	data.portes = {}

	for _, entree in ipairs(portesADrop) do
		detacherModele(entree)
		dropBrainRot(entree, posMort)
	end

	envoyerCarryUpdate(player)
	CarrySystem.UpdateDepotPrompts(player)
end

local function configurerMort(player, char)
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	humanoid.Died:Connect(function() onMort(player) end)
end

-- ============================================================
-- Init / nettoyage par joueur
-- ============================================================

local function initJoueur(player)
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

		-- Game Pass Protection : re-attacher après respawn
		if data.hasProtection and #data.portes > 0 then
			local ancien = data.portes
			data.portes  = {}
			for _, entree in ipairs(ancien) do
				if entree.modele and entree.modele.Parent then
					local slotIndex      = #data.portes + 1
					local nouvelleEntree = attacherModele(player, entree.modele, slotIndex)
					if nouvelleEntree then
						nouvelleEntree.rarete = entree.rarete
						table.insert(data.portes, nouvelleEntree)
					end
				end
			end
			envoyerCarryUpdate(player)
			CarrySystem.UpdateDepotPrompts(player)
		end
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
		for _, entree in ipairs(data.portes) do
			detacherModele(entree)
			if entree.modele and entree.modele.Parent then
				pcall(function() entree.modele:Destroy() end)
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
	return CARRY_CONFIG.niveaux[data.niveauCarry] or 1
end

function CarrySystem.GetPrixUpgrade(player)
	local data = donneesJoueurs[player.UserId]
	if not data then return nil end
	return CARRY_CONFIG.prixUpgrade[data.niveauCarry + 1]
end

function CarrySystem.UpgraderCarry(player)
	local data = donneesJoueurs[player.UserId]
	if not data then return false, "Joueur introuvable" end
	local niveauSuivant = data.niveauCarry + 1
	if not CARRY_CONFIG.niveaux[niveauSuivant] then return false, "Niveau maximum atteint" end
	if niveauSuivant == 3 and not data.hasProtection then return false, "VIP requis pour le niveau 3" end
	data.niveauCarry = niveauSuivant
	envoyerCarryUpdate(player)
	return true, "Carry niveau " .. niveauSuivant .. " débloqué"
end

-- Vide le carry et retourne la liste des BR déposés (appelé par DropSystem)
function CarrySystem.ViderCarry(player)
	local data = donneesJoueurs[player.UserId]
	if not data then return {} end
	local deposes = {}
	for _, entree in ipairs(data.portes) do
		detacherModele(entree)
		table.insert(deposes, { modele = entree.modele, rarete = entree.rarete })
	end
	data.portes = {}
	envoyerCarryUpdate(player)
	CarrySystem.UpdateDepotPrompts(player)
	return deposes
end

function CarrySystem.SetProtection(player, valeur)
	local data = donneesJoueurs[player.UserId]
	if data then data.hasProtection = valeur == true end
end

-- Appelé depuis Main.server.lua via BrainRotSpawner.OnCollecte
-- Pour les BRs en mode "touched" (COMMON / OG / RARE)
function CarrySystem.RamasserBR(player, rarete, brModel)
	local cfg = CAPTURE_CONFIG[rarete and rarete.nom or "COMMON"]
	if cfg and cfg.mode == "prompt" then
		return false  -- géré par OnBRSpawned → ProximityPrompt
	end
	return effectuerRamassage(player, rarete, brModel)
end

-- Appelé depuis Main.server.lua, connecté à BrainRotSpawner.OnBRSpawned.
-- Pour les BRs EPIC+ : attache un ProximityPrompt au modèle monde.
--
-- ⚠️ Nécessite l'ajout dans BrainRotSpawner, à la fin de spawnerUnBrainRot()
--    (après l'animation, avant le task.delay despawn) :
--
--    if BrainRotSpawner.OnBRSpawned then
--        pcall(BrainRotSpawner.OnBRSpawned, clone, baseIndex, rarete)
--    end
--
function CarrySystem.OnBRSpawned(brModel, baseIndex, rarete, onCapture)
	if not rarete then
		warn("[CarrySystem] OnBRSpawned : rarete nil")
		return
	end
	local cfg = CAPTURE_CONFIG[rarete.nom]
	if cfg and cfg.mode == "prompt" then
		creerPromptCapture(brModel, rarete, baseIndex, onCapture)
	end
	-- mode "touched" : BrainRotSpawner gère via Touched + OnCollecte
end

-- ============================================================
-- Init (appelé par Main.server.lua)
-- ============================================================
function CarrySystem.Init()
	BRAINROTS_FOLDER = ServerStorage:WaitForChild("Brainrots")

	local existing = ReplicatedStorage:FindFirstChild("CarryUpdate")
	if existing then
		CarryUpdate = existing
	else
		CarryUpdate        = Instance.new("RemoteEvent")
		CarryUpdate.Name   = "CarryUpdate"
		CarryUpdate.Parent = ReplicatedStorage
	end

	for _, player in ipairs(Players:GetPlayers()) do
		initJoueur(player)
	end
	Players.PlayerAdded:Connect(initJoueur)
	Players.PlayerRemoving:Connect(nettoyerJoueur)

	print("[CarrySystem] ✓ Initialisé (Touched COMMON/OG/RARE · ProximityPrompt EPIC+)")
end

return CarrySystem
