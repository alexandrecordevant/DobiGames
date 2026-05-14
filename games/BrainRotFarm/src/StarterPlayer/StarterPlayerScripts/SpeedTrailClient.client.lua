local Players    = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris     = game:GetService("Debris")

local player    = Players.LocalPlayer
local playerGui = player.PlayerGui

-- ============================================================
-- Propriétés du trail selon la WalkSpeed courante
-- ============================================================
local function trailProps(speed)
    if speed <= 16 then return nil end

    local pct = math.clamp((speed - 16) / (40 - 16), 0, 1)

    local color
    if speed <= 22 then
        -- Lv1-5 : bleu clair
        color = ColorSequence.new(Color3.fromRGB(120, 200, 255))
    elseif speed <= 30 then
        -- Lv6-10 : cyan électrique
        color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 230, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 160, 255)),
        })
    elseif speed <= 35 then
        -- Lv11-14 : bleu blanc vif
        color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(220, 245, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 140, 255)),
        })
    else
        -- Lv15 MAX : doré flamboyant
        color = ColorSequence.new({
            ColorSequenceKeypoint.new(0,   Color3.fromRGB(255, 230, 50)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 140, 0)),
            ColorSequenceKeypoint.new(1,   Color3.fromRGB(255, 50, 0)),
        })
    end

    return {
        color        = color,
        widthScale   = NumberSequence.new(0.15 + pct * 0.85), -- 0.15 → 1.0
        transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.05),
            NumberSequenceKeypoint.new(0.6, 0.4),
            NumberSequenceKeypoint.new(1, 1),
        }),
        lifetime     = 0.1 + pct * 0.35, -- 0.10 → 0.45 s
    }
end

-- ============================================================
-- Flash + overlay texte lors d'un achat de vitesse
-- ============================================================
local function flashAchat(speed)
    local gui = Instance.new("ScreenGui")
    gui.Name           = "SpeedFlash"
    gui.ResetOnSpawn   = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent         = playerGui

    -- Voile coloré en fonction du tier
    local couleur
    if speed <= 22 then
        couleur = Color3.fromRGB(80, 170, 255)
    elseif speed <= 30 then
        couleur = Color3.fromRGB(0, 220, 255)
    elseif speed <= 35 then
        couleur = Color3.fromRGB(130, 210, 255)
    else
        couleur = Color3.fromRGB(255, 190, 0) -- MAX doré
    end

    local bg = Instance.new("Frame")
    bg.Size                    = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3        = couleur
    bg.BackgroundTransparency  = 0.55
    bg.BorderSizePixel         = 0
    bg.ZIndex                  = 20
    bg.Parent                  = gui

    local label = Instance.new("TextLabel")
    label.Size               = UDim2.new(1, 0, 0, 90)
    label.Position           = UDim2.new(0, 0, 0.33, 0)
    label.BackgroundTransparency = 1
    label.Text               = speed >= 40 and "⚡ MAX SPEED! ⚡" or "⚡ SPEED UP! ⚡"
    label.TextColor3         = Color3.new(1, 1, 1)
    label.Font               = Enum.Font.GothamBold
    label.TextScaled         = true
    label.TextStrokeTransparency = 0.4
    label.TextStrokeColor3   = Color3.fromRGB(0, 80, 180)
    label.ZIndex             = 21
    label.Parent             = gui

    TweenService:Create(bg, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { BackgroundTransparency = 1 }):Play()

    TweenService:Create(label, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { TextTransparency = 1 }):Play()

    Debris:AddItem(gui, 0.6)
end

-- ============================================================
-- Setup du Trail sur le personnage
-- ============================================================
local trail, att0, att1 = nil, nil, nil

local function setupTrail(char)
    -- Nettoyage du précédent
    if att0  then pcall(function() att0:Destroy()  end) end
    if att1  then pcall(function() att1:Destroy()  end) end
    if trail then pcall(function() trail:Destroy() end) end
    trail, att0, att1 = nil, nil, nil

    local hrp      = char:WaitForChild("HumanoidRootPart", 5)
    local humanoid = char:WaitForChild("Humanoid", 5)
    if not hrp or not humanoid then return end

    -- Deux attachments : haut du HRP → pieds
    att0 = Instance.new("Attachment")
    att0.Position = Vector3.new(0, 0.6, 0)
    att0.Parent   = hrp

    att1 = Instance.new("Attachment")
    att1.Position = Vector3.new(0, -2.8, 0)
    att1.Parent   = hrp

    trail               = Instance.new("Trail")
    trail.Attachment0   = att0
    trail.Attachment1   = att1
    trail.FaceCamera    = true
    trail.Enabled       = false
    trail.LightEmission = 0.6
    trail.Parent        = hrp

    local prevSpeed = humanoid.WalkSpeed

    local function applySpeed(speed)
        local props = trailProps(speed)
        if not props then
            trail.Enabled = false
        else
            trail.Color        = props.color
            trail.WidthScale   = props.widthScale
            trail.Transparency = props.transparency
            trail.Lifetime     = props.lifetime
            trail.Enabled      = true
        end

        if speed > prevSpeed and prevSpeed > 0 then
            flashAchat(speed)
        end
        prevSpeed = speed
    end

    applySpeed(humanoid.WalkSpeed)
    humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
        applySpeed(humanoid.WalkSpeed)
    end)
end

player.CharacterAdded:Connect(setupTrail)
if player.Character then
    task.spawn(setupTrail, player.Character)
end
