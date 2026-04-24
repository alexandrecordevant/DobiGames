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
	CHANCE_SPAWN     = 3,   -- 1 chance sur N de faire spawn sur une plateforme libre
	HAUTEUR_OFFSET   = 0,   -- studs au-dessus de la surface de la plateforme
}

-- ════════════════════════════════════════════════════════════════
-- 🎰  MUTATIONS — chances appliquées à chaque spawn
--  Vérifiées du plus rare au plus commun (exclusivité mutuelle)
--   RAINBOW  : 1 / CHANCE_RAINBOW
--   DIAMANT  : 1 / CHANCE_DIAMANT  (si pas rainbow)
--   GOLD     : 1 / CHANCE_GOLD     (si pas diamond ni rainbow)
--   NORMAL   : sinon
-- ════════════════════════════════════════════════════════════════
local MUTATION_CONFIG = {
	CHANCE_RAINBOW  = 50,
	CHANCE_DIAMANT  = 20,
	CHANCE_GOLD     = 10,
}

-- Multiplicateurs de CashParSeconde par mutation (source de vérité côté spawner)
-- Ces valeurs doivent rester cohérentes avec Config.Fuse.MutationCPS dans GameConfigSpecific.
local MUTATION_MULT = {
	RAINBOW = 10,
	DIAMANT  = 3,
	GOLD     = 2,
}
local TOXIC_MULT = 5

-- Noms des sous-dossiers dans ReplicatedStorage.Mutation
local DOSSIER_MUTATION_NOM = "Mutation"
local NOMS_DOSSIERS_MUTATION = {
	GOLD    = "BrainrotsGold",
	DIAMANT = "BrainrotsDiamant",
	RAINBOW = "BrainrotsRainbow",
}

local NOM_DOSSIER_TOXIC      = "BrainrotsToxic"   -- dans ReplicatedStorage.Mutation
local CHANCE_TOXIC           = 10                  -- 1 chance sur N de spawn toxic
local INTERVALLE_TOXIC_SWAP  = 15                  -- secondes entre chaque passe de remplacement
local CHANCE_TOXIC_SWAP      = 10                  -- 1 chance sur N d'être remplacé à chaque passe

local NOM_DOSSIER_NEBULA     = "BrainrotsNebula"  -- dans ReplicatedStorage.Mutation
local NEBULA_MULT            = 5
local CHANCE_NEBULA          = 10
local INTERVALLE_NEBULA_SWAP = 15
local CHANCE_NEBULA_SWAP     = 10

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

local ReplicatedStorage    = game:GetService("ReplicatedStorage")
local CollectionService    = game:GetService("CollectionService")
local ServerStorage        = game:GetService("ServerStorage")
local Logger               = require(game:GetService("ServerScriptService").SharedLib.Server.Logger)
local BrainrotPositioner   = require(game:GetService("ServerScriptService").SharedLib.Server.BrainrotPositioner)
local RainbowEffect        = require(ReplicatedStorage.Modules.RainbowEffect)

local function isToxicActif()
	local flag = ServerStorage:FindFirstChild("ToxicEventActif")
	return flag ~= nil and flag.Value == true
end

local function isNebulaActif()
	local flag = ServerStorage:FindFirstChild("NebulaEventActif")
	return flag ~= nil and flag.Value == true
end

-- Cache des centres de tours (évite GetBoundingBox répété à chaque spawn)
local tourCentresCache = {}

-- Retourne le centre XZ (Vector3 Y=0) d'un modèle de tour
local function getTourCentre(tourModel)
	if not tourModel then return nil end
	local cached = tourCentresCache[tourModel]
	if cached then return cached end
	local ok, bbCF = pcall(function()
		local cf, _ = tourModel:GetBoundingBox()
		return cf
	end)
	local centre = (ok and bbCF) and Vector3.new(bbCF.Position.X, 0, bbCF.Position.Z) or nil
	tourCentresCache[tourModel] = centre
	return centre
end

local brainrotsRoot = ReplicatedStorage:FindFirstChild(DOSSIER_BRAINROTS_NOM)
if not brainrotsRoot then
	Logger.warn("Spawn", "❌ Dossier '%s' introuvable dans ReplicatedStorage !", DOSSIER_BRAINROTS_NOM)
end

-- Construit la table { COMMON = Folder, RARE = Folder, ... } pour un dossier racine donné
local function construireDossiersRarete(racine)
	local dossiers = {}
	if not racine then return dossiers end
	for cle, nomDossier in pairs(NOMS_DOSSIERS_RARETE) do
		local folder = racine:FindFirstChild(nomDossier)
		if folder then
			dossiers[cle] = folder
		else
			Logger.warn("Spawn", "⚠️ Sous-dossier manquant : %s/%s (rareté %s)", racine.Name, nomDossier, cle)
		end
	end
	return dossiers
end

-- Dossiers de rareté pour les brainrots normaux
local DOSSIERS_RARETE = construireDossiersRarete(brainrotsRoot)

-- Dossiers de rareté pour les mutations
local mutationRoot = ReplicatedStorage:FindFirstChild(DOSSIER_MUTATION_NOM)
if not mutationRoot then
	Logger.warn("Spawn", "⚠️ Dossier '%s' introuvable dans ReplicatedStorage — mutations désactivées.", DOSSIER_MUTATION_NOM)
end

-- DOSSIERS_MUTATION[type] = { COMMON = Folder, RARE = Folder, ... }
local DOSSIERS_MUTATION = {}
if mutationRoot then
	for typeMutation, nomDossier in pairs(NOMS_DOSSIERS_MUTATION) do
		local racine = mutationRoot:FindFirstChild(nomDossier)
		if racine then
			DOSSIERS_MUTATION[typeMutation] = construireDossiersRarete(racine)
		else
			Logger.warn("Spawn", "⚠️ Dossier mutation manquant : Mutation/%s", nomDossier)
		end
	end
end

-- Dossiers rareté pour les brainrots toxiques
local DOSSIERS_TOXIC = {}
if mutationRoot then
	local toxicRoot = mutationRoot:FindFirstChild(NOM_DOSSIER_TOXIC)
	if toxicRoot then
		DOSSIERS_TOXIC = construireDossiersRarete(toxicRoot)
		Logger.info("Spawn", "ToxicBrainrots chargé ✓ (%d raretés)", (function()
			local n = 0; for _ in pairs(DOSSIERS_TOXIC) do n += 1 end; return n
		end)())
	else
		Logger.warn("Spawn", "⚠️ Mutation/%s introuvable — spawn toxic désactivé.", NOM_DOSSIER_TOXIC)
	end
end

-- Dossiers rareté pour les brainrots nebula
local DOSSIERS_NEBULA = {}
if mutationRoot then
	local nebulaRoot = mutationRoot:FindFirstChild(NOM_DOSSIER_NEBULA)
	if nebulaRoot then
		DOSSIERS_NEBULA = construireDossiersRarete(nebulaRoot)
		Logger.info("Spawn", "NebulaBrainrots chargé ✓ (%d raretés)", (function()
			local n = 0; for _ in pairs(DOSSIERS_NEBULA) do n += 1 end; return n
		end)())
	else
		Logger.warn("Spawn", "⚠️ Mutation/%s introuvable — spawn nebula désactivé.", NOM_DOSSIER_NEBULA)
	end
end

-- Tire le type de mutation à appliquer ("RAINBOW", "DIAMANT", "GOLD", ou nil = normal)
local function tirerMutation()
	if math.random(MUTATION_CONFIG.CHANCE_RAINBOW) == 1 then return "RAINBOW" end
	if math.random(MUTATION_CONFIG.CHANCE_DIAMANT) == 1 then return "DIAMANT" end
	if math.random(MUTATION_CONFIG.CHANCE_GOLD)    == 1 then return "GOLD"    end
	return nil
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

-- Choisit une rareté ET un modèle dans le set de dossiers fourni, en ne considérant
-- que les dossiers non vides. Évite le cas où tirerRarete() sélectionne une rareté
-- sans modèles disponibles.
local function choisirRareteEtModele(zone, dossiersRarete)
	-- Construire un sous-tableau de poids limité aux raretés avec des modèles
	local poisdsValides = {}
	for rarete, poids in pairs(zone.poids) do
		local dossier = dossiersRarete[rarete]
		if dossier and #dossier:GetChildren() > 0 then
			poisdsValides[rarete] = poids
		end
	end

	if not next(poisdsValides) then
		Logger.warn("Spawn", "Aucun modèle disponible pour cette zone (hauteur %d+)", zone.hauteurMin)
		return nil, nil
	end

	local rarete  = tirerRarete(poisdsValides)
	local modeles = dossiersRarete[rarete]:GetChildren()
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

local function spawnBrainrot(plateforme, forceLifetime, forceToxic)
	-- 1. Hauteur et zone de rareté
	local hauteur = plateforme.Position.Y
	local zone    = getZone(hauteur)

	-- 2. Sélectionner la source : toxic/nebula (1/10 pendant l'event) ou normal+mutations
	local dossiersActifs = DOSSIERS_RARETE
	local mutation = nil
	local isToxic  = forceToxic or false
	local isNebula = false

	if not isToxic and isToxicActif() and next(DOSSIERS_TOXIC) ~= nil
		and math.random(CHANCE_TOXIC) == 1 then
		dossiersActifs = DOSSIERS_TOXIC
		isToxic        = true
	end

	if not isToxic and not isNebula and isNebulaActif() and next(DOSSIERS_NEBULA) ~= nil
		and math.random(CHANCE_NEBULA) == 1 then
		dossiersActifs = DOSSIERS_NEBULA
		isNebula       = true
	end

	if not isToxic and not isNebula then
		mutation = tirerMutation()
		if mutation and DOSSIERS_MUTATION[mutation] and next(DOSSIERS_MUTATION[mutation]) then
			dossiersActifs = DOSSIERS_MUTATION[mutation]
		elseif mutation then
			Logger.warn("Spawn", "Mutation %s sans dossiers valides — spawn normal.", mutation)
			mutation = nil
		end
	end

	-- 3. Modèle et rareté
	local modele, rarete = choisirRareteEtModele(zone, dossiersActifs)
	if not modele then return nil end

	-- 4. Clone
	local clone = modele:Clone()

	-- 5. Position sur la plateforme
	local surfaceY    = plateforme.Position.Y + plateforme.Size.Y / 2
	local platDossier = plateforme.Parent
	local tourModel   = platDossier and platDossier.Parent
	local towerCentre = (tourModel and tourModel:IsA("Model")) and getTourCentre(tourModel) or nil

	-- 6. Attributs — définis AVANT clone.Parent = workspace pour que le watcher
	-- DescendantAdded voie la bonne valeur Mutation dès le premier frame.
	-- Sans ça, le watcher lit l'attribut template du modèle (souvent "RAINBOW")
	-- et applique l'effet rainbow à des mutations GOLD/DIAMANT/TOXIC par erreur.
	local lifetime = forceLifetime or math.random(CONFIG.DUREE_VIE_MIN, CONFIG.DUREE_VIE_MAX)
	clone:SetAttribute("Rarete",          rarete)
	clone:SetAttribute("LifeTime",        lifetime)
	clone:SetAttribute("OriginalName",    modele.Name)
	clone:SetAttribute("SpawnTimestamp",  os.time())
	if isToxic   then clone:SetAttribute("IsToxic",  true)    end
	if isNebula  then clone:SetAttribute("IsNebula", true)    end
	if mutation  then clone:SetAttribute("Mutation", mutation) end
	local prixSrc = modele:GetAttribute("Prix")
	local cpsSrc  = modele:GetAttribute("CashParSeconde")
	if prixSrc then clone:SetAttribute("Prix",           prixSrc) end
	if cpsSrc  then clone:SetAttribute("CashParSeconde", cpsSrc)  end

	clone.Parent = workspace
	BrainrotPositioner.positionnerSurSurface(
		clone, surfaceY,
		plateforme.Position.X, plateforme.Position.Z,
		towerCentre, CONFIG.HAUTEUR_OFFSET
	)

	-- 7. Multiplicateur CPS — appliqué sur l'attribut AVANT le tag CollectionService
	-- → BrainrotBillboard.SetupField lit directement la valeur multipliée
	local cpsBase = clone:GetAttribute("CashParSeconde") or 0
	local mult = (mutation and MUTATION_MULT[mutation]) or (isToxic and TOXIC_MULT) or (isNebula and NEBULA_MULT) or 1
	if mult > 1 and cpsBase > 0 then
		clone:SetAttribute("CashParSeconde", math.floor(cpsBase * mult))
	end

	-- 8. Tag → BrainrotService
	CollectionService:AddTag(clone, TAG_COLLECTIBLE)

	-- 9. Effet arc-en-ciel (mutation RAINBOW uniquement)
	if mutation == "RAINBOW" then
		RainbowEffect.Apply(clone)
	end

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
	local function scanner(conteneur)
		for _, enfant in ipairs(conteneur:GetChildren()) do
			if not enfant:IsA("Model") then continue end
			if enfant.Name:sub(1, #TOWER_NAME_PREFIX) ~= TOWER_NAME_PREFIX then continue end
			if not enfant:FindFirstChild(NOM_DOSSIER_PLATEFORMES) then continue end
			table.insert(tours, enfant)
		end
	end

	-- Tours personnelles dans Bases/Base_X/Specific
	local bases = workspace:FindFirstChild("Bases")
	if bases then
		for _, base in ipairs(bases:GetChildren()) do
			local specific = base:FindFirstChild("Specific")
			if specific then scanner(specific) end
		end
	end

	-- Tours communes directement dans workspace (TourCommune, TourVIP…)
	scanner(workspace)

	return tours
end

local function getPlatefformes()
	local liste  = {}
	local tours  = scannerTours()

	if #tours == 0 then
		Logger.warn("Spawn", "Aucune tour détectée avec le préfixe '%s'", TOWER_NAME_PREFIX)
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
					Logger.warn("Spawn", "Modèle sans BasePart ignoré : %s", enfant:GetFullName())
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
		Logger.warn("Spawn", "❌ Arrêt — dossier Brainrots manquant dans ReplicatedStorage.")
		return
	end
	if next(DOSSIERS_RARETE) == nil then
		Logger.warn("Spawn", "❌ Arrêt — aucun dossier de rareté chargé. Vérifier NOMS_DOSSIERS_RARETE.")
		return
	end

	local plateformes = getPlatefformes()
	if #plateformes == 0 then
		Logger.warn("Spawn", "❌ Arrêt — aucune plateforme. Vérifier TOWER_NAME_PREFIX et NOM_DOSSIER_PLATEFORMES.")
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

-- ════════════════════════════════════════════════════════════════
-- REMPLACEMENT TOXIC — toutes les INTERVALLE_TOXIC_SWAP secondes
-- Pendant l'event : les brainrots normaux ont une chance d'être
-- remplacés par leur version toxique en conservant le timer restant.
-- ════════════════════════════════════════════════════════════════
task.spawn(function()
	task.wait(5)  -- laisser le spawner principal démarrer

	while true do
		task.wait(INTERVALLE_TOXIC_SWAP)

		if not isToxicActif() then continue end
		if not next(DOSSIERS_TOXIC) then continue end

		for plateforme, clone in pairs(platformState) do
			if not clone or not clone:IsDescendantOf(workspace) then continue end
			-- Ne pas remplacer les brainrots déjà spéciaux
			if clone:GetAttribute("IsToxic") or clone:GetAttribute("IsNebula") then continue end
			if math.random(CHANCE_TOXIC_SWAP) ~= 1 then continue end

			local rarete      = clone:GetAttribute("Rarete")
			local nomOriginal = clone:GetAttribute("OriginalName")
			if not rarete or not nomOriginal then continue end

			local dossierToxic = DOSSIERS_TOXIC[rarete]
			if not dossierToxic then continue end
			local modele = dossierToxic:FindFirstChild(nomOriginal)
			if not modele then continue end

			local spawnTime = clone:GetAttribute("SpawnTimestamp") or os.time()
			local lifeTime  = clone:GetAttribute("LifeTime") or CONFIG.DUREE_VIE_MIN
			local remaining = lifeTime - (os.time() - spawnTime)
			if remaining <= 3 then continue end

			clone:Destroy()

			local newClone    = modele:Clone()
			local surfaceY    = plateforme.Position.Y + plateforme.Size.Y / 2
			local platDossier = plateforme.Parent
			local tourModel   = platDossier and platDossier.Parent
			local towerCentre = (tourModel and tourModel:IsA("Model")) and getTourCentre(tourModel) or nil

			newClone.Parent = workspace
			BrainrotPositioner.positionnerSurSurface(
				newClone, surfaceY,
				plateforme.Position.X, plateforme.Position.Z,
				towerCentre, CONFIG.HAUTEUR_OFFSET
			)

			newClone:SetAttribute("Rarete",         rarete)
			newClone:SetAttribute("LifeTime",        math.max(1, math.floor(remaining)))
			newClone:SetAttribute("OriginalName",    nomOriginal)
			newClone:SetAttribute("IsToxic",         true)
			newClone:SetAttribute("SpawnTimestamp",  os.time())
			local prixSrc = modele:GetAttribute("Prix")
			local cpsSrc  = modele:GetAttribute("CashParSeconde")
			if prixSrc then newClone:SetAttribute("Prix",           prixSrc) end
			if cpsSrc  then newClone:SetAttribute("CashParSeconde", cpsSrc)  end

			platformState[plateforme] = newClone
			newClone.AncestryChanged:Connect(function()
				if not newClone:IsDescendantOf(workspace) then
					if platformState[plateforme] == newClone then
						platformState[plateforme] = nil
					end
				end
			end)
			local toxCpsBase = newClone:GetAttribute("CashParSeconde") or 0
			if toxCpsBase > 0 then
				newClone:SetAttribute("CashParSeconde", math.floor(toxCpsBase * TOXIC_MULT))
			end
			CollectionService:AddTag(newClone, TAG_COLLECTIBLE)

			Logger.debug("Spawn", "Brainrot '%s' (%s) → version toxic (%.0fs restantes)",
				nomOriginal, rarete, remaining)
		end
	end
end)

-- ════════════════════════════════════════════════════════════════
-- REMPLACEMENT NEBULA — toutes les INTERVALLE_NEBULA_SWAP secondes
-- ════════════════════════════════════════════════════════════════
task.spawn(function()
	task.wait(6)

	while true do
		task.wait(INTERVALLE_NEBULA_SWAP)

		if not isNebulaActif() then continue end
		if not next(DOSSIERS_NEBULA) then continue end

		for plateforme, clone in pairs(platformState) do
			if not clone or not clone:IsDescendantOf(workspace) then continue end
			if clone:GetAttribute("IsNebula") or clone:GetAttribute("IsToxic") then continue end
			if math.random(CHANCE_NEBULA_SWAP) ~= 1 then continue end

			local rarete      = clone:GetAttribute("Rarete")
			local nomOriginal = clone:GetAttribute("OriginalName")
			if not rarete or not nomOriginal then continue end

			local dossierNebula = DOSSIERS_NEBULA[rarete]
			if not dossierNebula then continue end
			local modele = dossierNebula:FindFirstChild(nomOriginal)
			if not modele then continue end

			local spawnTime = clone:GetAttribute("SpawnTimestamp") or os.time()
			local lifeTime  = clone:GetAttribute("LifeTime") or CONFIG.DUREE_VIE_MIN
			local remaining = lifeTime - (os.time() - spawnTime)
			if remaining <= 3 then continue end

			clone:Destroy()

			local newClone    = modele:Clone()
			local surfaceY    = plateforme.Position.Y + plateforme.Size.Y / 2
			local platDossier = plateforme.Parent
			local tourModel   = platDossier and platDossier.Parent
			local towerCentre = (tourModel and tourModel:IsA("Model")) and getTourCentre(tourModel) or nil

			newClone.Parent = workspace
			BrainrotPositioner.positionnerSurSurface(
				newClone, surfaceY,
				plateforme.Position.X, plateforme.Position.Z,
				towerCentre, CONFIG.HAUTEUR_OFFSET
			)

			newClone:SetAttribute("Rarete",        rarete)
			newClone:SetAttribute("LifeTime",       math.max(1, math.floor(remaining)))
			newClone:SetAttribute("OriginalName",   nomOriginal)
			newClone:SetAttribute("IsNebula",       true)
			newClone:SetAttribute("SpawnTimestamp", os.time())
			local prixSrc = modele:GetAttribute("Prix")
			local cpsSrc  = modele:GetAttribute("CashParSeconde")
			if prixSrc then newClone:SetAttribute("Prix",           prixSrc) end
			if cpsSrc  then newClone:SetAttribute("CashParSeconde", cpsSrc)  end

			platformState[plateforme] = newClone
			newClone.AncestryChanged:Connect(function()
				if not newClone:IsDescendantOf(workspace) then
					if platformState[plateforme] == newClone then
						platformState[plateforme] = nil
					end
				end
			end)
			local nebCpsBase = newClone:GetAttribute("CashParSeconde") or 0
			if nebCpsBase > 0 then
				newClone:SetAttribute("CashParSeconde", math.floor(nebCpsBase * NEBULA_MULT))
			end
			CollectionService:AddTag(newClone, TAG_COLLECTIBLE)

			Logger.debug("Spawn", "Brainrot '%s' (%s) → version nebula (%.0fs restantes)",
				nomOriginal, rarete, remaining)
		end
	end
end)
