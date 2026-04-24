-- ============================================================
-- RESET PROGRESSION -- LAVA TOWER
-- Coller dans : Studio > View > Command Bar
-- Prerequis : Game Settings > Security > "Enable Studio Access
--             to API Services" doit etre active
-- Le joueur cible doit etre hors ligne
-- ============================================================

local USER_ID = 10621969326  -- <- MODIFIER

local DS  = game:GetService("DataStoreService"):GetDataStore("LavaTowerV1")
local key = "player_" .. USER_ID

local data = {
    coins=0, tier=0, prestige=0, totalCollecte=0,
    rebirthLevel=0, multiplicateurPermanent=1.0, slotsBonus=0,
    progression={}, spotsOccupes={}, inventory={}, carryPortes={},
    shopUpgrades={ carry=0, speed=0, jump=0 },
    hasBat=false, batEquipped=false,
    hasGoldSlap=false, goldSlapEquipped=false,
    hasSpeedCoil=false, speedCoilEquipped=false,
    hasGravityCoil=false, gravityCoilEquipped=false,
    packAchete=false, luckyBlocks={},
    hasVIP=false, hasOfflineVault=false, hasAutoCollect=false,
    derniereConnexion=os.time(),
    stats={ sessionsCount=0, totalHeuresJeu=0 },
}

coroutine.wrap(function()
    local ok, err = pcall(DS.SetAsync, DS, key, data)
    print(ok and ("[ResetLT] OK progression reset userId=" .. USER_ID)
               or ("[ResetLT] ERREUR SetAsync: " .. tostring(err)))

    local okF, errF = pcall(DS.RemoveAsync, DS, "fuse_" .. USER_ID)
    print(okF and "[ResetLT] OK fuse reset."
               or ("[ResetLT] ERREUR fuse: " .. tostring(errF)))
end)()
