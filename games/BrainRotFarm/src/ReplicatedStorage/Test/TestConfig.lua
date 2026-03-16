-- ReplicatedStorage/Test/TestConfig.lua
-- ⚠️ CONFIG DE TEST UNIQUEMENT — ne jamais modifier GameConfig.lua pour tester
-- Activer via GameConfig.TEST_MODE = true dans GameConfig.lua

-- ═══════════════════════════════════════════════════════════════
-- PARAMÈTRES TEST — BrainRotFarm
-- ═══════════════════════════════════════════════════════════════
--
-- ✅ BOOSTÉS (pour tester sans attendre) :
--    - Spawn rate : 0.5s (vs 4s réel)
--    - Events : toutes les 30s (vs 2h réel)
--    - HoldDuration captures : réduit
--    - Income : ×3 (vs ×1 réel)
--
-- 🔴 VALEURS RÉELLES (pour tester la vraie progression) :
--    - Seuils déblocage base : réels (Floor 2 = 2 000 coins)
--    - Carry capacité défaut : 1 (réel)
--    - Prix upgrades carry : réels
--    - Conditions Rebirth : réelles (300 000 coins + LEGENDARY)
--
-- ⚠️  OBJECTIF : atteindre Floor 2 en ~5 min de test
--               (spawn rapide + income ×3 = réaliste)
-- ═══════════════════════════════════════════════════════════════

local TestConfig = {}

-- === SPAWN BOOSTÉ ===
TestConfig.BaseSpawnRate     = 0.5  -- spawn toutes les 0.5s (vs 4s normal)
TestConfig.MAX_BRAINROTS_MAP = 30   -- plus de BR sur la map simultanément
TestConfig.DESPAWN_SECONDES  = 60   -- BR restent plus longtemps avant despawn

-- === CARRY — VALEURS RÉELLES ===
-- nil → CarrySystem utilise les vraies valeurs (capacité 1 au départ, prix réels)
-- TestConfig.CarryCapaciteDefaut = 5           -- ❌ désactivé : progression réelle
-- TestConfig.CarryPrixUpgrade    = { [1]=1, [2]=1, [3]=1 }  -- ❌ désactivé

-- === INCOME LÉGÈREMENT BOOSTÉ ===
-- ×3 au lieu de ×100 : progression réaliste en ~5 min (vs 30+ min à ×1)
TestConfig.IncomeMultiplier = 3

-- === PROGRESSION BASE — VALEURS RÉELLES ===
-- nil → BaseProgressionSystem utilise GameConfig.ProgressionConfig.seuils
-- (Floor 2 = 2 000 coins, Floor 3 = 15 000 coins, Floor 4 = 80 000 coins)
-- TestConfig.SeuilsTest = { ... }  -- ❌ désactivé : seuils réels

-- === REBIRTH — VALEURS RÉELLES ===
-- nil → RebirthSystem utilise sa config interne réelle
-- (Rebirth I = 300 000 coins + 1 LEGENDARY, etc.)
-- TestConfig.RebirthConfig = { ... }  -- ❌ désactivé : conditions réelles

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
