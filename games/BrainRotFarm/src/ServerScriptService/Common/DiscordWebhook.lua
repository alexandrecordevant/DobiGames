-- ServerScriptService/Common/DiscordWebhook.lua
-- BrainRotFarm — Webhooks Discord
-- Envoie UNIQUEMENT les events rares et hebdomadaires
-- Pas de spam : rate limiting intégré

local HttpService = game:GetService("HttpService")
local Config      = require(game.ReplicatedStorage.Specialized.GameConfig)

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
        warn("[Discord] URL webhook manquante dans GameConfig.DiscordWebhooks")
        return
    end

    -- En TEST_MODE : print au lieu d'envoyer vraiment
    if Config.TEST_MODE then
        print("[Discord TEST] " .. tostring(username) .. " : " .. tostring(contenu))
        return
    end

    local ok, err = pcall(function()
        HttpService:PostAsync(
            webhookURL,
            HttpService:JSONEncode({
                username = username or "BrainRotFarm",
                embeds   = {{
                    description = contenu,
                    color       = couleur or 7506394,
                    footer      = { text = "BrainRotFarm • DobiGames" },
                    timestamp   = os.date("!%Y-%m-%dT%H:%M:%SZ", os.time()),
                }}
            }),
            Enum.HttpContentType.ApplicationJson,
            false
        )
    end)

    if not ok then
        warn("[Discord] Erreur webhook : " .. tostring(err))
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
             .. "**BRAINROT GOD** on BrainRotFarm!\n\n"
             .. "🎮 Join the server: " .. (Config.DiscordInvite or "")

    Envoyer(webhooks.records, msg, "BrainRotFarm", 16766720)
    print("[Discord] BRAINROT_GOD captured by " .. playerName)
end

-- 2. SECRET capturé → max 1 message / 30 min
function DiscordWebhook.SecretCapture(playerName)
    if not PeutEnvoyer("SECRET", 30) then return end

    local webhooks = Config.DiscordWebhooks
    if not webhooks or not webhooks.records then return end

    local msg = "🔴 **SECRET CAPTURED!**\n"
             .. "**" .. playerName .. "** just caught a **SECRET** Brain Rot\n"
             .. "on BrainRotFarm!\n\n"
             .. "🎮 Join now: " .. (Config.DiscordInvite or "")

    Envoyer(webhooks.records, msg, "BrainRotFarm", 16711680)
    print("[Discord] SECRET captured by " .. playerName)
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

    Envoyer(webhooks.events, msg, "BrainRotFarm Events", 16711680)
    print("[Discord] Admin Abuse hebdo announced")
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

    Envoyer(webhooks.events, msg, "BrainRotFarm", 16766720)
    print("[Discord] Top Farmer announced: " .. playerName)
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

    Envoyer(webhooks.dev, msg, "BrainRotFarm DevLogs", 16711680)
end

return DiscordWebhook
