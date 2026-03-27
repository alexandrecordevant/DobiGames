-- ReplicatedStorage/SharedLib/BRFilterSystem/Filters/Scale/Miniature.lua
-- Filtre Scale — 0.5× (BR miniature, utilisé : Carried, Deposited)

local Miniature = {}

Miniature.Config = {
    Echelle = 0.5,
}

function Miniature.Apply(brModel, params)
    local echelle = (params and params.Echelle) or Miniature.Config.Echelle

    if brModel:IsA("Model") then
        pcall(function() brModel:ScaleTo(echelle) end)
    elseif brModel:IsA("BasePart") then
        pcall(function() brModel.Size = brModel.Size * echelle end)
    end
end

return Miniature
