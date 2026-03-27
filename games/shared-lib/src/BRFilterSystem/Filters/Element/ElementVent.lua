-- ReplicatedStorage/SharedLib/BRFilterSystem/Filters/Element/ElementVent.lua
-- Filtre Élémentaire VENT — Blanc/gris clair + sparkles + lueur froide

local ElementVent = {}

ElementVent.Config = {
    Couleur         = Color3.fromRGB(200, 200, 220),
    CouleurParticle = ColorSequence.new(Color3.fromRGB(220, 220, 255)),
    TextureParticle = "rbxasset://textures/particles/sparkles_main.dds",
    CouleurLight    = Color3.fromRGB(200, 220, 255),
    Nom             = "VENT",
}

function ElementVent.Apply(brModel, params)
    local cfg = ElementVent.Config

    for _, part in ipairs(brModel:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function() part.Color = cfg.Couleur end)
        end
    end

    local primaryPart = brModel.PrimaryPart
                     or brModel:FindFirstChildWhichIsA("BasePart")
    if not primaryPart then
        warn("[ElementVent] PrimaryPart introuvable sur", brModel.Name)
        return
    end

    -- Particules vent (sparkles rapides)
    pcall(function()
        local emitter = Instance.new("ParticleEmitter")
        emitter.Name           = "ElementParticles"
        emitter.Texture        = cfg.TextureParticle
        emitter.Color          = cfg.CouleurParticle
        emitter.Rate           = 20
        emitter.Lifetime       = NumberRange.new(0.3, 0.8)
        emitter.Speed          = NumberRange.new(5, 10)
        emitter.SpreadAngle    = Vector2.new(60, 60)
        emitter.LightEmission  = 0.5
        emitter.LightInfluence = 0
        emitter.Parent         = primaryPart
    end)

    -- Lueur froide légère
    pcall(function()
        local light = Instance.new("PointLight")
        light.Name       = "ElementLight"
        light.Brightness = 2
        light.Range      = 14
        light.Color      = cfg.CouleurLight
        light.Parent     = primaryPart
    end)

    pcall(function()
        brModel:SetAttribute("ElementType", cfg.Nom)
    end)
end

return ElementVent
