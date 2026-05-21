--!strict
-- ============================================================================
-- AUDIT FUSE MACHINE — CPS exacts & ROI vs ZoneCommune
-- ============================================================================
-- À exécuter dans la Command Bar de Roblox Studio (vue Server).
-- Mode : LECTURE SEULE, ne modifie rien.
--
-- Output :
--   1. Inventaire complet des modèles dans ServerStorage/FuseBrainrots/
--   2. CPS par modèle (attribut CashParSeconde ou fallback)
--   3. Stats par rareté (min / median / max / count)
--   4. ROI Fuse vs ZoneCommune (temps d'amortissement)
--   5. Détection des anomalies (attributs manquants, CPS aberrants)
-- ============================================================================

local ServerStorage = game:GetService("ServerStorage")

-- ---------- CONFIG (à ajuster si paths différents) ----------------------------
local FUSE_FOLDER_PATH = "FuseBrainrots" -- enfant direct de ServerStorage
local CPS_ATTRIBUTE = "CashParSeconde"
local RARITY_ATTRIBUTE = "Rarete" -- ou "Rarity", à confirmer
local MUTATION_ATTRIBUTE = "Mutation" -- optionnel

-- Référence ZoneCommune (temps moyen pour obtenir un BR de ce tier en solo)
-- Source : tableau B de l'audit
local ZONE_COMMUNE_TIME_SECONDS = {
    MYTHIC = 8 * 60,           -- 8 min
    SECRET_T1 = 22 * 60,       -- 22 min
    SECRET_T2 = 200 * 60,      -- 200 min
    SECRET_T3 = 33 * 3600,     -- 33h
    SECRET_T4 = 333 * 3600,    -- 333h
    SECRET_T5 = 139 * 86400,   -- 139 jours
}

-- Coût Fuse : 4 BRs sacrifiés (FuseSystem.lua vérifie #toolInstances ~= 4)
local FUSE_INPUT_COUNT = 4
local FUSE_DURATION_SECONDS = 90 * 60 -- 1h30 (GameConfig.Fuse.FuseDuration = 5400)

-- ---------- HELPERS -----------------------------------------------------------
local function formatNumber(n)
    n = tonumber(n) or 0
    if n >= 1e9 then return string.format("%.2fB", n / 1e9)
    elseif n >= 1e6 then return string.format("%.2fM", n / 1e6)
    elseif n >= 1e3 then return string.format("%.2fk", n / 1e3)
    else return string.format("%.0f", n) end
end

local function formatDuration(seconds)
    if seconds < 60 then return string.format("%.0fs", seconds)
    elseif seconds < 3600 then return string.format("%.1fmin", seconds / 60)
    elseif seconds < 86400 then return string.format("%.1fh", seconds / 3600)
    else return string.format("%.1f jours", seconds / 86400) end
end

local function median(values)
    -- Filtre defensive : ne garder que les nombres
    local clean = {}
    for _, v in ipairs(values) do
        local n = tonumber(v)
        if n then table.insert(clean, n) end
    end
    if #clean == 0 then return 0 end
    table.sort(clean)
    local mid = math.floor(#clean / 2) + 1
    if #clean % 2 == 0 then
        return (clean[mid - 1] + clean[mid]) / 2
    end
    return clean[mid]
end

-- ---------- 1. SCAN FOLDER ----------------------------------------------------
print("\n" .. string.rep("=", 78))
print("AUDIT FUSE MACHINE — Scan de ServerStorage/" .. FUSE_FOLDER_PATH)
print(string.rep("=", 78))

local fuseFolder = ServerStorage:FindFirstChild(FUSE_FOLDER_PATH)
if not fuseFolder then
    warn("❌ Dossier ServerStorage/" .. FUSE_FOLDER_PATH .. " introuvable.")
    warn("   Vérifie le chemin. Alternatives possibles :")
    warn("   - ReplicatedStorage/FuseBrainrots")
    warn("   - ServerStorage/Fuse/Brainrots")
    warn("   - ServerStorage/Brainrots/Fuse")
    -- Tentative de fallback : lister ce qui existe dans ServerStorage
    print("\nContenu de ServerStorage (niveau 1) :")
    for _, child in ipairs(ServerStorage:GetChildren()) do
        print(string.format("  - %s (%s)", child.Name, child.ClassName))
    end
    return
end

local models = {}
local function collectModels(parent, depth)
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("Model") then
            table.insert(models, child)
        elseif child:IsA("Folder") and depth < 5 then
            collectModels(child, depth + 1) -- récursion sous-dossiers
        end
    end
end
collectModels(fuseFolder, 0)

print(string.format("\n✓ %d modèles trouvés dans %s", #models, fuseFolder:GetFullName()))

if #models == 0 then
    warn("Aucun modèle. Vérifie la structure du dossier.")
    return
end

-- ---------- 2. EXTRACT DATA ---------------------------------------------------
local data = {} -- { {name, cps, rarity, mutation, hasAttr, path, cpsType}, ... }
local missingAttr = 0
local typeIssues = {} -- modèles avec un type inattendu pour CashParSeconde

for _, model in ipairs(models) do
    local rawCps = model:GetAttribute(CPS_ATTRIBUTE)
    local rarity = model:GetAttribute(RARITY_ATTRIBUTE)
    local mutation = model:GetAttribute(MUTATION_ATTRIBUTE)

    local hasAttr = rawCps ~= nil
    local cps = 0
    local cpsType = type(rawCps)

    if not hasAttr then
        missingAttr += 1
    elseif cpsType == "number" then
        cps = rawCps
    elseif cpsType == "string" then
        -- Conversion string → number (cas trouvé en runtime)
        local converted = tonumber(rawCps)
        if converted then
            cps = converted
            table.insert(typeIssues, {
                name = model.Name,
                type = "string",
                value = rawCps,
            })
        else
            -- String non-numérique : on traite comme "missing"
            table.insert(typeIssues, {
                name = model.Name,
                type = "string (non-numeric)",
                value = tostring(rawCps),
            })
            cps = 0
        end
    else
        -- Type exotique (bool, table, Vector3, etc.)
        table.insert(typeIssues, {
            name = model.Name,
            type = cpsType,
            value = tostring(rawCps),
        })
        cps = 0
    end

    -- Inférer rareté depuis le nom si attribut absent
    if not rarity then
        local name = model.Name:upper()
        if name:find("BRAINROT_GOD") or name:find("BRAINROTGOD") then rarity = "BRAINROT_GOD"
        elseif name:find("GOD") then rarity = "BRAINROT_GOD"
        elseif name:find("SECRET") then rarity = "SECRET"
        elseif name:find("MYTHIC") then rarity = "MYTHIC"
        elseif name:find("LEGENDARY") then rarity = "LEGENDARY"
        elseif name:find("EPIC") then rarity = "EPIC"
        elseif name:find("RARE") then rarity = "RARE"
        elseif name:find("OG") then rarity = "OG"
        else rarity = "UNKNOWN" end
    end

    table.insert(data, {
        name = model.Name,
        cps = cps,
        rarity = rarity,
        mutation = mutation,
        hasAttr = hasAttr,
        path = model:GetFullName(),
    })
end

-- ---------- 3. INVENTAIRE PAR MODÈLE -----------------------------------------
print("\n" .. string.rep("-", 78))
print("INVENTAIRE COMPLET")
print(string.rep("-", 78))
print(string.format("%-35s %-12s %-12s %-10s %s", "Modèle", "Rareté", "CPS", "Mutation", "Attr?"))
print(string.rep("-", 78))

table.sort(data, function(a, b)
    local aRarity = tostring(a.rarity or "")
    local bRarity = tostring(b.rarity or "")
    if aRarity ~= bRarity then return aRarity < bRarity end
    local aCps = tonumber(a.cps) or 0
    local bCps = tonumber(b.cps) or 0
    return aCps > bCps
end)

for _, d in ipairs(data) do
    print(string.format(
        "%-35s %-12s %-12s %-10s %s",
        d.name:sub(1, 35),
        d.rarity,
        formatNumber(d.cps) .. " $/s",
        d.mutation or "-",
        d.hasAttr and "✓" or "❌ MISSING"
    ))
end

if missingAttr > 0 then
    warn(string.format("\n⚠️  %d modèles n'ont PAS l'attribut '%s' set.", missingAttr, CPS_ATTRIBUTE))
    warn("    Ces modèles tomberont sur le fallback IncomeParRarete.")
end

-- ---------- 4. STATS PAR RARETÉ ----------------------------------------------
print("\n" .. string.rep("-", 78))
print("STATS PAR RARETÉ (Fuse output)")
print(string.rep("-", 78))
print(string.format("%-14s %-8s %-15s %-15s %-15s", "Rareté", "Count", "Min CPS", "Median CPS", "Max CPS"))
print(string.rep("-", 78))

local byRarity = {}
for _, d in ipairs(data) do
    if d.hasAttr then
        byRarity[d.rarity] = byRarity[d.rarity] or {}
        table.insert(byRarity[d.rarity], d.cps)
    end
end

-- Ordre d'affichage (du plus faible au plus fort)
local rarityOrder = {"COMMON", "RARE", "EPIC", "LEGENDARY", "MYTHIC", "BRAINROT_GOD", "SECRET", "OG", "UNKNOWN"}
for _, rarity in ipairs(rarityOrder) do
    local values = byRarity[rarity]
    if values and #values > 0 then
        local minV, maxV = math.huge, 0
        local hasValid = false
        for _, v in ipairs(values) do
            local n = tonumber(v)
            if n then
                hasValid = true
                if n < minV then minV = n end
                if n > maxV then maxV = n end
            end
        end
        if not hasValid then minV = 0 end
        print(string.format(
            "%-14s %-8d %-15s %-15s %-15s",
            rarity, #values,
            formatNumber(minV) .. "/s",
            formatNumber(median(values)) .. "/s",
            formatNumber(maxV) .. "/s"
        ))
    end
end

-- ---------- 5. VÉRIFICATION TIERS (sanity check post-recalibration) -----------
print("\n" .. string.rep("-", 78))
print("SANITY CHECK — Seuils Fuse (GameConfig.Fuse.Tiers recalibrés)")
print(string.rep("-", 78))
-- Seuils post-recalibration β
local TIERS_ATTENDUS = {
    { maxTotal = 100,      rarity = "RARE"        },
    { maxTotal = 800,      rarity = "EPIC"        },
    { maxTotal = 5000,     rarity = "LEGENDARY"   },
    { maxTotal = 30000,    rarity = "MYTHIC"      },
    { maxTotal = 300000,   rarity = "BRAINROT_GOD"},
    { maxTotal = 5000000,  rarity = "SECRET"      },
    { maxTotal = math.huge, rarity = "SECRET (fallback)" },
}
for i, t in ipairs(TIERS_ATTENDUS) do
    local seuil = t.maxTotal == math.huge and "∞" or formatNumber(t.maxTotal)
    print(string.format("  Tier %d → %-18s (seuil CPS cumulé ≤ %s)", i, t.rarity, seuil))
end
print()
-- Vérifier que chaque rareté-tier a des modèles dans FuseBrainrots
local rariteParTier = { "RARE", "EPIC", "LEGENDARY", "MYTHIC", "BRAINROT_GOD", "SECRET" }
for tierIdx, rarity in ipairs(rariteParTier) do
    local tierFolder = fuseFolder:FindFirstChild("Tier_" .. tierIdx)
    if not tierFolder then
        warn(string.format("  ❌ Tier_%d manquant dans FuseBrainrots/ — relancer FillFuseTiers !", tierIdx))
    else
        local countInTier = 0
        for _, sub in ipairs(tierFolder:GetChildren()) do
            for _, m in ipairs(sub:GetChildren()) do
                if m:IsA("Model") then countInTier += 1 end
            end
        end
        local ok = countInTier > 0
        print(string.format("  %s Tier_%d (%s) : %d modèles",
            ok and "✓" or "❌", tierIdx, rarity, countInTier))
    end
end
-- Vérifier Tier_7 fallback
local tier7 = fuseFolder:FindFirstChild("Tier_7")
if tier7 then
    local count7 = 0
    for _, sub in ipairs(tier7:GetChildren()) do
        for _, m in ipairs(sub:GetChildren()) do
            if m:IsA("Model") then count7 += 1 end
        end
    end
    print(string.format("  %s Tier_7 (SECRET fallback) : %d modèles",
        count7 > 0 and "✓" or "❌ VIDE — relancer FillFuseTiers !", count7))
else
    warn("  ❌ Tier_7 manquant dans FuseBrainrots/ — relancer FillFuseTiers !")
end

-- ---------- 6. ROI FUSE vs ZONE COMMUNE --------------------------------------
print("\n" .. string.rep("-", 78))
print("ROI FUSE vs ZONE COMMUNE")
print(string.rep("-", 78))
print(string.format("Hypothèse : Fuse = %d BRs sacrifiés + %s d'attente",
    FUSE_INPUT_COUNT, formatDuration(FUSE_DURATION_SECONDS)))
print()

local mythicTime = ZONE_COMMUNE_TIME_SECONDS.MYTHIC
local fuseCostSeconds = (FUSE_INPUT_COUNT * mythicTime) + FUSE_DURATION_SECONDS

print(string.format("Coût Fuse total (en temps farming) : %s",
    formatDuration(fuseCostSeconds)))
print()

-- Référence : SECRET T1 via ZoneCommune
local secretT1Cps = 500000 -- $/s (audit Fuse.1 : SECRET T1 ZoneCommune = 500k $/s)
local secretT1Time = ZONE_COMMUNE_TIME_SECONDS.SECRET_T1

print(string.format("Référence : SECRET T1 = %s $/s, obtenu en %s via ZoneCommune",
    formatNumber(secretT1Cps), formatDuration(secretT1Time)))
print()

local godOutputs = byRarity["BRAINROT_GOD"] or {}
if #godOutputs > 0 then
    print("Output BRAINROT_GOD via Fuse vs SECRET T1 via ZoneCommune :")
    table.sort(godOutputs)
    local godMedian = median(godOutputs)

    print(string.format("  BRAINROT_GOD median CPS : %s $/s", formatNumber(godMedian)))
    print(string.format("  SECRET T1 CPS           : %s $/s", formatNumber(secretT1Cps)))

    if godMedian < secretT1Cps then
        local ratio = secretT1Cps / godMedian
        warn(string.format(
            "  ⚠️  SECRET T1 produit %.1fx plus de CPS que BRAINROT_GOD median !",
            ratio
        ))
        warn("      La Fuse Machine est un piège économique pour qui vise du SECRET.")
    else
        local ratio = godMedian / secretT1Cps
        print(string.format("  ✓ BRAINROT_GOD median produit %.1fx plus que SECRET T1", ratio))
    end

    print()
    print(string.format("Temps coût d'opportunité :"))
    print(string.format("  SECRET T1 (ZoneCommune) : %s", formatDuration(secretT1Time)))
    print(string.format("  BRAINROT_GOD via Fuse   : %s", formatDuration(fuseCostSeconds)))

    if fuseCostSeconds > secretT1Time and godMedian < secretT1Cps then
        warn("  ❌ Fuse Machine = plus longue ET moins productive que ZoneCommune.")
    end
else
    print("Aucun output BRAINROT_GOD trouvé dans les modèles scannés.")
    print("→ FillFuseTiers a peut-être besoin d'être relancé.")
end

-- ---------- 7. ANOMALIES -----------------------------------------------------
print("\n" .. string.rep("-", 78))
print("ANOMALIES DÉTECTÉES")
print(string.rep("-", 78))

local anomalies = 0

-- a) Type issues (CashParSeconde stocké avec un type inattendu)
if #typeIssues > 0 then
    warn(string.format("  ⚠️  %d modèles ont '%s' avec un type non-numérique :",
        #typeIssues, CPS_ATTRIBUTE))
    for _, issue in ipairs(typeIssues) do
        warn(string.format("       - %s : type=%s, valeur=\"%s\"",
            issue.name, issue.type, issue.value))
    end
    warn("       → À convertir en number pour cohérence.")
    anomalies += #typeIssues
end

-- b) CPS = 0
for _, d in ipairs(data) do
    if d.hasAttr and d.cps == 0 then
        warn(string.format("  - %s : CPS=0 mais attribut présent (bug config ?)", d.name))
        anomalies += 1
    end
end

-- c) CPS aberrant (> 10x le median du tier)
for _, d in ipairs(data) do
    if d.hasAttr and d.rarity ~= "UNKNOWN" then
        local med = median(byRarity[d.rarity] or {0})
        local dCps = tonumber(d.cps) or 0
        if med > 0 and dCps > med * 10 then
            warn(string.format(
                "  - %s : CPS=%s très au-dessus du median %s du tier %s",
                d.name, formatNumber(dCps), formatNumber(med), d.rarity
            ))
            anomalies += 1
        end
    end
end

-- d) Attribut manquant
if missingAttr > 0 then
    warn(string.format("  - %d modèles sans attribut %s", missingAttr, CPS_ATTRIBUTE))
    anomalies += missingAttr
end

if anomalies == 0 then
    print("  ✓ Aucune anomalie détectée.")
end

-- ---------- FIN --------------------------------------------------------------
print("\n" .. string.rep("=", 78))
print(string.format("AUDIT TERMINÉ — %d modèles analysés, %d anomalies", #models, anomalies))
print(string.rep("=", 78) .. "\n")
