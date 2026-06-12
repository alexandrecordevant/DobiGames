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
GameConfig.ProduitLuckyHour       = { Id = 0, Prix = 35  }
GameConfig.ProduitSecretReveal    = { Id = 0, Prix = 25  }
GameConfig.ProduitSkipTier        = { Id = 0, Prix = 50  }

-- === GAME PASS IDs (table structurée — remplir après création sur Roblox) ===
GameConfig.GamePassIds = {
    Tracteur     = 1817529557,  -- Tracteur auto-collect
    Protection   = 1819604298,  -- Protection offline (pas de perte)
    ArroseurMAX  = 1814153843,  -- Arroseur niveau MAX (×5 spawn rate)
    SpeedMAX     = 1818373456,  -- Speed niveau MAX (walkspeed 40)
    CarryMAX     = 1816561688,  -- Carry niveau MAX (5 BR)
    FlowerPot4   = 1816555612,  -- Débloquer FlowerPot 4 (149 R$)
    SeedDoubler  = 1817181575,  -- Seed Doubler : 2 graines quotidiennes au lieu de 1
    LuckyCharm   = 1819652284,  -- Lucky Charm : +25% chance rareté supérieure
}

-- Alias direct lu par ClaimDailySeed (synchronisé avec GamePassIds.SeedDoubler)
GameConfig.SeedDoublerPassId = GameConfig.GamePassIds.SeedDoubler

-- === DEV PRODUCT IDs (table structurée — remplir après création sur Roblox) ===
GameConfig.DevProductIds = {
    LuckyHour     = 3583048107,  -- Server Boost ×5 — 30 min income ×5 server-wide  (99 R$)
    SkipSeedTimer = 3583048518,  -- Skip timer daily seed (25 R$)
    SeedPackx3    = 3583048753,  -- +3 graines MYTHIC   (99 R$)
    SecretSeed    = 3583048915,  -- +1 graine SECRET    (149 R$)
    -- Lucky Blocks (consommables)
    LuckyBlockMythic = 3603993100,  -- Lucky Block Mythic        (49 R$)
    LuckyBlockGod    = 3603993169,  -- Lucky Block Brainrot God  (149 R$)
    LuckyBlockSecret = 3603993225,  -- Lucky Block Secret        (399 R$)
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
GameConfig.OfflineIncomeMultiplier = 0.2
GameConfig.MaxOfflineHeures       = 8

-- === PROGRESSION ===
GameConfig.TotalTiers             = 10
GameConfig.CoutUpgradeBase        = 100
GameConfig.CoutUpgradeMultiplier  = 2.5
GameConfig.PrestigeMultiplier     = 2.0

-- === EVENTS AUTOMATIQUES ===
GameConfig.EventFirstSpawnMinutes  = 4    -- délai avant le premier event (minutes)
GameConfig.ForceFirstEventType     = "MeteorDrop"  -- type forcé pour le premier event (nil = aléatoire)
GameConfig.EventIntervalleMinutes  = 12   -- intervalle entre events (minutes)
GameConfig.EventDureeMinutes       = 5
GameConfig.EventSpawnMultiplier    = 10
GameConfig.EarlyBirdBonusMinutes   = 2    -- réduit à 2 min pour coller à l'intervalle 12 min
GameConfig.AdminAbuseHebdo = {
    jourSemaine     = 7,
    heureUTC        = 20,
    dureeMinutes    = 45,
    spawnMultiplier = 50,
}
-- Types d'events aléatoires déclenchés par EventManager.
-- Modifier cette liste pour ajouter/retirer des events selon le jeu.
GameConfig.EventTypes = {"NightMode", "MeteorDrop", "Rain", "Golden", "RareSpawn"}


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
            [1] = { type="coins", prix=300000,   label="Lv.1",    effet={ spawnRateMultiplier=1.6 }, condition={ minUpgrade={ upgradeCarry=2 } } },
            [2] = { type="coins", prix=2500000,  label="Lv.2",    effet={ spawnRateMultiplier=2.7 } },
            [3] = { type="robux", prix=149,   gamePassId=1814153843, label="MAX 🔥", effet={ spawnRateMultiplier=5.0 }, isMax=true },
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
            [15] = { type="robux", prix=99, gamePassId=1818373456, label="MAX 🔥", effet={ walkSpeed=40 }, isMax=true },
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
            [1] = { type="coins", prix=75000,    label="Lv.1", effet={ carryCapacite=3 } },
            [2] = { type="coins", prix=600000,   label="Lv.2", effet={ carryCapacite=4 } },
            [3] = { type="coins", prix=4000000,  label="Lv.3", effet={ carryCapacite=5 } },
            [4] = { type="coins", prix=25000000, label="Lv.4", effet={ carryCapacite=6 } },
            [5] = { type="robux", prix=149,    gamePassId=1816561688, label="MAX 🔥", effet={ carryCapacite=8 }, isMax=true },
        },
        maxNiveau        = 5,
        dataField        = "upgradeCarry",
        iconeLeaderboard = true,
    },

    Aimant = {
        nom         = "Magnet",
        icone       = "🧲",
        description = "Increases Brain Rot collection radius",
        ordre       = 4,
        niveaux = {
            [1] = { type="coins", prix=500000,   label="Lv.1",   effet={ rayonCollecte=8  }, condition={ minUpgrade={ upgradeCarry=2 } } },
            [2] = { type="coins", prix=5000000,  label="Lv.2",   effet={ rayonCollecte=14 }, isMax=true },
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
            [1] = { type="robux", prix=299, gamePassId=1817529557, label="Activate", effet={ tracteurActif=true }, isMax=true },
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
            [1] = { type="robux", prix=149, gamePassId=1819652284, label="Activate", effet={ luckyBonus=1.25 }, isMax=true },
        },
        maxNiveau        = 1,
        isGamePass       = true,
        dataField        = "hasLuckyCharm",
        iconeLeaderboard = false,
    },

    SeedDoubler = {
        nom         = "Seed Doubler",
        icone       = "🌱",
        description = "Claim 2 Daily Seeds per day instead of 1",
        ordre       = 7,
        niveaux = {
            [1] = { type="robux", prix=99, gamePassId=1817181575, label="Activate", effet={}, isMax=true },
        },
        maxNiveau        = 1,
        isGamePass       = true,
        dataField        = "hasSeedDoubler",
        iconeLeaderboard = false,
    },
}

-- Valeurs par défaut (utilisées par ShopSystem pour réinitialisation / defaults)
GameConfig.WalkSpeedDefaut       = 16
GameConfig.CarryCapaciteDefaut   = 2
GameConfig.RayonCollecteDefaut   = 4

-- === COULEURS THÈME ===
GameConfig.CouleurPrimaire   = Color3.fromRGB(100, 200, 100)
GameConfig.CouleurSecondaire = Color3.fromRGB(100, 100, 100)
GameConfig.CouleurAccent     = Color3.fromRGB(255, 220, 50)

-- === UI SHOP ===
-- Clés lues par ShopHUD.client — ne pas hardcoder ces valeurs dans le script
GameConfig.UI = {
    Shop = {
        -- Sizing adaptatif mobile / desktop
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

        -- Couleurs par état des boutons upgrade
        ColAchete        = Color3.fromRGB(27,  94,  32),   -- vert foncé — acheté
        ColAcheteTxt     = Color3.fromRGB(255, 255, 255),
        ColDisponible    = Color3.fromRGB(76,  175,  80),  -- vert vif — achetable
        ColDisponibleTxt = Color3.fromRGB(255, 255, 255),
        ColVerrouille    = Color3.fromRGB(66,   66,  66),  -- gris — verrouillé
        ColVerrouilleTxt = Color3.fromRGB(180, 180, 180),
        ColMax           = Color3.fromRGB(255, 179,   0),  -- or — niveau MAX
        ColMaxTxt        = Color3.fromRGB(0,     0,   0),  -- noir sur fond or
        ColFutureTxt     = Color3.fromRGB(70,   70,  80),  -- très sombre — non débloqué
        ColStrokeDisp    = Color3.fromRGB(180, 255, 180),  -- bordure brillante bouton disponible
    }
}

-- === SHOP (données métier — lu par LuckyBlockSystem / HUDController / ShopHUD) ===
-- ⚠️ NE PAS confondre avec GameConfig.UI.Shop (au-dessus) qui ne contient que le style.
GameConfig.Shop = {
    -- ── LUCKY BLOCKS ──────────────────────────────────────────────
    -- Lu par LuckyBlockSystem : achat (DevProduct) → carry → dépôt slot → ouverture.
    -- CONTRAT DOSSIERS (à créer en Studio) :
    --   ReplicatedStorage.LuckyBlocks.Tier_N contient :
    --     • un modèle "Lucky Block" (visuel porté/déposé)
    --     • des sous-dossiers nommés exactement comme les `label` ci-dessous,
    --       chacun contenant les modèles Brainrot résultat possibles.
    --   Les BR résultat doivent porter les attributs Rarete + CashParSeconde.
    --   Si un label n'a pas de sous-dossier → fallback tirage aléatoire tout le tier.
    -- `devProduct` = clé dans GameConfig.DevProductIds.
    LuckyBlocks = {
        {
            nom        = "Mythic",
            prix       = 49,
            devProduct = "LuckyBlockMythic",
            folder     = "ReplicatedStorage.LuckyBlocks.Tier_1",
            weights = {
                { chance = 49.5, label = "50"  },
                { chance = 30,   label = "30"  },
                { chance = 18,   label = "18"  },
                { chance = 2,    label = "2"   },
                { chance = 0.5,  label = "0.5" },
            },
        },
        {
            nom        = "Brainrot God",
            prix       = 149,
            devProduct = "LuckyBlockGod",
            folder     = "ReplicatedStorage.LuckyBlocks.Tier_2",
            weights = {
                { chance = 49.5, label = "50"  },
                { chance = 30,   label = "30"  },
                { chance = 18,   label = "18"  },
                { chance = 2,    label = "2"   },
                { chance = 0.5,  label = "0.5" },
            },
        },
        {
            nom        = "Secret",
            prix       = 399,
            devProduct = "LuckyBlockSecret",
            folder     = "ReplicatedStorage.LuckyBlocks.Tier_3",
            weights = {
                { chance = 49.5, label = "50"  },
                { chance = 30,   label = "30"  },
                { chance = 18,   label = "18"  },
                { chance = 2,    label = "2"   },
                { chance = 0.5,  label = "0.5" },
            },
        },
    },
}

-- === AUDIO ===
-- IDs à remplir : chercher dans Toolbox Studio (onglet Audio, filtre Free)
--   SonCollecte → "pop" / "pickup" / "ding"         (< 1s)
--   SonDepot    → "coin drop" / "cash" / "whoosh"   (< 1.5s)
--   SonRare     → "fanfare" / "sparkle" / "level up" (1-2s)
--   SonEvent    → "notification" / "alert"           (1-3s)
--   SonUpgrade  → "purchase" / "coin" / "chime"     (< 1s)
--   SonGraine   → "plant" / "dirt" / "nature"       (< 1s)
--   SonBale     → "rumble" / "rolling" / "whoosh"   (looped, 1-3s)
GameConfig.SonCollecte = 90855521491933
GameConfig.SonDepot    = 127183292018512
GameConfig.SonRare     = 112485797063762
GameConfig.SonEvent    = 666152447
GameConfig.SonUpgrade  = 10066947742
GameConfig.SonGraine   = 133067975681895
GameConfig.SonBale     = 84022491118443

-- === BADGE ===
GameConfig.BadgePremierPrestige = 0

-- === EVENTS VISUELS ===
GameConfig.EventsVisuels = {

    NightMode = {
        duree                = 300,
        -- Lighting nuit
        brightnessMin        = 0.7,
        clockTimeNuit        = 0,    -- 0 = minuit, 14 = 14h00
        ambientNuit          = Color3.fromRGB(65, 65, 110),
        outdoorAmbientNuit   = Color3.fromRGB(45, 45, 90),
        fogEndNuit           = 800,
        fogColorNuit         = Color3.fromRGB(30, 30, 70),
        envDiffuseNuit       = 0.4,
        envSpecNuit          = 0.4,
        -- Ciel étoilé (0–3000)
        starCount            = 3000,
        -- Son ambiant nuit : remplir après import dans Studio
        -- Exemples gratuits Roblox : 507846804 (vent), 1843643716 (nuit)
        soundIdNuit          = 1843643716,
        -- Messages
        message              = "NIGHT MODE! Brain Rots glow in the dark!",
        messageFin           = "Day breaks... until the next event!",
    },

    MeteorDrop = {
        duree           = 180,
        nbMeteores      = 5,
        hauteurSpawn    = 400,
        vitesseTombee   = 80,
        rayonImpact     = 15,
        intervalleSpawn = 8,   -- un météore toutes les 8s (~22 sur l'event) au lieu de 30s
        raretesMeteore  = { "LEGENDARY", "LEGENDARY", "LEGENDARY", "LEGENDARY", "MYTHIC", "SECRET" },
        message         = "METEOR DROP! Meteors are crashing into the Common Field!",
        messageImpact   = "Impact! A rare Brain Rot has appeared!",
        messageFin      = "The meteors have stopped falling.",
    },

    Rain = {
        duree           = 300,
        nbNuages        = 6,   -- nuages répartis aléatoirement dans la ChampCommunZone
        hauteurNuages   = 18,
        tailleNuage     = Vector3.new(20, 5, 20),
        spawnMultiplier = 3,
        particleRate    = 50,
        message         = "RAIN EVENT! Rain boosts the Common Field x3!",
        messageFin      = "The rain stops... the field stays fertilized!",
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
        duree               = 45 * 60,  -- 2700 secondes
        spawnMultiplier     = 50,
        incomeMultiplier    = 5,
        autoCollectInterval = 20,
        questSeuils = {
            { seuil = 10,  seed = "MYTHIC", qty = 1 },
            { seuil = 25,  seed = "MYTHIC", qty = 2 },
            { seuil = 50,  seed = "MYTHIC", qty = 3 },
            { seuil = 100, seed = "SECRET", qty = 1 },
        },
        earlyBirdRarity = "SECRET",
        message    = "ADMIN ABUSE! Spawn x50 · Gains x5 · 45 min!",
        messageFin = "Admin Abuse ended. See you next Saturday!",

        -- Pool de spawn dédiée (remplace le champ perso normal)
        spawnPool = {
            { nom="RARE",      poids=35, dossier="RARE"      },
            { nom="EPIC",      poids=30, dossier="EPIC"      },
            { nom="LEGENDARY", poids=20, dossier="LEGENDARY" },
            { nom="MYTHIC",    poids=10, dossier="MYTHIC"    },
            { nom="SECRET",    poids=5,  dossier="SECRET"    },
            { nom="OG",        poids=0.03, dossier="OG"      },  -- ~1 apparition par mois (5 sessions hebdo)
            -- BRAINROT_GOD retiré : dossier Brainrots/BRAINROT_GOD absent
        },
        -- Mutations champ désactivées — on utilise uniquement les mutations élément (style FlowerPot)
        mutationChance = 0,
        -- Mutations élément (GALAXY/TOXIC/RAINBOW/VOID) sur TOUTES les raretés
        elementMutationChance  = 0.50,
        elementMutationRaretes = nil,  -- nil = toutes les raretés éligibles
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
        [2] = { nom = "FlowerPot_2", prixCoins = 150000,  prixRobux = 0,
                debloque = false },
        [3] = { nom = "FlowerPot_3", prixCoins = 1500000, prixRobux = 0,
                debloque = false },
        [4] = { nom = "FlowerPot_4", prixCoins = 0,     prixRobux = 149,
                debloque = false, gamePassId = 1816555612 },
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
        intervalleSecondes = 900,   -- 15 min entre chaque graine
        chanceMYTHIC       = 70,    -- 70% MYTHIC
        chanceSECRET       = 30,    -- 30% SECRET
        timeoutSecondes    = 600,   -- 10 min avant reset si non collectée
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
    [0] = 2,  -- défaut
    [1] = 3,  -- Lv.1 coins
    [2] = 4,  -- Lv.2 coins
    [3] = 5,  -- Lv.3 coins
    [4] = 6,  -- Lv.4 coins
    [5] = 8,  -- MAX Game Pass (149 R$)
}

GameConfig.CarryPrices = {
    [1] = 75000,
    [2] = 600000,
    [3] = 4000000,
    [4] = 25000000,
    [5] = 0,  -- Game Pass
}

-- === VALEUR PAR RARETÉ ===
GameConfig.ValeurParRarete = {
    COMMON    = 5,
    OG        = 500000000,
    RARE      = 100,
    EPIC      = 500,
    LEGENDARY = 3000,
    MYTHIC    = 30000,
    SECRET    = 1000000,   -- T1 (plancher safe — T2-T5 ont CashParSeconde sur le modèle)
    GOD       = 300000,    -- moyenne T1-T2
}

-- === INCOME PAR RARETÉ ===
GameConfig.IncomeParRarete = {
    COMMON    = 5,
    OG        = 500000000,
    RARE      = 100,
    EPIC      = 500,
    LEGENDARY = 3000,
    MYTHIC    = 30000,
    SECRET    = 1000000,   -- T1 (plancher safe — T2-T5 ont CashParSeconde sur le modèle)
    GOD       = 300000,    -- moyenne T1-T2
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
        -- OG retiré : spawn exclusivement via Admin Abuse (spawnPool dédié)
        -- BRAINROT_GOD retiré du spawn normal — admin abuse uniquement (rareteForce)
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
	ProtectionGamePassId = 1819604298,
}

-- === FUSE MACHINE ===
-- Lu par FuseSystem (shared-lib) — injecter via FuseSystem.Init(GameConfig)
-- FuseBrainrotsFolder : creer ServerStorage/FuseBrainrots/ dans Studio
-- MachineTag          : appliquer le tag CollectionService sur chaque Fuse Machine dans Workspace
GameConfig.Fuse = {
	MachineTag          = "FuseMachine",
	FuseBrainrotsFolder = game:GetService("ServerStorage"):FindFirstChild("FuseBrainrots"),
	FuseDuration        = 5400,  -- 1h30 en secondes
	DataStoreName       = "BrainRotIdleV1",
	DataStoreKeyPrefix  = "fuse_",
	Tiers = {
		{ maxTotal = 100       },  -- Tier 1 → RARE
		{ maxTotal = 800       },  -- Tier 2 → EPIC
		{ maxTotal = 5000      },  -- Tier 3 → LEGENDARY
		{ maxTotal = 30000     },  -- Tier 4 → MYTHIC
		{ maxTotal = 300000    },  -- Tier 5 → BRAINROT_GOD
		{ maxTotal = 5000000   },  -- Tier 6 → SECRET
		{ maxTotal = math.huge },  -- Tier 7 → SECRET (fallback pour CPS > 5M)
	},
	Weights = {
		{ folder = "50", weight = 50 },
		{ folder = "30", weight = 30 },
		{ folder = "18", weight = 18 },
		{ folder = "2",  weight = 2  },
	},
	-- Multiplicateurs CPS par slot de mutation (calqués sur LavaTower)
	MutationCPS = {
		GOLD    = 2,  -- GALAXY  (rebirth 0, income ×2)
		TOXIC   = 4,  -- TOXIC   (rebirth 0, income ×4) — aligné FlowerPot
		RAINBOW = 6,  -- RAINBOW (rebirth 3, income ×6) — aligné FlowerPot
		DIAMANT = 8,  -- VOID    (rebirth 5, income ×8) — aligné FlowerPot
	},
	-- Mapping MutantType FlowerPot → slot interne FuseSystem
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
GameConfig.LuckyHourMutationConfig = {
    enabled = true,
    chance  = 0.25,  -- 25% de chance qu'un spawn LuckyHour soit muté

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

    rareteMapping = {},

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

    rareteMapping  = {},
    ignoredFolders = { "LUCKY_BLOCK", "ToUseAfter" },
}

-- === POIDS DES SOUS-NIVEAUX SECRET (plus le numéro est élevé, plus c'est rare) ===
GameConfig.SECRET_LEVEL_WEIGHTS = {
    [1] = 88.89,
    [2] = 10,
    [3] = 1,
    [4] = 0.5,   -- était 0.1 → ~17 jours à 6P (était 83j)
    [5] = 0.1,   -- était 0.01 → ~83 jours à 6P (était 833j)
}

-- === POIDS DES SOUS-NIVEAUX GOD ===
GameConfig.GOD_LEVEL_WEIGHTS = {
    [1] = 65,
    [2] = 35,
}

-- === MENU HUD GRILLE (SideMenuHUD) ===
-- Lu par SideMenuHUD.client.lua — valeurs UI uniquement, pas de logique métier
GameConfig.MenuHUD = {
    BurgerSize     = 50,   -- taille du bouton hamburger (px)
    TailleBouton   = 80,   -- taille d'un bouton carré dans la grille (px)
    NbColonnes     = 2,    -- colonnes dans la grille
    GrilleGap      = 6,    -- espace entre cellules (px)
    GrillePadding  = 8,    -- padding intérieur du panneau (px)
    RayonCoin      = 10,   -- rayon UICorner des boutons (px)
    DureeAnimation = 0.2,  -- durée expand / collapse (secondes)
}

-- === CODES PROMO ===
-- Clés = codes en MAJUSCULES (comparaison case-insensitive côté serveur)
-- Rewards.Coins       : entier ajouté à player.leaderstats.Coins
-- Rewards.Seeds       : { { Rarity="MYTHIC"|"SECRET", Quantity=N }, ... }
-- Rewards.BrainRots   : réservé pour usage futur
-- ExpiresAt           : 0 = jamais, sinon timestamp Unix (os.time())
-- MaxUses             : -1 = illimité, sinon quota global (DataStore PromoCodesGlobal)
-- Active              : false = code désactivé sans le supprimer
GameConfig.PromoCodes = {

    ["BETA2026"] = {
        Rewards = {
            Coins     = 100000,
            Seeds     = { { Rarity = "MYTHIC", Quantity = 1 } },
            BrainRots = {},
        },
        ExpiresAt   = 0,
        MaxUses     = -1,
        Description = "Code de bienvenue pour les beta testeurs",
        Active      = true,
    },

    ["LAUNCH"] = {
        Rewards = {
            Coins     = 50000,
            Seeds     = {},
            BrainRots = {},
        },
        ExpiresAt   = 0,
        MaxUses     = -1,
        Description = "Code de lancement officiel",
        Active      = true,
    },

    ["LAUNCH2026"] = {
        Rewards = {
            Coins     = 25000,
            Seeds     = { { Rarity = "RARE", Quantity = 1 } },
            BrainRots = {},
        },
        ExpiresAt   = 0,
        MaxUses     = -1,
        Description = "Code de lancement officiel TikTok",
        Active      = true,
    },

    ["TIKTOK1K"] = {
        Rewards = {
            Coins     = 25000,
            Seeds     = { { Rarity = "SECRET", Quantity = 1 } },
            BrainRots = {},
        },
        ExpiresAt   = 0,
        MaxUses     = 1000,
        Description = "TikTok 1K followers milestone — premiers 1000 joueurs uniquement",
        Active      = true,
    },
}

return GameConfig
