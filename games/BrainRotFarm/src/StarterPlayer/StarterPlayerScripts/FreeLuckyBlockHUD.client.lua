-- StarterPlayerScripts/FreeLuckyBlockHUD.client.lua
-- Lucky Block GRATUIT offert après N minutes de session (récompense d'engagement).
-- Piloté par le serveur via le RemoteEvent "FreeLuckyBlock" :
--   • "start"   (secondesRestantes) → popup d'accueil
--   • "granted" (tier)              → popup final
-- Le compteur bas-droite est désormais affiché par RightDock (dock unifié) ;
-- ce script ne gère plus que les popups d'accueil et de récompense.

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
-- Réception serveur (popups uniquement — le compteur vit dans RightDock)
-- ============================================================
FreeLuckyBlock.OnClientEvent:Connect(function(action, valeur)
    if action == "start" then
        afficherPopup(
            "🎁 FREE LUCKY BLOCK",
            "Stay in game for <b>15 minutes</b> and a <b>Mythic Lucky Block</b> is yours — for free!\n\n" ..
            "⏳ Watch the timer at the <b>bottom-right</b> of your screen."
        )
    elseif action == "granted" then
        afficherPopup(
            "🎉 LUCKY BLOCK UNLOCKED!",
            "Your <b>free Mythic Lucky Block</b> is in your bag! 🎒\n\n" ..
            "Place it on an empty slot to <b>open it</b> and reveal your reward!"
        )
    end
end)
