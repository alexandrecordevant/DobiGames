-- ReplicatedStorage/SharedLib/BRFilterSystem/Filters/Element/ElementEau.lua
-- Filtre Élémentaire EAU — Gouttes qui coulent vers le bas + lueur bleue douce + label Mutant

local ElementEau = {}

ElementEau.Config = {
    Couleur      = Color3.fromRGB(40, 90, 160),
    CouleurLight = Color3.fromRGB(60, 110, 180),
    Nom          = "EAU",
}

local function ajouterBillboardMutant(primaryPart, couleur, nomElement)
    pcall(function()
        local existing = primaryPart:FindFirstChild("MutantBillboard")
        if existing then existing:Destroy() end

        local bb = Instance.new("BillboardGui")
        bb.Name         = "MutantBillboard"
        bb.StudsOffset  = Vector3.new(0, 6, 0)
        bb.Size         = UDim2.new(0, 200, 0, 50)
        bb.MaxDistance  = 100
        bb.AlwaysOnTop  = true
        bb.Parent       = primaryPart

        local label = Instance.new("TextLabel")
        label.Size                   = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Text                   = "✦ MUTANT " .. nomElement
        label.TextColor3             = couleur
        label.TextScaled             = true
        label.Font                   = Enum.Font.GothamBold
        label.TextStrokeTransparency = 0.3
        label.TextStrokeColor3       = Color3.new(0, 0, 0)
        label.Parent                 = bb
    end)
end

function ElementEau.Apply(brModel, params)
    local cfg = ElementEau.Config

    local primaryPart = brModel.PrimaryPart
                     or brModel:FindFirstChildWhichIsA("BasePart")
    if not primaryPart then
        warn("[ElementEau] PrimaryPart introuvable sur", brModel.Name)
        return
    end

    -- Highlight (contour + halo coloré, conserve les couleurs d'origine)
    pcall(function()
        local h = Instance.new("Highlight")
        h.Name                = "ElementHighlight"
        h.OutlineColor        = cfg.Couleur
        h.FillColor           = cfg.Couleur
        h.FillTransparency    = 0.65
        h.OutlineTransparency = 0.0
        h.Parent              = brModel
    end)

    pcall(function()
        local emitter = Instance.new("ParticleEmitter")
        emitter.Name              = "ElementParticles"
        emitter.Texture           = "rbxasset://textures/particles/smoke_main.dds"
        emitter.EmissionDirection = Enum.NormalId.Top
        emitter.Color             = ColorSequence.new({
            ColorSequenceKeypoint.new(0,    Color3.fromRGB(140, 190, 220)),
            ColorSequenceKeypoint.new(0.4,  Color3.fromRGB(40,  90,  160)),
            ColorSequenceKeypoint.new(1,    Color3.fromRGB(20,  50,  120)),
        })
        emitter.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0,   0.5),
            NumberSequenceKeypoint.new(0.6, 0.3),
            NumberSequenceKeypoint.new(1,   0),
        })
        emitter.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0,   0.7),
            NumberSequenceKeypoint.new(0.7, 0.88),
            NumberSequenceKeypoint.new(1,   1),
        })
        emitter.Rate           = 200
        emitter.Lifetime       = NumberRange.new(2, 4)
        emitter.Speed          = NumberRange.new(6, 12)
        emitter.SpreadAngle    = Vector2.new(15, 15)
        emitter.RotSpeed       = NumberRange.new(-30, 30)
        emitter.LightEmission  = 0
        emitter.LightInfluence = 1
        emitter.Parent         = primaryPart
    end)

    -- Label Mutant au-dessus
    ajouterBillboardMutant(primaryPart, cfg.Couleur, cfg.Nom)

    pcall(function() brModel:SetAttribute("ElementType", cfg.Nom) end)
end

return ElementEau
