-- ReplicatedStorage/SharedLib/BRFilterSystem/Filters/Rarity/RarityLEGENDARY.lua
-- Filtre Rareté LEGENDARY — Orange doré + lueur + sparkles

local RarityLEGENDARY = {}

RarityLEGENDARY.Config = {
    Couleur = Color3.fromRGB(255, 200, 0),
    Nom     = "LEGENDARY",
}

function RarityLEGENDARY.Apply(brModel, params)
    local couleur = (params and params.Couleur) or RarityLEGENDARY.Config.Couleur

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
        -- Lueur dorée
        pcall(function()
            local light = Instance.new("PointLight")
            light.Name       = "RarityGlow"
            light.Brightness = 2.5
            light.Range      = 18
            light.Color      = couleur
            light.Parent     = primaryPart
        end)

        -- Sparkles légères
        pcall(function()
            local sparkles = Instance.new("Sparkles")
            sparkles.Name          = "RaritySparkles"
            sparkles.SparkleColor  = couleur
            sparkles.Parent        = primaryPart
        end)
    end

    pcall(function()
        brModel:SetAttribute("Rarete", RarityLEGENDARY.Config.Nom)
        brModel:SetAttribute("RareteColor",
            couleur.R .. "," .. couleur.G .. "," .. couleur.B)
    end)
end

return RarityLEGENDARY
