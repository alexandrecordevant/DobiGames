-- BRFilterSystem/Filters/Mutant/MutantTOXIC.lua
-- Filtre Mutant TOXIC — Vert acide fluo, aura venimeuse + bulles vertes montantes
-- Appliqué via FilterManager.Apply(br, {{Name="MutantTOXIC"}})

local MutantTOXIC = {}
local Logger = require(game:GetService("ServerScriptService").SharedLib.Server.Logger)

MutantTOXIC.Config = {
    Couleur        = Color3.fromRGB(57,  255, 20),  -- vert acide fluo
    CouleurContour = Color3.fromRGB(0,   200, 0),   -- vert moyen
    Nom            = "TOXIC",
    Emoji          = "☠️",
}


function MutantTOXIC.Apply(brModel, params)
    local cfg = MutantTOXIC.Config

    local primaryPart = brModel.PrimaryPart
                     or brModel:FindFirstChildWhichIsA("BasePart")
    if not primaryPart then
        Logger.warn("Filter", "PrimaryPart introuvable sur %s", brModel.Name)
        return
    end

    -- Highlight vert acide (aura venimeuse)
    pcall(function()
        local h = Instance.new("Highlight")
        h.Name                = "ElementHighlight"
        h.OutlineColor        = cfg.CouleurContour
        h.FillColor           = cfg.Couleur
        h.FillTransparency    = 0.50
        h.OutlineTransparency = 0.0
        h.Parent              = brModel
    end)

    -- Particules bulles montantes (vert acide, LightEmission modéré)
    pcall(function()
        local emitter = Instance.new("ParticleEmitter")
        emitter.Name              = "ElementParticles"
        emitter.Texture           = "rbxasset://textures/particles/smoke_main.dds"
        emitter.EmissionDirection = Enum.NormalId.Top
        emitter.Color             = ColorSequence.new({
            ColorSequenceKeypoint.new(0,   Color3.fromRGB(57,  255,  20)),
            ColorSequenceKeypoint.new(0.4, Color3.fromRGB(0,   200,  0)),
            ColorSequenceKeypoint.new(1,   Color3.fromRGB(0,   100,  0)),
        })
        emitter.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0,   0.3),
            NumberSequenceKeypoint.new(0.5, 0.5),  -- gonfle comme une bulle
            NumberSequenceKeypoint.new(1,   0),
        })
        emitter.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0,   0.4),
            NumberSequenceKeypoint.new(0.6, 0.7),
            NumberSequenceKeypoint.new(1,   1),
        })
        emitter.Rate           = 220
        emitter.Lifetime       = NumberRange.new(1.5, 3.0)  -- bulles lentes
        emitter.Speed          = NumberRange.new(2, 6)      -- montée lente (bulles)
        emitter.SpreadAngle    = Vector2.new(20, 20)
        emitter.RotSpeed       = NumberRange.new(-45, 45)
        emitter.LightEmission  = 0.5                        -- lueur toxique
        emitter.LightInfluence = 0.5
        emitter.Parent         = primaryPart
    end)

    -- PointLight vert toxique (aura venimeuse dans l'environnement)
    pcall(function()
        local lumiere = Instance.new("PointLight")
        lumiere.Color      = Color3.fromRGB(57, 255, 20)
        lumiere.Brightness = 2.0
        lumiere.Range      = 10
        lumiere.Parent     = primaryPart
    end)

    pcall(function() brModel:SetAttribute("MutantType", cfg.Nom) end)
end

return MutantTOXIC
