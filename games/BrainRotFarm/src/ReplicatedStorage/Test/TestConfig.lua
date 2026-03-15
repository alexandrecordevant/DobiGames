-- ReplicatedStorage/Test/TestConfig.lua
-- ⚠️ CONFIG DE TEST UNIQUEMENT — ne jamais modifier GameConfig.lua pour tester
-- Activer via GameConfig.TEST_MODE = true dans GameConfig.lua

local TestConfig = {}

-- === SPAWN BOOSTÉ ===
TestConfig.BaseSpawnRate     = 0.5  -- spawn toutes les 0.5s (vs 4s normal)
TestConfig.MAX_BRAINROTS_MAP = 30   -- plus de BR sur la map simultanément
TestConfig.DESPAWN_SECONDES  = 60   -- BR restent plus longtemps avant despawn

-- === CARRY BOOSTÉ ===
TestConfig.CarryCapaciteDefaut = 5                        -- capacité max dès le début
TestConfig.CarryPrixUpgrade    = { [1]=1, [2]=1, [3]=1 } -- upgrades à 1 coin

-- === INCOME BOOSTÉ ===
-- Multiplicateur appliqué à TOUS les revenus passifs (IncomeSystem)
TestConfig.IncomeMultiplier = 100  -- ×100 → coins s'accumulent très vite

-- === PROGRESSION BASE BOOSTÉE ===
-- Seuils réduits à ~1/1000e pour tester tous les déblocages en quelques secondes
TestConfig.SeuilsTest = {
    -- Floor 1
    { floor=1, spot=1,  coins=0,   label="Départ"   },
    { floor=1, spot=2,  coins=0,   label="Départ"   },
    { floor=1, spot=3,  coins=1,   label="1 coin"   },
    { floor=1, spot=4,  coins=2,   label="2 coins"  },
    { floor=1, spot=5,  coins=3,   label="3 coins"  },
    { floor=1, spot=6,  coins=4,   label="4 coins"  },
    { floor=1, spot=7,  coins=5,   label="5 coins"  },
    { floor=1, spot=8,  coins=6,   label="6 coins"  },
    { floor=1, spot=9,  coins=7,   label="7 coins"  },
    { floor=1, spot=10, coins=8,   label="8 coins"  },
    -- Floor 2
    { floor=2, spot=1,  coins=10,  label="Étage 2"  },
    { floor=2, spot=2,  coins=12,  label="12 coins" },
    { floor=2, spot=3,  coins=14,  label="14 coins" },
    { floor=2, spot=4,  coins=16,  label="16 coins" },
    { floor=2, spot=5,  coins=18,  label="18 coins" },
    { floor=2, spot=6,  coins=20,  label="20 coins" },
    { floor=2, spot=7,  coins=22,  label="22 coins" },
    { floor=2, spot=8,  coins=24,  label="24 coins" },
    { floor=2, spot=9,  coins=26,  label="26 coins" },
    { floor=2, spot=10, coins=30,  label="30 coins" },
    -- Floor 3
    { floor=3, spot=1,  coins=40,  label="Étage 3"   },
    { floor=3, spot=2,  coins=50,  label="50 coins"  },
    { floor=3, spot=3,  coins=60,  label="60 coins"  },
    { floor=3, spot=4,  coins=70,  label="70 coins"  },
    { floor=3, spot=5,  coins=80,  label="80 coins"  },
    { floor=3, spot=6,  coins=90,  label="90 coins"  },
    { floor=3, spot=7,  coins=100, label="100 coins" },
    { floor=3, spot=8,  coins=110, label="110 coins" },
    { floor=3, spot=9,  coins=120, label="120 coins" },
    { floor=3, spot=10, coins=130, label="130 coins" },
    -- Floor 4
    { floor=4, spot=1,  coins=150, label="Étage 4"   },
    { floor=4, spot=2,  coins=160, label="160 coins" },
    { floor=4, spot=3,  coins=170, label="170 coins" },
    { floor=4, spot=4,  coins=180, label="180 coins" },
    { floor=4, spot=5,  coins=190, label="190 coins" },
    { floor=4, spot=6,  coins=200, label="200 coins" },
    { floor=4, spot=7,  coins=210, label="210 coins" },
    { floor=4, spot=8,  coins=220, label="220 coins" },
    { floor=4, spot=9,  coins=240, label="240 coins" },
    { floor=4, spot=10, coins=250, label="250 coins" },
}

-- === REBIRTH BOOSTÉ ===
-- Conditions drastiquement réduites pour valider le flow complet en studio
TestConfig.RebirthConfig = {
    [1] = { coinsRequis=50,  brainRotRequis={ rarete="LEGENDARY",    quantite=1 }, multiplicateur=1.5, slotsBonus=2  },
    [2] = { coinsRequis=100, brainRotRequis={ rarete="MYTHIC",       quantite=1 }, multiplicateur=2.0, slotsBonus=4  },
    [3] = { coinsRequis=200, brainRotRequis={ rarete="SECRET",       quantite=1 }, multiplicateur=3.0, slotsBonus=6  },
    [4] = { coinsRequis=300, brainRotRequis={ rarete="BRAINROT_GOD", quantite=1 }, multiplicateur=5.0, slotsBonus=10 },
}

-- === CHAMP COMMUN BOOSTÉ ===
TestConfig.ChampCommun = {
    MYTHIC = {
        intervalleSecondes   = 30,   -- toutes les 30s (vs 8 min en prod)
        compteurVisibleAvant = 10,   -- compteur visible 10s avant apparition
        valeur               = 300,
    },
    SECRET = {
        intervalleSecondes   = 60,   -- toutes les 60s (vs 20 min en prod)
        compteurVisibleAvant = 15,
        valeur               = 1000,
    },
}

-- === EVENTS BOOSTÉS ===
TestConfig.EventIntervalleMinutes = 0.5  -- event toutes les 30s (vs 120 min)
TestConfig.EventDureeMinutes      = 0.1  -- dure 6 secondes (vs 5 min)

-- === HOLD DURATION RÉDUIT ===
-- Permet de tester la capture ProximityPrompt sans attendre de longues durées
TestConfig.CaptureConfig = {
    COMMON       = { holdDuration = 0   },
    OG           = { holdDuration = 0   },
    RARE         = { holdDuration = 0   },
    EPIC         = { holdDuration = 0.1 },
    LEGENDARY    = { holdDuration = 0.2 },
    MYTHIC       = { holdDuration = 0.3 },
    SECRET       = { holdDuration = 0.5 },
    BRAINROT_GOD = { holdDuration = 1.0 },
}

-- === AUTO-RESET À LA CONNEXION ===
-- Si true : efface le DataStore de chaque joueur qui se connecte (sans kick)
-- Les données vides sont chargées immédiatement → parfait pour tester depuis zéro
-- ⚠️ Remettre à false si tu veux tester la persistance (étape 14)
TestConfig.AutoResetOnJoin = true

return TestConfig
