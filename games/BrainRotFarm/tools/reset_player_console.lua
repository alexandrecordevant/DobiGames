-- ============================================================
-- RESET COMPLET JOUEUR — Console Studio
-- DataStore : BrainRotIdleV1
-- Usage : coller dans la console Studio (F9 → onglet Server)
-- ⚠️  Lancer quand le joueur est hors ligne
-- ⚠️  Les vrais GamePasses Roblox (SeedDoubler, etc.) sont
--     re-vérifiés automatiquement via MarketplaceService au login,
--     ils ne peuvent pas être effacés via DataStore.
-- ============================================================

local DataStoreService = game:GetService("DataStoreService")

local USER_ID = 10621969326         -- ← changer ici si besoin
local DS_KEY  = "player_" .. USER_ID

local function buildDefaultData()
    return {
        -- Économie
        coins                   = 35000,
        tier                    = 0,
        prestige                = 0,
        coinsParMinute          = 1,
        derniereConnexion       = os.time(),
        totalCollecte           = 0,
        totalCoinsGagnes        = 0,
        -- Marque le bonus de bienvenue comme appliqué (évite le double +35k au 1er login)
        welcomeBonusV1          = true,
        -- Stats
        stats                   = { sessionsCount=0, totalHeuresJeu=0 },
        -- Progression base
        progression             = {},
        spotsOccupes            = {},
        -- Rebirth / AmelioBase
        rebirthLevel            = 0,
        multiplicateurPermanent = 1.0,
        slotsBonus              = 0,
        -- Inventaire Brain Rots
        inventory = {
            COMMON=0, OG=0, RARE=0, EPIC=0,
            LEGENDARY=0, MYTHIC=0, SECRET=0, GOD=0,
        },
        -- Upgrades shop (niveaux achetés en coins)
        upgrades = {
            upgradeArroseur=0, upgradeSpeed=0,
            upgradeCarry=0,    upgradeAimant=0,
        },
        -- Carry sauvegardé (BRs portés à la déconnexion)
        carryPortes             = {},
        -- Tracteur / Lucky Charm
        hasTracteur             = false,
        tracteurSeuilMin        = "RARE",
        hasLuckyCharm           = false,
        walkSpeedActuel         = 16,
        -- Graines portées
        graines                 = { MYTHIC=0, SECRET=0, RARE=0 },
        grainesMigratedV2       = true,
        -- Flower Pots
        pots = {
            [1] = { debloque=true,  rarete=nil, stage=0, tempsRestant=0, instantGrow=false, plantedAt=nil, elementType=nil, brNom=nil },
            [2] = { debloque=false, rarete=nil, stage=0, tempsRestant=0, instantGrow=false, plantedAt=nil, elementType=nil, brNom=nil },
            [3] = { debloque=false, rarete=nil, stage=0, tempsRestant=0, instantGrow=false, plantedAt=nil, elementType=nil, brNom=nil },
            [4] = { debloque=false, rarete=nil, stage=0, tempsRestant=0, instantGrow=false, plantedAt=nil, elementType=nil, brNom=nil },
        },
        -- Daily Seed
        dailySeed = {
            jourActuel     = 1,
            dernieresClaim = 0,
            graineDispo    = true,
        },
        -- Index Brainrots découverts
        indexObtenu             = {},
        -- Codes promo utilisés (vide = tous les codes re-utilisables)
        RedeemedCodes           = {},
        -- Onboarding première session
        hasFirstDeposit         = false,
        hasCompletedOnboarding  = false,
    }
end

local DS = DataStoreService:GetDataStore("BrainRotIdleV1")

-- Lecture préalable
local okRead, dataCourante = pcall(function() return DS:GetAsync(DS_KEY) end)
if okRead and dataCourante then
    print(string.format("[RESET] Données actuelles : %d coins, tier %d, rebirth %d, codes=%d",
        dataCourante.coins or 0,
        dataCourante.tier or 0,
        dataCourante.rebirthLevel or 0,
        dataCourante.RedeemedCodes and #dataCourante.RedeemedCodes or 0))
else
    print("[RESET] Clé vide ou inexistante.")
end

-- Suppression + écriture vierge
local okDel = pcall(function() DS:RemoveAsync(DS_KEY) end)
print(okDel and "[RESET] ✓ Clé supprimée." or "[RESET] ✗ Échec suppression.")

local okSet, errSet = pcall(function() DS:SetAsync(DS_KEY, buildDefaultData()) end)
if not okSet then
    warn("[RESET] ✗ Échec écriture : " .. tostring(errSet))
    return
end
print("[RESET] ✓ Save vierge écrite.")
print("[RESET]   → Première connexion : hasFirstDeposit=false, hasCompletedOnboarding=false")
print("[RESET]   → Codes promo : RedeemedCodes={} (tous re-utilisables)")
print("[RESET]   → Coins de départ : 35 000")

-- Vérification
task.wait(1)
local okV, v = pcall(function() return DS:GetAsync(DS_KEY) end)
if okV and v and v.coins == 35000 and v.hasFirstDeposit == false then
    print("[RESET] ✓ Vérifié — " .. USER_ID .. " peut se reconnecter comme nouveau joueur.")
else
    warn("[RESET] ⚠️  Vérification incertaine, relis manuellement.")
end
