-- ServerScriptService/ChampCommunSpawner.lua
-- BrainRotFarm — Spawn MYTHIC et SECRET dans le ChampCommun
-- COMMON/OG/RARE/EPIC/LEGENDARY/BRAINROT_GOD = réservés aux champs individuels

local ChampCommunSpawner = {}

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
-- Dépendances
-- ============================================================
local DiscordWebhook = require(ServerScriptService:WaitForChild("DiscordWebhook"))

-- ============================================================
-- Points de spawn fixes
-- ============================================================
local SPAWN_POINTS = {
	{ x = 190.92,  y = 16.189, z =   66.30 }, -- Point A
	{ x = 250.93,  y = 16.189, z =  -80.20 }, -- Point B
	{ x = 189.51,  y = 16.189, z = -241.28 }, -- Point C
}

-- ============================================================
-- Configuration des raretés
-- ============================================================
local CONFIG = {
	MYTHIC = {
		intervalleSecondes   = 480,
		compteurVisibleAvant = 180,
		valeur               = 300,
		despawnSecondes      = 60,
		couleur              = Color3.fromRGB(148, 0, 211),
		couleurHex           = 9699539,  -- 0x9400D3
		emoji                = "⚠️",
		dossier              = "MYTHIC",
	},
	SECRET = {
		intervalleSecondes   = 1200,
		compteurVisibleAvant = 300,
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
local actifMythic = false
local actifSecret = false
local idCounter   = 0

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
	print("[ChampCommun] " .. message)
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
		warn("[ChampCommunSpawner] Dossier introuvable : " .. nomDossier)
		return nil
	end
	local modeles = dossier:GetChildren()
	if #modeles == 0 then
		warn("[ChampCommunSpawner] Dossier vide : " .. nomDossier)
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
-- Effets permanents sur les 3 points de spawn
-- ============================================================

-- Lance la pulsation infinie du PointLight
local function lancerPulsationLight(light)
	task.spawn(function()
		local infoMonte  = TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
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
	bb.StudsOffset = Vector3.new(0, 6, 0)
	bb.AlwaysOnTop = false
	bb.Adornee     = part
	bb.Parent      = part

	local cadre = Instance.new("Frame")
	cadre.Size                = UDim2.new(1, 0, 1, 0)
	cadre.BackgroundColor3    = couleur
	cadre.BackgroundTransparency = 0.6
	cadre.BorderSizePixel     = 0
	cadre.Parent              = bb

	local coin = Instance.new("UICorner")
	coin.CornerRadius = UDim.new(0, 6)
	coin.Parent       = cadre

	local label = Instance.new("TextLabel")
	label.Size                   = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text                   = "✨ Zone Mystérieuse"
	label.Font                   = Enum.Font.GothamBold
	label.TextColor3             = Color3.new(1, 1, 1)
	label.TextScaled             = true
	label.Parent                 = cadre

	return bb, label
end

-- Initialise les effets permanents sur les 3 points dès Init()
local function initialiserEffetsPermanents()
	for i, pt in ipairs(SPAWN_POINTS) do
		local position = Vector3.new(pt.x, pt.y, pt.z)

		-- Part invisible permanente (ancre pour les effets)
		local part = Instance.new("Part")
		part.Name         = "ChampCommun_Point_" .. i
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

		print(string.format("[ChampCommunSpawner] Point %d initialisé (%.1f, %.1f, %.1f)", i, pt.x, pt.y, pt.z))
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

-- Crée le billboard countdown sur le point de spawn
-- Retourne (billboard, labelCompteur)
local function creerCompteurBillboard(part, typeConfig, typeNom)
	local bb = Instance.new("BillboardGui")
	bb.Name        = "CompteurBillboard"
	bb.Size        = UDim2.new(0, 200, 0, 80)
	bb.StudsOffset = Vector3.new(0, 5, 0)
	bb.AlwaysOnTop = false
	bb.Adornee     = part
	bb.Parent      = part

	local cadre = Instance.new("Frame")
	cadre.Size                = UDim2.new(1, 0, 1, 0)
	cadre.BackgroundColor3    = typeConfig.couleur
	cadre.BackgroundTransparency = 0.35
	cadre.BorderSizePixel     = 0
	cadre.Parent              = bb

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

	return bb, labelCompteur
end

-- ============================================================
-- Fade in / Fade out pour les Brain Rots du ChampCommun
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
	local pt = SPAWN_POINTS[pointIdx]
	local pd = pointsData[pointIdx]
	if not pt or not pd then
		onFin(nil, false, typeNom)
		return
	end

	-- Cloner le modèle
	local clone
	local ok, err = pcall(function()
		clone = modeleSource:Clone()
	end)
	if not ok or not clone then
		warn("[ChampCommunSpawner] Erreur clonage : " .. tostring(err))
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
			clone:PivotTo(CFrame.new(pt.x, pt.y, pt.z))
		else
			racine.CFrame = CFrame.new(pt.x, pt.y, pt.z)
		end
	end)

	local parts = obtenirBaseParts(clone)
	fadeIn(parts, 0.6)

	-- ── Billboard sur le Brain Rot ────────────────────────────
	local brBB = Instance.new("BillboardGui")
	brBB.Name        = "BR_Label"
	brBB.Size        = UDim2.new(0, 220, 0, 55)
	brBB.StudsOffset = Vector3.new(0, 4, 0)
	brBB.AlwaysOnTop = false
	brBB.Adornee     = racine
	brBB.Parent      = racine

	local brCadre = Instance.new("Frame")
	brCadre.Size                = UDim2.new(1, 0, 1, 0)
	brCadre.BackgroundColor3    = typeConfig.couleur
	brCadre.BackgroundTransparency = 0.3
	brCadre.BorderSizePixel     = 0
	brCadre.Parent              = brBB

	Instance.new("UICorner", brCadre).CornerRadius = UDim.new(0, 8)

	local brLabel = Instance.new("TextLabel")
	brLabel.Size                   = UDim2.new(1, 0, 1, 0)
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

	-- ── Touch detection (premier à toucher gagne) ─────────────
	local collected = false

	local function onTouched(hit)
		if collected then return end

		local character = hit.Parent
		local player    = Players:GetPlayerFromCharacter(character)
		if not player then
			character = hit.Parent and hit.Parent.Parent
			player    = character and Players:GetPlayerFromCharacter(character)
		end
		if not player then return end

		collected = true
		fadeOut(parts, 0.3, function()
			if clone and clone.Parent then clone:Destroy() end
		end)

		onFin(player, true, modeleSource.Name)
	end

	for _, part in ipairs(parts) do
		part.Touched:Connect(onTouched)
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
			local attenteAvantCompteur = cfg.intervalleSecondes - cfg.compteurVisibleAvant
			task.wait(math.max(1, attenteAvantCompteur))

			-- Verrouiller le slot (garde-fou si latence)
			if estActif() then task.wait(5) continue end
			setActif(true)

			-- Choisir un point de spawn aléatoire
			local pointIdx = math.random(1, #SPAWN_POINTS)
			local pd       = pointsData[pointIdx]

			-- ── Phase 2 : alerte + compteur ───────────────────────
			passerEnModeAlerte(pointIdx, cfg.couleur)

			-- Notification joueurs
			notifierTous("ALERT", string.format(
				"%s %s apparaît dans %s au ChampCommun !",
				cfg.emoji, typeNom, formatTemps(cfg.compteurVisibleAvant)
			))

			-- Notification Discord (SECRET uniquement au compteur)
			if typeNom == "SECRET" then
				pcall(function()
					DiscordWebhook.Envoyer(
						"🔴 SECRET incoming",
						string.format(
							"Un Brain Rot SECRET apparaîtra dans %s sur le ChampCommun !",
							formatTemps(cfg.compteurVisibleAvant)
						),
						cfg.couleurHex
					)
				end)
			end

			-- Créer le billboard de compteur
			local compteurBB, labelCompteur = creerCompteurBillboard(pd.part, cfg, typeNom)

			-- Décompte synchrone — mis à jour chaque seconde
			for restant = cfg.compteurVisibleAvant, 1, -1 do
				if labelCompteur and labelCompteur.Parent then
					labelCompteur.Text = formatTemps(restant)
				end
				task.wait(1)
			end

			-- Supprimer le billboard compteur
			if compteurBB and compteurBB.Parent then
				compteurBB:Destroy()
			end

			-- ── Phase 3 : spawn du Brain Rot ──────────────────────
			local modeleSource = choisirModele(cfg.dossier)
			if not modeleSource then
				-- Aucun modèle dispo → passer le cycle
				warn("[ChampCommunSpawner] Aucun modèle pour " .. typeNom .. ", cycle ignoré")
				setActif(false)
				restaurerEtatsDefaut(pointIdx)
				continue
			end

			-- Notifier l'apparition
			notifierTous("RARE", string.format(
				"%s %s [%s] est apparu ! Foncez au ChampCommun !",
				cfg.emoji, typeNom, modeleSource.Name
			))

			-- Discord au spawn (SECRET uniquement)
			if typeNom == "SECRET" then
				pcall(function()
					DiscordWebhook.Envoyer(
						"🔴 SECRET apparu !",
						string.format(
							"Un Brain Rot SECRET **%s** vient d'apparaître sur le ChampCommun !",
							modeleSource.Name
						),
						cfg.couleurHex
					)
				end)
			end

			-- ── Phase 4 : attendre résolution (collecte ou despawn) ─
			local resolu        = false
			local playerCollecte = nil
			local collecte      = false
			local nomModele     = modeleSource.Name

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
					"🏆 %s a attrapé le %s [%s] !",
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
				if ChampCommunSpawner.OnCollecte then
					pcall(ChampCommunSpawner.OnCollecte, playerCollecte, typeNom)
				end
			else
				-- BR expiré sans être collecté
				notifierTous("INFO", string.format(
					"Le %s a disparu...", nomModele
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
-- ChampCommunSpawner.OnCollecte = function(player, rarete) end
ChampCommunSpawner.OnCollecte = nil

function ChampCommunSpawner.Init()
	initialiserEffetsPermanents()
	lancerScheduler("MYTHIC")
	lancerScheduler("SECRET")
	print("[ChampCommunSpawner] ✓ Schedulers MYTHIC et SECRET démarrés")
end

return ChampCommunSpawner
