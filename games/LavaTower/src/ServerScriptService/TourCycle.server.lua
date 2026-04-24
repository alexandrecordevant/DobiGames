-- TourCycle.server.lua
-- Gère le cycle complet (attente → ouverture → TP → lave) pour TourCommune et TourVIP.
-- Chaque tour tourne dans sa propre coroutine indépendante via lancerCycleTour().

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Logger            = require(game:GetService("ServerScriptService").SharedLib.Server.Logger)

-- RemoteEvent pour notifier les non-VIP qui montent sur la plateforme
local function getOrCreate(name)
    local e = ReplicatedStorage:FindFirstChild(name)
    if e then return e end
    e = Instance.new("RemoteEvent"); e.Name = name; e.Parent = ReplicatedStorage
    return e
end
local VIPNotification = getOrCreate("VIPNotification")
local TowerEntered    = getOrCreate("TowerEntered")

-- ============================================================
-- CONFIGURATION PARTAGÉE
-- Les deux tours utilisent les mêmes timings.
-- ============================================================
local CONFIG = {
    DUREE_ATTENTE       = 10,   -- secondes d'attente entre deux cycles
    DUREE_OUVERTURE     = 10,   -- secondes pendant lesquelles la porte est ouverte
    DELAI_LAVA          = 10,   -- secondes après le TP avant que la lave apparaît
    DELAI_AVERTISSEMENT = 5,    -- secondes d'avertissement (lave visible mais immobile) avant qu'elle monte
    VITESSE_BASE        = 3,    -- studs/seconde (vitesse initiale de la lave)
    ACCELERATION        = 1,    -- studs/s ajoutés par palier
    INTERVALLE_ACCEL    = 10,   -- secondes entre chaque palier d'accélération
    HAUTEUR_ARRET       = 1020, -- studs au-dessus du point de départ avant que la lave s'arrête
}

-- ============================================================
-- UTILITAIRES
-- ============================================================

local function formatTimer(secondes)
    return ("%d:%02d"):format(math.floor(secondes / 60), secondes % 60)
end

-- Renvoie la liste des joueurs dont le HumanoidRootPart est dans la zone.
local function getJoueursZone(startZone)
    local liste = {}
    for _, player in ipairs(Players:GetPlayers()) do
        local char = player.Character
        if not char then continue end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end
        local pos   = hrp.Position
        local zPos  = startZone.Position
        local zSize = startZone.Size
        if math.abs(pos.X - zPos.X) <= zSize.X / 2 + 2
        and math.abs(pos.Z - zPos.Z) <= zSize.Z / 2 + 2
        and pos.Y >= zPos.Y - 1 and pos.Y <= zPos.Y + 15 then
            table.insert(liste, player)
        end
    end
    return liste
end

-- ============================================================
-- CYCLE GÉNÉRIQUE
--
-- cfg = {
--   nomTour          : string   — préfixe pour les logs et le billboard
--   startZone        : BasePart — pad d'entrée de la tour
--   interiorSpawn    : BasePart — point d'arrivée du TP
--   lava             : BasePart — la part de lave
--   couleurAttente   : Color3   — couleur du texte pendant l'attente
--   couleurOuverture : Color3   — couleur du texte pendant la fenêtre d'ouverture
-- }
-- ============================================================
local function lancerCycleTour(cfg)
    local tag           = "[" .. cfg.nomTour .. "]"
    local startZone     = cfg.startZone
    local interiorSpawn = cfg.interiorSpawn
    local lava          = cfg.lava

    local lavaActive    = false
    local laveConnexion = nil
    local lavaVitesse   = CONFIG.VITESSE_BASE
    local hauteurDepart = lava.Position.Y
    local joueursEnTour = {}  -- userId → true, uniquement ceux téléportés dans CETTE tour

    -- ── Billboard au-dessus de StartZone ──────────────────────────
    local billboard = Instance.new("BillboardGui")
    billboard.Name             = "TimerBillboard"
    billboard.Size             = UDim2.new(44, 0, 12, 0)  -- taille en studs : proportionnel à la distance
    billboard.StudsOffset      = Vector3.new(0, 10, 0)
    billboard.AlwaysOnTop      = false
    billboard.MaxDistance      = 200
    billboard.ClipsDescendants = true
    billboard.LightInfluence   = 1
    billboard.Parent           = startZone

    local timerLabel = Instance.new("TextLabel")
    timerLabel.Size                   = UDim2.new(1, 0, 1, 0)
    timerLabel.BackgroundTransparency = 1
    timerLabel.Font                   = Enum.Font.GothamBold
    timerLabel.TextStrokeTransparency = 0.4
    timerLabel.TextScaled             = true
    timerLabel.TextColor3             = cfg.couleurAttente
    timerLabel.Text                   = cfg.labelAffiche .. " dans 5:00"
    timerLabel.Parent                 = billboard

    -- ── Notification non-autorisé sur la plateforme ───────────────
    if cfg.filtrer then
        local debounceNotif = {}
        startZone.Touched:Connect(function(hit)
            local char   = hit.Parent
            local player = Players:GetPlayerFromCharacter(char)
            if not player then return end
            if cfg.filtrer(player) then return end
            local now = os.clock()
            if now - (debounceNotif[player.UserId] or 0) < 4 then return end
            debounceNotif[player.UserId] = now
            VIPNotification:FireClient(player)
        end)
    end

    -- ── Reset lave ────────────────────────────────────────────────
    local function resetLava()
        lavaActive = false
        if laveConnexion then
            laveConnexion:Disconnect()
            laveConnexion = nil
        end
        lavaVitesse   = CONFIG.VITESSE_BASE
        lava.Anchored = true
        lava.CFrame = CFrame.new(lava.Position.X, hauteurDepart, lava.Position.Z)
        for uid in pairs(joueursEnTour) do
            local p = Players:GetPlayerByUserId(uid)
            if p then p:SetAttribute("InTower", false) end
            joueursEnTour[uid] = nil
        end
        Logger.debug("Tower", "%s Lave reset à Y=%d", tag, hauteurDepart)
    end

    -- ── Démarrer la lave ──────────────────────────────────────────
    local function demarrerLava(nbJoueurs)
        if lavaActive then return end
        lavaActive  = true
        lavaVitesse = CONFIG.VITESSE_BASE
        Logger.info("Tower", "%s Lave démarrée | %d joueur(s)", tag, nbJoueurs)

        local tempsAccel   = 0
        local dernierTemps = os.clock()
        local tempsVerif   = 0
        local lavaArretee  = false

        laveConnexion = RunService.Heartbeat:Connect(function()
            if not lavaActive then return end
            local now   = os.clock()
            local delta = now - dernierTemps
            dernierTemps = now

            if not lavaArretee then
                lava.Anchored = true
                lava.CFrame = lava.CFrame + Vector3.new(0, lavaVitesse * delta, 0)

                tempsAccel = tempsAccel + delta
                if tempsAccel >= CONFIG.INTERVALLE_ACCEL then
                    tempsAccel  = 0
                    lavaVitesse = lavaVitesse + CONFIG.ACCELERATION
                end

                if lava.Position.Y >= hauteurDepart + CONFIG.HAUTEUR_ARRET then
                    lavaArretee = true
                    lava.CFrame = CFrame.new(lava.Position.X, hauteurDepart + CONFIG.HAUTEUR_ARRET, lava.Position.Z)
                    Logger.info("Tower", "%s Hauteur max atteinte (Y=%.0f) — lave en attente d'escape", tag, lava.Position.Y)
                end
            end

            tempsVerif = tempsVerif + delta
            if tempsVerif >= 2 then
                tempsVerif = 0
                local vivants = 0
                for uid in pairs(joueursEnTour) do
                    local p = Players:GetPlayerByUserId(uid)
                    local c = p and p.Character
                    if c then
                        local h   = c:FindFirstChildOfClass("Humanoid")
                        local hrp = c:FindFirstChild("HumanoidRootPart")
                        if h and h.Health > 0 and hrp and hrp.Position.Y > hauteurDepart + 5 then
                            vivants += 1
                        end
                    end
                end
                if vivants == 0 then
                    Logger.debug("Tower", "%s Plus personne → Reset lave", tag)
                    resetLava()
                end
            end
        end)
    end

    -- ── Lave : toucher = mort ──────────────────────────────────────
    lava.Touched:Connect(function(hit)
        if not lavaActive then return end
        local char   = hit.Parent
        local player = Players:GetPlayerFromCharacter(char)
        if not player then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return end
        Logger.info("Tower", "%s %s éliminé", tag, player.Name)
        hum.Health = 0
        task.delay(1, function()
            local vivants = 0
            for uid in pairs(joueursEnTour) do
                local p = Players:GetPlayerByUserId(uid)
                local c = p and p.Character
                if c then
                    local h   = c:FindFirstChildOfClass("Humanoid")
                    local hrp = c:FindFirstChild("HumanoidRootPart")
                    if h and h.Health > 0 and hrp and hrp.Position.Y > hauteurDepart + 5 then
                        vivants += 1
                    end
                end
            end
            if vivants == 0 then
                Logger.debug("Tower", "%s Tous éliminés → Reset lave", tag)
                resetLava()
            end
        end)
    end)

    -- ── Cycle principal ────────────────────────────────────────────
    task.spawn(function()
        while true do
            -- Phase 1 : Attente
            startZone.BrickColor = BrickColor.new("Really red")
            startZone.CanCollide = true
            startZone:SetAttribute("Locked", true)
            timerLabel.TextColor3 = cfg.couleurAttente

            for t = CONFIG.DUREE_ATTENTE, 1, -1 do
                timerLabel.Text = cfg.labelAffiche .. " dans " .. formatTimer(t)
                task.wait(1)
            end

            -- Phase 2 : Ouverture
            startZone.BrickColor = BrickColor.new("Lime green")
            startZone:SetAttribute("Locked", false)
            timerLabel.TextColor3 = cfg.couleurOuverture

            for t = CONFIG.DUREE_OUVERTURE, 1, -1 do
                local tous = getJoueursZone(startZone)
                local n = 0
                for _, p in ipairs(tous) do
                    if not cfg.filtrer or cfg.filtrer(p) then n += 1 end
                end
                timerLabel.Text = "ENTRER " .. t .. "s\n" .. n .. (n > 1 and " joueurs" or " joueur")
                task.wait(1)
            end

            -- Phase 3 : Fermeture + TP
            startZone.BrickColor = BrickColor.new("Really red")
            startZone:SetAttribute("Locked", true)
            timerLabel.TextColor3 = cfg.couleurAttente
            timerLabel.Text       = "FERMÉ"

            local joueurs = getJoueursZone(startZone)
            local nbTP    = 0

            for _, player in ipairs(joueurs) do
                if cfg.filtrer and not cfg.filtrer(player) then
                    Logger.debug("Tower", "%s %s ignoré (filtre)", tag, player.Name)
                    continue
                end
                local char = player.Character
                if char then
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        hrp.CFrame = interiorSpawn.CFrame + Vector3.new(0, 3, 0)
                        joueursEnTour[player.UserId] = true
                        player:SetAttribute("InTower", true)
                        TowerEntered:FireClient(player)
                        nbTP += 1
                        -- Reset InTower si le joueur meurt et respawn
                        local charConn; charConn = player.CharacterAdded:Connect(function()
                            charConn:Disconnect()
                            if player:GetAttribute("InTower") then
                                player:SetAttribute("InTower", false)
                            end
                        end)
                    end
                end
            end

            Logger.info("Tower", "%s Téléportation de %d joueur(s)", tag, nbTP)

            -- Phase 4 : Lave (uniquement si des joueurs ont été téléportés)
            if nbTP > 0 then
                timerLabel.Text = "Lave dans " .. CONFIG.DELAI_LAVA .. "s"
                task.wait(CONFIG.DELAI_LAVA)
                resetLava()
                -- Avertissement : lave visible mais immobile pendant DELAI_AVERTISSEMENT secondes
                for t = CONFIG.DELAI_AVERTISSEMENT, 1, -1 do
                    timerLabel.Text = "⚠ LAVE dans " .. t .. "s !"
                    task.wait(1)
                end
                demarrerLava(nbTP)
                while lavaActive do task.wait(1) end
            end

            Logger.debug("Tower", "%s Nouveau cycle", tag)
        end
    end)

    Logger.info("Tower", "%s ✓ Cycle lancé", tag)
end

-- ============================================================
-- LANCEMENT DES TOURS
-- ============================================================

-- TourCommune — texte d'ouverture vert
task.spawn(function()
    local tour = workspace:WaitForChild("TourCommune")
    lancerCycleTour({
        nomTour          = "TourCommune",
        labelAffiche     = "Tour commune",
        startZone        = tour:WaitForChild("Triggers"):WaitForChild("StartZone"),
        interiorSpawn    = tour:WaitForChild("InterriorSpawn"),
        lava             = tour:WaitForChild("Lava"),
        couleurAttente   = Color3.fromRGB(255,  80,  80),  -- rouge
        couleurOuverture = Color3.fromRGB( 80, 255,  80),  -- vert
    })
end)

-- TourVIP — texte d'ouverture doré (même logique, style visuel différent)
task.spawn(function()
    local tour = workspace:FindFirstChild("TourVIP")
    if not tour then
        Logger.warn("Tower", "TourVIP introuvable dans workspace — ignorée.")
        return
    end

    local triggers    = tour:FindFirstChild("Triggers")
    local startZone   = triggers and triggers:FindFirstChild("StartZone")
    local spawn       = tour:FindFirstChild("InterriorSpawn")
    local lava        = tour:FindFirstChild("Lava")

    if not startZone or not spawn or not lava then
        Logger.warn("Tower", "TourVIP : structure incomplète (Triggers/StartZone, InterriorSpawn ou Lava manquant).")
        return
    end

    lancerCycleTour({
        nomTour          = "TourVIP",
        labelAffiche     = "Tour VIP",
        startZone        = startZone,
        interiorSpawn    = spawn,
        lava             = lava,
        filtrer          = function(p) return p:GetAttribute("HasVIP") == true end,
        couleurAttente   = Color3.fromRGB(255, 215, 0),  -- orange (attente VIP)
        couleurOuverture = Color3.fromRGB(255, 215, 0),  -- doré  (ouverture VIP)
    })
end)
