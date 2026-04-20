-- BRFilterSystem/Filters/Mutant/MutantRAINBOW.lua
-- Filtre Mutant RAINBOW — Spectre complet, hue-shift constant (cycle 3s) + trail arc-en-ciel
-- Appliqué via FilterManager.Apply(br, {{Name="MutantRAINBOW"}})
-- Note : lance un task.spawn pour la boucle TweenService — s'arrête automatiquement
--        quand brModel est détruit (vérification .Parent à chaque cycle)

local MutantRAINBOW = {}
local Logger = require(game:GetService("ServerScriptService").SharedLib.Server.Logger)

MutantRAINBOW.Config = {
    Nom   = "RAINBOW",
    Emoji = "🌈",
    -- Séquence de couleurs pour le hue-shift (cycle complet du spectre)
    CouleursCycle = {
        Color3.fromRGB(255, 0,   0),    -- rouge
        Color3.fromRGB(255, 127, 0),    -- orange
        Color3.fromRGB(255, 255, 0),    -- jaune
        Color3.fromRGB(0,   255, 0),    -- vert
        Color3.fromRGB(0,   0,   255),  -- bleu
        Color3.fromRGB(148, 0,   211),  -- violet
    },
    -- Durée totale du cycle (secondes)
    DureeCycle = 3,
}


function MutantRAINBOW.Apply(brModel, params)
    local cfg = MutantRAINBOW.Config

    local primaryPart = brModel.PrimaryPart
                     or brModel:FindFirstChildWhichIsA("BasePart")
    if not primaryPart then
        Logger.warn("Filter", "PrimaryPart introuvable sur %s", brModel.Name)
        return
    end

    -- Highlight initial (rouge — sera hue-shifté par la boucle TweenService)
    local highlight = nil
    pcall(function()
        local h = Instance.new("Highlight")
        h.Name                = "ElementHighlight"
        h.OutlineColor        = Color3.fromRGB(255, 0, 0)
        h.FillColor           = Color3.fromRGB(255, 0, 0)
        h.FillTransparency    = 0.45
        h.OutlineTransparency = 0.0
        h.Parent              = brModel
        highlight             = h
    end)

    -- Particules arc-en-ciel (couleurs spectre complet)
    pcall(function()
        local emitter = Instance.new("ParticleEmitter")
        emitter.Name              = "ElementParticles"
        emitter.Texture           = "rbxasset://textures/particles/sparkles_main.dds"
        emitter.EmissionDirection = Enum.NormalId.Top
        emitter.Color             = ColorSequence.new({
            ColorSequenceKeypoint.new(0,    Color3.fromRGB(255, 0,   0)),
            ColorSequenceKeypoint.new(0.25, Color3.fromRGB(0,   255, 0)),
            ColorSequenceKeypoint.new(0.5,  Color3.fromRGB(0,   0,   255)),
            ColorSequenceKeypoint.new(0.75, Color3.fromRGB(255, 255, 0)),
            ColorSequenceKeypoint.new(1,    Color3.fromRGB(255, 0,   255)),
        })
        emitter.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0,   0.4),
            NumberSequenceKeypoint.new(0.5, 0.25),
            NumberSequenceKeypoint.new(1,   0),
        })
        emitter.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0,   0.0),
            NumberSequenceKeypoint.new(0.6, 0.5),
            NumberSequenceKeypoint.new(1,   1),
        })
        emitter.Rate           = 250
        emitter.Lifetime       = NumberRange.new(0.8, 1.8)
        emitter.Speed          = NumberRange.new(4, 10)
        emitter.SpreadAngle    = Vector2.new(45, 45)
        emitter.RotSpeed       = NumberRange.new(-180, 180)
        emitter.LightEmission  = 0.9
        emitter.LightInfluence = 0.1
        emitter.Parent         = primaryPart
    end)

    -- Trail arc-en-ciel
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
        trail.Attachment0   = a0
        trail.Attachment1   = a1
        trail.Color         = ColorSequence.new({
            ColorSequenceKeypoint.new(0,    Color3.fromRGB(255, 0,   0)),
            ColorSequenceKeypoint.new(0.2,  Color3.fromRGB(255, 127, 0)),
            ColorSequenceKeypoint.new(0.4,  Color3.fromRGB(255, 255, 0)),
            ColorSequenceKeypoint.new(0.6,  Color3.fromRGB(0,   255, 0)),
            ColorSequenceKeypoint.new(0.8,  Color3.fromRGB(0,   0,   255)),
            ColorSequenceKeypoint.new(1,    Color3.fromRGB(148, 0,   211)),
        })
        trail.Transparency  = NumberSequence.new({
            NumberSequenceKeypoint.new(0,   0.0),
            NumberSequenceKeypoint.new(1,   1.0),
        })
        trail.Lifetime      = 0.5
        trail.MinLength     = 0.05
        trail.LightEmission = 0.8
        trail.Parent        = primaryPart
    end)

    pcall(function() brModel:SetAttribute("MutantType", cfg.Nom) end)
end

return MutantRAINBOW
