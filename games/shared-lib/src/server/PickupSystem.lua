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

local CollectionService = game:GetService("CollectionService")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local ServerScriptService = game:GetService("ServerScriptService")

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
-- 🎨 COULEURS PAR RARETÉ
-- ─────────────────────────────────────────────────────────────

local RARETE_COULEURS = {
	COMMON    = Color3.fromRGB(200, 200, 200),
	RARE      = Color3.fromRGB(0,   120, 255),
	EPIC      = Color3.fromRGB(150,   0, 255),
	LEGENDARY = Color3.fromRGB(255, 200,   0),
	MYTHIC    = Color3.fromRGB(255,  50,  50),
	GOD       = Color3.fromRGB(255, 140,   0),
	SECRET    = Color3.fromRGB(255, 255, 255),
	OG        = Color3.fromRGB(100, 220, 255),
}

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

local function FormatNombre(n)
	n = tonumber(n) or 0
	if     n >= 1e12 then return ("%.1fT"):format(n / 1e12)
	elseif n >= 1e9  then return ("%.1fB"):format(n / 1e9)
	elseif n >= 1e6  then return ("%.1fM"):format(n / 1e6)
	elseif n >= 1e3  then return ("%.1fK"):format(n / 1e3)
	else                  return tostring(math.floor(n))
	end
end

local function FormatTimer(t)
	t = math.max(0, math.floor(t))
	local m = math.floor(t / 60)
	local s = t % 60
	return m > 0 and ("%d:%02d"):format(m, s) or ("%ds"):format(s)
end

-- ─────────────────────────────────────────────────────────────
-- BILLBOARD
-- ─────────────────────────────────────────────────────────────

local BILLBOARD_NAME = "_BRBillboard"

local function MakeLabel(parent, name, text, posY, color)
	local label = Instance.new("TextLabel")
	label.Name                   = name
	label.Text                   = text
	label.Size                   = UDim2.new(1, 0, 0.20, 0)
	label.Position               = UDim2.new(0, 0, posY, 0)
	label.TextColor3             = color or Color3.new(1, 1, 1)
	label.TextScaled             = true
	label.Font                   = Enum.Font.GothamBold
	label.BackgroundTransparency = 1
	label.TextStrokeTransparency = 0.5
	label.TextStrokeColor3       = Color3.new(1, 1, 1)
	label.Parent                 = parent
	return label
end

local function SetupBillboard(brainrot, duration)
	local root = GetRootPart(brainrot)
	if not root then return nil end

	for _, child in ipairs(root:GetChildren()) do
		if child:IsA("BillboardGui") then child:Destroy() end
	end

	local rarete  = brainrot:GetAttribute("Rarete")         or "COMMON"
	local nomAff  = brainrot:GetAttribute("OriginalName")   or brainrot.Name
	local prix    = brainrot:GetAttribute("Prix")           or 0
	local cps     = brainrot:GetAttribute("CashParSeconde") or 0
	local couleur = RARETE_COULEURS[rarete] or Color3.new(1, 1, 1)

	local bb = Instance.new("BillboardGui")
	bb.Name         = BILLBOARD_NAME
	bb.Size         = UDim2.new(5, 0, 2.5, 0)
	bb.StudsOffset  = Vector3.new(0, BILLBOARD_STUDS_Y, 0)
	bb.AlwaysOnTop  = false
	bb.ResetOnSpawn = false
	bb.Parent       = root

	MakeLabel(bb, "LNom",   nomAff,                             0,    Color3.fromRGB(0, 0, 0))
	local lRarete =
	MakeLabel(bb, "LRarete", rarete,                            0.20, couleur)
	MakeLabel(bb, "LPrix",  "$" .. FormatNombre(prix),          0.40, Color3.fromRGB(0, 220, 0))
	MakeLabel(bb, "LCPS",   "$" .. FormatNombre(cps) .. "/s",  0.60, Color3.fromRGB(255, 215, 0))
	MakeLabel(bb, "LTimer", FormatTimer(duration),              0.80, Color3.fromRGB(220, 60, 60))

	if rarete == "GOD" or rarete == "BRAINROT_GOD" then
		local hue, conn = 0, nil
		conn = RunService.Heartbeat:Connect(function(dt)
			if not lRarete or not lRarete.Parent then conn:Disconnect() return end
			hue = (hue + dt * 0.5) % 1
			lRarete.TextColor3 = Color3.fromHSV(hue, 1, 1)
		end)
	elseif rarete == "SECRET" then
		lRarete.TextColor3 = Color3.fromRGB(255, 255, 255)
		TweenService:Create(lRarete,
			TweenInfo.new(0.3, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1, true),
			{ TextColor3 = Color3.fromRGB(20, 20, 20) }
		):Play()
	end

	return bb
end

local function UpdateBillboardTimer(brainrot, t)
	local root = GetRootPart(brainrot)
	if not root then return end
	local bb = root:FindFirstChild(BILLBOARD_NAME)
	if not bb then return end
	local label = bb:FindFirstChild("LTimer")
	if not label then return end
	label.Text = FormatTimer(t)
	if t <= 10 then label.TextColor3 = Color3.fromRGB(255, 30, 30) end
end

-- ─────────────────────────────────────────────────────────────
-- PICKUP — PROXIMITYPROMPT
-- ─────────────────────────────────────────────────────────────

local function SetupPickup(brainrot)
	local root = GetRootPart(brainrot)
	if not root then
		warn("[PickupSystem] Aucune BasePart sur", brainrot.Name, "— pickup ignoré")
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
			UpdateBillboardTimer(brainrot, t)
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

	local duration = brainrot:GetAttribute("LifeTime") or DEFAULT_LIFETIME
	SetupBillboard(brainrot, duration)
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

	print("[PickupSystem] ✓ Démarré — tag : '" .. TAG .. "'"
		.. " | hold:" .. PICKUP_HOLD_DURATION .. "s"
		.. " | dist:" .. PICKUP_MAX_DISTANCE .. " studs")
end

return PickupSystem
