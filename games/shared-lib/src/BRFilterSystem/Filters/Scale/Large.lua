-- ReplicatedStorage/SharedLib/BRFilterSystem/Filters/Scale/Large.lua
-- Filtre Scale — 1.5× (grand, utilisé : ChampCommun MYTHIC/SECRET)

local Large = {}

Large.Config = {
    Echelle = 1.5,
}

function Large.Apply(brModel, params)
    local echelle = (params and params.Echelle) or Large.Config.Echelle

    if brModel:IsA("Model") then
        pcall(function() brModel:ScaleTo(echelle) end)
    elseif brModel:IsA("BasePart") then
        pcall(function() brModel.Size = brModel.Size * echelle end)
    end
end

return Large
