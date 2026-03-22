-- ServerScriptService/MonetizationHandler.lua
local MonetizationHandler = {}
local MarketplaceService  = game:GetService("MarketplaceService")
local Config              = require(game.ReplicatedStorage.Specialized.GameConfig)
local CollectSystem       = require(game.ReplicatedStorage.SharedLib.Shared.CollectSystem)

-- Chargement différé — ShopSystem dépend de MonetizationHandler (via Main), évite la circularité
local _ShopSystem = nil
local function getShopSystem()
    if not _ShopSystem then
        local ok, m = pcall(require, game:GetService("ServerScriptService").Common.ShopSystem)
        if ok and m then _ShopSystem = m end
    end
    return _ShopSystem
end

MarketplaceService.ProcessReceipt = function(receiptInfo)
    local player = game:GetService("Players"):GetPlayerByUserId(receiptInfo.PlayerId)
    if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
    local pid = receiptInfo.ProductId
    if pid == Config.ProduitLuckyHour.Id then
        CollectSystem.SetEventMultiplier(5)
        task.delay(1800, function() CollectSystem.SetEventMultiplier(1) end)
    elseif pid == Config.ProduitSkipTier.Id then
        local UpgradeSystem = require(game.ReplicatedStorage.SharedLib.Shared.UpgradeSystem)
        local data = player:FindFirstChild("_data")  -- géré par Main
        if data and data.tier < Config.TotalTiers then data.tier = data.tier + 1 end
    end
    return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationHandler.CheckGamePasses(player, data)
    local mps = game:GetService("MarketplaceService")
    local function check(id, field)
        if id > 0 then
            local ok, owns = pcall(function() return mps:UserOwnsGamePassAsync(player.UserId, id) end)
            if ok and owns then data[field] = true end
        end
    end

    -- Game Passes système (VIP, OfflineVault, AutoCollect)
    check(Config.GamePassVIP.Id,          "hasVIP")
    check(Config.GamePassOfflineVault.Id, "hasOfflineVault")
    check(Config.GamePassAutoCollect.Id,  "hasAutoCollect")

    -- Game Passes shop — itère Config.ShopUpgrades pour ne hardcoder aucun ID
    if Config.ShopUpgrades then
        for _, upgradeConfig in pairs(Config.ShopUpgrades) do
            for _, niveauConfig in pairs(upgradeConfig.niveaux) do
                local gpId = niveauConfig.gamePassId
                if type(gpId) == "number" and gpId > 0 then
                    local ok, owns = pcall(function()
                        return mps:UserOwnsGamePassAsync(player.UserId, gpId)
                    end)
                    if ok and owns then
                        -- Déléguer à ShopSystem pour appliquer l'effet correctement
                        local SS = getShopSystem()
                        if SS then
                            pcall(SS.ConfirmerAchatGamePass, player, gpId)
                        end
                    end
                end
            end
        end
    end
end

function MonetizationHandler.CheckPromptRules(data)
    if data.tier == 2 and not data.hasVIP           then return "VIP"         end
    if data.tier == 5 and not data.hasOfflineVault  then return "OfflineVault" end
    return nil
end

return MonetizationHandler
