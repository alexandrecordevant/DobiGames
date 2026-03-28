-- ReplicatedStorage/Modules/CollectSystem.lua
local CollectSystem = {}
local Config = require(
    game.ReplicatedStorage:FindFirstChild("GameConfig")
    or game.ReplicatedStorage.Specialized.GameConfig
)

CollectSystem.EventMultiplier = 1

function CollectSystem.TirerRarete()
    local rand = math.random(1, 1000) / 10
    local cumul = 0
    for _, rarete in ipairs(Config.Raretes) do
        cumul = cumul + rarete.chance
        if rand <= cumul then return rarete end
    end
    return Config.Raretes[1]
end

function CollectSystem.GetMultiplier(playerData)
    local tierBonus     = 1 + (playerData.tier * 0.15)
    local prestigeBonus = 1 + (playerData.prestige * (Config.PrestigeMultiplier - 1))
    local vipBonus      = playerData.hasVIP and 2 or 1
    local eventBonus    = CollectSystem.EventMultiplier or 1
    return tierBonus * prestigeBonus * vipBonus * eventBonus
end

function CollectSystem.CalculerOfflineIncome(playerData, derniereConnexion)
    local heures = math.min((os.time() - derniereConnexion) / 3600, Config.MaxOfflineHeures)
    local taux   = (playerData.coinsParMinute or 1) * Config.OfflineIncomeMultiplier * 60
    local mult   = playerData.hasOfflineVault and 3 or 1
    return math.floor(heures * taux * mult)
end

function CollectSystem.SetEventMultiplier(multiplier)
    CollectSystem.EventMultiplier = multiplier
end

return CollectSystem
