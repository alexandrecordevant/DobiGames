-- ReplicatedStorage/SharedLib/BRFilterSystem/Filters/Scale/Normal.lua
-- Filtre Scale — 1.0× (taille standard, appliqué par défaut sur spawn)

local Normal = {}

Normal.Config = {
    Echelle = 1.0,
}

function Normal.Apply(brModel, params)
    local echelle = (params and params.Echelle) or Normal.Config.Echelle

    if brModel:IsA("Model") then
        pcall(function() brModel:ScaleTo(echelle) end)
    elseif brModel:IsA("BasePart") then
        -- BasePart : rien à faire pour 1.0× (taille originale)
    end
end

return Normal
