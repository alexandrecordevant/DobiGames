-- ServerScriptService/VIPTowerSystem.server.lua
-- Fenêtre d'accès VIP toutes les 10 secondes — 10 secondes de détection
-- Seuls les joueurs avec l'attribut HasVIP=true sont comptés et téléportés.
--
-- Setup workspace attendu :
--   Workspace/TourVIP (Model, ou n'importe quel modèle avec attribut VIPTower=true)
--     ├─ AccesPlatform  (BasePart, joueurs se tiennent dessus pour attendre)
--     │   OU n'importe quelle BasePart avec attribut VIPPlatform=true
--     └─ VIPSpawn       (BasePart, destination de téléportation)
--         OU n'importe quelle BasePart avec attribut VIPSpawn=true

local Players   = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Logger    = require(game:GetService("ServerScriptService").SharedLib.Server.Logger)

-- ── Configuration ────────────────────────────────────────────────
local INTERVALLE_SECONDES = 10   -- cycle entre chaque fenêtre
local DUREE_FENETRE       = 10   -- secondes pendant lesquelles la fenêtre est ouverte

local NOM_TOUR_VIP        = "TourVIP"
local NOM_PLATEFORME      = "AccesPlatform"
local NOM_SPAWN           = "VIPSpawn"
-- ─────────────────────────────────────────────────────────────────

-- Recherche flexible : nom exact → attribut → nom partiel (insensible casse) → PrimaryPart
local function chercher(racine, nom, attribut, motsCles)
    -- 1. Nom exact (récursif)
    local found = racine:FindFirstChild(nom, true)
    if found and found:IsA("BasePart") then return found end
    -- 2. Attribut booléen
    for _, inst in ipairs(racine:GetDescendants()) do
        if inst:IsA("BasePart") and inst:GetAttribute(attribut) == true then return inst end
    end
    -- 3. Nom contenant l'un des mots-clés (insensible à la casse)
    if motsCles then
        for _, inst in ipairs(racine:GetDescendants()) do
            if inst:IsA("BasePart") then
                local n = inst.Name:lower()
                for _, mc in ipairs(motsCles) do
                    if n:find(mc) then return inst end
                end
            end
        end
    end
    -- 4. Fallback : PrimaryPart ou premier BasePart
    if racine:IsA("Model") and racine.PrimaryPart then return racine.PrimaryPart end
    return racine:FindFirstChildWhichIsA("BasePart", true)
end

local function trouverTourVIP()
    -- Par nom
    local tour = Workspace:FindFirstChild(NOM_TOUR_VIP, true)
    if tour then return tour end
    -- Par attribut
    for _, inst in ipairs(Workspace:GetDescendants()) do
        if inst:IsA("Model") and inst:GetAttribute("VIPTower") == true then return inst end
    end
    return nil
end

-- Retourne les joueurs dont le HumanoidRootPart est sur/au-dessus de la plateforme
local function getJoueursSurPlateforme(plateforme)
    local vips  = {}
    local total = {}
    local pos   = plateforme.Position
    local size  = plateforme.Size
    local margeXZ = 2  -- tolérance latérale en studs
    local margeY  = 6  -- hauteur au-dessus de la surface acceptée

    for _, p in ipairs(Players:GetPlayers()) do
        local char = p.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end
        local rpos = hrp.Position
        if math.abs(rpos.X - pos.X) <= size.X / 2 + margeXZ
            and math.abs(rpos.Z - pos.Z) <= size.Z / 2 + margeXZ
            and rpos.Y >= pos.Y
            and rpos.Y <= pos.Y + size.Y + margeY then
            table.insert(total, p)
            if p:GetAttribute("HasVIP") == true then
                table.insert(vips, p)
            end
        end
    end
    return vips, total
end

-- Crée (ou réinitialise) le BillboardGui sur la plateforme
local function creerBillboard(plateforme)
    local existing = plateforme:FindFirstChild("VIPBillboard")
    if existing then existing:Destroy() end

    local bg = Instance.new("BillboardGui")
    bg.Name         = "VIPBillboard"
    bg.Size         = UDim2.new(0, 220, 0, 64)
    bg.StudsOffset  = Vector3.new(0, 5, 0)
    bg.AlwaysOnTop  = false
    bg.Parent       = plateforme

    local frame = Instance.new("Frame")
    frame.Size                   = UDim2.fromScale(1, 1)
    frame.BackgroundColor3       = Color3.fromRGB(10, 10, 10)
    frame.BackgroundTransparency = 0.3
    frame.BorderSizePixel        = 0
    frame.Parent                 = bg
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 4); c.Parent = frame
    local s = Instance.new("UIStroke"); s.Color = Color3.fromRGB(200, 160, 20); s.Thickness = 2; s.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size                   = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Font                   = Enum.Font.GothamBold
    label.TextSize               = 16
    label.TextScaled             = false
    label.TextColor3             = Color3.fromRGB(255, 215, 50)
    label.Text                   = "⭐ 0 prêts"
    label.Parent                 = frame

    return bg, label
end

-- ── Boucle principale ────────────────────────────────────────────
task.spawn(function()
    task.wait(5)  -- attendre la fin du chargement

    local tourVIP = trouverTourVIP()
    if not tourVIP then
        Logger.warn("Tower", "[VIPTower] Modèle '%s' introuvable dans Workspace (ou attr VIPTower=true)", NOM_TOUR_VIP)
        return
    end

    local plateforme = chercher(tourVIP, NOM_PLATEFORME, "VIPPlatform", {"platform", "acces", "attente"})
    local spawnPart  = chercher(tourVIP, NOM_SPAWN,       "VIPSpawn",   {"spawn", "teleport", "entree"})

    if not plateforme then
        Logger.warn("Tower", "[VIPTower] AccesPlatform introuvable dans %s", tourVIP:GetFullName())
        return
    end
    if not spawnPart then
        Logger.warn("Tower", "[VIPTower] VIPSpawn introuvable dans %s — téléportation désactivée", tourVIP:GetFullName())
    end

    Logger.info("Tower", "[VIPTower] Initialisé — plateforme : %s", plateforme:GetFullName())

    while true do
        task.wait(INTERVALLE_SECONDES)

        -- Ouvrir la fenêtre
        Logger.info("Tower", "[VIPTower] Fenêtre ouverte (%ds)", DUREE_FENETRE)

        for t = DUREE_FENETRE, 1, -1 do
            task.wait(1)
            if not plateforme.Parent then break end  -- sécurité si tour détruite
        end

        -- Téléporter les VIP

        if not spawnPart then
            Logger.warn("Tower", "[VIPTower] Pas de VIPSpawn — téléportation ignorée")
            continue
        end

        local vips, _ = getJoueursSurPlateforme(plateforme)
        local nb = 0
        for _, p in ipairs(vips) do
            local char = p.Character
            local hrp  = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                pcall(function()
                    hrp.CFrame = spawnPart.CFrame + Vector3.new(0, 3, 0)
                end)
                nb = nb + 1
                Logger.info("Tower", "[VIPTower] %s téléporté dans la tour VIP", p.Name)
            end
        end

        Logger.info("Tower", "[VIPTower] Fenêtre fermée — %d joueur(s) téléporté(s)", nb)
    end
end)
