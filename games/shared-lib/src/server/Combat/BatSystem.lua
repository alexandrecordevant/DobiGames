-- ServerScriptService/SharedLib/Server/Combat/BatSystem.lua
-- DobiGames shared-lib — Système de frappe batte de baseball (validation serveur)
-- 8 validations anti-exploit + raycast + drop scatter des BRs portés

local BatSystem = {}

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local ServerScriptService = game:GetService("ServerScriptService")

-- Chargement différé pour éviter les dépendances circulaires
local _CarrySystem = nil
local function getCarrySystem()
	if not _CarrySystem then
		local ok, cs = pcall(function()
			return require(ServerScriptService.SharedLib.Server.CarrySystem)
		end)
		if ok then _CarrySystem = cs end
	end
	return _CarrySystem
end

-- Config et SafeZoneTracker injectés par Init
local _config          = nil
local _safeZoneTracker = nil

-- Tracking anti-exploit
local lastSwingTime  = {}  -- [userId] = tick() dernier swing
local swingAttempts  = {}  -- [userId] = { timestamps } pour rate limiting

-- ============================================================
-- Feedback visuel générique (billboard temporaire)
-- ============================================================
local function afficherFeedback(character, texte, couleur)
	local head = character and character:FindFirstChild("Head")
	if not head then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Name             = "CombatFeedback"
	billboard.Size             = UDim2.new(4, 0, 1, 0)
	billboard.StudsOffset      = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop      = false
	billboard.Adornee          = head
	billboard.Parent           = head

	local textLabel = Instance.new("TextLabel")
	textLabel.Text                   = texte
	textLabel.TextColor3             = couleur or Color3.fromRGB(255, 255, 255)
	textLabel.BackgroundTransparency = 1
	textLabel.Size                   = UDim2.new(1, 0, 1, 0)
	textLabel.Font                   = Enum.Font.FredokaOne
	textLabel.TextScaled             = true
	textLabel.TextStrokeTransparency = 0.5
	textLabel.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
	textLabel.Parent                 = billboard

	task.delay(1.5, function()
		if billboard and billboard.Parent then
			billboard:Destroy()
		end
	end)
end

-- ============================================================
-- Effets visuels d'impact sur la victime
-- ============================================================
local function afficherEffetsImpact(victimCharacter, handle)
	local rootPart = victimCharacter:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	-- Son d'impact depuis le handle de la batte
	if handle then
		local hitSound = handle:FindFirstChild("HitSound")
		if hitSound then
			pcall(function() hitSound:Play() end)
		end
	end

	-- Particules étincelles jaunes
	local spark = Instance.new("ParticleEmitter")
	spark.Name           = "ImpactSpark"
	spark.Texture        = "rbxasset://textures/particles/sparkles_main.dds"
	spark.Color          = ColorSequence.new(Color3.fromRGB(255, 200, 0))
	spark.Transparency   = NumberSequence.new(0)
	spark.Lifetime       = NumberRange.new(0.15, 0.3)
	spark.Rate           = 0
	spark.Speed          = NumberRange.new(8, 15)
	spark.SpreadAngle    = Vector2.new(180, 180)
	spark.LightEmission  = 0.8
	spark.Parent         = rootPart

	spark:Emit(25)

	task.delay(0.5, function()
		if spark and spark.Parent then
			spark:Destroy()
		end
	end)

	-- Billboard "OUCH!"
	afficherFeedback(victimCharacter, "OUCH!", Color3.fromRGB(255, 50, 50))
end

-- ============================================================
-- Drop des BRs portés par la victime (scatter aléatoire)
-- ============================================================
local function dropperBRsPortes(victim, victimCharacter)
	local carrySystem = getCarrySystem()
	if not carrySystem then
		warn("[BatSystem] CarrySystem introuvable — drop annulé")
		return
	end

	-- Vérifier que la victime porte quelque chose
	local portes = carrySystem.GetPortes(victim)
	if not portes or #portes == 0 then
		afficherFeedback(victimCharacter, "NOTHING!", Color3.fromRGB(180, 180, 180))
		return
	end

	local nbPortes = #portes

	-- Position de base pour le scatter
	local rootPart = victimCharacter:FindFirstChild("HumanoidRootPart")
	local victimPos = rootPart and rootPart.Position or Vector3.new(0, 5, 0)

	-- Vider le carry → retourne { { modele, rarete } }
	local deposes = carrySystem.ViderCarry(victim)

	-- Repositionner en scatter et rendre récupérables
	local rayon = _config and _config.BatDropRadius or 3
	for _, entree in ipairs(deposes) do
		local modele = entree.modele
		local rarete = entree.rarete
		if modele and modele.Parent then
			-- Position aléatoire dans le rayon
			local ox = math.random(-rayon * 10, rayon * 10) / 10
			local oz = math.random(-rayon * 10, rayon * 10) / 10
			local targetPos = victimPos + Vector3.new(ox, 2, oz)

			pcall(function()
				modele:PivotTo(CFrame.new(targetPos))
			end)

			-- Rendre le BR à nouveau récupérable par n'importe qui
			if rarete then
				pcall(function()
					carrySystem.OnBRSpawned(modele, nil, rarete, nil)
				end)
			end
		end
	end

	print(string.format("[BatSystem] %s a fait lâcher %d BR(s) à %s",
		"?", nbPortes, victim.Name))

	afficherFeedback(victimCharacter, "OUCH!", Color3.fromRGB(255, 50, 50))
end

-- ============================================================
-- Handler principal du swing (validations serveur)
-- ============================================================
local function onBatSwing(attacker)
	local character = attacker.Character
	if not character then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	-- VALIDATION 1 : Cooldown attaquant
	local now = tick()
	local dernier = lastSwingTime[attacker.UserId] or 0
	local cooldown = _config and _config.BatCooldown or 1
	if (now - dernier) < cooldown then return end
	lastSwingTime[attacker.UserId] = now

	-- VALIDATION 2 : Rate limiting anti-exploit
	if not swingAttempts[attacker.UserId] then
		swingAttempts[attacker.UserId] = {}
	end
	table.insert(swingAttempts[attacker.UserId], now)

	-- Nettoyer les timestamps > 10s
	local recent = {}
	for _, ts in ipairs(swingAttempts[attacker.UserId]) do
		if (now - ts) < 10 then
			table.insert(recent, ts)
		end
	end
	swingAttempts[attacker.UserId] = recent

	-- Kick si > 15 swings en 10s (spam exploit)
	if #recent > 15 then
		attacker:Kick("Exploit détecté : spam BatSwing")
		return
	end

	-- VALIDATION 3 : Attaquant a bien la batte équipée dans son character
	local tool = character:FindFirstChild("BaseballBat")
	if not tool then return end

	local handle = tool:FindFirstChild("Handle")
	if not handle then return end

	-- VALIDATION 4 : Raycast depuis le handle de la batte
	local portee = _config and _config.BatRange or 6
	local origin    = handle.Position
	local direction = handle.CFrame.LookVector * portee

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character }

	local result = workspace:Raycast(origin, direction, raycastParams)
	if not result then return end

	-- VALIDATION 5 : La cible touchée est bien un joueur
	local hitPart       = result.Instance
	local victimCharacter = hitPart.Parent
	local victim        = Players:GetPlayerFromCharacter(victimCharacter)

	if not victim or victim == attacker then return end

	-- VALIDATION 6 : Victime pas dans une zone safe
	if _safeZoneTracker and _safeZoneTracker.IsPlayerInSafeZone(victim) then
		afficherFeedback(victimCharacter, "SAFE ZONE!", Color3.fromRGB(0, 255, 100))
		return
	end

	-- VALIDATION 7 : Victime pas invincible (respawn)
	local victimHumanoid = victimCharacter:FindFirstChildOfClass("Humanoid")
	if victimHumanoid and victimHumanoid:GetAttribute("Invincible") then
		afficherFeedback(victimCharacter, "INVINCIBLE!", Color3.fromRGB(255, 215, 0))
		return
	end

	-- VALIDATION 8 : Victime possède le Game Pass Protection ?
	if _config and _config.ProtectionGamePassId and _config.ProtectionGamePassId ~= 0 then
		local hasProtection = false
		pcall(function()
			hasProtection = MarketplaceService:UserOwnsGamePassAsync(
				victim.UserId,
				_config.ProtectionGamePassId
			)
		end)
		if hasProtection then
			afficherFeedback(victimCharacter, "PROTECTED!", Color3.fromRGB(0, 200, 255))
			return
		end
	end

	-- TOUTES VALIDATIONS PASSÉES → Drop les BRs + effets d'impact
	afficherEffetsImpact(victimCharacter, handle)
	dropperBRsPortes(victim, victimCharacter)
end

-- ============================================================
-- Initialisation (appelée par Main.server.lua)
-- ============================================================
function BatSystem.Init(config, safeZoneTracker)
	if not config or not config.BatEnabled then
		print("[BatSystem] Batte désactivée — système ignoré")
		return
	end

	_config          = config
	_safeZoneTracker = safeZoneTracker

	-- Créer ou récupérer le RemoteEvent BatSwing
	local batSwingEvent = ReplicatedStorage:FindFirstChild("BatSwing")
	if not batSwingEvent then
		batSwingEvent        = Instance.new("RemoteEvent")
		batSwingEvent.Name   = "BatSwing"
		batSwingEvent.Parent = ReplicatedStorage
	end

	-- Écouter les demandes de swing depuis le client
	batSwingEvent.OnServerEvent:Connect(onBatSwing)

	-- Nettoyer le tracking quand un joueur quitte
	Players.PlayerRemoving:Connect(function(player)
		lastSwingTime[player.UserId] = nil
		swingAttempts[player.UserId] = nil
	end)

	print(string.format(
		"[BatSystem] Initialisé — portée : %d studs, cooldown : %.1fs",
		config.BatRange or 6,
		config.BatCooldown or 1
	))
end

return BatSystem
