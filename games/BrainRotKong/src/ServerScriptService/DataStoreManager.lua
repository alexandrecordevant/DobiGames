-- ServerScriptService/DataStoreManager.lua
local DataStoreManager = {}
local DataStoreService = game:GetService("DataStoreService")
local DS               = DataStoreService:GetDataStore("BrainRotKongV1")
local CollectSystem    = require(game:GetService("ServerScriptService").SharedLib.Shared.CollectSystem)
local Logger           = require(game:GetService("ServerScriptService").SharedLib.Server.Logger)

local function DefaultData()
    return {
        coins=35000, tier=0, prestige=0, coinsParMinute=1,
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
            LEGENDARY=0, MYTHIC=0, SECRET=0, GOD=0,
        },
        -- Upgrades shop (niveaux achetés en coins)
        upgrades={
            upgradeSpeed=0,
            upgradeCarry=0, upgradeAimant=0,
        },
        -- BRs portés non déposés (sauvegardés à la déconnexion, restaurés au login)
        carryPortes = {},
        hasLuckyCharm  = false,
        -- Vitesse actuelle (modifiée par upgrade Speed)
        walkSpeedActuel = 16,
        -- Index des Brainrots decouverts (par categorie)
        indexObtenu = {},
        -- Codes promo utilisés
        RedeemedCodes = {},
        -- Onboarding (première session)
        hasFirstDeposit        = false,
        hasCompletedOnboarding = false,
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

    -- Migration : ajouter les champs manquants pour les anciennes saves
    local defaults = DefaultData()
    if not data.upgrades then data.upgrades = defaults.upgrades end
    if not data.inventory then data.inventory = defaults.inventory end

    if not data.carryPortes    then data.carryPortes    = {} end
    if not data.RedeemedCodes  then data.RedeemedCodes  = {} end
    if data.hasFirstDeposit        == nil then data.hasFirstDeposit        = false end
    if data.hasCompletedOnboarding == nil then data.hasCompletedOnboarding = false end

    -- Migration one-shot : bonus de démarrage 35 000 coins pour les joueurs existants
    if not data.welcomeBonusV1 then
        data.coins = (data.coins or 0) + 35000
        data.welcomeBonusV1 = true
        Logger.info("Data", "welcomeBonusV1 : +35 000 coins appliqués à %s", player.Name)
    end

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
    if not ok then Logger.error("Data", "Erreur save %s: %s", player.Name, tostring(err)) end
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
