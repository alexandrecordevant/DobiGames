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
-- Utilitaires visuels — BillboardGui Studio existant ($amount / $offline)
-- ============================================================

local function FormatCoins(n)
    n = math.floor(n or 0)
    if     n >= 1e9  then return string.format("%.1fB", n / 1e9)
    elseif n >= 1e6  then return string.format("%.1fM", n / 1e6)
    elseif n >= 1e3  then return string.format("%.0fK", n / 1e3)
    else                  return tostring(n)
    end
end

-- Remonte au Model spot depuis une touchPart
-- Gère les cas : Part dans Button(Model), BasePart directe dans spot, etc.
local function trouverSpotModel(touchPart)
    if not touchPart or not touchPart.Parent then return nil end
    local parent = touchPart.Parent
    -- Si parent est un sous-modèle intermédiaire ("Button" ou "TouchPart"), remonter
    if parent:IsA("Model") and (parent.Name == "TouchPart" or parent.Name == "Button") then
        return parent.Parent
    end
    return parent
end

-- Trouve la BasePart du Button (Part verte — Touched déclenche la collecte)
-- Chemins : 1) touchPart est déjà dans Button → c'est elle-même
--           2) spotModel/Button(Model)/BasePart
local function trouverButtonPart(touchPart)
    if not touchPart or not touchPart.Parent then return nil end
    -- Chemin 1 : touchPart est la Part à l'intérieur du Model "Button"
    if touchPart.Parent:IsA("Model") and touchPart.Parent.Name == "Button" then
        return touchPart
    end
    -- Chemin 2 : chercher Button dans le spotModel
    local spotModel = trouverSpotModel(touchPart)
    if not spotModel then return nil end
    local btn = spotModel:FindFirstChild("Button")
    if not btn then return nil end
    if btn:IsA("BasePart") then return btn end
    return btn:FindFirstChildWhichIsA("BasePart")
end

-- Trouve le BillboardGui contenant $amount/$offline
-- Chemins : 1) "Text" enfant direct de touchPart (structure legacy)
--           2) spotModel/TouchPart(Model ou BasePart)/Text(BillboardGui)
--           3) premier BillboardGui descendant du spotModel (fallback)
local function trouverBillboard(touchPart)
    if not touchPart or not touchPart.Parent then return nil end
    -- Chemin 1 : Text directement sur touchPart (structure legacy TouchPart/Text)
    local bb = touchPart:FindFirstChild("Text")
           or touchPart:FindFirstChildOfClass("BillboardGui")
    if bb then return bb end
    -- Chemin 2 : via spotModel → child "TouchPart"
    local spotModel = trouverSpotModel(touchPart)
    if spotModel then
        local tpChild = spotModel:FindFirstChild("TouchPart")
        if tpChild then
            bb = tpChild:FindFirstChild("Text")
              or tpChild:FindFirstChildOfClass("BillboardGui")
            if bb then return bb end
        end
        -- Chemin 3 : premier BillboardGui n'importe où dans le spot
        bb = spotModel:FindFirstChildOfClass("BillboardGui", true)
        if bb then return bb end
    end
    return nil
end

-- Met à jour les TextLabels $amount et $offline du BillboardGui Studio
-- NE crée PAS de nouveaux BillboardGui — utilise uniquement ceux posés dans Studio
-- Recherche récursive pour $amount/$offline (tolère un Frame intermédiaire)
local function mettreAJourVisuel(touchPart, montant, incomeParSeconde)
    local bb = trouverBillboard(touchPart)
    if not bb then
        warn("[IncomeSystem] BillboardGui introuvable pour : "
            .. tostring(touchPart and touchPart:GetFullName()))
        return
    end

    -- Recherche récursive — tolère Frame intermédiaire dans le BillboardGui
    local lblAmount  = bb:FindFirstChild("$amount",  true)
    local lblOffline = bb:FindFirstChild("$offline", true)

    -- $amount : montant accumulé (caché si 0)
    if lblAmount then
        pcall(function()
            lblAmount.Text    = "$" .. FormatCoins(montant or 0)
            lblAmount.Visible = (montant or 0) > 0
        end)
    end

    -- $offline : revenu par seconde (affiché dès qu'un BR est déposé)
    if lblOffline and incomeParSeconde ~= nil then
        pcall(function()
            lblOffline.Text    = "$" .. FormatCoins(incomeParSeconde) .. "/s"
            lblOffline.Visible = incomeParSeconde > 0
        end)
    end

    -- Activer le billboard si income actif ou montant en attente
    pcall(function()
        bb.Enabled = ((montant or 0) > 0)
            or (incomeParSeconde ~= nil and incomeParSeconde > 0)
    end)
end

-- Connecte le Touched de la BasePart dans le Model "Button" pour la collecte manuelle
-- Garde : CollectConnected BoolValue sur buttonPart pour éviter la double connexion.
local function connecterButton(player, uid, touchPart, spotKey)
    if not touchPart or not touchPart.Parent then return end

    -- Trouver la BasePart du Button (peut être touchPart elle-même si elle est dans Button)
    local buttonPart = trouverButtonPart(touchPart)
    if not buttonPart then
        warn("[IncomeSystem] Button BasePart introuvable pour slot "
            .. tostring(spotKey) .. " → " .. tostring(touchPart:GetFullName()))
        return
    end

    -- Éviter double connexion
    if buttonPart:FindFirstChild("CollectConnected") then return end
    local tag = Instance.new("BoolValue", buttonPart)
    tag.Name  = "CollectConnected"

    local debounce = false

    buttonPart.Touched:Connect(function(hit)
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

        -- Réinitialiser accumulateur + reset $amount dans le BillboardGui Studio
        if coinsEnAttente[uid] then coinsEnAttente[uid][spotKey] = 0 end
        pcall(mettreAJourVisuel, touchPart, 0, nil)

        print("[IncomeSystem] " .. touchPlayer.Name
            .. " collecte $" .. FormatCoins(pending) .. " → slot " .. spotKey)

        task.delay(0.5, function() debounce = false end)
    end)

    print("[IncomeSystem] Button connecté → slot " .. spotKey)
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

        local baseValeur   = INCOME_PAR_RARETE[spot.rarete] or 0
        local valeurReelle = math.floor(baseValeur * multTotal)

        -- Utiliser le BillboardGui "Text" existant dans le Model TouchPart
        local bb = trouverBillboard(tp)
        if not bb then continue end

        -- Mettre à jour uniquement $offline (revenu/s affiché en permanence)
        local offlineLabel = bb:FindFirstChild("$offline")
        if offlineLabel then
            pcall(function()
                offlineLabel.Text    = "$" .. FormatCoins(valeurReelle) .. "/s"
                offlineLabel.Visible = valeurReelle > 0
            end)
        end

        -- Activer le billboard si income actif (même si $amount = 0)
        if valeurReelle > 0 then
            pcall(function() bb.Enabled = true end)
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

    if not touchPart then return end

    -- Reset visuel : $amount = 0, $offline = 0, billboard caché
    pcall(mettreAJourVisuel, touchPart, 0, 0)

    -- Supprimer le tag CollectConnected sur la BasePart du Button
    -- (permet re-connexion lors du prochain dépôt sur ce slot)
    local buttonPart = trouverButtonPart(touchPart)
    if buttonPart then
        local tag = buttonPart:FindFirstChild("CollectConnected")
        if tag then pcall(function() tag:Destroy() end) end
    end

    -- Compatibilité : IncomeBillboard dynamique créé par une session précédente
    local spotModel = trouverSpotModel(touchPart)
    if spotModel then
        local buttonModel = spotModel:FindFirstChild("Button")
        if buttonModel then
            local oldBB = buttonModel:FindFirstChild("IncomeBillboard")
            if oldBB then pcall(function() oldBB:Destroy() end) end
        end
    end

    -- Compatibilité : CollectPart créée par une session précédente
    local cp = touchPart:FindFirstChild("CollectPart")
    if cp then pcall(function() cp:Destroy() end) end
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
