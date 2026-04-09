-- shared-lib/src/client/FuseMachineClient.client.lua
-- UI Fuse Machine — partagé entre jeux
-- Affiche les 4 slots, sélection du carry, résultat, timer

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Logger           = require(game:GetService("ReplicatedStorage").SharedLib.Logger)

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ═══════════════════════════════════════════════
-- Attente des RemoteEvents (créés par FuseMachineSystem.Init)
-- ═══════════════════════════════════════════════
Logger.info("Fuse", "Script démarré ✓")
local OuvrirUI   = ReplicatedStorage:WaitForChild("FuseMachine_OuvrirUI",   60)
local FermerUI   = ReplicatedStorage:WaitForChild("FuseMachine_FermerUI",   60)
local EtatUpdate = ReplicatedStorage:WaitForChild("FuseMachine_EtatUpdate", 60)
local Lancer     = ReplicatedStorage:WaitForChild("FuseMachine_Lancer",     60)

if not OuvrirUI then
    Logger.warn("Fuse", "RemoteEvents introuvables après 60s — FuseMachineSystem.Init() appelé ?")
    return
end
Logger.info("Fuse", "RemoteEvents trouvés ✓")

-- ═══════════════════════════════════════════════
-- Couleurs thème LavaTower
-- ═══════════════════════════════════════════════
local C_BG          = Color3.fromRGB(20, 16, 12)
local C_BG2         = Color3.fromRGB(35, 28, 20)
local C_ACCENT      = Color3.fromRGB(220, 80, 20)   -- orange lave
local C_TITRE       = Color3.fromRGB(255, 210, 80)
local C_TEXTE       = Color3.fromRGB(255, 235, 200)
local C_SLOT        = Color3.fromRGB(42, 34, 24)
local C_SLOT_FILL   = Color3.fromRGB(58, 48, 32)
local C_BTN_ON      = Color3.fromRGB(220, 80, 20)
local C_BTN_OFF     = Color3.fromRGB(80, 55, 35)
local C_STROKE      = Color3.fromRGB(80, 58, 36)

-- Couleurs raretés (copie locale, pas de require côté client)
local COULEUR_RARETE = {
    Common    = Color3.fromRGB(200, 200, 200),
    Uncommon  = Color3.fromRGB(100, 200, 100),
    Rare      = Color3.fromRGB(100, 130, 255),
    Epic      = Color3.fromRGB(180, 50,  255),
    Legendary = Color3.fromRGB(255, 200, 0),
    Secret    = Color3.fromRGB(255, 50,  50),
}
local ICONE_RARETE = {
    Common    = "",
    Uncommon  = "",
    Rare      = "",
    Epic      = "",
    Legendary = "",
    Secret    = "",
}

-- ═══════════════════════════════════════════════
-- État client
-- ═══════════════════════════════════════════════
local machineActuelle     = nil   -- Instance machine en cours
local etatMachine         = {}    -- données reçues du serveur
local recettesDisponibles = {}    -- recettes reçues du serveur
local slotsSelectionnes   = {}    -- [1..4] → Tool | nil
local recetteTrouvee      = nil   -- recette matchée par les 4 slots
local timerConn           = nil   -- connexion Heartbeat pour le countdown

-- ═══════════════════════════════════════════════
-- Références UI (assignées par creerUI)
-- ═══════════════════════════════════════════════
local screenGui, cadre
local frameSelection, frameTimer
local slotsFrames = {}
local carryFrame
local labelResultat, labelCout, btnLancer
local barreProgress, labelTimer

-- ═══════════════════════════════════════════════
-- Déclarations forward
-- ═══════════════════════════════════════════════
local fermerUI
local viderSlot
local mettreAJourRecette
local rafraichirCarry
local rafraichirSlot

-- ═══════════════════════════════════════════════
-- Helpers UI
-- ═══════════════════════════════════════════════

local function coin(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = parent
    return c
end

local function stroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color     = color or C_STROKE
    s.Thickness = thickness or 1
    s.Name      = "Stroke"
    s.Parent    = parent
    return s
end

local function label(parent, text, size, font, color, xAlign)
    local l = Instance.new("TextLabel")
    l.Text               = text or ""
    l.TextSize           = size or 14
    l.Font               = font or Enum.Font.Gotham
    l.TextColor3         = color or C_TEXTE
    l.BackgroundTransparency = 1
    l.TextXAlignment     = xAlign or Enum.TextXAlignment.Center
    l.Size               = UDim2.new(1, 0, 1, 0)
    l.Parent             = parent
    return l
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

-- Trie les inputs pour comparer recettes (ordre libre)
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

-- ═══════════════════════════════════════════════
-- Construction de l'UI
-- ═══════════════════════════════════════════════

local function creerUI()
    -- ScreenGui
    screenGui = Instance.new("ScreenGui")
    screenGui.Name           = "FuseMachineUI"
    screenGui.ResetOnSpawn   = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.IgnoreGuiInset = true
    screenGui.Enabled        = false
    screenGui.Parent         = playerGui

    -- Cadre principal (480 × 530)
    cadre = Instance.new("Frame")
    cadre.Name             = "Cadre"
    cadre.Size             = UDim2.new(0, 480, 0, 530)
    cadre.Position         = UDim2.new(0.5, -240, 0.5, -265)
    cadre.BackgroundColor3 = C_BG
    cadre.BorderSizePixel  = 0
    cadre.Parent           = screenGui
    coin(cadre, 12)
    stroke(cadre, C_ACCENT, 2)

    -- ─── Titre ───────────────────────────────
    local titreBar = Instance.new("Frame")
    titreBar.Size             = UDim2.new(1, 0, 0, 50)
    titreBar.BackgroundColor3 = C_ACCENT
    titreBar.BorderSizePixel  = 0
    titreBar.Parent           = cadre
    coin(titreBar, 12)
    -- Masque les coins inférieurs du titre
    local fixBot = Instance.new("Frame")
    fixBot.Size             = UDim2.new(1, 0, 0, 12)
    fixBot.Position         = UDim2.new(0, 0, 1, -12)
    fixBot.BackgroundColor3 = C_ACCENT
    fixBot.BorderSizePixel  = 0
    fixBot.Parent           = titreBar

    local lTitre = Instance.new("TextLabel")
    lTitre.Size                  = UDim2.new(1, -55, 1, 0)
    lTitre.Position              = UDim2.new(0, 14, 0, 0)
    lTitre.BackgroundTransparency = 1
    lTitre.Text                  = "FUSE MACHINE"
    lTitre.TextColor3            = Color3.fromRGB(255, 255, 255)
    lTitre.TextSize              = 20
    lTitre.Font                  = Enum.Font.GothamBold
    lTitre.TextXAlignment        = Enum.TextXAlignment.Left
    lTitre.Parent                = titreBar

    local btnX = Instance.new("TextButton")
    btnX.Size             = UDim2.new(0, 34, 0, 34)
    btnX.Position         = UDim2.new(1, -44, 0, 8)
    btnX.BackgroundColor3 = Color3.fromRGB(190, 50, 20)
    btnX.BorderSizePixel  = 0
    btnX.Text             = "X"
    btnX.TextColor3       = Color3.fromRGB(255, 255, 255)
    btnX.TextSize         = 16
    btnX.Font             = Enum.Font.GothamBold
    btnX.AutoButtonColor  = false
    btnX.Parent           = titreBar
    coin(btnX, 6)
    btnX.MouseButton1Click:Connect(function() fermerUI() end)

    -- ─── FRAME SÉLECTION ─────────────────────
    frameSelection = Instance.new("Frame")
    frameSelection.Name             = "FrameSelection"
    frameSelection.Size             = UDim2.new(1, -20, 1, -60)
    frameSelection.Position         = UDim2.new(0, 10, 0, 55)
    frameSelection.BackgroundTransparency = 1
    frameSelection.Visible          = true
    frameSelection.Parent           = cadre

    -- Label "INGRÉDIENTS"
    local lIngr = Instance.new("TextLabel")
    lIngr.Size                  = UDim2.new(1, 0, 0, 20)
    lIngr.Position              = UDim2.new(0, 0, 0, 4)
    lIngr.BackgroundTransparency = 1
    lIngr.Text                  = "INGRÉDIENTS  (4 Brainrots)"
    lIngr.TextColor3            = C_TITRE
    lIngr.TextSize              = 13
    lIngr.Font                  = Enum.Font.GothamBold
    lIngr.TextXAlignment        = Enum.TextXAlignment.Left
    lIngr.Parent                = frameSelection

    -- Conteneur 4 slots
    local slotsConteneur = Instance.new("Frame")
    slotsConteneur.Size                  = UDim2.new(1, 0, 0, 90)
    slotsConteneur.Position              = UDim2.new(0, 0, 0, 26)
    slotsConteneur.BackgroundTransparency = 1
    slotsConteneur.Parent                = frameSelection

    local slotLayout = Instance.new("UIListLayout")
    slotLayout.FillDirection        = Enum.FillDirection.Horizontal
    slotLayout.HorizontalAlignment  = Enum.HorizontalAlignment.Center
    slotLayout.Padding              = UDim.new(0, 8)
    slotLayout.Parent               = slotsConteneur

    slotsFrames = {}
    for i = 1, 4 do
        local slot = Instance.new("TextButton")
        slot.Name             = "Slot" .. i
        slot.Size             = UDim2.new(0, 96, 0, 90)
        slot.BackgroundColor3 = C_SLOT
        slot.BorderSizePixel  = 0
        slot.Text             = ""
        slot.AutoButtonColor  = false
        slot.Parent           = slotsConteneur
        coin(slot, 8)
        stroke(slot, C_STROKE, 1)

        local iconeL = Instance.new("TextLabel")
        iconeL.Name                  = "Icone"
        iconeL.Size                  = UDim2.new(1, 0, 0, 44)
        iconeL.Position              = UDim2.new(0, 0, 0, 4)
        iconeL.BackgroundTransparency = 1
        iconeL.Text                  = "+"
        iconeL.TextColor3            = Color3.fromRGB(110, 88, 60)
        iconeL.TextSize              = 30
        iconeL.Font                  = Enum.Font.GothamBold
        iconeL.Parent                = slot

        local nomL = Instance.new("TextLabel")
        nomL.Name                  = "Nom"
        nomL.Size                  = UDim2.new(1, -4, 0, 34)
        nomL.Position              = UDim2.new(0, 2, 1, -36)
        nomL.BackgroundTransparency = 1
        nomL.Text                  = "Slot " .. i
        nomL.TextColor3            = Color3.fromRGB(110, 88, 60)
        nomL.TextSize              = 10
        nomL.Font                  = Enum.Font.Gotham
        nomL.TextWrapped           = true
        nomL.Parent                = slot

        local idx = i
        slot.MouseButton1Click:Connect(function() viderSlot(idx) end)

        slotsFrames[i] = slot
    end

    -- Flèche résultat
    local lFleche = Instance.new("TextLabel")
    lFleche.Size                  = UDim2.new(1, 0, 0, 22)
    lFleche.Position              = UDim2.new(0, 0, 0, 122)
    lFleche.BackgroundTransparency = 1
    lFleche.Text                  = "RÉSULTAT POSSIBLE"
    lFleche.TextColor3            = C_ACCENT
    lFleche.TextSize              = 12
    lFleche.Font                  = Enum.Font.GothamBold
    lFleche.Parent                = frameSelection

    -- Affichage du résultat
    labelResultat = Instance.new("TextLabel")
    labelResultat.Name                  = "LabelResultat"
    labelResultat.Size                  = UDim2.new(1, 0, 0, 46)
    labelResultat.Position              = UDim2.new(0, 0, 0, 147)
    labelResultat.BackgroundColor3      = C_BG2
    labelResultat.BorderSizePixel       = 0
    labelResultat.Text                  = "<font color='#7a6040'>Sélectionnez 4 Brainrots…</font>"
    labelResultat.TextColor3            = C_TEXTE
    labelResultat.TextSize              = 15
    labelResultat.Font                  = Enum.Font.GothamBold
    labelResultat.RichText              = true
    labelResultat.Parent                = frameSelection
    coin(labelResultat, 8)

    -- Coût + durée
    labelCout = Instance.new("TextLabel")
    labelCout.Name                  = "LabelCout"
    labelCout.Size                  = UDim2.new(1, 0, 0, 24)
    labelCout.Position              = UDim2.new(0, 0, 0, 197)
    labelCout.BackgroundTransparency = 1
    labelCout.Text                  = ""
    labelCout.TextColor3            = C_TEXTE
    labelCout.TextSize              = 13
    labelCout.Font                  = Enum.Font.Gotham
    labelCout.RichText              = true
    labelCout.Parent                = frameSelection

    -- Label "VOS BRAINROTS"
    local lCarry = Instance.new("TextLabel")
    lCarry.Size                  = UDim2.new(1, 0, 0, 20)
    lCarry.Position              = UDim2.new(0, 0, 0, 225)
    lCarry.BackgroundTransparency = 1
    lCarry.Text                  = "VOS BRAINROTS"
    lCarry.TextColor3            = C_TITRE
    lCarry.TextSize              = 12
    lCarry.Font                  = Enum.Font.GothamBold
    lCarry.TextXAlignment        = Enum.TextXAlignment.Left
    lCarry.Parent                = frameSelection

    -- ScrollingFrame carry
    carryFrame = Instance.new("ScrollingFrame")
    carryFrame.Name                  = "CarryFrame"
    carryFrame.Size                  = UDim2.new(1, 0, 0, 118)
    carryFrame.Position              = UDim2.new(0, 0, 0, 247)
    carryFrame.BackgroundColor3      = C_BG2
    carryFrame.BorderSizePixel       = 0
    carryFrame.ScrollBarThickness    = 4
    carryFrame.ScrollBarImageColor3  = C_ACCENT
    carryFrame.CanvasSize            = UDim2.new(0, 0, 0, 0)
    carryFrame.AutomaticCanvasSize   = Enum.AutomaticSize.XY
    carryFrame.ScrollingDirection    = Enum.ScrollingDirection.X
    carryFrame.Parent                = frameSelection
    coin(carryFrame, 8)

    local carryLayout = Instance.new("UIListLayout")
    carryLayout.FillDirection       = Enum.FillDirection.Horizontal
    carryLayout.VerticalAlignment   = Enum.VerticalAlignment.Center
    carryLayout.Padding             = UDim.new(0, 6)
    carryLayout.Parent              = carryFrame

    local carryPad = Instance.new("UIPadding")
    carryPad.PaddingLeft  = UDim.new(0, 8)
    carryPad.PaddingRight = UDim.new(0, 8)
    carryPad.Parent       = carryFrame

    -- Bouton lancer
    btnLancer = Instance.new("TextButton")
    btnLancer.Name             = "BtnLancer"
    btnLancer.Size             = UDim2.new(1, 0, 0, 46)
    btnLancer.Position         = UDim2.new(0, 0, 0, 374)
    btnLancer.BackgroundColor3 = C_BTN_OFF
    btnLancer.BorderSizePixel  = 0
    btnLancer.Text             = "LANCER LA FUSION"
    btnLancer.TextColor3       = Color3.fromRGB(255, 255, 255)
    btnLancer.TextSize         = 17
    btnLancer.Font             = Enum.Font.GothamBold
    btnLancer.AutoButtonColor  = false
    btnLancer.Parent           = frameSelection
    coin(btnLancer, 10)
    btnLancer.MouseButton1Click:Connect(function() onLancerFusion() end)

    -- ─── FRAME TIMER ─────────────────────────
    frameTimer = Instance.new("Frame")
    frameTimer.Name                  = "FrameTimer"
    frameTimer.Size                  = UDim2.new(1, -20, 1, -60)
    frameTimer.Position              = UDim2.new(0, 10, 0, 55)
    frameTimer.BackgroundTransparency = 1
    frameTimer.Visible               = false
    frameTimer.Parent                = cadre

    local lEnCours = Instance.new("TextLabel")
    lEnCours.Size                  = UDim2.new(1, 0, 0, 42)
    lEnCours.Position              = UDim2.new(0, 0, 0, 20)
    lEnCours.BackgroundTransparency = 1
    lEnCours.Text                  = "FUSION EN COURS..."
    lEnCours.TextColor3            = C_TITRE
    lEnCours.TextSize              = 22
    lEnCours.Font                  = Enum.Font.GothamBold
    lEnCours.Parent                = frameTimer

    local lSurprise = Instance.new("TextLabel")
    lSurprise.Name                  = "Surprise"
    lSurprise.Size                  = UDim2.new(1, 0, 0, 30)
    lSurprise.Position              = UDim2.new(0, 0, 0, 70)
    lSurprise.BackgroundTransparency = 1
    lSurprise.Text                  = "Résultat : ???"
    lSurprise.TextColor3            = Color3.fromRGB(160, 138, 100)
    lSurprise.TextSize              = 16
    lSurprise.Font                  = Enum.Font.Gotham
    lSurprise.Parent                = frameTimer

    -- Barre de progression
    local barreConteneur = Instance.new("Frame")
    barreConteneur.Size             = UDim2.new(1, 0, 0, 20)
    barreConteneur.Position         = UDim2.new(0, 0, 0, 114)
    barreConteneur.BackgroundColor3 = Color3.fromRGB(38, 28, 18)
    barreConteneur.BorderSizePixel  = 0
    barreConteneur.Parent           = frameTimer
    coin(barreConteneur, 10)

    barreProgress = Instance.new("Frame")
    barreProgress.Name             = "Barre"
    barreProgress.Size             = UDim2.new(0, 0, 1, 0)
    barreProgress.BackgroundColor3 = C_ACCENT
    barreProgress.BorderSizePixel  = 0
    barreProgress.Parent           = barreConteneur
    coin(barreProgress, 10)

    labelTimer = Instance.new("TextLabel")
    labelTimer.Name                  = "LabelTimer"
    labelTimer.Size                  = UDim2.new(1, 0, 0, 46)
    labelTimer.Position              = UDim2.new(0, 0, 0, 148)
    labelTimer.BackgroundTransparency = 1
    labelTimer.Text                  = "--h --m --s"
    labelTimer.TextColor3            = C_TEXTE
    labelTimer.TextSize              = 26
    labelTimer.Font                  = Enum.Font.GothamBold
    labelTimer.Parent                = frameTimer

    -- Rappel "revenez collecter"
    local lRappel = Instance.new("TextLabel")
    lRappel.Size                  = UDim2.new(1, 0, 0, 24)
    lRappel.Position              = UDim2.new(0, 0, 0, 204)
    lRappel.BackgroundTransparency = 1
    lRappel.Text                  = "Revenez avec le ProximityPrompt quand c'est prêt."
    lRappel.TextColor3            = Color3.fromRGB(130, 110, 75)
    lRappel.TextSize              = 12
    lRappel.Font                  = Enum.Font.Gotham
    lRappel.TextWrapped           = true
    lRappel.Parent                = frameTimer
end

-- ═══════════════════════════════════════════════
-- Logique slots
-- ═══════════════════════════════════════════════

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
            iconeL.Text      = ICONE_RARETE[rarete] or "?"
            iconeL.TextColor3 = coul
        end
        if nomL then
            nomL.Text      = brName .. "\n[" .. rarete .. "]"
            nomL.TextColor3 = C_TEXTE
        end
    else
        -- Slot vide
        slotsSelectionnes[i] = nil
        slot.BackgroundColor3 = C_SLOT
        if st then st.Color = C_STROKE ; st.Thickness = 1 end
        if iconeL then
            iconeL.Text      = "+"
            iconeL.TextColor3 = Color3.fromRGB(110, 88, 60)
        end
        if nomL then
            nomL.Text      = "Slot " .. i
            nomL.TextColor3 = Color3.fromRGB(110, 88, 60)
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
            labelResultat.Text = "<font color='#7a6040'>Sélectionnez 4 Brainrots…</font>"
        end
        if labelCout then labelCout.Text = "" end
        if btnLancer then btnLancer.BackgroundColor3 = C_BTN_OFF end
        return
    end

    -- Chercher la recette
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
            labelResultat.Text = "<font color='#e05030'>Combinaison invalide</font>"
        end
        if labelCout then labelCout.Text = "" end
        if btnLancer then btnLancer.BackgroundColor3 = C_BTN_OFF end
        return
    end

    -- Afficher les résultats possibles
    local parties = {}
    for _, sortie in ipairs(recetteTrouvee.outputs) do
        local coul  = COULEUR_RARETE[sortie.rarete] or Color3.fromRGB(200, 200, 200)
        local hex   = hexColor(coul)
        parties[#parties + 1] = "<font color='" .. hex .. "'>"
            .. sortie.rarete .. "  <b>" .. sortie.chance .. "%</b></font>"
    end
    if labelResultat then
        labelResultat.Text = table.concat(parties, "      ")
    end

    if labelCout then
        labelCout.Text = "<font color='#ffd050'>Cout : " .. recetteTrouvee.cout
            .. " coins</font>    <font color='#aaaaaa'>1h 30m</font>"
    end

    if btnLancer then btnLancer.BackgroundColor3 = C_BTN_ON end
end

-- ═══════════════════════════════════════════════
-- Refresh carry (liste de brainrots sélectionnables)
-- ═══════════════════════════════════════════════

rafraichirCarry = function()
    if not carryFrame then return end

    -- Vider le contenu
    for _, child in ipairs(carryFrame:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("TextLabel") then
            child:Destroy()
        end
    end

    local backpack = player:FindFirstChildOfClass("Backpack")
    if not backpack then return end

    -- Index des tools déjà sélectionnés
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
                local coul = COULEUR_RARETE[rarete] or Color3.fromRGB(200, 200, 200)

                local btn = Instance.new("TextButton")
                btn.Name             = "BT_" .. tool.Name
                btn.Size             = UDim2.new(0, 78, 0, 90)
                btn.BackgroundColor3 = selectionne and Color3.fromRGB(36, 30, 20) or C_SLOT
                btn.BorderSizePixel  = 0
                btn.Text             = ""
                btn.AutoButtonColor  = false
                btn.Parent           = carryFrame
                coin(btn, 8)

                local st = stroke(btn, selectionne and coul or C_STROKE,
                    selectionne and 1.5 or 1)
                if selectionne then st.Transparency = 0.5 end

                local iconeL = Instance.new("TextLabel")
                iconeL.Size                  = UDim2.new(1, 0, 0, 40)
                iconeL.Position              = UDim2.new(0, 0, 0, 8)
                iconeL.BackgroundTransparency = 1
                iconeL.Text                  = selectionne and "+" or (ICONE_RARETE[rarete] or "?")
                iconeL.TextColor3            = selectionne and Color3.fromRGB(90, 78, 52) or coul
                iconeL.TextSize              = 26
                iconeL.Font                  = Enum.Font.GothamBold
                iconeL.Parent                = btn

                local brName = tool:GetAttribute("BrainrotName") or tool.Name
                local nomL = Instance.new("TextLabel")
                nomL.Size                  = UDim2.new(1, -4, 0, 36)
                nomL.Position              = UDim2.new(0, 2, 1, -38)
                nomL.BackgroundTransparency = 1
                nomL.Text                  = brName .. "\n[" .. rarete .. "]"
                nomL.TextColor3            = selectionne
                    and Color3.fromRGB(80, 68, 46)
                    or C_TEXTE
                nomL.TextSize              = 9
                nomL.Font                  = Enum.Font.Gotham
                nomL.TextWrapped           = true
                nomL.Parent                = btn

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
        vide.Size                  = UDim2.new(0, 300, 1, 0)
        vide.BackgroundTransparency = 1
        vide.Text                  = "Aucun Brainrot dans votre carry"
        vide.TextColor3            = Color3.fromRGB(120, 100, 65)
        vide.TextSize              = 13
        vide.Font                  = Enum.Font.Gotham
        vide.Parent                = carryFrame
    end
end

-- ═══════════════════════════════════════════════
-- Timer client (Heartbeat)
-- ═══════════════════════════════════════════════

local function demarrerTimerClient(debutFusion, dureeFusion)
    if timerConn then timerConn:Disconnect() timerConn = nil end

    timerConn = RunService.Heartbeat:Connect(function()
        local elapsed = tick() - debutFusion
        local restant = math.max(0, dureeFusion - elapsed)
        local fraction = math.min(1, elapsed / dureeFusion)

        if labelTimer then
            labelTimer.Text = formaterTemps(restant)
        end
        if barreProgress then
            barreProgress.Size = UDim2.new(fraction, 0, 1, 0)
        end

        if restant <= 0 then
            if labelTimer then
                labelTimer.Text      = "PRÊT À COLLECTER !"
                labelTimer.TextColor3 = Color3.fromRGB(100, 220, 80)
            end
            if barreProgress then
                barreProgress.BackgroundColor3 = Color3.fromRGB(80, 200, 60)
            end
            timerConn:Disconnect()
            timerConn = nil
        end
    end)
end

-- ═══════════════════════════════════════════════
-- Ouvrir / Fermer
-- ═══════════════════════════════════════════════

local function ouvrirUI(machine, etatData, recettes)
    machineActuelle      = machine
    etatMachine          = etatData or {}
    recettesDisponibles  = recettes or {}
    slotsSelectionnes    = {}
    recetteTrouvee       = nil

    for i = 1, 4 do rafraichirSlot(i) end

    if etatData and etatData.actif then
        -- Fusion en cours : afficher uniquement le timer
        frameSelection.Visible = false
        frameTimer.Visible     = true

        if etatData.debutFusion and etatData.dureeFusion then
            demarrerTimerClient(etatData.debutFusion, etatData.dureeFusion)
        end
    else
        -- Machine libre : afficher la sélection
        frameTimer.Visible     = false
        frameSelection.Visible = true
        mettreAJourRecette()
        rafraichirCarry()
    end

    screenGui.Enabled = true
end

fermerUI = function()
    screenGui.Enabled = false
    machineActuelle   = nil
    slotsSelectionnes = {}
    recetteTrouvee    = nil
    if timerConn then timerConn:Disconnect() timerConn = nil end
end

-- ═══════════════════════════════════════════════
-- Lancer la fusion (client → serveur)
-- ═══════════════════════════════════════════════

function onLancerFusion()
    if not machineActuelle then return end
    if not recetteTrouvee  then return end

    local tools = {}
    for i = 1, 4 do
        local t = slotsSelectionnes[i]
        if not t or not t.Parent then return end
        tools[#tools + 1] = t
    end

    -- Désactiver le bouton (anti-double clic)
    if btnLancer then
        btnLancer.BackgroundColor3 = C_BTN_OFF
        btnLancer.Text             = "Envoi..."
    end

    Lancer:FireServer(machineActuelle, tools)

    -- Fermer après un court délai (le serveur envoie FermerUI aussi)
    task.delay(0.4, function()
        if screenGui.Enabled then fermerUI() end
    end)
end

-- ═══════════════════════════════════════════════
-- Événements serveur → client
-- ═══════════════════════════════════════════════

OuvrirUI.OnClientEvent:Connect(function(machine, etatData, recettes)
    Logger.debug("Fuse", "OuvrirUI reçu ✓ machine=%s", tostring(machine and machine.Name))
    ouvrirUI(machine, etatData, recettes)
end)

FermerUI.OnClientEvent:Connect(function()
    fermerUI()
end)

EtatUpdate.OnClientEvent:Connect(function(machine, update)
    if machine ~= machineActuelle then return end

    if update.actif ~= nil then
        etatMachine.actif = update.actif
    end

    if update.termine then
        if timerConn then timerConn:Disconnect() timerConn = nil end
        if labelTimer then
            labelTimer.Text       = "PRÊT À COLLECTER !"
            labelTimer.TextColor3 = Color3.fromRGB(100, 220, 80)
        end
        if barreProgress then
            barreProgress.Size             = UDim2.new(1, 0, 1, 0)
            barreProgress.BackgroundColor3 = Color3.fromRGB(80, 200, 60)
        end
    end

    if not update.actif then
        -- Machine libérée (collecte terminée)
        if screenGui.Enabled and machineActuelle == machine then
            fermerUI()
        end
    end
end)

-- Échap pour fermer
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.Escape and screenGui.Enabled then
        fermerUI()
    end
end)

-- ═══════════════════════════════════════════════
-- Init
-- ═══════════════════════════════════════════════
creerUI()
