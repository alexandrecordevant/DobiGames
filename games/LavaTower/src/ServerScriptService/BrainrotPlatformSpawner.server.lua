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
	DUREE_VIE_MIN    = 30,  -- durée de vie minimale d'un Brainrot (secondes)
	DUREE_VIE_MAX    = 90,  -- durée de vie maximale d'un Brainrot (secondes)
	INTERVALLE_CYCLE = 15,  -- secondes entre chaque passe de spawn
	CHANCE_SPAWN     = 5,   -- 1 chance sur N de faire spawn sur une plateforme libre
	HAUTEUR_OFFSET   = 0,   -- studs au-dessus de la surface de la plateforme
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
local CollectionService = game:GetService("CollectionService")

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
local workspaceBrainrots = workspace:FindFirstChild("Brainrots")
if not workspaceBrainrots then
	warn("[PlatformSpawner] ⚠️ workspace.Brainrots introuvable — les clones seront parentés à workspace")
end

-- ════════════════════════════════════════════════════════════════
-- ÉTAT
-- platformState[basePart] = clone actif dans le monde | nil
-- Lecture seule depuis l'extérieur ; écrit uniquement par runPlatformCycle.
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
	return next(poids)
end

-- Choisit une rareté ET un modèle en ne considérant que les dossiers non vides.
-- Évite le cas où tirerRarete() sélectionne une rareté sans modèles disponibles.
local function choisirRareteEtModele(zone)
	-- Construire un sous-tableau de poids limité aux raretés avec des modèles
	local poisdsValides = {}
	for rarete, poids in pairs(zone.poids) do
		local dossier = DOSSIERS_RARETE[rarete]
		if dossier and #dossier:GetChildren() > 0 then
			poisdsValides[rarete] = poids
		end
	end

	if not next(poisdsValides) then
		warn("[PlatformSpawner] Aucun modèle disponible pour cette zone (hauteur " .. zone.hauteurMin .. "+)")
		return nil, nil
	end

	local rarete  = tirerRarete(poisdsValides)
	local modeles = DOSSIERS_RARETE[rarete]:GetChildren()
	return modeles[math.random(1, #modeles)], rarete
end

-- ════════════════════════════════════════════════════════════════
-- TAG — clé partagée avec BrainrotService
-- BrainrotService écoute ce tag et gère billboard + pickup + Tool
-- ════════════════════════════════════════════════════════════════

local TAG_COLLECTIBLE = "BrainrotCollectible"

-- ════════════════════════════════════════════════════════════════
-- SPAWN D'UN BRAINROT SUR UNE PLATEFORME
--
-- ⚠️  SOURCE : toujours le template dans ReplicatedStorage.
--     Le clone actif dans workspace n'est JAMAIS utilisé comme source.
--     Cette fonction ne gère PAS le cycle de vie — c'est runPlatformCycle
--     qui en est responsable.
-- ════════════════════════════════════════════════════════════════

local function spawnBrainrot(plateforme)
	-- 1. Déterminer la rareté selon la hauteur et choisir un modèle disponible
	local hauteur        = plateforme.Position.Y
	local zone           = getZone(hauteur)
	local modele, rarete = choisirRareteEtModele(zone)
	if not modele then return nil end

	-- 3. Cloner depuis le template (jamais depuis un clone actif)
	local clone = modele:Clone()

	-- 4. Positionner le clone sur la surface de la plateforme
	local bbCF, bbSize  = clone:GetBoundingBox()
	local pivotCF       = clone:GetPivot()
	local pivotToBottom = (bbCF.Position.Y - bbSize.Y / 2) - pivotCF.Position.Y
	local surfaceY      = plateforme.Position.Y + plateforme.Size.Y / 2
	local targetPivotY  = surfaceY - pivotToBottom + CONFIG.HAUTEUR_OFFSET
	clone:PivotTo(CFrame.new(
		plateforme.Position.X, targetPivotY, plateforme.Position.Z
	))

	-- 5. Attributs requis par BrainrotService (billboard + Tool)
	-- Durée de vie aléatoire : lisse les disparitions dans le temps
	local lifetime = math.random(CONFIG.DUREE_VIE_MIN, CONFIG.DUREE_VIE_MAX)
	clone:SetAttribute("Rarete",          rarete)
	clone:SetAttribute("LifeTime",        lifetime)
	clone:SetAttribute("OriginalName",    modele.Name)
	local prixSrc = modele:GetAttribute("Prix")
	local cpsSrc  = modele:GetAttribute("CashParSeconde")
	if prixSrc then clone:SetAttribute("Prix",           prixSrc) end
	if cpsSrc  then clone:SetAttribute("CashParSeconde", cpsSrc)  end

	-- 6. Parenter dans workspace.Brainrots AVANT le tag
	clone.Parent = workspaceBrainrots or workspace

	-- 7. Tagguer → déclenche BrainrotService (billboard + pickup + countdown)
	CollectionService:AddTag(clone, TAG_COLLECTIBLE)

	return clone
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
		if not enfant:IsA("Model") then continue end
		if enfant.Name:sub(1, #TOWER_NAME_PREFIX) ~= TOWER_NAME_PREFIX then continue end
		if not enfant:FindFirstChild(NOM_DOSSIER_PLATEFORMES) then continue end
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

	for _, tour in ipairs(tours) do
		local dossier = tour:FindFirstChild(NOM_DOSSIER_PLATEFORMES)
		if not dossier then continue end

		for _, enfant in ipairs(dossier:GetDescendants()) do
			if enfant:IsA("BasePart") then
				table.insert(liste, enfant)
			elseif enfant:IsA("Model") then
				local part = enfant.PrimaryPart or enfant:FindFirstChildOfClass("BasePart")
				if part then
					table.insert(liste, part)
				else
					warn("[PlatformSpawner] Modèle sans BasePart ignoré : " .. enfant:GetFullName())
				end
			end
		end
	end

	return liste
end

-- ════════════════════════════════════════════════════════════════
-- SPAWN SUR UNE PLATEFORME LIBRE
--
-- Crée le clone, enregistre l'état, et connecte AncestryChanged pour
-- libérer platformState dès que le clone quitte workspace (pickup ou timer).
-- Pas de boucle bloquante : toute la gestion d'état est réactive.
-- ════════════════════════════════════════════════════════════════

local function spawnSurPlateforme(plateforme)
	local clone = spawnBrainrot(plateforme)
	if not clone then return end

	platformState[plateforme] = clone

	-- Libère la plateforme dès que le clone disparaît du monde.
	-- Couvre : destruction par StartCountdown, pickup par un joueur, ou tout autre cas.
	clone.AncestryChanged:Connect(function()
		if not clone:IsDescendantOf(workspace) then
			if platformState[plateforme] == clone then
				platformState[plateforme] = nil
			end
		end
	end)
end

-- ════════════════════════════════════════════════════════════════
-- BOUCLE PRINCIPALE
--
-- Toutes les INTERVALLE_CYCLE secondes :
--   • parcourt toutes les plateformes
--   • pour chaque plateforme libre → 1 chance sur CHANCE_SPAWN de spawner
--
-- Avantages :
--   - pas de tâche parallèle par plateforme (léger)
--   - spawn progressif, tour jamais totalement vide ni totalement pleine
--   - une seule source de vérité pour l'état : platformState[]
-- ════════════════════════════════════════════════════════════════

task.spawn(function()
	task.wait(3)  -- laisser le jeu terminer son chargement

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
		warn("[PlatformSpawner] ❌ Arrêt — aucune plateforme. Vérifier TOWER_NAME_PREFIX et NOM_DOSSIER_PLATEFORMES.")
		return
	end

	while true do
		for _, plateforme in ipairs(plateformes) do
			-- Ignorer les plateformes supprimées (sécurité)
			if not plateforme.Parent then continue end

			-- Plateforme occupée par un clone encore vivant → skip
			local current = platformState[plateforme]
			if current and current:IsDescendantOf(workspace) then continue end

			-- L'état est éventuellement périmé (AncestryChanged pas encore tiré) → nettoyer
			platformState[plateforme] = nil

			-- 1 chance sur CHANCE_SPAWN de spawner sur cette plateforme libre
			if math.random(CONFIG.CHANCE_SPAWN) == 1 then
				spawnSurPlateforme(plateforme)
			end
		end

		task.wait(CONFIG.INTERVALLE_CYCLE)
	end
end)
