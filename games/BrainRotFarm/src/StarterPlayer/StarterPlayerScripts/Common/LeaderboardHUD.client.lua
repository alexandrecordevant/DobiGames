-- StarterPlayerScripts/Common/LeaderboardHUD.client.lua
-- DobiGames — Mini leaderboard HUD (coin-right, 6 rows, local player highlight)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer
local playerGui   = localPlayer:WaitForChild("PlayerGui")

-- ============================================================
-- FormatCoins — 450 / 12.1k / 1.2M
-- ============================================================

local function FormatCoins(n)
    n = math.floor(n or 0)
    if n >= 1_000_000 then
        return string.format("%.1fM", n / 1_000_000)
    elseif n >= 1_000 then
        return string.format("%.1fk", n / 1_000)
    else
        return tostring(n)
    end
end

-- ============================================================
-- Constantes UI
-- ============================================================

local PANEL_SIZE     = UDim2.new(0, 220, 0, 310)
local PANEL_POS      = UDim2.new(1, -235, 1, -325)
local ROW_HEIGHT     = 40
local MAX_ROWS       = 6

local COLOR_BG       = Color3.fromRGB(15, 15, 20)
local COLOR_BG_ALT   = Color3.fromRGB(22, 22, 30)
local COLOR_LOCAL    = Color3.fromRGB(40, 40, 10)
local COLOR_BORDER   = Color3.fromRGB(60, 60, 80)
local COLOR_TITLE    = Color3.fromRGB(255, 210, 50)
local COLOR_TEXT     = Color3.fromRGB(220, 220, 220)
local COLOR_DIM      = Color3.fromRGB(130, 130, 150)
local COLOR_GOLD     = Color3.fromRGB(255, 200, 50)
local COLOR_SILVER   = Color3.fromRGB(190, 190, 210)
local COLOR_BRONZE   = Color3.fromRGB(200, 130, 70)

local COLOR_FLASH_UP = Color3.fromRGB(50, 200, 80)
local COLOR_FLASH_DN = Color3.fromRGB(200, 60, 60)

local RANG_COULEURS  = { COLOR_GOLD, COLOR_SILVER, COLOR_BRONZE }

-- ============================================================
-- Création du ScreenGui
-- ============================================================

local screenGui = Instance.new("ScreenGui")
screenGui.Name            = "LeaderboardHUD"
screenGui.ResetOnSpawn    = false
screenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder    = 5
screenGui.Parent          = playerGui

-- Panneau principal
local panel = Instance.new("Frame")
panel.Name            = "Panel"
panel.Size            = PANEL_SIZE
panel.Position        = PANEL_POS
panel.BackgroundColor3 = COLOR_BG
panel.BorderSizePixel = 0
panel.ClipsDescendants = true
panel.Parent          = screenGui

-- Bordure arrondie
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent       = panel

-- Liseré de bordure
local stroke = Instance.new("UIStroke")
stroke.Color     = COLOR_BORDER
stroke.Thickness = 1.5
stroke.Parent    = panel

-- Titre
local titre = Instance.new("TextLabel")
titre.Name              = "Titre"
titre.Size              = UDim2.new(1, 0, 0, 32)
titre.Position          = UDim2.new(0, 0, 0, 0)
titre.BackgroundColor3  = Color3.fromRGB(25, 20, 5)
titre.BorderSizePixel   = 0
titre.Text              = "🏆 Leaderboard"
titre.TextColor3        = COLOR_TITLE
titre.TextScaled        = true
titre.Font              = Enum.Font.GothamBold
titre.Parent            = panel

local titreCorner = Instance.new("UICorner")
titreCorner.CornerRadius = UDim.new(0, 8)
titreCorner.Parent       = titre

-- ============================================================
-- Création des 6 lignes
-- ============================================================

local rows = {}   -- rows[i] = { frame, rang, nom, coins, icones, youTag }

-- Layout par ligne (panel width = 220px) :
-- Rang:   x=4,  w=26
-- Nom:    x=32, w=76
-- Coins:  x=110, w=46 (right de l'espace central)
-- Icones: x=158, w=36 (emojis upgrades MAX)
-- Coins et icones → right side

for i = 1, MAX_ROWS do
    local y = 32 + (i - 1) * ROW_HEIGHT

    local row = Instance.new("Frame")
    row.Name             = "Row" .. i
    row.Size             = UDim2.new(1, 0, 0, ROW_HEIGHT)
    row.Position         = UDim2.new(0, 0, 0, y)
    row.BackgroundColor3 = (i % 2 == 0) and COLOR_BG_ALT or COLOR_BG
    row.BorderSizePixel  = 0
    row.Parent           = panel

    -- Rang (ex: #1, #2…)
    local rang = Instance.new("TextLabel")
    rang.Name            = "Rang"
    rang.Size            = UDim2.new(0, 26, 1, 0)
    rang.Position        = UDim2.new(0, 4, 0, 0)
    rang.BackgroundTransparency = 1
    rang.Text            = "#" .. i
    rang.TextColor3      = COLOR_DIM
    rang.TextScaled      = true
    rang.Font            = Enum.Font.GothamBold
    rang.Parent          = row

    -- Nom du joueur
    local nom = Instance.new("TextLabel")
    nom.Name             = "Nom"
    nom.Size             = UDim2.new(0, 80, 1, 0)
    nom.Position         = UDim2.new(0, 32, 0, 0)
    nom.BackgroundTransparency = 1
    nom.Text             = "—"
    nom.TextColor3       = COLOR_TEXT
    nom.TextScaled       = true
    nom.Font             = Enum.Font.Gotham
    nom.TextXAlignment   = Enum.TextXAlignment.Left
    nom.TextTruncate     = Enum.TextTruncate.AtEnd
    nom.Parent           = row

    -- Coins
    local coins = Instance.new("TextLabel")
    coins.Name           = "Coins"
    coins.Size           = UDim2.new(0, 48, 1, 0)
    coins.Position       = UDim2.new(1, -90, 0, 0)
    coins.BackgroundTransparency = 1
    coins.Text           = "0"
    coins.TextColor3     = COLOR_TITLE
    coins.TextScaled     = true
    coins.Font           = Enum.Font.GothamBold
    coins.TextXAlignment = Enum.TextXAlignment.Right
    coins.Parent         = row

    -- Icônes upgrades MAX (ex: 🚜💧⚡)
    local icones = Instance.new("TextLabel")
    icones.Name           = "Icones"
    icones.Size           = UDim2.new(0, 38, 1, 0)
    icones.Position       = UDim2.new(1, -40, 0, 0)
    icones.BackgroundTransparency = 1
    icones.Text           = ""
    icones.TextColor3     = Color3.fromRGB(255, 255, 255)
    icones.TextScaled     = true
    icones.Font           = Enum.Font.Gotham
    icones.TextXAlignment = Enum.TextXAlignment.Left
    icones.Parent         = row

    -- Tag "▶ YOU"
    local youTag = Instance.new("TextLabel")
    youTag.Name          = "YouTag"
    youTag.Size          = UDim2.new(0, 36, 0, 14)
    youTag.Position      = UDim2.new(0, 32, 0, 2)
    youTag.BackgroundTransparency = 1
    youTag.Text          = "▶ YOU"
    youTag.TextColor3    = COLOR_GOLD
    youTag.TextScaled    = true
    youTag.Font          = Enum.Font.GothamBold
    youTag.Visible       = false
    youTag.Parent        = row

    rows[i] = {
        frame  = row,
        rang   = rang,
        nom    = nom,
        coins  = coins,
        icones = icones,
        youTag = youTag,
    }
end

-- Footer (timestamp dernière mise à jour)
local footer = Instance.new("TextLabel")
footer.Name              = "Footer"
footer.Size              = UDim2.new(1, 0, 0, 18)
footer.Position          = UDim2.new(0, 0, 1, -18)
footer.BackgroundTransparency = 1
footer.Text              = "Mise à jour…"
footer.TextColor3        = COLOR_DIM
footer.TextScaled        = true
footer.Font              = Enum.Font.Gotham
footer.Parent            = panel

-- ============================================================
-- État local — rangs précédents pour détecter les changements
-- ============================================================

local previousRanks = {}   -- previousRanks[playerName] = rangIndex (1-6)

-- ============================================================
-- Flash d'une ligne (rank up = vert, rank down = rouge)
-- ============================================================

local function flashRow(rowFrame, couleur)
    local orig = rowFrame.BackgroundColor3
    rowFrame.BackgroundColor3 = couleur
    TweenService:Create(rowFrame,
        TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { BackgroundColor3 = orig }
    ):Play()
end

-- ============================================================
-- Mise à jour des lignes depuis un classement
-- classement = { { name, coins, rebirth }, ... } trié desc
-- ============================================================

local function mettreAJourLignes(classement)
    local newRanks = {}

    for i = 1, MAX_ROWS do
        local r     = rows[i]
        local entry = classement[i]

        if entry then
            newRanks[entry.name] = i

            -- Couleur de rang
            local couleurRang = RANG_COULEURS[i] or COLOR_DIM
            r.rang.Text       = "#" .. i
            r.rang.TextColor3 = couleurRang

            -- Nom (champ "name" envoyé par le serveur)
            r.nom.Text        = entry.name

            -- Coins formatés
            r.coins.Text      = FormatCoins(entry.coins)

            -- Icônes upgrades MAX
            r.icones.Text     = entry.icones or ""

            -- Highlight joueur local
            local isLocal = (entry.name == localPlayer.Name)
            r.frame.BackgroundColor3 = isLocal
                and COLOR_LOCAL
                or ((i % 2 == 0) and COLOR_BG_ALT or COLOR_BG)
            if isLocal then
                r.nom.Size       = UDim2.new(0, 58, 1, 0)  -- réduit pour le tag YOU
                r.youTag.Visible = true
            else
                r.nom.Size       = UDim2.new(0, 80, 1, 0)
                r.youTag.Visible = false
            end

            -- Flash si le rang a changé
            local prevRang = previousRanks[entry.name]
            if prevRang and prevRang ~= i then
                flashRow(r.frame, (i < prevRang) and COLOR_FLASH_UP or COLOR_FLASH_DN)
            end

            r.frame.Visible = true
        else
            -- Ligne vide
            r.rang.Text      = "#" .. i
            r.rang.TextColor3 = COLOR_DIM
            r.nom.Text        = "—"
            r.coins.Text      = "0"
            r.icones.Text     = ""
            r.youTag.Visible  = false
            r.nom.Size        = UDim2.new(0, 80, 1, 0)
            r.frame.BackgroundColor3 = (i % 2 == 0) and COLOR_BG_ALT or COLOR_BG
            r.frame.Visible   = true
        end
    end

    previousRanks = newRanks
end

-- ============================================================
-- S'assurer que le joueur local est toujours visible
-- (peut être en dehors du top-6)
-- ============================================================

local function assurerJoueurLocal(classement)
    -- Chercher le rang réel du joueur local
    local rangLocal = nil
    for i, entry in ipairs(classement) do
        if entry.name == localPlayer.Name then
            rangLocal = i
            break
        end
    end

    if not rangLocal or rangLocal <= MAX_ROWS then return end

    -- Le joueur n'est pas dans le top-6 : remplacer la dernière ligne
    local entry = classement[rangLocal]
    local r     = rows[MAX_ROWS]
    r.rang.Text       = "#" .. rangLocal
    r.rang.TextColor3 = COLOR_DIM
    r.nom.Text        = entry.name
    r.coins.Text      = FormatCoins(entry.coins)
    r.frame.BackgroundColor3 = COLOR_LOCAL
    r.nom.Size        = UDim2.new(0, 68, 1, 0)
    r.youTag.Visible  = true
end

-- ============================================================
-- Écoute de l'event LeaderboardUpdate
-- payload = { classement = {{name, coins, rebirth},...}, timestamp = number }
-- ============================================================

local function onLeaderboardUpdate(payload)
    if type(payload) ~= "table" or not payload.classement then return end

    mettreAJourLignes(payload.classement)
    assurerJoueurLocal(payload.classement)

    -- Footer timestamp
    local elapsed = math.floor(os.clock())  -- approximation locale
    footer.Text = "⟳ " .. os.date("%H:%M:%S")
end

-- Attendre que le RemoteEvent soit créé par le serveur
task.spawn(function()
    local ok, leaderboardUpdate = pcall(function()
        return ReplicatedStorage:WaitForChild("LeaderboardUpdate", 15)
    end)
    if ok and leaderboardUpdate then
        leaderboardUpdate.OnClientEvent:Connect(onLeaderboardUpdate)
    else
        footer.Text = "⚠ Leaderboard indisponible"
    end
end)

-- ============================================================
-- Animation d'entrée (slide depuis la droite)
-- ============================================================

panel.Position = UDim2.new(1, 20, 1, -305)
task.wait(0.5)
TweenService:Create(panel,
    TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
    { Position = PANEL_POS }
):Play()
