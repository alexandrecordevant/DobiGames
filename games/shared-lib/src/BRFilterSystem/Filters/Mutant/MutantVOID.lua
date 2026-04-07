-- BRFilterSystem/Filters/Mutant/MutantVOID.lua
-- Filtre Mutant VOID — Noir absolu + contour rouge sang, particules aspirées vers le centre
-- Appliqué via FilterManager.Apply(br, {{Name="MutantVOID"}})

local MutantVOID = {}
local Logger = require(game:GetService("ServerScriptService").SharedLib.Server.Logger)

MutantVOID.Config = {
    Couleur        = Color3.fromRGB(10,  0,   20),  -- noir absolu (légère teinte violette)
    CouleurContour = Color3.fromRGB(200, 0,   0),   -- rouge sang
    Nom            = "VOID",
    Emoji          = "🕳️",
}

local function ajouterBillboardMutant(primaryPart, emoji)
    pcall(function()
        local ancien = primaryPart:FindFirstChild("MutantBillboard")
        if ancien then ancien:Destroy() end

        local bb = Instance.new("BillboardGui")
        bb.Name        = "MutantBillboard"
        bb.StudsOffset = Vector3.new(0, 6, 0)
        bb.Size        = UDim2.new(0, 80, 0, 80)
        bb.MaxDistance = 100
        bb.AlwaysOnTop = true
        bb.Parent      = primaryPart

        local label = Instance.new("TextLabel")
        label.Size                   = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Text                   = emoji
        label.TextScaled             = true
        label.Font                   = Enum.Font.GothamBold
        label.TextStrokeTransparency = 0.5
        label.TextStrokeColor3       = Color3.new(0, 0, 0)
        label.Parent                 = bb
    end)
end

function MutantVOID.Apply(brModel, params)
    local cfg = MutantVOID.Config

    local primaryPart = brModel.PrimaryPart
                     or brModel:FindFirstChildWhichIsA("BasePart")
    if not primaryPart then
        Logger.warn("Filter", "PrimaryPart introuvable sur %s", brModel.Name)
        return
    end

    -- Highlight noir absolu + contour rouge sang (absorption de la lumière)
    pcall(function()
        local h = Instance.new("Highlight")
        h.Name                = "ElementHighlight"
        h.OutlineColor        = cfg.CouleurContour
        h.FillColor           = cfg.Couleur
        h.FillTransparency    = 0.20   -- très opaque : absorbe la lumière visuelle
        h.OutlineTransparency = 0.0
        h.Parent              = brModel
    end)

    -- Particules aspirées vers le centre (EmissionDirection.Bottom = chute vers l'intérieur)
    -- Vitesse faible + direction vers le bas = effet d'absorption gravitationnelle
    pcall(function()
        local emitter = Instance.new("ParticleEmitter")
        emitter.Name              = "ElementParticles"
        emitter.Texture           = "rbxasset://textures/particles/smoke_main.dds"
        emitter.EmissionDirection = Enum.NormalId.Bottom  -- aspiration vers le bas
        emitter.Color             = ColorSequence.new({
            ColorSequenceKeypoint.new(0,   Color3.fromRGB(200, 0,   0)),   -- rouge sang au départ
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80,  0,   0)),   -- rouge foncé
            ColorSequenceKeypoint.new(1,   Color3.fromRGB(10,  0,   20)),  -- noir absolu
        })
        emitter.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0,   0.5),
            NumberSequenceKeypoint.new(0.4, 0.25),
            NumberSequenceKeypoint.new(1,   0),
        })
        emitter.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0,   0.3),
            NumberSequenceKeypoint.new(0.5, 0.6),
            NumberSequenceKeypoint.new(1,   1),
        })
        emitter.Rate           = 180
        emitter.Lifetime       = NumberRange.new(0.5, 1.2)  -- durée courte : aspiration rapide
        emitter.Speed          = NumberRange.new(1, 4)       -- lent : attirées vers le vide
        emitter.SpreadAngle    = Vector2.new(10, 10)         -- angle étroit : convergent vers le centre
        emitter.RotSpeed       = NumberRange.new(-360, 360)
        emitter.LightEmission  = 0.0                         -- aucune lumière émise : absorption totale
        emitter.LightInfluence = 1.0
        emitter.Parent         = primaryPart
    end)

    -- Deuxième émetteur : distorsion autour du VOID (particules orbitales)
    pcall(function()
        local orbitEmitter = Instance.new("ParticleEmitter")
        orbitEmitter.Name              = "VoidOrbitParticles"
        orbitEmitter.Texture           = "rbxasset://textures/particles/sparkles_main.dds"
        orbitEmitter.EmissionDirection = Enum.NormalId.Top
        orbitEmitter.Color             = ColorSequence.new({
            ColorSequenceKeypoint.new(0,   Color3.fromRGB(200, 0, 0)),
            ColorSequenceKeypoint.new(1,   Color3.fromRGB(10,  0, 20)),
        })
        orbitEmitter.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0,   0.2),
            NumberSequenceKeypoint.new(1,   0),
        })
        orbitEmitter.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0,   0.2),
            NumberSequenceKeypoint.new(1,   1),
        })
        orbitEmitter.Rate           = 60
        orbitEmitter.Lifetime       = NumberRange.new(0.3, 0.8)
        orbitEmitter.Speed          = NumberRange.new(0.5, 2)
        orbitEmitter.SpreadAngle    = Vector2.new(180, 180)  -- orbitent tout autour
        orbitEmitter.LightEmission  = 0.0
        orbitEmitter.LightInfluence = 1.0
        orbitEmitter.Parent         = primaryPart
    end)

    -- Billboard emoji VOID
    ajouterBillboardMutant(primaryPart, cfg.Emoji)

    pcall(function() brModel:SetAttribute("MutantType", cfg.Nom) end)
end

return MutantVOID
