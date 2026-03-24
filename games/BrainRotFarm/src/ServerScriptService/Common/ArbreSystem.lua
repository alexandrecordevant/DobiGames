-- ServerScriptService/Common/ArbreSystem.lua
-- Gère les 2 arbres du ChampCommun (Tree 1 et Tree 2)
-- Graine toutes les 30 min — apparaît simultanément sur les 2 arbres
-- Fumée mystérieuse violette permanente → dorée quand graine présente

local ArbreSystem  = {}
local TweenService = game:GetService("TweenService")
local RS           = game:GetService("ReplicatedStorage")

-- Callback données joueur — assigné par Main.server.lua
ArbreSystem.GetData = nil

-- ═══════════════════════════════════════
-- COULEURS FUMÉE
-- ═══════════════════════════════════════

local FUMEE_PERMANENTE = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(180, 0,   255)),
    ColorSequenceKeypoint.new(0.3, Color3.fromRGB(130, 20,  230)),
    ColorSequenceKeypoint.new(0.7, Color3.fromRGB(70,  0,   180)),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB(20,  0,   80)),
})

local FUMEE_ACTIVE = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(255, 240, 80)),
    ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 180, 0)),
    ColorSequenceKeypoint.new(0.8, Color3.fromRGB(255, 100, 0)),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB(255, 255, 200)),
})

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
    part.Size         = Vector3.new(4, 4, 4)
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
    local existing = sommetPart:FindFirstChild("SeedBillboard")
    if existing then existing:Destroy() end

    local bb = Instance.new("BillboardGui", sommetPart)
    bb.Name        = "SeedBillboard"
    bb.Size        = UDim2.new(0, 240, 0, 100)
    bb.StudsOffset = Vector3.new(0, 8, 0)
    bb.AlwaysOnTop = false
    bb.MaxDistance = 150

    local fond = Instance.new("Frame", bb)
    fond.Size                   = UDim2.new(1, 0, 1, 0)
    fond.BackgroundColor3       = Color3.fromRGB(15, 5, 30)
    fond.BackgroundTransparency = 0.1
    fond.BorderSizePixel        = 0
    Instance.new("UICorner", fond).CornerRadius = UDim.new(0, 12)

    local stroke = Instance.new("UIStroke", fond)
    stroke.Color     = couleur or Color3.fromRGB(180, 0, 255)
    stroke.Thickness = 3

    local label = Instance.new("TextLabel", fond)
    label.Name                   = "Label"
    label.Size                   = UDim2.new(1, -12, 1, 0)
    label.Position               = UDim2.new(0, 6, 0, 0)
    label.BackgroundTransparency = 1
    label.TextColor3             = couleur or Color3.fromRGB(200, 100, 255)
    label.Font                   = Enum.Font.GothamBold
    label.TextSize               = 17
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

-- Fumée mystérieuse violette permanente
local function AjouterFumee(sommetPart, rate)
    local existing = sommetPart:FindFirstChild("SeedParticles")
    if existing then
        existing.Rate = rate or 20
        return existing
    end

    local p = Instance.new("ParticleEmitter", sommetPart)
    p.Name          = "SeedParticles"
    p.Rate          = rate or 20
    p.Lifetime      = NumberRange.new(3, 7)
    p.Speed         = NumberRange.new(1, 4)
    p.SpreadAngle   = Vector2.new(70, 70)
    p.Color         = FUMEE_PERMANENTE
    p.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0,   0.6),
        NumberSequenceKeypoint.new(0.25, 3.0),
        NumberSequenceKeypoint.new(0.6, 2.5),
        NumberSequenceKeypoint.new(1,   0),
    })
    p.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0,   0.1),
        NumberSequenceKeypoint.new(0.4, 0.35),
        NumberSequenceKeypoint.new(1,   1),
    })
    p.LightEmission  = 1
    p.LightInfluence = 0
    p.RotSpeed       = NumberRange.new(-90, 90)
    p.Rotation       = NumberRange.new(0, 360)

    return p
end

-- PointLight
local function AjouterLumiere(sommetPart, brightness)
    local existing = sommetPart:FindFirstChild("SeedLight")
    if existing then
        existing.Brightness = brightness or 0
        return existing
    end

    local light = Instance.new("PointLight", sommetPart)
    light.Name       = "SeedLight"
    light.Brightness = brightness or 0
    light.Range      = 30
    light.Color      = Color3.fromRGB(180, 0, 255)

    return light
end

-- ═══════════════════════════════════════
-- ACTIVER GRAINE SUR UN ARBRE
-- ═══════════════════════════════════════

local function ActiverGraine(sommetPart, typeGraine, onCollect)
    local Config    = require(game.ReplicatedStorage.Specialized.GameConfig)
    local graineCfg = Config.FlowerPotConfig.graines[typeGraine]
    local couleur   = (graineCfg and graineCfg.couleurStage4)
                   or Color3.fromRGB(255, 215, 0)

    -- Billboard "SEED READY!"
    local bb, label = CreerBillboard(sommetPart,
        "🌱 " .. typeGraine .. " SEED\n✨ READY! Press E",
        couleur)

    -- Pulse du texte
    task.spawn(function()
        while bb and bb.Parent do
            TweenService:Create(label,
                TweenInfo.new(0.7, Enum.EasingStyle.Sine,
                    Enum.EasingDirection.InOut, -1, true),
                { TextTransparency = 0.5 }):Play()
            task.wait(1.4)
        end
    end)

    -- Fumée dorée intense (graine présente)
    local particles = AjouterFumee(sommetPart, 60)
    particles.Color = FUMEE_ACTIVE

    -- Lumière dorée pulsante
    local light = AjouterLumiere(sommetPart, 4)
    light.Color = couleur
    task.spawn(function()
        while light and light.Parent and light.Brightness > 0 do
            TweenService:Create(light,
                TweenInfo.new(0.8, Enum.EasingStyle.Sine,
                    Enum.EasingDirection.InOut, -1, true),
                { Brightness = 8 }):Play()
            task.wait(1.6)
        end
    end)

    -- ProximityPrompt
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

        -- Retour fumée mystérieuse violette
        particles.Rate  = 20
        particles.Color = FUMEE_PERMANENTE
        light.Color     = Color3.fromRGB(180, 0, 255)
        TweenService:Create(light,
            TweenInfo.new(0.5), { Brightness = 1 }):Play()

        -- Billboard de confirmation
        label.Text       = "✅ Collected by\n" .. player.Name .. "!"
        label.TextColor3 = Color3.fromRGB(100, 255, 100)

        if onCollect then
            pcall(onCollect, player, typeGraine)
        end

        task.delay(4, function()
            if bb and bb.Parent then bb:Destroy() end
            if pp and pp.Parent then pp:Destroy() end
        end)
    end)

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
            label.TextColor3 = Color3.fromRGB(180, 140, 255)
        end
    end
end

-- ═══════════════════════════════════════
-- CALLBACK COLLECTE GRAINE
-- ═══════════════════════════════════════

local function OnGraineCollectee(player, typeGraine)
    local data = ArbreSystem.GetData and ArbreSystem.GetData(player)
    if not data then
        warn("[ArbreSystem] GetData nil pour " .. player.Name)
        return
    end

    data.graines                  = data.graines or { MYTHIC = 0, SECRET = 0 }
    data.graines[typeGraine]      = (data.graines[typeGraine] or 0) + 1
    local total = data.graines[typeGraine]

    local NotifEvent = RS:FindFirstChild("NotifEvent")
    if NotifEvent then
        pcall(function()
            NotifEvent:FireClient(player, "SUCCESS",
                "🌱 Got 1 " .. typeGraine .. " Seed! ("
                .. total .. " total)")
        end)
    end

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

    if not arbreCfg or not arbresConfig then
        warn("[ArbreSystem] arbresConfig / arbresDropConfig manquant dans GameConfig")
        return
    end

    local champCommun = workspace:FindFirstChild("ChampCommun")
    if not champCommun then
        warn("[ArbreSystem] ChampCommun introuvable dans Workspace")
        return
    end

    -- Préparer les arbres
    local arbresDonnees = {}
    for _, cfg in ipairs(arbresConfig) do
        local arbre = champCommun:FindFirstChild(cfg.nom)
        if arbre then
            local sommetPart = GetOuCreerSommetPart(arbre, cfg.sommetPos)

            -- Fumée mystérieuse violette permanente
            AjouterFumee(sommetPart, 20)

            -- Lumière violette faible permanente
            AjouterLumiere(sommetPart, 1)

            -- Billboard compteur initial
            CreerBillboard(sommetPart,
                "⏳ Next seed:\n" .. FormatTimer(arbreCfg.intervalleSecondes),
                Color3.fromRGB(180, 100, 255))

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

            local toutesLesParts = {}
            for _, d in ipairs(arbresDonnees) do
                table.insert(toutesLesParts, d.sommetPart)
            end

            -- Countdown 30:00 → 00:00 sur tous les arbres
            for t = intervalle, 0, -1 do
                MettreAJourCompteurs(toutesLesParts, t)
                if t > 0 then task.wait(1) end
            end

            -- Activer une graine sur CHAQUE arbre simultanément
            local treeEtats = {}
            for _, d in ipairs(arbresDonnees) do
                local rand       = math.random(1, 100)
                local typeGraine = (rand <= arbreCfg.chanceMYTHIC)
                    and "MYTHIC" or "SECRET"

                print(string.format("[ArbreSystem] Graine %s sur %s",
                    typeGraine, d.nom))

                local getC, _ = ActiverGraine(d.sommetPart, typeGraine,
                    function(player, type_)
                        OnGraineCollectee(player, type_)
                    end)

                table.insert(treeEtats, { d = d, getC = getC })
            end

            -- Attendre que toutes soient collectées ou timeout
            local elapsed = 0
            local timeout = arbreCfg.timeoutSecondes or 300

            while elapsed < timeout do
                task.wait(1)
                elapsed = elapsed + 1
                local allDone = true
                for _, e in ipairs(treeEtats) do
                    if not e.getC() then allDone = false end
                end
                if allDone then break end
            end

            -- Nettoyer les graines non collectées
            for _, e in ipairs(treeEtats) do
                if not e.getC() then
                    print(string.format("[ArbreSystem] Graine expirée sur %s (timeout %ds)",
                        e.d.nom, timeout))
                    local ppExist = e.d.sommetPart:FindFirstChild("SeedPrompt")
                    if ppExist then ppExist:Destroy() end
                    local bbExist = e.d.sommetPart:FindFirstChild("SeedBillboard")
                    if bbExist then bbExist:Destroy() end
                end
            end

            -- Reset visuels sur tous les arbres pour le prochain cycle
            for _, d in ipairs(arbresDonnees) do
                local particles = d.sommetPart:FindFirstChild("SeedParticles")
                local light     = d.sommetPart:FindFirstChild("SeedLight")
                if particles then
                    particles.Rate  = 20
                    particles.Color = FUMEE_PERMANENTE
                end
                if light then
                    light.Color = Color3.fromRGB(180, 0, 255)
                    TweenService:Create(light,
                        TweenInfo.new(0.5), { Brightness = 1 }):Play()
                end
                CreerBillboard(d.sommetPart,
                    "⏳ Next seed:\n" .. FormatTimer(intervalle),
                    Color3.fromRGB(180, 100, 255))
            end
        end
    end)

    print(string.format("[ArbreSystem] ✓ Graines toutes les %.0f min — 2 arbres simultanés",
        arbreCfg.intervalleSecondes / 60))
end

return ArbreSystem
