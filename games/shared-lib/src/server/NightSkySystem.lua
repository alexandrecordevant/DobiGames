-- shared-lib/src/server/NightSkySystem.lua
-- DobiGames — Gestionnaire d'état pour le ciel nocturne (NightMode)
-- Responsabilités : garde l'état actif/inactif, synchronise les joueurs
-- qui rejoignent en cours d'event, nettoie sur shutdown serveur.
-- Appelé par EventNightMode.Demarrer / EventNightMode.Terminer.

local NightSkySystem = {}

-- ============================================================
-- Services
-- ============================================================
local Players = game:GetService("Players")
local Logger  = require(game:GetService("ServerScriptService").SharedLib.Server.Logger)

-- ============================================================
-- État interne
-- ============================================================
local actif          = false
local tempsDebut     = 0   -- os.clock() au Demarrer
local dureeTotal     = 0
local connPlayerAdded = nil
local bindToCloseEnregistre = false

-- ============================================================
-- Accesseurs publics
-- ============================================================

function NightSkySystem.IsActif()
    return actif
end

-- Retourne les secondes restantes (0 si inactif)
function NightSkySystem.GetDureeRestante()
    if not actif then return 0 end
    local ecoule = os.clock() - tempsDebut
    return math.max(0, dureeTotal - ecoule)
end

-- ============================================================
-- API
-- ============================================================

-- Démarre le tracking.
-- @param duree          number   — durée totale de l'event (secondes)
-- @param onJoueurSync   function — appelé(player, dureeRestante) pour chaque
--                                  joueur rejoignant en cours d'event
function NightSkySystem.Demarrer(duree, onJoueurSync)
    if actif then return end
    actif      = true
    tempsDebut = os.clock()
    dureeTotal = duree

    -- Sync des joueurs qui rejoignent en cours d'event
    if onJoueurSync then
        connPlayerAdded = Players.PlayerAdded:Connect(function(player)
            if not actif then return end
            local restant = NightSkySystem.GetDureeRestante()
            if restant <= 0 then return end
            -- Attendre que le client charge avant de lui envoyer l'état
            task.wait(3)
            if actif then
                pcall(onJoueurSync, player, NightSkySystem.GetDureeRestante())
            end
        end)
    end

    -- BindToClose : restaurer le Lighting si le serveur s'arrête pendant l'event
    -- (enregistré une seule fois pour éviter les doublons entre runs)
    if not bindToCloseEnregistre then
        bindToCloseEnregistre = true
        game:BindToClose(function()
            if actif then
                -- Forcer la fin propre (sans attendre la durée restante)
                NightSkySystem.Terminer(nil)
            end
        end)
    end

end

-- Termine le tracking et déconnecte les listeners.
-- @param onTerminaison  function? — callback optionnel après nettoyage
function NightSkySystem.Terminer(onTerminaison)
    if not actif then return end
    actif = false

    if connPlayerAdded then
        pcall(function() connPlayerAdded:Disconnect() end)
        connPlayerAdded = nil
    end

    if onTerminaison then
        pcall(onTerminaison)
    end

end

return NightSkySystem
