-- ServerScriptService/Tests/MutantVisualTest.server.lua
-- SCRIPT DE TEST UNIQUEMENT — À SUPPRIMER AVANT PUBLICATION
-- Ligne 1 : 4 BRs MYTHIC/SECRET bruts
-- Ligne 2 : clones exacts de la ligne 1 + filtres Element uniquement

local ServerStorage = game:GetService("ServerStorage")
local Players       = game:GetService("Players")

-- ============================================================
-- FilterManager
-- ============================================================
local FilterManager = nil
local ServerScriptService = game:GetService("ServerScriptService")
local ok, result = pcall(function()
    return require(
        ServerScriptService
            :WaitForChild("SharedLib", 5)
            :WaitForChild("BRFilterSystem", 5)
            :WaitForChild("FilterManager", 5)
    )
end)
if ok and result then
    FilterManager = result
    print("[MutantVisualTest] FilterManager chargé.")
else
    warn("[MutantVisualTest] FilterManager introuvable :", result)
end

-- ============================================================
-- Configuration
-- ============================================================
local RARETES_LIGNE1 = { "MYTHIC", "MYTHIC", "SECRET", "SECRET" }

local FILTRES_LIGNE2 = {
    { Name = "ElementEau"   },
    { Name = "ElementFeu"   },
    { Name = "ElementTerre" },
    { Name = "ElementVent"  },
}

local ESPACEMENT  = 12
local DUREE_TEST  = 60

-- ============================================================
-- Utilitaires
-- ============================================================

local function getBrAleatoire(rarete)
    local dossier = ServerStorage:FindFirstChild("Brainrots")
    if not dossier then warn("[MutantVisualTest] ServerStorage.Brainrots introuvable") return nil end
    local rareteFolder = dossier:FindFirstChild(rarete)
    if not rareteFolder then warn("[MutantVisualTest] Dossier introuvable :", rarete) return nil end
    local enfants = rareteFolder:GetChildren()
    if #enfants == 0 then warn("[MutantVisualTest] Dossier vide :", rarete) return nil end
    return enfants[math.random(1, #enfants)]
end

-- Clone un modèle, ancre toutes les parts, nettoie tous les effets visuels natifs
local function clonerNu(source)
    local clone = source:Clone()

    for _, desc in ipairs(clone:GetDescendants()) do
        if desc:IsA("BasePart") then
            desc.Anchored   = true
            desc.CanCollide = false
        end
        if desc:IsA("PointLight") or desc:IsA("ParticleEmitter")
        or desc:IsA("Sparkles")   or desc:IsA("Fire") or desc:IsA("Smoke") then
            desc:Destroy()
        end
    end

    return clone
end

local function positionner(clone, cframe)
    if clone:IsA("Model") and clone.PrimaryPart then
        clone:SetPrimaryPartCFrame(cframe)
    elseif clone:IsA("BasePart") then
        clone.CFrame = cframe
    else
        pcall(function() clone:PivotTo(cframe) end)
    end
end

-- ============================================================
-- Attente joueur + spawn
-- ============================================================
print("[MutantVisualTest] En attente d'un joueur...")

local joueur = Players:GetPlayers()[1]
if not joueur then joueur = Players.PlayerAdded:Wait() end
if not joueur.Character then joueur.CharacterAdded:Wait() end
task.wait(2)

local rootPart = joueur.Character:WaitForChild("HumanoidRootPart", 10)
if not rootPart then
    warn("[MutantVisualTest] HumanoidRootPart introuvable — abandon.")
    return
end

print("[MutantVisualTest] Joueur :", joueur.Name)

local dossier = Instance.new("Folder")
dossier.Name   = "MutantVisualTest_Clones"
dossier.Parent = workspace

local avant  = rootPart.CFrame.LookVector
local droite = rootPart.CFrame.RightVector
local gauche = -droite * 10

local origineLigne1 = rootPart.Position - avant * 12 + gauche + Vector3.new(0, 3, 0)
local origineLigne2 = rootPart.Position + avant * 20 + gauche + Vector3.new(0, 3, 0)

-- ============================================================
-- Ligne 1 : BRs MYTHIC/SECRET bruts (nettoyés de tout effet)
-- ============================================================
local sourcesLigne1 = {}

for i, rarete in ipairs(RARETES_LIGNE1) do
    local source = getBrAleatoire(rarete)
    if source then
        local clone  = clonerNu(source)
        clone.Name   = "L1_" .. rarete
        clone.Parent = dossier

        local offset = droite * ((i - 1) * ESPACEMENT - (ESPACEMENT * (#RARETES_LIGNE1 - 1) / 2))
        positionner(clone, CFrame.new(origineLigne1 + offset))

        sourcesLigne1[i] = clone  -- on clone DEPUIS le clone L1 pour garantir l'identité
    end
end

-- ============================================================
-- Ligne 2 : clones exacts de L1 + filtre Element appliqué
-- ============================================================
for i, filtre in ipairs(FILTRES_LIGNE2) do
    local source = sourcesLigne1[i]
    if source then
        local clone  = source:Clone()  -- clone du clone L1 → identique
        clone.Name   = "L2_" .. filtre.Name
        clone.Parent = dossier

        local offset = droite * ((i - 1) * ESPACEMENT - (ESPACEMENT * (#FILTRES_LIGNE2 - 1) / 2))
        positionner(clone, CFrame.new(origineLigne2 + offset))

        if FilterManager then
            FilterManager.Apply(clone, { filtre })
        end
    end
end

print("=== MUTANT VISUAL TEST === L1: bruts | L2: +Element (eau/feu/terre/vent)")

task.delay(DUREE_TEST, function()
    if dossier and dossier.Parent then
        dossier:Destroy()
        print("[MutantVisualTest] Cleanup.")
    end
end)
