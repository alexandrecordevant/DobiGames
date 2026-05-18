-- StarterPlayerScripts/EventVoteClient.client.lua
-- Menu de vote Toxic vs Nebula — duel visuel avec couleurs de camp et animations

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ── Traductions ───────────────────────────────────────────────────────────────
local LANG = {
	en = { title = "Choose your event", vote = "Vote", closes = "Vote closes in" },
	fr = { title = "Choisissez votre événement", vote = "Voter", closes = "Vote dans" },
	es = { title = "Elige tu evento", vote = "Votar", closes = "Cierra en" },
	pt = { title = "Escolha seu evento", vote = "Votar", closes = "Fecha em" },
	de = { title = "Wähle dein Event", vote = "Abstimmen", closes = "Endet in" },
	it = { title = "Scegli il tuo evento", vote = "Vota", closes = "Chiude in" },
	ko = { title = "이벤트를 선택하세요", vote = "투표", closes = "마감" },
	ja = { title = "イベントを選んでください", vote = "投票", closes = "終了まで" },
	zh = { title = "选择你的活动", vote = "投票", closes = "截止" },
}
local function tr(key)
	local lang = (player.LocaleId or "en"):sub(1, 2):lower()
	return (LANG[lang] or LANG["en"])[key] or LANG["en"][key]
end

-- ── Palette ───────────────────────────────────────────────────────────────────
local C = {
	BgDark      = Color3.fromRGB(8,   8,   8),
	Bordure     = Color3.fromRGB(55,  55,  55),
	Accent      = Color3.fromRGB(220, 110, 15),
	TextPrim    = Color3.fromRGB(220, 220, 220),
	TextSec     = Color3.fromRGB(130, 130, 130),
	Fermer      = Color3.fromRGB(45,  45,  45),
	-- Toxic — vert de la palette (même famille que Jump/Base)
	ToxicBgTop  = Color3.fromRGB(75,  225, 125),  -- highlight
	ToxicBgBot  = Color3.fromRGB(42,  190, 88),   -- base
	ToxicStroke = Color3.fromRGB(115, 255, 165),
	ToxicBtn    = Color3.fromRGB(55,  205, 100),
	ToxicBtnStr = Color3.fromRGB(115, 255, 165),
	BarToxic    = Color3.fromRGB(75,  225, 125),
	-- Nebula — violet de la palette (même famille que GravityCoil/2h)
	NebulaBgTop = Color3.fromRGB(175, 110, 255),  -- highlight
	NebulaBgBot = Color3.fromRGB(135, 68,  220),  -- base
	NebulaStroke= Color3.fromRGB(215, 160, 255),
	NebulaBtn   = Color3.fromRGB(155, 85,  240),
	NebulaBtnStr= Color3.fromRGB(215, 160, 255),
	BarNebula   = Color3.fromRGB(175, 110, 255),
}

-- IDs des images (remplace par tes rbxassetid dans Studio)
local IMAGE_TOXIC  = "rbxassetid://0"
local IMAGE_NEBULA = "rbxassetid://0"

local PANEL_W, PANEL_H = 440, 330

-- TweenInfo réutilisables
local TI_BACK35 = TweenInfo.new(0.35, Enum.EasingStyle.Back,   Enum.EasingDirection.Out)
local TI_QUAD15 = TweenInfo.new(0.15, Enum.EasingStyle.Quad,   Enum.EasingDirection.In)
local TI_PULSE  = TweenInfo.new(1.2,  Enum.EasingStyle.Sine,   Enum.EasingDirection.InOut, -1, true)
local TI_ROT    = TweenInfo.new(2.5,  Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1)

-- ── Utilitaires ───────────────────────────────────────────────────────────────
local function addCorner(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 3)
	c.Parent = parent
end
local function addStrokeColor(parent, color, thick)
	local s = Instance.new("UIStroke")
	s.Color = color; s.Thickness = thick or 1; s.Parent = parent
	return s
end
local function addGradient(parent, keypoints)
	local g = Instance.new("UIGradient")
	g.Color  = ColorSequence.new(keypoints)
	g.Parent = parent
	return g
end
local function formatTimer(secs)
	secs = math.max(0, math.floor(secs))
	return string.format("%02d:%02d", math.floor(secs / 60), secs % 60)
end

-- ── RemoteEvents ──────────────────────────────────────────────────────────────
local EventVoteSubmit = ReplicatedStorage:WaitForChild("EventVoteSubmit", 30)
local EventVoteUpdate = ReplicatedStorage:WaitForChild("EventVoteUpdate", 30)
local EventVoteResult = ReplicatedStorage:WaitForChild("EventVoteResult", 30)
local OpenVoteMenu    = ReplicatedStorage:WaitForChild("OpenVoteMenu",    30)
if not EventVoteSubmit or not EventVoteUpdate or not OpenVoteMenu then
	warn("[EventVoteClient] RemoteEvents introuvables")
	return
end

-- ── ScreenGui ─────────────────────────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "EventVoteGui"
screenGui.ResetOnSpawn   = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Enabled        = false
screenGui.Parent         = playerGui

-- Panel principal
local panel = Instance.new("Frame")
panel.Size             = UDim2.new(0, PANEL_W, 0, PANEL_H)
panel.AnchorPoint      = Vector2.new(0.5, 0.5)
panel.Position         = UDim2.new(0.5, 0, 0.5, 0)
panel.BackgroundColor3 = C.BgDark
panel.BorderSizePixel  = 0
panel.ZIndex           = 2
panel.Parent           = screenGui
addCorner(panel, 5)
addStrokeColor(panel, C.Bordure, 1)

-- Gradient fond panel (aura vert-gauche → noir-centre → violet-droite)
addGradient(panel, {
	ColorSequenceKeypoint.new(0,   Color3.fromRGB(12, 28, 15)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(8,  8,  8)),
	ColorSequenceKeypoint.new(1,   Color3.fromRGB(22, 8,  42)),
})

-- Guard
local guard = Instance.new("TextButton")
guard.Size = UDim2.fromScale(1, 1); guard.BackgroundTransparency = 1
guard.BorderSizePixel = 0; guard.Text = ""; guard.ZIndex = 2; guard.Parent = panel

-- Titre
local titleLabel = Instance.new("TextLabel")
titleLabel.Size                   = UDim2.new(1, -50, 0, 38)
titleLabel.Position               = UDim2.new(0, 10, 0, 4)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3             = C.Accent
titleLabel.TextScaled             = false
titleLabel.TextSize               = 17
titleLabel.Font                   = Enum.Font.GothamBold
titleLabel.TextXAlignment         = Enum.TextXAlignment.Center
titleLabel.ZIndex                 = 3
titleLabel.Parent                 = panel

-- Bouton fermer
local closeBtn = Instance.new("TextButton")
closeBtn.Size             = UDim2.new(0, 32, 0, 32)
closeBtn.Position         = UDim2.new(1, -38, 0, 4)
closeBtn.BackgroundColor3 = C.Fermer
closeBtn.BorderSizePixel  = 0
closeBtn.TextColor3       = C.TextPrim
closeBtn.TextScaled       = false
closeBtn.TextSize         = 14
closeBtn.Font             = Enum.Font.GothamBold
closeBtn.Text             = "X"
closeBtn.ZIndex           = 4
closeBtn.Parent           = panel
addCorner(closeBtn, 2)

-- Séparateur titre/contenu
local sep = Instance.new("Frame")
sep.Size             = UDim2.new(1, -16, 0, 1)
sep.Position         = UDim2.new(0, 8, 0, 44)
sep.BackgroundColor3 = C.Bordure
sep.BorderSizePixel  = 0
sep.ZIndex           = 3
sep.Parent           = panel

-- Timer (sous le titre)
local timerLabel = Instance.new("TextLabel")
timerLabel.Size                   = UDim2.new(1, 0, 0, 26)
timerLabel.Position               = UDim2.new(0, 0, 0, 47)
timerLabel.BackgroundTransparency = 1
timerLabel.TextColor3             = C.TextSec
timerLabel.TextScaled             = false
timerLabel.TextSize               = 13
timerLabel.Font                   = Enum.Font.Gotham
timerLabel.TextXAlignment         = Enum.TextXAlignment.Center
timerLabel.ZIndex                 = 3
timerLabel.Parent                 = panel

-- ── Camps ─────────────────────────────────────────────────────────────────────
-- Retourne : btn (bouton VOTER)
local function creerCamp(xOffset, imageId, bgTop, bgBot, strokeColor, btnColor, btnStrokeColor, btnTextDark)
	local frame = Instance.new("Frame")
	frame.Size             = UDim2.new(0, 196, 0, 208)
	frame.Position         = UDim2.new(0, xOffset, 0, 76)
	frame.BackgroundColor3 = bgBot
	frame.BorderSizePixel  = 0
	frame.ZIndex           = 3
	frame.Parent           = panel
	addCorner(frame, 5)
	addStrokeColor(frame, strokeColor, 2)
	local g = addGradient(frame, {
		ColorSequenceKeypoint.new(0, bgTop),
		ColorSequenceKeypoint.new(1, bgBot),
	})
	g.Rotation = 90

	local thumb = Instance.new("ImageLabel")
	thumb.Size             = UDim2.new(1, -10, 0, 135)
	thumb.Position         = UDim2.new(0, 5, 0, 5)
	thumb.BackgroundColor3 = bgBot
	thumb.BorderSizePixel  = 0
	thumb.Image            = imageId
	thumb.ScaleType        = Enum.ScaleType.Fit
	thumb.ZIndex           = 4
	thumb.Parent           = frame
	addCorner(thumb, 3)

	local btn = Instance.new("TextButton")
	btn.Size                   = UDim2.new(1, -10, 0, 48)
	btn.Position               = UDim2.new(0, 5, 0, 150)
	btn.BackgroundColor3       = btnColor
	btn.BackgroundTransparency = 0.05
	btn.BorderSizePixel        = 0
	btn.TextColor3             = btnTextDark and Color3.fromRGB(8, 8, 8) or Color3.fromRGB(255, 255, 255)
	btn.TextScaled             = false
	btn.TextSize               = 17
	btn.Font                   = Enum.Font.GothamBold
	btn.ZIndex                 = 4
	btn.Parent                 = frame
	addCorner(btn, 5)
	addStrokeColor(btn, btnStrokeColor, 2)

	return btn
end

local voteToxicBtn  = creerCamp(12,  IMAGE_TOXIC,
	C.ToxicBgTop, C.ToxicBgBot, C.ToxicStroke, C.ToxicBtn, C.ToxicBtnStr, true)
local voteNebulaBtn = creerCamp(232, IMAGE_NEBULA,
	C.NebulaBgTop, C.NebulaBgBot, C.NebulaStroke, C.NebulaBtn, C.NebulaBtnStr, false)

-- ── Séparateur central animé (flammes) ───────────────────────────────────────
-- Positionné dans le gap de 24px entre les deux camps (208→232)
local sepCentral = Instance.new("Frame")
sepCentral.Size             = UDim2.new(0, 20, 0, 208)
sepCentral.Position         = UDim2.new(0, 210, 0, 76)
sepCentral.BackgroundColor3 = Color3.fromRGB(0, 200, 70)
sepCentral.BorderSizePixel  = 0
sepCentral.ZIndex           = 4
sepCentral.Parent           = panel

local sepGrad = addGradient(sepCentral, {
	ColorSequenceKeypoint.new(0,   Color3.fromRGB(0,   220, 70)),
	ColorSequenceKeypoint.new(1,   Color3.fromRGB(120, 30,  200)),
})
TweenService:Create(sepGrad, TI_ROT, { Rotation = 360 }):Play()

-- ── Barre de progression ──────────────────────────────────────────────────────
local barBg = Instance.new("Frame")
barBg.Size             = UDim2.new(1, -20, 0, 28)
barBg.Position         = UDim2.new(0, 10, 0, 292)
barBg.BackgroundColor3 = C.BarNebula
barBg.BorderSizePixel  = 0
barBg.ZIndex           = 3
barBg.Parent           = panel
addCorner(barBg, 6)
addStrokeColor(barBg, C.Bordure, 1)

local barToxic = Instance.new("Frame")
barToxic.Size             = UDim2.new(0.5, 0, 1, 0)
barToxic.BackgroundColor3 = C.BarToxic
barToxic.BorderSizePixel  = 0
barToxic.ZIndex           = 4
barToxic.Parent           = barBg
addCorner(barToxic, 6)

-- ── État ──────────────────────────────────────────────────────────────────────
local hasVoted        = false
local curToxic        = 0
local curNebula       = 0
local currentCycleEnd = os.time() + 30

local pulseToxicTween  = nil
local pulseNebulaTween = nil

local function startPulses()
	if pulseToxicTween  then pulseToxicTween:Cancel()  end
	if pulseNebulaTween then pulseNebulaTween:Cancel() end
	voteToxicBtn.BackgroundTransparency  = 0.05
	voteNebulaBtn.BackgroundTransparency = 0.05
	pulseToxicTween  = TweenService:Create(voteToxicBtn,  TI_PULSE, { BackgroundTransparency = 0.28 })
	pulseNebulaTween = TweenService:Create(voteNebulaBtn, TI_PULSE, { BackgroundTransparency = 0.28 })
	pulseToxicTween:Play()
	pulseNebulaTween:Play()
end

local function stopPulses()
	if pulseToxicTween  then pulseToxicTween:Cancel()  end
	if pulseNebulaTween then pulseNebulaTween:Cancel() end
	pulseToxicTween  = nil
	pulseNebulaTween = nil
end

local function updateBar(tv, nv)
	local total = tv + nv
	local ratio = total > 0 and (tv / total) or 0.5
	TweenService:Create(barToxic, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {
		Size = UDim2.new(ratio, 0, 1, 0),
	}):Play()
end

-- ── Ouverture / fermeture ─────────────────────────────────────────────────────
local function openMenu()
	local tpGui    = playerGui:FindFirstChild("TeleportMenuGui")
	if tpGui    then tpGui.Enabled    = false end
	local monetGui = playerGui:FindFirstChild("ShopMonetGui")
	if monetGui then monetGui.Enabled = false end
	local shopGui  = playerGui:FindFirstChild("ShopGui")
	if shopGui  then shopGui.Enabled  = false end
	local fuseGui  = playerGui:FindFirstChild("FuseSystemUI")
	if fuseGui  then fuseGui.Enabled  = false end

	titleLabel.Text    = tr("title")
	voteToxicBtn.Text  = tr("vote")
	voteNebulaBtn.Text = tr("vote")
	updateBar(curToxic, curNebula)

	panel.Size        = UDim2.new(0, 0, 0, 0)
	screenGui.Enabled = true
	TweenService:Create(panel, TI_BACK35, { Size = UDim2.new(0, PANEL_W, 0, PANEL_H) }):Play()

	if not hasVoted then startPulses() end
end

local function closeMenu()
	stopPulses()
	TweenService:Create(panel, TI_QUAD15, { Size = UDim2.new(0, 0, 0, 0) }):Play()
	task.delay(0.16, function()
		screenGui.Enabled = false
		panel.Size        = UDim2.new(0, PANEL_W, 0, PANEL_H)
	end)
end

closeBtn.Activated:Connect(closeMenu)

-- ── Vote ──────────────────────────────────────────────────────────────────────
local function soumettre(choix)
	if hasVoted then return end
	hasVoted = true
	stopPulses()
	voteToxicBtn.BackgroundTransparency  = 0.5
	voteNebulaBtn.BackgroundTransparency = 0.5
	EventVoteSubmit:FireServer(choix)
	local btn  = choix == "toxic" and voteToxicBtn or voteNebulaBtn
	local orig = btn.BackgroundColor3
	btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	TweenService:Create(btn, TweenInfo.new(0.3), { BackgroundColor3 = orig }):Play()
end

voteToxicBtn.Activated:Connect(function()  soumettre("toxic")  end)
voteNebulaBtn.Activated:Connect(function() soumettre("nebula") end)

-- ── Mises à jour depuis le serveur ────────────────────────────────────────────
EventVoteUpdate.OnClientEvent:Connect(function(tv, nv, cycleEnd)
	curToxic        = tv or 0
	curNebula       = nv or 0
	currentCycleEnd = cycleEnd or currentCycleEnd
	if screenGui.Enabled then updateBar(tv, nv) end
end)

if EventVoteResult then
	EventVoteResult.OnClientEvent:Connect(function(_winner)
		hasVoted  = false
		curToxic  = 0
		curNebula = 0
		voteToxicBtn.BackgroundTransparency  = 0.05
		voteNebulaBtn.BackgroundTransparency = 0.05
		if screenGui.Enabled then
			updateBar(0, 0)
			startPulses()
		end
	end)
end

OpenVoteMenu.OnClientEvent:Connect(function(tv, nv, cycleEnd)
	curToxic        = tv       or 0
	curNebula       = nv       or 0
	currentCycleEnd = cycleEnd or currentCycleEnd
	openMenu()
end)

-- ── Timer ─────────────────────────────────────────────────────────────────────
task.spawn(function()
	while true do
		task.wait(1)
		if currentCycleEnd > 0 then
			timerLabel.Text = tr("closes") .. "  " .. formatTimer(currentCycleEnd - os.time())
		end
	end
end)
