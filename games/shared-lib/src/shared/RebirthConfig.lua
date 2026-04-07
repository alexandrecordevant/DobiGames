-- shared-lib/src/shared/RebirthConfig.lua
-- Config Amélioration de Base — BrainRotFarm & LavaTower
--
-- 30 niveaux · uniquement coins requis (pas de brainrot)
-- Multiplicateur : +0.1 par niveau  →  ×1.1 au niveau 1, ×4.0 au niveau 30
-- Slots bonus    : +1 par niveau    →  30 slots débloqués au maximum
-- Prix           : croissance ×1.45 depuis 10 000 → ~500 M au niveau 30
--
-- Injecter via : RebirthSystem.Config = require(RS.SharedLib.Shared.RebirthConfig)

-- Prix arrondis — calculés avec un facteur ×1.45 entre chaque niveau
local PRIX = {
     10000,  15000,  22000,  32000,  46000,   --  1– 5
     67000,  97000, 141000, 204000, 296000,   --  6–10
    429000, 622000, 902000, 1308000, 1897000, -- 11–15
    2751000, 3989000, 5784000, 8387000, 12161000,  -- 16–20
    17633000, 25568000, 37074000, 53757000, 77948000,  -- 21–25
    113025000, 163886000, 237635000, 344571000, 500000000, -- 26–30
}

local BaseImprovementConfig = {}

for niveau = 1, 30 do
    -- Multiplicateur : arrondi à 1 décimale → 1.1, 1.2 … 4.0
    local mult = math.floor((1 + niveau * 0.1) * 10 + 0.5) / 10

    BaseImprovementConfig[niveau] = {
        coinsRequis    = PRIX[niveau],
        multiplicateur = mult,
        slotsBonus     = 1,               -- toujours +1 slot par amélioration
        label          = "Amélioration " .. niveau,
    }
end

return BaseImprovementConfig
