-- ReplicatedStorage/Modules/ShopConfig.lua
-- Configuration du shop pour LavaTower (partagée client/serveur)

local ShopConfig = {}

-- ── CARRY ──────────────────────────────────────────────────────────────────
-- 10 niveaux. Niveau = nombre de BR portables (Niv.1 = 1 BR, Niv.10 = 10 BR)
ShopConfig.Carry = {
    MaxLevel      = 10,
    BonusPerLevel = 1,   -- +1 BR par niveau ; level = MaxCarry
    Prices        = {
         500,       -- Niv.1  → 1 BR
        2000,       -- Niv.2  → 2 BR
        5000,       -- Niv.3  → 3 BR
        15000,      -- Niv.4  → 4 BR
        40000,      -- Niv.5  → 5 BR
        100000,     -- Niv.6  → 6 BR
        300000,     -- Niv.7  → 7 BR
        800000,     -- Niv.8  → 8 BR
        2000000,    -- Niv.9  → 9 BR
        5000000,    -- Niv.10 → 10 BR
    },
    Label         = "Carry",
}

-- ── VITESSE ────────────────────────────────────────────────────────────────
-- 4 niveaux, additif : WalkSpeed = BaseSpeed + level × SpeedPerLevel
--   Niv.0 (base) = 15   Niv.1 = 20   Niv.2 = 25   Niv.3 = 30   Niv.4 = 35
-- Actif partout (base ET tours)
ShopConfig.Speed = {
    MaxLevel      = 4,
    BaseSpeed     = 15,
    SpeedPerLevel = 5,
    Prices        = {
        1000,    -- Niv.1 → 20 WS
        5000,    -- Niv.2 → 25 WS
        20000,   -- Niv.3 → 30 WS
        75000,   -- Niv.4 → 35 WS
    },
    Label         = "Vitesse",
    OnlyInTower   = false,
}

-- ── SAUT ───────────────────────────────────────────────────────────────────
-- 30 niveaux, additif + effet anti-gravité progressif
-- Niv.0 = 50   Niv.10 = 130   Niv.20 = 210   Niv.30 = 290
-- Anti-gravité : 0 % au Niv.0 → 50 % au Niv.30 (lévitation progressive)
-- UNIQUEMENT dans les tours
ShopConfig.Jump = {
    MaxLevel        = 30,
    JumpPerLevel    = 8,     -- +8 JumpPower par niveau  (50 + 10×8 = 130 ✓)
    BaseJump        = 50,    -- valeur Roblox par défaut
    MaxAntiGravity  = 0.50,  -- 50 % de réduction gravitationnelle au niveau max
    BasePrice       = 500,
    PriceMultiplier = 1.45,
    Label           = "Saut",
    OnlyInTower     = true,
}

-- ── OBJETS (achat unique) ──────────────────────────────────────────────────
-- Rangés dans ReplicatedStorage/Tools/
ShopConfig.Bat = {
    Price = 500,
    Label = "Bat",
}

ShopConfig.GoldSlap = {
    Price = 10000,
    Label = "GoldSlap",
}

-- ── HELPERS ────────────────────────────────────────────────────────────────

-- WalkSpeed réelle pour un niveau donné (additif)
function ShopConfig.GetSpeedStat(level)
    return ShopConfig.Speed.BaseSpeed + level * ShopConfig.Speed.SpeedPerLevel
end

-- JumpPower pour un niveau donné
function ShopConfig.GetJumpStat(level)
    return ShopConfig.Jump.BaseJump + level * ShopConfig.Jump.JumpPerLevel
end

-- Facteur anti-gravité (0.0 → MaxAntiGravity) pour un niveau de saut donné
function ShopConfig.GetAntiGravFactor(level)
    if level <= 0 then return 0 end
    return (level / ShopConfig.Jump.MaxLevel) * ShopConfig.Jump.MaxAntiGravity
end

-- Prix d'un niveau de Speed (1-indexed)
function ShopConfig.GetSpeedPrice(level)
    return ShopConfig.Speed.Prices[level] or math.huge
end

-- Prix d'un niveau de Jump (1-indexed), exponentiel
function ShopConfig.GetJumpPrice(level)
    if level < 1 or level > ShopConfig.Jump.MaxLevel then return math.huge end
    return math.floor(ShopConfig.Jump.BasePrice * (ShopConfig.Jump.PriceMultiplier ^ (level - 1)))
end

-- Prix d'un niveau de Carry (1-indexed)
function ShopConfig.GetCarryPrice(level)
    return ShopConfig.Carry.Prices[level] or math.huge
end

-- Formate un grand nombre pour l'affichage
function ShopConfig.FormatNumber(n)
    if n == math.huge then return "∞" end
    if n >= 1e9 then
        return string.format("%.1fB", n / 1e9):gsub("%.0B", "B")
    elseif n >= 1e6 then
        return string.format("%.1fM", n / 1e6):gsub("%.0M", "M")
    elseif n >= 1e3 then
        return string.format("%.1fK", n / 1e3):gsub("%.0K", "K")
    else
        return tostring(math.floor(n))
    end
end

return ShopConfig
