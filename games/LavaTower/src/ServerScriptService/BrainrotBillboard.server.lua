-- ServerScriptService/BrainrotBillboard.server.lua
-- Affiche un BillboardGui d'informations au-dessus de chaque brainrot dans workspace.Brainrots.
-- Gère les brainrots existants et les ajouts dynamiques.

local RunService    = game:GetService("RunService")
local TweenService  = game:GetService("TweenService")

-- ─────────────────────────────────────────────────────────────────────────────
-- Couleurs par rareté
-- ─────────────────────────────────────────────────────────────────────────────

local RARETE_COULEURS = {
	COMMON      = Color3.fromRGB(0,   200, 0),
	RARE        = Color3.fromRGB(0,   120, 255),
	EPIC        = Color3.fromRGB(150, 0,   255),
	LEGENDARY   = Color3.fromRGB(255, 200, 0),
	MYTHIC      = Color3.fromRGB(255, 50,  50),
	OG          = Color3.fromRGB(255, 140, 0),
	LUCKY_BLOCK = Color3.fromRGB(255, 215, 0),
	-- BRAINROT_GOD et SECRET : gérés par animation
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Formatage des grands nombres
-- ─────────────────────────────────────────────────────────────────────────────

local function formatNombre(n)
	n = tonumber(n) or 0
	if n >= 1e12 then
		return string.format("%.1fT", n / 1e12)
	elseif n >= 1e9 then
		return string.format("%.1fB", n / 1e9)
	elseif n >= 1e6 then
		return string.format("%.1fM", n / 1e6)
	elseif n >= 1e3 then
		return string.format("%.1fK", n / 1e3)
	else
		return tostring(math.floor(n))
	end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Animation arc-en-ciel (BRAINROT_GOD)
-- ─────────────────────────────────────────────────────────────────────────────

-- Lance une connexion Heartbeat qui fait tourner la teinte du label donné.
local function lancerAnimationArcEnCiel(label)
	local hue = 0
	RunService.Heartbeat:Connect(function(dt)
		-- Si le label n'existe plus (brainrot détruit), la connexion peut continuer
		-- sans crash car label.TextColor3 échouera silencieusement via pcall.
		if not label or not label.Parent then return end
		hue = (hue + dt * 0.5) % 1   -- 0.5 tours/seconde
		label.TextColor3 = Color3.fromHSV(hue, 1, 1)
	end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Animation noir/blanc (SECRET)
-- ─────────────────────────────────────────────────────────────────────────────

-- Crée un Tween en boucle alternant blanc → noir → blanc toutes les 0.6s.
local function lancerAnimationSecret(label)
	local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1, true)
	local tween = TweenService:Create(label, tweenInfo, { TextColor3 = Color3.fromRGB(20, 20, 20) })
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	tween:Play()
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Création d'un TextLabel dans un BillboardGui
-- ─────────────────────────────────────────────────────────────────────────────

local function creerLabel(parent, nom, texte, posY, couleur)
	local label = Instance.new("TextLabel")
	label.Name                  = nom
	label.Text                  = texte
	label.Size                  = UDim2.new(1, 0, 0.25, 0)
	label.Position              = UDim2.new(0, 0, posY, 0)
	label.TextColor3            = couleur
	label.TextScaled            = true
	label.Font                  = Enum.Font.GothamBold
	label.BackgroundTransparency = 1
	label.TextStrokeTransparency = 0.5
	label.TextStrokeColor3      = Color3.fromRGB(255, 255, 255)
	label.Parent                = parent
	return label
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Fonction principale : setup d'un brainrot
-- ─────────────────────────────────────────────────────────────────────────────

local function setupBillboard(model)
	-- 1. Vérifie que l'attribut Rarete est présent
	local rarete = model:GetAttribute("Rarete")
	if not rarete then return end

	-- 2. Evite les doublons
	if model:FindFirstChild("BrainrotInfo") then return end

	-- 3. Trouve la part d'attache (PrimaryPart ou premier BasePart)
	local attache
	if model:IsA("Model") then
		attache = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	elseif model:IsA("BasePart") then
		attache = model
	end
	if not attache then return end

	-- 4. Récupère les attributs (valeurs par défaut si nil)
	local prix          = model:GetAttribute("Prix")          or 0
	local cashParSeconde = model:GetAttribute("CashParSeconde") or 0

	-- 5. Crée le BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Name          = "BrainrotInfo"
	billboard.Size          = UDim2.new(5, 0, 2.5, 0)   -- studs : taille fixe dans le monde
	billboard.StudsOffset   = Vector3.new(0, 5, 0)
	billboard.AlwaysOnTop   = false
	billboard.ResetOnSpawn  = false
	billboard.Parent        = attache

	-- 6. Label Nom (noir)
	creerLabel(billboard, "Nom", model.Name, 0,
		Color3.fromRGB(0, 0, 0))

	-- 7. Label Rareté (couleur selon rareté, animation si spécial)
	local couleurRarete = RARETE_COULEURS[rarete] or Color3.fromRGB(200, 200, 200)
	local labelRarete   = creerLabel(billboard, "Rarete", rarete, 0.25, couleurRarete)

	if rarete == "BRAINROT_GOD" then
		lancerAnimationArcEnCiel(labelRarete)
	elseif rarete == "SECRET" then
		lancerAnimationSecret(labelRarete)
	end

	-- 8. Label Prix (vert)
	creerLabel(billboard, "Prix", "$" .. formatNombre(prix), 0.5,
		Color3.fromRGB(0, 220, 0))

	-- 9. Label CPS (jaune)
	creerLabel(billboard, "CPS", "$" .. formatNombre(cashParSeconde) .. "/s", 0.75,
		Color3.fromRGB(255, 215, 0))
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Parcours récursif d'un dossier
-- ─────────────────────────────────────────────────────────────────────────────

local function parcourirDossier(dossier)
	for _, enfant in ipairs(dossier:GetChildren()) do
		if enfant:IsA("Model") or enfant:IsA("BasePart") then
			setupBillboard(enfant)
		elseif enfant:IsA("Folder") then
			-- Sous-dossier de rareté : descend récursivement
			parcourirDossier(enfant)
		end
	end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Point d'entrée
-- ─────────────────────────────────────────────────────────────────────────────

local folderBrainrot = workspace:WaitForChild("Brainrots")

-- Traite tous les brainrots déjà présents
parcourirDossier(folderBrainrot)

-- Écoute les ajouts dynamiques (brainrots spawnés en cours de partie)
folderBrainrot.DescendantAdded:Connect(function(descendant)
	task.wait() -- laisse le temps aux attributs d'être définis
	if descendant:IsA("Model") or descendant:IsA("BasePart") then
		setupBillboard(descendant)
	end
end)

print("[BrainrotBillboard] Démarré — billboards initialisés sur workspace.Brainrots")
