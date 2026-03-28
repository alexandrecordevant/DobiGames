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

-- === GAME PASS IDs (table structurée — remplir après création sur Roblox) ===
GameConfig.GamePassIds = {
    VIP          = 0,   -- Accès VIP (features premium)
    Tracteur     = 0,   -- Tracteur auto-collect
    AutoCollect  = 0,   -- Auto-collecte dans le champ
    Protection   = 0,   -- Protection offline (pas de perte)
    OfflineVault = 0,   -- Revenus offline x1 (vault)
    ArroseurMAX  = 0,   -- Arroseur niveau MAX (×5 spawn rate)
    SpeedMAX     = 0,   -- Speed niveau MAX (walkspeed 36)
    CarryMAX     = 0,   -- Carry niveau MAX (5 BR)
    FlowerPot4   = 0,   -- Débloquer FlowerPot 4 (149 R$)
}

-- === DEV PRODUCT IDs (table structurée — remplir après création sur Roblox) ===
GameConfig.DevProductIds = {
    LuckyHour     = 0,  -- 30 min × 5 income  (35 R$)
    SkipSeedTimer = 0,  -- Skip timer daily seed (25 R$)
    SeedPackx3    = 0,  -- +3 graines MYTHIC   (99 R$)
    SecretSeed    = 0,  -- +1 graine SECRET    (149 R$)
}

-- === DISCORD WEBHOOK ===
-- Remplir depuis discord_webhooks.json après setup_discord.py
GameConfig.DiscordWebhooks = {
    events  = "",  -- #events  : Admin Abuse hebdo, Top Farmer
    records = "",  -- #records : BRAINROT_GOD, SECRET capturés
    dev     = "",  -- #dev-logs : erreurs critiques (invisible des joueurs)
    revenue = "",  -- #revenue-tracking : (usage futur)
}
GameConfig.DiscordInvite = "https://discord.gg/JfPHVBpQXS"

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
-- Types d'events aléatoires déclenchés par EventManager.
-- Modifier cette liste pour ajouter/retirer des events selon le jeu.
GameConfig.EventTypes = {
    "NightMode", "MeteorDrop", "Rain", "Golden", "LuckyHour", "DoubleCoins",
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

-- === ANIMATION CONFIG ===
-- Durées et offsets lus par BrainRotSpawner, ChampCommunSpawner, DropSystem
GameConfig.AnimationConfig = {
    brSpawnDuree     = 2.0,  -- durée animation pousse de terre (s)
    brSpawnOffsetY   = -3,   -- départ sous la surface (studs négatifs)
    brDepotDuree     = 0.3,  -- durée fade-in mini modèle sur spot (s)
    timerHauteurY    = 8,    -- hauteur dédiée part compteur ChampCommun (studs)
    timerStudsOffset = 5,    -- StudsOffset Y du BillboardGui compteur (studs)
}

-- === SPRINKLER ===
-- Vitesse de rotation (°/s) par niveau d'upgrade Arroseur
-- Niveau 0 = désactivé (aucun upgrade acheté)
GameConfig.SprinklerVitesses = {
    [0] = 0,    -- désactivé (pas d'upgrade)
    [1] = 30,   -- Arroseur Niv.1 — rotation lente
    [2] = 60,   -- Arroseur Niv.2 — rotation normale
    [3] = 120,  -- Arroseur MAX   — rotation rapide
}

-- === TRACTEUR ===
-- Vitesse de déplacement du tracteur dans le champ (studs/seconde)
GameConfig.TracteurVitesse    = 12
-- Espacement entre les lignes de labourage (studs)
GameConfig.TracteurEspacement = 8

-- === LEADERBOARDS 3D ===
-- Panneaux Studio dans Workspace.Leaderboards — chaque panneau doit contenir Gui.Texto
GameConfig.Leaderboards = {
    -- Panneaux affichant le classement joueurs (alternent chaque cycle)
    classement = { "Leaderboard1", "Leaderboard3" },

    -- Panneaux affichant les infos serveur en direct (alternent chaque cycle)
    infos      = { "Leaderboard2", "Leaderboard4" },

    -- Durée (s) de chaque phase dans la boucle 3D
    updateClassement = 5,
    updateInfos      = 5,

    -- Noms des points de spawn du ChampCommun (index → lettre)
    PointsNoms = { "A", "B", "C" },

    -- Horaire Admin Abuse affiché dans les panneaux infos
    -- nil → lire GameConfig.AdminAbuseHebdo automatiquement
    AdminAbuseHoraire = nil,
}

-- (ancienne clé conservée pour compatibilité)
GameConfig.LeaderboardPosition = Vector3.new(0, 15, 0)

-- === SHOP UPGRADES ===
-- Lu par ShopSystem (Common) — seul fichier à modifier pour changer le shop
GameConfig.ShopUpgrades = {

    -- ═══ PAYABLES EN COINS ═══

    Arroseur = {
        nom         = "Sprinkler",
        icone       = "💧",
        description = "Speeds up Brain Rot spawns in your field",
        ordre       = 1,
        niveaux = {
            [1] = { type="coins", prix=500,   label="Lv.1",    effet={ spawnRateMultiplier=1.6 } },
            [2] = { type="coins", prix=2000,  label="Lv.2",    effet={ spawnRateMultiplier=2.7 } },
            [3] = { type="robux", prix=149,   gamePassId=0,    label="MAX 🔥", effet={ spawnRateMultiplier=5.0 }, isMax=true },
        },
        maxNiveau        = 3,
        dataField        = "upgradeArroseur",
        iconeLeaderboard = true,
    },

    Speed = {
        nom         = "Speed",
        icone       = "⚡",
        description = "Increases your movement speed",
        ordre       = 2,
        niveaux = {
            [1] = { type="coins", prix=300,  label="Lv.1",   effet={ walkSpeed=22 } },
            [2] = { type="coins", prix=1000, label="Lv.2",   effet={ walkSpeed=28 } },
            [3] = { type="robux", prix=99,   gamePassId=0,   label="MAX 🔥", effet={ walkSpeed=36 }, isMax=true },
        },
        maxNiveau        = 3,
        dataField        = "upgradeSpeed",
        iconeLeaderboard = true,
    },

    Carry = {
        nom         = "Carry+",
        icone       = "🎒",
        description = "Increases your Brain Rot carry capacity",
        ordre       = 3,
        niveaux = {
            [1] = { type="coins", prix=500,  label="Lv.1",   effet={ carryCapacite=2 } },
            [2] = { type="coins", prix=2000, label="Lv.2",   effet={ carryCapacite=3 } },
            [3] = { type="robux", prix=149,  gamePassId=0,   label="MAX 🔥", effet={ carryCapacite=5 }, isMax=true },
        },
        maxNiveau        = 3,
        dataField        = "upgradeCarry",
        iconeLeaderboard = true,
    },

    Aimant = {
        nom         = "Magnet",
        icone       = "🧲",
        description = "Increases Brain Rot collection radius",
        ordre       = 4,
        niveaux = {
            [1] = { type="coins", prix=800,  label="Lv.1",   effet={ rayonCollecte=8  } },
            [2] = { type="coins", prix=3000, label="Lv.2",   effet={ rayonCollecte=14 }, isMax=true },
        },
        maxNiveau        = 2,
        dataField        = "upgradeAimant",
        iconeLeaderboard = true,
    },

    -- ═══ PAYABLES EN R$ UNIQUEMENT ═══

    Tracteur = {
        nom         = "Tractor",
        icone       = "🚜",
        description = "Automatically collects BRs based on your rarity threshold",
        ordre       = 5,
        niveaux = {
            [1] = { type="robux", prix=299, gamePassId=0, label="Activate", effet={ tracteurActif=true }, isMax=true },
        },
        -- Seuils disponibles — le joueur choisit dans le Shop (RARE+ gratuit par défaut)
        seuilsDisponibles = {
            { label = "RARE+",      rareteMin = "RARE",      prix = 0    },  -- défaut, gratuit
            { label = "EPIC+",      rareteMin = "EPIC",      prix = 500  },  -- coût coins
            { label = "LEGENDARY+", rareteMin = "LEGENDARY", prix = 2000 },  -- coût coins
        },
        maxNiveau        = 1,
        isGamePass       = true,
        dataField        = "hasTracteur",
        iconeLeaderboard = true,
    },

    LuckyCharm = {
        nom         = "Lucky Charm",
        icone       = "🍀",
        description = "+25% chance to get a higher rarity",
        ordre       = 6,
        niveaux = {
            [1] = { type="robux", prix=99, gamePassId=0, label="Activate", effet={ luckyBonus=1.25 }, isMax=true },
        },
        maxNiveau        = 1,
        isGamePass       = true,
        dataField        = "hasLuckyCharm",
        iconeLeaderboard = false,
    },
}

-- Valeurs par défaut (utilisées par ShopSystem pour réinitialisation / defaults)
GameConfig.WalkSpeedDefaut       = 16
GameConfig.CarryCapaciteDefaut   = 1
GameConfig.RayonCollecteDefaut   = 4

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

-- === EVENTS VISUELS ===
GameConfig.EventsVisuels = {

    NightMode = {
        duree          = 45,
        brightnessMin  = 0,
        ambientNuit    = Color3.fromRGB(0, 0, 20),
        ambientJour    = Color3.fromRGB(70, 70, 70),
        brightnessJour = 2,
        fogEndNuit     = 200,
        message        = "🌙 NIGHT MODE! Brain Rots glow in the dark!",
        messageFin     = "☀️ Day breaks... until the next event!",
    },

    MeteorDrop = {
        duree           = 60,
        nbMeteores      = 5,
        hauteurSpawn    = 200,
        vitesseTombee   = 80,
        rayonImpact     = 15,
        intervalleSpawn = 12,
        raretesMeteore  = { "LEGENDARY", "MYTHIC", "SECRET" },
        message         = "☄️ METEOR DROP! Meteors are crashing into the Common Field!",
        messageImpact   = "💥 Impact! A rare Brain Rot has appeared!",
        messageFin      = "☄️ The meteors have stopped falling.",
    },

    Rain = {
        duree           = 90,
        hauteurNuages   = 35,
        tailleNuage     = Vector3.new(20, 5, 20),
        spawnMultiplier = 3,
        particleRate    = 50,
        message         = "🌧️ RAIN EVENT! Rain boosts the Common Field ×3!",
        messageFin      = "☀️ The rain stops... the field stays fertilized!",
    },

    Golden = {
        duree          = 60,
        multiplicateur = 5,
        couleurGolden  = Color3.fromRGB(255, 215, 0),
        ambientGolden  = Color3.fromRGB(255, 200, 50),
        message        = "✨ GOLDEN EVENT! All earnings ×5 for 60s!",
        messageFin     = "✨ The Golden Event is over. See you soon!",
    },
}

-- Positions spawn points ChampCommun (utilisées par Rain + MeteorDrop)
GameConfig.ChampCommunPoints = {
    { x = 190.92, y = 16.189, z =   66.30 },
    { x = 250.93, y = 16.189, z =  -80.20 },
    { x = 189.51, y = 16.189, z = -241.28 },
}

-- === PROGRESSION BASE ===
-- Lu par BaseProgressionSystem (Common) — ne pas modifier les clés
GameConfig.ProgressionConfig = {

    -- Structure des floors
    floors = {
        { index = 1, nom = "Floor_1", type = "Part",  spots = 10 },
        { index = 2, nom = "Floor_2", type = "Model", spots = 10 },
        { index = 3, nom = "Floor_3", type = "Model", spots = 10 },
        { index = 4, nom = "Floor_4", type = "Model", spots = 10 },
    },

    -- Seuils de déblocage (coins TOTAUX gagnés, pas le solde actuel)
    -- { floor=X, spot=Y, coins=Z, label="texte affiché" }
    seuils = {
        -- Floor 1
        { floor=1, spot=1,  coins=0,      label="Start"        },
        { floor=1, spot=2,  coins=0,      label="Start"        },
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

    -- true = progression basée sur les coins TOTAUX gagnés (jamais régressif)
    -- false = progression basée sur le solde actuel (peut régresser si coins dépensés)
    baseSurTotalGagne = true,
}

-- === FLOWER POT SYSTEM ===
-- Lu par FlowerPotSystem (Common) — pots MYTHIC/SECRET + BR Mutant + Daily Seed
GameConfig.FlowerPotConfig = {

    -- Déblocage des pots
    pots = {
        [1] = { nom = "FlowerPot_1", prixCoins = 0,     prixRobux = 0,
                debloque = true  },
        [2] = { nom = "FlowerPot_2", prixCoins = 5000,  prixRobux = 0,
                debloque = false },
        [3] = { nom = "FlowerPot_3", prixCoins = 25000, prixRobux = 0,
                debloque = false },
        [4] = { nom = "FlowerPot_4", prixCoins = 0,     prixRobux = 149,
                debloque = false, gamePassId = 0 },
    },

    -- BR plantables (uniquement MYTHIC et SECRET)
    brPlantables = { "MYTHIC", "SECRET" },

    -- Config par rareté plantée
    graines = {
        MYTHIC = {
            dureeStages    = { 225, 225, 225, 225 },  -- réel : 15 min total
            dureeTest      = { 30,  30,  30,  30  },  -- test : 2 min total
            multiplicateur = 3,
            couleurStage4  = Color3.fromRGB(180, 0, 255),
            label          = "MYTHIC Mutant",
        },
        SECRET = {
            dureeStages    = { 450, 450, 450, 450 },  -- réel : 30 min total
            dureeTest      = { 60,  60,  60,  60  },  -- test : 4 min total
            multiplicateur = 8,
            couleurStage4  = Color3.fromRGB(255, 50, 50),
            label          = "SECRET Mutant",
        },
    },

    -- Croissance instantanée (R$)
    instantGrow = {
        prixRobux  = 35,
        gamePassId = 0,
        label      = "⚡ Instant Grow",
    },

    -- Échelle visuelle par stage
    stageScales = {
        [0] = 0.0,
        [1] = 0.3,
        [2] = 0.6,
        [3] = 0.9,
        [4] = 1.4,
    },

    -- Graine quotidienne (cycle 7 jours)
    dailySeed = {
        intervalleHeures = 24,
        cycle = {
            [1] = "MYTHIC",
            [2] = "MYTHIC",
            [3] = "SECRET",
            [4] = "MYTHIC",
            [5] = "MYTHIC",
            [6] = "SECRET",
            [7] = "SECRET",
        },
        skipPrixRobux    = 25,
        packPrixRobux    = 99,
        premiumPrixRobux = 149,
        gamePassIds = {
            skip    = 0,
            pack    = 0,
            premium = 0,
        },
    },

    -- Arbres du ChampCommun (Tree 1 et Tree 2)
    arbresConfig = {
        {
            nom       = "Tree 1",   -- espace, pas underscore (nom Studio)
            sommetPos = Vector3.new(227.512, 67.588, 6.610),
        },
        {
            nom       = "Tree 2",
            sommetPos = Vector3.new(227.512, 67.588, -163.389),
        },
    },

    -- Config des drops de graines sur les arbres
    arbresDropConfig = {
        intervalleSecondes = 1800,  -- 30 min entre chaque graine
        chanceMYTHIC       = 70,    -- 70% MYTHIC
        chanceSECRET       = 30,    -- 30% SECRET
        timeoutSecondes    = 300,   -- 5 min avant reset si non collectée
    },

    -- Couleur dorée appliquée au spot quand un Mutant y est déposé
    spotMutantCouleur = Color3.fromRGB(255, 215, 0),

    -- Texte permanent sur pot vide
    labelPotVide    = "🌱 Plant MYTHIC / SECRET here",
    labelPotLocked2 = "🔒 5 000 💰",
    labelPotLocked3 = "🔒 25 000 💰",
    labelPotLocked4 = "🔒 149 R$",

    -- Visuels plante par rarete
    plantVisuels = {
        MYTHIC = {
            couleurTige    = Color3.fromRGB(100, 0, 200),
            couleurFeuille = Color3.fromRGB(130, 0, 255),
            couleurFleur   = Color3.fromRGB(180, 0, 255),
            effetSpecial   = "sparkles",
        },
        SECRET = {
            couleurTige    = Color3.fromRGB(180, 0, 0),
            couleurFeuille = Color3.fromRGB(200, 50, 0),
            couleurFleur   = Color3.fromRGB(255, 80, 0),
            effetSpecial   = "flames",
        },
    },
}

-- === REBIRTH ===
GameConfig.RebirthConfig = {
    [1] = { coinsRequis=300000,  brainRotRequis={rarete="LEGENDARY",    quantite=1}, multiplicateur=1.5, slotsBonus=2  },
    [2] = { coinsRequis=500000,  brainRotRequis={rarete="MYTHIC",       quantite=1}, multiplicateur=2.0, slotsBonus=4  },
    [3] = { coinsRequis=1000000, brainRotRequis={rarete="SECRET",       quantite=1}, multiplicateur=3.0, slotsBonus=6  },
    [4] = { coinsRequis=2000000, brainRotRequis={rarete="BRAINROT_GOD", quantite=1}, multiplicateur=5.0, slotsBonus=10 },
}

-- Réduction prix progression par rebirth (-15% cumulatif, cap -90%)
-- Utilisé par BaseProgressionSystem pour alléger les seuils de déblocage
GameConfig.RebirthFloorDiscount = 0.15

-- Prix de référence pour déblocage manuel des floors (Rebirth 0)
-- Utilisé par BaseProgressionSystem.GetFloorUnlockCost()
GameConfig.FloorUnlockCosts = {
    [2] = 100000,
    [3] = 200000,
    [4] = 300000,
}

-- === CAPTURE CONFIG ===
GameConfig.CaptureConfig = {
    COMMON       = { mode="prompt", holdDuration=0   },
    OG           = { mode="prompt", holdDuration=0   },
    RARE         = { mode="prompt", holdDuration=0   },
    EPIC         = { mode="prompt", holdDuration=0.5 },
    LEGENDARY    = { mode="prompt",  holdDuration=1.5 },
    MYTHIC       = { mode="prompt",  holdDuration=3.0 },
    SECRET       = { mode="prompt",  holdDuration=5.0 },
    BRAINROT_GOD = { mode="prompt",  holdDuration=8.0 },
}

-- === CARRY ===
GameConfig.CarryNiveaux = {
    [0] = 1,
    [1] = 5,
    [2] = 8,
    [3] = 15,
}

GameConfig.CarryPrices = {
    [1] = 1000,
    [2] = 5000,
    [3] = 0,
}

-- === VALEUR PAR RARETÉ ===
GameConfig.ValeurParRarete = {
    COMMON       = 1,
    OG           = 3,
    RARE         = 8,
    EPIC         = 20,
    LEGENDARY    = 60,
    MYTHIC       = 200,
    SECRET       = 500,
    BRAINROT_GOD = 2000,
}

-- === INCOME PAR RARETÉ ===
GameConfig.IncomeParRarete = {
    COMMON       = 1,
    OG           = 3,
    RARE         = 8,
    EPIC         = 20,
    LEGENDARY    = 60,
    MYTHIC       = 200,
    SECRET       = 500,
    BRAINROT_GOD = 2000,
}

-- === MAX BASES ===
GameConfig.MaxBases = 6

-- === ITEMS À SPAWNER ===
GameConfig.SpawnableItems = {
    dossier = "Brainrots",
    rarites = {
        { nom="COMMON",       poids=55,  valeur=1    },
        { nom="OG",           poids=22,  valeur=3    },
        { nom="RARE",         poids=13,  valeur=8    },
        { nom="EPIC",         poids=7,   valeur=20   },
        { nom="LEGENDARY",    poids=2.8, valeur=60   },
        { nom="BRAINROT_GOD", poids=0.2, valeur=2000 },
    },
    raretesCommunOnly = { "MYTHIC", "SECRET" },
}

-- === ZONE COMMUNE ===
GameConfig.CommunPoints = {
    { x=190.92, y=16.189, z=66.30   },
    { x=250.93, y=16.189, z=-80.20  },
    { x=189.51, y=16.189, z=-241.28 },
}

-- === SPAWN CONFIG ===
GameConfig.SpawnZoneNom = "SpawnZone"

GameConfig.SpawnConfig = {
    intervalleSecondes = 4,
    maxParBase         = 15,
    despawnSecondes    = 30,
}

-- === BOARD CONFIG ===
-- Textes et comportements des boards cliquables devant chaque base
GameConfig.BoardConfig = {
    texteDefaut   = "🔄 REBIRTH\nClick to view",
    distanceClick = 20,
}

-- === PLANT MODELS PATH ===
-- Dossier dans ServerStorage contenant Graine (Part+SpecialMesh) et Tree (Model)
GameConfig.PlantModelsPath = "PlantModels"

-- === RARETÉS EXCLUES DU SPAWN NORMAL ===
-- Ces raretés ne spawneront jamais via SpawnManager ni CommunSpawner
GameConfig.RaretesExcluesSpawn = {
    "OG",  -- jamais en spawn normal
}

return GameConfig
