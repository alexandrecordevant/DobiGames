-- ServerScriptService/Systems/FlowerPotSystem/TestFlowerPotGrowth.server.lua
-- DobiGames BrainRotFarm — Script de diagnostic FlowerPot Growth System
-- ⚠️ ACTIVER UNIQUEMENT EN MODE TEST — désactiver avant publication
-- Utilisation : lancer depuis Studio et observer l'Output pour vérifier la séquence

-- ============================================================
-- Chargement du système
-- ============================================================
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerStorage       = game:GetService("ServerStorage")
local Players             = game:GetService("Players")
local Workspace           = game:GetService("Workspace")

-- Attendre que les modules soient chargés
task.wait(3)

local ok, FGS = pcall(require,
    ServerScriptService.Systems.FlowerPotSystem.FlowerPotGrowthSystem)
if not ok or not FGS then
    warn("[TestFlowerPotGrowth] ❌ FlowerPotGrowthSystem introuvable :", FGS)
    return
end

print("[TestFlowerPotGrowth] ✅ FlowerPotGrowthSystem chargé")

-- ============================================================
-- Vérification assets ServerStorage
-- ============================================================
print("\n[TestFlowerPotGrowth] === VÉRIFICATION ASSETS ===")

local function checkAsset(path)
    local current = ServerStorage
    local parts   = string.split(path, "/")
    for _, part in ipairs(parts) do
        current = current:FindFirstChild(part)
        if not current then
            warn("[TestFlowerPotGrowth] ❌ MANQUANT :", path, "— créer dans Studio")
            return false
        end
    end
    print("[TestFlowerPotGrowth] ✅ Trouvé :", path)
    return true
end

-- Vérifier GenericSeed
checkAsset("Seeds/GenericSeed")

-- Vérifier Plant_Stage0 à Plant_Stage3
for i = 0, 3 do
    checkAsset("Plants/Plant_Stage" .. i)
end

-- Vérifier dossiers MYTHIC et SECRET dans Brainrots
local brMYTHIC = ServerStorage:FindFirstChild("Brainrots")
    and ServerStorage.Brainrots:FindFirstChild("MYTHIC")
local brSECRET = ServerStorage:FindFirstChild("Brainrots")
    and ServerStorage.Brainrots:FindFirstChild("SECRET")

if brMYTHIC and #brMYTHIC:GetChildren() > 0 then
    print("[TestFlowerPotGrowth] ✅ Brainrots/MYTHIC —", #brMYTHIC:GetChildren(), "modèle(s)")
else
    warn("[TestFlowerPotGrowth] ❌ Brainrots/MYTHIC vide ou absent")
end

if brSECRET and #brSECRET:GetChildren() > 0 then
    print("[TestFlowerPotGrowth] ✅ Brainrots/SECRET —", #brSECRET:GetChildren(), "modèle(s)")
else
    warn("[TestFlowerPotGrowth] ❌ Brainrots/SECRET vide ou absent")
end

-- ============================================================
-- Vérification GameConfig FlowerPotGrowthSystem
-- ============================================================
print("\n[TestFlowerPotGrowth] === VÉRIFICATION GAMECONFIG ===")

local Config = require(ReplicatedStorage.GameConfig)
local FPC    = Config.FlowerPotConfig

local champsRequis = {
    "GrowthDuration", "MutantSpawnStage", "MutantOffsetY",
    "ElementTypes", "ElementMultipliers", "ElementParticles",
}

for _, champ in ipairs(champsRequis) do
    if FPC[champ] ~= nil then
        print("[TestFlowerPotGrowth] ✅ FlowerPotConfig." .. champ)
    else
        warn("[TestFlowerPotGrowth] ❌ FlowerPotConfig." .. champ .. " manquant — ajouter à GameConfig")
    end
end

-- Afficher les multiplicateurs configurés
print("\n[TestFlowerPotGrowth] Multiplicateurs élémentaires :")
if FPC.ElementMultipliers then
    for elem, mult in pairs(FPC.ElementMultipliers) do
        print(string.format("  %s → ×%d", elem, mult))
    end
end

-- ============================================================
-- Test de croissance sur un pot de test
-- ============================================================
print("\n[TestFlowerPotGrowth] === TEST CROISSANCE ===")

-- Chercher un pot dans le Workspace (Base_1/FlowerPot_1)
local function trouverPotTest()
    local bases = Workspace:FindFirstChild("Bases")
    if not bases then
        warn("[TestFlowerPotGrowth] Workspace.Bases introuvable — créer la structure dans Studio")
        return nil
    end

    -- Chercher la première base
    for _, base in ipairs(bases:GetChildren()) do
        local pot = base:FindFirstChild("FlowerPot_1")
        if pot then
            print("[TestFlowerPotGrowth] Pot test trouvé :", pot:GetFullName())
            return pot
        end
    end

    warn("[TestFlowerPotGrowth] Aucun FlowerPot_1 trouvé dans Workspace.Bases")
    return nil
end

-- Chercher le premier joueur connecté
local function trouverJoueurTest()
    local joueurs = Players:GetPlayers()
    if #joueurs > 0 then
        return joueurs[1]
    end
    warn("[TestFlowerPotGrowth] Aucun joueur connecté — impossible de tester le carry")
    return nil
end

local pot    = trouverPotTest()
local player = trouverJoueurTest()

if pot then
    -- Forcer durée courte pour le test (override DUREE_PAR_STAGE)
    -- La config TEST_MODE réduira les durées si activée dans GameConfig
    if Config.TEST_MODE then
        print("[TestFlowerPotGrowth] TEST_MODE actif — durées réduites")
    else
        print("[TestFlowerPotGrowth] ⚠️ TEST_MODE inactif — durées réelles (8 min)")
        print("[TestFlowerPotGrowth] → Activer Config.TEST_MODE = true dans GameConfig pour test rapide")
    end

    print("\n[TestFlowerPotGrowth] Lancement croissance MYTHIC sur", pot.Name)
    print("[TestFlowerPotGrowth] Séquence attendue :")
    print("  1. GenericSeed apparaît (instant)")
    print("  2. Plant_Stage0 après 2min")
    print("  3. Plant_Stage1 après 2min")
    print("  4. Plant_Stage2 + BR Mutant spawn Y+3 après 2min")
    print("  5. Plant_Stage3 après 2min")
    print("  6. Plante meurt, BR Mutant tombe sur le pot")
    print("  7. ProximityPrompt 'Récolter' apparaît")
    if player then
        print("  8. Joueur test :", player.Name)
    end

    -- Callback de vérification harvest
    local function onHarvestTest(triggerPlayer, elementType, multiplier)
        print(string.format(
            "[TestFlowerPotGrowth] ✅ HARVEST RÉUSSI | Joueur: %s | Élément: %s | ×%d",
            triggerPlayer.Name, elementType, multiplier))
    end

    -- Lancer la croissance
    FGS.PlantSeed(pot, "MYTHIC", player, onHarvestTest)

    -- Vérification statut après lancement
    task.wait(0.5)
    if FGS.EstEnCroissance(pot) then
        print("[TestFlowerPotGrowth] ✅ Croissance en cours confirmée")
    else
        warn("[TestFlowerPotGrowth] ❌ Croissance non démarrée — vérifier Output ci-dessus")
    end

else
    print("[TestFlowerPotGrowth] ⚠️ Pas de pot disponible — test manuel uniquement")
    print("[TestFlowerPotGrowth] Pour tester manuellement dans la console Studio :")
    print([[
local FGS = require(game.ServerScriptService.Systems.FlowerPotSystem.FlowerPotGrowthSystem)
local pot = workspace.Bases.Base_1.FlowerPot_1  -- adapter le chemin
local player = game.Players:GetPlayers()[1]
FGS.PlantSeed(pot, "MYTHIC", player)
    ]])
end

-- ============================================================
-- Test annulation (optionnel — décommenter pour tester)
-- ============================================================
--[[
task.wait(5)
if pot and FGS.EstEnCroissance(pot) then
    FGS.Annuler(pot)
    print("[TestFlowerPotGrowth] Test annulation — croissance stoppée après 5s")
end
]]

print("\n[TestFlowerPotGrowth] === FIN DIAGNOSTIC ===")
print("[TestFlowerPotGrowth] Surveiller l'Output pour la progression des stages")
