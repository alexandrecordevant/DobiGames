-- ServerScriptService/BaseProgressionSystem.lua
-- Déblocage progressif des étages et spots — config lue depuis GameConfig
-- Compatible multi-jeu : tous les paramètres viennent de GameConfig.ProgressionConfig

local BaseProgressionSystem = {}

-- ============================================================
-- Services
-- ============================================================
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

-- ============================================================
-- Config depuis GameConfig
-- ============================================================
-- Cherche GameConfig à la racine de ReplicatedStorage (nouveau standard)
-- Fallback sur Specialized.GameConfig pour compatibilité anciens projets
local Config = require(
    game.ReplicatedStorage:FindFirstChild("GameConfig")
    or game.ReplicatedStorage.Specialized.GameConfig
)
local ProgConfig = Config.ProgressionConfig

local SEUILS = ProgConfig.seuils
local FLOORS = ProgConfig.floors  -- { index, nom, type, spots }

-- Retourne le nom Studio d'un floor à partir de son index
local function GetFloorNom(index)
	for _, f in ipairs(FLOORS) do
		if f.index == index then return f.nom end
	end
	return "Floor_" .. tostring(index)
end

-- ============================================================
-- Lazy loaders (évitent les dépendances circulaires)
-- ============================================================
local _CarrySystem = nil
local function getCarrySystem()
    if not _CarrySystem then
        local ok, m = pcall(require, game:GetService("ServerScriptService").SharedLib.Server.CarrySystem)
        if ok and m then _CarrySystem = m end
    end
    return _CarrySystem
end

local _DropSystem = nil
local function getDropSystem()
    if not _DropSystem then
        local ok, m = pcall(require, game:GetService("ServerScriptService").SharedLib.Server.DropSystem)
        if ok and m then _DropSystem = m end
    end
    return _DropSystem
end

-- Crée le DepotPrompt + met à jour spotIndex pour un spot nouvellement débloqué (runtime)
-- Ne pas appeler pendant Init (CarrySystem.InitDepotSpotsBase s'en charge en masse)
local function activerDepotSpot(player, spotObj, spotKey)
    local touchPart = spotObj:FindFirstChild("TouchPart")
    if touchPart and not touchPart:IsA("BasePart") then touchPart = nil end
    if not touchPart then
        touchPart = spotObj:IsA("BasePart") and spotObj
                 or spotObj:FindFirstChild("Part")
                 or (spotObj:IsA("Model") and spotObj.PrimaryPart)
                 or spotObj:FindFirstChildWhichIsA("BasePart")
    end
    if not touchPart then
        warn("[BaseProgressionSystem] activerDepotSpot : aucune Part dans " .. spotObj.Name)
        return
    end

    -- Mettre à jour le spotIndex de DropSystem (sinon DeposerBrainRots rejette le spot)
    local DS = getDropSystem()
    if DS then pcall(DS.AjouterSpotIndex, player, spotKey, touchPart) end

    -- Créer le ProximityPrompt de dépôt via CarrySystem
    local CS = getCarrySystem()
    if CS then pcall(CS.AjouterDepotSpot, player, touchPart) end

    print(string.format("[BaseProgressionSystem] DepotPrompt créé : %s (spot %s)", spotObj.Name, spotKey))
end

-- ============================================================
-- État interne par joueur
-- ============================================================
-- { baseIndex, playerData, progression, spotsActifs, baseFolder }
local donneesJoueurs = {}

-- ============================================================
-- Utilitaires
-- ============================================================

-- BaseParts de la structure d'un floor (hors spot_X)
local function obtenirPartsStructure(floorObj)
	local parts = {}
	-- Floor 1 est lui-même une BasePart
	if floorObj:IsA("BasePart") then
		table.insert(parts, floorObj)
	end
	for _, child in ipairs(floorObj:GetChildren()) do
		if not child.Name:match("^spot_") then
			if child:IsA("BasePart") then
				table.insert(parts, child)
			end
			for _, v in ipairs(child:GetDescendants()) do
				if v:IsA("BasePart") then table.insert(parts, v) end
			end
		end
	end
	return parts
end

-- Tous les BaseParts d'un spot (inclut TouchPart et Part visuel)
local function obtenirPartsSpot(spotModel)
	local parts = {}
	for _, v in ipairs(spotModel:GetDescendants()) do
		if v:IsA("BasePart") then table.insert(parts, v) end
	end
	if spotModel:IsA("BasePart") then table.insert(parts, spotModel) end
	return parts
end

-- Ajoute un TouchPart à spotsActifs sans doublon
local function ajouterSpotActif(spotsActifs, touchPart)
	for _, tp in ipairs(spotsActifs) do
		if tp == touchPart then return end
	end
	table.insert(spotsActifs, touchPart)
end

-- Retire un TouchPart de spotsActifs
local function retirerSpotActif(spotsActifs, touchPart)
	for i, tp in ipairs(spotsActifs) do
		if tp == touchPart then
			table.remove(spotsActifs, i)
			return
		end
	end
end

-- Normalise un nom pour comparaison tolérante (espaces/underscore/casse ignorés)
local function normaliserNom(nom)
	if type(nom) ~= "string" then return "" end
	return string.lower((nom:gsub("[%s_%-]", "")))
end

-- Recherche d'un floor avec fallback tolérant (exact, direct child, descendants)
local function trouverFloor(baseFolder, floorNum)
	if not baseFolder then return nil end

	local nomExact = GetFloorNom(floorNum)
	if nomExact then
		local direct = baseFolder:FindFirstChild(nomExact)
		if direct then return direct end
	end

	-- Compatibilité: "Floor1", "Floor_1", "floor 1", etc.
	local cible = "floor" .. tostring(floorNum)
	for _, child in ipairs(baseFolder:GetChildren()) do
		if normaliserNom(child.Name) == cible then
			return child
		end
	end
	for _, desc in ipairs(baseFolder:GetDescendants()) do
		if normaliserNom(desc.Name) == cible then
			return desc
		end
	end
	return nil
end

-- Recherche d'un spot avec fallback tolérant (spot_1, Spot 1, spot-1, etc.)
local function trouverSpot(floorObj, spotNum)
	if not floorObj then return nil end

	local nomExact = "spot_" .. tostring(spotNum)
	local direct = floorObj:FindFirstChild(nomExact)
	if direct then return direct end

	local cible = "spot" .. tostring(spotNum)
	for _, child in ipairs(floorObj:GetChildren()) do
		if normaliserNom(child.Name) == cible then
			return child
		end
	end
	for _, desc in ipairs(floorObj:GetDescendants()) do
		if normaliserNom(desc.Name) == cible then
			return desc
		end
	end
	return nil
end

-- Score un conteneur de base selon le nombre de floors/spots détectés.
-- Permet de choisir automatiquement la bonne racine visuelle (Base_1 ou Base_1/Base).
local function scorerConteneurBase(container)
	if not container then
		return -1, 0, 0
	end
	local floorsTrouves = 0
	local spotsTrouves = 0
	for _, floorDef in ipairs(FLOORS) do
		local floorObj = trouverFloor(container, floorDef.index)
		if floorObj then
			floorsTrouves += 1
			for spotNum = 1, (floorDef.spots or 10) do
				if trouverSpot(floorObj, spotNum) then
					spotsTrouves += 1
				end
			end
		end
	end
	-- Priorité au nombre de spots, puis floors
	return (spotsTrouves * 100 + floorsTrouves), floorsTrouves, spotsTrouves
end

-- Notifications
local function notifierJoueur(player, typeNotif, message)
	local ev = ReplicatedStorage:FindFirstChild("NotifEvent")
	if ev then pcall(function() ev:FireClient(player, typeNotif, message) end) end
end

local function notifierTous(typeNotif, message)
	local ev = ReplicatedStorage:FindFirstChild("NotifEvent")
	if ev then pcall(function() ev:FireAllClients(typeNotif, message) end) end
	print("[BaseProgression] " .. message)
end

-- ============================================================
-- Réduction des seuils par rebirth (optionnel)
-- ============================================================

-- Formate un entier avec séparateurs de milliers (ex: 12000 → "12 000")
local function formaterNombre(n)
	local s      = tostring(math.floor(n))
	local result = ""
	local count  = 0
	for i = #s, 1, -1 do
		if count > 0 and count % 3 == 0 then result = " " .. result end
		result = s:sub(i, i) .. result
		count  = count + 1
	end
	return result
end

-- Retourne un seuil avec coût réduit selon le niveau rebirth du joueur
-- Réduction : -Config.RebirthFloorDiscount par rebirth, plafonnée à -90%
-- Si la config ne définit pas de réduction, ou rebirthLevel = 0, retourne le seuil inchangé
local function obtenirSeuilEffectif(seuil, rebirthLevel)
	local discount = Config.RebirthFloorDiscount
	if not discount or discount <= 0 then return seuil end
	if not rebirthLevel or rebirthLevel <= 0 then return seuil end
	if seuil.coins <= 0 then return seuil end  -- Seuils gratuits inchangés

	local reduction   = math.min(rebirthLevel * discount, 0.90)
	local coinsReduit = math.floor(seuil.coins * (1 - reduction))
	local pct         = math.floor(reduction * 100)

	return {
		floor = seuil.floor,
		spot  = seuil.spot,
		coins = coinsReduit,
		label = formaterNombre(coinsReduit) .. " coins (-" .. pct .. "%)",
	}
end

-- ============================================================
-- Visuels — billboard de verrouillage
-- ============================================================

local function creerBillboardLock(spotModel, label)
	-- Chercher la Part de référence pour l'ancre
	local ancre = spotModel:FindFirstChild("TouchPart")
	if not ancre then ancre = spotModel:FindFirstChildWhichIsA("BasePart") end
	if not ancre then return end

	-- Supprimer l'ancien billboard si présent
	local ancien = ancre:FindFirstChild("LockBillboard")
	if ancien then ancien:Destroy() end

	local bb = Instance.new("BillboardGui")
	bb.Name        = "LockBillboard"
	bb.Size        = UDim2.new(0, 160, 0, 60)
	bb.StudsOffset = Vector3.new(0, 4, 0)
	bb.AlwaysOnTop = false
	bb.Adornee     = ancre
	bb.Parent      = ancre

	local cadre = Instance.new("Frame")
	cadre.Size                   = UDim2.new(1, 0, 1, 0)
	cadre.BackgroundColor3       = Color3.fromRGB(80, 0, 0)
	cadre.BackgroundTransparency = 0.3
	cadre.BorderSizePixel        = 0
	cadre.Parent                 = bb

	Instance.new("UICorner", cadre).CornerRadius = UDim.new(0, 6)

	local lblLock = Instance.new("TextLabel")
	lblLock.Size                   = UDim2.new(1, 0, 0.5, 0)
	lblLock.Position               = UDim2.new(0, 0, 0, 0)
	lblLock.BackgroundTransparency = 1
	lblLock.Text                   = "🔒 Locked"
	lblLock.Font                   = Enum.Font.GothamBold
	lblLock.TextColor3             = Color3.new(1, 1, 1)
	lblLock.TextScaled             = true
	lblLock.Parent                 = cadre

	local lblCoins = Instance.new("TextLabel")
	lblCoins.Size                   = UDim2.new(1, 0, 0.5, 0)
	lblCoins.Position               = UDim2.new(0, 0, 0.5, 0)
	lblCoins.BackgroundTransparency = 1
	lblCoins.Text                   = "💰 " .. tostring(label or "?")
	lblCoins.Font                   = Enum.Font.GothamBold
	lblCoins.TextColor3             = Color3.new(1, 1, 1)
	lblCoins.TextScaled             = true
	lblCoins.Parent                 = cadre
end

local function supprimerBillboardLock(spotModel)
	local ancre = spotModel:FindFirstChild("TouchPart")
	if not ancre then ancre = spotModel:FindFirstChildWhichIsA("BasePart") end
	if not ancre then return end
	local bb = ancre:FindFirstChild("LockBillboard")
	if bb then bb:Destroy() end
end

-- ============================================================
-- Visuels — états spot
-- ============================================================

-- Applique l'état verrouillé (semi-transparent, CanTouch=false, billboard)
local function appliquerEtatVerrouille(spotModel, seuil)
	local parts = obtenirPartsSpot(spotModel)
	for _, part in ipairs(parts) do
		pcall(function() part.Transparency = 0.7 end)
	end
	local touchPart = spotModel:FindFirstChild("TouchPart")
	if touchPart then
		pcall(function() touchPart.CanTouch = false end)
	end
	creerBillboardLock(spotModel, seuil.label)
end

-- Applique l'état débloqué (visible, CanTouch=true, pas de billboard)
local function appliquerEtatDebloque(spotModel, spotsActifs)
	local parts = obtenirPartsSpot(spotModel)
	for _, part in ipairs(parts) do
		pcall(function() part.Transparency = 0; part.CanCollide = true end)
	end
	local touchPart = spotModel:FindFirstChild("TouchPart")
	if touchPart then
		pcall(function() touchPart.CanTouch = true end)
		if spotsActifs then
			ajouterSpotActif(spotsActifs, touchPart)
		end
	end
	supprimerBillboardLock(spotModel)
end

-- ============================================================
-- Visuels — gestion d'un étage entier
-- ============================================================

-- Cache tout un étage (floors 2-4 non encore débloqués)
-- Tous les BaseParts → invisible + non-collidable (évite l'interaction avec parties invisibles)
local function cacherEtage(floorObj)
	if floorObj:IsA("BasePart") then
		pcall(function() floorObj.Transparency = 1; floorObj.CanCollide = false end)
	end
	for _, v in ipairs(floorObj:GetDescendants()) do
		if v:IsA("BasePart") then
			pcall(function() v.Transparency = 1; v.CanCollide = false end)
		elseif v:IsA("ProximityPrompt") or v:IsA("ClickDetector") then
			pcall(function() v.Enabled = false end)
		end
	end
end

-- Rend visibles les parts de structure d'un floor (hors spots)
local function afficherStructure(floorObj)
	local partsStructure = obtenirPartsStructure(floorObj)
	for _, part in ipairs(partsStructure) do
		pcall(function() part.Transparency = 0; part.CanCollide = true end)
	end
	-- Réactiver les ProximityPrompts/ClickDetectors de la structure
	for _, v in ipairs(floorObj:GetDescendants()) do
		if not v.Name:match("^spot_") then
			if v:IsA("ProximityPrompt") or v:IsA("ClickDetector") then
				pcall(function() v.Enabled = true end)
			end
		end
	end
end

-- Fade in de la structure d'un étage en 2 secondes
local function fadeInStructure(floorObj, onFin)
	local parts = obtenirPartsStructure(floorObj)
	if #parts == 0 then
		if onFin then task.spawn(onFin) end
		return
	end
	-- Restaurer la collision immédiatement (avant le fade pour éviter le fantôme)
	for _, part in ipairs(parts) do
		pcall(function() part.CanCollide = true end)
	end
	-- Réactiver les ProximityPrompts/ClickDetectors de la structure
	for _, v in ipairs(floorObj:GetDescendants()) do
		if not v.Name:match("^spot_") then
			if v:IsA("ProximityPrompt") or v:IsA("ClickDetector") then
				pcall(function() v.Enabled = true end)
			end
		end
	end
	local tweenInfo = TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local termine   = 0
	local total     = #parts
	for _, part in ipairs(parts) do
		if part and part.Parent then
			local t = TweenService:Create(part, tweenInfo, { Transparency = 0 })
			t.Completed:Connect(function()
				termine += 1
				if termine >= total and onFin then onFin() end
			end)
			t:Play()
		else
			termine += 1
			if termine >= total and onFin then onFin() end
		end
	end
end

-- Particules dorées au déblocage d'un étage
local function effetDeblocageEtage(position)
	local ancre = Instance.new("Part")
	ancre.Anchored     = true
	ancre.CanCollide   = false
	ancre.Transparency = 1
	ancre.Size         = Vector3.new(1, 1, 1)
	ancre.Position     = position
	ancre.Parent       = Workspace

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0,   Color3.fromRGB(255, 215,   0)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 150)),
		ColorSequenceKeypoint.new(1,   Color3.fromRGB(255, 180,   0)),
	})
	emitter.LightEmission = 0.8
	emitter.Rate          = 80
	emitter.Lifetime      = NumberRange.new(1.5, 3)
	emitter.Speed         = NumberRange.new(8, 15)
	emitter.SpreadAngle   = Vector2.new(70, 70)
	emitter.Size          = NumberSequence.new(0.4)
	emitter.Parent        = ancre

	task.delay(3, function()
		emitter.Enabled = false
		task.delay(3, function() ancre:Destroy() end)
	end)
end

-- ============================================================
-- Déblocage d'un étage entier (quand spot=1 d'un floor>1 s'ouvre)
-- ============================================================

local function debloquerEtage(player, dd, floorNum, floorObj)
	-- Fade in de la structure
	fadeInStructure(floorObj, nil)

	-- Particules au centre de l'étage
	local racineFloor = nil
	if floorObj:IsA("BasePart") then
		racineFloor = floorObj
	else
		racineFloor = floorObj:FindFirstChildWhichIsA("BasePart")
	end
	if racineFloor then
		effetDeblocageEtage(racineFloor.Position + Vector3.new(0, 5, 0))
	end

	-- spot_1 → débloqué + DepotPrompt créé
	local spot1 = trouverSpot(floorObj, 1)
	if spot1 then
		appliquerEtatDebloque(spot1, dd.spotsActifs)
		activerDepotSpot(player, spot1, floorNum .. "_1")
	end

	-- spot_2 à spot_10 → verrouillés (maintenant visibles à 0.7) ou déjà débloqués (cascade)
	local rebirthLvl = (dd.playerData and dd.playerData.rebirthLevel) or 0
	for _, seuil in ipairs(SEUILS) do
		if seuil.floor == floorNum and seuil.spot > 1 then
			local spotObj = trouverSpot(floorObj, seuil.spot)
			if spotObj then
				local cle = seuil.floor .. "_" .. seuil.spot
				if dd.progression[cle] then
					-- Déjà débloqué (cas rare : déblocage en cascade)
					appliquerEtatDebloque(spotObj, dd.spotsActifs)
					activerDepotSpot(player, spotObj, cle)
				else
					-- Afficher le prix réduit si le joueur a des rebirths
					appliquerEtatVerrouille(spotObj, obtenirSeuilEffectif(seuil, rebirthLvl))
				end
			end
		end
	end

	-- Notifications
	notifierJoueur(player, "INFO", "🎉 Stage " .. floorNum .. " unlocked!")
	notifierTous("INFO", "🏗️ " .. player.Name .. " unlocked Stage " .. floorNum .. "!")
end

-- ============================================================
-- Déblocage d'un spot individuel
-- ============================================================

local function debloquerSpotIndividuel(player, dd, floorObj, seuil)
	local spotObj = trouverSpot(floorObj, seuil.spot)
	if not spotObj then return end
	appliquerEtatDebloque(spotObj, dd.spotsActifs)
	-- Créer le DepotPrompt et mettre à jour spotIndex (runtime)
	activerDepotSpot(player, spotObj, seuil.floor .. "_" .. seuil.spot)
end

-- ============================================================
-- Vérification des déblocages (appelé à chaque changement de coins)
-- ============================================================

function BaseProgressionSystem.VerifierDeblocages(player, playerData)
	local dd = donneesJoueurs[player.UserId]
	if not dd then return end

	-- Utilise totalCoinsGagnes si baseSurTotalGagne=true, sinon coins courants
	local coinsRef
	if ProgConfig.baseSurTotalGagne then
		coinsRef = playerData.totalCoinsGagnes or playerData.coins or 0
	else
		coinsRef = playerData.coins or 0
	end

	for _, seuil in ipairs(SEUILS) do
		local cle      = seuil.floor .. "_" .. seuil.spot
		local seuilEff = obtenirSeuilEffectif(seuil, playerData.rebirthLevel or 0)
		if not dd.progression[cle] and coinsRef >= seuilEff.coins then
			dd.progression[cle] = true

			local floorObj = trouverFloor(dd.baseFolder, seuil.floor)
			if not floorObj then continue end

			if seuil.spot == 1 and seuil.floor > 1 then
				-- Premier spot d'un étage supérieur → déblocage complet de l'étage
				debloquerEtage(player, dd, seuil.floor, floorObj)
			else
				-- Spot individuel (player passé pour créer le DepotPrompt)
				debloquerSpotIndividuel(player, dd, floorObj, seuil)
			end
		end
	end
end

-- ============================================================
-- Init — applique l'état visuel complet de la base d'un joueur
-- ============================================================

function BaseProgressionSystem.Init(player, baseIndex, playerData)
	-- Initialiser la progression si absente (nouveau joueur)
	if not playerData.progression then
		playerData.progression = {}
	end

	-- Débloquer les spots de départ (coins = 0) pour tout nouveau joueur
	for _, seuil in ipairs(SEUILS) do
		if seuil.coins == 0 then
			local cle = seuil.floor .. "_" .. seuil.spot
			if not playerData.progression[cle] then
				playerData.progression[cle] = true
			end
		end
	end

	-- Récupérer la base dans le Workspace
	local bases = Workspace:FindFirstChild("Bases")
	if not bases then
		warn("[BaseProgressionSystem] Workspace.Bases introuvable")
		return
	end
	local baseRoot = bases:FindFirstChild("Base_" .. baseIndex)
	if not baseRoot then
		warn("[BaseProgressionSystem] Base_" .. baseIndex .. " introuvable")
		return
	end
	local candidatBase = baseRoot:FindFirstChild("Base")
	local scoreRoot, floorsRoot, spotsRoot = scorerConteneurBase(baseRoot)
	local scoreBase, floorsBase, spotsBase = scorerConteneurBase(candidatBase)

	local baseFolder = nil
	if scoreBase >= scoreRoot then
		baseFolder = candidatBase
	else
		baseFolder = baseRoot
	end

	if not baseFolder or math.max(scoreBase, scoreRoot) <= 0 then
		warn("[BaseProgressionSystem] Aucun conteneur valide trouvé pour Base_" .. baseIndex .. " (floors/spots introuvables)")
		return
	end

	donneesJoueurs[player.UserId] = {
		baseIndex   = baseIndex,
		playerData  = playerData,
		progression = playerData.progression,
		spotsActifs = {},
		baseFolder  = baseFolder,
	}
	local dd = donneesJoueurs[player.UserId]

	-- Appliquer l'état visuel pour chaque étage
	for _, floorDef in ipairs(FLOORS) do
		local floorNum = floorDef.index
		local floorObj = trouverFloor(baseFolder, floorNum)
		if not floorObj then continue end

		local cleEtage = floorNum .. "_1"
		local etageDebloque = (dd.progression[cleEtage] == true)

		if not etageDebloque and floorNum > 1 then
			-- Étage non débloqué → tout invisible, CanTouch=false
			cacherEtage(floorObj)
		else
			-- Étage débloqué → structure visible, spots selon état individuel
			afficherStructure(floorObj)

			for _, seuil in ipairs(SEUILS) do
				if seuil.floor == floorNum then
					local spotObj = trouverSpot(floorObj, seuil.spot)
					if spotObj then
						local cle = seuil.floor .. "_" .. seuil.spot
						if dd.progression[cle] then
							appliquerEtatDebloque(spotObj, dd.spotsActifs)
						else
							-- Afficher le prix reduit selon le niveau rebirth du joueur
							appliquerEtatVerrouille(spotObj, obtenirSeuilEffectif(seuil, playerData.rebirthLevel or 0))
						end
					end
				end
			end
		end
	end

	print(string.format(
		"[BaseProgressionSystem] %s → Base_%d initialisée (%d spots actifs) [root=%dF/%dS, base=%dF/%dS, cible=%s]",
		player.Name,
		baseIndex,
		#dd.spotsActifs,
		floorsRoot, spotsRoot,
		floorsBase, spotsBase,
		baseFolder.Name
	))
end

-- ============================================================
-- API publique
-- ============================================================

-- Retourne la liste des TouchParts actifs du joueur (pour DropSystem)
function BaseProgressionSystem.GetSpotsActifs(player)
	local dd = donneesJoueurs[player.UserId]
	return dd and dd.spotsActifs or {}
end

-- Réinitialise les données du joueur (à appeler à la déconnexion)
function BaseProgressionSystem.Reset(player)
	donneesJoueurs[player.UserId] = nil
end

-- Remet la base visuellement à zéro (étages 2+ cachés, étage 1 verrouillé).
-- À appeler en TEST_MODE avant Init, après un reset DataStore, pour éviter
-- que la base garde visuellement ses étages débloqués de la session précédente.
function BaseProgressionSystem.ResetVisuelBase(baseIndex)
	local bases = Workspace:FindFirstChild("Bases")
	if not bases then return end
	local baseRoot = bases:FindFirstChild("Base_" .. baseIndex)
	if not baseRoot then return end

	local candidatBase = baseRoot:FindFirstChild("Base")
	local scoreRoot    = scorerConteneurBase(baseRoot)
	local scoreBase    = scorerConteneurBase(candidatBase)
	local baseFolder   = (scoreBase >= scoreRoot) and candidatBase or baseRoot
	if not baseFolder or math.max(scoreBase, scoreRoot) <= 0 then return end

	for _, floorDef in ipairs(FLOORS) do
		local floorObj = trouverFloor(baseFolder, floorDef.index)
		if not floorObj then continue end

		if floorDef.index > 1 then
			-- Étages supérieurs : tout invisible
			cacherEtage(floorObj)
		else
			-- Étage 1 : structure visible, spots selon seuil de coins
			afficherStructure(floorObj)
			for _, seuil in ipairs(SEUILS) do
				if seuil.floor == floorDef.index then
					local spotObj = trouverSpot(floorObj, seuil.spot)
					if spotObj then
						if seuil.coins > 0 then
							pcall(appliquerEtatVerrouille, spotObj, seuil)
						else
							pcall(appliquerEtatDebloque, spotObj, nil)
						end
					end
				end
			end
		end
	end

	print("[BaseProgressionSystem] ResetVisuel Base_" .. baseIndex .. " ✓")
end

-- ============================================================
-- Masque floors > 1 sur toutes les bases inactives (avant que les joueurs rejoignent)
-- À appeler une seule fois au démarrage du serveur, avant OnPlayerAdded
-- ============================================================
function BaseProgressionSystem.InitBasesInactives()
    local maxBases = Config.MaxBases or 6
    for i = 1, maxBases do
        pcall(BaseProgressionSystem.ResetVisuelBase, i)
    end
    print("[BaseProgressionSystem] InitBasesInactives (" .. maxBases .. " bases) ✓")
end

-- ============================================================
-- Débloque visuellement le floor suivant après un Rebirth
-- niveauRebirth = nouveau niveau (1 après 1er rebirth → débloque Floor 2)
-- ============================================================
function BaseProgressionSystem.DebloquerFloorApresRebirth(player, niveauRebirth)
    local AssignationSystem = require(game:GetService("ServerScriptService").SharedLib.Server.AssignationSystem)
    local baseIndex = AssignationSystem.GetBaseIndex(player)
    if not baseIndex then
        warn("[BaseProgressionSystem] DebloquerFloorApresRebirth : base introuvable pour " .. player.Name)
        return
    end

    local bases = Workspace:FindFirstChild("Bases")
    if not bases then return end
    local baseRoot = bases:FindFirstChild("Base_" .. baseIndex)
    if not baseRoot then return end

    -- Floor à débloquer = niveau rebirth + 1
    local floorIndex = niveauRebirth + 1
    local floorDef   = nil
    for _, f in ipairs(FLOORS) do
        if f.index == floorIndex then floorDef = f break end
    end
    if not floorDef then
        print("[BaseProgressionSystem] DebloquerFloor : pas de Floor " .. floorIndex .. " dans la config")
        return
    end

    -- Trouver le conteneur (Base_X ou Base_X/Base)
    local candidatBase = baseRoot:FindFirstChild("Base")
    local scoreRoot    = scorerConteneurBase(baseRoot)
    local scoreBase    = scorerConteneurBase(candidatBase)
    local baseFolder   = (scoreBase >= scoreRoot) and candidatBase or baseRoot

    local floorObj = trouverFloor(baseFolder, floorIndex)
    if not floorObj then
        warn("[BaseProgressionSystem] DebloquerFloor : Floor " .. floorIndex
            .. " introuvable dans Base_" .. baseIndex)
        return
    end

    -- Fade in avec les fonctions locales existantes
    fadeInStructure(floorObj, function()
        print(string.format(
            "[BaseProgressionSystem] Floor %d débloqué → Base_%d (Rebirth %d, %s)",
            floorIndex, baseIndex, niveauRebirth, player.Name
        ))
    end)
end

-- ============================================================
-- Calcul du coût réduit d'un floor selon le niveau rebirth
-- ============================================================

-- Retourne le coût d'unlock d'un floor après réduction rebirth
-- Utilise Config.FloorUnlockCosts comme base si défini, sinon seuil spot_1 du floor
-- Ex: GetFloorUnlockCost(2, 0) = 100000 ; GetFloorUnlockCost(2, 3) = 55000 (-45%)
function BaseProgressionSystem.GetFloorUnlockCost(floorNumber, rebirthCount)
    local costs = Config.FloorUnlockCosts
    local base  = 0

    if costs and costs[floorNumber] then
        base = costs[floorNumber]
    else
        -- Fallback : chercher le seuil spot_1 du floor dans SEUILS
        for _, seuil in ipairs(SEUILS) do
            if seuil.floor == floorNumber and seuil.spot == 1 then
                base = seuil.coins
                break
            end
        end
    end

    if base <= 0 then return 0 end

    local discount  = Config.RebirthFloorDiscount or 0
    local reduction = math.min((rebirthCount or 0) * discount, 0.90)
    return math.floor(base * (1 - reduction))
end

return BaseProgressionSystem
