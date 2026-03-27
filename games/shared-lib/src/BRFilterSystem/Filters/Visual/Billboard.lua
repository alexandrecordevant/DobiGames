-- ReplicatedStorage/SharedLib/BRFilterSystem/Filters/Visual/Billboard.lua
-- Filtre Billboard — Affiche un HUD texte au-dessus du BR
-- Remplace BillboardHelper.lua — le Billboard devient un filtre standard

local Billboard = {}

Billboard.Config = {
    Taille        = UDim2.new(0, 200, 0, 50),
    StudsOffsetY  = 6,
    MaxDistance   = 120,
    Police        = Enum.Font.GothamBold,
    StrokeTransp  = 0.4,
}

--[[
    Applique un Billboard au-dessus du BR

    @param brModel (Model|BasePart)
    @param params  (table)
        REQUIS  : Text  (string)  — Texte à afficher
                  Color (Color3)  — Couleur du texte
        OPTIONNEL: OffsetY     (number)  — Override hauteur (défaut Config.StudsOffsetY)
                   MaxDistance (number)  — Override distance visible
                   Taille      (UDim2)   — Override taille billboard
]]
function Billboard.Apply(brModel, params)
    params = params or {}

    -- Trouver la racine (PrimaryPart ou premier BasePart)
    local racine = nil
    if brModel:IsA("BasePart") then
        racine = brModel
    elseif brModel.PrimaryPart then
        racine = brModel.PrimaryPart
    else
        racine = brModel:FindFirstChildWhichIsA("BasePart")
    end

    if not racine then
        warn("[Billboard] Racine introuvable sur", brModel.Name)
        return
    end

    if not params.Text or not params.Color then
        warn("[Billboard] Params Text et Color requis")
        return
    end

    -- Supprimer ancien billboard si présent (évite doublons)
    local existing = racine:FindFirstChild("BRBillboard")
    if existing then
        existing:Destroy()
    end

    -- Créer BillboardGui
    local bb = Instance.new("BillboardGui")
    bb.Name        = "BRBillboard"
    bb.Size        = params.Taille or Billboard.Config.Taille
    bb.StudsOffset = Vector3.new(0, params.OffsetY or Billboard.Config.StudsOffsetY, 0)
    bb.AlwaysOnTop = false
    bb.MaxDistance = params.MaxDistance or Billboard.Config.MaxDistance
    bb.ResetOnSpawn = false
    bb.Parent      = racine

    -- TextLabel principal
    local label = Instance.new("TextLabel")
    label.Name                   = "Label"
    label.Size                   = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text                   = params.Text
    label.TextColor3             = params.Color
    label.TextScaled             = true
    label.Font                   = Billboard.Config.Police
    label.TextStrokeTransparency = Billboard.Config.StrokeTransp
    label.TextStrokeColor3       = Color3.new(0, 0, 0)
    label.Parent                 = bb
end

--[[
    Met à jour le texte d'un Billboard existant (sans recréer)

    @param brModel (Model|BasePart)
    @param newText (string)
    @param newColor (Color3, optionnel)
]]
function Billboard.Update(brModel, newText, newColor)
    local racine = nil
    if brModel:IsA("BasePart") then
        racine = brModel
    elseif brModel.PrimaryPart then
        racine = brModel.PrimaryPart
    else
        racine = brModel:FindFirstChildWhichIsA("BasePart")
    end
    if not racine then return end

    local bb = racine:FindFirstChild("BRBillboard")
    if not bb then return end

    local label = bb:FindFirstChild("Label")
    if label then
        pcall(function()
            label.Text = newText
            if newColor then
                label.TextColor3 = newColor
            end
        end)
    end
end

--[[
    Supprime le Billboard d'un BR

    @param brModel (Model|BasePart)
]]
function Billboard.Remove(brModel)
    local racine = nil
    if brModel:IsA("BasePart") then
        racine = brModel
    elseif brModel.PrimaryPart then
        racine = brModel.PrimaryPart
    else
        racine = brModel:FindFirstChildWhichIsA("BasePart")
    end
    if not racine then return end

    local bb = racine:FindFirstChild("BRBillboard")
    if bb then
        pcall(function() bb:Destroy() end)
    end
end

return Billboard
