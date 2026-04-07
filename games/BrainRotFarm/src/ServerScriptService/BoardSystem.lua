-- ServerScriptService/Common/BoardSystem.lua
-- BrainRotFarm — Boards cliquables devant chaque base
-- SurfaceGui sur la face du Board → affiche infos Rebirth
-- ClickDetector → ouvre le menu Rebirth côté client
-- 0 valeur hardcodée — tout lu depuis GameConfig

local BoardSystem = {}

-- ============================================================
-- Services
-- ============================================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

-- ============================================================
-- Config (Specialized — aucune valeur hardcodée ici)
-- ============================================================
local Logger   = require(game:GetService("ServerScriptService").SharedLib.Server.Logger)
local Config   = require(ReplicatedStorage.GameConfig)
local boardCfg = Config.BoardConfig or {
    texteDefaut   = "🔄 REBIRTH\nClick to view",
    distanceClick = 20,
}

-- ============================================================
-- Lazy loaders
-- ============================================================
local _RebirthSystem = nil
local function getRebirthSystem()
    if not _RebirthSystem then
        local ok, m = pcall(require, game:GetService("ServerScriptService").SharedLib.Server.RebirthSystem)
        if ok and m then _RebirthSystem = m end
    end
    return _RebirthSystem
end

local _AssignationSystem = nil
local function getAssignationSystem()
    if not _AssignationSystem then
        local ok, m = pcall(require, game:GetService("ServerScriptService").SharedLib.Server.AssignationSystem)
        if ok and m then _AssignationSystem = m end
    end
    return _AssignationSystem
end

-- ============================================================
-- Utilitaires — formate un nombre avec espaces milliers
-- ============================================================
local function formaterNombre(n)
    local s      = tostring(math.floor(n or 0))
    local result = ""
    local count  = 0
    for i = #s, 1, -1 do
        if count > 0 and count % 3 == 0 then result = " " .. result end
        result = s:sub(i, i) .. result
        count  = count + 1
    end
    return result
end

-- ============================================================
-- Création de la SurfaceGui sur le Board
-- Layout : titre blanc sur fond noir + bouton vert avec le prix
-- Le TextButton "BoutonAchat" est cliqué directement par le client
-- ============================================================
local function creerSurfaceGui(board)
    local ancienne = board:FindFirstChild("BoardGui")
    if ancienne then ancienne:Destroy() end

    -- Supprimer l'ancien ClickDetector (le bouton sur le panneau remplace l'interaction)
    local oldCd = board:FindFirstChildOfClass("ClickDetector")
    if oldCd then oldCd:Destroy() end

    local sg = Instance.new("SurfaceGui", board)
    sg.Name          = "BoardGui"
    sg.Face          = Enum.NormalId.Front
    sg.SizingMode    = Enum.SurfaceGuiSizingMode.PixelsPerStud
    sg.PixelsPerStud = 50
    sg.AlwaysOnTop   = false
    sg.MaxDistance   = 150
    sg.LightInfluence = 0.1

    -- Fond gris foncé avec marge pour que les coins arrondis ne mordent pas le panneau
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

    -- Titre blanc
    local lblTitre = Instance.new("TextLabel", fond)
    lblTitre.Name                   = "Titre"
    lblTitre.Size                   = UDim2.new(1, -10, 0.28, 0)
    lblTitre.Position               = UDim2.new(0, 5, 0.02, 0)
    lblTitre.BackgroundTransparency = 1
    lblTitre.TextColor3             = Color3.fromRGB(235, 235, 235)
    lblTitre.Font                   = Enum.Font.GothamBlack
    lblTitre.TextScaled             = true
    lblTitre.Text                   = "AMÉLIORATION\nDE LA BASE"

    -- Ligne séparatrice
    local sep = Instance.new("Frame", fond)
    sep.Size             = UDim2.new(0.85, 0, 0, 2)
    sep.Position         = UDim2.new(0.075, 0, 0.32, 0)
    sep.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    sep.BorderSizePixel  = 0

    -- Info niveau + multiplicateur
    local lblNiveau = Instance.new("TextLabel", fond)
    lblNiveau.Name                   = "Niveau"
    lblNiveau.Size                   = UDim2.new(1, -10, 0.2, 0)
    lblNiveau.Position               = UDim2.new(0, 5, 0.34, 0)
    lblNiveau.BackgroundTransparency = 1
    lblNiveau.TextColor3             = Color3.fromRGB(235, 235, 235)
    lblNiveau.Font                   = Enum.Font.GothamBold
    lblNiveau.TextScaled             = true
    lblNiveau.Text                   = "Niveau 0 / 30  ·  x1.0"

    -- Bouton vert d'achat (cliqué directement par le LocalScript client)
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

    local niveau  = etat.rebirthLevel or 0
    local coinsR  = etat.coinsRequis  or 0
    local mult    = etat.multiplicateur or (1 + niveau * 0.1)
    local maxed   = etat.maxAtteint or (niveau >= 30)
    local dispon  = etat.disponible or false

    -- Niveau + multiplicateur
    local lblNiveau = fond:FindFirstChild("Niveau")
    if lblNiveau then
        lblNiveau.Text = "Niveau " .. niveau .. " / 30  ·  x" .. string.format("%.1f", mult)
    end

    -- Bouton : prix ou "MAX"
    local bouton = fond:FindFirstChild("BoutonAchat")
    if bouton then
        if maxed then
            bouton.Text             = "NIVEAU MAXIMUM"
            bouton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            bouton.TextColor3       = Color3.fromRGB(120, 120, 120)
            bouton.Active           = false
        else
            bouton.Text             = formaterNombre(coinsR) .. " coins"
            bouton.BackgroundColor3 = dispon
                and Color3.fromRGB(60, 165, 80)
                or  Color3.fromRGB(40, 40, 40)
            bouton.TextColor3       = dispon
                and Color3.fromRGB(240, 240, 240)
                or  Color3.fromRGB(120, 120, 120)
            bouton.Active           = dispon
        end
    end

    -- Bordure verte si achat possible
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

    local maxBases = Config.MaxBases or 6

    for i = 1, maxBases do
        local base   = bases:FindFirstChild("Base_" .. i)
        -- Base (floors/spots) dans Shared/ (structure Shared/Specific)
        local shared = base and base:FindFirstChild("Shared")
        local bat    = shared and shared:FindFirstChild("Base")
        local board  = bat and bat:FindFirstChild("Board")

        if board then
            -- Créer la SurfaceGui avec le bouton d'amélioration
            -- Le clic est géré côté client (RebirthHUD.client.lua)
            creerSurfaceGui(board)
            Logger.debug("Board", "Board configuré → Base_%d", i)
        else
            Logger.warn("Board", "Board introuvable dans Base_%d", i)
        end
    end

    Logger.info("Board", "Init ✓")
end

-- ============================================================
-- API publique — Mise à jour du Board pour un joueur
-- etat = table RebirthButtonUpdate (rebirthLevel, coinsActuels, coinsRequis, etc.)
-- ============================================================

function BoardSystem.MettreAJourBoard(player, etat)
    local AS = getAssignationSystem()
    if not AS then return end
    local baseIndex = AS.GetBaseIndex(player)
    if not baseIndex then return end

    local bases = Workspace:FindFirstChild("Bases")
    if not bases then return end
    local base   = bases:FindFirstChild("Base_" .. baseIndex)
    -- Base (floors/spots) dans Shared/ (structure Shared/Specific)
    local shared = base and base:FindFirstChild("Shared")
    local bat    = shared and shared:FindFirstChild("Base")
    local board  = bat and bat:FindFirstChild("Board")
    if not board then return end

    mettreAJourSurfaceGui(board, etat or {})
end

return BoardSystem
