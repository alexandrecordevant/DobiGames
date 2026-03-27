-- ReplicatedStorage/SharedLib/BRFilterSystem/FilterRegistry.lua
-- DobiGames — Registry centralisé des filtres disponibles
-- Permet de valider les noms de filtres avant application

local FilterRegistry = {}

-- ============================================================
-- Liste canonique de tous les filtres disponibles
-- ============================================================
local FILTRES_VALIDES = {
    -- Scale
    "Miniature", "Normal", "Large", "Geant",

    -- Rarity
    "RarityCOMMON", "RarityOG", "RarityRARE",
    "RarityEPIC", "RarityLEGENDARY", "RarityMYTHIC", "RaritySECRET",

    -- Element
    "ElementEau", "ElementFeu", "ElementTerre", "ElementVent",

    -- Visual
    "Glow", "Trail", "Sparkles", "Billboard",

    -- State
    "Pickupable", "Deposited", "Carried",
}

-- Index pour O(1) lookup
local _index = {}
for _, nom in ipairs(FILTRES_VALIDES) do
    _index[nom] = true
end

-- ============================================================
-- API publique
-- ============================================================

--[[
    Vérifie si un filtre est enregistré

    @param filterName (string)
    @return boolean
]]
function FilterRegistry.Exists(filterName)
    return _index[filterName] == true
end

--[[
    Retourne la liste de tous les filtres disponibles

    @return table
]]
function FilterRegistry.GetAll()
    local liste = {}
    for _, nom in ipairs(FILTRES_VALIDES) do
        table.insert(liste, nom)
    end
    return liste
end

--[[
    Retourne les filtres d'une catégorie
    Catégories : "Scale", "Rarity", "Element", "Visual", "State"

    @param categorie (string)
    @return table
]]
function FilterRegistry.GetByCategory(categorie)
    local categories = {
        Scale   = {"Miniature", "Normal", "Large", "Geant"},
        Rarity  = {"RarityCOMMON", "RarityOG", "RarityRARE", "RarityEPIC", "RarityLEGENDARY", "RarityMYTHIC", "RaritySECRET"},
        Element = {"ElementEau", "ElementFeu", "ElementTerre", "ElementVent"},
        Visual  = {"Glow", "Trail", "Sparkles", "Billboard"},
        State   = {"Pickupable", "Deposited", "Carried"},
    }
    return categories[categorie] or {}
end

--[[
    Retourne la couleur canonique d'une rareté

    @param rariteNom (string)
    @return Color3
]]
function FilterRegistry.GetRarityColor(rariteNom)
    local couleurs = {
        COMMON      = Color3.fromRGB(200, 200, 200),
        OG          = Color3.fromRGB(100, 220, 255),
        RARE        = Color3.fromRGB(0,   120, 255),
        EPIC        = Color3.fromRGB(150, 0,   255),
        LEGENDARY   = Color3.fromRGB(255, 200, 0  ),
        MYTHIC      = Color3.fromRGB(148, 0,   211),
        SECRET      = Color3.fromRGB(255, 255, 255),
        BRAINROT_GOD = Color3.fromRGB(255, 140, 0 ),
    }
    return couleurs[rariteNom] or Color3.new(1, 1, 1)
end

return FilterRegistry
