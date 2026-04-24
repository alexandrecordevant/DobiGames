-- shared-lib/server/WeatherSystem/WetGroundEffect.lua
-- Sol mouillé : Baseplate reflectante + couche d'eau sur toute la Baseplate

local WetGroundEffect = {}

local Workspace    = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Logger       = require(script.Parent.Parent.Logger)

local savedState = nil
local waterLayer = nil

local function getBaseplate()
    local map = Workspace:FindFirstChild("Map")
    if map then
        local bp = map:FindFirstChild("Baseplate")
        if bp then return bp end
    end
    return Workspace:FindFirstChild("Baseplate")
end

local function creerCoucheEau(bp, surfaceY)
    waterLayer              = Instance.new("Part")
    waterLayer.Name         = "WaterLayer"
    waterLayer.Size         = Vector3.new(bp.Size.X, 0.1, bp.Size.Z)
    waterLayer.Position     = Vector3.new(bp.Position.X, surfaceY, bp.Position.Z)
    waterLayer.Anchored     = true
    waterLayer.CanCollide   = false
    waterLayer.CastShadow   = false
    waterLayer.Material     = Enum.Material.Glass
    waterLayer.Color        = Color3.fromRGB(140, 185, 220)
    waterLayer.Reflectance  = 0.95
    waterLayer.Transparency = 1
    waterLayer.Parent       = Workspace

    TweenService:Create(waterLayer,
        TweenInfo.new(4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Transparency = 0.82 }
    ):Play()
end

function WetGroundEffect.Appliquer(config)
    local bp = getBaseplate()
    if not bp then
        Logger.warn("Weather", "Baseplate introuvable pour WetGroundEffect")
        return
    end

    savedState = {
        Material    = bp.Material,
        Reflectance = bp.Reflectance,
        Color       = bp.Color,
    }

    pcall(function()
        bp.Material = Enum.Material.SmoothPlastic
        TweenService:Create(bp, TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Reflectance = config.wetGroundReflectance or 0.75,
            Color       = config.wetGroundColor       or Color3.fromRGB(85, 90, 100),
        }):Play()
    end)

    -- Surface = centre Baseplate + demi-hauteur + petit offset
    local surfaceY = bp.Position.Y + bp.Size.Y / 2 + 0.06
    creerCoucheEau(bp, surfaceY)

    Logger.info("Weather", "WetGroundEffect appliqué (%.0fx%.0f studs)", bp.Size.X, bp.Size.Z)
end

function WetGroundEffect.Restaurer()
    local bp = getBaseplate()
    if bp and savedState then
        pcall(function()
            bp.Material = savedState.Material
            TweenService:Create(bp, TweenInfo.new(5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Reflectance = savedState.Reflectance,
                Color       = savedState.Color,
            }):Play()
        end)
        savedState = nil
    end

    if waterLayer and waterLayer.Parent then
        local w = waterLayer ; waterLayer = nil
        TweenService:Create(w, TweenInfo.new(3), { Transparency = 1 }):Play()
        task.delay(3.2, function()
            if w and w.Parent then w:Destroy() end
        end)
    end

    Logger.info("Weather", "WetGroundEffect restauré")
end

return WetGroundEffect
