-- Logger.lua
-- Système de logs centralisé, partagé entre tous les jeux DobiGames
-- Initialiser via Logger.init(GameConfig.DEBUG_MODE) au boot de chaque jeu

local Logger = {}

local LEVELS = { DEBUG = 1, INFO = 2, WARN = 3, ERROR = 4 }
local minLevel = LEVELS.INFO  -- défaut prod, sécurisé

-- Prefixes extensibles : ajouter ici si nouveau système
local PREFIXES = {
    Spawn   = "[SPAWN]",
    Carry   = "[CARRY]",
    Deposit = "[DEPOSIT]",
    Shop    = "[SHOP]",
    Data    = "[DATA]",
    Event   = "[EVENT]",
    Prog    = "[PROG]",
    Bot     = "[BOT]",
    Filter  = "[FILTER]",
    Pot     = "[POT]",
    AmelioBase = "[AMELIO-BASE]",
    Assign  = "[ASSIGN]",
    Drop    = "[DROP]",
    Tower   = "[TOWER]",
    Income  = "[INCOME]",
    Pickup  = "[PICKUP]",
    Combat  = "[COMBAT]",
    Notif   = "[NOTIF]",
    HUD     = "[HUD]",
    Board   = "[BOARD]",
    Fuse    = "[FUSE]",
    Arbre   = "[ARBRE]",
    Bale    = "[BALE]",
    Seed    = "[SEED]",
    Pad     = "[PAD]",
    Sprinkler = "[SPRINKLER]",
    Tracteur  = "[TRACTEUR]",
    Leaderboard = "[LEADERBOARD]",
    Discord  = "[DISCORD]",
    Cosmet   = "[COSMET]",
    Inventory = "[INVENTORY]",
    Safe     = "[SAFE]",
    Bat      = "[BAT]",
}

-- Appeler une seule fois au boot du jeu
-- Accepte un niveau string ("DEBUG"|"INFO"|"WARN"|"ERROR") ou un bool (true=DEBUG, false=INFO)
function Logger.init(level)
    if type(level) == "string" then
        minLevel = LEVELS[level:upper()] or LEVELS.INFO
    else
        minLevel = (level == true) and LEVELS.DEBUG or LEVELS.INFO
    end
end

local function format(system, msg)
    return string.format("%s %s", PREFIXES[system] or ("[" .. tostring(system) .. "]"), msg)
end

function Logger.debug(system, msg, ...)
    if LEVELS.DEBUG < minLevel then return end
    print(format(system, string.format(msg, ...)))
end

function Logger.info(system, msg, ...)
    if LEVELS.INFO < minLevel then return end
    print(format(system, string.format(msg, ...)))
end

function Logger.warn(system, msg, ...)
    warn(format(system, string.format(msg, ...)))
end

function Logger.error(system, msg, ...)
    warn("[ERROR]" .. format(system, string.format(msg, ...)))
end

return Logger
