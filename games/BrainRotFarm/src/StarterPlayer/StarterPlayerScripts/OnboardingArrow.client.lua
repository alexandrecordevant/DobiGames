-- StarterPlayerScripts/OnboardingArrow.client.lua
-- Flèche 3D onboarding + message HUD + célébration premier dépôt
-- Actif uniquement sur la première session (sessionsCount == 1 et non complété)

local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local UpdateHUD       = RS:WaitForChild("UpdateHUD")
local OnboardingEvent = RS:WaitForChild("OnboardingEvent")

local arrowActive = false

-- Message HUD top-center (3s puis fade)
local function afficherMessageHUD(texte)
    local sg = Instance.new("ScreenGui")
    sg.Name              = "OnboardingMsg"
    sg.ResetOnSpawn      = false
    sg.ZIndexBehavior    = Enum.ZIndexBehavior.Sibling
    sg.DisplayOrder      = 30
    sg.IgnoreGuiInset    = true
    sg.Parent            = playerGui

    local lbl = Instance.new("TextLabel", sg)
    lbl.Size                   = UDim2.new(0.5, 0, 0, 56)
    lbl.Position               = UDim2.new(0.25, 0, 0.08, 0)
    lbl.BackgroundColor3       = Color3.fromRGB(20, 20, 20)
    lbl.BackgroundTransparency = 0.25
    lbl.TextColor3             = Color3.fromRGB(255, 220, 50)
    lbl.Font                   = Enum.Font.GothamBold
    lbl.TextSize               = 20
    lbl.Text                   = texte
    lbl.TextWrapped            = true
    lbl.ZIndex                 = 10
    lbl.BorderSizePixel        = 0
    Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 10)

    task.delay(2.5, function()
        if not sg.Parent then return end
        TweenService:Create(lbl, TweenInfo.new(0.7, Enum.EasingStyle.Quad), {
            TextTransparency       = 1,
            BackgroundTransparency = 1,
        }):Play()
        task.delay(0.8, function()
            if sg.Parent then sg:Destroy() end
        end)
    end)
end

-- Flèche BillboardGui au-dessus du joueur avec bobbing
local function creerFleche()
    local character = player.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local ancienne = hrp:FindFirstChild("OnboardingArrowBB")
    if ancienne then ancienne:Destroy() end

    local bb = Instance.new("BillboardGui")
    bb.Name             = "OnboardingArrowBB"
    bb.Size             = UDim2.new(0, 120, 0, 90)
    bb.StudsOffset      = Vector3.new(0, 6, 0)
    bb.AlwaysOnTop      = false
    bb.MaxDistance      = 80
    bb.ClipsDescendants = false
    bb.Parent           = hrp

    local fleche = Instance.new("TextLabel", bb)
    fleche.Size                   = UDim2.new(1, 0, 0.55, 0)
    fleche.Position               = UDim2.new(0, 0, 0, 0)
    fleche.BackgroundTransparency = 1
    fleche.Text                   = "⬇"
    fleche.Font                   = Enum.Font.GothamBold
    fleche.TextColor3             = Color3.fromRGB(255, 220, 50)
    fleche.TextScaled             = true
    fleche.TextStrokeTransparency = 0
    fleche.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)

    local texte = Instance.new("TextLabel", bb)
    texte.Size                   = UDim2.new(1, 0, 0.45, 0)
    texte.Position               = UDim2.new(0, 0, 0.55, 0)
    texte.BackgroundTransparency = 1
    texte.Text                   = "Catch a BrainRot!"
    texte.Font                   = Enum.Font.GothamBold
    texte.TextColor3             = Color3.fromRGB(255, 255, 255)
    texte.TextScaled             = true
    texte.TextStrokeTransparency = 0.2
    texte.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
    texte.TextWrapped            = true

    -- Bobbing axe Y
    TweenService:Create(bb,
        TweenInfo.new(0.65, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { StudsOffset = Vector3.new(0, 8.5, 0) }
    ):Play()

    -- Auto-destroy après 30s
    task.delay(30, function()
        if bb and bb.Parent then bb:Destroy() end
        arrowActive = false
    end)

    return bb
end

-- Floating text "+X 🎉 FIRST CASH!" doré qui monte et s'efface
local function celebrerPremierDepot(bonusCoins)
    local character = player.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local bb = Instance.new("BillboardGui")
    bb.Name        = "FirstDepositVFX"
    bb.Size        = UDim2.new(0, 220, 0, 70)
    bb.StudsOffset = Vector3.new(0, 10, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 60
    bb.Parent      = hrp

    local lbl = Instance.new("TextLabel", bb)
    lbl.Size                   = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = "+" .. tostring(bonusCoins) .. " 🎉 FIRST CASH!"
    lbl.Font                   = Enum.Font.GothamBold
    lbl.TextColor3             = Color3.fromRGB(255, 215, 0)
    lbl.TextScaled             = true
    lbl.TextStrokeTransparency = 0
    lbl.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)

    -- Montée
    TweenService:Create(bb,
        TweenInfo.new(2.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { StudsOffset = Vector3.new(0, 18, 0) }
    ):Play()
    -- Fade texte après 1.5s
    task.delay(1.5, function()
        if lbl and lbl.Parent then
            TweenService:Create(lbl, TweenInfo.new(1, Enum.EasingStyle.Quad), {
                TextTransparency = 1,
            }):Play()
        end
    end)
    task.delay(2.6, function()
        if bb and bb.Parent then bb:Destroy() end
    end)

    -- Petites particules dorées sur le HumanoidRootPart (côté client uniquement)
    local pe = Instance.new("ParticleEmitter", hrp)
    pe.Rate        = 30
    pe.Lifetime    = NumberRange.new(0.6, 1.2)
    pe.Speed       = NumberRange.new(8, 16)
    pe.SpreadAngle = Vector2.new(60, 60)
    pe.Color       = ColorSequence.new(Color3.fromRGB(255, 215, 0))
    pe.Size        = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
    pe.LightEmission = 0.8
    pe.Transparency = NumberSequence.new(0.2)
    task.delay(0.5, function() if pe.Parent then pe.Rate = 0 end end)
    task.delay(2, function() if pe.Parent then pe:Destroy() end end)

    afficherMessageHUD("Continue! Fill your base 🌾")
end

-- Détruire la flèche au premier pickup
local function surPremierPickup()
    local character = player.Character
    if character then
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local fleche = hrp:FindFirstChild("OnboardingArrowBB")
            if fleche then fleche:Destroy() end
        end
    end
    arrowActive = false
end

-- Écoute des events onboarding depuis le serveur
OnboardingEvent.OnClientEvent:Connect(function(eventType, data)
    if eventType == "firstPickup" then
        surPremierPickup()
    elseif eventType == "firstDeposit" then
        celebrerPremierDepot(data or 100)
    end
end)

-- Déclenchement flèche à la réception du premier HUD
UpdateHUD.OnClientEvent:Connect(function(playerData)
    if arrowActive then return end
    if playerData.hasCompletedOnboarding then return end

    -- Onboarding non complété → afficher flèche + message
    arrowActive = true
    afficherMessageHUD("🎯 Catch a BrainRot!")
    task.spawn(function()
        local character = player.Character or player.CharacterAdded:Wait()
        local hrp = character:WaitForChild("HumanoidRootPart", 10)
        if not hrp then return end
        task.wait(1.2) -- laisser le téléport vers la base se stabiliser
        creerFleche()
    end)
end)
