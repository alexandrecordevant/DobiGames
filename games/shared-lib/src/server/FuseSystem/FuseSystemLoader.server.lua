-- shared-lib/src/server/FuseSystem/FuseSystemLoader.server.lua
-- Initialise FuseSystem automatiquement depuis le GameConfig du jeu.
-- Alternative : appeler FuseSystem.Init(GameConfig) depuis Main.server.lua
-- pour injecter FuseSystem.OnResultatPret avant l'initialisation.

local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local gcOk, GameConfig = pcall(function()
	return require(
		ReplicatedStorage:FindFirstChild("GameConfig")
		or ReplicatedStorage.Specialized.GameConfig
	)
end)
if not gcOk then return end

local logOk, Logger = pcall(require, ServerScriptService.SharedLib.Server.Logger)
if not logOk then return end
Logger.init(GameConfig.LOG_LEVEL or "WARN")

if not GameConfig.Fuse then return end

local fsOk, FuseSystem = pcall(require, script.Parent.FuseSystem)
if not fsOk then return end

FuseSystem.Init(GameConfig)
