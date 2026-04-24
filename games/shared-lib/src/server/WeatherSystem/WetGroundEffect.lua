-- shared-lib/server/WeatherSystem/WetGroundEffect.lua
-- Sol mouillé : Baseplate reflectante pendant l'event pluie

local WetGroundEffect = {}

local Workspace    = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Logger       = require(script.Parent.Parent.Logger)

local savedState = nil

local function getBaseplate()
    local map = Workspace:FindFirstChild("Map")
    if map then
        local bp = map:FindFirstChild("Baseplate")
        if bp then return bp end
    end
    return Workspace:FindFirstChild("Baseplate")
end

function WetGroundEffect.Appliquer(config)
    local bp = getBaseplate()
    if not bp then return end

    savedState = {
        Material    = bp.Material,
        Reflectance = bp.Reflectance,
        Color       = bp.Color,
    }

    local tweenInfo = TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    pcall(function()
        bp.Material = Enum.Material.SmoothPlastic
        TweenService:Create(bp, tweenInfo, {
            Reflectance = config.wetGroundReflectance or 0.4,
            Color       = config.wetGroundColor       or Color3.fromRGB(90, 95, 105),
        }):Play()
    end)

end

function WetGroundEffect.Restaurer()
    local bp = getBaseplate()
    if bp and savedState then
        local tweenInfo = TweenInfo.new(5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        pcall(function()
            bp.Material = savedState.Material
            TweenService:Create(bp, tweenInfo, {
                Reflectance = savedState.Reflectance,
                Color       = savedState.Color,
            }):Play()
        end)
        savedState = nil
    end

end

return WetGroundEffect
