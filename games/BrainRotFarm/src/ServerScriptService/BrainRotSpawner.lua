-- ServerScriptService/BrainRotSpawner.lua
-- BrainRotFarm — Spawn champs individuels (COMMON → BRAINROT_GOD)
-- MYTHIC et SECRET réservés au ChampCommun (autre script)

local BrainRotSpawner = {}

-- ============================================================
-- Services
-- ============================================================
local TweenService   = game:GetService("TweenService")
local Players        = game:GetService("Players")
local ServerStorage  = game:GetService("ServerStorage")
local Workspace      = game:GetService("Workspace")

-- ============================================================
-- Configuration
-- ============================================================
local CONFIG = {
	INTERVALLE_SPAWN_DEFAUT = 4,   -- secondes entre deux spawns par base
	DUREE_FADE_OUT          = 0.3, -- durée du fade out collecte/despawn (s)
	DUREE_DESPAWN           = 30,  -- durée de vie d'un BR non collecté (s)
	MAX_PAR_BASE            = 15,  -- collectibles actifs max par base
	Y_OFFSET                = 2,   -- studs au-dessus de la moyenne Y des murs
	NETTOYAGE_ITERATIONS    = 15,  -- nettoyage de la liste toutes les N itérations
	-- Pousse de terre
	Y_DEPART_OFFSET         = -2,  -- studs sous la surface au départ
	DUREE_POUSSE            = 1.1, -- durée totale de l'animation (s)
	ETAPES_POUSSE           = 30,  -- nb d'étapes d'interpolation
}

-- ============================================================
-- Constantes — Raretés (champs individuels uniquement)
-- ============================================================
local RARITES = {
	{ nom = "COMMON",       poids = 5.0,   dossier = "COMMON"       },  -- DEBUG réduit
	{ nom = "OG",           poids = 2.0,   dossier = "OG"           },  -- DEBUG réduit
	{ nom = "RARE",         poids = 1.0,   dossier = "RARE"         },  -- DEBUG réduit
	{ nom = "EPIC",         poids = 70.0,  dossier = "EPIC"         },  -- DEBUG boosté
	{ nom = "LEGENDARY",    poids = 14.0,  dossier = "LEGENDARY"    },  -- DEBUG boosté
	{ nom = "BRAINROT_GOD", poids = 8.0,   dossier = "BRAINROT_GOD" },  -- DEBUG boosté
}
-- MYTHIC et SECRET exclus de ce script

-- Raretés collectées uniquement par ProximityPrompt (pas par Touched)
local RARITES_PROMPT = { EPIC = true, LEGENDARY = true, BRAINROT_GOD = true }

local POIDS_TOTAL = 0
for _, r in ipairs(RARITES) do
	POIDS_TOTAL = POIDS_TOTAL + r.poids
end

-- ============================================================
-- État interne
-- ============================================================
local zones           = {}  -- { [baseIndex] = { xMin, xMax, zMin, zMax, yFixe } }
local actifs          = {}  -- { [baseIndex] = { [id] = cloneModel } }
local compteurs       = {}  -- { [baseIndex] = nombreActifsActuels }
local intervalles     = {}  -- { [baseIndex] = intervalle en secondes }
local multiplicateurs = {}  -- { [baseIndex] = multiplicateur event }
local assignations    = {}  -- { [userId] = baseIndex }
local idCounter       = 0   -- compteur global pour nommer les clones

local brainrotsFolder = ServerStorage:WaitForChild("Brainrots")

-- ============================================================
-- Utilitaires internes
-- ============================================================

-- Tire une rareté selon les poids
local function tirerRarete()
	local r = math.random() * POIDS_TOTAL
	local cumul = 0
	for _, rarete in ipairs(RARITES) do
		cumul = cumul + rarete.poids
		if r <= cumul then
			return rarete
		end
	end
	return RARITES[1] -- fallback COMMON
end

-- Retourne un modèle aléatoire depuis le dossier de rareté
local function choisirModele(nomDossier)
	local dossier = brainrotsFolder:FindFirstChild(nomDossier)
	if not dossier then
		warn("[BrainRotSpawner] Dossier introuvable : " .. nomDossier)
		return nil
	end
	local modeles = dossier:GetChildren()
	if #modeles == 0 then
		warn("[BrainRotSpawner] Dossier vide : " .. nomDossier)
		return nil
	end
	return modeles[math.random(1, #modeles)]
end

-- Obtenir le PrimaryPart ou le premier BasePart trouvé
local function obtenirRacine(modele)
	if modele.PrimaryPart then
		return modele.PrimaryPart
	end
	for _, v in ipairs(modele:GetDescendants()) do
		if v:IsA("BasePart") then
			return v
		end
	end
	return nil
end

-- Récupérer tous les BaseParts d'un modèle
local function obtenirBaseParts(modele)
	local parts = {}
	for _, v in ipairs(modele:GetDescendants()) do
		if v:IsA("BasePart") then
			table.insert(parts, v)
		end
	end
	if modele:IsA("BasePart") then
		table.insert(parts, modele)
	end
	return parts
end

-- Appliquer un Tween de transparence à tous les BaseParts
local function tweenTransparence(parts, cible, duree, extraProps)
	local info = TweenInfo.new(duree, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, part in ipairs(parts) do
		local props = { Transparency = cible }
		if extraProps then
			for k, v in pairs(extraProps) do
				props[k] = v
			end
		end
		TweenService:Create(part, info, props):Play()
	end
end

-- Ajouter le BillboardGui sur la racine du modèle
local function ajouterBillboard(racine, nomRarete, nomModele)
	local billboard = Instance.new("BillboardGui")
	billboard.Name        = "BR_Label"
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.Size        = UDim2.new(0, 140, 0, 35)
	billboard.AlwaysOnTop = false
	billboard.Adornee     = racine
	billboard.Parent      = racine

	local label = Instance.new("TextLabel")
	label.Size                   = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text                   = "⭐ " .. nomRarete .. " · " .. nomModele
	label.Font                   = Enum.Font.GothamBold
	label.TextColor3             = Color3.new(1, 1, 1)
	label.TextScaled             = true

	local stroke = Instance.new("UIStroke")
	stroke.Color     = Color3.new(0, 0, 0)
	stroke.Thickness = 1.5
	stroke.Parent    = label

	label.Parent = billboard
end

-- Nettoyer les entrées nil dans la liste des actifs d'une base
local function nettoyerActifs(baseIndex)
	local nouveaux = {}
	local compte   = 0
	for id, modele in pairs(actifs[baseIndex]) do
		if modele and modele.Parent then
			nouveaux[id] = modele
			compte = compte + 1
		end
	end
	actifs[baseIndex]    = nouveaux
	compteurs[baseIndex] = compte
end

-- ============================================================
-- Initialisation des zones de spawn depuis les murs de SpawnZone
-- ============================================================

local function initialiserZones()
	local basesFolder = Workspace:FindFirstChild("Bases")
	if not basesFolder then
		warn("[BrainRotSpawner] Workspace.Bases introuvable !")
		return
	end

	for _, baseModel in ipairs(basesFolder:GetChildren()) do
		-- Extraire l'index numérique depuis le nom (ex: "Base_1" → 1)
		local indexStr = baseModel.Name:match("Base_(%d+)")
		if not indexStr then continue end
		local baseIndex = tonumber(indexStr)

		local spawnZone = baseModel:FindFirstChild("SpawnZone")
		if not spawnZone then
			warn("[BrainRotSpawner] SpawnZone manquante pour " .. baseModel.Name)
			continue
		end

		local wallTop    = spawnZone:FindFirstChild("Wall_Top")
		local wallBottom = spawnZone:FindFirstChild("Wall_Bottom")
		local wallLeft   = spawnZone:FindFirstChild("Wall_Left")
		local wallRight  = spawnZone:FindFirstChild("Wall_Right")

		if not (wallTop and wallBottom and wallLeft and wallRight) then
			warn("[BrainRotSpawner] Murs manquants dans SpawnZone de " .. baseModel.Name)
			continue
		end

		-- Calculer les bornes depuis les 4 murs
		local posTop    = wallTop.Position
		local posBottom = wallBottom.Position
		local posLeft   = wallLeft.Position
		local posRight  = wallRight.Position

		local xMin = math.min(posLeft.X, posRight.X, posTop.X, posBottom.X)
		local xMax = math.max(posLeft.X, posRight.X, posTop.X, posBottom.X)
		local zMin = math.min(posTop.Z, posBottom.Z, posLeft.Z, posRight.Z)
		local zMax = math.max(posTop.Z, posBottom.Z, posLeft.Z, posRight.Z)

		local yMoyenne = (posTop.Y + posBottom.Y + posLeft.Y + posRight.Y) / 4
		local yFixe    = yMoyenne + CONFIG.Y_OFFSET

		zones[baseIndex]             = { xMin = xMin, xMax = xMax, zMin = zMin, zMax = zMax, yFixe = yFixe }
		actifs[baseIndex]            = {}
		compteurs[baseIndex]         = 0
		intervalles[baseIndex]       = CONFIG.INTERVALLE_SPAWN_DEFAUT
		multiplicateurs[baseIndex]   = 1

		print(string.format("[BrainRotSpawner] Zone %s initialisée → X[%.1f, %.1f] Z[%.1f, %.1f] Y=%.1f",
			baseModel.Name, xMin, xMax, zMin, zMax, yFixe))
	end
end

-- ============================================================
-- Logique de collecte — Touch detection
-- ============================================================

local function configurerCollecte(clone, baseIndex, rarete, id, parts)
	local collected = false

	local function onTouched(hit)
		if collected then return end

		-- Identifier le personnage et le joueur
		local character = hit.Parent
		local player    = Players:GetPlayerFromCharacter(character)
		if not player then
			-- Essayer un niveau au-dessus (accessoires, outils, etc.)
			character = hit.Parent and hit.Parent.Parent
			player    = character and Players:GetPlayerFromCharacter(character)
		end
		if not player then return end

		-- Vérifier que ce joueur est bien assigné à CETTE base
		if assignations[player.UserId] ~= baseIndex then return end

		-- Marquer comme collecté (anti-doublon)
		collected = true
		actifs[baseIndex][id]    = nil
		compteurs[baseIndex]     = math.max(0, compteurs[baseIndex] - 1)

		-- Fade out + Size × 1.2
		local info = TweenInfo.new(CONFIG.DUREE_FADE_OUT, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		for _, part in ipairs(parts) do
			if part and part.Parent then
				TweenService:Create(part, info, {
					Transparency = 1,
					Size         = part.Size * 1.2,
				}):Play()
			end
		end

		-- Destroy après le fade out
		task.delay(CONFIG.DUREE_FADE_OUT + 0.1, function()
			if clone and clone.Parent then clone:Destroy() end
		end)

		-- Callback global de collecte
		if BrainRotSpawner.OnCollecte then
			pcall(BrainRotSpawner.OnCollecte, player, baseIndex, rarete.nom)
		end
	end

	-- Connecter Touched sur tous les BaseParts
	for _, part in ipairs(parts) do
		part.Touched:Connect(onTouched)
	end

	-- Retourne une fonction pour forcer la collecte (utilisée par le despawn)
	return function()
		collected = true
	end
end

-- ============================================================
-- Spawn d'un seul Brain Rot dans une base
-- ============================================================

local function spawnerUnBrainRot(baseIndex)
	local zone = zones[baseIndex]
	if not zone then return end

	-- Limite max par base
	if compteurs[baseIndex] >= CONFIG.MAX_PAR_BASE then return end

	-- Tirage de rareté
	local rarete = tirerRarete()

	-- Choix du modèle
	local modeleSource = choisirModele(rarete.dossier)
	if not modeleSource then return end

	-- Clonage
	local clone
	local ok, err = pcall(function()
		clone = modeleSource:Clone()
	end)
	if not ok or not clone then
		warn("[BrainRotSpawner] Erreur clonage : " .. tostring(err))
		return
	end

	-- Nommage unique
	idCounter  = idCounter + 1
	local id   = idCounter
	clone.Name = string.format("BR_%d_%d", baseIndex, id)

	-- Position aléatoire dans la SpawnZone
	local x = math.random() * (zone.xMax - zone.xMin) + zone.xMin
	local z = math.random() * (zone.zMax - zone.zMin) + zone.zMin

	-- Placer dans le Workspace avant de manipuler le CFrame
	clone.Parent = Workspace

	local racine = obtenirRacine(clone)
	if not racine then
		clone:Destroy()
		warn("[BrainRotSpawner] Modèle sans BasePart : " .. modeleSource.Name)
		return
	end

	-- Récupérer tous les BaseParts
	local parts = obtenirBaseParts(clone)

	-- CanCollide = false permanent (collecte via Touched uniquement)
	for _, part in ipairs(parts) do
		part.CanCollide = false
	end

	-- Enregistrer dans la liste des actifs
	actifs[baseIndex][id]    = clone
	compteurs[baseIndex]     = compteurs[baseIndex] + 1

	-- Configurer la collecte par Touch (COMMON/OG/RARE uniquement)
	-- EPIC+ utilisent un ProximityPrompt via OnBRSpawned → CarrySystem
	local forceCollected
	if RARITES_PROMPT[rarete.nom] then
		-- Mode prompt : pas de Touched, juste un flag pour le despawn
		local _c = false
		forceCollected = function() _c = true end
	else
		forceCollected = configurerCollecte(clone, baseIndex, rarete, id, parts)
	end

	-- ══ ANIMATION "POUSSE DE TERRE" ══
	-- Partir d'une taille microscopique, 2 studs sous la surface
	local yDepart = zone.yFixe + CONFIG.Y_DEPART_OFFSET
	pcall(function()
		if clone:IsA("Model") then
			clone:ScaleTo(0.01)
			clone:PivotTo(CFrame.new(x, yDepart, z))
		else
			racine.Size  = racine.Size * 0.01
			racine.CFrame = CFrame.new(x, yDepart, z)
		end
	end)

	task.spawn(function()
		local duree  = CONFIG.DUREE_POUSSE
		local etapes = CONFIG.ETAPES_POUSSE
		for i = 1, etapes do
			if not clone or not clone.Parent then return end
			local t     = i / etapes
			-- Easing cubique : démarre vite, ralentit en fin
			local scale = 1 - math.pow(1 - t, 3)
			local yPos  = yDepart + scale * math.abs(CONFIG.Y_DEPART_OFFSET)
			pcall(function()
				if clone:IsA("Model") then
					clone:ScaleTo(math.max(scale, 0.001))
					clone:PivotTo(CFrame.new(x, yPos, z))
				else
					racine.CFrame = CFrame.new(x, yPos, z)
				end
			end)
			task.wait(duree / etapes)
		end
		-- Snap final à la position et taille exactes
		pcall(function()
			if clone and clone.Parent then
				if clone:IsA("Model") then
					clone:ScaleTo(1)
					clone:PivotTo(CFrame.new(x, zone.yFixe, z))
				else
					racine.CFrame = CFrame.new(x, zone.yFixe, z)
				end
			end
		end)

		-- Billboard affiché uniquement après que le BR soit sorti de terre
		if clone and clone.Parent then
			pcall(ajouterBillboard, racine, rarete.nom, modeleSource.Name)
		end

		-- Hook CarrySystem pour ProximityPrompt (EPIC+)
		print("[BrainRotSpawner][DEBUG] OnBRSpawned hook ?", BrainRotSpawner.OnBRSpawned ~= nil, "| rareté:", rarete.nom)
		if clone and clone.Parent and BrainRotSpawner.OnBRSpawned then
			pcall(BrainRotSpawner.OnBRSpawned, clone, baseIndex, rarete)
		end
	end)

	-- Despawn automatique après 30 secondes
	task.delay(CONFIG.DUREE_DESPAWN, function()
		if not clone or not clone.Parent then return end
		if actifs[baseIndex][id] == nil then return end -- déjà collecté

		forceCollected()
		actifs[baseIndex][id] = nil
		compteurs[baseIndex]  = math.max(0, compteurs[baseIndex] - 1)

		tweenTransparence(parts, 1, CONFIG.DUREE_FADE_OUT)
		task.delay(CONFIG.DUREE_FADE_OUT + 0.1, function()
			if clone and clone.Parent then clone:Destroy() end
		end)
	end)
end

-- ============================================================
-- Boucle de spawn par base (task.spawn indépendant)
-- ============================================================

local function lancerBoucleSpawn(baseIndex)
	task.spawn(function()
		local iteration = 0

		while true do
			local mult       = multiplicateurs[baseIndex] or 1
			local intervalle = (intervalles[baseIndex] or CONFIG.INTERVALLE_SPAWN_DEFAUT) / math.max(1, mult)

			task.wait(intervalle)

			-- Nettoyage périodique des entrées obsolètes
			iteration = iteration + 1
			if iteration % CONFIG.NETTOYAGE_ITERATIONS == 0 then
				nettoyerActifs(baseIndex)
			end

			-- Spawn si la zone existe encore
			if zones[baseIndex] then
				pcall(spawnerUnBrainRot, baseIndex)
			else
				break -- zone supprimée, arrêter la boucle
			end
		end
	end)
end

-- ============================================================
-- Démarrage — lancer toutes les boucles après l'init
-- ============================================================

local function demarrer()
	initialiserZones()

	for baseIndex in pairs(zones) do
		lancerBoucleSpawn(baseIndex)
		print("[BrainRotSpawner] Boucle lancée pour Base_" .. baseIndex)
	end
end

-- ============================================================
-- API publique
-- ============================================================

-- Multiplicateur d'event global
BrainRotSpawner.EventMultiplier = 1

-- Définir le multiplicateur (baseIndex = nil → toutes les bases)
function BrainRotSpawner.SetEventMultiplier(mult, baseIndex)
	mult = math.max(1, mult or 1)
	if baseIndex then
		multiplicateurs[baseIndex] = mult
	else
		BrainRotSpawner.EventMultiplier = mult
		for idx in pairs(zones) do
			multiplicateurs[idx] = mult
		end
	end
end

-- Assigner un joueur à la première base libre
function BrainRotSpawner.AssignerBase(player)
	if assignations[player.UserId] then
		return assignations[player.UserId]
	end

	local basesOccupees = {}
	for _, baseIdx in pairs(assignations) do
		basesOccupees[baseIdx] = true
	end

	for baseIndex in pairs(zones) do
		if not basesOccupees[baseIndex] then
			assignations[player.UserId] = baseIndex
			print(string.format("[BrainRotSpawner] %s → Base_%d", player.Name, baseIndex))
			return baseIndex
		end
	end

	warn("[BrainRotSpawner] Toutes les bases sont occupées pour " .. player.Name)
	return nil
end

-- Libérer la base d'un joueur (à la déconnexion)
function BrainRotSpawner.LibererBase(player)
	if assignations[player.UserId] then
		local baseIndex = assignations[player.UserId]
		assignations[player.UserId] = nil
		print(string.format("[BrainRotSpawner] Base_%d libérée (%s)", baseIndex, player.Name))
	end
end

-- Obtenir l'index de la base d'un joueur
function BrainRotSpawner.GetBase(player)
	return assignations[player.UserId]
end

-- Callback collecte — à assigner depuis Main.server.lua :
-- BrainRotSpawner.OnCollecte = function(player, baseIndex, rarete) end
BrainRotSpawner.OnCollecte  = nil
BrainRotSpawner.OnBRSpawned = nil  -- hook CarrySystem (ProximityPrompt EPIC+)

-- Libération automatique à la déconnexion
Players.PlayerRemoving:Connect(function(player)
	BrainRotSpawner.LibererBase(player)
end)

-- ============================================================
-- Init (appelé par Main.server.lua)
-- ============================================================
function BrainRotSpawner.Init()
	demarrer()
end

return BrainRotSpawner
