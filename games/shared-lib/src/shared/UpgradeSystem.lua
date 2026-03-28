-- ReplicatedStorage/Modules/UpgradeSystem.lua
local UpgradeSystem = {}
local Config = require(
    game.ReplicatedStorage:FindFirstChild("GameConfig")
    or game.ReplicatedStorage.Specialized.GameConfig
)

function UpgradeSystem.GetCoutUpgrade(tier)
    return math.floor(Config.CoutUpgradeBase * (Config.CoutUpgradeMultiplier ^ tier))
end

function UpgradeSystem.AppliquerUpgrade(data)
    local cout = UpgradeSystem.GetCoutUpgrade(data.tier)
    if data.coins < cout then return false, "Not enough coins" end
    data.coins = data.coins - cout
    data.tier  = data.tier + 1
    return true, data
end

function UpgradeSystem.AppliquerPrestige(data)
    if data.tier < Config.TotalTiers then return false, "Max tier not reached" end
    data.prestige = data.prestige + 1
    data.tier     = 0
    data.coins    = 0
    return true, data
end

function UpgradeSystem.ZoneDebloquee(data, zoneIndex)
    local seuils = { [1]=0, [2]=3, [3]=6, [4]=1 }
    if zoneIndex == 4 then return data.prestige >= 1 end
    return data.tier >= (seuils[zoneIndex] or 999)
end

return UpgradeSystem
