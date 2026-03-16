-- ServerScriptService/RebirthSystem.lua
-- BrainRotFarm — Système de Rebirth
-- Reset volontaire contre multiplicateur permanent + slots bonus
-- Conditions : coins + Brain Rot rare spécifique
-- DobiGames · Validation serveur uniquement

local RebirthSystem = {}

-- ============================================================
-- Services
-- ============================================================
local TweenService        = game:GetService("TweenService")
local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- ============================================================
-- Dépendances
-- ============================================================
local DiscordWebhook         = require(ServerScriptService:WaitForChild("Common"):WaitForChild("DiscordWebhook"))
local BaseProgressionSystem  = require(ServerScriptService:WaitForChild("Common"):WaitForChild("BaseProgressionSystem"))

-- Config Test (override des conditions si TestConfig.RebirthConfig défini)
local _GameConfig = require(game.ReplicatedStorage.Specialized.GameConfig)
local _TestConfig = _GameConfig.TEST_MODE
    and require(game.ReplicatedStorage.Test.TestConfig)
    or nil

-- ============================================================
-- Configuration des Rebirths
-- Si TestConfig.RebirthConfig est défini il prend le dessus sur les valeurs réelles.
-- TestConfig.RebirthConfig = nil → valeurs de production ci-dessous.
-- ============================================================
local REBIRTH_CONFIG_REEL = {
    [1] = {
        coinsRequis    = 300000,
        brainRotRequis = { rarete = "LEGENDARY", quantite = 1 },
        multiplicateur = 1.5,
        slotsBonus     = 2,
        label          = "Rebirth I",
        couleur        = Color3.fromRGB(255, 200, 0),   -- doré
        couleurHex     = 16763904,                       -- 0xFFC800
    },
    [2] = {
        coinsRequis    = 500000,
        brainRotRequis = { rarete = "MYTHIC", quantite = 1 },
        multiplicateur = 2.0,
        slotsBonus     = 4,
        label          = "Rebirth II",
        couleur        = Color3.fromRGB(180, 50, 255),  -- violet
        couleurHex     = 11800319,                       -- 0xB432FF
    },
    [3] = {
        coinsRequis    = 1000000,
        brainRotRequis = { rarete = "SECRET", quantite = 1 },
        multiplicateur = 3.0,
        slotsBonus     = 6,
        label          = "Rebirth III",
        couleur        = Color3.fromRGB(255, 50, 50),   -- rouge
        couleurHex     = 16725042,                       -- 0xFF3232
    },
    [4] = {
        coinsRequis    = 2000000,
        brainRotRequis = { rarete = "BRAINROT_GOD", quantite = 1 },
        multiplicateur = 5.0,
        slotsBonus     = 10,
        label          = "Rebirth IV",
        couleur        = Color3.fromRGB(255, 255, 255), -- blanc divin
        couleurHex     = 16777215,                       -- 0xFFFFFF
    },
}

-- Sélection finale : TestConfig en priorité, sinon valeurs réelles
local REBIRTH_CONFIG = (_TestConfig and _TestConfig.RebirthConfig) or REBIRTH_CONFIG_REEL

-- Calcule la config d'un niveau de rebirth (5+ = exponentiel)
local function obtenirConfig(niveau)
    if REBIRTH_CONFIG[niveau] then
        return REBIRTH_CONFIG[niveau]
    end
    -- Niveaux 5+ : exponentiel
    local extra = niveau - 4
    return {
        coinsRequis    = 2000000 * (2 ^ extra),
        brainRotRequis = { rarete = "BRAINROT_GOD", quantite = 1 },
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

-- Récupère les autres events déjà créés par Main
local function getNotifEvent()    return ReplicatedStorage:FindFirstChild("NotifEvent")   end
local function getUpdateHUD()     return ReplicatedStorage:FindFirstChild("UpdateHUD")    end

-- ============================================================
-- État interne par joueur
-- ============================================================
-- { playerData, baseIndex, enCoursDeRebirth }
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

-- Vérifie si le joueur a atteint la progression maximale (Floor 4 spot_10)
local function aAtteintProgressionMax(playerData)
    if not playerData.progression then return false end
    return playerData.progression["4_10"] == true
end

-- Retourne le niveau de rebirth actuel (0 si jamais fait)
local function niveauActuel(playerData)
    return playerData.rebirthLevel or 0
end

-- Retourne le prochain niveau de rebirth à atteindre
local function prochainNiveau(playerData)
    return niveauActuel(playerData) + 1
end

-- Formate un grand nombre avec séparateurs de milliers
local function formaterCoins(n)
    local s = tostring(math.floor(n))
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

-- Retourne : ok (bool), manques (table)
-- manques = { manqueCoins = X, manqueBR = "RARETE" }
function RebirthSystem.VerifierConditions(player)
    local data = getData(player)
    if not data then return false, { erreur = "Données introuvables" } end

    local niveau = prochainNiveau(data)
    local cfg    = obtenirConfig(niveau)
    local manques = {}
    local ok      = true

    -- Vérification coins
    local coins = data.coins or 0
    if coins < cfg.coinsRequis then
        ok = false
        manques.manqueCoins = cfg.coinsRequis - coins
    end

    -- Vérification inventaire Brain Rot rare
    local inv   = data.inventory or {}
    local rarete   = cfg.brainRotRequis.rarete
    local quantite = cfg.brainRotRequis.quantite
    local stock    = inv[rarete] or 0
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

    local visible    = aAtteintProgressionMax(data)
    local niveau     = prochainNiveau(data)
    local cfg        = obtenirConfig(niveau)
    local ok, manques = RebirthSystem.VerifierConditions(player)

    local etat = {
        visible          = visible,
        disponible       = ok,
        prochainLevel    = niveau,
        coinsActuels     = data.coins or 0,
        coinsRequis      = cfg.coinsRequis,
        brainRotRequis   = cfg.brainRotRequis.rarete,
        label            = cfg.label,
        couleur          = cfg.couleur,
        manqueCoins      = manques.manqueCoins or 0,
        manqueBR         = manques.manqueBR,
        manqueBRActuel   = manques.manqueBRActuel or 0,
        manqueBRRequis   = manques.manqueBRRequis or 0,
        rebirthLevel     = niveauActuel(data),
        multiplicateur   = data.multiplicateurPermanent or 1.0,
    }

    pcall(function()
        RebirthButtonUpdate:FireClient(player, etat)
    end)
end

-- ============================================================
-- Effets visuels (côté serveur — particules dans le Workspace)
-- ============================================================

local function effetExplosionRebirth(player)
    -- Trouver la position du joueur
    local char = player.Character
    if not char then return end
    local hrp  = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local pos = hrp.Position

    -- Ancre temporaire pour les particules
    local ancre = Instance.new("Part")
    ancre.Name        = "RebirthFX_" .. player.UserId
    ancre.Size        = Vector3.new(1, 1, 1)
    ancre.Position    = pos
    ancre.Anchored    = true
    ancre.CanCollide  = false
    ancre.Transparency = 1
    ancre.Parent      = game:GetService("Workspace")

    -- Explosion de particules dorées
    local emitter = Instance.new("ParticleEmitter")
    emitter.Color        = ColorSequence.new({
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

    -- Lumière explosive
    local light = Instance.new("PointLight")
    light.Brightness = 8
    light.Range      = 50
    light.Color      = Color3.fromRGB(255, 220, 80)
    light.Parent     = ancre

    -- Burst initial
    emitter:Emit(120)

    -- Pulsation lumière
    task.spawn(function()
        local info = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        TweenService:Create(light, info, { Brightness = 0 }):Play()
    end)

    -- Nettoyage après 4 secondes
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

    -- Garde-fou anti-doublon
    if dd.enCoursDeRebirth then return end
    dd.enCoursDeRebirth = true

    local data     = dd.playerData
    local baseIndex = dd.baseIndex
    local niveau   = prochainNiveau(data)
    local cfg      = obtenirConfig(niveau)

    -- ── Étape 1 : Consommer les ressources ────────────────────
    data.coins = 0

    local inv = data.inventory or {}
    local rarete = cfg.brainRotRequis.rarete
    inv[rarete]  = math.max(0, (inv[rarete] or 0) - cfg.brainRotRequis.quantite)
    data.inventory = inv

    data.rebirthLevel = niveau

    -- ── Étape 2 : Sauvegarder les récompenses permanentes ─────
    -- Multiplicateur : prendre directement la valeur de la config
    data.multiplicateurPermanent = cfg.multiplicateur

    -- Slots bonus : cumulatif
    data.slotsBonus = (data.slotsBonus or 0) + cfg.slotsBonus

    -- ── Étape 3 : Animation côté client (flash blanc + son) ───
    pcall(function()
        RebirthAnimation:FireClient(player, {
            niveau   = niveau,
            label    = cfg.label,
            couleur  = cfg.couleur,
        })
    end)

    -- Effet particules côté serveur
    task.spawn(function()
        effetExplosionRebirth(player)
    end)

    -- ── Étape 4 : Notifications ───────────────────────────────
    local msgJoueur = string.format(
        "🔥 %s ! Multiplicateur ×%.1f débloqué ! +%d slots bonus",
        cfg.label, cfg.multiplicateur, cfg.slotsBonus
    )
    local msgTous = string.format(
        "⚡ %s vient d'effectuer son %s ! (×%.1f)",
        player.Name, cfg.label, cfg.multiplicateur
    )

    local notif = getNotifEvent()
    if notif then
        pcall(function() notif:FireClient(player, "REBIRTH", msgJoueur) end)
        pcall(function() notif:FireAllClients("REBIRTH_GLOBAL", msgTous) end)
    end

    -- Discord
    pcall(function()
        DiscordWebhook.Envoyer(
            "🔥 " .. player.Name .. " — " .. cfg.label,
            string.format(
                "**%s** vient d'effectuer son **%s** sur BrainRotFarm !\n" ..
                "Multiplicateur : **×%.1f** | Slots bonus : **+%d**",
                player.Name, cfg.label, cfg.multiplicateur, cfg.slotsBonus
            ),
            cfg.couleurHex
        )
    end)

    -- ── Étape 5 : Reset et ré-initialisation de la progression ─
    task.wait(1.5) -- laisser l'animation démarrer côté client

    -- Reset la progression (tous les spots reverrouillés)
    data.progression = {}

    -- Reset visuel de la base
    BaseProgressionSystem.Reset(player)
    task.wait(0.1)
    BaseProgressionSystem.Init(player, baseIndex, data)

    -- ── Étape 6 : Mettre à jour le HUD ────────────────────────
    local updateHUD = getUpdateHUD()
    if updateHUD then
        pcall(function() updateHUD:FireClient(player, data) end)
    end

    -- Remettre à jour le bouton rebirth (maintenant grisé — progression reset)
    task.wait(0.5)
    envoyerEtatBouton(player)

    -- ── Callback externe (Main.server.lua peut s'y accrocher) ──
    if RebirthSystem.OnRebirthComplete then
        pcall(RebirthSystem.OnRebirthComplete, player, niveau)
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
    if not dd then return end
    if dd.enCoursDeRebirth then return end

    local data = dd.playerData

    -- Vérifier que la progression max est atteinte
    if not aAtteintProgressionMax(data) then
        local notif = getNotifEvent()
        if notif then
            pcall(function()
                notif:FireClient(player, "ERREUR",
                    "Tu dois atteindre Floor 4 - Spot 10 avant de faire un Rebirth !")
            end)
        end
        return
    end

    -- Vérifier les conditions (coins + BR rare)
    local ok, manques = RebirthSystem.VerifierConditions(player)
    if not ok then
        local parties = {}
        if manques.manqueCoins and manques.manqueCoins > 0 then
            table.insert(parties, "💰 " .. formaterCoins(manques.manqueCoins) .. " coins manquants")
        end
        if manques.manqueBR then
            table.insert(parties, "🧬 1 " .. manques.manqueBR .. " manquant dans ton inventaire")
        end
        local msg = "Conditions non remplies : " .. table.concat(parties, " · ")
        local notif = getNotifEvent()
        if notif then
            pcall(function() notif:FireClient(player, "ERREUR", msg) end)
        end
        return
    end

    -- Lancer la séquence
    task.spawn(executerRebirth, player)
end)

-- ============================================================
-- Boucle de mise à jour du bouton (toutes les 5s)
-- ============================================================
-- Permet de griser/dé-griser le bouton au fil de la progression
-- sans attendre une action joueur

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

-- Initialise un joueur dans le système
function RebirthSystem.Init(player, playerData, baseIndex)
    -- S'assurer que les champs existent dans playerData
    if playerData.rebirthLevel == nil then
        playerData.rebirthLevel = 0
    end
    if playerData.multiplicateurPermanent == nil then
        playerData.multiplicateurPermanent = 1.0
    end
    if playerData.slotsBonus == nil then
        playerData.slotsBonus = 0
    end
    if not playerData.inventory then
        playerData.inventory = {
            COMMON       = 0,
            OG           = 0,
            RARE         = 0,
            EPIC         = 0,
            LEGENDARY    = 0,
            MYTHIC       = 0,
            SECRET       = 0,
            BRAINROT_GOD = 0,
        }
    end

    donneesJoueurs[player.UserId] = {
        playerData      = playerData,
        baseIndex       = baseIndex,
        enCoursDeRebirth = false,
    }

    -- Envoyer l'état initial du bouton (avec délai pour laisser le client charger)
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

-- Retourne le multiplicateur permanent du joueur (1.0 par défaut)
function RebirthSystem.GetMultiplicateur(player)
    local data = getData(player)
    if not data then return 1.0 end
    return data.multiplicateurPermanent or 1.0
end

-- Retourne les slots bonus cumulés du joueur (0 par défaut)
function RebirthSystem.GetSlotsBonus(player)
    local data = getData(player)
    if not data then return 0 end
    return data.slotsBonus or 0
end

-- Réinitialise les données du joueur (à la déconnexion)
function RebirthSystem.Reset(player)
    donneesJoueurs[player.UserId] = nil
end

-- Met à jour manuellement l'état du bouton (appelé par Main après chaque gain de coins)
function RebirthSystem.MettreAJourBouton(player)
    if donneesJoueurs[player.UserId] then
        pcall(envoyerEtatBouton, player)
    end
end

-- Callback externe — assigné depuis Main.server.lua si besoin
-- RebirthSystem.OnRebirthComplete = function(player, newLevel) end
RebirthSystem.OnRebirthComplete = nil

return RebirthSystem
