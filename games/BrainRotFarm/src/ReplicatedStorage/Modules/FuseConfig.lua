-- ReplicatedStorage/Modules/FuseConfig.lua
-- Configuration de la Fuse Machine — BrainRot Farm
-- Recettes, timer, coûts, couleurs

local FuseConfig = {}

-- ═══════════════════════════════════════════════
-- PARAMÈTRES GÉNÉRAUX
-- ═══════════════════════════════════════════════

-- Durée de fusion en secondes (1h30 = 5400)
FuseConfig.DureeFusion = 5400

-- Nombre de slots d'entrée (toujours 4)
FuseConfig.NbSlots = 4

-- Tag CollectionService utilisé pour trouver les machines dans Workspace
FuseConfig.MachineTag = "FuseMachine"

-- ═══════════════════════════════════════════════
-- RECETTES
-- ═══════════════════════════════════════════════
-- inputs  : 4 raretés (ordre libre)
-- cout    : prix en coins pour lancer
-- outputs : liste { rarete, chance } — les chances DOIVENT totaliser 100
-- ═══════════════════════════════════════════════

FuseConfig.Recettes = {

    {
        id     = "common_x4",
        label  = "4 × Common",
        inputs = { "Common", "Common", "Common", "Common" },
        cout   = 50,
        outputs = {
            { rarete = "Uncommon", chance = 85 },
            { rarete = "Rare",     chance = 15 },
        },
    },

    {
        id     = "uncommon_x4",
        label  = "4 × Uncommon",
        inputs = { "Uncommon", "Uncommon", "Uncommon", "Uncommon" },
        cout   = 200,
        outputs = {
            { rarete = "Rare", chance = 75 },
            { rarete = "Epic", chance = 25 },
        },
    },

    {
        id     = "rare_uncommon_mix",
        label  = "2 × Rare + 2 × Uncommon",
        inputs = { "Rare", "Rare", "Uncommon", "Uncommon" },
        cout   = 500,
        outputs = {
            { rarete = "Rare", chance = 50 },
            { rarete = "Epic", chance = 50 },
        },
    },

    {
        id     = "rare_x4",
        label  = "4 × Rare",
        inputs = { "Rare", "Rare", "Rare", "Rare" },
        cout   = 800,
        outputs = {
            { rarete = "Epic",      chance = 70 },
            { rarete = "Legendary", chance = 30 },
        },
    },

    {
        id     = "epic_rare_mix",
        label  = "2 × Epic + 2 × Rare",
        inputs = { "Epic", "Epic", "Rare", "Rare" },
        cout   = 2000,
        outputs = {
            { rarete = "Epic",      chance = 60 },
            { rarete = "Legendary", chance = 40 },
        },
    },

    {
        id     = "epic_x4",
        label  = "4 × Epic",
        inputs = { "Epic", "Epic", "Epic", "Epic" },
        cout   = 3000,
        outputs = {
            { rarete = "Legendary", chance = 80 },
            { rarete = "Secret",    chance = 20 },
        },
    },

    {
        id     = "legendary_x4",
        label  = "4 × Legendary",
        inputs = { "Legendary", "Legendary", "Legendary", "Legendary" },
        cout   = 15000,
        outputs = {
            { rarete = "Secret", chance = 100 },
        },
    },

}

-- ═══════════════════════════════════════════════
-- COULEURS & ICÔNES PAR RARETÉ
-- ═══════════════════════════════════════════════

FuseConfig.CouleurRarete = {
    Common    = Color3.fromRGB(200, 200, 200),
    Uncommon  = Color3.fromRGB(100, 200, 100),
    Rare      = Color3.fromRGB(100, 130, 255),
    Epic      = Color3.fromRGB(180, 50,  255),
    Legendary = Color3.fromRGB(255, 200, 0),
    Secret    = Color3.fromRGB(255, 50,  50),
}

FuseConfig.IconeRarete = {
    Common    = "",
    Uncommon  = "",
    Rare      = "",
    Epic      = "",
    Legendary = "",
    Secret    = "",
}

return FuseConfig
