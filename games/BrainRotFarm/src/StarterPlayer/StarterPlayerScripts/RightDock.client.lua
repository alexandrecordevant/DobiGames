-- StarterPlayerScripts/RightDock.client.lua
-- Dock unifié bas-droite, repliable — regroupe tout le "statut live" :
--   • Évolution de la base (3 jauges : 🔧 Base / 🌱 Seed / 🌈 Mutant)
--   • Free Lucky Block (compteur, affiché seulement pendant la fenêtre d'offre)
--   • Prochain Event + prochain Spécial (MYTHIC/SECRET/Arbre)
-- Replié  : colonne étroite, icône + chiffre uniquement.
-- Déplié  : large, avec libellés (+ barres pour les jauges).
-- Replié par défaut sur mobile, déplié sur PC ; tap sur l'en-tête pour basculer.
--
-- Remplace TimerHUD + BaseProgressHUD + le compteur de FreeLuckyBlockHUD.
-- (FreeLuckyBlockHUD conserve uniquement ses popups start/granted.)

local Players          = game:GetService("Players")
local RS               = game:GetService("ReplicatedStorage")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ModalManager = require(RS:WaitForChild("SharedLib"):WaitForChild("ModalManager"))
local UpdateHUD             = RS:WaitForChild("UpdateHUD")
local BaseProgressMilestone = RS:WaitForChild("BaseProgressMilestone")
local FreeLuckyBlock        = RS:WaitForChild("FreeLuckyBlock")
local GetTimerData          = RS:WaitForChild("GetTimerData")

local GOLD       = Color3.fromRGB(255, 215, 60)
local COLOR_DIM  = Color3.fromRGB(160, 160, 160)
local COLOR_VAL  = Color3.fromRGB(225, 225, 230)

local EST_MOBILE = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

-- Dimensions
local ROW_H      = 20
local HEADER_H   = 24
local PAD        = 5
local W_OUVERT   = 250
local W_FERME    = 86
local LABEL_X    = 30   -- début des libellés
local VAL_W      = 48   -- largeur de la valeur (droite)
local BAR_X      = 86   -- début des barres (jauges)

-- ============================================================
-- Nettoyage hérité : ce dock remplace TimerHUD + BaseProgressHUD + le compteur
-- de FreeLuckyBlockHUD. Si un build pas encore resynchronisé laisse traîner ces
-- anciens ScreenGui, on les supprime pour éviter les jauges/timers en double.
-- ============================================================
do
    local LEGACY = { TimerHUD = true, BaseProgressHUD = true, FreeLuckyBlockTimer = true }
    local function purge(inst)
        if inst:IsA("ScreenGui") and LEGACY[inst.Name] then
            inst:Destroy()
        end
    end
    for _, g in ipairs(playerGui:GetChildren()) do purge(g) end
    local conn = playerGui.ChildAdded:Connect(purge)   -- au cas où un vieux script les recrée
    task.delay(10, function() conn:Disconnect() end)
end

-- ============================================================
-- ScreenGui + panneau
-- ============================================================
local sg = Instance.new("ScreenGui")
sg.Name           = "RightDock"
sg.ResetOnSpawn   = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.DisplayOrder   = 6
sg.IgnoreGuiInset = true
sg.Parent         = playerGui

local panneau = Instance.new("Frame", sg)
panneau.Name                   = "Dock"
panneau.AnchorPoint            = Vector2.new(1, 1)
panneau.Position               = UDim2.new(1, -8, 1, -100)  -- au-dessus du bouton Jump mobile
panneau.Size                   = UDim2.new(0, W_OUVERT, 0, HEADER_H)
panneau.BackgroundColor3       = Color3.fromRGB(14, 14, 17)
panneau.BackgroundTransparency = 0.18
panneau.BorderSizePixel        = 0
panneau.ClipsDescendants       = true
Instance.new("UICorner", panneau).CornerRadius = UDim.new(0, 10)
local pStroke = Instance.new("UIStroke", panneau)
pStroke.Color        = Color3.fromRGB(60, 60, 70)
pStroke.Thickness    = 1
pStroke.Transparency = 0.3

local layout = Instance.new("UIListLayout", panneau)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding   = UDim.new(0, 2)
local pad = Instance.new("UIPadding", panneau)
pad.PaddingTop, pad.PaddingBottom = UDim.new(0, PAD), UDim.new(0, PAD)

-- En-tête cliquable (toggle)
local header = Instance.new("TextButton", panneau)
header.Name                   = "Header"
header.LayoutOrder            = 1
header.Size                   = UDim2.new(1, 0, 0, HEADER_H)
header.BackgroundTransparency = 1
header.AutoButtonColor        = false
header.Font                   = Enum.Font.GothamBold
header.TextSize               = 13
header.TextColor3             = GOLD
header.Text                   = "🏆 BASE EVOLUTION ▾"

-- ============================================================
-- Lignes
-- ============================================================
-- Crée une ligne (icône + libellé + [barre] + valeur). Retourne ses handles.
local function makeRow(order, hasBar, barColor)
    local row = Instance.new("Frame", panneau)
    row.Name                   = "Row"
    row.LayoutOrder            = order
    row.BackgroundTransparency = 1
    row.Size                   = UDim2.new(1, 0, 0, ROW_H)

    local icone = Instance.new("TextLabel", row)
    icone.Name                   = "Icone"
    icone.Size                   = UDim2.new(0, 22, 1, 0)
    icone.Position               = UDim2.new(0, 6, 0, 0)
    icone.BackgroundTransparency = 1
    icone.Font                   = Enum.Font.GothamBold
    icone.TextSize               = 13
    icone.TextXAlignment         = Enum.TextXAlignment.Left
    icone.Text                   = ""

    local label = Instance.new("TextLabel", row)
    label.Name                   = "Label"
    label.Position               = UDim2.new(0, LABEL_X, 0, 0)
    label.Size                   = UDim2.new(1, -(LABEL_X + VAL_W + 4), 1, 0)
    label.BackgroundTransparency = 1
    label.Font                   = Enum.Font.GothamBold
    label.TextSize               = 12
    label.TextXAlignment         = Enum.TextXAlignment.Left
    label.TextColor3             = COLOR_DIM
    label.Text                   = ""

    local fond, fill
    if hasBar then
        fond = Instance.new("Frame", row)
        fond.Name             = "BarFond"
        fond.Position         = UDim2.new(0, BAR_X, 0.5, -5)
        fond.Size             = UDim2.new(1, -(BAR_X + VAL_W + 4), 0, 10)
        fond.BackgroundColor3 = Color3.fromRGB(42, 42, 48)
        fond.BorderSizePixel  = 0
        Instance.new("UICorner", fond).CornerRadius = UDim.new(0, 5)
        fill = Instance.new("Frame", fond)
        fill.Name             = "Fill"
        fill.Size             = UDim2.new(0, 0, 1, 0)
        fill.BackgroundColor3 = barColor or GOLD
        fill.BorderSizePixel  = 0
        Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 5)
    end

    local valeur = Instance.new("TextLabel", row)
    valeur.Name                   = "Valeur"
    valeur.Size                   = UDim2.new(0, VAL_W, 1, 0)
    valeur.Position               = UDim2.new(1, -(VAL_W + 4), 0, 0)
    valeur.BackgroundTransparency = 1
    valeur.Font                   = Enum.Font.GothamBold
    valeur.TextSize               = 12
    valeur.TextXAlignment         = Enum.TextXAlignment.Right
    valeur.TextColor3             = COLOR_VAL
    valeur.Text                   = "—"

    return { row = row, icone = icone, label = label, fond = fond, fill = fill, valeur = valeur }
end

-- Jauges (avec barre)
local JAUGES = {
    { key = "base",    icone = "🔧", nom = "Base",   couleur = Color3.fromRGB(90, 175, 255),  format = "frac" },
    { key = "seeds",   icone = "🌱", nom = "Seed",   couleur = Color3.fromRGB(120, 220, 120), format = "frac" },
    { key = "mutants", icone = "🌈", nom = "Mutant", couleur = Color3.fromRGB(210, 120, 255), format = "pct"  },
}
local rowsJauge = {}
for i, def in ipairs(JAUGES) do
    local r = makeRow(1 + i, true, def.couleur)
    r.icone.Text = def.icone
    r.label.Text = def.nom
    rowsJauge[def.key] = r
end

-- Séparateur
local sep = Instance.new("Frame", panneau)
sep.Name             = "Sep"
sep.LayoutOrder      = 5
sep.Size             = UDim2.new(1, -16, 0, 1)
sep.Position         = UDim2.new(0, 8, 0, 0)
sep.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
sep.BackgroundTransparency = 0.3
sep.BorderSizePixel  = 0

-- Lignes timers (sans barre)
local rowFree  = makeRow(6, false)   -- Free Lucky Block (masqué par défaut)
rowFree.icone.Text = "🎁"
rowFree.label.Text = "🎁 Free Lucky"
rowFree.label.TextColor3 = GOLD
rowFree.row.Visible = false

local rowEvent   = makeRow(7, false)
rowEvent.icone.Text = "⚡"
rowEvent.label.Text = "Next Event"

local rowSpecial = makeRow(8, false)
rowSpecial.icone.Text = "✨"
rowSpecial.label.Text = "Mythic"

-- ============================================================
-- Pliage / dépliage
-- ============================================================
local deplie = not EST_MOBILE
local function appliquerEtat(anime)
    -- Affiche/masque libellés + barres. Jauges : icône toujours visible.
    -- Timers : icône seulement en replié (en déplié, le libellé porte déjà l'emoji).
    local function maj(r, isTimer)
        if not r then return end
        r.label.Visible = deplie
        if r.fond then r.fond.Visible = deplie end
        if isTimer then r.icone.Visible = not deplie end
    end
    for _, def in ipairs(JAUGES) do maj(rowsJauge[def.key], false) end
    maj(rowFree, true); maj(rowEvent, true); maj(rowSpecial, true)
    sep.BackgroundTransparency = deplie and 0.3 or 0.7
    header.Text = deplie and "🏆 BASE EVOLUTION ▾" or "🏆 ▸"

    local cible = UDim2.new(0, deplie and W_OUVERT or W_FERME, 0, panneau.Size.Y.Offset)
    if anime then
        TweenService:Create(panneau, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Size = cible }):Play()
    else
        panneau.Size = cible
    end
end

-- Hauteur auto selon les lignes visibles
local function majHauteur()
    local h = layout.AbsoluteContentSize.Y + PAD * 2
    panneau.Size = UDim2.new(panneau.Size.X.Scale, panneau.Size.X.Offset, 0, h)
end
layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(majHauteur)

header.Activated:Connect(function()
    deplie = not deplie
    appliquerEtat(true)
end)

-- ============================================================
-- Jauges d'évolution (UpdateHUD)
-- ============================================================
local function rendreJauges(bp)
    for _, def in ipairs(JAUGES) do
        local j = bp[def.key]
        local r = rowsJauge[def.key]
        if j and r then
            local maxV = tonumber(j.max) or 0
            local curV = tonumber(j.cur) or 0
            local pct  = (maxV > 0) and math.clamp((tonumber(j.pct) or (curV / maxV)), 0, 1) or 0
            if r.fill then
                TweenService:Create(r.fill, TweenInfo.new(0.3, Enum.EasingStyle.Quad),
                    { Size = UDim2.new(pct, 0, 1, 0) }):Play()
            end
            if maxV <= 0 then
                r.valeur.Text = "—"
            elseif def.format == "frac" then
                r.valeur.Text = string.format("%d/%d", curV, maxV)
            else
                r.valeur.Text = string.format("%d%%", math.floor(pct * 100 + 0.5))
            end
            r.valeur.TextColor3 = (pct >= 1 and maxV > 0) and GOLD or COLOR_VAL
        end
    end
end
UpdateHUD.OnClientEvent:Connect(function(hudData)
    if hudData and hudData.baseProgress then rendreJauges(hudData.baseProgress) end
end)

-- ============================================================
-- Timers (event + spécial) — porté de TimerHUD
-- ============================================================
local function formatTemps(s)
    if not s or s < 0 then return "--:--" end
    s = math.floor(s)
    local h = math.floor(s / 3600)
    local m = math.floor((s % 3600) / 60)
    local sec = s % 60
    if h > 0 then return string.format("%d:%02d:%02d", h, m, sec) end
    return string.format("%d:%02d", m, sec)
end

local EVENT_LABELS = {
    Rain="🌧️ RAIN", NightMode="🌙 NIGHT", MeteorDrop="☄️ METEOR", Golden="✨ GOLDEN",
    LuckyHour="⭐ LUCKY HOUR", SecretSpawn="🔴 SECRET", AdminAbuse="🌈 ADMIN ABUSE",
}
local EVENT_COLORS = {
    Rain=Color3.fromRGB(100,180,255), NightMode=Color3.fromRGB(160,100,255),
    MeteorDrop=Color3.fromRGB(255,130,50), Golden=Color3.fromRGB(255,215,0),
    LuckyHour=Color3.fromRGB(255,220,80), SecretSpawn=Color3.fromRGB(255,60,60),
    AdminAbuse=Color3.fromRGB(255,80,200),
}
local SPECIAL_LABELS = { MYTHIC="⚡ MYTHIC", SECRET="🔴 SECRET", ARBRE="🌳 TREE" }
local SPECIAL_COLORS = {
    MYTHIC=Color3.fromRGB(190,80,255), SECRET=Color3.fromRGB(255,60,60), ARBRE=Color3.fromRGB(100,220,120),
}
local COLOR_GREEN = Color3.fromRGB(50, 255, 100)

local cachedData, cdEvent, cdSpecial = nil, nil, nil

local function majTimers()
    if not cachedData then return end
    -- Event
    if cachedData.eventActif then
        local nom = cachedData.eventNom or ""
        rowEvent.label.Text       = EVENT_LABELS[nom] or ("🔥 " .. nom)
        rowEvent.label.TextColor3 = EVENT_COLORS[nom] or GOLD
        rowEvent.valeur.Text       = formatTemps(cdEvent)
        rowEvent.valeur.TextColor3 = Color3.fromRGB(255, 255, 255)
    else
        rowEvent.label.Text       = "Next Event"
        rowEvent.label.TextColor3 = COLOR_DIM
        rowEvent.valeur.Text       = formatTemps(cdEvent)
        rowEvent.valeur.TextColor3 = GOLD
    end
    -- Spécial
    local sp = cachedData.prochainSpecial
    if sp and sp.secondes and sp.secondes >= 0 then
        local t = sp.type or "MYTHIC"
        rowSpecial.label.Text       = SPECIAL_LABELS[t] or t
        rowSpecial.label.TextColor3 = SPECIAL_COLORS[t] or GOLD
        if cdSpecial == 0 then
            rowSpecial.valeur.Text       = "NOW! 🎯"
            rowSpecial.valeur.TextColor3 = COLOR_GREEN
        else
            rowSpecial.valeur.Text       = formatTemps(cdSpecial)
            rowSpecial.valeur.TextColor3 = SPECIAL_COLORS[t] or GOLD
        end
    else
        rowSpecial.label.Text       = "Mythic"
        rowSpecial.label.TextColor3 = COLOR_DIM
        rowSpecial.valeur.Text       = "--:--"
        rowSpecial.valeur.TextColor3 = COLOR_DIM
    end
end

local function fetchTimers()
    local ok, data = pcall(function() return GetTimerData:InvokeServer() end)
    if ok and data then
        cachedData = data
        cdEvent    = data.eventTempsRestant or 0
        cdSpecial  = data.prochainSpecial and data.prochainSpecial.secondes or nil
        majTimers()
    end
end

-- ============================================================
-- Free Lucky Block (compteur) — porté de FreeLuckyBlockHUD
-- ============================================================
local freeDeadline = nil   -- os.time() de fin (nil = inactif)

local function majFreeLucky()
    if freeDeadline then
        rowFree.row.Visible = true
        local restant = freeDeadline - os.time()
        if restant > 0 then
            rowFree.valeur.Text       = formatTemps(restant)
            rowFree.valeur.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            rowFree.valeur.Text       = "SOON!"
            rowFree.valeur.TextColor3 = GOLD
        end
    else
        rowFree.row.Visible = false
    end
end

FreeLuckyBlock.OnClientEvent:Connect(function(action, valeur)
    if action == "start" then
        freeDeadline = os.time() + (tonumber(valeur) or 0)
        majFreeLucky()
    elseif action == "granted" then
        freeDeadline = nil
        majFreeLucky()
    end
end)

-- ============================================================
-- Boucle 1 Hz : décompte local + resync serveur toutes les 5 s
-- ============================================================
task.spawn(function()
    fetchTimers()
    local tick = 0
    while true do
        task.wait(1)
        tick = tick + 1
        if cdEvent ~= nil and cdEvent > 0 then cdEvent = cdEvent - 1 end
        if cdSpecial ~= nil and cdSpecial > 0 then
            cdSpecial = cdSpecial - 1
            if cachedData and cachedData.prochainSpecial then
                cachedData.prochainSpecial.secondes = cdSpecial
            end
        end
        majTimers()
        majFreeLucky()
        if tick >= 5 then tick = 0; fetchTimers() end
    end
end)

-- État initial
appliquerEtat(false)
majHauteur()

-- ============================================================
-- Popup de célébration (palier d'évolution franchi)
-- ============================================================
local function afficherCelebration(info)
    local popupSg = Instance.new("ScreenGui")
    popupSg.Name           = "BaseProgressPopup"
    popupSg.ResetOnSpawn   = false
    popupSg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    popupSg.IgnoreGuiInset = true
    popupSg.DisplayOrder   = 34
    popupSg.Parent         = playerGui

    local overlay = Instance.new("Frame", popupSg)
    overlay.Size                   = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
    overlay.BackgroundTransparency = 0.45
    overlay.BorderSizePixel        = 0
    overlay.ZIndex                 = 1

    local card = Instance.new("Frame", popupSg)
    card.AnchorPoint            = Vector2.new(0.5, 0.5)
    card.Size                   = UDim2.new(0.82, 0, 0, 210)
    card.SizeConstraint         = Enum.SizeConstraint.RelativeXX
    card.Position               = UDim2.new(0.5, 0, 0.5, 0)
    card.BackgroundColor3       = Color3.fromRGB(18, 18, 22)
    card.BackgroundTransparency = 0.05
    card.BorderSizePixel        = 0
    card.ZIndex                 = 2
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 14)
    local maxCard = Instance.new("UISizeConstraint", card)
    maxCard.MaxSize = Vector2.new(420, 250)
    local stroke = Instance.new("UIStroke", card)
    stroke.Color     = GOLD
    stroke.Thickness = 2.5

    local pd = Instance.new("UIPadding", card)
    pd.PaddingTop, pd.PaddingBottom = UDim.new(0, 16), UDim.new(0, 16)
    pd.PaddingLeft, pd.PaddingRight = UDim.new(0, 16), UDim.new(0, 16)

    local titreLbl = Instance.new("TextLabel", card)
    titreLbl.Size                   = UDim2.new(1, 0, 0, 64)
    titreLbl.BackgroundTransparency = 1
    titreLbl.Font                   = Enum.Font.GothamBold
    titreLbl.TextSize               = 22
    titreLbl.TextColor3             = GOLD
    titreLbl.TextStrokeTransparency = 0.4
    titreLbl.RichText               = true
    titreLbl.TextWrapped            = true
    titreLbl.Text                   = "🎉 MILESTONE REACHED!\n" .. (info.label or "")
    titreLbl.ZIndex                 = 3

    local corpsLbl = Instance.new("TextLabel", card)
    corpsLbl.AnchorPoint            = Vector2.new(0.5, 0.5)
    corpsLbl.Size                   = UDim2.new(1, 0, 1, -130)
    corpsLbl.Position               = UDim2.new(0.5, 0, 0.5, 6)
    corpsLbl.BackgroundTransparency = 1
    corpsLbl.Font                   = Enum.Font.GothamMedium
    corpsLbl.TextSize               = 16
    corpsLbl.TextColor3             = Color3.fromRGB(235, 235, 235)
    corpsLbl.RichText               = true
    corpsLbl.TextWrapped            = true
    corpsLbl.Text                   = info.desc or "Reward unlocked!"
    corpsLbl.ZIndex                 = 3

    local btn = Instance.new("TextButton", card)
    btn.AnchorPoint            = Vector2.new(0.5, 1)
    btn.Size                   = UDim2.new(0.6, 0, 0, 44)
    btn.Position               = UDim2.new(0.5, 0, 1, 0)
    btn.BackgroundColor3       = GOLD
    btn.BorderSizePixel        = 0
    btn.Font                   = Enum.Font.GothamBold
    btn.TextSize               = 18
    btn.TextColor3             = Color3.fromRGB(25, 20, 0)
    btn.Text                   = "NICE!"
    btn.ZIndex                 = 3
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)

    ModalManager.Open("BaseProgressMilestone")

    card.Size = UDim2.new(0, 0, 0, 0)
    TweenService:Create(card, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Size = UDim2.new(0.82, 0, 0, 210) }):Play()

    btn.Activated:Connect(function()
        ModalManager.Close("BaseProgressMilestone")
        TweenService:Create(overlay, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
        TweenService:Create(card, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Size = UDim2.new(0, 0, 0, 0) }):Play()
        task.delay(0.25, function() if popupSg.Parent then popupSg:Destroy() end end)
    end)
end

BaseProgressMilestone.OnClientEvent:Connect(function(info)
    if typeof(info) == "table" then afficherCelebration(info) end
end)
