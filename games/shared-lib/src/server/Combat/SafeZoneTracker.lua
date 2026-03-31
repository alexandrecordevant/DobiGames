-- ServerScriptService/SharedLib/Server/Combat/SafeZoneTracker.lua
-- DobiGames shared-lib — Suivi des joueurs dans les zones safe
-- Désactive le PvP dans un rayon configurable autour de chaque base

local SafeZoneTracker = {}

local Players = game:GetService("Players")

-- Table globale : [userId] = true si dans une zone safe
local playersInSafeZone = {}
-- Cooldown feedback billboard : [userId] = timestamp dernière notification
local lastFeedbackTime = {}

-- Affiche un billboard "SAFE ZONE" au-dessus de la tête du joueur
local function afficherFeedbackSafeZone(character)
	local head = character:FindFirstChild("Head")
	if not head then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Name             = "SafeZoneFeedback"
	billboard.Size             = UDim2.new(4, 0, 1, 0)
	billboard.StudsOffset      = Vector3.new(0, 2, 0)
	billboard.AlwaysOnTop      = false
	billboard.Adornee          = head
	billboard.Parent           = head

	local textLabel = Instance.new("TextLabel")
	textLabel.Text                = "SAFE ZONE"
	textLabel.TextColor3          = Color3.fromRGB(0, 255, 100)
	textLabel.BackgroundTransparency = 1
	textLabel.Size                = UDim2.new(1, 0, 1, 0)
	textLabel.Font                = Enum.Font.FredokaOne
	textLabel.TextScaled          = true
	textLabel.TextStrokeTransparency = 0.5
	textLabel.TextStrokeColor3    = Color3.fromRGB(0, 80, 0)
	textLabel.Parent              = billboard

	task.delay(2, function()
		if billboard and billboard.Parent then
			billboard:Destroy()
		end
	end)
end

-- Initialise le tracker (appelé par Main.server.lua)
function SafeZoneTracker.Init(config)
	if not config or not config.SafeZoneEnabled then
		print("[SafeZoneTracker] Zones safe désactivées — système ignoré")
		return
	end

	-- Chercher toutes les bases dans workspace.Bases
	local bases = workspace:FindFirstChild("Bases")
	if not bases then
		warn("[SafeZoneTracker] workspace.Bases introuvable — zones safe non initialisées")
		return
	end

	local zonesInitialisees = 0

	for _, baseModel in ipairs(bases:GetChildren()) do
		-- SafeZone dans Shared/ (structure Shared/Specific)
		local sharedFolderSZ = baseModel:FindFirstChild("Shared")
		local safeZone       = sharedFolderSZ and sharedFolderSZ:FindFirstChild("SafeZone")
		if not safeZone then
			-- Zone safe optionnelle — warn uniquement si au moins une base existe
			continue
		end

		-- Joueur entre dans la zone safe
		safeZone.Touched:Connect(function(hit)
			local character = hit.Parent
			if not character then return end
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if not humanoid or humanoid.Health <= 0 then return end

			local player = Players:GetPlayerFromCharacter(character)
			if not player then return end

			playersInSafeZone[player.UserId] = true

			-- Feedback visuel (cooldown configurable)
			local now = tick()
			local cooldown = config.SafeZoneFeedbackCooldown or 5
			local dernierFeedback = lastFeedbackTime[player.UserId] or 0
			if (now - dernierFeedback) >= cooldown then
				lastFeedbackTime[player.UserId] = now
				afficherFeedbackSafeZone(character)
			end
		end)

		-- Joueur sort de la zone safe
		safeZone.TouchEnded:Connect(function(hit)
			local character = hit.Parent
			if not character then return end
			local player = Players:GetPlayerFromCharacter(character)
			if not player then return end
			playersInSafeZone[player.UserId] = nil
		end)

		zonesInitialisees = zonesInitialisees + 1
	end

	-- Nettoyer les données quand un joueur quitte
	Players.PlayerRemoving:Connect(function(player)
		playersInSafeZone[player.UserId]  = nil
		lastFeedbackTime[player.UserId]   = nil
	end)

	print(string.format("[SafeZoneTracker] Initialisé — %d zone(s) safe détectée(s)", zonesInitialisees))
end

-- Vérifie si un joueur est actuellement dans une zone safe
function SafeZoneTracker.IsPlayerInSafeZone(player)
	return playersInSafeZone[player.UserId] == true
end

return SafeZoneTracker
