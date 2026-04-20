-- shared-lib/src/server/BoardSystem.lua
-- DobiGames shared-lib — Boards cliquables devant chaque base
-- SurfaceGui sur la face du Board → affiche infos Rebirth
-- Le TextButton "BoutonAchat" est cliqué directement par le client (RebirthHUD.client.lua)

local BoardSystem = {}

-- ============================================================
-- Services
-- ============================================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local Logger = require(script.Parent.Logger)

local function formatPrix(n)
    n = math.floor(n or 0)
    local function fmt(v, s)
        return (math.floor(v * 10) % 10 == 0 and tostring(math.floor(v)) or string.format("%.1f", v)) .. s
    end
    if n >= 1e9 then return fmt(n / 1e9, "B")
    elseif n >= 1e6 then return fmt(n / 1e6, "M")
    elseif n >= 1e3 then return fmt(n / 1e3, "K")
    else return tostring(n) end
end

-- ============================================================
-- Config
-- ============================================================
local Config = require(
    game.ReplicatedStorage:FindFirstChild("GameConfig")
    or game.ReplicatedStorage.Specialized.GameConfig
)
local boardCfg = Config.BoardConfig or {
    texteDefaut   = "REBIRTH\nClick to view",
    distanceClick = 20,
}

-- ============================================================
-- Lazy loaders
-- ============================================================
local _AssignationSystem = nil
local function getAssignationSystem()
    if not _AssignationSystem then
        local ok, m = pcall(require, game:GetService("ServerScriptService").SharedLib.Server.AssignationSystem)
        if ok and m then _AssignationSystem = m end
    end
    return _AssignationSystem
end


-- ============================================================
-- Création de la SurfaceGui sur le Board
-- ============================================================
local function creerSurfaceGui(board)
    -- Supprimer tous les SurfaceGui/BillboardGui existants
    for _, child in ipairs(board:GetChildren()) do
        if child:IsA("SurfaceGui") or child:IsA("BillboardGui") then
            child:Destroy()
        end
    end
    -- Supprimer aussi les TextLabels/Frames parasites Studio
    for _, child in ipairs(board:GetChildren()) do
        if child:IsA("TextLabel") or child:IsA("Frame") then
            child:Destroy()
        end
    end
    -- Supprimer l'ancien ClickDetector (le bouton sur le panneau remplace l'interaction)
    local oldCd = board:FindFirstChildOfClass("ClickDetector")
    if oldCd then oldCd:Destroy() end

    local sg = Instance.new("SurfaceGui", board)
    sg.Name           = "BoardGui"
    sg.Face           = Enum.NormalId.Front
    sg.SizingMode     = Enum.SurfaceGuiSizingMode.PixelsPerStud
    sg.PixelsPerStud  = 50
    sg.AlwaysOnTop    = false
    sg.MaxDistance    = 80
    sg.LightInfluence = 0.1

    local fond = Instance.new("Frame", sg)
    fond.Name                   = "Fond"
    fond.Size                   = UDim2.new(1, -8, 1, -8)
    fond.Position               = UDim2.new(0, 4, 0, 4)
    fond.BackgroundColor3       = Color3.fromRGB(45, 45, 45)
    fond.BackgroundTransparency = 0
    fond.BorderSizePixel        = 0
    Instance.new("UICorner", fond).CornerRadius = UDim.new(0, 8)

    local stroke = Instance.new("UIStroke", fond)
    stroke.Color     = Color3.fromRGB(50, 50, 50)
    stroke.Thickness = 2

    local lblTitre = Instance.new("TextLabel", fond)
    lblTitre.Name                   = "Titre"
    lblTitre.Size                   = UDim2.new(1, -10, 0.28, 0)
    lblTitre.Position               = UDim2.new(0, 5, 0.02, 0)
    lblTitre.BackgroundTransparency = 1
    lblTitre.TextColor3             = Color3.fromRGB(235, 235, 235)
    lblTitre.Font                   = Enum.Font.GothamBlack
    lblTitre.TextScaled             = true
    lblTitre.Text                   = "BASE\nUPGRADE"

    local sep = Instance.new("Frame", fond)
    sep.Size             = UDim2.new(0.85, 0, 0, 2)
    sep.Position         = UDim2.new(0.075, 0, 0.32, 0)
    sep.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    sep.BorderSizePixel  = 0

    local lblNiveau = Instance.new("TextLabel", fond)
    lblNiveau.Name                   = "Niveau"
    lblNiveau.Size                   = UDim2.new(1, -10, 0.2, 0)
    lblNiveau.Position               = UDim2.new(0, 5, 0.34, 0)
    lblNiveau.BackgroundTransparency = 1
    lblNiveau.TextColor3             = Color3.fromRGB(235, 235, 235)
    lblNiveau.Font                   = Enum.Font.GothamBold
    lblNiveau.TextScaled             = true
    lblNiveau.Text                   = "Level 0 / 30  ·  x1.0"

    local bouton = Instance.new("TextButton", fond)
    bouton.Name             = "BoutonAchat"
    bouton.Size             = UDim2.new(0.85, 0, 0.3, 0)
    bouton.Position         = UDim2.new(0.075, 0, 0.62, 0)
    bouton.BackgroundColor3 = Color3.fromRGB(60, 165, 80)
    bouton.TextColor3       = Color3.fromRGB(240, 240, 240)
    bouton.Font             = Enum.Font.GothamBlack
    bouton.TextScaled       = true
    bouton.Text             = "—"
    bouton.BorderSizePixel  = 0
    bouton.AutoButtonColor  = true
    Instance.new("UICorner", bouton).CornerRadius = UDim.new(0, 6)

    return sg
end

-- ============================================================
-- Met à jour le contenu de la SurfaceGui d'un Board
-- etat = table envoyée par RebirthButtonUpdate / OnLevelUp :
--   rebirthLevel, coinsRequis, multiplicateur, disponible, maxAtteint
-- ============================================================
local function mettreAJourSurfaceGui(board, etat)
    local sg   = board:FindFirstChild("BoardGui")
    if not sg  then return end
    local fond = sg:FindFirstChild("Fond")
    if not fond then return end

    local niveau = etat.rebirthLevel or 0
    local coinsR = etat.coinsRequis  or 0
    local mult   = etat.multiplicateur or (1 + niveau * 0.1)
    local maxed  = etat.maxAtteint or (niveau >= 30)
    local dispon = etat.disponible or false

    local lblNiveau = fond:FindFirstChild("Niveau")
    if lblNiveau then
        lblNiveau.Text = "Level " .. niveau .. " / 30  ·  x" .. string.format("%.1f", mult)
    end

    local bouton = fond:FindFirstChild("BoutonAchat")
    if bouton then
        if maxed then
            bouton.Text             = "MAX LEVEL"
            bouton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            bouton.TextColor3       = Color3.fromRGB(120, 120, 120)
            bouton.Active           = false
        else
            bouton.Text             = formatPrix(coinsR) .. " coins"
            bouton.BackgroundColor3 = dispon
                and Color3.fromRGB(60, 165, 80)
                or  Color3.fromRGB(40, 40, 40)
            bouton.TextColor3       = dispon
                and Color3.fromRGB(240, 240, 240)
                or  Color3.fromRGB(120, 120, 120)
            bouton.Active           = dispon
        end
    end

    local stroke = fond:FindFirstChildOfClass("UIStroke")
    if stroke then
        stroke.Color = dispon
            and Color3.fromRGB(60, 165, 80)
            or  Color3.fromRGB(50, 50, 50)
    end
end

-- ============================================================
-- API publique — Init
-- ============================================================

function BoardSystem.Init()
    local bases = Workspace:FindFirstChild("Bases")
    if not bases then
        Logger.warn("Board", "Workspace.Bases introuvable")
        return
    end

    local maxBases = Config.MaxBases or 8

    for i = 1, maxBases do
        local base   = bases:FindFirstChild("Base_" .. i)
        local shared = base and base:FindFirstChild("Shared")
        local bat    = shared and shared:FindFirstChild("Base")
        local board  = bat and bat:FindFirstChild("Board")

        if board then
            creerSurfaceGui(board)
            Logger.debug("Board", "Board configuré → Base_%d", i)
        else
            if base then
                Logger.warn("Board", "Board introuvable dans Base_%d", i)
            end
        end
    end

    Logger.info("Board", "Init ✓")
end

-- ============================================================
-- API publique — MettreAJourBoard
-- ============================================================

function BoardSystem.MettreAJourBoard(player, etat)
    local AS = getAssignationSystem()
    if not AS then return end
    local baseIndex = AS.GetBaseIndex(player)
    if not baseIndex then return end

    local bases  = Workspace:FindFirstChild("Bases")
    if not bases then return end
    local base   = bases:FindFirstChild("Base_" .. baseIndex)
    local shared = base and base:FindFirstChild("Shared")
    local bat    = shared and shared:FindFirstChild("Base")
    local board  = bat and bat:FindFirstChild("Board")
    if not board then return end

    mettreAJourSurfaceGui(board, etat or {})
end

return BoardSystem
