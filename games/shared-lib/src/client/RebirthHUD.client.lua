-- shared-lib/src/client/RebirthHUD.client.lua
-- Amélioration de la Base — interaction via le Board 3D
--
-- Principe :
--   1. Le serveur (BoardSystem) crée une SurfaceGui sur la Part "Board" avec
--      un TextButton nommé "BoutonAchat".
--   2. Ce script client reçoit l'event "AssignBase" (baseIndex du joueur),
--      trouve le Board correspondant dans Workspace, puis connecte le clic
--      du bouton → DemandeRebirth.
--   3. Le serveur (RebirthSystem + BoardSystem.MettreAJourBoard) met à jour
--      le contenu du Board automatiquement. Le client n'a qu'à gérer l'état
--      local "achat en cours" pour éviter le double-clic.
--
-- Aucun ScreenGui créé ici — tout est sur la Part physique.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local Logger            = require(game:GetService("ReplicatedStorage").SharedLib.Logger)

local player = Players.LocalPlayer

-- ═══════════════════════════════════════════════
-- 1. ÉTAT LOCAL
-- ═══════════════════════════════════════════════

local achatEnCours  = false
local estDisponible = false   -- mis à jour par RebirthButtonUpdate
local boutonRef     = nil     -- référence au TextButton sur le Board

-- ═══════════════════════════════════════════════
-- 2. REMOTES (chargées en parallèle dans task.spawn, sans bloquer)
-- ═══════════════════════════════════════════════

-- Les remotes critiques sont attendues dans task.spawn pour ne pas bloquer
-- l'initialisation des autres LocalScripts.

task.spawn(function()
    local RebirthButtonUpdate = ReplicatedStorage:WaitForChild("RebirthButtonUpdate", 10)
    local DemandeRebirth      = ReplicatedStorage:WaitForChild("DemandeRebirth",      10)
    local RebirthAnimation    = ReplicatedStorage:WaitForChild("RebirthAnimation",    10)
    local AssignBase          = ReplicatedStorage:WaitForChild("AssignBase",           15)

    if not RebirthButtonUpdate or not DemandeRebirth or not AssignBase then
        Logger.warn("AmelioBase", "Remotes manquants — vérifier Main.server.lua")
        return
    end

    -- ═══════════════════════════════════════════════
    -- 3. RECHERCHE DU BOARD ET CONNEXION DU BOUTON
    -- ═══════════════════════════════════════════════

    -- Chemin : Workspace.Bases.Base_N.Shared.Base.Board.BoardGui.Fond.BoutonAchat
    local function trouverBouton(baseIndex)
        local bases  = Workspace:FindFirstChild("Bases")
        if not bases then
            Logger.warn("AmelioBase", "Workspace.Bases introuvable")
            return nil
        end

        local base   = bases:FindFirstChild("Base_" .. baseIndex)
        local shared = base   and base:FindFirstChild("Shared")
        local bat    = shared and shared:FindFirstChild("Base")
        local board  = bat    and bat:FindFirstChild("Board")
        if not board then
            Logger.warn("AmelioBase", "Board introuvable pour Base_%d", baseIndex)
            return nil
        end

        -- La SurfaceGui est créée par le serveur à l'Init — on attend qu'elle apparaisse
        local sg   = board:WaitForChild("BoardGui",   8)
        local fond = sg    and sg:WaitForChild("Fond", 4)
        local btn  = fond  and fond:WaitForChild("BoutonAchat", 4)

        if not btn then
            Logger.warn("AmelioBase", "BoutonAchat introuvable dans Board Base_%d", baseIndex)
            return nil
        end

        return btn
    end

    local function connecterBouton(baseIndex)
        local btn = trouverBouton(baseIndex)
        if not btn then return end

        boutonRef = btn

        btn.MouseButton1Click:Connect(function()
            -- Bloquer si achat impossible ou déjà en cours
            if achatEnCours or not estDisponible then return end
            achatEnCours = true

            -- Feedback visuel local immédiat (remplacé par la prochaine mise à jour serveur)
            btn.Text             = "En cours..."
            btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            btn.TextColor3       = Color3.fromRGB(150, 150, 150)

            DemandeRebirth:FireServer()
        end)

        Logger.info("AmelioBase", "Bouton connecté → Base_%d", baseIndex)
    end

    -- ═══════════════════════════════════════════════
    -- 4. RÉCEPTION DE L'ASSIGNATION DE BASE
    -- ═══════════════════════════════════════════════

    AssignBase.OnClientEvent:Connect(function(baseIndex)
        -- Lancer dans une coroutine pour ne pas bloquer (WaitForChild peut attendre)
        task.spawn(connecterBouton, baseIndex)
    end)

    -- ═══════════════════════════════════════════════
    -- 5. REMOTES ENTRANTS
    -- ═══════════════════════════════════════════════

    -- Le serveur a répondu (succès ou échec) — on libère le bouton
    -- Le contenu du bouton est remis à jour par BoardSystem.MettreAJourBoard côté serveur
    RebirthButtonUpdate.OnClientEvent:Connect(function(etat)
        achatEnCours  = false
        estDisponible = etat ~= nil and etat.disponible == true
    end)

    -- Animation après achat réussi — libérer le verrou uniquement
    -- Le bouton est entièrement géré côté serveur via BoardSystem.MettreAJourBoard
    if RebirthAnimation then
        RebirthAnimation.OnClientEvent:Connect(function(_info)
            achatEnCours = false
        end)
    end

    Logger.info("AmelioBase", "Client prêt ✓")
end)
