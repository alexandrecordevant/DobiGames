-- ReplicatedStorage/Modules/RebirthConfig.lua
-- Configuration data-driven des paliers de Rebirth.
-- Pour ajouter un palier : copier une ligne dans Tiers et incrémenter MaxTier.

local RebirthConfig = {}

-- Ordre croissant des raretés (index = puissance)
RebirthConfig.RarityOrder = {
	"Common", "Uncommon", "Rare", "Epic", "Legendary", "Secret"
}

-- Couleurs associées aux raretés (cohérent avec GameConfig)
RebirthConfig.RarityColors = {
	Common    = Color3.fromRGB(200, 200, 200),
	Uncommon  = Color3.fromRGB(100, 200, 100),
	Rare      = Color3.fromRGB(100, 130, 255),
	Epic      = Color3.fromRGB(180, 50,  255),
	Legendary = Color3.fromRGB(255, 200, 0),
	Secret    = Color3.fromRGB(255, 50,  50),
}

-- ─── 10 paliers de Rebirth ───────────────────────────────────────────────────
-- Chaque entrée : money (requis), rarity (BrainRot requis), reward (ce que le joueur gagne)
RebirthConfig.Tiers = {
	[1]  = { money = 10000,       rarity = "Common",    reward = { slots = 1 } },
	[2]  = { money = 25000,       rarity = "Uncommon",  reward = { slots = 1 } },
	[3]  = { money = 60000,       rarity = "Rare",      reward = { slots = 1 } },
	[4]  = { money = 150000,      rarity = "Rare",      reward = { slots = 1 } },
	[5]  = { money = 500000,      rarity = "Epic",      reward = { slots = 1 } },
	[6]  = { money = 1500000,     rarity = "Epic",      reward = { slots = 1 } },
	[7]  = { money = 5000000,     rarity = "Legendary", reward = { slots = 1 } },
	[8]  = { money = 20000000,    rarity = "Legendary", reward = { slots = 1 } },
	[9]  = { money = 75000000,    rarity = "Secret",    reward = { slots = 1 } },
	[10] = { money = 250000000,   rarity = "Secret",    reward = { slots = 1 } },
}

RebirthConfig.MaxTier = 10

-- Retourne la config d'un palier (nil si hors limites)
function RebirthConfig.GetTier(level)
	return RebirthConfig.Tiers[level]
end

-- Retourne l'index de puissance d'une rareté (0 si inconnue)
function RebirthConfig.RarityIndex(rarity)
	for i, r in ipairs(RebirthConfig.RarityOrder) do
		if r == rarity then return i end
	end
	return 0
end

-- Retourne true si la rareté possédée est >= à la rareté requise
function RebirthConfig.MeetsRarity(owned, required)
	return RebirthConfig.RarityIndex(owned) >= RebirthConfig.RarityIndex(required)
		and RebirthConfig.RarityIndex(owned) > 0
end

return RebirthConfig
