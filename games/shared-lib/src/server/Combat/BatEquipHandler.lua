-- ServerScriptService/SharedLib/Server/Combat/BatEquipHandler.lua
-- DobiGames shared-lib — Équipe la batte de baseball au spawn de chaque joueur
-- La batte est clonée depuis ServerStorage.Weapons.BaseballBat

local BatEquipHandler = {}

local Players      = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

-- Donne la batte au joueur si elle n'est pas déjà présente
local function equiperBatte(player)
	-- Attendre que le Backpack soit initialisé
	task.wait(0.5)

	-- Vérifier que le joueur est encore connecté
	if not player or not player.Parent then return end

	-- Anti-duplication : vérifier Backpack et Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack and backpack:FindFirstChild("BaseballBat") then return end

	local character = player.Character
	if character and character:FindFirstChild("BaseballBat") then return end

	-- Récupérer le template dans ServerStorage
	local weaponsFolder = ServerStorage:FindFirstChild("Weapons")
	if not weaponsFolder then
		warn("[BatEquipHandler] ServerStorage.Weapons introuvable")
		return
	end

	local batTemplate = weaponsFolder:FindFirstChild("BaseballBat")
	if not batTemplate then
		warn("[BatEquipHandler] ServerStorage.Weapons.BaseballBat introuvable")
		return
	end

	-- Cloner et donner au joueur
	local bat = batTemplate:Clone()
	bat.Parent = backpack or player:WaitForChild("Backpack", 5)
end

-- Initialise le système (appelé par Main.server.lua)
function BatEquipHandler.Init(config)
	if not config or not config.BatEnabled then
		print("[BatEquipHandler] Batte désactivée — système ignoré")
		return
	end

	-- Vérifier que le modèle existe au démarrage
	local weaponsFolder = ServerStorage:FindFirstChild("Weapons")
	if not weaponsFolder or not weaponsFolder:FindFirstChild("BaseballBat") then
		warn("[BatEquipHandler] ATTENTION : ServerStorage.Weapons.BaseballBat manquante — créer le Tool dans Studio")
	end

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.spawn(function()
				equiperBatte(player)
			end)
		end)
	end)

	-- Gérer les joueurs déjà connectés
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			equiperBatte(player)
		end)
	end

	print("[BatEquipHandler] Initialisé — batte équipée au spawn")
end

return BatEquipHandler
