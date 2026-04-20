-- BRFilterSystem/Filters/Mutant/MutantGALAXY.lua
-- Filtre Mutant GALAXY — Violet/noir cosmique, particules étoiles + highlight galactique
-- Appliqué via FilterManager.Apply(br, {{Name="MutantGALAXY"}})

local MutantGALAXY = {}
local Logger = require(game:GetService("ServerScriptService").SharedLib.Server.Logger)

MutantGALAXY.Config = {
    Couleur        = Color3.fromRGB(88,  24,  169), -- violet profond
    CouleurContour = Color3.fromRGB(200, 150, 255), -- lilas clair
    Nom            = "GALAXY",
    Emoji          = "🌌",
}


function MutantGALAXY.Apply(brModel, params)
    local cfg = MutantGALAXY.Config

    local primaryPart = brModel.PrimaryPart
                     or brModel:FindFirstChildWhichIsA("BasePart")
    if not primaryPart then
        Logger.warn("Filter", "PrimaryPart introuvable sur %s", brModel.Name)
        return
    end

    -- Highlight violet cosmique (contour brillant, fill semi-transparent)
    pcall(function()
        local h = Instance.new("Highlight")
        h.Name                = "ElementHighlight"
        h.OutlineColor        = cfg.CouleurContour
        h.FillColor           = cfg.Couleur
        h.FillTransparency    = 0.55
        h.OutlineTransparency = 0.0
        h.Parent              = brModel
    end)

    -- Particules étoiles : petites, rapides, durée courte, dispersées
    pcall(function()
        local emitter = Instance.new("ParticleEmitter")
        emitter.Name              = "ElementParticles"
        emitter.Texture           = "rbxasset://textures/particles/sparkles_main.dds"
        emitter.EmissionDirection = Enum.NormalId.Top
        emitter.Color             = ColorSequence.new({
            ColorSequenceKeypoint.new(0,   Color3.fromRGB(220, 180, 255)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(150,  60, 230)),
            ColorSequenceKeypoint.new(1,   Color3.fromRGB(40,    0, 100)),
        })
        emitter.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0,   0.4),
            NumberSequenceKeypoint.new(0.5, 0.2),
            NumberSequenceKeypoint.new(1,   0),
        })
        emitter.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0,   0.0),
            NumberSequenceKeypoint.new(0.6, 0.5),
            NumberSequenceKeypoint.new(1,   1),
        })
        emitter.Rate           = 180
        emitter.Lifetime       = NumberRange.new(0.6, 1.4)  -- durée courte : étoiles filantes
        emitter.Speed          = NumberRange.new(3, 9)
        emitter.SpreadAngle    = Vector2.new(60, 60)
        emitter.RotSpeed       = NumberRange.new(-180, 180)
        emitter.LightEmission  = 0.8                        -- lueur cosmique
        emitter.LightInfluence = 0.2
        emitter.Parent         = primaryPart
    end)

    -- Trail cosmique sur la part principale
    pcall(function()
        local a0 = Instance.new("Attachment")
        a0.Name     = "TrailA0"
        a0.Position = Vector3.new(0,  0.5, 0)
        a0.Parent   = primaryPart

        local a1 = Instance.new("Attachment")
        a1.Name     = "TrailA1"
        a1.Position = Vector3.new(0, -0.5, 0)
        a1.Parent   = primaryPart

        local trail = Instance.new("Trail")
        trail.Attachment0  = a0
        trail.Attachment1  = a1
        trail.Color        = ColorSequence.new({
            ColorSequenceKeypoint.new(0,   Color3.fromRGB(200, 150, 255)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(88,   24, 169)),
            ColorSequenceKeypoint.new(1,   Color3.fromRGB(10,    0,  40)),
        })
        trail.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0,   0.0),
            NumberSequenceKeypoint.new(1,   1.0),
        })
        trail.Lifetime     = 0.4
        trail.MinLength    = 0.05
        trail.LightEmission = 0.6
        trail.Parent       = primaryPart
    end)

    pcall(function() brModel:SetAttribute("MutantType", cfg.Nom) end)
end

return MutantGALAXY
