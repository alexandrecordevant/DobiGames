-- ServerScriptService/Specialized/LeaderboardSystem.lua
-- ⚠️ SCRIPT SPÉCIALISÉ — À personnaliser par jeu
-- Gère l'affichage du leaderboard visible par tous les joueurs
-- Critère de classement à définir selon le jeu (coins, prestige, rebirth...)
--
-- Ce script doit exposer :
--   LeaderboardSystem.Init()
--   LeaderboardSystem.MettreAJour(player, playerData)

local LeaderboardSystem = {}

function LeaderboardSystem.Init()
    warn("[LeaderboardSystem] Stub non remplacé — implémenter le leaderboard spécifique au jeu")
end

function LeaderboardSystem.MettreAJour(player, playerData) end

return LeaderboardSystem
