-- ReplicatedStorage/SharedLib/BRFilterSystem/Filters/Visual/Trail.lua
-- Filtre Visuel TRAIL — Ajoute un trail de traîne sur le BR

local Trail = {}

Trail.Config = {
    Couleur        = Color3.fromRGB(255, 255, 255),
    Lifetime       = 0.5,
    MinLength      = 0,
    MaxLength      = 100,
    Transparency   = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(1, 1),
    }),
    LightEmission  = 0.5,
    FaceCamera     = false,
    WidthScale     = NumberSequence.new(0.5),
}

--[[
    @param brModel (Model|BasePart)
    @param params  (table, optionnel)
        Couleur   (Color3)  — Couleur du trail
        Lifetime  (number)  — Durée en secondes
]]
function Trail.Apply(brModel, params)
    params = params or {}

    local primaryPart = brModel.PrimaryPart
                     or brModel:FindFirstChildWhichIsA("BasePart")
    if not primaryPart then
        warn("[Trail] PrimaryPart introuvable sur", brModel.Name)
        return
    end

    -- Supprimer anciens attachments + trail si présents
    local oldA0 = primaryPart:FindFirstChild("TrailA0")
    local oldA1 = primaryPart:FindFirstChild("TrailA1")
    if oldA0 then oldA0:Destroy() end
    if oldA1 then oldA1:Destroy() end
    local oldTrail = primaryPart:FindFirstChild("BRTrail")
    if oldTrail then oldTrail:Destroy() end

    local couleur = params.Couleur or Trail.Config.Couleur

    pcall(function()
        -- Deux attachments pour définir la largeur du trail
        local a0 = Instance.new("Attachment")
        a0.Name     = "TrailA0"
        a0.Position = Vector3.new(0, 0.5, 0)
        a0.Parent   = primaryPart

        local a1 = Instance.new("Attachment")
        a1.Name     = "TrailA1"
        a1.Position = Vector3.new(0, -0.5, 0)
        a1.Parent   = primaryPart

        local trail = Instance.new("Trail")
        trail.Name          = "BRTrail"
        trail.Attachment0   = a0
        trail.Attachment1   = a1
        trail.Lifetime      = params.Lifetime or Trail.Config.Lifetime
        trail.MinLength     = Trail.Config.MinLength
        trail.MaxLength     = Trail.Config.MaxLength
        trail.Transparency  = Trail.Config.Transparency
        trail.LightEmission = Trail.Config.LightEmission
        trail.FaceCamera    = Trail.Config.FaceCamera
        trail.WidthScale    = Trail.Config.WidthScale
        trail.Color         = ColorSequence.new(couleur)
        trail.Parent        = primaryPart
    end)
end

return Trail
