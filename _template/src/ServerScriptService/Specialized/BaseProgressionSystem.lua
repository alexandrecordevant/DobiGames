-- ServerScriptService/Specialized/BaseProgressionSystem.lua
-- ⚠️ SCRIPT SPÉCIALISÉ — À personnaliser par jeu
-- Gère le déblocage progressif des étages/zones de la base joueur
-- Exemple d'implémentation : BaseProgressionSystem.lua de BrainRotFarm
--
-- Ce script doit exposer :
--   BaseProgressionSystem.Init(player, baseIndex, playerData)
--   BaseProgressionSystem.VerifierDeblocages(player, coinsActuels)
--   BaseProgressionSystem.GetSpotsActifs(player) → table
--   BaseProgressionSystem.Reset(player)

local BaseProgressionSystem = {}

function BaseProgressionSystem.Init(player, baseIndex, playerData)
    warn("[BaseProgressionSystem] Stub non remplacé — implémenter la progression de base spécifique au jeu")
end

function BaseProgressionSystem.VerifierDeblocages(player, coinsActuels) end

function BaseProgressionSystem.GetSpotsActifs(player)
    return {}
end

function BaseProgressionSystem.Reset(player) end

return BaseProgressionSystem
