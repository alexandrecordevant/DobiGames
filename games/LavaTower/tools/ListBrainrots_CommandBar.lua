-- ============================================================
-- LIST BRAINROTS — LAVA TOWER
-- Coller dans : Studio > View > Command Bar
-- Liste tous les brainrots de ReplicatedStorage.Brainrots
-- avec leur rareté, nom et attribut CashParSeconde.
-- ============================================================

local RS = game:GetService("ReplicatedStorage")
local root = RS:FindFirstChild("Brainrots")
if not root then
	warn("[ListBrainrots] Dossier 'Brainrots' introuvable dans ReplicatedStorage !")
	return
end

-- Ordre d'affichage des raretés
local ORDRE_RARETE = { "COMMON", "RARE", "EPIC", "LEGENDARY", "MYTHIC", "GOD", "SECRET", "OG", "ToUseAfter" }

local totalBrainrots = 0
local totalFolders   = 0
local lines = {}

local function listFolder(folder, indent)
	local children = folder:GetChildren()
	-- Trier alphabétiquement
	table.sort(children, function(a, b) return a.Name < b.Name end)

	for _, child in ipairs(children) do
		if child:IsA("Folder") then
			-- Sous-dossier (ex: SECRET/1, SECRET/2…)
			totalFolders += 1
			local subCount = #child:GetChildren()
			table.insert(lines, indent .. "📁 [" .. child.Name .. "] (" .. subCount .. " brainrots)")
			listFolder(child, indent .. "   ")
		else
			-- Modèle brainrot
			totalBrainrots += 1
			local cps = child:GetAttribute("CashParSeconde")
			local cpsStr = cps and (" | CPS=" .. tostring(cps)) or ""
			table.insert(lines, indent .. "• " .. child.Name .. cpsStr)
		end
	end
end

-- Afficher dans l'ordre défini
local seen = {}
for _, rarete in ipairs(ORDRE_RARETE) do
	local folder = root:FindFirstChild(rarete)
	if folder then
		seen[rarete] = true
		local count = #folder:GetDescendants()
		table.insert(lines, "\n══ " .. rarete .. " ══")
		listFolder(folder, "  ")
	end
end

-- Raretés non listées dans ORDRE_RARETE (fallback)
for _, folder in ipairs(root:GetChildren()) do
	if folder:IsA("Folder") and not seen[folder.Name] then
		table.insert(lines, "\n══ " .. folder.Name .. " (extra) ══")
		listFolder(folder, "  ")
	end
end

-- Résumé
table.insert(lines, "\n────────────────────────────────")
table.insert(lines, "Total brainrots : " .. totalBrainrots)

print(table.concat(lines, "\n"))
