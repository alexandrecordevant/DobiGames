-- shared-lib/src/shared/StudsBackground.lua
-- Helper réutilisable : fond studs LEGO tuilé sur n'importe quel GuiObject
-- Usage : local SB = require(RS.SharedLib.StudsBackground)
--         SB.create(parent, { tileSize=40, transparency=0.8, assetId="rbxassetid://..." })

local StudsBackground = {}

-- 6927295847 = texture studs uploadée
-- Fallback : texture officielle Roblox studs = rbxassetid://1088500
local DEFAULT_ASSET_ID = "rbxassetid://6927295847"

--[[
    createStudsBackground(parent, opts) → ImageLabel
    opts:
      tileSize     number?   taille d'une tuile en px     (default 40)
      transparency number?   ImageTransparency 0..1       (default 0.8)
      assetId      string?   "rbxassetid://..."           (default DEFAULT_ASSET_ID)
--]]
function StudsBackground.create(parent, opts)
    opts = opts or {}
    local tileSize    = opts.tileSize     or 40
    local transp      = opts.transparency or 0.8
    local assetId     = opts.assetId      or DEFAULT_ASSET_ID

    local img = Instance.new("ImageLabel")
    img.Name                 = "StudsBackground"
    img.Size                 = UDim2.fromScale(1, 1)
    img.Position             = UDim2.fromScale(0, 0)
    img.BackgroundTransparency = 1
    -- TODO: replace with actual studs decal asset ID
    img.Image                = assetId
    img.ScaleType            = Enum.ScaleType.Tile
    img.TileSize             = UDim2.fromOffset(tileSize, tileSize)
    img.ImageTransparency    = transp
    img.ImageColor3          = Color3.fromRGB(255, 255, 255)
    img.ZIndex               = 1
    img.Parent               = parent
    return img
end

return StudsBackground
