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
local STUDS_Y_BASE      = 6   -- hauteur par défaut — base (slot dépôt)

-- ─────────────────────────────────────────────────────────────
-- Couleurs par rareté
-- ─────────────────────────────────────────────────────────────

-- Couleurs/textes des mutations LavaTower (GOLD/DIAMANT/RAINBOW)
-- Le multiplicateur est affiché dans le label pour que le joueur comprenne la source du bonus.
local MUTATION_INFOS = {
	GOLD    = { texte = "Gold",    couleur = Color3.fromRGB(255, 215,   0) },
	DIAMANT = { texte = "Diamant", couleur = Color3.fromRGB(130, 220, 255) },
	RAINBOW = { texte = "Rainbow", couleur = Color3.fromRGB(255, 100, 255) },
}

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

local function MakeLabel(parent, name, text, posY, color, strokeColor)
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
	label.TextStrokeColor3       = strokeColor or Color3.new(1, 1, 1)
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

local TOXIC_COLOR_A  = Color3.fromRGB(0,   255,  80)
local TOXIC_COLOR_B  = Color3.fromRGB(120, 255,  60)
local NEBULA_COLOR_A = Color3.fromRGB(255, 100, 255)
local NEBULA_COLOR_B = Color3.fromRGB(180,   0, 255)

-- Couleurs des mutations LuckyHour / champ perso (IsMutated + MutationType)
local LUCKY_MUTATION_COLORS = {
    BrainrotsToxic   = Color3.fromRGB(0,   220,   0),
    BrainrotsLava    = Color3.fromRGB(255,  80,   0),
    BrainrotsGold    = Color3.fromRGB(255, 200,   0),
    BrainrotsDiamant = Color3.fromRGB(0,   200, 255),
    BrainrotsRainbow = Color3.fromRGB(255, 255, 255),
    BrainrotsNebula  = Color3.fromRGB(160,   0, 255),
    CrazyBrainrots   = Color3.fromRGB(255,   0, 200),
}

local function AppliquerAnimationToxic(label)
	TweenService:Create(label,
		TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ TextColor3 = TOXIC_COLOR_B }
	):Play()
end

local function AppliquerAnimationNebula(label)
	label.TextColor3 = NEBULA_COLOR_A
	TweenService:Create(label,
		TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ TextColor3 = NEBULA_COLOR_B }
	):Play()
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

	local rarete     = brainrot:GetAttribute("Rarete")         or "COMMON"
	local nomAff     = brainrot:GetAttribute("OriginalName")   or brainrot.Name
	local prix       = brainrot:GetAttribute("Prix")           or 0
	local cps        = brainrot:GetAttribute("CashParSeconde") or 0
	local isMutant    = brainrot:GetAttribute("IsMutant")
	local mutantType  = brainrot:GetAttribute("MutantType")
	local isToxic     = brainrot:GetAttribute("IsToxic")
	local isNebula    = brainrot:GetAttribute("IsNebula")
	-- Mutations LuckyHour / champ perso
	local isMutated   = brainrot:GetAttribute("IsMutated")
	local mutationType = brainrot:GetAttribute("MutationType")
	local couleur     = RARETE_COULEURS[rarete] or Color3.new(1, 1, 1)

	local function ajouterLabelSpecial(bb, s)
		local off = 0
		if isToxic then
			local lTox = MakeLabel(bb, "LToxic",  "TOXIC",  0, TOXIC_COLOR_A,  Color3.new(0, 0, 0))
			AppliquerAnimationToxic(lTox)
			off = s
		elseif isNebula then
			local lNeb = MakeLabel(bb, "LNebula", "NEBULA", 0, NEBULA_COLOR_A, Color3.new(0, 0, 0))
			AppliquerAnimationNebula(lNeb)
			off = s
		elseif isMutated and mutationType then
			local mutCol  = LUCKY_MUTATION_COLORS[mutationType] or Color3.fromRGB(255, 255, 255)
			local mutTag  = mutationType:gsub("Brainrots", ""):upper()
			local lMut    = MakeLabel(bb, "LMutated", mutTag, 0, mutCol, Color3.new(0, 0, 0))
			-- Animation Rainbow
			if mutationType == "BrainrotsRainbow" then
				local hue, conn = 0, nil
				conn = RunService.Heartbeat:Connect(function(dt)
					if not lMut or not lMut.Parent then conn:Disconnect() return end
					hue = (hue + dt * 0.8) % 1
					lMut.TextColor3 = Color3.fromHSV(hue, 1, 1)
				end)
			end
			off = s
		end
		return off
	end

	local hasSpecial = isToxic or isNebula or (isMutated and mutationType ~= nil)

	if isMutant and mutantType then
		local n  = hasSpecial and 7 or 6
		local s  = 1 / n
		local bb = CreerBillboardGui(root, studsY or STUDS_Y_FIELD, n)
		local off = ajouterLabelSpecial(bb, s)
		MakeLabel(bb, "LNom",    nomAff,                            off,       Color3.fromRGB(255, 255, 255), Color3.new(0, 0, 0))
		MakeLabel(bb, "LMutant", "✨ Mutant " .. mutantType,        off + s,   Color3.fromRGB(255, 215, 0))
		local lRarete =
		MakeLabel(bb, "LRarete", rarete,                            off + s*2, couleur)
		MakeLabel(bb, "LPrix",  "$" .. FormatNombre(prix),          off + s*3, Color3.fromRGB(0, 220, 0))
		MakeLabel(bb, "LCPS",   "$" .. FormatNombre(cps) .. "/s",  off + s*4, Color3.fromRGB(255, 215, 0))
		MakeLabel(bb, "LTimer", FormatTimer(duration or 0),         off + s*5, Color3.fromRGB(220, 60, 60))
		AppliquerAnimationRarete(lRarete, rarete)
	else
		local n  = hasSpecial and 6 or 5
		local s  = 1 / n
		local bb = CreerBillboardGui(root, studsY or STUDS_Y_FIELD, n)
		local off = ajouterLabelSpecial(bb, s)
		MakeLabel(bb, "LNom",   nomAff,                             off,       Color3.fromRGB(255, 255, 255), Color3.new(0, 0, 0))
		local lRarete =
		MakeLabel(bb, "LRarete", rarete,                            off + s,   couleur)
		MakeLabel(bb, "LPrix",  "$" .. FormatNombre(prix),          off + s*2, Color3.fromRGB(0, 220, 0))
		MakeLabel(bb, "LCPS",   "$" .. FormatNombre(cps) .. "/s",  off + s*3, Color3.fromRGB(255, 215, 0))
		MakeLabel(bb, "LTimer", FormatTimer(duration or 0),         off + s*4, Color3.fromRGB(220, 60, 60))
		AppliquerAnimationRarete(lRarete, rarete)
	end
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

	local rarete     = brainrot:GetAttribute("Rarete")         or "COMMON"
	local nomAff     = brainrot:GetAttribute("OriginalName")   or brainrot.Name
	local prix       = brainrot:GetAttribute("Prix")           or 0
	local cps        = brainrot:GetAttribute("CashParSeconde") or 0
	local isMutant     = brainrot:GetAttribute("IsMutant")
	local mutantType   = brainrot:GetAttribute("MutantType")
	local mutation     = brainrot:GetAttribute("Mutation")   -- LavaTower: "GOLD"|"DIAMANT"|"RAINBOW"
	local isToxic      = brainrot:GetAttribute("IsToxic")
	local isNebula     = brainrot:GetAttribute("IsNebula")
	-- Mutations LuckyHour / champ perso
	local isMutated    = brainrot:GetAttribute("IsMutated")
	local mutationType = brainrot:GetAttribute("MutationType")
	local couleur      = RARETE_COULEURS[rarete] or Color3.new(1, 1, 1)

	local hasSpecial = isToxic or isNebula or (isMutated and mutationType ~= nil)

	local function ajouterLabelSpecialBase(bb, s)
		local off = 0
		if isToxic then
			local lTox = MakeLabel(bb, "LToxic",  "TOXIC",  0, TOXIC_COLOR_A,  Color3.new(0, 0, 0))
			AppliquerAnimationToxic(lTox)
			off = s
		elseif isNebula then
			local lNeb = MakeLabel(bb, "LNebula", "NEBULA", 0, NEBULA_COLOR_A, Color3.new(0, 0, 0))
			AppliquerAnimationNebula(lNeb)
			off = s
		elseif isMutated and mutationType then
			local mutCol = LUCKY_MUTATION_COLORS[mutationType] or Color3.fromRGB(255, 255, 255)
			local mutTag = mutationType:gsub("Brainrots", ""):upper()
			local lMut   = MakeLabel(bb, "LMutated", mutTag, 0, mutCol, Color3.new(0, 0, 0))
			if mutationType == "BrainrotsRainbow" then
				local hue, conn = 0, nil
				conn = RunService.Heartbeat:Connect(function(dt)
					if not lMut or not lMut.Parent then conn:Disconnect() return end
					hue = (hue + dt * 0.8) % 1
					lMut.TextColor3 = Color3.fromHSV(hue, 1, 1)
				end)
			end
			off = s
		end
		return off
	end

	if isMutant and mutantType then
		local n  = hasSpecial and 6 or 5
		local s  = 1 / n
		local bb = CreerBillboardGui(root, studsY or STUDS_Y_BASE, n)
		local off = ajouterLabelSpecialBase(bb, s)
		MakeLabel(bb, "LNom",    nomAff,                            off,       Color3.fromRGB(255, 255, 255), Color3.new(0, 0, 0))
		MakeLabel(bb, "LMutant", "✨ Mutant " .. mutantType,        off + s,   Color3.fromRGB(255, 215, 0))
		local lRarete =
		MakeLabel(bb, "LRarete", rarete,                            off + s*2, couleur)
		MakeLabel(bb, "LPrix",  "$" .. FormatNombre(prix),          off + s*3, Color3.fromRGB(0, 220, 0))
		MakeLabel(bb, "LCPS",   "$" .. FormatNombre(cps) .. "/s",  off + s*4, Color3.fromRGB(255, 215, 0))
		AppliquerAnimationRarete(lRarete, rarete)
	elseif mutation and MUTATION_INFOS[mutation] then
		local mutInfo    = MUTATION_INFOS[mutation]
		local showRarete = rarete:upper() ~= mutation
		local baseLines  = showRarete and 5 or 4
		local n          = hasSpecial and (baseLines + 1) or baseLines
		local s          = 1 / n
		local bb         = CreerBillboardGui(root, studsY or STUDS_Y_BASE, n)
		local off = ajouterLabelSpecialBase(bb, s)
		MakeLabel(bb, "LNom",      nomAff,        off,     Color3.fromRGB(255, 255, 255), Color3.new(0, 0, 0))
		local lMut =
		MakeLabel(bb, "LMutation", mutInfo.texte, off + s, mutInfo.couleur)
		local nextOff = off + s * 2
		if showRarete then
			local lRarete = MakeLabel(bb, "LRarete", rarete, nextOff, couleur)
			AppliquerAnimationRarete(lRarete, rarete)
			nextOff = nextOff + s
		end
		MakeLabel(bb, "LPrix", "$" .. FormatNombre(prix),         nextOff,     Color3.fromRGB(0, 220, 0))
		MakeLabel(bb, "LCPS",  "$" .. FormatNombre(cps) .. "/s", nextOff + s, Color3.fromRGB(255, 215, 0))
		if mutation == "RAINBOW" then
			local hue, conn = 0, nil
			conn = RunService.Heartbeat:Connect(function(dt)
				if not lMut or not lMut.Parent then conn:Disconnect() return end
				hue = (hue + dt * 0.8) % 1
				lMut.TextColor3 = Color3.fromHSV(hue, 1, 1)
			end)
		end
	else
		local n  = hasSpecial and 5 or 4
		local s  = 1 / n
		local bb = CreerBillboardGui(root, studsY or STUDS_Y_BASE, n)
		local off = ajouterLabelSpecialBase(bb, s)
		MakeLabel(bb, "LNom",   nomAff,                             off,       Color3.fromRGB(255, 255, 255), Color3.new(0, 0, 0))
		local lRarete =
		MakeLabel(bb, "LRarete", rarete,                            off + s,   couleur)
		MakeLabel(bb, "LPrix",  "$" .. FormatNombre(prix),          off + s*2, Color3.fromRGB(0, 220, 0))
		MakeLabel(bb, "LCPS",   "$" .. FormatNombre(cps) .. "/s",  off + s*3, Color3.fromRGB(255, 215, 0))
		AppliquerAnimationRarete(lRarete, rarete)
	end
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
