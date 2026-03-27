-- ReplicatedStorage/SharedLib/BRFilterSystem/Filters/State/Pickupable.lua
-- Filtre État PICKUPABLE — Rend un BR ramassable via ProximityPrompt
-- Note : la logique de capture réelle est dans CarrySystem (OnBRSpawned hook)
-- Ce filtre crée uniquement le ProximityPrompt

local Pickupable = {}

Pickupable.Config = {
    ActionText   = "Ramasser",
    HoldDuration = 0,
    MaxDistance  = 20,
}

--[[
    @param brModel (Model|BasePart)
    @param params  (table, optionnel)
        ActionText    (string)   — Texte du prompt
        HoldDuration  (number)   — Durée de maintien (0 = instantané)
        MaxDistance   (number)   — Distance maximale d'activation
        OnTriggered   (function) — Callback optionnel (player, brModel)
]]
function Pickupable.Apply(brModel, params)
    params = params or {}

    local primaryPart = brModel.PrimaryPart
                     or brModel:FindFirstChildWhichIsA("BasePart")
    if not primaryPart then
        warn("[Pickupable] PrimaryPart introuvable sur", brModel.Name)
        return
    end

    -- Supprimer prompt existant
    local existingPrompt = primaryPart:FindFirstChild("PickupPrompt")
    if existingPrompt then existingPrompt:Destroy() end

    pcall(function()
        local prompt = Instance.new("ProximityPrompt")
        prompt.Name                  = "PickupPrompt"
        prompt.ActionText            = params.ActionText   or Pickupable.Config.ActionText
        prompt.ObjectText            = brModel.Name
        prompt.HoldDuration          = params.HoldDuration or Pickupable.Config.HoldDuration
        prompt.MaxActivationDistance = params.MaxDistance  or Pickupable.Config.MaxDistance
        prompt.KeyboardKeyCode       = Enum.KeyCode.E
        prompt.RequiresLineOfSight   = false
        prompt.Parent                = primaryPart

        -- Callback optionnel
        if type(params.OnTriggered) == "function" then
            prompt.Triggered:Connect(function(player)
                params.OnTriggered(player, brModel)
            end)
        end
    end)
end

return Pickupable
