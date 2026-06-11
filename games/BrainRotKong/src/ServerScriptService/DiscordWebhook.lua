-- ServerScriptService/Common/DiscordWebhook.lua
-- BrainRotKong — Webhooks Discord
-- Envoie UNIQUEMENT les events rares et hebdomadaires
-- Pas de spam : rate limiting intégré

local HttpService = game:GetService("HttpService")
local Logger      = require(game:GetService("ServerScriptService").SharedLib.Server.Logger)
local Config      = require(game.ReplicatedStorage.GameConfig)

local DiscordWebhook = {}

-- Rate limiting : timestamp du dernier envoi par type de message
local dernierEnvoi = {}

-- Vérifie si on peut envoyer (renvoie false si trop tôt)
local function PeutEnvoyer(typeMessage, intervalleMinutes)
    local maintenant = os.time()
    local dernier    = dernierEnvoi[typeMessage] or 0
    if maintenant - dernier >= intervalleMinutes * 60 then
        dernierEnvoi[typeMessage] = maintenant
        return true
    end
    return false
end

-- Envoie un embed Discord via webhook
local function Envoyer(webhookURL, contenu, username, couleur)
    if not webhookURL or webhookURL == "" then
        Logger.warn("Discord", "URL webhook manquante dans GameConfig.DiscordWebhooks")
        return
    end

    local ok, err = pcall(function()
        HttpService:PostAsync(
            webhookURL,
            HttpService:JSONEncode({
                username = username or "BrainRotKong",
                embeds   = {{
                    description = contenu,
                    color       = couleur or 7506394,
                    footer      = { text = "BrainRotKong • DobiGames" },
                    timestamp   = os.date("!%Y-%m-%dT%H:%M:%SZ", os.time()),
                }}
            }),
            Enum.HttpContentType.ApplicationJson,
            false
        )
    end)

    if not ok then
        Logger.warn("Discord", "Erreur webhook : %s", tostring(err))
    end
end

-- ═══════════════════════════════════════════════════════
-- API PUBLIQUE — Uniquement les events importants
-- ═══════════════════════════════════════════════════════

-- 1. BRAINROT_GOD capturé → toujours envoyer (très rare, pas de rate limit)
function DiscordWebhook.BrainrotGodCapture(playerName)
    local webhooks = Config.DiscordWebhooks
    if not webhooks or not webhooks.records then return end

    local msg = "👑 **BRAINROT GOD CAPTURED!**\n"
             .. "**" .. playerName .. "** just caught the legendary\n"
             .. "**BRAINROT GOD** on BrainRotKong!\n\n"
             .. "🎮 Join the server: " .. (Config.DiscordInvite or "")

    Envoyer(webhooks.records, msg, "BrainRotKong", 16766720)
    Logger.info("Discord", "BRAINROT_GOD captured by %s", playerName)
end

-- 2. SECRET capturé → max 1 message / 30 min
function DiscordWebhook.SecretCapture(playerName)
    if not PeutEnvoyer("SECRET", 30) then return end

    local webhooks = Config.DiscordWebhooks
    if not webhooks or not webhooks.records then return end

    local msg = "🔴 **SECRET CAPTURED!**\n"
             .. "**" .. playerName .. "** just caught a **SECRET** Brain Rot\n"
             .. "on BrainRotKong!\n\n"
             .. "🎮 Join now: " .. (Config.DiscordInvite or "")

    Envoyer(webhooks.records, msg, "BrainRotKong", 16711680)
    Logger.info("Discord", "SECRET captured by %s", playerName)
end

-- 3. Admin Abuse hebdo → max 1 envoi toutes les 6h (protection contre appels répétés)
function DiscordWebhook.AdminAbuseHebdo()
    if not PeutEnvoyer("AdminAbuse", 60 * 6) then return end

    local webhooks = Config.DiscordWebhooks
    if not webhooks or not webhooks.events then return end

    local duree = (Config.AdminAbuseHebdo and Config.AdminAbuseHebdo.dureeMinutes) or 30

    local msg = "⚡ **WEEKLY ADMIN ABUSE!**\n"
             .. "The special Saturday event just started!\n"
             .. "**Massive rare Brain Rot spawns** for "
             .. duree .. " minutes!\n\n"
             .. "🔴 @everyone Get in now!\n"
             .. "🎮 " .. (Config.DiscordInvite or "")

    Envoyer(webhooks.events, msg, "BrainRotKong Events", 16711680)
    Logger.info("Discord", "Admin Abuse hebdo announced")
end

-- 4. Top Farmer hebdomadaire → max 1 envoi toutes les 6 jours
function DiscordWebhook.TopFarmerHebdo(playerName, heuresJeu, semaine)
    if not PeutEnvoyer("TopFarmer", 60 * 24 * 6) then return end

    local webhooks = Config.DiscordWebhooks
    if not webhooks or not webhooks.events then return end

    local msg = "🚜 **TOP FARMER OF THE WEEK " .. (semaine or "") .. "**\n\n"
             .. "👑 **" .. playerName .. "**\n"
             .. "⏱️ Play time: **" .. heuresJeu .. "h**\n\n"
             .. "🎁 Reward: **Exclusive Red Tractor** for 7 days!\n"
             .. "🎮 " .. (Config.DiscordInvite or "")

    Envoyer(webhooks.events, msg, "BrainRotKong", 16766720)
    Logger.info("Discord", "Top Farmer announced: %s", playerName)
end

-- 5. Erreur critique → dev-logs uniquement, max 1 envoi / 5 min par contexte
function DiscordWebhook.ErreurCritique(erreur, contexte)
    if Config.TEST_MODE then return end
    if not PeutEnvoyer("Erreur_" .. tostring(contexte), 5) then return end

    local webhooks = Config.DiscordWebhooks
    if not webhooks or not webhooks.dev then return end

    local msg = "🔴 **CRITICAL ERROR**\n"
             .. "```\n" .. tostring(erreur):sub(1, 500) .. "\n```\n"
             .. "Context: `" .. tostring(contexte) .. "`"

    Envoyer(webhooks.dev, msg, "BrainRotKong DevLogs", 16711680)
end

return DiscordWebhook
