-- ReplicatedStorage/SharedLib/BRFilterSystem/Filters/Scale/Geant.lua
-- Filtre Scale — 2.5× (géant, utilisé : événements spéciaux, boss BR)

local Geant = {}

Geant.Config = {
    Echelle = 2.5,
}

function Geant.Apply(brModel, params)
    local echelle = (params and params.Echelle) or Geant.Config.Echelle

    if brModel:IsA("Model") then
        pcall(function() brModel:ScaleTo(echelle) end)
    elseif brModel:IsA("BasePart") then
        pcall(function() brModel.Size = brModel.Size * echelle end)
    end
end

return Geant
