-- ReplicatedStorage/Modules/GameConfig.lua
-- ⚠️ SEUL FICHIER À MODIFIER PAR JEU

local GameConfig = {}

-- === IDENTITÉ DU JEU ===
GameConfig.NomDuJeu          = "Brain Rot Farm"
GameConfig.Theme             = "farm"
GameConfig.CollectibleName   = "Brain Rot"
GameConfig.BaseNom           = "Base"

-- === IDs MONÉTISATION (remplir après création sur Roblox) ===
GameConfig.GamePassVIP            = { Id = 0, Prix = 149 }
GameConfig.GamePassOfflineVault   = { Id = 0, Prix = 199 }
GameConfig.GamePassAutoCollect    = { Id = 0, Prix = 299 }
GameConfig.ProduitLuckyHour       = { Id = 0, Prix = 35  }
GameConfig.ProduitSecretReveal    = { Id = 0, Prix = 25  }
GameConfig.ProduitSkipTier        = { Id = 0, Prix = 50  }

-- === DISCORD WEBHOOK (remplir après création Discord) ===
GameConfig.DiscordWebhookURL = ""

-- === ÉCONOMIE ===
GameConfig.BaseSpawnRate          = 3
GameConfig.BaseSpawnCount         = 1
GameConfig.OfflineIncomeMultiplier = 0.1
GameConfig.MaxOfflineHeures       = 8

-- === PROGRESSION ===
GameConfig.TotalTiers             = 10
GameConfig.CoutUpgradeBase        = 100
GameConfig.CoutUpgradeMultiplier  = 2.5
GameConfig.PrestigeMultiplier     = 2.0

-- === EVENTS AUTOMATIQUES ===
GameConfig.EventIntervalleMinutes = 120
GameConfig.EventDureeMinutes      = 5
GameConfig.EventSpawnMultiplier   = 10
GameConfig.EarlyBirdBonusMinutes  = 60
GameConfig.AdminAbuseHebdo = {
    jourSemaine     = 6,
    heureUTC        = 20,
    dureeMinutes    = 45,
    spawnMultiplier = 50,
}

-- === RARETÉS ===
GameConfig.Raretes = {
    { nom = "Common",    chance = 60,  valeur = 1,   couleur = Color3.fromRGB(200, 200, 200) },
    { nom = "Uncommon",  chance = 25,  valeur = 3,   couleur = Color3.fromRGB(100, 200, 100) },
    { nom = "Rare",      chance = 10,  valeur = 10,  couleur = Color3.fromRGB(100, 100, 255) },
    { nom = "Epic",      chance = 4,   valeur = 30,  couleur = Color3.fromRGB(180, 50,  255) },
    { nom = "Legendary", chance = 0.9, valeur = 100, couleur = Color3.fromRGB(255, 200, 0  ) },
    { nom = "Secret",    chance = 0.1, valeur = 500, couleur = Color3.fromRGB(255, 50,  50 ) },
}

-- === COULEURS THÈME ===
GameConfig.CouleurPrimaire   = Color3.fromRGB(100, 200, 100)
GameConfig.CouleurSecondaire = Color3.fromRGB(100, 100, 100)
GameConfig.CouleurAccent     = Color3.fromRGB(255, 220, 50)

-- === AUDIO ===
GameConfig.SonCollecte = 0
GameConfig.SonRare     = 0
GameConfig.SonEvent    = 0
GameConfig.SonUpgrade  = 0

-- === BADGE ===
GameConfig.BadgePremierPrestige = 0

-- === PROGRESSION BASE ===
-- Lu par BaseProgressionSystem (Common) — ne pas modifier les clés
GameConfig.ProgressionConfig = {

    -- Structure des floors
    -- ATTENTION : Floor 1 a un double espace dans son nom Studio
    floors = {
        { index = 1, nom = "Floor  1", type = "Part",  spots = 10 },
        { index = 2, nom = "Floor 2",  type = "Model", spots = 10 },
        { index = 3, nom = "Floor 3",  type = "Model", spots = 10 },
        { index = 4, nom = "Floor 4",  type = "Model", spots = 10 },
    },

    -- Seuils de déblocage (coins TOTAUX gagnés, pas le solde actuel)
    -- { floor=X, spot=Y, coins=Z, label="texte affiché" }
    seuils = {
        -- Floor 1
        { floor=1, spot=1,  coins=0,      label="Départ"        },
        { floor=1, spot=2,  coins=0,      label="Départ"        },
        { floor=1, spot=3,  coins=50,     label="50 coins"      },
        { floor=1, spot=4,  coins=100,    label="100 coins"     },
        { floor=1, spot=5,  coins=200,    label="200 coins"     },
        { floor=1, spot=6,  coins=350,    label="350 coins"     },
        { floor=1, spot=7,  coins=500,    label="500 coins"     },
        { floor=1, spot=8,  coins=750,    label="750 coins"     },
        { floor=1, spot=9,  coins=1000,   label="1 000 coins"   },
        { floor=1, spot=10, coins=1500,   label="1 500 coins"   },
        -- Floor 2
        { floor=2, spot=1,  coins=2000,   label="Étage 2"       },
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
        { floor=3, spot=1,  coins=15000,  label="Étage 3"       },
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
        { floor=4, spot=1,  coins=80000,  label="Étage 4"       },
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

    -- true = progression basée sur les coins TOTAUX gagnés (jamais régressif)
    -- false = progression basée sur le solde actuel (peut régresser si coins dépensés)
    baseSurTotalGagne = true,
}

return GameConfig
