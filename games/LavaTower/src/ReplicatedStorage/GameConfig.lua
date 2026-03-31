-- ReplicatedStorage/GameConfig.lua
-- Point d'entrée racine — requis par shared-lib (AssignationSystem, BaseProgressionSystem, etc.)
-- Délègue au merger dans Modules/
return require(game.ReplicatedStorage.Modules.GameConfig)
