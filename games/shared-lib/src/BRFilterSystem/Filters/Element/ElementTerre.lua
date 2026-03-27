-- ReplicatedStorage/SharedLib/BRFilterSystem/Filters/Element/ElementTerre.lua
-- Filtre Élémentaire TERRE — Vert/marron + particules fumée + lueur verte

local ElementTerre = {}

ElementTerre.Config = {
    Couleur         = Color3.fromRGB(100, 150, 50),
    CouleurParticle = ColorSequence.new(Color3.fromRGB(150, 200, 100)),
    TextureParticle = "rbxasset://textures/particles/smoke_main.dds",
    CouleurLight    = Color3.fromRGB(100, 200, 80),
    Nom             = "TERRE",
}

function ElementTerre.Apply(brModel, params)
    local cfg = ElementTerre.Config

    for _, part in ipairs(brModel:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function() part.Color = cfg.Couleur end)
        end
    end

    local primaryPart = brModel.PrimaryPart
                     or brModel:FindFirstChildWhichIsA("BasePart")
    if not primaryPart then
        warn("[ElementTerre] PrimaryPart introuvable sur", brModel.Name)
        return
    end

    -- Particules terre (tourbillons)
    pcall(function()
        local emitter = Instance.new("ParticleEmitter")
        emitter.Name           = "ElementParticles"
        emitter.Texture        = cfg.TextureParticle
        emitter.Color          = cfg.CouleurParticle
        emitter.Rate           = 8
        emitter.Lifetime       = NumberRange.new(0.6, 1.5)
        emitter.Speed          = NumberRange.new(1, 3)
        emitter.SpreadAngle    = Vector2.new(40, 40)
        emitter.LightEmission  = 0.4
        emitter.LightInfluence = 0
        emitter.Parent         = primaryPart
    end)

    -- Lueur verte naturelle
    pcall(function()
        local light = Instance.new("PointLight")
        light.Name       = "ElementLight"
        light.Brightness = 3
        light.Range      = 15
        light.Color      = cfg.CouleurLight
        light.Parent     = primaryPart
    end)

    pcall(function()
        brModel:SetAttribute("ElementType", cfg.Nom)
    end)
end

return ElementTerre
