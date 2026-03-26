-- TourCycle.server.lua
-- Gère le cycle complet (attente → ouverture → TP → lave) pour TourCommune et TourVIP.
-- Chaque tour tourne dans sa propre coroutine indépendante via lancerCycleTour().

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

-- ============================================================
-- CONFIGURATION PARTAGÉE
-- Les deux tours utilisent les mêmes timings.
-- ============================================================
local CONFIG = {
    DUREE_ATTENTE    = 300,   -- secondes d'attente entre deux cycles
    DUREE_OUVERTURE  = 3,     -- secondes pendant lesquelles la porte est ouverte
    DELAI_LAVA       = 10,    -- secondes après le TP avant que la lave démarre
    VITESSE_BASE     = 3,     -- studs/seconde (vitesse initiale de la lave)
    ACCELERATION     = 0.5,   -- studs/s ajoutés par palier
    INTERVALLE_ACCEL = 10,    -- secondes entre chaque palier d'accélération
    HAUTEUR_MAX      = 2000,  -- hauteur Y de reset de la lave
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

    -- ── Billboard au-dessus de StartZone ──────────────────────────
    local billboard = Instance.new("BillboardGui")
    billboard.Name             = "TimerBillboard"
    billboard.Size             = UDim2.new(0, 500, 0, 100)
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
    timerLabel.TextScaled             = false
    timerLabel.TextSize               = 50
    timerLabel.TextColor3             = cfg.couleurAttente
    timerLabel.Text                   = cfg.nomTour .. " dans 5:00"
    timerLabel.Parent                 = billboard

    -- ── Reset lave ────────────────────────────────────────────────
    local function resetLava()
        lavaActive = false
        if laveConnexion then
            laveConnexion:Disconnect()
            laveConnexion = nil
        end
        lavaVitesse   = CONFIG.VITESSE_BASE
        lava.Anchored = true
        lava.Position = Vector3.new(lava.Position.X, hauteurDepart, lava.Position.Z)
        print(tag .. " Lave reset à Y=" .. hauteurDepart)
    end

    -- ── Démarrer la lave ──────────────────────────────────────────
    local function demarrerLava(nbJoueurs)
        if lavaActive then return end
        lavaActive  = true
        lavaVitesse = CONFIG.VITESSE_BASE
        print(tag .. " Lave démarrée | " .. nbJoueurs .. " joueur(s)")

        local tempsAccel = 0
        local dernierTemps = os.clock()
        local tempsVerif = 0

        laveConnexion = RunService.Heartbeat:Connect(function()
            if not lavaActive then return end
            local now   = os.clock()
            local delta = now - dernierTemps
            dernierTemps = now

            lava.Anchored = true
            lava.Position = lava.Position + Vector3.new(0, lavaVitesse * delta, 0)

            tempsAccel = tempsAccel + delta
            if tempsAccel >= CONFIG.INTERVALLE_ACCEL then
                tempsAccel  = 0
                lavaVitesse = lavaVitesse + CONFIG.ACCELERATION
            end

            tempsVerif = tempsVerif + delta
            if tempsVerif >= 2 then
                tempsVerif = 0
                local vivants = 0
                for _, p in ipairs(Players:GetPlayers()) do
                    local c = p.Character
                    if c then
                        local h   = c:FindFirstChildOfClass("Humanoid")
                        local hrp = c:FindFirstChild("HumanoidRootPart")
                        if h and h.Health > 0 and hrp and hrp.Position.Y > hauteurDepart + 5 then
                            vivants += 1
                        end
                    end
                end
                if vivants == 0 then
                    print(tag .. " Plus personne → Reset lave")
                    resetLava()
                end
            end

            if lava.Position.Y >= CONFIG.HAUTEUR_MAX then
                print(tag .. " Hauteur max → Reset lave")
                resetLava()
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
        print(tag .. " " .. player.Name .. " éliminé")
        hum.Health = 0
        task.delay(1, function()
            local vivants = 0
            for _, p in ipairs(Players:GetPlayers()) do
                local c = p.Character
                if c then
                    local h   = c:FindFirstChildOfClass("Humanoid")
                    local hrp = c:FindFirstChild("HumanoidRootPart")
                    if h and h.Health > 0 and hrp and hrp.Position.Y > hauteurDepart + 5 then
                        vivants += 1
                    end
                end
            end
            if vivants == 0 then
                print(tag .. " Tous éliminés → Reset lave")
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
                timerLabel.Text = cfg.nomTour .. " dans " .. formatTimer(t)
                task.wait(1)
            end

            -- Phase 2 : Ouverture
            startZone.BrickColor = BrickColor.new("Lime green")
            startZone:SetAttribute("Locked", false)
            timerLabel.TextColor3 = cfg.couleurOuverture

            for t = CONFIG.DUREE_OUVERTURE, 1, -1 do
                local n = #getJoueursZone(startZone)
                timerLabel.Text = "ENTRER ! " .. t .. "s | " .. n .. " joueur(s)"
                task.wait(1)
            end

            -- Phase 3 : Fermeture + TP
            startZone.BrickColor = BrickColor.new("Really red")
            startZone:SetAttribute("Locked", true)
            timerLabel.TextColor3 = cfg.couleurAttente
            timerLabel.Text       = "FERMÉ"

            local joueurs = getJoueursZone(startZone)
            local nbTP    = #joueurs
            print(tag .. " Téléportation de " .. nbTP .. " joueur(s)")

            for _, player in ipairs(joueurs) do
                local char = player.Character
                if char then
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        hrp.CFrame = interiorSpawn.CFrame + Vector3.new(0, 3, 0)
                    end
                end
            end

            -- Phase 4 : Lave (uniquement si des joueurs ont été téléportés)
            if nbTP > 0 then
                timerLabel.Text = "Lave dans " .. CONFIG.DELAI_LAVA .. "s"
                task.wait(CONFIG.DELAI_LAVA)
                resetLava()
                demarrerLava(nbTP)
                while lavaActive do task.wait(1) end
            end

            print(tag .. " Nouveau cycle")
        end
    end)

    print(tag .. " ✓ Cycle lancé")
end

-- ============================================================
-- LANCEMENT DES TOURS
-- ============================================================

-- TourCommune — texte d'ouverture vert
task.spawn(function()
    local tour = workspace:WaitForChild("TourCommune")
    lancerCycleTour({
        nomTour          = "TourCommune",
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
        warn("[TourCycle] TourVIP introuvable dans workspace — ignorée.")
        return
    end

    local triggers    = tour:FindFirstChild("Triggers")
    local startZone   = triggers and triggers:FindFirstChild("StartZone")
    local spawn       = tour:FindFirstChild("InterriorSpawn")
    local lava        = tour:FindFirstChild("Lava")

    if not startZone or not spawn or not lava then
        warn("[TourCycle] TourVIP : structure incomplète (Triggers/StartZone, InterriorSpawn ou Lava manquant).")
        return
    end

    lancerCycleTour({
        nomTour          = "TourVIP",
        startZone        = startZone,
        interiorSpawn    = spawn,
        lava             = lava,
        couleurAttente   = Color3.fromRGB(255, 215, 0),  -- orange (attente VIP)
        couleurOuverture = Color3.fromRGB(255, 215, 0),  -- doré  (ouverture VIP)
    })
end)
