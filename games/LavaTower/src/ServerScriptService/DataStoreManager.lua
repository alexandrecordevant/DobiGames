-- ServerScriptService/DataStoreManager.lua
-- Chargement / sauvegarde des données joueur.
--
-- USAGE (depuis Main.server.lua, avant tout Load/Save) :
--   DataStoreManager.Setup("MonDataStoreV1", function()
--       return { coins = 0, tier = 0, ... }  -- données par défaut
--   end)

local DataStoreManager = {}
local DataStoreService = game:GetService("DataStoreService")

-- ─────────────────────────────────────────────────────────────
-- État interne — injecté via Setup()
-- ─────────────────────────────────────────────────────────────

local _ds            = nil   -- DataStore instance (lazy)
local _datastoreName = nil   -- nom injecté par Setup()
local _defaultDataFn = nil   -- fonction de données par défaut injectée

-- ─────────────────────────────────────────────────────────────
-- API de configuration — à appeler depuis Main avant le premier Load
-- ─────────────────────────────────────────────────────────────

--[[
    DataStoreManager.Setup(datastoreName, defaultDataFn)

    datastoreName : string   — nom du DataStore (ex: "LavaTowerV1")
    defaultDataFn : function — retourne la table de données par défaut
                               (optionnel — si absent, utilise DefaultData() interne)
--]]
function DataStoreManager.Setup(datastoreName, defaultDataFn)
    _datastoreName = datastoreName
    _defaultDataFn = defaultDataFn
    _ds            = DataStoreService:GetDataStore(datastoreName)
    print("[DataStoreManager] DataStore : '" .. datastoreName .. "' ✓")
end

-- Accesseur interne avec fallback de sécurité
local function getDS()
    if not _ds then
        -- Setup() non appelé — fallback avec avertissement
        warn("[DataStoreManager] Setup() non appelé — DataStore non configuré. Appeler Setup() dans Main.server.lua.")
        _ds = DataStoreService:GetDataStore("FallbackDataStore_UNCONFIGURED")
    end
    return _ds
end

local function DefaultData()
    if _defaultDataFn then return _defaultDataFn() end
    -- Données minimales si aucune fonction injectée
    return {
        coins = 0, tier = 0, prestige = 0,
        inventory = {}, hasVIP = false, hasOfflineVault = false, hasAutoCollect = false,
        derniereConnexion = os.time(), totalCollecte = 0,
        stats = { sessionsCount = 0, totalHeuresJeu = 0 },
    }
end

-- ─────────────────────────────────────────────────────────────
-- API publique
-- ─────────────────────────────────────────────────────────────

function DataStoreManager.Load(player)
    local ok, data = pcall(function()
        return getDS():GetAsync("player_" .. player.UserId)
    end)
    if not ok or not data then data = DefaultData() end
    data.derniereConnexion       = os.time()
    data.stats                   = data.stats or {}
    data.stats.sessionsCount     = (data.stats.sessionsCount or 0) + 1
    return data
end

function DataStoreManager.Save(player, data)
    data.derniereConnexion = os.time()
    local ok, err = pcall(function()
        getDS():SetAsync("player_" .. player.UserId, data)
    end)
    if not ok then
        warn("[DataStore] Erreur save " .. player.Name .. ": " .. tostring(err))
    end
end

--[[
    StartAutoSave(player, getData, intervalSeconds)

    getData         : function() → table  — retourne les données actuelles du joueur
    intervalSeconds : number (optionnel)  — intervalle en secondes (défaut : 60)
--]]
function DataStoreManager.StartAutoSave(player, getData, intervalSeconds)
    local interval = intervalSeconds or 60
    task.spawn(function()
        while player.Parent do
            task.wait(interval)
            if player.Parent then
                DataStoreManager.Save(player, getData())
            end
        end
    end)
end

return DataStoreManager
