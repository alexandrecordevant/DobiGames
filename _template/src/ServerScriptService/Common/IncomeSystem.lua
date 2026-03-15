-- ServerScriptService/Common/IncomeSystem.lua
-- ⚠️ STUB — À implémenter
-- Gère les coins/sec générés par les Brain Rots déposés sur les spots
-- Boucle passive : chaque BR déposé génère un revenu continu
--
-- Ce script doit exposer :
--   IncomeSystem.Init()
--   IncomeSystem.AjouterBR(player, spotId, rarete)
--   IncomeSystem.RetirerBR(player, spotId)
--   IncomeSystem.GetRevenuParSeconde(player) → number

local IncomeSystem = {}

function IncomeSystem.Init()
    warn("[IncomeSystem] Stub non implémenté — revenus passifs désactivés")
end

function IncomeSystem.AjouterBR(player, spotId, rarete) end
function IncomeSystem.RetirerBR(player, spotId) end

function IncomeSystem.GetRevenuParSeconde(player)
    return 0
end

return IncomeSystem
