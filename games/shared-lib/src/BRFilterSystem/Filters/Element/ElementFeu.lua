-- ReplicatedStorage/SharedLib/BRFilterSystem/Filters/Element/ElementFeu.lua
-- Filtre Élémentaire FEU — Flammes qui montent + lueur chaude modérée + label Mutant

local ElementFeu = {}
local Logger = require(game:GetService("ServerScriptService").SharedLib.Server.Logger)

ElementFeu.Config = {
    Couleur      = Color3.fromRGB(160, 50, 0),
    CouleurLight = Color3.fromRGB(180, 80, 0),
    Nom          = "FEU",
}

local function ajouterBillboardMutant(primaryPart)
    pcall(function()
        local existing = primaryPart:FindFirstChild("MutantBillboard")
        if existing then existing:Destroy() end

        local bb = Instance.new("BillboardGui")
        bb.Name         = "MutantBillboard"
        bb.StudsOffset  = Vector3.new(0, 6, 0)
        bb.Size         = UDim2.new(0, 80, 0, 80)
        bb.MaxDistance  = 100
        bb.AlwaysOnTop  = true
        bb.Parent       = primaryPart

        local label = Instance.new("TextLabel")
        label.Size                   = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Text                   = "🔥"
        label.TextScaled             = true
        label.Font                   = Enum.Font.GothamBold
        label.TextStrokeTransparency = 0.5
        label.TextStrokeColor3       = Color3.new(0, 0, 0)
        label.Parent                 = bb
    end)
end

function ElementFeu.Apply(brModel, params)
    local cfg = ElementFeu.Config

    local primaryPart = brModel.PrimaryPart
                     or brModel:FindFirstChildWhichIsA("BasePart")
    if not primaryPart then
        Logger.warn("Filter", "PrimaryPart introuvable sur %s", brModel.Name)
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
        emitter.Texture           = "rbxasset://textures/particles/fire_main.dds"
        emitter.EmissionDirection = Enum.NormalId.Top
        emitter.Color             = ColorSequence.new({
            ColorSequenceKeypoint.new(0,    Color3.fromRGB(255, 255, 80)),
            ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 120, 0)),
            ColorSequenceKeypoint.new(0.6,  Color3.fromRGB(200, 30,  0)),
            ColorSequenceKeypoint.new(1,    Color3.fromRGB(80,  0,   0)),
        })
        emitter.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0,   0.5),
            NumberSequenceKeypoint.new(0.3, 0.3),
            NumberSequenceKeypoint.new(1,   0),
        })
        emitter.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0,   0.65),
            NumberSequenceKeypoint.new(0.6, 0.85),
            NumberSequenceKeypoint.new(1,   1),
        })
        emitter.Rate           = 200
        emitter.Lifetime       = NumberRange.new(1.5, 3)
        emitter.Speed          = NumberRange.new(8, 16)
        emitter.SpreadAngle    = Vector2.new(15, 15)
        emitter.RotSpeed       = NumberRange.new(-180, 180)
        emitter.LightEmission  = 0
        emitter.LightInfluence = 1
        emitter.Parent         = primaryPart
    end)

    -- Label Mutant au-dessus
    ajouterBillboardMutant(primaryPart)

    pcall(function() brModel:SetAttribute("ElementType", cfg.Nom) end)
end

return ElementFeu
