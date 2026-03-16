-- ReplicatedStorage/Test/TestRunner.lua
-- Guide de test interactif BrainRotFarm
-- S'active automatiquement si GameConfig.TEST_MODE = true
-- Appelé depuis Main.server.lua : TestRunner.Init()

local TestRunner = {}

local Config = require(game.ReplicatedStorage.Specialized.GameConfig)

-- ============================================================
-- Helpers — affichage conditionnel
-- ============================================================

local function log(message)
    if not Config.TEST_MODE then return end
    print("[🧪 TEST] " .. message)
end

local function logEtape(numero, titre, instructions)
    if not Config.TEST_MODE then return end
    print("")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("🧪 ÉTAPE " .. numero .. " — " .. titre)
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    for _, ligne in ipairs(instructions) do
        print("   " .. ligne)
    end
    print("")
end

local function logOK(message)
    if not Config.TEST_MODE then return end
    print("[✅ OK] " .. message)
end

local function logWarn(message)
    if not Config.TEST_MODE then return end
    warn("[⚠️  TEST] " .. message)
end

-- ============================================================
-- Plan de test complet
-- ============================================================

local PLAN_DE_TEST = {

    {
        numero  = 0,
        titre   = "RESET PROGRESSION (avant tout test)",
        attente = 0,
        instructions = {
            "▶ Exécuter dans la console Studio (barre en bas de l'Output) :",
            "",
            "  -- Reset complet : efface DataStore + kick le joueur",
            "  game.ReplicatedStorage:WaitForChild('DEBUG_Reset'):FireServer('joueur')",
            "",
            "  -- Reset DataStore seulement (pas de kick — nouvelles données au prochain chargement)",
            "  game.ReplicatedStorage:WaitForChild('DEBUG_Reset'):FireServer('data')",
            "",
            "  -- Reset tous les joueurs connectés",
            "  game.ReplicatedStorage:WaitForChild('DEBUG_Reset'):FireServer('tous')",
            "",
            "  -- Reset visuel de la base seulement (sans toucher au DataStore)",
            "  game.ReplicatedStorage:WaitForChild('DEBUG_Reset'):FireServer('visuel')",
            "",
            "▶ OU : TestConfig.AutoResetOnJoin = true → reset auto à chaque connexion",
            "       (désactiver pour tester la persistance — étape 14)",
            "",
            "✅ OBJECTIF : partir de zéro pour chaque run de test",
        },
    },

    {
        numero  = 1,
        titre   = "ASSIGNATION BASE",
        attente = 2,
        instructions = {
            "▶ Rejoindre le jeu",
            "▶ Console : '[AssignationSystem] [Nom] → Base_1'",
            "▶ Tu spawnes dans ta base (SpawnZone)",
            "▶ Notification : '🏠 Tu as été assigné à la Base 1 !'",
            "",
            "✅ ATTENDU : Téléportation à la base au spawn",
        },
    },

    {
        numero  = 2,
        titre   = "SPAWN BRAIN ROTS (champ individuel)",
        attente = 3,
        instructions = {
            "▶ Attendre 1-2 secondes",
            "▶ Des Brain Rots apparaissent dans TON champ (SpawnZone)",
            "▶ Raretés visibles : COMMON (gris), OG, RARE, EPIC, LEGENDARY...",
            "▶ MYTHIC/SECRET ne doivent PAS apparaître ici",
            "",
            "✅ ATTENDU : BillboardGui visible au-dessus de chaque BR",
        },
    },

    {
        numero  = 3,
        titre   = "RAMASSAGE — ProximityPrompt (COMMON/OG/RARE)",
        attente = 3,
        instructions = {
            "▶ S'approcher d'un Brain Rot COMMON → bouton [E] apparaît",
            "▶ Appuyer E (HoldDuration = 0 en test → instantané)",
            "▶ Le BR disparaît et apparaît au-dessus de ta tête",
            "▶ HUD affiche 'BR : 1/5'",
            "",
            "✅ ATTENDU : BR porté au-dessus de la tête, HUD mis à jour",
        },
    },

    {
        numero  = 4,
        titre   = "CARRY MAX — Stack de 5 BR",
        attente = 3,
        instructions = {
            "▶ En TEST_MODE : capacité = 5 dès le début",
            "▶ Ramasser 5 Brain Rots d'affilée",
            "▶ Vérifier le stack visuel (empilés au-dessus de la tête)",
            "▶ Tenter d'en ramasser un 6ème",
            "▶ Message : '🎒 Sac plein ! (5/5)'",
            "",
            "✅ ATTENDU : Stack de 5 BR, blocage au 6ème",
        },
    },

    {
        numero  = 5,
        titre   = "RAMASSAGE — EPIC/LEGENDARY (HoldDuration réduit)",
        attente = 3,
        instructions = {
            "▶ S'approcher d'un EPIC (violet) → bouton [E]",
            "▶ Maintenir E (0.1s en test vs 0.5s en prod)",
            "▶ Maintenir E sur un LEGENDARY (0.2s en test vs 1.5s en prod)",
            "▶ Vérifier capture réussie et notification",
            "",
            "✅ ATTENDU : HoldDuration réduit, capture rapide",
        },
    },

    {
        numero  = 6,
        titre   = "DÉPÔT À LA BASE (DropSystem)",
        attente = 3,
        instructions = {
            "▶ Aller à ta base (bâtiment principal)",
            "▶ S'approcher d'un spot débloqué (spot_1 ou spot_2)",
            "▶ Bouton [E] 'Déposer' visible",
            "▶ Appuyer E → BR miniature apparaît sur le spot (fade in)",
            "▶ SurfaceGui affiche '+X/s' et '⏱ +Y/s'",
            "▶ Console : '[DropSystem] [Nom] a déposé COMMON sur spot 1_1'",
            "",
            "✅ ATTENDU : Mini modèle sur spot, income affiché dans GUI",
        },
    },

    {
        numero  = 7,
        titre   = "INCOME SYSTEM — Revenus passifs",
        attente = 5,
        instructions = {
            "▶ Avec au moins 1 BR déposé",
            "▶ Attendre 5 secondes",
            "▶ Coins augmentent dans le HUD (×100 en test → très rapide)",
            "▶ HUD se met à jour toutes les 5s",
            "▶ Console : '[IncomeSystem] ✓ Boucle démarrée pour [Nom]'",
            "",
            "✅ ATTENDU : Coins augmentent en continu sans interaction",
        },
    },

    {
        numero  = 8,
        titre   = "RÉCUPÉRATION d'un BR déposé",
        attente = 2,
        instructions = {
            "▶ S'approcher d'un spot occupé",
            "▶ Bouton 'Récupérer' visible (DepotPrompt désactivé)",
            "▶ Appuyer E → BR revient dans le carry",
            "▶ Mini modèle disparaît (fade out)",
            "▶ Income recalculé immédiatement",
            "",
            "✅ ATTENDU : BR récupéré, income réduit, spot vide",
        },
    },

    {
        numero  = 9,
        titre   = "PROGRESSION BASE — Déblocage spots et étages",
        attente = 5,
        instructions = {
            "▶ En test : spot_3 = 1 coin, Floor 2 = 10 coins, Floor 4 = 150 coins",
            "▶ Attendre quelques secondes (income ×100 → monte très vite)",
            "▶ Spots se débloquent automatiquement un par un",
            "▶ À 10 coins : Floor 2 fade in avec particules dorées",
            "▶ Notification : '🎉 Étage 2 débloqué !'",
            "▶ Tester jusqu'à Floor 4 (≈ 30 secondes en test)",
            "",
            "✅ ATTENDU : 4 étages débloqués, 40 spots actifs",
        },
    },

    {
        numero  = 10,
        titre   = "CHAMP COMMUN — MYTHIC",
        attente = 35,
        instructions = {
            "▶ Aller au centre de la map (ChampCommun)",
            "▶ 3 points avec particules permanentes visibles",
            "▶ Attendre ≈30s → MYTHIC spawn",
            "▶ À T-10s : compteur visible + notification '⚠️ MYTHIC dans 10s !'",
            "▶ HoldDuration = 0.3s en test (vs 3s en prod)",
            "▶ Capturer le MYTHIC",
            "",
            "✅ ATTENDU : Countdown + spawn + capture ProximityPrompt",
        },
    },

    {
        numero  = 11,
        titre   = "MORT ET DROP",
        attente = 5,
        instructions = {
            "▶ Porter 3 Brain Rots",
            "▶ Mourir (tomber dans le vide ou kill via commande)",
            "▶ BR tombent au sol à l'endroit de la mort",
            "▶ Notification : '💀 [Nom] a lâché ses Brain Rots !'",
            "▶ BR restent 15 secondes puis disparaissent",
            "",
            "✅ ATTENDU : Drop visuel, ramassable par n'importe qui",
        },
    },

    {
        numero  = 12,
        titre   = "REBIRTH",
        attente = 5,
        instructions = {
            "▶ En test : Rebirth 1 = 50 coins + 1 LEGENDARY",
            "▶ Ramasser 1 LEGENDARY et accumuler 50 coins",
            "▶ Bouton REBIRTH pulse en doré (visible Floor 4 spot_10 débloqué)",
            "▶ Activer le Rebirth",
            "▶ Animation : reset base + particules dorées",
            "▶ Vérifier : ×1.5 multiplicateur + 2 slots bonus permanents",
            "",
            "✅ ATTENDU : Reset progression + multiplicateur actif",
        },
    },

    {
        numero  = 13,
        titre   = "EVENT AUTOMATIQUE",
        attente = 35,
        instructions = {
            "▶ En test : event toutes les 30s (vs 2h en prod)",
            "▶ Attendre la notification : '⭐ LUCKY HOUR ! ...'",
            "▶ Spawn rate augmente visuellement pendant l'event",
            "▶ Timer visible dans le HUD",
            "▶ L'event dure 6s en test (vs 5min en prod)",
            "",
            "✅ ATTENDU : Event déclenché auto, spawn boosté, expiration",
        },
    },

    {
        numero  = 14,
        titre   = "SAUVEGARDE ET OFFLINE INCOME",
        attente = 5,
        instructions = {
            "▶ Déposer quelques BR sur des spots",
            "▶ Quitter le jeu (déconnexion propre)",
            "▶ Console : '[NomJeu] [Nom] sauvegardé et déconnecté'",
            "▶ Rejoindre à nouveau",
            "▶ Notification : '+X coins gagnés hors ligne !'",
            "▶ Vérifier que les BR sont toujours sur leurs spots",
            "",
            "✅ ATTENDU : Données persistées + offline income calculé",
        },
    },

    {
        numero  = 15,
        titre   = "SHOP — Vérification RemoteEvents + ProximityPrompts",
        attente = 3,
        instructions = {
            "▶ Console doit afficher :",
            "   [ShopSystem] Init() démarré…",
            "   [ShopSystem] RemoteEvents créés :",
            "     OuvrirShop : ✅",
            "     AchatUpgrade : ✅",
            "     ShopUpdate : ✅",
            "   [ShopSystem] ProximityPrompt créé → Base_1",
            "   [ShopSystem] 6 ProximityPrompt(s) Shop initialisés",
            "",
            "▶ Script Console (mode Server) :",
            "   local RS = game.ReplicatedStorage",
            "   for _,n in ipairs({'OuvrirShop','FermerShop','AchatUpgrade','ShopUpdate'}) do",
            "     print(n..': '..(RS:FindFirstChild(n) and '✅' or '❌'))",
            "   end",
            "",
            "▶ S'approcher du Shop de SA base → appuyer E",
            "▶ Le menu Shop doit s'ouvrir",
            "▶ S'approcher du Shop d'une AUTRE base → message ❌",
            "▶ Acheter Arroseur Niv.1 (500 coins) → coins déduits + notif ✅",
            "",
            "✅ ATTENDU : Menu ouvert + achat validé + coins déduits + HUD mis à jour",
        },
    },

    {
        numero  = 16,
        titre   = "VÉRIFICATION FINALE",
        attente = 0,
        instructions = {
            "▶ 0 erreur rouge dans la console",
            "▶ Warnings jaunes notés et évalués",
            "▶ Test avec 2 joueurs simultanés si possible",
            "▶ Bases bien séparées (champ joueur 1 ≠ champ joueur 2)",
            "",
            "🚀 TOUT OK → GameConfig.TEST_MODE = false → PUBLIER",
            "❌ ERREURS  → Corriger, re-tester depuis l'étape concernée",
        },
    },
}

-- ============================================================
-- Vérifications automatiques de la structure Studio
-- ============================================================

local function VerifierStructureStudio()
    log("Vérification structure Studio...")

    -- Bases
    local bases   = workspace:FindFirstChild("Bases")
    local nbBases = 0
    if not bases then
        logWarn("⛔ Workspace/Bases INTROUVABLE")
    else
        for i = 1, 6 do
            local base = bases:FindFirstChild("Base_" .. i)
            if base then
                nbBases += 1
                if not base:FindFirstChild("SpawnZone") then
                    logWarn("Base_" .. i .. " : SpawnZone manquante")
                end
                local batiment = base:FindFirstChild("Base")
                if batiment then
                    -- Floor 1 a un double espace dans son nom Studio
                    if not batiment:FindFirstChild("Floor  1") then
                        logWarn("Base_" .. i .. " : 'Floor  1' manquant (double espace ?)")
                    end
                    for f = 2, 4 do
                        if not batiment:FindFirstChild("Floor " .. f) then
                            logWarn("Base_" .. i .. " : Floor " .. f .. " manquant")
                        end
                    end
                else
                    logWarn("Base_" .. i .. " : Model 'Base' manquant")
                end
            else
                logWarn("Base_" .. i .. " introuvable dans Workspace/Bases")
            end
        end
        logOK(nbBases .. "/6 bases détectées")
    end

    -- ChampCommun
    if workspace:FindFirstChild("ChampCommun") then
        logOK("ChampCommun ✓")
    else
        logWarn("Workspace/ChampCommun introuvable")
    end

    -- Brainrots dans ServerStorage
    local brainrots = game.ServerStorage:FindFirstChild("Brainrots")
    if not brainrots then
        logWarn("⛔ ServerStorage/Brainrots INTROUVABLE")
    else
        local dossiers = { "COMMON", "OG", "RARE", "EPIC", "LEGENDARY", "MYTHIC", "SECRET", "BRAINROT_GOD" }
        for _, d in ipairs(dossiers) do
            local folder = brainrots:FindFirstChild(d)
            if folder then
                local nb = #folder:GetChildren()
                if nb > 0 then
                    logOK("Brainrots/" .. d .. " : " .. nb .. " modèle(s) ✓")
                else
                    logWarn("Brainrots/" .. d .. " : dossier VIDE")
                end
            else
                logWarn("Brainrots/" .. d .. " : dossier MANQUANT")
            end
        end
    end
end

-- ============================================================
-- Vérifications des scripts requis
-- ============================================================

local function VerifierScripts()
    log("Vérification des scripts...")

    -- Chaque entrée : { service, chemin en points, nom affiché }
    local SSS = game.ServerScriptService
    local RS  = game.ReplicatedStorage

    local scripts = {
        { service=SSS, chemin="Common.Main",                    nom="Main.server"           },
        { service=SSS, chemin="Common.DataStoreManager",        nom="DataStoreManager"      },
        { service=SSS, chemin="Common.CarrySystem",             nom="CarrySystem"           },
        { service=SSS, chemin="Common.DropSystem",              nom="DropSystem"            },
        { service=SSS, chemin="Common.IncomeSystem",            nom="IncomeSystem"          },
        { service=SSS, chemin="Common.AssignationSystem",       nom="AssignationSystem"     },
        { service=SSS, chemin="Common.BaseProgressionSystem",   nom="BaseProgressionSystem" },
        { service=SSS, chemin="Common.RebirthSystem",           nom="RebirthSystem"         },
        { service=SSS, chemin="Specialized.BrainRotSpawner",    nom="BrainRotSpawner"       },
        { service=SSS, chemin="Specialized.ChampCommunSpawner", nom="ChampCommunSpawner"    },
        { service=RS,  chemin="Specialized.GameConfig",         nom="GameConfig"            },
        { service=RS,  chemin="Test.TestConfig",                nom="TestConfig"            },
    }

    local manquants = 0
    for _, s in ipairs(scripts) do
        local parties = s.chemin:split(".")
        local obj     = s.service
        local ok      = true
        for _, partie in ipairs(parties) do
            obj = obj and obj:FindFirstChild(partie)
            if not obj then ok = false; break end
        end
        if ok then
            logOK(s.nom .. " ✓")
        else
            logWarn(s.nom .. " MANQUANT → " .. s.service.Name .. "/" .. s.chemin)
            manquants += 1
        end
    end

    if manquants == 0 then
        logOK("Tous les scripts présents ✓")
    else
        logWarn(manquants .. " script(s) manquant(s) — corriger avant de tester")
    end
end

-- ============================================================
-- Affichage du plan de test complet
-- ============================================================

local function AfficherPlan()
    print("")
    print("╔══════════════════════════════════════════════════════╗")
    print("║     🧪 MODE TEST ACTIVÉ — " .. Config.NomDuJeu .. "     ")
    print("║     Config boostée — NE PAS PUBLIER AINSI            ║")
    print("╚══════════════════════════════════════════════════════╝")
    print("")
    print("📋 PLAN DE TEST — " .. #PLAN_DE_TEST .. " étapes")
    print("")

    for _, etape in ipairs(PLAN_DE_TEST) do
        logEtape(etape.numero, etape.titre, etape.instructions)
        if etape.attente > 0 then
            print("   ⏱️  Durée estimée : ~" .. etape.attente .. "s")
        end
    end

    print("")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("⚠️  RAPPEL : GameConfig.TEST_MODE = false AVANT publish !")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("")
end

-- ============================================================
-- Watchers — validation automatique en temps réel
-- ============================================================

local function LancerWatchers()
    if not Config.TEST_MODE then return end

    local Players = game:GetService("Players")

    Players.PlayerAdded:Connect(function(player)
        log("Joueur connecté : " .. player.Name)

        -- Vérifier l'assignation 3 secondes après la connexion
        task.wait(3)
        local ok, AssignationSystem = pcall(require,
            game.ServerScriptService.Common.AssignationSystem)
        if ok and AssignationSystem then
            local baseIndex = AssignationSystem.GetBaseIndex(player)
            if baseIndex then
                logOK("Étape 1 ✓ — " .. player.Name .. " → Base_" .. baseIndex)
            else
                logWarn("Étape 1 ✗ — " .. player.Name .. " non assigné (spectateur ou bug)")
            end
        end
    end)

    Players.PlayerRemoving:Connect(function(player)
        log("Joueur déconnecté : " .. player.Name)
    end)
end

-- ============================================================
-- Init — appelé depuis Main.server.lua
-- ============================================================

function TestRunner.Init()
    if not Config.TEST_MODE then return end

    task.wait(1)  -- laisser tous les systèmes démarrer

    print("")
    print("╔══════════════════════════════════════╗")
    print("║  🔍 Vérifications pré-test en cours  ║")
    print("╚══════════════════════════════════════╝")

    VerifierStructureStudio()
    task.wait(0.3)
    VerifierScripts()
    task.wait(0.3)
    AfficherPlan()
    LancerWatchers()
end

return TestRunner
