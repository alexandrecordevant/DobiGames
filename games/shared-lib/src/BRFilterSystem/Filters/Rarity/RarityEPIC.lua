-- ReplicatedStorage/SharedLib/BRFilterSystem/Filters/Rarity/RarityEPIC.lua
-- Filtre Rareté EPIC — Violet

local RarityEPIC = {}

RarityEPIC.Config = {
    Couleur = Color3.fromRGB(150, 0, 255),
    Nom     = "EPIC",
}

function RarityEPIC.Apply(brModel, params)
    local couleur = (params and params.Couleur) or RarityEPIC.Config.Couleur

    if params and params.AppliquerCouleur then
        for _, part in ipairs(brModel:GetDescendants()) do
            if part:IsA("BasePart") then
                pcall(function() part.Color = couleur end)
            end
        end
    end

    -- Lueur légère pour EPIC
    local primaryPart = brModel.PrimaryPart
                     or brModel:FindFirstChildWhichIsA("BasePart")
    if primaryPart then
        pcall(function()
            local light = Instance.new("PointLight")
            light.Name       = "RarityGlow"
            light.Brightness = 1.5
            light.Range      = 12
            light.Color      = couleur
            light.Parent     = primaryPart
        end)
    end

    pcall(function()
        brModel:SetAttribute("Rarete", RarityEPIC.Config.Nom)
        brModel:SetAttribute("RareteColor",
            couleur.R .. "," .. couleur.G .. "," .. couleur.B)
    end)
end

return RarityEPIC
