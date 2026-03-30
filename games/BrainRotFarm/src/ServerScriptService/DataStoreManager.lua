-- ServerScriptService/DataStoreManager.lua
local DataStoreManager = {}
local DataStoreService = game:GetService("DataStoreService")
local DS               = DataStoreService:GetDataStore("BrainRotIdleV1")
local CollectSystem    = require(game:GetService("ServerScriptService").SharedLib.Shared.CollectSystem)

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
        -- BRs portés non déposés (sauvegardés à la déconnexion, restaurés au login)
        carryPortes = {},
        hasTracteur      = false,
        tracteurSeuilMin = "RARE",  -- seuil de rareté minimum collecté par le tracteur
        hasLuckyCharm  = false,
        -- Vitesse actuelle (modifiée par upgrade Speed)
        walkSpeedActuel = 16,
        -- Flower Pots
        pots = {
            [1] = { debloque=true,  rarete=nil, stage=0, tempsRestant=0, instantGrow=false, plantedAt=nil, elementType=nil, brNom=nil },
            [2] = { debloque=false, rarete=nil, stage=0, tempsRestant=0, instantGrow=false, plantedAt=nil, elementType=nil, brNom=nil },
            [3] = { debloque=false, rarete=nil, stage=0, tempsRestant=0, instantGrow=false, plantedAt=nil, elementType=nil, brNom=nil },
            [4] = { debloque=false, rarete=nil, stage=0, tempsRestant=0, instantGrow=false, plantedAt=nil, elementType=nil, brNom=nil },
        },
        dailySeed = {
            jourActuel     = 1,
            dernieresClaim = 0,
            graineDispo    = true,
        },
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
    if not data.pots then data.pots = defaults.pots end
    if not data.dailySeed then data.dailySeed = defaults.dailySeed end
    if not data.upgrades then data.upgrades = defaults.upgrades end
    if not data.inventory then data.inventory = defaults.inventory end

    -- Migration : champ graines (inventaire de graines actuellement portées)
    if not data.graines then data.graines = { MYTHIC = 0, SECRET = 0 } end
    -- Migration one-shot : graines était un compteur cumulatif avant cette version.
    -- On remet à zéro une seule fois via le flag grainesMigratedV2.
    -- Après migration, les valeurs reflètent uniquement les graines actuellement portées.
    if not data.grainesMigratedV2 then
        local ancien = {}
        for r, v in pairs(data.graines) do ancien[r] = v end
        data.graines = { MYTHIC = 0, SECRET = 0 }
        data.grainesMigratedV2 = true
        warn("[DataStore] Migration grainesMigratedV2 : graines remises à 0 pour "..player.Name
            .." (ancienne valeur : MYTHIC="..tostring(ancien.MYTHIC or 0).." SECRET="..tostring(ancien.SECRET or 0)..")")
    end
    if not data.carryPortes then data.carryPortes = {} end

    -- Migration plantedAt : pots déjà en cours de croissance sans timestamp
    -- Traité comme planté maintenant → timer repart de zéro (conservatif)
    for _, pot in pairs(data.pots) do
        if pot.rarete and not pot.plantedAt then
            pot.plantedAt = os.time()
        end
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
