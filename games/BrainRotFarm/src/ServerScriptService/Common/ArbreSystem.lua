-- ServerScriptService/Common/ArbreSystem.lua
-- Gère les 2 arbres du ChampCommun (Tree 1 et Tree 2)
-- Graine toutes les 30 min au sommet d'un arbre aléatoire
-- Fumée dorée + billboard + compteur dégressif + ProximityPrompt

local ArbreSystem  = {}
local TweenService = game:GetService("TweenService")
local RS           = game:GetService("ReplicatedStorage")

-- Callback données joueur — assigné par Main.server.lua
ArbreSystem.GetData = nil

-- ═══════════════════════════════════════
-- HELPER — Format timer MM:SS
-- ═══════════════════════════════════════

local function FormatTimer(secondes)
    local m = math.floor(secondes / 60)
    local s = math.floor(secondes % 60)
    return string.format("%02d:%02d", m, s)
end

-- ═══════════════════════════════════════
-- CRÉER PART INVISIBLE AU SOMMET
-- ═══════════════════════════════════════

local function GetOuCreerSommetPart(arbre, sommetPos)
    local existing = arbre:FindFirstChild("SommetPart")
    if existing then return existing end

    local part = Instance.new("Part", arbre)
    part.Name         = "SommetPart"
    part.Size         = Vector3.new(3, 3, 3)
    part.Position     = sommetPos
    part.Anchored     = true
    part.CanCollide   = false
    part.Transparency = 1
    part.CastShadow   = false

    return part
end

-- ═══════════════════════════════════════
-- CRÉER BILLBOARD
-- ═══════════════════════════════════════

local function CreerBillboard(sommetPart, texte, couleur)
    -- Détruire le billboard existant si présent
    local existing = sommetPart:FindFirstChild("SeedBillboard")
    if existing then existing:Destroy() end

    local bb = Instance.new("BillboardGui", sommetPart)
    bb.Name        = "SeedBillboard"
    bb.Size        = UDim2.new(0, 220, 0, 90)
    bb.StudsOffset = Vector3.new(0, 6, 0)
    bb.AlwaysOnTop = false
    bb.MaxDistance = 120

    local fond = Instance.new("Frame", bb)
    fond.Size                   = UDim2.new(1, 0, 1, 0)
    fond.BackgroundColor3       = Color3.fromRGB(20, 15, 5)
    fond.BackgroundTransparency = 0.15
    fond.BorderSizePixel        = 0
    Instance.new("UICorner", fond).CornerRadius = UDim.new(0, 10)

    local stroke = Instance.new("UIStroke", fond)
    stroke.Color     = couleur or Color3.fromRGB(255, 200, 0)
    stroke.Thickness = 2.5

    local label = Instance.new("TextLabel", fond)
    label.Name                   = "Label"
    label.Size                   = UDim2.new(1, -10, 1, 0)
    label.Position               = UDim2.new(0, 5, 0, 0)
    label.BackgroundTransparency = 1
    label.TextColor3             = couleur or Color3.fromRGB(255, 215, 0)
    label.Font                   = Enum.Font.GothamBold
    label.TextSize               = 16
    label.TextWrapped            = true
    label.RichText               = true
    label.Text                   = texte

    local txtStroke = Instance.new("UIStroke", label)
    txtStroke.Color     = Color3.fromRGB(0, 0, 0)
    txtStroke.Thickness = 1.5

    return bb, label
end

-- ═══════════════════════════════════════
-- EFFETS VISUELS
-- ═══════════════════════════════════════

-- Ajouter ou ajuster le ParticleEmitter fumée dorée
local function AjouterFumeeDoree(sommetPart, rate)
    local existing = sommetPart:FindFirstChild("SeedParticles")
    if existing then
        existing.Rate = rate or 5
        return existing
    end

    local p = Instance.new("ParticleEmitter", sommetPart)
    p.Name          = "SeedParticles"
    p.Rate          = rate or 5
    p.Lifetime      = NumberRange.new(2, 4)
    p.Speed         = NumberRange.new(3, 8)
    p.SpreadAngle   = Vector2.new(30, 30)
    p.Color         = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   Color3.fromRGB(255, 215, 0)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 150, 0)),
        ColorSequenceKeypoint.new(1,   Color3.fromRGB(255, 255, 150)),
    })
    p.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0,   0.5),
        NumberSequenceKeypoint.new(0.5, 1.2),
        NumberSequenceKeypoint.new(1,   0),
    })
    p.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0,   0),
        NumberSequenceKeypoint.new(0.5, 0.3),
        NumberSequenceKeypoint.new(1,   1),
    })
    p.LightEmission  = 0.8
    p.LightInfluence = 0.2
    p.RotSpeed       = NumberRange.new(-45, 45)

    return p
end

-- Ajouter ou ajuster le PointLight
local function AjouterLumiere(sommetPart, brightness)
    local existing = sommetPart:FindFirstChild("SeedLight")
    if existing then
        existing.Brightness = brightness or 0
        return existing
    end

    local light = Instance.new("PointLight", sommetPart)
    light.Name       = "SeedLight"
    light.Brightness = brightness or 0
    light.Range      = 25
    light.Color      = Color3.fromRGB(255, 215, 0)

    return light
end

-- ═══════════════════════════════════════
-- ACTIVER GRAINE SUR UN ARBRE
-- ═══════════════════════════════════════

-- onCollect(player, typeGraine) appelé quand un joueur récupère la graine
local function ActiverGraine(sommetPart, typeGraine, onCollect)
    local Config    = require(game.ReplicatedStorage.Specialized.GameConfig)
    local graineCfg = Config.FlowerPotConfig.graines[typeGraine]
    -- couleurStage4 utilisée comme couleur d'accentuation du type
    local couleur   = (graineCfg and graineCfg.couleurStage4)
                   or Color3.fromRGB(255, 215, 0)

    -- Billboard "SEED READY!"
    local bb, label = CreerBillboard(sommetPart,
        "🌱 " .. typeGraine .. " SEED\n✨ READY! Press E",
        couleur)

    -- Pulse du texte (clignotement doux)
    task.spawn(function()
        while bb and bb.Parent do
            TweenService:Create(label,
                TweenInfo.new(0.7, Enum.EasingStyle.Sine,
                    Enum.EasingDirection.InOut, -1, true),
                { TextTransparency = 0.5 }):Play()
            task.wait(1.4)
        end
    end)

    -- Fumée intense (graine présente)
    local particles = AjouterFumeeDoree(sommetPart, 30)

    -- Lumière pulsante
    local light = AjouterLumiere(sommetPart, 3)
    task.spawn(function()
        while light and light.Parent and light.Brightness > 0 do
            TweenService:Create(light,
                TweenInfo.new(0.8, Enum.EasingStyle.Sine,
                    Enum.EasingDirection.InOut, -1, true),
                { Brightness = 6 }):Play()
            task.wait(1.6)
        end
    end)

    -- ProximityPrompt (supprimer l'ancien s'il existe)
    local existing = sommetPart:FindFirstChild("SeedPrompt")
    if existing then existing:Destroy() end

    local pp = Instance.new("ProximityPrompt", sommetPart)
    pp.Name                  = "SeedPrompt"
    pp.ActionText            = "Collect Seed"
    pp.ObjectText            = "🌱 " .. typeGraine .. " Seed"
    pp.HoldDuration          = 0.5
    pp.MaxActivationDistance = 20
    pp.KeyboardKeyCode       = Enum.KeyCode.E
    pp.RequiresLineOfSight   = false
    pp.Enabled               = true

    local aEteCollecte = false

    pp.Triggered:Connect(function(player)
        if aEteCollecte then return end
        aEteCollecte = true
        pp.Enabled   = false

        -- Réduire la fumée (retour léger après collecte)
        particles.Rate = 5
        TweenService:Create(light,
            TweenInfo.new(0.5), { Brightness = 0 }):Play()

        -- Billboard de confirmation
        label.Text       = "✅ Collected by\n" .. player.Name .. "!"
        label.TextColor3 = Color3.fromRGB(100, 255, 100)

        -- Callback principal
        if onCollect then
            pcall(onCollect, player, typeGraine)
        end

        -- Nettoyer billboard et prompt après 4s
        task.delay(4, function()
            if bb and bb.Parent then bb:Destroy() end
            if pp and pp.Parent then pp:Destroy() end
        end)
    end)

    -- Retourner flag et prompt pour le timeout externe
    return function() return aEteCollecte end, pp
end

-- ═══════════════════════════════════════
-- METTRE À JOUR COMPTEURS DES ARBRES
-- ═══════════════════════════════════════

local function MettreAJourCompteurs(sommetParts, secondes, texteOverride)
    for _, sommetPart in ipairs(sommetParts) do
        local bb    = sommetPart:FindFirstChild("SeedBillboard")
        local label = bb and bb:FindFirstChild("Label")
        if label then
            label.Text       = texteOverride
                or ("⏳ Next seed:\n" .. FormatTimer(secondes))
            label.TextColor3 = Color3.fromRGB(200, 200, 200)
        end
    end
end

-- ═══════════════════════════════════════
-- CALLBACK COLLECTE GRAINE
-- ═══════════════════════════════════════

local function OnGraineCollectee(player, typeGraine)
    -- Récupérer les données via le callback fourni par Main
    local data = ArbreSystem.GetData and ArbreSystem.GetData(player)
    if not data then
        warn("[ArbreSystem] GetData nil pour " .. player.Name)
        return
    end

    -- Incrémenter l'inventaire de graines
    data.graines                  = data.graines or { MYTHIC = 0, SECRET = 0 }
    data.graines[typeGraine]      = (data.graines[typeGraine] or 0) + 1
    local total = data.graines[typeGraine]

    -- Notifier le joueur
    local NotifEvent = RS:FindFirstChild("NotifEvent")
    if NotifEvent then
        pcall(function()
            NotifEvent:FireClient(player, "SUCCESS",
                "🌱 Got 1 " .. typeGraine .. " Seed! ("
                .. total .. " total)")
        end)
    end

    -- Synchroniser l'HUD graines côté client
    local UpdateGraines = RS:FindFirstChild("UpdateGraines")
    if UpdateGraines then
        pcall(function()
            UpdateGraines:FireClient(player, data.graines)
        end)
    end

    print(string.format("[ArbreSystem] %s → +%s Seed (%d total)",
        player.Name, typeGraine, total))
end

-- ═══════════════════════════════════════
-- INIT PRINCIPAL
-- ═══════════════════════════════════════

function ArbreSystem.Init()
    local Config       = require(game.ReplicatedStorage.Specialized.GameConfig)
    local arbreCfg     = Config.FlowerPotConfig.arbresDropConfig
    local arbresConfig = Config.FlowerPotConfig.arbresConfig

    -- Vérifications de config
    if not arbreCfg or not arbresConfig then
        warn("[ArbreSystem] arbresConfig / arbresDropConfig manquant dans GameConfig")
        return
    end

    local champCommun = workspace:FindFirstChild("ChampCommun")
    if not champCommun then
        warn("[ArbreSystem] ChampCommun introuvable dans Workspace")
        return
    end

    -- Préparer les arbres avec leur SommetPart et effets permanents
    local arbresDonnees = {}
    for _, cfg in ipairs(arbresConfig) do
        local arbre = champCommun:FindFirstChild(cfg.nom)
        if arbre then
            local sommetPart = GetOuCreerSommetPart(arbre, cfg.sommetPos)

            -- Fumée légère permanente
            AjouterFumeeDoree(sommetPart, 5)

            -- Lumière faible permanente
            AjouterLumiere(sommetPart, 0.5)

            -- Billboard compteur initial
            CreerBillboard(sommetPart,
                "⏳ Next seed:\n" .. FormatTimer(arbreCfg.intervalleSecondes),
                Color3.fromRGB(200, 200, 200))

            table.insert(arbresDonnees, {
                arbre      = arbre,
                sommetPart = sommetPart,
                nom        = cfg.nom,
            })

            print("[ArbreSystem] " .. cfg.nom .. " initialisé ✓")
        else
            warn("[ArbreSystem] " .. cfg.nom .. " introuvable dans ChampCommun")
        end
    end

    if #arbresDonnees == 0 then
        warn("[ArbreSystem] Aucun arbre trouvé — abandon")
        return
    end

    -- ═══ BOUCLE PRINCIPALE ═══
    task.spawn(function()
        while true do
            local intervalle = arbreCfg.intervalleSecondes

            -- Extraire toutes les SommetParts pour les compteurs groupés
            local toutesLesParts = {}
            for _, d in ipairs(arbresDonnees) do
                table.insert(toutesLesParts, d.sommetPart)
            end

            -- Countdown dégressif sur tous les arbres
            for t = intervalle, 1, -1 do
                MettreAJourCompteurs(toutesLesParts, t)
                task.wait(1)
            end

            -- Choisir un arbre aléatoire pour la graine
            local idx    = math.random(1, #arbresDonnees)
            local choisi = arbresDonnees[idx]

            -- Lister les parts des autres arbres (affichage secondaire)
            local autresParts = {}
            for i, d in ipairs(arbresDonnees) do
                if i ~= idx then
                    table.insert(autresParts, d.sommetPart)
                end
            end

            -- Choisir le type de graine (MYTHIC 70% / SECRET 30%)
            local rand       = math.random(1, 100)
            local typeGraine = (rand <= arbreCfg.chanceMYTHIC) and "MYTHIC" or "SECRET"

            print(string.format("[ArbreSystem] Graine %s sur %s",
                typeGraine, choisi.nom))

            -- Activer la graine sur l'arbre choisi
            local collecte = false
            local getCollecte, pp = ActiverGraine(choisi.sommetPart, typeGraine,
                function(player, type_)
                    collecte = true
                    OnGraineCollectee(player, type_)
                end)

            -- Billboard informatif sur les autres arbres
            MettreAJourCompteurs(autresParts, 0,
                "🌳 " .. choisi.nom .. "\nhas a seed!")

            -- Attendre collecte ou timeout
            local elapsed = 0
            local timeout = arbreCfg.timeoutSecondes or 300

            while elapsed < timeout and not collecte do
                task.wait(1)
                elapsed = elapsed + 1
                collecte = getCollecte()
            end

            -- Si non collectée : nettoyer prompt et log
            if not collecte then
                print(string.format("[ArbreSystem] Graine expirée sur %s (timeout %ds)",
                    choisi.nom, timeout))
                local ppExist = choisi.sommetPart:FindFirstChild("SeedPrompt")
                if ppExist then ppExist:Destroy() end
                local bbExist = choisi.sommetPart:FindFirstChild("SeedBillboard")
                if bbExist then bbExist:Destroy() end
            end

            -- Reset visuels sur tous les arbres pour le prochain cycle
            for _, d in ipairs(arbresDonnees) do
                local particles = d.sommetPart:FindFirstChild("SeedParticles")
                local light     = d.sommetPart:FindFirstChild("SeedLight")
                if particles then particles.Rate = 5 end
                if light then
                    TweenService:Create(light,
                        TweenInfo.new(0.5), { Brightness = 0.5 }):Play()
                end
                -- Recréer billboard compteur
                CreerBillboard(d.sommetPart,
                    "⏳ Next seed:\n" .. FormatTimer(intervalle),
                    Color3.fromRGB(200, 200, 200))
            end
        end
    end)

    print(string.format("[ArbreSystem] ✓ Graines toutes les %.0f min",
        arbreCfg.intervalleSecondes / 60))
end

return ArbreSystem
