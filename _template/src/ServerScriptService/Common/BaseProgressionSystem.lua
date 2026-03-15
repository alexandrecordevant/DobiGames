-- ServerScriptService/Common/BaseProgressionSystem.lua
-- Script générique — lit sa config depuis GameConfig.ProgressionConfig
-- Ce script est partagé entre tous les jeux DobiGames
--
-- API exposée :
--   BaseProgressionSystem.Init(player, baseIndex, playerData)
--   BaseProgressionSystem.VerifierDeblocages(player, playerData)
--     → utilise playerData.totalCoinsGagnes si ProgressionConfig.baseSurTotalGagne=true
--   BaseProgressionSystem.GetSpotsActifs(player) → table de TouchParts actifs
--   BaseProgressionSystem.Reset(player)

local BaseProgressionSystem = {}

function BaseProgressionSystem.Init(player, baseIndex, playerData)
    warn("[BaseProgressionSystem] Stub non remplacé — copier l'implémentation de BrainRotFarm")
end

function BaseProgressionSystem.VerifierDeblocages(player, playerData) end

function BaseProgressionSystem.GetSpotsActifs(player)
    return {}
end

function BaseProgressionSystem.Reset(player) end

return BaseProgressionSystem
