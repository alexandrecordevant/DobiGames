-- ServerScriptService/Debug/DiagnosticCarry.server.lua
-- Diagnostic carry en temps réel (graines, portes, capacité, backpack)
-- Activer en Play Solo — lire Output
-- SUPPRIMER avant publication en production

local Players             = game:GetService("Players")
local DataStoreService    = game:GetService("DataStoreService")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")

local DS = DataStoreService:GetDataStore("BrainRotIdleV1")

-- Charger CarrySystem via le chemin correct (identique à Main.server.lua)
local CarrySystem = require(ServerScriptService.SharedLib.Server.CarrySystem)

-- ============================================================
-- Utilitaire : afficher l'état complet du carry d'un joueur
-- ============================================================
local function diagnostiquerJoueur(player)
    print("\n══════════════════════════════════════════════")
    print("=== DIAGNOSTIC CARRY — " .. player.Name .. " ===")
    print("══════════════════════════════════════════════")

    -- 1. Données DataStore (raw)
    local ok, dsData = pcall(function()
        return DS:GetAsync("player_" .. player.UserId)
    end)
    if ok and dsData then
        print("[DS] upgradeCarry    :", (dsData.upgrades and dsData.upgrades.upgradeCarry) or "n/a")
        print("[DS] graines         :", "MYTHIC=" .. tostring(dsData.graines and dsData.graines.MYTHIC or "?")
            .. " | SECRET=" .. tostring(dsData.graines and dsData.graines.SECRET or "?"))
        local nbCarryPortes = dsData.carryPortes and #dsData.carryPortes or 0
        print("[DS] carryPortes     :", nbCarryPortes .. " entrée(s)")
        if nbCarryPortes > 0 then
            for i, e in ipairs(dsData.carryPortes) do
                print(string.format("  [%d] nom=%-12s dossier=%-12s isMutant=%s",
                    i, tostring(e.nom), tostring(e.dossier), tostring(e.isMutant)))
            end
        end
    else
        warn("[DS] GetAsync échoué :", ok, dsData)
    end

    -- 2. CarrySystem état en mémoire (portes actifs en session)
    local portes = CarrySystem.GetPortes(player)
    local max    = CarrySystem.GetCapaciteMax(player)
    local estPlein = CarrySystem.EstPlein(player)
    print("\n[Live] Capacité max   :", max)
    print("[Live] EstPlein       :", estPlein)
    print("[Live] data.portes    :", #portes .. " entrée(s)")
    if #portes > 0 then
        for i, entree in ipairs(portes) do
            local toolParent = entree.toolRef and tostring(entree.toolRef.Parent) or "NIL"
            local toolValide = entree.toolRef and entree.toolRef.Parent ~= nil
            print(string.format("  [%d] rarete=%-12s toolRef=%s parent=%s",
                i,
                entree.rarete and tostring(entree.rarete.nom) or "?",
                entree.toolRef and "OK" or "NIL",
                toolValide and "✅ " .. toolParent or "❌ FANTÔME"
            ))
        end
    end

    -- 3. Folder CarriedSeeds (graines en session)
    local carriedSeeds = player:FindFirstChild("CarriedSeeds")
    if carriedSeeds then
        local seedList = carriedSeeds:GetChildren()
        print("\n[Live] CarriedSeeds   :", #seedList .. " graine(s)")
        for i, sv in ipairs(seedList) do
            print(string.format("  [%d] rarete=%s", i, sv.Value or "?"))
        end
    else
        print("[Live] CarriedSeeds   : absent (0 graines portées)")
    end

    -- 4. Backpack Tools
    local backpack = player:FindFirstChildOfClass("Backpack")
    local tools = {}
    if backpack then
        for _, t in ipairs(backpack:GetChildren()) do
            if t:IsA("Tool") then
                table.insert(tools, t)
            end
        end
    end
    -- Tool équipé dans le Character
    if player.Character then
        for _, t in ipairs(player.Character:GetChildren()) do
            if t:IsA("Tool") then
                table.insert(tools, t)
            end
        end
    end
    print("\n[Live] Backpack Tools :", #tools .. " outil(s)")
    for i, t in ipairs(tools) do
        local rarete = t:GetAttribute("Rarete") or "?"
        local isSeed = t:GetAttribute("IsSeed") and "SEED" or "BR"
        print(string.format("  [%d] %-25s type=%-4s rarete=%s",
            i, t.Name, isSeed, rarete))
    end

    -- 5. Total carry occupé vs max
    local total = #portes + (carriedSeeds and #carriedSeeds:GetChildren() or 0)
    print(string.format("\n[Résumé] %d/%d slots occupés (%d BR + %d graines) — %s",
        total, max,
        #portes,
        carriedSeeds and #carriedSeeds:GetChildren() or 0,
        estPlein and "PLEIN ❌" or "OK ✅"
    ))
    print("══════════════════════════════════════════════\n")
end

-- ============================================================
-- Déclencher au login (après chargement Main.server.lua)
-- ============================================================
Players.PlayerAdded:Connect(function(player)
    task.wait(5) -- attendre que Main.server.lua charge tout
    diagnostiquerJoueur(player)
end)

-- Pour les joueurs déjà connectés (Play Solo)
task.wait(6)
for _, player in ipairs(Players:GetPlayers()) do
    diagnostiquerJoueur(player)
end

-- ============================================================
-- Commande console : taper "diag" dans le chat pour re-diagnostiquer
-- ============================================================
Players.PlayerAdded:Connect(function(player)
    player.Chatted:Connect(function(msg)
        if msg:lower() == "diag" then
            diagnostiquerJoueur(player)
        end
    end)
end)
for _, player in ipairs(Players:GetPlayers()) do
    player.Chatted:Connect(function(msg)
        if msg:lower() == "diag" then
            diagnostiquerJoueur(player)
        end
    end)
end

print("[DiagnosticCarry] Script chargé — tape 'diag' dans le chat pour rafraîchir")
