-- ServerScriptService/LeaderboardSystem.lua
-- LavaTower — Classement $/sec
--   · leaderstats Roblox  → tableau de score par serveur (touche Tab)
--   · OrderedDataStore    → billboard in-world cross-serveur, top 200, scroll manuel

local Players             = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local Workspace           = game:GetService("Workspace")
local DataStoreService    = game:GetService("DataStoreService")

local Logger      = require(ServerScriptService.SharedLib.Server.Logger)
local FormatCoins = require(ReplicatedStorage.SharedLib.Shared.FormatNumber).format

local LeaderboardSystem = {}

-- ============================================================
-- Config
-- ============================================================

local MAX_RANGS          = 200
local PAGE_SIZE          = 100
local PUSH_COOLDOWN_SEC  = 60
local REFRESH_GLOBAL_SEC = 60

local PIXELS_PER_STUD = 50
local ROW_HEIGHT_PX   = 80    -- hauteur de chaque ligne  → taille du texte
local TITLE_HEIGHT_PX = 90    -- hauteur du titre
local SEP_HEIGHT_PX   = 3

-- ============================================================
-- Couleurs — dark navy / or / argent / bronze
-- ============================================================

local GOLD         = Color3.fromRGB(255, 215,   0)
local SILVER       = Color3.fromRGB(200, 200, 200)
local BRONZE       = Color3.fromRGB(205, 127,  50)
local TEXT_DEFAULT = Color3.fromRGB(220, 220, 220)
local BG_A         = Color3.fromRGB( 12,  12,  38)
local BG_B         = Color3.fromRGB( 18,  18,  52)
local EMPTY_COLOR  = Color3.fromRGB( 90,  90, 110)

local RANK_COLOR = { GOLD, SILVER, BRONZE }

-- ============================================================
-- Forward declaration
-- ============================================================

local actualiserAffichage

-- ============================================================
-- OrderedDataStore global (cross-serveur)
-- ============================================================

local orderedDS  = nil
local globalTop  = {}
local nameCache  = {}
local lastPushAt = {}

local function getDS()
    if not orderedDS then
        local ok, ds = pcall(DataStoreService.GetOrderedDataStore,
            DataStoreService, "LT_TopIncSec_v1")
        orderedDS = ok and ds or nil
    end
    return orderedDS
end

local function resoudreName(userId)
    if nameCache[userId] then return nameCache[userId] end
    local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
    local result   = (ok and name) or ("User#" .. userId)
    nameCache[userId] = result
    return result
end

local function rafraichirTopGlobal()
    local ds = getDS()
    if not ds then return end

    task.spawn(function()
        local ok, pages = pcall(ds.GetSortedAsync, ds, false, PAGE_SIZE)
        if not ok or not pages then
            Logger.warn("Leaderboard", "GetSortedAsync échoué : %s", tostring(pages))
            return
        end

        local top = {}
        local function ajouterPage(items)
            for _, entry in ipairs(items) do
                local uid    = tonumber(entry.key)
                local income = entry.value
                if uid and income > 0 then
                    table.insert(top, { name = resoudreName(uid), income = income })
                end
            end
        end

        ajouterPage(pages:GetCurrentPage())

        if not pages.IsFinished and #top < MAX_RANGS then
            local ok2 = pcall(pages.AdvanceToNextPageAsync, pages)
            if ok2 then ajouterPage(pages:GetCurrentPage()) end
        end

        globalTop = top
        task.defer(function() pcall(actualiserAffichage) end)
        Logger.debug("Leaderboard", "Top global rechargé : %d entrées", #top)
    end)
end

local function pousserScore(player, incSec)
    local uid = player.UserId
    local now = os.clock()
    if lastPushAt[uid] and (now - lastPushAt[uid]) < PUSH_COOLDOWN_SEC then return end
    lastPushAt[uid] = now
    local ds = getDS()
    if not ds then return end
    task.spawn(function()
        local ok, err = pcall(ds.SetAsync, ds, tostring(uid), math.max(incSec, 0))
        if not ok then
            Logger.warn("Leaderboard", "SetAsync échoué pour %s : %s", player.Name, tostring(err))
        end
    end)
end

-- ============================================================
-- Leaderstats Roblox (par serveur)
-- ============================================================

local function initLeaderstats(player)
    if player:FindFirstChild("leaderstats") then return end
    local ls  = Instance.new("Folder"); ls.Name = "leaderstats"; ls.Parent = player
    local val = Instance.new("IntValue"); val.Name = "$/sec"; val.Value = 0; val.Parent = ls
end

local function setLeaderstats(player, incSec)
    local ls  = player:FindFirstChild("leaderstats")
    local val = ls and ls:FindFirstChild("$/sec")
    if val then val.Value = incSec end
end

-- ============================================================
-- Billboard in-world — Workspace.Leaderboard.Leaderbord
-- ============================================================

local function getLeaderbordPart()
    local model = Workspace:FindFirstChild("Leaderboard")
    return model and model:FindFirstChild("Leaderbord")
end

local function creerSurfaceGui(part)
    local ancien = part:FindFirstChild("LeaderboardGui")
    if ancien then ancien:Destroy() end

    local gui              = Instance.new("SurfaceGui")
    gui.Name               = "LeaderboardGui"
    gui.Face               = Enum.NormalId.Front
    gui.SizingMode         = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud      = PIXELS_PER_STUD
    gui.AlwaysOnTop        = false
    gui.LightInfluence     = 0
    gui.Active             = true   -- permet les interactions souris
    gui.Parent             = part
    return gui
end

local function creerContenu(gui)
    -- Fond principal avec dégradé navy
    local bg                      = Instance.new("Frame")
    bg.Name                       = "BG"
    bg.Size                       = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3           = BG_A
    bg.BackgroundTransparency     = 0.15
    bg.BorderSizePixel            = 0
    bg.Active                     = true
    bg.Parent                     = gui

    local grad                    = Instance.new("UIGradient")
    grad.Rotation                 = 90
    grad.Color                    = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 20, 60)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(5,  5,  20)),
    })
    grad.Parent = bg

    -- Titre
    local title                   = Instance.new("TextLabel")
    title.Name                    = "Title"
    title.Size                    = UDim2.new(1, 0, 0, TITLE_HEIGHT_PX)
    title.Position                = UDim2.new(0, 0, 0, 0)
    title.BackgroundColor3        = Color3.fromRGB(15, 15, 50)
    title.BackgroundTransparency  = 0
    title.BorderSizePixel         = 0
    title.Text                    = "🏆 Global Leaderboard"
    title.TextColor3              = GOLD
    title.TextScaled              = true
    title.Font                    = Enum.Font.GothamBold
    title.TextXAlignment          = Enum.TextXAlignment.Left
    title.Parent                  = bg
    local tp = Instance.new("UIPadding"); tp.PaddingLeft = UDim.new(0.04, 0); tp.Parent = title

    -- Séparateur doré
    local sep                     = Instance.new("Frame")
    sep.Name                      = "Sep"
    sep.Size                      = UDim2.new(1, 0, 0, SEP_HEIGHT_PX)
    sep.Position                  = UDim2.new(0, 0, 0, TITLE_HEIGHT_PX)
    sep.BackgroundColor3          = GOLD
    sep.BackgroundTransparency    = 0.4
    sep.BorderSizePixel           = 0
    sep.Parent                    = bg

    -- ScrollingFrame avec scroll manuel activé
    local scrollTop               = TITLE_HEIGHT_PX + SEP_HEIGHT_PX
    local scroll                  = Instance.new("ScrollingFrame")
    scroll.Name                   = "Scroll"
    scroll.Size                   = UDim2.new(1, 0, 1, -scrollTop)
    scroll.Position               = UDim2.new(0, 0, 0, scrollTop)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel        = 0
    scroll.Active                 = true    -- reçoit les événements souris
    scroll.ScrollingEnabled       = false   -- géré par LeaderboardScrollClient
    scroll.ScrollBarThickness     = 12      -- barre dorée visible
    scroll.ScrollBarImageColor3   = GOLD
    scroll.CanvasSize             = UDim2.new(0, 0, 0, 0)
    scroll.ClipsDescendants       = true
    scroll.Parent                 = bg

    return bg
end

actualiserAffichage = function()
    local part = getLeaderbordPart()
    if not part then
        Logger.warn("Leaderboard", "Part 'Leaderbord' introuvable dans Workspace.Leaderboard")
        return
    end

    local gui = part:FindFirstChild("LeaderboardGui")
    if not gui then gui = creerSurfaceGui(part) end
    local bg  = gui:FindFirstChild("BG")
    if not bg then bg = creerContenu(gui) end

    local scroll = bg:FindFirstChild("Scroll")
    if not scroll then
        bg:Destroy()
        bg     = creerContenu(gui)
        scroll = bg:FindFirstChild("Scroll")
    end

    -- Supprimer les anciennes lignes
    for _, child in ipairs(scroll:GetChildren()) do
        child:Destroy()
    end

    local count = MAX_RANGS   -- toujours 200 lignes pour que le scroll soit actif
    scroll.CanvasSize = UDim2.new(0, 0, 0, count * ROW_HEIGHT_PX)

    for i = 1, count do
        local entry    = globalTop[i]
        local rankColor = RANK_COLOR[i] or TEXT_DEFAULT
        local hasEntry  = entry and entry.income > 0

        -- Conteneur de la ligne
        local row                  = Instance.new("Frame")
        row.Name                   = "Row" .. i
        row.Size                   = UDim2.new(1, 0, 0, ROW_HEIGHT_PX)
        row.Position               = UDim2.new(0, 0, 0, (i - 1) * ROW_HEIGHT_PX)
        row.BackgroundColor3       = (i % 2 == 0) and BG_B or BG_A
        row.BackgroundTransparency = 0
        row.BorderSizePixel        = 0
        row.Parent                 = scroll

        -- Colonne gauche : rang + pseudo
        local lblLeft              = Instance.new("TextLabel")
        lblLeft.Size               = UDim2.new(0.62, 0, 1, 0)
        lblLeft.Position           = UDim2.new(0, 0, 0, 0)
        lblLeft.BackgroundTransparency = 1
        lblLeft.TextScaled         = true
        lblLeft.Font               = Enum.Font.GothamBold
        lblLeft.TextXAlignment     = Enum.TextXAlignment.Left
        lblLeft.TextColor3         = hasEntry and rankColor or EMPTY_COLOR
        lblLeft.Text               = hasEntry
            and string.format("#%d  %s", i, entry.name)
            or  ("#" .. i .. "   —")
        lblLeft.Parent             = row
        local padL = Instance.new("UIPadding"); padL.PaddingLeft = UDim.new(0, 16); padL.Parent = lblLeft

        -- Colonne droite : $/sec
        local lblRight             = Instance.new("TextLabel")
        lblRight.Size              = UDim2.new(0.38, -16, 1, 0)
        lblRight.Position          = UDim2.new(0.62, 0, 0, 0)
        lblRight.BackgroundTransparency = 1
        lblRight.TextScaled        = true
        lblRight.Font              = Enum.Font.GothamBold
        lblRight.TextXAlignment    = Enum.TextXAlignment.Right
        lblRight.TextColor3        = hasEntry and rankColor or EMPTY_COLOR
        lblRight.Text              = hasEntry
            and ("$" .. FormatCoins(entry.income) .. "/s")
            or  "—"
        lblRight.Parent            = row
        local padR = Instance.new("UIPadding"); padR.PaddingRight = UDim.new(0, 16); padR.Parent = lblRight
    end

    Logger.debug("Leaderboard", "Billboard mis à jour : %d lignes", count)
end

-- ============================================================
-- API publique
-- ============================================================

function LeaderboardSystem.MettreAJour(player, playerData)
    local incSec = math.floor((playerData.coinsParMinute or 0) / 60)
    setLeaderstats(player, incSec)
    pousserScore(player, incSec)
    Logger.debug("Leaderboard", "%s → %d $/sec", player.Name, incSec)
end

function LeaderboardSystem.Init()
    Players.PlayerAdded:Connect(function(player)
        initLeaderstats(player)
        Logger.info("Leaderboard", "leaderstats créés pour %s", player.Name)
    end)

    Players.PlayerRemoving:Connect(function(player)
        lastPushAt[player.UserId] = nil
    end)

    for _, player in ipairs(Players:GetPlayers()) do
        initLeaderstats(player)
    end

    task.defer(function() pcall(actualiserAffichage) end)

    task.spawn(function()
        while true do
            rafraichirTopGlobal()
            task.wait(REFRESH_GLOBAL_SEC)
        end
    end)

    Logger.info("Leaderboard", "LeaderboardSystem initialisé ✓")
end

return LeaderboardSystem
