-- ServerScriptService/BaseSpawner.lua
-- ⚠️  DOIT ÊTRE UN MODULESCRIPT (pas un Script)
--     pour être requirable par BrainrotSpawnManager
-- Gère le clonage de la base de chaque joueur sur un slot libre

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Template de base (dans ReplicatedStorage)
local baseTemplate = ReplicatedStorage:WaitForChild("BaseTemplate")

-- Dossier des slots dans Workspace (Parts invisibles Slot_1 … Slot_6)
local slotsFolder = workspace:WaitForChild("Slots")

-- ── Tables internes ────────────────────────────────────────────
-- slots : [Part] = Player (présent = occupé, absent = libre)
local slots       = {}  -- stocke uniquement les slots OCCUPÉS
local playerBases = {}  -- [Player] = { model = Model, slot = Part }

-- ── Utilitaire : premier slot libre ───────────────────────────
-- Lit les enfants du dossier dynamiquement (évite la race condition d'init)
local function TrouverSlotLibre()
    for _, slot in ipairs(slotsFolder:GetChildren()) do
        if slot:IsA("BasePart") and slots[slot] == nil then
            return slot
        end
    end
    return nil
end

-- ── Spawn de la base à l'arrivée du joueur ─────────────────────
local function OnPlayerAdded(player)
    local slot = TrouverSlotLibre()
    if not slot then
        warn("[BaseSpawner] Aucun slot disponible pour " .. player.Name)
        return
    end

    -- Réserver le slot
    slots[slot] = player

    -- Cloner le template et le positionner sur le slot
    local base  = baseTemplate:Clone()
    base.Name   = "Base_" .. player.UserId

    -- PivotTo ne fonctionne que sur les Models
    if base:IsA("Model") then
        base:PivotTo(slot.CFrame)
    else
        -- Fallback : déplacer toutes les BaseParts (si BaseTemplate est un Folder)
        local offset = slot.CFrame
        for _, part in ipairs(base:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CFrame = offset * part.CFrame
            end
        end
    end

    base.Parent = workspace

    playerBases[player] = { model = base, slot = slot }
    print("[BaseSpawner] Base créée → " .. player.Name .. " sur " .. slot.Name)
end

-- ── Destruction de la base à la déconnexion ────────────────────
local function OnPlayerRemoving(player)
    local data = playerBases[player]
    if not data then return end

    -- Détruire la base
    if data.model and data.model.Parent then
        data.model:Destroy()
    end

    -- Libérer le slot
    slots[data.slot] = nil
    playerBases[player] = nil

    print("[BaseSpawner] Base détruite → " .. player.Name)
end

Players.PlayerAdded:Connect(OnPlayerAdded)
Players.PlayerRemoving:Connect(OnPlayerRemoving)

-- Joueurs déjà connectés (si le module est chargé tardivement)
for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(OnPlayerAdded, player)
end

-- ══════════════════════════════════════════════════════════════
-- API PUBLIQUE
-- ══════════════════════════════════════════════════════════════

local BaseSpawner = {}

-- Retourne le Model de la base du joueur (ou nil si pas de base)
function BaseSpawner.GetBase(player)
    local data = playerBases[player]
    return data and data.model or nil
end

-- Retourne la Part "SpawnArea" dans la base du joueur (ou nil)
-- Cherche en récursif pour supporter des structures imbriquées
function BaseSpawner.GetSpawnArea(player)
    local base = BaseSpawner.GetBase(player)
    if not base then return nil end
    return base:FindFirstChild("SpawnArea", true)
end

return BaseSpawner
