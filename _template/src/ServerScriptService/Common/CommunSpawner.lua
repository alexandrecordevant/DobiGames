-- ServerScriptService/Common/CommunSpawner.lua
-- BrainRotFarm — Spawn MYTHIC et SECRET dans la ZoneCommune
-- COMMON/OG/RARE/EPIC/LEGENDARY/BRAINROT_GOD = réservés aux champs individuels
-- Refactorisé depuis ChampCommunSpawner.lua — coordonnées lues depuis GameConfig.CommunPoints

local CommunSpawner = {}

-- ============================================================
-- Services
-- ============================================================
local TweenService        = game:GetService("TweenService")
local Players             = game:GetService("Players")
local ServerStorage       = game:GetService("ServerStorage")
local Workspace           = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")

-- ============================================================
-- Config
-- ============================================================
local Config = require(game.ReplicatedStorage.Specialized.GameConfig)

-- Points de spawn lus depuis GameConfig.CommunPoints
local SPAWN_POINTS = {}
for _, pt in ipairs(Config.CommunPoints) do
    table.insert(SPAWN_POINTS, Vector3.new(pt.x, pt.y, pt.z))
end

-- ============================================================
-- Dépendances
-- ============================================================
local DiscordWebhook = require(ServerScriptService:WaitForChild("Common"):WaitForChild("DiscordWebhook"))

-- Chargement différé (évite les dépendances circulaires)
local _LeaderboardSystem = nil
local function getLeaderboardSystem()
    if not _LeaderboardSystem then
        local ok, m = pcall(require, ServerScriptService.Common.LeaderboardSystem)
        if ok and m then _LeaderboardSystem = m end
    end
    return _LeaderboardSystem
end

-- Configuration TEST_MODE
local _GameConfig = Config
local _TestConfig = _GameConfig.TEST_MODE
    and require(game.ReplicatedStorage.Test.TestConfig)
    or nil

-- Retourne la config ZoneCommune (TestConfig ou valeur par défaut)
local function GetZoneCommCfg(typeNom, champKey, valeurNormale)
    if _TestConfig and _TestConfig.ChampCommun
        and _TestConfig.ChampCommun[typeNom]
        and _TestConfig.ChampCommun[typeNom][champKey] ~= nil then
        return _TestConfig.ChampCommun[typeNom][champKey]
    end
    return valeurNormale
end

-- ============================================================
-- Configuration des raretés
-- ============================================================
local CONFIG = {
	MYTHIC = {
		intervalleSecondes   = GetZoneCommCfg("MYTHIC", "intervalleSecondes",   8 * 60),
		compteurVisibleAvant = GetZoneCommCfg("MYTHIC", "compteurVisibleAvant", 3 * 60),
		valeur               = 300,
		despawnSecondes      = 60,
		couleur              = Color3.fromRGB(148, 0, 211),
		couleurHex           = 9699539,  -- 0x9400D3
		emoji                = "⚠️",
		dossier              = "MYTHIC",
	},
	SECRET = {
		intervalleSecondes   = GetZoneCommCfg("SECRET", "intervalleSecondes",   20 * 60),
		compteurVisibleAvant = GetZoneCommCfg("SECRET", "compteurVisibleAvant",  5 * 60),
		valeur               = 1000,
		despawnSecondes      = 60,
		couleur              = Color3.fromRGB(255, 30, 30),
		couleurHex           = 16718878, -- 0xFF1E1E
		emoji                = "🔴",
		dossier              = "SECRET",
	},
}

-- Effets permanents — valeurs par défaut (couleur MYTHIC)
local COULEUR_DEFAUT       = Color3.fromRGB(148, 0, 211)
local PARTICLE_RATE_BASE   = 8
local PARTICLE_RATE_ALERTE = 40
local LIGHT_RANGE_BASE     = 20
local LIGHT_RANGE_ALERTE   = 40

local BRAINROTS_FOLDER = ServerStorage:WaitForChild("Brainrots")

-- ============================================================
-- État interne
-- ============================================================
local actifMythic     = false
local actifSecret     = false
local idCounter       = 0
local spawnMultiplier = 1  -- modifié par SetMultiplier (Rain Event)

-- Timers pour Leaderboard2 (lus via GetProchainSpawn)
local prochainSpawnTime  = {}  -- { [typeNom] = os.time() du prochain spawn }
local prochainSpawnPoint = {}  -- { [typeNom] = index point A/B/C }

-- Données permanentes par point de spawn
-- { part, particle, light, bb, labelPermanent }
local pointsData = {}

-- ============================================================
-- Utilitaires
-- ============================================================

local function getNotifEvent()
	return ReplicatedStorage:FindFirstChild("NotifEvent")
end

local function notifierTous(typeNotif, message)
	local ev = getNotifEvent()
	if ev then
		pcall(function() ev:FireAllClients(typeNotif, message) end)
	end
	print("[CommunSpawner] " .. message)
end

-- Format MM:SS
local function formatTemps(secondes)
	local m = math.floor(secondes / 60)
	local s = secondes % 60
	return string.format("%d:%02d", m, s)
end

local function choisirModele(nomDossier)
	local dossier = BRAINROTS_FOLDER:FindFirstChild(nomDossier)
	if not dossier then
		warn("[CommunSpawner] Dossier introuvable : " .. nomDossier)
		return nil
	end
	local modeles = dossier:GetChildren()
	if #modeles == 0 then
		warn("[CommunSpawner] Dossier vide : " .. nomDossier)
		return nil
	end
	return modeles[math.random(1, #modeles)]
end

local function obtenirRacine(modele)
	if modele.PrimaryPart then return modele.PrimaryPart end
	for _, v in ipairs(modele:GetDescendants()) do
		if v:IsA("BasePart") then return v end
	end
	return nil
end

local function obtenirBaseParts(modele)
	local parts = {}
	for _, v in ipairs(modele:GetDescendants()) do
		if v:IsA("BasePart") then table.insert(parts, v) end
	end
	if modele:IsA("BasePart") then table.insert(parts, modele) end
	return parts
end

-- ============================================================
-- Effets permanents sur les points de spawn de la ZoneCommune
-- ============================================================

-- Lance la pulsation infinie du PointLight
local function lancerPulsationLight(light)
	task.spawn(function()
		local infoMonte   = TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		local infoDescend = TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		while light and light.Parent do
			TweenService:Create(light, infoMonte,   { Brightness = 3.0 }):Play()
			task.wait(1)
			if not (light and light.Parent) then break end
			TweenService:Create(light, infoDescend, { Brightness = 0.5 }):Play()
			task.wait(1)
		end
	end)
end

-- Crée le BillboardGui permanent "✨ Zone Mystérieuse"
local function creerBillboardPermanent(part, couleur)
	local ancien = part:FindFirstChild("ZoneBillboard")
	if ancien then ancien:Destroy() end

	local bb = Instance.new("BillboardGui")
	bb.Name        = "ZoneBillboard"
	bb.Size        = UDim2.new(0, 160, 0, 40)
	bb.StudsOffset = Vector3.new(0, 10, 0)
	bb.AlwaysOnTop = false
	bb.Adornee     = part
	bb.Parent      = part

	local cadre = Instance.new("Frame")
	cadre.Size                   = UDim2.new(1, 0, 1, 0)
	cadre.BackgroundColor3       = couleur
	cadre.BackgroundTransparency = 0.6
	cadre.BorderSizePixel        = 0
	cadre.Parent                 = bb

	local coin = Instance.new("UICorner")
	coin.CornerRadius = UDim.new(0, 6)
	coin.Parent       = cadre

	local label = Instance.new("TextLabel")
	label.Size                   = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text                   = "✨ Mysterious Zone"
	label.Font                   = Enum.Font.GothamBold
	label.TextColor3             = Color3.new(1, 1, 1)
	label.TextScaled             = true
	label.Parent                 = cadre

	return bb, label
end

-- Initialise les effets permanents sur tous les points dès Init()
local function initialiserEffetsPermanents()
	for i, position in ipairs(SPAWN_POINTS) do
		-- Part invisible permanente (ancre pour les effets)
		local part = Instance.new("Part")
		part.Name         = "ZoneCommune_Point_" .. i
		part.Size         = Vector3.new(1, 1, 1)
		part.Position     = position
		part.Anchored     = true
		part.CanCollide   = false
		part.Transparency = 1
		part.Parent       = Workspace

		-- ParticleEmitter énergie mystérieuse
		local particle = Instance.new("ParticleEmitter")
		particle.Texture     = "rbxasset://textures/particles/sparkles_main.dds"
		particle.Rate        = PARTICLE_RATE_BASE
		particle.Lifetime    = NumberRange.new(1.5, 2.5)
		particle.Speed       = NumberRange.new(2, 4)
		particle.SpreadAngle = Vector2.new(30, 30)
		particle.Color       = ColorSequence.new(COULEUR_DEFAUT)
		particle.Parent      = part

		-- PointLight pulsante
		local light = Instance.new("PointLight")
		light.Brightness = 2
		light.Range      = LIGHT_RANGE_BASE
		light.Color      = COULEUR_DEFAUT
		light.Parent     = part

		lancerPulsationLight(light)

		-- Billboard permanent
		local bb, label = creerBillboardPermanent(part, COULEUR_DEFAUT)

		pointsData[i] = {
			part     = part,
			particle = particle,
			light    = light,
			bb       = bb,
			label    = label,
		}

		print(string.format("[CommunSpawner] Point %d initialisé (%.1f, %.1f, %.1f)",
			i, position.X, position.Y, position.Z))
	end
end

-- Passe un point en mode alerte (compteur imminent)
local function passerEnModeAlerte(pointIdx, couleur)
	local pd = pointsData[pointIdx]
	if not pd then return end

	pd.particle.Color = ColorSequence.new(couleur)
	pd.particle.Rate  = PARTICLE_RATE_ALERTE
	pd.light.Color    = couleur
	pd.light.Range    = LIGHT_RANGE_ALERTE

	-- Supprimer le billboard permanent pour laisser place au compteur
	if pd.bb and pd.bb.Parent then
		pd.bb:Destroy()
		pd.bb    = nil
		pd.label = nil
	end
end

-- Restaure un point à son état par défaut (après collecte/despawn)
local function restaurerEtatsDefaut(pointIdx)
	local pd = pointsData[pointIdx]
	if not pd then return end

	pd.particle.Color = ColorSequence.new(COULEUR_DEFAUT)
	pd.particle.Rate  = PARTICLE_RATE_BASE
	pd.light.Color    = COULEUR_DEFAUT
	pd.light.Range    = LIGHT_RANGE_BASE

	-- Recréer le billboard permanent
	local bb, label = creerBillboardPermanent(pd.part, COULEUR_DEFAUT)
	pd.bb    = bb
	pd.label = label
end

-- ============================================================
-- Billboard de compteur (affiché pendant le décompte)
-- ============================================================

-- Crée le billboard countdown sur une Part dédiée en hauteur
-- Retourne (billboard, labelCompteur, partCompteur)  — détruire les 3 après usage
local function creerCompteurBillboard(spawnPos, typeConfig, typeNom)
	-- Part invisible dédiée : positionnée au-dessus du sol pour que le billboard soit visible
	local hauteur     = (_GameConfig.AnimationConfig and _GameConfig.AnimationConfig.timerHauteurY) or 8
	local studsOffset = (_GameConfig.AnimationConfig and _GameConfig.AnimationConfig.timerStudsOffset) or 5

	local partCompteur = Instance.new("Part")
	partCompteur.Name         = "CompteurPart"
	partCompteur.Size         = Vector3.new(1, 1, 1)
	partCompteur.Position     = Vector3.new(spawnPos.X, spawnPos.Y + hauteur, spawnPos.Z)
	partCompteur.Anchored     = true
	partCompteur.CanCollide   = false
	partCompteur.Transparency = 1
	partCompteur.Parent       = Workspace

	local bb = Instance.new("BillboardGui")
	bb.Name        = "CompteurBillboard"
	bb.Size        = UDim2.new(0, 200, 0, 80)
	bb.StudsOffset = Vector3.new(0, studsOffset, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 100
	bb.Adornee     = partCompteur
	bb.Parent      = partCompteur

	local cadre = Instance.new("Frame")
	cadre.Size                   = UDim2.new(1, 0, 1, 0)
	cadre.BackgroundColor3       = typeConfig.couleur
	cadre.BackgroundTransparency = 0.35
	cadre.BorderSizePixel        = 0
	cadre.Parent                 = bb

	local coin = Instance.new("UICorner")
	coin.CornerRadius = UDim.new(0, 10)
	coin.Parent       = cadre

	local labelType = Instance.new("TextLabel")
	labelType.Size                   = UDim2.new(1, 0, 0.5, 0)
	labelType.Position               = UDim2.new(0, 0, 0, 0)
	labelType.BackgroundTransparency = 1
	labelType.Text                   = typeConfig.emoji .. " " .. typeNom
	labelType.Font                   = Enum.Font.GothamBold
	labelType.TextColor3             = Color3.new(1, 1, 1)
	labelType.TextScaled             = true
	labelType.Parent                 = cadre

	local labelCompteur = Instance.new("TextLabel")
	labelCompteur.Name                   = "Compteur"
	labelCompteur.Size                   = UDim2.new(1, 0, 0.5, 0)
	labelCompteur.Position               = UDim2.new(0, 0, 0.5, 0)
	labelCompteur.BackgroundTransparency = 1
	labelCompteur.Text                   = "..."
	labelCompteur.Font                   = Enum.Font.GothamBold
	labelCompteur.TextColor3             = Color3.new(1, 1, 0) -- jaune vif
	labelCompteur.TextScaled             = true
	labelCompteur.Parent                 = cadre

	return bb, labelCompteur, partCompteur
end

-- ============================================================
-- Fade in / Fade out pour les Brain Rots de la ZoneCommune
-- ============================================================

local function fadeIn(parts, duree)
	-- Mémoriser les transparences originales avant de tout cacher
	local originales = {}
	for _, part in ipairs(parts) do
		originales[part] = part.Transparency
		part.Transparency = 1
		part.CanCollide   = false
	end
	task.delay(0.1, function()
		local info = TweenInfo.new(duree or 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		for _, part in ipairs(parts) do
			if part and part.Parent then
				-- Restaurer la transparence d'origine (pas forcer 0)
				TweenService:Create(part, info, { Transparency = originales[part] or 0 }):Play()
			end
		end
	end)
end

local function fadeOut(parts, duree, callback)
	local info = TweenInfo.new(duree or 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, part in ipairs(parts) do
		if part and part.Parent then
			TweenService:Create(part, info, { Transparency = 1 }):Play()
		end
	end
	if callback then
		task.delay((duree or 0.4) + 0.1, callback)
	end
end

-- ============================================================
-- Spawn d'un Brain Rot au point de spawn donné
-- onFin(player, collecte, nomModele)
--   player    = Player si collecté, nil si despawn
--   collecte  = true/false
--   nomModele = nom du modèle (toujours fourni)
-- ============================================================

local function spawnerBrainRot(typeNom, typeConfig, pointIdx, modeleSource, onFin)
	local spawnPos = SPAWN_POINTS[pointIdx]
	local pd       = pointsData[pointIdx]
	if not spawnPos or not pd then
		onFin(nil, false, typeNom)
		return
	end

	-- Cloner le modèle
	local clone
	local ok, err = pcall(function()
		clone = modeleSource:Clone()
	end)
	if not ok or not clone then
		warn("[CommunSpawner] Erreur clonage : " .. tostring(err))
		onFin(nil, false, modeleSource.Name)
		return
	end

	idCounter  = idCounter + 1
	clone.Name = string.format("CC_%s_%d", typeNom, idCounter)
	clone.Parent = Workspace

	local racine = obtenirRacine(clone)
	if not racine then
		clone:Destroy()
		onFin(nil, false, modeleSource.Name)
		return
	end

	-- Positionner
	pcall(function()
		if clone.PrimaryPart then
			clone:PivotTo(CFrame.new(spawnPos.X, spawnPos.Y, spawnPos.Z))
		else
			racine.CFrame = CFrame.new(spawnPos.X, spawnPos.Y, spawnPos.Z)
		end
	end)

	local parts = obtenirBaseParts(clone)
	fadeIn(parts, 0.6)

	-- ── Billboard sur le Brain Rot ────────────────────────────
	local brBB = Instance.new("BillboardGui")
	brBB.Name        = "BR_Label"
	brBB.Size        = UDim2.new(0, 220, 0, 75)
	brBB.StudsOffset = Vector3.new(0, 10, 0)
	brBB.AlwaysOnTop = false
	brBB.Adornee     = racine
	brBB.Parent      = racine

	local brCadre = Instance.new("Frame")
	brCadre.Size                   = UDim2.new(1, 0, 1, 0)
	brCadre.BackgroundColor3       = typeConfig.couleur
	brCadre.BackgroundTransparency = 0.3
	brCadre.BorderSizePixel        = 0
	brCadre.Parent                 = brBB

	Instance.new("UICorner", brCadre).CornerRadius = UDim.new(0, 8)

	local brLabel = Instance.new("TextLabel")
	brLabel.Size                   = UDim2.new(1, 0, 0.6, 0)
	brLabel.BackgroundTransparency = 1
	brLabel.Text                   = typeConfig.emoji .. " " .. typeNom .. " · " .. modeleSource.Name
	brLabel.Font                   = Enum.Font.GothamBold
	brLabel.TextColor3             = Color3.new(1, 1, 1)
	brLabel.TextScaled             = true
	brLabel.Parent                 = brCadre

	local stroke = Instance.new("UIStroke")
	stroke.Color     = Color3.new(0, 0, 0)
	stroke.Thickness = 1.5
	stroke.Parent    = brLabel

	-- Timer "avant disparition"
	local labelTimer = Instance.new("TextLabel")
	labelTimer.Size                   = UDim2.new(1, 0, 0.4, 0)
	labelTimer.Position               = UDim2.new(0, 0, 0.6, 0)
	labelTimer.BackgroundTransparency = 1
	labelTimer.Font                   = Enum.Font.GothamBold
	labelTimer.TextColor3             = Color3.new(1, 1, 0)
	labelTimer.TextScaled             = true
	labelTimer.Text                   = "⏳ " .. typeConfig.despawnSecondes .. "s"
	labelTimer.Parent                 = brCadre

	local strokeTimer = Instance.new("UIStroke")
	strokeTimer.Color     = Color3.new(0, 0, 0)
	strokeTimer.Thickness = 1.5
	strokeTimer.Parent    = labelTimer

	-- ── ProximityPrompt via CarrySystem ───────────────────────
	local collected = false

	-- Countdown "avant disparition" — mis à jour chaque seconde
	task.spawn(function()
		local restant = typeConfig.despawnSecondes
		while not collected and restant > 0 and labelTimer and labelTimer.Parent do
			task.wait(1)
			restant = restant - 1
			if labelTimer and labelTimer.Parent then
				if restant <= 10 then
					labelTimer.TextColor3 = Color3.new(1, 0.2, 0.2) -- rouge urgent
				end
				labelTimer.Text = "⏳ " .. restant .. "s"
			end
		end
	end)

	-- Appeler le hook OnBRSpawned pour créer le ProximityPrompt via CarrySystem
	if CommunSpawner.OnBRSpawned then
		pcall(CommunSpawner.OnBRSpawned, clone, typeNom, function(player)
			if collected then return end
			collected = true
			onFin(player, true, modeleSource.Name)
		end)
	end

	-- ── Despawn automatique ───────────────────────────────────
	task.delay(typeConfig.despawnSecondes, function()
		if collected then return end
		if not clone or not clone.Parent then return end
		collected = true
		fadeOut(parts, 0.5, function()
			if clone and clone.Parent then clone:Destroy() end
		end)
		onFin(nil, false, modeleSource.Name)
	end)
end

-- ============================================================
-- Scheduler générique (synchrone, 1 par type)
-- ============================================================

local function lancerScheduler(typeNom)
	local cfg = CONFIG[typeNom]
	if not cfg then return end

	local function estActif()
		return typeNom == "MYTHIC" and actifMythic or actifSecret
	end
	local function setActif(v)
		if typeNom == "MYTHIC" then actifMythic = v else actifSecret = v end
	end

	task.spawn(function()
		-- Décalage initial pour éviter que MYTHIC et SECRET spawnent en même temps
		local decalage = typeNom == "SECRET" and 60 or 0
		if decalage > 0 then task.wait(decalage) end

		while true do
			-- ── Phase 1 : attente silencieuse ──────────────────────
			-- spawnMultiplier réduit l'intervalle (ex: Rain Event ×3 → 3× plus fréquent)
			local intervalleEffectif = math.max(
				cfg.compteurVisibleAvant + 30,
				cfg.intervalleSecondes / math.max(1, spawnMultiplier)
			)
			-- Enregistrer le moment prévu du spawn (lu par GetProchainSpawn)
			prochainSpawnTime[typeNom]  = os.time() + intervalleEffectif
			prochainSpawnPoint[typeNom] = nil  -- point pas encore choisi

			local attenteAvantCompteur = intervalleEffectif - cfg.compteurVisibleAvant
			task.wait(math.max(1, attenteAvantCompteur))

			-- Verrouiller le slot (garde-fou si latence)
			if estActif() then task.wait(5) continue end
			setActif(true)

			-- Choisir un point de spawn aléatoire
			local pointIdx = math.random(1, #SPAWN_POINTS)
			prochainSpawnPoint[typeNom] = pointIdx

			-- ── Phase 2 : alerte + compteur ───────────────────────
			passerEnModeAlerte(pointIdx, cfg.couleur)

			-- Notification joueurs
			notifierTous("ALERT", string.format(
				"%s %s spawns in %s in the Common Field!",
				cfg.emoji, typeNom, formatTemps(cfg.compteurVisibleAvant)
			))

			-- Notification Discord (SECRET uniquement au compteur)
			if typeNom == "SECRET" then
				pcall(function()
					DiscordWebhook.Envoyer(
						"🔴 SECRET incoming",
						string.format(
							"Un Brain Rot SECRET apparaîtra dans %s sur la ZoneCommune !",
							formatTemps(cfg.compteurVisibleAvant)
						),
						cfg.couleurHex
					)
				end)
			end

			-- Créer le billboard de compteur (Part dédiée en hauteur pour visibilité)
			local spawnPos = SPAWN_POINTS[pointIdx]
			local compteurBB, labelCompteur, partCompteur = creerCompteurBillboard(spawnPos, cfg, typeNom)

			-- Décompte synchrone — mis à jour chaque seconde
			for restant = cfg.compteurVisibleAvant, 1, -1 do
				if labelCompteur and labelCompteur.Parent then
					labelCompteur.Text = formatTemps(restant)
				end
				task.wait(1)
			end

			-- Supprimer le billboard compteur ET la Part dédiée
			if compteurBB and compteurBB.Parent then
				compteurBB:Destroy()
			end
			if partCompteur and partCompteur.Parent then
				partCompteur:Destroy()
			end

			-- ── Phase 3 : spawn du Brain Rot ──────────────────────
			local modeleSource = choisirModele(cfg.dossier)
			if not modeleSource then
				-- Aucun modèle dispo → passer le cycle
				warn("[CommunSpawner] Aucun modèle pour " .. typeNom .. ", cycle ignoré")
				setActif(false)
				restaurerEtatsDefaut(pointIdx)
				continue
			end

			-- Notifier l'apparition
			notifierTous("RARE", string.format(
				"%s %s [%s] has appeared! Rush to the Common Field!",
				cfg.emoji, typeNom, modeleSource.Name
			))

			-- Discord au spawn (SECRET uniquement)
			if typeNom == "SECRET" then
				pcall(function()
					DiscordWebhook.Envoyer(
						"🔴 SECRET apparu !",
						string.format(
							"Un Brain Rot SECRET **%s** vient d'apparaître sur la ZoneCommune !",
							modeleSource.Name
						),
						cfg.couleurHex
					)
				end)
			end

			-- ── Phase 4 : attendre résolution (collecte ou despawn) ─
			local resolu         = false
			local playerCollecte = nil
			local collecte       = false
			local nomModele      = modeleSource.Name

			spawnerBrainRot(typeNom, cfg, pointIdx, modeleSource, function(player, didCollect, nom)
				playerCollecte = player
				collecte       = didCollect
				nomModele      = nom or nomModele
				resolu         = true
			end)

			-- Polling (bloque le scheduler jusqu'à résolution)
			while not resolu do
				task.wait(1)
			end

			-- ── Phase 5 : post-résolution ──────────────────────────
			setActif(false)
			restaurerEtatsDefaut(pointIdx)

			if collecte and playerCollecte then
				-- Notif victoire
				notifierTous("RARE", string.format(
					"🏆 %s grabbed the %s [%s]!",
					playerCollecte.Name, nomModele, typeNom
				))

				-- Discord collecte (SECRET uniquement)
				if typeNom == "SECRET" then
					pcall(function()
						DiscordWebhook.Envoyer(
							"🏆 SECRET collecté !",
							string.format(
								"**%s** a attrapé le Brain Rot SECRET **%s** !",
								playerCollecte.Name, nomModele
							),
							cfg.couleurHex
						)
					end)
				end

				-- Callback principal (gestion coins dans Main.server.lua)
				if CommunSpawner.OnCollecte then
					pcall(CommunSpawner.OnCollecte, playerCollecte, typeNom)
				end

				-- Notifier LeaderboardSystem (DernierRare affiché dans Leaderboard2)
				local LBS = getLeaderboardSystem()
				if LBS and LBS.EnregistrerRare then
					pcall(LBS.EnregistrerRare, playerCollecte, typeNom)
				end
			else
				-- BR expiré sans être collecté
				notifierTous("INFO", string.format(
					"%s disappeared...", nomModele
				))
			end

			-- La boucle repart : task.wait(attenteAvantCompteur) au prochain tour
		end
	end)
end

-- ============================================================
-- API publique
-- ============================================================

-- Callback collecte — à assigner depuis Main.server.lua :
-- CommunSpawner.OnCollecte = function(player, rarete) end
CommunSpawner.OnCollecte = nil

-- Hook ProximityPrompt — à assigner depuis Main.server.lua :
-- CommunSpawner.OnBRSpawned = function(clone, typeNom, onCapture) end
CommunSpawner.OnBRSpawned = nil

-- Retourne le temps restant avant le prochain spawn d'un type donné
-- typeNom = "MYTHIC" | "SECRET"
-- Retourne { tempsRestant = secondes (0 si spawn imminent/passé), point = "A"|"B"|"C"|nil }
function CommunSpawner.GetProchainSpawn(typeNom)
    local t = prochainSpawnTime[typeNom]
    if not t then
        return { tempsRestant = -1, point = nil }
    end
    local restant = math.max(0, t - os.time())
    local lettres = { "A", "B", "C" }
    local pointLettre = prochainSpawnPoint[typeNom] and lettres[prochainSpawnPoint[typeNom]] or nil
    return { tempsRestant = restant, point = pointLettre }
end

-- Modifie le multiplicateur de spawn (appelé par Rain Event)
-- mult = 1 → vitesse normale, mult = 3 → 3× plus fréquent
function CommunSpawner.SetMultiplier(mult)
    spawnMultiplier = math.max(1, mult or 1)
    print("[CommunSpawner] Multiplicateur spawn : ×" .. spawnMultiplier)
end

function CommunSpawner.Init()
	initialiserEffetsPermanents()
	lancerScheduler("MYTHIC")
	lancerScheduler("SECRET")
	print("[CommunSpawner] ✓ Schedulers MYTHIC et SECRET démarrés")
end

return CommunSpawner
