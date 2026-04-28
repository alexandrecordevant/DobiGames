-- StarterPlayerScripts/SoundManager.client.lua
-- BrainRotFarm — Gestionnaire centralisé des sons UI/gameplay côté client

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService      = game:GetService("SoundService")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

-- ============================================================
-- Création des sons depuis GameConfig
-- ============================================================

local function creerSon(nom, id, volume)
    if not id or id == 0 then return nil end
    local son      = Instance.new("Sound")
    son.Name       = nom
    son.SoundId    = "rbxassetid://" .. tostring(id)
    son.Volume     = volume or 0.7
    son.RollOffMaxDistance = 0
    son.Parent     = SoundService
    return son
end

local sons = {
    collecte  = creerSon("SonCollecte", GameConfig.SonCollecte, 0.6),
    depot     = creerSon("SonDepot",    GameConfig.SonDepot,    0.7),
    evenement = creerSon("SonEvent",    GameConfig.SonEvent,    0.8),
    upgrade   = creerSon("SonUpgrade",  GameConfig.SonUpgrade,  0.8),
    graine    = creerSon("SonGraine",   GameConfig.SonGraine,   0.7),
    rare      = creerSon("SonRare",     GameConfig.SonRare,     1.0),
}

-- Table de dispatch : typeNotif → son à jouer
local NOTIF_SONS = {
    RARE         = sons.rare,
    AMELIORATION = sons.upgrade,
}

-- Table de dispatch : nom → son (pour SoundEvent serveur→client)
local SOUND_DISPATCH = {
    SonCollecte = sons.collecte,
    SonDepot    = sons.depot,
    SonUpgrade  = sons.upgrade,
    SonRare     = sons.rare,
}

local function jouer(son)
    if son then pcall(function() son:Play() end) end
end

-- ============================================================
-- Collecte / Dépôt — BrainrotCarryUpdate
-- carried augmente = ramassage | carried diminue = dépôt
-- ============================================================

local carryPrev = 0

local reCarry = ReplicatedStorage:WaitForChild("BrainrotCarryUpdate", 10)
if reCarry then
    reCarry.OnClientEvent:Connect(function(carried)
        local n = tonumber(carried) or 0
        if n > carryPrev then
            jouer(sons.collecte)
        elseif n < carryPrev then
            jouer(sons.depot)
        end
        carryPrev = n
    end)
end

-- ============================================================
-- Événements — NightMode + Rain
-- ============================================================

local reNight = ReplicatedStorage:WaitForChild("NightModeStart", 10)
if reNight then
    reNight.OnClientEvent:Connect(function()
        jouer(sons.evenement)
    end)
end

local reRain = ReplicatedStorage:WaitForChild("RainEventStart", 10)
if reRain then
    reRain.OnClientEvent:Connect(function()
        jouer(sons.evenement)
    end)
end

-- ============================================================
-- NotifEvent — RARE (MYTHIC/SECRET spawn) + AMELIORATION (upgrade de base)
-- ============================================================

local reNotif = ReplicatedStorage:WaitForChild("NotifEvent", 10)
if reNotif then
    reNotif.OnClientEvent:Connect(function(typeNotif)
        jouer(NOTIF_SONS[typeNotif])
    end)
end

-- ============================================================
-- SoundEvent — déclenché serveur→client (ex: tracteur auto-collect)
-- ============================================================

local reSoundEvent = ReplicatedStorage:WaitForChild("SoundEvent", 10)
if reSoundEvent then
    reSoundEvent.OnClientEvent:Connect(function(nomSon)
        jouer(SOUND_DISPATCH[nomSon])
    end)
end
