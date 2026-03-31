-- ReplicatedStorage/Modules/GameConfig.lua
-- Point d'entrée unique — shared-lib fait require(ReplicatedStorage.GameConfig)
-- Ne pas ajouter de champs ici : modifier GameConfigShared ou GameConfigSpecific

local Config = {}
local Shared   = require(script.Parent.GameConfigShared)
local Specific = require(script.Parent.GameConfigSpecific)
for k, v in pairs(Shared)   do Config[k] = v end
for k, v in pairs(Specific) do Config[k] = v end  -- Specific écrase si conflit
return Config
