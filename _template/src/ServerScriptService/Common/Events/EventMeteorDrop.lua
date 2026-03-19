-- ServerScriptService/Common/Events/EventMeteorDrop.lua
-- BrainRotFarm — Event Meteor Drop
-- Météores tombent sur le ChampCommun, génèrent des BR rares à l'impact

local EventMeteorDrop = {}
EventMeteorDrop.NOM          = "MeteorDrop"
EventMeteorDrop.DUREE_DEFAUT = 60

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
-- Chargement différé de SpawnManager (renommé depuis BrainRotSpawner)
-- ============================================================
local _BRS = nil
local function getBRS()
    if not _BRS then
        local ok, m = pcall(require, game:GetService("ServerScriptService").Common.SpawnManager)
        if ok and m then _BRS = m end
    end
    return _BRS
end

-- ============================================================
-- État interne
-- ============================================================
local actif           = false
local meteorActifsCount = 0
local meteorsParts    = {}   -- liste des Parts météores en vol (pour nettoyage)

-- ============================================================
-- Utilitaires
-- ============================================================
local function notifierTous(message)
    local ev = ReplicatedStorage:FindFirstChild("NotifEvent")
    if ev then pcall(function() ev:FireAllClients("INFO", message) end) end
end

-- Choisit un point ChampCommun aléatoire depuis GameConfig
local function choisirPoint()
    local pts = Config.ChampCommunPoints
    if not pts or #pts == 0 then
        return Vector3.new(190, 16, 66)  -- fallback hardcodé
    end
    local pt = pts[math.random(1, #pts)]
    return Vector3.new(pt.x, pt.y, pt.z)
end

-- ============================================================
-- Effet d'impact : explosion visuelle au sol
-- ============================================================
local function creerImpact(position, rayonImpact)
    local impact = Instance.new("Part")
    impact.Name             = "MeteorImpact"
    impact.Size             = Vector3.new(rayonImpact * 2, 0.5, rayonImpact * 2)
    impact.Position         = position
    impact.Anchored         = true
    impact.CanCollide       = false
    impact.BrickColor       = BrickColor.new("Bright orange")
    impact.Material         = Enum.Material.Neon
    impact.Transparency     = 0
    impact.CastShadow       = false
    impact.Parent           = Workspace

    -- Fade out + agrandissement en 1s
    local info = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    pcall(function()
        TweenService:Create(impact, info, {
            Transparency = 1,
            Size         = Vector3.new(rayonImpact * 4, 0.5, rayonImpact * 4),
        }):Play()
    end)

    -- Lumière d'impact
    local light = Instance.new("PointLight")
    light.Brightness = 5
    light.Range      = rayonImpact * 3
    light.Color      = Color3.fromRGB(255, 100, 20)
    light.Parent     = impact

    -- Fade de la lumière
    pcall(function()
        TweenService:Create(light, info, { Brightness = 0 }):Play()
    end)

    task.delay(1.5, function()
        if impact and impact.Parent then
            pcall(function() impact:Destroy() end)
        end
    end)
end

-- ============================================================
-- Spawn d'un météore
-- ============================================================
local function spawnerMeteore(config)
    -- Limite max simultanés
    if meteorActifsCount >= (config.nbMeteores or 5) then return end

    local solPoint = choisirPoint()
    -- Décalage horizontal aléatoire autour du point
    local offsetX  = math.random(-20, 20)
    local offsetZ  = math.random(-20, 20)
    local posDepart = Vector3.new(
        solPoint.X + offsetX,
        solPoint.Y + (config.hauteurSpawn or 200),
        solPoint.Z + offsetZ
    )
    local posImpact = Vector3.new(
        solPoint.X + offsetX,
        solPoint.Y,
        solPoint.Z + offsetZ
    )

    -- Créer la Part météore
    local meteor = Instance.new("Part")
    meteor.Name          = "Meteor_" .. tostring(math.random(1000, 9999))
    meteor.Size          = Vector3.new(6, 6, 6)
    meteor.Position      = posDepart
    meteor.Anchored      = true
    meteor.CanCollide    = false
    meteor.BrickColor    = BrickColor.new("Bright orange")
    meteor.Material      = Enum.Material.Neon
    meteor.CastShadow    = false
    meteor.Parent        = Workspace

    -- SpecialMesh sphérique
    local mesh = Instance.new("SpecialMesh")
    mesh.MeshType = Enum.MeshType.Sphere
    mesh.Parent   = meteor

    -- PointLight orange
    local light = Instance.new("PointLight")
    light.Brightness = 4
    light.Range      = 30
    light.Color      = Color3.fromRGB(255, 100, 20)
    light.Parent     = meteor

    -- ParticleEmitter flammes
    local particle = Instance.new("ParticleEmitter")
    particle.Texture     = "rbxasset://textures/particles/fire_main.dds"
    particle.Rate        = 20
    particle.Lifetime    = NumberRange.new(0.3, 0.7)
    particle.Speed       = NumberRange.new(5, 10)
    particle.SpreadAngle = Vector2.new(30, 30)
    particle.Color       = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 150, 0)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 50, 0)),
    })
    particle.Parent = meteor

    -- Ajouter à la liste de nettoyage
    meteorActifsCount = meteorActifsCount + 1
    table.insert(meteorsParts, meteor)

    -- Animation de chute (linéaire)
    local dureeChute = (config.hauteurSpawn or 200) / (config.vitesseTombee or 80)
    local infoChute  = TweenInfo.new(dureeChute, Enum.EasingStyle.Linear)
    local tween = TweenService:Create(meteor, infoChute, { Position = posImpact })
    tween:Play()

    -- Impact à l'arrivée
    tween.Completed:Connect(function(playbackState)
        if playbackState ~= Enum.PlaybackState.Completed then return end
        if not meteor or not meteor.Parent then return end

        -- Retirer de la liste
        for i, p in ipairs(meteorsParts) do
            if p == meteor then table.remove(meteorsParts, i) break end
        end
        meteorActifsCount = math.max(0, meteorActifsCount - 1)

        -- Détruire le météore
        pcall(function() meteor:Destroy() end)

        -- Explosion visuelle
        creerImpact(posImpact, config.rayonImpact or 15)

        -- Notifier l'impact + shake caméra client
        notifierTous(config.messageImpact or "💥 Impact !")
        local reImpact = ReplicatedStorage:FindFirstChild("MeteorImpact")
        if reImpact then
            pcall(function() reImpact:FireAllClients(posImpact) end)
        end

        -- Spawner un BR rare à l'impact
        local raretes = config.raretesMeteore or { "LEGENDARY" }
        local rareteChoisie = raretes[math.random(1, #raretes)]
        local BRS = getBRS()
        if BRS and BRS.SpawnerBRSpecifique then
            pcall(BRS.SpawnerBRSpecifique, posImpact, rareteChoisie)
        end
    end)
end

-- ============================================================
-- Boucle de spawn des météores
-- ============================================================
local function boucleSpawn(config)
    local intervalle = config.intervalleSpawn or 12
    while actif do
        task.wait(intervalle)
        if not actif then break end
        pcall(spawnerMeteore, config)
    end
end

-- ============================================================
-- API
-- ============================================================

function EventMeteorDrop.Demarrer(config)
    actif             = true
    meteorActifsCount = 0
    meteorsParts      = {}

    -- Notifier + EventStarted
    local ev = ReplicatedStorage:FindFirstChild("NotifEvent")
    if ev then pcall(function() ev:FireAllClients("INFO", config.message) end) end
    local es = ReplicatedStorage:FindFirstChild("EventStarted")
    if es then pcall(function() es:FireAllClients("MeteorDrop", config.duree) end) end

    -- Spawn immédiat du 1er météore, puis boucle
    task.spawn(function()
        task.wait(2)
        if actif then pcall(spawnerMeteore, config) end
        boucleSpawn(config)
    end)

    print("[EventMeteorDrop] ▶ Meteor Drop démarré (" .. (config.duree or 60) .. "s)")
end

function EventMeteorDrop.Terminer()
    actif = false

    -- Détruire les météores encore en vol
    for _, meteor in ipairs(meteorsParts) do
        if meteor and meteor.Parent then
            pcall(function() meteor:Destroy() end)
        end
    end
    meteorsParts      = {}
    meteorActifsCount = 0

    local ev = ReplicatedStorage:FindFirstChild("NotifEvent")
    if ev then pcall(function() ev:FireAllClients("INFO", "☄️ Les météores ont cessé de tomber.") end) end

    print("[EventMeteorDrop] ■ Meteor Drop terminé")
end

return EventMeteorDrop
