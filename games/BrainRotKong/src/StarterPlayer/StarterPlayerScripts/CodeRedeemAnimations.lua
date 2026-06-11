-- StarterPlayerScripts/CodeRedeemAnimations.lua
-- Animations feedback succès / erreur pour la modale Promo Codes

local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")
local Debris            = game:GetService("Debris")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.SharedLib.Logger)

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local CodeRedeemAnimations = {}

-- ============================================================
-- TweenInfo constants
-- ============================================================
local TI_FLASH_IN      = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TI_FLASH_OUT     = TweenInfo.new(0.5,  Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local TI_ERR_FLASH_IN  = TweenInfo.new(0.1,  Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TI_ERR_FLASH_OUT = TweenInfo.new(0.4,  Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local TI_POPUP_IN      = TweenInfo.new(0.3,  Enum.EasingStyle.Back,  Enum.EasingDirection.Out)
local TI_POPUP_SQUISH  = TweenInfo.new(0.15, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out)
local TI_POPUP_FADE    = TweenInfo.new(0.5,  Enum.EasingStyle.Quad,  Enum.EasingDirection.In)
local TI_SHAKE         = TweenInfo.new(0.05, Enum.EasingStyle.Linear)

-- TODO: tester en Studio et remplacer les asset ids si besoin
-- Chime positif de validation
local SOUND_SUCCES = "rbxassetid://9046908152"
-- TODO: remplacer par un son buzz/refus depuis la library Roblox (ex: rechercher "error buzz ui")
local SOUND_ERREUR = "rbxassetid://9046908152"

-- Incrémenté à chaque nouvelle anim pour invalider les callbacks des anims précédentes
local activeAnimId = 0

-- ============================================================
-- Utilitaires internes
-- ============================================================

local function annulerAnimPrecedente()
	activeAnimId = activeAnimId + 1
	for _, child in ipairs(playerGui:GetChildren()) do
		if child.Name == "CodeAnimGui" then
			child:Destroy()
		end
	end
end

local function creerScreenGuiAnim()
	local sg = Instance.new("ScreenGui")
	sg.Name           = "CodeAnimGui"
	sg.ResetOnSpawn   = false
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sg.DisplayOrder   = 1000
	sg.IgnoreGuiInset = true
	sg.Parent         = playerGui
	return sg
end

local function jouerSon(assetId)
	local sound = Instance.new("Sound")
	sound.SoundId = assetId
	sound.Volume  = 0.8
	sound.Parent  = workspace
	sound:Play()
	Debris:AddItem(sound, 5)
end

local function verifierReducedMotion()
	return player:GetAttribute("ReducedMotion") == true
end

-- ============================================================
-- Particules succès (Part temporaire dans workspace)
-- ============================================================

local function spawnParticules()
	local character = player.Character
	if not character then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local part = Instance.new("Part")
	part.Anchored     = true
	part.CanCollide   = false
	part.Transparency = 1
	part.Size         = Vector3.new(0.1, 0.1, 0.1)
	part.CFrame       = rootPart.CFrame + Vector3.new(0, 2, 0)
	part.Parent       = workspace

	local sparkles = Instance.new("Sparkles", part)
	sparkles.Color       = ColorSequence.new(Color3.fromRGB(255, 215, 80))
	sparkles.SparkleSize = 2

	local confetti = Instance.new("ParticleEmitter", part)
	confetti.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0,   Color3.fromRGB(255, 215, 80)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(180, 80, 255)),
		ColorSequenceKeypoint.new(1,   Color3.fromRGB(80, 200, 255)),
	})
	confetti.LightEmission = 0.8
	confetti.Size          = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 0),
	})
	confetti.Speed       = NumberRange.new(8, 16)
	confetti.Rate        = 60
	confetti.Lifetime    = NumberRange.new(1, 2)
	confetti.SpreadAngle = Vector2.new(180, 180)
	confetti.RotSpeed    = NumberRange.new(-360, 360)
	confetti.Rotation    = NumberRange.new(0, 360)

	Debris:AddItem(part, 3)
end

-- ============================================================
-- Camera shake léger (désactivé si ReducedMotion)
-- ============================================================

local function cameraShake()
	if verifierReducedMotion() then return end

	local camera = workspace.CurrentCamera
	if not camera then return end

	local elapsed = 0
	local duree   = 0.4
	-- 0.3 degrés en radians
	local amp  = 0.3 * (math.pi / 180)
	local conn

	conn = RunService.RenderStepped:Connect(function(dt)
		elapsed = elapsed + dt
		if elapsed >= duree then
			conn:Disconnect()
			return
		end
		local decay = 1 - (elapsed / duree)
		local angle = math.sin(elapsed * 40) * amp * decay
		camera.CFrame = camera.CFrame * CFrame.Angles(0, angle, 0)
	end)

	-- Garde-fou au cas où le Disconnect ne se déclenche pas
	task.delay(duree + 0.1, function()
		if conn.Connected then conn:Disconnect() end
	end)
end

-- ============================================================
-- ANIMATION SUCCÈS (~3s)
-- ============================================================

function CodeRedeemAnimations.PlaySuccess(rewards, redeemBtn)
	annulerAnimPrecedente()
	local myId = activeAnimId
	Logger.debug("Code", "Animation succes declenchee")

	local sg = creerScreenGuiAnim()
	Debris:AddItem(sg, 4)

	-- 1. Flash doré plein écran : 1→0.4 en 0.15s, puis 0.4→1 en 0.5s
	local flash = Instance.new("Frame", sg)
	flash.Size                   = UDim2.new(1, 0, 1, 0)
	flash.BackgroundColor3       = Color3.fromRGB(255, 215, 80)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel        = 0
	flash.ZIndex                 = 100

	TweenService:Create(flash, TI_FLASH_IN, { BackgroundTransparency = 0.4 }):Play()
	task.delay(0.15, function()
		if myId ~= activeAnimId then return end
		TweenService:Create(flash, TI_FLASH_OUT, { BackgroundTransparency = 1 }):Play()
	end)

	-- 2. Popup central
	local popup = Instance.new("Frame", sg)
	popup.AnchorPoint      = Vector2.new(0.5, 0.5)
	popup.Position         = UDim2.new(0.5, 0, 0.45, 0)
	popup.Size             = UDim2.new(0, 300, 0, 10)
	popup.BackgroundColor3 = Color3.fromRGB(20, 10, 35)
	popup.BorderSizePixel  = 0
	popup.ZIndex           = 101
	popup.AutomaticSize    = Enum.AutomaticSize.Y
	Instance.new("UICorner", popup).CornerRadius = UDim.new(0, 16)

	local popupStroke = Instance.new("UIStroke", popup)
	popupStroke.Color     = Color3.fromRGB(255, 215, 80)
	popupStroke.Thickness = 2.5

	local layout = Instance.new("UIListLayout", popup)
	layout.Padding             = UDim.new(0, 6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder           = Enum.SortOrder.LayoutOrder

	local pad = Instance.new("UIPadding", popup)
	pad.PaddingTop    = UDim.new(0, 14)
	pad.PaddingBottom = UDim.new(0, 14)
	pad.PaddingLeft   = UDim.new(0, 12)
	pad.PaddingRight  = UDim.new(0, 12)

	local titre = Instance.new("TextLabel", popup)
	titre.Size                   = UDim2.new(1, 0, 0, 36)
	titre.BackgroundTransparency = 1
	titre.Text                   = "🎉 CODE ACTIVÉ !"
	titre.TextColor3             = Color3.fromRGB(255, 215, 80)
	titre.Font                   = Enum.Font.GothamBold
	titre.TextSize               = 20
	titre.ZIndex                 = 102
	titre.LayoutOrder            = 0

	if rewards and rewards.Coins and rewards.Coins > 0 then
		local montant
		if rewards.Coins >= 1e9 then
			montant = string.format("%.1fB", rewards.Coins / 1e9)
		elseif rewards.Coins >= 1e6 then
			montant = string.format("%.0fM", rewards.Coins / 1e6)
		elseif rewards.Coins >= 1e3 then
			montant = string.format("%.0fK", rewards.Coins / 1e3)
		else
			montant = tostring(math.floor(rewards.Coins))
		end
		local lbl = Instance.new("TextLabel", popup)
		lbl.Size                   = UDim2.new(1, 0, 0, 32)
		lbl.BackgroundTransparency = 1
		lbl.Text                   = "💰 +" .. montant .. " COINS"
		lbl.TextColor3             = Color3.fromRGB(255, 240, 100)
		lbl.Font                   = Enum.Font.GothamBold
		lbl.TextSize               = 22
		lbl.ZIndex                 = 102
		lbl.LayoutOrder            = 1
	end

	if rewards and rewards.BrainRots then
		for i, br in ipairs(rewards.BrainRots) do
			local lbl = Instance.new("TextLabel", popup)
			lbl.Size                   = UDim2.new(1, 0, 0, 26)
			lbl.BackgroundTransparency = 1
			lbl.Text                   = "🧠 +" .. (br.Quantity or 1) .. " " .. (br.Rarity or "?") .. " BR"
			lbl.TextColor3             = Color3.fromRGB(100, 220, 255)
			lbl.Font                   = Enum.Font.GothamBold
			lbl.TextSize               = 17
			lbl.ZIndex                 = 102
			lbl.LayoutOrder            = 10 + i
		end
	end

	-- Scale 0→1.2 (Back Out) puis 1.2→1.0 (Quad Out)
	local uiScale = Instance.new("UIScale", popup)
	uiScale.Scale = 0

	TweenService:Create(uiScale, TI_POPUP_IN, { Scale = 1.2 }):Play()
	task.delay(0.3, function()
		if myId ~= activeAnimId then return end
		TweenService:Create(uiScale, TI_POPUP_SQUISH, { Scale = 1.0 }):Play()
	end)

	-- Disparition après 2.2s
	task.delay(2.2, function()
		if myId ~= activeAnimId then return end
		for _, desc in ipairs(popup:GetDescendants()) do
			if desc:IsA("TextLabel") then
				TweenService:Create(desc, TI_POPUP_FADE, { TextTransparency = 1 }):Play()
			end
		end
		TweenService:Create(popup,       TI_POPUP_FADE, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(popupStroke, TI_POPUP_FADE, { Transparency = 1 }):Play()
	end)

	-- 3. Particules autour du personnage
	spawnParticules()

	-- 4. Son succès
	jouerSon(SOUND_SUCCES)

	-- 5. Camera shake
	cameraShake()

	-- Désactiver le bouton pendant l'animation (3s)
	if redeemBtn then
		redeemBtn.Active          = false
		redeemBtn.AutoButtonColor = false
		task.delay(3, function()
			if redeemBtn and redeemBtn.Parent then
				redeemBtn.Active          = true
				redeemBtn.AutoButtonColor = true
			end
		end)
	end
end

-- ============================================================
-- ANIMATION ERREUR (~1.5s)
-- ============================================================

function CodeRedeemAnimations.PlayError(message, redeemBtn)
	annulerAnimPrecedente()
	local myId = activeAnimId
	Logger.debug("Code", "Animation erreur declenchee : %s", message or "?")

	local sg = creerScreenGuiAnim()
	Debris:AddItem(sg, 2)

	-- 1. Flash rouge plein écran : 1→0.6 en 0.1s, puis 0.6→1 en 0.4s
	local flash = Instance.new("Frame", sg)
	flash.Size                   = UDim2.new(1, 0, 1, 0)
	flash.BackgroundColor3       = Color3.fromRGB(220, 50, 50)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel        = 0
	flash.ZIndex                 = 100

	TweenService:Create(flash, TI_ERR_FLASH_IN, { BackgroundTransparency = 0.6 }):Play()
	task.delay(0.1, function()
		if myId ~= activeAnimId then return end
		TweenService:Create(flash, TI_ERR_FLASH_OUT, { BackgroundTransparency = 1 }):Play()
	end)

	-- 2. Shake horizontal du bouton REDEEM (-10, +10, -10, +10, 0)
	if redeemBtn then
		local posBase = redeemBtn.Position
		local offsets = { -10, 10, -10, 10, 0 }
		local function shakeStep(i)
			if myId ~= activeAnimId then
				redeemBtn.Position = posBase
				return
			end
			if i > #offsets then
				redeemBtn.Position = posBase
				return
			end
			local cible = UDim2.new(
				posBase.X.Scale,
				posBase.X.Offset + offsets[i],
				posBase.Y.Scale,
				posBase.Y.Offset
			)
			local tw = TweenService:Create(redeemBtn, TI_SHAKE, { Position = cible })
			tw:Play()
			tw.Completed:Connect(function()
				tw:Destroy()
				shakeStep(i + 1)
			end)
		end
		shakeStep(1)
	end

	-- 3. Son erreur (TODO: remplacer par un son buzz/refus depuis la library Roblox)
	jouerSon(SOUND_ERREUR)
end

return CodeRedeemAnimations
