-- shared-lib/src/shared/AmelioConfig.lua
-- Config Amélioration de Base — BrainRotFarm & LavaTower
--
-- 30 niveaux · uniquement coins requis (pas de brainrot)
-- Multiplicateur : +0.1 par niveau  →  ×1.1 au niveau 1, ×4.0 au niveau 30
-- Slots bonus    : +1 par niveau    →  30 slots débloqués au maximum
-- Prix           : formule exponentielle — 10 000 au niveau 1, 1Q au niveau 30
--   cost(N) = 10000 × (1Q / 10000) ^ ((N-1) / 29)
--
-- Injecter via : AmelioSystem.Config = require(RS.SharedLib.Shared.AmelioConfig)

local COUT_DEPART = 10000   -- coût du niveau 1
local COUT_MAX    = 1e15    -- coût du niveau 30 (1Q)
local NB_NIVEAUX  = 30

local BaseImprovementConfig = {}

for niveau = 1, NB_NIVEAUX do
    -- Multiplicateur : arrondi à 1 décimale → 1.1, 1.2 … 4.0
    local mult = math.floor((1 + niveau * 0.1) * 10 + 0.5) / 10

    -- Prix exponentiel : premier et dernier niveau fixés, intermédiaires calculés
    local prix
    if niveau == 1 then
        prix = COUT_DEPART
    else
        local ratio = COUT_MAX / COUT_DEPART
        prix = math.floor(COUT_DEPART * ratio ^ ((niveau - 1) / (NB_NIVEAUX - 1)) + 0.5)
    end

    BaseImprovementConfig[niveau] = {
        coinsRequis    = prix,
        multiplicateur = mult,
        slotsBonus     = 1,               -- toujours +1 slot par amélioration
        label          = "Amélioration " .. niveau,
    }
end

return BaseImprovementConfig
