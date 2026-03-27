-- ReplicatedStorage/SharedLib/BRFilterSystem/Filters/State/Deposited.lua
-- Filtre État DEPOSITED — BR déposé sur un slot de base
-- Désactive le ProximityPrompt de pickup, réduit la taille

local Deposited = {}

function Deposited.Apply(brModel, params)
    params = params or {}

    local primaryPart = brModel.PrimaryPart
                     or brModel:FindFirstChildWhichIsA("BasePart")

    -- Désactiver/supprimer le ProximityPrompt de pickup
    if primaryPart then
        local prompt = primaryPart:FindFirstChild("PickupPrompt")
        if prompt then
            pcall(function() prompt.Enabled = false end)
        end
    end

    -- Ancrer toutes les parts (immobile sur le slot)
    for _, part in ipairs(brModel:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function()
                part.Anchored   = true
                part.CanCollide = false
            end)
        end
    end
    if brModel:IsA("BasePart") then
        pcall(function()
            brModel.Anchored   = true
            brModel.CanCollide = false
        end)
    end

    -- Marquer l'état
    pcall(function()
        brModel:SetAttribute("State", "Deposited")
    end)
end

return Deposited
