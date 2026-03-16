-- ServerScriptService/DataStoreManager.lua
local DataStoreManager = {}
local DataStoreService = game:GetService("DataStoreService")
local DS               = DataStoreService:GetDataStore("BrainRotIdleV1")
local CollectSystem    = require(game.ReplicatedStorage.Common.CollectSystem)

local function DefaultData()
    return {
        coins=0, tier=0, prestige=0, coinsParMinute=1,
        hasVIP=false, hasOfflineVault=false, hasAutoCollect=false,
        derniereConnexion=os.time(), totalCollecte=0,
        totalCoinsGagnes=0,
        stats={ sessionsCount=0, totalHeuresJeu=0 },
        -- Progression base
        progression={},
        spotsOccupes={},
        -- Rebirth
        rebirthLevel=0,
        multiplicateurPermanent=1.0,
        slotsBonus=0,
        -- Inventaire Brain Rots (pour conditions rebirth)
        inventory={
            COMMON=0, OG=0, RARE=0, EPIC=0,
            LEGENDARY=0, MYTHIC=0, SECRET=0, BRAINROT_GOD=0,
        },
        -- Upgrades shop (niveaux achetés en coins)
        upgrades={
            upgradeArroseur=0, upgradeSpeed=0,
            upgradeCarry=0,    upgradeAimant=0,
        },
        -- Game Passes shop
        hasTracteur      = false,
        tracteurSeuilMin = "RARE",  -- seuil de rareté minimum collecté par le tracteur
        hasLuckyCharm  = false,
        -- Vitesse actuelle (modifiée par upgrade Speed)
        walkSpeedActuel = 16,
        -- Flower Pots
        pots = {
            [1] = { debloque=true,  graine=nil, stage=0, tempsRestant=0, instantGrow=false },
            [2] = { debloque=false, graine=nil, stage=0, tempsRestant=0, instantGrow=false },
            [3] = { debloque=false, graine=nil, stage=0, tempsRestant=0, instantGrow=false },
            [4] = { debloque=false, graine=nil, stage=0, tempsRestant=0, instantGrow=false },
        },
        graines = { COMMON=0, RARE=0, EPIC=0, LEGENDARY=0 },
    }
end

-- Retourne des données vierges sans toucher au DataStore
-- Utilisé par le reset automatique en TEST_MODE pour bypasser le cache Studio
function DataStoreManager.GetDefaultData()
    return DefaultData()
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
