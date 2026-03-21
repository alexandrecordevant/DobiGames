-- TourCycle.lua
-- Script -> ServerScriptService

local Players   = game:GetService("Players")
local RunService = game:GetService("RunService")

-- ============================================================
-- CONFIGURATION
-- ============================================================
local CONFIG = {
    DUREE_ATTENTE    = 300,   -- 5 minutes
    DUREE_OUVERTURE  = 3,    -- 30 secondes
    DELAI_LAVA       = 10,    -- secondes avant que la lave démarre
    VITESSE_BASE     = 3,     -- studs/seconde
    ACCELERATION     = 0.5,   -- studs/s ajoutés par palier
    INTERVALLE_ACCEL = 10,    -- secondes entre chaque palier
    HAUTEUR_MAX      = 2000,  -- hauteur Y de reset
}

-- ============================================================
-- Références
-- ============================================================
local startZone     = workspace:WaitForChild("TourCommune"):WaitForChild("Triggers"):WaitForChild("StartZone")
local interiorSpawn = workspace:WaitForChild("TourCommune"):WaitForChild("InterriorSpawn")
local lava          = workspace:WaitForChild("TourCommune"):WaitForChild("Lava")

if not lava then warn("[Tour] Part 'Lava' introuvable !") return end

-- ============================================================
-- Variables
-- ============================================================
local lavaActive        = false
local laveConnexion     = nil
local lavaVitesse       = CONFIG.VITESSE_BASE
local hauteurDepart     = lava.Position.Y
local joueursTeleportes = 0

-- ============================================================
-- Billboard au-dessus de StartZone
-- ============================================================
local billboard = Instance.new("BillboardGui")
billboard.Name             = "TimerBillboard"
billboard.Size             = UDim2.new(0, 500, 0, 100)
billboard.StudsOffset      = Vector3.new(0, 10, 0)
billboard.AlwaysOnTop      = false
billboard.MaxDistance      = 200     -- disparaît au-delà de 300 studs
billboard.ClipsDescendants = true
billboard.SizeOffset       = Vector2.new(0, 0)
billboard.LightInfluence   = 1
billboard.Parent           = startZone

local timerLabel = Instance.new("TextLabel")
timerLabel.Size                   = UDim2.new(1, 0, 1, 0)
timerLabel.BackgroundTransparency = 1
timerLabel.TextScaled             = true
timerLabel.Font                   = Enum.Font.GothamBold
timerLabel.TextColor3             = Color3.fromRGB(255, 80, 80)
timerLabel.TextStrokeTransparency = 0.4
timerLabel.Text                   = "Tour dans 5:00"
timerLabel.Parent                 = billboard
timerLabel.TextScaled = false          -- désactive le TextScaled
timerLabel.TextSize   = 50             -- taille fixe en pixels

-- ============================================================
-- Utilitaire : MM:SS
-- ============================================================
local function formatTimer(secondes)
    local m = math.floor(secondes / 60)
    local s = secondes % 60
    return string.format("%d:%02d", m, s)
end

-- ============================================================
-- Utilitaire : joueurs sur StartZone
-- ============================================================
local function getJoueursZone()
    local liste = {}
    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        if not character then continue end
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end

        local pos      = hrp.Position
        local zPos     = startZone.Position
        local zSize    = startZone.Size

        local dansX = math.abs(pos.X - zPos.X) <= zSize.X / 2 + 2
        local dansZ = math.abs(pos.Z - zPos.Z) <= zSize.Z / 2 + 2
        local dansY = pos.Y >= zPos.Y - 1 and pos.Y <= zPos.Y + 15

        if dansX and dansZ and dansY then
            table.insert(liste, player)
        end
    end
    return liste
end

-- ============================================================
-- Reset lave
-- ============================================================
local function resetLava()
    lavaActive = false
    if laveConnexion then
        laveConnexion:Disconnect()
        laveConnexion = nil
    end
    lavaVitesse = CONFIG.VITESSE_BASE
    lava.Anchored = true
    lava.Position = Vector3.new(lava.Position.X, hauteurDepart, lava.Position.Z)
    print("[Lava] Reset a Y=" .. hauteurDepart)
end

-- ============================================================
-- Démarrer la lave
-- ============================================================
local function demarrerLava(nbJoueurs)
    if lavaActive then return end
    lavaActive   = true
    lavaVitesse  = CONFIG.VITESSE_BASE
    joueursTeleportes = nbJoueurs
    print("[Lava] Demarrage | " .. nbJoueurs .. " joueurs dans la tour")

    local tempsAccel   = 0
    local dernierTemps = os.clock()
    local joueursElimines = 0
    local tempsVerifJoueurs = 0

    laveConnexion = RunService.Heartbeat:Connect(function()
        if not lavaActive then return end

        local now   = os.clock()
        local delta = now - dernierTemps
        dernierTemps = now

        -- Monter
        lava.Anchored = true
        lava.Position = lava.Position + Vector3.new(0, lavaVitesse * delta, 0)

        -- Accélération
        tempsAccel = tempsAccel + delta
        if tempsAccel >= CONFIG.INTERVALLE_ACCEL then
            tempsAccel  = 0
            lavaVitesse = lavaVitesse + CONFIG.ACCELERATION
            print("[Lava] Vitesse -> " .. string.format("%.1f", lavaVitesse) .. " studs/s")
        end

        -- Vérification périodique : plus personne dans la tour ?
        tempsVerifJoueurs = tempsVerifJoueurs + delta
        if tempsVerifJoueurs >= 2 then
            tempsVerifJoueurs = 0
            local joueursVivants = 0
            for _, p in ipairs(Players:GetPlayers()) do
                local c = p.Character
                if c then
                    local h   = c:FindFirstChildOfClass("Humanoid")
                    local hrp = c:FindFirstChild("HumanoidRootPart")
                    if h and h.Health > 0 and hrp and hrp.Position.Y > hauteurDepart + 5 then
                        joueursVivants = joueursVivants + 1
                    end
                end
            end
            if joueursVivants == 0 then
                print("[Lava] Plus personne dans la tour -> Reset")
                resetLava()
                return
            end
        end

        -- Hauteur max atteinte
        if lava.Position.Y >= CONFIG.HAUTEUR_MAX then
            print("[Lava] Hauteur max atteinte -> Reset")
            resetLava()
        end
    end)
end

-- ============================================================
-- Détection joueur touché par la lave
-- ============================================================
lava.Touched:Connect(function(hit)
    if not lavaActive then return end
    local character = hit.Parent
    local player    = Players:GetPlayerFromCharacter(character)
    if not player then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    print("[Lava] " .. player.Name .. " elimine")
    humanoid.Health = 0

    -- Vérifier si tous les joueurs dans la tour sont éliminés
    -- (on reset si plus personne n'est vivant à l'intérieur)
    task.delay(1, function()
        local joueursVivants = 0
        for _, p in ipairs(Players:GetPlayers()) do
            local c = p.Character
            if c then
                local h = c:FindFirstChildOfClass("Humanoid")
                local hrp = c:FindFirstChild("HumanoidRootPart")
                if h and h.Health > 0 and hrp then
                    -- Vérifier si proche de la zone intérieure (heuristique)
                    if hrp.Position.Y > hauteurDepart + 5 then
                        joueursVivants = joueursVivants + 1
                    end
                end
            end
        end
        if joueursVivants == 0 then
            print("[Lava] Tous elimines -> Reset")
            resetLava()
        end
    end)
end)

-- ============================================================
-- CYCLE PRINCIPAL
-- ============================================================
task.spawn(function()
    while true do

        -- == PHASE 1 : ATTENTE 5 minutes ==
        startZone.BrickColor         = BrickColor.new("Really red")
        startZone.CanCollide         = true
        startZone:SetAttribute("Locked", true)
        timerLabel.TextColor3        = Color3.fromRGB(255, 80, 80)

        for t = CONFIG.DUREE_ATTENTE, 1, -1 do
            timerLabel.Text = "Tour dans " .. formatTimer(t)
            task.wait(1)
        end

        -- == PHASE 2 : OUVERTURE 30 secondes ==
        startZone.BrickColor         = BrickColor.new("Lime green")
        startZone:SetAttribute("Locked", false)
        timerLabel.TextColor3        = Color3.fromRGB(80, 255, 80)

        for t = CONFIG.DUREE_OUVERTURE, 1, -1 do
            local joueursZone = getJoueursZone()
            timerLabel.Text = "ENTRER ! " .. t .. "s | " .. #joueursZone .. " joueur(s)"
            task.wait(1)
        end

        -- == PHASE 3 : FERMETURE + TP ==
        startZone.BrickColor         = BrickColor.new("Really red")
        startZone:SetAttribute("Locked", true)
        timerLabel.TextColor3        = Color3.fromRGB(255, 80, 80)
        timerLabel.Text              = "FERME"

        local joueursATP = getJoueursZone()
        local nbTP = #joueursATP
        print("[Tour] Teleportation de " .. nbTP .. " joueurs")

        for _, player in ipairs(joueursATP) do
            local character = player.Character
            if character then
                local hrp = character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    hrp.CFrame = interiorSpawn.CFrame + Vector3.new(0, 3, 0)
                end
            end
        end

        -- == PHASE 4 : DÉLAI PUIS LAVE ==
        if nbTP > 0 then
            timerLabel.Text = "Lave dans " .. CONFIG.DELAI_LAVA .. "s"
            task.wait(CONFIG.DELAI_LAVA)
            resetLava()
            demarrerLava(nbTP)

            -- Attendre que la lave se reset avant de relancer
            while lavaActive do
                task.wait(1)
            end
        end

        -- Cycle repart
        print("[Tour] Nouveau cycle")
    end
end)