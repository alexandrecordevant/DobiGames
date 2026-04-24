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

-- Plan hauteur nuages Cloud (Y + 18 = hauteurNuages)
local cloudY = zone.y + 18
local pCloud = makePart("CloudHeight", Vector3.new(w, 0.2, d), Vector3.new(cx, cloudY, cz))
pCloud.Color = Color3.fromRGB(0, 150, 255)
pCloud.Transparency = 0.5

-- Plan hauteur modèle Rain (Y + 50)
local rainY = zone.y + 50
local pRain = makePart("RainModelHeight", Vector3.new(w, 0.2, d), Vector3.new(cx, rainY, cz))
pRain.Color = Color3.fromRGB(0, 255, 100)
pRain.Transparency = 0.5

-- Labels verticaux sur un poteau central
local poteauH = rainY - zone.y + 4
local poteau = Instance.new("Part")
poteau.Name = "PoteauCentre"
poteau.Size = Vector3.new(0.3, poteauH, 0.3)
poteau.Position = Vector3.new(cx, zone.y + poteauH/2, cz)
poteau.Anchored = true ; poteau.CanCollide = false
poteau.Material = Enum.Material.Neon
poteau.Color = Color3.fromRGB(255,255,255)
poteau.Transparency = 0.2
poteau.Parent = folder

local function makeLabel(parent, text, offsetY, color)
    local bg = Instance.new("BillboardGui", parent)
    bg.Size = UDim2.new(0, 160, 0, 26)
    bg.StudsOffset = Vector3.new(2, offsetY, 0)
    bg.AlwaysOnTop = true
    local lbl = Instance.new("TextLabel", bg)
    lbl.Size = UDim2.new(1,0,1,0)
    lbl.BackgroundTransparency = 0.3
    lbl.BackgroundColor3 = color
    lbl.Text = text
    lbl.TextColor3 = Color3.new(1,1,1)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 13
    Instance.new("UICorner", lbl).CornerRadius = UDim.new(0,4)
end

makeLabel(poteau, "🟢 Rain model  Y=" .. math.floor(rainY),  rainY  - zone.y - poteauH/2, Color3.fromRGB(0,150,60))
makeLabel(poteau, "🔵 Clouds       Y=" .. math.floor(cloudY), cloudY - zone.y - poteauH/2, Color3.fromRGB(0,80,200))
makeLabel(poteau, "🔴 Sol           Y=" .. math.floor(zone.y), 0 - poteauH/2 + 1,           Color3.fromRGB(160,0,0))

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

print(string.format("[DEBUG] ChampCommunZone — %.0fx%.0f studs, centre (%.0f, %.0f)", w, d, cx, cz))
print(string.format("[DEBUG] 🔴 Sol           Y=%.1f", zone.y))
print(string.format("[DEBUG] 🔵 Nuages Cloud  Y=%.1f  (hauteurNuages=18)", cloudY))
print(string.format("[DEBUG] 🟢 Modèle Rain   Y=%.1f  (hauteur=50)", rainY))
print("[DEBUG] Relancer pour masquer")
