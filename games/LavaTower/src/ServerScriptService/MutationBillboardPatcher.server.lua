-- ServerScriptService/MutationBillboardPatcher.server.lua  (LavaTower uniquement)
-- Injecte une ligne de mutation tout en haut du billboard des brainrots mutés.
-- Lit l'attribut "Mutation" = "GOLD" | "DIAMANT" | "RAINBOW" posé par BrainrotPlatformSpawner.
-- Ne touche pas à shared-lib : patche le _BRBillboard après sa création par PickupSystem.

local CollectionService = game:GetService("CollectionService")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Logger            = require(game:GetService("ServerScriptService").SharedLib.Server.Logger)
local RainbowEffect     = require(ReplicatedStorage.Modules.RainbowEffect)

local TAG                 = "BrainrotCollectible"
local MAIN_BILLBOARD_NAME = "_BRBillboard"

-- ─────────────────────────────────────────────────────────────
-- Couleurs et textes par type de mutation
-- ─────────────────────────────────────────────────────────────

local INFOS_MUTATION = {
	GOLD    = { texte = "Gold",    couleur = Color3.fromRGB(255, 215,   0) },
	DIAMANT = { texte = "Diamant", couleur = Color3.fromRGB(130, 220, 255) },
	RAINBOW = { texte = "Rainbow", couleur = nil },  -- animée
}

-- ─────────────────────────────────────────────────────────────
-- Utilitaires
-- ─────────────────────────────────────────────────────────────

local function GetRootPart(instance)
	if instance:IsA("Model") then
		return instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
	elseif instance:IsA("BasePart") then
		return instance
	end
	return nil
end

-- ─────────────────────────────────────────────────────────────
-- Patch du billboard
--
-- Le billboard _BRBillboard est une grille de N lignes régulières
-- (posY = i/N, height = 1/N). On ajoute une ligne en position 0,
-- on décale toutes les autres d'un slot et on redimensionne le tout.
-- ─────────────────────────────────────────────────────────────

local function PatcherBillboard(bb, mutation)
	local info = INFOS_MUTATION[mutation]
	if not info then return end
	if bb:FindFirstChild("LMutation") then return end  -- déjà patchée (ex: SetupBase)

	-- Déduire le nombre de lignes depuis la hauteur en studs
	-- (CreerBillboardGui pose Size = UDim2.new(5, 0, nbLignes * 0.5, 0))
	local oldN = math.round(bb.Size.Y.Scale / 0.5)
	if oldN <= 0 then return end
	local newN = oldN + 1

	-- Agrandir le billboard d'une ligne
	bb.Size = UDim2.new(bb.Size.X.Scale, 0, newN * 0.5, 0)

	-- Décaler et redimensionner tous les labels existants
	-- formule : new_posY = (old_posY * oldN + 1) / newN
	for _, child in ipairs(bb:GetChildren()) do
		if child:IsA("TextLabel") then
			local oldY = child.Position.Y.Scale
			child.Position = UDim2.new(0, 0, (oldY * oldN + 1) / newN, 0)
			child.Size     = UDim2.new(1, 0, 1 / newN, 0)
		end
	end

	-- Label de mutation en haut (position 0)
	local label = Instance.new("TextLabel")
	label.Name                   = "LMutation"
	label.Text                   = info.texte
	label.Size                   = UDim2.new(1, 0, 1 / newN, 0)
	label.Position               = UDim2.new(0, 0, 0, 0)
	label.TextColor3             = info.couleur or Color3.fromRGB(255, 255, 255)
	label.TextScaled             = true
	label.Font                   = Enum.Font.GothamBold
	label.BackgroundTransparency = 1
	label.TextStrokeTransparency = 0.4
	label.TextStrokeColor3       = Color3.new(0, 0, 0)
	label.Parent                 = bb

	-- Animation arc-en-ciel pour RAINBOW
	if mutation == "RAINBOW" then
		local hue, conn = 0, nil
		conn = RunService.Heartbeat:Connect(function(dt)
			if not label or not label.Parent then conn:Disconnect() return end
			hue = (hue + dt * 0.8) % 1
			label.TextColor3 = Color3.fromHSV(hue, 1, 1)
		end)
	end
end

-- ─────────────────────────────────────────────────────────────
-- Setup par brainrot taggué
-- ─────────────────────────────────────────────────────────────

local function SetupMutationLabel(brainrot)
	-- task.wait() initial : laisser les attributs être définis (identique à PickupSystem)
	task.wait()
	if not brainrot or not brainrot.Parent then return end

	local mutation = brainrot:GetAttribute("Mutation")
	if not mutation or not INFOS_MUTATION[mutation] then return end

	local root = GetRootPart(brainrot)
	if not root then return end

	local function appliquerPatch(bb)
		-- task.wait() : laisser MakeLabel() peupler le billboard (SetupField est synchrone
		-- mais ChildAdded peut tirer avant que les labels soient parentés)
		task.wait()
		if not bb or not bb.Parent then return end
		PatcherBillboard(bb, mutation)
		Logger.debug("Spawn", "Billboard muté (%s) : %s", mutation, brainrot.Name)
	end

	local bb = root:FindFirstChild(MAIN_BILLBOARD_NAME)
	if bb then
		appliquerPatch(bb)
	else
		-- PickupSystem n'a pas encore créé le billboard → attendre ChildAdded
		local conn
		conn = root.ChildAdded:Connect(function(child)
			if child.Name == MAIN_BILLBOARD_NAME then
				conn:Disconnect()
				appliquerPatch(child)
			end
		end)
	end
end

-- ─────────────────────────────────────────────────────────────
-- Écoute CollectionService
-- ─────────────────────────────────────────────────────────────

for _, inst in ipairs(CollectionService:GetTagged(TAG)) do
	task.spawn(SetupMutationLabel, inst)
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(function(inst)
	task.spawn(SetupMutationLabel, inst)
end)

-- ─────────────────────────────────────────────────────────────
-- Watcher workspace — effet Rainbow sur les clones de slot de dépôt
--
-- Quand DropSystem dépose un brainrot, il fait modeleSource:Clone() puis
-- place le clone dans workspace. Ce clone hérite de l attribut Mutation.
-- Le spawner applique l effet via un appel explicite, mais le clone de slot
-- est un nouvel objet sans effet actif : ce watcher le détecte et l applique.
-- L appel est idempotent (Apply() ignore les modeles déjà traités).
-- ─────────────────────────────────────────────────────────────

local function appliquerRainbowSiNecessaire(desc)
	if not desc:IsA("Model") then return end
	if desc:GetAttribute("Mutation") ~= "RAINBOW" then return end
	RainbowEffect.Apply(desc)
end

-- Scan des modeles déjà présents au démarrage (cas edge : redémarrage à chaud)
for _, desc in ipairs(workspace:GetDescendants()) do
	task.spawn(appliquerRainbowSiNecessaire, desc)
end

-- Ecoute des nouveaux modeles ajoutés à workspace (clones de slot, restaurations)
workspace.DescendantAdded:Connect(function(desc)
	task.spawn(appliquerRainbowSiNecessaire, desc)
end)

Logger.info("Spawn", "✓ MutationBillboardPatcher démarré")
