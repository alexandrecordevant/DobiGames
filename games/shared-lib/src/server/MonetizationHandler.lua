-- ServerScriptService/MonetizationHandler.lua
local MonetizationHandler = {}
local MarketplaceService  = game:GetService("MarketplaceService")
local Config = require(
    game.ReplicatedStorage:FindFirstChild("GameConfig")
    or game.ReplicatedStorage.Specialized.GameConfig
)
local CollectSystem       = require(game:GetService("ServerScriptService").SharedLib.Shared.CollectSystem)

-- Injecté depuis Main.server.lua via MonetizationHandler.SetGetData(GetData)
local _GetData = nil
function MonetizationHandler.SetGetData(fn) _GetData = fn end

-- Chargement différé — ShopSystem dépend de MonetizationHandler (via Main), évite la circularité
local _ShopSystem = nil
local function getShopSystem()
    if not _ShopSystem then
        local ok, m = pcall(require, game:GetService("ServerScriptService").ShopSystem)
        if ok and m then _ShopSystem = m end
    end
    return _ShopSystem
end

-- Chargement différé de FlowerPotSystem (même raison)
local _FlowerPotSystem = nil
local function getFlowerPotSystem()
    if not _FlowerPotSystem then
        local ok, m = pcall(require, game:GetService("ServerScriptService").FlowerPotSystem)
        if ok and m then _FlowerPotSystem = m end
    end
    return _FlowerPotSystem
end

MarketplaceService.ProcessReceipt = function(receiptInfo)
    local player = game:GetService("Players"):GetPlayerByUserId(receiptInfo.PlayerId)
    if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end

    local pid  = receiptInfo.ProductId
    local devP = Config.DevProductIds or {}
    local data = _GetData and _GetData(player)

    -- Lucky Hour : ×5 income pendant 30 min
    if pid == Config.ProduitLuckyHour.Id or pid == devP.LuckyHour then
        CollectSystem.SetEventMultiplier(5)
        task.delay(1800, function() CollectSystem.SetEventMultiplier(1) end)

    -- Skip Tier : avancer d'un tier (réservé pour usage futur, tier non utilisé actuellement)
    elseif pid == Config.ProduitSkipTier.Id then
        if data and (data.tier or 0) < Config.TotalTiers then
            data.tier = (data.tier or 0) + 1
        end

    -- Skip Seed Timer : rend la graine quotidienne disponible immédiatement
    elseif pid == devP.SkipSeedTimer then
        if data and data.dailySeed then
            data.dailySeed.graineDispo    = true
            data.dailySeed.dernieresClaim = 0  -- force le timer à repartir après claim
            local FPS = getFlowerPotSystem()
            if FPS and FPS.NotifierGraineDispo then
                pcall(FPS.NotifierGraineDispo, player)
            end
        end

    -- Seed Pack ×3 : ajoute 3 graines MYTHIC au stock du joueur
    elseif pid == devP.SeedPackx3 then
        if data then
            data.graines = data.graines or {}
            data.graines.MYTHIC = (data.graines.MYTHIC or 0) + 3
            local FPS = getFlowerPotSystem()
            if FPS and FPS.NotifierStock then
                pcall(FPS.NotifierStock, player)
            end
        end

    -- Secret Seed : ajoute 1 graine SECRET au stock du joueur
    elseif pid == devP.SecretSeed then
        if data then
            data.graines = data.graines or {}
            data.graines.SECRET = (data.graines.SECRET or 0) + 1
            local FPS = getFlowerPotSystem()
            if FPS and FPS.NotifierStock then
                pcall(FPS.NotifierStock, player)
            end
        end
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
