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
-- Palette — thème Lava Tower (fond sombre, accents lave vifs)
-- ═══════════════════════════════════════════════════════════════════════════════
local C_BG           = Color3.fromRGB(18,  16,  22)   -- fond foncé neutre
local C_BG2          = Color3.fromRGB(28,  25,  35)
local C_BG3          = Color3.fromRGB(38,  34,  48)
local C_ACCENT       = Color3.fromRGB(255, 100, 20)   -- lave orange vif
local C_ACCENT_LIGHT = Color3.fromRGB(255, 145, 50)
local C_TEXTE        = Color3.fromRGB(220, 220, 220)
local C_TEXTE2       = Color3.fromRGB(130, 130, 130)
local C_BORDURE      = Color3.fromRGB(65,  70,  95)   -- ardoise
local C_BORDURE_SOMBRE = Color3.fromRGB(40, 42, 60)
local C_SLOT         = Color3.fromRGB(32,  36,  50)   -- slot vide ardoise
local C_SLOT_FILL    = Color3.fromRGB(42,  45,  65)   -- slot rempli
local C_BTN_ON       = Color3.fromRGB(200, 65,  10)   -- bouton actif = lave
local C_BTN_OFF      = Color3.fromRGB(38,  40,  55)
local C_FERMER       = Color3.fromRGB(50,  50,  65)
local C_ORANGE_STROKE = Color3.fromRGB(220, 110, 20)

-- Couleurs mutation
local C_GOLD    = Color3.fromRGB(255, 215,   0)
local C_DIAMANT = Color3.fromRGB(130, 220, 255)
local C_RAINBOW = Color3.fromRGB(200, 100, 255)
local C_TOXIC   = Color3.fromRGB( 80, 220,  80)

-- ═══════════════════════════════════════════════════════════════════════════════
-- Etat client
-- ═══════════════════════════════════════════════════════════════════════════════
local machineActuelle   = nil
local slotsSelectionnes = {}
local estEnFermeture    = false
local toxicEventActif   = false

-- References UI
local screenGui, cadre
local slotsFrames = {}
local carryFrame
local btnLancer
local btnGradTween        -- Tween gradient lave sur bouton FUSIONNER
local mutLignesContainer  -- Frame du panneau mutation (contient les lignes dynamiques)
local mutEventBanner      -- Label bannière event toxique

-- Declarations forward
local fermerUI
local viderSlot
local rafraichirCarry
local mettreAJourBouton
local mettreAJourMutation

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

	local tool   = slotsSelectionnes[i]
	local iconeL = slot:FindFirstChild("Icone")
	local lNom   = slot:FindFirstChild("Nom")
	local lCPS   = slot:FindFirstChild("CPS")
	local st     = slot:FindFirstChild("Stroke")

	if tool and tool.Parent then
		local nom      = tool:GetAttribute("BrainrotName") or tool.Name
		local cps      = tool:GetAttribute("CashParSeconde") or 0
		local mutation = tool:GetAttribute("Mutation")
		local isToxic  = tool:GetAttribute("IsToxic")

		local coulMut = (isToxic and C_TOXIC)
		              or (mutation == "GOLD"    and C_GOLD)
		              or (mutation == "DIAMANT" and C_DIAMANT)
		              or (mutation == "RAINBOW" and C_RAINBOW)
		              or C_ACCENT_LIGHT

		slot.BackgroundColor3 = C_SLOT_FILL
		if st then st.Color = coulMut ; st.Thickness = 2 end

		if iconeL then iconeL.Visible = false end
		if lNom   then lNom.Text = nom ; lNom.Visible = true end
		if lCPS   then lCPS.Text = formaterCPS(cps) .. "/s" ; lCPS.Visible = true end
	else
		slotsSelectionnes[i] = nil
		slot.BackgroundColor3 = C_SLOT
		if st then st.Color = C_BORDURE ; st.Thickness = 1 end

		if iconeL then iconeL.Visible = true end
		if lNom   then lNom.Visible  = false end
		if lCPS   then lCPS.Visible  = false end
	end
end

viderSlot = function(i)
	slotsSelectionnes[i] = nil
	rafraichirSlot(i)
	mettreAJourBouton()  -- appelle mettreAJourMutation en interne
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
		btnLancer.Text             = complet and "LAUNCH FUSION" or "Select 4 Brainrots"
		btnLancer.TextColor3       = complet and C_TEXTE or C_TEXTE2
		btnLancer.Font             = complet and Enum.Font.GothamBold or Enum.Font.Gotham
		btnLancer.TextSize         = complet and 16 or 14
		btnLancer.Active           = complet
		-- Gradient lave animé uniquement quand tous les slots sont remplis
		local g = btnLancer:FindFirstChildWhichIsA("UIGradient")
		if g then
			g.Enabled = complet
			if btnGradTween then
				if complet then btnGradTween:Play() else btnGradTween:Pause() end
			end
		end
	end
	mettreAJourMutation()
end

-- ─── Calcul et affichage des chances de mutation ──────────────────────────────
local function calculerChancesMutation()
	local nbGold, nbDiamant, nbRainbow, nbToxic = 0, 0, 0, 0
	for i = 1, 4 do
		local t = slotsSelectionnes[i]
		if t and t.Parent then
			local mutation = t:GetAttribute("Mutation")
			if t:GetAttribute("IsToxic") then
				nbToxic   += 1
			elseif mutation == "GOLD" then
				nbGold    += 1
			elseif mutation == "DIAMANT" then
				nbDiamant += 1
			elseif mutation == "RAINBOW" then
				nbRainbow += 1
			end
			-- brainrots normaux : aucun bonus
		end
	end
	local toxicBonus    = toxicEventActif and 10 or 0
	local goldChance    = nbGold    * 10
	local diamantChance = nbDiamant * 10
	local rainbowChance = nbRainbow * 10
	local toxicChance   = nbToxic   * 10 + toxicBonus
	return goldChance, diamantChance, rainbowChance, toxicChance, toxicBonus
end

local function creerLigneMutation(texte, couleur)
	local lbl = Instance.new("TextLabel")
	lbl.Size                   = UDim2.new(1, 0, 0, 28)
	lbl.BackgroundTransparency = 1
	lbl.Text                   = texte
	lbl.TextColor3             = couleur
	lbl.TextSize               = 14
	lbl.TextScaled             = false
	lbl.Font                   = Enum.Font.GothamBold
	lbl.TextXAlignment         = Enum.TextXAlignment.Center
	lbl.RichText               = true
	lbl.Parent                 = mutLignesContainer
	return lbl
end

mettreAJourMutation = function()
	if not mutLignesContainer then return end

	for _, child in ipairs(mutLignesContainer:GetChildren()) do
		if child:IsA("TextLabel") then child:Destroy() end
	end

	-- Bannière event
	if mutEventBanner then
		mutEventBanner.Visible = toxicEventActif
	end

	local goldChance, diamantChance, rainbowChance, toxicChance, toxicBonus = calculerChancesMutation()
	local aucune = goldChance == 0 and diamantChance == 0 and rainbowChance == 0 and toxicChance == 0

	if aucune then
		local lbl = creerLigneMutation("Aucune mutation\npossible", C_TEXTE2)
		lbl.TextSize = 11
		lbl.Font = Enum.Font.Gotham
		return
	end

	if rainbowChance > 0 then
		creerLigneMutation(string.format("<b>%d%%</b> Rainbow", rainbowChance), C_RAINBOW)
	end
	if diamantChance > 0 then
		creerLigneMutation(string.format("<b>%d%%</b> Diamant", diamantChance), C_DIAMANT)
	end
	if goldChance > 0 then
		creerLigneMutation(string.format("<b>%d%%</b> Gold",    goldChance),    C_GOLD)
	end
	if toxicChance > 0 then
		local txt = string.format("<b>%d%%</b> Toxic", toxicChance)
		if toxicBonus > 0 then
			txt = txt .. string.format(" <font size='10'>(+%d event)</font>", toxicBonus)
		end
		creerLigneMutation(txt, C_TOXIC)
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

	local dejaSelec = {}
	for i = 1, 4 do
		if slotsSelectionnes[i] then dejaSelec[slotsSelectionnes[i]] = true end
	end

	-- Collecte les tools du backpack ET de l'outil équipé (dans Character)
	local allTools = {}
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, tool in ipairs(backpack:GetChildren()) do
			if tool:IsA("Tool") and tool:GetAttribute("CashParSeconde") then
				allTools[#allTools + 1] = tool
			end
		end
	end
	local character = player.Character
	if character then
		for _, tool in ipairs(character:GetChildren()) do
			if tool:IsA("Tool") and tool:GetAttribute("CashParSeconde") then
				allTools[#allTools + 1] = tool
			end
		end
	end

	local count = #allTools
	for idx, tool in ipairs(allTools) do
		local cps         = tool:GetAttribute("CashParSeconde")
		local selectionne = dejaSelec[tool] == true
		local nom         = tool:GetAttribute("BrainrotName") or tool.Name
		local mutation    = tool:GetAttribute("Mutation")
		local isToxic     = tool:GetAttribute("IsToxic")

		local coulMut = (isToxic and C_TOXIC)
		              or (mutation == "GOLD"    and C_GOLD)
		              or (mutation == "DIAMANT" and C_DIAMANT)
		              or (mutation == "RAINBOW" and C_RAINBOW)
		              or C_ACCENT

		local btn = Instance.new("TextButton")
		btn.Name                   = "BT_" .. idx
		btn.Size                   = UDim2.new(0, 84, 0, 96)
		btn.BackgroundColor3       = selectionne and C_SLOT_FILL or C_SLOT
		btn.BackgroundTransparency = 0
		btn.BorderSizePixel        = 0
		btn.Text                   = ""
		btn.AutoButtonColor        = false
		btn.Parent                 = carryFrame
		coin(btn, 0)

		local st = stroke(btn, selectionne and (coulMut) or C_BORDURE, 1)
		if selectionne then st.Transparency = 0.5 end

		local topBar = Instance.new("Frame")
		topBar.Size             = UDim2.new(1, 0, 0, 5)
		topBar.BackgroundColor3 = selectionne and C_BORDURE or coulMut
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
				mettreAJourBouton()  -- appelle mettreAJourMutation en interne
				rafraichirCarry()
			end)
		end
	end

	if count == 0 then
		local vide = Instance.new("TextLabel")
		vide.Size                   = UDim2.new(0, 340, 1, 0)
		vide.BackgroundTransparency = 1
		vide.Text                   = "No Brainrot in your carry"
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
	mettreAJourBouton()   -- appelle mettreAJourMutation en interne
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
		btnLancer.Text             = "Sending..."
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

	-- Cadre principal 668x380
	cadre = Instance.new("Frame")
	cadre.Name             = "Cadre"
	cadre.Size             = UDim2.new(0, 668, 0, 380)
	cadre.AnchorPoint      = Vector2.new(0.5, 0.5)
	cadre.Position         = UDim2.new(0.5, 0, 1.5, 0)
	cadre.BackgroundColor3 = C_BG
	cadre.BorderSizePixel  = 0
	cadre.Parent           = screenGui
	coin(cadre, 10)
	-- Gradient fond : ardoise bleutée du haut vers légèrement plus clair en bas
	do
		local g = Instance.new("UIGradient")
		g.Color    = ColorSequence.new(Color3.fromRGB(12, 15, 25), Color3.fromRGB(20, 22, 35))
		g.Rotation = 90
		g.Parent   = cadre
	end
	local _cs = stroke(cadre, Color3.fromRGB(220, 100, 20), 4)
	_cs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	cadre.ClipsDescendants = true

	-- UIScale pour mobile
	local uiScale = Instance.new("UIScale")
	uiScale.Parent = cadre
	local function ajusterScale()
		local vp = workspace.CurrentCamera.ViewportSize
		local s  = math.min(vp.X / 730, vp.Y / 500, 1)
		uiScale.Scale = math.max(0.5, s)
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(ajusterScale)
	ajusterScale()

	-- ─── Header (gradient lava orange→rouge) ──────────────────────────────────
	local titreBar = Instance.new("Frame")
	titreBar.Size             = UDim2.new(1, 0, 0, 52)
	titreBar.BackgroundColor3 = C_ACCENT
	titreBar.BorderSizePixel  = 0
	titreBar.Parent           = cadre
	do
		local g = Instance.new("UIGradient")
		g.Color    = ColorSequence.new(Color3.fromRGB(210, 65, 8), Color3.fromRGB(155, 40, 5))
		g.Rotation = 0
		g.Parent   = titreBar
	end

	local _hdrStuds = Instance.new("ImageLabel", titreBar)
	_hdrStuds.Size = UDim2.new(1,0,1,0) ; _hdrStuds.BackgroundTransparency = 1
	_hdrStuds.Image = "rbxassetid://6927295847" ; _hdrStuds.ScaleType = Enum.ScaleType.Tile
	_hdrStuds.TileSize = UDim2.fromOffset(30,30) ; _hdrStuds.ImageTransparency = 0.3
	_hdrStuds.ZIndex = 1

	local lTitre = Instance.new("TextLabel")
	lTitre.Size                   = UDim2.new(1, -60, 0, 28)
	lTitre.Position               = UDim2.new(0, 16, 0, 8)
	lTitre.BackgroundTransparency = 1
	lTitre.Text                   = "FUSE MACHINE"
	lTitre.TextColor3             = Color3.fromRGB(255, 255, 255)
	lTitre.TextSize               = 18
	lTitre.TextScaled             = false
	lTitre.Font                   = Enum.Font.GothamBold
	lTitre.TextXAlignment         = Enum.TextXAlignment.Left
	lTitre.TextStrokeColor3       = Color3.fromRGB(80, 20, 0)
	lTitre.TextStrokeTransparency = 0.4
	lTitre.Parent                 = titreBar

	local lSousTitre = Instance.new("TextLabel")
	lSousTitre.Size                   = UDim2.new(1, -60, 0, 16)
	lSousTitre.Position               = UDim2.new(0, 16, 0, 32)
	lSousTitre.BackgroundTransparency = 1
	lSousTitre.Text                   = "Combine 4 Brainrots to get a better one!"
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
	btnX.BackgroundColor3 = Color3.fromRGB(230, 50, 50)
	btnX.BorderSizePixel  = 0
	btnX.Text             = "X"
	btnX.TextColor3       = Color3.fromRGB(255, 255, 255)
	btnX.TextSize         = 16
	btnX.TextScaled       = false
	btnX.Font             = Enum.Font.GothamBold
	btnX.AutoButtonColor  = false
	btnX.Parent           = titreBar
	coin(btnX, 6)
	stroke(btnX, Color3.fromRGB(255, 255, 255), 3)
	addHover(btnX)
	btnX.MouseButton1Click:Connect(function() fermerUI() end)

	-- ─── Contenu (gauche, largeur fixe 444px) ────────────────────────────────
	local contenu = Instance.new("Frame")
	contenu.Name                   = "Contenu"
	contenu.Size                   = UDim2.new(0, 444, 1, -62)
	contenu.Position               = UDim2.new(0, 12, 0, 58)
	contenu.BackgroundTransparency = 1
	contenu.Parent                 = cadre

	-- Conteneur 4 slots (y=0, h=100)
	local slotsConteneur = Instance.new("Frame")
	slotsConteneur.Size                   = UDim2.new(1, 0, 0, 100)
	slotsConteneur.Position               = UDim2.new(0, 0, 0, 0)
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
		coin(slot, 6)
		stroke(slot, C_BORDURE, 1.5)

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

		local idx = i
		slot.MouseButton1Click:Connect(function() viderSlot(idx) end)
		slotsFrames[i] = slot
	end

	-- Separateur (y=106)
	local sep = Instance.new("Frame")
	sep.Size             = UDim2.new(1, 0, 0, 1)
	sep.Position         = UDim2.new(0, 0, 0, 106)
	sep.BackgroundColor3 = C_BORDURE
	sep.BorderSizePixel  = 0
	sep.Parent           = contenu

	-- ScrollingFrame carry (y=111, h=118)
	carryFrame = Instance.new("ScrollingFrame")
	carryFrame.Name                   = "CarryFrame"
	carryFrame.Size                   = UDim2.new(1, 0, 0, 118)
	carryFrame.Position               = UDim2.new(0, 0, 0, 111)
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

	-- Bouton FUSIONNER (y=234, h=52) — gradient lave animé quand actif
	btnLancer = Instance.new("TextButton")
	btnLancer.Name             = "BtnLancer"
	btnLancer.Size             = UDim2.new(1, 0, 0, 52)
	btnLancer.Position         = UDim2.new(0, 0, 0, 234)
	btnLancer.BackgroundColor3 = C_BTN_OFF
	btnLancer.BorderSizePixel  = 0
	btnLancer.Text             = "Select 4 Brainrots"
	btnLancer.TextColor3       = C_TEXTE2
	btnLancer.TextSize         = 14
	btnLancer.TextScaled       = false
	btnLancer.Font             = Enum.Font.Gotham
	btnLancer.AutoButtonColor  = false
	btnLancer.Active           = false
	btnLancer.Parent           = contenu
	coin(btnLancer, 10)
	local btnStroke = stroke(btnLancer, C_BORDURE_SOMBRE, 2)
	addHover(btnLancer)

	-- Gradient lave sur le bouton (rotation animée en boucle)
	local btnGrad = Instance.new("UIGradient")
	btnGrad.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0,   Color3.fromRGB(220, 55,  5)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 140, 20)),
		ColorSequenceKeypoint.new(1,   Color3.fromRGB(220, 55,  5)),
	}
	btnGrad.Rotation = 0
	btnGrad.Parent   = btnLancer
	btnGrad.Enabled  = false  -- activé uniquement quand les 4 slots sont remplis

	btnGradTween = TweenService:Create(btnGrad,
		TweenInfo.new(2, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
		{ Rotation = 360 })

	btnLancer.MouseButton1Click:Connect(function()
		if not btnLancer.Active then return end
		onLancer()
	end)

	-- ─── Barre de lave animée en bas du cadre ────────────────────────────────
	local laveBar = Instance.new("Frame")
	laveBar.Name             = "LavaBarre"
	laveBar.Size             = UDim2.new(1, 0, 0, 14)
	laveBar.AnchorPoint      = Vector2.new(0, 1)
	laveBar.Position         = UDim2.new(0, 0, 1, 0)
	laveBar.BackgroundColor3 = Color3.fromRGB(220, 50, 0)
	laveBar.BorderSizePixel  = 0
	laveBar.ZIndex           = 8
	laveBar.Parent           = cadre
	do
		local lavGrad = Instance.new("UIGradient")
		lavGrad.Color = ColorSequence.new{
			ColorSequenceKeypoint.new(0,   Color3.fromRGB(220, 50,  0)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 140, 0)),
			ColorSequenceKeypoint.new(1,   Color3.fromRGB(220, 50,  0)),
		}
		lavGrad.Rotation = 0
		lavGrad.Parent   = laveBar
		-- Animation montée et rotation gradient en boucle
		TweenService:Create(lavGrad,
			TweenInfo.new(3, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
			{ Rotation = 360 }):Play()
		TweenService:Create(laveBar,
			TweenInfo.new(2.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Size = UDim2.new(1, 0, 0, 22) }):Play()
	end

	-- ─── Panneau MUTATION (droite, x=468, largeur=188) ────────────────────────
	local mutPanel = Instance.new("Frame")
	mutPanel.Name             = "MutationPanel"
	mutPanel.Size             = UDim2.new(0, 188, 1, -70)
	mutPanel.Position         = UDim2.new(0, 468, 0, 62)
	mutPanel.BackgroundColor3 = Color3.fromRGB(20, 22, 35)
	mutPanel.BorderSizePixel  = 0
	mutPanel.Parent           = cadre
	coin(mutPanel, 8)
	do
		local g = Instance.new("UIGradient")
		g.Color    = ColorSequence.new(Color3.fromRGB(25, 28, 45), Color3.fromRGB(15, 17, 30))
		g.Rotation = 90
		g.Parent   = mutPanel
	end
	local _mps = stroke(mutPanel, Color3.fromRGB(200, 90, 20), 2)
	_mps.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

	-- Barre accent gauche
	local mutAccent = Instance.new("Frame")
	mutAccent.Size             = UDim2.new(0, 3, 1, 0)
	mutAccent.BackgroundColor3 = C_ACCENT
	mutAccent.BorderSizePixel  = 0
	mutAccent.Parent           = mutPanel

	-- Titre centré
	local mutTitre = Instance.new("TextLabel")
	mutTitre.Size                   = UDim2.new(1, -6, 0, 30)
	mutTitre.Position               = UDim2.new(0, 3, 0, 8)
	mutTitre.BackgroundTransparency = 1
	mutTitre.Text                   = "MUTATION"
	mutTitre.TextColor3             = C_TEXTE
	mutTitre.TextSize               = 13
	mutTitre.TextScaled             = false
	mutTitre.Font                   = Enum.Font.GothamBold
	mutTitre.TextXAlignment         = Enum.TextXAlignment.Center
	mutTitre.Parent                 = mutPanel

	local mutSep = Instance.new("Frame")
	mutSep.Size             = UDim2.new(1, -8, 0, 1)
	mutSep.Position         = UDim2.new(0, 4, 0, 42)
	mutSep.BackgroundColor3 = C_BORDURE
	mutSep.BorderSizePixel  = 0
	mutSep.Parent           = mutPanel

	-- Bannière event toxique (cachée par défaut)
	mutEventBanner = Instance.new("TextLabel")
	mutEventBanner.Name                   = "EventBanner"
	mutEventBanner.Size                   = UDim2.new(1, -8, 0, 22)
	mutEventBanner.Position               = UDim2.new(0, 4, 1, -30)
	mutEventBanner.BackgroundColor3       = Color3.fromRGB(20, 60, 20)
	mutEventBanner.BackgroundTransparency = 0
	mutEventBanner.BorderSizePixel        = 0
	mutEventBanner.Text                   = "+10% Toxic (Event)"
	mutEventBanner.TextColor3             = C_TOXIC
	mutEventBanner.TextSize               = 10
	mutEventBanner.TextScaled             = false
	mutEventBanner.Font                   = Enum.Font.GothamBold
	mutEventBanner.TextXAlignment         = Enum.TextXAlignment.Center
	mutEventBanner.Visible                = false
	mutEventBanner.Parent                 = mutPanel
	coin(mutEventBanner, 2)

	-- Conteneur lignes mutation (liste verticale)
	mutLignesContainer = Instance.new("Frame")
	mutLignesContainer.Name                   = "MutLignes"
	mutLignesContainer.Size                   = UDim2.new(1, -8, 1, -90)
	mutLignesContainer.Position               = UDim2.new(0, 4, 0, 50)
	mutLignesContainer.BackgroundTransparency = 1
	mutLignesContainer.BorderSizePixel        = 0
	mutLignesContainer.Parent                 = mutPanel

	local mutLayout = Instance.new("UIListLayout")
	mutLayout.FillDirection       = Enum.FillDirection.Vertical
	mutLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	mutLayout.Padding             = UDim.new(0, 8)
	mutLayout.Parent              = mutLignesContainer
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

-- Etat de l'événement Toxic (ToxicEventSystem.server.lua)
task.spawn(function()
	local re = ReplicatedStorage:WaitForChild("ToxicEventState", 30)
	if not re then return end
	re.OnClientEvent:Connect(function(active)
		toxicEventActif = active == true
		if screenGui and screenGui.Enabled then
			mettreAJourMutation()
		end
	end)
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

-- ─── Bulles de lave animées ──────────────────────────────────────────────────
-- Petites sphères oranges/rouges qui montent depuis le bas du cadre
local BULLE_COULEURS = {
	Color3.fromRGB(255, 100, 20),
	Color3.fromRGB(255, 150, 40),
	Color3.fromRGB(230, 60,  5),
	Color3.fromRGB(255, 180, 50),
}
local function creerBulle()
	if not cadre or not screenGui or not screenGui.Enabled then return end
	local taille = math.random(8, 22)
	local xPos   = math.random(10, 640)
	local duree  = math.random(2, 5) * 0.8
	local couleur= BULLE_COULEURS[math.random(1, #BULLE_COULEURS)]

	local bulle = Instance.new("Frame")
	bulle.Size                  = UDim2.new(0, taille, 0, taille)
	bulle.Position              = UDim2.new(0, xPos, 1, -taille - 10)
	bulle.BackgroundColor3      = couleur
	bulle.BackgroundTransparency= 0.25
	bulle.BorderSizePixel       = 0
	bulle.ZIndex                = 1  -- sous tout le contenu
	bulle.Parent                = cadre
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = bulle

	local targetY = -taille - 20
	TweenService:Create(bulle,
		TweenInfo.new(duree, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0, xPos, 0, targetY), BackgroundTransparency = 1 }
	):Play()

	task.delay(duree + 0.1, function()
		if bulle.Parent then bulle:Destroy() end
	end)
end

task.spawn(function()
	while true do
		task.wait(0.25 + math.random() * 0.35)
		if screenGui and screenGui.Enabled then
			creerBulle()
		end
	end
end)
