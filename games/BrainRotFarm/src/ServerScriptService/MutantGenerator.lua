-- ServerScriptService/Specialized/MutantGenerator.lua
-- DobiGames — Génère des BR Mutants depuis une graine MYTHIC/SECRET
-- Types disponibles : GALAXY (×2) | TOXIC (×4) | RAINBOW (×6) | VOID (×8)
-- Rareté finale TOUJOURS COMMON/OG/RARE (jamais MYTHIC/SECRET)
-- SECRET seed = meilleures chances RARE | MYTHIC seed = plus souvent COMMON/OG
-- Effets visuels via FilterManager uniquement — aucune modification directe des BR

local MutantGenerator = {}

-- ============================================================
-- Services
-- ============================================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Logger            = require(game:GetService("ServerScriptService").SharedLib.Server.Logger)
local _GameConfig       = require(ReplicatedStorage:WaitForChild("GameConfig"))

-- Chargement différé FilterManager (évite erreur si BRFilterSystem pas encore chargé)
local _FilterManager = nil
local function getFilterManager()
    if not _FilterManager then
        local ok, m = pcall(function()
            return require(game:GetService("ServerScriptService"):WaitForChild("SharedLib")
                :WaitForChild("BRFilterSystem")
                :WaitForChild("FilterManager"))
        end)
        if ok and m then _FilterManager = m end
    end
    return _FilterManager
end

-- ============================================================
-- Configuration des types Mutants (lue depuis GameConfig.MutantTypes)
-- ============================================================

-- Construction de MUTANT_CONFIG depuis GameConfig pour éviter toute valeur hardcodée
local MUTANT_CONFIG = {}
local MUTANT_NAMES  = {}

for _, mt in ipairs(_GameConfig.MutantTypes) do
    MUTANT_CONFIG[mt.Name] = {
        nomFiltre  = mt.Filtre,
        nomDisplay = mt.Emoji .. " BR Mutant " .. mt.Name,
        couleur    = mt.Color,
        multiplier = mt.Multiplier,
    }
    table.insert(MUTANT_NAMES, mt.Name)
end

-- Poids rareté selon type de graine (jamais MYTHIC/SECRET — seulement COMMON/OG/RARE)
local POIDS_RARETE = {
    SECRET = { COMMON = 30, OG = 40, RARE = 30 },  -- SECRET seed : meilleures chances RARE
    MYTHIC = { COMMON = 50, OG = 35, RARE = 15 },  -- MYTHIC seed : plus souvent COMMON/OG
}

-- ============================================================
-- Utilitaires internes
-- ============================================================

-- Tirage pondéré (table { NOM = poids, ... })
local function tirerPondere(poids)
    local total = 0
    for _, p in pairs(poids) do total = total + p end
    local r     = math.random() * total
    local cumul = 0
    for nom, p in pairs(poids) do
        cumul = cumul + p
        if r <= cumul then return nom end
    end
    return "COMMON"  -- Fallback
end

-- Tirage type Mutant aléatoire (uniforme sur MUTANT_NAMES)
local function tirerMutantType()
    return MUTANT_NAMES[math.random(1, #MUTANT_NAMES)]
end

-- ============================================================
-- API publique
-- ============================================================

--[[
    Génère un BR Mutant depuis une graine

    @param seedRarity  (string)  — "MYTHIC" ou "SECRET"
    @param mutantType  (string, optionnel) — "GALAXY"/"TOXIC"/"RAINBOW"/"VOID" (aléatoire si nil)
    @return clone (Model), finalRarity (string), mutantType (string)
            ou nil, nil, nil en cas d'échec
]]
function MutantGenerator.Generate(seedRarity, mutantType)
    local brainrots = ReplicatedStorage:FindFirstChild("Brainrots")
    if not brainrots then
        Logger.warn("Spawn", "ReplicatedStorage.Brainrots introuvable")
        return nil, nil, nil
    end

    -- Choisir rareté finale (COMMON/OG/RARE uniquement)
    local poids       = POIDS_RARETE[seedRarity] or POIDS_RARETE.MYTHIC
    local finalRarity = tirerPondere(poids)

    -- Choisir ou valider le type Mutant
    if not mutantType or not MUTANT_CONFIG[mutantType] then
        mutantType = tirerMutantType()
    end
    local elemCfg = MUTANT_CONFIG[mutantType]

    -- Cloner un BR de la rareté sélectionnée
    local dossier = brainrots:FindFirstChild(finalRarity)
    if not dossier then
        Logger.warn("Spawn", "Dossier introuvable : %s", finalRarity)
        return nil, nil, nil
    end

    local modeles = dossier:GetChildren()
    if #modeles == 0 then
        Logger.warn("Spawn", "Dossier vide : %s", finalRarity)
        return nil, nil, nil
    end

    local clone = nil
    local ok = pcall(function()
        clone = modeles[math.random(1, #modeles)]:Clone()
    end)
    if not ok or not clone then
        Logger.warn("Spawn", "Échec clone BR %s", finalRarity)
        return nil, nil, nil
    end

    -- Ancrer + désactiver collision sur toutes les parts
    for _, part in ipairs(clone:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function()
                part.Anchored   = true
                part.CanCollide = false
                part.CanTouch   = false
            end)
        end
    end
    if clone:IsA("BasePart") then
        pcall(function()
            clone.Anchored   = true
            clone.CanCollide = false
            clone.CanTouch   = false
        end)
    end

    -- Attributs + nom (avant les filtres pour que le Billboard ait le bon ObjectText)
    pcall(function()
        clone:SetAttribute("MutantType",  mutantType)
        clone:SetAttribute("Rarete",      finalRarity)
        clone:SetAttribute("IsMutant",    true)
        clone:SetAttribute("SeedRarity",  seedRarity)
        clone.Name = elemCfg.nomDisplay
    end)

    -- Calculer la valeur du mutant (income base × multiplicateur du type)
    local incomeBase   = (_GameConfig.IncomeParRarete and _GameConfig.IncomeParRarete[finalRarity]) or 0
    local multElement  = elemCfg.multiplier or 1
    local valeurMutant = incomeBase * multElement
    -- Stocker CashParSeconde sur le clone (lu par DropSystem et les billboards)
    pcall(function() clone:SetAttribute("CashParSeconde", valeurMutant) end)
    local valeurTexte  = valeurMutant > 0 and ("  💰 " .. valeurMutant .. "/s") or ""

    -- Appliquer les effets visuels via FilterManager (seul point d'entrée autorisé)
    local FM = getFilterManager()
    if FM then
        FM.Apply(clone, {
            {Name = elemCfg.nomFiltre},   -- MutantGALAXY / MutantTOXIC / MutantRAINBOW / MutantVOID
            {Name = "Normal"},             -- Scale 1×
            {Name = "Billboard", Params = {
                Text    = elemCfg.nomDisplay .. valeurTexte,
                Color   = elemCfg.couleur,
                OffsetY = 6,
            }},
        })
    else
        Logger.warn("Spawn", "FilterManager indisponible — effets visuels ignorés")
    end

    Logger.info("Spawn", "%s (%s) depuis graine %s", elemCfg.nomDisplay, finalRarity, seedRarity)

    return clone, finalRarity, mutantType
end

--[[
    Retourne la config complète d'un type Mutant

    @param mutantType (string) — "GALAXY"/"TOXIC"/"RAINBOW"/"VOID"
    @return table ou nil
]]
function MutantGenerator.GetMutantConfig(mutantType)
    return MUTANT_CONFIG[mutantType]
end

--[[
    Retourne la liste des types Mutants disponibles

    @return table { "GALAXY", "TOXIC", "RAINBOW", "VOID" }
]]
function MutantGenerator.GetMutantTypes()
    return MUTANT_NAMES
end

return MutantGenerator
