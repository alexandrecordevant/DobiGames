-- tools/DebugRain_CommandBar.lua
-- Coller dans la Command Bar pendant l'event Rain pour localiser le RainEffect
-- Affiche : position, taille, ParticleEmitters et leur Rate

local Workspace = game:GetService("Workspace")
local FOLDER    = "_DebugRain"

-- Toggle OFF
local existing = Workspace:FindFirstChild(FOLDER)
if existing then
    existing:Destroy()
    print("[DebugRain] masqué")
    return
end

local folder = Instance.new("Folder")
folder.Name   = FOLDER
folder.Parent = Workspace

-- ── Trouver RainEffect ──────────────────────────────────────
local rainEffect = Workspace:FindFirstChild("RainEffect")
if not rainEffect then
    print("[DebugRain] ⚠️  RainEffect introuvable dans Workspace — l'event est-il actif ?")
    folder:Destroy()
    return
end

-- Part principale
local mainPart = nil
if rainEffect:IsA("BasePart") then
    mainPart = rainEffect
elseif rainEffect:IsA("Model") then
    mainPart = rainEffect.PrimaryPart or rainEffect:FindFirstChildWhichIsA("BasePart")
end

if not mainPart then
    print("[DebugRain] ⚠️  Aucune BasePart trouvée dans RainEffect")
    folder:Destroy()
    return
end

local pos  = mainPart.Position
local size = mainPart.Size
print(string.format("[DebugRain] RainEffect trouvé"))
print(string.format("  Position : (%.1f, %.1f, %.1f)", pos.X, pos.Y, pos.Z))
print(string.format("  Size     : (%.1f, %.1f, %.1f)", size.X, size.Y, size.Z))

-- ParticleEmitters
local emitters = {}
for _, pe in ipairs(mainPart:GetChildren()) do
    if pe:IsA("ParticleEmitter") then
        table.insert(emitters, pe)
        print(string.format("  ParticleEmitter [%s]  Rate=%.0f  Enabled=%s", pe.Name, pe.Rate, tostring(pe.Enabled)))
    end
end
if #emitters == 0 then
    print("  ⚠️  Aucun ParticleEmitter sur la part principale")
    -- Chercher dans tous les descendants
    for _, pe in ipairs(rainEffect:GetDescendants()) do
        if pe:IsA("ParticleEmitter") then
            print(string.format("  → trouvé dans [%s]  Rate=%.0f", pe.Parent.Name, pe.Rate))
        end
    end
end

-- ── Visualisation : contour jaune de la zone couverte ───────
local function makeLine(name, sz, p)
    local part = Instance.new("Part")
    part.Name        = name
    part.Size        = sz
    part.Position    = p
    part.Anchored    = true
    part.CanCollide  = false
    part.CastShadow  = false
    part.Material    = Enum.Material.Neon
    part.Color       = Color3.fromRGB(255, 220, 0)
    part.Transparency = 0.2
    part.Parent      = folder
end

local cx, cy, cz = pos.X, pos.Y, pos.Z
local w, h, d    = size.X, size.Y, size.Z
local T = 0.4

-- Contour (4 barres)
makeLine("Nord",  Vector3.new(w, T, T), Vector3.new(cx, cy, cz + d/2))
makeLine("Sud",   Vector3.new(w, T, T), Vector3.new(cx, cy, cz - d/2))
makeLine("Est",   Vector3.new(T, T, d), Vector3.new(cx + w/2, cy, cz))
makeLine("Ouest", Vector3.new(T, T, d), Vector3.new(cx - w/2, cy, cz))

-- Croix centrale
makeLine("CentreX", Vector3.new(w * 0.5, T, T), Vector3.new(cx, cy, cz))
makeLine("CentreZ", Vector3.new(T, T, d * 0.5), Vector3.new(cx, cy, cz))

-- Billboard centre
local post = Instance.new("Part")
post.Size = Vector3.new(0.3, 10, 0.3)
post.Position = Vector3.new(cx, cy - 5, cz)
post.Anchored = true ; post.CanCollide = false
post.Material = Enum.Material.Neon
post.Color = Color3.fromRGB(255, 220, 0)
post.Transparency = 0.3
post.Parent = folder

local bg = Instance.new("BillboardGui", post)
bg.Size = UDim2.new(0, 220, 0, 50)
bg.StudsOffset = Vector3.new(0, 8, 0)
bg.AlwaysOnTop = true
local lbl = Instance.new("TextLabel", bg)
lbl.Size = UDim2.new(1,0,1,0)
lbl.BackgroundColor3 = Color3.fromRGB(30,30,30)
lbl.BackgroundTransparency = 0.2
lbl.TextColor3 = Color3.fromRGB(255,220,0)
lbl.Font = Enum.Font.GothamBold
lbl.TextSize = 13
lbl.Text = string.format("RainEffect  %.0fx%.0f\nY=%.1f  Rate×%d emitters", w, d, cy, #emitters)
Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 4)

print("[DebugRain] Relancer pour masquer")
