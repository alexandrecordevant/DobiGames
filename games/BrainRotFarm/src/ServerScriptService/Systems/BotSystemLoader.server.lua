-- ServerScriptService/Systems/BotSystemLoader.server.lua
-- DobiGames — Point d'entrée unique pour BotSystem
-- shared-lib/src/server → ServerScriptService/SharedLib/Server (voir default.project.json)

local ServerScriptService = game:GetService("ServerScriptService")

-- Chemin Rojo : ServerScriptService/SharedLib/Server/BotSystem
local sharedLib = ServerScriptService:WaitForChild("SharedLib", 15)
if not sharedLib then
    warn("[BotSystemLoader] ServerScriptService/SharedLib introuvable après 15s")
    return
end

local serverFolder = sharedLib:WaitForChild("Server", 10)
if not serverFolder then
    warn("[BotSystemLoader] ServerScriptService/SharedLib/Server introuvable après 10s")
    return
end

local botSystemModule = serverFolder:FindFirstChild("BotSystem")
                     or serverFolder:FindFirstChild("BotSytem")
if not botSystemModule then
    warn("[BotSystemLoader] BotSystem introuvable dans SharedLib/Server")
    return
end

-- Chargement du système de bots (server-side uniquement via .server.lua)
local ok, err = pcall(require, botSystemModule)
if not ok then
    warn("[BotSystemLoader] Erreur au chargement de BotSystem :", err)
end
