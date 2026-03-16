-- StarterPlayer/StarterPlayerScripts/Common/FlowerPotHUD.client.lua
-- DobiGames — Interface plantation, croissance et récolte des pots

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player     = Players.LocalPlayer
local playerGui  = player:WaitForChild("PlayerGui")

-- ============================================================
-- RemoteEvents
-- ============================================================
local OuvrirPot      = ReplicatedStorage:WaitForChild("OuvrirPot", 10)
local PlanterGraine  = ReplicatedStorage:WaitForChild("PlanterGraine", 10)
local DebloquerPot   = ReplicatedStorage:WaitForChild("DebloquerPot", 10)
local InstantGrowPot = ReplicatedStorage:WaitForChild("InstantGrowPot", 10)

if not OuvrirPot or not PlanterGraine or not DebloquerPot then
    warn("[FlowerPotHUD] RemoteEvents not found — aborting")
    return
end

-- ============================================================
-- Construction de la GUI principale
-- ============================================================

local screenGui = Instance.new("ScreenGui")
screenGui.Name             = "FlowerPotHUD"
screenGui.ResetOnSpawn     = false
screenGui.ZIndexBehavior   = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset   = true
screenGui.Parent           = playerGui

-- Frame principale (centrée, modal)
local mainFrame = Instance.new("Frame")
mainFrame.Name                   = "MainFrame"
mainFrame.Size                   = UDim2.new(0, 320, 0, 260)
mainFrame.Position               = UDim2.new(0.5, -160, 0.5, -130)
mainFrame.BackgroundColor3       = Color3.fromRGB(20, 20, 30)
mainFrame.BackgroundTransparency = 0.1
mainFrame.BorderSizePixel        = 0
mainFrame.Visible                = false
mainFrame.Parent                 = screenGui

Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 12)

local uiStroke = Instance.new("UIStroke", mainFrame)
uiStroke.Color     = Color3.fromRGB(80, 200, 120)
uiStroke.Thickness = 2

-- Titre
local titleLabel = Instance.new("TextLabel")
titleLabel.Name                   = "Title"
titleLabel.Size                   = UDim2.new(1, -40, 0, 40)
titleLabel.Position               = UDim2.new(0, 10, 0, 5)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3             = Color3.fromRGB(255, 255, 255)
titleLabel.Font                   = Enum.Font.GothamBold
titleLabel.TextSize               = 18
titleLabel.TextXAlignment         = Enum.TextXAlignment.Left
titleLabel.Text                   = "🌱 Pot"
titleLabel.Parent                 = mainFrame

-- Séparateur
local sep = Instance.new("Frame")
sep.Size              = UDim2.new(1, -20, 0, 1)
sep.Position          = UDim2.new(0, 10, 0, 48)
sep.BackgroundColor3  = Color3.fromRGB(80, 200, 120)
sep.BorderSizePixel   = 0
sep.Parent            = mainFrame

-- Zone de contenu (scrollable si besoin)
local contentFrame = Instance.new("Frame")
contentFrame.Name                   = "Content"
contentFrame.Size                   = UDim2.new(1, -20, 1, -100)
contentFrame.Position               = UDim2.new(0, 10, 0, 55)
contentFrame.BackgroundTransparency = 1
contentFrame.Parent                 = mainFrame

-- Bouton fermer
local closeBtn = Instance.new("TextButton")
closeBtn.Name                   = "CloseBtn"
closeBtn.Size                   = UDim2.new(0, 30, 0, 30)
closeBtn.Position               = UDim2.new(1, -35, 0, 5)
closeBtn.BackgroundColor3       = Color3.fromRGB(180, 40, 40)
closeBtn.Text                   = "✕"
closeBtn.TextColor3             = Color3.new(1, 1, 1)
closeBtn.Font                   = Enum.Font.GothamBold
closeBtn.TextSize               = 16
closeBtn.BorderSizePixel        = 0
closeBtn.Parent                 = mainFrame
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

-- Zone des boutons d'action (bas du panel)
local actionFrame = Instance.new("Frame")
actionFrame.Name                   = "Actions"
actionFrame.Size                   = UDim2.new(1, -20, 0, 44)
actionFrame.Position               = UDim2.new(0, 10, 1, -50)
actionFrame.BackgroundTransparency = 1
actionFrame.Parent                 = mainFrame

-- ============================================================
-- Utilitaires UI
-- ============================================================

local currentPotIndex = nil
local currentMode     = nil

local function clearContent()
    for _, child in ipairs(contentFrame:GetChildren()) do
        child:Destroy()
    end
    for _, child in ipairs(actionFrame:GetChildren()) do
        child:Destroy()
    end
end

local function creerBouton(parent, text, color, position, size, callback)
    local btn = Instance.new("TextButton")
    btn.Size                   = size or UDim2.new(0.45, 0, 1, 0)
    btn.Position               = position or UDim2.new(0, 0, 0, 0)
    btn.BackgroundColor3       = color or Color3.fromRGB(60, 160, 80)
    btn.Text                   = text
    btn.TextColor3             = Color3.new(1, 1, 1)
    btn.Font                   = Enum.Font.GothamBold
    btn.TextSize               = 15
    btn.BorderSizePixel        = 0
    btn.Parent                 = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    if callback then
        btn.MouseButton1Click:Connect(callback)
    end
    return btn
end

local function afficherPanel(visible)
    mainFrame.Visible = visible
    if visible then
        mainFrame.Size = UDim2.new(0, 0, 0, 0)
        mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
        TweenService:Create(mainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Back),
            {
                Size     = UDim2.new(0, 320, 0, 260),
                Position = UDim2.new(0.5, -160, 0.5, -130),
            }):Play()
    end
end

local function fermer()
    TweenService:Create(mainFrame, TweenInfo.new(0.15, Enum.EasingStyle.Quad),
        {
            Size     = UDim2.new(0, 0, 0, 0),
            Position = UDim2.new(0.5, 0, 0.5, 0),
        }):Play()
    task.wait(0.16)
    mainFrame.Visible = false
    currentPotIndex   = nil
    currentMode       = nil
end

closeBtn.MouseButton1Click:Connect(fermer)

-- ============================================================
-- Mode : Plantation (inventaire graines)
-- ============================================================
local GRAINE_ORDER = { "COMMON", "RARE", "EPIC", "LEGENDARY" }
local GRAINE_ICONES = { COMMON="🌱", RARE="🌿", EPIC="🌸", LEGENDARY="🌟" }

local function afficherMenuPlanter(potIndex, grainesInv)
    clearContent()
    titleLabel.Text = "🌱 POT " .. potIndex .. " — Plant a Seed"

    local layout = Instance.new("UIListLayout", contentFrame)
    layout.SortOrder       = Enum.SortOrder.LayoutOrder
    layout.Padding         = UDim.new(0, 6)

    local hasAny = false
    for _, rarete in ipairs(GRAINE_ORDER) do
        local count = grainesInv[rarete] or 0
        hasAny = hasAny or count > 0

        local row = Instance.new("Frame")
        row.Size              = UDim2.new(1, 0, 0, 38)
        row.BackgroundColor3  = Color3.fromRGB(30, 30, 45)
        row.BorderSizePixel   = 0
        row.LayoutOrder       = 1
        row.Parent            = contentFrame
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

        local icone = GRAINE_ICONES[rarete] or "🌱"

        local nomLbl = Instance.new("TextLabel")
        nomLbl.Size                   = UDim2.new(0.55, 0, 1, 0)
        nomLbl.Position               = UDim2.new(0, 8, 0, 0)
        nomLbl.BackgroundTransparency = 1
        nomLbl.Text                   = icone .. " " .. rarete
            .. "  ×" .. count
        nomLbl.TextColor3             = Color3.fromRGB(220, 220, 220)
        nomLbl.Font                   = Enum.Font.Gotham
        nomLbl.TextSize               = 14
        nomLbl.TextXAlignment         = Enum.TextXAlignment.Left
        nomLbl.Parent                 = row

        if count > 0 then
            local plantBtn = Instance.new("TextButton")
            plantBtn.Size              = UDim2.new(0, 80, 0, 26)
            plantBtn.Position          = UDim2.new(1, -88, 0.5, -13)
            plantBtn.BackgroundColor3  = Color3.fromRGB(60, 160, 80)
            plantBtn.Text              = "Plant"
            plantBtn.TextColor3        = Color3.new(1, 1, 1)
            plantBtn.Font              = Enum.Font.GothamBold
            plantBtn.TextSize          = 13
            plantBtn.BorderSizePixel   = 0
            plantBtn.Parent            = row
            Instance.new("UICorner", plantBtn).CornerRadius = UDim.new(0, 6)

            local capturedRarete = rarete
            plantBtn.MouseButton1Click:Connect(function()
                PlanterGraine:FireServer(potIndex, capturedRarete)
                fermer()
            end)
        else
            local dash = Instance.new("TextLabel")
            dash.Size                   = UDim2.new(0, 80, 0, 26)
            dash.Position               = UDim2.new(1, -88, 0.5, -13)
            dash.BackgroundTransparency = 1
            dash.Text                   = "—"
            dash.TextColor3             = Color3.fromRGB(100, 100, 100)
            dash.Font                   = Enum.Font.Gotham
            dash.TextSize               = 14
            dash.TextXAlignment         = Enum.TextXAlignment.Center
            dash.Parent                 = row
        end
    end

    -- Hint si inventaire vide
    if not hasAny then
        local hint = Instance.new("TextLabel")
        hint.Size                   = UDim2.new(1, 0, 0, 30)
        hint.BackgroundTransparency = 1
        hint.Text                   = "💡 Collect RARE+ Brain Rots to get seeds!"
        hint.TextColor3             = Color3.fromRGB(180, 180, 120)
        hint.Font                   = Enum.Font.Gotham
        hint.TextSize               = 13
        hint.TextXAlignment         = Enum.TextXAlignment.Center
        hint.Parent                 = contentFrame
    end

    -- Bouton fermer en bas
    creerBouton(actionFrame, "Close",
        Color3.fromRGB(140, 40, 40),
        UDim2.new(0.5, -50, 0, 0),
        UDim2.new(0, 100, 1, 0),
        fermer)
end

-- ============================================================
-- Mode : Infos croissance
-- ============================================================

local function formatTemps(secs)
    secs = math.max(0, math.floor(secs))
    local m = math.floor(secs / 60)
    local s = secs % 60
    if m > 0 then
        return m .. "m " .. s .. "s"
    else
        return s .. "s"
    end
end

local function afficherMenuInfos(potIndex, infos)
    clearContent()
    local graine    = infos.graine    or "?"
    local stage     = infos.stage     or 0
    local tRestant  = infos.tempsRestant or 0
    local prixInst  = infos.prixInstant or 35

    local icone = GRAINE_ICONES[graine] or "🌿"

    if stage >= 4 then
        titleLabel.Text = icone .. " POT " .. potIndex .. " — MATURE! 🌟"
    else
        titleLabel.Text = icone .. " POT " .. potIndex .. " — Growing..."
    end

    -- Ligne rareté
    local rarLbl = Instance.new("TextLabel")
    rarLbl.Size                   = UDim2.new(1, 0, 0, 28)
    rarLbl.BackgroundTransparency = 1
    rarLbl.Text                   = icone .. " " .. graine .. " Seed"
    rarLbl.TextColor3             = Color3.fromRGB(220, 220, 220)
    rarLbl.Font                   = Enum.Font.GothamBold
    rarLbl.TextSize               = 16
    rarLbl.TextXAlignment         = Enum.TextXAlignment.Left
    rarLbl.Parent                 = contentFrame

    -- Barre de progression stage
    local stageFrame = Instance.new("Frame")
    stageFrame.Size              = UDim2.new(1, 0, 0, 28)
    stageFrame.BackgroundColor3  = Color3.fromRGB(30, 30, 45)
    stageFrame.BorderSizePixel   = 0
    stageFrame.Parent            = contentFrame
    Instance.new("UICorner", stageFrame).CornerRadius = UDim.new(0, 6)

    -- Remplissage barre
    local fill = Instance.new("Frame")
    fill.Size             = UDim2.new(math.min(stage / 4, 1), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(80, 200, 120)
    fill.BorderSizePixel  = 0
    fill.Parent           = stageFrame
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 6)

    local stageLbl = Instance.new("TextLabel")
    stageLbl.Size                   = UDim2.new(1, 0, 1, 0)
    stageLbl.BackgroundTransparency = 1
    stageLbl.Text                   = "Stage " .. stage .. " / 4"
    stageLbl.TextColor3             = Color3.new(1, 1, 1)
    stageLbl.Font                   = Enum.Font.GothamBold
    stageLbl.TextSize               = 13
    stageLbl.TextXAlignment         = Enum.TextXAlignment.Center
    stageLbl.Parent                 = stageFrame

    -- Temps restant
    if stage < 4 then
        local timeLbl = Instance.new("TextLabel")
        timeLbl.Size                   = UDim2.new(1, 0, 0, 28)
        timeLbl.BackgroundTransparency = 1
        timeLbl.Text                   = "⏱ Ready in: " .. formatTemps(tRestant)
        timeLbl.TextColor3             = Color3.fromRGB(180, 230, 255)
        timeLbl.Font                   = Enum.Font.Gotham
        timeLbl.TextSize               = 14
        timeLbl.TextXAlignment         = Enum.TextXAlignment.Left
        timeLbl.Parent                 = contentFrame
    else
        local readyLbl = Instance.new("TextLabel")
        readyLbl.Size                   = UDim2.new(1, 0, 0, 28)
        readyLbl.BackgroundTransparency = 1
        readyLbl.Text                   = "✅ Ready to harvest!"
        readyLbl.TextColor3             = Color3.fromRGB(100, 255, 120)
        readyLbl.Font                   = Enum.Font.GothamBold
        readyLbl.TextSize               = 14
        readyLbl.TextXAlignment         = Enum.TextXAlignment.Left
        readyLbl.Parent                 = contentFrame
    end

    -- Layout vertical
    local layout = Instance.new("UIListLayout", contentFrame)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding   = UDim.new(0, 6)

    -- Boutons d'action
    if stage >= 4 then
        creerBouton(actionFrame, "🌟 Harvest",
            Color3.fromRGB(200, 160, 0),
            UDim2.new(0, 0, 0, 0),
            UDim2.new(0.5, -4, 1, 0),
            function()
                -- Le serveur gère la récolte via ProximityPrompt
                -- Ici on ferme juste le panel (le joueur doit approcher le pot)
                fermer()
            end)
    else
        creerBouton(actionFrame, "⚡ Instant Grow\n" .. prixInst .. " R$",
            Color3.fromRGB(100, 40, 180),
            UDim2.new(0, 0, 0, 0),
            UDim2.new(0.5, -4, 1, 0),
            function()
                InstantGrowPot:FireServer(potIndex)
                fermer()
            end)
    end

    creerBouton(actionFrame, "Close",
        Color3.fromRGB(140, 40, 40),
        UDim2.new(0.5, 4, 0, 0),
        UDim2.new(0.5, -4, 1, 0),
        fermer)
end

-- ============================================================
-- Mode : Déblocage
-- ============================================================

local Config = require(ReplicatedStorage:WaitForChild("Specialized"):WaitForChild("GameConfig"))

local function afficherMenuDebloque(potIndex)
    clearContent()
    titleLabel.Text = "🔒 POT " .. potIndex .. " — Locked"

    local FPConfig  = Config.FlowerPotConfig
    local potCfg    = FPConfig and FPConfig.pots and FPConfig.pots[potIndex]

    local desc = Instance.new("TextLabel")
    desc.Size                   = UDim2.new(1, 0, 0, 60)
    desc.BackgroundTransparency = 1
    desc.TextColor3             = Color3.fromRGB(220, 220, 220)
    desc.Font                   = Enum.Font.Gotham
    desc.TextSize               = 15
    desc.TextWrapped            = true
    desc.TextXAlignment         = Enum.TextXAlignment.Center
    desc.Parent                 = contentFrame

    if potCfg then
        if potCfg.prixCoins and potCfg.prixCoins > 0 then
            desc.Text = "Unlock for " .. potCfg.prixCoins .. " 💰"
        elseif potCfg.prixRobux and potCfg.prixRobux > 0 then
            desc.Text = "Unlock for " .. potCfg.prixRobux .. " R$"
        else
            desc.Text = "This pot is locked."
        end
    else
        desc.Text = "Pot " .. potIndex .. " is locked."
    end

    -- Boutons Unlock + Cancel
    creerBouton(actionFrame, "Unlock",
        Color3.fromRGB(60, 160, 80),
        UDim2.new(0, 0, 0, 0),
        UDim2.new(0.5, -4, 1, 0),
        function()
            DebloquerPot:FireServer(potIndex)
            fermer()
        end)

    creerBouton(actionFrame, "Cancel",
        Color3.fromRGB(140, 40, 40),
        UDim2.new(0.5, 4, 0, 0),
        UDim2.new(0.5, -4, 1, 0),
        fermer)
end

-- ============================================================
-- Écouter OuvrirPot depuis le serveur
-- ============================================================

OuvrirPot.OnClientEvent:Connect(function(potIndex, mode, extraData)
    currentPotIndex = potIndex
    currentMode     = mode

    if mode == "planter" then
        afficherMenuPlanter(potIndex, extraData or {})
    elseif mode == "infos" then
        afficherMenuInfos(potIndex, extraData or {})
    elseif mode == "debloque" then
        afficherMenuDebloque(potIndex)
    end

    afficherPanel(true)
end)

-- Fermer si on clique ailleurs
screenGui.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        -- Vérifier si le clic est hors du panel
        -- (simple vérification : si mainFrame invisible, rien à faire)
        if not mainFrame.Visible then return end
        -- On laisse les clics passer (ProximityPrompt les gère)
    end
end)

print("[FlowerPotHUD] ✓ Initialized")
