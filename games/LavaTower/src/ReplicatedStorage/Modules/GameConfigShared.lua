-- ReplicatedStorage/Modules/GameConfigShared.lua
-- Champs requis par shared-lib — commun à tous les jeux du studio

local GameConfigShared = {}

-- === PROGRESSION BASE ===
-- Lu par BaseProgressionSystem
GameConfigShared.ProgressionConfig = {

    floors = {
        { index = 1, nom = "Floor_1", type = "Part",  spots = 10 },
        { index = 2, nom = "Floor_2", type = "Model", spots = 10 },
        { index = 3, nom = "Floor_3", type = "Model", spots = 10 },
        { index = 4, nom = "Floor_4", type = "Model", spots = 10 },
    },

    -- NOTE : Floor 1 entièrement débloqué au départ (coins=0).
    -- Étages 2-4 débloqués uniquement via Rebirth (coins=9999999999 = jamais via coins).
    -- L'ordre de déblocage par rebirth est géré dans Main.server.lua (BuildProgressionFromRebirth).
    seuils = {
        -- Floor 1 : tout débloqué au départ
        { floor=1, spot=1,  coins=0, label="Start" },
        { floor=1, spot=2,  coins=0, label="Start" },
        { floor=1, spot=3,  coins=0, label="Start" },
        { floor=1, spot=4,  coins=0, label="Start" },
        { floor=1, spot=5,  coins=0, label="Start" },
        { floor=1, spot=6,  coins=0, label="Start" },
        { floor=1, spot=7,  coins=0, label="Start" },
        { floor=1, spot=8,  coins=0, label="Start" },
        { floor=1, spot=9,  coins=0, label="Start" },
        { floor=1, spot=10, coins=0, label="Start" },
        -- Floor 2 : déblocage par Rebirth 1-10
        { floor=2, spot=1,  coins=9999999999, label="Rebirth 1"  },
        { floor=2, spot=2,  coins=9999999999, label="Rebirth 2"  },
        { floor=2, spot=3,  coins=9999999999, label="Rebirth 3"  },
        { floor=2, spot=4,  coins=9999999999, label="Rebirth 4"  },
        { floor=2, spot=5,  coins=9999999999, label="Rebirth 5"  },
        { floor=2, spot=6,  coins=9999999999, label="Rebirth 6"  },
        { floor=2, spot=7,  coins=9999999999, label="Rebirth 7"  },
        { floor=2, spot=8,  coins=9999999999, label="Rebirth 8"  },
        { floor=2, spot=9,  coins=9999999999, label="Rebirth 9"  },
        { floor=2, spot=10, coins=9999999999, label="Rebirth 10" },
        -- Floor 3 : déblocage par Rebirth 11-20
        { floor=3, spot=1,  coins=9999999999, label="Rebirth 11" },
        { floor=3, spot=2,  coins=9999999999, label="Rebirth 12" },
        { floor=3, spot=3,  coins=9999999999, label="Rebirth 13" },
        { floor=3, spot=4,  coins=9999999999, label="Rebirth 14" },
        { floor=3, spot=5,  coins=9999999999, label="Rebirth 15" },
        { floor=3, spot=6,  coins=9999999999, label="Rebirth 16" },
        { floor=3, spot=7,  coins=9999999999, label="Rebirth 17" },
        { floor=3, spot=8,  coins=9999999999, label="Rebirth 18" },
        { floor=3, spot=9,  coins=9999999999, label="Rebirth 19" },
        { floor=3, spot=10, coins=9999999999, label="Rebirth 20" },
        -- Floor 4 : déblocage par Rebirth 21-30
        { floor=4, spot=1,  coins=9999999999, label="Rebirth 21" },
        { floor=4, spot=2,  coins=9999999999, label="Rebirth 22" },
        { floor=4, spot=3,  coins=9999999999, label="Rebirth 23" },
        { floor=4, spot=4,  coins=9999999999, label="Rebirth 24" },
        { floor=4, spot=5,  coins=9999999999, label="Rebirth 25" },
        { floor=4, spot=6,  coins=9999999999, label="Rebirth 26" },
        { floor=4, spot=7,  coins=9999999999, label="Rebirth 27" },
        { floor=4, spot=8,  coins=9999999999, label="Rebirth 28" },
        { floor=4, spot=9,  coins=9999999999, label="Rebirth 29" },
        { floor=4, spot=10, coins=9999999999, label="Rebirth 30" },
    },

    baseSurTotalGagne = true,
}

-- === MAX BASES ===
-- Lu par AssignationSystem
GameConfigShared.MaxBases = 8

-- === RARETÉS ===
-- Lu par DropSystem, SpawnManager
GameConfigShared.Raretes = {
    { nom = "Common",    chance = 60,  valeur = 1,   couleur = Color3.fromRGB(200, 200, 200) },
    { nom = "Uncommon",  chance = 25,  valeur = 3,   couleur = Color3.fromRGB(100, 200, 100) },
    { nom = "Rare",      chance = 10,  valeur = 8,   couleur = Color3.fromRGB(100, 130, 255) },
    { nom = "Epic",      chance = 4,   valeur = 20,  couleur = Color3.fromRGB(180, 50,  255) },
    { nom = "Legendary", chance = 0.9, valeur = 60,  couleur = Color3.fromRGB(255, 200, 0  ) },
    { nom = "Secret",    chance = 0.1, valeur = 500, couleur = Color3.fromRGB(255, 50,  50 ) },
}

-- === VALEUR PAR RARETÉ ===
-- Lu par DropSystem
-- Clés en minuscule (Common…) ET en majuscule (COMMON…) pour compatibilité
-- avec BrainrotPlatformSpawner qui utilise des raretés ALL CAPS.
GameConfigShared.ValeurParRarete = {
    Common    = 1,   COMMON    = 1,
    Uncommon  = 3,   UNCOMMON  = 3,
    Rare      = 8,   RARE      = 8,
    Epic      = 20,  EPIC      = 20,
    Legendary = 60,  LEGENDARY = 60,
    Mythic    = 100, MYTHIC    = 100,
    God       = 200, GOD       = 200,
    Secret    = 500, SECRET    = 500,
    Og        = 500, OG        = 500,
}

-- === INCOME PAR RARETÉ ===
-- Lu par IncomeSystem
GameConfigShared.IncomeParRarete = {
    Common    = 1,   COMMON    = 1,
    Uncommon  = 3,   UNCOMMON  = 3,
    Rare      = 8,   RARE      = 8,
    Epic      = 20,  EPIC      = 20,
    Legendary = 60,  LEGENDARY = 60,
    Mythic    = 100, MYTHIC    = 100,
    God       = 200, GOD       = 200,
    Secret    = 500, SECRET    = 500,
    Og        = 500, OG        = 500,
}

-- === ANIMATION CONFIG ===
-- Lu par DropSystem, SpawnManager
GameConfigShared.AnimationConfig = {
    brSpawnDuree     = 2.0,
    brSpawnOffsetY   = -3,
    brDepotDuree     = 0.3,
    timerHauteurY    = 8,
    timerStudsOffset = 5,
}

-- === CAPTURE CONFIG ===
-- Lu par PickupSystem
GameConfigShared.CaptureConfig = {
    Common    = { mode = "prompt", holdDuration = 0   },
    Uncommon  = { mode = "prompt", holdDuration = 0   },
    Rare      = { mode = "prompt", holdDuration = 0   },
    Epic      = { mode = "prompt", holdDuration = 0.5 },
    Legendary = { mode = "prompt", holdDuration = 1.5 },
    Secret    = { mode = "prompt", holdDuration = 5.0 },
}

-- === CARRY ===
-- Lu par CarrySystem
GameConfigShared.CarryNiveaux = {
    [0] = 1,
    [1] = 3,
    [2] = 5,
    [3] = 8,
}

GameConfigShared.CarryPrices = {
    [1] = 500,
    [2] = 2000,
    [3] = 0,  -- Game Pass
}

-- === REBIRTH ===
-- Lu par BaseProgressionSystem, RebirthSystem
GameConfigShared.RebirthFloorDiscount = 0.15

GameConfigShared.FloorUnlockCosts = {
    [2] = 2000,
    [3] = 10000,
    [4] = 60000,
}

-- === SPAWN CONFIG ===
-- Lu par SpawnManager
GameConfigShared.SpawnConfig = {
    intervalleSecondes = 4,
    maxParBase         = 15,
    despawnSecondes    = 30,
}

-- === ITEMS À SPAWNER ===
-- Lu par SpawnManager / DropSystem
GameConfigShared.SpawnableItems = {
    dossier = "Brainrots",
    rarites = {
        { nom = "Common",    poids = 60,  valeur = 1   },
        { nom = "Uncommon",  poids = 25,  valeur = 3   },
        { nom = "Rare",      poids = 10,  valeur = 8   },
        { nom = "Epic",      poids = 4,   valeur = 20  },
        { nom = "Legendary", poids = 0.9, valeur = 60  },
        { nom = "Secret",    poids = 0.1, valeur = 500 },
    },
}

-- === BOARD CONFIG ===
-- Lu par BoardSystem
GameConfigShared.BoardConfig = {
    texteDefaut   = "REBIRTH\nClick to view",
    distanceClick = 20,
}

return GameConfigShared