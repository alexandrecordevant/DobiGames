-- ReplicatedStorage/Modules/RainbowEffect.lua
-- Effet arc-en-ciel sur les BaseParts d un modele Brainrot.
-- Utilisation : RainbowEffect.Apply(model) / RainbowEffect.Remove(model)

local RainbowEffect = {}

local RunService = game:GetService("RunService")

-- Logger optionnel (disponible cote serveur uniquement)
local Logger
do
	local ok, m = pcall(function()
		return require(game:GetService("ServerScriptService").SharedLib.Server.Logger)
	end)
	Logger = ok and m or nil
end

local function log(msg, ...)
	if Logger then Logger.debug("Rainbow", msg, ...) end
end

-- ─────────────────────────────────────────────────────────────
-- Palette et duree de transition
-- ─────────────────────────────────────────────────────────────

local RAINBOW_COLORS = {
	Color3.fromRGB(255,   0,   0),
	Color3.fromRGB(255, 100,   0),
	Color3.fromRGB(255, 255,   0),
	Color3.fromRGB(  0, 255,   0),
	Color3.fromRGB(  0, 255, 255),
	Color3.fromRGB(  0,   0, 255),
	Color3.fromRGB(255,   0, 255),
}
local NB_COULEURS    = #RAINBOW_COLORS
local TRANSITION_TIME = 1.5  -- secondes par couleur

-- ─────────────────────────────────────────────────────────────
-- Etat interne : une entree par modele actif
-- ─────────────────────────────────────────────────────────────

local effetsActifs = {}
-- effetsActifs[model] = {
--   conn              : RBXScriptConnection (Heartbeat)
--   parts             : { BasePart }
--   couleursOriginales: { [BasePart] = Color3 }
-- }

-- ─────────────────────────────────────────────────────────────
-- Utilitaires
-- ─────────────────────────────────────────────────────────────

local function collecterBaseParts(modele)
	local liste = {}
	if modele:IsA("BasePart") then
		table.insert(liste, modele)
	end
	for _, desc in ipairs(modele:GetDescendants()) do
		if desc:IsA("BasePart") then
			table.insert(liste, desc)
		end
	end
	return liste
end

-- ─────────────────────────────────────────────────────────────
-- API publique
-- ─────────────────────────────────────────────────────────────

-- Lance l effet arc-en-ciel sur toutes les BaseParts du modele.
-- Sans effet si le modele est deja traite.
function RainbowEffect.Apply(modele)
	if effetsActifs[modele] then return end

	local parts = collecterBaseParts(modele)
	if #parts == 0 then
		log("Aucune BasePart sur %s — effet ignore", modele.Name)
		return
	end

	-- Sauvegarder les couleurs d origine pour pouvoir les restaurer
	local couleursOriginales = {}
	for _, part in ipairs(parts) do
		couleursOriginales[part] = part.Color
	end

	local elapsed     = 0
	local indexCourant = 1
	local conn

	conn = RunService.Heartbeat:Connect(function(dt)
		-- Nettoyer uniquement si le modele est detruit (Parent nil)
		-- L effet doit persister en dehors de workspace (Backpack, Tool, slot)
		if not modele or not modele.Parent then
			conn:Disconnect()
			effetsActifs[modele] = nil
			return
		end

		elapsed = elapsed + dt

		-- Calculer la couleur interpolee entre la teinte courante et la suivante
		local t          = math.clamp(elapsed / TRANSITION_TIME, 0, 1)
		local indexSuivant = (indexCourant % NB_COULEURS) + 1
		local couleur    = RAINBOW_COLORS[indexCourant]:Lerp(RAINBOW_COLORS[indexSuivant], t)

		for _, part in ipairs(parts) do
			if part and part.Parent then
				part.Color = couleur
			end
		end

		-- Passer a la prochaine teinte quand la transition est terminee
		if elapsed >= TRANSITION_TIME then
			elapsed       = elapsed - TRANSITION_TIME
			indexCourant  = indexSuivant
		end
	end)

	effetsActifs[modele] = {
		conn               = conn,
		parts              = parts,
		couleursOriginales = couleursOriginales,
	}

	log("Effet applique sur %s (%d parts)", modele.Name, #parts)
end

-- Stoppe l effet et restaure les couleurs d origine.
function RainbowEffect.Remove(modele)
	local effet = effetsActifs[modele]
	if not effet then return end

	effet.conn:Disconnect()

	for part, couleur in pairs(effet.couleursOriginales) do
		if part and part.Parent then
			part.Color = couleur
		end
	end

	effetsActifs[modele] = nil
	log("Effet retire sur %s", modele.Name)
end

return RainbowEffect
