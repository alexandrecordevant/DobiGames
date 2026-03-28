-- BrainrotService.server.lua
-- Point d'entrée pickup — délègue à PickupSystem (shared-lib)
require(game:GetService("ServerScriptService").SharedLib.Server.PickupSystem).Init()
