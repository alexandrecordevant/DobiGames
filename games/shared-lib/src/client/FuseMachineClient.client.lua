-- shared-lib/src/client/FuseMachineClient.client.lua
-- UI Fuse Machine -- commune BrainRotFarm & LavaTower

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Logger           = require(game:GetService("ReplicatedStorage").SharedLib.Logger)

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

Logger.info("Fuse", "Script demarre")
local OuvrirUI   = ReplicatedStorage:WaitForChild("FuseMachine_OuvrirUI",   60)
local FermerUI   = ReplicatedStorage:WaitForChild("FuseMachine_FermerUI",   60)
local EtatUpdate = ReplicatedStorage:WaitForChild("FuseMachine_EtatUpdate", 60)
local Lancer     = ReplicatedStorage:WaitForChild("FuseMachine_Lancer",     60)

if not OuvrirUI then
    Logger.warn("Fuse", "RemoteEvents introuvables apres 60s -- FuseMachineSystem.Init() appele ?")
    return
end
Logger.info("Fuse", "RemoteEvents trouves")

-- ═══════════════════════════════════════════════════════════════════════════════
-- Palette
-- ═══════════════════════════════════════════════════════════════════════════════
local C_BG            = Color3.fromRGB(10,  10,  10)
local C_BG2           = Color3.fromRGB(18,  18,  18)
local C_BG3           = Color3.fromRGB(25,  25,  25)
local C_ACCENT        = Color3.fromRGB(160, 80,  15)
local C_ACCENT_LIGHT  = Color3.fromRGB(180, 95,  20)
local C_TEXTE         = Color3.fromRGB(220, 220, 220)
local C_TEXTE2        = Color3.fromRGB(130, 130, 130)
local C_BORDURE       = Color3.fromRGB(60,  60,  60)
local C_SLOT          = Color3.fromRGB(18,  18,  18)
local C_SLOT_FILL     = Color3.fromRGB(32,  32,  32)
local C_BTN_ON        = Color3.fromRGB(160, 80,  15)
local C_BTN_OFF       = Color3.fromRGB(40,  40,  40)
local C_FERMER        = Color3.fromRGB(50,  50,  50)
local C_ORANGE_STROKE = Color3.fromRGB(180, 90,  20)
local C_INVALIDE      = Color3.fromRGB(160, 60,  60)
local C_VALIDE        = Color3.fromRGB(123, 198, 126)

local COULEUR_RARETE = {
    Common    = Color3.fromRGB(200, 200, 200),
    Uncommon  = Color3.fromRGB(100, 200, 100),
    Rare      = Color3.fromRGB(100, 130, 255),
    Epic      = Color3.fromRGB(180, 50,  255),
    Legendary = Color3.fromRGB(255, 200, 0),
    Secret    = Color3.fromRGB(255, 50,  50),
}
local ICONE_RARETE = {
    Common    = "C",
    Uncommon  = "U",
    Rare      = "R",
    Epic      = "E",
    Legendary = "L",
    Secret    = "S",
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- Etat client
-- ═══════════════════════════════════════════════════════════════════════════════
local machineActuelle     = nil
local etatMachine         = {}
local recettesDisponibles = {}
local slotsSelectionnes   = {}
local recetteTrouvee      = nil
local timerConn           = nil
local estEnFermeture      = false

local screenGui, cadre
local frameSelection, frameTimer
local slotsFrames = {}
local carryFrame
local labelResultat, labelCout, btnLancer
local barreProgress, labelTimer
local barreResultatGauche

local fermerUI
local viderSlot
local mettreAJourRecette
local rafraichirCarry
local rafraichirSlot

-- ═══════════════════════════════════════════════════════════════════════════════
-- Helpers UI
-- ═══════════════════════════════════════════════════════════════════════════════
local function coin(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 0)
    c.Parent = parent
    return c
end

local function stroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color     = color or C_BORDURE
    s.Thickness = thickness or 1
    s.Name      = "Stroke"
    s.Parent    = parent
    return s
end

local function addHover(btn)
    local couleurBase = nil
    local tweenActif  = nil
    local strokeInst  = btn:FindFirstChild("Stroke")

    btn.MouseEnter:Connect(function()
        if not couleurBase then couleurBase = btn.BackgroundColor3 end
        local cible = Color3.new(
            math.min(1, couleurBase.R + 0.08),
            math.min(1, couleurBase.G + 0.08),
            math.min(1, couleurBase.B + 0.08)
        )
        if tweenActif then tweenActif:Cancel() end
        tweenActif = TweenService:Create(btn, TweenInfo.new(0.08), { BackgroundColor3 = cible })
        tweenActif:Play()
        if strokeInst then
            TweenService:Create(strokeInst, TweenInfo.new(0.08), { Color = C_ORANGE_STROKE }):Play()
        end
    end)

    btn.MouseLeave:Connect(function()
        if not couleurBase then return end
        local restaurer = couleurBase
        couleurBase = nil
        if tweenActif then tweenActif:Cancel() end
        tweenActif = TweenService:Create(btn, TweenInfo.new(0.08), { BackgroundColor3 = restaurer })
        tweenActif:Play()
        if strokeInst then
            TweenService:Create(strokeInst, TweenInfo.new(0.08), { Color = C_BORDURE }):Play()
        end
    end)
end

local function creerSectionLabel(parent, texte, yPos)
    local cont = Instance.new("Frame")
    cont.Size                   = UDim2.new(1, 0, 0, 18)
    cont.Position               = UDim2.new(0, 0, 0, yPos)
    cont.BackgroundTransparency = 1
    cont.BorderSizePixel        = 0
    cont.Parent                 = parent

    local barre = Instance.new("Frame")
    barre.Size             = UDim2.new(0, 3, 1, 0)
    barre.BackgroundColor3 = C_ACCENT
    barre.BorderSizePixel  = 0
    barre.Parent           = cont

    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.new(1, -10, 1, 0)
    lbl.Position               = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = texte
    lbl.TextColor3             = C_ACCENT
    lbl.TextSize               = 11
    lbl.TextScaled             = false
    lbl.Font                   = Enum.Font.GothamBold
    lbl.TextXAlignment         = Enum.TextXAlignment.Left
    lbl.Parent                 = cont

    return cont
end

local function hexColor(c3)
    return string.format("#%02X%02X%02X",
        math.floor(c3.R * 255),
        math.floor(c3.G * 255),
        math.floor(c3.B * 255))
end

local function formaterTemps(sec)
    sec = math.max(0, math.floor(sec))
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    local s = sec % 60
    return string.format("%02dh %02dm %02ds", h, m, s)
end

local function trierInputs(liste)
    local c = {}
    for _, v in ipairs(liste) do c[#c + 1] = v end
    table.sort(c)
    return c
end

local function inputsEgaux(a, b)
    if #a ~= #b then return false end
    for i, v in ipairs(a) do if v ~= b[i] then return false end end
    return true
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- Construction UI
-- ═══════════════════════════════════════════════════════════════════════════════
local function creerUI()
    screenGui = Instance.new("ScreenGui")
    screenGui.Name           = "FuseMachineUI"
    screenGui.ResetOnSpawn   = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.IgnoreGuiInset = true
    screenGui.Enabled        = false
    screenGui.Parent         = playerGui

    cadre = Instance.new("Frame")
    cadre.Name                   = "Cadre"
    cadre.Size                   = UDim2.new(0, 480, 0, 510)
    cadre.AnchorPoint            = Vector2.new(0.5, 0.5)
    cadre.Position               = UDim2.new(0.5, 0, 1.5, 0)
    cadre.BackgroundColor3       = C_BG
    cadre.BackgroundTransparency = 0.05
    cadre.BorderSizePixel        = 0
    cadre.Parent                 = screenGui
    coin(cadre, 0)
    stroke(cadre, C_BORDURE, 1)

    local uiScale = Instance.new("UIScale")
    uiScale.Parent = cadre
    local function ajusterScale()
        local vp = workspace.CurrentCamera.ViewportSize
        local s  = math.min(vp.X / 540, vp.Y / 630, 1)
        uiScale.Scale = math.max(0.55, s)
    end
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(ajusterScale)
    ajusterScale()

    -- ─── Header ──────────────────────────────────────────────────────────────
    local accentBande = Instance.new("Frame")
    accentBande.Size             = UDim2.new(0, 3, 0, 52)
    accentBande.BackgroundColor3 = C_ACCENT
    accentBande.BorderSizePixel  = 0
    accentBande.ZIndex           = 3
    accentBande.Parent           = cadre

    local titreBar = Instance.new("Frame")
    titreBar.Name                   = "TitreBar"
    titreBar.Size                   = UDim2.new(1, 0, 0, 52)
    titreBar.BackgroundTransparency = 1
    titreBar.BorderSizePixel        = 0
    titreBar.Parent                 = cadre

    local lTitre = Instance.new("TextLabel")
    lTitre.Size                   = UDim2.new(1, -60, 0, 28)
    lTitre.Position               = UDim2.new(0, 16, 0, 8)
    lTitre.BackgroundTransparency = 1
    lTitre.Text                   = "FUSE MACHINE"
    lTitre.TextColor3             = C_TEXTE
    lTitre.TextSize               = 18
    lTitre.TextScaled             = false
    lTitre.Font                   = Enum.Font.GothamBold
    lTitre.TextXAlignment         = Enum.TextXAlignment.Left
    lTitre.Parent                 = titreBar

    local lSousTitre = Instance.new("TextLabel")
    lSousTitre.Size                   = UDim2.new(1, -60, 0, 16)
    lSousTitre.Position               = UDim2.new(0, 16, 0, 32)
    lSousTitre.BackgroundTransparency = 1
    lSousTitre.Text                   = "Combine 4 Brainrots to get a better one!"
    lSousTitre.TextColor3             = C_TEXTE2
    lSousTitre.TextSize               = 10
    lSousTitre.TextScaled             = false
    lSousTitre.Font                   = Enum.Font.Gotham
    lSousTitre.TextXAlignment         = Enum.TextXAlignment.Left
    lSousTitre.Parent                 = titreBar

    local sep = Instance.new("Frame")
    sep.Size             = UDim2.new(1, 0, 0, 1)
    sep.Position         = UDim2.new(0, 0, 0, 52)
    sep.BackgroundColor3 = C_BORDURE
    sep.BorderSizePixel  = 0
    sep.Parent           = cadre

    local btnX = Instance.new("TextButton")
    btnX.Size             = UDim2.new(0, 44, 0, 44)
    btnX.Position         = UDim2.new(1, -50, 0, 4)
    btnX.BackgroundColor3 = C_FERMER
    btnX.BorderSizePixel  = 0
    btnX.Text             = "X"
    btnX.TextColor3       = Color3.fromRGB(180, 180, 180)
    btnX.TextSize         = 16
    btnX.TextScaled       = false
    btnX.Font             = Enum.Font.GothamBold
    btnX.AutoButtonColor  = false
    btnX.Parent           = titreBar
    coin(btnX, 2)
    stroke(btnX, C_BORDURE, 1)
    addHover(btnX)
    btnX.MouseButton1Click:Connect(function() fermerUI() end)

    -- ─── FRAME SELECTION ─────────────────────────────────────────────────────
    frameSelection = Instance.new("Frame")
    frameSelection.Name                   = "FrameSelection"
    frameSelection.Size                   = UDim2.new(1, -24, 1, -62)
    frameSelection.Position               = UDim2.new(0, 12, 0, 58)
    frameSelection.BackgroundTransparency = 1
    frameSelection.Visible                = true
    frameSelection.Parent                 = cadre

    local slotsConteneur = Instance.new("Frame")
    slotsConteneur.Size                   = UDim2.new(1, 0, 0, 100)
    slotsConteneur.Position               = UDim2.new(0, 0, 0, 0)
    slotsConteneur.BackgroundTransparency = 1
    slotsConteneur.Parent                 = frameSelection

    local slotLayout = Instance.new("UIListLayout")
    slotLayout.FillDirection       = Enum.FillDirection.Horizontal
    slotLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    slotLayout.VerticalAlignment   = Enum.VerticalAlignment.Center
    slotLayout.Padding             = UDim.new(0, 7)
    slotLayout.Parent              = slotsConteneur

    slotsFrames = {}
    for i = 1, 4 do
        local slot = Instance.new("TextButton")
        slot.Name                   = "Slot" .. i
        slot.Size                   = UDim2.new(0, 100, 0, 100)
        slot.BackgroundColor3       = C_SLOT
        slot.BackgroundTransparency = 0
        slot.BorderSizePixel        = 0
        slot.Text                   = ""
        slot.AutoButtonColor        = false
        slot.Parent                 = slotsConteneur
        coin(slot, 0)
        stroke(slot, C_BORDURE, 1)

        local iconeL = Instance.new("TextLabel")
        iconeL.Name                   = "Icone"
        iconeL.Size                   = UDim2.new(1, 0, 0, 52)
        iconeL.Position               = UDim2.new(0, 0, 0, 14)
        iconeL.BackgroundTransparency = 1
        iconeL.Text                   = "+"
        iconeL.TextColor3             = C_BORDURE
        iconeL.TextSize               = 26
        iconeL.TextScaled             = false
        iconeL.Font                   = Enum.Font.GothamBold
        iconeL.Parent                 = slot

        local nomL = Instance.new("TextLabel")
        nomL.Name                   = "Nom"
        nomL.Size                   = UDim2.new(1, -6, 0, 22)
        nomL.Position               = UDim2.new(0, 3, 0, 66)
        nomL.BackgroundTransparency = 1
        nomL.Text                   = ""
        nomL.TextColor3             = C_TEXTE2
        nomL.TextSize               = 9
        nomL.TextScaled             = false
        nomL.Font                   = Enum.Font.Gotham
        nomL.TextWrapped            = true
        nomL.TextXAlignment         = Enum.TextXAlignment.Center
        nomL.Parent                 = slot

        local idx = i
        slot.MouseButton1Click:Connect(function() viderSlot(idx) end)
        slotsFrames[i] = slot
    end

    local sep2 = Instance.new("Frame")
    sep2.Size             = UDim2.new(1, 0, 0, 1)
    sep2.Position         = UDim2.new(0, 0, 0, 106)
    sep2.BackgroundColor3 = C_BORDURE
    sep2.BorderSizePixel  = 0
    sep2.Parent           = frameSelection

    creerSectionLabel(frameSelection, "POSSIBLE RESULT", 111)

    local resultFrame = Instance.new("Frame")
    resultFrame.Name                   = "ResultFrame"
    resultFrame.Size                   = UDim2.new(1, 0, 0, 56)
    resultFrame.Position               = UDim2.new(0, 0, 0, 133)
    resultFrame.BackgroundColor3       = C_BG2
    resultFrame.BackgroundTransparency = 0
    resultFrame.BorderSizePixel        = 0
    resultFrame.Parent                 = frameSelection
    coin(resultFrame, 0)
    stroke(resultFrame, C_BORDURE, 1)

    barreResultatGauche = Instance.new("Frame")
    barreResultatGauche.Name             = "BarreGauche"
    barreResultatGauche.Size             = UDim2.new(0, 4, 1, 0)
    barreResultatGauche.BackgroundColor3 = C_BORDURE
    barreResultatGauche.BorderSizePixel  = 0
    barreResultatGauche.Parent           = resultFrame

    labelResultat = Instance.new("TextLabel")
    labelResultat.Name                   = "LabelResultat"
    labelResultat.Size                   = UDim2.new(1, -14, 1, 0)
    labelResultat.Position               = UDim2.new(0, 14, 0, 0)
    labelResultat.BackgroundTransparency = 1
    labelResultat.Text                   = "<font color='#828282'>Select 4 Brainrots!</font>"
    labelResultat.TextColor3             = C_TEXTE
    labelResultat.TextSize               = 13
    labelResultat.TextScaled             = false
    labelResultat.Font                   = Enum.Font.GothamBold
    labelResultat.RichText               = true
    labelResultat.Parent                 = resultFrame

    local coutFrame = Instance.new("Frame")
    coutFrame.Size                   = UDim2.new(1, 0, 0, 28)
    coutFrame.Position               = UDim2.new(0, 0, 0, 193)
    coutFrame.BackgroundColor3       = C_BG3
    coutFrame.BackgroundTransparency = 0
    coutFrame.BorderSizePixel        = 0
    coutFrame.Parent                 = frameSelection
    coin(coutFrame, 0)
    stroke(coutFrame, C_BORDURE, 1)

    labelCout = Instance.new("TextLabel")
    labelCout.Name                   = "LabelCout"
    labelCout.Size                   = UDim2.new(1, -10, 1, 0)
    labelCout.Position               = UDim2.new(0, 10, 0, 0)
    labelCout.BackgroundTransparency = 1
    labelCout.Text                   = ""
    labelCout.TextColor3             = C_TEXTE2
    labelCout.TextSize               = 12
    labelCout.TextScaled             = false
    labelCout.Font                   = Enum.Font.Gotham
    labelCout.RichText               = true
    labelCout.TextXAlignment         = Enum.TextXAlignment.Left
    labelCout.Parent                 = coutFrame

    carryFrame = Instance.new("ScrollingFrame")
    carryFrame.Name                   = "CarryFrame"
    carryFrame.Size                   = UDim2.new(1, 0, 0, 112)
    carryFrame.Position               = UDim2.new(0, 0, 0, 225)
    carryFrame.BackgroundColor3       = C_BG2
    carryFrame.BackgroundTransparency = 0
    carryFrame.BorderSizePixel        = 0
    carryFrame.ScrollBarThickness     = 4
    carryFrame.ScrollBarImageColor3   = C_ACCENT
    carryFrame.CanvasSize             = UDim2.new(0, 0, 0, 0)
    carryFrame.AutomaticCanvasSize    = Enum.AutomaticSize.XY
    carryFrame.ScrollingDirection     = Enum.ScrollingDirection.X
    carryFrame.Parent                 = frameSelection
    coin(carryFrame, 0)
    stroke(carryFrame, C_BORDURE, 1)

    local carryLayout = Instance.new("UIListLayout")
    carryLayout.FillDirection     = Enum.FillDirection.Horizontal
    carryLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    carryLayout.Padding           = UDim.new(0, 6)
    carryLayout.Parent            = carryFrame

    local carryPad = Instance.new("UIPadding")
    carryPad.PaddingLeft   = UDim.new(0, 8)
    carryPad.PaddingRight  = UDim.new(0, 8)
    carryPad.PaddingTop    = UDim.new(0, 6)
    carryPad.PaddingBottom = UDim.new(0, 6)
    carryPad.Parent        = carryFrame

    btnLancer = Instance.new("TextButton")
    btnLancer.Name             = "BtnLancer"
    btnLancer.Size             = UDim2.new(1, 0, 0, 52)
    btnLancer.Position         = UDim2.new(0, 0, 0, 342)
    btnLancer.BackgroundColor3 = C_BTN_OFF
    btnLancer.BorderSizePixel  = 0
    btnLancer.Text             = "Select 4 Brainrots"
    btnLancer.TextColor3       = C_TEXTE2
    btnLancer.TextSize         = 14
    btnLancer.TextScaled       = false
    btnLancer.Font             = Enum.Font.Gotham
    btnLancer.AutoButtonColor  = false
    btnLancer.Parent           = frameSelection
    coin(btnLancer, 2)
    stroke(btnLancer, C_BORDURE, 1)
    addHover(btnLancer)
    btnLancer.MouseButton1Click:Connect(function() onLancerFusion() end)

    -- ─── FRAME TIMER ─────────────────────────────────────────────────────────
    frameTimer = Instance.new("Frame")
    frameTimer.Name                   = "FrameTimer"
    frameTimer.Size                   = UDim2.new(1, -24, 1, -62)
    frameTimer.Position               = UDim2.new(0, 12, 0, 58)
    frameTimer.BackgroundTransparency = 1
    frameTimer.Visible                = false
    frameTimer.Parent                 = cadre

    local bandeauTimer = Instance.new("Frame")
    bandeauTimer.Size             = UDim2.new(1, 0, 0, 44)
    bandeauTimer.Position         = UDim2.new(0, 0, 0, 0)
    bandeauTimer.BackgroundColor3 = Color3.fromRGB(50, 25, 5)
    bandeauTimer.BorderSizePixel  = 0
    bandeauTimer.Parent           = frameTimer
    coin(bandeauTimer, 0)
    stroke(bandeauTimer, C_ACCENT, 1)

    local lBandeauAccent = Instance.new("Frame")
    lBandeauAccent.Size             = UDim2.new(0, 4, 1, 0)
    lBandeauAccent.BackgroundColor3 = C_ACCENT
    lBandeauAccent.BorderSizePixel  = 0
    lBandeauAccent.Parent           = bandeauTimer

    local lEnCours = Instance.new("TextLabel")
    lEnCours.Size                   = UDim2.new(1, -14, 1, 0)
    lEnCours.Position               = UDim2.new(0, 14, 0, 0)
    lEnCours.BackgroundTransparency = 1
    lEnCours.Text                   = "FUSION IN PROGRESS..."
    lEnCours.TextColor3             = C_ACCENT_LIGHT
    lEnCours.TextSize               = 16
    lEnCours.TextScaled             = false
    lEnCours.Font                   = Enum.Font.GothamBold
    lEnCours.TextXAlignment         = Enum.TextXAlignment.Left
    lEnCours.Parent                 = bandeauTimer

    local lSurprise = Instance.new("TextLabel")
    lSurprise.Name                   = "Surprise"
    lSurprise.Size                   = UDim2.new(1, 0, 0, 28)
    lSurprise.Position               = UDim2.new(0, 0, 0, 54)
    lSurprise.BackgroundTransparency = 1
    lSurprise.Text                   = "Result: ???"
    lSurprise.TextColor3             = C_TEXTE2
    lSurprise.TextSize               = 14
    lSurprise.TextScaled             = false
    lSurprise.Font                   = Enum.Font.Gotham
    lSurprise.Parent                 = frameTimer

    local barreConteneur = Instance.new("Frame")
    barreConteneur.Size             = UDim2.new(1, 0, 0, 28)
    barreConteneur.Position         = UDim2.new(0, 0, 0, 92)
    barreConteneur.BackgroundColor3 = C_BG2
    barreConteneur.BorderSizePixel  = 0
    barreConteneur.Parent           = frameTimer
    coin(barreConteneur, 2)
    stroke(barreConteneur, C_BORDURE, 1)

    barreProgress = Instance.new("Frame")
    barreProgress.Name             = "Barre"
    barreProgress.Size             = UDim2.new(0, 0, 1, 0)
    barreProgress.BackgroundColor3 = C_ACCENT
    barreProgress.BorderSizePixel  = 0
    barreProgress.Parent           = barreConteneur
    coin(barreProgress, 2)

    local timerConteneur = Instance.new("Frame")
    timerConteneur.Size                   = UDim2.new(1, 0, 0, 56)
    timerConteneur.Position               = UDim2.new(0, 0, 0, 130)
    timerConteneur.BackgroundColor3       = C_BG2
    timerConteneur.BackgroundTransparency = 0
    timerConteneur.BorderSizePixel        = 0
    timerConteneur.Parent                 = frameTimer
    coin(timerConteneur, 0)
    stroke(timerConteneur, C_BORDURE, 1)

    local timerAccent = Instance.new("Frame")
    timerAccent.Size             = UDim2.new(0, 4, 1, 0)
    timerAccent.BackgroundColor3 = C_ACCENT
    timerAccent.BorderSizePixel  = 0
    timerAccent.Parent           = timerConteneur

    local timerPrefixe = Instance.new("TextLabel")
    timerPrefixe.Size                   = UDim2.new(0, 80, 1, 0)
    timerPrefixe.Position               = UDim2.new(0, 14, 0, 0)
    timerPrefixe.BackgroundTransparency = 1
    timerPrefixe.Text                   = "TIME"
    timerPrefixe.TextColor3             = C_TEXTE2
    timerPrefixe.TextSize               = 10
    timerPrefixe.TextScaled             = false
    timerPrefixe.Font                   = Enum.Font.GothamBold
    timerPrefixe.TextXAlignment         = Enum.TextXAlignment.Left
    timerPrefixe.Parent                 = timerConteneur

    labelTimer = Instance.new("TextLabel")
    labelTimer.Name                   = "LabelTimer"
    labelTimer.Size                   = UDim2.new(1, -14, 1, 0)
    labelTimer.Position               = UDim2.new(0, 14, 0, 0)
    labelTimer.BackgroundTransparency = 1
    labelTimer.Text                   = "--h --m --s"
    labelTimer.TextColor3             = C_TEXTE
    labelTimer.TextSize               = 26
    labelTimer.TextScaled             = false
    labelTimer.Font                   = Enum.Font.GothamBold
    labelTimer.TextXAlignment         = Enum.TextXAlignment.Right
    labelTimer.Parent                 = timerConteneur

    local lRappel = Instance.new("TextLabel")
    lRappel.Size                   = UDim2.new(1, 0, 0, 28)
    lRappel.Position               = UDim2.new(0, 0, 0, 196)
    lRappel.BackgroundTransparency = 1
    lRappel.Text                   = "Come back with the ProximityPrompt when it's ready."
    lRappel.TextColor3             = C_TEXTE2
    lRappel.TextSize               = 11
    lRappel.TextScaled             = false
    lRappel.Font                   = Enum.Font.Gotham
    lRappel.TextWrapped            = true
    lRappel.TextXAlignment         = Enum.TextXAlignment.Center
    lRappel.Parent                 = frameTimer
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- Logique slots
-- ═══════════════════════════════════════════════════════════════════════════════
rafraichirSlot = function(i)
    local slot = slotsFrames[i]
    if not slot then return end

    local tool   = slotsSelectionnes[i]
    local iconeL = slot:FindFirstChild("Icone")
    local nomL   = slot:FindFirstChild("Nom")
    local st     = slot:FindFirstChild("Stroke")

    if tool and tool.Parent then
        local rarete = tool:GetAttribute("Rarete") or "Common"
        local brName = tool:GetAttribute("BrainrotName") or tool.Name
        local coul   = COULEUR_RARETE[rarete] or Color3.fromRGB(200, 200, 200)

        slot.BackgroundColor3 = C_SLOT_FILL
        if st then st.Color = coul ; st.Thickness = 2 end
        if iconeL then
            iconeL.Text       = ICONE_RARETE[rarete] or "?"
            iconeL.TextColor3 = coul
            iconeL.TextSize   = 28
        end
        if nomL then
            nomL.Text       = brName
            nomL.TextColor3 = C_TEXTE
        end
    else
        slotsSelectionnes[i] = nil
        slot.BackgroundColor3 = C_SLOT
        if st then st.Color = C_BORDURE ; st.Thickness = 1 end
        if iconeL then
            iconeL.Text       = "+"
            iconeL.TextColor3 = C_BORDURE
            iconeL.TextSize   = 26
        end
        if nomL then
            nomL.Text       = ""
            nomL.TextColor3 = C_TEXTE2
        end
    end
end

viderSlot = function(i)
    slotsSelectionnes[i] = nil
    rafraichirSlot(i)
    mettreAJourRecette()
    rafraichirCarry()
end

local function premierSlotVide()
    for i = 1, 4 do
        if not slotsSelectionnes[i] then return i end
    end
    return nil
end

mettreAJourRecette = function()
    local raretes = {}
    local complet = true
    for i = 1, 4 do
        local t = slotsSelectionnes[i]
        if t and t.Parent then
            raretes[#raretes + 1] = t:GetAttribute("Rarete") or "Common"
        else
            complet = false
        end
    end

    if not complet or #raretes < 4 then
        recetteTrouvee = nil
        if labelResultat then
            labelResultat.Text = "<font color='#828282'>Select 4 Brainrots!</font>"
        end
        if barreResultatGauche then barreResultatGauche.BackgroundColor3 = C_BORDURE end
        if labelCout then labelCout.Text = "" end
        if btnLancer then
            btnLancer.BackgroundColor3 = C_BTN_OFF
            btnLancer.Text             = "Select 4 Brainrots"
            btnLancer.TextColor3       = C_TEXTE2
            btnLancer.Font             = Enum.Font.Gotham
            btnLancer.TextSize         = 14
        end
        return
    end

    local inputsTries = trierInputs(raretes)
    recetteTrouvee = nil
    for _, recette in ipairs(recettesDisponibles) do
        if inputsEgaux(inputsTries, trierInputs(recette.inputs)) then
            recetteTrouvee = recette
            break
        end
    end

    if not recetteTrouvee then
        if labelResultat then
            labelResultat.Text = "<font color='#e07070'>Invalid combination</font>"
        end
        if barreResultatGauche then barreResultatGauche.BackgroundColor3 = C_INVALIDE end
        if labelCout then labelCout.Text = "" end
        if btnLancer then
            btnLancer.BackgroundColor3 = C_BTN_OFF
            btnLancer.Text             = "Invalid combination"
            btnLancer.TextColor3       = C_TEXTE2
            btnLancer.Font             = Enum.Font.Gotham
            btnLancer.TextSize         = 14
        end
        return
    end

    local parties = {}
    for _, sortie in ipairs(recetteTrouvee.outputs) do
        local coul = COULEUR_RARETE[sortie.rarete] or Color3.fromRGB(200, 200, 200)
        local hex  = hexColor(coul)
        local abr  = ICONE_RARETE[sortie.rarete] or "?"
        parties[#parties + 1] = "<font color='" .. hex .. "'><b>"
            .. abr .. "</b>  " .. sortie.rarete .. "  " .. sortie.chance .. "%</font>"
    end
    if labelResultat then
        labelResultat.Text = table.concat(parties, "    |    ")
    end
    if barreResultatGauche then barreResultatGauche.BackgroundColor3 = C_ACCENT end

    if labelCout then
        labelCout.Text = "<font color='#ffd050'>Cost: " .. recetteTrouvee.cout
            .. " coins</font>   <font color='#828282'>|   Duration: 1h 30m</font>"
    end

    if btnLancer then
        btnLancer.BackgroundColor3 = C_BTN_ON
        btnLancer.Text             = "LAUNCH FUSION"
        btnLancer.TextColor3       = C_TEXTE
        btnLancer.Font             = Enum.Font.GothamBold
        btnLancer.TextSize         = 16
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- Refresh carry
-- ═══════════════════════════════════════════════════════════════════════════════
rafraichirCarry = function()
    if not carryFrame then return end

    for _, child in ipairs(carryFrame:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("TextLabel") then
            child:Destroy()
        end
    end

    local backpack = player:FindFirstChildOfClass("Backpack")
    if not backpack then return end

    local dejaSelec = {}
    for i = 1, 4 do
        if slotsSelectionnes[i] then
            dejaSelec[slotsSelectionnes[i]] = true
        end
    end

    local count = 0
    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") then
            local rarete = tool:GetAttribute("Rarete")
            if rarete then
                count = count + 1
                local selectionne = dejaSelec[tool] == true
                local coul        = COULEUR_RARETE[rarete] or Color3.fromRGB(200, 200, 200)

                local btn = Instance.new("TextButton")
                btn.Name                   = "BT_" .. tool.Name
                btn.Size                   = UDim2.new(0, 82, 0, 88)
                btn.BackgroundColor3       = selectionne and C_SLOT_FILL or C_SLOT
                btn.BackgroundTransparency = 0
                btn.BorderSizePixel        = 0
                btn.Text                   = ""
                btn.AutoButtonColor        = false
                btn.Parent                 = carryFrame
                coin(btn, 0)
                local st = stroke(btn, selectionne and coul or C_BORDURE, 1)
                if selectionne then st.Transparency = 0.5 end

                local topBar = Instance.new("Frame")
                topBar.Name             = "TopBar"
                topBar.Size             = UDim2.new(1, 0, 0, 5)
                topBar.BackgroundColor3 = selectionne and C_BORDURE or coul
                topBar.BorderSizePixel  = 0
                topBar.Parent           = btn

                local iconeL = Instance.new("TextLabel")
                iconeL.Size                   = UDim2.new(1, 0, 0, 38)
                iconeL.Position               = UDim2.new(0, 0, 0, 8)
                iconeL.BackgroundTransparency = 1
                iconeL.Text                   = selectionne and "V" or (ICONE_RARETE[rarete] or "?")
                iconeL.TextColor3             = selectionne and C_TEXTE2 or coul
                iconeL.TextSize               = 22
                iconeL.TextScaled             = false
                iconeL.Font                   = Enum.Font.GothamBold
                iconeL.Parent                 = btn

                local brName = tool:GetAttribute("BrainrotName") or tool.Name
                local nomL = Instance.new("TextLabel")
                nomL.Size                   = UDim2.new(1, -4, 0, 36)
                nomL.Position               = UDim2.new(0, 2, 1, -38)
                nomL.BackgroundTransparency = 1
                nomL.Text                   = brName .. "\n" .. rarete
                nomL.TextColor3             = selectionne and C_TEXTE2 or C_TEXTE
                nomL.TextSize               = 9
                nomL.TextScaled             = false
                nomL.Font                   = Enum.Font.Gotham
                nomL.TextWrapped            = true
                nomL.TextXAlignment         = Enum.TextXAlignment.Center
                nomL.Parent                 = btn

                if not selectionne then
                    local toolRef = tool
                    btn.MouseButton1Click:Connect(function()
                        local slot = premierSlotVide()
                        if not slot then return end
                        slotsSelectionnes[slot] = toolRef
                        rafraichirSlot(slot)
                        mettreAJourRecette()
                        rafraichirCarry()
                    end)
                end
            end
        end
    end

    if count == 0 then
        local vide = Instance.new("TextLabel")
        vide.Size                   = UDim2.new(0, 340, 1, 0)
        vide.BackgroundTransparency = 1
        vide.Text                   = "No Brainrot in your carry"
        vide.TextColor3             = C_TEXTE2
        vide.TextSize               = 13
        vide.TextScaled             = false
        vide.Font                   = Enum.Font.Gotham
        vide.TextXAlignment         = Enum.TextXAlignment.Center
        vide.Parent                 = carryFrame
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- Timer client
-- ═══════════════════════════════════════════════════════════════════════════════
local function demarrerTimerClient(debutFusion, dureeFusion)
    if timerConn then timerConn:Disconnect() timerConn = nil end

    timerConn = RunService.Heartbeat:Connect(function()
        local elapsed  = tick() - debutFusion
        local restant  = math.max(0, dureeFusion - elapsed)
        local fraction = math.min(1, elapsed / dureeFusion)

        if labelTimer then labelTimer.Text = formaterTemps(restant) end
        if barreProgress then barreProgress.Size = UDim2.new(fraction, 0, 1, 0) end

        if restant <= 0 then
            if labelTimer then
                labelTimer.Text       = "READY TO COLLECT!"
                labelTimer.TextColor3 = C_VALIDE
                labelTimer.TextSize   = 20
            end
            if barreProgress then
                barreProgress.BackgroundColor3 = C_VALIDE
            end
            timerConn:Disconnect()
            timerConn = nil
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- Ouvrir / Fermer
-- ═══════════════════════════════════════════════════════════════════════════════
local function ouvrirUI(machine, etatData, recettes)
    machineActuelle     = machine
    etatMachine         = etatData or {}
    recettesDisponibles = recettes or {}
    slotsSelectionnes   = {}
    recetteTrouvee      = nil
    estEnFermeture      = false

    for i = 1, 4 do rafraichirSlot(i) end

    if etatData and etatData.actif then
        frameSelection.Visible = false
        frameTimer.Visible     = true
        if etatData.debutFusion and etatData.dureeFusion then
            demarrerTimerClient(etatData.debutFusion, etatData.dureeFusion)
        end
    else
        frameTimer.Visible     = false
        frameSelection.Visible = true
        mettreAJourRecette()
        rafraichirCarry()
    end

    screenGui.Enabled = true
    cadre.Position    = UDim2.new(0.5, 0, 1.5, 0)
    TweenService:Create(cadre,
        TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Position = UDim2.new(0.5, 0, 0.5, 0) }):Play()
end

fermerUI = function()
    if estEnFermeture then return end
    estEnFermeture    = true
    machineActuelle   = nil
    slotsSelectionnes = {}
    recetteTrouvee    = nil
    if timerConn then timerConn:Disconnect() timerConn = nil end

    local tween = TweenService:Create(cadre,
        TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { Position = UDim2.new(0.5, 0, 1.5, 0) })
    tween:Play()
    tween.Completed:Connect(function()
        screenGui.Enabled = false
        estEnFermeture    = false
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- Lancer la fusion
-- ═══════════════════════════════════════════════════════════════════════════════
function onLancerFusion()
    if not machineActuelle then return end
    if not recetteTrouvee  then return end

    local tools = {}
    for i = 1, 4 do
        local t = slotsSelectionnes[i]
        if not t or not t.Parent then return end
        tools[#tools + 1] = t
    end

    if btnLancer then
        btnLancer.BackgroundColor3 = C_BTN_OFF
        btnLancer.Text             = "Sending..."
        btnLancer.TextColor3       = C_TEXTE2
    end

    Lancer:FireServer(machineActuelle, tools)

    task.delay(0.4, function()
        if screenGui.Enabled and not estEnFermeture then fermerUI() end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- Evenements serveur
-- ═══════════════════════════════════════════════════════════════════════════════
OuvrirUI.OnClientEvent:Connect(function(machine, etatData, recettes)
    Logger.debug("Fuse", "OuvrirUI recu machine=%s", tostring(machine and machine.Name))
    ouvrirUI(machine, etatData, recettes)
end)

FermerUI.OnClientEvent:Connect(function()
    fermerUI()
end)

EtatUpdate.OnClientEvent:Connect(function(machine, update)
    if machine ~= machineActuelle then return end

    if update.actif ~= nil then etatMachine.actif = update.actif end

    if update.termine then
        if timerConn then timerConn:Disconnect() timerConn = nil end
        if labelTimer then
            labelTimer.Text       = "READY TO COLLECT!"
            labelTimer.TextColor3 = C_VALIDE
            labelTimer.TextSize   = 20
        end
        if barreProgress then
            barreProgress.Size             = UDim2.new(1, 0, 1, 0)
            barreProgress.BackgroundColor3 = C_VALIDE
        end
    end

    if not update.actif then
        if screenGui.Enabled and not estEnFermeture and machineActuelle == machine then
            fermerUI()
        end
    end
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.Escape and screenGui.Enabled and not estEnFermeture then
        fermerUI()
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- Init
-- ═══════════════════════════════════════════════════════════════════════════════
creerUI()
