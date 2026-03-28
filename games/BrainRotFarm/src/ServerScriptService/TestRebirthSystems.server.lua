-- ServerScriptService/TestRebirthSystems.server.lua
-- ⚠️ SCRIPT DE TEST UNIQUEMENT — SUPPRIMER AVANT PUBLICATION ⚠️
-- Lance automatiquement en Studio au démarrage du serveur

local ReplicatedStorage     = game:GetService("ReplicatedStorage")
local Players               = game:GetService("Players")
local RunService            = game:GetService("RunService")

-- Sécurité : ne s'exécute qu'en Studio, jamais en production
if not RunService:IsStudio() then
    return
end

task.wait(3)  -- Laisser les systèmes s'initialiser

local BaseProgressionSystem = require(ReplicatedStorage.SharedLib.Server.BaseProgressionSystem)
local NotifEvent            = ReplicatedStorage:FindFirstChild("NotifEvent")

print("========================================")
print("[TEST] TestRebirthSystems démarré")
print("========================================")

-- ============================================================
-- TEST 1 : Prix dynamiques floors (GetFloorUnlockCost)
-- ============================================================
print("\n--- TEST 1 : Prix floors dynamiques ---")

local cas = {
    { floor = 2, rebirth = 0,  attendu = 100000, label = "Floor 2, Rebirth 0  → -0%"  },
    { floor = 2, rebirth = 3,  attendu = 55000,  label = "Floor 2, Rebirth 3  → -45%" },
    { floor = 2, rebirth = 6,  attendu = 10000,  label = "Floor 2, Rebirth 6  → cap -90%" },
    { floor = 3, rebirth = 0,  attendu = 200000, label = "Floor 3, Rebirth 0  → -0%"  },
    { floor = 3, rebirth = 3,  attendu = 110000, label = "Floor 3, Rebirth 3  → -45%" },
    { floor = 4, rebirth = 0,  attendu = 300000, label = "Floor 4, Rebirth 0  → -0%"  },
    { floor = 4, rebirth = 10, attendu = 30000,  label = "Floor 4, Rebirth 10 → cap -90%" },
}

local tousOK = true
for _, cas in ipairs(cas) do
    local obtenu = BaseProgressionSystem.GetFloorUnlockCost(cas.floor, cas.rebirth)
    local ok     = obtenu == cas.attendu
    local statut = ok and "✅" or "❌"
    print(string.format("%s %s | obtenu=%d, attendu=%d", statut, cas.label, obtenu, cas.attendu))
    if not ok then tousOK = false end
end

if tousOK then
    print("✅ TEST 1 PASSÉ : tous les prix sont corrects")
else
    print("❌ TEST 1 ÉCHOUÉ : vérifier Config.FloorUnlockCosts + Config.RebirthFloorDiscount")
end

-- ============================================================
-- TEST 2 : Notification REBIRTH_GLOBAL
-- ============================================================
print("\n--- TEST 2 : Notification Rebirth Global ---")

if NotifEvent then
    -- Attendre qu'un joueur rejoigne pour voir la notification
    task.delay(2, function()
        local msg = "⚡ TestPlayer just performed their Rebirth III! (×3.0)"
        NotifEvent:FireAllClients("REBIRTH_GLOBAL", msg)
        print("✅ TEST 2 : NotifEvent REBIRTH_GLOBAL envoyé → vérifier l'écran client")
    end)
else
    print("❌ TEST 2 : NotifEvent introuvable (Main.server.lua non chargé ?)")
end

-- ============================================================
-- TEST 3 : Cosmétiques Rebirth (attendre un joueur)
-- ============================================================
print("\n--- TEST 3 : Cosmétiques Rebirth (joueur requis) ---")
print("ℹ️ TEST 3 : rejoindre la partie avec un joueur ayant rebirthLevel > 0 pour voir les effets")
print("   → Rebirth 1  : aura bleue")
print("   → Rebirth 3  : aura violette + trail")
print("   → Rebirth 5  : aura dorée + trail")
print("   → Rebirth 10 : aura rouge + trail orange + flammes tête")

-- Simulation rapide : forcer rebirthLevel sur le premier joueur pour test visuel
Players.PlayerAdded:Connect(function(player)
    task.wait(5)
    -- Simuler Rebirth 5 via attribute (test uniquement)
    local char = player.Character
    if char then
        print(string.format(
            "[TEST 3] %s connecté — forcer rebirthLevel=5 pour tester cosmétiques",
            player.Name
        ))
        -- Note : pour un vrai test, modifier playerData.rebirthLevel via DataStoreManager
        -- et relancer avec /tp ou mort du personnage pour déclencher CharacterAdded
    end
end)

print("\n========================================")
print("[TEST] Tous les tests automatiques terminés")
print("[TEST] Vérifier l'Output pour les résultats")
print("========================================")
