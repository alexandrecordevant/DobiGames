-- StarterPlayerScripts/BaseProgressHUD.client.lua
-- Barre permanente "Évolution de la Base" — 3 jauges empilées :
--   🔧 Base    : upgrades de base maxés
--   🌱 Graines : graines quotidiennes de la semaine (x/7)
--   🌈 Mutants : mutants flowerpot collectionnés
-- Pilotée par le serveur :
--   • UpdateHUD (hudData.baseProgress = {base,seeds,mutants})  → remplit les barres
--   • BaseProgressMilestone (palier franchi)                   → popup de célébration

local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ModalManager = require(RS:WaitForChild("SharedLib"):WaitForChild("ModalManager"))
local UpdateHUD             = RS:WaitForChild("UpdateHUD")
local BaseProgressMilestone = RS:WaitForChild("BaseProgressMilestone")

local GOLD = Color3.fromRGB(255, 215, 60)

-- Définition des 3 jauges (ordre d'affichage)
local JAUGES = {
    { key = "base",    icone = "🔧", nom = "Base",   couleur = Color3.fromRGB(90, 175, 255),  format = "frac" },
    { key = "seeds",   icone = "🌱", nom = "Seed",   couleur = Color3.fromRGB(120, 220, 120), format = "frac" },
    { key = "mutants", icone = "🌈", nom = "Mutant", couleur = Color3.fromRGB(210, 120, 255), format = "pct"  },
}

-- ============================================================
-- Construction de la carte
-- ============================================================
local sg = Instance.new("ScreenGui")
sg.Name           = "BaseProgressHUD"
sg.ResetOnSpawn   = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.DisplayOrder   = 15
sg.IgnoreGuiInset = true
sg.Parent         = playerGui

local ROW_H   = 20
local panneau = Instance.new("Frame", sg)
panneau.Name                   = "Panneau"
-- Bas-droite, juste au-dessus des compteurs (FREE LUCKY BLOCK / Next Event)
panneau.AnchorPoint            = Vector2.new(1, 1)
panneau.Position               = UDim2.new(1, -8, 1, -212)
panneau.Size                   = UDim2.new(0, 250, 0, 26 + (#JAUGES * ROW_H) + 8)
panneau.BackgroundColor3       = Color3.fromRGB(15, 15, 18)
panneau.BackgroundTransparency = 0.15
panneau.BorderSizePixel        = 0
Instance.new("UICorner", panneau).CornerRadius = UDim.new(0, 10)
local pStroke = Instance.new("UIStroke", panneau)
pStroke.Color        = Color3.fromRGB(60, 60, 70)
pStroke.Thickness    = 1
pStroke.Transparency = 0.3

local titre = Instance.new("TextLabel", panneau)
titre.Size                   = UDim2.new(1, -12, 0, 22)
titre.Position               = UDim2.new(0, 6, 0, 3)
titre.BackgroundTransparency = 1
titre.Font                   = Enum.Font.GothamBold
titre.TextSize               = 13
titre.TextColor3             = GOLD
titre.TextXAlignment         = Enum.TextXAlignment.Center
titre.Text                   = "🏆 BASE EVOLUTION"

-- Construit une ligne (icône + nom + barre + valeur) ; retourne les éléments animables
local LABEL_W = 64   -- largeur du libellé "🔧 Base"
local function creerLigne(def, indexLigne)
    local y = 26 + (indexLigne - 1) * ROW_H

    local icone = Instance.new("TextLabel", panneau)
    icone.Size                   = UDim2.new(0, LABEL_W, 0, ROW_H - 2)
    icone.Position               = UDim2.new(0, 6, 0, y)
    icone.BackgroundTransparency = 1
    icone.Font                   = Enum.Font.GothamBold
    icone.TextSize               = 12
    icone.TextXAlignment         = Enum.TextXAlignment.Left
    icone.TextColor3             = Color3.fromRGB(235, 235, 235)
    icone.Text                   = def.icone .. " " .. def.nom

    local barreX = 6 + LABEL_W + 4
    local fond = Instance.new("Frame", panneau)
    fond.Size                   = UDim2.new(1, -(barreX + 52), 0, 11)
    fond.Position               = UDim2.new(0, barreX, 0, y + 3)
    fond.BackgroundColor3       = Color3.fromRGB(42, 42, 48)
    fond.BorderSizePixel        = 0
    Instance.new("UICorner", fond).CornerRadius = UDim.new(0, 5)

    local fill = Instance.new("Frame", fond)
    fill.Size                   = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3       = def.couleur
    fill.BorderSizePixel        = 0
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 5)

    local valeur = Instance.new("TextLabel", panneau)
    valeur.Size                   = UDim2.new(0, 46, 0, ROW_H - 2)
    valeur.Position               = UDim2.new(1, -50, 0, y)
    valeur.BackgroundTransparency = 1
    valeur.Font                   = Enum.Font.GothamBold
    valeur.TextSize               = 12
    valeur.TextColor3             = Color3.fromRGB(200, 200, 205)
    valeur.TextXAlignment         = Enum.TextXAlignment.Right
    valeur.Text                   = "—"

    return { fill = fill, valeur = valeur, couleur = def.couleur }
end

local lignes = {}
for i, def in ipairs(JAUGES) do
    lignes[def.key] = creerLigne(def, i)
end

-- ============================================================
-- Mise à jour des jauges
-- ============================================================
local function rendre(bp)
    for _, def in ipairs(JAUGES) do
        local j   = bp[def.key]
        local row = lignes[def.key]
        if j and row then
            local maxV = tonumber(j.max) or 0
            local curV = tonumber(j.cur) or 0
            local pct  = (maxV > 0) and math.clamp((tonumber(j.pct) or (curV / maxV)), 0, 1) or 0

            TweenService:Create(row.fill,
                TweenInfo.new(0.3, Enum.EasingStyle.Quad),
                { Size = UDim2.new(pct, 0, 1, 0) }
            ):Play()

            if maxV <= 0 then
                row.valeur.Text = "—"
            elseif def.format == "frac" then
                row.valeur.Text = string.format("%d/%d", curV, maxV)
            else
                row.valeur.Text = string.format("%d%%", math.floor(pct * 100 + 0.5))
            end

            -- Jauge complétée : valeur en doré
            row.valeur.TextColor3 = (pct >= 1 and maxV > 0)
                and GOLD or Color3.fromRGB(200, 200, 205)
        end
    end
end

UpdateHUD.OnClientEvent:Connect(function(hudData)
    if hudData and hudData.baseProgress then
        rendre(hudData.baseProgress)
    end
end)

-- ============================================================
-- Popup de célébration (palier franchi)
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

    local pad = Instance.new("UIPadding", card)
    pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 16), UDim.new(0, 16)
    pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 16), UDim.new(0, 16)

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
    if typeof(info) == "table" then
        afficherCelebration(info)
    end
end)
