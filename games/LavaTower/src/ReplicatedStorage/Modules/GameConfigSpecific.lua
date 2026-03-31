-- ReplicatedStorage/Modules/GameConfigSpecific.lua
-- Champs propres à LavaTower — ne pas mettre ici ce que shared-lib lit

local GameConfigSpecific = {}

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

-- === PROGRESSION DES ZONES ===
GameConfigSpecific.ZoneUnlockSeuils  = { [1] = 0, [2] = 3, [3] = 6 }
GameConfigSpecific.ZonePrestigeSeuil = 1

return GameConfigSpecific
