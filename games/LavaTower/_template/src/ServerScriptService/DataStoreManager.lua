-- ServerScriptService/DataStoreManager.lua
local DataStoreManager = {}
local DataStoreService = game:GetService("DataStoreService")
local DS               = DataStoreService:GetDataStore("BrainRotIdleV1")
local CollectSystem    = require(game.ReplicatedStorage.Modules.CollectSystem)

local function DefaultData()
    return {
        coins=0, tier=0, prestige=0, coinsParMinute=1,
        inventory={}, hasVIP=false, hasOfflineVault=false, hasAutoCollect=false,
        derniereConnexion=os.time(), totalCollecte=0,
        stats={ sessionsCount=0, totalHeuresJeu=0 }
    }
end

function DataStoreManager.Load(player)
    local ok, data = pcall(function() return DS:GetAsync("player_"..player.UserId) end)
    if not ok or not data then data = DefaultData() end
    local income = CollectSystem.CalculerOfflineIncome(data, data.derniereConnexion)
    if income > 0 then
        data.coins = data.coins + income
        local notif = game.ReplicatedStorage:FindFirstChild("OfflineIncomeNotif")
        if notif then task.delay(2, function() notif:FireClient(player, income) end) end
    end
    data.derniereConnexion = os.time()
    data.stats.sessionsCount = (data.stats.sessionsCount or 0) + 1
    return data
end

function DataStoreManager.Save(player, data)
    data.derniereConnexion = os.time()
    local ok, err = pcall(function() DS:SetAsync("player_"..player.UserId, data) end)
    if not ok then warn("[DataStore] Erreur save "..player.Name..": "..tostring(err)) end
end

function DataStoreManager.StartAutoSave(player, getData)
    task.spawn(function()
        while player.Parent do
            task.wait(60)
            if player.Parent then DataStoreManager.Save(player, getData()) end
        end
    end)
end

return DataStoreManager
