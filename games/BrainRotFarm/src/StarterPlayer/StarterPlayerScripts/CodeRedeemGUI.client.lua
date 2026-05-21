-- StarterPlayerScripts/CodeRedeemGUI.client.lua
-- Modale de saisie des codes promo — mobile-first

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local function _getCloseEvent()
    local e = playerGui:FindFirstChild("__CloseMenuEvent")
    if not e then e = Instance.new("BindableEvent") ; e.Name = "__CloseMenuEvent" ; e.Parent = playerGui end
    return e
end
local closeMenuEvent = _getCloseEvent()

local Logger               = require(ReplicatedStorage.SharedLib.Logger)
local ModalManager         = require(ReplicatedStorage.SharedLib.ModalManager)
local CodeRedeemAnimations = require(script.Parent:WaitForChild("CodeRedeemAnimations"))

local MODAL_NAME = "CodeRedeem"

-- RemoteFunction créée par Main.server.lua
local CodeRedeem = ReplicatedStorage:WaitForChild("CodeRedeem", 30)

-- ============================================================
-- ScreenGui
-- ============================================================
local gui = Instance.new("ScreenGui")
gui.Name           = "CodeRedeemGUI"
gui.ResetOnSpawn   = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset = false
gui.DisplayOrder   = 20
gui.Parent         = playerGui

-- ============================================================
-- Bouton "Codes" — sera reparenté dans SideMenuHUD
-- ============================================================
local codesBtn = Instance.new("TextButton")
codesBtn.Name                   = "CodesButton"
codesBtn.BackgroundColor3       = Color3.fromRGB(40, 10, 70)
codesBtn.BackgroundTransparency = 0.05
codesBtn.Text                   = "🎟️\nCodes"
codesBtn.TextColor3             = Color3.fromRGB(220, 180, 255)
codesBtn.Font                   = Enum.Font.GothamBold
codesBtn.TextSize               = 13
codesBtn.TextWrapped            = true
codesBtn.BorderSizePixel        = 0
codesBtn.ZIndex                 = 16
codesBtn.Parent                 = gui
Instance.new("UICorner", codesBtn).CornerRadius = UDim.new(0, 10)
local codesBtnStroke = Instance.new("UIStroke", codesBtn)
codesBtnStroke.Color     = Color3.fromRGB(140, 80, 220)
codesBtnStroke.Thickness = 1.5

-- ============================================================
-- Overlay de fond (clic en dehors = fermer)
-- ============================================================
local overlay = Instance.new("TextButton")
overlay.Name                   = "Overlay"
overlay.Size                   = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
overlay.BackgroundTransparency = 0.5
overlay.Text                   = ""
overlay.BorderSizePixel        = 0
overlay.ZIndex                 = 25
overlay.Visible                = false
overlay.Parent                 = gui

-- ============================================================
-- Panel principal
-- ============================================================
local PANEL_W = 340
local PANEL_H = 290

local panel = Instance.new("Frame")
panel.Name                   = "CodePanel"
panel.Size                   = UDim2.new(0, PANEL_W, 0, PANEL_H)
panel.Position               = UDim2.new(0.5, -PANEL_W / 2, 0.5, -PANEL_H / 2)
panel.BackgroundColor3       = Color3.fromRGB(15, 8, 25)
panel.BorderSizePixel        = 0
panel.ZIndex                 = 26
panel.Visible                = false
panel.Parent                 = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)
local panelStroke = Instance.new("UIStroke", panel)
panelStroke.Color           = Color3.fromRGB(255, 180, 30)
panelStroke.Thickness       = 5
panelStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
panel.ClipsDescendants      = true

-- Titre
local titleLabel = Instance.new("TextLabel")
titleLabel.Name                   = "Title"
titleLabel.Size                   = UDim2.new(1, 0, 0, 54)
titleLabel.Position               = UDim2.new(0, 0, 0, 0)
titleLabel.BackgroundColor3       = Color3.fromRGB(255, 200, 50)
titleLabel.BackgroundTransparency = 0
titleLabel.Text                   = "  PROMO CODES"
titleLabel.TextColor3             = Color3.fromRGB(255, 255, 255)
titleLabel.TextStrokeColor3       = Color3.fromRGB(80, 40, 0)
titleLabel.TextStrokeTransparency = 0
titleLabel.Font                   = Enum.Font.GothamBold
titleLabel.TextSize               = 20
titleLabel.TextXAlignment         = Enum.TextXAlignment.Left
titleLabel.ZIndex                 = 27
titleLabel.Parent                 = panel
local _codeStuds = Instance.new("ImageLabel", titleLabel)
_codeStuds.Size = UDim2.new(1,0,1,0) ; _codeStuds.BackgroundTransparency = 1
_codeStuds.Image = "rbxassetid://6927295847" ; _codeStuds.ScaleType = Enum.ScaleType.Tile
_codeStuds.TileSize = UDim2.fromOffset(30,30) ; _codeStuds.ImageTransparency =  0.15
_codeStuds.ImageColor3 = Color3.fromRGB(160, 90, 0)
_codeStuds.ZIndex = 28

-- Bouton X
local closeBtn = Instance.new("TextButton")
closeBtn.Name                   = "CloseBtn"
closeBtn.Size                   = UDim2.new(0, 32, 0, 32)
closeBtn.Position               = UDim2.new(1, -44, 0, 12)
closeBtn.BackgroundColor3       = Color3.fromRGB(230, 50, 50)
closeBtn.BackgroundTransparency = 0
closeBtn.Text                   = "X"
closeBtn.TextColor3             = Color3.fromRGB(255, 255, 255)
closeBtn.Font                   = Enum.Font.GothamBold
closeBtn.TextSize               = 16
closeBtn.BorderSizePixel        = 0
closeBtn.ZIndex                 = 28
closeBtn.Parent                 = panel
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
local _cbs = Instance.new("UIStroke", closeBtn)
_cbs.Color = Color3.fromRGB(255,255,255) ; _cbs.Thickness = 3

-- Séparateur
local sep = Instance.new("Frame")
sep.Size                   = UDim2.new(1, -32, 0, 1)
sep.Position               = UDim2.new(0, 16, 0, 58)
sep.BackgroundColor3       = Color3.fromRGB(80, 50, 120)
sep.BackgroundTransparency = 0
sep.BorderSizePixel        = 0
sep.ZIndex                 = 27
sep.Parent                 = panel

-- Label "Enter your code"
local inputLabel = Instance.new("TextLabel")
inputLabel.Name                   = "InputLabel"
inputLabel.Size                   = UDim2.new(1, -32, 0, 22)
inputLabel.Position               = UDim2.new(0, 16, 0, 70)
inputLabel.BackgroundTransparency = 1
inputLabel.Text                   = "Enter your code:"
inputLabel.TextColor3             = Color3.fromRGB(180, 160, 210)
inputLabel.Font                   = Enum.Font.Gotham
inputLabel.TextSize               = 14
inputLabel.TextXAlignment         = Enum.TextXAlignment.Left
inputLabel.ZIndex                 = 27
inputLabel.Parent                 = panel

-- TextBox
local inputBox = Instance.new("TextBox")
inputBox.Name                   = "CodeInput"
inputBox.Size                   = UDim2.new(1, -32, 0, 50)
inputBox.Position               = UDim2.new(0, 16, 0, 96)
inputBox.BackgroundColor3       = Color3.fromRGB(30, 15, 50)
inputBox.BackgroundTransparency = 0
inputBox.Text                   = ""
inputBox.PlaceholderText        = "ENTER CODE HERE..."
inputBox.PlaceholderColor3      = Color3.fromRGB(100, 80, 130)
inputBox.TextColor3             = Color3.fromRGB(255, 255, 255)
inputBox.Font                   = Enum.Font.GothamBold
inputBox.TextSize               = 18
inputBox.ClearTextOnFocus       = false
inputBox.BorderSizePixel        = 0
inputBox.ZIndex                 = 27
inputBox.Parent                 = panel
Instance.new("UICorner", inputBox).CornerRadius = UDim.new(0, 10)
local inputStroke = Instance.new("UIStroke", inputBox)
inputStroke.Color     = Color3.fromRGB(140, 80, 220)
inputStroke.Thickness = 1.5

-- Bouton REDEEM
local redeemBtn = Instance.new("TextButton")
redeemBtn.Name                   = "RedeemBtn"
redeemBtn.Size                   = UDim2.new(1, -32, 0, 50)
redeemBtn.Position               = UDim2.new(0, 16, 0, 158)
redeemBtn.BackgroundColor3       = Color3.fromRGB(140, 220, 70)
redeemBtn.BackgroundTransparency = 0
redeemBtn.Text                   = "REDEEM"
redeemBtn.TextColor3             = Color3.fromRGB(255, 255, 255)
redeemBtn.TextStrokeColor3       = Color3.fromRGB(40, 80, 10)
redeemBtn.TextStrokeTransparency = 0
redeemBtn.Font                   = Enum.Font.GothamBold
redeemBtn.TextSize               = 18
redeemBtn.BorderSizePixel        = 0
redeemBtn.ZIndex                 = 27
redeemBtn.Parent                 = panel
Instance.new("UICorner", redeemBtn).CornerRadius = UDim.new(0, 20)
local _rds = Instance.new("UIStroke", redeemBtn)
_rds.Color = Color3.fromRGB(60,120,30) ; _rds.Thickness = 2

-- Zone de feedback
local feedbackLabel = Instance.new("TextLabel")
feedbackLabel.Name                   = "FeedbackLabel"
feedbackLabel.Size                   = UDim2.new(1, -32, 0, 56)
feedbackLabel.Position               = UDim2.new(0, 16, 0, 220)
feedbackLabel.BackgroundTransparency = 1
feedbackLabel.Text                   = ""
feedbackLabel.TextColor3             = Color3.fromRGB(200, 200, 200)
feedbackLabel.Font                   = Enum.Font.Gotham
feedbackLabel.TextSize               = 14
feedbackLabel.TextWrapped            = true
feedbackLabel.ZIndex                 = 27
feedbackLabel.Parent                 = panel

-- ============================================================
-- Logique open / close
-- ============================================================
closeMenuEvent.Event:Connect(function(exceptName)
    if exceptName ~= "CODE_REDEEM" and panel.Visible then fermerModal() end
end)

local function ouvrirModal()
    closeMenuEvent:Fire("CODE_REDEEM")
    ModalManager.Open(MODAL_NAME)
    overlay.Visible = true
    panel.Visible   = true
    panel.Size      = UDim2.new(0, PANEL_W, 0, 0)
    TweenService:Create(panel,
        TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Size = UDim2.new(0, PANEL_W, 0, PANEL_H) }
    ):Play()
    task.delay(0.05, function()
        if panel.Visible then inputBox:CaptureFocus() end
    end)
    Logger.debug("Code", "Modal ouverte")
end

local function fermerModal()
    if not panel.Visible then return end
    ModalManager.Close(MODAL_NAME)
    overlay.Visible    = false
    panel.Visible      = false
    feedbackLabel.Text = ""
    Logger.debug("Code", "Modal fermee")
end

-- ============================================================
-- Logique de soumission
-- ============================================================
local enCooldown = false
local enRequete  = false

local COULEUR_SUCCES = Color3.fromRGB(100, 255, 140)
local COULEUR_ERREUR = Color3.fromRGB(255, 100, 100)
local COULEUR_INFO   = Color3.fromRGB(255, 200, 50)
local COULEUR_BTN    = Color3.fromRGB(140, 220, 70)

local function setFeedback(texte, couleur, dureeAuto)
    feedbackLabel.Text       = texte
    feedbackLabel.TextColor3 = couleur or Color3.fromRGB(200, 200, 200)
    if dureeAuto then
        local snapshot = texte
        task.delay(dureeAuto, function()
            if feedbackLabel.Text == snapshot then
                feedbackLabel.Text = ""
            end
        end)
    end
end

local function flashBtn(couleur)
    TweenService:Create(redeemBtn, TweenInfo.new(0.12),
        { BackgroundColor3 = couleur }):Play()
    task.delay(0.4, function()
        TweenService:Create(redeemBtn, TweenInfo.new(0.2),
            { BackgroundColor3 = COULEUR_BTN }):Play()
    end)
end

local function effectuerRedeem()
    if enCooldown or enRequete then return end

    local code = string.upper(string.match(inputBox.Text or "", "^%s*(.-)%s*$") or "")
    if #code == 0 then
        setFeedback("⚠️ Please enter a code.", COULEUR_INFO, 3)
        return
    end

    if not CodeRedeem then
        setFeedback("❌ Server not ready. Try again.", COULEUR_ERREUR, 4)
        return
    end

    -- État chargement
    enRequete                    = true
    redeemBtn.Text               = "..."
    redeemBtn.BackgroundColor3   = Color3.fromRGB(55, 25, 105)
    redeemBtn.AutoButtonColor    = false

    local ok, result = pcall(function()
        return CodeRedeem:InvokeServer(code)
    end)

    -- Restaurer le bouton
    enRequete                    = false
    redeemBtn.Text               = "REDEEM"
    redeemBtn.BackgroundColor3   = COULEUR_BTN
    redeemBtn.AutoButtonColor    = true

    if not ok or not result then
        setFeedback("❌ Server error. Please try again.", COULEUR_ERREUR, 4)
        return
    end

    if result.Success then
        setFeedback("✅ " .. (result.Message or "Code redeemed!"), COULEUR_SUCCES, 6)
        inputBox.Text = ""
        flashBtn(Color3.fromRGB(40, 140, 60))
        CodeRedeemAnimations.PlaySuccess(result.Rewards, redeemBtn)
    else
        setFeedback("❌ " .. (result.Message or "Invalid code."), COULEUR_ERREUR, 4)
        flashBtn(Color3.fromRGB(140, 40, 40))
        CodeRedeemAnimations.PlayError(result.Message, redeemBtn)
    end

    -- Cooldown anti-spam client (3s sur succès pour couvrir l'animation, 2s sur erreur)
    enCooldown = true
    task.delay(result.Success and 3 or 2, function() enCooldown = false end)
end

-- ============================================================
-- Connexions
-- ============================================================

codesBtn.MouseButton1Click:Connect(ouvrirModal)
closeBtn.MouseButton1Click:Connect(fermerModal)
overlay.MouseButton1Click:Connect(fermerModal)
redeemBtn.MouseButton1Click:Connect(effectuerRedeem)

-- Forcer l'uppercase à la saisie (UX mobile)
inputBox:GetPropertyChangedSignal("Text"):Connect(function()
    local upper = string.upper(inputBox.Text)
    if inputBox.Text ~= upper then
        inputBox.Text = upper
    end
end)

-- Entrée clavier = soumettre
inputBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then effectuerRedeem() end
end)

Logger.info("Menu", "CodeRedeemGUI initialise")
