-- shared-lib/server/AmelioSystem.lua
-- DobiGames — Système d'Amélioration de Base générique
--
-- Principe : le joueur paie des coins pour débloquer un slot supplémentaire
-- et augmenter son multiplicateur permanent.  Il ne perd ni ses brainrots
-- ni sa progression.
--
-- Callbacks à injecter depuis Main.server.lua :
--   AmelioSystem.Config         = require(...RebirthConfig)
--   AmelioSystem.OnLevelUp      = function(player, newLevel, cfg)
--   AmelioSystem.OnButtonUpdate = function(player, etat)

local AmelioSystem = {}

-- ============================================================
-- Services
-- ============================================================
local TweenService      = game:GetService("TweenService")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ============================================================
-- Dépendances
-- ============================================================
local Logger = require(script.Parent.Logger)

-- ============================================================
-- Callbacks injectés par Main.server.lua
-- ============================================================

-- Table de config des niveaux (RebirthConfig depuis GameConfig)
AmelioSystem.Config = nil

-- Appelé après chaque amélioration réussie
-- function(player, newLevel, cfg)
AmelioSystem.OnLevelUp = nil

-- Appelé à chaque envoi de RebirthButtonUpdate (boucle 5s + après collectes)
-- function(player, etat)
AmelioSystem.OnButtonUpdate = nil

-- ============================================================
-- Helpers config
-- ============================================================

local MAX_LEVEL = 30

local function obtenirConfig(niveau)
    local cfg = AmelioSystem.Config
    return cfg and cfg[niveau] or nil
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

local function niveauActuel(playerData)
    return playerData.rebirthLevel or 0
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
-- Vérification des conditions (coins uniquement)
-- ============================================================

function AmelioSystem.VerifierConditions(player)
    local data = getData(player)
    if not data then return false, { erreur = "Données introuvables" } end

    local niveau = niveauActuel(data) + 1
    if niveau > MAX_LEVEL then
        return false, { maxAtteint = true }
    end

    local cfg = obtenirConfig(niveau)
    if not cfg then return false, { erreur = "Config introuvable" } end

    local manques = {}
    local ok      = true

    if (data.coins or 0) < cfg.coinsRequis then
        ok = false
        manques.manqueCoins = cfg.coinsRequis - (data.coins or 0)
    end

    return ok, manques
end

-- ============================================================
-- Mise à jour du bouton côté client
-- ============================================================

local function envoyerEtatBouton(player)
    local data = getData(player)
    if not data then return end

    local niveau    = niveauActuel(data)
    local prochain  = niveau + 1
    local maxAtteint = niveau >= MAX_LEVEL

    local cfg = obtenirConfig(prochain)
    local ok, manques = AmelioSystem.VerifierConditions(player)

    local etat = {
        disponible     = ok,
        maxAtteint     = maxAtteint,
        prochainLevel  = prochain,
        coinsActuels   = data.coins or 0,
        coinsRequis    = cfg and cfg.coinsRequis or 0,
        manqueCoins    = manques.manqueCoins or 0,
        rebirthLevel   = niveau,
        multiplicateur = cfg and cfg.multiplicateur or (data.multiplicateurPermanent or 1.0),
    }

    pcall(function() RebirthButtonUpdate:FireClient(player, etat) end)

    if AmelioSystem.OnButtonUpdate then
        pcall(AmelioSystem.OnButtonUpdate, player, etat)
    end
end

-- ============================================================
-- Effets visuels serveur (particules dorées)
-- ============================================================

local function effetExplosion(player)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local ancre = Instance.new("Part")
    ancre.Name         = "BaseImproveFX_" .. player.UserId
    ancre.Size         = Vector3.new(1, 1, 1)
    ancre.Position     = hrp.Position
    ancre.Anchored     = true
    ancre.CanCollide   = false
    ancre.Transparency = 1
    ancre.Parent       = game:GetService("Workspace")

    local emitter = Instance.new("ParticleEmitter")
    emitter.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   Color3.fromRGB(100, 220, 120)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(60,  180, 80 )),
        ColorSequenceKeypoint.new(1,   Color3.fromRGB(40,  120, 60 )),
    })
    emitter.LightEmission = 0.8
    emitter.Rate          = 150
    emitter.Lifetime      = NumberRange.new(1.0, 2.5)
    emitter.Speed         = NumberRange.new(10, 25)
    emitter.SpreadAngle   = Vector2.new(180, 180)
    emitter.Size          = NumberSequence.new({
        NumberSequenceKeypoint.new(0,   0.5),
        NumberSequenceKeypoint.new(0.5, 0.8),
        NumberSequenceKeypoint.new(1,   0),
    })
    emitter.Parent = ancre

    local light = Instance.new("PointLight")
    light.Brightness = 6
    light.Range      = 40
    light.Color      = Color3.fromRGB(80, 220, 100)
    light.Parent     = ancre

    emitter:Emit(80)
    task.spawn(function()
        TweenService:Create(light,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { Brightness = 0 }
        ):Play()
    end)
    task.delay(3, function()
        emitter.Enabled = false
        task.delay(2.5, function()
            if ancre and ancre.Parent then ancre:Destroy() end
        end)
    end)
end

-- ============================================================
-- Séquence d'amélioration
-- ============================================================

local function executerAmelioration(player)
    local dd = donneesJoueurs[player.UserId]
    if not dd then return end
    if dd.enCoursDeRebirth then return end
    dd.enCoursDeRebirth = true

    local data      = dd.playerData
    local baseIndex = dd.baseIndex
    local niveau    = niveauActuel(data) + 1
    local cfg       = obtenirConfig(niveau)

    if not cfg then
        dd.enCoursDeRebirth = false
        return
    end

    -- Étape 1 : Déduire les coins
    data.coins = math.max(0, (data.coins or 0) - cfg.coinsRequis)

    -- Étape 2 : Appliquer les récompenses permanentes
    data.rebirthLevel             = niveau
    data.multiplicateurPermanent  = cfg.multiplicateur
    data.slotsBonus               = (data.slotsBonus or 0) + cfg.slotsBonus

    -- Étape 3 : Animation client + particules serveur
    pcall(function()
        RebirthAnimation:FireClient(player, {
            niveau         = niveau,
            label          = cfg.label,
            multiplicateur = cfg.multiplicateur,
        })
    end)
    task.spawn(effetExplosion, player)

    -- Étape 4 : Notification personnelle (pas de notification globale)
    local notif = getNotifEvent()
    if notif then
        local msg = string.format(
            "Base améliorée au niveau %d ! ×%.1f multiplicateur · +1 slot",
            niveau, cfg.multiplicateur
        )
        pcall(function() notif:FireClient(player, "AMELIORATION", msg) end)
    end

    -- Étape 5 : Callback game-specific (ex. ajouter slot LavaTower, refresh BRF)
    if AmelioSystem.OnLevelUp then
        pcall(AmelioSystem.OnLevelUp, player, niveau, cfg)
    end

    -- Étape 6 : Mettre à jour le HUD et le bouton
    local updateHUD = getUpdateHUD()
    if updateHUD then
        pcall(function() updateHUD:FireClient(player, data) end)
    end

    task.wait(0.3)
    envoyerEtatBouton(player)

    Logger.info("AmelioBase", "%s → Amélioration %d (×%.1f, +%d slot)",
        player.Name, niveau, cfg.multiplicateur, cfg.slotsBonus)

    dd.enCoursDeRebirth = false
end

-- ============================================================
-- Gestionnaire de la demande client
-- ============================================================

-- Token requis pour distinguer un clic manuel d'un fire automatique
-- (un ancien script sans token sera ignoré silencieusement)
local AMELIO_TOKEN = "AMELIO_MANUEL"

DemandeRebirth.OnServerEvent:Connect(function(player, token)
    -- Rejeter tout fire qui ne vient pas du bouton Board officiel
    if token ~= AMELIO_TOKEN then return end

    local dd = donneesJoueurs[player.UserId]
    if not dd or dd.enCoursDeRebirth then return end

    local ok, manques = AmelioSystem.VerifierConditions(player)
    if not ok then
        local notif = getNotifEvent()
        if notif then
            local msg
            if manques.maxAtteint then
                msg = "Votre base est déjà au niveau maximum !"
            elseif manques.manqueCoins and manques.manqueCoins > 0 then
                msg = formaterCoins(manques.manqueCoins) .. " coins manquants"
            else
                msg = "Conditions non remplies"
            end
            pcall(function() notif:FireClient(player, "ERREUR", msg) end)
        end
        return
    end

    task.spawn(executerAmelioration, player)
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

function AmelioSystem.Init(player, playerData, baseIndex)
    -- Valeurs par défaut — rétrocompatibles avec les saves existantes
    if playerData.rebirthLevel          == nil then playerData.rebirthLevel          = 0   end
    if playerData.multiplicateurPermanent == nil then playerData.multiplicateurPermanent = 1.0 end
    if playerData.slotsBonus            == nil then playerData.slotsBonus            = 0   end

    donneesJoueurs[player.UserId] = {
        playerData       = playerData,
        baseIndex        = baseIndex,
        enCoursDeRebirth = false,
    }

    if donneesJoueurs[player.UserId] then
        envoyerEtatBouton(player)
    end

    Logger.info("AmelioBase", "%s initialisé (base niv.%d, ×%.1f, +%d slots)",
        player.Name, playerData.rebirthLevel,
        playerData.multiplicateurPermanent, playerData.slotsBonus)
end

function AmelioSystem.GetMultiplicateur(player)
    local data = getData(player)
    return data and (data.multiplicateurPermanent or 1.0) or 1.0
end

function AmelioSystem.GetSlotsBonus(player)
    local data = getData(player)
    return data and (data.slotsBonus or 0) or 0
end

function AmelioSystem.Reset(player)
    donneesJoueurs[player.UserId] = nil
end

function AmelioSystem.MettreAJourBouton(player)
    if donneesJoueurs[player.UserId] then
        pcall(envoyerEtatBouton, player)
    end
end

return AmelioSystem
