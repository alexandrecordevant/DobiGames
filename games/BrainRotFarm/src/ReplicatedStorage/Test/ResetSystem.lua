-- ReplicatedStorage/Test/ResetSystem.lua
-- BrainRotFarm — Remise à zéro complète des données joueur (TEST uniquement)
-- ⚠️ CE FICHIER NE DOIT JAMAIS ALLER EN PRODUCTION
-- ⚠️ NE JAMAIS COPIER DANS _template/

local ResetSystem = {}

-- ============================================================
-- Services
-- ============================================================
local Players           = game:GetService("Players")
local DataStoreService  = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- ============================================================
-- Config — sécurité absolue
-- ============================================================
local Config = require(ReplicatedStorage.Specialized.GameConfig)

-- Garde-fou : si TEST_MODE est faux, ce module ne fait RIEN
local function verifierTestMode()
    if not Config.TEST_MODE then
        warn("[RESET] ⛔ TEST_MODE = false — reset refusé (sécurité production)")
        return false
    end
    return true
end

-- DataStore identique à DataStoreManager.lua
local DS = DataStoreService:GetDataStore("BrainRotIdleV1")

-- ============================================================
-- Données par défaut (même structure que DataStoreManager)
-- ============================================================
local function donneesVides()
    return {
        coins                   = 0,
        totalCoinsGagnes        = 0,
        tier                    = 0,
        prestige                = 0,
        rebirthLevel            = 0,
        multiplicateurPermanent = 1.0,
        slotsBonus              = 0,
        coinsParMinute          = 1,
        totalCollecte           = 0,
        derniereConnexion       = os.time(),
        spotsOccupes            = {},
        inventory = {
            COMMON=0, OG=0, RARE=0, EPIC=0,
            LEGENDARY=0, MYTHIC=0, SECRET=0, BRAINROT_GOD=0,
        },
        progression = {},
        upgrades = {
            upgradeArroseur = 0,
            upgradeSpeed    = 0,
            upgradeCarry    = 0,
            upgradeAimant   = 0,
        },
        hasVIP           = false,
        hasOfflineVault  = false,
        hasAutoCollect   = false,
        hasTracteur      = false,
        hasLuckyCharm    = false,
        walkSpeedActuel  = 16,
        tracteurSeuilMin = "RARE",
        stats = {
            sessionsCount  = 0,
            totalHeuresJeu = 0,
        },
    }
end

-- ============================================================
-- Helpers
-- ============================================================
local function log(message)
    print("[RESET] " .. message)
end

local function notifJoueur(player, message)
    local ev = ReplicatedStorage:FindFirstChild("NotifEvent")
    if ev then pcall(function() ev:FireClient(player, "INFO", message) end) end
end

-- Supprime le DataStore d'un userId
-- Retourne true si succès, false si erreur
local function supprimerDataStore(userId)
    local cle = "player_" .. tostring(userId)
    local ok, err = pcall(function()
        DS:RemoveAsync(cle)
    end)
    if not ok then
        warn("[RESET] Erreur RemoveAsync pour " .. cle .. " : " .. tostring(err))
        return false
    end
    return true
end

-- ============================================================
-- API publique
-- ============================================================

-- Remet à zéro le DataStore ET kicke le joueur
function ResetSystem.ResetJoueur(player)
    if not verifierTestMode() then return end
    if not player or not player.Parent then
        warn("[RESET] ResetJoueur : joueur invalide")
        return
    end

    local userId = player.UserId
    local nom    = player.Name

    -- 1. Supprimer les données DataStore
    local ok = supprimerDataStore(userId)
    if not ok then
        warn("[RESET] ⚠ Échec suppression DataStore pour " .. nom .. " — kick quand même")
    end

    -- 2. Kicker le joueur avec un message clair
    task.delay(0.3, function()
        pcall(function()
            player:Kick("🔄 Reset TEST effectué — Reconnecte-toi pour repartir de zéro.")
        end)
    end)

    log(nom .. " remis à zéro ✓ (DataStore effacé + kick)")
end

-- Remet à zéro TOUS les joueurs connectés
function ResetSystem.ResetTous()
    if not verifierTestMode() then return end

    local joueurs = Players:GetPlayers()
    if #joueurs == 0 then
        log("Aucun joueur connecté.")
        return
    end

    log("Reset de " .. #joueurs .. " joueur(s)...")

    for _, player in ipairs(joueurs) do
        ResetSystem.ResetJoueur(player)
        task.wait(0.5)  -- délai entre chaque pour respecter les limites DataStore
    end

    log("Tous les joueurs remis à zéro ✓")
end

-- Efface le DataStore SANS kicker (pour tester le rechargement de nouvelles données)
function ResetSystem.ResetDataSeulement(userId)
    if not verifierTestMode() then return end

    if type(userId) ~= "number" then
        warn("[RESET] ResetDataSeulement : userId invalide (" .. tostring(userId) .. ")")
        return
    end

    local ok = supprimerDataStore(userId)
    if ok then
        log("DataStore effacé pour userId " .. userId .. " (sans kick)")
        -- Notifier le joueur s'il est connecté
        local player = Players:GetPlayerByUserId(userId)
        if player then
            notifJoueur(player, "🔄 Tes données ont été effacées. Rejoins à nouveau pour repartir de zéro.")
        end
    end
end

-- Remet la base à son état visuel initial SANS toucher au DataStore
function ResetSystem.ResetVisuelBase(player)
    if not verifierTestMode() then return end
    if not player or not player.Parent then return end

    local ok, BPS = pcall(require, ServerScriptService.Common.BaseProgressionSystem)
    if ok and BPS and BPS.Reset then
        pcall(BPS.Reset, player)
        log("Visuel base remis à zéro pour " .. player.Name .. " ✓")
        notifJoueur(player, "🔄 Base remise à zéro visuellement.")
    else
        warn("[RESET] BaseProgressionSystem.Reset introuvable")
    end
end

-- ============================================================
-- RemoteEvent "DEBUG_Reset" — déclenchement depuis la Console Studio
-- OnServerEvent(player, typeReset, targetUserId?)
--   typeReset : "joueur" | "tous" | "data" | "visuel"
--   targetUserId (optionnel) : pour "data" cibler un UserId précis
-- ============================================================
function ResetSystem.Init()
    if not Config.TEST_MODE then
        -- En production : créer le RemoteEvent mais ignorer tous les appels
        local re = ReplicatedStorage:FindFirstChild("DEBUG_Reset")
        if re then re:Destroy() end  -- supprimer si résiduel d'une session test
        return
    end

    -- Créer le RemoteEvent
    local existing = ReplicatedStorage:FindFirstChild("DEBUG_Reset")
    if existing then existing:Destroy() end

    local debugReset = Instance.new("RemoteEvent")
    debugReset.Name   = "DEBUG_Reset"
    debugReset.Parent = ReplicatedStorage

    debugReset.OnServerEvent:Connect(function(player, typeReset, targetUserId)
        -- Sécurité : refuser si TEST_MODE désactivé (au cas où)
        if not Config.TEST_MODE then
            warn("[RESET] ⛔ Tentative de reset en production refusée pour " .. player.Name)
            return
        end

        -- Validation du type
        if type(typeReset) ~= "string" then return end
        typeReset = string.lower(typeReset)

        log("Commande reçue : '" .. typeReset .. "' par " .. player.Name)

        if typeReset == "joueur" then
            -- Reset du joueur qui envoie la commande
            ResetSystem.ResetJoueur(player)

        elseif typeReset == "tous" then
            ResetSystem.ResetTous()

        elseif typeReset == "data" then
            -- Si targetUserId fourni → cibler cet userId
            -- Sinon → cibler le joueur qui envoie
            local uid = type(targetUserId) == "number" and targetUserId or player.UserId
            ResetSystem.ResetDataSeulement(uid)

        elseif typeReset == "visuel" then
            ResetSystem.ResetVisuelBase(player)

        else
            warn("[RESET] Type inconnu : '" .. typeReset .. "' — utilise : joueur | tous | data | visuel")
        end
    end)

    -- Auto-reset à chaque connexion si AutoResetOnJoin = true dans TestConfig
    local TestConfig = nil
    local okTC, tc = pcall(require, ReplicatedStorage.Test.TestConfig)
    if okTC and tc then TestConfig = tc end

    if TestConfig and TestConfig.AutoResetOnJoin then
        Players.PlayerAdded:Connect(function(player)
            if not Config.TEST_MODE then return end
            -- Attendre que la connexion soit établie avant d'effacer
            task.wait(0.5)
            log("AutoResetOnJoin : effacement DataStore de " .. player.Name)
            supprimerDataStore(player.UserId)
            -- Ne pas kicker — le joueur vient d'arriver, les données vides seront chargées
            -- par DataStoreManager.Load (retourne DefaultData si rien en store)
        end)
        log("AutoResetOnJoin activé — données effacées à chaque connexion")
    end

    log("✓ ResetSystem initialisé (TEST_MODE = true)")
    log("   ▶ game.ReplicatedStorage:WaitForChild('DEBUG_Reset'):FireServer('joueur')")
    log("   ▶ game.ReplicatedStorage:WaitForChild('DEBUG_Reset'):FireServer('tous')")
    log("   ▶ game.ReplicatedStorage:WaitForChild('DEBUG_Reset'):FireServer('data')")
    log("   ▶ game.ReplicatedStorage:WaitForChild('DEBUG_Reset'):FireServer('visuel')")
end

return ResetSystem
