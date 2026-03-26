-- ReplicatedStorage/Modules/UpgradeSystem.lua
local UpgradeSystem = {}
local Config = require(game.ReplicatedStorage.Modules.GameConfig)

function UpgradeSystem.GetCoutUpgrade(tier)
    return math.floor(Config.CoutUpgradeBase * (Config.CoutUpgradeMultiplier ^ tier))
end

function UpgradeSystem.AppliquerUpgrade(data)
    local cout = UpgradeSystem.GetCoutUpgrade(data.tier)
    if data.coins < cout then return false, "Pas assez de coins" end
    data.coins = data.coins - cout
    data.tier  = data.tier + 1
    return true, data
end

function UpgradeSystem.AppliquerPrestige(data)
    if data.tier < Config.TotalTiers then return false, "Tier max non atteint" end
    data.prestige = data.prestige + 1
    data.tier     = 0
    data.coins    = 0
    return true, data
end

function UpgradeSystem.ZoneDebloquee(data, zoneIndex)
    -- Seuils lus depuis GameConfig (fallback sur valeurs par défaut si absents)
    local seuils = Config.ZoneUnlockSeuils or { [1]=0, [2]=3, [3]=6 }
    local prestigeSeuil = Config.ZonePrestigeSeuil or 1
    if zoneIndex == 4 then return data.prestige >= prestigeSeuil end
    return data.tier >= (seuils[zoneIndex] or 999)
end

return UpgradeSystem
