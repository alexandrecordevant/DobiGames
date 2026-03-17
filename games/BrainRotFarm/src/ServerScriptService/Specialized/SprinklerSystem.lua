-- ServerScriptService/Common/SprinklerSystem.lua
-- DobiGames — Gestion activation/vitesse des sprinklers par base
-- Désactivé par défaut — activé uniquement si upgrade Arroseur acheté

local SprinklerSystem = {}

-- ============================================================
-- Services
-- ============================================================
local Workspace    = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ============================================================
-- Config — vitesses lues depuis GameConfig (0 valeur hardcodée)
-- ============================================================
local Config  = require(ReplicatedStorage.Specialized.GameConfig)
local VITESSES = Config.SprinklerVitesses or { [0]=0, [1]=30, [2]=60, [3]=120 }

-- ============================================================
-- Utilitaires
-- ============================================================

-- Retourne tous les Scripts/LocalScripts dans le dossier Sprinklers
local function getScriptsSprinkler(sprinklersFolder)
    local scripts = {}
    for _, desc in ipairs(sprinklersFolder:GetDescendants()) do
        if desc:IsA("Script") or desc:IsA("LocalScript") then
            table.insert(scripts, desc)
        end
    end
    return scripts
end

-- Essaie de définir la vitesse angulaire d'une part (BodyAngularVelocity ou AngularVelocity)
local function appliquerVitessePart(part, vitesseDegres)
    local bav = part:FindFirstChildOfClass("BodyAngularVelocity")
    if bav then
        pcall(function()
            bav.AngularVelocity = Vector3.new(0, math.rad(vitesseDegres), 0)
        end)
        return
    end
    local av = part:FindFirstChildOfClass("AngularVelocity")
    if av then
        pcall(function()
            av.AngularVelocity = Vector3.new(0, math.rad(vitesseDegres), 0)
        end)
        return
    end
    -- Arrêt physique si vitesse = 0
    if vitesseDegres == 0 then
        pcall(function()
            part.AssemblyAngularVelocity = Vector3.zero
        end)
    end
end

-- Cherche les parts rotatives (nom contenant arm/pivot/rotate/rotor/head/nozzle)
local function getPartsRotatives(sprinklersFolder)
    local parts = {}
    local patterns = { "arm", "pivot", "rotat", "rotor", "head", "nozzle", "tete" }
    for _, desc in ipairs(sprinklersFolder:GetDescendants()) do
        if desc:IsA("BasePart") then
            local nom = string.lower(desc.Name)
            for _, pat in ipairs(patterns) do
                if nom:find(pat) then
                    table.insert(parts, desc)
                    break
                end
            end
        end
    end
    -- Fallback : toutes les BaseParts si aucun nom reconnu
    if #parts == 0 then
        for _, desc in ipairs(sprinklersFolder:GetDescendants()) do
            if desc:IsA("BasePart") then
                table.insert(parts, desc)
            end
        end
    end
    return parts
end

-- ============================================================
-- API publique
-- ============================================================

-- Désactiver tous les sprinklers d'une base
function SprinklerSystem.DesactiverBase(baseIndex)
    local base = Workspace:FindFirstChild("Bases")
                 and Workspace.Bases:FindFirstChild("Base_" .. baseIndex)
    if not base then return end

    local sprinklersFolder = base:FindFirstChild("Sprinklers")
    if not sprinklersFolder then return end

    -- Désactiver les scripts
    for _, script in ipairs(getScriptsSprinkler(sprinklersFolder)) do
        pcall(function() script.Disabled = true end)
    end

    -- Stopper les rotations physiques
    for _, part in ipairs(sprinklersFolder:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function()
                part.AssemblyAngularVelocity = Vector3.zero
            end)
            appliquerVitessePart(part, 0)
        end
    end

    print("[SprinklerSystem] Base_" .. baseIndex .. " sprinklers désactivés")
end

-- Activer les sprinklers d'une base au niveau donné (0 = désactiver)
function SprinklerSystem.ActiverBase(baseIndex, niveau)
    if niveau == 0 then
        SprinklerSystem.DesactiverBase(baseIndex)
        return
    end

    local base = Workspace:FindFirstChild("Bases")
                 and Workspace.Bases:FindFirstChild("Base_" .. baseIndex)
    if not base then
        warn("[SprinklerSystem] Base_" .. baseIndex .. " introuvable")
        return
    end

    local sprinklersFolder = base:FindFirstChild("Sprinklers")
    if not sprinklersFolder then
        warn("[SprinklerSystem] Dossier Sprinklers introuvable dans Base_" .. baseIndex)
        return
    end

    local vitesse = VITESSES[niveau] or VITESSES[1] or 30

    -- Activer les scripts (ils reprennent leur animation)
    for _, script in ipairs(getScriptsSprinkler(sprinklersFolder)) do
        pcall(function() script.Disabled = false end)
    end

    -- Appliquer la vitesse de rotation sur les parts rotatives
    for _, part in ipairs(getPartsRotatives(sprinklersFolder)) do
        appliquerVitessePart(part, vitesse)
    end

    print(string.format(
        "[SprinklerSystem] Base_%d sprinkler activé — niveau %d (%.0f°/s)",
        baseIndex, niveau, vitesse
    ))
end

-- Init : désactiver tous les sprinklers au démarrage serveur
function SprinklerSystem.Init()
    -- Attendre que les Bases soient chargées (max 10s)
    local bases = Workspace:FindFirstChild("Bases")
    if not bases then
        local t = 0
        repeat
            task.wait(0.5)
            t = t + 0.5
            bases = Workspace:FindFirstChild("Bases")
        until bases or t >= 10
    end

    if not bases then
        warn("[SprinklerSystem] Workspace.Bases introuvable — Init ignoré")
        return
    end

    for i = 1, 6 do
        SprinklerSystem.DesactiverBase(i)
    end

    print("[SprinklerSystem] ✓ Init — tous sprinklers désactivés par défaut")
end

return SprinklerSystem
