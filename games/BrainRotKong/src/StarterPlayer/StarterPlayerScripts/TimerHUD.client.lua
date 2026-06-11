-- StarterPlayerScripts/TimerHUD.client.lua
-- Widget bottom-right : Prochain Event + Prochain Spécial (MYTHIC/SECRET/Arbre)
-- Poll serveur toutes les 5s, décompte local entre les polls

local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GetTimerData = RS:WaitForChild("GetTimerData")

-- ============================================================
-- ScreenGui
-- ============================================================
local sg = Instance.new("ScreenGui")
sg.Name           = "TimerHUD"
sg.ResetOnSpawn   = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.IgnoreGuiInset = true
sg.DisplayOrder   = 5
sg.Parent         = playerGui

-- Conteneur principal — ancré en bas à droite, au-dessus du bouton Jump mobile
local frame = Instance.new("Frame", sg)
frame.Name                   = "TimerFrame"
frame.AnchorPoint            = Vector2.new(1, 1)
frame.Size                   = UDim2.new(0, 210, 0, 66)
frame.Position               = UDim2.new(1, -8, 1, -100)
frame.BackgroundColor3       = Color3.fromRGB(12, 12, 12)
frame.BackgroundTransparency = 0.22
frame.BorderSizePixel        = 0
frame.ZIndex                 = 5
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
local _stroke = Instance.new("UIStroke", frame)
_stroke.Color     = Color3.fromRGB(70, 70, 70)
_stroke.Thickness = 1.5

local _layout = Instance.new("UIListLayout", frame)
_layout.SortOrder     = Enum.SortOrder.LayoutOrder
_layout.FillDirection = Enum.FillDirection.Vertical

local _pad = Instance.new("UIPadding", frame)
_pad.PaddingTop    = UDim.new(0, 6)
_pad.PaddingBottom = UDim.new(0, 6)
_pad.PaddingLeft   = UDim.new(0, 9)
_pad.PaddingRight  = UDim.new(0, 9)

-- ============================================================
-- Helper : une ligne label + valeur
-- ============================================================
local function makeRow(order)
    local row = Instance.new("Frame", frame)
    row.Size                   = UDim2.new(1, 0, 0, 25)
    row.BackgroundTransparency = 1
    row.BorderSizePixel        = 0
    row.LayoutOrder            = order
    row.ZIndex                 = 6

    local lbl = Instance.new("TextLabel", row)
    lbl.Name                   = "Label"
    lbl.Size                   = UDim2.new(0.58, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font                   = Enum.Font.GothamBold
    lbl.TextSize               = 13
    lbl.TextXAlignment         = Enum.TextXAlignment.Left
    lbl.TextScaled             = false
    lbl.ZIndex                 = 6

    local val = Instance.new("TextLabel", row)
    val.Name                   = "Value"
    val.Size                   = UDim2.new(0.42, 0, 1, 0)
    val.Position               = UDim2.new(0.58, 0, 0, 0)
    val.BackgroundTransparency = 1
    val.Font                   = Enum.Font.GothamBold
    val.TextSize               = 13
    val.TextXAlignment         = Enum.TextXAlignment.Right
    val.TextScaled             = false
    val.ZIndex                 = 6

    return lbl, val
end

local eventLabel,   eventVal   = makeRow(1)
local specialLabel, specialVal = makeRow(2)

-- ============================================================
-- Helpers affichage
-- ============================================================
local function formatTemps(s)
    if not s or s < 0 then return "--:--" end
    s = math.floor(s)
    local h = math.floor(s / 3600)
    local m = math.floor((s % 3600) / 60)
    local sec = s % 60
    if h > 0 then
        return string.format("%d:%02d:%02d", h, m, sec)
    end
    return string.format("%d:%02d", m, sec)
end

local EVENT_LABELS = {
    Rain        = "🌧️ RAIN",
    NightMode   = "🌙 NIGHT",
    MeteorDrop  = "☄️ METEOR",
    Golden      = "✨ GOLDEN",
    LuckyHour   = "⭐ LUCKY HOUR",
    SecretSpawn = "🔴 SECRET",
    AdminAbuse  = "🌈 ADMIN ABUSE",
}
local EVENT_COLORS = {
    Rain        = Color3.fromRGB(100, 180, 255),
    NightMode   = Color3.fromRGB(160, 100, 255),
    MeteorDrop  = Color3.fromRGB(255, 130, 50),
    Golden      = Color3.fromRGB(255, 215, 0),
    LuckyHour   = Color3.fromRGB(255, 220, 80),
    SecretSpawn = Color3.fromRGB(255, 60, 60),
    AdminAbuse  = Color3.fromRGB(255, 80, 200),
}
local SPECIAL_LABELS = {
    MYTHIC = "⚡ MYTHIC",
    SECRET = "🔴 SECRET",
}
local SPECIAL_COLORS = {
    MYTHIC = Color3.fromRGB(190, 80, 255),
    SECRET = Color3.fromRGB(255, 60, 60),
}
local COLOR_DIM    = Color3.fromRGB(160, 160, 160)
local COLOR_GOLD   = Color3.fromRGB(255, 220, 50)
local COLOR_GREEN  = Color3.fromRGB(50, 255, 100)

-- ============================================================
-- Mise à jour de l'affichage depuis cachedData
-- ============================================================
local cachedData       = nil
local countdown_event  = nil
local countdown_special = nil

local function majAffichage()
    if not cachedData then return end

    -- Ligne 1 : event actif ou prochain
    if cachedData.eventActif then
        local nom = cachedData.eventNom or ""
        eventLabel.Text       = EVENT_LABELS[nom] or ("🔥 " .. nom)
        eventLabel.TextColor3 = EVENT_COLORS[nom] or COLOR_GOLD
        eventVal.Text         = formatTemps(countdown_event)
        eventVal.TextColor3   = Color3.fromRGB(255, 255, 255)
    else
        eventLabel.Text       = "⚡ Next Event"
        eventLabel.TextColor3 = COLOR_DIM
        eventVal.Text         = formatTemps(countdown_event)
        eventVal.TextColor3   = COLOR_GOLD
    end

    -- Ligne 2 : prochain spécial
    local sp = cachedData.prochainSpecial
    if sp and sp.secondes >= 0 then
        local t = sp.type or "MYTHIC"
        specialLabel.Text       = SPECIAL_LABELS[t] or t
        specialLabel.TextColor3 = SPECIAL_COLORS[t] or COLOR_GOLD
        if countdown_special == 0 then
            specialVal.Text       = "NOW! 🎯"
            specialVal.TextColor3 = COLOR_GREEN
        else
            specialVal.Text       = formatTemps(countdown_special)
            specialVal.TextColor3 = SPECIAL_COLORS[t] or COLOR_GOLD
        end
    else
        specialLabel.Text       = "⚡ MYTHIC"
        specialLabel.TextColor3 = COLOR_DIM
        specialVal.Text         = "--:--"
        specialVal.TextColor3   = COLOR_DIM
    end
end

-- ============================================================
-- Fetch serveur
-- ============================================================
local function fetchTimers()
    local ok, data = pcall(function()
        return GetTimerData:InvokeServer()
    end)
    if ok and data then
        cachedData        = data
        countdown_event   = data.eventTempsRestant or 0
        countdown_special = data.prochainSpecial and data.prochainSpecial.secondes or nil
        majAffichage()
    end
end

-- ============================================================
-- Loop : décompte local chaque seconde, fetch toutes les 5s
-- ============================================================
task.spawn(function()
    fetchTimers()
    local tick = 0
    while true do
        task.wait(1)
        tick = tick + 1

        -- Décompte local
        if countdown_event ~= nil and countdown_event > 0 then
            countdown_event = countdown_event - 1
        end
        if countdown_special ~= nil and countdown_special > 0 then
            countdown_special = countdown_special - 1
            if cachedData and cachedData.prochainSpecial then
                cachedData.prochainSpecial.secondes = countdown_special
            end
        end
        majAffichage()

        -- Resync serveur toutes les 5s
        if tick >= 5 then
            tick = 0
            fetchTimers()
        end
    end
end)
