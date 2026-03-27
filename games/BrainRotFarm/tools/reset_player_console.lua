-- ============================================================
-- RESET COMPLET JOUEUR — Console Studio
-- DataStore : BrainRotIdleV1
-- Usage : coller dans la console Studio (F9 → onglet Server)
-- ⚠️  Lancer quand le joueur est hors ligne
-- ============================================================

local DataStoreService = game:GetService("DataStoreService")

local USER_ID = 10621969326         -- ← changer ici si besoin
local DS_KEY  = "player_" .. USER_ID

local function buildDefaultData()
    return {
        coins=0, tier=0, prestige=0, coinsParMinute=1,
        hasVIP=false, hasOfflineVault=false, hasAutoCollect=false,
        derniereConnexion=os.time(), totalCollecte=0,
        totalCoinsGagnes=0,
        stats={ sessionsCount=0, totalHeuresJeu=0 },
        progression={},
        spotsOccupes={},
        rebirthLevel=0,
        multiplicateurPermanent=1.0,
        slotsBonus=0,
        inventory={
            COMMON=0, OG=0, RARE=0, EPIC=0,
            LEGENDARY=0, MYTHIC=0, SECRET=0, BRAINROT_GOD=0,
        },
        upgrades={
            upgradeArroseur=0, upgradeSpeed=0,
            upgradeCarry=0,    upgradeAimant=0,
        },
        hasTracteur      = false,
        tracteurSeuilMin = "RARE",
        hasLuckyCharm    = false,
        walkSpeedActuel  = 16,
        pots = {
            [1] = { debloque=true,  rarete=nil, stage=0, tempsRestant=0, instantGrow=false },
            [2] = { debloque=false, rarete=nil, stage=0, tempsRestant=0, instantGrow=false },
            [3] = { debloque=false, rarete=nil, stage=0, tempsRestant=0, instantGrow=false },
            [4] = { debloque=false, rarete=nil, stage=0, tempsRestant=0, instantGrow=false },
        },
        dailySeed = {
            jourActuel     = 1,
            dernieresClaim = 0,
            graineDispo    = true,
        },
    }
end

local DS = DataStoreService:GetDataStore("BrainRotIdleV1")

-- Lecture préalable
local okRead, dataCourante = pcall(function() return DS:GetAsync(DS_KEY) end)
if okRead and dataCourante then
    print(string.format("[RESET] Données actuelles : %d coins, tier %d, rebirth %d",
        dataCourante.coins or 0, dataCourante.tier or 0, dataCourante.rebirthLevel or 0))
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

-- Vérification
task.wait(1)
local okV, v = pcall(function() return DS:GetAsync(DS_KEY) end)
if okV and v and v.coins == 0 then
    print("[RESET] ✓ Vérifié : coins = 0 — " .. USER_ID .. " peut se reconnecter.")
else
    warn("[RESET] ⚠️  Vérification incertaine, relis manuellement.")
end
