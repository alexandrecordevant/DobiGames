-- shared-lib/server/RebirthSystem.lua
-- DobiGames — Système de Rebirth générique
-- Reset volontaire contre multiplicateur permanent + slots bonus
-- Conditions : coins + Brain Rot rare spécifique
-- Callbacks à injecter depuis Main.server.lua :
--   RebirthSystem.Config               = GameConfig.RebirthConfig
--   RebirthSystem.IsProgressionComplete = function(playerData) → bool
--   RebirthSystem.OnRebirthComplete     = function(player, niveau, cfg)

local RebirthSystem = {}

-- ============================================================
-- Services
-- ============================================================
local TweenService      = game:GetService("TweenService")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ============================================================
-- Dépendances
-- ============================================================
local BaseProgressionSystem = require(ReplicatedStorage.SharedLib.Server.BaseProgressionSystem)

-- ============================================================
-- Callbacks injectés par Main.server.lua
-- ============================================================

-- Table de config des niveaux de rebirth (RebirthConfig depuis GameConfig)
RebirthSystem.Config = nil

-- Retourne true si le joueur a atteint la progression maximale requise
-- Exemple Farm : function(data) return data.progression["4_10"] == true end
RebirthSystem.IsProgressionComplete = nil

-- Appelé après la séquence complète (Discord, analytics, etc.)
-- function(player, niveau, cfg)
RebirthSystem.OnRebirthComplete = nil

-- ============================================================
-- Config des niveaux
-- ============================================================

-- Lit REBIRTH_CONFIG depuis RebirthSystem.Config (injecté par Main)
-- Niveaux 5+ : exponentiel, basé sur le dernier BR requis dans la config
local function obtenirConfig(niveau)
    local cfg = RebirthSystem.Config
    if cfg and cfg[niveau] then
        return cfg[niveau]
    end
    -- Fallback exponentiel pour les niveaux très élevés (5+)
    -- Utilise le BR requis du niveau 4 si disponible, sinon "BRAINROT_GOD"
    local fallbackBR = (cfg and cfg[4] and cfg[4].brainRotRequis)
        or { rarete = "BRAINROT_GOD", quantite = 1 }
    local extra = niveau - 4
    return {
        coinsRequis    = 2000000 * (2 ^ extra),
        brainRotRequis = fallbackBR,
        multiplicateur = 5.0 + (1.5 * extra),
        slotsBonus     = 5,
        label          = "Rebirth " .. tostring(niveau),
        couleur        = Color3.fromRGB(255, 255, 255),
        couleurHex     = 16777215,
    }
end

-- ============================================================
-- RemoteEvents
-- ============================================================
local function creerOuRecuperer(classe, nom)
    local existing = ReplicatedStorage:FindFirstChild(nom)
    if existing then return existing end
    local inst = Instance.new(classe)
    inst.Name   = nom
    inst.Parent = ReplicatedStorage
    return inst
end

local RebirthButtonUpdate = creerOuRecuperer("RemoteEvent", "RebirthButtonUpdate")
local DemandeRebirth      = creerOuRecuperer("RemoteEvent", "DemandeRebirth")
local RebirthAnimation    = creerOuRecuperer("RemoteEvent", "RebirthAnimation")

local function getNotifEvent() return ReplicatedStorage:FindFirstChild("NotifEvent") end
local function getUpdateHUD()  return ReplicatedStorage:FindFirstChild("UpdateHUD")  end

-- ============================================================
-- État interne par joueur
-- ============================================================
local donneesJoueurs = {}

local function getData(player)
    local dd = donneesJoueurs[player.UserId]
    return dd and dd.playerData or nil
end

local function getBaseIndex(player)
    local dd = donneesJoueurs[player.UserId]
    return dd and dd.baseIndex or nil
end

-- ============================================================
-- Utilitaires
-- ============================================================

local function aAtteintProgressionMax(playerData)
    if not RebirthSystem.IsProgressionComplete then return false end
    return RebirthSystem.IsProgressionComplete(playerData) == true
end

local function niveauActuel(playerData)
    return playerData.rebirthLevel or 0
end

local function prochainNiveau(playerData)
    return niveauActuel(playerData) + 1
end

local function formaterCoins(n)
    local s      = tostring(math.floor(n))
    local result = ""
    local count  = 0
    for i = #s, 1, -1 do
        if count > 0 and count % 3 == 0 then result = " " .. result end
        result = s:sub(i, i) .. result
        count  = count + 1
    end
    return result
end

-- ============================================================
-- Vérification des conditions
-- ============================================================

function RebirthSystem.VerifierConditions(player)
    local data = getData(player)
    if not data then return false, { erreur = "Données introuvables" } end

    local niveau  = prochainNiveau(data)
    local cfg     = obtenirConfig(niveau)
    local manques = {}
    local ok      = true

    local coins = data.coins or 0
    if coins < cfg.coinsRequis then
        ok = false
        manques.manqueCoins = cfg.coinsRequis - coins
    end

    local inv      = data.inventory or {}
    local rarete   = cfg.brainRotRequis.rarete
    local quantite = cfg.brainRotRequis.quantite
    local stock    = inv[rarete] or 0

    -- Vérifier aussi dans les slots déposés (spotsOccupes) — fix LEGENDARY non compté
    local spotsOccupes = data.spotsOccupes or {}
    for _, slotData in pairs(spotsOccupes) do
        if type(slotData) == "table" and slotData.rarete == rarete then
            stock = stock + 1
            print("[RebirthSystem] BR requis trouvé dans slot déposé : " .. rarete)
        end
    end

    if stock < quantite then
        ok = false
        manques.manqueBR       = rarete
        manques.manqueBRActuel = stock
        manques.manqueBRRequis = quantite
    end

    return ok, manques
end

-- ============================================================
-- Mise à jour du bouton Rebirth côté client
-- ============================================================

local function envoyerEtatBouton(player)
    local data = getData(player)
    if not data then return end

    local visible     = aAtteintProgressionMax(data)
    local niveau      = prochainNiveau(data)
    local cfg         = obtenirConfig(niveau)
    local ok, manques = RebirthSystem.VerifierConditions(player)

    local etat = {
        visible        = visible,
        disponible     = ok,
        prochainLevel  = niveau,
        coinsActuels   = data.coins or 0,
        coinsRequis    = cfg.coinsRequis,
        brainRotRequis = cfg.brainRotRequis.rarete,
        label          = cfg.label,
        couleur        = cfg.couleur,
        manqueCoins    = manques.manqueCoins or 0,
        manqueBR       = manques.manqueBR,
        manqueBRActuel = manques.manqueBRActuel or 0,
        manqueBRRequis = manques.manqueBRRequis or 0,
        rebirthLevel   = niveauActuel(data),
        multiplicateur = data.multiplicateurPermanent or 1.0,
    }

    pcall(function() RebirthButtonUpdate:FireClient(player, etat) end)
end

-- ============================================================
-- Effets visuels serveur (particules dorées)
-- ============================================================

local function effetExplosionRebirth(player)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local ancre = Instance.new("Part")
    ancre.Name         = "RebirthFX_" .. player.UserId
    ancre.Size         = Vector3.new(1, 1, 1)
    ancre.Position     = hrp.Position
    ancre.Anchored     = true
    ancre.CanCollide   = false
    ancre.Transparency = 1
    ancre.Parent       = game:GetService("Workspace")

    local emitter = Instance.new("ParticleEmitter")
    emitter.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   Color3.fromRGB(255, 255, 100)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 180,   0)),
        ColorSequenceKeypoint.new(1,   Color3.fromRGB(255, 100,   0)),
    })
    emitter.LightEmission = 1
    emitter.Rate          = 200
    emitter.Lifetime      = NumberRange.new(1.5, 3.5)
    emitter.Speed         = NumberRange.new(15, 30)
    emitter.SpreadAngle   = Vector2.new(180, 180)
    emitter.Size          = NumberSequence.new({
        NumberSequenceKeypoint.new(0,   0.6),
        NumberSequenceKeypoint.new(0.5, 1.0),
        NumberSequenceKeypoint.new(1,   0),
    })
    emitter.Parent = ancre

    local light = Instance.new("PointLight")
    light.Brightness = 8
    light.Range      = 50
    light.Color      = Color3.fromRGB(255, 220, 80)
    light.Parent     = ancre

    emitter:Emit(120)
    task.spawn(function()
        TweenService:Create(light,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { Brightness = 0 }
        ):Play()
    end)
    task.delay(4, function()
        emitter.Enabled = false
        task.delay(3.5, function()
            if ancre and ancre.Parent then ancre:Destroy() end
        end)
    end)
end

-- ============================================================
-- Séquence de Rebirth
-- ============================================================

local function executerRebirth(player)
    local dd = donneesJoueurs[player.UserId]
    if not dd then return end
    if dd.enCoursDeRebirth then return end
    dd.enCoursDeRebirth = true

    local data      = dd.playerData
    local baseIndex = dd.baseIndex
    local niveau    = prochainNiveau(data)
    local cfg       = obtenirConfig(niveau)

    -- Étape 1 : Consommer les ressources
    data.coins = 0
    local inv  = data.inventory or {}
    local rarete = cfg.brainRotRequis.rarete
    inv[rarete]  = math.max(0, (inv[rarete] or 0) - cfg.brainRotRequis.quantite)
    data.inventory    = inv
    data.rebirthLevel = niveau

    -- Étape 2 : Récompenses permanentes
    data.multiplicateurPermanent = cfg.multiplicateur
    data.slotsBonus = (data.slotsBonus or 0) + cfg.slotsBonus

    -- Étape 3 : Animation client + particules serveur
    pcall(function()
        RebirthAnimation:FireClient(player, {
            niveau   = niveau,
            label    = cfg.label,
            couleur  = cfg.couleur,
        })
    end)
    task.spawn(effetExplosionRebirth, player)

    -- Étape 4 : Notifications in-game
    local msgJoueur = string.format(
        "🔥 %s! Multiplier ×%.1f unlocked! +%d bonus slots",
        cfg.label, cfg.multiplicateur, cfg.slotsBonus
    )
    local msgTous = string.format(
        "⚡ %s just performed their %s! (×%.1f)",
        player.Name, cfg.label, cfg.multiplicateur
    )
    local notif = getNotifEvent()
    if notif then
        pcall(function() notif:FireClient(player, "REBIRTH", msgJoueur) end)
        pcall(function() notif:FireAllClients("REBIRTH_GLOBAL", msgTous) end)
    end

    -- Étape 5 : Reset progression + ré-init base
    task.wait(1.5)
    data.progression = {}
    BaseProgressionSystem.Reset(player)
    task.wait(0.1)
    BaseProgressionSystem.Init(player, baseIndex, data)

    -- Étape 6 : Mettre à jour le HUD
    local updateHUD = getUpdateHUD()
    if updateHUD then
        pcall(function() updateHUD:FireClient(player, data) end)
    end

    task.wait(0.5)
    envoyerEtatBouton(player)

    -- Callback externe (Discord, analytics…)
    if RebirthSystem.OnRebirthComplete then
        pcall(RebirthSystem.OnRebirthComplete, player, niveau, cfg)
    end

    print(string.format(
        "[RebirthSystem] %s → %s (×%.1f, +%d slots)",
        player.Name, cfg.label, cfg.multiplicateur, cfg.slotsBonus
    ))

    dd.enCoursDeRebirth = false
end

-- ============================================================
-- Gestionnaire de la demande client
-- ============================================================

DemandeRebirth.OnServerEvent:Connect(function(player)
    local dd = donneesJoueurs[player.UserId]
    if not dd or dd.enCoursDeRebirth then return end

    local data = dd.playerData

    if not aAtteintProgressionMax(data) then
        local notif = getNotifEvent()
        if notif then
            pcall(function()
                notif:FireClient(player, "ERREUR",
                    "Complete the full progression before performing a Rebirth!")
            end)
        end
        return
    end

    local ok, manques = RebirthSystem.VerifierConditions(player)
    if not ok then
        local parties = {}
        if manques.manqueCoins and manques.manqueCoins > 0 then
            table.insert(parties, "💰 " .. formaterCoins(manques.manqueCoins) .. " coins missing")
        end
        if manques.manqueBR then
            table.insert(parties, "🧬 1 " .. manques.manqueBR .. " missing in your inventory")
        end
        local notif = getNotifEvent()
        if notif then
            pcall(function()
                notif:FireClient(player, "ERREUR",
                    "Requirements not met: " .. table.concat(parties, " · "))
            end)
        end
        return
    end

    task.spawn(executerRebirth, player)
end)

-- ============================================================
-- Boucle de mise à jour du bouton (toutes les 5s)
-- ============================================================

task.spawn(function()
    while true do
        task.wait(5)
        for _, player in ipairs(Players:GetPlayers()) do
            if donneesJoueurs[player.UserId] then
                pcall(envoyerEtatBouton, player)
            end
        end
    end
end)

-- ============================================================
-- API publique
-- ============================================================

function RebirthSystem.Init(player, playerData, baseIndex)
    -- Champs requis avec valeurs par défaut
    if playerData.rebirthLevel         == nil then playerData.rebirthLevel         = 0   end
    if playerData.multiplicateurPermanent == nil then playerData.multiplicateurPermanent = 1.0 end
    if playerData.slotsBonus           == nil then playerData.slotsBonus           = 0   end
    if not playerData.inventory             then playerData.inventory              = {}  end

    donneesJoueurs[player.UserId] = {
        playerData       = playerData,
        baseIndex        = baseIndex,
        enCoursDeRebirth = false,
    }

    task.delay(2, function()
        if donneesJoueurs[player.UserId] then
            envoyerEtatBouton(player)
        end
    end)

    print(string.format(
        "[RebirthSystem] %s initialisé (Rebirth %d, ×%.1f, +%d slots)",
        player.Name,
        playerData.rebirthLevel,
        playerData.multiplicateurPermanent,
        playerData.slotsBonus
    ))
end

function RebirthSystem.GetMultiplicateur(player)
    local data = getData(player)
    return data and (data.multiplicateurPermanent or 1.0) or 1.0
end

function RebirthSystem.GetSlotsBonus(player)
    local data = getData(player)
    return data and (data.slotsBonus or 0) or 0
end

function RebirthSystem.Reset(player)
    donneesJoueurs[player.UserId] = nil
end

function RebirthSystem.MettreAJourBouton(player)
    if donneesJoueurs[player.UserId] then
        pcall(envoyerEtatBouton, player)
    end
end

return RebirthSystem
