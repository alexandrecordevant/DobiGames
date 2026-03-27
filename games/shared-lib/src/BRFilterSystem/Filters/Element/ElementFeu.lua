-- ReplicatedStorage/SharedLib/BRFilterSystem/Filters/Element/ElementFeu.lua
-- Filtre Élémentaire FEU — Rouge/orange + particules feu + lueur chaude

local ElementFeu = {}

ElementFeu.Config = {
    Couleur         = Color3.fromRGB(255, 80, 0),
    CouleurParticle = ColorSequence.new(Color3.fromRGB(255, 150, 0)),
    TextureParticle = "rbxasset://textures/particles/fire_main.dds",
    CouleurLight    = Color3.fromRGB(255, 120, 0),
    Nom             = "FEU",
}

function ElementFeu.Apply(brModel, params)
    local cfg = ElementFeu.Config

    for _, part in ipairs(brModel:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function() part.Color = cfg.Couleur end)
        end
    end

    local primaryPart = brModel.PrimaryPart
                     or brModel:FindFirstChildWhichIsA("BasePart")
    if not primaryPart then
        warn("[ElementFeu] PrimaryPart introuvable sur", brModel.Name)
        return
    end

    -- Particules feu
    pcall(function()
        local emitter = Instance.new("ParticleEmitter")
        emitter.Name           = "ElementParticles"
        emitter.Texture        = cfg.TextureParticle
        emitter.Color          = cfg.CouleurParticle
        emitter.Rate           = 12
        emitter.Lifetime       = NumberRange.new(0.4, 1.0)
        emitter.Speed          = NumberRange.new(3, 6)
        emitter.SpreadAngle    = Vector2.new(25, 25)
        emitter.LightEmission  = 0.8
        emitter.LightInfluence = 0
        emitter.Parent         = primaryPart
    end)

    -- Lueur orange chaude
    pcall(function()
        local light = Instance.new("PointLight")
        light.Name       = "ElementLight"
        light.Brightness = 5
        light.Range      = 20
        light.Color      = cfg.CouleurLight
        light.Parent     = primaryPart
    end)

    pcall(function()
        brModel:SetAttribute("ElementType", cfg.Nom)
    end)
end

return ElementFeu
