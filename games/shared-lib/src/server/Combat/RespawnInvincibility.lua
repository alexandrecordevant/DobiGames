-- ServerScriptService/SharedLib/Server/Combat/RespawnInvincibility.lua
-- DobiGames shared-lib — Invincibilité temporaire après respawn (anti spawn-camp)
-- Durée configurable via GameConfig.Combat.RespawnInvincibilityDuration

local RespawnInvincibility = {}

local Players = game:GetService("Players")

-- Crée une aura dorée de particules sur le HumanoidRootPart
local function creerAuraInvincibilite(rootPart)
	local aura = Instance.new("ParticleEmitter")
	aura.Name            = "InvincibilityAura"
	aura.Texture         = "rbxasset://textures/particles/sparkles_main.dds"
	aura.Color           = ColorSequence.new(Color3.fromRGB(255, 215, 0))
	aura.Transparency    = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 1.0),
	})
	aura.Size            = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	aura.Lifetime        = NumberRange.new(0.5, 1.0)
	aura.Rate            = 30
	aura.Speed           = NumberRange.new(3, 6)
	aura.SpreadAngle     = Vector2.new(180, 180)
	aura.Rotation        = NumberRange.new(0, 360)
	aura.RotSpeed        = NumberRange.new(-50, 50)
	aura.LightEmission   = 1
	aura.LightInfluence  = 0
	aura.Parent          = rootPart
	return aura
end

-- Crée le billboard "INVINCIBLE" au-dessus de la tête
local function creerBillboardInvincibilite(character)
	local head = character:FindFirstChild("Head")
	if not head then return nil end

	local billboard = Instance.new("BillboardGui")
	billboard.Name             = "InvincibilityBillboard"
	billboard.Size             = UDim2.new(4, 0, 1, 0)
	billboard.StudsOffset      = Vector3.new(0, 2, 0)
	billboard.AlwaysOnTop      = false
	billboard.Adornee          = head
	billboard.Parent           = head

	local textLabel = Instance.new("TextLabel")
	textLabel.Text                   = "INVINCIBLE"
	textLabel.TextColor3             = Color3.fromRGB(255, 215, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Size                   = UDim2.new(1, 0, 1, 0)
	textLabel.Font                   = Enum.Font.FredokaOne
	textLabel.TextScaled             = true
	textLabel.TextStrokeTransparency = 0.5
	textLabel.TextStrokeColor3       = Color3.fromRGB(120, 80, 0)
	textLabel.Parent                 = billboard

	return billboard
end

-- Applique l'invincibilité à un character venant de spawner
local function appliquerInvincibilite(character, duree)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if not humanoid then return end

	local rootPart = character:WaitForChild("HumanoidRootPart", 5)
	if not rootPart then return end

	-- Marquer comme invincible (lu par BatSystem)
	humanoid:SetAttribute("Invincible", true)

	-- Effets visuels
	local aura      = creerAuraInvincibilite(rootPart)
	local billboard = creerBillboardInvincibilite(character)

	-- Retirer après la durée configurée
	task.delay(duree, function()
		-- Retirer le marqueur
		if humanoid and humanoid.Parent then
			humanoid:SetAttribute("Invincible", nil)
		end
		-- Détruire les effets visuels
		if aura and aura.Parent then
			aura:Destroy()
		end
		if billboard and billboard.Parent then
			billboard:Destroy()
		end
	end)
end

-- Initialise le système (appelé par Main.server.lua)
function RespawnInvincibility.Init(config)
	if not config or not config.RespawnInvincibilityEnabled then
		print("[RespawnInvincibility] Invincibilité respawn désactivée — système ignoré")
		return
	end

	local duree = config.RespawnInvincibilityDuration or 3

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			task.spawn(function()
				appliquerInvincibilite(character, duree)
			end)
		end)
	end)

	-- Gérer les joueurs déjà connectés
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			task.spawn(function()
				appliquerInvincibilite(player.Character, duree)
			end)
		end
		player.CharacterAdded:Connect(function(character)
			task.spawn(function()
				appliquerInvincibilite(character, duree)
			end)
		end)
	end

	print(string.format("[RespawnInvincibility] Initialisé — durée : %ds", duree))
end

return RespawnInvincibility
