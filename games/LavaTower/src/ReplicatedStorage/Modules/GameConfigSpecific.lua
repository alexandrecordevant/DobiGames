-- ReplicatedStorage/Modules/GameConfigSpecific.lua
-- Champs propres à LavaTower — ne pas mettre ici ce que shared-lib lit

local GameConfigSpecific = {}

-- === DEBUG ===
GameConfigSpecific.LOG_LEVEL = "WARN"

-- === IDENTITÉ DU JEU ===
GameConfigSpecific.NomDuJeu        = "LavaTower"
GameConfigSpecific.Theme           = "Lava"
GameConfigSpecific.CollectibleName = "Stone"
GameConfigSpecific.BaseNom         = "Base"

-- === IDs MONÉTISATION (remplir après création sur Roblox) ===
GameConfigSpecific.GamePassVIP            = { Id = 0, Prix = 149 }
GameConfigSpecific.GamePassOfflineVault   = { Id = 0, Prix = 199 }
GameConfigSpecific.GamePassAutoCollect    = { Id = 0, Prix = 299 }
GameConfigSpecific.ProduitLuckyHour       = { Id = 0, Prix = 35  }
GameConfigSpecific.ProduitSecretReveal    = { Id = 0, Prix = 25  }
GameConfigSpecific.ProduitSkipTier        = { Id = 0, Prix = 50  }

-- === DISCORD WEBHOOK (remplir après création Discord) ===
GameConfigSpecific.DiscordWebhookURL = ""

-- === ÉCONOMIE ===
GameConfigSpecific.BaseSpawnRate           = 3
GameConfigSpecific.BaseSpawnCount          = 1
GameConfigSpecific.OfflineIncomeMultiplier = 0.1
GameConfigSpecific.MaxOfflineHeures        = 8

-- === PROGRESSION ===
GameConfigSpecific.TotalTiers            = 10
GameConfigSpecific.CoutUpgradeBase       = 100
GameConfigSpecific.CoutUpgradeMultiplier = 2.5
GameConfigSpecific.PrestigeMultiplier    = 2.0

-- === EVENTS AUTOMATIQUES ===
GameConfigSpecific.EventIntervalleMinutes = 120
GameConfigSpecific.EventDureeMinutes      = 5
GameConfigSpecific.EventSpawnMultiplier   = 10
GameConfigSpecific.EarlyBirdBonusMinutes  = 60
GameConfigSpecific.AdminAbuseHebdo = {
    jourSemaine     = 6,
    heureUTC        = 20,
    dureeMinutes    = 45,
    spawnMultiplier = 50,
}

-- === COULEURS THÈME ===
GameConfigSpecific.CouleurPrimaire   = Color3.fromRGB(220, 80,  20)   -- orange lave
GameConfigSpecific.CouleurSecondaire = Color3.fromRGB(100, 100, 100)
GameConfigSpecific.CouleurAccent     = Color3.fromRGB(255, 200, 50)

-- === AUDIO ===
GameConfigSpecific.SonCollecte = 0
GameConfigSpecific.SonRare     = 0
GameConfigSpecific.SonEvent    = 0
GameConfigSpecific.SonUpgrade  = 0

-- === BADGE ===
GameConfigSpecific.BadgePremierPrestige = 0

-- === POIDS DES SOUS-NIVEAUX SECRET (plus le numero est eleve, plus c est rare) ===
-- Modifier ces valeurs pour ajuster les chances par niveau
GameConfigSpecific.SECRET_LEVEL_WEIGHTS = {
    [1] = 88.89,
    [2] = 10,
    [3] = 1,
    [4] = 0.1,
    [5] = 0.01,
}

-- === POIDS DES SOUS-NIVEAUX GOD ===
GameConfigSpecific.GOD_LEVEL_WEIGHTS = {
    [1] = 65,
    [2] = 35,
}

-- === PROGRESSION DES ZONES ===
GameConfigSpecific.ZoneUnlockSeuils  = { [1] = 0, [2] = 3, [3] = 6 }
GameConfigSpecific.ZonePrestigeSeuil = 1

-- === FUSE SYSTEM ===
GameConfigSpecific.Fuse = {
	MachineTag          = "FuseMachine",
	FuseBrainrotsFolder = game:GetService("ServerStorage"):FindFirstChild("FuseBrainrots"),
	MutationRoot        = game:GetService("ReplicatedStorage"):FindFirstChild("Mutation"),
	FuseDuration        = 5400,  -- 1h30 en secondes
	DataStoreName       = "LavaTowerV1",
	DataStoreKeyPrefix  = "fuse_",
	MutationCPS = { GOLD=2, DIAMANT=3, RAINBOW=10, TOXIC=5 },
	Tiers = {
		{ maxTotal = 1000                },
		{ maxTotal = 100000              },
		{ maxTotal = 1000000             },
		{ maxTotal = 1000000000          },
		{ maxTotal = 1000000000000       },
		{ maxTotal = 1000000000000000    },
		{ maxTotal = 1e18                },
		{ maxTotal = math.huge           },
	},
	Weights = {
		{ folder = "50", weight = 50 },
		{ folder = "30", weight = 30 },
		{ folder = "18", weight = 18 },
		{ folder = "2",  weight = 2  },
	},
}

-- === SHOP MONETISATION ===
GameConfigSpecific.Shop = {

    PackDemarrage = {
        Prix            = 99,
        Cash            = 1000000,
        BrainrotsFolder = "ReplicatedStorage.Pack",
    },

    PackVIP = {
        Prix                = 799,
        Cash                = 10000000,
        LuckDureeSecondes   = 900,   -- 15 minutes de luck x2 au join
    },

    Cash = {
        { label = "Petit Sac", multiplicateur = 1800,  duree = "30 min", prix = 99,  minCash = 1000000,  image = "rbxassetid://113671815348394" },
        { label = "Gros Sac",  multiplicateur = 7200,  duree = "2 h",    prix = 299, minCash = 4003200,  image = "rbxassetid://122722381530421" },
        { label = "Coffre",    multiplicateur = 36000, duree = "10 h",   prix = 799, minCash = 20016000, image = "rbxassetid://88226292288257"  },
    },

    LuckyBlocks = {
        {
            nom    = "Mythic",
            prix   = 49,
            image  = "rbxassetid://115883899717307",
            folder = "ReplicatedStorage.LuckyBlocks.Tier_1",
            weights = {
                { chance = 49.5, label = "50"  },
                { chance = 30,   label = "30"  },
                { chance = 18,   label = "18"  },
                { chance = 2,    label = "2"   },
                { chance = 0.5,  label = "0.5" },
            },
        },
        {
            nom    = "Brainrot God",
            prix   = 149,
            image  = "rbxassetid://109291267681539",
            folder = "ReplicatedStorage.LuckyBlocks.Tier_2",
            weights = {
                { chance = 49.5, label = "50"  },
                { chance = 30,   label = "30"  },
                { chance = 18,   label = "18"  },
                { chance = 2,    label = "2"   },
                { chance = 0.5,  label = "0.5" },
            },
        },
        {
            nom    = "Secret",
            prix   = 399,
            image  = "rbxassetid://82792065995734",
            folder = "ReplicatedStorage.LuckyBlocks.Tier_3",
            weights = {
                { chance = 49.5, label = "50"  },
                { chance = 30,   label = "30"  },
                { chance = 18,   label = "18"  },
                { chance = 2,    label = "2"   },
                { chance = 0.5,  label = "0.5" },
            },
        },
    },

    Luck = {
        Paliers = { 2, 4, 8, 10, 15, 20, 25, 30 },
        Duree   = 900,
        Prix    = { 49, 99, 149, 199, 299, 399, 499, 799 },
    },
}

return GameConfigSpecific
