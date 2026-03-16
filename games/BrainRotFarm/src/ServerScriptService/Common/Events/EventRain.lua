-- ServerScriptService/Common/Events/EventRain.lua
-- BrainRotFarm — Rain Event
-- 3 nuages au-dessus des spawn points du ChampCommun, pluie visible + boost spawn

local EventRain = {}
EventRain.NOM          = "Rain"
EventRain.DUREE_DEFAUT = 90

-- ============================================================
-- Services
-- ============================================================
local TweenService        = game:GetService("TweenService")
local Workspace           = game:GetService("Workspace")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- ============================================================
-- Config
-- ============================================================
local Config = require(ReplicatedStorage.Specialized.GameConfig)

-- ============================================================
-- Chargement différé de ChampCommunSpawner
-- ============================================================
local _CCS = nil
local function getCCS()
    if not _CCS then
        local ok, m = pcall(require, ServerScriptService.Specialized.ChampCommunSpawner)
        if ok and m then _CCS = m end
    end
    return _CCS
end

-- ============================================================
-- État interne
-- ============================================================
local nuages     = {}   -- liste des Parts nuage créées
local pulseTasks = {}   -- threads de pulsation des lumières

-- ============================================================
-- Utilitaires
-- ============================================================
local function notifierTous(message)
    local ev = ReplicatedStorage:FindFirstChild("NotifEvent")
    if ev then pcall(function() ev:FireAllClients("INFO", message) end) end
end

-- ============================================================
-- Création d'un nuage avec pluie
-- ============================================================
local function creerNuage(position, config)
    local taille = config.tailleNuage or Vector3.new(20, 5, 20)

    local nuage = Instance.new("Part")
    nuage.Name         = "RainCloud"
    nuage.Size         = taille
    nuage.Anchored     = true
    nuage.CanCollide   = false
    nuage.BrickColor   = BrickColor.new("Medium stone grey")
    nuage.Material     = Enum.Material.SmoothPlastic
    nuage.Transparency = 0.3
    nuage.CastShadow   = false
    -- Position initiale : plus haut (pour l'animation d'arrivée)
    nuage.Position     = position + Vector3.new(0, 50, 0)
    nuage.Parent       = Workspace

    -- SpecialMesh cylindrique pour l'aspect "nuage plat"
    local mesh = Instance.new("SpecialMesh")
    mesh.MeshType = Enum.MeshType.Cylinder
    mesh.Parent   = nuage

    -- ParticleEmitter pluie
    local rain = Instance.new("ParticleEmitter")
    rain.Texture          = "rbxasset://textures/particles/sparkles_main.dds"
    rain.Rate             = config.particleRate or 50
    rain.Lifetime         = NumberRange.new(0.8, 1.2)
    rain.Speed            = NumberRange.new(40, 60)
    rain.SpreadAngle      = Vector2.new(15, 15)
    rain.EmissionDirection = Enum.NormalId.Bottom
    rain.Color            = ColorSequence.new(Color3.fromRGB(150, 200, 255))
    rain.Size             = NumberSequence.new(0.2)
    rain.LightEmission    = 0
    rain.Parent           = nuage

    -- PointLight sous le nuage (lumière bleutée)
    local light = Instance.new("PointLight")
    light.Brightness = 1
    light.Range      = 30
    light.Color      = Color3.fromRGB(150, 180, 255)
    light.Parent     = nuage

    -- Pulsation lente de la lumière (2s loop)
    local pulseThread = task.spawn(function()
        local infoHaut = TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
        local infoBas  = TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
        while nuage and nuage.Parent do
            pcall(function()
                TweenService:Create(light, infoHaut, { Brightness = 2 }):Play()
            end)
            task.wait(2.1)
            if not (nuage and nuage.Parent) then break end
            pcall(function()
                TweenService:Create(light, infoBas, { Brightness = 0.5 }):Play()
            end)
            task.wait(2.1)
        end
    end)
    table.insert(pulseTasks, pulseThread)

    -- Animation d'arrivée (descend vers la position finale)
    local posFinale = position
    local infoDesc  = TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    pcall(function()
        TweenService:Create(nuage, infoDesc, { Position = posFinale }):Play()
    end)

    return nuage
end

-- ============================================================
-- API
-- ============================================================

function EventRain.Demarrer(config)
    nuages     = {}
    pulseTasks = {}

    -- Notifier + EventStarted
    notifierTous(config.message)
    local es = ReplicatedStorage:FindFirstChild("EventStarted")
    if es then pcall(function() es:FireAllClients("Rain", config.duree) end) end

    -- Créer un nuage par point ChampCommun
    local points = Config.ChampCommunPoints or {}
    for _, pt in ipairs(points) do
        local hauteur = config.hauteurNuages or 35
        local pos     = Vector3.new(pt.x, pt.y + hauteur, pt.z)
        local nuage   = creerNuage(pos, config)
        table.insert(nuages, nuage)
    end

    -- Booster le spawn du ChampCommun
    local CCS = getCCS()
    if CCS and CCS.SetMultiplier then
        pcall(CCS.SetMultiplier, config.spawnMultiplier or 3)
    end

    print("[EventRain] ▶ Rain Event démarré (" .. (config.duree or 90) .. "s) — " .. #nuages .. " nuage(s)")
end

function EventRain.Terminer()
    -- Arrêter les pulsations
    for _, thread in ipairs(pulseTasks) do
        pcall(task.cancel, thread)
    end
    pulseTasks = {}

    -- Animer la montée des nuages puis les détruire
    for _, nuage in ipairs(nuages) do
        if nuage and nuage.Parent then
            local posHaut   = nuage.Position + Vector3.new(0, 80, 0)
            local infoMonte = TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            pcall(function()
                TweenService:Create(nuage, infoMonte, { Position = posHaut }):Play()
            end)
            local ref = nuage
            task.delay(3.2, function()
                if ref and ref.Parent then
                    pcall(function() ref:Destroy() end)
                end
            end)
        end
    end
    nuages = {}

    -- Remettre le multiplicateur de spawn à 1
    local CCS = getCCS()
    if CCS and CCS.SetMultiplier then
        pcall(CCS.SetMultiplier, 1)
    end

    local ev = ReplicatedStorage:FindFirstChild("NotifEvent")
    if ev then pcall(function() ev:FireAllClients("INFO", "☀️ The rain stops... the field stays fertilized!") end) end

    print("[EventRain] ■ Rain Event terminé")
end

return EventRain
