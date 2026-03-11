-- ServerScriptService/RebirthServer.server.lua
-- Système de Rebirth — logique serveur complète
-- DataStore séparé pour ne pas interférer avec le DataStore principal

local Players             = game:GetService("Players")
local DataStoreService    = game:GetService("DataStoreService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- ═══════════════════════════════════════════════
-- 1. CONFIG + INVENTAIRE
-- ═══════════════════════════════════════════════

local RebirthConfig          = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RebirthConfig"))
local BrainrotInventoryService = require(ServerScriptService:WaitForChild("BrainrotInventoryService"))

-- ═══════════════════════════════════════════════
-- 2. DATASTORE
-- ═══════════════════════════════════════════════

-- Clé séparée "rebirth_USERID" pour ne pas polluer le DataStore principal
local RebirthDS = DataStoreService:GetDataStore("LavaTowerRebirthV1")

-- Cache mémoire : [tostring(userId)] = { rebirthCount, slots }
local cache = {}

-- ═══════════════════════════════════════════════
-- 3. REMOTES
-- ═══════════════════════════════════════════════

local function getOrCreate(class, name)
	local existing = ReplicatedStorage:FindFirstChild(name)
	if existing then return existing end
	local inst = Instance.new(class)
	inst.Name   = name
	inst.Parent = ReplicatedStorage
	return inst
end

local rfGetRebirthData = getOrCreate("RemoteFunction", "GetRebirthData")
local reRequestRebirth = getOrCreate("RemoteEvent",    "RequestRebirth")
local reRebirthResult  = getOrCreate("RemoteEvent",    "RebirthResult")

print("[RebirthServer] Remotes créés ✓")

-- ═══════════════════════════════════════════════
-- 4. STUBS — CONNECTER AUX VRAIS SYSTÈMES
-- ═══════════════════════════════════════════════
-- Ces fonctions isolent les dépendances externes.
-- Remplacer leur corps quand les vrais systèmes sont prêts.

-- TODO: Retourner les vraies coins du joueur depuis le cache de Main.server.lua
-- Exemple : return MainCache[player.UserId].coins
local function getPlayerMoney(player)
	-- Stub : lit le DataStore principal pour récupérer les coins
	-- En production, utiliser le cache mémoire de Main.server.lua via BindableFunction
	local ok, data = pcall(function()
		return DataStoreService:GetDataStore("BrainRotIdleV1"):GetAsync("player_" .. player.UserId)
	end)
	if ok and data and data.coins then
		return data.coins
	end
	return 0
end

-- TODO: Déduire les coins depuis le cache de Main.server.lua
-- Exemple : MainCache[player.UserId].coins -= amount
local function deductMoney(player, amount)
	-- Stub : avertissement seulement, pas de déduction réelle sans accès au cache principal
	-- Pour connecter : exposer une BindableFunction "Rebirth_DeductMoney" dans Main.server.lua
	warn(string.format("[RebirthServer] STUB deductMoney: %s doit perdre %d coins", player.Name, amount))
end

-- Vérifie si le joueur possède au moins un BrainRot de la rareté requise (ou supérieure)
local function playerHasRarity(player, requiredRarity)
	local inventory = BrainrotInventoryService.GetAll(player)
	for _, entry in pairs(inventory) do
		if RebirthConfig.MeetsRarity(entry.rarity, requiredRarity) then
			return true
		end
	end
	return false
end

-- TODO: Consommer un BrainRot de la rareté requise de l'inventaire
-- Exemple : BrainrotInventoryService.RemoveOneOfRarity(player, rarity)
local function consumeRarity(player, rarity)
	warn(string.format("[RebirthServer] STUB consumeRarity: %s doit perdre un BrainRot %s", player.Name, rarity))
end

-- ═══════════════════════════════════════════════
-- 5. DATASTORE — CHARGEMENT / SAUVEGARDE
-- ═══════════════════════════════════════════════

local function defaultData()
	return { rebirthCount = 0, slots = 1 }
end

local function loadData(player)
	local uid = tostring(player.UserId)
	local data

	local ok, err = pcall(function()
		data = RebirthDS:GetAsync("rebirth_" .. uid)
	end)
	if not ok then
		warn("[RebirthServer] Erreur lecture " .. player.Name .. ": " .. tostring(err))
	end

	cache[uid] = data or defaultData()
	print(string.format("[RebirthServer] Chargé %s — Rebirth:%d Slots:%d",
		player.Name, cache[uid].rebirthCount, cache[uid].slots))
	return cache[uid]
end

local function saveData(player)
	local uid  = tostring(player.UserId)
	local data = cache[uid]
	if not data then return end

	local ok, err = pcall(function()
		RebirthDS:SetAsync("rebirth_" .. uid, data)
	end)
	if not ok then
		warn("[RebirthServer] Erreur sauvegarde " .. player.Name .. ": " .. tostring(err))
	end
end

-- ═══════════════════════════════════════════════
-- 6. CONSTRUCTION DU PAYLOAD CLIENT
-- ═══════════════════════════════════════════════

-- Construit la table envoyée au client avec tout l'état courant
local function buildPayload(player)
	local uid  = tostring(player.UserId)
	local data = cache[uid]
	if not data then return nil end

	local nextLevel = data.rebirthCount + 1
	local tierCfg   = RebirthConfig.GetTier(nextLevel)
	local money     = getPlayerMoney(player)
	local hasRarity = tierCfg and playerHasRarity(player, tierCfg.rarity) or false

	return {
		rebirthCount = data.rebirthCount,
		slots        = data.slots,
		maxReached   = (tierCfg == nil),
		nextLevel    = nextLevel,
		required     = tierCfg and {
			money   = tierCfg.money,
			rarity  = tierCfg.rarity,
			reward  = tierCfg.reward,
		} or nil,
		current = {
			money     = money,
			hasRarity = hasRarity,
		},
	}
end

-- ═══════════════════════════════════════════════
-- 7. REMOTEFUNCTION — GetRebirthData
-- ═══════════════════════════════════════════════

rfGetRebirthData.OnServerInvoke = function(player)
	print("[RebirthServer] GetRebirthData ← " .. player.Name)
	return buildPayload(player)
end

-- ═══════════════════════════════════════════════
-- 8. REMOTEEVENT — RequestRebirth
-- ═══════════════════════════════════════════════

reRequestRebirth.OnServerEvent:Connect(function(player)
	print("[RebirthServer] RequestRebirth ← " .. player.Name)

	local uid  = tostring(player.UserId)
	local data = cache[uid]

	if not data then
		reRebirthResult:FireClient(player, { success = false, reason = "Données introuvables." })
		return
	end

	local nextLevel = data.rebirthCount + 1
	local tierCfg   = RebirthConfig.GetTier(nextLevel)

	-- Niveau maximum
	if not tierCfg then
		reRebirthResult:FireClient(player, { success = false, reason = "Niveau maximum atteint !" })
		return
	end

	-- Vérification argent
	local money = getPlayerMoney(player)
	if money < tierCfg.money then
		reRebirthResult:FireClient(player, {
			success = false,
			reason  = "Argent insuffisant. Requis : " .. tierCfg.money,
		})
		return
	end

	-- Vérification rareté
	if not playerHasRarity(player, tierCfg.rarity) then
		reRebirthResult:FireClient(player, {
			success = false,
			reason  = "BrainRot requis : " .. tierCfg.rarity,
		})
		return
	end

	-- ═══ REBIRTH VALIDE ═══
	deductMoney(player, tierCfg.money)
	consumeRarity(player, tierCfg.rarity)

	data.rebirthCount = nextLevel
	data.slots        = data.slots + (tierCfg.reward.slots or 0)

	saveData(player)

	reRebirthResult:FireClient(player, {
		success      = true,
		newCount     = data.rebirthCount,
		newSlots     = data.slots,
		payload      = buildPayload(player),
	})

	print(string.format("[RebirthServer] ✓ Rebirth %d pour %s | Slots:%d",
		data.rebirthCount, player.Name, data.slots))
end)

-- ═══════════════════════════════════════════════
-- 9. CONNEXION JOUEURS
-- ═══════════════════════════════════════════════

Players.PlayerAdded:Connect(function(player)
	-- Décalage pour ne pas saturer le DataStore queue au même moment que Main.server.lua
	task.wait(3)
	if player and player.Parent then
		loadData(player)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	saveData(player)
	cache[tostring(player.UserId)] = nil
end)

game:BindToClose(function()
	for _, p in ipairs(Players:GetPlayers()) do
		saveData(p)
	end
end)

print("[RebirthServer] Démarré ✓")
