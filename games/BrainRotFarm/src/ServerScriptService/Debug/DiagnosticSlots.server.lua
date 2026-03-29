-- ServerScriptService/Debug/DiagnosticSlots.server.lua
-- Diagnostic système de slots + persistence des BR
-- Exécuter en Play Solo — lire Output pour analyser les bugs
-- SUPPRIMER avant publication en production

local Players           = game:GetService("Players")
local DataStoreService  = game:GetService("DataStoreService")
local ServerStorage     = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DS = DataStoreService:GetDataStore("BrainRotIdleV1")

-- ============================================================
-- TEST 1 : Structure DataStore au login
-- ============================================================
Players.PlayerAdded:Connect(function(player)
    task.wait(3) -- attendre que DataManager + DropSystem chargent

    local ok, data = pcall(function()
        return DS:GetAsync("player_" .. player.UserId)
    end)

    print("\n══════════════════════════════════════════")
    print("=== DIAGNOSTIC SLOTS — " .. player.Name .. " ===")
    print("══════════════════════════════════════════")

    if not ok or not data then
        warn("[Diag] GetAsync échoué ou données vides — joueur nouveau ou erreur DataStore")
        return
    end

    print("[Diag] Coins sauvegardés    :", data.coins or 0)
    print("[Diag] Rebirth level        :", data.rebirthLevel or 0)
    print("[Diag] Multiplicateur       :", data.multiplicateurPermanent or 1.0)

    -- Analyser spotsOccupes
    if data.spotsOccupes and next(data.spotsOccupes) then
        print("\n--- SPOTS OCCUPÉS (DataStore) ---")
        local nbSpots = 0
        local nbAvecBrNom = 0
        local nbSansBrNom = 0

        for spotKey, info in pairs(data.spotsOccupes) do
            nbSpots = nbSpots + 1
            print(string.format("  Spot [%s] rarete=%-12s valeurSec=%-4s isMutant=%s brNom=%s",
                spotKey,
                tostring(info.rarete),
                tostring(info.valeurSec),
                tostring(info.isMutant),
                tostring(info.brNom)
            ))

            if info.brNom then
                nbAvecBrNom = nbAvecBrNom + 1

                -- Vérifier que le modèle existe bien dans ServerStorage
                local brainrots = ServerStorage:FindFirstChild("Brainrots")
                local dossier   = brainrots and brainrots:FindFirstChild(info.rarete)
                local modele    = dossier and dossier:FindFirstChild(info.brNom)

                if modele then
                    print("    ✅ Modèle trouvé dans ServerStorage : " .. info.brNom)
                else
                    warn("    ❌ PROBLÈME : modèle '" .. tostring(info.brNom) .. "' introuvable dans ServerStorage/" .. tostring(info.rarete))
                    if dossier then
                        local enfants = dossier:GetChildren()
                        print("    Modèles disponibles dans " .. info.rarete .. " (" .. #enfants .. ") :")
                        for _, e in ipairs(enfants) do
                            print("      - " .. e.Name)
                        end
                    else
                        warn("    Dossier rareté '" .. tostring(info.rarete) .. "' introuvable dans ServerStorage.Brainrots")
                    end
                end
            else
                nbSansBrNom = nbSansBrNom + 1
                warn("    ⚠️ brNom manquant → restore sera ALÉATOIRE pour ce spot")
            end
        end

        print(string.format("\n  Résumé : %d spots | %d avec brNom | %d sans brNom",
            nbSpots, nbAvecBrNom, nbSansBrNom))

        if nbSansBrNom > 0 then
            warn("[Diag] " .. nbSansBrNom .. " spot(s) sans brNom → reconnexion non-déterministe (bug connu)")
        end
    else
        print("[Diag] Aucun spot occupé sauvegardé (normal si première session)")
    end

    -- Analyser pots si présents
    if data.pots then
        print("\n--- POTS DE FLEURS (DataStore) ---")
        for i, pot in pairs(data.pots) do
            if pot.rarete then
                print(string.format("  Pot %d : rarete=%s stage=%d tempsRestant=%d",
                    i, tostring(pot.rarete), pot.stage or 0, pot.tempsRestant or 0))
            end
        end
    end

    print("══════════════════════════════════════════\n")
end)

-- ============================================================
-- TEST 2 : Tracer les opérations DropSystem en runtime
-- (hook sur RemoteEvents pour observer sans modifier DropSystem)
-- ============================================================

task.spawn(function()
    task.wait(2) -- attendre RemoteEvents créés par Main.server.lua

    local NotifEvent = game.ReplicatedStorage:FindFirstChild("NotifEvent")
    if NotifEvent then
        -- Observer les notifications (Deposit/Retrieve/Sell passent par NotifEvent)
        NotifEvent.OnServerEvent:Connect(function(player, typeNotif, message)
            if typeNotif == "INFO" then
                print(string.format("[Diag:Notif] %s → %s", player.Name, tostring(message)))
            end
        end)
        print("[DiagnosticSlots] Écoute NotifEvent activée ✓")
    end
end)

-- ============================================================
-- TEST 3 : Vérifier la structure ServerStorage.Brainrots
-- ============================================================

task.spawn(function()
    task.wait(1)

    local brainrots = ServerStorage:FindFirstChild("Brainrots")
    if not brainrots then
        warn("[Diag] ServerStorage.Brainrots introuvable — spawn impossible !")
        return
    end

    print("\n--- SERVERSSTORAGE.BRAINROTS ---")
    local raretesConfig = {
        "COMMON", "OG", "RARE", "EPIC", "LEGENDARY", "MYTHIC", "SECRET", "BRAINROT_GOD"
    }
    for _, rarete in ipairs(raretesConfig) do
        local dossier = brainrots:FindFirstChild(rarete)
        if dossier then
            local enfants = dossier:GetChildren()
            print(string.format("  %-15s : %d modèle(s)", rarete, #enfants))
        else
            warn(string.format("  %-15s : ❌ dossier manquant", rarete))
        end
    end
    print("─────────────────────────────────\n")
end)

print("[DiagnosticSlots] Script chargé — diagnostics actifs")
