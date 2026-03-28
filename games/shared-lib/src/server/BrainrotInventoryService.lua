-- ServerScriptService/BrainrotInventoryService.lua
-- DobiGames shared-lib — Inventaire collectible des Brainrots (log côté serveur)
-- Structure prête pour intégration DataStore (voir commentaires).

local BrainrotInventoryService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")

-- ── RemoteEvent pour notifier le client après une collecte ──
local function getOrCreate(name)
	local e = ReplicatedStorage:FindFirstChild(name)
	if e then return e end
	local re = Instance.new("RemoteEvent")
	re.Name   = name
	re.Parent = ReplicatedStorage
	return re
end

local BrainrotCollected = getOrCreate("BrainrotCollected")

-- ── Table runtime : inventaire par joueur (userId -> { [id] = entry })
-- Pour intégrer avec DataStore :
--   Charger depuis data.brainrotInventory dans DataStoreManager.Load()
--   Sauvegarder dans data.brainrotInventory dans DataStoreManager.Save()
local inventaires = {}

-- Initialise l'inventaire d'un joueur à sa connexion
function BrainrotInventoryService.Init(player)
	inventaires[player.UserId] = {}
end

-- Nettoie la mémoire à la déconnexion
function BrainrotInventoryService.Clear(player)
	inventaires[player.UserId] = nil
end

-- Vérifie si un brainrot est déjà dans l'inventaire du joueur.
-- brainrotId : string (Attribute "BrainrotId" de l'instance, ou son Name)
function BrainrotInventoryService.Has(player, brainrotId)
	local inv = inventaires[player.UserId]
	return inv ~= nil and inv[brainrotId] ~= nil
end

-- Ajoute un brainrot à l'inventaire.
-- brainrotData : { id: string, name: string, rarity: string }
-- Retourne true si ajouté, false + raison si refusé.
function BrainrotInventoryService.Add(player, brainrotData)
	local inv = inventaires[player.UserId]
	if not inv then
		return false, "Inventaire joueur introuvable"
	end
	if inv[brainrotData.id] then
		return false, "Déjà collecté"
	end

	inv[brainrotData.id] = {
		name      = brainrotData.name,
		rarity    = brainrotData.rarity,
		timestamp = os.time(),
	}

	pcall(function() BrainrotCollected:FireClient(player, brainrotData) end)

	print(("[BrainrotInventory] %s a collecté %s (%s)"):format(
		player.Name, brainrotData.name, brainrotData.rarity))

	return true
end

-- Retourne tout l'inventaire d'un joueur (copie superficielle)
function BrainrotInventoryService.GetAll(player)
	local inv = inventaires[player.UserId]
	if not inv then return {} end
	local copy = {}
	for id, entry in pairs(inv) do
		copy[id] = entry
	end
	return copy
end

-- Retire un brainrot par rareté (utilisé par RebirthSystem.ConsumeRarity).
-- Supprime le premier BR trouvé avec la rareté demandée.
-- Retourne true si trouvé et supprimé, false sinon.
function BrainrotInventoryService.RemoveOneOfRarity(player, rarity)
	local inv = inventaires[player.UserId]
	if not inv then return false end
	for id, entry in pairs(inv) do
		if entry.rarity == rarity then
			inv[id] = nil
			print(("[BrainrotInventory] %s : BR rareté %s consommé (rebirth)"):format(
				player.Name, rarity))
			return true
		end
	end
	return false
end

-- Nettoyage auto à la déconnexion
Players.PlayerRemoving:Connect(function(player)
	BrainrotInventoryService.Clear(player)
end)

return BrainrotInventoryService
