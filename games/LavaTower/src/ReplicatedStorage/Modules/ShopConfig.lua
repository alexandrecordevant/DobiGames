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
-- 50 niveaux, additif : WalkSpeed = BaseSpeed + level × SpeedPerLevel
--   Niv.0 (base) = 15   Niv.50 = 35  (valeur max identique à l'ancienne config)
-- SpeedPerLevel = 0.4 → 15 + 50×0.4 = 35
-- Coûts : formule exponentielle de CoutDepart à 1Q (niveau max)
-- Actif partout (base ET tours)
ShopConfig.Speed = {
    MaxLevel      = 50,
    BaseSpeed     = 15,
    SpeedPerLevel = 0.4,   -- +0.4 WS par niveau ; 15 + 50×0.4 = 35 (inchangé au max)
    CoutDepart    = 1000,  -- coût du niveau 1 (identique à l'ancienne config)
    CoutMax       = 1e15,  -- 1Q — coût exact du dernier niveau
    Label         = "Vitesse",
    OnlyInTower   = false,
}

-- ── SAUT ───────────────────────────────────────────────────────────────────
-- 100 niveaux, additif + effet anti-gravité progressif
-- Niv.0 = 50   Niv.100 = 290  (valeur max identique à l'ancienne config)
-- JumpPerLevel = 2.4 → 50 + 100×2.4 = 290
-- Anti-gravité : 0 % au Niv.0 → 50 % au Niv.100 (lévitation progressive)
-- Coûts : formule exponentielle de CoutDepart à 1Q (niveau max)
-- UNIQUEMENT dans les tours
ShopConfig.Jump = {
    MaxLevel        = 100,
    JumpPerLevel    = 2.4,   -- +2.4 JP par niveau ; 50 + 100×2.4 = 290 (inchangé au max)
    BaseJump        = 50,    -- valeur Roblox par défaut
    MaxAntiGravity  = 0.08,  -- 8 % de reduction gravitationnelle au niveau max (cosmetique)
    CoutDepart      = 500,   -- coût du niveau 1 (identique à l'ancienne config)
    CoutMax         = 1e15,  -- 1Q — coût exact du dernier niveau
    Label           = "Saut",
    OnlyInTower     = true,
}

-- ── OBJETS (achat unique) ──────────────────────────────────────────────────
-- Rangés dans ReplicatedStorage/Tools/
ShopConfig.SpeedCoil = {
    Price = 50000,
    Label = "SpeedCoil",
}

ShopConfig.GravityCoil = {
    Price = 100000,
    Label = "GravityCoil",
}

ShopConfig.Cape = {
    Price = 1000000,
    Label = "Cape",
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

-- Formule exponentielle : cost(N) = depart × (coutMax / depart) ^ ((N-1) / (maxN-1))
local function prixExponentiel(cfg, level)
    if level < 1 or level > cfg.MaxLevel then return math.huge end
    if level == 1 then return cfg.CoutDepart end
    local ratio = cfg.CoutMax / cfg.CoutDepart
    return math.floor(cfg.CoutDepart * ratio ^ ((level - 1) / (cfg.MaxLevel - 1)) + 0.5)
end

-- Prix d'un niveau de Speed (1-indexed)
function ShopConfig.GetSpeedPrice(level)
    return prixExponentiel(ShopConfig.Speed, level)
end

-- Prix d'un niveau de Jump (1-indexed)
function ShopConfig.GetJumpPrice(level)
    return prixExponentiel(ShopConfig.Jump, level)
end

-- Prix d'un niveau de Carry (1-indexed)
function ShopConfig.GetCarryPrice(level)
    return ShopConfig.Carry.Prices[level] or math.huge
end

-- Formate un grand nombre pour l'affichage (jusqu'à 1Q = 1e15)
function ShopConfig.FormatNumber(n)
    if n == math.huge then return "∞" end
    if n >= 1e15 then
        return string.format("%.1fQ", n / 1e15):gsub("%.0Q", "Q")
    elseif n >= 1e12 then
        return string.format("%.1fT", n / 1e12):gsub("%.0T", "T")
    elseif n >= 1e9 then
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
