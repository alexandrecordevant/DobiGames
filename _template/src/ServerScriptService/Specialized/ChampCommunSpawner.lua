-- ServerScriptService/Specialized/ChampCommunSpawner.lua
-- ⚠️ SCRIPT SPÉCIALISÉ — À personnaliser par jeu
-- Gère le spawn des entités rares dans la zone commune centrale
-- Exemple d'implémentation : ChampCommunSpawner.lua de BrainRotFarm
--
-- Ce script doit exposer :
--   ChampCommunSpawner.Init()
--   ChampCommunSpawner.OnCollecte = function(player, typeNom) end
--   ChampCommunSpawner.OnBRSpawned = function(clone, typeNom, onCapture) end

local ChampCommunSpawner = {}

function ChampCommunSpawner.Init()
    warn("[ChampCommunSpawner] Stub non remplacé — créer le spawner de zone commune spécifique au jeu")
end

ChampCommunSpawner.OnCollecte  = nil
ChampCommunSpawner.OnBRSpawned = nil

return ChampCommunSpawner
