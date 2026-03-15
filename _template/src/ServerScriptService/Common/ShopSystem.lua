-- ServerScriptService/Common/ShopSystem.lua
-- ⚠️ STUB — À implémenter
-- Gère les achats in-game (carry+, arroseur, tracteur, speed...)
-- Déclenché par RemoteEvent côté client
--
-- Ce script doit exposer :
--   ShopSystem.Init()
--   ShopSystem.AcheterUpgrade(player, typeUpgrade) → bool, string

local ShopSystem = {}

function ShopSystem.Init()
    warn("[ShopSystem] Stub non implémenté — boutique désactivée")
end

function ShopSystem.AcheterUpgrade(player, typeUpgrade)
    return false, "ShopSystem non implémenté"
end

return ShopSystem
