-- StarterPlayerScripts/Common/SlotMenuHUD.client.lua
-- DobiGames — Menu Retrieve / Sell sur slot occupé
-- Ouvert par le PP "Manage" sur TouchPart côté serveur

local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- RemoteEvents
local OuvrirMenuSlot = RS:WaitForChild("OuvrirMenuSlot", 30)
local ActionSlot     = RS:WaitForChild("ActionSlot",     30)

if not OuvrirMenuSlot or not ActionSlot then
    warn("[SlotMenuHUD] RemoteEvents manquants — HUD désactivé")
    return
end

-- ScreenGui dédié (évite conflit avec MainGui)
local screenGui = Instance.new("ScreenGui")
screenGui.Name               = "SlotMenuGui"
screenGui.ResetOnSpawn       = false
screenGui.IgnoreGuiInset     = true
screenGui.ZIndexBehavior     = Enum.ZIndexBehavior.Sibling
screenGui.Parent             = playerGui

-- ============================================================
-- Création / mise à jour du menu
-- ============================================================

local function fermerMenu()
    local existing = screenGui:FindFirstChild("SlotMenu")
    if existing then existing:Destroy() end
end

OuvrirMenuSlot.OnClientEvent:Connect(function(slotInfo)
    -- Fermer menu précédent
    fermerMenu()

    -- ── Fond du menu ─────────────────────────────────────────
    local menu = Instance.new("Frame", screenGui)
    menu.Name                   = "SlotMenu"
    menu.Size                   = UDim2.new(0, 300, 0, 200)
    menu.Position               = UDim2.new(0.5, -150, 0.5, -100)
    menu.BackgroundColor3       = Color3.fromRGB(30, 20, 8)
    menu.BackgroundTransparency = 0.05
    menu.BorderSizePixel        = 0
    menu.ZIndex                 = 20
    Instance.new("UICorner", menu).CornerRadius = UDim.new(0, 12)

    local stroke = Instance.new("UIStroke", menu)
    stroke.Color     = Color3.fromRGB(220, 170, 40)
    stroke.Thickness = 3

    -- ── Titre ────────────────────────────────────────────────
    local titre = Instance.new("TextLabel", menu)
    titre.Size                   = UDim2.new(1, -50, 0, 38)
    titre.Position               = UDim2.new(0, 10, 0, 6)
    titre.BackgroundTransparency = 1
    titre.TextColor3             = Color3.fromRGB(255, 215, 50)
    titre.Font                   = Enum.Font.GothamBold
    titre.TextSize               = 15
    titre.TextXAlignment         = Enum.TextXAlignment.Left
    titre.RichText               = true
    titre.Text                   = "🎮 " .. tostring(slotInfo.rarete)
        .. (slotInfo.brNom ~= slotInfo.rarete and ("  —  " .. tostring(slotInfo.brNom)) or "")
    titre.ZIndex                 = 21

    -- ── Bouton fermer ────────────────────────────────────────
    local btnClose = Instance.new("TextButton", menu)
    btnClose.Size                   = UDim2.new(0, 32, 0, 32)
    btnClose.Position               = UDim2.new(1, -38, 0, 6)
    btnClose.BackgroundColor3       = Color3.fromRGB(170, 40, 25)
    btnClose.TextColor3             = Color3.fromRGB(255, 255, 255)
    btnClose.Font                   = Enum.Font.GothamBold
    btnClose.TextSize               = 14
    btnClose.Text                   = "✕"
    btnClose.BorderSizePixel        = 0
    btnClose.ZIndex                 = 22
    Instance.new("UICorner", btnClose).CornerRadius = UDim.new(0, 6)
    btnClose.MouseButton1Click:Connect(fermerMenu)

    -- ── Info income ──────────────────────────────────────────
    local lblIncome = Instance.new("TextLabel", menu)
    lblIncome.Size                   = UDim2.new(1, -20, 0, 24)
    lblIncome.Position               = UDim2.new(0, 10, 0, 48)
    lblIncome.BackgroundTransparency = 1
    lblIncome.TextColor3             = Color3.fromRGB(180, 160, 100)
    lblIncome.Font                   = Enum.Font.Gotham
    lblIncome.TextSize               = 13
    lblIncome.TextXAlignment         = Enum.TextXAlignment.Left
    lblIncome.Text                   = "💰 Revenu : $" .. tostring(slotInfo.income or 0) .. "/s"
    lblIncome.ZIndex                 = 21

    -- ── Bouton RETRIEVE ──────────────────────────────────────
    local btnRetrieve = Instance.new("TextButton", menu)
    btnRetrieve.Size                   = UDim2.new(1, -20, 0, 48)
    btnRetrieve.Position               = UDim2.new(0, 10, 0, 78)
    btnRetrieve.BackgroundColor3       = Color3.fromRGB(60, 130, 25)
    btnRetrieve.TextColor3             = Color3.fromRGB(255, 255, 255)
    btnRetrieve.Font                   = Enum.Font.GothamBold
    btnRetrieve.TextSize               = 14
    btnRetrieve.Text                   = "↩️  Retrieve  (reprendre dans carry)"
    btnRetrieve.BorderSizePixel        = 0
    btnRetrieve.ZIndex                 = 21
    Instance.new("UICorner", btnRetrieve).CornerRadius = UDim.new(0, 8)

    btnRetrieve.MouseButton1Click:Connect(function()
        ActionSlot:FireServer("retrieve", slotInfo.spotKey)
        fermerMenu()
    end)

    -- ── Bouton SELL ──────────────────────────────────────────
    local btnSell = Instance.new("TextButton", menu)
    btnSell.Size                   = UDim2.new(1, -20, 0, 48)
    btnSell.Position               = UDim2.new(0, 10, 0, 136)
    btnSell.BackgroundColor3       = Color3.fromRGB(200, 140, 0)
    btnSell.TextColor3             = Color3.fromRGB(255, 255, 255)
    btnSell.Font                   = Enum.Font.GothamBold
    btnSell.TextSize               = 14
    btnSell.Text                   = "💰  Sell  (+" .. tostring(math.floor((slotInfo.income or 0) * 10)) .. " coins bonus)"
    btnSell.BorderSizePixel        = 0
    btnSell.ZIndex                 = 21
    Instance.new("UICorner", btnSell).CornerRadius = UDim.new(0, 8)

    btnSell.MouseButton1Click:Connect(function()
        ActionSlot:FireServer("sell", slotInfo.spotKey)
        fermerMenu()
    end)

    -- Animation apparition
    menu.Size     = UDim2.new(0, 300, 0, 0)
    menu.ClipsDescendants = true
    TweenService:Create(menu,
        TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Size = UDim2.new(0, 300, 0, 200) }
    ):Play()
    task.delay(0.2, function()
        if menu and menu.Parent then
            menu.ClipsDescendants = false
        end
    end)
end)
