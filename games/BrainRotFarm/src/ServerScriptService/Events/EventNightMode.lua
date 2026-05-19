-- ServerScriptService/Common/Events/EventNightMode.lua
-- BrainRotFarm — Event Night Mode
-- Obscurité soudaine, ciel étoilé, son ambiant, BR EPIC+ brillent dans le noir
--
-- Changelog :
--   Added: savedAtmosphere snapshot (Density, Color, Decay, Glare, Haze)
--   Added: ColorShift_Top/Bottom dans la sauvegarde et la restauration
--   Added: restauration Atmosphere avec fallback Brainrot (rose/violet)
--   Added: transition Atmosphere vers ambiance nuit au demarrage de l'event
--   Modified: fallbacks restaurerLighting maintenant Brainrot (rose/violet) et ClockTime 17

local EventNightMode = {}
EventNightMode.NOM          = "NightMode"
EventNightMode.DUREE_DEFAUT = 90

-- ============================================================
-- Services
-- ============================================================
local TweenService      = game:GetService("TweenService")
local Lighting          = game:GetService("Lighting")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

-- ============================================================
-- Dépendances shared-lib
-- ============================================================
local SharedLib      = game:GetService("ServerScriptService").SharedLib.Server
local Logger         = require(SharedLib.Logger)
local NightSkySystem = require(SharedLib.NightSkySystem)
local Config         = require(ReplicatedStorage:WaitForChild("GameConfig"))

local _DropSystem = nil
local function getDropSystem()
    if not _DropSystem then
        local ok, m = pcall(require, SharedLib.DropSystem)
        if ok and m then _DropSystem = m end
    end
    return _DropSystem
end

-- ============================================================
-- Ordre de rareté (EPIC = 4)
-- ============================================================
local RARETE_ORDRE = {
    COMMON=1, OG=2, RARE=3, EPIC=4,
    LEGENDARY=5, MYTHIC=6, SECRET=7, GOD=8,
}

-- ============================================================
-- État interne (réinitialisé à chaque Demarrer)
-- ============================================================
local savedLighting    = {}   -- snapshot complet du Lighting
local savedAtmosphere  = nil  -- snapshot des proprietes Atmosphere
local savedStarCount   = nil
local skyCreated       = false
local pulseTasks       = {}
local savedLights      = {}
local createdLights    = {}
local materiauOriginel = {}   -- { [BasePart] = Enum.Material } pour restauration Map
local savedChampignons          = {}   -- { [BasePart] = { color, material } }
local savedChampignonLights     = {}   -- { PointLight, ... } créés par appliquerChampignons
local champignonLightsOriginals = {}   -- { [light] = { brightness, range } } pour restauration
local nightGlowLights           = {}   -- { [modeleSlot] = PointLight } NightGlow sur BR slottés
local nightModeActif            = false
local _ancienOnBRDepose         = nil
local savedLucioles             = {}   -- { Part, ... } anchors lucioles
local _descendantAddedConn      = nil  -- connexion Workspace.DescendantAdded pour BR glow continu

-- ============================================================
-- Utilitaires
-- ============================================================
local function notifierTous(message)
    local ev = ReplicatedStorage:FindFirstChild("NotifEvent")
    if ev then pcall(function() ev:FireAllClients("INFO", message) end) end
end

-- ============================================================
-- Sauvegarde / restauration Lighting (snapshot complet)
-- ============================================================
local function sauvegarderLighting()
    savedLighting = {
        Brightness               = Lighting.Brightness,
        Ambient                  = Lighting.Ambient,
        OutdoorAmbient           = Lighting.OutdoorAmbient,
        FogEnd                   = Lighting.FogEnd,
        FogStart                 = Lighting.FogStart,
        FogColor                 = Lighting.FogColor,
        ClockTime                = Lighting.ClockTime,
        EnvironmentDiffuseScale  = Lighting.EnvironmentDiffuseScale,
        EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
        ColorShift_Top           = Lighting.ColorShift_Top,
        ColorShift_Bottom        = Lighting.ColorShift_Bottom,
    }

    -- Sauvegarder l'Atmosphere
    local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
    if atmo then
        savedAtmosphere = {
            Density = atmo.Density,
            Color   = atmo.Color,
            Decay   = atmo.Decay,
            Glare   = atmo.Glare,
            Haze    = atmo.Haze,
        }
    else
        savedAtmosphere = nil
    end

    local sky = Lighting:FindFirstChildOfClass("Sky")
    if sky then
        savedStarCount = sky.StarCount
        skyCreated     = false
    else
        savedStarCount = nil
        skyCreated     = false
    end
end

local function restaurerLighting()
    local ok, err = pcall(function()
        -- ClockTime ne se tween pas : set direct avec fallback Brainrot (coucher soleil)
        Lighting.ClockTime = savedLighting.ClockTime or 17

        local info = TweenInfo.new(5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        TweenService:Create(Lighting, info, {
            Brightness               = savedLighting.Brightness               or 2,
            Ambient                  = savedLighting.Ambient                  or Color3.fromRGB(180, 100, 255),
            OutdoorAmbient           = savedLighting.OutdoorAmbient           or Color3.fromRGB(255, 150, 200),
            FogEnd                   = savedLighting.FogEnd                   or 100000,
            FogStart                 = savedLighting.FogStart                 or 0,
            FogColor                 = savedLighting.FogColor                 or Color3.fromRGB(191, 191, 191),
            EnvironmentDiffuseScale  = savedLighting.EnvironmentDiffuseScale  or 1,
            EnvironmentSpecularScale = savedLighting.EnvironmentSpecularScale or 1,
            ColorShift_Top           = savedLighting.ColorShift_Top           or Color3.fromRGB(255, 100, 200),
            ColorShift_Bottom        = savedLighting.ColorShift_Bottom        or Color3.fromRGB(150, 50, 255),
        }):Play()

        -- Restaurer l'Atmosphere
        local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
        if atmo and savedAtmosphere then
            local infoAtmo = TweenInfo.new(5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            TweenService:Create(atmo, infoAtmo, {
                Density = savedAtmosphere.Density,
                Color   = savedAtmosphere.Color,
                Decay   = savedAtmosphere.Decay,
                Glare   = savedAtmosphere.Glare,
                Haze    = savedAtmosphere.Haze,
            }):Play()
        elseif atmo then
            -- Pas de snapshot : forcer valeurs Brainrot (rose/violet)
            local infoAtmo = TweenInfo.new(5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            TweenService:Create(atmo, infoAtmo, {
                Density = 0.45,
                Color   = Color3.fromRGB(255, 150, 200),
                Decay   = Color3.fromRGB(180, 100, 255),
                Glare   = 0.8,
                Haze    = 2,
            }):Play()
        end
    end)
    if not ok then
        Logger.warn("Sky", "restaurerLighting : erreur %s", tostring(err))
    end
end

-- ============================================================
-- Ciel étoilé
-- ============================================================
local function activerEtoiles(starCount)
    local sky = Lighting:FindFirstChildOfClass("Sky")
    if not sky then
        sky        = Instance.new("Sky")
        sky.Parent = Lighting
        skyCreated = true
    end
    sky.StarCount = starCount or 3000
end

local function restaurerEtoiles()
    local sky = Lighting:FindFirstChildOfClass("Sky")
    if not sky then return end
    if skyCreated then
        pcall(function() sky:Destroy() end)
        skyCreated = false
    else
        sky.StarCount = savedStarCount or 0
    end
end

-- ============================================================
-- Matériau Map : Limestone pendant NightMode
-- ============================================================
local function appliquerMateriauMap()
    materiauOriginel = {}
    local map = Workspace:FindFirstChild("Map")
    if not map then return end
    for _, obj in ipairs(map:GetDescendants()) do
        if obj:IsA("BasePart") then
            materiauOriginel[obj] = { Material = obj.Material, Color = obj.Color }
            obj.Material = Enum.Material.Basalt
            obj.Color    = Color3.fromRGB(30, 30, 35)
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
-- Champignons-lampes
-- ============================================================
local function appliquerChampignons()
    savedChampignons      = {}
    savedChampignonLights = {}

    -- Étape 1 : trouver les modèles champignons
    local modeles = {}

    -- Diagnostic : dump des enfants de Deco pour identifier la structure réelle
    local deco = Workspace:FindFirstChild("Deco")
    if deco then
        Logger.warn("Event", "Deco trouvé (%s), %d enfants :", deco.ClassName, #deco:GetChildren())
        for _, ch in ipairs(deco:GetChildren()) do
            Logger.warn("Event", "  Deco > %s (%s)", ch.Name, ch.ClassName)
        end
    else
        Logger.warn("Event", "DECO INTROUVABLE dans Workspace")
    end

    -- Stratégie 1 : dossier/modèle nommé "Champignons" (insensible à la casse)
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj.Name:lower() == "champignons" then
            Logger.warn("Event", "Dossier Champignons trouvé : %s", obj:GetFullName())
            for _, child in ipairs(obj:GetChildren()) do
                table.insert(modeles, child)
            end
            break
        end
    end

    -- Stratégie 2 : modèles dont le nom commence par "champignon" (insensible à la casse)
    if #modeles == 0 then
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if (obj:IsA("Model") or obj:IsA("BasePart")) and obj.Name:lower():match("^champignon") then
                table.insert(modeles, obj)
            end
        end
    end

    -- Stratégie 3 (nucléaire) : BaseParts sous Deco avec la couleur rouge caractéristique (196,40,28 ±15)
    if #modeles == 0 and deco then
        Logger.warn("Event", "Fallback couleur : scan des parts rouges sous Deco")
        local dejaVus = {}
        for _, part in ipairs(deco:GetDescendants()) do
            if part:IsA("BasePart") then
                local r, g, b = part.Color.R * 255, part.Color.G * 255, part.Color.B * 255
                if math.abs(r - 196) < 15 and math.abs(g - 40) < 15 and math.abs(b - 28) < 15 then
                    -- Part rouge champignon → remonter au Model parent
                    local parentModel = part.Parent
                    while parentModel and not parentModel:IsA("Model") do
                        parentModel = parentModel.Parent
                    end
                    if parentModel and parentModel ~= Workspace and not dejaVus[parentModel] then
                        dejaVus[parentModel] = true
                        table.insert(modeles, parentModel)
                    end
                end
            end
        end
    end

    -- Diagnostic : compter les BaseParts visibles dans le premier modèle
    if #modeles > 0 then
        local m0 = modeles[1]
        local partCount = 0
        for _, d in ipairs(m0:GetDescendants()) do
            if d:IsA("BasePart") then partCount += 1 end
        end
        Logger.warn("Event", "1er modèle '%s' (%s) → %d BaseParts côté serveur", m0.Name, m0.ClassName, partCount)
    end
    Logger.warn("Event", "NightMode champignons : %d modèles à colorier", #modeles)

    -- Étape 2 : colorier et ajouter les lights
    for _, model in ipairs(modeles) do
        local rootPart = trouverRootPart(model)
        if rootPart then
            local point = Instance.new("PointLight")
            point.Brightness = 2
            point.Range      = 18
            point.Color      = Color3.fromRGB(255, 200, 120)
            point.Parent     = rootPart
            table.insert(savedChampignonLights, point)
            local spot = Instance.new("SpotLight")
            spot.Brightness = 3
            spot.Range      = 14
            spot.Angle      = 60
            spot.Color      = Color3.fromRGB(255, 180, 80)
            spot.Face       = Enum.NormalId.Bottom
            spot.Shadows    = false
            spot.Parent     = rootPart
            table.insert(savedChampignonLights, spot)
        end
        for _, part in ipairs(model:GetDescendants()) do
            if part:IsA("BasePart") then
                savedChampignons[part] = { color = part.Color, material = part.Material }
                part.Material = Enum.Material.Neon
                part.Color    = Color3.fromRGB(255, 230, 160)
            end
        end
        if model:IsA("BasePart") then
            savedChampignons[model] = { color = model.Color, material = model.Material }
            model.Material = Enum.Material.Neon
            model.Color    = Color3.fromRGB(255, 230, 160)
        end
    end
end

local function restaurerChampignons()
    for _, light in ipairs(savedChampignonLights) do
        if light and light.Parent then
            pcall(function() light:Destroy() end)
        end
    end
    savedChampignonLights = {}
    for part, saved in pairs(savedChampignons) do
        if part and part.Parent then
            pcall(function()
                part.Material = saved.material
                part.Color    = saved.color
            end)
        end
    end
    savedChampignons = {}
end

-- ============================================================
-- Couleur de rareté (lookup depuis GameConfig.Brainrots)
-- ============================================================
local _couleurParRarete = nil
local COULEUR_FALLBACK = {  -- rarités absentes de GameConfig.Brainrots
    GOD      = Color3.fromRGB(255, 255, 100),
    OG       = Color3.fromRGB(200, 200, 200),
    UNCOMMON = Color3.fromRGB(100, 200, 100),
}
local function getCouleurRarete(rarete)
    if not _couleurParRarete then
        _couleurParRarete = {}
        if Config.Brainrots then
            for _, r in ipairs(Config.Brainrots) do
                _couleurParRarete[r.nom:upper()] = r.couleur
            end
        end
    end
    local key = rarete and tostring(rarete):upper() or ""
    return _couleurParRarete[key] or COULEUR_FALLBACK[key] or Color3.fromRGB(200, 200, 200)
end

-- Trouve la première BasePart visible d'un modèle (PrimaryPart → descendants)
local function trouverRootPart(modele)
    if modele:IsA("BasePart") then return modele end
    if not modele:IsA("Model") then return nil end
    if modele.PrimaryPart then return modele.PrimaryPart end
    for _, v in ipairs(modele:GetDescendants()) do
        if v:IsA("BasePart") and v.Transparency < 0.9 then
            return v
        end
    end
    return nil
end

-- ============================================================
-- Atténuation des lumières des champignons (trop lumineuses)
-- Appelé APRÈS appliquerChampignons pour capturer les PointLights créés
-- ============================================================
local function attenuerChampignonLights()
    champignonLightsOriginals = {}
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if not (obj:IsA("PointLight") or obj:IsA("SurfaceLight") or obj:IsA("SpotLight")) then continue end
        -- N'atténuer que les lights sous un modèle nommé Champignon (Studio-placed)
        local parent = obj.Parent
        local inChampignon = false
        while parent and parent ~= Workspace do
            if parent:IsA("Model") and parent.Name:match("^[Cc]hampignon") then
                inChampignon = true break
            end
            parent = parent.Parent
        end
        if not inChampignon then continue end
        champignonLightsOriginals[obj] = { brightness = obj.Brightness, range = obj.Range }
        pcall(function()
            obj.Brightness = obj.Brightness * 0.35
            obj.Range      = math.min(obj.Range, 12)
        end)
    end
end

local function restaurerChampignonLights()
    for light, saved in pairs(champignonLightsOriginals) do
        if light and light.Parent then
            pcall(function()
                light.Brightness = saved.brightness
                light.Range      = saved.range
            end)
        end
    end
    champignonLightsOriginals = {}
end

-- ============================================================
-- Pulsation des PointLights des BR EPIC+
-- (définie avant appliquerNightGlowBR pour être dans sa closure)
-- ============================================================
local function lancerPulsation(light, brightnessBase)
    local thread = task.spawn(function()
        local infoHaut = TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
        local infoBas  = TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
        while light and light.Parent do
            pcall(function()
                TweenService:Create(light, infoHaut, { Brightness = brightnessBase * 3 }):Play()
            end)
            task.wait(0.9)
            if not (light and light.Parent) then break end
            pcall(function()
                TweenService:Create(light, infoBas, { Brightness = brightnessBase * 1.2 }):Play()
            end)
            task.wait(0.9)
        end
    end)
    return thread
end

-- ============================================================
-- NightGlow : éclairage doux sur les BR déposés dans les slots
-- ============================================================
-- Glow par rareté : tous les BRs (champ + slots), avec pulsation pour EPIC+
local RARETE_LIGHT = {
    COMMON    = { brightness = 1.2, range = 8,  pulse = false },
    UNCOMMON  = { brightness = 1.4, range = 9,  pulse = false },
    OG        = { brightness = 1.4, range = 9,  pulse = false },
    RARE      = { brightness = 1.8, range = 12, pulse = false },
    EPIC      = { brightness = 2.5, range = 16, pulse = true  },
    LEGENDARY = { brightness = 4,   range = 24, pulse = true  },
    MYTHIC    = { brightness = 6,   range = 32, pulse = true  },
    SECRET    = { brightness = 8,   range = 38, pulse = true  },
    GOD       = { brightness = 10,  range = 45, pulse = true  },
}

-- Applique NightGlow sur un modèle BR (slot ou champ)
local function appliquerNightGlowBR(modele, rarete)
    if not modele or not modele.Parent then return end
    local root = trouverRootPart(modele)
    if not root then return end
    if root:FindFirstChild("NightGlow") then return end  -- déjà appliqué

    local key   = rarete and tostring(rarete):upper() or "COMMON"
    local cfg   = RARETE_LIGHT[key] or RARETE_LIGHT["COMMON"]
    local light = Instance.new("PointLight")
    light.Name       = "NightGlow"
    light.Brightness = cfg.brightness
    light.Range      = cfg.range
    light.Color      = getCouleurRarete(rarete)
    light.Shadows    = false
    light.Parent     = root
    table.insert(createdLights, light)
    nightGlowLights[modele] = light
    if cfg.pulse then
        table.insert(pulseTasks, lancerPulsation(light, cfg.brightness))
    end
end

-- Scan workspace entier par attribut Rarete (couvre BR champ CC_* et BR slottés)
local function eclairerTousBR()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") then
            local rareteNom = obj:GetAttribute("Rarete")
            if rareteNom then
                appliquerNightGlowBR(obj, rareteNom)
            end
        end
    end
end

-- Active l'écoute de nouveaux BRs spawnnés pendant NightMode (champ continu)
local function activerEcouteBR()
    if _descendantAddedConn then _descendantAddedConn:Disconnect() end
    _descendantAddedConn = Workspace.DescendantAdded:Connect(function(obj)
        if not nightModeActif then return end
        if not obj:IsA("Model") then return end
        -- Attendre que les attributs soient propagés par le serveur
        task.delay(0.3, function()
            if not nightModeActif then return end
            if not obj or not obj.Parent then return end
            local rareteNom = obj:GetAttribute("Rarete")
            if rareteNom then
                appliquerNightGlowBR(obj, rareteNom)
            end
        end)
    end)
end

local function desactiverEcouteBR()
    if _descendantAddedConn then
        _descendantAddedConn:Disconnect()
        _descendantAddedConn = nil
    end
end

local function stopperPulsations()
    for _, thread in ipairs(pulseTasks) do pcall(task.cancel, thread) end
    pulseTasks = {}
    for _, entry in ipairs(savedLights) do
        if entry.light and entry.light.Parent then
            pcall(function() entry.light.Brightness = entry.brightness end)
        end
    end
    savedLights = {}
    for _, light in ipairs(createdLights) do
        if light and light.Parent then pcall(function() light:Destroy() end) end
    end
    createdLights = {}
end

-- ============================================================
-- Lucioles : particules lumineuses flottantes pendant NightMode
-- ============================================================
local function appliquerLucioles()
    savedLucioles = {}
    local map = Workspace:FindFirstChild("Map")
    if not map then return end

    -- Calculer les bounds du sol de la map
    local xMin, xMax, zMin, zMax, yGround = 0, 0, 0, 0, 4
    local n = 0
    for _, p in ipairs(map:GetDescendants()) do
        if p:IsA("BasePart") and p.Size.Y < 3 then
            xMin = math.min(xMin, p.Position.X - p.Size.X * 0.5)
            xMax = math.max(xMax, p.Position.X + p.Size.X * 0.5)
            zMin = math.min(zMin, p.Position.Z - p.Size.Z * 0.5)
            zMax = math.max(zMax, p.Position.Z + p.Size.Z * 0.5)
            yGround = math.max(yGround, p.Position.Y + p.Size.Y * 0.5)
            n += 1
        end
    end
    if n == 0 then return end

    -- 28 sources de lucioles en grille légèrement aléatoire
    local cols, rows = 7, 4
    for i = 0, cols - 1 do
        for j = 0, rows - 1 do
            local x = xMin + (xMax - xMin) * (i + 0.5 + (math.random() - 0.5) * 0.6) / cols
            local z = zMin + (zMax - zMin) * (j + 0.5 + (math.random() - 0.5) * 0.6) / rows
            local y = yGround + math.random() * 3 + 1.5

            local anchor = Instance.new("Part")
            anchor.Name        = "FireflyAnchor"
            anchor.Size        = Vector3.new(0.2, 0.2, 0.2)
            anchor.Transparency = 1
            anchor.Anchored    = true
            anchor.CanCollide  = false
            anchor.CastShadow  = false
            anchor.Position    = Vector3.new(x, y, z)

            local emitter = Instance.new("ParticleEmitter")
            emitter.Texture        = "rbxassetid://1266311066"  -- sparkle
            emitter.LightEmission  = 1
            emitter.LightInfluence = 0
            emitter.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0,   Color3.fromRGB(255, 240, 120)),
                ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200, 255, 150)),
                ColorSequenceKeypoint.new(1,   Color3.fromRGB(255, 220, 80)),
            })
            emitter.Size = NumberSequence.new({
                NumberSequenceKeypoint.new(0,   0),
                NumberSequenceKeypoint.new(0.5, 0.12),
                NumberSequenceKeypoint.new(1,   0),
            })
            emitter.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0,   1),
                NumberSequenceKeypoint.new(0.3, 0),
                NumberSequenceKeypoint.new(0.7, 0),
                NumberSequenceKeypoint.new(1,   1),
            })
            emitter.Rate        = 1.5
            emitter.Lifetime    = NumberRange.new(3, 5)
            emitter.Speed       = NumberRange.new(0.3, 1.2)
            emitter.SpreadAngle = Vector2.new(180, 180)
            emitter.RotSpeed    = NumberRange.new(-20, 20)
            emitter.Rotation    = NumberRange.new(0, 360)
            emitter.Parent      = anchor

            local light = Instance.new("PointLight")
            light.Brightness = 0.4
            light.Range      = 6
            light.Color      = Color3.fromRGB(255, 230, 100)
            light.Parent     = anchor

            anchor.Parent = Workspace
            table.insert(savedLucioles, anchor)
        end
    end
    Logger.debug("Event", "Lucioles : %d sources créées", #savedLucioles)
end

local function nettoyerLucioles()
    for _, anchor in ipairs(savedLucioles) do
        if anchor and anchor.Parent then
            pcall(function() anchor:Destroy() end)
        end
    end
    savedLucioles = {}
end

-- ============================================================
-- Callback sync joueur rejoignant en cours d'event
-- ============================================================
local function syncNouveauJoueur(player, dureeRestante)
    local re = ReplicatedStorage:FindFirstChild("NightModeStart")
    if re then
        pcall(function() re:FireClient(player, dureeRestante) end)
    end
end

-- ============================================================
-- API
-- ============================================================

function EventNightMode.Demarrer(config)
    -- Sauvegarder l'état complet du Lighting
    sauvegarderLighting()

    -- Transition Lighting vers la nuit (3s)
    local infoNuit = TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    pcall(function()
        Lighting.ClockTime = config.clockTimeNuit or 0  -- minuit immediat
        TweenService:Create(Lighting, infoNuit, {
            Brightness               = config.brightnessMin       or 0.25,
            Ambient                  = config.ambientNuit         or Color3.fromRGB(40, 40, 80),
            OutdoorAmbient           = config.outdoorAmbientNuit  or Color3.fromRGB(20, 20, 60),
            FogEnd                   = config.fogEndNuit          or 500,
            FogStart                 = config.fogStartNuit        or 120,
            FogColor                 = config.fogColorNuit        or Color3.fromRGB(10, 10, 30),
            EnvironmentDiffuseScale  = config.envDiffuseNuit      or 0.2,
            EnvironmentSpecularScale = config.envSpecNuit         or 0.2,
            ColorShift_Top           = Color3.fromRGB(0, 5, 20),
            ColorShift_Bottom        = Color3.fromRGB(0, 0, 15),
        }):Play()
    end)

    -- Atmosphere : transition vers ambiance nuit (sombre, brume bleue)
    local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
    if atmo then
        local infoAtmoNuit = TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        pcall(function()
            TweenService:Create(atmo, infoAtmoNuit, {
                Density = config.atmoDensiteNuit or 0.2,
                Color   = config.atmoColorNuit   or Color3.fromRGB(20, 20, 50),
                Decay   = config.atmoDecayNuit   or Color3.fromRGB(0, 0, 30),
                Glare   = config.atmoGlareNuit   or 0,
                Haze    = config.atmoHazeNuit    or 0.3,
            }):Play()
        end)
    end

    -- Notifier joueurs + EventStarted
    notifierTous(config.message)
    local es = ReplicatedStorage:FindFirstChild("EventStarted")
    if es then pcall(function() es:FireAllClients("NightMode", config.duree) end) end

    -- Flash client + son ambiant (passe la durée pour l'auto-cleanup client)
    local reStart = ReplicatedStorage:FindFirstChild("NightModeStart")
    if reStart then pcall(function() reStart:FireAllClients(config.duree) end) end

    -- Étoiles après la transition (ciel sombre visible)
    task.delay(3, function()
        activerEtoiles(config.starCount)
    end)

    nightModeActif = true

    -- Éclairage BR : scan immédiat + re-scan à 3.5s + écoute continue
    eclairerTousBR()                     -- BRs déjà présents au démarrage
    task.delay(3.5, function()
        if not nightModeActif then return end
        eclairerTousBR()                 -- BRs spawnnés pendant la transition
    end)
    activerEcouteBR()                    -- BRs spawnnés pendant tout l'event

    -- Matériau Map + lucioles + champignons
    -- Ordre : attenuerChampignonLights AVANT appliquerChampignons → seules les lights Studio sont atténuées
    appliquerMateriauMap()
    attenuerChampignonLights()
    appliquerChampignons()
    appliquerLucioles()

    -- Hook : BR déposés pendant l'event
    local DS = getDropSystem()
    if DS then
        _ancienOnBRDepose = DS.OnBRDepose
        DS.OnBRDepose = function(player, touchPart, modeleSlot, rarete)
            if nightModeActif then
                appliquerNightGlowBR(modeleSlot, rarete)
            end
            if _ancienOnBRDepose then
                pcall(_ancienOnBRDepose, player, touchPart, modeleSlot, rarete)
            end
        end
    end

    -- NightSkySystem : tracking état + sync joueurs qui rejoignent
    NightSkySystem.Demarrer(config.duree or EventNightMode.DUREE_DEFAUT, syncNouveauJoueur)

end

function EventNightMode.Terminer()
    -- Désactiver le mode et restaurer le hook avant toute autre opération
    nightModeActif = false
    local DS = getDropSystem()
    if DS then
        DS.OnBRDepose = _ancienOnBRDepose
        _ancienOnBRDepose = nil
    end

    desactiverEcouteBR()
    stopperPulsations()          -- détruit createdLights (inclut NightGlow) + annule pulsations
    nettoyerLucioles()
    restaurerEtoiles()
    restaurerMateriauMap()
    restaurerChampignonLights()  -- restaurer brightness des lights Studio avant destruction
    restaurerChampignons()
    restaurerLighting()

    -- Signal fin aux clients (arrêt son + cleanup)
    local reEnd = ReplicatedStorage:FindFirstChild("NightModeSkyEnd")
    if reEnd then pcall(function() reEnd:FireAllClients() end) end

    -- Terminer le tracking NightSkySystem
    NightSkySystem.Terminer(nil)

end

return EventNightMode
