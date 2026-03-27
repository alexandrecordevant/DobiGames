-- ReplicatedStorage/SharedLib/BRFilterSystem/Filters/Element/ElementEau.lua
-- Filtre Élémentaire EAU — Bleu + particules fumée + lueur bleue

local ElementEau = {}

ElementEau.Config = {
    Couleur         = Color3.fromRGB(0, 150, 255),
    CouleurParticle = ColorSequence.new(Color3.fromRGB(100, 200, 255)),
    TextureParticle = "rbxasset://textures/particles/smoke_main.dds",
    CouleurLight    = Color3.fromRGB(0, 180, 255),
    Nom             = "EAU",
}

function ElementEau.Apply(brModel, params)
    local cfg = ElementEau.Config

    -- Teinter toutes les parts en bleu eau
    for _, part in ipairs(brModel:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function() part.Color = cfg.Couleur end)
        end
    end

    local primaryPart = brModel.PrimaryPart
                     or brModel:FindFirstChildWhichIsA("BasePart")
    if not primaryPart then
        warn("[ElementEau] PrimaryPart introuvable sur", brModel.Name)
        return
    end

    -- Particules eau
    pcall(function()
        local emitter = Instance.new("ParticleEmitter")
        emitter.Name           = "ElementParticles"
        emitter.Texture        = cfg.TextureParticle
        emitter.Color          = cfg.CouleurParticle
        emitter.Rate           = 10
        emitter.Lifetime       = NumberRange.new(0.5, 1.2)
        emitter.Speed          = NumberRange.new(2, 4)
        emitter.SpreadAngle    = Vector2.new(30, 30)
        emitter.LightEmission  = 0.6
        emitter.LightInfluence = 0
        emitter.Parent         = primaryPart
    end)

    -- Lueur bleue
    pcall(function()
        local light = Instance.new("PointLight")
        light.Name       = "ElementLight"
        light.Brightness = 4
        light.Range      = 18
        light.Color      = cfg.CouleurLight
        light.Parent     = primaryPart
    end)

    pcall(function()
        brModel:SetAttribute("ElementType", cfg.Nom)
    end)
end

return ElementEau
