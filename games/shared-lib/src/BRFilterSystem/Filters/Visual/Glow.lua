-- ReplicatedStorage/SharedLib/BRFilterSystem/Filters/Visual/Glow.lua
-- Filtre Visuel GLOW — Ajoute un PointLight générique sur le BR

local Glow = {}

Glow.Config = {
    Brightness = 3,
    Range      = 20,
    Couleur    = Color3.new(1, 1, 1),  -- Blanc par défaut (override via params)
}

--[[
    @param brModel (Model|BasePart)
    @param params  (table, optionnel)
        Brightness (number)  — Intensité lumineuse
        Range      (number)  — Portée en studs
        Couleur    (Color3)  — Couleur de la lumière
]]
function Glow.Apply(brModel, params)
    params = params or {}

    local primaryPart = brModel.PrimaryPart
                     or brModel:FindFirstChildWhichIsA("BasePart")
    if not primaryPart then
        warn("[Glow] PrimaryPart introuvable sur", brModel.Name)
        return
    end

    -- Supprimer lumière existante créée par ce filtre
    local existingLight = primaryPart:FindFirstChild("GlowLight")
    if existingLight then existingLight:Destroy() end

    pcall(function()
        local light = Instance.new("PointLight")
        light.Name       = "GlowLight"
        light.Brightness = params.Brightness or Glow.Config.Brightness
        light.Range      = params.Range      or Glow.Config.Range
        light.Color      = params.Couleur    or Glow.Config.Couleur
        light.Parent     = primaryPart
    end)
end

return Glow
