-- ServerScriptService/Systems/CodeRedeemSystem.lua
-- Validation et application des codes promo — server-side only

local CodeRedeemSystem = {}

local DataStoreService  = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Logger            = require(game:GetService("ServerScriptService").SharedLib.Server.Logger)
local GameConfig        = require(ReplicatedStorage:WaitForChild("GameConfig"))

-- DataStore global pour le compteur MaxUses (une entrée par code limité)
local GlobalCodesStore = DataStoreService:GetDataStore("PromoCodesGlobal")

-- Dépendances injectées depuis Main.server.lua
CodeRedeemSystem.GetData       = nil  -- function(player) → data
CodeRedeemSystem.FireUpdateHUD = nil  -- function(player, data)

CodeRedeemSystem.CarrySystem   = nil  -- module CarrySystem

-- ============================================================
-- Rate limiting : 5 tentatives max par minute par joueur
-- ============================================================
local rateLimitData  = {}   -- { [userId] = { count=N, windowStart=os.time() } }
local invalidAttempts = {}  -- { [userId] = { count=N, windowStart=os.time() } }

local MAX_PAR_MINUTE      = 5
local SEUIL_WARN_INVALIDE = 10
local FENETRE_WARN        = 5 * 60  -- 5 minutes

local function verifierRateLimit(player)
    local now    = os.time()
    local userId = player.UserId
    local rl     = rateLimitData[userId]

    if not rl or now - rl.windowStart >= 60 then
        rateLimitData[userId] = { count = 1, windowStart = now }
        return true
    end

    if rl.count >= MAX_PAR_MINUTE then
        return false
    end
    rl.count = rl.count + 1
    return true
end

local function compterTentativeInvalide(player)
    local now    = os.time()
    local userId = player.UserId
    local ia     = invalidAttempts[userId]

    if not ia or now - ia.windowStart >= FENETRE_WARN then
        invalidAttempts[userId] = { count = 1, windowStart = now }
        return
    end

    ia.count = ia.count + 1
    if ia.count >= SEUIL_WARN_INVALIDE then
        Logger.warn("Code", "Activite suspecte : %s — %d codes invalides en %d min",
            player.Name, ia.count, FENETRE_WARN / 60)
        -- Reset pour éviter le spam de warns
        invalidAttempts[userId] = { count = 0, windowStart = now }
    end
end

-- ============================================================
-- DataStore global pour MaxUses
-- ============================================================

local function lireNbUtilisations(codeUpper)
    local ok, valeur = pcall(function()
        return GlobalCodesStore:GetAsync("USES_" .. codeUpper)
    end)
    return ok and (valeur or 0) or 0
end

local function incrementerNbUtilisations(codeUpper)
    -- UpdateAsync pour éviter les race conditions entre serveurs
    local ok, _ = pcall(function()
        GlobalCodesStore:UpdateAsync("USES_" .. codeUpper, function(current)
            return (current or 0) + 1
        end)
    end)
    if not ok then
        -- Retry unique
        ok = pcall(function()
            GlobalCodesStore:UpdateAsync("USES_" .. codeUpper, function(current)
                return (current or 0) + 1
            end)
        end)
        if not ok then
            Logger.error("Code", "Impossible d'incrementer compteur pour %s", codeUpper)
            return false
        end
    end
    return true
end

-- ============================================================
-- Application des récompenses
-- ============================================================

local function appliquerRecompenses(player, data, rewards)
    if rewards.Coins and rewards.Coins > 0 then
        data.coins            = (data.coins or 0) + rewards.Coins
        data.totalCoinsGagnes = (data.totalCoinsGagnes or 0) + rewards.Coins
    end

    if CodeRedeemSystem.FireUpdateHUD then
        CodeRedeemSystem.FireUpdateHUD(player, data)
    end
end

-- Construit le texte de confirmation affiché côté client
local function construireMessage(rewards)
    local parties = {}

    if rewards.Coins and rewards.Coins > 0 then
        local affichage
        if rewards.Coins >= 1e9 then
            affichage = string.format("%.1fB", rewards.Coins / 1e9)
        elseif rewards.Coins >= 1e6 then
            affichage = string.format("%.0fM", rewards.Coins / 1e6)
        elseif rewards.Coins >= 1e3 then
            affichage = string.format("%.0fK", rewards.Coins / 1e3)
        else
            affichage = tostring(math.floor(rewards.Coins))
        end
        table.insert(parties, "+" .. affichage .. " coins")
    end

    if #parties == 0 then return "Rewards applied!" end
    return table.concat(parties, " · ")
end

-- ============================================================
-- API publique — appelée depuis Main.server.lua via RemoteFunction
-- ============================================================

function CodeRedeemSystem.Redeem(player, code)
    -- Validation du type d'entrée
    if type(code) ~= "string" or #code == 0 then
        return { Success = false, Message = "Invalid code." }
    end

    -- Normalisation : uppercase + trim des espaces
    code = string.upper(string.match(code, "^%s*(.-)%s*$") or code)

    if #code > 32 then
        return { Success = false, Message = "Invalid code." }
    end

    -- Rate limiting
    if not verifierRateLimit(player) then
        Logger.warn("Code", "Rate limit depasse : %s (%s)", player.Name, code)
        return { Success = false, Message = "Too many attempts. Wait a moment." }
    end

    -- Récupérer les données du joueur
    local data = CodeRedeemSystem.GetData and CodeRedeemSystem.GetData(player)
    if not data then
        Logger.warn("Code", "Donnees joueur introuvables pour %s", player.Name)
        return { Success = false, Message = "Server error. Try again later." }
    end

    -- Vérifier l'existence du code
    local codeCfg = GameConfig.PromoCodes and GameConfig.PromoCodes[code]
    if not codeCfg then
        compterTentativeInvalide(player)
        Logger.debug("Code", "Code inconnu : [%s] (joueur : %s)", code, player.Name)
        return { Success = false, Message = "Invalid code." }
    end

    -- Vérifier que le code est actif
    if not codeCfg.Active then
        Logger.debug("Code", "Code inactif : [%s] (joueur : %s)", code, player.Name)
        return { Success = false, Message = "This code is no longer active." }
    end

    -- Vérifier l'expiration
    if codeCfg.ExpiresAt and codeCfg.ExpiresAt > 0 and os.time() > codeCfg.ExpiresAt then
        Logger.debug("Code", "Code expire : [%s] (joueur : %s)", code, player.Name)
        return { Success = false, Message = "This code has expired." }
    end

    -- Vérifier si le joueur a déjà utilisé ce code
    if not data.RedeemedCodes then data.RedeemedCodes = {} end
    if table.find(data.RedeemedCodes, code) then
        return { Success = false, Message = "You already used this code." }
    end

    -- Vérifier le quota global MaxUses
    if codeCfg.MaxUses and codeCfg.MaxUses ~= -1 then
        local utilisations = lireNbUtilisations(code)
        if utilisations >= codeCfg.MaxUses then
            Logger.info("Code", "Quota atteint pour [%s] (%d/%d)", code, utilisations, codeCfg.MaxUses)
            return { Success = false, Message = "This code has reached its maximum uses." }
        end
        -- Incrémenter le compteur global AVANT d'appliquer les récompenses
        -- (en cas d'échec DataStore, on refuse plutôt que de donner sans tracer)
        local ok = incrementerNbUtilisations(code)
        if not ok then
            Logger.error("Code", "Echec increment compteur [%s] pour %s", code, player.Name)
            return { Success = false, Message = "Server error. Please try again." }
        end
    end

    -- Appliquer les récompenses
    appliquerRecompenses(player, data, codeCfg.Rewards)

    -- Marquer le code comme utilisé dans le DataStore joueur
    table.insert(data.RedeemedCodes, code)

    local messageRecompense = construireMessage(codeCfg.Rewards)
    Logger.info("Code", "Redemption reussie : [%s] → %s (%s)", code, player.Name, messageRecompense)

    return {
        Success = true,
        Message = messageRecompense,
        Rewards = codeCfg.Rewards,
    }
end

-- Nettoyage des tables en mémoire à la déconnexion du joueur
function CodeRedeemSystem.OnPlayerRemoving(player)
    rateLimitData[player.UserId]   = nil
    invalidAttempts[player.UserId] = nil
end

return CodeRedeemSystem
