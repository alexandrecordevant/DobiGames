-- ReplicatedStorage/SharedLib/BRFilterSystem/Filters/Rarity/RarityOG.lua
-- Filtre Rareté OG — Bleu clair

local RarityOG = {}

RarityOG.Config = {
    Couleur = Color3.fromRGB(100, 220, 255),
    Nom     = "OG",
}

function RarityOG.Apply(brModel, params)
    local couleur = (params and params.Couleur) or RarityOG.Config.Couleur

    if params and params.AppliquerCouleur then
        for _, part in ipairs(brModel:GetDescendants()) do
            if part:IsA("BasePart") then
                pcall(function() part.Color = couleur end)
            end
        end
    end

    pcall(function()
        brModel:SetAttribute("Rarete", RarityOG.Config.Nom)
        brModel:SetAttribute("RareteColor",
            couleur.R .. "," .. couleur.G .. "," .. couleur.B)
    end)
end

return RarityOG
