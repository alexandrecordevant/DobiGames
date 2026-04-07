-- ReplicatedStorage/SharedLib/BRFilterSystem/Filters/Element/ElementTerre.lua
-- Filtre Élémentaire TERRE — Débris qui jaillissent en éventail + lueur verte douce + label Mutant

local ElementTerre = {}
local Logger = require(game:GetService("ServerScriptService").SharedLib.Server.Logger)

ElementTerre.Config = {
    Couleur      = Color3.fromRGB(65, 95, 30),
    CouleurLight = Color3.fromRGB(70, 120, 45),
    Nom          = "TERRE",
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
        label.Text                   = "🌍"
        label.TextScaled             = true
        label.Font                   = Enum.Font.GothamBold
        label.TextStrokeTransparency = 0.5
        label.TextStrokeColor3       = Color3.new(0, 0, 0)
        label.Parent                 = bb
    end)
end

function ElementTerre.Apply(brModel, params)
    local cfg = ElementTerre.Config

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
        emitter.Texture           = "rbxasset://textures/particles/smoke_main.dds"
        emitter.EmissionDirection = Enum.NormalId.Top
        emitter.Color             = ColorSequence.new({
            ColorSequenceKeypoint.new(0,   Color3.fromRGB(110, 140, 60)),
            ColorSequenceKeypoint.new(0.4, Color3.fromRGB(65,  95,  30)),
            ColorSequenceKeypoint.new(1,   Color3.fromRGB(50,  35,  15)),
        })
        emitter.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0,   0.5),
            NumberSequenceKeypoint.new(0.5, 0.3),
            NumberSequenceKeypoint.new(1,   0),
        })
        emitter.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0,   0.65),
            NumberSequenceKeypoint.new(0.5, 0.85),
            NumberSequenceKeypoint.new(1,   1),
        })
        emitter.Rate           = 200
        emitter.Lifetime       = NumberRange.new(2, 4)
        emitter.Speed          = NumberRange.new(4, 8)
        emitter.SpreadAngle    = Vector2.new(75, 75)
        emitter.RotSpeed       = NumberRange.new(-90, 90)
        emitter.LightEmission  = 0
        emitter.LightInfluence = 1
        emitter.Parent         = primaryPart
    end)

    -- Label Mutant au-dessus
    ajouterBillboardMutant(primaryPart)

    pcall(function() brModel:SetAttribute("ElementType", cfg.Nom) end)
end

return ElementTerre
