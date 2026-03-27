-- ReplicatedStorage/SharedLib/BRFilterSystem/Filters/State/Carried.lua
-- Filtre État CARRIED — BR porté par un joueur
-- Supprime le ProximityPrompt de pickup et le Billboard
-- (le BR est attaché à la tête du joueur via Motor6D dans CarrySystem)

local Carried = {}

function Carried.Apply(brModel, params)
    params = params or {}

    -- Trouver la racine
    local racine = nil
    if brModel:IsA("BasePart") then
        racine = brModel
    elseif brModel.PrimaryPart then
        racine = brModel.PrimaryPart
    else
        racine = brModel:FindFirstChildWhichIsA("BasePart")
    end

    if racine then
        -- Supprimer ProximityPrompt de pickup
        local prompt = racine:FindFirstChild("PickupPrompt")
        if prompt then
            pcall(function() prompt:Destroy() end)
        end

        -- Supprimer Billboard (inutile quand porté)
        local bb = racine:FindFirstChild("BRBillboard")
        if bb then
            pcall(function() bb:Destroy() end)
        end
    end

    -- Désactiver collision sur toutes les parts
    for _, part in ipairs(brModel:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function()
                part.CanCollide = false
                part.Anchored   = false  -- doit pouvoir suivre le joueur via Motor6D
            end)
        end
    end
    if brModel:IsA("BasePart") then
        pcall(function()
            brModel.CanCollide = false
            brModel.Anchored   = false
        end)
    end

    -- Marquer l'état
    pcall(function()
        brModel:SetAttribute("State", "Carried")
    end)
end

return Carried
