-- ServerScriptService/Common/SpawnManager.lua
-- BrainRotFarm — Spawn champs individuels (COMMON → BRAINROT_GOD)
-- MYTHIC et SECRET réservés à CommunSpawner (ZoneCommune)
-- Refactorisé depuis BrainRotSpawner.lua — config lue depuis GameConfig

local SpawnManager = {}

-- ============================================================
-- Services
-- ============================================================
local TweenService       = game:GetService("TweenService")
local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local ServerStorage      = game:GetService("ServerStorage")
local Workspace          = game:GetService("Workspace")
local MarketplaceService = game:GetService("MarketplaceService")

-- Chargement différé FilterManager (système de filtres centralisé)
local _FilterManager = nil
local function getFilterManager()
    if not _FilterManager then
        local ok, m = pcall(function()
            return require(game:GetService("ServerScriptService")
                :WaitForChild("SharedLib")
                :WaitForChild("BRFilterSystem")
                :WaitForChild("FilterManager"))
        end)
        if ok then _FilterManager = m end
    end
    return _FilterManager
end

-- ============================================================
-- Config — lue depuis GameConfig
-- ============================================================
local Logger            = require(game:GetService("ServerScriptService").SharedLib.Server.Logger)
local BrainrotBillboard = require(game:GetService("ServerScriptService").SharedLib.Server.BrainrotBillboard)
local _GameConfig       = require(game.ReplicatedStorage.GameConfig)
-- Valeurs animation depuis AnimationConfig (fallback si absent)
local _animCfg = _GameConfig.AnimationConfig or {}

-- SpawnConfig lu depuis GameConfig
local _spawnCfg = _GameConfig.SpawnConfig or {}

-- Probabilités roll bonus Tracteur — lues depuis GameConfig.TracteurConfig
local _tracteurCfg = _GameConfig.TracteurConfig or {}
local TRACTEUR_CONFIG = {
    MYTHIC_CHANCE  = _tracteurCfg.MYTHIC_CHANCE  or 4,
    SECRET_CHANCE  = _tracteurCfg.SECRET_CHANCE  or 1,
    JACKPOT_CHANCE = _tracteurCfg.JACKPOT_CHANCE or 1,
}

local CONFIG = {
	INTERVALLE_SPAWN_DEFAUT = _spawnCfg.intervalleSecondes or 4,
	DUREE_FADE_OUT          = 0.3,
	DUREE_DESPAWN           = _spawnCfg.despawnSecondes or 30,
	MAX_PAR_BASE            = _spawnCfg.maxParBase or 15,
	Y_OFFSET                = 2,
	NETTOYAGE_ITERATIONS    = 15,
	-- Pousse de terre — lus depuis GameConfig.AnimationConfig
	Y_DEPART_OFFSET         = _animCfg.brSpawnOffsetY or -3,
	DUREE_POUSSE            = _animCfg.brSpawnDuree    or 2.0,
	ETAPES_POUSSE           = 30,
}

-- ============================================================
-- Raretés — lues depuis GameConfig.SpawnableItems.rarites
-- ============================================================
local _spawnableItems = _GameConfig.SpawnableItems or {}
local _dosierBrainrots = _spawnableItems.dossier or "Brainrots"
local _spawnZoneNom = _GameConfig.SpawnZoneNom or "SpawnZone"

local RARITES = {}
if _spawnableItems.rarites then
    for _, r in ipairs(_spawnableItems.rarites) do
        table.insert(RARITES, {
            nom     = r.nom,
            poids   = r.poids,
            dossier = r.nom,  -- le dossier correspond au nom de la rareté
        })
    end
else
    -- Fallback si SpawnableItems non défini
    RARITES = {
        { nom = "COMMON",       poids = 55,  dossier = "COMMON"       },
        { nom = "OG",           poids = 22,  dossier = "OG"           },
        { nom = "RARE",         poids = 13,  dossier = "RARE"         },
        { nom = "EPIC",         poids = 7,   dossier = "EPIC"         },
        { nom = "LEGENDARY",    poids = 2.8, dossier = "LEGENDARY"    },
        { nom = "BRAINROT_GOD", poids = 0.2, dossier = "BRAINROT_GOD" },
    }
end
-- MYTHIC et SECRET exclus de ce script (ZoneCommune uniquement)

-- Ordre croissant des rarites (logique interne — non configurable)
local RARETE_ORDRE = {
    COMMON=1, OG=2, RARE=3, EPIC=4,
    LEGENDARY=5, MYTHIC=6, SECRET=7, BRAINROT_GOD=8,
}

local POIDS_TOTAL = 0
for _, r in ipairs(RARITES) do
	POIDS_TOTAL = POIDS_TOTAL + r.poids
end

-- Raretés exclues du spawn — lues depuis GameConfig
local _raretesExclues = _GameConfig.RaretesExcluesSpawn or {}
local function EstExclue(rarete)
    for _, nom in ipairs(_raretesExclues) do
        if nom == rarete.nom then return true end
    end
    return false
end

-- ============================================================
-- État interne
-- ============================================================
local zones            = {}  -- { [baseIndex] = { xMin, xMax, zMin, zMax, yFixe } }
local actifs           = {}  -- { [baseIndex] = { [id] = cloneModel } }
local compteurs        = {}  -- { [baseIndex] = nombreActifsActuels }
local intervalles      = {}  -- { [baseIndex] = intervalle en secondes }
local multiplicateurs  = {}  -- { [baseIndex] = multiplicateur event }
local arroseurMults    = {}  -- { [baseIndex] = multiplicateur upgrade Arroseur }
local assignations     = {}  -- { [userId] = baseIndex }
local idCounter        = 0   -- compteur global pour nommer les clones

-- Admin Abuse — pool et chances de mutation overridées pendant l'event
local _adminAbusePool          = nil  -- { { nom, poids, dossier }, ... }
local _adminAbusePoidsTot      = 0
local _adminAbuseMutChance     = nil  -- remplace pfMutCfg.chance
local _adminAbuseElemChance    = nil  -- chance mutation GALAXY/VOID sur MYTHIC/SECRET/BRAINROT_GOD
local _adminAbuseElemRaretes   = nil  -- { MYTHIC=true, SECRET=true, BRAINROT_GOD=true }

-- Lazy loader FlowerPotSystem (évite dépendance circulaire)
local _FlowerPotSystem = nil
local function getFlowerPotSystem()
    if not _FlowerPotSystem then
        local ok, m = pcall(require,
            game:GetService("ServerScriptService").FlowerPotSystem)
        if ok then _FlowerPotSystem = m end
    end
    return _FlowerPotSystem
end

local brainrotsFolder = ReplicatedStorage:WaitForChild(_dosierBrainrots)

-- ============================================================
-- Utilitaires internes
-- ============================================================

-- Tire une rareté selon les poids (réessaie si la rareté est exclue)
-- hasLucky : si true, 25% de chance de reroll et garde la meilleure des deux
local function tirerRarete(hasLucky)
    local pool       = _adminAbusePool or RARITES
    local total      = _adminAbusePool and _adminAbusePoidsTot or POIDS_TOTAL
    local skipExclus = _adminAbusePool ~= nil  -- pool Admin Abuse = déjà curatée, pas besoin d'EstExclue

    local function unTirage()
        local tentatives = 0
        local rarete
        repeat
            local r     = math.random() * total
            local cumul = 0
            rarete      = pool[1]
            for _, candidat in ipairs(pool) do
                cumul = cumul + candidat.poids
                if r <= cumul then
                    rarete = candidat
                    break
                end
            end
            tentatives = tentatives + 1
        until (skipExclus or not EstExclue(rarete)) and (not hasLucky or rarete.nom ~= "COMMON") or tentatives > 20
        return rarete
    end

    local rarete = unTirage()
    if hasLucky and math.random() < 0.25 then
        local reroll = unTirage()
        if (RARETE_ORDRE[reroll.nom] or 0) > (RARETE_ORDRE[rarete.nom] or 0) then
            rarete = reroll
        end
    end
    return rarete
end

-- Retourne un modèle aléatoire depuis le dossier de rareté
local function choisirModele(nomDossier)
	local dossier = brainrotsFolder:FindFirstChild(nomDossier)
	if not dossier then
		Logger.warn("Spawn", "Dossier introuvable : %s", nomDossier)
		return nil
	end
	local modeles = dossier:GetChildren()
	if #modeles == 0 then
		Logger.warn("Spawn", "Dossier vide : %s", nomDossier)
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

-- Couleurs par type de mutation (pour PointLight + tag billboard)
local MUTATION_COLORS = {
    -- Mutations champ (dossiers ServerStorage/Mutation/)
    BrainrotsToxic   = Color3.fromRGB(0,   220,   0),
    BrainrotsLava    = Color3.fromRGB(255,  80,   0),
    BrainrotsGold    = Color3.fromRGB(255, 200,   0),
    BrainrotsDiamant = Color3.fromRGB(0,   220, 255),
    BrainrotsRainbow = Color3.fromRGB(255, 255, 255),
    BrainrotsNebula  = Color3.fromRGB(160,   0, 255),
    CrazyBrainrots   = Color3.fromRGB(255,   0, 200),
    -- Mutations élément Admin Abuse / FlowerPot (MutantTypes)
    GALAXY  = Color3.fromRGB(88,   24, 169),
    TOXIC   = Color3.fromRGB(57,  255,  20),
    RAINBOW = Color3.fromRGB(255, 255, 255),
    VOID    = Color3.fromRGB(200,   0,   0),
}

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

-- ─────────────────────────────────────────────────────────────
-- BILLBOARD — délégué à BrainrotBillboard (shared-lib)
-- ─────────────────────────────────────────────────────────────

-- Countdown mis à jour via BrainrotBillboard.UpdateTimer
local function lancerCountdownBillboard(clone, duree)
	task.spawn(function()
		for t = duree, 0, -1 do
			if not clone or not clone.Parent then return end
			BrainrotBillboard.UpdateTimer(clone, t)
			if t > 0 then task.wait(1) end
		end
	end)
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
		Logger.warn("Spawn", "Workspace.Bases introuvable !")
		return
	end

	for _, baseModel in ipairs(basesFolder:GetChildren()) do
		-- Extraire l'index numérique depuis le nom (ex: "Base_1" → 1)
		local indexStr = baseModel.Name:match("Base_(%d+)")
		if not indexStr then continue end
		local baseIndex = tonumber(indexStr)

		-- SpawnZone dans Specific/ (structure Shared/Specific)
		local specificFolderSM = baseModel:FindFirstChild("Specific")
		local spawnZone        = specificFolderSM and specificFolderSM:FindFirstChild(_spawnZoneNom)
		if not spawnZone then
			Logger.warn("Spawn", "SpawnZone manquante pour %s", baseModel.Name)
			continue
		end

		local wallTop    = spawnZone:FindFirstChild("Wall_Top")
		local wallBottom = spawnZone:FindFirstChild("Wall_Bottom")
		local wallLeft   = spawnZone:FindFirstChild("Wall_Left")
		local wallRight  = spawnZone:FindFirstChild("Wall_Right")

		if not (wallTop and wallBottom and wallLeft and wallRight) then
			Logger.warn("Spawn", "Murs manquants dans SpawnZone de %s", baseModel.Name)
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

		zones[baseIndex]           = { xMin = xMin, xMax = xMax, zMin = zMin, zMax = zMax, yFixe = yFixe }
		actifs[baseIndex]          = {}
		compteurs[baseIndex]       = 0
		intervalles[baseIndex]     = CONFIG.INTERVALLE_SPAWN_DEFAUT
		multiplicateurs[baseIndex] = 1

		Logger.debug("Spawn", "Zone %s initialisée → X[%.1f, %.1f] Z[%.1f, %.1f] Y=%.1f", baseModel.Name, xMin, xMax, zMin, zMax, yFixe)
	end
end

-- ============================================================
-- Spawn d'un seul Brain Rot dans une base
-- ============================================================

-- rareteForce   : { nom, dossier } — rareté imposée (LuckyHour), nil = tirage normal
-- modeleForce   : modèle source imposé (BR muté), nil = choisirModele()
-- mutTypeForce  : nom du type de mutation (pour attributs + income mult)
-- incomeMultForce : multiplicateur income appliqué sur CashParSeconde
local function spawnerUnBrainRot(baseIndex, rareteForce, modeleForce, mutTypeForce, incomeMultForce)
	local zone = zones[baseIndex]
	if not zone then return end

	-- Limite max par base (ignorée pour spawns forcés LuckyHour)
	if not rareteForce and compteurs[baseIndex] >= CONFIG.MAX_PAR_BASE then return end

	-- Tirage de rareté (ou rareté imposée)
	local hasLucky = false
	if not rareteForce and _getPlayerData then
		local joueur = trouverJoueurBase(baseIndex)
		if joueur then
			local d = _getPlayerData(joueur)
			hasLucky = d and d.hasLuckyCharm == true
		end
	end
	local rarete = rareteForce or tirerRarete(hasLucky)

	-- ── Tentative mutation champ perso (0.2%, jamais COMMON) — ignorée si spawn forcé ──
	local mutSourcePerso  = nil
	local mutTypePerso    = mutTypeForce or nil
	local mutMultPerso    = incomeMultForce or 1
	local pfMutCfg        = _GameConfig.PersonalFieldMutationConfig

	if not rareteForce and pfMutCfg and pfMutCfg.enabled and mutationFolder then
		-- Vérifier rareté non exclue (+ exclure MYTHIC/SECRET/BRAINROT_GOD des mutations champ en Admin Abuse)
		local exclu = false
		for _, r in ipairs(pfMutCfg.raretesExclues or {}) do
			if r == rarete.nom then exclu = true ; break end
		end
		if _adminAbuseElemRaretes and _adminAbuseElemRaretes[rarete.nom] then
			exclu = true  -- réservés aux mutations élément (GALAXY/VOID etc.)
		end

		local mutChance = _adminAbuseMutChance or pfMutCfg.chance or 0.002
		if not exclu and math.random() < mutChance then
			-- Tirage pondéré du type
			local totalMut = 0
			for _, t in ipairs(pfMutCfg.types) do totalMut = totalMut + t.weight end
			local roll, cumul = math.random() * totalMut, 0
			local typeTire = nil
			for _, t in ipairs(pfMutCfg.types) do
				cumul = cumul + t.weight
				if roll <= cumul then typeTire = t ; break end
			end

			if typeTire then
				local typeFolder = mutationFolder and mutationFolder:FindFirstChild(typeTire.name)
				if typeFolder then
					local rareteMappe = (pfMutCfg.rareteMapping and pfMutCfg.rareteMapping[rarete.nom]) or rarete.nom
					local rareteFolder = typeFolder:FindFirstChild(rareteMappe)
					if rareteFolder then
						local ignored = {}
						for _, nom in ipairs(pfMutCfg.ignoredFolders or {}) do ignored[nom] = true end
						local candidats = {}
						for _, child in ipairs(rareteFolder:GetChildren()) do
							if not ignored[child.Name] and (child:IsA("Model") or child:IsA("BasePart")) then
								table.insert(candidats, child)
							end
						end
						if #candidats > 0 then
							mutSourcePerso = candidats[math.random(1, #candidats)]
							mutTypePerso   = typeTire.name
							mutMultPerso   = typeTire.multiplier
						else
							Logger.warn("Spawn", "[AdminAbuse] Mutation '%s/%s' vide ou introuvable", typeTire.name, rareteMappe)
						end
					else
						Logger.warn("Spawn", "[AdminAbuse] Dossier rareté '%s' absent dans Mutation/%s", rareteMappe, typeTire.name)
					end
				else
					Logger.warn("Spawn", "[AdminAbuse] Dossier mutation '%s' absent dans ServerStorage/Mutation", typeTire.name)
				end
			end
		end
	end

	-- Mutation élément Admin Abuse (GALAXY/TOXIC/RAINBOW/VOID)
	local _adminAbuseElemType = nil
	local elemEligible = _adminAbuseElemRaretes == nil or (_adminAbuseElemRaretes and _adminAbuseElemRaretes[rarete.nom])
	if not rareteForce and not mutSourcePerso
		and _adminAbuseElemChance and elemEligible
		and math.random() < _adminAbuseElemChance then

		local mutTypes = _GameConfig.MutantTypes
		if mutTypes and #mutTypes > 0 then
			local mt = mutTypes[math.random(1, #mutTypes)]
			_adminAbuseElemType = mt
			mutTypePerso  = mt.Name
			mutMultPerso  = mt.Multiplier
			-- Enrichir rarete pour que DropSystem réapplique le bon filtre au dépôt
			rarete = {
				nom         = rarete.nom,
				poids       = rarete.poids,
				dossier     = rarete.dossier,
				isMutant    = true,
				elementType = mt.Name,
			}
			Logger.warn("Spawn", "[AdminAbuse] Mutation élément %s %s ×%d", mt.Name, rarete.nom, mt.Multiplier)
		else
			Logger.warn("Spawn", "[AdminAbuse] MutantTypes vide ou absent dans GameConfig")
		end
	end

	-- Choix du modèle (forcé, muté perso, ou normal)
	local modeleSource = modeleForce or mutSourcePerso or choisirModele(rarete.dossier)
	if not modeleSource then return end

	-- Clonage
	local clone
	local ok, err = pcall(function()
		clone = modeleSource:Clone()
	end)
	if not ok or not clone then
		Logger.warn("Spawn", "Erreur clonage : %s", tostring(err))
		return
	end

	-- Nommage unique + attribut rareté (lu par GetPlusProcheEligible)
	idCounter  = idCounter + 1
	local id   = idCounter
	clone.Name = string.format("BR_%d_%d", baseIndex, id)
	pcall(function() clone:SetAttribute("Rarete",       rarete.nom)    end)
	pcall(function() clone:SetAttribute("BaseIndex",    baseIndex)     end)
	pcall(function() clone:SetAttribute("SpawnId",      id)            end)
	pcall(function() clone:SetAttribute("OriginalName", modeleSource.Name) end)
	-- Copier Prix et CashParSeconde depuis le modèle source (comme LavaTower)
	local prixSrc = modeleSource:GetAttribute("Prix")
	local cpsSrc  = modeleSource:GetAttribute("CashParSeconde")
	if prixSrc then pcall(function() clone:SetAttribute("Prix", prixSrc) end) end
	local cpsVal = cpsSrc or (_GameConfig.IncomeParRarete and _GameConfig.IncomeParRarete[rarete.nom]) or 0
	if mutTypePerso then
		cpsVal = math.floor(cpsVal * mutMultPerso)
	end
	-- Lucky Charm Pattern C : OG vaut 2× coins (COMMON ne spawn plus avec Lucky Charm)
	if hasLucky and rarete.nom == "OG" then
		cpsVal = cpsVal * 2
	end
	pcall(function() clone:SetAttribute("CashParSeconde", cpsVal) end)

	-- Attributs mutation champ perso
	if mutTypePerso then
		pcall(function() clone:SetAttribute("IsMutated",    true)        end)
		pcall(function() clone:SetAttribute("MutationType", mutTypePerso) end)
		pcall(function() clone:SetAttribute("Mutation", mutTypePerso) end)  -- lu par CarrySystem.creerTool
		Logger.info("Mutation", "Champ perso : %s %s x%.0f sur Base_%d",
			mutTypePerso, rarete.nom, mutMultPerso, baseIndex)
	end

	-- Position aléatoire dans la SpawnZone
	local x = math.random() * (zone.xMax - zone.xMin) + zone.xMin
	local z = math.random() * (zone.zMax - zone.zMin) + zone.zMin

	-- Placer dans le Workspace avant de manipuler le CFrame
	clone.Parent = Workspace

	-- Appliquer filtre visuel Admin Abuse APRÈS parenting (FilterManager nécessite Parent ≠ nil)
	if _adminAbuseElemType then
		local FM = getFilterManager()
		if FM and FM.Apply and _adminAbuseElemType.Filtre then
			pcall(FM.Apply, clone, { { Name = _adminAbuseElemType.Filtre } })
		end
	end

	local racine = obtenirRacine(clone)
	if not racine then
		clone:Destroy()
		Logger.warn("Spawn", "Modèle sans BasePart : %s", modeleSource.Name)
		return
	end

	-- Récupérer tous les BaseParts
	local parts = obtenirBaseParts(clone)

	-- Ancrer + désactiver collision immédiatement pour que la physique
	-- ne disperse pas les parts non-weldées pendant l'animation de pousse
	for _, part in ipairs(parts) do
		part.Anchored   = true
		part.CanCollide = false
	end

	-- Enregistrer dans la liste des actifs
	actifs[baseIndex][id]    = clone
	compteurs[baseIndex]     = compteurs[baseIndex] + 1

	local forceCollected = function() end  -- placeholder no-op

	-- ══ ANIMATION "POUSSE DE TERRE" ══
	local yDepart = zone.yFixe + CONFIG.Y_DEPART_OFFSET
	pcall(function()
		if clone:IsA("Model") then
			clone:ScaleTo(0.01)
			clone:PivotTo(CFrame.new(x, yDepart, z))
		else
			racine.Size   = racine.Size * 0.01
			racine.CFrame = CFrame.new(x, yDepart, z)
		end
	end)

	task.spawn(function()
		local duree  = CONFIG.DUREE_POUSSE
		local etapes = CONFIG.ETAPES_POUSSE
		for i = 1, etapes do
			if not clone or not clone.Parent then return end
			local t     = i / etapes
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
			local dureeRestante = math.floor(CONFIG.DUREE_DESPAWN - CONFIG.DUREE_POUSSE)
			BrainrotBillboard.SetupField(clone, dureeRestante)
			pcall(lancerCountdownBillboard, clone, dureeRestante)

			-- PointLight coloré pour BR mutés (billboard géré par BrainrotBillboard)
			if mutTypePerso and racine then
				local couleur      = MUTATION_COLORS[mutTypePerso] or Color3.fromRGB(255, 255, 255)
				local light        = Instance.new("PointLight")
				light.Color        = couleur
				light.Brightness   = 3
				light.Range        = 22
				light.Parent       = racine
			end
		end

		if clone and clone.Parent then
			-- ProximityPrompt pour tous les BR (via OnBRSpawned)
			if SpawnManager.OnBRSpawned then
				local onCapture = nil
				local ordreRarete = RARETE_ORDRE[rarete.nom] or 0
				if ordreRarete >= 3 then  -- RARE+ → Tracteur roll au collect
					onCapture = function(player)
						task.spawn(rollBonusTracteur, baseIndex)
						if ordreRarete >= 4 then  -- EPIC+ → leaderboard + seed drop
							if SpawnManager.OnRareCollecte then
								pcall(SpawnManager.OnRareCollecte, player, rarete.nom)
							end
							local FPS = getFlowerPotSystem()
							if FPS then
								pcall(FPS.TenterDropGraine, player, rarete.nom)
							end
						end
					end
				end
				pcall(SpawnManager.OnBRSpawned, clone, baseIndex, rarete, onCapture)
			end
		end
	end)

	-- Despawn automatique
	task.delay(CONFIG.DUREE_DESPAWN, function()
		if not clone or not clone.Parent then return end
		if actifs[baseIndex][id] == nil then return end
		if clone:GetAttribute("Captured") then
			actifs[baseIndex][id] = nil
			compteurs[baseIndex]  = math.max(0, compteurs[baseIndex] - 1)
			return
		end

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
-- TRACTEUR — Lucky Spawn passif (Game Pass)
-- ============================================================

-- Cherche le joueur assigné à une base (lookup inverse sur assignations)
local function trouverJoueurBase(baseIndex)
    for userId, idx in pairs(assignations) do
        if idx == baseIndex then
            return Players:GetPlayerByUserId(userId)
        end
    end
    return nil
end

-- Feedback visuel jackpot : lumière dorée 1s + notification flottante 3s + son rare
local function ajouterFeedbackBonus(racine, rareteNom)
    if not racine or not racine.Parent then return end

    -- Lumière dorée éphémère (1 seconde)
    local light          = Instance.new("PointLight")
    light.Color          = Color3.fromRGB(255, 215, 0)
    light.Brightness     = 6
    light.Range          = 18
    light.Parent         = racine
    task.delay(1, function()
        if light and light.Parent then light:Destroy() end
    end)

    -- Notification flottante au-dessus du BR (3 secondes)
    local bb        = Instance.new("BillboardGui")
    bb.Name         = "TracteurNotif"
    bb.Size         = UDim2.new(4, 0, 1.2, 0)
    bb.StudsOffset  = Vector3.new(0, 10, 0)
    bb.AlwaysOnTop  = false
    bb.ResetOnSpawn = false
    bb.Parent       = racine

    local texte        = rareteNom == "MYTHIC" and "MYTHIC!" or "SECRET!"
    local couleurNotif = rareteNom == "MYTHIC"
        and Color3.fromRGB(180, 0, 255)
        or  Color3.fromRGB(255, 50,  50)

    local label                  = Instance.new("TextLabel")
    label.Text                   = texte
    label.Size                   = UDim2.new(1, 0, 1, 0)
    label.TextColor3             = couleurNotif
    label.TextScaled             = true
    label.Font                   = Enum.Font.GothamBold
    label.BackgroundTransparency = 1
    label.TextStrokeTransparency = 0.3
    label.TextStrokeColor3       = Color3.new(0, 0, 0)
    label.Parent                 = bb

    task.delay(3, function()
        if bb and bb.Parent then bb:Destroy() end
    end)

    -- Son rare si configuré dans GameConfig
    local sonId = _GameConfig.SonRare
    if sonId and sonId > 0 then
        local son                 = Instance.new("Sound")
        son.SoundId               = "rbxassetid://" .. tostring(sonId)
        son.Volume                = 1
        son.RollOffMaxDistance    = 60
        son.Parent                = racine
        pcall(function() son:Play() end)
        task.delay(5, function()
            if son and son.Parent then son:Destroy() end
        end)
    end
end

-- Spawne un BR d'une rareté précise dans la zone d'une base (bonus Tracteur)
-- Suit la même logique que spawnerUnBrainRot : animation, attributs, despawn
local function spawnerBRBonus(baseIndex, rareteNom)
    local zone = zones[baseIndex]
    if not zone then return end

    -- Respecter le plafond max par base
    if compteurs[baseIndex] >= CONFIG.MAX_PAR_BASE then return end

    -- Dossier rareté dans ReplicatedStorage (MYTHIC ou SECRET)
    local dossier = brainrotsFolder:FindFirstChild(rareteNom)
    if not dossier then
        Logger.warn("Spawn", "Tracteur: dossier '%s' introuvable dans ReplicatedStorage", rareteNom)
        return
    end
    local modeles = dossier:GetChildren()
    if #modeles == 0 then
        Logger.warn("Spawn", "Tracteur: dossier '%s' vide", rareteNom)
        return
    end

    local source = modeles[math.random(1, #modeles)]
    local clone
    local ok, err = pcall(function() clone = source:Clone() end)
    if not ok or not clone then
        Logger.warn("Spawn", "Tracteur: erreur clonage %s : %s", rareteNom, tostring(err))
        return
    end

    -- Attributs identiques aux spawns normaux
    idCounter  = idCounter + 1
    local id   = idCounter
    clone.Name = string.format("BR_%d_%d_tracteur", baseIndex, id)
    pcall(function() clone:SetAttribute("Rarete",       rareteNom)   end)
    pcall(function() clone:SetAttribute("BaseIndex",    baseIndex)   end)
    pcall(function() clone:SetAttribute("SpawnId",      id)          end)
    pcall(function() clone:SetAttribute("OriginalName", source.Name) end)
    -- Copier Prix et CashParSeconde depuis le modèle source (comme LavaTower)
    local prixSrcT = source:GetAttribute("Prix")
    local cpsSrcT  = source:GetAttribute("CashParSeconde")
    if prixSrcT then pcall(function() clone:SetAttribute("Prix", prixSrcT) end) end
    local cpsValT = cpsSrcT or (_GameConfig.IncomeParRarete and _GameConfig.IncomeParRarete[rareteNom]) or 0
    pcall(function() clone:SetAttribute("CashParSeconde", cpsValT) end)

    -- Position aléatoire dans la zone de spawn
    local x = math.random() * (zone.xMax - zone.xMin) + zone.xMin
    local z = math.random() * (zone.zMax - zone.zMin) + zone.zMin

    clone.Parent = Workspace

    local racine = obtenirRacine(clone)
    if not racine then clone:Destroy(); return end

    local parts = obtenirBaseParts(clone)
    for _, part in ipairs(parts) do
        part.Anchored   = true
        part.CanCollide = false
    end

    -- Animation pousse de terre (même style que les spawns normaux)
    local yDepart = zone.yFixe + CONFIG.Y_DEPART_OFFSET
    pcall(function()
        if clone:IsA("Model") then
            clone:ScaleTo(0.01)
            clone:PivotTo(CFrame.new(x, yDepart, z))
        else
            racine.Size   = racine.Size * 0.01
            racine.CFrame = CFrame.new(x, yDepart, z)
        end
    end)

    -- Enregistrement immédiat dans les actifs
    actifs[baseIndex][id]  = clone
    compteurs[baseIndex]   = compteurs[baseIndex] + 1

    task.spawn(function()
        local duree  = CONFIG.DUREE_POUSSE
        local etapes = CONFIG.ETAPES_POUSSE
        for i = 1, etapes do
            if not clone or not clone.Parent then return end
            local t     = i / etapes
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

        -- Snap final à la position exacte
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

        if clone and clone.Parent then
            -- Billboard et countdown (durée réduite de l'animation)
            local dureeRestante = math.floor(CONFIG.DUREE_DESPAWN - CONFIG.DUREE_POUSSE)
            BrainrotBillboard.SetupField(clone, dureeRestante)
            pcall(lancerCountdownBillboard, clone, dureeRestante)

            -- FilterManager (visuels rareté centralisés)
            local FM = getFilterManager()
            if FM then pcall(FM.Apply, clone, rareteNom) end

            -- Feedback jackpot (lumière + notification + son)
            pcall(ajouterFeedbackBonus, racine, rareteNom)

            -- ProximityPrompt via OnBRSpawned (même hook que les spawns normaux)
            local rareteObj = { nom = rareteNom, dossier = rareteNom }
            if SpawnManager.OnBRSpawned then
                pcall(SpawnManager.OnBRSpawned, clone, baseIndex, rareteObj)
            end
        end
    end)

    -- Despawn automatique
    task.delay(CONFIG.DUREE_DESPAWN, function()
        if not clone or not clone.Parent then return end
        if actifs[baseIndex][id] == nil then return end
        if clone:GetAttribute("Captured") then
            actifs[baseIndex][id] = nil
            compteurs[baseIndex]  = math.max(0, compteurs[baseIndex] - 1)
            return
        end
        actifs[baseIndex][id] = nil
        compteurs[baseIndex]  = math.max(0, compteurs[baseIndex] - 1)
        tweenTransparence(parts, 1, CONFIG.DUREE_FADE_OUT)
        task.delay(CONFIG.DUREE_FADE_OUT + 0.1, function()
            if clone and clone.Parent then clone:Destroy() end
        end)
    end)
end

-- Injecté par Main.server.lua pour lire playerData sans dépendance circulaire
local _getPlayerData = nil
function SpawnManager.SetGetData(fn) _getPlayerData = fn end

-- Active/désactive la pool Admin Abuse (appelé par EventAdminAbuse)
function SpawnManager.SetAdminAbuseMode(enabled, cfg)
    if enabled and cfg and cfg.spawnPool then
        _adminAbusePool = cfg.spawnPool
        _adminAbusePoidsTot = 0
        for _, r in ipairs(_adminAbusePool) do
            _adminAbusePoidsTot = _adminAbusePoidsTot + r.poids
        end
        _adminAbuseMutChance   = cfg.mutationChance
        _adminAbuseElemChance  = cfg.elementMutationChance
        _adminAbuseElemRaretes = cfg.elementMutationRaretes
        Logger.warn("Spawn", "[AdminAbuse] Pool activée — %d raretés, mut=%.0f%%, elem=%.0f%%",
            #_adminAbusePool,
            (_adminAbuseMutChance or 0) * 100,
            (_adminAbuseElemChance or 0) * 100)
    else
        _adminAbusePool        = nil
        _adminAbusePoidsTot    = 0
        _adminAbuseMutChance   = nil
        _adminAbuseElemChance  = nil
        _adminAbuseElemRaretes = nil
        Logger.warn("Spawn", "[AdminAbuse] Pool désactivée — retour pool normale")
    end
end

-- Roll bonus Tracteur — appelé après chaque spawn normal dans le champ d'une base
-- Vérifie le Game Pass côté serveur (pas de cache statique) puis tire le bonus
local function rollBonusTracteur(baseIndex)
    -- Trouver le joueur propriétaire de cette base
    local player = trouverJoueurBase(baseIndex)
    if not player then return end

    -- ID Game Pass Tracteur depuis GameConfig
    local tracteurId = _GameConfig.GamePassIds and _GameConfig.GamePassIds.Tracteur

    local possede = false
    if not tracteurId or tracteurId == 0 then
        -- Pas d'ID configuré : fallback sur playerData.hasTracteur (Studio / force-test)
        if _getPlayerData then
            local d = _getPlayerData(player)
            possede = d and d.hasTracteur == true
        end
        if not possede then return end
    else
        -- Vérification côté serveur (jamais en cache pour éviter les exploits)
        local ok, err = pcall(function()
            possede = MarketplaceService:UserOwnsGamePassAsync(player.UserId, tracteurId)
        end)
        if not ok then
            Logger.warn("Spawn", "Tracteur: erreur vérif GamePass pour %s : %s", player.Name, tostring(err))
            return
        end
        if not possede then return end
    end

    -- Tirage bonus sur 100
    -- 1%  → jackpot (MYTHIC + SECRET simultanés)
    -- 1%  → SECRET seul
    -- 4%  → MYTHIC seul
    -- 94% → rien (spawn normal uniquement)
    local roll  = math.random(1, 100)
    local cumul = 0

    cumul = cumul + TRACTEUR_CONFIG.JACKPOT_CHANCE
    if roll <= cumul then
        -- Jackpot : MYTHIC + SECRET
        spawnerBRBonus(baseIndex, "MYTHIC")
        spawnerBRBonus(baseIndex, "SECRET")
        return
    end

    cumul = cumul + TRACTEUR_CONFIG.SECRET_CHANCE
    if roll <= cumul then
        -- SECRET seul
        spawnerBRBonus(baseIndex, "SECRET")
        return
    end

    cumul = cumul + TRACTEUR_CONFIG.MYTHIC_CHANCE
    if roll <= cumul then
        -- MYTHIC seul
        spawnerBRBonus(baseIndex, "MYTHIC")
        return
    end

    -- 94% : aucun bonus
end

-- ============================================================
-- Boucle de spawn par base (task.spawn indépendant)
-- ============================================================

local function lancerBoucleSpawn(baseIndex)
	task.spawn(function()
		local iteration = 0

		while true do
			-- Multiplicateur combiné : event × arroseur upgrade
			local mult       = (multiplicateurs[baseIndex] or 1) * (arroseurMults[baseIndex] or 1)
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
		Logger.info("Spawn", "Boucle lancée pour Base_%s", tostring(baseIndex))
	end
end

-- ============================================================
-- API publique
-- ============================================================

-- Multiplicateur d'event global
SpawnManager.EventMultiplier = 1

-- Définir le multiplicateur (baseIndex = nil → toutes les bases)
function SpawnManager.SetEventMultiplier(mult, baseIndex)
	mult = math.max(1, mult or 1)
	if baseIndex then
		multiplicateurs[baseIndex] = mult
	else
		SpawnManager.EventMultiplier = mult
		for idx in pairs(zones) do
			multiplicateurs[idx] = mult
		end
	end
end

-- Forcer l'assignation d'un joueur à une base précise (appelé par Main via AssignationSystem)
function SpawnManager.SetBase(player, baseIndex)
    assignations[player.UserId] = baseIndex
    Logger.info("Spawn", "%s → Base_%d (SetBase)", player.Name, baseIndex)
end

-- Assigner un joueur à la première base libre
function SpawnManager.AssignerBase(player)
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
			Logger.info("Spawn", "%s → Base_%d", player.Name, baseIndex)
			return baseIndex
		end
	end

	Logger.warn("Spawn", "Toutes les bases sont occupées pour %s", player.Name)
	return nil
end

-- Libérer la base d'un joueur (à la déconnexion)
function SpawnManager.LibererBase(player)
	if assignations[player.UserId] then
		local baseIndex = assignations[player.UserId]
		assignations[player.UserId] = nil
		Logger.debug("Spawn", "Base_%d libérée (%s)", baseIndex, player.Name)
	end
end

-- Obtenir l'index de la base d'un joueur
function SpawnManager.GetBase(player)
	return assignations[player.UserId]
end

-- Callbacks — à assigner depuis Main.server.lua
SpawnManager.OnCollecte    = nil
SpawnManager.OnBRSpawned   = nil
SpawnManager.OnRareCollecte = nil

-- Libération automatique à la déconnexion
Players.PlayerRemoving:Connect(function(player)
	SpawnManager.LibererBase(player)
end)

-- Multiplicateur de spawn par joueur (upgrade Arroseur)
function SpawnManager.SetSpawnRateMultiplier(player, mult)
	local baseIndex = assignations[player.UserId]
	if not baseIndex then return end
	arroseurMults[baseIndex] = math.max(1, mult or 1)
end

-- Trouve le BR éligible de plus haute rareté dans le champ du joueur
function SpawnManager.GetPlusProcheEligible(player, seuilOrdre)
	local baseIndex = assignations[player.UserId]
	if not baseIndex then return nil end

	local meilleur      = nil
	local meilleurOrdre = -1

	for id, modele in pairs(actifs[baseIndex] or {}) do
		if modele and modele.Parent and not modele:GetAttribute("Captured") then
			local rareteNom = modele:GetAttribute("Rarete")
			if rareteNom then
				local ordre = RARETE_ORDRE[rareteNom] or 0
				if ordre >= seuilOrdre and ordre > meilleurOrdre then
					meilleur = {
						id        = id,
						baseIndex = baseIndex,
						rarete    = rareteNom,
						modele    = modele,
					}
					meilleurOrdre = ordre
				end
			end
		end
	end

	return meilleur
end

-- Supprime un BR actif par id + baseIndex (appelé par le tracteur après aspiration)
function SpawnManager.SupprimerCollectible(id, baseIndex)
	if not baseIndex or not actifs[baseIndex] then return end
	local modele = actifs[baseIndex][id]
	if not modele or not modele.Parent then return end

	pcall(function() modele:SetAttribute("Captured", true) end)
	actifs[baseIndex][id] = nil
	compteurs[baseIndex]  = math.max(0, (compteurs[baseIndex] or 0) - 1)

	local info = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, v in ipairs(modele:GetDescendants()) do
		if v:IsA("BasePart") then
			pcall(function() TweenService:Create(v, info, { Transparency = 1, Size = v.Size * 1.3 }):Play() end)
		end
	end
	task.delay(0.4, function()
		if modele and modele.Parent then modele:Destroy() end
	end)
end

-- Spawne un BR d'une rareté précise à une position précise (utilisé par MeteorDrop)
function SpawnManager.SpawnerBRSpecifique(position, rareteNom)
    local dossier = brainrotsFolder:FindFirstChild(rareteNom)
    if not dossier then
        dossier = brainrotsFolder:FindFirstChild("LEGENDARY")
    end
    if not dossier then
        Logger.warn("Spawn", "SpawnerBRSpecifique : dossier introuvable (%s)", tostring(rareteNom))
        return
    end

    local modeles = dossier:GetChildren()
    if #modeles == 0 then return end

    local source = modeles[math.random(1, #modeles)]
    local clone
    local ok, err = pcall(function() clone = source:Clone() end)
    if not ok or not clone then
        Logger.warn("Spawn", "SpawnerBRSpecifique : erreur clonage %s", tostring(err))
        return
    end

    idCounter  = idCounter + 1
    local id   = idCounter
    clone.Name = string.format("BR_meteor_%d", id)
    pcall(function() clone:SetAttribute("Rarete",       rareteNom)   end)
    pcall(function() clone:SetAttribute("OriginalName", source.Name) end)
    -- Copier Prix et CashParSeconde depuis le modèle source (comme LavaTower)
    local prixSrcM = source:GetAttribute("Prix")
    local cpsSrcM  = source:GetAttribute("CashParSeconde")
    if prixSrcM then pcall(function() clone:SetAttribute("Prix", prixSrcM) end) end
    local cpsValM = cpsSrcM or (_GameConfig.IncomeParRarete and _GameConfig.IncomeParRarete[rareteNom]) or 0
    pcall(function() clone:SetAttribute("CashParSeconde", cpsValM) end)
    clone.Parent = Workspace

    local racine = obtenirRacine(clone)
    if not racine then
        clone:Destroy()
        return
    end

    local parts = obtenirBaseParts(clone)
    for _, part in ipairs(parts) do
        part.CanCollide = false
        part.Anchored   = true
    end

    -- Positionner
    pcall(function()
        if clone:IsA("Model") then
            clone:PivotTo(CFrame.new(position))
        else
            racine.CFrame = CFrame.new(position)
        end
    end)

    -- Billboard
    BrainrotBillboard.SetupField(clone, CONFIG.DUREE_DESPAWN)
    pcall(lancerCountdownBillboard, clone, CONFIG.DUREE_DESPAWN)

    -- ProximityPrompt via hook OnBRSpawned (baseIndex = nil → tout le monde peut capturer)
    local rareteObj = { nom = rareteNom, dossier = rareteNom }
    if SpawnManager.OnBRSpawned then
        pcall(SpawnManager.OnBRSpawned, clone, nil, rareteObj)
    end

    -- Despawn automatique
    task.delay(CONFIG.DUREE_DESPAWN, function()
        if not clone or not clone.Parent then return end
        if clone:GetAttribute("Captured") then return end
        tweenTransparence(parts, 1, CONFIG.DUREE_FADE_OUT)
        task.delay(CONFIG.DUREE_FADE_OUT + 0.1, function()
            if clone and clone.Parent then clone:Destroy() end
        end)
    end)
end

-- Spawne un BR d'une rareté précise dans la zone d'une base (LuckyHour normal)
-- Utilise spawnerUnBrainRot : registration, despawn, billboard, ProximityPrompt inclus
function SpawnManager.SpawnerBRDansBase(baseIndex, rareteNom)
    if not zones[baseIndex] then
        Logger.warn("Spawn", "SpawnerBRDansBase : zone introuvable pour Base_%s", tostring(baseIndex))
        return
    end
    -- Construire l'objet rareté attendu par spawnerUnBrainRot
    local rareteObj = nil
    for _, r in ipairs(RARITES) do
        if r.nom == rareteNom then rareteObj = r ; break end
    end
    -- Fallback pour MYTHIC/SECRET (absents de RARITES SpawnManager)
    if not rareteObj then
        rareteObj = { nom = rareteNom, dossier = rareteNom, poids = 0 }
    end
    spawnerUnBrainRot(baseIndex, rareteObj)
end

-- ============================================================
-- Spawn BR Muté (LuckyHour Mutation)
-- Clone depuis ServerStorage/Mutation/[type]/[rareteNom]
-- Applique les attributs IsMutated, MutationType, CashParSeconde × multiplicateur
-- ============================================================

local mutationFolder = ServerStorage:FindFirstChild("Mutation")

-- Dossiers à ignorer dans chaque type de mutation
local MUTATION_IGNORED = { LUCKY_BLOCK = true, ToUseAfter = true }

-- Mapping rareté → nom de dossier dans Mutation/ (GOD au lieu de BRAINROT_GOD)
local function mapperRarete(rareteNom, mutCfg)
    if mutCfg and mutCfg.rareteMapping and mutCfg.rareteMapping[rareteNom] then
        return mutCfg.rareteMapping[rareteNom]
    end
    return rareteNom
end

-- Tire un modèle aléatoire depuis un dossier de rareté, en ignorant les sous-dossiers exclus
local function clonerBRMute(typeFolder, rareteNom, mutCfg)
    local rareteFolder = typeFolder:FindFirstChild(rareteNom)
    if not rareteFolder then
        Logger.warn("Mutation", "Dossier rareté introuvable : %s/%s", typeFolder.Name, rareteNom)
        return nil
    end

    -- Filtrer les enfants valides (exclure LUCKY_BLOCK, ToUseAfter, scripts)
    local ignored = {}
    if mutCfg and mutCfg.ignoredFolders then
        for _, nom in ipairs(mutCfg.ignoredFolders) do ignored[nom] = true end
    end

    local modeles = {}
    for _, child in ipairs(rareteFolder:GetChildren()) do
        if not ignored[child.Name] and (child:IsA("Model") or child:IsA("BasePart")) then
            table.insert(modeles, child)
        end
    end

    if #modeles == 0 then
        Logger.warn("Mutation", "Aucun modèle valide dans %s/%s", typeFolder.Name, rareteNom)
        return nil
    end

    local source = modeles[math.random(1, #modeles)]
    local clone
    local ok, err = pcall(function() clone = source:Clone() end)
    if not ok or not clone then
        Logger.warn("Mutation", "Erreur clonage muté : %s", tostring(err))
        return nil
    end
    return clone, source.Name
end

function SpawnManager.SpawnerBRMuteeDansBase(baseIndex, rareteNom, mutationType, multiplier)
    if not mutationFolder then
        Logger.warn("Mutation", "ServerStorage/Mutation introuvable")
        return
    end
    if not zones[baseIndex] then
        Logger.warn("Mutation", "Zone introuvable pour Base_%s", tostring(baseIndex))
        return
    end

    local mutCfg     = _GameConfig.LuckyHourMutationConfig
    local typeFolder = mutationFolder:FindFirstChild(mutationType)
    if not typeFolder then
        Logger.warn("Mutation", "Type mutation introuvable : %s", tostring(mutationType))
        return
    end

    -- Trouver le modèle source muté
    local rareteMappe = mapperRarete(rareteNom, mutCfg)
    local source, _   = clonerBRMute(typeFolder, rareteMappe, mutCfg)
    -- clonerBRMute retourne déjà un clone — on a besoin du SOURCE pour spawnerUnBrainRot
    -- On relit le dossier pour obtenir le modèle source (pas le clone)
    if source then pcall(function() source:Destroy() end) end  -- détruire le clone temporaire

    local ignored = {}
    for _, nom in ipairs((mutCfg and mutCfg.ignoredFolders) or {}) do ignored[nom] = true end
    local rareteFolder = typeFolder:FindFirstChild(rareteMappe)
    if not rareteFolder then
        Logger.warn("Mutation", "Dossier rareté muté introuvable : %s/%s", mutationType, rareteMappe)
        return
    end
    local candidats = {}
    for _, child in ipairs(rareteFolder:GetChildren()) do
        if not ignored[child.Name] and (child:IsA("Model") or child:IsA("BasePart")) then
            table.insert(candidats, child)
        end
    end
    if #candidats == 0 then
        Logger.warn("Mutation", "Aucun modèle muté dans %s/%s", mutationType, rareteMappe)
        return
    end
    local modeleSource = candidats[math.random(1, #candidats)]

    -- Construire l'objet rareté
    local rareteObj = nil
    for _, r in ipairs(RARITES) do
        if r.nom == rareteNom then rareteObj = r ; break end
    end
    rareteObj = rareteObj or { nom = rareteNom, dossier = rareteNom, poids = 0 }

    -- Déléguer à spawnerUnBrainRot : registration, despawn, billboard, ProximityPrompt inclus
    spawnerUnBrainRot(baseIndex, rareteObj, modeleSource, mutationType, multiplier or 1)

    Logger.info("Mutation", "LuckyHour mute : %s %s x%.1f sur Base_%d",
        mutationType, rareteNom, multiplier or 1, baseIndex)
end

-- ============================================================
-- Init (appelé par Main.server.lua)
-- ============================================================
function SpawnManager.Init()
	demarrer()
end

return SpawnManager
