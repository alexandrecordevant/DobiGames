-- ServerScriptService/Systems/BotSystemLoader.server.lua
-- DobiGames — Point d'entrée unique pour BotSystem
-- shared-lib/src/server → ServerScriptService/SharedLib/Server (voir default.project.json)

local ServerScriptService = game:GetService("ServerScriptService")
local Logger = require(game:GetService("ServerScriptService").SharedLib.Server.Logger)

-- Chemin Rojo : ServerScriptService/SharedLib/Server/BotSystem
local sharedLib = ServerScriptService:WaitForChild("SharedLib", 15)
if not sharedLib then
    Logger.warn("Bot", "ServerScriptService/SharedLib introuvable après 15s")
    return
end

local serverFolder = sharedLib:WaitForChild("Server", 10)
if not serverFolder then
    Logger.warn("Bot", "ServerScriptService/SharedLib/Server introuvable après 10s")
    return
end

local botSystemModule = serverFolder:FindFirstChild("BotSystem")
                     or serverFolder:FindFirstChild("BotSytem")
if not botSystemModule then
    Logger.warn("Bot", "BotSystem introuvable dans SharedLib/Server")
    return
end

-- Chargement du système de bots (server-side uniquement via .server.lua)
local ok, err = pcall(require, botSystemModule)
if not ok then
    Logger.warn("Bot", "Erreur au chargement de BotSystem : %s", tostring(err))
end
