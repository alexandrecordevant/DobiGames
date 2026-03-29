-- StarterPlayerScripts/Combat/BatController.client.lua
-- DobiGames shared-lib — Contrôleur client de la batte de baseball
-- Détecte l'activation du Tool, joue l'animation, envoie le RemoteEvent au serveur

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- Vérifier si PvP est activé dans la config
local ok, Config = pcall(function()
	return require(ReplicatedStorage:WaitForChild("GameConfig", 10))
end)

if not ok or not Config then
	warn("[BatController] GameConfig introuvable — contrôleur désactivé")
	return
end

if not Config.PvPEnabled or not (Config.Combat and Config.Combat.BatEnabled) then
	return -- PvP désactivé pour ce jeu
end

-- Paramètres depuis Config
local COOLDOWN = Config.Combat.BatCooldown or 1

-- RemoteEvent (créé par BatSystem côté serveur)
local batSwingEvent = ReplicatedStorage:WaitForChild("BatSwing", 10)
if not batSwingEvent then
	warn("[BatController] RemoteEvent BatSwing introuvable")
	return
end

-- Cooldown local (affichage fluidifié — validation réelle côté serveur)
local lastSwing    = 0
local connectedBat = nil  -- connexion Tool.Activated en cours

-- Configure les écouteurs sur une batte équipée
local function configurerBatte(tool)
	if tool.Name ~= "BaseballBat" then return end
	if connectedBat then return end  -- déjà configuré

	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local animator = humanoid:FindFirstChildOfClass("Animator")

	-- Charger l'animation de swing si présente
	local animTrack = nil
	local swingAnim = tool:FindFirstChild("SwingAnimation")
	if swingAnim and animator then
		pcall(function()
			animTrack = animator:LoadAnimation(swingAnim)
		end)
	end

	-- Son d'impact (joué localement)
	local handle   = tool:FindFirstChild("Handle")
	local hitSound = handle and handle:FindFirstChild("HitSound")

	-- Connexion à l'activation du Tool (clic gauche / tap mobile)
	connectedBat = tool.Activated:Connect(function()
		local now = tick()
		if (now - lastSwing) < COOLDOWN then return end
		lastSwing = now

		-- Animation locale (non bloquante)
		if animTrack then
			pcall(function() animTrack:Play() end)
		end

		-- Son local
		if hitSound then
			pcall(function() hitSound:Play() end)
		end

		-- Demande de validation au serveur
		batSwingEvent:FireServer()
	end)
end

-- Nettoie la connexion quand la batte est retirée
local function nettoyerBatte()
	if connectedBat then
		connectedBat:Disconnect()
		connectedBat = nil
	end
end

-- Configure les listeners pour le character actuel
local function configurerCharacter(character)
	nettoyerBatte()

	-- Écouter l'équipement de la batte
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			configurerBatte(child)
		end
	end)

	-- Si la batte est déjà équipée au chargement du character
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then
			configurerBatte(child)
		end
	end

	-- Nettoyage quand la batte est déséquipée (retour dans Backpack)
	character.ChildRemoved:Connect(function(child)
		if child.Name == "BaseballBat" then
			nettoyerBatte()
		end
	end)
end

-- Setup initial
if player.Character then
	configurerCharacter(player.Character)
end

-- Re-setup à chaque respawn
player.CharacterAdded:Connect(function(character)
	nettoyerBatte()
	configurerCharacter(character)
end)
