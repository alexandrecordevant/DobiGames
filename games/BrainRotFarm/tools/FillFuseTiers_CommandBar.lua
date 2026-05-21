-- ================================================================
-- FILL FUSE TIERS — BrainRotFarm
-- Coller dans : Studio > View > Command Bar
-- Clone chaque brainrot de SS.Brainrots vers SS.FuseBrainrots/Tier_N/poids
-- ================================================================

local SS = game:GetService("ServerStorage")

-- ================================================================
-- CONFIG — ajuster ici selon la progression souhaitée
-- ================================================================

-- Rareté → numéro de tier de SORTIE (1-6)
-- Le tier est déterminé côté entrée par le CPS combiné des 4 inputs.
-- Ces brainrots sont ce que le joueur peut OBTENIR depuis ce tier.
-- Tier 7 = copie automatique de Tier 6 (fallback SECRET pour CPS > 5M).
local TIER_PAR_RARETE = {
	RARE         = 1,  -- fuse 4× Common  → reçoit un Rare
	EPIC         = 2,  -- fuse 4× Rare    → reçoit un Epic
	LEGENDARY    = 3,  -- fuse 4× Epic    → reçoit un Legendary
	MYTHIC       = 4,  -- fuse 4× Leg.    → reçoit un Mythic
	GOD          = 5,  -- fuse 4× Mythic  → reçoit un God
	BRAINROT_GOD = 5,  -- alias utilisé dans le jeu pour GOD
	SECRET       = 6,  -- fuse 4× God     → reçoit un Secret
}

-- Ces raretés ne sont pas mises en sortie de fuse
local IGNORER = { COMMON = true, ToUseAfter = true, LUCKY_BLOCK = true }

-- ================================================================
-- Sous-dossiers pondérés (ordre : plus faible → plus fort)
-- "50" = 50% de chance d'être sélectionné → brainrots les moins bons du tier
-- "2"  =  2% de chance                   → brainrots les meilleurs du tier
-- ================================================================
local POIDS = {
	{ key = "50", frac = 0.50 },
	{ key = "30", frac = 0.30 },
	{ key = "18", frac = 0.18 },
	{ key = "2",  frac = 0.02 },
}

-- ================================================================
-- UTILS
-- ================================================================

local source = SS:FindFirstChild("Brainrots")
assert(source, "[FillFuseTiers] ServerStorage.Brainrots introuvable !")
print("[FillFuseTiers] Source : " .. source:GetFullName())

-- Retrouve le dossier de rareté (enfant direct de SS.Brainrots)
-- Gère les sous-dossiers comme SECRET/1, SECRET/2, GOD/2, etc.
local function getRarity(inst)
	local p = inst.Parent
	while p and p ~= SS do
		if p.Parent == source then return p.Name end
		p = p.Parent
	end
	return nil
end

-- Récolte tous les modèles (non-Folder) de manière récursive
local function collectAll(root)
	local list = {}
	local function rec(f)
		for _, c in ipairs(f:GetChildren()) do
			if c:IsA("Folder") then rec(c)
			else table.insert(list, c) end
		end
	end
	rec(root)
	return list
end

-- Distribue une liste (triée par CPS croissant) dans les 4 sous-dossiers.
-- Si moins de 4 brainrots : tous les dossiers reçoivent tous les clones
-- (évite les dossiers vides qui bloquent la fuse machine).
local function distribuer(list, folders)
	local n = #list
	if n == 0 then return 0 end

	table.sort(list, function(a, b) return a.cps < b.cps end)

	local placed = 0

	if n < 4 then
		for _, p in ipairs(POIDS) do
			for _, item in ipairs(list) do
				item.inst:Clone().Parent = folders[p.key]
				placed += 1
			end
		end
		return placed
	end

	-- Tailles proportionnelles, minimum 1 par dossier.
	-- Approche cumulative : chaque dossier réserve 1 slot aux suivants pour
	-- garantir que le dernier ("2") reçoit toujours au moins 1 brainrot.
	local sizes = {}
	local assigned = 0
	for i, p in ipairs(POIDS) do
		if i < #POIDS then
			local slotsRestants = #POIDS - i          -- dossiers encore à servir après celui-ci
			local plafond = n - assigned - slotsRestants  -- on garde 1 slot par dossier suivant
			sizes[i] = math.min(math.max(1, math.floor(n * p.frac)), math.max(1, plafond))
			assigned += sizes[i]
		else
			sizes[i] = math.max(1, n - assigned)
		end
	end

	local idx = 1
	for i, p in ipairs(POIDS) do
		for _ = 1, sizes[i] do
			if idx > n then break end
			list[idx].inst:Clone().Parent = folders[p.key]
			placed += 1
			idx += 1
		end
	end
	return placed
end

-- ================================================================
-- MAIN
-- ================================================================

-- Recréer SS.FuseBrainrots de zéro
local dest = SS:FindFirstChild("FuseBrainrots")
if dest then dest:Destroy() ; task.wait() end
dest = Instance.new("Folder")
dest.Name = "FuseBrainrots"
dest.Parent = SS

-- Structure Tier_1..Tier_7 / "50" / "30" / "18" / "2"
local tierFolders = {}
for t = 1, 7 do
	local tf = Instance.new("Folder")
	tf.Name = "Tier_" .. t
	tf.Parent = dest
	tierFolders[t] = {}
	for _, p in ipairs(POIDS) do
		local pf = Instance.new("Folder")
		pf.Name = p.key
		pf.Parent = tf
		tierFolders[t][p.key] = pf
	end
end

-- Regrouper les brainrots par tier
local byTier = {}
for t = 1, 7 do byTier[t] = {} end
local skipped = {}

for _, inst in ipairs(collectAll(source)) do
	local rarity = getRarity(inst)
	if rarity and IGNORER[rarity] then
		-- ignoré volontairement
	elseif rarity and TIER_PAR_RARETE[rarity] then
		local cps = tonumber(inst:GetAttribute("CashParSeconde")) or 0
		table.insert(byTier[TIER_PAR_RARETE[rarity]], { inst = inst, cps = cps })
	else
		table.insert(skipped, inst.Name .. (rarity and " [" .. rarity .. "]" or " [rareté inconnue]"))
	end
end

-- Remplir chaque tier et afficher le bilan
local totalPlaced = 0
print("[FillFuseTiers] Remplissage en cours...")
for t = 1, 7 do
	local list = byTier[t]
	local n = distribuer(list, tierFolders[t])
	totalPlaced += n
	if n > 0 then
		print(string.format("  Tier_%d : %d clones  (%d sources uniques)", t, n, #list))
	end
end

-- Tier 7 = copie de Tier 6 (fallback SECRET — empêche output nil si CPS > 5M)
local nbFallback = 0
for _, p in ipairs(POIDS) do
	local src = tierFolders[6] and tierFolders[6][p.key]
	local dst = tierFolders[7] and tierFolders[7][p.key]
	if src and dst then
		for _, child in ipairs(src:GetChildren()) do
			child:Clone().Parent = dst
			nbFallback += 1
		end
	end
end
if nbFallback > 0 then
	print(string.format("  Tier_7 (fallback SECRET) : %d clones copiés de Tier_6", nbFallback))
end

print(string.format("[FillFuseTiers] ✓ %d clones placés dans SS.FuseBrainrots", totalPlaced + nbFallback))

if #skipped > 0 then
	warn(string.format("[FillFuseTiers] ⚠ %d ignorés (rareté non mappée) :", #skipped))
	for _, s in ipairs(skipped) do warn("  • " .. s) end
end
