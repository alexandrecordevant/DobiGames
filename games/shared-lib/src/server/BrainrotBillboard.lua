-- ServerScriptService/SharedLib/Server/BrainrotBillboard.lua
-- DobiGames shared-lib — Billboard multi-lignes au-dessus des Brain Rots
--
-- SetupField(brainrot, duration, studsY)  → champ  : Nom + Rareté + Prix + CPS/s + Timer
-- SetupBase(brainrot, studsY)             → base   : Nom + Rareté + Prix + CPS/s (sans timer)
-- UpdateTimer(brainrot, t)               → met à jour LTimer (appelé chaque seconde)
--
-- PRÉREQUIS sur le brainrot :
--   Attribut "Rarete"         string
--   Attribut "OriginalName"   string
--   Attribut "Prix"           number  (optionnel)
--   Attribut "CashParSeconde" number  (optionnel)

local BrainrotBillboard = {}

local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- ─────────────────────────────────────────────────────────────
-- Configuration
-- ─────────────────────────────────────────────────────────────

local BILLBOARD_NAME    = "_BRBillboard"
local STUDS_Y_FIELD     = 7   -- hauteur par défaut — champ
local STUDS_Y_BASE      = 4   -- hauteur par défaut — base (slot dépôt)

-- ─────────────────────────────────────────────────────────────
-- Couleurs par rareté
-- ─────────────────────────────────────────────────────────────

local RARETE_COULEURS = {
	COMMON       = Color3.fromRGB(200, 200, 200),
	OG           = Color3.fromRGB(100, 220, 255),
	RARE         = Color3.fromRGB(0,   120, 255),
	EPIC         = Color3.fromRGB(150,   0, 255),
	LEGENDARY    = Color3.fromRGB(255, 200,   0),
	MYTHIC       = Color3.fromRGB(148,   0, 211),
	GOD          = Color3.fromRGB(255, 140,   0),
	BRAINROT_GOD = Color3.fromRGB(255, 140,   0),
	SECRET       = Color3.fromRGB(255, 255, 255),
}

-- ─────────────────────────────────────────────────────────────
-- Utilitaires internes
-- ─────────────────────────────────────────────────────────────

local function GetRootPart(instance)
	if instance:IsA("Model") then
		return instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
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

local function AppliquerAnimationRarete(lRarete, rarete)
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
end

local function CreerBillboardGui(root, studsY, nbLignes)
	local existing = root:FindFirstChild(BILLBOARD_NAME)
	if existing then pcall(function() existing:Destroy() end) end

	local bb = Instance.new("BillboardGui")
	bb.Name         = BILLBOARD_NAME
	bb.Size         = UDim2.new(5, 0, nbLignes * 0.5, 0)
	bb.StudsOffset  = Vector3.new(0, studsY, 0)
	bb.AlwaysOnTop  = false
	bb.ResetOnSpawn = false
	bb.Parent       = root
	return bb
end

-- ─────────────────────────────────────────────────────────────
-- API publique
-- ─────────────────────────────────────────────────────────────

--[[
    SetupField — Billboard champ (avec timer)
    Nom · Rareté · $Prix · $CPS/s · Timer

    @param brainrot  Model|BasePart
    @param duration  number  — durée initiale du timer (secondes)
    @param studsY    number? — hauteur override (défaut : 7)
]]
function BrainrotBillboard.SetupField(brainrot, duration, studsY)
	local root = GetRootPart(brainrot)
	if not root then return end

	local rarete  = brainrot:GetAttribute("Rarete")         or "COMMON"
	local nomAff  = brainrot:GetAttribute("OriginalName")   or brainrot.Name
	local prix    = brainrot:GetAttribute("Prix")           or 0
	local cps     = brainrot:GetAttribute("CashParSeconde") or 0
	local couleur = RARETE_COULEURS[rarete] or Color3.new(1, 1, 1)

	local bb = CreerBillboardGui(root, studsY or STUDS_Y_FIELD, 5)

	MakeLabel(bb, "LNom",   nomAff,                             0,    Color3.fromRGB(255, 255, 255))
	local lRarete =
	MakeLabel(bb, "LRarete", rarete,                            0.20, couleur)
	MakeLabel(bb, "LPrix",  "$" .. FormatNombre(prix),          0.40, Color3.fromRGB(0, 220, 0))
	MakeLabel(bb, "LCPS",   "$" .. FormatNombre(cps) .. "/s",  0.60, Color3.fromRGB(255, 215, 0))
	MakeLabel(bb, "LTimer", FormatTimer(duration or 0),         0.80, Color3.fromRGB(220, 60, 60))

	AppliquerAnimationRarete(lRarete, rarete)
end

--[[
    SetupBase — Billboard base/slot (sans timer)
    Nom · Rareté · $Prix · $CPS/s

    @param brainrot  Model|BasePart
    @param studsY    number? — hauteur override (défaut : 4)
]]
function BrainrotBillboard.SetupBase(brainrot, studsY)
	local root = GetRootPart(brainrot)
	if not root then return end

	local rarete  = brainrot:GetAttribute("Rarete")         or "COMMON"
	local nomAff  = brainrot:GetAttribute("OriginalName")   or brainrot.Name
	local prix    = brainrot:GetAttribute("Prix")           or 0
	local cps     = brainrot:GetAttribute("CashParSeconde") or 0
	local couleur = RARETE_COULEURS[rarete] or Color3.new(1, 1, 1)

	local bb = CreerBillboardGui(root, studsY or STUDS_Y_BASE, 4)

	MakeLabel(bb, "LNom",   nomAff,                             0,    Color3.fromRGB(255, 255, 255))
	local lRarete =
	MakeLabel(bb, "LRarete", rarete,                            0.25, couleur)
	MakeLabel(bb, "LPrix",  "$" .. FormatNombre(prix),          0.50, Color3.fromRGB(0, 220, 0))
	MakeLabel(bb, "LCPS",   "$" .. FormatNombre(cps) .. "/s",  0.75, Color3.fromRGB(255, 215, 0))

	AppliquerAnimationRarete(lRarete, rarete)
end

--[[
    UpdateTimer — Met à jour le label LTimer du billboard champ

    @param brainrot  Model|BasePart
    @param t         number  — secondes restantes
]]
function BrainrotBillboard.UpdateTimer(brainrot, t)
	local root = GetRootPart(brainrot)
	if not root then return end
	local bb = root:FindFirstChild(BILLBOARD_NAME)
	if not bb then return end
	local label = bb:FindFirstChild("LTimer")
	if not label then return end
	label.Text = FormatTimer(t)
	if t <= 10 then label.TextColor3 = Color3.fromRGB(255, 30, 30) end
end

return BrainrotBillboard
