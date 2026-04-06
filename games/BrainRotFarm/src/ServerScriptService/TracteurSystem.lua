-- ServerScriptService/TracteurSystem.lua
-- ⚠️ MIGRÉ — Ancien comportement auto-collect supprimé
-- Le Game Pass Tracteur est désormais un roll bonus passif dans SpawnManager.lua :
-- à chaque spawn dans le champ, 6% de chance de faire apparaître un MYTHIC/SECRET bonus.
-- Ce fichier est conservé comme stub pour compatibilité avec les require() existants.

local TracteurSystem = {}

function TracteurSystem.Init()
    print("[TracteurSystem] Stub — logique migrée vers SpawnManager (Lucky Spawn passif)")
end

-- No-op : le Tracteur n'anime plus rien, le roll passif est géré dans SpawnManager
function TracteurSystem.Activer(player, baseIndex, onCollect) end

-- No-op
function TracteurSystem.Desactiver(baseIndex) end

return TracteurSystem
