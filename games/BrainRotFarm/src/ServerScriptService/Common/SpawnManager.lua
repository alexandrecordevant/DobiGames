-- ServerScriptService/Common/SpawnManager.lua
-- BrainRotFarm — Spawn champs individuels (COMMON → BRAINROT_GOD)
-- MYTHIC et SECRET réservés à CommunSpawner (ZoneCommune)
-- Refactorisé depuis BrainRotSpawner.lua — config lue depuis GameConfig

local SpawnManager = {}

-- ============================================================
-- Services
-- ============================================================
local TweenService   = game:GetService("TweenService")
local Players        = game:GetService("Players")
local ServerStorage  = game:GetService("ServerStorage")
local Workspace      = game:GetService("Workspace")

-- ============================================================
-- Config — lue depuis GameConfig
-- ============================================================
local _GameConfig = require(game.ReplicatedStorage.Specialized.GameConfig)
-- Valeurs animation depuis AnimationConfig (fallback si absent)
local _animCfg = _GameConfig.AnimationConfig or {}

-- SpawnConfig lu depuis GameConfig
local _spawnCfg = _GameConfig.SpawnConfig or {}

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

-- Lazy loader FlowerPotSystem (évite dépendance circulaire)
local _FlowerPotSystem = nil
local function getFlowerPotSystem()
    if not _FlowerPotSystem then
        local ok, m = pcall(require,
            game:GetService("ServerScriptService").Specialized.FlowerPotSystem)
        if ok then _FlowerPotSystem = m end
    end
    return _FlowerPotSystem
end

local brainrotsFolder = ServerStorage:WaitForChild(_dosierBrainrots)

-- ============================================================
-- Utilitaires internes
-- ============================================================

-- Tire une rareté selon les poids (réessaie si la rareté est exclue)
local function tirerRarete()
    local tentatives = 0
    local rarete
    repeat
        local r     = math.random() * POIDS_TOTAL
        local cumul = 0
        rarete      = RARITES[1]  -- fallback COMMON
        for _, candidat in ipairs(RARITES) do
            cumul = cumul + candidat.poids
            if r <= cumul then
                rarete = candidat
                break
            end
        end
        tentatives = tentatives + 1
    until not EstExclue(rarete) or tentatives > 20
    return rarete
end

-- Retourne un modèle aléatoire depuis le dossier de rareté
local function choisirModele(nomDossier)
	local dossier = brainrotsFolder:FindFirstChild(nomDossier)
	if not dossier then
		warn("[SpawnManager] Dossier introuvable : " .. nomDossier)
		return nil
	end
	local modeles = dossier:GetChildren()
	if #modeles == 0 then
		warn("[SpawnManager] Dossier vide : " .. nomDossier)
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
		warn("[SpawnManager] Workspace.Bases introuvable !")
		return
	end

	for _, baseModel in ipairs(basesFolder:GetChildren()) do
		-- Extraire l'index numérique depuis le nom (ex: "Base_1" → 1)
		local indexStr = baseModel.Name:match("Base_(%d+)")
		if not indexStr then continue end
		local baseIndex = tonumber(indexStr)

		local spawnZone = baseModel:FindFirstChild(_spawnZoneNom)
		if not spawnZone then
			warn("[SpawnManager] SpawnZone manquante pour " .. baseModel.Name)
			continue
		end

		local wallTop    = spawnZone:FindFirstChild("Wall_Top")
		local wallBottom = spawnZone:FindFirstChild("Wall_Bottom")
		local wallLeft   = spawnZone:FindFirstChild("Wall_Left")
		local wallRight  = spawnZone:FindFirstChild("Wall_Right")

		if not (wallTop and wallBottom and wallLeft and wallRight) then
			warn("[SpawnManager] Murs manquants dans SpawnZone de " .. baseModel.Name)
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

		print(string.format("[SpawnManager] Zone %s initialisée → X[%.1f, %.1f] Z[%.1f, %.1f] Y=%.1f",
			baseModel.Name, xMin, xMax, zMin, zMax, yFixe))
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
		warn("[SpawnManager] Erreur clonage : " .. tostring(err))
		return
	end

	-- Nommage unique + attribut rareté (lu par GetPlusProcheEligible)
	idCounter  = idCounter + 1
	local id   = idCounter
	clone.Name = string.format("BR_%d_%d", baseIndex, id)
	pcall(function() clone:SetAttribute("Rarete",    rarete.nom) end)
	pcall(function() clone:SetAttribute("BaseIndex", baseIndex)  end)
	pcall(function() clone:SetAttribute("SpawnId",   id)         end)

	-- Position aléatoire dans la SpawnZone
	local x = math.random() * (zone.xMax - zone.xMin) + zone.xMin
	local z = math.random() * (zone.zMax - zone.zMin) + zone.zMin

	-- Placer dans le Workspace avant de manipuler le CFrame
	clone.Parent = Workspace

	local racine = obtenirRacine(clone)
	if not racine then
		clone:Destroy()
		warn("[SpawnManager] Modèle sans BasePart : " .. modeleSource.Name)
		return
	end

	-- Récupérer tous les BaseParts
	local parts = obtenirBaseParts(clone)

	-- CanCollide = false permanent (tous les BR)
	for _, part in ipairs(parts) do
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
			pcall(ajouterBillboard, racine, rarete.nom, modeleSource.Name)
		end

		-- Ancrer les parts pour qu'elles ne tombent pas
		if clone and clone.Parent then
			for _, part in ipairs(parts) do
				part.Anchored = true
			end

			-- ProximityPrompt pour tous les BR (via OnBRSpawned)
			if SpawnManager.OnBRSpawned then
				local onCapture = nil
				if (RARETE_ORDRE[rarete.nom] or 0) >= 4 then  -- EPIC = 4, LEGENDARY = 5, etc.
					onCapture = function(player)
						if SpawnManager.OnRareCollecte then
							pcall(SpawnManager.OnRareCollecte, player, rarete.nom)
						end
						local FPS = getFlowerPotSystem()
						if FPS then
							pcall(FPS.TenterDropGraine, player, rarete.nom)
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
		print("[SpawnManager] Boucle lancée pour Base_" .. baseIndex)
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
    print(string.format("[SpawnManager] %s → Base_%d (SetBase)", player.Name, baseIndex))
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
			print(string.format("[SpawnManager] %s → Base_%d", player.Name, baseIndex))
			return baseIndex
		end
	end

	warn("[SpawnManager] Toutes les bases sont occupées pour " .. player.Name)
	return nil
end

-- Libérer la base d'un joueur (à la déconnexion)
function SpawnManager.LibererBase(player)
	if assignations[player.UserId] then
		local baseIndex = assignations[player.UserId]
		assignations[player.UserId] = nil
		print(string.format("[SpawnManager] Base_%d libérée (%s)", baseIndex, player.Name))
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
        warn("[SpawnManager] SpawnerBRSpecifique : dossier introuvable (" .. tostring(rareteNom) .. ")")
        return
    end

    local modeles = dossier:GetChildren()
    if #modeles == 0 then return end

    local source = modeles[math.random(1, #modeles)]
    local clone
    local ok, err = pcall(function() clone = source:Clone() end)
    if not ok or not clone then
        warn("[SpawnManager] SpawnerBRSpecifique : erreur clonage " .. tostring(err))
        return
    end

    idCounter  = idCounter + 1
    local id   = idCounter
    clone.Name = string.format("BR_meteor_%d", id)
    pcall(function() clone:SetAttribute("Rarete", rareteNom) end)
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
    pcall(ajouterBillboard, racine, rareteNom, source.Name)

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

-- ============================================================
-- Init (appelé par Main.server.lua)
-- ============================================================
function SpawnManager.Init()
	demarrer()
end

return SpawnManager
