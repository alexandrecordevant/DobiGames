-- StarterPlayerScripts/EventVoteClient.client.lua
-- Menu de vote Toxic vs Nebula — style Tower (coins carrés, deux noirs, orange)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local Workspace         = game:GetService("Workspace")

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

-- ── Palette style Tower ───────────────────────────────────────────────────────
local C = {
	BgDark     = Color3.fromRGB(8,   8,   8),    -- fond principal
	BgMid      = Color3.fromRGB(22,  22,  22),   -- fond cartes
	Bordure    = Color3.fromRGB(55,  55,  55),
	Accent     = Color3.fromRGB(220, 110, 15),   -- orange Tower (titre)
	TextPrim   = Color3.fromRGB(220, 220, 220),
	TextSec    = Color3.fromRGB(130, 130, 130),
	Fermer     = Color3.fromRGB(45,  45,  45),
	VoteToxic  = Color3.fromRGB(0,   230, 80),   -- vert fluo
	VoteNebula = Color3.fromRGB(255, 60,  200),  -- rose fluo
	-- barre : même couleur que les boutons (cohérence)
	BarToxic   = Color3.fromRGB(0,   230, 80),
	BarNebula  = Color3.fromRGB(255, 60,  200),  -- rose (pas violet)
}
local CORNER = UDim.new(0, 3)   -- très légèrement arrondi, style Tower

-- IDs des images (remplace par tes rbxassetid dans Studio)
local IMAGE_TOXIC  = "rbxassetid://0"
local IMAGE_NEBULA = "rbxassetid://0"

-- ── Utilitaires ───────────────────────────────────────────────────────────────
local function addCorner(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 3)
	c.Parent = parent
end
local function addStroke(parent)
	local s = Instance.new("UIStroke")
	s.Color = C.Bordure; s.Thickness = 1; s.Parent = parent
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


-- Panel principal (440 × 330)
local panel = Instance.new("Frame")
panel.Size                   = UDim2.new(0, 440, 0, 330)
panel.Position               = UDim2.new(0.5, -220, 0.5, -165)
panel.BackgroundColor3       = C.BgDark
panel.BorderSizePixel        = 0
panel.ZIndex                 = 2
panel.Parent                 = screenGui
addCorner(panel, 3); addStroke(panel)

-- Guard (empêche les clics de traverser au backdrop)
local guard = Instance.new("TextButton")
guard.Size = UDim2.fromScale(1, 1); guard.BackgroundTransparency = 1
guard.BorderSizePixel = 0; guard.Text = ""; guard.ZIndex = 2; guard.Parent = panel

-- Titre orange
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
closeBtn.Size                   = UDim2.new(0, 32, 0, 32)
closeBtn.Position               = UDim2.new(1, -38, 0, 4)
closeBtn.BackgroundColor3       = C.Fermer
closeBtn.BorderSizePixel        = 0
closeBtn.TextColor3             = C.TextPrim
closeBtn.TextScaled             = false
closeBtn.TextSize               = 14
closeBtn.Font                   = Enum.Font.GothamBold
closeBtn.Text                   = "X"
closeBtn.ZIndex                 = 4
closeBtn.Parent                 = panel
addCorner(closeBtn, 2)

-- Séparateur
local sep = Instance.new("Frame")
sep.Size                   = UDim2.new(1, -16, 0, 1)
sep.Position               = UDim2.new(0, 8, 0, 44)
sep.BackgroundColor3       = C.Bordure
sep.BorderSizePixel        = 0
sep.ZIndex                 = 3
sep.Parent                 = panel

-- Timer du cycle (sous le titre)
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

-- ── Camp (gauche ou droite) ───────────────────────────────────────────────────
local function creerCamp(xOffset, imageId, btnColor)
	local frame = Instance.new("Frame")
	frame.Size                   = UDim2.new(0, 196, 0, 208)
	frame.Position               = UDim2.new(0, xOffset, 0, 76)
	frame.BackgroundColor3       = C.BgMid
	frame.BorderSizePixel        = 0
	frame.ZIndex                 = 3
	frame.Parent                 = panel
	addCorner(frame, 3); addStroke(frame)

	local thumb = Instance.new("ImageLabel")
	thumb.Size                   = UDim2.new(1, -10, 0, 135)
	thumb.Position               = UDim2.new(0, 5, 0, 5)
	thumb.BackgroundColor3       = Color3.fromRGB(14, 14, 14)
	thumb.BorderSizePixel        = 0
	thumb.Image                  = imageId
	thumb.ScaleType              = Enum.ScaleType.Fit
	thumb.ZIndex                 = 4
	thumb.Parent                 = frame
	addCorner(thumb, 2)

	local btn = Instance.new("TextButton")
	btn.Size                   = UDim2.new(1, -10, 0, 48)
	btn.Position               = UDim2.new(0, 5, 0, 150)
	btn.BackgroundColor3       = btnColor
	btn.BackgroundTransparency = 0.05
	btn.BorderSizePixel        = 0
	btn.TextColor3             = Color3.fromRGB(8, 8, 8)
	btn.TextScaled             = false
	btn.TextSize               = 17
	btn.Font                   = Enum.Font.GothamBold
	btn.ZIndex                 = 4
	btn.Parent                 = frame
	addCorner(btn, 3)

	return btn
end

local voteToxicBtn  = creerCamp(12,  IMAGE_TOXIC,  C.VoteToxic)
local voteNebulaBtn = creerCamp(232, IMAGE_NEBULA, C.VoteNebula)

-- ── Barre de progression ──────────────────────────────────────────────────────
local barBg = Instance.new("Frame")
barBg.Size                   = UDim2.new(1, -20, 0, 20)
barBg.Position               = UDim2.new(0, 10, 0, 294)
barBg.BackgroundColor3       = C.BarNebula   -- rose (côté Nebula = partie droite)
barBg.BorderSizePixel        = 0
barBg.ZIndex                 = 3
barBg.Parent                 = panel
addCorner(barBg, 3)

local barToxic = Instance.new("Frame")
barToxic.Size                   = UDim2.new(0.5, 0, 1, 0)
barToxic.BackgroundColor3       = C.BarToxic  -- vert (côté Toxic = partie gauche)
barToxic.BorderSizePixel        = 0
barToxic.ZIndex                 = 4
barToxic.Parent                 = barBg
addCorner(barToxic, 3)

-- ── État ──────────────────────────────────────────────────────────────────────
local hasVoted        = false
local curToxic        = 0
local curNebula       = 0
local currentCycleEnd = os.time() + 30  -- valeur par défaut visible immédiatement

local function updateBar(tv, nv)
	local total = tv + nv
	local ratio = total > 0 and (tv / total) or 0.5
	TweenService:Create(barToxic, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {
		Size = UDim2.new(ratio, 0, 1, 0),
	}):Play()
end

-- ── Ouverture / fermeture ─────────────────────────────────────────────────────
local function openMenu()
	titleLabel.Text = tr("title")
	voteToxicBtn.Text  = tr("vote")
	voteNebulaBtn.Text = tr("vote")
	voteToxicBtn.BackgroundTransparency  = hasVoted and 0.5 or 0.05
	voteNebulaBtn.BackgroundTransparency = hasVoted and 0.5 or 0.05
	updateBar(curToxic, curNebula)
	screenGui.Enabled = true
end

local function closeMenu()
	screenGui.Enabled = false
end

closeBtn.Activated:Connect(closeMenu)

-- ── Vote ──────────────────────────────────────────────────────────────────────
local function soumettre(choix)
	if hasVoted then return end
	hasVoted = true
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

-- ── Mise à jour barre ─────────────────────────────────────────────────────────
EventVoteUpdate.OnClientEvent:Connect(function(tv, nv, cycleEnd)
	curToxic        = tv or 0
	curNebula       = nv or 0
	currentCycleEnd = cycleEnd or currentCycleEnd
	if screenGui.Enabled then updateBar(tv, nv) end
end)

-- ── Reset à chaque nouveau cycle ─────────────────────────────────────────────
if EventVoteResult then
	EventVoteResult.OnClientEvent:Connect(function(_winner)
		hasVoted  = false
		curToxic  = 0
		curNebula = 0
		voteToxicBtn.BackgroundTransparency  = 0.05
		voteNebulaBtn.BackgroundTransparency = 0.05
		if screenGui.Enabled then updateBar(0, 0) end
	end)
end

-- ── Ouverture depuis le serveur ───────────────────────────────────────────────
OpenVoteMenu.OnClientEvent:Connect(function(tv, nv, cycleEnd)
	curToxic        = tv       or 0
	curNebula       = nv       or 0
	currentCycleEnd = cycleEnd or currentCycleEnd
	openMenu()
end)

-- ── Timer dans le menu (mise à jour chaque seconde) ───────────────────────────
task.spawn(function()
	while true do
		task.wait(1)
		if currentCycleEnd > 0 then
			local remaining = currentCycleEnd - os.time()
			timerLabel.Text = tr("closes") .. "  " .. formatTimer(remaining)
		end
	end
end)

