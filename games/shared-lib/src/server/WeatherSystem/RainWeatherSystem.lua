-- shared-lib/server/WeatherSystem/RainWeatherSystem.lua
-- Coordinateur principal du système météo pluie
-- Gère l'état, le sync joueurs, les sous-systèmes, les RemoteEvents

local RainWeatherSystem = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local Logger            = require(script.Parent.Parent.Logger)

local CloudsManager   = require(script.Parent.CloudsManager)
local LightningEffect = require(script.Parent.LightningEffect)
local WetGroundEffect = require(script.Parent.WetGroundEffect)

-- ============================================================
-- État
-- ============================================================
local actif        = false
local tempsDebut   = nil
local dureeTotal   = nil
local connJoueur   = nil
local bindRegistre = false

-- ============================================================
-- Utilitaires
-- ============================================================
local function getRemote(nom)
    return ReplicatedStorage:FindFirstChild(nom)
end

local function syncJoueur(player, restant)
    local re = getRemote("RainEventStart")
    if re then
        task.wait(3)
        pcall(function() re:FireClient(player, restant) end)
    end
end

-- ============================================================
-- API
-- ============================================================

function RainWeatherSystem.IsActif()
    return actif
end

function RainWeatherSystem.GetDureeRestante()
    if not actif or not tempsDebut or not dureeTotal then return 0 end
    return math.max(0, dureeTotal - (os.time() - tempsDebut))
end

function RainWeatherSystem.Demarrer(config, duree)
    actif      = true
    tempsDebut = os.time()
    dureeTotal = duree

    -- Atmosphère + Clouds + Lighting
    pcall(CloudsManager.Appliquer, config)

    -- Sol mouillé + flaques
    pcall(WetGroundEffect.Appliquer, config)

    -- Boucle éclairs
    pcall(LightningEffect.DemarrerBoucle, config.lightningInterval)

    -- Notifier tous les clients
    local reStart = getRemote("RainEventStart")
    if reStart then
        pcall(function() reStart:FireAllClients(duree) end)
    end

    -- Sync joueurs qui rejoignent en cours d'event
    connJoueur = Players.PlayerAdded:Connect(function(player)
        local restant = RainWeatherSystem.GetDureeRestante()
        if restant > 3 then
            syncJoueur(player, restant)
        end
    end)

    -- BindToClose unique pour nettoyer en cas d'arrêt serveur
    if not bindRegistre then
        bindRegistre = true
        game:BindToClose(function()
            if actif then RainWeatherSystem.Terminer() end
        end)
    end

end

function RainWeatherSystem.Terminer()
    if not actif then return end
    actif      = false
    tempsDebut = nil
    dureeTotal = nil

    -- Arrêter éclairs
    pcall(LightningEffect.ArreterBoucle)

    -- Restaurer atmosphère + clouds + lighting
    pcall(CloudsManager.Restaurer)

    -- Restaurer sol
    pcall(WetGroundEffect.Restaurer)

    -- Déconnecter PlayerAdded
    if connJoueur then
        connJoueur:Disconnect()
        connJoueur = nil
    end

    -- Notifier clients (arrêt effets)
    local reEnd = getRemote("RainEventEnd")
    if reEnd then
        pcall(function() reEnd:FireAllClients() end)
    end

end

return RainWeatherSystem
