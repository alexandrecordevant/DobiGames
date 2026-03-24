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
-- Utilitaires visuels — BillboardGui vert style Steal a Brainrot
-- ============================================================

local function FormatCoins(n)
    n = math.floor(n or 0)
    if     n >= 1e9  then return string.format("%.1fB", n / 1e9)
    elseif n >= 1e6  then return string.format("%.1fM", n / 1e6)
    elseif n >= 1e3  then return string.format("%.0fK", n / 1e3)
    else                  return tostring(n)
    end
end

-- Crée ou met à jour le BillboardGui vert sur un slot
local function creerOuMettreAJourPanneau(touchPart, montant, playerName)
    if not touchPart or not touchPart.Parent then return end

    local bb = touchPart:FindFirstChild("IncomeBillboard")
    if not bb then
        bb          = Instance.new("BillboardGui")
        bb.Name     = "IncomeBillboard"
        bb.Size     = UDim2.new(0, 180, 0, 80)
        bb.StudsOffset  = Vector3.new(0, 3, 0)
        bb.AlwaysOnTop  = false
        bb.MaxDistance  = 40
        bb.Parent       = touchPart

        -- Fond vert
        local fond = Instance.new("Frame", bb)
        fond.Name                   = "Fond"
        fond.Size                   = UDim2.new(1, 0, 1, 0)
        fond.BackgroundColor3       = Color3.fromRGB(50, 180, 50)
        fond.BackgroundTransparency = 0
        fond.BorderSizePixel        = 0
        Instance.new("UICorner", fond).CornerRadius = UDim.new(0, 8)

        local stroke = Instance.new("UIStroke", fond)
        stroke.Color     = Color3.fromRGB(0, 0, 0)
        stroke.Thickness = 3

        -- Montant (blanc gros)
        local lblM = Instance.new("TextLabel", fond)
        lblM.Name                   = "Montant"
        lblM.Size                   = UDim2.new(1, -10, 0.6, 0)
        lblM.Position               = UDim2.new(0, 5, 0, 2)
        lblM.BackgroundTransparency = 1
        lblM.TextColor3             = Color3.fromRGB(255, 255, 255)
        lblM.Font                   = Enum.Font.GothamBold
        lblM.TextScaled             = true
        local s1 = Instance.new("UIStroke", lblM)
        s1.Color     = Color3.fromRGB(0, 80, 0)
        s1.Thickness = 2

        -- Nom joueur (rouge)
        local lblN = Instance.new("TextLabel", fond)
        lblN.Name                   = "NomJoueur"
        lblN.Size                   = UDim2.new(1, -10, 0.4, 0)
        lblN.Position               = UDim2.new(0, 5, 0.6, 0)
        lblN.BackgroundTransparency = 1
        lblN.TextColor3             = Color3.fromRGB(220, 30, 30)
        lblN.Font                   = Enum.Font.GothamBold
        lblN.TextScaled             = true
        local s2 = Instance.new("UIStroke", lblN)
        s2.Color     = Color3.fromRGB(0, 0, 0)
        s2.Thickness = 1.5
    end

    local fond = bb:FindFirstChild("Fond")
    if fond then
        local lblM = fond:FindFirstChild("Montant")
        local lblN = fond:FindFirstChild("NomJoueur")
        if lblM then pcall(function() lblM.Text = "$" .. FormatCoins(montant) end) end
        if lblN then pcall(function() lblN.Text = playerName or ""             end) end
    end
end

-- Crée la CollectPart au sol sous le slot pour la collecte manuelle (Touched)
local function creerCollectPart(player, uid, touchPart, spotKey)
    if not touchPart or not touchPart.Parent then return end
    if touchPart:FindFirstChild("CollectPart") then return end  -- déjà créée

    local cp = Instance.new("Part")
    cp.Name         = "CollectPart"
    cp.Size         = Vector3.new(touchPart.Size.X, 0.2, touchPart.Size.Z)
    cp.CFrame       = touchPart.CFrame * CFrame.new(0, -(touchPart.Size.Y / 2 + 0.1), 0)
    cp.Transparency = 0.6
    cp.Color        = Color3.fromRGB(50, 200, 50)
    cp.Material     = Enum.Material.Neon
    cp.Anchored     = true
    cp.CanCollide   = false
    cp.Parent       = touchPart

    local debounce = false

    cp.Touched:Connect(function(hit)
        if debounce then return end
        local character  = hit.Parent
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

        -- Réinitialiser l'accumulateur et le panneau
        if coinsEnAttente[uid] then coinsEnAttente[uid][spotKey] = 0 end
        pcall(creerOuMettreAJourPanneau, touchPart, 0, touchPlayer.Name)

        print("[IncomeSystem] " .. touchPlayer.Name
            .. " collecte $" .. FormatCoins(pending) .. " → slot " .. spotKey)

        task.delay(0.5, function() debounce = false end)
    end)
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

                        -- Mise à jour du panneau vert
                        pcall(creerOuMettreAJourPanneau,
                            spot.touchPart,
                            coinsEnAttente[uid][spot.spotKey],
                            player.Name)

                        -- Créer CollectPart si absente
                        if spot.touchPart and spot.touchPart.Parent
                            and not spot.touchPart:FindFirstChild("CollectPart") then
                            creerCollectPart(player, uid, spot.touchPart, spot.spotKey)
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
    incomeCache[uid]    = nil
    getDataFns[uid]     = nil
    coinsEnAttente[uid] = nil
end

-- ============================================================
-- API publique — Visuels slots
-- ============================================================

-- Supprime le BillboardGui vert + CollectPart d'un slot
-- Appelé par DropSystem lors d'un Retrieve, Sell ou Eject
function IncomeSystem.SupprimerSlotVisuel(player, touchPart, spotKey)
    local uid = player.UserId

    -- Remettre à zéro les coins en attente pour ce slot
    if coinsEnAttente[uid] and spotKey then
        coinsEnAttente[uid][spotKey] = nil
    end

    if not touchPart then return end
    local bb = touchPart:FindFirstChild("IncomeBillboard")
    if bb then pcall(function() bb:Destroy() end) end
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
