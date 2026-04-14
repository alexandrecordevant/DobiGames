-- ServerScriptService/PickupSystem.lua
-- DobiGames shared-lib — Collecte de Brainrots via CollectionService (LavaTower)
-- Billboard + Timer + ProximityPrompt → délègue le carry à CarrySystem (Tool/Backpack).
--
-- USAGE :
--   local PickupSystem = require(path.to.PickupSystem)
--   PickupSystem.Init()
--
-- PRÉREQUIS sur chaque brainrot dans workspace :
--   • Tag CollectionService  "BrainrotCollectible"
--   • Attribut "Rarete"          string   "COMMON" | "RARE" | "EPIC" | …
--   • Attribut "LifeTime"        number   secondes avant auto-despawn  (défaut : 60)
--   • Attribut "OriginalName"    string   nom affiché                  (défaut : instance.Name)
--   • Attribut "CashParSeconde"  number   optionnel, ligne CPS dans le billboard
--   • Attribut "Prix"            number   optionnel, stocké comme info

local PickupSystem = {}

-- ─────────────────────────────────────────────────────────────
-- Services
-- ─────────────────────────────────────────────────────────────

local CollectionService   = game:GetService("CollectionService")
local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Logger              = require(script.Parent.Logger)
local BrainrotBillboard   = require(script.Parent.BrainrotBillboard)

-- ─────────────────────────────────────────────────────────────
-- ⚙️  CONFIGURATION — peut être surchargée via Init(config)
-- ─────────────────────────────────────────────────────────────

local TAG                  = "BrainrotCollectible"
local PICKUP_HOLD_DURATION = 3
local PICKUP_MAX_DISTANCE  = 10
local DEFAULT_LIFETIME     = 60
local BILLBOARD_STUDS_Y    = 7
local ERROR_COOLDOWN       = 1.5


-- ─────────────────────────────────────────────────────────────
-- CarrySystem — chargement différé (évite dépendance circulaire)
-- ─────────────────────────────────────────────────────────────

local _CarrySystem = nil
local function getCarrySystem()
	if not _CarrySystem then
		local ok, m = pcall(require, ServerScriptService.SharedLib.Server.CarrySystem)
		if ok and m then _CarrySystem = m end
	end
	return _CarrySystem
end

-- ─────────────────────────────────────────────────────────────
-- Anti-spam erreur par joueur
-- ─────────────────────────────────────────────────────────────

local lastErrorTime = {}

local function fireCarryError(player, msg)
	local now  = os.clock()
	local last = lastErrorTime[player.UserId] or 0
	if now - last < ERROR_COOLDOWN then return end
	lastErrorTime[player.UserId] = now
	local ev = ReplicatedStorage:FindFirstChild("BrainrotCarryError")
	if ev then pcall(function() ev:FireClient(player, msg) end) end
end

Players.PlayerRemoving:Connect(function(player)
	lastErrorTime[player.UserId] = nil
end)

-- ─────────────────────────────────────────────────────────────
-- UTILITAIRES
-- ─────────────────────────────────────────────────────────────

local function GetRootPart(instance)
	if instance:IsA("Model") then
		return instance.PrimaryPart
			or instance:FindFirstChildWhichIsA("BasePart", true)
	elseif instance:IsA("BasePart") then
		return instance
	end
	return nil
end


-- ─────────────────────────────────────────────────────────────
-- PICKUP — PROXIMITYPROMPT
-- ─────────────────────────────────────────────────────────────

local function SetupPickup(brainrot)
	local root = GetRootPart(brainrot)
	if not root then
		Logger.warn("Pickup", "Aucune BasePart sur %s — pickup ignoré", brainrot.Name)
		return
	end

	for _, child in ipairs(root:GetChildren()) do
		if child:IsA("ProximityPrompt") then child:Destroy() end
	end

	local rarete = brainrot:GetAttribute("Rarete")       or "COMMON"
	local nomAff = brainrot:GetAttribute("OriginalName") or brainrot.Name

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText            = "Collect"
	prompt.ObjectText            = "[" .. rarete .. "] " .. nomAff
	prompt.HoldDuration          = PICKUP_HOLD_DURATION
	prompt.MaxActivationDistance = PICKUP_MAX_DISTANCE
	prompt.RequiresLineOfSight   = false
	prompt.Parent                = root

	-- Avertissement anticipé si carry plein (début de hold)
	prompt.PromptButtonHoldBegan:Connect(function(player)
		local CS = getCarrySystem()
		if not CS then return end
		local portes = CS.GetPortes(player)
		local max    = CS.GetCapaciteMax(player)
		if #portes >= max then
			fireCarryError(player, "Carry full (" .. #portes .. "/" .. max .. ") — deposit your Brain Rots first!")
		end
	end)

	prompt.Triggered:Connect(function(player)
		-- Guard 1 : brainrot encore présent dans workspace
		if not brainrot or not brainrot:IsDescendantOf(workspace) then return end
		-- Guard 2 : anti-race (deux joueurs ou double-clic)
		if brainrot:GetAttribute("_Collecting") then return end
		brainrot:SetAttribute("_Collecting", true)

		-- Guard 3 : validation distance (anti-exploit)
		local char = player.Character
		if char and char.PrimaryPart then
			local dist = (char.PrimaryPart.Position - root.Position).Magnitude
			if dist > PICKUP_MAX_DISTANCE + 5 then
				brainrot:SetAttribute("_Collecting", nil)
				return
			end
		end

		-- Guard 4 : Backpack présent (joueur pas en train de respawn)
		if not player:FindFirstChildOfClass("Backpack") then
			brainrot:SetAttribute("_Collecting", nil)
			return
		end

		-- Déléguer au CarrySystem (gère capacité + création Tool + Backpack)
		local CS = getCarrySystem()
		if not CS then
			brainrot:SetAttribute("_Collecting", nil)
			return
		end

		local rareteObj = { nom = rarete, dossier = rarete }
		-- AjouterAuCarry utilise brainrot comme visuel → le déplace dans le Tool
		local success = CS.AjouterAuCarry(player, brainrot, rareteObj)
		if not success then
			-- Carry plein : CarrySystem a déjà affiché le message
			brainrot:SetAttribute("_Collecting", nil)
		end
		-- Si success : brainrot est maintenant dans le Tool (Backpack), ne pas le détruire
	end)
end

-- ─────────────────────────────────────────────────────────────
-- COUNTDOWN + AUTO-DESPAWN
-- ─────────────────────────────────────────────────────────────

local function StartCountdown(brainrot, duration)
	task.spawn(function()
		for t = duration, 0, -1 do
			-- Arrêt si le BR a quitté workspace (collecté → dans un Tool, ou détruit)
			if not brainrot or not brainrot:IsDescendantOf(workspace) then return end
			BrainrotBillboard.UpdateTimer(brainrot, t)
			if t > 0 then task.wait(1) end
		end
		-- Détruire uniquement si encore dans workspace (pas collecté)
		if brainrot and brainrot:IsDescendantOf(workspace) then
			brainrot:Destroy()
		end
	end)
end

-- ─────────────────────────────────────────────────────────────
-- SETUP COMPLET D'UN BRAINROT TAGGUÉ
-- ─────────────────────────────────────────────────────────────

local function SetupBrainrot(brainrot)
	task.wait()  -- garantit que les attributs sont définis avant lecture
	if not brainrot or not brainrot.Parent then return end
	-- Ignorer les templates hors workspace
	if not brainrot:IsDescendantOf(workspace) then return end

	-- Supprimer tous les BillboardGui pré-baked dans le template (ex: BRBillboard)
	-- avant que SetupField ne crée le _BRBillboard officiel (texte blanc, multi-lignes)
	for _, desc in ipairs(brainrot:GetDescendants()) do
		if desc:IsA("BillboardGui") then
			pcall(function() desc:Destroy() end)
		end
	end

	local duration = brainrot:GetAttribute("LifeTime") or DEFAULT_LIFETIME
	BrainrotBillboard.SetupField(brainrot, duration, BILLBOARD_STUDS_Y)
	SetupPickup(brainrot)
	StartCountdown(brainrot, duration)
end

-- ─────────────────────────────────────────────────────────────
-- API PUBLIQUE
-- ─────────────────────────────────────────────────────────────

--[[
    PickupSystem.Init(config)

    À appeler une seule fois depuis BrainrotService.server.lua.
    Toutes les clés de `config` sont optionnelles.

    config = {
        Tag              = "BrainrotCollectible",
        HoldDuration     = 3,
        MaxDistance      = 10,
        DefaultLifetime  = 60,
        BillboardStudsY  = 7,
        RarityColors     = { COMMON = Color3, ... },
    }
--]]
function PickupSystem.Init(config)
	config = config or {}
	if config.Tag             then TAG                  = config.Tag             end
	if config.HoldDuration   ~= nil then PICKUP_HOLD_DURATION = config.HoldDuration   end
	if config.MaxDistance    ~= nil then PICKUP_MAX_DISTANCE  = config.MaxDistance    end
	if config.DefaultLifetime ~= nil then DEFAULT_LIFETIME    = config.DefaultLifetime end
	if config.BillboardStudsY ~= nil then BILLBOARD_STUDS_Y   = config.BillboardStudsY end
	if config.RarityColors        then RARETE_COULEURS        = config.RarityColors   end

	-- Instances déjà taggées (placées en Studio)
	for _, inst in ipairs(CollectionService:GetTagged(TAG)) do
		task.spawn(SetupBrainrot, inst)
	end
	-- Instances taggées dynamiquement (spawner)
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(inst)
		task.spawn(SetupBrainrot, inst)
	end)

	Logger.info("Pickup", "✓ Démarré — tag : '%s' | hold:%ds | dist:%d studs", TAG, PICKUP_HOLD_DURATION, PICKUP_MAX_DISTANCE)
end

return PickupSystem
