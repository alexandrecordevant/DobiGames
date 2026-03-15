-- ServerScriptService/Specialized/AssignationSystem.lua
-- ⚠️ SCRIPT SPÉCIALISÉ — À personnaliser par jeu
-- Assigne une base/zone au joueur à la connexion
-- Exemple : attribuer Base_1 à Base_6 selon disponibilité
--
-- Ce script doit exposer :
--   AssignationSystem.AssignerBase(player) → baseIndex (number)
--   AssignationSystem.GetBase(player) → baseIndex
--   AssignationSystem.LibererBase(player)

local AssignationSystem = {}

local basesAssignees = {}  -- { [userId] = baseIndex }

function AssignationSystem.AssignerBase(player)
    warn("[AssignationSystem] Stub non remplacé — implémenter l'assignation de base spécifique au jeu")
    local baseIndex = 1
    basesAssignees[player.UserId] = baseIndex
    return baseIndex
end

function AssignationSystem.GetBase(player)
    return basesAssignees[player.UserId]
end

function AssignationSystem.LibererBase(player)
    basesAssignees[player.UserId] = nil
end

return AssignationSystem
