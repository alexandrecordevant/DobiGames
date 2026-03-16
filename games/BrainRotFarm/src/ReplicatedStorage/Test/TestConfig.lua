-- ReplicatedStorage/Test/TestConfig.lua
-- ⚠️ CONFIG DE TEST UNIQUEMENT — ne jamais modifier GameConfig.lua pour tester
-- Activer via GameConfig.TEST_MODE = true dans GameConfig.lua

--[[
COMPARATIF TEST vs RÉEL
═══════════════════════════════════════════════════════
Paramètre              TEST            RÉEL        Ratio
───────────────────────────────────────────────────────
Spawn BR               0.5s            4s          ×8
Income                 ×2              ×1          ×2
Seuil Floor 2          1 000 coins     2 000       ÷2
Seuil Floor 3          7 500 coins     15 000      ÷2
Seuil Floor 4          40 000 coins    80 000      ÷2
Rebirth 1              150 000 coins   300 000     ÷2
Event intervalle        2 min           2h          ×60
MYTHIC intervalle       2 min           8 min       ×4
SECRET intervalle       5 min           20 min      ×4
HoldDuration EPIC       0.3s            0.5s        légère
Carry défaut            1 BR            1 BR        =
Prix upgrades           réels           réels       =
AutoReset au Play       ✅ actif        —           —
═══════════════════════════════════════════════════════
OBJECTIF : tester toute la progression en ~20-30 min
]]

local TestConfig = {}

-- ═══════════════════════════════════════════
-- ✅ BOOSTÉS (sans ces boosts les tests prendraient trop longtemps)
-- ═══════════════════════════════════════════

-- Spawn BR : toutes les 0.5s au lieu de 4s (×8)
TestConfig.BaseSpawnRate     = 0.5
TestConfig.MAX_BRAINROTS_MAP = 20
TestConfig.DESPAWN_SECONDES  = 45

-- Events automatiques : toutes les 2 min au lieu de 2h (×60)
TestConfig.EventIntervalleMinutes = 2
TestConfig.EventDureeMinutes      = 0.5  -- 30 secondes

-- ChampCommun : MYTHIC toutes les 2 min, SECRET toutes les 5 min
TestConfig.ChampCommun = {
    MYTHIC = {
        intervalleSecondes   = 120,
        compteurVisibleAvant = 20,
        valeur               = 300,
    },
    SECRET = {
        intervalleSecondes   = 300,
        compteurVisibleAvant = 30,
        valeur               = 1000,
    },
}

-- Admin Abuse hebdo : toutes les 5 min en test
TestConfig.AdminAbuseHebdo = {
    intervalleSecondes = 300,
    dureeMinutes       = 0.5,
    spawnMultiplier    = 20,
}

-- HoldDuration réduit (mais pas à 0 — teste quand même le ProximityPrompt)
TestConfig.CaptureConfig = {
    COMMON       = { mode = "touched", holdDuration = 0   },
    OG           = { mode = "touched", holdDuration = 0   },
    RARE         = { mode = "touched", holdDuration = 0   },
    EPIC         = { mode = "prompt",  holdDuration = 0.3 },
    LEGENDARY    = { mode = "prompt",  holdDuration = 0.5 },
    MYTHIC       = { mode = "prompt",  holdDuration = 1.0 },
    SECRET       = { mode = "prompt",  holdDuration = 2.0 },
    BRAINROT_GOD = { mode = "prompt",  holdDuration = 3.0 },
}

-- ═══════════════════════════════════════════
-- 🔴 VALEURS ×2 (légèrement accéléré, testable)
-- ═══════════════════════════════════════════

-- Income ×2 (vs ×1 réel)
TestConfig.IncomeMultiplier = 2

-- Seuils progression ÷2 (Floor 2 = 1 000 coins au lieu de 2 000)
TestConfig.SeuilsTest = {
    -- Floor 1
    { floor = 1, spot = 1,  coins = 0    },
    { floor = 1, spot = 2,  coins = 0    },
    { floor = 1, spot = 3,  coins = 25   },
    { floor = 1, spot = 4,  coins = 50   },
    { floor = 1, spot = 5,  coins = 100  },
    { floor = 1, spot = 6,  coins = 175  },
    { floor = 1, spot = 7,  coins = 250  },
    { floor = 1, spot = 8,  coins = 375  },
    { floor = 1, spot = 9,  coins = 500  },
    { floor = 1, spot = 10, coins = 750  },
    -- Floor 2
    { floor = 2, spot = 1,  coins = 1000  },
    { floor = 2, spot = 2,  coins = 1250  },
    { floor = 2, spot = 3,  coins = 1500  },
    { floor = 2, spot = 4,  coins = 1750  },
    { floor = 2, spot = 5,  coins = 2000  },
    { floor = 2, spot = 6,  coins = 2500  },
    { floor = 2, spot = 7,  coins = 3000  },
    { floor = 2, spot = 8,  coins = 3500  },
    { floor = 2, spot = 9,  coins = 4000  },
    { floor = 2, spot = 10, coins = 5000  },
    -- Floor 3
    { floor = 3, spot = 1,  coins = 7500  },
    { floor = 3, spot = 2,  coins = 9000  },
    { floor = 3, spot = 3,  coins = 10500 },
    { floor = 3, spot = 4,  coins = 12500 },
    { floor = 3, spot = 5,  coins = 15000 },
    { floor = 3, spot = 6,  coins = 17500 },
    { floor = 3, spot = 7,  coins = 20000 },
    { floor = 3, spot = 8,  coins = 22500 },
    { floor = 3, spot = 9,  coins = 25000 },
    { floor = 3, spot = 10, coins = 30000 },
    -- Floor 4
    { floor = 4, spot = 1,  coins = 40000  },
    { floor = 4, spot = 2,  coins = 45000  },
    { floor = 4, spot = 3,  coins = 50000  },
    { floor = 4, spot = 4,  coins = 60000  },
    { floor = 4, spot = 5,  coins = 70000  },
    { floor = 4, spot = 6,  coins = 80000  },
    { floor = 4, spot = 7,  coins = 90000  },
    { floor = 4, spot = 8,  coins = 100000 },
    { floor = 4, spot = 9,  coins = 125000 },
    { floor = 4, spot = 10, coins = 150000 },
}

-- Rebirth ÷2
TestConfig.RebirthConfig = {
    [1] = {
        coinsRequis    = 150000,
        brainRotRequis = { rarete = "LEGENDARY", quantite = 1 },
        multiplicateur = 1.5,
        slotsBonus     = 2,
        label          = "Rebirth I",
    },
    [2] = {
        coinsRequis    = 250000,
        brainRotRequis = { rarete = "MYTHIC", quantite = 1 },
        multiplicateur = 2.0,
        slotsBonus     = 4,
        label          = "Rebirth II",
    },
    [3] = {
        coinsRequis    = 500000,
        brainRotRequis = { rarete = "SECRET", quantite = 1 },
        multiplicateur = 3.0,
        slotsBonus     = 6,
        label          = "Rebirth III",
    },
    [4] = {
        coinsRequis    = 1000000,
        brainRotRequis = { rarete = "BRAINROT_GOD", quantite = 1 },
        multiplicateur = 5.0,
        slotsBonus     = 10,
        label          = "Rebirth IV",
    },
}

-- ═══════════════════════════════════════════
-- 🔵 VALEURS RÉELLES (inchangées)
-- ═══════════════════════════════════════════

-- Carry : 1 BR par défaut (réel)
-- TestConfig.CarryCapaciteDefaut = nil  ← utilise GameConfig

-- Prix upgrades shop : réels
-- TestConfig.CarryPrixUpgrade = nil  ← utilise GameConfig

-- WalkSpeed : réel (16)
-- TestConfig.WalkSpeedDefaut = nil  ← utilise GameConfig

-- ═══════════════════════════════════════════
-- 🔄 RESET AUTOMATIQUE AU PLAY
-- ═══════════════════════════════════════════

-- Reset automatique dès qu'un joueur rejoint en TEST_MODE
-- Mettre à false pour tester la persistance des données (étape 14)
TestConfig.AutoResetOnJoin = true

return TestConfig
