-- StarterPlayer/StarterPlayerScripts/Common/RebirthHUD.client.lua
-- BrainRotFarm — Interface Rebirth côté client
-- Écoute RebirthButtonUpdate + RebirthAnimation
-- Envoie DemandeRebirth au clic

local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local player       = Players.LocalPlayer
local playerGui    = player:WaitForChild("PlayerGui")

-- Attendre les RemoteEvents créés par RebirthSystem.lua
local RebirthButtonUpdate = RS:WaitForChild("RebirthButtonUpdate", 10)
local RebirthAnimation    = RS:WaitForChild("RebirthAnimation",    10)
local DemandeRebirth      = RS:WaitForChild("DemandeRebirth",      10)

if not RebirthButtonUpdate or not RebirthAnimation or not DemandeRebirth then
    warn("[RebirthHUD] RemoteEvents introuvables — script interrompu")
    return
end

-- ═══════════════════════════════════════
-- CRÉATION DE L'UI
-- ═══════════════════════════════════════

-- Réutiliser MainGui si existant, sinon créer
local screenGui = playerGui:FindFirstChild("MainGui")
if not screenGui then
    screenGui = Instance.new("ScreenGui")
    screenGui.Name         = "MainGui"
    screenGui.ResetOnSpawn = false
    screenGui.Parent       = playerGui
end

-- Conteneur principal (bas centre)
local rebirthFrame = Instance.new("Frame")
rebirthFrame.Name                   = "RebirthFrame"
rebirthFrame.Size                   = UDim2.new(0, 350, 0, 145)
rebirthFrame.Position               = UDim2.new(0.5, -175, 1, -160)
rebirthFrame.BackgroundColor3       = Color3.fromRGB(15, 15, 15)
rebirthFrame.BackgroundTransparency = 0.2
rebirthFrame.BorderSizePixel        = 0
rebirthFrame.Visible                = false
rebirthFrame.Parent                 = screenGui

local corner = Instance.new("UICorner", rebirthFrame)
corner.CornerRadius = UDim.new(0, 10)

local stroke = Instance.new("UIStroke", rebirthFrame)
stroke.Color     = Color3.fromRGB(255, 140, 0)
stroke.Thickness = 1.5

-- Titre
local lblTitre = Instance.new("TextLabel", rebirthFrame)
lblTitre.Name                   = "Titre"
lblTitre.Size                   = UDim2.new(1, -20, 0, 24)
lblTitre.Position               = UDim2.new(0, 10, 0, 8)
lblTitre.BackgroundTransparency = 1
lblTitre.TextColor3             = Color3.fromRGB(255, 165, 0)
lblTitre.Font                   = Enum.Font.GothamBold
lblTitre.TextSize               = 16
lblTitre.TextXAlignment         = Enum.TextXAlignment.Left
lblTitre.RichText               = true
lblTitre.Text                   = "🔥 REBIRTH I"

-- Barre de progression — fond
local barFond = Instance.new("Frame", rebirthFrame)
barFond.Name             = "BarFond"
barFond.Size             = UDim2.new(1, -20, 0, 14)
barFond.Position         = UDim2.new(0, 10, 0, 36)
barFond.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
barFond.BorderSizePixel  = 0
Instance.new("UICorner", barFond).CornerRadius = UDim.new(1, 0)

-- Barre de progression — remplissage
local barFill = Instance.new("Frame", barFond)
barFill.Name             = "BarFill"
barFill.Size             = UDim2.new(0, 0, 1, 0)
barFill.BackgroundColor3 = Color3.fromRGB(255, 140, 0)
barFill.BorderSizePixel  = 0
Instance.new("UICorner", barFill).CornerRadius = UDim.new(1, 0)

-- Pourcentage (centré sur la barre)
local lblPourcent = Instance.new("TextLabel", barFond)
lblPourcent.Name                   = "Pourcent"
lblPourcent.Size                   = UDim2.new(1, 0, 1, 0)
lblPourcent.BackgroundTransparency = 1
lblPourcent.TextColor3             = Color3.fromRGB(255, 255, 255)
lblPourcent.Font                   = Enum.Font.GothamBold
lblPourcent.TextSize               = 11
lblPourcent.Text                   = "0%"

-- Coins requis
local lblCoins = Instance.new("TextLabel", rebirthFrame)
lblCoins.Name                   = "Coins"
lblCoins.Size                   = UDim2.new(1, -20, 0, 18)
lblCoins.Position               = UDim2.new(0, 10, 0, 54)
lblCoins.BackgroundTransparency = 1
lblCoins.TextColor3             = Color3.fromRGB(255, 215, 0)
lblCoins.Font                   = Enum.Font.Gotham
lblCoins.TextSize               = 13
lblCoins.TextXAlignment         = Enum.TextXAlignment.Left
lblCoins.RichText               = true
lblCoins.Text                   = "💰 0 / 300 000"

-- Brain Rot requis
local lblBR = Instance.new("TextLabel", rebirthFrame)
lblBR.Name                   = "BRRequis"
lblBR.Size                   = UDim2.new(1, -20, 0, 18)
lblBR.Position               = UDim2.new(0, 10, 0, 74)
lblBR.BackgroundTransparency = 1
lblBR.TextColor3             = Color3.fromRGB(200, 200, 200)
lblBR.Font                   = Enum.Font.Gotham
lblBR.TextSize               = 13
lblBR.TextXAlignment         = Enum.TextXAlignment.Left
lblBR.RichText               = true
lblBR.Text                   = "☄️ LEGENDARY requis ❌"

-- Bouton Rebirth
local btnRebirth = Instance.new("TextButton", rebirthFrame)
btnRebirth.Name                   = "BtnRebirth"
btnRebirth.Size                   = UDim2.new(1, -20, 0, 34)
btnRebirth.Position               = UDim2.new(0, 10, 0, 100)
btnRebirth.BackgroundColor3       = Color3.fromRGB(80, 80, 80)
btnRebirth.TextColor3             = Color3.fromRGB(255, 255, 255)
btnRebirth.Font                   = Enum.Font.GothamBold
btnRebirth.TextSize               = 14
btnRebirth.Text                   = "⚡ REBIRTH — ×1.5 income"
btnRebirth.BorderSizePixel        = 0
btnRebirth.AutoButtonColor        = false
Instance.new("UICorner", btnRebirth).CornerRadius = UDim.new(0, 8)

-- ═══════════════════════════════════════
-- HELPERS
-- ═══════════════════════════════════════

-- Formate un nombre avec espaces milliers : 1234567 → "1 234 567"
local function FormatCoins(n)
    local s      = tostring(math.floor(n))
    local result = ""
    local count  = 0
    for i = #s, 1, -1 do
        if count > 0 and count % 3 == 0 then result = " " .. result end
        result = s:sub(i, i) .. result
        count  = count + 1
    end
    return result
end

local iconeParRarete = {
    COMMON       = "⚪",
    OG           = "🟢",
    RARE         = "🔵",
    EPIC         = "🟣",
    LEGENDARY    = "⭐",
    MYTHIC       = "☄️",
    SECRET       = "🔴",
    BRAINROT_GOD = "👑",
}

local pulseTween = nil
local isReady    = false

-- Active ou désactive le pulse du bouton selon disponibilité
local function SetBoutonPret(ready)
    isReady = ready
    if pulseTween then
        pulseTween:Cancel()
        pulseTween = nil
    end

    if ready then
        btnRebirth.BackgroundColor3       = Color3.fromRGB(255, 140, 0)
        btnRebirth.BackgroundTransparency = 0
        stroke.Color                      = Color3.fromRGB(255, 215, 0)
        stroke.Thickness                  = 2.5
        -- Pulse orange ↔ transparent
        pulseTween = TweenService:Create(
            btnRebirth,
            TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { BackgroundTransparency = 0.35 }
        )
        pulseTween:Play()
    else
        btnRebirth.BackgroundColor3       = Color3.fromRGB(80, 80, 80)
        btnRebirth.BackgroundTransparency = 0
        stroke.Color                      = Color3.fromRGB(255, 140, 0)
        stroke.Thickness                  = 1.5
    end
end

-- ═══════════════════════════════════════
-- ÉCOUTER RebirthButtonUpdate
-- Champs réels envoyés par RebirthSystem.lua :
--   visible, disponible, prochainLevel, rebirthLevel
--   coinsActuels, coinsRequis, brainRotRequis (string rarete)
--   manqueCoins, manqueBR, multiplicateur, label
-- ═══════════════════════════════════════

RebirthButtonUpdate.OnClientEvent:Connect(function(data)
    if not data then return end

    rebirthFrame.Visible = data.visible == true
    if not data.visible then return end

    -- Titre
    lblTitre.Text = "🔥 " .. (data.label or "REBIRTH")

    -- Calcul du pourcentage coins côté client
    local coinsActuels = data.coinsActuels or 0
    local coinsRequis  = data.coinsRequis  or 1
    local pct = math.clamp(math.floor((coinsActuels / coinsRequis) * 100), 0, 100)

    -- Animer la barre
    TweenService:Create(barFill,
        TweenInfo.new(0.5, Enum.EasingStyle.Quad),
        { Size = UDim2.new(pct / 100, 0, 1, 0) }
    ):Play()
    lblPourcent.Text = pct .. "%"

    -- Couleur barre selon progression
    if pct >= 100 then
        barFill.BackgroundColor3 = Color3.fromRGB(0, 220, 0)
    elseif pct >= 75 then
        barFill.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
    else
        barFill.BackgroundColor3 = Color3.fromRGB(255, 140, 0)
    end

    -- Coins
    lblCoins.Text = "💰 " .. FormatCoins(coinsActuels) .. " / " .. FormatCoins(coinsRequis)

    -- BR requis (brainRotRequis = string rarete, manqueBR = nil si ok)
    local rarete = data.brainRotRequis or "LEGENDARY"
    local brOk   = data.manqueBR == nil
    local icone  = iconeParRarete[rarete] or "🌟"
    local check  = brOk and "✅" or "❌"
    lblBR.Text       = icone .. " " .. rarete .. " requis  " .. check
    lblBR.TextColor3 = brOk
        and Color3.fromRGB(100, 255, 100)
        or  Color3.fromRGB(255, 100, 100)

    -- Texte du bouton
    local mult = data.multiplicateur or 1.0
    -- Formater le multiplicateur : "2" si entier, "1.5" sinon
    local multStr = (mult == math.floor(mult))
        and tostring(math.floor(mult))
        or  tostring(mult)
    btnRebirth.Text = "⚡ REBIRTH — ×" .. multStr .. " income"

    -- Activer le pulse uniquement si 100% coins ET BR ok
    SetBoutonPret(pct >= 100 and brOk)
end)

-- ═══════════════════════════════════════
-- DIALOGUE DE CONFIRMATION
-- ═══════════════════════════════════════

local function afficherConfirmation(multStr)
    -- Supprimer un éventuel doublon
    local ancien = screenGui:FindFirstChild("ConfirmRebirth")
    if ancien then ancien:Destroy() end

    local confirm = Instance.new("Frame", screenGui)
    confirm.Name                   = "ConfirmRebirth"
    confirm.Size                   = UDim2.new(0, 320, 0, 160)
    confirm.Position               = UDim2.new(0.5, -160, 0.5, -80)
    confirm.BackgroundColor3       = Color3.fromRGB(20, 20, 20)
    confirm.BackgroundTransparency = 0.05
    confirm.BorderSizePixel        = 0
    confirm.ZIndex                 = 5
    Instance.new("UICorner", confirm).CornerRadius = UDim.new(0, 12)

    local stroke2 = Instance.new("UIStroke", confirm)
    stroke2.Color     = Color3.fromRGB(255, 140, 0)
    stroke2.Thickness = 2

    local lbl = Instance.new("TextLabel", confirm)
    lbl.Size                   = UDim2.new(1, -20, 0, 70)
    lbl.Position               = UDim2.new(0, 10, 0, 12)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3             = Color3.fromRGB(255, 255, 255)
    lbl.Font                   = Enum.Font.GothamBold
    lbl.TextSize               = 14
    lbl.TextWrapped            = true
    lbl.RichText               = true
    lbl.ZIndex                 = 6
    lbl.Text = "⚠️ <b>Reset ALL progress?</b>\nCoins + Base → 0\nIncome ×<b>"
        .. multStr .. "</b> permanent!"

    local btnOui = Instance.new("TextButton", confirm)
    btnOui.Size             = UDim2.new(0.45, 0, 0, 38)
    btnOui.Position         = UDim2.new(0.05, 0, 1, -48)
    btnOui.BackgroundColor3 = Color3.fromRGB(255, 140, 0)
    btnOui.TextColor3       = Color3.fromRGB(255, 255, 255)
    btnOui.Font             = Enum.Font.GothamBold
    btnOui.TextSize         = 14
    btnOui.Text             = "✅ Confirm"
    btnOui.BorderSizePixel  = 0
    btnOui.ZIndex           = 6
    Instance.new("UICorner", btnOui).CornerRadius = UDim.new(0, 8)

    local btnNon = Instance.new("TextButton", confirm)
    btnNon.Size             = UDim2.new(0.45, 0, 0, 38)
    btnNon.Position         = UDim2.new(0.5, 0, 1, -48)
    btnNon.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    btnNon.TextColor3       = Color3.fromRGB(255, 255, 255)
    btnNon.Font             = Enum.Font.GothamBold
    btnNon.TextSize         = 14
    btnNon.Text             = "❌ Cancel"
    btnNon.BorderSizePixel  = 0
    btnNon.ZIndex           = 6
    Instance.new("UICorner", btnNon).CornerRadius = UDim.new(0, 8)

    btnOui.MouseButton1Click:Connect(function()
        confirm:Destroy()
        DemandeRebirth:FireServer()
    end)
    btnNon.MouseButton1Click:Connect(function()
        confirm:Destroy()
    end)
end

-- ═══════════════════════════════════════
-- CLIC BOUTON REBIRTH
-- ═══════════════════════════════════════

btnRebirth.MouseButton1Click:Connect(function()
    if not isReady then return end
    -- Extraire le multiplicateur du texte du bouton ("×1.5 income" → "1.5")
    local multStr = btnRebirth.Text:match("×(.+) income") or "?"
    afficherConfirmation(multStr)
end)

-- ═══════════════════════════════════════
-- ÉCOUTER RebirthAnimation
-- ═══════════════════════════════════════

RebirthAnimation.OnClientEvent:Connect(function(data)
    if not data then return end

    -- Flash doré plein écran
    local flash = Instance.new("Frame", screenGui)
    flash.Name                   = "RebirthFlash"
    flash.Size                   = UDim2.new(1, 0, 1, 0)
    flash.BackgroundColor3       = Color3.fromRGB(255, 215, 0)
    flash.BackgroundTransparency = 0
    flash.BorderSizePixel        = 0
    flash.ZIndex                 = 10

    TweenService:Create(flash,
        TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { BackgroundTransparency = 1 }
    ):Play()
    task.delay(1.3, function()
        if flash and flash.Parent then flash:Destroy() end
    end)

    -- Texte "REBIRTH !" centré à l'écran
    local niveau   = data.niveau or ""
    local mult     = data.multiplicateur or 1.0
    local multStr  = (mult == math.floor(mult))
        and tostring(math.floor(mult))
        or  tostring(mult)

    local lblAnim = Instance.new("TextLabel", screenGui)
    lblAnim.Name                   = "RebirthAnimText"
    lblAnim.Size                   = UDim2.new(0, 420, 0, 90)
    lblAnim.Position               = UDim2.new(0.5, -210, 0.5, -45)
    lblAnim.BackgroundTransparency = 1
    lblAnim.TextColor3             = Color3.fromRGB(255, 215, 0)
    lblAnim.Font                   = Enum.Font.GothamBold
    lblAnim.TextSize               = 46
    lblAnim.RichText               = true
    lblAnim.TextTransparency       = 1
    lblAnim.ZIndex                 = 11
    lblAnim.Text = "🔥 REBIRTH " .. tostring(niveau)
        .. "\n<font size='22'>×" .. multStr .. " income!</font>"

    -- Apparition
    TweenService:Create(lblAnim,
        TweenInfo.new(0.3), { TextTransparency = 0 }
    ):Play()

    -- Disparition après 2.5s
    task.delay(2.5, function()
        TweenService:Create(lblAnim,
            TweenInfo.new(0.5), { TextTransparency = 1 }
        ):Play()
        task.delay(0.55, function()
            if lblAnim and lblAnim.Parent then lblAnim:Destroy() end
        end)
    end)
end)

print("[RebirthHUD] Initialisé ✓")
