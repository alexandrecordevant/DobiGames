-- ReplicatedStorage/Modules/BrainrotSpawnConfig.lua
-- ModuleScript — Configuration centralisée du système de spawn hybride
-- Modifier uniquement ce fichier pour ajuster les paramètres

local Config = {}

-- ══════════════════════════════════════════════════════════════
-- RARETÉS (doivent correspondre aux dossiers dans BrainrotModels)
-- ══════════════════════════════════════════════════════════════

Config.Raretes = {
    { nom = "Common",    chance = 55, valeur = 10,   taille = 2,   couleur = Color3.fromRGB(180, 180, 180) },
    { nom = "Epic",      chance = 25, valeur = 35,   taille = 2.5, couleur = Color3.fromRGB(160, 50,  255) },
    { nom = "Legendary", chance = 12, valeur = 100,  taille = 3,   couleur = Color3.fromRGB(255, 180, 0  ) },
    { nom = "Mythic",    chance = 6,  valeur = 300,  taille = 3.5, couleur = Color3.fromRGB(255, 50,  150) },
    { nom = "God",       chance = 2,  valeur = 1000, taille = 4.5, couleur = Color3.fromRGB(255, 215, 0  ) },
}

-- ══════════════════════════════════════════════════════════════
-- CHAMP INDIVIDUEL (Part "SpawnArea" dans la base de chaque joueur)
-- Spawn uniquement : Common, Epic
-- Ramassage : propriétaire uniquement
-- ══════════════════════════════════════════════════════════════

Config.ChampIndividuel = {
    SpawnInterval = 8,    -- secondes entre chaque tentative de spawn
    MaxActifs     = 6,    -- max brainrots simultanés par base joueur
    Raretes       = { "Common", "Epic" },
    Expiration    = {
        Common = 45,      -- secondes avant disparition
        Epic   = 60,
    },
}

-- ══════════════════════════════════════════════════════════════
-- CHAMP COMMUN (Model "ChampCommun" dans Workspace)
-- Spawn uniquement : Legendary, Mythic, God
-- Ramassage : tout le monde
-- ══════════════════════════════════════════════════════════════

Config.ChampCommun = {
    SpawnInterval   = 45,  -- secondes entre chaque tentative de spawn
    MaxActifs       = 4,   -- max brainrots simultanés sur le champ commun

    -- Limite par rareté (ne peut pas dépasser ces valeurs simultanément)
    MaxParRarete    = {
        Legendary = 2,
        Mythic    = 1,
        God       = 1,
    },

    Raretes         = { "Legendary", "Mythic", "God" },

    -- Durée de maintien du ProximityPrompt avant collecte
    HoldDuration    = {
        Legendary = 0,    -- instantané
        Mythic    = 0.5,  -- demi-seconde
        God       = 2,    -- 2 secondes
    },

    GodNeverExpires = true,   -- un God ne disparaît jamais
    Expiration      = 120,    -- secondes avant disparition (Legendary, Mythic)
}

return Config
