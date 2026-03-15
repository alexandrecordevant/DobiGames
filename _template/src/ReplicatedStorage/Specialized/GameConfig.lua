-- ReplicatedStorage/Modules/GameConfig.lua
-- ⚠️ SEUL FICHIER À MODIFIER PAR JEU

local GameConfig = {}

-- === IDENTITÉ DU JEU ===
GameConfig.NomDuJeu          = "GAME_NAME"
GameConfig.Theme             = "GAME_THEME"
GameConfig.CollectibleName   = "COLLECTIBLE_NAME"
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
GameConfig.CouleurPrimaire   = Color3.fromRGB(PRIMARY_R, PRIMARY_G, PRIMARY_B)
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
-- Lu par BaseProgressionSystem (Common) — obligatoire, ne pas supprimer les clés
-- Adapter les floors, spots et seuils à la structure Studio du jeu
GameConfig.ProgressionConfig = {

    -- Structure des floors Studio
    -- type = "Part" si Floor 1 est une BasePart, "Model" sinon
    floors = {
        { index = 1, nom = "Floor 1", type = "Part",  spots = 10 },
        { index = 2, nom = "Floor 2", type = "Model", spots = 10 },
        { index = 3, nom = "Floor 3", type = "Model", spots = 10 },
        { index = 4, nom = "Floor 4", type = "Model", spots = 10 },
    },

    -- Seuils de déblocage — { floor=X, spot=Y, coins=Z, label="texte" }
    -- coins = 0 → débloqué dès le départ
    seuils = {
        { floor=1, spot=1,  coins=0,      label="Départ"        },
        { floor=1, spot=2,  coins=0,      label="Départ"        },
        -- ... (à compléter selon la progression du jeu)
        { floor=2, spot=1,  coins=2000,   label="Étage 2"       },
        { floor=3, spot=1,  coins=15000,  label="Étage 3"       },
        { floor=4, spot=1,  coins=80000,  label="Étage 4"       },
        { floor=4, spot=10, coins=300000, label="300 000 coins" },
    },

    -- true = utilise totalCoinsGagnes (jamais régressif même si coins dépensés)
    -- false = utilise coins courants (peut régresser)
    baseSurTotalGagne = true,
}

return GameConfig
