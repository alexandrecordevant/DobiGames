-- ReplicatedStorage/SharedLib/BRFilterSystem/Filters/Rarity/RarityCOMMON.lua
-- Filtre Rareté COMMON — Gris

local RarityCOMMON = {}

RarityCOMMON.Config = {
    Couleur = Color3.fromRGB(200, 200, 200),
    Nom     = "COMMON",
}

function RarityCOMMON.Apply(brModel, params)
    local couleur = (params and params.Couleur) or RarityCOMMON.Config.Couleur

    -- Teinter toutes les parts (utile surtout pour mutants, optionnel pour spawns normaux)
    if params and params.AppliquerCouleur then
        for _, part in ipairs(brModel:GetDescendants()) do
            if part:IsA("BasePart") then
                pcall(function() part.Color = couleur end)
            end
        end
    end

    -- Stocker la rareté comme attribut (référence pour IncomeSystem, etc.)
    pcall(function()
        brModel:SetAttribute("Rarete", RarityCOMMON.Config.Nom)
        brModel:SetAttribute("RareteColor",
            couleur.R .. "," .. couleur.G .. "," .. couleur.B)
    end)
end

return RarityCOMMON
