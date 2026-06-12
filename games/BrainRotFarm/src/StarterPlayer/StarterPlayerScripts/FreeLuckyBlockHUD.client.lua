-- StarterPlayerScripts/FreeLuckyBlockHUD.client.lua
-- Lucky Block GRATUIT offert après N minutes de session (récompense d'engagement).
-- Piloté par le serveur via le RemoteEvent "FreeLuckyBlock" :
--   • "start"   (secondesRestantes) → popup d'accueil + compteur bas-droite qui décompte
--   • "granted" (tier)              → popup final + retrait du compteur
-- Le serveur reste seul juge de l'octroi (anti-triche) : le compteur n'est qu'un visuel.

local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ModalManager   = require(RS:WaitForChild("SharedLib"):WaitForChild("ModalManager"))
local FreeLuckyBlock = RS:WaitForChild("FreeLuckyBlock")

local MODAL_NAME = "FreeLuckyBlock"
local GOLD       = Color3.fromRGB(255, 215, 60)

-- ============================================================
-- Format temps M:SS
-- ============================================================
local function formatTemps(s)
    if not s or s < 0 then s = 0 end
    s = math.floor(s)
    return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

-- ============================================================
-- Popup centré (overlay + carte + bouton OK)
-- ============================================================
local function afficherPopup(titre, corps)
    local sg = Instance.new("ScreenGui")
    sg.Name           = "FreeLuckyBlockPopup"
    sg.ResetOnSpawn   = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.IgnoreGuiInset = true
    sg.DisplayOrder   = 33          -- au-dessus des autres menus
    sg.Parent         = playerGui

    local overlay = Instance.new("Frame", sg)
    overlay.Size                   = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
    overlay.BackgroundTransparency = 0.45
    overlay.BorderSizePixel        = 0
    overlay.ZIndex                 = 1

    local card = Instance.new("Frame", sg)
    card.AnchorPoint            = Vector2.new(0.5, 0.5)
    card.Size                   = UDim2.new(0.82, 0, 0, 220)
    card.SizeConstraint         = Enum.SizeConstraint.RelativeXX
    card.Position               = UDim2.new(0.5, 0, 0.5, 0)
    card.BackgroundColor3       = Color3.fromRGB(18, 18, 22)
    card.BackgroundTransparency = 0.05
    card.BorderSizePixel        = 0
    card.ZIndex                 = 2
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 14)
    local maxCard = Instance.new("UISizeConstraint", card)
    maxCard.MaxSize = Vector2.new(420, 260)
    local stroke = Instance.new("UIStroke", card)
    stroke.Color     = GOLD
    stroke.Thickness = 2.5

    local pad = Instance.new("UIPadding", card)
    pad.PaddingTop    = UDim.new(0, 16)
    pad.PaddingBottom = UDim.new(0, 16)
    pad.PaddingLeft   = UDim.new(0, 16)
    pad.PaddingRight  = UDim.new(0, 16)

    local titreLbl = Instance.new("TextLabel", card)
    titreLbl.Size                   = UDim2.new(1, 0, 0, 40)
    titreLbl.BackgroundTransparency = 1
    titreLbl.Font                   = Enum.Font.GothamBold
    titreLbl.TextSize               = 24
    titreLbl.TextColor3             = GOLD
    titreLbl.TextStrokeTransparency = 0.4
    titreLbl.RichText               = true
    titreLbl.TextWrapped            = true
    titreLbl.Text                   = titre
    titreLbl.ZIndex                 = 3

    local corpsLbl = Instance.new("TextLabel", card)
    corpsLbl.AnchorPoint            = Vector2.new(0.5, 0.5)
    corpsLbl.Size                   = UDim2.new(1, 0, 1, -110)
    corpsLbl.Position               = UDim2.new(0.5, 0, 0.5, 0)
    corpsLbl.BackgroundTransparency = 1
    corpsLbl.Font                   = Enum.Font.GothamMedium
    corpsLbl.TextSize               = 17
    corpsLbl.TextColor3             = Color3.fromRGB(235, 235, 235)
    corpsLbl.RichText               = true
    corpsLbl.TextWrapped            = true
    corpsLbl.Text                   = corps
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
    btn.Text                   = "OK"
    btn.ZIndex                 = 3
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)

    ModalManager.Open(MODAL_NAME)

    -- Animation d'entrée
    card.Size = UDim2.new(0, 0, 0, 0)
    TweenService:Create(card, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Size = UDim2.new(0.82, 0, 0, 220) }):Play()

    local function fermer()
        ModalManager.Close(MODAL_NAME)
        TweenService:Create(overlay, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
        TweenService:Create(card, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Size = UDim2.new(0, 0, 0, 0) }):Play()
        task.delay(0.25, function() if sg.Parent then sg:Destroy() end end)
    end
    btn.Activated:Connect(fermer)
end

-- ============================================================
-- Compteur bas-droite (au-dessus du TimerHUD)
-- ============================================================
local compteurSg  = nil
local compteurVal = nil
local deadline    = nil   -- os.time() de fin

local function creerCompteur()
    if compteurSg then return end
    local sg = Instance.new("ScreenGui")
    sg.Name           = "FreeLuckyBlockTimer"
    sg.ResetOnSpawn   = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.IgnoreGuiInset = true
    sg.DisplayOrder   = 6
    sg.Parent         = playerGui

    local frame = Instance.new("Frame", sg)
    frame.AnchorPoint            = Vector2.new(1, 1)
    frame.Size                   = UDim2.new(0, 210, 0, 34)
    frame.Position               = UDim2.new(1, -8, 1, -172)  -- juste au-dessus du TimerHUD (bottom -100, haut 66)
    frame.BackgroundColor3       = Color3.fromRGB(12, 12, 12)
    frame.BackgroundTransparency = 0.22
    frame.BorderSizePixel        = 0
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
    local fstroke = Instance.new("UIStroke", frame)
    fstroke.Color     = GOLD
    fstroke.Thickness = 1.5

    local pad = Instance.new("UIPadding", frame)
    pad.PaddingLeft  = UDim.new(0, 9)
    pad.PaddingRight = UDim.new(0, 9)

    local lbl = Instance.new("TextLabel", frame)
    lbl.Size                   = UDim2.new(0.66, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font                   = Enum.Font.GothamBold
    lbl.TextSize               = 13
    lbl.TextXAlignment         = Enum.TextXAlignment.Left
    lbl.TextColor3             = GOLD
    lbl.Text                   = "🎁 FREE LUCKY BLOCK"

    local val = Instance.new("TextLabel", frame)
    val.Size                   = UDim2.new(0.34, 0, 1, 0)
    val.Position               = UDim2.new(0.66, 0, 0, 0)
    val.BackgroundTransparency = 1
    val.Font                   = Enum.Font.GothamBold
    val.TextSize               = 14
    val.TextXAlignment         = Enum.TextXAlignment.Right
    val.TextColor3             = Color3.fromRGB(255, 255, 255)
    val.Text                   = "--:--"

    compteurSg  = sg
    compteurVal = val
end

local function retirerCompteur()
    if compteurSg then
        compteurSg:Destroy()
        compteurSg  = nil
        compteurVal = nil
    end
    deadline = nil
end

-- Boucle d'affichage du compteur (1 Hz)
task.spawn(function()
    while true do
        task.wait(1)
        if compteurVal and deadline then
            local restant = deadline - os.time()
            if restant > 0 then
                compteurVal.Text       = formatTemps(restant)
                compteurVal.TextColor3 = Color3.fromRGB(255, 255, 255)
            else
                compteurVal.Text       = "SOON! 🎁"
                compteurVal.TextColor3 = GOLD
            end
        end
    end
end)

-- ============================================================
-- Réception serveur
-- ============================================================
FreeLuckyBlock.OnClientEvent:Connect(function(action, valeur)
    if action == "start" then
        deadline = os.time() + (tonumber(valeur) or 0)
        creerCompteur()
        afficherPopup(
            "🎁 FREE LUCKY BLOCK",
            "Stay in game for <b>15 minutes</b> and a <b>Mythic Lucky Block</b> is yours — for free!\n\n" ..
            "⏳ Watch the timer at the <b>bottom-right</b> of your screen."
        )
    elseif action == "granted" then
        retirerCompteur()
        afficherPopup(
            "🎉 LUCKY BLOCK UNLOCKED!",
            "Your <b>free Mythic Lucky Block</b> is in your bag! 🎒\n\n" ..
            "Place it on an empty slot to <b>open it</b> and reveal your reward!"
        )
    end
end)
