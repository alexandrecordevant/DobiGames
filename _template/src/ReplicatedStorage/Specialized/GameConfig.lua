-- _template/src/ReplicatedStorage/Specialized/GameConfig.lua
-- Copier dans chaque nouveau jeu et remplir les valeurs

local GameConfig = {}

GameConfig.NomDuJeu  = "MonJeu"
GameConfig.TEST_MODE = false

-- === ITEMS À SPAWNER ===
-- GameConfig.SpawnableItems = {
--     dossier = "NomDossierServerStorage",
--     raretés = {
--         { nom="COMMON", poids=55, valeur=1 },
--         -- ...
--     },
--     raretesCommunOnly = { "MYTHIC", "SECRET" },
-- }

-- === ZONE COMMUNE ===
-- GameConfig.CommunPoints = {
--     { x=0, y=0, z=0 },
-- }

-- === SPAWN CONFIG ===
-- GameConfig.SpawnConfig = {
--     intervalleSecondes = 4,
--     maxParBase         = 15,
--     despawnSecondes    = 30,
-- }
-- GameConfig.SpawnZoneNom = "SpawnZone"

-- === CAPTURE CONFIG ===
-- GameConfig.CaptureConfig = {
--     COMMON = { mode="touched", holdDuration=0 },
--     RARE   = { mode="touched", holdDuration=0 },
--     EPIC   = { mode="prompt",  holdDuration=0.5 },
-- }

-- === VALEUR PAR RARETÉ ===
-- GameConfig.ValeurParRarete = {
--     COMMON = 1,
--     RARE   = 8,
-- }

-- === INCOME PAR RARETÉ ===
-- GameConfig.IncomeParRarete = {
--     COMMON = 1,
--     RARE   = 8,
-- }

-- === CARRY ===
-- GameConfig.CarryNiveaux = { [0]=1, [1]=2, [2]=3, [3]=5 }
-- GameConfig.CarryPrices  = { [1]=500, [2]=2000, [3]=0 }

-- === MAX BASES ===
-- GameConfig.MaxBases = 6

-- === PROGRESSION BASE ===
-- GameConfig.ProgressionConfig = {
--     floors = {
--         { index=1, nom="Floor 1" },
--         { index=2, nom="Floor 2" },
--     },
--     seuils = {
--         { floor=1, spot=1, coins=0,    label="Départ" },
--         { floor=1, spot=2, coins=100,  label="100 coins" },
--     },
--     baseSurTotalGagne = true,
-- }

-- === REBIRTH ===
-- GameConfig.RebirthConfig = {
--     [1] = { coinsRequis=0, brainRotRequis={rarete="",quantite=1},
--             multiplicateur=1.5, slotsBonus=2 },
-- }

-- === SHOP ===
-- GameConfig.ShopUpgrades = {
--     NomUpgrade = {
--         nom         = "Nom Affiché",
--         icon        = "🔧",
--         description = "Description",
--         niveaux     = {
--             { valeur=2, prix=500,  label="Niveau 1" },
--             { valeur=3, prix=2000, label="Niveau 2" },
--         },
--     },
-- }

-- === EVENTS ===
-- GameConfig.EventsVisuels     = { ... }
-- GameConfig.EventIntervalleMinutes = 120
-- GameConfig.EventDureeMinutes      = 10

-- === LEADERBOARD ===
-- GameConfig.Leaderboards = {
--     { nom="Top Coins", stat="coins", max=10 },
-- }
-- GameConfig.LeaderboardPosition = Vector3.new(0, 15, 0)

-- === ANIMATION ===
-- GameConfig.AnimationConfig = {
--     popScale    = 1.3,
--     popDuration = 0.15,
-- }

-- === DISCORD ===
-- GameConfig.DiscordWebhookURL = ""

return GameConfig
