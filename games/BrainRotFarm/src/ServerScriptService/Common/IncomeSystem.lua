-- ServerScriptService/Common/IncomeSystem.lua
-- DobiGames — Revenus passifs continus (coins/sec par BR déposé)
-- Boucle serveur : +income chaque seconde, HUD toutes les 5s, progression toutes les 10s

local IncomeSystem = {}

-- ============================================================
-- Services
-- ============================================================
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- ============================================================
-- TEST_MODE — multiplicateur income ×100 pour accélérer la progression
-- ============================================================
local _GameConfig  = require(game.ReplicatedStorage.Specialized.GameConfig)
local _TestConfig  = _GameConfig.TEST_MODE
    and require(game.ReplicatedStorage.Test.TestConfig)
    or nil
local _testIncomeMult = (_TestConfig and _TestConfig.IncomeMultiplier) or 1

-- ============================================================
-- Valeur de base par rareté (coins/sec par Brain Rot déposé)
-- Multipliée par _testIncomeMult en TEST_MODE (×100)
-- ============================================================
local INCOME_PAR_RARETE = {
    COMMON       = 1    * _testIncomeMult,
    OG           = 3    * _testIncomeMult,
    RARE         = 8    * _testIncomeMult,
    EPIC         = 20   * _testIncomeMult,
    LEGENDARY    = 60   * _testIncomeMult,
    MYTHIC       = 200  * _testIncomeMult,
    SECRET       = 500  * _testIncomeMult,
    BRAINROT_GOD = 2000 * _testIncomeMult,
}

-- ============================================================
-- Multiplicateur d'event (partagé pour tous les joueurs)
-- Modifié par IncomeSystem.SetEventMultiplier (appelé par EventManager)
-- ============================================================
local eventMultiplier = 1

-- ============================================================
-- État interne par joueur
-- ============================================================
-- incomeCache[userId]  = coins/sec total calculé
-- threads[userId]      = coroutine de la boucle passive
-- getDataFns[userId]   = function() → playerData en mémoire (évite les références périmées)
local incomeCache  = {}
local threads      = {}
local getDataFns   = {}

-- ============================================================
-- Chargement différé — évite dépendances circulaires
-- ============================================================
local _BaseProgressionSystem = nil
local function getBPS()
    if not _BaseProgressionSystem then
        local ok, m = pcall(require, ServerScriptService.Common.BaseProgressionSystem)
        if ok and m then _BaseProgressionSystem = m end
    end
    return _BaseProgressionSystem
end

local _DropSystem = nil
local function getDropSystem()
    if not _DropSystem then
        local ok, m = pcall(require, ServerScriptService.Common.DropSystem)
        if ok and m then _DropSystem = m end
    end
    return _DropSystem
end

-- ============================================================
-- Calcul du revenu par seconde
-- ============================================================

-- Calcule le revenu/sec total d'un joueur à partir d'une liste de spots
-- spotsTable = { { touchPart, rarete, valeurSec }, ... }
-- Si spotsTable est nil, interroge DropSystem directement
local function calculerRevenu(player, spotsTable, playerData)
    if not spotsTable then
        local DS = getDropSystem()
        spotsTable = DS and DS.GetSpotsOccupes(player) or {}
    end

    local total = 0
    for _, spot in ipairs(spotsTable) do
        local base = INCOME_PAR_RARETE[spot.rarete] or 0
        total = total + base
    end

    if total == 0 then return 0 end

    -- Multiplicateur rebirth permanent
    local multRebirth = (playerData and playerData.multiplicateurPermanent) or 1.0

    -- Multiplicateur VIP Game Pass (×2)
    local multVIP = (playerData and playerData.hasVIP) and 2 or 1

    -- Multiplicateur event en cours
    local multEvent = eventMultiplier

    return math.floor(total * multRebirth * multVIP * multEvent)
end

-- ============================================================
-- Mise à jour des SurfaceGui sur les spots
-- ============================================================

local function mettreAJourGuiSpots(spotsTable, multTotal)
    for _, spot in ipairs(spotsTable) do
        local tp = spot.touchPart
        if not tp or not tp.Parent then continue end

        local baseValeur = INCOME_PAR_RARETE[spot.rarete] or 0
        local valeurReelle = math.floor(baseValeur * multTotal)
        local valeurOffline = math.max(1, math.floor(valeurReelle * 0.1))

        local gui = tp:FindFirstChild("Text")
        if not gui then gui = tp:FindFirstChildOfClass("SurfaceGui") end
        if not gui then continue end

        local amountLabel  = gui:FindFirstChild("$amount")
        local offlineLabel = gui:FindFirstChild("$offline")

        if amountLabel  then
            pcall(function() amountLabel.Text  = "+" .. valeurReelle .. "/s" end)
        end
        if offlineLabel then
            pcall(function() offlineLabel.Text = "⏱ +" .. valeurOffline .. "/s" end)
        end
    end
end

-- ============================================================
-- Synchronisation playerData.spotsOccupes
-- Met à jour la structure DataStore-safe depuis DropSystem
-- ============================================================

local function syncSpotsOccupes(player, playerData)
    local DS = getDropSystem()
    if not DS then return end
    local serialisable = DS.GetSpotsOccupesSerialisables(player)
    playerData.spotsOccupes = serialisable
end

-- ============================================================
-- API publique — RecalculerIncome
-- Appelé par DropSystem après chaque dépôt / récupération
-- ============================================================

-- spotsTable optionnel — si absent, interroge DropSystem
function IncomeSystem.RecalculerIncome(player, spotsTable)
    local uid      = player.UserId
    local getData  = getDataFns[uid]
    if not getData then return end

    local playerData = getData()
    if not playerData then return end

    -- Calcul du multiplicateur composite (hors event, pour les GUI)
    local multRebirth = playerData.multiplicateurPermanent or 1.0
    local multVIP     = playerData.hasVIP and 2 or 1
    local multTotal   = multRebirth * multVIP * eventMultiplier

    -- Résoudre spotsTable si absent
    if not spotsTable then
        local DS = getDropSystem()
        spotsTable = DS and DS.GetSpotsOccupes(player) or {}
    end

    -- Calculer et mettre en cache le revenu/sec
    local revenu = calculerRevenu(player, spotsTable, playerData)
    incomeCache[uid] = revenu

    -- Mettre à jour coinsParMinute dans playerData (utilisé par offline income)
    playerData.coinsParMinute = revenu * 60

    -- Mettre à jour les SurfaceGui de chaque spot
    mettreAJourGuiSpots(spotsTable, multTotal)

    -- Synchroniser playerData.spotsOccupes pour le DataStore
    syncSpotsOccupes(player, playerData)
end

-- ============================================================
-- API publique — Init
-- Lance la boucle passive de revenus pour un joueur
-- ============================================================

-- getData = function() → playerData (même pattern que DataStoreManager.StartAutoSave)
function IncomeSystem.Init(player, getData)
    local uid = player.UserId

    -- Stopper une éventuelle boucle précédente
    IncomeSystem.Stop(player)

    getDataFns[uid]  = getData
    incomeCache[uid] = 0

    -- Calcul initial (au chargement, les spots déposés sont déjà restaurés par DropSystem)
    task.spawn(function()
        -- Attendre un tick pour que DropSystem ait fini de restaurer les spots
        task.wait(0.5)
        if not Players:FindFirstChild(player.Name) then return end
        IncomeSystem.RecalculerIncome(player, nil)
    end)

    -- Boucle passive : +income chaque seconde
    local thread = task.spawn(function()
        local tickHUD         = 0  -- compteur pour UpdateHUD toutes les 5s
        local tickProgression = 0  -- compteur pour VerifierDeblocages toutes les 10s

        while player.Parent do
            task.wait(1)

            local playerData = getData()
            if not playerData then break end

            local revenu = incomeCache[uid] or 0

            if revenu > 0 then
                -- Ajouter au solde et au total historique
                playerData.coins            = (playerData.coins or 0) + revenu
                playerData.totalCoinsGagnes = (playerData.totalCoinsGagnes or 0) + revenu
            end

            tickHUD         = tickHUD + 1
            tickProgression = tickProgression + 1

            -- Mise à jour HUD toutes les 5 secondes
            if tickHUD >= 5 then
                tickHUD = 0
                local UpdateHUD = ReplicatedStorage:FindFirstChild("UpdateHUD")
                if UpdateHUD then
                    pcall(function() UpdateHUD:FireClient(player, playerData) end)
                end
            end

            -- Vérification progression toutes les 10 secondes
            if tickProgression >= 10 then
                tickProgression = 0
                local BPS = getBPS()
                if BPS and revenu > 0 then
                    pcall(BPS.VerifierDeblocages, player, playerData)
                end
            end
        end

        -- Nettoyage en fin de boucle (joueur déconnecté)
        incomeCache[uid] = nil
        getDataFns[uid]  = nil
        threads[uid]     = nil
    end)

    threads[uid] = thread
    print("[IncomeSystem] ✓ Boucle démarrée pour " .. player.Name)
end

-- ============================================================
-- API publique — GetIncomeParSeconde
-- Utilisé par DataStoreManager pour le calcul offline income
-- ============================================================

function IncomeSystem.GetIncomeParSeconde(player)
    return incomeCache[player.UserId] or 0
end

-- ============================================================
-- API publique — SetEventMultiplier
-- Appelé par EventManager lors du déclenchement / fin d'un event
-- ============================================================

function IncomeSystem.SetEventMultiplier(multiplier)
    eventMultiplier = multiplier or 1

    -- Recalculer immédiatement pour tous les joueurs connectés
    for _, player in ipairs(Players:GetPlayers()) do
        task.spawn(function()
            IncomeSystem.RecalculerIncome(player, nil)
            -- Notifier les joueurs du changement
            local NotifEvent = ReplicatedStorage:FindFirstChild("NotifEvent")
            if NotifEvent then
                if multiplier > 1 then
                    pcall(function()
                        NotifEvent:FireClient(player, "EVENT",
                            "⚡ Multiplicateur event ×" .. multiplier .. " actif sur tes revenus !")
                    end)
                end
            end
        end)
    end

    print("[IncomeSystem] eventMultiplier → ×" .. tostring(eventMultiplier))
end

-- ============================================================
-- API publique — Stop
-- Appelé à la déconnexion du joueur
-- ============================================================

function IncomeSystem.Stop(player)
    local uid = player.UserId
    local thread = threads[uid]
    if thread then
        pcall(function() task.cancel(thread) end)
        threads[uid] = nil
    end
    incomeCache[uid] = nil
    getDataFns[uid]  = nil
end

return IncomeSystem
