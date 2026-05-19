-- ServerScriptService/Events/EventLuckyHour.lua
-- BrainRotFarm — Lucky Hour Event
-- Des BR RARE/EPIC/LEGENDARY spawnnent directement sur les bases occupées des joueurs

local EventLuckyHour = {}
EventLuckyHour.NOM          = "LuckyHour"
EventLuckyHour.DUREE_DEFAUT = 60

-- ============================================================
-- Services
-- ============================================================
local Players             = game:GetService("Players")
local Lighting            = game:GetService("Lighting")
local TweenService        = game:GetService("TweenService")
local Workspace           = game:GetService("Workspace")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- ============================================================
-- Dépendances
-- ============================================================
local Logger      = require(ServerScriptService.SharedLib.Server.Logger)
local GameConfig  = require(ReplicatedStorage:WaitForChild("GameConfig"))

-- ============================================================
-- Chargement différé de SpawnManager
-- ============================================================
local _SpawnManager = nil
local function getSpawnManager()
    if not _SpawnManager then
        local ok, m = pcall(require, ServerScriptService.SpawnManager)
        if ok and m then _SpawnManager = m end
    end
    return _SpawnManager
end

-- ============================================================
-- État interne
-- ============================================================
local actif           = false
local spawnThread     = nil
local colorCorrection = nil
local savedLighting   = {}
local savedMap        = {}   -- { [BasePart] = { Material, Color } }
local savedDeco       = {}   -- { [BasePart] = { color, material } }
local savedDecoLights = {}   -- { PointLight, ... }

-- ============================================================
-- Utilitaires
-- ============================================================
local function notifierTous(message)
    local ev = ReplicatedStorage:FindFirstChild("NotifEvent")
    if ev then pcall(function() ev:FireAllClients("INFO", message) end) end
end

-- Tirage pondéré dans le pool de rareté
-- rarityPool = { RARE = 60, EPIC = 35, LEGENDARY = 5 }
local function tirerRarete(rarityPool)
    local total = 0
    for _, poids in pairs(rarityPool) do
        total = total + poids
    end
    local roll = math.random() * total
    local cumul = 0
    for nom, poids in pairs(rarityPool) do
        cumul = cumul + poids
        if roll <= cumul then
            return nom
        end
    end
    -- Fallback au cas où
    return "RARE"
end

-- ============================================================
-- Visuel : ColorCorrection violette
-- ============================================================
-- ============================================================
-- Sol CrackedLava rose
-- ============================================================
local function appliquerSol()
    savedMap = {}
    local map = Workspace:FindFirstChild("Map")
    if not map then return end
    for _, obj in ipairs(map:GetDescendants()) do
        if obj:IsA("BasePart") then
            savedMap[obj] = { Material = obj.Material, Color = obj.Color }
            obj.Material  = Enum.Material.CrackedLava
            obj.Color     = Color3.fromRGB(255, 20, 147)
        end
    end
end

local function restaurerSol()
    for part, saved in pairs(savedMap) do
        if part and part.Parent then
            pcall(function()
                part.Material = saved.Material
                part.Color    = saved.Color
            end)
        end
    end
    savedMap = {}
end

-- ============================================================
-- Ciel rosé
-- ============================================================
local function appliquerCiel()
    savedLighting = {
        Ambient           = Lighting.Ambient,
        OutdoorAmbient    = Lighting.OutdoorAmbient,
        ColorShift_Top    = Lighting.ColorShift_Top,
        ColorShift_Bottom = Lighting.ColorShift_Bottom,
    }
    local info = TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    pcall(function()
        TweenService:Create(Lighting, info, {
            Ambient           = Color3.fromRGB(180, 140, 165),
            OutdoorAmbient    = Color3.fromRGB(160, 120, 145),
            ColorShift_Top    = Color3.fromRGB(255, 160, 200),
            ColorShift_Bottom = Color3.fromRGB(220, 130, 170),
        }):Play()
    end)
end

local function restaurerCiel()
    local info = TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    pcall(function()
        TweenService:Create(Lighting, info, {
            Ambient           = savedLighting.Ambient           or Color3.fromRGB(70, 70, 70),
            OutdoorAmbient    = savedLighting.OutdoorAmbient    or Color3.fromRGB(70, 70, 70),
            ColorShift_Top    = savedLighting.ColorShift_Top    or Color3.new(0, 0, 0),
            ColorShift_Bottom = savedLighting.ColorShift_Bottom or Color3.new(0, 0, 0),
        }):Play()
    end)
end

-- ============================================================
-- Champignons roses
-- ============================================================
local function appliquerChampignons()
    savedDeco       = {}
    savedDecoLights = {}
    local folder = Workspace:FindFirstChild("Deco")
    if folder then folder = folder:FindFirstChild("Champignons") end
    if not folder then return end
    for _, model in ipairs(folder:GetChildren()) do
        local lightAdded = false
        for _, part in ipairs(model:GetDescendants()) do
            if part:IsA("BasePart") then
                local r, g, b = part.Color.R * 255, part.Color.G * 255, part.Color.B * 255
                if g > 150 and b > 100 then  -- tiges beiges (241,231,199) + points blancs (248,248,248)
                    savedDeco[part] = { color = part.Color, material = part.Material }
                    part.Material = Enum.Material.Neon
                    part.Color    = Color3.fromRGB(255, 0, 200)
                    if not lightAdded then
                        local light = Instance.new("PointLight")
                        light.Brightness = 4
                        light.Range      = 20
                        light.Color      = Color3.fromRGB(255, 0, 180)
                        light.Parent     = part  -- BasePart, pas Model
                        table.insert(savedDecoLights, light)
                        lightAdded = true
                    end
                end
            end
        end
    end
end

local function restaurerChampignons()
    for _, light in ipairs(savedDecoLights) do
        if light and light.Parent then
            pcall(function() light:Destroy() end)
        end
    end
    savedDecoLights = {}
    for part, saved in pairs(savedDeco) do
        if part and part.Parent then
            pcall(function()
                part.Material = saved.material
                part.Color    = saved.color
            end)
        end
    end
    savedDeco = {}
end

-- ============================================================
-- Visuel : ColorCorrection violette
-- ============================================================
local function activerAmbiance(couleur)
    local existing = Lighting:FindFirstChild("LuckyHourCC")
    if existing then existing:Destroy() end

    colorCorrection            = Instance.new("ColorCorrectionEffect")
    colorCorrection.Name       = "LuckyHourCC"
    colorCorrection.TintColor  = couleur or Color3.fromRGB(255, 180, 220)
    colorCorrection.Saturation = 0.2
    colorCorrection.Brightness = 0.08
    colorCorrection.Contrast   = 0
    colorCorrection.Parent     = Lighting
end

local function desactiverAmbiance()
    if colorCorrection and colorCorrection.Parent then
        pcall(function() colorCorrection:Destroy() end)
    end
    colorCorrection = nil
    -- Sécurité
    local residuel = Lighting:FindFirstChild("LuckyHourCC")
    if residuel then residuel:Destroy() end
end

-- ============================================================
-- Tirage mutation (LuckyHour Mutation)
-- ============================================================
local function tirerTypeMutation(mutCfg)
    local total = 0
    for _, t in ipairs(mutCfg.types) do total = total + t.weight end
    local roll  = math.random() * total
    local cumul = 0
    for _, t in ipairs(mutCfg.types) do
        cumul = cumul + t.weight
        if roll <= cumul then return t end
    end
    return mutCfg.types[1]
end

local function doitMuter(mutCfg)
    if not mutCfg or not mutCfg.enabled then return false end
    return math.random() < (mutCfg.chance or 0)
end

-- ============================================================
-- Boucle de spawn sur les bases occupées
-- ============================================================
local function spawnPourJoueur(SM, player, rarityPool)
    local baseIndex = SM.GetBase(player)
    if not baseIndex then return end

    local rareteNom = tirerRarete(rarityPool)
    local mutCfg    = GameConfig.LuckyHourMutationConfig

    if doitMuter(mutCfg) then
        local typeMutation = tirerTypeMutation(mutCfg)
        pcall(SM.SpawnerBRMuteeDansBase, baseIndex, rareteNom, typeMutation.name, typeMutation.multiplier)
        Logger.info("Mutation", "LuckyHour mute : %s %s x%.1f sur Base_%d (%s)",
            typeMutation.name, rareteNom, typeMutation.multiplier, baseIndex, player.Name)
    else
        pcall(SM.SpawnerBRDansBase, baseIndex, rareteNom)
        Logger.debug("Event", "LuckyHour : %s spawne sur Base_%d (%s)", rareteNom, baseIndex, player.Name)
    end
end

local function boucleSpawn(config)
    local rarityPool    = config.rarityPool    or { RARE = 60, EPIC = 35, LEGENDARY = 5 }
    local spawnInterval = config.spawnInterval or 10

    while actif do
        task.wait(spawnInterval)
        if not actif then break end

        local SM = getSpawnManager()
        if not SM then continue end

        for _, player in ipairs(Players:GetPlayers()) do
            spawnPourJoueur(SM, player, rarityPool)
        end
    end
end

-- ============================================================
-- API
-- ============================================================

function EventLuckyHour.Demarrer(config)
    actif = true

    -- Notifier + EventStarted
    notifierTous(config.message)
    local es = ReplicatedStorage:FindFirstChild("EventStarted")
    if es then pcall(function() es:FireAllClients("LuckyHour", config.duree) end) end

    -- Sol + ciel + ambiance + champignons
    appliquerSol()
    appliquerCiel()
    task.delay(1, appliquerChampignons)
    activerAmbiance(config.couleurAmbiance or Color3.fromRGB(180, 0, 255))

    -- Lancer la boucle de spawn
    spawnThread = task.spawn(function()
        -- Premier spawn immédiat après un court délai
        task.wait(2)
        if not actif then return end

        local SM = getSpawnManager()
        if SM then
            local rarityPool = config.rarityPool or { RARE = 60, EPIC = 35, LEGENDARY = 5 }
            for _, player in ipairs(Players:GetPlayers()) do
                spawnPourJoueur(SM, player, rarityPool)
            end
        end

        boucleSpawn(config)
    end)

    Logger.info("Event", "▶ Lucky Hour démarré (%ds) — interval %ds", config.duree or EventLuckyHour.DUREE_DEFAUT, config.spawnInterval or 10)
end

function EventLuckyHour.Terminer()
    actif = false

    -- Arrêter la boucle
    if spawnThread then
        pcall(task.cancel, spawnThread)
        spawnThread = nil
    end

    -- Restaurer sol + ciel + ambiance + champignons
    restaurerSol()
    restaurerCiel()
    restaurerChampignons()
    desactiverAmbiance()

    Logger.info("Event", "■ Lucky Hour terminé")
end

return EventLuckyHour
