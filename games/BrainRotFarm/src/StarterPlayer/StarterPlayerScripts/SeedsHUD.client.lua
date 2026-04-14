-- StarterPlayer/StarterPlayerScripts/SeedsHUD.client.lua
-- DobiGames BrainRotFarm — Bouton Seeds (gauche, sous Rebirth)
-- ⚠️ Le bouton est créé immédiatement — les données chargent en tâche séparée

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local Logger            = require(game:GetService("ReplicatedStorage").SharedLib.Logger)

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ============================================================
-- Thème
-- ============================================================
local C = {
    fond       = Color3.fromRGB(12,  10,  22),
    fondCarte  = Color3.fromRGB(22,  18,  40),
    bordure    = Color3.fromRGB(120, 60,  200),
    texte      = Color3.fromRGB(230, 220, 255),
    texteDim   = Color3.fromRGB(140, 120, 180),
    mythic     = Color3.fromRGB(180, 0,   255),
    secret     = Color3.fromRGB(255, 50,  50),
    vert       = Color3.fromRGB(80,  220, 100),
    or_        = Color3.fromRGB(255, 215, 0),
    arbre      = Color3.fromRGB(100, 200, 50),
    growing    = Color3.fromRGB(100, 200, 255),
    ready      = Color3.fromRGB(255, 180, 0),
    vide       = Color3.fromRGB(100, 90,  130),
    verrouille = Color3.fromRGB(160, 120, 50),
}

local JOUR_NOMS    = { "Lun", "Mar", "Mer", "Jeu", "Ven", "Sam", "Dim" }
local ELEMENT_EMOJI = { water="💧", fire="🔥", earth="🌍", wind="💨" }

-- ============================================================
-- ScreenGui — IgnoreGuiInset = false pour matcher HUDController
-- ============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "SeedsHUD"
screenGui.ResetOnSpawn   = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset = false   -- même espace coordonnées que HUDController
screenGui.Parent         = playerGui

-- ============================================================
-- Bouton "🌱 Seeds" — gauche, juste sous Rebirth
-- HUDController Shop     : pos (0,10, 0.5,-130)  h=50
-- HUDController Rebirth  : pos (0,10, 0.5,-65)   h=85 → bas à (0.5,+20)
-- Seeds                  : pos (0,10, 0.5,+30)   h=50
-- ============================================================
local btnSeeds = Instance.new("TextButton", screenGui)
btnSeeds.Name                   = "BtnFlowerPot"
btnSeeds.Size                   = UDim2.new(0, 120, 0, 55)
btnSeeds.Position               = UDim2.new(0, 10, 0.5, 85)
btnSeeds.BackgroundColor3       = Color3.fromRGB(20, 40, 20)
btnSeeds.BorderSizePixel        = 0
btnSeeds.Text                   = "🪴 FlowerPot"
btnSeeds.TextColor3             = Color3.fromRGB(150, 230, 130)
btnSeeds.Font                   = Enum.Font.GothamBold
btnSeeds.TextSize               = 13
btnSeeds.TextWrapped            = true
btnSeeds.AutoButtonColor        = false
btnSeeds.ZIndex                 = 10
btnSeeds.Visible                = false  -- bouton géré par FlowerPotHUD
btnSeeds.Parent                 = screenGui
Instance.new("UICorner", btnSeeds).CornerRadius = UDim.new(0, 10)

local btnStroke = Instance.new("UIStroke", btnSeeds)
btnStroke.Color     = Color3.fromRGB(60, 180, 60)
btnStroke.Thickness = 1.5

-- ============================================================
-- Panel principal (caché par défaut, s'ouvre à droite du bouton)
-- ============================================================
local PANEL_W = 310
local PANEL_H = 500

local panel = Instance.new("Frame", screenGui)
panel.Name                   = "SeedsPanel"
panel.Size                   = UDim2.new(0, PANEL_W, 0, PANEL_H)
panel.Position               = UDim2.new(0, 140, 0.5, -PANEL_H / 2)
panel.BackgroundColor3       = C.fond
panel.BorderSizePixel        = 0
panel.Visible                = false
panel.ZIndex                 = 20
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)
Instance.new("UIStroke", panel).Color        = C.bordure
panel:FindFirstChildOfClass("UIStroke").Thickness = 2

-- ── Titre ──
local titre = Instance.new("TextLabel", panel)
titre.Size                   = UDim2.new(1, -44, 0, 40)
titre.Position               = UDim2.new(0, 12, 0, 6)
titre.BackgroundTransparency = 1
titre.Text                   = "🪴 FlowerPots"
titre.TextColor3             = C.texte
titre.Font                   = Enum.Font.GothamBold
titre.TextSize               = 15
titre.TextXAlignment         = Enum.TextXAlignment.Left
titre.ZIndex                 = 21

-- ── Bouton fermer ──
local btnFermer = Instance.new("TextButton", panel)
btnFermer.Size             = UDim2.new(0, 30, 0, 30)
btnFermer.Position         = UDim2.new(1, -38, 0, 8)
btnFermer.BackgroundColor3 = Color3.fromRGB(60, 30, 80)
btnFermer.BorderSizePixel  = 0
btnFermer.Text             = "✕"
btnFermer.TextColor3       = C.texteDim
btnFermer.Font             = Enum.Font.GothamBold
btnFermer.TextSize         = 13
btnFermer.ZIndex           = 22
Instance.new("UICorner", btnFermer).CornerRadius = UDim.new(0, 6)

local function makeSep(parent, yPos)
    local s = Instance.new("Frame", parent)
    s.Size               = UDim2.new(1, -24, 0, 1)
    s.Position           = UDim2.new(0, 12, 0, yPos)
    s.BackgroundColor3   = C.bordure
    s.BackgroundTransparency = 0.6
    s.BorderSizePixel    = 0
    s.ZIndex             = 21
end
makeSep(panel, 48)

-- ============================================================
-- Section 1 : Stock graines
-- ============================================================
local stockSection = Instance.new("Frame", panel)
stockSection.Size             = UDim2.new(1, -24, 0, 52)
stockSection.Position         = UDim2.new(0, 12, 0, 54)
stockSection.BackgroundColor3 = C.fondCarte
stockSection.BorderSizePixel  = 0
stockSection.ZIndex           = 21
Instance.new("UICorner", stockSection).CornerRadius = UDim.new(0, 8)

local function makeLabel(parent, name, size, pos, text, color, fontSize, bold)
    local l = Instance.new("TextLabel", parent)
    l.Name                   = name
    l.Size                   = size
    l.Position               = pos
    l.BackgroundTransparency = 1
    l.Text                   = text
    l.TextColor3             = color
    l.Font                   = bold and Enum.Font.GothamBold or Enum.Font.Gotham
    l.TextSize               = fontSize
    l.TextXAlignment         = Enum.TextXAlignment.Left
    l.ZIndex                 = 22
    return l
end

makeLabel(stockSection, "Titre", UDim2.new(1,-8,0,18), UDim2.new(0,8,0,3),
    "📦 Inventaire graines", C.texteDim, 10, false)

local lblMythic = makeLabel(stockSection, "LblMythic",
    UDim2.new(0.5,-8,0,26), UDim2.new(0,8,0,22),
    "⚡ MYTHIC: 0", C.mythic, 12, true)

local lblSecret = makeLabel(stockSection, "LblSecret",
    UDim2.new(0.5,-8,0,26), UDim2.new(0.5,0,0,22),
    "🔴 SECRET: 0", C.secret, 12, true)

makeSep(panel, 112)

-- ============================================================
-- Section 2 : État des 4 pots
-- ============================================================
makeLabel(panel, "PotsTitre",
    UDim2.new(1,-24,0,18), UDim2.new(0,12,0,118),
    "🪴 État des pots", C.texteDim, 10, false)

local POT_W = 62
local POT_H = 72
local potsFrames = {}

for i = 1, 4 do
    local cell = Instance.new("Frame", panel)
    cell.Name             = "Pot_" .. i
    cell.Size             = UDim2.new(0, POT_W, 0, POT_H)
    cell.Position         = UDim2.new(0, 12 + (i-1) * (POT_W + 6), 0, 138)
    cell.BackgroundColor3 = C.fondCarte
    cell.BorderSizePixel  = 0
    cell.ZIndex           = 21
    Instance.new("UICorner", cell).CornerRadius = UDim.new(0, 8)

    local function potLabel(name, size, pos, text, fontSize, bold)
        local l = Instance.new("TextLabel", cell)
        l.Name                   = name
        l.Size                   = size
        l.Position               = pos
        l.BackgroundTransparency = 1
        l.Text                   = text
        l.TextColor3             = C.texteDim
        l.Font                   = bold and Enum.Font.GothamBold or Enum.Font.Gotham
        l.TextSize               = fontSize
        l.ZIndex                 = 22
        return l
    end

    potLabel("Num", UDim2.new(1,0,0,14), UDim2.new(0,0,0,3), "Pot "..i, 9, false)
    local lblIcon   = potLabel("Icon",   UDim2.new(1,0,0,24), UDim2.new(0,0,0,17), "🔒", 18, true)
    local lblRarity = potLabel("Rarity", UDim2.new(1,-4,0,14), UDim2.new(0,2,0,40), "", 8, true)
    local lblElem   = potLabel("Elem",   UDim2.new(1,0,0,14), UDim2.new(0,0,0,54), "", 10, false)

    table.insert(potsFrames, { cell=cell, icon=lblIcon, rarity=lblRarity, elem=lblElem })
end

makeSep(panel, 216)

-- ============================================================
-- Section 3 : Countdown arbre
-- ============================================================
local arbreSection = Instance.new("Frame", panel)
arbreSection.Size             = UDim2.new(1, -24, 0, 48)
arbreSection.Position         = UDim2.new(0, 12, 0, 222)
arbreSection.BackgroundColor3 = C.fondCarte
arbreSection.BorderSizePixel  = 0
arbreSection.ZIndex           = 21
Instance.new("UICorner", arbreSection).CornerRadius = UDim.new(0, 8)

makeLabel(arbreSection, "Titre", UDim2.new(1,-8,0,18), UDim2.new(0,8,0,3),
    "🌳 Prochaine graine arbre", C.texteDim, 10, false)

local lblArbreTimer = makeLabel(arbreSection, "LblArbreTimer",
    UDim2.new(1,-8,0,22), UDim2.new(0,8,0,22),
    "⏳ --:--", C.arbre, 13, true)

makeSep(panel, 276)

-- ============================================================
-- Section 4 : Calendrier 7 jours
-- ============================================================
local calSection = Instance.new("Frame", panel)
calSection.Size             = UDim2.new(1, -24, 0, 170)
calSection.Position         = UDim2.new(0, 12, 0, 282)
calSection.BackgroundColor3 = C.fondCarte
calSection.BorderSizePixel  = 0
calSection.ZIndex           = 21
Instance.new("UICorner", calSection).CornerRadius = UDim.new(0, 8)

makeLabel(calSection, "Titre", UDim2.new(1,-8,0,18), UDim2.new(0,8,0,4),
    "📅 Daily Seed — cycle 7 jours", C.texteDim, 10, false)

local joursFrames = {}
local cellW = 35

for i = 1, 7 do
    local cell = Instance.new("Frame", calSection)
    cell.Size             = UDim2.new(0, cellW, 0, 52)
    cell.Position         = UDim2.new(0, 6 + (i-1) * (cellW + 3), 0, 25)
    cell.BackgroundColor3 = Color3.fromRGB(30, 22, 50)
    cell.BorderSizePixel  = 0
    cell.ZIndex           = 22
    Instance.new("UICorner", cell).CornerRadius = UDim.new(0, 6)

    local function calLabel(name, size, pos, text, fs)
        local l = Instance.new("TextLabel", cell)
        l.Name = name; l.Size = size; l.Position = pos
        l.BackgroundTransparency = 1; l.Text = text
        l.Font = Enum.Font.Gotham; l.TextSize = fs; l.ZIndex = 23
        l.TextColor3 = C.texteDim
        return l
    end

    local lblJour  = calLabel("Jour",  UDim2.new(1,0,0,14), UDim2.new(0,0,0,1),  JOUR_NOMS[i] or ("J"..i), 8)
    local lblEmoji = calLabel("Emoji", UDim2.new(1,0,0,20), UDim2.new(0,0,0,15), "?", 14)
    local lblRar   = calLabel("Rar",   UDim2.new(1,0,0,12), UDim2.new(0,0,0,36), "", 7)
    table.insert(joursFrames, { cell=cell, emoji=lblEmoji, label=lblRar, jour=lblJour })
end

local lblDailyTimer = makeLabel(calSection, "LblDailyTimer",
    UDim2.new(1,-8,0,18), UDim2.new(0,8,0,83),
    "⏰ --:--:--", C.or_, 11, true)

local lblDailyStatus = makeLabel(calSection, "LblDailyStatus",
    UDim2.new(1,-8,0,16), UDim2.new(0,8,0,102),
    "", C.vert, 10, false)

-- ============================================================
-- État local (décompte côté client)
-- ============================================================
local arbreTimerLocal  = 0
local arbreGraineDispo = false
local dailyTimerLocal  = 0
local dailyClaimable   = false

local function formatTimer(s)
    s = math.max(0, math.floor(s))
    local h = math.floor(s / 3600)
    local m = math.floor((s % 3600) / 60)
    local sec = s % 60
    if h > 0 then return string.format("%02d:%02d:%02d", h, m, sec) end
    return string.format("%02d:%02d", m, sec)
end

-- ============================================================
-- Mise à jour UI
-- ============================================================
local function majStock(graines)
    if not graines then return end
    lblMythic.Text = "⚡ MYTHIC: " .. (graines.MYTHIC or 0)
    lblSecret.Text = "🔴 SECRET: " .. (graines.SECRET or 0)
end

local function majPots(pots)
    if not pots then return end
    local nbReady, nbGrowing = 0, 0
    for i, f in ipairs(potsFrames) do
        local p = pots[i]
        if not p then
            f.icon.Text = "?"; f.rarity.Text = ""; f.elem.Text = ""
            continue
        end
        if not p.debloque then
            f.icon.Text = "🔒"; f.icon.TextColor3 = C.verrouille
            f.rarity.Text = "Verr."; f.rarity.TextColor3 = C.verrouille
            f.elem.Text = ""; f.cell.BackgroundColor3 = Color3.fromRGB(18,14,25)
        elseif p.statut == nil then
            f.icon.Text = "🪴"; f.icon.TextColor3 = C.vide
            f.rarity.Text = "Vide"; f.rarity.TextColor3 = C.vide
            f.elem.Text = ""; f.cell.BackgroundColor3 = C.fondCarte
        elseif p.statut.statut == "growing" then
            local s = p.statut
            f.icon.Text = "🌱"; f.icon.TextColor3 = C.growing
            f.rarity.Text = (s.rarity=="SECRET" and "SEC" or "MYT") .. " S" .. math.max(0, s.stage or 0)
            f.rarity.TextColor3 = s.rarity=="SECRET" and C.secret or C.mythic
            f.elem.Text = s.elementType and ELEMENT_EMOJI[s.elementType] or ""
            f.cell.BackgroundColor3 = Color3.fromRGB(15,28,35)
            nbGrowing = nbGrowing + 1
        elseif p.statut.statut == "ready" then
            local s = p.statut
            f.icon.Text = "🎯"; f.icon.TextColor3 = C.ready
            f.rarity.Text = s.rarity=="SECRET" and "SECRET" or "MYTHIC"
            f.rarity.TextColor3 = s.rarity=="SECRET" and C.secret or C.mythic
            f.elem.Text = s.elementType and ELEMENT_EMOJI[s.elementType] or "✨"
            f.cell.BackgroundColor3 = Color3.fromRGB(35,25,10)
            nbReady = nbReady + 1
        end
    end
    -- Mise à jour du texte du bouton avec résumé d'état
    if nbReady > 0 then
        btnSeeds.Text = "🪴 FlowerPot\n✅ " .. nbReady .. " ready!"
        btnSeeds.BackgroundColor3 = Color3.fromRGB(30, 50, 15)
    elseif nbGrowing > 0 then
        btnSeeds.Text = "🪴 FlowerPot\n🌱 " .. nbGrowing .. " growing"
        btnSeeds.BackgroundColor3 = Color3.fromRGB(20, 40, 20)
    else
        btnSeeds.Text = "🪴 FlowerPot"
        btnSeeds.BackgroundColor3 = Color3.fromRGB(20, 40, 20)
    end
end

local function majCalendrier(info)
    if not info or not info.dailyCycle then return end
    local jourActuel  = info.dailySeed and info.dailySeed.jourActuel or 1
    local graineDispo = info.dailySeed and info.dailySeed.graineDispo or false
    for i, f in ipairs(joursFrames) do
        local rarity  = info.dailyCycle[i] or "MYTHIC"
        local couleur = rarity == "SECRET" and C.secret or C.mythic
        f.emoji.Text = rarity=="SECRET" and "🔴" or "⚡"
        f.emoji.TextColor3 = couleur
        f.label.Text = rarity=="SECRET" and "SEC" or "MYT"
        f.label.TextColor3 = couleur
        local stroke = f.cell:FindFirstChildOfClass("UIStroke")
        if stroke then stroke:Destroy() end
        if i == jourActuel then
            f.cell.BackgroundColor3 = Color3.fromRGB(45,30,80)
            local st = Instance.new("UIStroke", f.cell)
            st.Color = graineDispo and C.vert or C.or_; st.Thickness = 2
            f.jour.TextColor3 = C.or_
        elseif i < jourActuel then
            f.cell.BackgroundColor3 = Color3.fromRGB(18,15,28)
            f.emoji.TextTransparency = 0.6; f.label.TextTransparency = 0.6
            f.jour.TextColor3 = Color3.fromRGB(90,80,110)
        else
            f.cell.BackgroundColor3 = Color3.fromRGB(30,22,50)
            f.emoji.TextTransparency = 0; f.label.TextTransparency = 0
            f.jour.TextColor3 = C.texteDim
        end
    end
    lblDailyStatus.Text = graineDispo and "✅ Daily seed available!" or ""
end

local function majArbreTimer()
    if arbreGraineDispo then
        lblArbreTimer.Text = "🌱 Seed available on trees!"; lblArbreTimer.TextColor3 = C.vert
    elseif arbreTimerLocal > 0 then
        lblArbreTimer.Text = "⏳ " .. formatTimer(arbreTimerLocal); lblArbreTimer.TextColor3 = C.arbre
    else
        lblArbreTimer.Text = "⏳ --:--"; lblArbreTimer.TextColor3 = C.arbre
    end
end

local function majDailyTimer()
    if dailyClaimable then lblDailyTimer.Text = "✅ Daily seed ready!"
    elseif dailyTimerLocal > 0 then lblDailyTimer.Text = "⏰ " .. formatTimer(dailyTimerLocal)
    else lblDailyTimer.Text = "⏰ --:--:--" end
end

-- ============================================================
-- Boucle décompte local (1 tick/s)
-- ============================================================
task.spawn(function()
    while true do
        task.wait(1)
        if not arbreGraineDispo and arbreTimerLocal > 0 then
            arbreTimerLocal = arbreTimerLocal - 1
            if arbreTimerLocal <= 0 then arbreGraineDispo = true end
        end
        if not dailyClaimable and dailyTimerLocal > 0 then
            dailyTimerLocal = dailyTimerLocal - 1
            if dailyTimerLocal <= 0 then dailyClaimable = true end
        end
        if panel.Visible then
            majArbreTimer(); majDailyTimer()
        end
    end
end)

-- ============================================================
-- Connexions RemoteEvents (en tâche séparée — ne bloque pas l'UI)
-- ============================================================
local GetSeedInfo   = nil
local UpdateGraines = nil

local function rafraichir()
    if not GetSeedInfo then return end
    local ok, info = pcall(function() return GetSeedInfo:InvokeServer() end)
    if not ok or not info then
        Logger.warn("HUD", "[SeedsHUD] GetSeedInfo erreur : %s", tostring(info))
        return
    end
    majStock(info.graines)
    majPots(info.pots)
    majCalendrier(info)
    arbreTimerLocal  = info.arbreTimerRestant or 0
    arbreGraineDispo = info.arbreGraineDispo  or false
    majArbreTimer()
    if info.dailySeed then
        local elapsed = os.time() - (info.dailySeed.dernieresClaim or 0)
        local restant = math.max(0, ((info.intervalleHeures or 24) * 3600) - elapsed)
        dailyClaimable  = info.dailySeed.graineDispo or (restant <= 0)
        dailyTimerLocal = restant
        majDailyTimer()
    end
end

task.spawn(function()
    -- Attendre les remotes en arrière-plan (ne bloque pas le bouton)
    GetSeedInfo   = ReplicatedStorage:WaitForChild("GetSeedInfo",   20)
    UpdateGraines = ReplicatedStorage:WaitForChild("UpdateGraines", 20)

    if not GetSeedInfo then
        Logger.warn("HUD", "[SeedsHUD] GetSeedInfo introuvable après 20s")
        return
    end

    if UpdateGraines then
        UpdateGraines.OnClientEvent:Connect(function(graines)
            majStock(graines)
        end)
    end

    -- Chargement initial
    task.wait(3)
    rafraichir()
end)

-- ============================================================
-- Ouverture / Fermeture du panel
-- ============================================================
local panelOuvert = false

local function ouvrirPanel()
    panelOuvert   = true
    panel.Visible = true
    task.spawn(rafraichir)
end

local function fermerPanel()
    panelOuvert   = false
    panel.Visible = false
end

btnSeeds.MouseButton1Click:Connect(function()
    if panelOuvert then fermerPanel() else ouvrirPanel() end
end)

btnFermer.MouseButton1Click:Connect(fermerPanel)

btnSeeds.MouseEnter:Connect(function()
    TweenService:Create(btnSeeds, TweenInfo.new(0.12),
        { BackgroundColor3 = Color3.fromRGB(30, 60, 30) }):Play()
end)
btnSeeds.MouseLeave:Connect(function()
    TweenService:Create(btnSeeds, TweenInfo.new(0.12),
        { BackgroundColor3 = Color3.fromRGB(20, 40, 20) }):Play()
end)
