-- ServerScriptService/BaseProgressionSystem.lua
-- BrainRotFarm — Déblocage progressif des étages et spots
-- 4 étages × 10 spots par base = 40 paliers de progression par joueur

local BaseProgressionSystem = {}

-- ============================================================
-- Services
-- ============================================================
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

-- ============================================================
-- Noms des étages (ATTENTION : Floor 1 = double espace)
-- ============================================================
local FLOOR_NOMS = {
	[1] = "Floor  1",  -- double espace
	[2] = "Floor 2",
	[3] = "Floor 3",
	[4] = "Floor 4",
}

-- ============================================================
-- Seuils de déblocage
-- ============================================================
local SEUILS = {
	-- Floor 1 — spots 1 et 2 gratuits (départ)
	{ floor=1, spot=1,  coins=0,      label="Départ"         },
	{ floor=1, spot=2,  coins=0,      label="Départ"         },
	{ floor=1, spot=3,  coins=50,     label="50 coins"       },
	{ floor=1, spot=4,  coins=100,    label="100 coins"      },
	{ floor=1, spot=5,  coins=200,    label="200 coins"      },
	{ floor=1, spot=6,  coins=350,    label="350 coins"      },
	{ floor=1, spot=7,  coins=500,    label="500 coins"      },
	{ floor=1, spot=8,  coins=750,    label="750 coins"      },
	{ floor=1, spot=9,  coins=1000,   label="1 000 coins"    },
	{ floor=1, spot=10, coins=1500,   label="1 500 coins"    },
	-- Floor 2
	{ floor=2, spot=1,  coins=2000,   label="Étage 2"        },
	{ floor=2, spot=2,  coins=2500,   label="2 500 coins"    },
	{ floor=2, spot=3,  coins=3000,   label="3 000 coins"    },
	{ floor=2, spot=4,  coins=3500,   label="3 500 coins"    },
	{ floor=2, spot=5,  coins=4000,   label="4 000 coins"    },
	{ floor=2, spot=6,  coins=5000,   label="5 000 coins"    },
	{ floor=2, spot=7,  coins=6000,   label="6 000 coins"    },
	{ floor=2, spot=8,  coins=7000,   label="7 000 coins"    },
	{ floor=2, spot=9,  coins=8000,   label="8 000 coins"    },
	{ floor=2, spot=10, coins=10000,  label="10 000 coins"   },
	-- Floor 3
	{ floor=3, spot=1,  coins=15000,  label="Étage 3"        },
	{ floor=3, spot=2,  coins=18000,  label="18 000 coins"   },
	{ floor=3, spot=3,  coins=21000,  label="21 000 coins"   },
	{ floor=3, spot=4,  coins=25000,  label="25 000 coins"   },
	{ floor=3, spot=5,  coins=30000,  label="30 000 coins"   },
	{ floor=3, spot=6,  coins=35000,  label="35 000 coins"   },
	{ floor=3, spot=7,  coins=40000,  label="40 000 coins"   },
	{ floor=3, spot=8,  coins=45000,  label="45 000 coins"   },
	{ floor=3, spot=9,  coins=50000,  label="50 000 coins"   },
	{ floor=3, spot=10, coins=60000,  label="60 000 coins"   },
	-- Floor 4
	{ floor=4, spot=1,  coins=80000,  label="Étage 4"        },
	{ floor=4, spot=2,  coins=90000,  label="90 000 coins"   },
	{ floor=4, spot=3,  coins=100000, label="100 000 coins"  },
	{ floor=4, spot=4,  coins=120000, label="120 000 coins"  },
	{ floor=4, spot=5,  coins=140000, label="140 000 coins"  },
	{ floor=4, spot=6,  coins=160000, label="160 000 coins"  },
	{ floor=4, spot=7,  coins=180000, label="180 000 coins"  },
	{ floor=4, spot=8,  coins=200000, label="200 000 coins"  },
	{ floor=4, spot=9,  coins=250000, label="250 000 coins"  },
	{ floor=4, spot=10, coins=300000, label="300 000 coins"  },
}

-- ============================================================
-- État interne par joueur
-- ============================================================
-- { baseIndex, playerData, progression, spotsActifs, baseFolder }
local donneesJoueurs = {}

-- ============================================================
-- Utilitaires
-- ============================================================

-- BaseParts de la structure d'un floor (hors spot_X)
local function obtenirPartsStructure(floorObj)
	local parts = {}
	-- Floor 1 est lui-même une BasePart
	if floorObj:IsA("BasePart") then
		table.insert(parts, floorObj)
	end
	for _, child in ipairs(floorObj:GetChildren()) do
		if not child.Name:match("^spot_") then
			if child:IsA("BasePart") then
				table.insert(parts, child)
			end
			for _, v in ipairs(child:GetDescendants()) do
				if v:IsA("BasePart") then table.insert(parts, v) end
			end
		end
	end
	return parts
end

-- Tous les BaseParts d'un spot (inclut TouchPart et Part visuel)
local function obtenirPartsSpot(spotModel)
	local parts = {}
	for _, v in ipairs(spotModel:GetDescendants()) do
		if v:IsA("BasePart") then table.insert(parts, v) end
	end
	if spotModel:IsA("BasePart") then table.insert(parts, spotModel) end
	return parts
end

-- Ajoute un TouchPart à spotsActifs sans doublon
local function ajouterSpotActif(spotsActifs, touchPart)
	for _, tp in ipairs(spotsActifs) do
		if tp == touchPart then return end
	end
	table.insert(spotsActifs, touchPart)
end

-- Retire un TouchPart de spotsActifs
local function retirerSpotActif(spotsActifs, touchPart)
	for i, tp in ipairs(spotsActifs) do
		if tp == touchPart then
			table.remove(spotsActifs, i)
			return
		end
	end
end

-- Normalise un nom pour comparaison tolérante (espaces/underscore/casse ignorés)
local function normaliserNom(nom)
	if type(nom) ~= "string" then return "" end
	return string.lower((nom:gsub("[%s_%-]", "")))
end

-- Recherche d'un floor avec fallback tolérant (exact, direct child, descendants)
local function trouverFloor(baseFolder, floorNum)
	if not baseFolder then return nil end

	local nomExact = FLOOR_NOMS[floorNum]
	if nomExact then
		local direct = baseFolder:FindFirstChild(nomExact)
		if direct then return direct end
	end

	-- Compatibilité: "Floor1", "Floor_1", "floor 1", etc.
	local cible = "floor" .. tostring(floorNum)
	for _, child in ipairs(baseFolder:GetChildren()) do
		if normaliserNom(child.Name) == cible then
			return child
		end
	end
	for _, desc in ipairs(baseFolder:GetDescendants()) do
		if normaliserNom(desc.Name) == cible then
			return desc
		end
	end
	return nil
end

-- Recherche d'un spot avec fallback tolérant (spot_1, Spot 1, spot-1, etc.)
local function trouverSpot(floorObj, spotNum)
	if not floorObj then return nil end

	local nomExact = "spot_" .. tostring(spotNum)
	local direct = floorObj:FindFirstChild(nomExact)
	if direct then return direct end

	local cible = "spot" .. tostring(spotNum)
	for _, child in ipairs(floorObj:GetChildren()) do
		if normaliserNom(child.Name) == cible then
			return child
		end
	end
	for _, desc in ipairs(floorObj:GetDescendants()) do
		if normaliserNom(desc.Name) == cible then
			return desc
		end
	end
	return nil
end

-- Score un conteneur de base selon le nombre de floors/spots détectés.
-- Permet de choisir automatiquement la bonne racine visuelle (Base_1 ou Base_1/Base).
local function scorerConteneurBase(container)
	if not container then
		return -1, 0, 0
	end
	local floorsTrouves = 0
	local spotsTrouves = 0
	for floorNum = 1, 4 do
		local floorObj = trouverFloor(container, floorNum)
		if floorObj then
			floorsTrouves += 1
			for spotNum = 1, 10 do
				if trouverSpot(floorObj, spotNum) then
					spotsTrouves += 1
				end
			end
		end
	end
	-- Priorité au nombre de spots, puis floors
	return (spotsTrouves * 100 + floorsTrouves), floorsTrouves, spotsTrouves
end

-- Notifications
local function notifierJoueur(player, typeNotif, message)
	local ev = ReplicatedStorage:FindFirstChild("NotifEvent")
	if ev then pcall(function() ev:FireClient(player, typeNotif, message) end) end
end

local function notifierTous(typeNotif, message)
	local ev = ReplicatedStorage:FindFirstChild("NotifEvent")
	if ev then pcall(function() ev:FireAllClients(typeNotif, message) end) end
	print("[BaseProgression] " .. message)
end

-- ============================================================
-- Visuels — billboard de verrouillage
-- ============================================================

local function creerBillboardLock(spotModel, label)
	-- Chercher la Part de référence pour l'ancre
	local ancre = spotModel:FindFirstChild("TouchPart")
	if not ancre then ancre = spotModel:FindFirstChildWhichIsA("BasePart") end
	if not ancre then return end

	-- Supprimer l'ancien billboard si présent
	local ancien = ancre:FindFirstChild("LockBillboard")
	if ancien then ancien:Destroy() end

	local bb = Instance.new("BillboardGui")
	bb.Name        = "LockBillboard"
	bb.Size        = UDim2.new(0, 160, 0, 60)
	bb.StudsOffset = Vector3.new(0, 4, 0)
	bb.AlwaysOnTop = false
	bb.Adornee     = ancre
	bb.Parent      = ancre

	local cadre = Instance.new("Frame")
	cadre.Size                   = UDim2.new(1, 0, 1, 0)
	cadre.BackgroundColor3       = Color3.fromRGB(80, 0, 0)
	cadre.BackgroundTransparency = 0.3
	cadre.BorderSizePixel        = 0
	cadre.Parent                 = bb

	Instance.new("UICorner", cadre).CornerRadius = UDim.new(0, 6)

	local lblLock = Instance.new("TextLabel")
	lblLock.Size                   = UDim2.new(1, 0, 0.5, 0)
	lblLock.Position               = UDim2.new(0, 0, 0, 0)
	lblLock.BackgroundTransparency = 1
	lblLock.Text                   = "🔒 Verrouillé"
	lblLock.Font                   = Enum.Font.GothamBold
	lblLock.TextColor3             = Color3.new(1, 1, 1)
	lblLock.TextScaled             = true
	lblLock.Parent                 = cadre

	local lblCoins = Instance.new("TextLabel")
	lblCoins.Size                   = UDim2.new(1, 0, 0.5, 0)
	lblCoins.Position               = UDim2.new(0, 0, 0.5, 0)
	lblCoins.BackgroundTransparency = 1
	lblCoins.Text                   = "💰 " .. label
	lblCoins.Font                   = Enum.Font.GothamBold
	lblCoins.TextColor3             = Color3.new(1, 1, 1)
	lblCoins.TextScaled             = true
	lblCoins.Parent                 = cadre
end

local function supprimerBillboardLock(spotModel)
	local ancre = spotModel:FindFirstChild("TouchPart")
	if not ancre then ancre = spotModel:FindFirstChildWhichIsA("BasePart") end
	if not ancre then return end
	local bb = ancre:FindFirstChild("LockBillboard")
	if bb then bb:Destroy() end
end

-- ============================================================
-- Visuels — états spot
-- ============================================================

-- Applique l'état verrouillé (semi-transparent, CanTouch=false, billboard)
local function appliquerEtatVerrouille(spotModel, seuil)
	local parts = obtenirPartsSpot(spotModel)
	for _, part in ipairs(parts) do
		pcall(function() part.Transparency = 0.7 end)
	end
	local touchPart = spotModel:FindFirstChild("TouchPart")
	if touchPart then
		pcall(function() touchPart.CanTouch = false end)
	end
	creerBillboardLock(spotModel, seuil.label)
end

-- Applique l'état débloqué (visible, CanTouch=true, pas de billboard)
local function appliquerEtatDebloque(spotModel, spotsActifs)
	local parts = obtenirPartsSpot(spotModel)
	for _, part in ipairs(parts) do
		pcall(function() part.Transparency = 0; part.CanCollide = true end)
	end
	local touchPart = spotModel:FindFirstChild("TouchPart")
	if touchPart then
		pcall(function() touchPart.CanTouch = true end)
		if spotsActifs then
			ajouterSpotActif(spotsActifs, touchPart)
		end
	end
	supprimerBillboardLock(spotModel)
end

-- ============================================================
-- Visuels — gestion d'un étage entier
-- ============================================================

-- Cache tout un étage (floors 2-4 non encore débloqués)
-- Tous les BaseParts → invisible + non-collidable (évite l'interaction avec parties invisibles)
local function cacherEtage(floorObj)
	if floorObj:IsA("BasePart") then
		pcall(function() floorObj.Transparency = 1; floorObj.CanCollide = false end)
	end
	for _, v in ipairs(floorObj:GetDescendants()) do
		if v:IsA("BasePart") then
			pcall(function() v.Transparency = 1; v.CanCollide = false end)
		elseif v:IsA("ProximityPrompt") or v:IsA("ClickDetector") then
			pcall(function() v.Enabled = false end)
		end
	end
end

-- Rend visibles les parts de structure d'un floor (hors spots)
local function afficherStructure(floorObj)
	local partsStructure = obtenirPartsStructure(floorObj)
	for _, part in ipairs(partsStructure) do
		pcall(function() part.Transparency = 0; part.CanCollide = true end)
	end
	-- Réactiver les ProximityPrompts/ClickDetectors de la structure
	for _, v in ipairs(floorObj:GetDescendants()) do
		if not v.Name:match("^spot_") then
			if v:IsA("ProximityPrompt") or v:IsA("ClickDetector") then
				pcall(function() v.Enabled = true end)
			end
		end
	end
end

-- Fade in de la structure d'un étage en 2 secondes
local function fadeInStructure(floorObj, onFin)
	local parts = obtenirPartsStructure(floorObj)
	if #parts == 0 then
		if onFin then task.spawn(onFin) end
		return
	end
	-- Restaurer la collision immédiatement (avant le fade pour éviter le fantôme)
	for _, part in ipairs(parts) do
		pcall(function() part.CanCollide = true end)
	end
	-- Réactiver les ProximityPrompts/ClickDetectors de la structure
	for _, v in ipairs(floorObj:GetDescendants()) do
		if not v.Name:match("^spot_") then
			if v:IsA("ProximityPrompt") or v:IsA("ClickDetector") then
				pcall(function() v.Enabled = true end)
			end
		end
	end
	local tweenInfo = TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local termine   = 0
	local total     = #parts
	for _, part in ipairs(parts) do
		if part and part.Parent then
			local t = TweenService:Create(part, tweenInfo, { Transparency = 0 })
			t.Completed:Connect(function()
				termine += 1
				if termine >= total and onFin then onFin() end
			end)
			t:Play()
		else
			termine += 1
			if termine >= total and onFin then onFin() end
		end
	end
end

-- Particules dorées au déblocage d'un étage
local function effetDeblocageEtage(position)
	local ancre = Instance.new("Part")
	ancre.Anchored     = true
	ancre.CanCollide   = false
	ancre.Transparency = 1
	ancre.Size         = Vector3.new(1, 1, 1)
	ancre.Position     = position
	ancre.Parent       = Workspace

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0,   Color3.fromRGB(255, 215,   0)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 150)),
		ColorSequenceKeypoint.new(1,   Color3.fromRGB(255, 180,   0)),
	})
	emitter.LightEmission = 0.8
	emitter.Rate          = 80
	emitter.Lifetime      = NumberRange.new(1.5, 3)
	emitter.Speed         = NumberRange.new(8, 15)
	emitter.SpreadAngle   = Vector2.new(70, 70)
	emitter.Size          = NumberSequence.new(0.4)
	emitter.Parent        = ancre

	task.delay(3, function()
		emitter.Enabled = false
		task.delay(3, function() ancre:Destroy() end)
	end)
end

-- ============================================================
-- Déblocage d'un étage entier (quand spot=1 d'un floor>1 s'ouvre)
-- ============================================================

local function debloquerEtage(player, dd, floorNum, floorObj)
	-- Fade in de la structure
	fadeInStructure(floorObj, nil)

	-- Particules au centre de l'étage
	local racineFloor = nil
	if floorObj:IsA("BasePart") then
		racineFloor = floorObj
	else
		racineFloor = floorObj:FindFirstChildWhichIsA("BasePart")
	end
	if racineFloor then
		effetDeblocageEtage(racineFloor.Position + Vector3.new(0, 5, 0))
	end

	-- spot_1 → débloqué
	local spot1 = trouverSpot(floorObj, 1)
	if spot1 then appliquerEtatDebloque(spot1, dd.spotsActifs) end

	-- spot_2 à spot_10 → verrouillés (maintenant visibles à 0.7)
	for _, seuil in ipairs(SEUILS) do
		if seuil.floor == floorNum and seuil.spot > 1 then
			local spotObj = trouverSpot(floorObj, seuil.spot)
			if spotObj then
				local cle = seuil.floor .. "_" .. seuil.spot
				if dd.progression[cle] then
					-- Déjà débloqué (cas rare : déblocage en cascade)
					appliquerEtatDebloque(spotObj, dd.spotsActifs)
				else
					appliquerEtatVerrouille(spotObj, seuil)
				end
			end
		end
	end

	-- Notifications
	notifierJoueur(player, "INFO", "🎉 Étage " .. floorNum .. " débloqué !")
	notifierTous("INFO", "🏗️ " .. player.Name .. " a débloqué l'Étage " .. floorNum .. " !")
end

-- ============================================================
-- Déblocage d'un spot individuel
-- ============================================================

local function debloquerSpotIndividuel(dd, floorObj, seuil)
	local spotObj = trouverSpot(floorObj, seuil.spot)
	if not spotObj then return end
	appliquerEtatDebloque(spotObj, dd.spotsActifs)
end

-- ============================================================
-- Vérification des déblocages (appelé à chaque changement de coins)
-- ============================================================

function BaseProgressionSystem.VerifierDeblocages(player, coinsActuels)
	local dd = donneesJoueurs[player.UserId]
	if not dd then return end

	for _, seuil in ipairs(SEUILS) do
		local cle = seuil.floor .. "_" .. seuil.spot
		if not dd.progression[cle] and coinsActuels >= seuil.coins then
			dd.progression[cle] = true

			local floorObj = trouverFloor(dd.baseFolder, seuil.floor)
			if not floorObj then continue end

			if seuil.spot == 1 and seuil.floor > 1 then
				-- Premier spot d'un étage supérieur → déblocage complet de l'étage
				debloquerEtage(player, dd, seuil.floor, floorObj)
			else
				-- Spot individuel
				debloquerSpotIndividuel(dd, floorObj, seuil)
			end
		end
	end
end

-- ============================================================
-- Init — applique l'état visuel complet de la base d'un joueur
-- ============================================================

function BaseProgressionSystem.Init(player, baseIndex, playerData)
	-- Initialiser la progression si absente (nouveau joueur)
	if not playerData.progression then
		playerData.progression = {}
	end

	-- Débloquer les spots de départ (coins = 0) pour tout nouveau joueur
	for _, seuil in ipairs(SEUILS) do
		if seuil.coins == 0 then
			local cle = seuil.floor .. "_" .. seuil.spot
			if not playerData.progression[cle] then
				playerData.progression[cle] = true
			end
		end
	end

	-- Récupérer la base dans le Workspace
	local bases = Workspace:FindFirstChild("Bases")
	if not bases then
		warn("[BaseProgressionSystem] Workspace.Bases introuvable")
		return
	end
	local baseRoot = bases:FindFirstChild("Base_" .. baseIndex)
	if not baseRoot then
		warn("[BaseProgressionSystem] Base_" .. baseIndex .. " introuvable")
		return
	end
	local candidatBase = baseRoot:FindFirstChild("Base")
	local scoreRoot, floorsRoot, spotsRoot = scorerConteneurBase(baseRoot)
	local scoreBase, floorsBase, spotsBase = scorerConteneurBase(candidatBase)

	local baseFolder = nil
	if scoreBase >= scoreRoot then
		baseFolder = candidatBase
	else
		baseFolder = baseRoot
	end

	if not baseFolder or math.max(scoreBase, scoreRoot) <= 0 then
		warn("[BaseProgressionSystem] Aucun conteneur valide trouvé pour Base_" .. baseIndex .. " (floors/spots introuvables)")
		return
	end

	donneesJoueurs[player.UserId] = {
		baseIndex   = baseIndex,
		playerData  = playerData,
		progression = playerData.progression,
		spotsActifs = {},
		baseFolder  = baseFolder,
	}
	local dd = donneesJoueurs[player.UserId]

	-- Appliquer l'état visuel pour chaque étage
	for floorNum = 1, 4 do
		local floorObj = trouverFloor(baseFolder, floorNum)
		if not floorObj then continue end

		local cleEtage = floorNum .. "_1"
		local etageDebloque = (dd.progression[cleEtage] == true)

		if not etageDebloque and floorNum > 1 then
			-- Étage non débloqué → tout invisible, CanTouch=false
			cacherEtage(floorObj)
		else
			-- Étage débloqué → structure visible, spots selon état individuel
			afficherStructure(floorObj)

			for _, seuil in ipairs(SEUILS) do
				if seuil.floor == floorNum then
					local spotObj = trouverSpot(floorObj, seuil.spot)
					if spotObj then
						local cle = seuil.floor .. "_" .. seuil.spot
						if dd.progression[cle] then
							appliquerEtatDebloque(spotObj, dd.spotsActifs)
						else
							appliquerEtatVerrouille(spotObj, seuil)
						end
					end
				end
			end
		end
	end

	print(string.format(
		"[BaseProgressionSystem] %s → Base_%d initialisée (%d spots actifs) [root=%dF/%dS, base=%dF/%dS, cible=%s]",
		player.Name,
		baseIndex,
		#dd.spotsActifs,
		floorsRoot, spotsRoot,
		floorsBase, spotsBase,
		baseFolder.Name
	))
end

-- ============================================================
-- API publique
-- ============================================================

-- Retourne la liste des TouchParts actifs du joueur (pour DropSystem)
function BaseProgressionSystem.GetSpotsActifs(player)
	local dd = donneesJoueurs[player.UserId]
	return dd and dd.spotsActifs or {}
end

-- Réinitialise les données du joueur (à appeler à la déconnexion)
function BaseProgressionSystem.Reset(player)
	donneesJoueurs[player.UserId] = nil
end

return BaseProgressionSystem
