-- shared-lib/src/shared/RebirthConfig.lua
-- Config Rebirth unifiée — BrainRotFarm & LavaTower
-- Injecter via : RebirthSystem.Config = require(RS.SharedLib.Shared.RebirthConfig)
--
-- Distribution : 3 COMMON · 5 RARE · 3 EPIC · 5 LEGENDARY · 4 MYTHIC · 5 GOD · 5 SECRET
-- slotsBonus = 1 par rebirth → 30 slots débloqués au total
--
-- TODO : chaque niveau aura un brainrot précis requis (pas juste une rareté).
--        Le champ brainRotRequis.id sera ajouté ultérieurement.

local RebirthConfig = {

    -- ── COMMON (1–3) ────────────────────────────────────────────────────────
    [1]  = { coinsRequis = 5000,                 brainRotRequis = { rarete = "COMMON",    quantite = 1 }, multiplicateur = 1.10, slotsBonus = 1, label = "Rebirth I",      couleur = Color3.fromRGB(200, 200, 200), couleurHex = 0xC8C8C8 },
    [2]  = { coinsRequis = 11000,                brainRotRequis = { rarete = "COMMON",    quantite = 1 }, multiplicateur = 1.20, slotsBonus = 1, label = "Rebirth II",     couleur = Color3.fromRGB(200, 200, 200), couleurHex = 0xC8C8C8 },
    [3]  = { coinsRequis = 25000,                brainRotRequis = { rarete = "COMMON",    quantite = 1 }, multiplicateur = 1.30, slotsBonus = 1, label = "Rebirth III",    couleur = Color3.fromRGB(200, 200, 200), couleurHex = 0xC8C8C8 },

    -- ── RARE (4–8) ──────────────────────────────────────────────────────────
    [4]  = { coinsRequis = 60000,                brainRotRequis = { rarete = "RARE",      quantite = 1 }, multiplicateur = 1.45, slotsBonus = 1, label = "Rebirth IV",     couleur = Color3.fromRGB(100, 130, 255), couleurHex = 0x6482FF },
    [5]  = { coinsRequis = 135000,               brainRotRequis = { rarete = "RARE",      quantite = 1 }, multiplicateur = 1.60, slotsBonus = 1, label = "Rebirth V",      couleur = Color3.fromRGB(100, 130, 255), couleurHex = 0x6482FF },
    [6]  = { coinsRequis = 300000,               brainRotRequis = { rarete = "RARE",      quantite = 1 }, multiplicateur = 1.80, slotsBonus = 1, label = "Rebirth VI",     couleur = Color3.fromRGB(100, 130, 255), couleurHex = 0x6482FF },
    [7]  = { coinsRequis = 680000,               brainRotRequis = { rarete = "RARE",      quantite = 1 }, multiplicateur = 2.00, slotsBonus = 1, label = "Rebirth VII",    couleur = Color3.fromRGB(100, 130, 255), couleurHex = 0x6482FF },
    [8]  = { coinsRequis = 1500000,              brainRotRequis = { rarete = "RARE",      quantite = 1 }, multiplicateur = 2.25, slotsBonus = 1, label = "Rebirth VIII",   couleur = Color3.fromRGB(100, 130, 255), couleurHex = 0x6482FF },

    -- ── EPIC (9–11) ─────────────────────────────────────────────────────────
    [9]  = { coinsRequis = 5000000,              brainRotRequis = { rarete = "EPIC",      quantite = 1 }, multiplicateur = 2.55, slotsBonus = 1, label = "Rebirth IX",     couleur = Color3.fromRGB(180,  50, 255), couleurHex = 0xB432FF },
    [10] = { coinsRequis = 13000000,             brainRotRequis = { rarete = "EPIC",      quantite = 1 }, multiplicateur = 2.90, slotsBonus = 1, label = "Rebirth X",      couleur = Color3.fromRGB(180,  50, 255), couleurHex = 0xB432FF },
    [11] = { coinsRequis = 33000000,             brainRotRequis = { rarete = "EPIC",      quantite = 1 }, multiplicateur = 3.30, slotsBonus = 1, label = "Rebirth XI",     couleur = Color3.fromRGB(180,  50, 255), couleurHex = 0xB432FF },

    -- ── LEGENDARY (12–16) ───────────────────────────────────────────────────
    [12] = { coinsRequis = 120000000,            brainRotRequis = { rarete = "LEGENDARY", quantite = 1 }, multiplicateur = 3.75, slotsBonus = 1, label = "Rebirth XII",    couleur = Color3.fromRGB(255, 200,   0), couleurHex = 0xFFC800 },
    [13] = { coinsRequis = 300000000,            brainRotRequis = { rarete = "LEGENDARY", quantite = 1 }, multiplicateur = 4.25, slotsBonus = 1, label = "Rebirth XIII",   couleur = Color3.fromRGB(255, 200,   0), couleurHex = 0xFFC800 },
    [14] = { coinsRequis = 750000000,            brainRotRequis = { rarete = "LEGENDARY", quantite = 1 }, multiplicateur = 4.80, slotsBonus = 1, label = "Rebirth XIV",    couleur = Color3.fromRGB(255, 200,   0), couleurHex = 0xFFC800 },
    [15] = { coinsRequis = 1900000000,           brainRotRequis = { rarete = "LEGENDARY", quantite = 1 }, multiplicateur = 5.40, slotsBonus = 1, label = "Rebirth XV",     couleur = Color3.fromRGB(255, 200,   0), couleurHex = 0xFFC800 },
    [16] = { coinsRequis = 4800000000,           brainRotRequis = { rarete = "LEGENDARY", quantite = 1 }, multiplicateur = 6.10, slotsBonus = 1, label = "Rebirth XVI",    couleur = Color3.fromRGB(255, 200,   0), couleurHex = 0xFFC800 },

    -- ── MYTHIC (17–20) ──────────────────────────────────────────────────────
    [17] = { coinsRequis = 18000000000,          brainRotRequis = { rarete = "MYTHIC",    quantite = 1 }, multiplicateur = 7.00, slotsBonus = 1, label = "Rebirth XVII",   couleur = Color3.fromRGB(255, 100,   0), couleurHex = 0xFF6400 },
    [18] = { coinsRequis = 54000000000,          brainRotRequis = { rarete = "MYTHIC",    quantite = 1 }, multiplicateur = 8.00, slotsBonus = 1, label = "Rebirth XVIII",  couleur = Color3.fromRGB(255, 100,   0), couleurHex = 0xFF6400 },
    [19] = { coinsRequis = 162000000000,         brainRotRequis = { rarete = "MYTHIC",    quantite = 1 }, multiplicateur = 9.20, slotsBonus = 1, label = "Rebirth XIX",    couleur = Color3.fromRGB(255, 100,   0), couleurHex = 0xFF6400 },
    [20] = { coinsRequis = 487000000000,         brainRotRequis = { rarete = "MYTHIC",    quantite = 1 }, multiplicateur = 10.5, slotsBonus = 1, label = "Rebirth XX",     couleur = Color3.fromRGB(255, 100,   0), couleurHex = 0xFF6400 },

    -- ── GOD (21–25) ─────────────────────────────────────────────────────────
    [21] = { coinsRequis = 2000000000000,        brainRotRequis = { rarete = "GOD",       quantite = 1 }, multiplicateur = 12.0, slotsBonus = 1, label = "Rebirth XXI",    couleur = Color3.fromRGB(255,  50,  50), couleurHex = 0xFF3232 },
    [22] = { coinsRequis = 6500000000000,        brainRotRequis = { rarete = "GOD",       quantite = 1 }, multiplicateur = 14.0, slotsBonus = 1, label = "Rebirth XXII",   couleur = Color3.fromRGB(255,  50,  50), couleurHex = 0xFF3232 },
    [23] = { coinsRequis = 21000000000000,       brainRotRequis = { rarete = "GOD",       quantite = 1 }, multiplicateur = 16.0, slotsBonus = 1, label = "Rebirth XXIII",  couleur = Color3.fromRGB(255,  50,  50), couleurHex = 0xFF3232 },
    [24] = { coinsRequis = 68000000000000,       brainRotRequis = { rarete = "GOD",       quantite = 1 }, multiplicateur = 18.5, slotsBonus = 1, label = "Rebirth XXIV",   couleur = Color3.fromRGB(255,  50,  50), couleurHex = 0xFF3232 },
    [25] = { coinsRequis = 220000000000000,      brainRotRequis = { rarete = "GOD",       quantite = 1 }, multiplicateur = 21.5, slotsBonus = 1, label = "Rebirth XXV",    couleur = Color3.fromRGB(255,  50,  50), couleurHex = 0xFF3232 },

    -- ── SECRET (26–30) ──────────────────────────────────────────────────────
    [26] = { coinsRequis = 990000000000000,      brainRotRequis = { rarete = "SECRET",    quantite = 1 }, multiplicateur = 25.0, slotsBonus = 1, label = "Rebirth XXVI",   couleur = Color3.fromRGB(180,   0, 120), couleurHex = 0xB40078 },
    [27] = { coinsRequis = 3300000000000000,     brainRotRequis = { rarete = "SECRET",    quantite = 1 }, multiplicateur = 29.0, slotsBonus = 1, label = "Rebirth XXVII",  couleur = Color3.fromRGB(180,   0, 120), couleurHex = 0xB40078 },
    [28] = { coinsRequis = 11000000000000000,    brainRotRequis = { rarete = "SECRET",    quantite = 1 }, multiplicateur = 34.0, slotsBonus = 1, label = "Rebirth XXVIII", couleur = Color3.fromRGB(180,   0, 120), couleurHex = 0xB40078 },
    [29] = { coinsRequis = 37000000000000000,    brainRotRequis = { rarete = "SECRET",    quantite = 1 }, multiplicateur = 40.0, slotsBonus = 1, label = "Rebirth XXIX",   couleur = Color3.fromRGB(180,   0, 120), couleurHex = 0xB40078 },
    [30] = { coinsRequis = 124000000000000000,   brainRotRequis = { rarete = "SECRET",    quantite = 1 }, multiplicateur = 47.0, slotsBonus = 1, label = "Rebirth XXX",    couleur = Color3.fromRGB(180,   0, 120), couleurHex = 0xB40078 },
}

return RebirthConfig
