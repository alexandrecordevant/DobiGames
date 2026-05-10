-- StarterPlayerScripts/SellConfirmClient.client.lua
-- Dialogue de confirmation avant la vente d'un BR rare (GOD / SECRET / OG)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local SellConfirmShow  = ReplicatedStorage:WaitForChild("SellConfirmShow",  30)
local SellConfirmReply = ReplicatedStorage:WaitForChild("SellConfirmReply", 30)
if not SellConfirmShow or not SellConfirmReply then return end

-- Palette identique au reste de LavaTower
local C = {
    PanelBg  = Color3.fromRGB(10,  10,  10),
    Bordure  = Color3.fromRGB(60,  60,  60),
    TextPrim = Color3.fromRGB(220, 220, 220),
    Oui      = Color3.fromRGB(45,  130, 45),
    Non      = Color3.fromRGB(140, 45,  45),
    OuiHov   = Color3.fromRGB(60,  160, 60),
    NonHov   = Color3.fromRGB(170, 60,  60),
}

local function newInst(class, props)
    local inst = Instance.new(class)
    for k, v in pairs(props) do inst[k] = v end
    return inst
end

local function addCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 0)
    c.Parent = parent
end

local function addStroke(parent, color)
    local s = Instance.new("UIStroke")
    s.Color     = color or C.Bordure
    s.Thickness = 1
    s.Parent    = parent
end

local function addHover(btn, base, hovered)
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.08), { BackgroundColor3 = hovered }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.08), { BackgroundColor3 = base }):Play()
    end)
end

-- ScreenGui
local screenGui = newInst("ScreenGui", {
    Name           = "SellConfirmGui",
    ResetOnSpawn   = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    Enabled        = false,
    Parent         = playerGui,
})


-- Panel central
local panel = newInst("Frame", {
    Name                   = "Panel",
    Size                   = UDim2.new(0, 340, 0, 168),
    AnchorPoint            = Vector2.new(0.5, 0.5),
    Position               = UDim2.new(0.5, 0, 1.5, 0),
    BackgroundColor3       = C.PanelBg,
    BackgroundTransparency = 0.05,
    BorderSizePixel        = 0,
    ZIndex                 = 2,
    Parent                 = screenGui,
})
addCorner(panel, 0)
addStroke(panel)

-- UIScale (cohérent avec ShopClient)
local uiScale = Instance.new("UIScale")
uiScale.Parent = panel
local function ajusterScale()
    local vp = workspace.CurrentCamera.ViewportSize
    local s  = math.min(vp.X / 480, vp.Y / 640, 1)
    uiScale.Scale = math.max(0.55, s)
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(ajusterScale)
ajusterScale()

-- Texte de la question
newInst("TextLabel", {
    Size                   = UDim2.new(1, -28, 0, 52),
    Position               = UDim2.new(0, 14, 0, 14),
    BackgroundTransparency = 1,
    Text                   = "Are you sure you want to sell it?",
    Font                   = Enum.Font.GothamBold,
    TextSize               = 17,
    TextScaled             = false,
    TextWrapped            = true,
    TextColor3             = C.TextPrim,
    TextXAlignment         = Enum.TextXAlignment.Center,
    ZIndex                 = 3,
    Parent                 = panel,
})

-- Séparateur
newInst("Frame", {
    Size             = UDim2.new(1, -24, 0, 1),
    Position         = UDim2.new(0, 12, 0, 74),
    BackgroundColor3 = C.Bordure,
    BorderSizePixel  = 0,
    ZIndex           = 3,
    Parent           = panel,
})

-- Bouton Yes (vert)
local ouiBtn = newInst("TextButton", {
    Name             = "OuiBtn",
    Size             = UDim2.new(0, 136, 0, 58),
    Position         = UDim2.new(0, 12, 0, 90),
    BackgroundColor3 = C.Oui,
    Text             = "Yes",
    Font             = Enum.Font.GothamBold,
    TextSize         = 18,
    TextScaled       = false,
    TextColor3       = Color3.fromRGB(255, 255, 255),
    BorderSizePixel  = 0,
    ZIndex           = 3,
    Parent           = panel,
})
addCorner(ouiBtn, 0)
addStroke(ouiBtn, Color3.fromRGB(30, 100, 30))
addHover(ouiBtn, C.Oui, C.OuiHov)

-- Bouton No (rouge)
local nonBtn = newInst("TextButton", {
    Name             = "NonBtn",
    Size             = UDim2.new(0, 136, 0, 58),
    Position         = UDim2.new(1, -148, 0, 90),
    BackgroundColor3 = C.Non,
    Text             = "No",
    Font             = Enum.Font.GothamBold,
    TextSize         = 18,
    TextScaled       = false,
    TextColor3       = Color3.fromRGB(255, 255, 255),
    BorderSizePixel  = 0,
    ZIndex           = 3,
    Parent           = panel,
})
addCorner(nonBtn, 0)
addStroke(nonBtn, Color3.fromRGB(100, 30, 30))
addHover(nonBtn, C.Non, C.NonHov)

-- Animations (identiques au ShopClient : slide depuis le bas)
local function slideIn()
    screenGui.Enabled = true
    panel.Position    = UDim2.new(0.5, 0, 1.5, 0)
    TweenService:Create(panel,
        TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Position = UDim2.new(0.5, 0, 0.5, 0) }):Play()
end

local function slideOut()
    local t = TweenService:Create(panel,
        TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { Position = UDim2.new(0.5, 0, 1.5, 0) })
    t:Play()
    t.Completed:Wait()
    screenGui.Enabled = false
end

-- Handler : appelé quand le serveur veut une confirmation
-- On répond via SellConfirmReply:FireServer(bool)
SellConfirmShow.OnClientEvent:Connect(function()
    slideIn()

    local bindable = Instance.new("BindableEvent")
    local result   = false

    local connOui = ouiBtn.MouseButton1Click:Connect(function()
        result = true
        bindable:Fire()
    end)
    local connNon = nonBtn.MouseButton1Click:Connect(function()
        bindable:Fire()
    end)
    bindable.Event:Wait()
    bindable:Destroy()
    connOui:Disconnect()
    connNon:Disconnect()

    slideOut()
    SellConfirmReply:FireServer(result)
end)
