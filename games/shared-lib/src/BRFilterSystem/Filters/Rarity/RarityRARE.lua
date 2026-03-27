-- ReplicatedStorage/SharedLib/BRFilterSystem/Filters/Rarity/RarityRARE.lua
-- Filtre Rareté RARE — Bleu

local RarityRARE = {}

RarityRARE.Config = {
    Couleur = Color3.fromRGB(0, 120, 255),
    Nom     = "RARE",
}

function RarityRARE.Apply(brModel, params)
    local couleur = (params and params.Couleur) or RarityRARE.Config.Couleur

    if params and params.AppliquerCouleur then
        for _, part in ipairs(brModel:GetDescendants()) do
            if part:IsA("BasePart") then
                pcall(function() part.Color = couleur end)
            end
        end
    end

    pcall(function()
        brModel:SetAttribute("Rarete", RarityRARE.Config.Nom)
        brModel:SetAttribute("RareteColor",
            couleur.R .. "," .. couleur.G .. "," .. couleur.B)
    end)
end

return RarityRARE
