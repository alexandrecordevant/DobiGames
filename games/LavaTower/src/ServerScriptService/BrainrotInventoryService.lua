-- ServerScriptService/BrainrotInventoryService.lua
-- Module : gère l'inventaire brainrot en mémoire côté serveur.
-- Structure prête pour intégration DataStore (voir commentaires).

local BrainrotInventoryService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")

-- ── RemoteEvent pour notifier le client après une collecte ──
local BrainrotCollected = Instance.new("RemoteEvent")
BrainrotCollected.Name   = "BrainrotCollected"
BrainrotCollected.Parent = ReplicatedStorage

-- ── Table runtime : inventaire par joueur (userId -> { [id] = entry })
-- Pour intégrer avec DataStore plus tard :
--   Charger cet inventaire depuis data.brainrotInventory dans DataStoreManager.Load()
--   Le sauvegarder dans data.brainrotInventory dans DataStoreManager.Save()
local inventaires = {}

-- Initialise l'inventaire d'un joueur à sa connexion
function BrainrotInventoryService.Init(player)
    inventaires[player.UserId] = {}
end

-- Nettoie la mémoire à la déconnexion
function BrainrotInventoryService.Clear(player)
    inventaires[player.UserId] = nil
end

-- Vérifie si un brainrot est déjà dans l'inventaire du joueur.
-- brainrotId : string (Attribute "BrainrotId" de l'instance, ou son Name)
function BrainrotInventoryService.Has(player, brainrotId)
    local inv = inventaires[player.UserId]
    return inv ~= nil and inv[brainrotId] ~= nil
end

-- Ajoute un brainrot à l'inventaire.
-- brainrotData : { id: string, name: string, rarity: string }
-- Retourne true si ajouté, false + raison si refusé.
function BrainrotInventoryService.Add(player, brainrotData)
    local inv = inventaires[player.UserId]
    if not inv then
        return false, "Inventaire joueur introuvable"
    end
    if inv[brainrotData.id] then
        return false, "Déjà collecté"
    end

    inv[brainrotData.id] = {
        name      = brainrotData.name,
        rarity    = brainrotData.rarity,
        timestamp = os.time(),
    }

    -- Notifie le client (HUDController peut écouter cet event)
    BrainrotCollected:FireClient(player, brainrotData)

    print(("[Inventory] %s a collecté %s (%s)"):format(
        player.Name, brainrotData.name, brainrotData.rarity))

    return true
end

-- Retourne tout l'inventaire d'un joueur (copie)
function BrainrotInventoryService.GetAll(player)
    local inv = inventaires[player.UserId]
    if not inv then return {} end
    -- Copie superficielle pour éviter les modifications extérieures
    local copy = {}
    for id, entry in pairs(inv) do
        copy[id] = entry
    end
    return copy
end

-- Nettoyage auto à la déconnexion
Players.PlayerRemoving:Connect(function(player)
    BrainrotInventoryService.Clear(player)
end)

return BrainrotInventoryService
