-- shared-lib/server/WeatherSystem/LightningEffect.lua
-- Déclenche des éclairs aléatoires en cours d'event pluie
-- Côté serveur : fire RemoteEvent RainLightning → clients gèrent le visuel

local LightningEffect = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Logger            = require(script.Parent.Parent.Logger)

local running         = false
local lightningThread = nil

-- ============================================================
-- API
-- ============================================================

function LightningEffect.DemarrerBoucle(intervalConfig)
    local minI = (intervalConfig and intervalConfig.min) or 15
    local maxI = (intervalConfig and intervalConfig.max) or 45

    LightningEffect.ArreterBoucle()
    running = true

    lightningThread = task.spawn(function()
        while running do
            local attente = minI + math.random() * (maxI - minI)
            task.wait(attente)
            if not running then break end

            local re = ReplicatedStorage:FindFirstChild("RainLightning")
            if re then
                pcall(function() re:FireAllClients() end)
            end
        end
    end)
end

function LightningEffect.ArreterBoucle()
    running = false
    if lightningThread then
        pcall(task.cancel, lightningThread)
        lightningThread = nil
    end
end

return LightningEffect
