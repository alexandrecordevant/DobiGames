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
local Lighting            = game:GetService("Lighting")
local Workspace           = game:GetService("Workspace")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- ============================================================
-- Config
-- ============================================================
local Logger = require(game:GetService("ServerScriptService").SharedLib.Server.Logger)
local Config = require(ReplicatedStorage.GameConfig)

-- ============================================================
-- Chargement différé de SpawnManager (renommé depuis BrainRotSpawner)
-- ============================================================
local _BRS = nil
local function getBRS()
    if not _BRS then
        local ok, m = pcall(require, game:GetService("ServerScriptService").SpawnManager)
        if ok and m then _BRS = m end
    end
    return _BRS
end

-- ============================================================
-- État interne
-- ============================================================
local actif             = false
local meteorActifsCount = 0
local meteorsParts      = {}  -- liste des Parts météores en vol (pour nettoyage)
local materiauOriginel  = {}  -- { [Part] = Enum.Material } pour restauration
local savedLighting     = {}  -- snapshot Lighting avant l'event
local savedChampignons  = {}  -- { [BasePart] = { saColor, material } }

-- ============================================================
-- Utilitaires
-- ============================================================
local function notifierTous(message)
    local ev = ReplicatedStorage:FindFirstChild("NotifEvent")
    if ev then pcall(function() ev:FireAllClients("INFO", message) end) end
end

-- Paramètres raycast : exclut les embankments (GrassTop, Dirt, BaseSeparators)
-- construits une seule fois et réutilisés
local _rayParams = nil
local function getRayParams()
    if _rayParams then return _rayParams end
    _rayParams = RaycastParams.new()
    _rayParams.FilterType = Enum.RaycastFilterType.Exclude
    local excl = {}
    local map = Workspace:FindFirstChild("Map")
    if map then
        for _, child in ipairs(map:GetChildren()) do
            local n = child.Name
            if n:find("GrassTop") or n:find("Dirt") or n == "BaseSeparators" then
                table.insert(excl, child)
            end
        end
    end
    _rayParams.FilterDescendantsInstances = excl
    return _rayParams
end

-- Choisit une position aléatoire dans la zone ChampCommun
-- Raycast depuis Y=500 pour trouver le sol réel (ignore embankments)
local function choisirPoint()
    local zone = Config.ChampCommunZone
    local x, z, fallbackY
    if zone then
        x         = zone.xMin + math.random() * (zone.xMax - zone.xMin)
        z         = zone.zMin + math.random() * (zone.zMax - zone.zMin)
        fallbackY = zone.y or 16
    else
        local pts = Config.ChampCommunPoints
        if pts and #pts > 0 then
            local pt = pts[math.random(1, #pts)]
            return Vector3.new(pt.x, pt.y, pt.z)
        end
        return Vector3.new(190, 16, 66)
    end
    local result = Workspace:Raycast(
        Vector3.new(x, 500, z),
        Vector3.new(0, -600, 0),
        getRayParams()
    )
    local y = result and result.Position.Y or fallbackY
    return Vector3.new(x, y, z)
end

-- ============================================================
-- Lighting : ciel sombre orangé pendant l'event
-- ============================================================
local function assombrirCiel()
    savedLighting = {
        Brightness        = Lighting.Brightness,
        Ambient           = Lighting.Ambient,
        OutdoorAmbient    = Lighting.OutdoorAmbient,
        FogEnd            = Lighting.FogEnd,
        FogColor          = Lighting.FogColor,
        ColorShift_Top    = Lighting.ColorShift_Top,
        ColorShift_Bottom = Lighting.ColorShift_Bottom,
        ClockTime         = Lighting.ClockTime,
    }
    -- ClockTime direct (non tweenable) → crépuscule pour ciel rouge sans trop obscurcir
    pcall(function() Lighting.ClockTime = 17.0 end)

    local info = TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    pcall(function()
        TweenService:Create(Lighting, info, {
            Brightness        = 2.0,
            Ambient           = Color3.fromRGB(180, 60, 30),
            OutdoorAmbient    = Color3.fromRGB(160, 50, 20),
            FogEnd            = 1400,
            FogColor          = Color3.fromRGB(140, 40, 20),
            ColorShift_Top    = Color3.fromRGB(255, 80, 40),
            ColorShift_Bottom = Color3.fromRGB(220, 60, 20),
        }):Play()
    end)

    -- ColorCorrectionEffect pour renforcer la teinte rouge sur tout l'écran
    local cc = Lighting:FindFirstChild("MeteorColorCorrection")
    if cc then cc:Destroy() end
    local correction = Instance.new("ColorCorrectionEffect")
    correction.Name       = "MeteorColorCorrection"
    correction.TintColor  = Color3.fromRGB(255, 120, 100)
    correction.Brightness = 0.05
    correction.Contrast   = 0.05
    correction.Saturation = 0.1
    correction.Parent     = Lighting
end

local function restaurerCiel()
    local cc = Lighting:FindFirstChild("MeteorColorCorrection")
    if cc then pcall(function() cc:Destroy() end) end

    pcall(function()
        Lighting.ClockTime = savedLighting.ClockTime or 14
    end)
    local info = TweenInfo.new(4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    pcall(function()
        TweenService:Create(Lighting, info, {
            Brightness        = savedLighting.Brightness        or 2,
            Ambient           = savedLighting.Ambient           or Color3.fromRGB(70, 70, 70),
            OutdoorAmbient    = savedLighting.OutdoorAmbient    or Color3.fromRGB(70, 70, 70),
            FogEnd            = savedLighting.FogEnd            or 100000,
            FogColor          = savedLighting.FogColor          or Color3.fromRGB(191, 191, 191),
            ColorShift_Top    = savedLighting.ColorShift_Top    or Color3.new(0, 0, 0),
            ColorShift_Bottom = savedLighting.ColorShift_Bottom or Color3.new(0, 0, 0),
        }):Play()
    end)
end

-- ============================================================
-- Matériau Map : CrackedLava pendant l'event
-- ============================================================
local function appliquerMateriauMap()
    materiauOriginel = {}
    local map = Workspace:FindFirstChild("Map")
    if not map then return end
    for _, obj in ipairs(map:GetDescendants()) do
        if obj:IsA("BasePart") then
            materiauOriginel[obj] = { Material = obj.Material, Color = obj.Color }
            obj.Material = Enum.Material.Granite
            obj.Color    = Color3.fromRGB(180, 55, 15)
        end
    end
end

local function restaurerMateriauMap()
    for part, saved in pairs(materiauOriginel) do
        if part and part.Parent then
            pcall(function()
                part.Material = saved.Material
                part.Color    = saved.Color
            end)
        end
    end
    materiauOriginel = {}
end

-- ============================================================
-- Champignons : neon orange-rouge (météore)
-- ============================================================
local function appliquerChampignons()
    savedChampignons = {}
    local deco = Workspace:FindFirstChild("Deco")
    if not deco then return end
    for _, obj in ipairs(deco:GetChildren()) do
        if obj.Name == "Meshes/Mushroom" and obj:IsA("BasePart") then
            local sa = obj:FindFirstChildOfClass("SurfaceAppearance")
            savedChampignons[obj] = { saColor = sa and sa.Color or nil, material = obj.Material }
            obj.Material = Enum.Material.SmoothPlastic
            if sa then sa.Color = Color3.fromRGB(10, 10, 10) end
        end
    end
end

local function restaurerChampignons()
    for obj, saved in pairs(savedChampignons) do
        if obj and obj.Parent then
            pcall(function()
                obj.Material = saved.material
                local sa = obj:FindFirstChildOfClass("SurfaceAppearance")
                if sa and saved.saColor then sa.Color = saved.saColor end
            end)
        end
    end
    savedChampignons = {}
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
    local posDepart = Vector3.new(
        solPoint.X,
        solPoint.Y + (config.hauteurSpawn or 400),
        solPoint.Z
    )
    local posImpact = Vector3.new(solPoint.X, solPoint.Y, solPoint.Z)

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
    local dureeChute = (config.hauteurSpawn or 400) / (config.vitesseTombee or 80)
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

        -- Shake caméra client
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

    assombrirCiel()
    appliquerMateriauMap()
    appliquerChampignons()

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

    restaurerMateriauMap()
    restaurerChampignons()
    restaurerCiel()

end

return EventMeteorDrop
