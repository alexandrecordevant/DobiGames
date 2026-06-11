-- ServerScriptService/BRPreviewsBuilder.lua
-- Construit ReplicatedStorage/BRPreviews au démarrage du serveur.
-- Clone les modèles depuis ServerStorage (Brainrots + Mutation) en supprimant
-- les scripts — les previews sont des shells visuels accessibles aux clients
-- pour le rendu ViewportFrame de l'IndexClient.

local BRPreviewsBuilder = {}

local ServerStorage     = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Logger = require(ServerScriptService.SharedLib.Server.Logger)

-- Supprime récursivement tous les scripts d'un clone (sécurité côté client)
local function purgerScripts(inst)
    for _, desc in ipairs(inst:GetDescendants()) do
        if desc:IsA("Script") or desc:IsA("LocalScript") or desc:IsA("ModuleScript") then
            desc:Destroy()
        end
    end
end

-- Clone récursivement un dossier source vers un dossier de destination
local function clonerDossier(source, dest)
    local count = 0
    for _, enfant in ipairs(source:GetChildren()) do
        if enfant:IsA("Folder") then
            local sousDir = Instance.new("Folder")
            sousDir.Name   = enfant.Name
            sousDir.Parent = dest
            count += clonerDossier(enfant, sousDir)
        else
            local clone = enfant:Clone()
            purgerScripts(clone)
            clone.Parent = dest
            count += 1
        end
    end
    return count
end

function BRPreviewsBuilder.Build()
    -- Nettoyer l'ancien BRPreviews s'il existe (re-build propre)
    local ancien = ReplicatedStorage:FindFirstChild("BRPreviews")
    if ancien then ancien:Destroy() end

    local previews = Instance.new("Folder")
    previews.Name   = "BRPreviews"
    previews.Parent = ReplicatedStorage

    local total = 0

    -- Brainrots normaux
    local brainrots = ServerStorage:FindFirstChild("Brainrots")
    if brainrots then
        local dest = Instance.new("Folder")
        dest.Name   = "Brainrots"
        dest.Parent = previews
        total += clonerDossier(brainrots, dest)
    else
        Logger.warn("Index", "BRPreviewsBuilder : SS.Brainrots introuvable")
    end

    -- Mutations (BrainrotsGold, BrainrotsDiamant, etc.)
    local mutation = ServerStorage:FindFirstChild("Mutation")
    if mutation then
        local dest = Instance.new("Folder")
        dest.Name   = "Mutation"
        dest.Parent = previews
        total += clonerDossier(mutation, dest)
    else
        Logger.warn("Index", "BRPreviewsBuilder : SS.Mutation introuvable")
    end

    Logger.info("Index", "BRPreviews construit : %d modeles clones dans RS", total)
end

return BRPreviewsBuilder
