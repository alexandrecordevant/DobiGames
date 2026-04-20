-- shared-lib/src/server/FuseSystem/FuseSystemLoader.server.lua
-- Initialise FuseSystem automatiquement depuis le GameConfig du jeu.
-- Alternative : appeler FuseSystem.Init(GameConfig) depuis Main.server.lua
-- pour injecter FuseSystem.OnResultatPret avant l'initialisation.

print("[FUSE-DIAG] FuseSystemLoader demarre")

local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Verifier que GameConfig est accessible
local gcOk, GameConfig = pcall(function()
	return require(
		ReplicatedStorage:FindFirstChild("GameConfig")
		or ReplicatedStorage.Specialized.GameConfig
	)
end)
if not gcOk then
	warn("[FUSE-DIAG] ERREUR require GameConfig : " .. tostring(GameConfig))
	return
end
print("[FUSE-DIAG] GameConfig charge OK")

-- Verifier que Logger est accessible
local logOk, Logger = pcall(require, ServerScriptService.SharedLib.Server.Logger)
if not logOk then
	warn("[FUSE-DIAG] ERREUR require Logger : " .. tostring(Logger))
	return
end
print("[FUSE-DIAG] Logger charge OK")
Logger.init(GameConfig.LOG_LEVEL or "WARN")

-- Verifier GameConfig.Fuse
if not GameConfig.Fuse then
	print("[FUSE-DIAG] GameConfig.Fuse absent — FuseSystem desactive pour ce jeu")
	return
end
print("[FUSE-DIAG] GameConfig.Fuse present | MachineTag=" .. tostring(GameConfig.Fuse.MachineTag))
print("[FUSE-DIAG] FuseBrainrotsFolder=" .. tostring(GameConfig.Fuse.FuseBrainrotsFolder))

-- Charger FuseSystem
local fsOk, FuseSystem = pcall(require, script.Parent.FuseSystem)
if not fsOk then
	warn("[FUSE-DIAG] ERREUR require FuseSystem : " .. tostring(FuseSystem))
	return
end
print("[FUSE-DIAG] FuseSystem module charge OK — appel Init()")

FuseSystem.Init(GameConfig)
print("[FUSE-DIAG] FuseSystem.Init termine via Loader")
