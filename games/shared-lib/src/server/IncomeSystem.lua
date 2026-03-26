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

local _GameConfig  = require(game.ReplicatedStorage.Specialized.GameConfig)

-- ============================================================
-- Valeur de base par rareté (coins/sec par Brain Rot déposé)
-- ============================================================
local INCOME_PAR_RARETE = _GameConfig.IncomeParRarete

-- ============================================================
-- Multiplicateur d'event (partagé pour tous les joueurs)
-- Modifié par IncomeSystem.SetEventMultiplier (appelé par EventManager)
-- ============================================================
local eventMultiplier = 1

-- ============================================================
-- État interne par joueur
-- ============================================================
-- incomeCache[userId]      = coins/sec total calculé
-- threads[userId]          = coroutine de la boucle passive
-- getDataFns[userId]       = function() → playerData en mémoire (évite les références périmées)
-- coinsEnAttente[userId]   = { [spotKey] = coinsCumulés } — collecte manuelle (style Steal a Brainrot)
local incomeCache     = {}
local threads         = {}
local getDataFns      = {}
local coinsEnAttente  = {}

-- ============================================================
-- Chargement différé — évite dépendances circulaires
-- ============================================================
local _LeaderboardSystem = nil
local function getLeaderboardSystem()
    if not _LeaderboardSystem then
        local ok, m = pcall(require, ServerScriptService.Common.LeaderboardSystem)
        if ok and m then _LeaderboardSystem = m end
    end
    return _LeaderboardSystem
end

local _BaseProgressionSystem = nil
local function getBPS()
    if not _BaseProgressionSystem then
        local ok, m = pcall(require, game:GetService("ReplicatedStorage").SharedLib.Server.BaseProgressionSystem)
        if ok and m then _BaseProgressionSystem = m end
    end
    return _BaseProgressionSystem
end

local _DropSystem = nil
local function getDropSystem()
    if not _DropSystem then
        local ok, m = pcall(require, ReplicatedStorage.SharedLib.Server.DropSystem)
        if ok and m then _DropSystem = m end
    end
    return _DropSystem
end

-- ============================================================
-- Utilitaires visuels — SurfaceGui Studio existant ($amount / $offline)
-- Structure : spot_X / Button (Model) / TouchPart (Part) / Text (SurfaceGui)
-- ============================================================

local function FormatCoins(n)
    n = math.floor(n or 0)
    if     n >= 1e9  then return string.format("%.1fB", n / 1e9)
    elseif n >= 1e6  then return string.format("%.1fM", n / 1e6)
    elseif n >= 1e3  then return string.format("%.0fK", n / 1e3)
    else                  return tostring(n)
    end
end

-- Retourne la BasePart Button/TouchPart du spot (Part avec le SurfaceGui + Touched collecte)
-- spotModel = le Model spot_X parent direct des slots
local function GetButtonTouchPart(spotModel)
    local buttonModel = spotModel:FindFirstChild("Button")
    if not buttonModel then return nil end
    local tp = buttonModel:FindFirstChild("TouchPart")
    if tp and tp:IsA("BasePart") then return tp end
    return buttonModel:FindFirstChildWhichIsA("BasePart")
end

-- Retourne les TextBox $amount et $offline depuis le SurfaceGui "Text"
-- situé sur Button/TouchPart
local function GetTextLabels(spotModel)
    local tp = GetButtonTouchPart(spotModel)
    if not tp then return nil, nil end
    local surfGui = tp:FindFirstChild("Text")
    if not surfGui then return nil, nil end
    return surfGui:FindFirstChild("$amount"), surfGui:FindFirstChild("$offline")
end

-- Met à jour les TextBox $amount et $offline du SurfaceGui Studio
-- NE crée PAS de nouveaux SurfaceGui — utilise uniquement ceux posés dans Studio
-- touchPart = ProximityPrompt TouchPart (outer) ; son parent = spotModel
local function mettreAJourVisuel(touchPart, montant, incomeParSeconde)
    if not touchPart or not touchPart.Parent then return end
    local spotModel = touchPart.Parent

    local lblAmount, lblOffline = GetTextLabels(spotModel)

    -- $amount : montant accumulé (caché si 0)
    if lblAmount then
        pcall(function()
            lblAmount.Text    = "$" .. FormatCoins(montant or 0)
            lblAmount.Visible = (montant or 0) > 0
        end)
    end

    -- $offline : revenu par seconde (toujours visible — $0/s quand slot vide)
    if lblOffline and incomeParSeconde ~= nil then
        pcall(function()
            lblOffline.Text    = "Earns $" .. FormatCoins(incomeParSeconde) .. "/s"
            lblOffline.Visible = true
        end)
    end
end

-- Connecte le Touched de Button/TouchPart pour la collecte manuelle
-- Garde : CollectConnected BoolValue sur buttonTouchPart pour éviter la double connexion.
-- touchPart = ProximityPrompt TouchPart (outer) ; son parent = spotModel
local function connecterButton(player, uid, touchPart, spotKey)
    if not touchPart or not touchPart.Parent then return end
    local spotModel = touchPart.Parent

    -- Trouver Button/TouchPart (Part avec SurfaceGui + Touched collecte)
    local buttonTouchPart = GetButtonTouchPart(spotModel)
    if not buttonTouchPart then
        warn("[IncomeSystem] Button/TouchPart introuvable : " .. spotModel:GetFullName())
        return
    end

    -- Éviter double connexion
    if buttonTouchPart:FindFirstChild("CollectConnected") then return end
    local tag = Instance.new("BoolValue", buttonTouchPart)
    tag.Name  = "CollectConnected"

    local debounce = false

    buttonTouchPart.Touched:Connect(function(hit)
        if debounce then return end
        local character   = hit.Parent
        local touchPlayer = Players:GetPlayerFromCharacter(character)
        -- Seul le propriétaire de la base collecte
        if not touchPlayer or touchPlayer.UserId ~= uid then return end

        local pending = (coinsEnAttente[uid] or {})[spotKey] or 0
        if pending <= 0 then return end

        debounce = true

        -- Créditer les coins
        local getData = getDataFns[uid]
        if getData then
            local pd = getData()
            if pd then
                pd.coins            = (pd.coins or 0) + pending
                pd.totalCoinsGagnes = (pd.totalCoinsGagnes or 0) + pending

                -- Notification au joueur
                local notif = ReplicatedStorage:FindFirstChild("NotifEvent")
                if notif then
                    pcall(function()
                        notif:FireClient(touchPlayer, "SUCCESS",
                            "💰 +" .. FormatCoins(pending) .. " coins!")
                    end)
                end
                -- Mise à jour HUD immédiate
                local UpdateHUD = ReplicatedStorage:FindFirstChild("UpdateHUD")
                if UpdateHUD then
                    pcall(function() UpdateHUD:FireClient(touchPlayer, pd) end)
                end
            end
        end

        -- Réinitialiser accumulateur + reset $amount dans le SurfaceGui Studio
        if coinsEnAttente[uid] then coinsEnAttente[uid][spotKey] = 0 end
        pcall(mettreAJourVisuel, touchPart, 0, nil)

        print("[IncomeSystem] " .. touchPlayer.Name
            .. " collecte $" .. FormatCoins(pending) .. " → slot " .. spotKey)

        task.delay(0.5, function() debounce = false end)
    end)

    print("[IncomeSystem] Button/TouchPart connecté → slot " .. spotKey)
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
        -- Multiplicateur Mutant : vérifier MutantTag sur le mini modèle du spot
        local mutantMult = 1
        if spot.touchPart and spot.touchPart.Parent then
            for _, child in ipairs(spot.touchPart.Parent:GetChildren()) do
                local tag = child:FindFirstChild("MutantTag")
                if tag then
                    mutantMult = tonumber(tag.Value) or 1
                    break
                end
            end
            -- Fallback : vérifier directement sous touchPart
            if mutantMult == 1 then
                local tag = spot.touchPart:FindFirstChild("MutantTag", true)
                if tag then mutantMult = tonumber(tag.Value) or 1 end
            end
        end
        total = total + base * mutantMult
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
-- Mise à jour du $offline sur les spots (revenu/s après recalcul multiplicateurs)
-- $amount est géré par l'accumulateur — ne pas l'écraser ici
-- ============================================================

local function mettreAJourGuiSpots(spotsTable, multTotal)
    for _, spot in ipairs(spotsTable) do
        local tp = spot.touchPart
        if not tp or not tp.Parent then continue end
        local spotModel = tp.Parent

        local baseValeur   = INCOME_PAR_RARETE[spot.rarete] or 0
        local valeurReelle = math.floor(baseValeur * multTotal)

        -- Mettre à jour uniquement $offline (revenu/s affiché en permanence)
        local _, lblOffline = GetTextLabels(spotModel)
        if not lblOffline then continue end

        pcall(function()
            lblOffline.Text    = "Earns $" .. FormatCoins(valeurReelle) .. "/s"
            lblOffline.Visible = true
        end)
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

            -- ── Accumulation manuelle par slot (style Steal a Brainrot) ──────────
            -- Les coins s'affichent sur le BillboardGui vert ; le joueur marche
            -- sur la CollectPart pour les récupérer.  Pas de crédit automatique.
            local DS         = getDropSystem()
            local spotsTable = DS and DS.GetSpotsOccupes(player) or {}
            local revenuTotal = 0

            if not coinsEnAttente[uid] then coinsEnAttente[uid] = {} end

            local multRebirth = playerData.multiplicateurPermanent or 1.0
            local multVIP     = playerData.hasVIP and 2 or 1

            for _, spot in ipairs(spotsTable) do
                local base = INCOME_PAR_RARETE[spot.rarete] or 0
                if base > 0 then
                    local incomeSpot = math.floor(
                        base * multRebirth * multVIP * eventMultiplier)
                    if incomeSpot > 0 then
                        coinsEnAttente[uid][spot.spotKey] =
                            (coinsEnAttente[uid][spot.spotKey] or 0) + incomeSpot
                        revenuTotal = revenuTotal + incomeSpot

                        -- Mettre à jour $amount dans le BillboardGui Studio
                        pcall(mettreAJourVisuel,
                            spot.touchPart,
                            coinsEnAttente[uid][spot.spotKey],
                            spot.valeurSec)

                        -- Connecter Button.Touched si pas encore fait
                        if spot.touchPart and spot.touchPart.Parent then
                            connecterButton(player, uid, spot.touchPart, spot.spotKey)
                        end
                    end
                end
            end

            -- Mettre à jour le cache income (pour GetIncomeParSeconde + offline income)
            incomeCache[uid]          = revenuTotal
            playerData.coinsParMinute = revenuTotal * 60
            -- NOTE : playerData.coins est incrémenté uniquement via CollectPart.Touched

            tickHUD         = tickHUD + 1
            tickProgression = tickProgression + 1

            -- Mise à jour HUD toutes les 5 secondes
            if tickHUD >= 5 then
                tickHUD = 0
                local UpdateHUD = ReplicatedStorage:FindFirstChild("UpdateHUD")
                if UpdateHUD then
                    pcall(function() UpdateHUD:FireClient(player, playerData) end)
                end
                -- Notifier le leaderboard de la mise à jour
                local LS = getLeaderboardSystem()
                if LS then
                    pcall(LS.MettreAJour, player, playerData)
                end
            end

            -- Vérification progression toutes les 10 secondes
            if tickProgression >= 10 then
                tickProgression = 0
                local BPS = getBPS()
                if BPS and revenuTotal > 0 then
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
    incomeCache[uid]    = nil
    getDataFns[uid]     = nil
    coinsEnAttente[uid] = nil
end

-- ============================================================
-- API publique — Visuels slots
-- ============================================================

-- Remet à zéro les visuels $amount/$offline + tag CollectConnected du slot
-- Crédite automatiquement les coins en attente avant la suppression (Retrieve, Sell, Eject)
-- Appelé par DropSystem lors d'un Retrieve, Sell ou Eject
function IncomeSystem.SupprimerSlotVisuel(player, touchPart, spotKey)
    local uid = player.UserId

    -- Créditer les coins en attente avant suppression (pas de coins perdus)
    if coinsEnAttente[uid] and spotKey then
        local pending = coinsEnAttente[uid][spotKey] or 0
        if pending > 0 then
            local getData = getDataFns[uid]
            if getData then
                local pd = getData()
                if pd then
                    pd.coins            = (pd.coins or 0) + pending
                    pd.totalCoinsGagnes = (pd.totalCoinsGagnes or 0) + pending
                end
            end
        end
        coinsEnAttente[uid][spotKey] = nil
    end

    if not touchPart or not touchPart.Parent then return end
    local spotModel = touchPart.Parent

    -- Reset visuel : $amount = 0, $offline = 0
    pcall(mettreAJourVisuel, touchPart, 0, 0)

    -- Supprimer le tag CollectConnected sur Button/TouchPart
    -- (permet re-connexion lors du prochain dépôt sur ce slot)
    local buttonTouchPart = GetButtonTouchPart(spotModel)
    if buttonTouchPart then
        local tag = buttonTouchPart:FindFirstChild("CollectConnected")
        if tag then pcall(function() tag:Destroy() end) end
    end
end

-- Collecte les coins en attente d'un slot et les crédite immédiatement
-- Appelé avant Sell pour ne pas perdre les coins accumulés
function IncomeSystem.CollecterSlot(player, spotKey)
    local uid = player.UserId
    if not coinsEnAttente[uid] then return end
    local montant = coinsEnAttente[uid][spotKey] or 0
    if montant <= 0 then return end

    local getData = getDataFns[uid]
    if getData then
        local pd = getData()
        if pd then
            pd.coins            = (pd.coins or 0) + montant
            pd.totalCoinsGagnes = (pd.totalCoinsGagnes or 0) + montant
        end
    end
    coinsEnAttente[uid][spotKey] = 0
    print("[IncomeSystem] Slot " .. spotKey .. " collecté avant vente : $" .. FormatCoins(montant))
end

-- Connecte manuellement le Button d'un slot pour la collecte
-- Appelé par DropSystem après un dépôt pour une réactivité immédiate
function IncomeSystem.ConnecterButton(player, touchPart, spotKey)
    local uid = player.UserId
    connecterButton(player, uid, touchPart, spotKey)
end

-- Met à jour les TextLabels $amount et $offline du BillboardGui Studio
-- Appelé par DropSystem après un dépôt (initialiser $offline) ou reset
function IncomeSystem.MettreAJourVisuel(touchPart, montant, incomeParSeconde)
    mettreAJourVisuel(touchPart, montant, incomeParSeconde)
end

-- Ajoute des coins directement au joueur (utilisé par VendreBR dans DropSystem)
function IncomeSystem.AjouterCoins(player, montant)
    if montant <= 0 then return end
    local uid    = player.UserId
    local getData = getDataFns[uid]
    if not getData then return end
    local pd = getData()
    if not pd then return end
    pd.coins            = (pd.coins or 0) + montant
    pd.totalCoinsGagnes = (pd.totalCoinsGagnes or 0) + montant

    -- Mise à jour HUD
    local UpdateHUD = ReplicatedStorage:FindFirstChild("UpdateHUD")
    if UpdateHUD then
        pcall(function() UpdateHUD:FireClient(player, pd) end)
    end
end

return IncomeSystem
