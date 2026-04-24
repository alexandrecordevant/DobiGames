-- ReplicatedStorage/Modules/GameConfig.lua
-- ⚠️ SEUL FICHIER À MODIFIER PAR JEU

local GameConfig = {}

-- === DEBUG ===
GameConfig.LOG_LEVEL = "WARN"

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
    SpeedMAX     = 0,   -- Speed niveau MAX (walkspeed 40)
    CarryMAX     = 0,   -- Carry niveau MAX (5 BR)
    FlowerPot4   = 0,   -- Débloquer FlowerPot 4 (149 R$)
    SeedDoubler  = 0,   -- Seed Doubler : 2 graines quotidiennes au lieu de 1 (à remplir après création Roblox)
}

-- Alias direct lu par ClaimDailySeed (synchronisé avec GamePassIds.SeedDoubler)
GameConfig.SeedDoublerPassId = GameConfig.GamePassIds.SeedDoubler

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
GameConfig.EventIntervalleMinutes = 0.1 --120
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
GameConfig.EventTypes = {"NightMode", "MeteorDrop", "Rain", "Golden", "LuckyHour"}

-- === RARETÉS ===
GameConfig.Raretes = {
    { nom = "Common",    chance = 60,  valeur = 1,   couleur = Color3.fromRGB(200, 200, 200) },
    { nom = "Uncommon",  chance = 25,  valeur = 3,   couleur = Color3.fromRGB(100, 200, 100) },
    { nom = "Rare",      chance = 10,  valeur = 10,  couleur = Color3.fromRGB(100, 100, 255) },
    { nom = "Epic",      chance = 4,   valeur = 30,  couleur = Color3.fromRGB(180, 50,  255) },
    { nom = "Legendary", chance = 0.9,  valeur = 100,  couleur = Color3.fromRGB(255, 200, 0  ) },
    { nom = "Mythic",    chance = 0.3,  valeur = 250,  couleur = Color3.fromRGB(255, 20,  180) },
    { nom = "Secret",    chance = 0.1,  valeur = 500,  couleur = Color3.fromRGB(255, 50,  50 ) },
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

-- === TRACTEUR — Lucky Spawn passif ===
-- À chaque spawn dans le champ d'un joueur possédant le Game Pass Tracteur,
-- un roll bonus indépendant est effectué pour faire apparaître un MYTHIC/SECRET supplémentaire.
-- 94% → rien | 4% → MYTHIC | 1% → SECRET | 1% → MYTHIC + SECRET (jackpot)
GameConfig.TracteurConfig = {
    MYTHIC_CHANCE  = 4,   -- % : spawn un MYTHIC bonus dans le champ
    SECRET_CHANCE  = 1,   -- % : spawn un SECRET bonus dans le champ
    JACKPOT_CHANCE = 1,   -- % : spawn MYTHIC + SECRET simultanément (jackpot)
    -- Le reste (94 %) ne déclenche rien de bonus
}

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
            [1] = { type="coins", prix=1500,  label="Lv.1",    effet={ spawnRateMultiplier=1.6 } },
            [2] = { type="coins", prix=6000,  label="Lv.2",    effet={ spawnRateMultiplier=2.7 } },
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
            [1]  = { type="coins", prix=500,        label="Lv.1",  effet={ walkSpeed=18 } },
            [2]  = { type="coins", prix=1500,        label="Lv.2",  effet={ walkSpeed=19 } },
            [3]  = { type="coins", prix=4000,        label="Lv.3",  effet={ walkSpeed=20 } },
            [4]  = { type="coins", prix=10000,       label="Lv.4",  effet={ walkSpeed=21 } },
            [5]  = { type="coins", prix=25000,       label="Lv.5",  effet={ walkSpeed=22 } },
            [6]  = { type="coins", prix=60000,       label="Lv.6",  effet={ walkSpeed=23 } },
            [7]  = { type="coins", prix=150000,      label="Lv.7",  effet={ walkSpeed=24 } },
            [8]  = { type="coins", prix=400000,      label="Lv.8",  effet={ walkSpeed=26 } },
            [9]  = { type="coins", prix=1000000,     label="Lv.9",  effet={ walkSpeed=28 } },
            [10] = { type="coins", prix=2500000,     label="Lv.10", effet={ walkSpeed=30 } },
            [11] = { type="coins", prix=6000000,     label="Lv.11", effet={ walkSpeed=32 } },
            [12] = { type="coins", prix=15000000,    label="Lv.12", effet={ walkSpeed=33 } },
            [13] = { type="coins", prix=40000000,    label="Lv.13", effet={ walkSpeed=34 } },
            [14] = { type="coins", prix=100000000,   label="Lv.14", effet={ walkSpeed=35 } },
            [15] = { type="robux", prix=99, gamePassId=0, label="MAX 🔥", effet={ walkSpeed=40 }, isMax=true },
        },
        maxNiveau        = 15,
        dataField        = "upgradeSpeed",
        iconeLeaderboard = true,
    },

    Carry = {
        nom         = "Carry+",
        icone       = "🎒",
        description = "Increases your Brain Rot carry capacity",
        ordre       = 3,
        niveaux = {
            [1] = { type="coins", prix=1000,  label="Lv.1",   effet={ carryCapacite=3 } },
            [2] = { type="coins", prix=5000,  label="Lv.2",   effet={ carryCapacite=5 } },
            [3] = { type="robux", prix=149,   gamePassId=0,   label="MAX 🔥", effet={ carryCapacite=8 }, isMax=true },
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
            [1] = { type="coins", prix=2000,  label="Lv.1",   effet={ rayonCollecte=8  } },
            [2] = { type="coins", prix=8000,  label="Lv.2",   effet={ rayonCollecte=14 }, isMax=true },
        },
        maxNiveau        = 2,
        dataField        = "upgradeAimant",
        iconeLeaderboard = true,
    },

    -- ═══ PAYABLES EN R$ UNIQUEMENT ═══

    Tracteur = {
        nom         = "Tractor",
        icone       = "🚜",
        description = "Each spawn in your field: 4% MYTHIC bonus, 1% SECRET bonus, 1% jackpot (both)!",
        ordre       = 5,
        niveaux = {
            [1] = { type="robux", prix=299, gamePassId=0, label="Activate", effet={ tracteurActif=true }, isMax=true },
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
        duree                = 90,
        -- Lighting nuit
        brightnessMin        = 0.3,
        clockTimeNuit        = 0,    -- 0 = minuit, 14 = 14h00
        ambientNuit          = Color3.fromRGB(40, 40, 80),
        outdoorAmbientNuit   = Color3.fromRGB(20, 20, 60),
        fogEndNuit           = 500,
        fogColorNuit         = Color3.fromRGB(20, 20, 50),
        envDiffuseNuit       = 0.2,
        envSpecNuit          = 0.2,
        -- Ciel étoilé (0–3000)
        starCount            = 3000,
        -- Son ambiant nuit : remplir après import dans Studio
        -- Exemples gratuits Roblox : 507846804 (vent), 1843643716 (nuit)
        soundIdNuit          = 1843643716,
        -- Messages
        message              = "🌙 NIGHT MODE! Brain Rots glow in the dark!",
        messageFin           = "☀️ Day breaks... until the next event!",
    },

    MeteorDrop = {
        duree           = 60,
        nbMeteores      = 5,
        hauteurSpawn    = 400,
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
        nbNuages        = 6,   -- nuages répartis aléatoirement dans la ChampCommunZone
        hauteurNuages   = 18,
        tailleNuage     = Vector3.new(20, 5, 20),
        spawnMultiplier = 3,
        particleRate    = 50,
        message         = "🌧️ RAIN EVENT! Rain boosts the Common Field ×3!",
        messageFin      = "☀️ The rain stops... the field stays fertilized!",
        -- Système météo (RainWeatherSystem)
        brightnessRain       = 0.65,
        fogEndRain           = 1400,
        fogColorRain         = Color3.fromRGB(160, 170, 185),
        ambientRain          = Color3.fromRGB(110, 115, 130),
        atmosphereDensity    = 0.25,
        atmosphereOffset     = 0.1,
        atmosphereColor      = Color3.fromRGB(160, 170, 185),
        atmosphereDecay      = Color3.fromRGB(130, 140, 155),
        atmosphereHaze       = 1.0,
        cloudsDensity        = 0.8,
        cloudsCover          = 0.95,
        cloudsColor          = Color3.fromRGB(120, 130, 140),
        lightningInterval    = { min = 15, max = 45 },
        soundIdRain          = 0,   -- remplir après import son pluie dans Studio
        wetGroundReflectance = 0.75,
        wetGroundColor       = Color3.fromRGB(85, 90, 100),
        hauteurRain          = 15,  -- studs au-dessus du sol
        pluieTouteMap        = true, -- true = couvre toute la Baseplate, false = ChampCommunZone uniquement
        rainGridCols         = 8,   -- colonnes (axe X)
        rainGridRows         = 6,   -- rangées  (axe Z) → 8×6 = 48 tuiles
    },

    Golden = {
        duree          = 60,
        multiplicateur = 5,
        couleurGolden  = Color3.fromRGB(255, 215, 0),
        ambientGolden  = Color3.fromRGB(255, 200, 50),
        message        = "✨ GOLDEN EVENT! All earnings ×5 for 60s!",
        messageFin     = "✨ The Golden Event is over. See you soon!",
    },

    LuckyHour = {
        duree           = 60,
        rarityPool      = { RARE = 60, EPIC = 35, LEGENDARY = 5 },
        spawnInterval   = 10,
        couleurAmbiance = Color3.fromRGB(255, 180, 220),
        message         = "⭐ LUCKY HOUR! Rare BRs are spawning on your base!",
        messageFin      = "⭐ Lucky Hour is over.",
    },
}

-- Positions spawn points ChampCommun
GameConfig.ChampCommunPoints = {
    { x = 190.92, y = 2, z =   66.30 },
    { x = 250.93, y = 2, z =  -80.20 },
    { x = 189.51, y = 2, z = -241.28 },
}

-- Zone couverte par le ChampCommun entre les 4 leaderboards
GameConfig.ChampCommunZone = {
    xMin = 150,
    xMax = 300,
    zMin = -350.5,
    zMax =  177.13,
    y    = 2,
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
        { floor=1, spot=3,  coins=0,      label="Start"         },
        { floor=1, spot=4,  coins=0,      label="Start"         },
        { floor=1, spot=5,  coins=0,      label="Start"         },
        { floor=1, spot=6,  coins=0,      label="Start"         },
        { floor=1, spot=7,  coins=0,      label="Start"         },
        { floor=1, spot=8,  coins=0,      label="Start"         },
        { floor=1, spot=9,  coins=0,      label="Start"         },
        { floor=1, spot=10, coins=0,      label="Start"         },
        -- Floor 2 — déblocage via Rebirth uniquement (coins=9999999999 = jamais auto)
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
        -- Floor 3
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
        -- Floor 4
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

    -- Offset Y du BR Mutant au-dessus de la surface du pot (studs)
    -- Augmenter si le BR est encore à l'intérieur de la plante
    MutantOffsetY = 7,

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
        intervalleSecondes = 60,  -- 30 min entre chaque graine
        --intervalleSecondes = 1800,  -- 30 min entre chaque graine
        chanceMYTHIC       = 70,    -- 70% MYTHIC
        chanceSECRET       = 30,    -- 30% SECRET
        timeoutSecondes    = 30,   -- 5 min avant reset si non collectée
        --timeoutSecondes    = 300,   -- 5 min avant reset si non collectée
    },

    -- Couleur dorée appliquée au spot quand un Mutant y est déposé
    spotMutantCouleur   = Color3.fromRGB(255, 215, 0),
    -- Couleur de restauration du spot après retrait d'un Mutant (fallback si couleur originale inconnue)
    spotDefaultCouleur  = Color3.fromRGB(106, 127, 63),

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

    -- ─── FlowerPotGrowthSystem (nouveau système visuel) ───
    -- Lu par FlowerPotGrowthSystem.lua — assets Plant_Stage0-3 + GenericSeed

    -- Durée en secondes par stage (2 min × 4 stages = 8 min total)
    GrowthDuration   = 120,
    -- Stage à partir duquel le BR Mutant apparaît au-dessus du pot
    MutantSpawnStage = 2,
    -- Offset Y (studs) du BR Mutant au-dessus de la plante
    MutantOffsetY    = 3,

    -- Types de Mutants disponibles (remplace les anciens éléments eau/feu/terre/vent)
    -- Lus par MutantGenerator, FlowerPotGrowthSystem et les filtres BRFilterSystem
    MutantTypes = { "GALAXY", "TOXIC", "RAINBOW", "VOID" },

    -- Multiplicateurs de revenu par type Mutant (income = ValeurParRarete[rarity] × multiplier)
    MutantMultipliers = {
        GALAXY  = 2,
        TOXIC   = 4,
        RAINBOW = 6,
        VOID    = 8,
    },

    -- Correspondance type Mutant → nom de filtre FilterManager
    MutantFiltres = {
        GALAXY  = "MutantGALAXY",
        TOXIC   = "MutantTOXIC",
        RAINBOW = "MutantRAINBOW",
        VOID    = "MutantVOID",
    },

    -- Emojis par type Mutant (affichage billboard et notifications)
    MutantEmojis = {
        GALAXY  = "🌌",
        TOXIC   = "☠️",
        RAINBOW = "🌈",
        VOID    = "🕳️",
    },
}

-- === TYPES MUTANTS ===
-- Source de vérité canonique pour tous les systèmes (MutantGenerator, FlowerPotGrowthSystem, filtres)
-- Multiplier = facteur appliqué sur IncomeParRarete lors de la récolte d'un BR Mutant
GameConfig.MutantTypes = {
    {
        Name           = "GALAXY",
        Multiplier     = 2,
        Color          = Color3.fromRGB(88,  24,  169),
        SecondaryColor = Color3.fromRGB(20,   0,   60),
        ParticleColor  = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 150, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(88,   24, 169)),
        }),
        Scale          = 1.2,
        Filtre         = "MutantGALAXY",
        Emoji          = "🌌",
        Icon           = "rbxassetid://GALAXY_ICON_ID",
    },
    {
        Name           = "TOXIC",
        Multiplier     = 4,
        Color          = Color3.fromRGB(57,  255,  20),
        SecondaryColor = Color3.fromRGB(0,    80,   0),
        ParticleColor  = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(57,  255,  20)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(0,   200,   0)),
        }),
        Scale          = 1.4,
        Filtre         = "MutantTOXIC",
        Emoji          = "☠️",
        Icon           = "rbxassetid://TOXIC_ICON_ID",
    },
    {
        Name           = "RAINBOW",
        Multiplier     = 6,
        Color          = Color3.fromRGB(255,   0,   0),  -- hue-shift via TweenService en jeu
        SecondaryColor = Color3.fromRGB(255, 255,   0),
        ParticleColor  = ColorSequence.new({
            ColorSequenceKeypoint.new(0,    Color3.fromRGB(255,   0,   0)),
            ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0,   255,   0)),
            ColorSequenceKeypoint.new(0.66, Color3.fromRGB(0,     0, 255)),
            ColorSequenceKeypoint.new(1,    Color3.fromRGB(255,   0, 255)),
        }),
        Scale          = 1.6,
        Filtre         = "MutantRAINBOW",
        Emoji          = "🌈",
        Icon           = "rbxassetid://RAINBOW_ICON_ID",
    },
    {
        Name           = "VOID",
        Multiplier     = 8,
        Color          = Color3.fromRGB(10,    0,  20),
        SecondaryColor = Color3.fromRGB(200,   0,   0),
        ParticleColor  = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(200,   0,   0)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(10,    0,  20)),
        }),
        Scale          = 1.8,
        Filtre         = "MutantVOID",
        Emoji          = "🕳️",
        Icon           = "rbxassetid://VOID_ICON_ID",
    },
}

-- Index par nom pour lookup O(1) : GameConfig.MutantTypesByName["GALAXY"] → entrée complète
GameConfig.MutantTypesByName = {}
for _, mt in ipairs(GameConfig.MutantTypes) do
    GameConfig.MutantTypesByName[mt.Name] = mt
end

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
    [0] = 2,  -- défaut (bat de baseball)
    [1] = 3,  -- Lv.1 coins
    [2] = 5,  -- Lv.2 coins
    [3] = 8,  -- MAX Game Pass (149 R$)
}

GameConfig.CarryPrices = {
    [1] = 500,
    [2] = 2000,
    [3] = 0,  -- Game Pass
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
    -- Points originaux (sol)
    { x=190.92, y=16.189, z=66.30   },
    { x=250.93, y=16.189, z=-80.20  },
    { x=189.51, y=16.189, z=-241.28 },
    -- Points arbres
    { x=251.01, y=59.25, z=-159.01 },
    { x=252.68, y=59.25, z=-145.41 },
    { x=207.58, y=62.43, z=-155.42 },
    { x=213.49, y=67.20, z=-164.68 },
    { x=226.27, y=51.30, z=-152.08 },
    { x=224.96, y=52.89, z=-183.79 },
    { x=241.08, y=62.43, z=-180.62 },
    { x=241.42, y=62.43, z=-191.89 },
    { x=225.17, y=52.89, z=-14.62  },
    { x=207.66, y=54.48, z=-2.66   },
    { x=207.20, y=62.43, z=14.77   },
    { x=214.03, y=67.20, z=4.74    },
    { x=253.34, y=59.25, z=24.97   },
    { x=241.38, y=62.43, z=-11.13  },
    { x=241.63, y=62.43, z=-22.72  },
    { x=225.65, y=51.30, z=18.81   },
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

-- === PVP / COMBAT ===
-- Mettre PvPEnabled = false pour désactiver tout le système Combat (reskins pacifiques)
GameConfig.PvPEnabled = true

GameConfig.Combat = {
	-- Batte de baseball
	BatEnabled  = true,
	BatCooldown = 1,     -- Secondes entre chaque frappe
	BatRange    = 6,     -- Portée en studs (raycast depuis le handle)
	BatDropRadius = 3,   -- Rayon de scatter des BRs lâchés (studs)

	-- Zones safe (autour de chaque base — Part "SafeZone" à créer dans Studio)
	SafeZoneEnabled          = true,
	SafeZoneFeedbackCooldown = 5, -- Secondes entre chaque billboard "SAFE ZONE"

	-- Invincibilité respawn (anti spawn-camp)
	RespawnInvincibilityEnabled  = true,
	RespawnInvincibilityDuration = 3, -- Secondes d'invincibilité après spawn

	-- Game Pass Protection (bloque le drop des BRs)
	-- Remplir avec le vrai ID après création sur Roblox
	ProtectionGamePassId = 0,
}

-- === FUSE MACHINE ===
-- Lu par FuseSystem (shared-lib) — injecter via FuseSystem.Init(GameConfig)
-- FuseBrainrotsFolder : creer ReplicatedStorage/FuseBrainrots/ dans Studio
-- MachineTag          : appliquer le tag CollectionService sur chaque Fuse Machine dans Workspace
GameConfig.Fuse = {
	MachineTag          = "FuseMachine",
	FuseBrainrotsFolder = game:GetService("ReplicatedStorage"):FindFirstChild("FuseBrainrots"),
	FuseDuration        = 5400,  -- 1h30 en secondes
	DataStoreName       = "BrainRotIdleV1",
	DataStoreKeyPrefix  = "fuse_",
	Tiers = {
		{ maxTotal = 1000                },  -- Tier 1
		{ maxTotal = 100000              },  -- Tier 2
		{ maxTotal = 1000000             },  -- Tier 3
		{ maxTotal = 1000000000          },  -- Tier 4
		{ maxTotal = 1000000000000       },  -- Tier 5
		{ maxTotal = 1000000000000000    },  -- Tier 6
		{ maxTotal = 1e18                },  -- Tier 7
		{ maxTotal = math.huge           },  -- Tier 8
	},
	Weights = {
		{ folder = "50", weight = 50 },
		{ folder = "30", weight = 30 },
		{ folder = "18", weight = 18 },
		{ folder = "2",  weight = 2  },
	},
}

-- Injecter la zone dans la config Rain (définie plus haut dans ce fichier)
GameConfig.EventsVisuels.Rain.champCommunZone = GameConfig.ChampCommunZone

-- === LUCKY HOUR — MUTATION CONFIG ===
GameConfig.LuckyHourMutationConfig = {
    enabled = true,
    chance  = 0.15,  -- 15% de chance qu'un spawn LuckyHour soit muté

    -- Poids et multiplicateur d'income par type de mutation
    types = {
        { name = "BrainrotsToxic",   weight = 20, multiplier = 2   },
        { name = "BrainrotsLava",    weight = 15, multiplier = 2.5 },
        { name = "BrainrotsGold",    weight = 15, multiplier = 3   },
        { name = "BrainrotsDiamant", weight = 10, multiplier = 4   },
        { name = "BrainrotsRainbow", weight = 10, multiplier = 5   },
        { name = "BrainrotsNebula",  weight = 15, multiplier = 3   },
        { name = "CrazyBrainrots",   weight = 15, multiplier = 2   },
    },

    -- Mapping rareté : Mutation/ utilise "GOD" au lieu de "BRAINROT_GOD"
    rareteMapping = { BRAINROT_GOD = "GOD" },

    -- Sous-dossiers à ignorer dans chaque type de mutation
    ignoredFolders = { "LUCKY_BLOCK", "ToUseAfter" },
}

-- === CHAMP PERSO — MUTATION CONFIG ===
GameConfig.PersonalFieldMutationConfig = {
    enabled = true,
    chance  = 0.002,  -- 0.2% par spawn (jamais sur COMMON)

    -- Raretés exclues de la mutation (toujours normales)
    raretesExclues = { "COMMON" },

    -- Poids et multiplicateur d'income par type
    types = {
        { name = "BrainrotsToxic",   weight = 20, multiplier = 3 },
        { name = "BrainrotsLava",    weight = 15, multiplier = 4 },
        { name = "BrainrotsGold",    weight = 15, multiplier = 5 },
        { name = "BrainrotsDiamant", weight = 10, multiplier = 6 },
        { name = "BrainrotsRainbow", weight = 10, multiplier = 8 },
        { name = "BrainrotsNebula",  weight = 15, multiplier = 4 },
        { name = "CrazyBrainrots",   weight = 15, multiplier = 3 },
    },

    rareteMapping  = { BRAINROT_GOD = "GOD" },
    ignoredFolders = { "LUCKY_BLOCK", "ToUseAfter" },
}

return GameConfig
