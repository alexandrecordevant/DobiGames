-- ServerScriptService/BrainrotPlatformSpawner.server.lua
-- Spawn automatique de Brainrots sur les plateformes des tours Tour & TourCommune

-- ════════════════════════════════════════════════════════════════
-- ⚙️  CONFIGURATION — Adapter ces valeurs à votre projet
-- ════════════════════════════════════════════════════════════════

-- ┌──────────────────────────────────────────────────────────────┐
-- │  1.  TOURS — détection par préfixe de nom                   │
-- │                                                              │
-- │  Tous les modèles de Workspace dont le nom COMMENCE par      │
-- │  TOWER_NAME_PREFIX sont considérés comme des tours valides.  │
-- │                                                              │
-- │  Exemples couverts : Tour1, Tour2, TourCommune, TourVIP …   │
-- │                                                              │
-- │  ── Pour passer plus tard à un système player-specific ──   │
-- │  Remplacer scannerTours() par une fonction qui retourne       │
-- │  la liste des tours assignées à un joueur donné.             │
-- └──────────────────────────────────────────────────────────────┘

-- Préfixe de détection — tout modèle workspace dont le nom commence par ça
-- ⚠️ À ADAPTER si vos tours ont un autre préfixe (ex: "Tower", "Etage", "Floor")
local TOWER_NAME_PREFIX = "Tour"

-- Nom du dossier contenant les plateformes DANS chaque modèle de tour
-- ⚠️ À REMPLACER par le nom exact de votre dossier (ex: "Plateformes", "Floors", "Platforms")
local NOM_DOSSIER_PLATEFORMES = "Plateformes"

-- ┌──────────────────────────────────────────────────────────────┐
-- │  2.  SOURCE DES BRAINROTS                                    │
-- │                                                              │
-- │  Structure attendue dans ReplicatedStorage :                 │
-- │    ReplicatedStorage                                         │
-- │    └─ Brainrots          ← DOSSIER_BRAINROTS_NOM            │
-- │       ├─ COMMON          ← un sous-dossier par rareté        │
-- │       ├─ RARE                                                │
-- │       ├─ EPIC                                                │
-- │       ├─ LEGENDARY                                           │
-- │       ├─ MYTHIC                                              │
-- │       ├─ GOD                                                 │
-- │       ├─ SECRET                                              │
-- │       └─ OG                                                  │
-- │                                                              │
-- │  ⚠️ Les noms des sous-dossiers sont configurables ci-dessous │
-- └──────────────────────────────────────────────────────────────┘
local DOSSIER_BRAINROTS_NOM = "Brainrots"  -- nom dans ReplicatedStorage

-- Noms EXACTS des sous-dossiers par rareté (clé = identifiant interne)
-- ⚠️ Modifier la valeur (droite) si vos dossiers ont des noms différents
local NOMS_DOSSIERS_RARETE = {
	COMMON    = "COMMON",
	RARE      = "RARE",
	EPIC      = "EPIC",
	LEGENDARY = "LEGENDARY",
	MYTHIC    = "MYTHIC",
	GOD       = "GOD",
	SECRET    = "SECRET",
	OG        = "OG",
}

-- ┌──────────────────────────────────────────────────────────────┐
-- │  3.  PARAMÈTRES DE SPAWN                                     │
-- └──────────────────────────────────────────────────────────────┘
local CONFIG = {
	INTERVALLE_CYCLE = 60,   -- secondes entre chaque évaluation de toutes les plateformes
	DUREE_VIE        = 60,   -- secondes avant auto-despawn du Brainrot
	CHANCE_SPAWN     = 0.5,  -- probabilité qu'une plateforme vide spawn (0.0 → 1.0)
	HAUTEUR_OFFSET   = 0,    -- studs au-dessus de la surface de la plateforme
}

-- ════════════════════════════════════════════════════════════════
-- 🎲  TABLE DE RÉPARTITION DES RARETÉS PAR HAUTEUR
--
--  ┌────────────┬──────────────────────────────────────────────┐
--  │ Hauteur Y  │ Raretés disponibles (poids relatifs)         │
--  ├────────────┼──────────────────────────────────────────────┤
--  │   0 – 250  │ COMMON 65 / RARE 25 / EPIC 10                │
--  │ 250 – 500  │ COMMON 40 / RARE 35 / EPIC 18 / LEGENDARY 7  │
--  │ 500 – 750  │ COMMON 15 / RARE 30 / EPIC 35 / LEG 18 / MYT 2│
--  │ 750 –1000  │ RARE 10 / EPIC 30 / LEG 32 / MYTHIC 24 / GOD 4│
--  │1000 –1250  │ EPIC 10 / LEG 28 / MYTHIC 32 / GOD 24 / SEC 6 │
--  │1250 –1500  │ LEG 8 / MYTHIC 22 / GOD 38 / SECRET 24 / OG 8 │
--  │1500 –1750  │ MYTHIC 5 / GOD 20 / SECRET 38 / OG 37         │
--  │1750 –2000  │ GOD 5 / SECRET 25 / OG 70                     │
--  └────────────┴──────────────────────────────────────────────┘
--
--  Les poids sont RELATIFS — inutile qu'ils somment à 100.
--  Pour ajuster la difficulté, modifiez librement les valeurs.
-- ════════════════════════════════════════════════════════════════

local RARITY_ZONES = {
	-- Zone 1 : Pied de tour (0 → 250) — COMMON dominant
	{ hauteurMin = 0,    poids = {
		COMMON = 65, RARE = 25, EPIC = 10,
	}},
	-- Zone 2 : Bas (250 → 500) — RARE monte, LEGENDARY pointe
	{ hauteurMin = 250,  poids = {
		COMMON = 40, RARE = 35, EPIC = 18, LEGENDARY = 7,
	}},
	-- Zone 3 : Quart bas (500 → 750) — EPIC prend de la place
	{ hauteurMin = 500,  poids = {
		COMMON = 15, RARE = 30, EPIC = 35, LEGENDARY = 18, MYTHIC = 2,
	}},
	-- Zone 4 : Mi-tour (750 → 1000) — EPIC/LEGENDARY dominent, MYTHIC s'installe
	{ hauteurMin = 750,  poids = {
		RARE = 10, EPIC = 30, LEGENDARY = 32, MYTHIC = 24, GOD = 4,
	}},
	-- Zone 5 : Mi-haut (1000 → 1250) — MYTHIC dominant, GOD/SECRET apparaissent
	{ hauteurMin = 1000, poids = {
		EPIC = 10, LEGENDARY = 28, MYTHIC = 32, GOD = 24, SECRET = 6,
	}},
	-- Zone 6 : Haut (1250 → 1500) — GOD dominant, OG pointe
	{ hauteurMin = 1250, poids = {
		LEGENDARY = 16, MYTHIC = 22, GOD = 38, SECRET = 24,
	}},
	-- Zone 7 : Très haut (1500 → 1750) — SECRET/OG prennent le dessus
	{ hauteurMin = 1500, poids = {
		MYTHIC = 20, GOD = 50, SECRET = 30,
	}},
	-- Zone 8 : Sommet (1750 → 2000) — OG exclusif, SECRET rare
	{ hauteurMin = 1750, poids = {
		GOD = 40, SECRET = 59, OG = 1,
	}},
}

-- ════════════════════════════════════════════════════════════════
-- INITIALISATION
-- ════════════════════════════════════════════════════════════════

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local brainrotsRoot = ReplicatedStorage:FindFirstChild(DOSSIER_BRAINROTS_NOM)
if not brainrotsRoot then
	warn("[PlatformSpawner] ❌ Dossier '" .. DOSSIER_BRAINROTS_NOM .. "' introuvable dans ReplicatedStorage !")
end

-- Construit la table { COMMON = Folder, RARE = Folder, ... }
local DOSSIERS_RARETE = {}
if brainrotsRoot then
	for cle, nomDossier in pairs(NOMS_DOSSIERS_RARETE) do
		local folder = brainrotsRoot:FindFirstChild(nomDossier)
		if folder then
			DOSSIERS_RARETE[cle] = folder
		else
			warn("[PlatformSpawner] ⚠️ Sous-dossier manquant : " .. nomDossier .. " (rareté " .. cle .. ")")
		end
	end
end

-- Dossier workspace.Brainrots — destination des clones
-- (BrainrotBillboard.server.lua écoutera DescendantAdded dessus)
local workspaceBrainrots = workspace:FindFirstChild("Brainrots")
if not workspaceBrainrots then
	warn("[PlatformSpawner] ⚠️ workspace.Brainrots introuvable — les clones seront parentés à workspace")
end

-- ════════════════════════════════════════════════════════════════
-- ÉTAT
-- platformState[basePart] = brainrotModel en cours | nil
-- ════════════════════════════════════════════════════════════════

local platformState = {}

-- ════════════════════════════════════════════════════════════════
-- UTILITAIRES — RARETÉ
-- ════════════════════════════════════════════════════════════════

-- Retourne la zone de rareté correspondant à une hauteur Y
local function getZone(y)
	local zone = RARITY_ZONES[1]
	for _, z in ipairs(RARITY_ZONES) do
		if y >= z.hauteurMin then zone = z end
	end
	return zone
end

-- Tirage pondéré dans un tableau { RARETÉ = poids }
local function tirerRarete(poids)
	local total = 0
	for _, p in pairs(poids) do total += p end
	local r = math.random() * total
	local cumul = 0
	for rarete, p in pairs(poids) do
		cumul += p
		if r <= cumul then return rarete end
	end
	-- Fallback (ne devrait pas arriver)
	return next(poids)
end

-- Choisit un modèle aléatoire dans le dossier de la rareté
local function choisirModele(rarete)
	local dossier = DOSSIERS_RARETE[rarete]
	if not dossier then
		warn("[PlatformSpawner] Dossier introuvable pour rareté : " .. tostring(rarete))
		return nil
	end
	local modeles = dossier:GetChildren()
	if #modeles == 0 then
		warn("[PlatformSpawner] Dossier vide pour rareté : " .. rarete)
		return nil
	end
	return modeles[math.random(1, #modeles)]
end

-- ════════════════════════════════════════════════════════════════
-- BILLBOARD TIMER
--
-- Ajoute une ligne rouge de countdown au BillboardGui "BrainrotInfo"
-- créé dynamiquement par BrainrotBillboard.server.lua.
-- Utilise un BillboardGui séparé "TimerGui" pour ne pas perturber
-- les 4 lignes existantes (Nom / Rareté / Prix / CPS).
-- ════════════════════════════════════════════════════════════════

local function ajouterTimerBillboard(brainrot, duree)
	-- Attendre que BrainrotBillboard ait eu le temps d'initialiser le BrainrotInfo
	task.wait(0.5)
	if not brainrot or not brainrot.Parent then return end

	-- Trouver la part d'attache
	local attache
	if brainrot:IsA("Model") then
		attache = brainrot.PrimaryPart or brainrot:FindFirstChildOfClass("BasePart")
	elseif brainrot:IsA("BasePart") then
		attache = brainrot
	end
	if not attache then
		warn("[PlatformSpawner] Pas de BasePart d'attache pour le timer : " .. brainrot.Name)
		return
	end

	-- Supprimer un éventuel timer précédent
	local old = attache:FindFirstChild("TimerGui")
	if old then old:Destroy() end

	-- BillboardGui dédié au timer — positionné juste sous le BrainrotInfo
	-- BrainrotInfo : StudsOffset (0,5,0), Size 2.5 studs → base à ≈3.75 studs
	-- TimerGui     : StudsOffset (0,3,0), Size 0.5 studs  → sommet à ≈3.25 studs
	local timerGui = Instance.new("BillboardGui")
	timerGui.Name         = "TimerGui"
	timerGui.Size         = UDim2.new(5, 0, 0.5, 0)    -- même largeur que BrainrotInfo
	timerGui.StudsOffset  = Vector3.new(0, 3, 0)        -- en dessous du BrainrotInfo
	timerGui.AlwaysOnTop  = false
	timerGui.ResetOnSpawn = false
	timerGui.Parent       = attache

	local timerLabel = Instance.new("TextLabel")
	timerLabel.Name                   = "SpawnTimer"
	timerLabel.Size                   = UDim2.new(1, 0, 1, 0)
	timerLabel.BackgroundTransparency = 1
	timerLabel.TextColor3             = Color3.fromRGB(220, 60, 60)
	timerLabel.TextScaled             = true
	timerLabel.Font                   = Enum.Font.GothamBold
	timerLabel.TextXAlignment         = Enum.TextXAlignment.Center
	timerLabel.TextStrokeTransparency = 0.5
	timerLabel.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
	timerLabel.Text                   = "⏱ " .. duree .. "s"
	timerLabel.Parent                 = timerGui

	-- Countdown (task.spawn = non bloquant)
	task.spawn(function()
		for t = duree, 1, -1 do
			if not timerLabel or not timerLabel.Parent then return end
			timerLabel.Text = "⏱ " .. t .. "s"
			task.wait(1)
		end
		-- Nettoyage propre du billboard timer
		if timerGui and timerGui.Parent then
			timerGui:Destroy()
		end
	end)
end

-- ════════════════════════════════════════════════════════════════
-- SPAWN D'UN BRAINROT SUR UNE PLATEFORME
-- ════════════════════════════════════════════════════════════════

local function spawnBrainrot(plateforme)
	-- 1. Déterminer la rareté selon la hauteur
	local hauteur = plateforme.Position.Y
	local zone    = getZone(hauteur)
	local rarete  = tirerRarete(zone.poids)

	-- 2. Récupérer un modèle source
	local modele = choisirModele(rarete)
	if not modele then return end

	-- 3. Cloner
	local clone = modele:Clone()

	-- 4. Positionner au-dessus du centre de la plateforme
	--    GetBoundingBox() fonctionne sur Model ; pour BasePart, utiliser Size
	local brainrotHauteur
	if clone:IsA("Model") then
		local _, sz = clone:GetBoundingBox()
		brainrotHauteur = sz.Y
	else
		brainrotHauteur = clone.Size.Y
	end

	local surfaceY    = plateforme.Position.Y + plateforme.Size.Y / 2
	local centreClone = Vector3.new(
		plateforme.Position.X,
		surfaceY + CONFIG.HAUTEUR_OFFSET + brainrotHauteur / 2,
		plateforme.Position.Z
	)
	clone:PivotTo(CFrame.new(centreClone))

	-- 5. Définir l'attribut Rarete si absent (requis par BrainrotBillboard)
	if not clone:GetAttribute("Rarete") then
		clone:SetAttribute("Rarete", rarete)
	end

	-- 6. Parenter dans workspace.Brainrots
	--    → BrainrotBillboard.server.lua crée le billboard automatiquement
	clone.Parent = workspaceBrainrots or workspace

	-- 7. Enregistrer l'état de la plateforme
	platformState[plateforme] = clone

	-- 8. Billboard timer (countdown rouge sous le BrainrotInfo)
	ajouterTimerBillboard(clone, CONFIG.DUREE_VIE)

	print(string.format("[PlatformSpawner] ✦ Spawn %s [%s] à Y=%.0f", clone.Name, rarete, hauteur))

	-- 9. Auto-despawn après DUREE_VIE secondes
	task.delay(CONFIG.DUREE_VIE, function()
		-- Vérifier que c'est toujours CE clone sur cette plateforme
		if platformState[plateforme] ~= clone then return end
		platformState[plateforme] = nil
		if clone and clone.Parent then
			clone:Destroy()
			print(string.format("[PlatformSpawner] Despawn %s [%s] Y=%.0f", modele.Name, rarete, hauteur))
		end
	end)
end

-- ════════════════════════════════════════════════════════════════
-- RÉCUPÉRATION DES PLATEFORMES
-- ════════════════════════════════════════════════════════════════

-- ════════════════════════════════════════════════════════════════
-- SCAN DES TOURS
--
-- Retourne la liste des modèles de tours valides dans Workspace.
-- "Valide" = nom commence par TOWER_NAME_PREFIX ET contient
-- le dossier NOM_DOSSIER_PLATEFORMES.
--
-- ── Point d'extension player-specific ──────────────────────────
-- Plus tard, remplacer cet appel dans getPlatefformes() par :
--   scannerTours(player)  → retourne uniquement la tour du joueur
-- ────────────────────────────────────────────────────────────────
local function scannerTours()
	local tours = {}
	for _, enfant in ipairs(workspace:GetChildren()) do
		-- Filtrer : doit être un Model dont le nom commence par le préfixe
		if not enfant:IsA("Model") then continue end
		if not enfant.Name:sub(1, #TOWER_NAME_PREFIX) == TOWER_NAME_PREFIX then continue end
		if enfant.Name:sub(1, #TOWER_NAME_PREFIX) ~= TOWER_NAME_PREFIX then continue end

		-- Doit contenir le dossier de plateformes
		if not enfant:FindFirstChild(NOM_DOSSIER_PLATEFORMES) then
			-- Pas un warn bloquant : certains modèles "Tour..." peuvent ne pas être des tours jouables
			continue
		end

		table.insert(tours, enfant)
	end
	return tours
end

local function getPlatefformes()
	local liste  = {}
	local tours  = scannerTours()

	if #tours == 0 then
		warn("[PlatformSpawner] Aucune tour détectée avec le préfixe '" .. TOWER_NAME_PREFIX .. "'")
		return liste
	end
	print("[PlatformSpawner] " .. #tours .. " tour(s) détectée(s) : " ..
		table.concat((function()
			local noms = {}
			for _, t in ipairs(tours) do table.insert(noms, t.Name) end
			return noms
		end)(), ", "))

	for _, tour in ipairs(tours) do
		local dossier = tour:FindFirstChild(NOM_DOSSIER_PLATEFORMES)
		if not dossier then continue end  -- déjà filtré par scannerTours, garde-fou

		-- GetDescendants pour gérer les sous-dossiers éventuels
		for _, enfant in ipairs(dossier:GetDescendants()) do
			if enfant:IsA("BasePart") then
				table.insert(liste, enfant)
			elseif enfant:IsA("Model") then
				-- Modèle de plateforme → PrimaryPart ou première BasePart trouvée
				local part = enfant.PrimaryPart or enfant:FindFirstChildOfClass("BasePart")
				if part then
					table.insert(liste, part)
				else
					warn("[PlatformSpawner] Modèle sans BasePart ignoré : " .. enfant:GetFullName())
				end
			end
		end
	end

	print("[PlatformSpawner] " .. #liste .. " plateforme(s) au total")
	return liste
end

-- ════════════════════════════════════════════════════════════════
-- ÉVALUATION D'UNE PLATEFORME (appelée chaque cycle)
-- ════════════════════════════════════════════════════════════════

local function evaluerPlateforme(plateforme)
	if not plateforme or not plateforme.Parent then return end

	local actuel = platformState[plateforme]

	-- Nettoyer si le Brainrot a été détruit manuellement (ramassé, exploité, etc.)
	if actuel and not actuel.Parent then
		platformState[plateforme] = nil
		actuel = nil
	end

	-- Plateforme déjà occupée → skip
	if actuel then return end

	-- Tirage de chance de spawn
	if math.random() > CONFIG.CHANCE_SPAWN then return end

	spawnBrainrot(plateforme)
end

-- ════════════════════════════════════════════════════════════════
-- BOUCLE PRINCIPALE
-- ════════════════════════════════════════════════════════════════

task.spawn(function()
	-- Attendre le chargement complet du jeu
	task.wait(3)

	-- Vérification critique
	if not brainrotsRoot then
		warn("[PlatformSpawner] ❌ Arrêt — dossier Brainrots manquant dans ReplicatedStorage.")
		return
	end
	if next(DOSSIERS_RARETE) == nil then
		warn("[PlatformSpawner] ❌ Arrêt — aucun dossier de rareté chargé. Vérifier NOMS_DOSSIERS_RARETE.")
		return
	end

	local plateformes = getPlatefformes()
	if #plateformes == 0 then
		warn("[PlatformSpawner] ❌ Arrêt — aucune plateforme. Vérifier NOMS_TOURS et NOM_DOSSIER_PLATEFORMES.")
		return
	end

	print(string.format("[PlatformSpawner] ✓ Démarré — %d plateforme(s) | cycle %ds | chance %.0f%%",
		#plateformes, CONFIG.INTERVALLE_CYCLE, CONFIG.CHANCE_SPAWN * 100))

	-- Premier cycle immédiat, puis toutes les INTERVALLE_CYCLE secondes
	while true do
		for _, plateforme in ipairs(plateformes) do
			evaluerPlateforme(plateforme)
		end
		task.wait(CONFIG.INTERVALLE_CYCLE)
	end
end)
