-- ServerScriptService/Common/DiscordWebhook.lua
-- Template — Webhooks Discord
-- Envoie UNIQUEMENT les events rares et hebdomadaires
-- Pas de spam : rate limiting intégré

local HttpService = game:GetService("HttpService")
local Config      = require(game.ReplicatedStorage.Specialized.GameConfig)

local DiscordWebhook = {}

-- Rate limiting : timestamp du dernier envoi par type de message
local dernierEnvoi = {}

local function PeutEnvoyer(typeMessage, intervalleMinutes)
    local maintenant = os.time()
    local dernier    = dernierEnvoi[typeMessage] or 0
    if maintenant - dernier >= intervalleMinutes * 60 then
        dernierEnvoi[typeMessage] = maintenant
        return true
    end
    return false
end

local function Envoyer(webhookURL, contenu, username, couleur)
    if not webhookURL or webhookURL == "" then
        warn("[Discord] URL webhook manquante dans GameConfig.DiscordWebhooks")
        return
    end
    if Config.TEST_MODE then
        print("[Discord TEST] " .. tostring(username) .. " : " .. tostring(contenu))
        return
    end
    local ok, err = pcall(function()
        HttpService:PostAsync(
            webhookURL,
            HttpService:JSONEncode({
                username = username or "GameBot",
                embeds   = {{
                    description = contenu,
                    color       = couleur or 7506394,
                    footer      = { text = Config.NomDuJeu .. " • DobiGames" },
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

-- Ajouter les fonctions spécifiques au jeu ici
-- Exemple : DiscordWebhook.BrainrotGodCapture(playerName)

return DiscordWebhook
