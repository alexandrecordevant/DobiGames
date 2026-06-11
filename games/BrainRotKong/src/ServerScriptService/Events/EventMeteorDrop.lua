-- ServerScriptService/Common/Events/EventMeteorDrop.lua
-- BrainRotKong — Event Meteor Drop
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
local savedChampignons      = {}  -- { [BasePart] = { color, material } }
local savedChampignonLights = {}  -- { PointLight, ... } braises
local _meteorFolder     = nil -- Folder Workspace contenant les météores en vol

-- ============================================================
-- Utilitaires
-- ============================================================
local function notifierTous(message)
    local ev = ReplicatedStorage:FindFirstChild("NotifEvent")
    if ev then pcall(function() ev:FireAllClients("INFO", message) end) end
end

local function getMeteorFolder()
    if not _meteorFolder or not _meteorFolder.Parent then
        _meteorFolder = Instance.new("Folder")
        _meteorFolder.Name   = "MeteorsFolder"
        _meteorFolder.Parent = Workspace
    end
    return _meteorFolder
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
    -- Exclure le folder des météores en vol pour éviter qu'un raycast
    -- frappe un météore et retourne un Y trop haut
    local mf = Workspace:FindFirstChild("MeteorsFolder")
    if mf then table.insert(excl, mf) end
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
    pcall(function() Lighting.ClockTime = 17.5 end)

    local info = TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    pcall(function()
        TweenService:Create(Lighting, info, {
            Brightness        = 1.8,
            Ambient           = Color3.fromRGB(140, 70, 45),
            OutdoorAmbient    = Color3.fromRGB(120, 60, 35),
            FogEnd            = 900,
            FogColor          = Color3.fromRGB(180, 60, 30),
            ColorShift_Top    = Color3.fromRGB(180, 70, 40),
            ColorShift_Bottom = Color3.fromRGB(150, 55, 25),
        }):Play()
    end)

    -- ColorCorrectionEffect : teinte orange-rouge légère, lisibilité préservée
    local cc = Lighting:FindFirstChild("MeteorColorCorrection")
    if cc then cc:Destroy() end
    local correction = Instance.new("ColorCorrectionEffect")
    correction.Name       = "MeteorColorCorrection"
    correction.TintColor  = Color3.fromRGB(255, 140, 100)
    correction.Brightness = 0.03
    correction.Contrast   = 0.12
    correction.Saturation = 0.15
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
            obj.Color    = Color3.fromRGB(160, 80, 45)
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
    savedChampignons      = {}
    savedChampignonLights = {}
    local folder = Workspace:FindFirstChild("Deco")
    if folder then folder = folder:FindFirstChild("Champignons") end
    if not folder then return end
    for _, model in ipairs(folder:GetChildren()) do
        -- Détecter tige (241,231,199) ET points blancs (248,248,248) : g>150 et b>100 exclut le rouge (g=40)
        local lowestPart = nil
        for _, part in ipairs(model:GetDescendants()) do
            if part:IsA("BasePart") then
                local r, g, b = part.Color.R * 255, part.Color.G * 255, part.Color.B * 255
                if g > 150 and b > 100 then  -- tiges beiges + points blancs, exclut rouge (g=40)
                    savedChampignons[part] = { color = part.Color, material = part.Material }
                    part.Material = Enum.Material.Neon
                    part.Color    = Color3.fromRGB(255, 150, 30)
                    -- Trouver la part la plus basse pour la braise (tige au sol)
                    if not lowestPart or part.Position.Y < lowestPart.Position.Y then
                        lowestPart = part
                    end
                end
            end
        end
        -- Braise sur la tige (part la plus basse du modèle)
        if lowestPart then
            local pl = Instance.new("PointLight")
            pl.Brightness = 4
            pl.Range      = 16
            pl.Color      = Color3.fromRGB(255, 80, 10)
            pl.Shadows    = false
            pl.Parent     = lowestPart
            table.insert(savedChampignonLights, pl)
        end
    end
end

local function restaurerChampignons()
    for _, light in ipairs(savedChampignonLights) do
        if light and light.Parent then light:Destroy() end
    end
    savedChampignonLights = {}
    for part, saved in pairs(savedChampignons) do
        if part and part.Parent then
            part.Material = saved.material
            part.Color    = saved.color
        end
    end
    savedChampignons = {}
end

-- ============================================================
-- Effet d'impact : explosion visuelle au sol
-- ============================================================
local function creerImpact(position, rayonImpact)
    local r    = rayonImpact
    local pos0 = position + Vector3.new(0, 0.15, 0)

    -- ── Shockwave 1 : anneau qui explose vers l'extérieur ─────────
    local ring1 = Instance.new("Part")
    ring1.Name        = "MeteorRing"
    ring1.Size        = Vector3.new(r, 0.3, r)
    ring1.CFrame      = CFrame.new(pos0)
    ring1.Anchored    = true
    ring1.CanCollide  = false
    ring1.Material    = Enum.Material.Neon
    ring1.Color       = Color3.fromRGB(255, 120, 20)
    ring1.Transparency = 0
    ring1.CastShadow  = false
    ring1.Parent      = Workspace
    pcall(function()
        TweenService:Create(ring1,
            TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = Vector3.new(r * 8, 0.2, r * 8), Transparency = 1,
        }):Play()
    end)

    -- ── Shockwave 2 : légèrement décalé, plus lent ────────────────
    task.delay(0.12, function()
        local ring2 = Instance.new("Part")
        ring2.Name        = "MeteorRing"
        ring2.Size        = Vector3.new(r * 0.5, 0.3, r * 0.5)
        ring2.CFrame      = CFrame.new(pos0)
        ring2.Anchored    = true
        ring2.CanCollide  = false
        ring2.Material    = Enum.Material.Neon
        ring2.Color       = Color3.fromRGB(255, 200, 60)
        ring2.Transparency = 0.2
        ring2.CastShadow  = false
        ring2.Parent      = Workspace
        pcall(function()
            TweenService:Create(ring2,
                TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = Vector3.new(r * 5, 0.2, r * 5), Transparency = 1,
            }):Play()
        end)
        task.delay(1, function()
            if ring2 and ring2.Parent then pcall(function() ring2:Destroy() end) end
        end)
    end)

    -- ── Flash central : sphère brillante qui explose ──────────────
    local flash = Instance.new("Part")
    flash.Name        = "MeteorFlash"
    flash.Size        = Vector3.new(r * 0.6, r * 0.6, r * 0.6)
    flash.CFrame      = CFrame.new(position + Vector3.new(0, r * 0.3, 0))
    flash.Anchored    = true
    flash.CanCollide  = false
    flash.Material    = Enum.Material.Neon
    flash.Color       = Color3.fromRGB(255, 240, 140)
    flash.Transparency = 0
    flash.CastShadow  = false
    flash.Shape       = Enum.PartType.Ball
    flash.Parent      = Workspace
    pcall(function()
        TweenService:Create(flash,
            TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = Vector3.new(r * 3, r * 3, r * 3), Transparency = 1,
        }):Play()
    end)

    -- ── Cratère : disque lumineux qui s'estompe sur 5s ────────────
    local crater = Instance.new("Part")
    crater.Name        = "MeteorCrater"
    crater.Size        = Vector3.new(r * 1.8, 0.4, r * 1.8)
    crater.CFrame      = CFrame.new(position)
    crater.Anchored    = true
    crater.CanCollide  = false
    crater.Material    = Enum.Material.Neon
    crater.Color       = Color3.fromRGB(255, 70, 10)
    crater.Transparency = 0.05
    crater.CastShadow  = false
    crater.Parent      = Workspace
    pcall(function()
        TweenService:Create(crater,
            TweenInfo.new(5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Transparency = 1,
        }):Play()
    end)

    -- ── Lumière très intense, fade sur 3s ─────────────────────────
    local lightPart = Instance.new("Part")
    lightPart.Size        = Vector3.new(1, 1, 1)
    lightPart.CFrame      = CFrame.new(position + Vector3.new(0, 3, 0))
    lightPart.Anchored    = true
    lightPart.CanCollide  = false
    lightPart.Transparency = 1
    lightPart.CastShadow  = false
    lightPart.Parent      = Workspace
    local light = Instance.new("PointLight")
    light.Brightness = 14
    light.Range      = r * 7
    light.Color      = Color3.fromRGB(255, 110, 20)
    light.Parent     = lightPart
    pcall(function()
        TweenService:Create(light,
            TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Brightness = 0,
        }):Play()
    end)

    -- ── Émetteur de particules ────────────────────────────────────
    local emitterPart = Instance.new("Part")
    emitterPart.Size        = Vector3.new(r * 0.4, 1, r * 0.4)
    emitterPart.CFrame      = CFrame.new(position + Vector3.new(0, 0.5, 0))
    emitterPart.Anchored    = true
    emitterPart.CanCollide  = false
    emitterPart.Transparency = 1
    emitterPart.CastShadow  = false
    emitterPart.Parent      = Workspace

    -- Feu : colonne qui monte
    local feu = Instance.new("ParticleEmitter")
    feu.Texture        = "rbxasset://textures/particles/fire_main.dds"
    feu.Rate           = 0
    feu.Lifetime       = NumberRange.new(1.5, 3.5)
    feu.Speed          = NumberRange.new(20, 55)
    feu.SpreadAngle    = Vector2.new(22, 22)
    feu.RotSpeed       = NumberRange.new(-90, 90)
    feu.Acceleration   = Vector3.new(0, -8, 0)
    feu.LightEmission  = 0.85
    feu.LightInfluence = 0.1
    feu.Size           = NumberSequence.new({
        NumberSequenceKeypoint.new(0,   r * 0.22),
        NumberSequenceKeypoint.new(0.4, r * 0.42),
        NumberSequenceKeypoint.new(1,   0),
    })
    feu.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   Color3.fromRGB(255, 220, 80)),
        ColorSequenceKeypoint.new(0.3, Color3.fromRGB(255, 80, 10)),
        ColorSequenceKeypoint.new(1,   Color3.fromRGB(50, 10, 5)),
    })
    feu.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0,   0),
        NumberSequenceKeypoint.new(0.6, 0.2),
        NumberSequenceKeypoint.new(1,   1),
    })
    feu.Parent = emitterPart

    -- Fumée : nuage sombre qui monte lentement
    local fumee = Instance.new("ParticleEmitter")
    fumee.Texture        = "rbxasset://textures/particles/smoke_main.dds"
    fumee.Rate           = 0
    fumee.Lifetime       = NumberRange.new(4, 8)
    fumee.Speed          = NumberRange.new(6, 16)
    fumee.SpreadAngle    = Vector2.new(18, 18)
    fumee.RotSpeed       = NumberRange.new(-20, 20)
    fumee.LightEmission  = 0
    fumee.LightInfluence = 1
    fumee.Size           = NumberSequence.new({
        NumberSequenceKeypoint.new(0,   r * 0.1),
        NumberSequenceKeypoint.new(0.4, r * 0.8),
        NumberSequenceKeypoint.new(1,   r * 1.8),
    })
    fumee.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   Color3.fromRGB(80, 30, 10)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(40, 20, 10)),
        ColorSequenceKeypoint.new(1,   Color3.fromRGB(18, 18, 18)),
    })
    fumee.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0,   0.2),
        NumberSequenceKeypoint.new(0.6, 0.5),
        NumberSequenceKeypoint.new(1,   1),
    })
    fumee.Parent = emitterPart

    -- Étincelles : fusent en arc avec gravité
    local etincelles = Instance.new("ParticleEmitter")
    etincelles.Texture        = "rbxasset://textures/particles/sparkles_main.dds"
    etincelles.Rate           = 0
    etincelles.Lifetime       = NumberRange.new(0.6, 2)
    etincelles.Speed          = NumberRange.new(35, 95)
    etincelles.SpreadAngle    = Vector2.new(75, 75)
    etincelles.RotSpeed       = NumberRange.new(-180, 180)
    etincelles.Acceleration   = Vector3.new(0, -55, 0)
    etincelles.LightEmission  = 1
    etincelles.LightInfluence = 0
    etincelles.Size           = NumberSequence.new({
        NumberSequenceKeypoint.new(0,   1.4),
        NumberSequenceKeypoint.new(0.5, 0.9),
        NumberSequenceKeypoint.new(1,   0),
    })
    etincelles.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   Color3.fromRGB(255, 245, 120)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 140, 20)),
        ColorSequenceKeypoint.new(1,   Color3.fromRGB(180, 40, 0)),
    })
    etincelles.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0,   0),
        NumberSequenceKeypoint.new(0.8, 0),
        NumberSequenceKeypoint.new(1,   1),
    })
    etincelles.Parent = emitterPart

    -- Burst ponctuel immédiat (pas de Rate continu)
    pcall(function()
        feu:Emit(55)
        fumee:Emit(28)
        etincelles:Emit(90)
    end)

    -- ── Nettoyage progressif ──────────────────────────────────────
    task.delay(0.7, function()
        if ring1 and ring1.Parent then pcall(function() ring1:Destroy() end) end
        if flash and flash.Parent then pcall(function() flash:Destroy() end) end
    end)
    task.delay(3.5, function()
        if lightPart and lightPart.Parent then pcall(function() lightPart:Destroy() end) end
    end)
    task.delay(5.5, function()
        if crater and crater.Parent then pcall(function() crater:Destroy() end) end
    end)
    task.delay(9, function()
        if emitterPart and emitterPart.Parent then pcall(function() emitterPart:Destroy() end) end
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
    meteor.Parent        = getMeteorFolder()

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

    -- Créer le folder avant tout raycast, puis invalider le cache pour
    -- que getRayParams() l'inclue dans la liste d'exclusion
    getMeteorFolder()
    _rayParams = nil

    assombrirCiel()
    appliquerMateriauMap()
    task.delay(1, appliquerChampignons)

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

    -- Nettoyer le folder et invalider le cache raycast
    if _meteorFolder and _meteorFolder.Parent then
        pcall(function() _meteorFolder:Destroy() end)
    end
    _meteorFolder = nil
    _rayParams    = nil

    restaurerMateriauMap()
    restaurerChampignons()
    restaurerCiel()

end

return EventMeteorDrop
