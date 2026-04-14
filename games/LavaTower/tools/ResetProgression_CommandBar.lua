-- ╔══════════════════════════════════════════════════════════════╗
-- ║  RESET PROGRESSION — LAVA TOWER                              ║
-- ║  Coller dans : Studio > View > Command Bar                   ║
-- ║  !! Activer "Enable Studio Access to API Services" !!        ║
-- ╚══════════════════════════════════════════════════════════════╝
--
--  1. Remplacer USER_ID par le UserId numérique cible.
--  2. Coller tout le bloc dans la barre de commandes de Studio.
--  3. Le joueur ne doit PAS être connecté au moment de l'exécution.

local USER_ID = 10621969326  -- ← MODIFIER (ex: 123456789)

local DataStoreService = game:GetService("DataStoreService")
local ds  = DataStoreService:GetDataStore("LavaTowerV1")
local key = "player_" .. USER_ID

local donneesVierges = {
    -- Progression principale
    coins                   = 0,
    tier                    = 0,
    prestige                = 0,
    totalCollecte           = 0,
    -- Rebirth / slots
    rebirthLevel            = 0,
    multiplicateurPermanent = 1.0,
    slotsBonus              = 0,
    progression             = {},
    spotsOccupes            = {},
    -- Inventaire brainrots
    inventory               = {},
    -- Shop upgrades
    shopUpgrades            = { carry = 0, speed = 0, jump = 0 },
    -- Objets boutique (cosmétiques/gameplay)
    hasBat                  = false,
    batEquipped             = false,
    hasGoldSlap             = false,
    goldSlapEquipped        = false,
    -- Game passes (conservés tels quels — retirer si reset total souhaité)
    hasVIP                  = false,
    hasOfflineVault         = false,
    hasAutoCollect          = false,
    -- Méta
    derniereConnexion       = os.time(),
    stats                   = { sessionsCount = 0, totalHeuresJeu = 0 },
}

local ok, err = pcall(function()
    ds:SetAsync(key, donneesVierges)
end)

if ok then
    print(string.format("[ResetLavaTower] ✓ Progression réinitialisée — userId=%d  clé=%s", USER_ID, key))
else
    warn(string.format("[ResetLavaTower] ✗ ERREUR SetAsync — %s", tostring(err)))
end
