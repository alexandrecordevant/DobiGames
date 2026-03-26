-- ServerScriptService/_RebirthCallbacks.lua
-- Pont singleton entre Main.server.lua et RebirthServer.server.lua.
-- Main injecte les vraies implémentations via SetCallbacks().
-- RebirthServer appelle GetMoney / DeductMoney / ConsumeRarity sans connaître Main.

local RebirthCallbacks = {}

-- Implémentations par défaut — warn si Main n'a pas encore injecté
local _getMoney      = function(player)
	warn("[RebirthCallbacks] GetMoney non connecté — Main.server.lua n'a pas appelé SetCallbacks()")
	return 0
end
local _deductMoney   = function(player, amount)
	warn(string.format("[RebirthCallbacks] DeductMoney non connecté — %s · %d coins ignorés", player.Name, amount))
end
local _consumeRarity = function(player, rarity)
	warn(string.format("[RebirthCallbacks] ConsumeRarity non connecté — %s · rareté %s ignorée", player.Name, rarity))
end

-- Appelé une seule fois depuis Main.server.lua au démarrage
function RebirthCallbacks.SetCallbacks(getMoney, deductMoney, consumeRarity)
	_getMoney      = getMoney
	_deductMoney   = deductMoney
	_consumeRarity = consumeRarity
	print("[RebirthCallbacks] Callbacks injectés ✓")
end

function RebirthCallbacks.GetMoney(player)
	return _getMoney(player)
end

function RebirthCallbacks.DeductMoney(player, amount)
	_deductMoney(player, amount)
end

function RebirthCallbacks.ConsumeRarity(player, rarity)
	_consumeRarity(player, rarity)
end

return RebirthCallbacks
