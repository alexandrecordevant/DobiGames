-- ReplicatedStorage/SharedLib/BRFilterSystem/Filters/Visual/Sparkles.lua
-- Filtre Visuel SPARKLES — Ajoute des sparkles sur le BR

local Sparkles = {}

Sparkles.Config = {
    Couleur = Color3.fromRGB(255, 255, 200),  -- Jaune pâle par défaut
}

--[[
    @param brModel (Model|BasePart)
    @param params  (table, optionnel)
        Couleur (Color3) — Couleur des sparkles
]]
function Sparkles.Apply(brModel, params)
    params = params or {}

    local primaryPart = brModel.PrimaryPart
                     or brModel:FindFirstChildWhichIsA("BasePart")
    if not primaryPart then
        warn("[Sparkles] PrimaryPart introuvable sur", brModel.Name)
        return
    end

    -- Supprimer sparkles existantes créées par ce filtre
    local existing = primaryPart:FindFirstChild("BRSparkles")
    if existing then existing:Destroy() end

    pcall(function()
        local sparkles = Instance.new("Sparkles")
        sparkles.Name         = "BRSparkles"
        sparkles.SparkleColor = params.Couleur or Sparkles.Config.Couleur
        sparkles.Parent       = primaryPart
    end)
end

return Sparkles
