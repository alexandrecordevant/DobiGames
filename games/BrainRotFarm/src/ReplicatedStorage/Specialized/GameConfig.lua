-- ReplicatedStorage/Modules/GameConfig.lua
-- ⚠️ SEUL FICHIER À MODIFIER PAR JEU

local GameConfig = {}

-- ═══════════════════════════════════════════
-- MODE TEST
-- ⚠️ METTRE À false AVANT PUBLISH
-- ═══════════════════════════════════════════
GameConfig.TEST_MODE = true

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
        nom         = "Arroseur",
        icone       = "💧",
        description = "Accélère le spawn des Brain Rots dans ton champ",
        ordre       = 1,
        niveaux = {
            [1] = { type="coins", prix=500,   label="Niv.1",   effet={ spawnRateMultiplier=1.6 } },
            [2] = { type="coins", prix=2000,  label="Niv.2",   effet={ spawnRateMultiplier=2.7 } },
            [3] = { type="robux", prix=149,   gamePassId=0,    label="MAX 🔥", effet={ spawnRateMultiplier=5.0 }, isMax=true },
        },
        maxNiveau        = 3,
        dataField        = "upgradeArroseur",
        iconeLeaderboard = true,
    },

    Speed = {
        nom         = "Speed",
        icone       = "⚡",
        description = "Augmente ta vitesse de déplacement",
        ordre       = 2,
        niveaux = {
            [1] = { type="coins", prix=300,  label="Niv.1",  effet={ walkSpeed=22 } },
            [2] = { type="coins", prix=1000, label="Niv.2",  effet={ walkSpeed=28 } },
            [3] = { type="robux", prix=99,   gamePassId=0,   label="MAX 🔥", effet={ walkSpeed=36 }, isMax=true },
        },
        maxNiveau        = 3,
        dataField        = "upgradeSpeed",
        iconeLeaderboard = true,
    },

    Carry = {
        nom         = "Carry+",
        icone       = "🎒",
        description = "Augmente ta capacité de transport de Brain Rots",
        ordre       = 3,
        niveaux = {
            [1] = { type="coins", prix=500,  label="Niv.1",  effet={ carryCapacite=2 } },
            [2] = { type="coins", prix=2000, label="Niv.2",  effet={ carryCapacite=3 } },
            [3] = { type="robux", prix=149,  gamePassId=0,   label="MAX 🔥", effet={ carryCapacite=5 }, isMax=true },
        },
        maxNiveau        = 3,
        dataField        = "upgradeCarry",
        iconeLeaderboard = true,
    },

    Aimant = {
        nom         = "Aimant",
        icone       = "🧲",
        description = "Augmente le rayon de collecte des Brain Rots",
        ordre       = 4,
        niveaux = {
            [1] = { type="coins", prix=800,  label="Niv.1",  effet={ rayonCollecte=8  } },
            [2] = { type="coins", prix=3000, label="Niv.2",  effet={ rayonCollecte=14 }, isMax=true },
        },
        maxNiveau        = 2,
        dataField        = "upgradeAimant",
        iconeLeaderboard = true,
    },

    -- ═══ PAYABLES EN R$ UNIQUEMENT ═══

    Tracteur = {
        nom         = "Tracteur",
        icone       = "🚜",
        description = "Collecte automatiquement les BR selon ton seuil de rareté",
        ordre       = 5,
        niveaux = {
            [1] = { type="robux", prix=299, gamePassId=0, label="Activer", effet={ tracteurActif=true }, isMax=true },
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
        description = "+25% chances d'obtenir une rareté supérieure",
        ordre       = 6,
        niveaux = {
            [1] = { type="robux", prix=99, gamePassId=0, label="Activer", effet={ luckyBonus=1.25 }, isMax=true },
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
        message        = "🌙 NIGHT MODE ! Les Brain Rots brillent dans le noir !",
        messageFin     = "☀️ Le jour se lève... jusqu'au prochain event !",
    },

    MeteorDrop = {
        duree           = 60,
        nbMeteores      = 5,
        hauteurSpawn    = 200,
        vitesseTombee   = 80,
        rayonImpact     = 15,
        intervalleSpawn = 12,
        raretesMeteore  = { "LEGENDARY", "MYTHIC", "SECRET" },
        message         = "☄️ METEOR DROP ! Des météores s'écrasent sur le ChampCommun !",
        messageImpact   = "💥 Impact ! Un Brain Rot rare est apparu !",
        messageFin      = "☄️ Les météores ont cessé de tomber.",
    },

    Rain = {
        duree           = 90,
        hauteurNuages   = 35,
        tailleNuage     = Vector3.new(20, 5, 20),
        spawnMultiplier = 3,
        particleRate    = 50,
        message         = "🌧️ RAIN EVENT ! La pluie booste le ChampCommun ×3 !",
        messageFin      = "☀️ La pluie s'arrête... le champ reste fertilisé !",
    },

    Golden = {
        duree          = 60,
        multiplicateur = 5,
        couleurGolden  = Color3.fromRGB(255, 215, 0),
        ambientGolden  = Color3.fromRGB(255, 200, 50),
        message        = "✨ GOLDEN EVENT ! Tous les gains ×5 pendant 60s !",
        messageFin     = "✨ Le Golden Event est terminé. À bientôt !",
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
