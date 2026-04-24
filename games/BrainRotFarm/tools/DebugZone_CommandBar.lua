-- tools/DebugZone_CommandBar.lua
-- Coller dans la Command Bar Studio pour afficher/masquer la ChampCommunZone en rouge
-- Relancer pour toggle OFF (détruit les marqueurs existants)

local Workspace = game:GetService("Workspace")
local FOLDER_NAME = "_DebugZone"

-- Toggle OFF si déjà affiché
local existing = Workspace:FindFirstChild(FOLDER_NAME)
if existing then
    existing:Destroy()
    print("[DEBUG] ChampCommunZone masquée")
    return
end

local zone = {
    xMin = 150, xMax = 300,
    zMin = -270, zMax = 100,
    y    = 16.189,
}

local cx = (zone.xMin + zone.xMax) / 2   -- 225
local cz = (zone.zMin + zone.zMax) / 2   -- -85
local w  = zone.xMax - zone.xMin          -- 150
local d  = zone.zMax - zone.zMin          -- 370

local folder = Instance.new("Folder")
folder.Name  = FOLDER_NAME
folder.Parent = Workspace

local function makePart(name, size, pos)
    local p = Instance.new("Part")
    p.Name         = name
    p.Size         = size
    p.Position     = pos
    p.Anchored     = true
    p.CanCollide   = false
    p.CastShadow   = false
    p.Material     = Enum.Material.Neon
    p.Color        = Color3.fromRGB(255, 0, 0)
    p.Transparency = 0.35
    p.Parent       = folder
    return p
end

local Y  = zone.y + 0.3   -- légèrement au-dessus du sol
local T  = 0.5             -- épaisseur des murs
local H  = 8               -- hauteur des murs

-- Sol rouge semi-transparent
makePart("Sol",   Vector3.new(w, 0.2, d),  Vector3.new(cx, Y, cz))

-- 4 murs de contour
makePart("Nord",  Vector3.new(w, H, T),    Vector3.new(cx,         Y + H/2, zone.zMax))
makePart("Sud",   Vector3.new(w, H, T),    Vector3.new(cx,         Y + H/2, zone.zMin))
makePart("Est",   Vector3.new(T, H, d),    Vector3.new(zone.xMax,  Y + H/2, cz))
makePart("Ouest", Vector3.new(T, H, d),    Vector3.new(zone.xMin,  Y + H/2, cz))

-- Marqueur hauteur Rain (Y + 18 = hauteur des nuages)
local cloudY = zone.y + 18
makePart("CloudHeight", Vector3.new(w, 0.2, d), Vector3.new(cx, cloudY, cz)).Transparency = 0.6

-- Labels coins
local corners = {
    { zone.xMin, zone.zMin }, { zone.xMax, zone.zMin },
    { zone.xMin, zone.zMax }, { zone.xMax, zone.zMax },
}
for i, c in ipairs(corners) do
    local post = Instance.new("Part")
    post.Name        = "Corner" .. i
    post.Size        = Vector3.new(1, 12, 1)
    post.Position    = Vector3.new(c[1], Y + 6, c[2])
    post.Anchored    = true
    post.CanCollide  = false
    post.Material    = Enum.Material.Neon
    post.Color       = Color3.fromRGB(255, 80, 80)
    post.Transparency = 0
    post.Parent      = folder

    local bg = Instance.new("BillboardGui", post)
    bg.Size          = UDim2.new(0, 120, 0, 30)
    bg.StudsOffset   = Vector3.new(0, 7, 0)
    bg.AlwaysOnTop   = true
    local lbl = Instance.new("TextLabel", bg)
    lbl.Size             = UDim2.new(1,0,1,0)
    lbl.BackgroundTransparency = 1
    lbl.Text             = string.format("(%.0f, %.0f)", c[1], c[2])
    lbl.TextColor3       = Color3.new(1,1,1)
    lbl.Font             = Enum.Font.GothamBold
    lbl.TextSize         = 14
    lbl.TextStrokeTransparency = 0
    lbl.TextStrokeColor3 = Color3.new(0,0,0)
end

print(string.format("[DEBUG] ChampCommunZone affichée — %.0fx%.0f studs, centre (%.0f, %.0f)", w, d, cx, cz))
print(string.format("[DEBUG] Ligne bleue = hauteur nuages Rain (Y=%.1f)", cloudY))
print("[DEBUG] Relancer ce script pour masquer")
