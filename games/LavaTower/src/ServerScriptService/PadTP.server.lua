-- PadTP.server.lua
-- Téléportation vers la tour personnelle du joueur (Tour_1, Tour_2, …)
-- Chaque base est scannée automatiquement : seul le joueur propriétaire de la base peut entrer.
-- La lave démarre 5 secondes après l'entrée, avec accélération progressive (indépendante par tour).

local Players             = game:GetService("Players")
local RunService          = game:GetService("RunService")
local CollectionService   = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local Workspace           = game:GetService("Workspace")
local Logger              = require(ServerScriptService.SharedLib.Server.Logger)

local AssignationSystem = require(ServerScriptService.SharedLib.Server.AssignationSystem)

-- ============================================================
-- RemoteEvents pour le bouton "Escape the Tower"
-- ============================================================
local function getOrCreateRemote(name)
	local existing = ReplicatedStorage:FindFirstChild(name)
	if existing then return existing end
	local re = Instance.new("RemoteEvent")
	re.Name   = name
	re.Parent = ReplicatedStorage
	return re
end

local TowerEntered = getOrCreateRemote("TowerEntered")
local TowerExited  = getOrCreateRemote("TowerExited")
local EscapeTower  = getOrCreateRemote("EscapeTower")

-- ============================================================
-- CONFIGURATION LAVE (tours personnelles)
-- ============================================================
local LAVA_CONFIG = {
	DELAI            = 5,    -- secondes après le TP avant que la lave démarre
	VITESSE_BASE     = 5,    -- studs/seconde (vitesse initiale)
	ACCELERATION     = 2.0,  -- studs/s ajoutés par palier
	INTERVALLE_ACCEL = 8,    -- secondes entre chaque palier d'accélération
	HAUTEUR_MAX      = 2000, -- hauteur Y de reset de la lave
}

-- ============================================================
-- Map baseIndex → resetLava()
-- Permet à EscapeTower et PlayerRemoving de stopper la lave
-- de la bonne tour sans avoir à chercher la référence.
-- ============================================================
local lavaResetByBase = {}

-- ============================================================
-- Cooldown escape (anti-spam bouton)
-- ============================================================
local derniersEscape = {}

EscapeTower.OnServerEvent:Connect(function(player)
	local baseIndex = AssignationSystem.GetBaseIndex(player)
	if not baseIndex then return end

	local now = os.clock()
	if now - (derniersEscape[player.UserId] or 0) < 1 then return end
	derniersEscape[player.UserId] = now

	-- Stopper la lave AVANT de téléporter le joueur dehors
	if lavaResetByBase[baseIndex] then
		lavaResetByBase[baseIndex]()
	end

	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local spawnCFrame = AssignationSystem.GetSpawnCFrame(baseIndex)
	if spawnCFrame then
		hrp.CFrame = spawnCFrame
		player:SetAttribute("InTower", false)
		TowerExited:FireClient(player)
		Logger.debug("Pad", "%s escape tower button (Base_%d)", player.Name, baseIndex)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	derniersEscape[player.UserId] = nil

	-- Reset la lave si le joueur se déconnecte en cours de partie dans sa tour
	local baseIndex = AssignationSystem.GetBaseIndex(player)
	if baseIndex and lavaResetByBase[baseIndex] then
		lavaResetByBase[baseIndex]()
	end
end)

-- ============================================================
-- CONFIGURATION TP
-- ============================================================
local NOM_TRIGGERS   = "Triggers"
local NOM_START_ZONE = "StartZone"
local NOM_SPAWN      = "InterriorSpawn"
local NOM_LAVA       = "Lava"
local TP_COOLDOWN    = 1

-- ============================================================
-- Utilitaire : est-ce une tour personnelle ?
-- Tour personnelle = "Tour_" suivi de chiffres  (Tour_1, Tour_2…)
-- Exclut : TourCommune, TourVIP, etc.
-- ============================================================
local function estTourPersonnelle(nom)
	return nom:match("^Tour_%d+$") ~= nil
end

-- ============================================================
-- Setup du pad de TP ET de la lave d'une tour personnelle.
-- baseIndex = index de la Base_X qui contient cette tour.
-- Chaque appel crée une closure totalement indépendante :
-- lavaActive, lavaOwner, etc. ne sont pas partagés entre tours.
-- ============================================================
local function setupTour(tour, baseIndex)
	-- ── Vérifications des composants obligatoires ──────────────────
	local triggers = tour:FindFirstChild(NOM_TRIGGERS)
	if not triggers then
		Logger.warn("Pad", "'%s' manquant dans %s", NOM_TRIGGERS, tour.Name)
		return
	end

	local startZone = triggers:FindFirstChild(NOM_START_ZONE)
	if not startZone then
		Logger.warn("Pad", "'%s' manquant dans %s.%s", NOM_START_ZONE, tour.Name, NOM_TRIGGERS)
		return
	end

	local interiorSpawn = tour:FindFirstChild(NOM_SPAWN)
	if not interiorSpawn then
		Logger.warn("Pad", "'%s' manquant dans %s", NOM_SPAWN, tour.Name)
		return
	end

	local lava = tour:FindFirstChild(NOM_LAVA)
	if not lava then
		Logger.warn("Pad", "'Lava' manquant dans %s — lave désactivée pour cette tour", tour.Name)
	end

	-- Hauteurs d'arrêt : bas des parties taggées "Stop" dans la tour
	local stopHeights = {}
	if lava then
		for _, desc in ipairs(tour:GetDescendants()) do
			if desc:IsA("BasePart") and CollectionService:HasTag(desc, "Stop") then
				local bottomY = desc.Position.Y - desc.Size.Y / 2
				table.insert(stopHeights, bottomY)
			end
		end
		table.sort(stopHeights)
	end

	-- ── État lave (closure isolée par tour) ───────────────────────
	local lavaActive    = false
	local lavaArretee   = false
	local laveConnexion = nil
	local lavaVitesse   = LAVA_CONFIG.VITESSE_BASE
	local hauteurDepart = lava and lava.Position.Y or 0
	local lavaOwner     = nil -- joueur propriétaire actuellement dans cette tour

	local function resetLava()
		lavaActive  = false
		lavaArretee = false
		lavaOwner   = nil
		if laveConnexion then
			laveConnexion:Disconnect()
			laveConnexion = nil
		end
		lavaVitesse = LAVA_CONFIG.VITESSE_BASE
		if lava then
			lava.Anchored = true
			lava.Position = Vector3.new(lava.Position.X, hauteurDepart, lava.Position.Z)
		end
		Logger.debug("Pad", "%s Lave reset (Base_%d)", tour.Name, baseIndex)
	end

	-- Enregistrer ce reset dans la map globale
	lavaResetByBase[baseIndex] = resetLava

	local function demarrerLava()
		if not lava then return end
		if lavaActive then return end
		lavaActive  = true
		lavaVitesse = LAVA_CONFIG.VITESSE_BASE

		Logger.info("Pad", "%s Lave démarrée (Base_%d)", tour.Name, baseIndex)

		local tempsAccel   = 0
		local dernierTemps = os.clock()
		local tempsVerif   = 0

		laveConnexion = RunService.Heartbeat:Connect(function()
			if not lavaActive then return end

			local now   = os.clock()
			local delta = now - dernierTemps
			dernierTemps = now

			-- Vérifier arrêt sur tag Stop (10 studs à l'intérieur de la partie)
			if not lavaArretee and #stopHeights > 0 then
				local lavaTopY = lava.Position.Y + lava.Size.Y / 2
				for _, stopY in ipairs(stopHeights) do
					if lavaTopY >= stopY + 24 then
						lavaArretee = true
						lava.Position = Vector3.new(lava.Position.X, (stopY + 24) - lava.Size.Y / 2, lava.Position.Z)
						Logger.info("Pad", "%s Lave stoppée (tag Stop Y=%.0f, Base_%d)", tour.Name, stopY, baseIndex)
						break
					end
				end
			end
			if lavaArretee then return end

			-- Monter la lave
			lava.Anchored = true
			lava.Position = lava.Position + Vector3.new(0, lavaVitesse * delta, 0)

			-- Accélération progressive
			tempsAccel += delta
			if tempsAccel >= LAVA_CONFIG.INTERVALLE_ACCEL then
				tempsAccel  = 0
				lavaVitesse += LAVA_CONFIG.ACCELERATION
			end

			-- Vérifier toutes les 2s si le propriétaire est encore vivant dans la tour.
			-- On vérifie UNIQUEMENT lavaOwner (pas tous les joueurs) pour éviter
			-- toute interférence entre tours personnelles différentes.
			tempsVerif += delta
			if tempsVerif >= 2 then
				tempsVerif = 0
				local vivant = false
				local owner  = lavaOwner
				-- owner.Parent == Players tant que le joueur est connecté
				if owner and owner.Parent then
					local char = owner.Character
					if char then
						local h   = char:FindFirstChildOfClass("Humanoid")
						local hrp = char:FindFirstChild("HumanoidRootPart")
						if h and h.Health > 0 and hrp and hrp.Position.Y > hauteurDepart + 5 then
							vivant = true
						end
					end
				end
				if not vivant then
					Logger.debug("Pad", "%s Propriétaire absent/mort → Reset lave (Base_%d)", tour.Name, baseIndex)
					resetLava()
				end
			end

			-- Reset si hauteur max atteinte
			if lava.Position.Y >= LAVA_CONFIG.HAUTEUR_MAX then
				Logger.debug("Pad", "%s Hauteur max → Reset lave (Base_%d)", tour.Name, baseIndex)
				resetLava()
			end
		end)
	end

	-- ── Lave : toucher = mort ──────────────────────────────────────
	if lava then
		lava.Touched:Connect(function(hit)
			if not lavaActive then return end
			local char   = hit.Parent
			local player = Players:GetPlayerFromCharacter(char)
			if not player then return end
			local hum = char:FindFirstChildOfClass("Humanoid")
			if not hum or hum.Health <= 0 then return end
			Logger.info("Pad", "%s %s éliminé par la lave (Base_%d)", tour.Name, player.Name, baseIndex)
			hum.Health = 0
		end)
	end

	-- ── Pad de téléportation ───────────────────────────────────────
	local derniersTP = {}

	startZone.Touched:Connect(function(hit)
		local character = hit.Parent
		local player    = Players:GetPlayerFromCharacter(character)
		if not player then return end

		-- Vérification ownership : uniquement le joueur assigné à cette base
		if AssignationSystem.GetBaseIndex(player) ~= baseIndex then return end

		local hrp = character:FindFirstChild("HumanoidRootPart")
		if not hrp then return end

		local now = os.clock()
		if now - (derniersTP[player.UserId] or 0) < TP_COOLDOWN then return end
		derniersTP[player.UserId] = now

		-- Téléportation
		hrp.CFrame = interiorSpawn.CFrame + Vector3.new(0, 3, 0)
		player:SetAttribute("InTower", true)
		TowerEntered:FireClient(player)
		Logger.debug("Pad", "%s → %s (Base_%d)", player.Name, tour.Name, baseIndex)

		-- Programmer le démarrage de la lave (si la tour en a une)
		if lava then
			-- Si la lave était encore active (re-entrée rapide), on repart de zéro
			if lavaActive then
				resetLava()
			end
			lavaOwner = player

			local entryTimestamp = now
			task.delay(LAVA_CONFIG.DELAI, function()
				-- Vérifier que c'est toujours CE joueur et qu'il est bien dans la tour
				-- (garde contre les re-entrées multiples ou une sortie avant le délai)
				if lavaOwner == player
					and player.Parent  -- joueur encore connecté
					and player:GetAttribute("InTower")
				then
					demarrerLava()
				end
			end)
		end
	end)

	Logger.info("Pad", "✓ %s configurée (Base_%d)%s",
		tour.Name, baseIndex, lava and " + lave" or " (sans lave)")
end

-- ============================================================
-- Scanner le dossier Specific d'une base et écouter les ajouts
-- ============================================================
local function scannerSpecific(specific, baseIndex)
	for _, enfant in ipairs(specific:GetChildren()) do
		if enfant:IsA("Model") and estTourPersonnelle(enfant.Name) then
			setupTour(enfant, baseIndex)
		end
	end

	specific.ChildAdded:Connect(function(enfant)
		if enfant:IsA("Model") and estTourPersonnelle(enfant.Name) then
			setupTour(enfant, baseIndex)
		end
	end)
end

-- ============================================================
-- Démarrage : scanner toutes les bases présentes + écouter les nouvelles
-- ============================================================
task.spawn(function()
	local bases = Workspace:WaitForChild("Bases", 10)
	if not bases then
		Logger.warn("Pad", "❌ Workspace.Bases introuvable")
		return
	end

	for _, base in ipairs(bases:GetChildren()) do
		local indexStr = base.Name:match("^Base_(%d+)$")
		if indexStr then
			local baseIndex = tonumber(indexStr)
			local specific  = base:FindFirstChild("Specific")
			if specific then
				scannerSpecific(specific, baseIndex)
			else
				Logger.warn("Pad", "Pas de dossier Specific dans %s", base.Name)
			end
		end
	end

	-- Bases ajoutées dynamiquement (runtime)
	bases.ChildAdded:Connect(function(base)
		local indexStr = base.Name:match("^Base_(%d+)$")
		if not indexStr then return end
		local baseIndex = tonumber(indexStr)
		local specific  = base:WaitForChild("Specific", 5)
		if specific then
			scannerSpecific(specific, baseIndex)
		end
	end)
end)
