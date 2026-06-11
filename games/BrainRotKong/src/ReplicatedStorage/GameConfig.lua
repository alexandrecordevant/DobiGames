-- ReplicatedStorage/Modules/GameConfig.lua
-- ⚠️ SEUL FICHIER À MODIFIER PAR JEU
-- ⚠️ KONG : dupliqué depuis BrainRotKong — full reskin. Blocs pot/seed/arbre/sprinkler/tracteur retirés.
--    Voir KONG_SCOPE.md. Les valeurs marquées TODO_KONG sont à remplir/rééquilibrer.

local GameConfig = {}

-- === DEBUG ===
GameConfig.LOG_LEVEL = "WARN"

-- === IDENTITÉ DU JEU ===
GameConfig.NomDuJeu          = "BrainRot Kong"
GameConfig.Theme             = "kong"          -- TODO_KONG : thème visuel
GameConfig.CollectibleName   = "Brain Rot"
GameConfig.BaseNom           = "Base"

-- === IDs MONÉTISATION (remplir après création sur Roblox) ===
-- TODO_KONG : créer les produits Kong et remplir les Id
GameConfig.ProduitLuckyHour       = { Id = 0, Prix = 35  }
GameConfig.ProduitSecretReveal    = { Id = 0, Prix = 25  }
GameConfig.ProduitSkipTier        = { Id = 0, Prix = 50  }

-- === GAME PASS IDs (table structurée) ===
-- TODO_KONG : créer les Game Passes Kong et remplir les Id (les anciens IDs étaient ceux de BrainRotKong)
GameConfig.GamePassIds = {
    Protection   = 0,  -- Protection offline (pas de perte)
    SpeedMAX     = 0,  -- Speed niveau MAX (walkspeed 40)
    CarryMAX     = 0,  -- Carry niveau MAX
    LuckyCharm   = 0,  -- Lucky Charm : +25% chance rareté supérieure
}

-- === DEV PRODUCT IDs (table structurée) ===
-- TODO_KONG : créer les Dev Products Kong et remplir les Id
GameConfig.DevProductIds = {
    LuckyHour     = 0,  -- Server Boost ×5 — 30 min income ×5 server-wide
}

-- === DISCORD WEBHOOK ===
-- TODO_KONG : remplir depuis discord_webhooks.json après setup_discord.py
GameConfig.DiscordWebhooks = {
    events  = "",  -- #events
    records = "",  -- #records
    dev     = "",  -- #dev-logs
    revenue = "",  -- #revenue-tracking
}
GameConfig.DiscordInvite = ""   -- TODO_KONG : invite Discord Kong

-- === ÉCONOMIE ===
GameConfig.BaseSpawnRate          = 3
GameConfig.BaseSpawnCount         = 1
GameConfig.OfflineIncomeMultiplier = 0.2
GameConfig.MaxOfflineHeures       = 8

-- === PROGRESSION ===
GameConfig.TotalTiers             = 10
GameConfig.CoutUpgradeBase        = 100
GameConfig.CoutUpgradeMultiplier  = 2.5
GameConfig.PrestigeMultiplier     = 2.0

-- === EVENTS AUTOMATIQUES ===
GameConfig.EventFirstSpawnMinutes  = 6
GameConfig.ForceFirstEventType     = "MeteorDrop"
GameConfig.EventIntervalleMinutes  = 12
GameConfig.EventDureeMinutes       = 5
GameConfig.EventSpawnMultiplier    = 10
GameConfig.EarlyBirdBonusMinutes   = 2
GameConfig.AdminAbuseHebdo = {
    jourSemaine     = 7,
    heureUTC        = 20,
    dureeMinutes    = 45,
    spawnMultiplier = 50,
}
-- Types d'events aléatoires déclenchés par EventManager.
GameConfig.EventTypes = {"NightMode", "MeteorDrop", "Rain", "Golden", "RareSpawn"}


-- === RARETÉS ===
-- TODO_KONG : rééquilibrer chances/valeurs pour l'économie Kong
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
GameConfig.AnimationConfig = {
    brSpawnDuree     = 2.0,
    brSpawnOffsetY   = -3,
    brDepotDuree     = 0.3,
    timerHauteurY    = 8,
    timerStudsOffset = 5,
}

-- === LEADERBOARDS 3D ===
-- TODO_KONG : noms des panneaux Studio dans Workspace.Leaderboards de la map Kong
GameConfig.Leaderboards = {
    classement = { "Leaderboard1", "Leaderboard3" },
    infos      = { "Leaderboard2", "Leaderboard4" },
    updateClassement = 5,
    updateInfos      = 5,
    PointsNoms = { "A", "B", "C" },
    AdminAbuseHoraire = nil,
}

-- (ancienne clé conservée pour compatibilité)
GameConfig.LeaderboardPosition = Vector3.new(0, 15, 0)   -- TODO_KONG : position map Kong

-- === SHOP UPGRADES ===
-- Lu par ShopSystem (Common) — Shop Kong = Speed · Carry · Magnet · LuckyCharm UNIQUEMENT
-- TODO_KONG : remplir les gamePassId Kong (0 = placeholder) + rééquilibrer prix
GameConfig.ShopUpgrades = {

    -- ═══ PAYABLES EN COINS ═══

    Speed = {
        nom         = "Speed",
        icone       = "⚡",
        description = "Increases your movement speed",
        ordre       = 1,
        niveaux = {
            [1]  = { type="coins", prix=50000,        label="Lv.1",  effet={ walkSpeed=18 } },
            [2]  = { type="coins", prix=200000,       label="Lv.2",  effet={ walkSpeed=19 } },
            [3]  = { type="coins", prix=750000,       label="Lv.3",  effet={ walkSpeed=20 } },
            [4]  = { type="coins", prix=2500000,      label="Lv.4",  effet={ walkSpeed=21 } },
            [5]  = { type="coins", prix=8000000,      label="Lv.5",  effet={ walkSpeed=22 } },
            [6]  = { type="coins", prix=25000000,     label="Lv.6",  effet={ walkSpeed=23 } },
            [7]  = { type="coins", prix=75000000,     label="Lv.7",  effet={ walkSpeed=24 } },
            [8]  = { type="coins", prix=200000000,    label="Lv.8",  effet={ walkSpeed=26 } },
            [9]  = { type="coins", prix=500000000,    label="Lv.9",  effet={ walkSpeed=28 } },
            [10] = { type="coins", prix=1500000000,   label="Lv.10", effet={ walkSpeed=30 } },
            [11] = { type="coins", prix=4000000000,   label="Lv.11", effet={ walkSpeed=32 } },
            [12] = { type="coins", prix=10000000000,  label="Lv.12", effet={ walkSpeed=33 } },
            [13] = { type="coins", prix=25000000000,  label="Lv.13", effet={ walkSpeed=34 } },
            [14] = { type="coins", prix=60000000000,  label="Lv.14", effet={ walkSpeed=35 } },
            [15] = { type="robux", prix=99, gamePassId=0, label="MAX 🔥", effet={ walkSpeed=40 }, isMax=true },  -- TODO_KONG gamePassId
        },
        maxNiveau        = 15,
        dataField        = "upgradeSpeed",
        iconeLeaderboard = true,
    },

    Carry = {
        nom         = "Carry+",
        icone       = "🎒",
        description = "Increases your Brain Rot carry capacity",
        ordre       = 2,
        niveaux = {
            [1] = { type="coins", prix=75000,    label="Lv.1", effet={ carryCapacite=2 } },
            [2] = { type="coins", prix=600000,   label="Lv.2", effet={ carryCapacite=3 } },
            [3] = { type="coins", prix=4000000,  label="Lv.3", effet={ carryCapacite=4 } },
            [4] = { type="coins", prix=25000000, label="Lv.4", effet={ carryCapacite=5 } },
            [5] = { type="robux", prix=149,    gamePassId=0, label="MAX 🔥", effet={ carryCapacite=8 }, isMax=true },  -- TODO_KONG gamePassId
        },
        maxNiveau        = 5,
        dataField        = "upgradeCarry",
        iconeLeaderboard = true,
    },

    Aimant = {
        nom         = "Magnet",
        icone       = "🧲",
        description = "Increases Brain Rot collection radius",
        ordre       = 3,
        niveaux = {
            [1] = { type="coins", prix=500000,   label="Lv.1",   effet={ rayonCollecte=8  }, condition={ minUpgrade={ upgradeCarry=2 } } },
            [2] = { type="coins", prix=5000000,  label="Lv.2",   effet={ rayonCollecte=14 }, isMax=true },
        },
        maxNiveau        = 2,
        dataField        = "upgradeAimant",
        iconeLeaderboard = true,
    },

    -- ═══ PAYABLE EN R$ UNIQUEMENT ═══

    LuckyCharm = {
        nom         = "Lucky Charm",
        icone       = "🍀",
        description = "+25% chance to get a higher rarity",
        ordre       = 4,
        niveaux = {
            [1] = { type="robux", prix=149, gamePassId=0, label="Activate", effet={ luckyBonus=1.25 }, isMax=true },  -- TODO_KONG gamePassId
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
-- TODO_KONG : palette Kong
GameConfig.CouleurPrimaire   = Color3.fromRGB(100, 200, 100)
GameConfig.CouleurSecondaire = Color3.fromRGB(100, 100, 100)
GameConfig.CouleurAccent     = Color3.fromRGB(255, 220, 50)

-- === UI SHOP ===
GameConfig.UI = {
    Shop = {
        BtnHeightMobile  = 60,
        BtnHeightDesktop = 45,
        BtnCornerRadius  = 8,
        BtnGap           = 8,
        StrokeAvailable  = 1.5,
        PaddingMobile    = 12,
        PaddingDesktop   = 16,
        UpgradeGap       = 16,
        ScrollBarMobile  = 6,
        ScrollBarDesktop = 4,

        ColAchete        = Color3.fromRGB(27,  94,  32),
        ColAcheteTxt     = Color3.fromRGB(255, 255, 255),
        ColDisponible    = Color3.fromRGB(76,  175,  80),
        ColDisponibleTxt = Color3.fromRGB(255, 255, 255),
        ColVerrouille    = Color3.fromRGB(66,   66,  66),
        ColVerrouilleTxt = Color3.fromRGB(180, 180, 180),
        ColMax           = Color3.fromRGB(255, 179,   0),
        ColMaxTxt        = Color3.fromRGB(0,     0,   0),
        ColFutureTxt     = Color3.fromRGB(70,   70,  80),
        ColStrokeDisp    = Color3.fromRGB(180, 255, 180),
    }
}

-- === AUDIO ===
-- TODO_KONG : remplacer par les IDs audio Kong (valeurs actuelles = placeholders BrainRotKong)
GameConfig.SonCollecte = 90855521491933
GameConfig.SonDepot    = 127183292018512
GameConfig.SonRare     = 112485797063762
GameConfig.SonEvent    = 666152447
GameConfig.SonUpgrade  = 10066947742

-- === BADGE ===
GameConfig.BadgePremierPrestige = 0   -- TODO_KONG

-- === EVENTS VISUELS ===
GameConfig.EventsVisuels = {

    NightMode = {
        duree                = 300,
        brightnessMin        = 0.7,
        clockTimeNuit        = 0,
        ambientNuit          = Color3.fromRGB(65, 65, 110),
        outdoorAmbientNuit   = Color3.fromRGB(45, 45, 90),
        fogEndNuit           = 800,
        fogColorNuit         = Color3.fromRGB(30, 30, 70),
        envDiffuseNuit       = 0.4,
        envSpecNuit          = 0.4,
        starCount            = 3000,
        soundIdNuit          = 1843643716,
        message              = "NIGHT MODE! Brain Rots glow in the dark!",
        messageFin           = "Day breaks... until the next event!",
    },

    MeteorDrop = {
        duree           = 180,
        nbMeteores      = 5,
        hauteurSpawn    = 400,
        vitesseTombee   = 80,
        rayonImpact     = 15,
        intervalleSpawn = 30,
        raretesMeteore  = { "LEGENDARY", "LEGENDARY", "LEGENDARY", "LEGENDARY", "MYTHIC", "SECRET" },
        message         = "METEOR DROP! Meteors are crashing into the Common Field!",
        messageImpact   = "Impact! A rare Brain Rot has appeared!",
        messageFin      = "The meteors have stopped falling.",
    },

    Rain = {
        duree           = 300,
        nbNuages        = 6,
        hauteurNuages   = 18,
        tailleNuage     = Vector3.new(20, 5, 20),
        spawnMultiplier = 3,
        particleRate    = 50,
        message         = "RAIN EVENT! Rain boosts the Common Field x3!",
        messageFin      = "The rain stops... the field stays fertilized!",
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
        soundIdRain          = 0,
        wetGroundReflectance = 0.75,
        wetGroundColor       = Color3.fromRGB(85, 90, 100),
        hauteurRain          = 15,
        pluieTouteMap        = true,
        rainGridCols         = 8,
        rainGridRows         = 6,
    },

    Golden = {
        duree          = 180,
        multiplicateur = 5,
        couleurGolden  = Color3.fromRGB(255, 215, 0),
        ambientGolden  = Color3.fromRGB(255, 200, 50),
        message        = "GOLDEN EVENT! All earnings x5 for 60s!",
        messageFin     = "The Golden Event is over. See you soon!",
    },

    LuckyHour = {
        duree           = 180,
        rarityPool      = { RARE = 60, EPIC = 35, LEGENDARY = 5 },
        spawnInterval   = 10,
        couleurAmbiance = Color3.fromRGB(255, 180, 220),
        message         = "LUCKY HOUR! Rare BRs are spawning on your base!",
        messageFin      = "Lucky Hour is over.",
    },

    AdminAbuse = {
        duree               = 45 * 60,
        spawnMultiplier     = 50,
        incomeMultiplier    = 5,
        autoCollectInterval = 20,
        -- KONG : récompenses de quête = Brainrots PAR RARETÉ (plus de graines).
        -- Le champ "rarete" indique la rareté du Brainrot offert directement dans la base.
        questSeuils = {
            { seuil = 10,  rarete = "MYTHIC", qty = 1 },
            { seuil = 25,  rarete = "MYTHIC", qty = 2 },
            { seuil = 50,  rarete = "MYTHIC", qty = 3 },
            { seuil = 100, rarete = "SECRET", qty = 1 },
        },
        earlyBirdRarity = "SECRET",
        message    = "ADMIN ABUSE! Spawn x50 · Gains x5 · 45 min!",
        messageFin = "Admin Abuse ended. See you next Saturday!",

        spawnPool = {
            { nom="RARE",      poids=35, dossier="RARE"      },
            { nom="EPIC",      poids=30, dossier="EPIC"      },
            { nom="LEGENDARY", poids=20, dossier="LEGENDARY" },
            { nom="MYTHIC",    poids=10, dossier="MYTHIC"    },
            { nom="SECRET",    poids=5,  dossier="SECRET"    },
            { nom="OG",        poids=0.03, dossier="OG"      },
        },
        mutationChance = 0,
        elementMutationChance  = 0.50,
        elementMutationRaretes = nil,
    },
}

-- Positions spawn points ChampCommun
-- TODO_KONG : coordonnées de la map Kong
GameConfig.ChampCommunPoints = {
    { x = 190.92, y = 2, z =   66.30 },
    { x = 250.93, y = 2, z =  -80.20 },
    { x = 189.51, y = 2, z = -241.28 },
}

-- Zone couverte par le ChampCommun
-- TODO_KONG : zone de la map Kong
GameConfig.ChampCommunZone = {
    xMin = 150,
    xMax = 300,
    zMin = -350.5,
    zMax =  177.13,
    y    = 2,
}

-- === PROGRESSION BASE ===
GameConfig.ProgressionConfig = {

    floors = {
        { index = 1, nom = "Floor_1", type = "Part",  spots = 10 },
        { index = 2, nom = "Floor_2", type = "Model", spots = 10 },
        { index = 3, nom = "Floor_3", type = "Model", spots = 10 },
        { index = 4, nom = "Floor_4", type = "Model", spots = 10 },
    },

    seuils = {
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

    baseSurTotalGagne = true,
}

-- === TYPES MUTANTS ===
-- Source de vérité canonique (MutantGenerator + mutations champ + Fuse). Conservé pour Kong.
GameConfig.MutantTypes = {
    {
        Name           = "GALAXY",
        MinRebirth     = 0,
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
        MinRebirth     = 0,
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
        MinRebirth     = 3,
        Multiplier     = 6,
        Color          = Color3.fromRGB(255,   0,   0),
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
        MinRebirth     = 5,
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

-- Index par nom pour lookup O(1)
GameConfig.MutantTypesByName = {}
for _, mt in ipairs(GameConfig.MutantTypes) do
    GameConfig.MutantTypesByName[mt.Name] = mt
end

-- Réduction prix progression par rebirth (-15% cumulatif, cap -90%)
GameConfig.RebirthFloorDiscount = 0.15

-- Prix de référence pour déblocage manuel des floors (Rebirth 0)
GameConfig.FloorUnlockCosts = {
    [2] = 2000000,
    [3] = 20000000,
    [4] = 150000000,
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
    GOD          = { mode="prompt",  holdDuration=8.0 },
}

-- === CARRY ===
GameConfig.CarryNiveaux = {
    [0] = 1,
    [1] = 2,
    [2] = 3,
    [3] = 4,
    [4] = 5,
    [5] = 8,
}

GameConfig.CarryPrices = {
    [1] = 75000,
    [2] = 600000,
    [3] = 4000000,
    [4] = 25000000,
    [5] = 0,
}

-- === VALEUR PAR RARETÉ ===
-- TODO_KONG : rééquilibrer pour l'économie Kong
GameConfig.ValeurParRarete = {
    COMMON    = 5,
    OG        = 500000000,
    RARE      = 100,
    EPIC      = 500,
    LEGENDARY = 3000,
    MYTHIC    = 30000,
    SECRET    = 1000000,
    GOD       = 300000,
}

-- === INCOME PAR RARETÉ ===
-- TODO_KONG : rééquilibrer pour l'économie Kong
GameConfig.IncomeParRarete = {
    COMMON    = 5,
    OG        = 500000000,
    RARE      = 100,
    EPIC      = 500,
    LEGENDARY = 3000,
    MYTHIC    = 30000,
    SECRET    = 1000000,
    GOD       = 300000,
}

-- === MAX BASES ===
GameConfig.MaxBases = 6

-- === ITEMS À SPAWNER ===
GameConfig.SpawnableItems = {
    dossier = "Brainrots",
    rarites = {
        { nom="COMMON",    poids=55,  valeur=1  },
        { nom="RARE",      poids=13,  valeur=8  },
        { nom="EPIC",      poids=7,   valeur=20 },
        { nom="LEGENDARY", poids=0.3, valeur=60 },
    },
    raretesCommunOnly = { "MYTHIC", "SECRET" },
}

-- === ZONE COMMUNE ===
-- TODO_KONG : coordonnées de la map Kong
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
GameConfig.BoardConfig = {
    texteDefaut   = "🔄 REBIRTH\nClick to view",
    distanceClick = 20,
}

-- === RARETÉS EXCLUES DU SPAWN NORMAL ===
GameConfig.RaretesExcluesSpawn = {
    "OG",
}

-- === PVP / COMBAT ===
GameConfig.PvPEnabled = true

GameConfig.Combat = {
	BatEnabled  = true,
	BatCooldown = 1,
	BatRange    = 6,
	BatDropRadius = 3,

	SafeZoneEnabled          = true,
	SafeZoneFeedbackCooldown = 5,

	RespawnInvincibilityEnabled  = true,
	RespawnInvincibilityDuration = 3,

	ProtectionGamePassId = 0,   -- TODO_KONG : Game Pass Protection Kong
}

-- === FUSE MACHINE ===
-- Lu par FuseSystem (shared-lib) — injecter via FuseSystem.Init(GameConfig)
GameConfig.Fuse = {
	MachineTag          = "FuseMachine",
	FuseBrainrotsFolder = game:GetService("ServerStorage"):FindFirstChild("FuseBrainrots"),
	FuseDuration        = 5400,
	DataStoreName       = "BrainRotKongV1",
	DataStoreKeyPrefix  = "fuse_",
	Tiers = {
		{ maxTotal = 100       },
		{ maxTotal = 800       },
		{ maxTotal = 5000      },
		{ maxTotal = 30000     },
		{ maxTotal = 300000    },
		{ maxTotal = 5000000   },
		{ maxTotal = math.huge },
	},
	Weights = {
		{ folder = "50", weight = 50 },
		{ folder = "30", weight = 30 },
		{ folder = "18", weight = 18 },
		{ folder = "2",  weight = 2  },
	},
	MutationCPS = {
		GOLD    = 2,
		TOXIC   = 4,
		RAINBOW = 6,
		DIAMANT = 8,
	},
	MutantTypeToSlot = {
		GALAXY  = "GOLD",
		TOXIC   = "TOXIC",
		RAINBOW = "RAINBOW",
		VOID    = "DIAMANT",
	},
}

-- Injecter la zone dans la config Rain (définie plus haut dans ce fichier)
GameConfig.EventsVisuels.Rain.champCommunZone = GameConfig.ChampCommunZone

-- === LUCKY HOUR — MUTATION CONFIG ===
-- TODO_KONG : noms de dossiers de mutation de la map Kong
GameConfig.LuckyHourMutationConfig = {
    enabled = true,
    chance  = 0.25,

    types = {
        { name = "BrainrotsToxic",   weight = 20, multiplier = 2   },
        { name = "BrainrotsLava",    weight = 15, multiplier = 2.5 },
        { name = "BrainrotsGold",    weight = 15, multiplier = 3   },
        { name = "BrainrotsDiamant", weight = 10, multiplier = 4   },
        { name = "BrainrotsRainbow", weight = 10, multiplier = 5   },
        { name = "BrainrotsNebula",  weight = 15, multiplier = 3   },
        { name = "CrazyBrainrots",   weight = 15, multiplier = 2   },
    },

    rareteMapping = {},

    ignoredFolders = { "LUCKY_BLOCK", "ToUseAfter" },
}

-- === CHAMP PERSO — MUTATION CONFIG ===
GameConfig.PersonalFieldMutationConfig = {
    enabled = true,
    chance  = 0.002,

    raretesExclues = { "COMMON" },

    types = {
        { name = "BrainrotsToxic",   weight = 20, multiplier = 3 },
        { name = "BrainrotsLava",    weight = 15, multiplier = 4 },
        { name = "BrainrotsGold",    weight = 15, multiplier = 5 },
        { name = "BrainrotsDiamant", weight = 10, multiplier = 6 },
        { name = "BrainrotsRainbow", weight = 10, multiplier = 8 },
        { name = "BrainrotsNebula",  weight = 15, multiplier = 4 },
        { name = "CrazyBrainrots",   weight = 15, multiplier = 3 },
    },

    rareteMapping  = {},
    ignoredFolders = { "LUCKY_BLOCK", "ToUseAfter" },
}

-- === POIDS DES SOUS-NIVEAUX SECRET ===
GameConfig.SECRET_LEVEL_WEIGHTS = {
    [1] = 88.89,
    [2] = 10,
    [3] = 1,
    [4] = 0.5,
    [5] = 0.1,
}

-- === POIDS DES SOUS-NIVEAUX GOD ===
GameConfig.GOD_LEVEL_WEIGHTS = {
    [1] = 65,
    [2] = 35,
}

-- === MENU HUD GRILLE (SideMenuHUD) ===
GameConfig.MenuHUD = {
    BurgerSize     = 50,
    TailleBouton   = 80,
    NbColonnes     = 2,
    GrilleGap      = 6,
    GrillePadding  = 8,
    RayonCoin      = 10,
    DureeAnimation = 0.2,
}

-- === CODES PROMO ===
-- Clés = codes en MAJUSCULES (comparaison case-insensitive côté serveur)
-- Rewards.Coins     : entier ajouté à player.leaderstats.Coins
-- Rewards.BrainRots : réservé pour usage futur
-- ExpiresAt         : 0 = jamais, sinon timestamp Unix (os.time())
-- MaxUses           : -1 = illimité, sinon quota global (DataStore PromoCodesGlobal)
-- Active            : false = code désactivé sans le supprimer
-- TODO_KONG : définir les codes promo Kong (les codes BrainRotKong ont été retirés ;
--             le champ Seeds n'existe plus — utiliser Coins / BrainRots).
GameConfig.PromoCodes = {}

return GameConfig
