-- shared-lib/src/client/FuseSystemClient.client.lua
-- UI client Fuse Machine -- rework visuel
-- Logique inchangee : 4 slots ingredients + inventaire carry + bouton Lancer
-- RemoteEvents : FuseSystem_OuvrirUI / FuseSystem_FermerUI / FuseSystem_Lancer

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Logger
do
	local ok, m = pcall(function()
		local sl = ReplicatedStorage:WaitForChild("SharedLib", 5)
		return require(sl:WaitForChild("Logger", 5))
	end)
	Logger = (ok and m) or {
		debug = function() end,
		info  = function() end,
		warn  = function() end,
		error = function() end,
	}
end

Logger.info("Fuse", "FuseSystemClient demarre")

local OuvrirUI = ReplicatedStorage:WaitForChild("FuseSystem_OuvrirUI", 30)
local FermerUI = OuvrirUI and ReplicatedStorage:WaitForChild("FuseSystem_FermerUI", 10)
local Lancer   = FermerUI and ReplicatedStorage:WaitForChild("FuseSystem_Lancer",   10)

if not OuvrirUI then
	Logger.warn("Fuse", "FuseSystem_OuvrirUI introuvable apres 30s -- FuseSystem.Init non appele")
	return
end
if not FermerUI or not Lancer then
	Logger.warn("Fuse", "FermerUI ou Lancer introuvables")
	return
end

Logger.info("Fuse", "RemoteEvents trouves")

-- ═══════════════════════════════════════════════════════════════════════════════
-- Palette
-- ═══════════════════════════════════════════════════════════════════════════════
local C_BG           = Color3.fromRGB(10,  10,  10)
local C_BG2          = Color3.fromRGB(18,  18,  18)
local C_BG3          = Color3.fromRGB(25,  25,  25)
local C_ACCENT       = Color3.fromRGB(160, 80,  15)
local C_ACCENT_LIGHT = Color3.fromRGB(180, 95,  20)
local C_TEXTE        = Color3.fromRGB(220, 220, 220)
local C_TEXTE2       = Color3.fromRGB(130, 130, 130)
local C_BORDURE      = Color3.fromRGB(60,  60,  60)
local C_BORDURE_SOMBRE = Color3.fromRGB(35, 35, 35)
local C_SLOT         = Color3.fromRGB(18,  18,  18)
local C_SLOT_FILL    = Color3.fromRGB(32,  32,  32)
local C_BTN_ON       = Color3.fromRGB(160, 80,  15)
local C_BTN_OFF      = Color3.fromRGB(40,  40,  40)
local C_FERMER       = Color3.fromRGB(50,  50,  50)
local C_ORANGE_STROKE = Color3.fromRGB(180, 90, 20)

-- ═══════════════════════════════════════════════════════════════════════════════
-- Etat client
-- ═══════════════════════════════════════════════════════════════════════════════
local machineActuelle   = nil
local slotsSelectionnes = {}
local estEnFermeture    = false

-- References UI
local screenGui, cadre
local slotsFrames = {}
local carryFrame
local btnLancer

-- Declarations forward
local fermerUI
local viderSlot
local rafraichirCarry
local mettreAJourBouton

-- ═══════════════════════════════════════════════════════════════════════════════
-- Helpers UI
-- ═══════════════════════════════════════════════════════════════════════════════
local function coin(parent, rayon)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, rayon or 0)
	c.Parent = parent
	return c
end

local function stroke(parent, couleur, epaisseur)
	local s = Instance.new("UIStroke")
	s.Name      = "Stroke"
	s.Color     = couleur or C_BORDURE
	s.Thickness = epaisseur or 1
	s.Parent    = parent
	return s
end

local function addHover(btn)
	local couleurBase = nil
	local tweenActif  = nil
	local strokeInst  = btn:FindFirstChild("Stroke")

	btn.MouseEnter:Connect(function()
		if not couleurBase then couleurBase = btn.BackgroundColor3 end
		local cible = Color3.new(
			math.min(1, couleurBase.R + 0.08),
			math.min(1, couleurBase.G + 0.08),
			math.min(1, couleurBase.B + 0.08)
		)
		if tweenActif then tweenActif:Cancel() end
		tweenActif = TweenService:Create(btn, TweenInfo.new(0.08), { BackgroundColor3 = cible })
		tweenActif:Play()
		if strokeInst then
			TweenService:Create(strokeInst, TweenInfo.new(0.08), { Color = C_ORANGE_STROKE }):Play()
		end
	end)

	btn.MouseLeave:Connect(function()
		if not couleurBase then return end
		local restaurer = couleurBase
		couleurBase = nil
		if tweenActif then tweenActif:Cancel() end
		tweenActif = TweenService:Create(btn, TweenInfo.new(0.08), { BackgroundColor3 = restaurer })
		tweenActif:Play()
		if strokeInst then
			TweenService:Create(strokeInst, TweenInfo.new(0.08), { Color = C_BORDURE }):Play()
		end
	end)
end

-- Section label avec barre accent gauche
local function creerSectionLabel(parent, texte, yPos)
	local cont = Instance.new("Frame")
	cont.Size                   = UDim2.new(1, 0, 0, 18)
	cont.Position               = UDim2.new(0, 0, 0, yPos)
	cont.BackgroundTransparency = 1
	cont.BorderSizePixel        = 0
	cont.Parent                 = parent

	local barre = Instance.new("Frame")
	barre.Size             = UDim2.new(0, 3, 1, 0)
	barre.BackgroundColor3 = C_ACCENT
	barre.BorderSizePixel  = 0
	barre.Parent           = cont

	local lbl = Instance.new("TextLabel")
	lbl.Size                   = UDim2.new(1, -10, 1, 0)
	lbl.Position               = UDim2.new(0, 10, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text                   = texte
	lbl.TextColor3             = C_ACCENT
	lbl.TextSize               = 11
	lbl.TextScaled             = false
	lbl.Font                   = Enum.Font.GothamBold
	lbl.TextXAlignment         = Enum.TextXAlignment.Left
	lbl.Parent                 = cont

	return cont
end

local function formaterCPS(cps)
	if     cps >= 1e15 then return string.format("%.1fQd", cps / 1e15)
	elseif cps >= 1e12 then return string.format("%.1fT",  cps / 1e12)
	elseif cps >= 1e9  then return string.format("%.1fB",  cps / 1e9)
	elseif cps >= 1e6  then return string.format("%.1fM",  cps / 1e6)
	elseif cps >= 1e3  then return string.format("%.1fK",  cps / 1e3)
	else                    return string.format("%.0f",   cps)
	end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- Logique slots (inchangee)
-- ═══════════════════════════════════════════════════════════════════════════════
local function rafraichirSlot(i)
	local slot = slotsFrames[i]
	if not slot then return end

	local tool     = slotsSelectionnes[i]
	local iconeL   = slot:FindFirstChild("Icone")
	local lNom     = slot:FindFirstChild("Nom")
	local lCPS     = slot:FindFirstChild("CPS")
	local st       = slot:FindFirstChild("Stroke")
	local numStrip = slot:FindFirstChild("NumStrip")

	if tool and tool.Parent then
		local nom = tool:GetAttribute("BrainrotName") or tool.Name
		local cps = tool:GetAttribute("CashParSeconde") or 0

		slot.BackgroundColor3 = C_SLOT_FILL
		if st then st.Color = C_ACCENT_LIGHT ; st.Thickness = 2 end

		if iconeL then iconeL.Visible = false end
		if lNom   then
			lNom.Text    = nom
			lNom.Visible = true
		end
		if lCPS then
			lCPS.Text    = formaterCPS(cps) .. "/s"
			lCPS.Visible = true
		end
		if numStrip then
			numStrip.BackgroundColor3 = Color3.fromRGB(35, 18, 5)
		end
	else
		slotsSelectionnes[i] = nil
		slot.BackgroundColor3 = C_SLOT
		if st then st.Color = C_BORDURE ; st.Thickness = 1 end

		if iconeL then iconeL.Visible = true end
		if lNom   then lNom.Visible  = false end
		if lCPS   then lCPS.Visible  = false end
		if numStrip then
			numStrip.BackgroundColor3 = C_BORDURE_SOMBRE
		end
	end
end

viderSlot = function(i)
	slotsSelectionnes[i] = nil
	rafraichirSlot(i)
	mettreAJourBouton()
	rafraichirCarry()
end

local function premierSlotVide()
	for i = 1, 4 do
		if not slotsSelectionnes[i] then return i end
	end
	return nil
end

mettreAJourBouton = function()
	local complet = true
	for i = 1, 4 do
		if not slotsSelectionnes[i] then complet = false ; break end
	end
	if btnLancer then
		btnLancer.BackgroundColor3 = complet and C_BTN_ON or C_BTN_OFF
		btnLancer.Text             = complet and "LANCER LA FUSION" or "Choisissez 4 Brainrots"
		btnLancer.TextColor3       = complet and C_TEXTE or C_TEXTE2
		btnLancer.Font             = complet and Enum.Font.GothamBold or Enum.Font.Gotham
		btnLancer.TextSize         = complet and 16 or 14
		btnLancer.Active           = complet
	end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- Refresh carry (inchange)
-- ═══════════════════════════════════════════════════════════════════════════════
rafraichirCarry = function()
	if not carryFrame then return end

	for _, child in ipairs(carryFrame:GetChildren()) do
		if child:IsA("TextButton") or child:IsA("TextLabel") then
			child:Destroy()
		end
	end

	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return end

	local dejaSelec = {}
	for i = 1, 4 do
		if slotsSelectionnes[i] then dejaSelec[slotsSelectionnes[i]] = true end
	end

	local count = 0
	for _, tool in ipairs(backpack:GetChildren()) do
		if tool:IsA("Tool") then
			local cps = tool:GetAttribute("CashParSeconde")
			if cps then
				count = count + 1
				local selectionne = dejaSelec[tool] == true
				local nom         = tool:GetAttribute("BrainrotName") or tool.Name

				local btn = Instance.new("TextButton")
				btn.Name                   = "BT_" .. count
				btn.Size                   = UDim2.new(0, 84, 0, 96)
				btn.BackgroundColor3       = selectionne and C_SLOT_FILL or C_SLOT
				btn.BackgroundTransparency = 0
				btn.BorderSizePixel        = 0
				btn.Text                   = ""
				btn.AutoButtonColor        = false
				btn.Parent                 = carryFrame
				coin(btn, 0)

				local st = stroke(btn, selectionne and C_ACCENT_LIGHT or C_BORDURE, 1)
				if selectionne then st.Transparency = 0.5 end

				-- Barre d'accent en haut (orange si selectionne, accent si libre)
				local topBar = Instance.new("Frame")
				topBar.Size             = UDim2.new(1, 0, 0, 5)
				topBar.BackgroundColor3 = selectionne and C_BORDURE or C_ACCENT
				topBar.BorderSizePixel  = 0
				topBar.Parent           = btn

				local lNom = Instance.new("TextLabel")
				lNom.Size                   = UDim2.new(1, -4, 0, 44)
				lNom.Position               = UDim2.new(0, 2, 0, 8)
				lNom.BackgroundTransparency = 1
				lNom.Text                   = nom
				lNom.TextColor3             = selectionne and C_TEXTE2 or C_TEXTE
				lNom.TextSize               = 11
				lNom.TextScaled             = false
				lNom.Font                   = Enum.Font.GothamBold
				lNom.TextWrapped            = true
				lNom.TextXAlignment         = Enum.TextXAlignment.Center
				lNom.Parent                 = btn

				local lCPS = Instance.new("TextLabel")
				lCPS.Size                   = UDim2.new(1, -4, 0, 24)
				lCPS.Position               = UDim2.new(0, 2, 1, -28)
				lCPS.BackgroundTransparency = 1
				lCPS.Text                   = formaterCPS(cps) .. "/s"
				lCPS.TextColor3             = selectionne and C_TEXTE2 or C_ACCENT_LIGHT
				lCPS.TextSize               = 12
				lCPS.TextScaled             = false
				lCPS.Font                   = Enum.Font.GothamBold
				lCPS.TextXAlignment         = Enum.TextXAlignment.Center
				lCPS.Parent                 = btn

				if not selectionne then
					local toolRef = tool
					btn.MouseButton1Click:Connect(function()
						local slot = premierSlotVide()
						if not slot then return end
						slotsSelectionnes[slot] = toolRef
						rafraichirSlot(slot)
						mettreAJourBouton()
						rafraichirCarry()
					end)
				end
			end
		end
	end

	if count == 0 then
		local vide = Instance.new("TextLabel")
		vide.Size                   = UDim2.new(0, 340, 1, 0)
		vide.BackgroundTransparency = 1
		vide.Text                   = "Aucun Brainrot dans votre carry"
		vide.TextColor3             = C_TEXTE2
		vide.TextSize               = 13
		vide.TextScaled             = false
		vide.Font                   = Enum.Font.Gotham
		vide.TextXAlignment         = Enum.TextXAlignment.Center
		vide.Parent                 = carryFrame
	end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- Ouvrir / Fermer
-- ═══════════════════════════════════════════════════════════════════════════════
local function ouvrirUI(machine)
	machineActuelle   = machine
	slotsSelectionnes = {}
	estEnFermeture    = false

	for i = 1, 4 do rafraichirSlot(i) end
	mettreAJourBouton()
	rafraichirCarry()

	screenGui.Enabled  = true
	cadre.Position     = UDim2.new(0.5, 0, 1.5, 0)
	TweenService:Create(cadre,
		TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0.5, 0, 0.5, 0) }
	):Play()

	Logger.debug("Fuse", "UI ouverte pour machine : %s", tostring(machine and machine.Name))
end

fermerUI = function()
	if estEnFermeture then return end
	estEnFermeture    = true
	machineActuelle   = nil
	slotsSelectionnes = {}

	local tween = TweenService:Create(cadre,
		TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Position = UDim2.new(0.5, 0, 1.5, 0) }
	)
	tween:Play()
	tween.Completed:Connect(function()
		screenGui.Enabled = false
		estEnFermeture    = false
	end)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- Lancer la fusion (inchange)
-- ═══════════════════════════════════════════════════════════════════════════════
local function onLancer()
	if not machineActuelle then return end

	for i = 1, 4 do
		local t = slotsSelectionnes[i]
		if not t or not t.Parent then return end
	end

	local tools = {}
	for i = 1, 4 do
		tools[i] = slotsSelectionnes[i]
	end

	if btnLancer then
		btnLancer.BackgroundColor3 = C_BTN_OFF
		btnLancer.Active           = false
		btnLancer.Text             = "Envoi..."
		btnLancer.TextColor3       = C_TEXTE2
		btnLancer.Font             = Enum.Font.Gotham
	end

	Lancer:FireServer(machineActuelle, tools)

	task.delay(0.5, function()
		if screenGui.Enabled then fermerUI() end
	end)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- Construction UI
-- ═══════════════════════════════════════════════════════════════════════════════
local function creerUI()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name           = "FuseSystemUI"
	screenGui.ResetOnSpawn   = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.IgnoreGuiInset = true
	screenGui.Enabled        = false
	screenGui.Parent         = playerGui

	-- Cadre principal 480x430, ancre centre
	cadre = Instance.new("Frame")
	cadre.Name                   = "Cadre"
	cadre.Size                   = UDim2.new(0, 480, 0, 430)
	cadre.AnchorPoint            = Vector2.new(0.5, 0.5)
	cadre.Position               = UDim2.new(0.5, 0, 1.5, 0)
	cadre.BackgroundColor3       = C_BG
	cadre.BackgroundTransparency = 0.05
	cadre.BorderSizePixel        = 0
	cadre.Parent                 = screenGui
	coin(cadre, 0)
	stroke(cadre, C_BORDURE, 1)

	-- UIScale pour mobile
	local uiScale = Instance.new("UIScale")
	uiScale.Parent = cadre
	local function ajusterScale()
		local vp = workspace.CurrentCamera.ViewportSize
		local s  = math.min(vp.X / 540, vp.Y / 500, 1)
		uiScale.Scale = math.max(0.55, s)
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(ajusterScale)
	ajusterScale()

	-- ─── Header ──────────────────────────────────────────────────────────────
	local accentBande = Instance.new("Frame")
	accentBande.Size             = UDim2.new(0, 3, 0, 52)
	accentBande.BackgroundColor3 = C_ACCENT
	accentBande.BorderSizePixel  = 0
	accentBande.Parent           = cadre

	local titreBar = Instance.new("Frame")
	titreBar.Size                   = UDim2.new(1, 0, 0, 52)
	titreBar.BackgroundTransparency = 1
	titreBar.BorderSizePixel        = 0
	titreBar.Parent                 = cadre

	local lTitre = Instance.new("TextLabel")
	lTitre.Size                   = UDim2.new(1, -60, 0, 28)
	lTitre.Position               = UDim2.new(0, 16, 0, 8)
	lTitre.BackgroundTransparency = 1
	lTitre.Text                   = "FUSE MACHINE"
	lTitre.TextColor3             = C_TEXTE
	lTitre.TextSize               = 18
	lTitre.TextScaled             = false
	lTitre.Font                   = Enum.Font.GothamBold
	lTitre.TextXAlignment         = Enum.TextXAlignment.Left
	lTitre.Parent                 = titreBar

	local lSousTitre = Instance.new("TextLabel")
	lSousTitre.Size                   = UDim2.new(1, -60, 0, 16)
	lSousTitre.Position               = UDim2.new(0, 16, 0, 32)
	lSousTitre.BackgroundTransparency = 1
	lSousTitre.Text                   = "Combinez 4 Brainrots pour en obtenir un meilleur"
	lSousTitre.TextColor3             = C_TEXTE2
	lSousTitre.TextSize               = 10
	lSousTitre.TextScaled             = false
	lSousTitre.Font                   = Enum.Font.Gotham
	lSousTitre.TextXAlignment         = Enum.TextXAlignment.Left
	lSousTitre.Parent                 = titreBar

	local sep0 = Instance.new("Frame")
	sep0.Size             = UDim2.new(1, 0, 0, 1)
	sep0.Position         = UDim2.new(0, 0, 0, 52)
	sep0.BackgroundColor3 = C_BORDURE
	sep0.BorderSizePixel  = 0
	sep0.Parent           = cadre

	local btnX = Instance.new("TextButton")
	btnX.Size             = UDim2.new(0, 44, 0, 44)
	btnX.Position         = UDim2.new(1, -50, 0, 4)
	btnX.BackgroundColor3 = C_FERMER
	btnX.BorderSizePixel  = 0
	btnX.Text             = "X"
	btnX.TextColor3       = Color3.fromRGB(180, 180, 180)
	btnX.TextSize         = 16
	btnX.TextScaled       = false
	btnX.Font             = Enum.Font.GothamBold
	btnX.AutoButtonColor  = false
	btnX.Parent           = titreBar
	coin(btnX, 2)
	stroke(btnX, C_BORDURE, 1)
	addHover(btnX)
	btnX.MouseButton1Click:Connect(function() fermerUI() end)

	-- ─── Contenu ─────────────────────────────────────────────────────────────
	local contenu = Instance.new("Frame")
	contenu.Name                   = "Contenu"
	contenu.Size                   = UDim2.new(1, -24, 1, -62)
	contenu.Position               = UDim2.new(0, 12, 0, 58)
	contenu.BackgroundTransparency = 1
	contenu.Parent                 = cadre

	-- Section INGREDIENTS (y=0)
	creerSectionLabel(contenu, "INGREDIENTS  --  4 Brainrots requis", 0)

	-- Conteneur 4 slots (y=22, h=100)
	local slotsConteneur = Instance.new("Frame")
	slotsConteneur.Size                   = UDim2.new(1, 0, 0, 100)
	slotsConteneur.Position               = UDim2.new(0, 0, 0, 22)
	slotsConteneur.BackgroundTransparency = 1
	slotsConteneur.Parent                 = contenu

	local slotLayout = Instance.new("UIListLayout")
	slotLayout.FillDirection       = Enum.FillDirection.Horizontal
	slotLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	slotLayout.VerticalAlignment   = Enum.VerticalAlignment.Center
	slotLayout.Padding             = UDim.new(0, 7)
	slotLayout.Parent              = slotsConteneur

	slotsFrames = {}
	for i = 1, 4 do
		local slot = Instance.new("TextButton")
		slot.Name                   = "Slot" .. i
		slot.Size                   = UDim2.new(0, 100, 0, 100)
		slot.BackgroundColor3       = C_SLOT
		slot.BackgroundTransparency = 0
		slot.BorderSizePixel        = 0
		slot.Text                   = ""
		slot.AutoButtonColor        = false
		slot.Parent                 = slotsConteneur
		coin(slot, 0)
		stroke(slot, C_BORDURE, 1)

		-- "+" quand slot vide
		local iconeL = Instance.new("TextLabel")
		iconeL.Name                   = "Icone"
		iconeL.Size                   = UDim2.new(1, 0, 0, 52)
		iconeL.Position               = UDim2.new(0, 0, 0, 14)
		iconeL.BackgroundTransparency = 1
		iconeL.Text                   = "+"
		iconeL.TextColor3             = C_BORDURE
		iconeL.TextSize               = 26
		iconeL.TextScaled             = false
		iconeL.Font                   = Enum.Font.GothamBold
		iconeL.Visible                = true
		iconeL.Parent                 = slot

		-- Nom (cache par defaut)
		local lNom = Instance.new("TextLabel")
		lNom.Name                   = "Nom"
		lNom.Size                   = UDim2.new(1, -4, 0, 44)
		lNom.Position               = UDim2.new(0, 2, 0, 6)
		lNom.BackgroundTransparency = 1
		lNom.Text                   = ""
		lNom.TextColor3             = C_TEXTE
		lNom.TextSize               = 11
		lNom.TextScaled             = false
		lNom.Font                   = Enum.Font.GothamBold
		lNom.TextWrapped            = true
		lNom.TextXAlignment         = Enum.TextXAlignment.Center
		lNom.Visible                = false
		lNom.Parent                 = slot

		-- CPS (cache par defaut)
		local lCPS = Instance.new("TextLabel")
		lCPS.Name                   = "CPS"
		lCPS.Size                   = UDim2.new(1, -4, 0, 22)
		lCPS.Position               = UDim2.new(0, 2, 0, 52)
		lCPS.BackgroundTransparency = 1
		lCPS.Text                   = ""
		lCPS.TextColor3             = C_ACCENT_LIGHT
		lCPS.TextSize               = 12
		lCPS.TextScaled             = false
		lCPS.Font                   = Enum.Font.GothamBold
		lCPS.TextXAlignment         = Enum.TextXAlignment.Center
		lCPS.Visible                = false
		lCPS.Parent                 = slot

		-- Bandeau bas avec numero
		local numStrip = Instance.new("Frame")
		numStrip.Name             = "NumStrip"
		numStrip.Size             = UDim2.new(1, 0, 0, 18)
		numStrip.Position         = UDim2.new(0, 0, 1, -18)
		numStrip.BackgroundColor3 = C_BORDURE_SOMBRE
		numStrip.BorderSizePixel  = 0
		numStrip.Parent           = slot

		local numLbl = Instance.new("TextLabel")
		numLbl.Size                   = UDim2.new(1, 0, 1, 0)
		numLbl.BackgroundTransparency = 1
		numLbl.Text                   = "SLOT " .. i
		numLbl.TextColor3             = C_TEXTE2
		numLbl.TextSize               = 9
		numLbl.TextScaled             = false
		numLbl.Font                   = Enum.Font.GothamBold
		numLbl.Parent                 = numStrip

		local idx = i
		slot.MouseButton1Click:Connect(function() viderSlot(idx) end)
		slotsFrames[i] = slot
	end

	-- Separateur (y=126)
	local sep = Instance.new("Frame")
	sep.Size             = UDim2.new(1, 0, 0, 1)
	sep.Position         = UDim2.new(0, 0, 0, 128)
	sep.BackgroundColor3 = C_BORDURE
	sep.BorderSizePixel  = 0
	sep.Parent           = contenu

	-- Section VOS BRAINROTS (y=133)
	creerSectionLabel(contenu, "VOS BRAINROTS  --  Cliquez pour ajouter", 133)

	-- ScrollingFrame carry (y=155, h=118)
	carryFrame = Instance.new("ScrollingFrame")
	carryFrame.Name                   = "CarryFrame"
	carryFrame.Size                   = UDim2.new(1, 0, 0, 118)
	carryFrame.Position               = UDim2.new(0, 0, 0, 155)
	carryFrame.BackgroundColor3       = C_BG2
	carryFrame.BackgroundTransparency = 0
	carryFrame.BorderSizePixel        = 0
	carryFrame.ScrollBarThickness     = 4
	carryFrame.ScrollBarImageColor3   = C_ACCENT
	carryFrame.CanvasSize             = UDim2.new(0, 0, 0, 0)
	carryFrame.AutomaticCanvasSize    = Enum.AutomaticSize.XY
	carryFrame.ScrollingDirection     = Enum.ScrollingDirection.X
	carryFrame.Parent                 = contenu
	coin(carryFrame, 0)
	stroke(carryFrame, C_BORDURE, 1)

	local carryLayout = Instance.new("UIListLayout")
	carryLayout.FillDirection     = Enum.FillDirection.Horizontal
	carryLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	carryLayout.Padding           = UDim.new(0, 6)
	carryLayout.Parent            = carryFrame

	local carryPad = Instance.new("UIPadding")
	carryPad.PaddingLeft   = UDim.new(0, 8)
	carryPad.PaddingRight  = UDim.new(0, 8)
	carryPad.PaddingTop    = UDim.new(0, 6)
	carryPad.PaddingBottom = UDim.new(0, 6)
	carryPad.Parent        = carryFrame

	-- Bouton Lancer (y=277, h=52)
	btnLancer = Instance.new("TextButton")
	btnLancer.Name             = "BtnLancer"
	btnLancer.Size             = UDim2.new(1, 0, 0, 52)
	btnLancer.Position         = UDim2.new(0, 0, 0, 278)
	btnLancer.BackgroundColor3 = C_BTN_OFF
	btnLancer.BorderSizePixel  = 0
	btnLancer.Text             = "Choisissez 4 Brainrots"
	btnLancer.TextColor3       = C_TEXTE2
	btnLancer.TextSize         = 14
	btnLancer.TextScaled       = false
	btnLancer.Font             = Enum.Font.Gotham
	btnLancer.AutoButtonColor  = false
	btnLancer.Active           = false
	btnLancer.Parent           = contenu
	coin(btnLancer, 2)
	stroke(btnLancer, C_BORDURE, 1)
	addHover(btnLancer)
	btnLancer.MouseButton1Click:Connect(function()
		if not btnLancer.Active then return end
		onLancer()
	end)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- Evenements serveur -> client
-- ═══════════════════════════════════════════════════════════════════════════════
OuvrirUI.OnClientEvent:Connect(function(machine)
	Logger.debug("Fuse", "OuvrirUI recu | machine=%s", tostring(machine and machine.Name))
	ouvrirUI(machine)
end)

FermerUI.OnClientEvent:Connect(function()
	Logger.debug("Fuse", "FermerUI recu")
	if screenGui and screenGui.Enabled then fermerUI() end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.Escape and screenGui and screenGui.Enabled then
		fermerUI()
	end
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- Init
-- ═══════════════════════════════════════════════════════════════════════════════
creerUI()
Logger.info("Fuse", "UI creee")
