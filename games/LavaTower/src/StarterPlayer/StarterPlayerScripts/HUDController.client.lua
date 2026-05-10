-- StarterPlayerScripts/HUDController.client.lua
-- HUD LavaTower

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local Lighting          = game:GetService("Lighting")
local player            = Players.LocalPlayer
local FormatNumber      = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("FormatNumber"))

-- Palette
local C = {
    PanelBg  = Color3.fromRGB(10,  10,  10),
    Bordure  = Color3.fromRGB(60,  60,  60),
    Accent   = Color3.fromRGB(160, 80,  15),
    TextPrim = Color3.fromRGB(220, 220, 220),
    TextSec  = Color3.fromRGB(130, 130, 130),
}

local gui = Instance.new("ScreenGui")
gui.Name          = "HUD"
gui.ResetOnSpawn  = false
gui.Parent        = player.PlayerGui

-- Coins (bas gauche)
local coinsLabel = Instance.new("TextLabel", gui)
coinsLabel.Size                   = UDim2.new(0, 260, 0, 60)
coinsLabel.Position               = UDim2.new(0, 10, 1, -70)
coinsLabel.BackgroundTransparency = 1
coinsLabel.Text                   = "0"
coinsLabel.TextColor3             = C.Accent
coinsLabel.TextStrokeColor3       = Color3.fromRGB(255, 255, 255)
coinsLabel.TextStrokeTransparency = 0
coinsLabel.TextScaled             = false
coinsLabel.TextSize               = 36
coinsLabel.Font                   = Enum.Font.GothamBold
coinsLabel.TextXAlignment         = Enum.TextXAlignment.Left

-- Banniere evenement (haut centre, cachee par defaut)
local eventFrame  = Instance.new("Frame", gui)
eventFrame.Size                   = UDim2.new(0, 320, 0, 50)
eventFrame.Position               = UDim2.new(0.5, -160, 0, 10)
eventFrame.BackgroundColor3       = C.PanelBg
eventFrame.BackgroundTransparency = 0.05
eventFrame.BorderSizePixel        = 0
eventFrame.Visible                = false
local evtCorner = Instance.new("UICorner", eventFrame)
evtCorner.CornerRadius = UDim.new(0, 0)
local evtStroke = Instance.new("UIStroke", eventFrame)
evtStroke.Color     = C.Bordure
evtStroke.Thickness = 1
local eventLabel = Instance.new("TextLabel", eventFrame)
eventLabel.Size                   = UDim2.new(1, 0, 1, 0)
eventLabel.BackgroundTransparency = 1
eventLabel.TextColor3             = C.TextPrim
eventLabel.TextScaled             = false
eventLabel.TextSize               = 15
eventLabel.Font                   = Enum.Font.GothamBold
eventLabel.Text                   = ""

-- Mise a jour HUD
local UpdateHUD = ReplicatedStorage:WaitForChild("UpdateHUD", 15)
if not UpdateHUD then warn("[HUD] UpdateHUD introuvable -- Main.server.lua a crashe ?") return end

UpdateHUD.OnClientEvent:Connect(function(data)
    coinsLabel.Text = FormatNumber.format(data.coins)
end)

-- Inventaire Brainrot (bas gauche, au-dessus des coins)
local brainrotFrame = Instance.new("Frame", gui)
brainrotFrame.Size                   = UDim2.new(0, 280, 0, 50)
brainrotFrame.Position               = UDim2.new(0, 10, 1, -116)
brainrotFrame.BackgroundColor3       = C.PanelBg
brainrotFrame.BackgroundTransparency = 0.05
brainrotFrame.BorderSizePixel        = 0
brainrotFrame.Visible                = false
local brCorner = Instance.new("UICorner", brainrotFrame)
brCorner.CornerRadius = UDim.new(0, 0)
local brStroke = Instance.new("UIStroke", brainrotFrame)
brStroke.Color     = C.Bordure
brStroke.Thickness = 1
local brainrotLabel = Instance.new("TextLabel", brainrotFrame)
brainrotLabel.Size                   = UDim2.new(1, 0, 1, 0)
brainrotLabel.BackgroundTransparency = 1
brainrotLabel.TextColor3             = Color3.fromRGB(200, 160, 255)
brainrotLabel.TextScaled             = false
brainrotLabel.TextSize               = 13
brainrotLabel.Font                   = Enum.Font.GothamBold
brainrotLabel.Text                   = ""

local evtPickedUp = ReplicatedStorage:FindFirstChild("BrainrotPickedUp")
local evtDropped  = ReplicatedStorage:FindFirstChild("BrainrotDropped")

if evtPickedUp then
    evtPickedUp.OnClientEvent:Connect(function(nom, rarete)
        brainrotLabel.Text    = "Brainrot : " .. nom .. " (" .. rarete .. ")"
        brainrotFrame.Visible = true
    end)
end

if evtDropped then
    evtDropped.OnClientEvent:Connect(function()
        brainrotFrame.Visible = false
    end)
end

-- Bouton Escape the Tower (droite ecran)
local ORANGE = Color3.fromRGB(160, 80, 15)

local escapeFrame = Instance.new("Frame", gui)
escapeFrame.Size                   = UDim2.new(0, 170, 0, 50)
escapeFrame.Position               = UDim2.new(1, -180, 0.5, -25)
escapeFrame.BackgroundColor3       = ORANGE
escapeFrame.BackgroundTransparency = 0.05
escapeFrame.BorderSizePixel        = 0
escapeFrame.Visible                = false

local escCorner = Instance.new("UICorner", escapeFrame)
escCorner.CornerRadius = UDim.new(0, 2)

local escStroke = Instance.new("UIStroke", escapeFrame)
escStroke.Color     = Color3.fromRGB(60, 60, 60)
escStroke.Thickness = 1

local escapeButton = Instance.new("TextButton", escapeFrame)
escapeButton.Size                   = UDim2.new(1, 0, 1, 0)
escapeButton.BackgroundTransparency = 1
escapeButton.TextColor3             = Color3.fromRGB(220, 220, 220)
escapeButton.TextScaled             = false
escapeButton.TextSize               = 15
escapeButton.Font                   = Enum.Font.GothamBold
escapeButton.Text                   = "Escape the Tower"

-- Countdown (haut centre pendant l'escape)
local countdownFrame = Instance.new("Frame", gui)
countdownFrame.Size                   = UDim2.new(0, 200, 0, 60)
countdownFrame.Position               = UDim2.new(0.5, -100, 0, 20)
countdownFrame.BackgroundTransparency = 1
countdownFrame.BorderSizePixel        = 0
countdownFrame.Visible                = false

local countdownLabel = Instance.new("TextLabel", countdownFrame)
countdownLabel.Size                   = UDim2.new(1, 0, 1, 0)
countdownLabel.BackgroundTransparency = 1
countdownLabel.TextColor3             = ORANGE
countdownLabel.TextStrokeColor3       = Color3.fromRGB(255, 255, 255)
countdownLabel.TextStrokeTransparency = 0
countdownLabel.TextScaled             = false
countdownLabel.TextSize               = 42
countdownLabel.Font                   = Enum.Font.GothamBold
countdownLabel.Text                   = "3"

-- ── Effets ambiance Toxic Event ──────────────────────────────────────────────
local TWEEN_ATMO = TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

-- Sauvegarde des valeurs Lighting originales (lues une fois au démarrage)
local origLight = {
    Ambient        = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    Brightness     = Lighting.Brightness,
    ClockTime      = Lighting.ClockTime,
    FogColor       = Lighting.FogColor,
    FogStart       = Lighting.FogStart,
    FogEnd         = Lighting.FogEnd,
}

local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
local origAtmo = atmosphere and {
    Density = atmosphere.Density,
    Haze    = atmosphere.Haze,
    Glare   = atmosphere.Glare,
    Color   = atmosphere.Color,
    Decay   = atmosphere.Decay,
} or nil

-- ColorCorrection pour la teinte verte
local colorFX = Instance.new("ColorCorrectionEffect")
colorFX.Name        = "ToxicColorFX"
colorFX.TintColor   = Color3.fromRGB(160, 230, 140)
colorFX.Saturation  = -0.1
colorFX.Brightness  = 0
colorFX.Contrast    = 0.05
colorFX.Enabled     = false
colorFX.Parent      = Lighting

local function activerEffetsLighting()
    colorFX.Enabled    = true
    Lighting.ClockTime = 15  -- après-midi, pas de nuit

    TweenService:Create(Lighting, TWEEN_ATMO, {
        Ambient        = Color3.fromRGB(40, 90, 40),
        OutdoorAmbient = Color3.fromRGB(50, 110, 50),
        Brightness     = 1.4,
        FogColor       = Color3.fromRGB(110, 220, 65),
        FogStart       = 50,
        FogEnd         = 280,
    }):Play()

    if atmosphere then
        TweenService:Create(atmosphere, TWEEN_ATMO, {
            Density = 0.35,
            Haze    = 3,
            Glare   = 0,
            Color   = Color3.fromRGB(110, 210, 60),
            Decay   = Color3.fromRGB(30, 90, 20),
        }):Play()
    end
end

local function restaurerLighting()
    Lighting.ClockTime = origLight.ClockTime

    local tw = TweenService:Create(Lighting, TWEEN_ATMO, {
        Ambient        = origLight.Ambient,
        OutdoorAmbient = origLight.OutdoorAmbient,
        Brightness     = origLight.Brightness,
        FogColor       = origLight.FogColor,
        FogStart       = origLight.FogStart,
        FogEnd         = origLight.FogEnd,
    })
    tw:Play()
    tw.Completed:Once(function() colorFX.Enabled = false end)

    if atmosphere and origAtmo then
        TweenService:Create(atmosphere, TWEEN_ATMO, {
            Density = origAtmo.Density,
            Haze    = origAtmo.Haze,
            Glare   = origAtmo.Glare,
            Color   = origAtmo.Color,
            Decay   = origAtmo.Decay,
        }):Play()
    end
end
-- ────────────────────────────────────────────────────────────────────────────

-- ── Timer Toxic Event ────────────────────────────────────────────────────────
local toxicActif = false

-- Timer toxic (bas droite, même style que LuckHud : indicateur coloré + texte)
local toxicTimerFrame = Instance.new("Frame", gui)
toxicTimerFrame.Name                   = "ToxicTimer"
toxicTimerFrame.Size                   = UDim2.new(0, 150, 0, 44)
toxicTimerFrame.AnchorPoint            = Vector2.new(1, 1)
toxicTimerFrame.Position               = UDim2.new(1, -12, 1, -64)
toxicTimerFrame.BackgroundTransparency = 1
toxicTimerFrame.BorderSizePixel        = 0
toxicTimerFrame.Visible                = false

local toxicIndicator = Instance.new("Frame", toxicTimerFrame)
toxicIndicator.Size             = UDim2.new(0, 40, 0, 40)
toxicIndicator.Position         = UDim2.new(0, 0, 0.5, -20)
toxicIndicator.BackgroundColor3 = Color3.fromRGB(60, 200, 60)
toxicIndicator.BorderSizePixel  = 0
local _ticC = Instance.new("UICorner", toxicIndicator)
_ticC.CornerRadius = UDim.new(0, 8)

local toxicTimerLabel = Instance.new("TextLabel", toxicTimerFrame)
toxicTimerLabel.Size                   = UDim2.new(1, -48, 1, 0)
toxicTimerLabel.Position               = UDim2.new(0, 48, 0, 0)
toxicTimerLabel.BackgroundTransparency = 1
toxicTimerLabel.TextColor3             = Color3.fromRGB(255, 255, 255)
toxicTimerLabel.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
toxicTimerLabel.TextStrokeTransparency = 0.4
toxicTimerLabel.TextScaled             = false
toxicTimerLabel.TextSize               = 22
toxicTimerLabel.Font                   = Enum.Font.GothamBold
toxicTimerLabel.TextXAlignment         = Enum.TextXAlignment.Left
toxicTimerLabel.Text                   = ""

local toxicTimerThread = nil

local function formatTimer(secondes)
    local m = math.floor(secondes / 60)
    local s = secondes % 60
    return string.format("%02d:%02d", m, s)
end

local function stopperTimerClient()
    toxicActif = false
    if toxicTimerThread then
        task.cancel(toxicTimerThread)
        toxicTimerThread = nil
    end
    toxicTimerFrame.Visible = false
    toxicTimerLabel.Text    = ""
    restaurerLighting()
end

local function lancerTimerClient(endTime)
    toxicActif              = true
    toxicTimerFrame.Visible = true
    activerEffetsLighting()

    if toxicTimerThread then task.cancel(toxicTimerThread) end
    toxicTimerThread = task.spawn(function()
        while true do
            local restant = math.max(0, endTime - os.time())
            toxicTimerLabel.Text = formatTimer(restant)
            if restant <= 0 then
                stopperTimerClient()
                break
            end
            task.wait(1)
        end
    end)
end

-- Connexion état Toxic depuis le serveur
local ToxicEventState = ReplicatedStorage:WaitForChild("ToxicEventState", 15)
if ToxicEventState then
    ToxicEventState.OnClientEvent:Connect(function(actif, endTime)
        if actif then
            lancerTimerClient(endTime)
        else
            stopperTimerClient()
        end
    end)
end

-- ────────────────────────────────────────────────────────────────────────────

-- ── Effets ambiance Nebula Event ──────────────────────────────────────────────
local nebulaColorFX = Instance.new("ColorCorrectionEffect")
nebulaColorFX.Name        = "NebulaColorFX"
nebulaColorFX.TintColor   = Color3.fromRGB(230, 140, 230)
nebulaColorFX.Saturation  = 0.2
nebulaColorFX.Brightness  = 0
nebulaColorFX.Contrast    = 0.05
nebulaColorFX.Enabled     = false
nebulaColorFX.Parent      = Lighting

local function activerEffetsLightingNebula()
	nebulaColorFX.Enabled  = true
	Lighting.ClockTime     = 15
	TweenService:Create(Lighting, TWEEN_ATMO, {
		Ambient        = Color3.fromRGB(90,  30, 100),
		OutdoorAmbient = Color3.fromRGB(110, 40, 120),
		Brightness     = 1.2,
		FogColor       = Color3.fromRGB(200, 80, 220),
		FogStart       = 60,
		FogEnd         = 300,
	}):Play()
	if atmosphere then
		TweenService:Create(atmosphere, TWEEN_ATMO, {
			Density = 0.45,
			Haze    = 4,
			Glare   = 0,
			Color   = Color3.fromRGB(200, 80, 220),
			Decay   = Color3.fromRGB(100, 20, 120),
		}):Play()
	end
end

local function restaurerLightingNebula()
	Lighting.ClockTime = origLight.ClockTime
	local tw = TweenService:Create(Lighting, TWEEN_ATMO, {
		Ambient        = origLight.Ambient,
		OutdoorAmbient = origLight.OutdoorAmbient,
		Brightness     = origLight.Brightness,
		FogColor       = origLight.FogColor,
		FogStart       = origLight.FogStart,
		FogEnd         = origLight.FogEnd,
	})
	tw:Play()
	tw.Completed:Once(function() nebulaColorFX.Enabled = false end)
	if atmosphere and origAtmo then
		TweenService:Create(atmosphere, TWEEN_ATMO, {
			Density = origAtmo.Density,
			Haze    = origAtmo.Haze,
			Glare   = origAtmo.Glare,
			Color   = origAtmo.Color,
			Decay   = origAtmo.Decay,
		}):Play()
	end
end
-- ────────────────────────────────────────────────────────────────────────────

-- ── Physiques Nebula (saut + anti-gravité, hors tours) ───────────────────────
local NEBULA_JUMP_ADD  = 15
local NEBULA_ANTI_GRAV = 0.25
local origJumpNebula   = nil
local nebulaActif      = false

local function appliquerPhysiquesNebula()
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp then return end
	local old = hrp:FindFirstChild("NebulaGravityBF")
	if old then old:Destroy() end
	origJumpNebula = hum.JumpPower
	hum.JumpPower  = origJumpNebula + NEBULA_JUMP_ADD
	local bf = Instance.new("BodyForce")
	bf.Name   = "NebulaGravityBF"
	bf.Force  = Vector3.new(0, hrp:GetMass() * workspace.Gravity * NEBULA_ANTI_GRAV, 0)
	bf.Parent = hrp
end

local function retirerPhysiquesNebula()
	local char = player.Character
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hum and origJumpNebula then hum.JumpPower = origJumpNebula end
		if hrp then
			local bf = hrp:FindFirstChild("NebulaGravityBF")
			if bf then bf:Destroy() end
		end
	end
	origJumpNebula = nil
end

player.CharacterAdded:Connect(function()
	task.wait(0.1)
	if nebulaActif and not player:GetAttribute("InTower") then
		appliquerPhysiquesNebula()
	end
end)
-- ────────────────────────────────────────────────────────────────────────────

-- ── Timer Nebula Event ────────────────────────────────────────────────────────

-- Timer nebula (bas droite, même style que LuckHud : indicateur coloré + texte)
local nebulaTimerFrame = Instance.new("Frame", gui)
nebulaTimerFrame.Name                   = "NebulaTimer"
nebulaTimerFrame.Size                   = UDim2.new(0, 150, 0, 44)
nebulaTimerFrame.AnchorPoint            = Vector2.new(1, 1)
nebulaTimerFrame.Position               = UDim2.new(1, -12, 1, -116)
nebulaTimerFrame.BackgroundTransparency = 1
nebulaTimerFrame.BorderSizePixel        = 0
nebulaTimerFrame.Visible                = false

local nebulaIndicator = Instance.new("Frame", nebulaTimerFrame)
nebulaIndicator.Size             = UDim2.new(0, 40, 0, 40)
nebulaIndicator.Position         = UDim2.new(0, 0, 0.5, -20)
nebulaIndicator.BackgroundColor3 = Color3.fromRGB(180, 60, 220)
nebulaIndicator.BorderSizePixel  = 0
local _nebC = Instance.new("UICorner", nebulaIndicator)
_nebC.CornerRadius = UDim.new(0, 8)

local nebulaTimerLabel = Instance.new("TextLabel", nebulaTimerFrame)
nebulaTimerLabel.Size                   = UDim2.new(1, -48, 1, 0)
nebulaTimerLabel.Position               = UDim2.new(0, 48, 0, 0)
nebulaTimerLabel.BackgroundTransparency = 1
nebulaTimerLabel.TextColor3             = Color3.fromRGB(255, 100, 255)
nebulaTimerLabel.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
nebulaTimerLabel.TextStrokeTransparency = 0.4
nebulaTimerLabel.TextScaled             = false
nebulaTimerLabel.TextSize               = 22
nebulaTimerLabel.Font                   = Enum.Font.GothamBold
nebulaTimerLabel.TextXAlignment         = Enum.TextXAlignment.Left
nebulaTimerLabel.Text                   = ""

local nebulaTimerThread = nil

local function stopperTimerClientNebula()
	nebulaActif = false
	if nebulaTimerThread then
		task.cancel(nebulaTimerThread)
		nebulaTimerThread = nil
	end
	nebulaTimerFrame.Visible = false
	nebulaTimerLabel.Text    = ""
	restaurerLightingNebula()
	retirerPhysiquesNebula()
end

local function lancerTimerClientNebula(endTime)
	nebulaActif              = true
	nebulaTimerFrame.Visible = true
	activerEffetsLightingNebula()
	if not player:GetAttribute("InTower") then
		appliquerPhysiquesNebula()
	end
	if nebulaTimerThread then task.cancel(nebulaTimerThread) end
	nebulaTimerThread = task.spawn(function()
		while true do
			local restant = math.max(0, endTime - os.time())
			nebulaTimerLabel.Text = formatTimer(restant)
			if restant <= 0 then
				stopperTimerClientNebula()
				break
			end
			task.wait(1)
		end
	end)
end

local NebulaEventState = ReplicatedStorage:WaitForChild("NebulaEventState", 15)
if NebulaEventState then
	NebulaEventState.OnClientEvent:Connect(function(actif, endTime)
		if actif then
			lancerTimerClientNebula(endTime)
		else
			stopperTimerClientNebula()
		end
	end)
end

-- ────────────────────────────────────────────────────────────────────────────

-- Notification VIP (bannière rouge haut écran)
local vipNotifFrame = Instance.new("Frame", gui)
vipNotifFrame.Name                  = "VIPNotif"
vipNotifFrame.Size                  = UDim2.new(0, 340, 0, 48)
vipNotifFrame.Position              = UDim2.new(0.5, -170, 0, 8)
vipNotifFrame.BackgroundColor3      = Color3.fromRGB(180, 20, 20)
vipNotifFrame.BackgroundTransparency = 0.1
vipNotifFrame.BorderSizePixel       = 0
vipNotifFrame.Visible               = false
local vipNotifCorner = Instance.new("UICorner", vipNotifFrame)
vipNotifCorner.CornerRadius = UDim.new(0, 6)
local vipNotifLabel = Instance.new("TextLabel", vipNotifFrame)
vipNotifLabel.Size                   = UDim2.new(1, 0, 1, 0)
vipNotifLabel.BackgroundTransparency = 1
vipNotifLabel.TextColor3             = Color3.fromRGB(255, 255, 255)
vipNotifLabel.TextScaled             = false
vipNotifLabel.TextSize               = 16
vipNotifLabel.Font                   = Enum.Font.GothamBold
vipNotifLabel.Text                   = "You need to buy VIP"

local vipNotifThread = nil
local VIPNotificationRE = ReplicatedStorage:WaitForChild("VIPNotification", 30)
if VIPNotificationRE then
    VIPNotificationRE.OnClientEvent:Connect(function()
        if vipNotifThread then task.cancel(vipNotifThread) end
        vipNotifFrame.Visible = true
        vipNotifThread = task.delay(3, function()
            vipNotifFrame.Visible = false
            vipNotifThread = nil
        end)
    end)
end

-- Connexions RemoteEvents tour
local EscapeTowerRE  = ReplicatedStorage:WaitForChild("EscapeTower",  15)
local TowerEnteredRE = ReplicatedStorage:WaitForChild("TowerEntered", 15)
local TowerExitedRE  = ReplicatedStorage:WaitForChild("TowerExited",  15)

local countdownActive = false

local function resetEscape()
    countdownActive        = false
    countdownFrame.Visible = false
    escapeFrame.Visible    = false
end

if TowerEnteredRE then
    TowerEnteredRE.OnClientEvent:Connect(function()
        countdownActive        = false
        countdownFrame.Visible = false
        escapeFrame.Visible    = true
    end)
end

if TowerExitedRE then
    TowerExitedRE.OnClientEvent:Connect(function()
        resetEscape()
    end)
end

if player:GetAttribute("InTower") then
    escapeFrame.Visible = true
end
player:GetAttributeChangedSignal("InTower"):Connect(function()
    if player:GetAttribute("InTower") then
        countdownActive        = false
        countdownFrame.Visible = false
        escapeFrame.Visible    = true
        retirerPhysiquesNebula()
    else
        resetEscape()
        if nebulaActif then appliquerPhysiquesNebula() end
    end
end)

if EscapeTowerRE then
    escapeButton.Activated:Connect(function()
        if countdownActive then return end
        countdownActive        = true
        escapeFrame.Visible    = false
        countdownFrame.Visible = true

        task.spawn(function()
            for t = 3, 1, -1 do
                if not countdownActive then return end
                countdownLabel.Text = tostring(t)
                task.wait(1)
            end
            if not countdownActive then return end
            countdownFrame.Visible = false
            countdownActive        = false
            EscapeTowerRE:FireServer()
        end)
    end)
end
