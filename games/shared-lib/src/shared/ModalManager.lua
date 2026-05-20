-- shared-lib/src/shared/ModalManager.lua
-- Gestionnaire centralisé des modales — côté client uniquement
-- API : Open(name) · Close(name) · IsAnyOpen() · OnModalStateChanged · Reset()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Logger            = require(ReplicatedStorage.SharedLib.Logger)

local ModalManager = {}

-- Noms canoniques des modales (constantes exportées)
ModalManager.Modals = {
    SHOP              = "Shop",
    ROBUX_SHOP        = "RobuxShop",
    INDEX             = "Index",
    HOW_TO_PLAY       = "HowToPlay",
    DAILY_SEEDS       = "DailySeeds",
    FLOWER_POT        = "FlowerPot",
    FLOWER_POT_PANEL  = "FlowerPotPanel",
}

-- Set des modales ouvertes { nomModale = true }
local openModals = {}

local stateEvent      = Instance.new("BindableEvent")
local beforeOpenEvent = Instance.new("BindableEvent")

-- Émis quand l'état "au moins une modale ouverte" bascule (bool)
ModalManager.OnModalStateChanged = stateEvent.Event

-- Émis AVANT l'enregistrement d'une nouvelle modale — chaque menu écoute
-- et se ferme si openingModal ~= son propre nom
ModalManager.BeforeOpen = beforeOpenEvent.Event

local function compterOuverts()
    local n = 0
    for _ in pairs(openModals) do n = n + 1 end
    return n
end

local function anyOpen()
    return next(openModals) ~= nil
end

-- Retourne true si au moins une modale est ouverte
function ModalManager.IsAnyOpen()
    return anyOpen()
end

-- Enregistre l'ouverture d'une modale
-- Fire(true) uniquement si c'est la première modale ouverte
function ModalManager.Open(modalName)
    if not modalName then return end
    beforeOpenEvent:Fire(modalName)
    local etaitVide = not anyOpen()
    openModals[modalName] = true
    Logger.debug("Modal", "Open [" .. modalName .. "] — actives: " .. compterOuverts())
    if etaitVide then
        stateEvent:Fire(true)
    end
end

-- Enregistre la fermeture d'une modale
-- Fire(false) uniquement si c'était la dernière modale ouverte
function ModalManager.Close(modalName)
    if not modalName then return end
    if not openModals[modalName] then return end
    openModals[modalName] = nil
    Logger.debug("Modal", "Close [" .. modalName .. "] — actives: " .. compterOuverts())
    if not anyOpen() then
        stateEvent:Fire(false)
    end
end

-- Réinitialise tous les états (ex: respawn du joueur)
function ModalManager.Reset()
    local etaitOuvert = anyOpen()
    openModals = {}
    Logger.debug("Modal", "Reset")
    if etaitOuvert then
        stateEvent:Fire(false)
    end
end

return ModalManager
