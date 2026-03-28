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
        local ok, m = pcall(require, ReplicatedStorage.SharedLib.Server.RebirthSystem)
        if ok and m then _RebirthSystem = m end
    end
    return _RebirthSystem
end

local _AssignationSystem = nil
local function getAssignationSystem()
    if not _AssignationSystem then
        local ok, m = pcall(require, ReplicatedStorage.SharedLib.Server.AssignationSystem)
        if ok and m then _AssignationSystem = m end
    end
    return _AssignationSystem
end

local function getOuvrirRebirth()
    local ev = ReplicatedStorage:FindFirstChild("OuvrirRebirth")
    if not ev then
        ev        = Instance.new("RemoteEvent")
        ev.Name   = "OuvrirRebirth"
        ev.Parent = ReplicatedStorage
    end
    return ev
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
-- Affiche les infos Rebirth directement sur la surface de l'objet
-- ============================================================
local function creerSurfaceGui(board)
    -- Supprimer l'ancienne SurfaceGui si elle existe
    local ancienne = board:FindFirstChild("BoardGui")
    if ancienne then ancienne:Destroy() end

    local sg = Instance.new("SurfaceGui", board)
    sg.Name             = "BoardGui"
    sg.Face             = Enum.NormalId.Front
    sg.SizingMode       = Enum.SurfaceGuiSizingMode.PixelsPerStud
    sg.PixelsPerStud    = 50
    sg.AlwaysOnTop      = false
    sg.MaxDistance      = 40
    sg.LightInfluence   = 0.3

    -- Fond semi-transparent
    local fond = Instance.new("Frame", sg)
    fond.Name                   = "Fond"
    fond.Size                   = UDim2.new(1, 0, 1, 0)
    fond.BackgroundColor3       = Color3.fromRGB(10, 10, 20)
    fond.BackgroundTransparency = 0.3
    fond.BorderSizePixel        = 0

    local corner = Instance.new("UICorner", fond)
    corner.CornerRadius = UDim.new(0, 8)

    local stroke = Instance.new("UIStroke", fond)
    stroke.Color     = Color3.fromRGB(255, 140, 0)
    stroke.Thickness = 3

    -- Titre "🔄 REBIRTH"
    local lblTitre = Instance.new("TextLabel", fond)
    lblTitre.Name                   = "Titre"
    lblTitre.Size                   = UDim2.new(1, -10, 0.2, 0)
    lblTitre.Position               = UDim2.new(0, 5, 0, 4)
    lblTitre.BackgroundTransparency = 1
    lblTitre.TextColor3             = Color3.fromRGB(255, 165, 0)
    lblTitre.Font                   = Enum.Font.GothamBold
    lblTitre.TextScaled             = true
    lblTitre.RichText               = true
    lblTitre.Text                   = "🔄 REBIRTH"

    -- Niveau actuel → suivant
    local lblNiveau = Instance.new("TextLabel", fond)
    lblNiveau.Name                   = "Niveau"
    lblNiveau.Size                   = UDim2.new(1, -10, 0.18, 0)
    lblNiveau.Position               = UDim2.new(0, 5, 0.2, 2)
    lblNiveau.BackgroundTransparency = 1
    lblNiveau.TextColor3             = Color3.fromRGB(255, 255, 255)
    lblNiveau.Font                   = Enum.Font.GothamBold
    lblNiveau.TextScaled             = true
    lblNiveau.RichText               = true
    lblNiveau.Text                   = "Level 0 → 1"

    -- Barre de progression coins (fond)
    local barFond = Instance.new("Frame", fond)
    barFond.Name             = "BarFond"
    barFond.Size             = UDim2.new(1, -10, 0.08, 0)
    barFond.Position         = UDim2.new(0, 5, 0.4, 0)
    barFond.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    barFond.BorderSizePixel  = 0
    Instance.new("UICorner", barFond).CornerRadius = UDim.new(1, 0)

    -- Barre de progression coins (remplissage)
    local barFill = Instance.new("Frame", barFond)
    barFill.Name             = "Fill"
    barFill.Size             = UDim2.new(0, 0, 1, 0)
    barFill.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
    barFill.BorderSizePixel  = 0
    Instance.new("UICorner", barFill).CornerRadius = UDim.new(1, 0)

    -- Coins X / Y
    local lblCoins = Instance.new("TextLabel", fond)
    lblCoins.Name                   = "Coins"
    lblCoins.Size                   = UDim2.new(1, -10, 0.15, 0)
    lblCoins.Position               = UDim2.new(0, 5, 0.5, 2)
    lblCoins.BackgroundTransparency = 1
    lblCoins.TextColor3             = Color3.fromRGB(255, 215, 0)
    lblCoins.Font                   = Enum.Font.Gotham
    lblCoins.TextScaled             = true
    lblCoins.RichText               = true
    lblCoins.Text                   = "💰 — / —"

    -- BR requis
    local lblBR = Instance.new("TextLabel", fond)
    lblBR.Name                   = "BR"
    lblBR.Size                   = UDim2.new(1, -10, 0.15, 0)
    lblBR.Position               = UDim2.new(0, 5, 0.66, 2)
    lblBR.BackgroundTransparency = 1
    lblBR.TextColor3             = Color3.fromRGB(200, 200, 200)
    lblBR.Font                   = Enum.Font.Gotham
    lblBR.TextScaled             = true
    lblBR.RichText               = true
    lblBR.Text                   = "☄️ — requis"

    -- Hint "Click to view"
    local lblHint = Instance.new("TextLabel", fond)
    lblHint.Name                   = "Hint"
    lblHint.Size                   = UDim2.new(1, -10, 0.13, 0)
    lblHint.Position               = UDim2.new(0, 5, 0.85, 2)
    lblHint.BackgroundTransparency = 1
    lblHint.TextColor3             = Color3.fromRGB(150, 150, 150)
    lblHint.Font                   = Enum.Font.Gotham
    lblHint.TextScaled             = true
    lblHint.RichText               = true
    lblHint.Text                   = "<i>🖱 Click to open menu</i>"

    return sg
end

-- ============================================================
-- Met à jour le contenu de la SurfaceGui d'un Board
-- etat = table identique à celle envoyée par RebirthButtonUpdate :
--   rebirthLevel, coinsActuels, coinsRequis, brainRotRequis, manqueBR, multiplicateur
-- ============================================================
local function mettreAJourSurfaceGui(board, etat)
    local sg   = board:FindFirstChild("BoardGui")
    if not sg then return end
    local fond = sg:FindFirstChild("Fond")
    if not fond then return end

    local niveau   = etat.rebirthLevel or 0
    local coinsA   = etat.coinsActuels or 0
    local coinsR   = etat.coinsRequis  or 0
    local rarete   = etat.brainRotRequis or "?"
    local brOk     = etat.manqueBR == nil
    local pct      = coinsR > 0 and math.clamp(coinsA / coinsR, 0, 1) or 0

    -- Niveau
    local lblNiveau = fond:FindFirstChild("Niveau")
    if lblNiveau then
        lblNiveau.Text = "<b>Level " .. niveau .. " → " .. (niveau + 1) .. "</b>"
        if etat.label then
            lblNiveau.Text = "<b>" .. etat.label .. "</b>"
        end
    end

    -- Barre coins
    local barFond = fond:FindFirstChild("BarFond")
    local barFill = barFond and barFond:FindFirstChild("Fill")
    if barFill then
        barFill.Size             = UDim2.new(pct, 0, 1, 0)
        barFill.BackgroundColor3 = pct >= 1
            and Color3.fromRGB(0, 220, 0)
            or  Color3.fromRGB(255, 200, 0)
    end

    -- Coins
    local lblCoins = fond:FindFirstChild("Coins")
    if lblCoins then
        lblCoins.Text = "💰 " .. formaterNombre(coinsA) .. " / " .. formaterNombre(coinsR)
        lblCoins.TextColor3 = pct >= 1
            and Color3.fromRGB(0, 255, 100)
            or  Color3.fromRGB(255, 215, 0)
    end

    -- BR requis
    local lblBR = fond:FindFirstChild("BR")
    if lblBR then
        local check = brOk and "✅" or "❌"
        lblBR.Text       = "☄️ " .. rarete .. "  " .. check
        lblBR.TextColor3 = brOk
            and Color3.fromRGB(100, 255, 100)
            or  Color3.fromRGB(255, 100, 100)
    end

    -- Bordure : orange si prêt à rebirther
    local stroke = fond:FindFirstChildOfClass("UIStroke")
    if stroke then
        stroke.Color = (pct >= 1 and brOk)
            and Color3.fromRGB(255, 215, 0)
            or  Color3.fromRGB(255, 140, 0)
    end
end

-- ============================================================
-- API publique — Init
-- ============================================================

function BoardSystem.Init()
    local bases = Workspace:FindFirstChild("Bases")
    if not bases then
        warn("[BoardSystem] Workspace.Bases introuvable")
        return
    end

    local maxBases      = Config.MaxBases or 6
    local OuvrirRebirth = getOuvrirRebirth()

    for i = 1, maxBases do
        local base  = bases:FindFirstChild("Base_" .. i)
        local bat   = base and base:FindFirstChild("Base")
        local board = bat and bat:FindFirstChild("Board")

        if board then
            -- Créer la SurfaceGui
            creerSurfaceGui(board)

            -- ClickDetector
            local ancien = board:FindFirstChildOfClass("ClickDetector")
            if ancien then ancien:Destroy() end

            local cd = Instance.new("ClickDetector", board)
            cd.MaxActivationDistance = boardCfg.distanceClick

            local capturedIndex = i
            cd.MouseClick:Connect(function(player)
                -- Mettre à jour le bouton avant d'ouvrir
                local RS = getRebirthSystem()
                if RS then pcall(RS.MettreAJourBouton, player) end

                pcall(function() OuvrirRebirth:FireClient(player) end)

                print("[BoardSystem] " .. player.Name
                    .. " → panel Rebirth ouvert (Base_" .. capturedIndex .. ")")
            end)

            print("[BoardSystem] Board configuré → Base_" .. i)
        else
            warn("[BoardSystem] Board introuvable dans Base_" .. i)
        end
    end

    print("[BoardSystem] Init ✓")
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
    local base  = bases:FindFirstChild("Base_" .. baseIndex)
    local bat   = base and base:FindFirstChild("Base")
    local board = bat and bat:FindFirstChild("Board")
    if not board then return end

    mettreAJourSurfaceGui(board, etat or {})
end

return BoardSystem
