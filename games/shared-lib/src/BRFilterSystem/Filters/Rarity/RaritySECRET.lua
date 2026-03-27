-- ReplicatedStorage/SharedLib/BRFilterSystem/Filters/Rarity/RaritySECRET.lua
-- Filtre Rareté SECRET — Blanc + flammes rouges + lueur intense

local RaritySECRET = {}

RaritySECRET.Config = {
    Couleur      = Color3.fromRGB(255, 255, 255),
    CouleurFeu   = Color3.fromRGB(255, 30, 30),
    Nom          = "SECRET",
}

function RaritySECRET.Apply(brModel, params)
    local couleur = (params and params.Couleur) or RaritySECRET.Config.Couleur

    if params and params.AppliquerCouleur then
        for _, part in ipairs(brModel:GetDescendants()) do
            if part:IsA("BasePart") then
                pcall(function() part.Color = couleur end)
            end
        end
    end

    local primaryPart = brModel.PrimaryPart
                     or brModel:FindFirstChildWhichIsA("BasePart")
    if primaryPart then
        -- Lueur rouge intense
        pcall(function()
            local light = Instance.new("PointLight")
            light.Name       = "RarityGlow"
            light.Brightness = 5
            light.Range      = 30
            light.Color      = RaritySECRET.Config.CouleurFeu
            light.Parent     = primaryPart
        end)

        -- Flammes rouges
        pcall(function()
            local emitter = Instance.new("ParticleEmitter")
            emitter.Name          = "RarityParticles"
            emitter.Texture       = "rbxasset://textures/particles/fire_main.dds"
            emitter.Color         = ColorSequence.new({
                ColorSequenceKeypoint.new(0,   RaritySECRET.Config.CouleurFeu),
                ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 100, 0)),
                ColorSequenceKeypoint.new(1,   Color3.fromRGB(255, 200, 0)),
            })
            emitter.Rate          = 25
            emitter.Lifetime      = NumberRange.new(0.6, 1.2)
            emitter.Speed         = NumberRange.new(3, 7)
            emitter.SpreadAngle   = Vector2.new(30, 30)
            emitter.LightEmission = 0.9
            emitter.Parent        = primaryPart
        end)

        -- Sparkles blanches
        pcall(function()
            local sparkles = Instance.new("Sparkles")
            sparkles.Name         = "RaritySparkles"
            sparkles.SparkleColor = couleur
            sparkles.Parent       = primaryPart
        end)
    end

    pcall(function()
        brModel:SetAttribute("Rarete", RaritySECRET.Config.Nom)
        brModel:SetAttribute("RareteColor",
            couleur.R .. "," .. couleur.G .. "," .. couleur.B)
    end)
end

return RaritySECRET
