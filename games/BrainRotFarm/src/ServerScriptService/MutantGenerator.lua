-- ServerScriptService/Specialized/MutantGenerator.lua
-- DobiGames — Génère des BR Mutants élémentaires depuis une graine MYTHIC/SECRET
-- Rareté finale TOUJOURS COMMON/OG/RARE (jamais MYTHIC/SECRET)
-- SECRET seed = meilleures chances RARE | MYTHIC seed = plus souvent COMMON/OG
-- Refactorisé : effets visuels via FilterManager (plus de part.Color ni BillboardHelper direct)

local MutantGenerator = {}

-- ============================================================
-- Services
-- ============================================================
local ServerStorage     = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Chargement différé FilterManager (évite erreur si BRFilterSystem pas encore chargé)
local _FilterManager = nil
local function getFilterManager()
    if not _FilterManager then
        local ok, m = pcall(function()
            return require(ReplicatedStorage:WaitForChild("SharedLib")
                :WaitForChild("BRFilterSystem")
                :WaitForChild("FilterManager"))
        end)
        if ok and m then _FilterManager = m end
    end
    return _FilterManager
end

-- ============================================================
-- Configuration élémentaire
-- ============================================================
local ELEMENT_CONFIG = {
    EAU = {
        nomFiltre  = "ElementEau",
        nomDisplay = "🌊 BR Mutant EAU",
        couleur    = Color3.fromRGB(0,   150, 255),
    },
    FEU = {
        nomFiltre  = "ElementFeu",
        nomDisplay = "🔥 BR Mutant FEU",
        couleur    = Color3.fromRGB(255, 80,  0),
    },
    TERRE = {
        nomFiltre  = "ElementTerre",
        nomDisplay = "🌍 BR Mutant TERRE",
        couleur    = Color3.fromRGB(100, 150, 50),
    },
    VENT = {
        nomFiltre  = "ElementVent",
        nomDisplay = "💨 BR Mutant VENT",
        couleur    = Color3.fromRGB(200, 200, 220),
    },
}

local ELEMENTS = { "EAU", "FEU", "TERRE", "VENT" }

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

-- Tirage élément aléatoire
local function tirerElement()
    return ELEMENTS[math.random(1, #ELEMENTS)]
end

-- ============================================================
-- API publique
-- ============================================================

--[[
    Génère un BR Mutant élémentaire depuis une graine

    @param seedRarity  (string)  — "MYTHIC" ou "SECRET"
    @param elementType (string, optionnel) — "EAU"/"FEU"/"TERRE"/"VENT" (aléatoire si nil)
    @return clone (Model), finalRarity (string), elementType (string)
            ou nil, nil, nil en cas d'échec
]]
function MutantGenerator.Generate(seedRarity, elementType)
    local brainrots = ServerStorage:FindFirstChild("Brainrots")
    if not brainrots then
        warn("[MutantGenerator] ServerStorage.Brainrots introuvable")
        return nil, nil, nil
    end

    -- Choisir rareté finale (COMMON/OG/RARE uniquement)
    local poids       = POIDS_RARETE[seedRarity] or POIDS_RARETE.MYTHIC
    local finalRarity = tirerPondere(poids)

    -- Choisir ou valider l'élément
    if not elementType or not ELEMENT_CONFIG[elementType] then
        elementType = tirerElement()
    end
    local elemCfg = ELEMENT_CONFIG[elementType]

    -- Cloner un BR de la rareté sélectionnée
    local dossier = brainrots:FindFirstChild(finalRarity)
    if not dossier then
        warn("[MutantGenerator] Dossier introuvable :", finalRarity)
        return nil, nil, nil
    end

    local modeles = dossier:GetChildren()
    if #modeles == 0 then
        warn("[MutantGenerator] Dossier vide :", finalRarity)
        return nil, nil, nil
    end

    local clone = nil
    local ok = pcall(function()
        clone = modeles[math.random(1, #modeles)]:Clone()
    end)
    if not ok or not clone then
        warn("[MutantGenerator] Échec clone BR", finalRarity)
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
        clone:SetAttribute("ElementType", elementType)
        clone:SetAttribute("Rarete",      finalRarity)
        clone:SetAttribute("IsMutant",    true)
        clone:SetAttribute("SeedRarity",  seedRarity)
        clone.Name = elemCfg.nomDisplay
    end)

    -- NOUVEAU : Appliquer les effets visuels via FilterManager
    -- (remplace : appliquerTheme() + BillboardHelper direct + part.Color direct)
    local FM = getFilterManager()
    if FM then
        FM.Apply(clone, {
            {Name = elemCfg.nomFiltre},   -- ElementEau / ElementFeu / ElementTerre / ElementVent
            {Name = "Normal"},             -- Scale 1×
            {Name = "Billboard", Params = {
                Text    = elemCfg.nomDisplay,
                Color   = elemCfg.couleur,
                OffsetY = 3,
            }},
        })
    else
        warn("[MutantGenerator] FilterManager indisponible — effets visuels ignorés")
    end

    print(string.format(
        "[MutantGenerator] %s (%s) depuis graine %s",
        elemCfg.nomDisplay, finalRarity, seedRarity))

    return clone, finalRarity, elementType
end

--[[
    Retourne la config complète d'un élément

    @param elementType (string)
    @return table ou nil
]]
function MutantGenerator.GetElementConfig(elementType)
    return ELEMENT_CONFIG[elementType]
end

--[[
    Retourne la liste des éléments disponibles

    @return table { "EAU", "FEU", "TERRE", "VENT" }
]]
function MutantGenerator.GetElements()
    return ELEMENTS
end

return MutantGenerator
