-- StarterPlayerScripts/OnboardingArrow.client.lua
-- Flèche 3D onboarding + message HUD + célébration premier dépôt
-- Actif uniquement sur la première session (sessionsCount == 1 et non complété)

local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local UpdateHUD       = RS:WaitForChild("UpdateHUD")
local OnboardingEvent = RS:WaitForChild("OnboardingEvent")

local arrowActive = false
local _fermerLienBase = nil  -- fermeture du lien étape 1 (joueur → base), fermé au 1er dépôt

-- Base réellement assignée au joueur (reçue via AssignBase) — fiable, contrairement
-- à la proximité qui pouvait viser la base d'un autre joueur.
local _baseIndex = nil
task.spawn(function()
    local AssignBase = RS:WaitForChild("AssignBase", 20)
    if AssignBase then
        AssignBase.OnClientEvent:Connect(function(idx) _baseIndex = idx end)
    end
end)

-- Message HUD top-center (3s puis fade)
local function afficherMessageHUD(texte)
    local sg = Instance.new("ScreenGui")
    sg.Name              = "OnboardingMsg"
    sg.ResetOnSpawn      = false
    sg.ZIndexBehavior    = Enum.ZIndexBehavior.Sibling
    sg.DisplayOrder      = 30
    sg.IgnoreGuiInset    = true
    sg.Parent            = playerGui

    local lbl = Instance.new("TextLabel", sg)
    lbl.Size                   = UDim2.new(0.5, 0, 0, 56)
    lbl.Position               = UDim2.new(0.25, 0, 0.08, 0)
    lbl.BackgroundColor3       = Color3.fromRGB(20, 20, 20)
    lbl.BackgroundTransparency = 0.25
    lbl.TextColor3             = Color3.fromRGB(255, 220, 50)
    lbl.Font                   = Enum.Font.GothamBold
    lbl.TextSize               = 20
    lbl.Text                   = texte
    lbl.TextWrapped            = true
    lbl.ZIndex                 = 10
    lbl.BorderSizePixel        = 0
    Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 10)

    task.delay(2.5, function()
        if not sg.Parent then return end
        TweenService:Create(lbl, TweenInfo.new(0.7, Enum.EasingStyle.Quad), {
            TextTransparency       = 1,
            BackgroundTransparency = 1,
        }):Play()
        task.delay(0.8, function()
            if sg.Parent then sg:Destroy() end
        end)
    end)
end

-- ============================================================
-- Helpers liens 3D (Beam joueur → part cible) — partagés étapes 1 & 3
-- ============================================================
-- BasePart la plus proche du joueur pour un objet nommé dans Base_*/Specific
local function trouverPartProche(nomDansSpecific)
    local bases = workspace:FindFirstChild("Bases")
    local char  = player.Character
    local hrp   = char and char:FindFirstChild("HumanoidRootPart")
    if not bases or not hrp then return nil end
    local meilleur, meilleureDist = nil, math.huge
    for _, base in ipairs(bases:GetChildren()) do
        local specific = base:FindFirstChild("Specific")
        local obj      = specific and specific:FindFirstChild(nomDansSpecific)
        local part     = obj and (obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart", true))
        if part then
            local d = (part.Position - hrp.Position).Magnitude
            if d < meilleureDist then meilleureDist = d ; meilleur = part end
        end
    end
    return meilleur
end

-- Crée un lien (Beam + flèche flottante "label") entre le joueur et targetPart.
-- Se ferme à l'approche (<proximite studs), au timeout (dureeMax s), ou via la
-- fonction de fermeture retournée (appelée par un déclencheur externe).
-- hauteur (optionnel) : studs au-dessus du SOMMET de la part où finit le beam.
--   ~2 pour un objet haut (pot), 0 pour une cible au sol (spot de dépôt).
local function creerLienVers(targetPart, labelTexte, proximite, dureeMax, hauteur)
    local char = player.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp or not targetPart then return function() end end
    hauteur = hauteur or 2

    local instances = {}
    local fini = false
    local function fermer()
        if fini then return end
        fini = true
        for _, inst in ipairs(instances) do
            if inst and inst.Parent then pcall(function() inst:Destroy() end) end
        end
        instances = {}
    end

    local a0 = Instance.new("Attachment")
    a0.Name   = "OnboardLinkStart"
    a0.Parent = hrp

    local sommet = targetPart.Size.Y / 2  -- du centre de la part à son sommet
    -- hauteur>0 : ancrage au-dessus du sommet (objet haut, ex. pot)
    -- hauteur<=0 : ancrage au BAS de la part (= au sol), peu importe son épaisseur
    local ancreY = (hauteur > 0) and (sommet + hauteur) or (-sommet + 0.3)
    local a1 = Instance.new("Attachment")
    a1.Name     = "OnboardLinkEnd"
    a1.Position = Vector3.new(0, ancreY, 0)
    a1.Parent   = targetPart

    local beam = Instance.new("Beam")
    beam.Name          = "OnboardingLinkBeam"
    beam.Attachment0   = a0
    beam.Attachment1   = a1
    beam.Width0        = 1.4
    beam.Width1        = 1.4
    beam.FaceCamera    = true
    beam.Color         = ColorSequence.new(Color3.fromRGB(255, 220, 50))
    beam.Transparency  = NumberSequence.new(0.1)
    beam.LightEmission = 1
    beam.Texture       = "rbxassetid://446111271"  -- chevrons défilants (remplaçable)
    beam.TextureMode   = Enum.TextureMode.Wrap
    beam.TextureLength = 5
    beam.TextureSpeed  = 1.5  -- défile du joueur vers la cible
    beam.CurveSize0    = 6
    beam.CurveSize1    = 6
    beam.Parent        = hrp

    -- Flèche flottante + label au-dessus de la cible
    local bb = Instance.new("BillboardGui")
    bb.Name        = "OnboardLinkArrow"
    bb.Size        = UDim2.new(0, 130, 0, 95)
    bb.StudsOffset = Vector3.new(0, ancreY + 3, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 200
    bb.Parent      = targetPart

    local fl = Instance.new("TextLabel", bb)
    fl.Size                   = UDim2.new(1, 0, 0.55, 0)
    fl.BackgroundTransparency = 1
    fl.Text                   = "⬇"
    fl.Font                   = Enum.Font.GothamBold
    fl.TextColor3             = Color3.fromRGB(255, 220, 50)
    fl.TextScaled             = true
    fl.TextStrokeTransparency = 0
    fl.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
    local txt = Instance.new("TextLabel", bb)
    txt.Size                   = UDim2.new(1, 0, 0.45, 0)
    txt.Position               = UDim2.new(0, 0, 0.55, 0)
    txt.BackgroundTransparency = 1
    txt.Text                   = labelTexte
    txt.Font                   = Enum.Font.GothamBold
    txt.TextColor3             = Color3.fromRGB(255, 255, 255)
    txt.TextScaled             = true
    txt.TextStrokeTransparency = 0.2
    txt.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
    TweenService:Create(bb,
        TweenInfo.new(0.65, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { StudsOffset = Vector3.new(0, ancreY + 5, 0) }
    ):Play()

    instances = { beam, a0, a1, bb }

    -- Fermeture auto : approche du joueur, ou timeout
    task.spawn(function()
        while not fini do
            local h = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if not h or not targetPart.Parent then break end
            if (h.Position - targetPart.Position).Magnitude < proximite then break end
            task.wait(0.5)
        end
        fermer()
    end)
    task.delay(dureeMax, fermer)

    return fermer
end

-- Racine de la base assignée au joueur (workspace.Bases.Base_<idx>)
local function getBaseRoot()
    local bases = workspace:FindFirstChild("Bases")
    if not bases or not _baseIndex then return nil end
    return bases:FindFirstChild("Base_" .. tostring(_baseIndex))
end

-- BasePart représentative d'un objet (BasePart direct, TouchPart, ou 1er descendant)
local function partDe(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj end
    return obj:FindFirstChild("TouchPart")
        or obj:FindFirstChildWhichIsA("BasePart", true)
end

-- FlowerPot_1 de la base ASSIGNÉE (fallback proximité si baseIndex pas encore reçu)
local function trouverFlowerPot1()
    local base = getBaseRoot()
    if base then
        local specific = base:FindFirstChild("Specific")
        local part = partDe(specific and specific:FindFirstChild("FlowerPot_1"))
        if part then return part end
    end
    return trouverPartProche("FlowerPot_1")
end

-- Spot de dépôt de la base ASSIGNÉE le plus PROCHE du joueur (au sol, atteignable).
-- Les bases ont des étages empilés verticalement → on ne peut pas prendre "le 1er
-- spot_1" (souvent en hauteur). On prend donc le spot le plus proche du joueur.
local function trouverSpotDepot()
    local base = getBaseRoot()
    local char = player.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if base and hrp then
        local meilleur, meilleureDist = nil, math.huge
        for _, d in ipairs(base:GetDescendants()) do
            if string.lower(d.Name):match("^spot[_ ]?%d") then
                local part = partDe(d)
                if part then
                    local dist = (part.Position - hrp.Position).Magnitude
                    if dist < meilleureDist then meilleureDist = dist ; meilleur = part end
                end
            end
        end
        if meilleur then return meilleur end
    end
    return trouverPartProche("SpawnZone")
end

-- ============================================================
-- Étape 4 onboarding : message final d'ouverture au jeu
-- Déclenché une fois la 1re graine plantée → invite à remplir sa base
-- de Mutants et à récolter des graines sur les Arbres Sacrés.
-- ============================================================
local function messageFinalOuverture()
    local sg = Instance.new("ScreenGui")
    sg.Name           = "OnboardingFinalMsg"
    sg.ResetOnSpawn   = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.DisplayOrder   = 30
    sg.IgnoreGuiInset = true
    sg.Parent         = playerGui

    local lbl = Instance.new("TextLabel", sg)
    lbl.Size                   = UDim2.new(0.6, 0, 0, 74)
    lbl.Position               = UDim2.new(0.2, 0, 0.07, 0)
    lbl.BackgroundColor3       = Color3.fromRGB(20, 20, 20)
    lbl.BackgroundTransparency = 0.2
    lbl.TextColor3             = Color3.fromRGB(255, 220, 50)
    lbl.Font                   = Enum.Font.GothamBold
    lbl.TextSize               = 18
    lbl.RichText               = true
    lbl.TextWrapped            = true
    lbl.Text                   = "🎉 Your first <b>MUTANT</b> is growing! Now <b>fill your base with Mutants</b> and grab more seeds from the <b>Sacred Trees 🌳</b> out in the field!"
    lbl.BorderSizePixel        = 0
    lbl.ZIndex                 = 10
    Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 10)

    task.delay(6, function()
        if not sg.Parent then return end
        TweenService:Create(lbl, TweenInfo.new(0.8, Enum.EasingStyle.Quad), {
            TextTransparency       = 1,
            BackgroundTransparency = 1,
        }):Play()
        task.delay(0.9, function() if sg.Parent then sg:Destroy() end end)
    end)
end

-- ============================================================
-- Gros compteur au-dessus du pot : décompte le temps TOTAL jusqu'au Mutant prêt.
-- total = 5 × dureeStage (cohérent avec le billboard de statut existant, qui
-- bascule "Ready!" à etape>=5). S'auto-détruit une fois prêt.
-- ============================================================
local function creerGrosCompteur(potPart, plantedAt, dureeStage)
    if not potPart or not plantedAt or not dureeStage then return end
    local cible = plantedAt + 5 * dureeStage

    -- Éviter les doublons (re-fire éventuel de l'event)
    local ancien = potPart:FindFirstChild("OnboardGrowCountdown")
    if ancien then ancien:Destroy() end

    local bb = Instance.new("BillboardGui")
    bb.Name        = "OnboardGrowCountdown"
    bb.Size        = UDim2.new(0, 260, 0, 110)
    bb.StudsOffset = Vector3.new(0, potPart.Size.Y / 2 + 13, 0)  -- au-dessus du billboard de statut
    bb.AlwaysOnTop = true
    bb.MaxDistance = 250
    bb.Parent      = potPart

    local lbl = Instance.new("TextLabel", bb)
    lbl.Size                   = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font                   = Enum.Font.GothamBold
    lbl.TextColor3             = Color3.fromRGB(255, 220, 50)
    lbl.TextStrokeTransparency = 0
    lbl.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
    lbl.TextScaled             = true
    lbl.Text                   = "🌱 Mutant in ..."

    task.spawn(function()
        while bb.Parent and potPart.Parent do
            local restant = cible - os.time()
            if restant <= 0 then break end
            local m = math.floor(restant / 60)
            local s = restant % 60
            lbl.Text = string.format("🌱 Mutant in %d:%02d", m, s)
            task.wait(1)
        end
        if bb.Parent then
            lbl.Text       = "✨ MUTANT READY! ✨"
            lbl.TextColor3 = Color3.fromRGB(120, 255, 120)
            task.delay(6, function() if bb.Parent then bb:Destroy() end end)
        end
    end)
end

-- ============================================================
-- Étape 3 onboarding : guider vers la Daily Seed (free Mutant à venir)
-- Flèche 2D clignotante pointant sur le bouton DailySeedButton (HUD gauche)
-- + bannière explicative. Disparaît au clic sur le bouton ou après timeout.
-- ============================================================
local function guiderVersDailySeed()
    -- Localiser le bouton Daily Seed dans le FlowerPotHUD
    local fpGui    = playerGui:WaitForChild("FlowerPotHUD", 10)
    local dailyBtn = fpGui and fpGui:WaitForChild("DailySeedButton", 10)

    local sg = Instance.new("ScreenGui")
    sg.Name           = "OnboardingSeedGuide"
    sg.ResetOnSpawn   = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.DisplayOrder   = 30
    sg.IgnoreGuiInset = true
    sg.Parent         = playerGui

    -- Bannière haut-centre (persistante)
    local banner = Instance.new("TextLabel", sg)
    banner.Size                   = UDim2.new(0.6, 0, 0, 74)
    banner.Position               = UDim2.new(0.2, 0, 0.07, 0)
    banner.BackgroundColor3       = Color3.fromRGB(20, 20, 20)
    banner.BackgroundTransparency = 0.2
    banner.TextColor3             = Color3.fromRGB(255, 220, 50)
    banner.Font                   = Enum.Font.GothamBold
    banner.TextSize               = 18
    banner.RichText               = true
    banner.TextWrapped            = true
    banner.Text                   = "🌱 Tap the SEED button on the LEFT to claim your <b>FREE seed</b>!\nPlant it → a <b>FREE MUTANT</b> brainrot grows in minutes, worth WAY more! 🤑"
    banner.BorderSizePixel        = 0
    banner.ZIndex                 = 10
    Instance.new("UICorner", banner).CornerRadius = UDim.new(0, 10)

    -- Flèche 👈 ancrée juste à droite du bouton Seed (centrée verticalement dessus)
    local ARROW_W, ARROW_H = 70, 60
    local arrow = Instance.new("TextLabel", sg)
    arrow.Size                   = UDim2.new(0, ARROW_W, 0, ARROW_H)
    arrow.AnchorPoint            = Vector2.new(0, 0.5)
    arrow.Position               = UDim2.new(0, 92, 0.5, 0)  -- fallback si bouton introuvable
    arrow.BackgroundTransparency = 1
    arrow.Text                   = "👈"
    arrow.Font                   = Enum.Font.GothamBold
    arrow.TextScaled             = true
    arrow.TextColor3             = Color3.fromRGB(255, 220, 50)
    arrow.TextStrokeTransparency = 0
    arrow.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
    arrow.ZIndex                 = 10

    -- Ancrage dynamique : flèche collée à droite du bouton, alignée sur son centre Y
    local bobTween = nil
    local function ancrerFleche()
        if not (dailyBtn and dailyBtn.Parent) then return end
        local bp, bs = dailyBtn.AbsolutePosition, dailyBtn.AbsoluteSize
        if bs.X <= 0 then return end
        local baseX = bp.X + bs.X + 6
        local baseY = bp.Y + bs.Y / 2
        arrow.Position = UDim2.fromOffset(baseX, baseY)
        -- Bobbing horizontal (relance le tween à chaque ré-ancrage)
        if bobTween then bobTween:Cancel() end
        bobTween = TweenService:Create(arrow,
            TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { Position = UDim2.fromOffset(baseX + 16, baseY) })
        bobTween:Play()
    end

    if dailyBtn then
        -- Tenter d'ancrer dès que le bouton a une taille (peut être 0 au 1er frame)
        for _ = 1, 30 do
            ancrerFleche()
            if dailyBtn.AbsoluteSize.X > 0 then break end
            task.wait()
        end
        dailyBtn:GetPropertyChangedSignal("AbsolutePosition"):Connect(ancrerFleche)
    else
        -- Fallback : bobbing sur la position fixe
        TweenService:Create(arrow,
            TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { Position = UDim2.new(0, 108, 0.5, 0) }
        ):Play()
    end

    -- Lien 3D vers le FlowerPot_1 (déclaré ici, créé en fin de fonction).
    -- Survit au clic Seed et guide vers la plantation.
    local fermerLienPot = function() end

    -- Disparition de la bannière + flèche Seed : clic sur le bouton OU timeout 60s
    -- (n'affecte PAS le lien vers le pot, qui guide après la récupération de la graine)
    local fini = false
    local function fermer()
        if fini then return end
        fini = true
        if sg.Parent then sg:Destroy() end
    end
    if dailyBtn then
        dailyBtn.MouseButton1Click:Connect(fermer)
    end
    task.delay(60, fermer)

    -- Détection plantation : le serveur envoie PotBillboardUpdate(potModel, data)
    -- avec data non-nul dès qu'une graine pousse → retire message ET lien, puis étape 4.
    local PotBillboardUpdate = RS:FindFirstChild("PotBillboardUpdate")
                            or RS:WaitForChild("PotBillboardUpdate", 5)
    local plantConn
    if PotBillboardUpdate then
        plantConn = PotBillboardUpdate.OnClientEvent:Connect(function(potModelEvt, data)
            if data then  -- pot planté (croissance en cours)
                if plantConn then plantConn:Disconnect() ; plantConn = nil end
                fermer()
                fermerLienPot()
                -- Gros compteur total au-dessus du pot planté
                local potPart = partDe(potModelEvt) or trouverFlowerPot1()
                creerGrosCompteur(potPart, data.plantedAt, data.dureeStage)
                task.delay(0.4, messageFinalOuverture)  -- étape 4
            end
        end)
    end

    -- Lien vers le pot de SA base (approche 10 studs, timeout 120s)
    fermerLienPot = creerLienVers(trouverFlowerPot1(), "Plant here!", 10, 120)
end

-- Flèche BillboardGui au-dessus du joueur avec bobbing
local function creerFleche()
    local character = player.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local ancienne = hrp:FindFirstChild("OnboardingArrowBB")
    if ancienne then ancienne:Destroy() end

    local bb = Instance.new("BillboardGui")
    bb.Name             = "OnboardingArrowBB"
    bb.Size             = UDim2.new(0, 120, 0, 90)
    bb.StudsOffset      = Vector3.new(0, 6, 0)
    bb.AlwaysOnTop      = false
    bb.MaxDistance      = 80
    bb.ClipsDescendants = false
    bb.Parent           = hrp

    local fleche = Instance.new("TextLabel", bb)
    fleche.Size                   = UDim2.new(1, 0, 0.55, 0)
    fleche.Position               = UDim2.new(0, 0, 0, 0)
    fleche.BackgroundTransparency = 1
    fleche.Text                   = "⬇"
    fleche.Font                   = Enum.Font.GothamBold
    fleche.TextColor3             = Color3.fromRGB(255, 220, 50)
    fleche.TextScaled             = true
    fleche.TextStrokeTransparency = 0
    fleche.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)

    local texte = Instance.new("TextLabel", bb)
    texte.Size                   = UDim2.new(1, 0, 0.45, 0)
    texte.Position               = UDim2.new(0, 0, 0.55, 0)
    texte.BackgroundTransparency = 1
    texte.Text                   = "Catch a BrainRot!"
    texte.Font                   = Enum.Font.GothamBold
    texte.TextColor3             = Color3.fromRGB(255, 255, 255)
    texte.TextScaled             = true
    texte.TextStrokeTransparency = 0.2
    texte.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
    texte.TextWrapped            = true

    -- Bobbing axe Y
    TweenService:Create(bb,
        TweenInfo.new(0.65, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { StudsOffset = Vector3.new(0, 8.5, 0) }
    ):Play()

    -- Auto-destroy après 30s
    task.delay(30, function()
        if bb and bb.Parent then bb:Destroy() end
        arrowActive = false
    end)

    return bb
end

-- Floating text "+X 🎉 FIRST CASH!" doré qui monte et s'efface
local function celebrerPremierDepot(bonusCoins)
    -- Étape 1 terminée : fermer le lien vers la base
    if _fermerLienBase then _fermerLienBase() ; _fermerLienBase = nil end

    local character = player.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local bb = Instance.new("BillboardGui")
    bb.Name        = "FirstDepositVFX"
    bb.Size        = UDim2.new(0, 220, 0, 70)
    bb.StudsOffset = Vector3.new(0, 10, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 60
    bb.Parent      = hrp

    local lbl = Instance.new("TextLabel", bb)
    lbl.Size                   = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = "+" .. tostring(bonusCoins) .. " 🎉 FIRST CASH!"
    lbl.Font                   = Enum.Font.GothamBold
    lbl.TextColor3             = Color3.fromRGB(255, 215, 0)
    lbl.TextScaled             = true
    lbl.TextStrokeTransparency = 0
    lbl.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)

    -- Montée
    TweenService:Create(bb,
        TweenInfo.new(2.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { StudsOffset = Vector3.new(0, 18, 0) }
    ):Play()
    -- Fade texte après 1.5s
    task.delay(1.5, function()
        if lbl and lbl.Parent then
            TweenService:Create(lbl, TweenInfo.new(1, Enum.EasingStyle.Quad), {
                TextTransparency = 1,
            }):Play()
        end
    end)
    task.delay(2.6, function()
        if bb and bb.Parent then bb:Destroy() end
    end)

    -- Petites particules dorées sur le HumanoidRootPart (côté client uniquement)
    local pe = Instance.new("ParticleEmitter", hrp)
    pe.Rate        = 30
    pe.Lifetime    = NumberRange.new(0.6, 1.2)
    pe.Speed       = NumberRange.new(8, 16)
    pe.SpreadAngle = Vector2.new(60, 60)
    pe.Color       = ColorSequence.new(Color3.fromRGB(255, 215, 0))
    pe.Size        = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
    pe.LightEmission = 0.8
    pe.Transparency = NumberSequence.new(0.2)
    task.delay(0.5, function() if pe.Parent then pe.Rate = 0 end end)
    task.delay(2, function() if pe.Parent then pe:Destroy() end end)

    -- Étape 3 onboarding : après la 1re cash, guider vers la Daily Seed (free Mutant à venir)
    task.delay(0.5, guiderVersDailySeed)
end

-- Détruire la flèche au premier pickup + créer le lien vers la base (à déposer)
local function surPremierPickup()
    local character = player.Character
    if character then
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local fleche = hrp:FindFirstChild("OnboardingArrowBB")
            if fleche then fleche:Destroy() end
        end
    end
    arrowActive = false

    -- Étape 1 (suite) : BR attrapé → lien vers le spot de dépôt de SA base
    -- (fermé au 1er dépôt via celebrerPremierDepot, ou à l'approche/timeout)
    afficherMessageHUD("Carry it to your base to deposit! 🏠")
    -- hauteur=0 : le beam descend jusqu'au spot au sol (pas en l'air)
    _fermerLienBase = creerLienVers(trouverSpotDepot(), "Deposit here!", 10, 90, 0)
end

-- Écoute des events onboarding depuis le serveur
OnboardingEvent.OnClientEvent:Connect(function(eventType, data)
    if eventType == "firstPickup" then
        surPremierPickup()
    elseif eventType == "firstDeposit" then
        celebrerPremierDepot(data or 100)
    end
end)

-- Déclenchement flèche à la réception du premier HUD
UpdateHUD.OnClientEvent:Connect(function(playerData)
    if arrowActive then return end
    if playerData.hasCompletedOnboarding then return end

    -- Onboarding non complété → afficher flèche + message
    arrowActive = true
    afficherMessageHUD("🎯 Catch a BrainRot!")
    task.spawn(function()
        local character = player.Character or player.CharacterAdded:Wait()
        local hrp = character:WaitForChild("HumanoidRootPart", 10)
        if not hrp then return end
        task.wait(1.2) -- laisser le téléport vers la base se stabiliser
        creerFleche()
    end)
end)
