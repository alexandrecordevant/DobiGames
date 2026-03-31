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

    seuils = {
        -- Floor 1
        { floor=1, spot=1,  coins=0,      label="Start"         },
        { floor=1, spot=2,  coins=0,      label="Start"         },
        { floor=1, spot=3,  coins=50,     label="50 coins"      },
        { floor=1, spot=4,  coins=100,    label="100 coins"     },
        { floor=1, spot=5,  coins=200,    label="200 coins"     },
        { floor=1, spot=6,  coins=350,    label="350 coins"     },
        { floor=1, spot=7,  coins=500,    label="500 coins"     },
        { floor=1, spot=8,  coins=750,    label="750 coins"     },
        { floor=1, spot=9,  coins=1000,   label="1 000 coins"   },
        { floor=1, spot=10, coins=1500,   label="1 500 coins"   },
        -- Floor 2
        { floor=2, spot=1,  coins=2000,   label="Stage 2"       },
        { floor=2, spot=2,  coins=2500,   label="2 500 coins"   },
        { floor=2, spot=3,  coins=3000,   label="3 000 coins"   },
        { floor=2, spot=4,  coins=3500,   label="3 500 coins"   },
        { floor=2, spot=5,  coins=4000,   label="4 000 coins"   },
        { floor=2, spot=6,  coins=5000,   label="5 000 coins"   },
        { floor=2, spot=7,  coins=6000,   label="6 000 coins"   },
        { floor=2, spot=8,  coins=7000,   label="7 000 coins"   },
        { floor=2, spot=9,  coins=8000,   label="8 000 coins"   },
        { floor=2, spot=10, coins=10000,  label="10 000 coins"  },
        -- Floor 3
        { floor=3, spot=1,  coins=15000,  label="Stage 3"       },
        { floor=3, spot=2,  coins=18000,  label="18 000 coins"  },
        { floor=3, spot=3,  coins=21000,  label="21 000 coins"  },
        { floor=3, spot=4,  coins=25000,  label="25 000 coins"  },
        { floor=3, spot=5,  coins=30000,  label="30 000 coins"  },
        { floor=3, spot=6,  coins=35000,  label="35 000 coins"  },
        { floor=3, spot=7,  coins=40000,  label="40 000 coins"  },
        { floor=3, spot=8,  coins=45000,  label="45 000 coins"  },
        { floor=3, spot=9,  coins=50000,  label="50 000 coins"  },
        { floor=3, spot=10, coins=60000,  label="60 000 coins"  },
        -- Floor 4
        { floor=4, spot=1,  coins=80000,  label="Stage 4"       },
        { floor=4, spot=2,  coins=90000,  label="90 000 coins"  },
        { floor=4, spot=3,  coins=100000, label="100 000 coins" },
        { floor=4, spot=4,  coins=120000, label="120 000 coins" },
        { floor=4, spot=5,  coins=140000, label="140 000 coins" },
        { floor=4, spot=6,  coins=160000, label="160 000 coins" },
        { floor=4, spot=7,  coins=180000, label="180 000 coins" },
        { floor=4, spot=8,  coins=200000, label="200 000 coins" },
        { floor=4, spot=9,  coins=250000, label="250 000 coins" },
        { floor=4, spot=10, coins=300000, label="300 000 coins" },
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
GameConfigShared.ValeurParRarete = {
    Common    = 1,
    Uncommon  = 3,
    Rare      = 8,
    Epic      = 20,
    Legendary = 60,
    Secret    = 500,
}

-- === INCOME PAR RARETÉ ===
-- Lu par IncomeSystem
GameConfigShared.IncomeParRarete = {
    Common    = 1,
    Uncommon  = 3,
    Rare      = 8,
    Epic      = 20,
    Legendary = 60,
    Secret    = 500,
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
    texteDefaut   = "🔄 REBIRTH\nClick to view",
    distanceClick = 20,
}

return GameConfigShared