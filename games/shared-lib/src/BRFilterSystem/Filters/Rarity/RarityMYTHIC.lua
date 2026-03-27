-- ReplicatedStorage/SharedLib/BRFilterSystem/Filters/Rarity/RarityMYTHIC.lua
-- Filtre Rareté MYTHIC — Violet foncé + lueur pulsante + particules

local RarityMYTHIC = {}

RarityMYTHIC.Config = {
    Couleur = Color3.fromRGB(148, 0, 211),
    Nom     = "MYTHIC",
}

function RarityMYTHIC.Apply(brModel, params)
    local couleur = (params and params.Couleur) or RarityMYTHIC.Config.Couleur

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
        -- Lueur mystique
        pcall(function()
            local light = Instance.new("PointLight")
            light.Name       = "RarityGlow"
            light.Brightness = 3
            light.Range      = 22
            light.Color      = couleur
            light.Parent     = primaryPart
        end)

        -- Particules mystiques
        pcall(function()
            local emitter = Instance.new("ParticleEmitter")
            emitter.Name          = "RarityParticles"
            emitter.Texture       = "rbxasset://textures/particles/sparkles_main.dds"
            emitter.Color         = ColorSequence.new(couleur)
            emitter.Rate          = 15
            emitter.Lifetime      = NumberRange.new(0.8, 1.5)
            emitter.Speed         = NumberRange.new(2, 5)
            emitter.SpreadAngle   = Vector2.new(45, 45)
            emitter.LightEmission = 0.7
            emitter.Parent        = primaryPart
        end)
    end

    pcall(function()
        brModel:SetAttribute("Rarete", RarityMYTHIC.Config.Nom)
        brModel:SetAttribute("RareteColor",
            couleur.R .. "," .. couleur.G .. "," .. couleur.B)
    end)
end

return RarityMYTHIC
