-- ServerScriptService/CarrySystem.lua
-- BrainRotFarm — Transport des Brain Rots
-- Stack visuel au-dessus de la tête, drop à la mort

local CarrySystem = {}

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
-- Configuration
-- ============================================================
local CARRY_CONFIG = {
	niveaux = {
		[0] = 1,  -- défaut : 1 BR
		[1] = 2,  -- upgrade 1
		[2] = 3,  -- upgrade 2
		[3] = 5,  -- upgrade 3 (VIP uniquement)
	},
	prixUpgrade = {
		[1] = 500,
		[2] = 2000,
		[3] = 0,  -- VIP Game Pass uniquement
	},
	-- Y offsets par slot (index = position dans le stack, 1-based)
	yOffsets          = { 4, 6, 8, 10, 12 },
	-- Drop à la mort
	rayonDrop         = 3,    -- studs de dispersion max
	dureeDropSecondes = 15,   -- durée de vie au sol avant disparition
	-- Bobbing
	bobbingAmplitude  = 0.3,  -- amplitude en studs
	bobbingVitesse    = 1.0,  -- cycles par seconde
	-- Son de collecte (0 = désactivé)
	sonCollecte       = 0,
}

-- ============================================================
-- État interne
-- ============================================================
-- Structure par joueur :
-- { portes = { entree, ... }, niveauCarry = 0, hasProtection = false }
-- Structure entree :
-- { modele, racine, rarete, motor, bobbingThread, yOffset, rotY }
local donneesJoueurs = {}

-- RemoteEvent (assigné dans Init)
local CarryUpdate = nil

-- Dossier des modèles dans ServerStorage
local BRAINROTS_FOLDER = nil

-- ============================================================
-- Utilitaires
-- ============================================================

local function obtenirRacine(instance)
	if instance:IsA("BasePart") then return instance end
	if instance.PrimaryPart then return instance.PrimaryPart end
	for _, v in ipairs(instance:GetDescendants()) do
		if v:IsA("BasePart") then return v end
	end
	return nil
end

local function obtenirBaseParts(instance)
	local parts = {}
	if instance:IsA("BasePart") then
		table.insert(parts, instance)
	end
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

local function jouerSon(player)
	if CARRY_CONFIG.sonCollecte == 0 then return end
	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	pcall(function()
		local son     = Instance.new("Sound")
		son.SoundId   = "rbxassetid://" .. CARRY_CONFIG.sonCollecte
		son.Volume    = 0.5
		son.Parent    = hrp
		son:Play()
		Debris:AddItem(son, 3)
	end)
end

-- ============================================================
-- Attachement visuel (Motor6D + bobbing)
-- ============================================================

-- Attache le modèle au-dessus de la tête du joueur via Motor6D.
-- Retourne une entree { modele, racine, motor, bobbingThread, yOffset, rotY }
-- ou nil si l'attachement a échoué.
local function attacherModele(player, modele, slotIndex)
	local char = player.Character
	if not char then modele:Destroy() return nil end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then modele:Destroy() return nil end

	local racine = obtenirRacine(modele)
	if not racine then modele:Destroy() return nil end

	-- Désactiver la collision sur toutes les parts
	local parts = obtenirBaseParts(modele)
	for _, part in ipairs(parts) do
		part.CanCollide = false
		part.Anchored   = false
	end

	modele.Parent = Workspace

	local yOffset = CARRY_CONFIG.yOffsets[slotIndex] or (4 + (slotIndex - 1) * 2)
	local rotY    = math.random() * math.pi * 2  -- légère rotation aléatoire sur Y

	-- Créer le joint Motor6D avec l'offset voulu
	local motor = nil
	local ok = pcall(function()
		motor        = Instance.new("Motor6D")
		motor.Name   = "CarryMotor_" .. slotIndex
		motor.Part0  = hrp
		motor.Part1  = racine
		motor.C0     = CFrame.new(0, yOffset, 0) * CFrame.Angles(0, rotY, 0)
		motor.C1     = CFrame.new()
		motor.Parent = hrp
	end)
	if not ok or not motor then
		pcall(function() modele:Destroy() end)
		return nil
	end

	-- Bobbing : mise à jour continue du C0 (amplitude ±0.3 stud, 1 cycle/s)
	local bobbingThread = task.spawn(function()
		local t = 0
		while motor and motor.Parent do
			t = t + task.wait(0.03)
			local bob = math.sin(t * math.pi * 2 * CARRY_CONFIG.bobbingVitesse)
				* CARRY_CONFIG.bobbingAmplitude
			pcall(function()
				motor.C0 = CFrame.new(0, yOffset + bob, 0) * CFrame.Angles(0, rotY, 0)
			end)
		end
	end)

	return {
		modele        = modele,
		racine        = racine,
		motor         = motor,
		bobbingThread = bobbingThread,
		yOffset       = yOffset,
		rotY          = rotY,
	}
end

-- Détache le modèle (arrête le bobbing, supprime le Motor6D).
-- Ne détruit PAS le modèle.
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

-- ============================================================
-- Drop au sol (mort du joueur)
-- ============================================================

-- Repose un BR détaché au sol près de positionMort.
-- N'importe quel joueur peut le ramasser pendant dureeDropSecondes.
local function dropBrainRot(entree, positionMort)
	local modele = entree.modele
	if not modele or not modele.Parent then return end

	local parts = obtenirBaseParts(modele)

	-- Position aléatoire dans le rayon de dispersion
	local angle   = math.random() * math.pi * 2
	local rayon   = math.random() * CARRY_CONFIG.rayonDrop
	local posDrop = positionMort + Vector3.new(
		math.cos(angle) * rayon,
		0.5,
		math.sin(angle) * rayon
	)

	-- Replacer le modèle au sol
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

	-- Collecte libre — premier joueur à toucher remporte le BR
	local collected = false

	local function tenterRamassage(player)
		if collected then return end
		local data = donneesJoueurs[player.UserId]
		if not data then return end

		local max = CARRY_CONFIG.niveaux[data.niveauCarry] or 1
		if #data.portes >= max then
			notifierJoueur(player, "INFO", "Sac plein ! Dépose tes Brain Rots à la base")
			return
		end

		collected = true

		local slotIndex    = #data.portes + 1
		local nouvelleEntree = attacherModele(player, modele, slotIndex)
		if not nouvelleEntree then
			-- Attachement échoué, laisser le BR au sol pour réessai
			collected = false
			return
		end

		nouvelleEntree.rarete = entree.rarete
		table.insert(data.portes, nouvelleEntree)
		envoyerCarryUpdate(player)
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

	-- Expiration après dureeDropSecondes
	task.delay(CARRY_CONFIG.dureeDropSecondes, function()
		if collected or not modele or not modele.Parent then return end
		collected = true
		local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad)
		for _, part in ipairs(parts) do
			if part and part.Parent then
				pcall(function()
					TweenService:Create(part, tweenInfo, { Transparency = 1 }):Play()
				end)
			end
		end
		task.delay(0.6, function()
			if modele and modele.Parent then modele:Destroy() end
		end)
	end)
end

-- ============================================================
-- Gestion mort
-- ============================================================

local function onMort(player)
	local data = donneesJoueurs[player.UserId]
	if not data or #data.portes == 0 then return end

	-- Game Pass Protection → conserver les BR au respawn
	if data.hasProtection then return end

	local hrp    = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local posMort = hrp and hrp.Position or Vector3.new(0, 5, 0)

	notifierTous("💀 " .. player.Name .. " a lâché ses Brain Rots !")

	-- Détacher puis dropper chaque BR
	local portesADrop = data.portes
	data.portes = {}

	for _, entree in ipairs(portesADrop) do
		detacherModele(entree)
		dropBrainRot(entree, posMort)
	end

	envoyerCarryUpdate(player)
end

local function configurerMort(player, char)
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	humanoid.Died:Connect(function()
		onMort(player)
	end)
end

-- ============================================================
-- Initialisation / nettoyage par joueur
-- ============================================================

local function initJoueur(player)
	donneesJoueurs[player.UserId] = {
		portes        = {},
		niveauCarry   = 0,
		hasProtection = false,
	}

	-- Respawn → reconfigurer la détection de mort
	player.CharacterAdded:Connect(function(char)
		local data = donneesJoueurs[player.UserId]
		if not data then return end

		task.wait(0.5)  -- laisser le personnage se charger

		-- Game Pass Protection → re-attacher les BR après respawn
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
		end

		configurerMort(player, char)
	end)

	-- Personnage déjà présent au moment de l'init
	if player.Character then
		task.spawn(function()
			configurerMort(player, player.Character)
		end)
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
	end
	donneesJoueurs[player.UserId] = nil
end

-- ============================================================
-- API publique
-- ============================================================

-- Retourne la liste des entrées portées par le joueur
function CarrySystem.GetPortes(player)
	local data = donneesJoueurs[player.UserId]
	return data and data.portes or {}
end

-- Retourne la capacité max du joueur selon son niveau
function CarrySystem.GetCapaciteMax(player)
	local data = donneesJoueurs[player.UserId]
	if not data then return 1 end
	return CARRY_CONFIG.niveaux[data.niveauCarry] or 1
end

-- Retourne le prix du prochain upgrade de carry
function CarrySystem.GetPrixUpgrade(player)
	local data = donneesJoueurs[player.UserId]
	if not data then return nil end
	local niveauSuivant = data.niveauCarry + 1
	return CARRY_CONFIG.prixUpgrade[niveauSuivant]
end

-- Upgrade le niveau de carry du joueur (appelé depuis ShopSystem)
-- Retourne (bool succès, string message)
function CarrySystem.UpgraderCarry(player)
	local data = donneesJoueurs[player.UserId]
	if not data then return false, "Joueur introuvable" end

	local niveauActuel  = data.niveauCarry
	local niveauSuivant = niveauActuel + 1

	if not CARRY_CONFIG.niveaux[niveauSuivant] then
		return false, "Niveau maximum atteint"
	end
	if niveauSuivant == 3 and not data.hasProtection then
		return false, "VIP requis pour le niveau 3"
	end

	data.niveauCarry = niveauSuivant
	envoyerCarryUpdate(player)
	return true, "Carry niveau " .. niveauSuivant .. " débloqué"
end

-- Vide le carry du joueur (appelé depuis DropSystem au dépôt base).
-- Retourne la liste { modele, rarete } des BR déposés.
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
	return deposes
end

-- Active/désactive le Game Pass Protection pour un joueur
function CarrySystem.SetProtection(player, valeur)
	local data = donneesJoueurs[player.UserId]
	if data then data.hasProtection = valeur == true end
end

-- Déclenché par BrainRotSpawner.OnCollecte(player, baseIndex, rarete).
-- Clône un modèle depuis ServerStorage, l'attache au-dessus de la tête.
-- rarete = { nom, poids, dossier }
function CarrySystem.RamasserBR(player, rarete)
	local data = donneesJoueurs[player.UserId]
	if not data then return false end

	local max = CARRY_CONFIG.niveaux[data.niveauCarry] or 1
	if #data.portes >= max then
		notifierJoueur(player, "INFO", "Sac plein ! Dépose tes Brain Rots à la base")
		return false
	end

	-- Choisir un modèle dans le dossier de la rareté
	local nomDossier   = rarete and rarete.dossier or "COMMON"
	local modeleSource = choisirModele(nomDossier)
	if not modeleSource then return false end

	local clone
	local ok = pcall(function() clone = modeleSource:Clone() end)
	if not ok or not clone then return false end

	local slotIndex = #data.portes + 1
	local entree    = attacherModele(player, clone, slotIndex)
	if not entree then return false end

	entree.rarete = rarete
	table.insert(data.portes, entree)

	jouerSon(player)
	envoyerCarryUpdate(player)
	return true
end

-- ============================================================
-- Init (appelé par Main.server.lua)
-- ============================================================
function CarrySystem.Init()
	-- Dossier des modèles
	BRAINROTS_FOLDER = ServerStorage:WaitForChild("Brainrots")

	-- Créer le RemoteEvent CarryUpdate
	local existing = ReplicatedStorage:FindFirstChild("CarryUpdate")
	if existing then
		CarryUpdate = existing
	else
		CarryUpdate        = Instance.new("RemoteEvent")
		CarryUpdate.Name   = "CarryUpdate"
		CarryUpdate.Parent = ReplicatedStorage
	end

	-- Initialiser les joueurs déjà connectés
	for _, player in ipairs(Players:GetPlayers()) do
		initJoueur(player)
	end
	Players.PlayerAdded:Connect(initJoueur)
	Players.PlayerRemoving:Connect(nettoyerJoueur)

	print("[CarrySystem] ✓ Initialisé")
end

return CarrySystem
