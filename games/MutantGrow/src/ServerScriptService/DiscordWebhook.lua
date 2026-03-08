-- ServerScriptService/DiscordWebhook.lua
local DiscordWebhook = {}
local HttpService = game:GetService("HttpService")
local Config      = require(game.ReplicatedStorage.Modules.GameConfig)

function DiscordWebhook.Envoyer(titre, message, couleurHex)
    if Config.DiscordWebhookURL == "" then return end
    pcall(function()
        HttpService:PostAsync(Config.DiscordWebhookURL,
            HttpService:JSONEncode({
                embeds = {{
                    title       = titre,
                    description = message,
                    color       = couleurHex or 16776960,
                    footer      = { text = "DobiGames · " .. Config.NomDuJeu }
                }}
            }),
            Enum.HttpContentType.ApplicationJson)
    end)
end

return DiscordWebhook
